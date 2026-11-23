/* Jsonw.java: jsonW para Java 22+ pela FFM (sem JNI e sem dependência), por cima da ABI C (libjsonw).
 *   try (var a = new Jsonw.Leitor("dados.jsw")) { for (long i = 0; i < a.linhas; i++) IO.println(a.json(i)); }
 *   try (var w = new Jsonw.Escritor("novo.jsw", "id:i64,nome:texto")) { w.gravar("{\"id\":1,\"nome\":\"x\"}"); }
 * Rodar: java --enable-native-access=ALL-UNNAMED Jsonw.java arquivo.jsw */
import java.lang.foreign.*;
import java.lang.invoke.MethodHandle;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;

public final class Jsonw {
    private Jsonw() {}

    static final AddressLayout P = ValueLayout.ADDRESS;
    static final ValueLayout.OfLong SZ = ValueLayout.JAVA_LONG;
    static final ValueLayout.OfInt I32 = ValueLayout.JAVA_INT;
    private static final int ERRO = 320;

    private static final Linker L = Linker.nativeLinker();
    private static final SymbolLookup LIB = carregar();

    /** A biblioteca: JSONW_LIB, a pasta atual, as de cima ou bin/<plataforma> do pacote. */
    private static SymbolLookup carregar() {
        var so = System.getProperty("os.name").toLowerCase();
        var maq = switch (System.getProperty("os.arch").toLowerCase()) {
            case "aarch64" -> "arm64";
            case "amd64" -> "x86_64";
            case String outra -> outra;
        };
        var win = so.contains("win");
        var plat = (win ? "windows" : so.contains("mac") ? "macos" : "linux") + "-" + maq;
        var dito = System.getenv("JSONW_LIB");
        if (dito != null && !dito.isEmpty()) return SymbolLookup.libraryLookup(Path.of(dito).toAbsolutePath(), Arena.global());
        var nomes = win ? List.of("libjsonw.dll") : List.of("libjsonw.dylib", "libjsonw.so");
        for (var base : List.of(".", "..", "../..", "bin/" + plat, "../bin/" + plat, "../../bin/" + plat))
            for (var n : nomes) {
                var p = Path.of(base, n);
                if (Files.exists(p)) return SymbolLookup.libraryLookup(p.toAbsolutePath(), Arena.global());
            }
        throw new IllegalStateException("libjsonw nao encontrada para " + plat + ": aponte JSONW_LIB para a biblioteca");
    }

    static MethodHandle fn(String nome, FunctionDescriptor d) {
        return L.downcallHandle(LIB.find(nome).orElseThrow(() -> new IllegalStateException("libjsonw sem " + nome)), d);
    }

    private static final MethodHandle
        VERSAO = fn("jsonw_versao", FunctionDescriptor.of(P)),
        ABRIR = fn("jsonw_abrir", FunctionDescriptor.of(P, P, P, SZ)),
        FECHAR = fn("jsonw_fechar", FunctionDescriptor.ofVoid(P)),
        LINHAS = fn("jsonw_linhas", FunctionDescriptor.of(SZ, P)),
        CAMPOS = fn("jsonw_campos", FunctionDescriptor.of(I32, P)),
        ESQUEMA = fn("jsonw_esquema", FunctionDescriptor.of(P, P)),
        CAMPO_NOME = fn("jsonw_campo_nome", FunctionDescriptor.of(P, P, I32)),
        LINHA_JSON = fn("jsonw_linha_json", FunctionDescriptor.of(SZ, P, SZ, P, SZ)),
        LINHA_TEXTO = fn("jsonw_linha_texto", FunctionDescriptor.of(SZ, P, SZ, P, SZ)),
        CAMPO_JSON = fn("jsonw_campo_json", FunctionDescriptor.of(SZ, P, SZ, I32, P, SZ)),
        CONFERIR = fn("jsonw_conferir", FunctionDescriptor.of(I32, P, P, SZ)),
        VISAO = fn("jsonw_visao", FunctionDescriptor.of(I32, P, P, P, SZ)),
        INDEXAR = fn("jsonw_indexar", FunctionDescriptor.of(I32, P, I32)),
        TEM_INDICE = fn("jsonw_tem_indice", FunctionDescriptor.of(I32, P, I32)),
        CHAVE = fn("jsonw_chave", FunctionDescriptor.of(SZ, P, I32, P, SZ, P, SZ)),
        CRIAR = fn("jsonw_criar", FunctionDescriptor.of(P, P, P, P, SZ)),
        OPCOES = fn("jsonw_opcoes", FunctionDescriptor.of(I32, P, I32, I32, I32)),
        GRAVAR = fn("jsonw_gravar_json", FunctionDescriptor.of(I32, P, P, SZ, P, SZ)),
        DESCARREGAR = fn("jsonw_descarregar", FunctionDescriptor.of(I32, P)),
        FECHAR_W = fn("jsonw_fechar_escritor", FunctionDescriptor.of(I32, P)),
        ABANDONAR = fn("jsonw_abandonar", FunctionDescriptor.of(I32, P));

    /** Linha de outro tenant depois de visao() (-3 na ABI). */
    public static final class LinhaOculta extends RuntimeException {
        LinhaOculta() { super("linha oculta pela visao"); }
    }

    /** Erro devolvido pela biblioteca. */
    public static final class Erro extends RuntimeException {
        Erro(String msg) { super(msg); }
        Erro(Throwable causa) { super(causa); }
    }

    @FunctionalInterface interface Nativo<T> { T rodar() throws Throwable; }
    @FunctionalInterface interface Chamada { long rodar(MemorySegment b, long cap) throws Throwable; }

    /** Uma chamada nativa: Throwable vira Erro, RuntimeException passa como veio. */
    static <T> T nativo(Nativo<T> c) {
        try {
            return c.rodar();
        } catch (RuntimeException | Error e) {
            throw e;
        } catch (Throwable t) {
            throw new Erro(t);
        }
    }

    static String str(MemorySegment p) {
        return p.address() == 0 ? "" : p.reinterpret(Long.MAX_VALUE).getString(0);
    }

    static MemorySegment utf8(Arena ar, String s) {
        return ar.allocateFrom(s);
    }

    static long tamanho(MemorySegment s) {
        return s.byteSize() - 1;
    }

    /** Buffer que cresce até caber (-2 = curto). */
    static String lerTexto(Chamada c) {
        return nativo(() -> {
            try (var ar = Arena.ofConfined()) {
                for (long cap = 1 << 16; ; cap *= 4) {
                    var b = ar.allocate(cap);
                    long n = c.rodar(b, cap);
                    if (n == -2) continue;
                    if (n == -3) throw new LinhaOculta();
                    if (n < 0) throw new Erro("linha ou campo ilegivel");
                    return new String(b.asSlice(0, n).toArray(ValueLayout.JAVA_BYTE), StandardCharsets.UTF_8);
                }
            }
        });
    }

    private static void exigir(Nativo<Integer> c, MemorySegment erro) {
        if (nativo(c) != 0) throw new Erro(str(erro));
    }

    public static String versao() {
        return nativo(() -> str((MemorySegment) VERSAO.invokeExact()));
    }

    public static final class Leitor implements AutoCloseable {
        MemorySegment a;
        public final long linhas;
        public String esquema;
        public final List<String> campos = new ArrayList<>();

        public Leitor(String caminho) {
            try (var ar = Arena.ofConfined()) {
                var erro = ar.allocate(ERRO);
                a = nativo(() -> (MemorySegment) ABRIR.invokeExact(utf8(ar, caminho), erro, (long) ERRO));
                if (a.address() == 0) throw new Erro(str(erro));
            }
            linhas = nativo(() -> (long) LINHAS.invokeExact(a));
            lerEsquema();
        }

        private void lerEsquema() {
            esquema = nativo(() -> str((MemorySegment) ESQUEMA.invokeExact(a)));
            campos.clear();
            int n = nativo(() -> (int) CAMPOS.invokeExact(a));
            for (int i = 0; i < n; i++) {
                int k = i;
                campos.add(nativo(() -> str((MemorySegment) CAMPO_NOME.invokeExact(a, k))));
            }
        }

        public String json(long i) { return lerTexto((b, cap) -> (long) LINHA_JSON.invokeExact(a, i, b, cap)); }
        public String texto(long i) { return lerTexto((b, cap) -> (long) LINHA_TEXTO.invokeExact(a, i, b, cap)); }
        public String campo(long i, int k) { return lerTexto((b, cap) -> (long) CAMPO_JSON.invokeExact(a, i, k, b, cap)); }
        public String campo(long i, String nome) { return campo(i, indice(nome)); }

        public int indice(String nome) {
            int k = campos.indexOf(nome);
            if (k < 0) throw new Erro("campo inexistente: " + nome);
            return k;
        }

        public void conferir() {
            try (var ar = Arena.ofConfined()) {
                var erro = ar.allocate(ERRO);
                exigir(() -> (int) CONFERIR.invokeExact(a, erro, (long) ERRO), erro);
            }
        }

        /** Trava o que a sessão vê ("pessoal vendas tenant:42"); linha de outro tenant = LinhaOculta. */
        public Leitor visao(String escopos) {
            try (var ar = Arena.ofConfined()) {
                var erro = ar.allocate(ERRO);
                exigir(() -> (int) VISAO.invokeExact(a, utf8(ar, escopos), erro, (long) ERRO), erro);
            }
            lerEsquema();
            return this;
        }

        public void indexar(int k) {
            if (nativo(() -> (int) INDEXAR.invokeExact(a, k)) != 0) throw new Erro("campo sem indice");
        }

        public boolean temIndice(int k) {
            return nativo(() -> (int) TEM_INDICE.invokeExact(a, k)) == 1;
        }

        /** As linhas em que o campo k vale `valor` (o JSON do valor: "7", "\"RJ\""), em ordem crescente. */
        public long[] chave(int k, String valor) {
            try (var ar = Arena.ofConfined()) {
                var v = utf8(ar, valor);
                for (long cap = 16; ; ) {
                    var out = ar.allocate(ValueLayout.JAVA_LONG, cap);
                    long c = cap;
                    long n = nativo(() -> (long) CHAVE.invokeExact(a, k, v, tamanho(v), out, c));
                    if (n == -2) throw new Erro("valor nao e do tipo do campo");
                    if (n < 0) throw new Erro("campo invalido");
                    if (n <= cap) return out.asSlice(0, n * Long.BYTES).toArray(ValueLayout.JAVA_LONG);
                    cap = n;
                }
            }
        }

        @Override public void close() {
            if (a == null) return;
            var h = a;
            a = null;
            nativo(() -> { FECHAR.invokeExact(h); return null; });
        }
    }

    /** O destino só aparece no close(); abandonar() desiste e deixa o destino como estava. */
    public static final class Escritor implements AutoCloseable {
        private MemorySegment w;

        public Escritor(String caminho, String esquema) { this(caminho, esquema, 1, 0, 0); }

        public Escritor(String caminho, String esquema, int compressao, int hash, int blocoKb) {
            try (var ar = Arena.ofConfined()) {
                var erro = ar.allocate(ERRO);
                w = nativo(() -> (MemorySegment) CRIAR.invokeExact(utf8(ar, caminho), utf8(ar, esquema), erro, (long) ERRO));
                if (w.address() == 0) throw new Erro(str(erro));
            }
            nativo(() -> (int) OPCOES.invokeExact(w, compressao, hash, blocoKb));
        }

        public void gravar(String json) {
            try (var ar = Arena.ofConfined()) {
                var s = utf8(ar, json);
                var erro = ar.allocate(ERRO);
                exigir(() -> (int) GRAVAR.invokeExact(w, s, tamanho(s), erro, (long) ERRO), erro);
            }
        }

        public void descarregar() { nativo(() -> (int) DESCARREGAR.invokeExact(w)); }

        public void abandonar() {
            if (w == null) return;
            var h = w;
            w = null;
            nativo(() -> (int) ABANDONAR.invokeExact(h));
        }

        @Override public void close() {
            if (w == null) return;
            var h = w;
            w = null;
            if (nativo(() -> (int) FECHAR_W.invokeExact(h)) != 0) throw new Erro("nao gravou tudo");
        }
    }

    /** java Jsonw.java arq.jsw -> JSONL; --avaliar arq pedido k; --visao arq escopos pedido k; --reconhecer termos.jsw texto */
    public static void main(String[] args) {
        switch (args) {
            case String[] x when x.length == 4 && x[0].equals("--avaliar") -> {
                try (var a = new Leitor(x[1])) { IO.println(JsonwOps.avaliar(a, x[2], Long.parseLong(x[3]))); }
            }
            case String[] x when x.length == 5 && x[0].equals("--visao") -> {
                try (var a = new Leitor(x[1]).visao(x[2])) {
                    IO.println(String.join(",", a.campos));
                    for (long i = 0; i < a.linhas; i++) {
                        try { IO.println(a.json(i)); } catch (LinhaOculta _) { }
                    }
                    IO.println(JsonwOps.avaliar(a, x[3], Long.parseLong(x[4])));
                }
            }
            case String[] x when x.length == 3 && x[0].equals("--reconhecer") -> {
                try (var r = new JsonwOps.Reconhecedor(x[1])) { IO.println(r.reconhecer(x[2])); }
            }
            default -> {
                try (var a = new Leitor(args[0])) { for (long i = 0; i < a.linhas; i++) IO.println(a.json(i)); }
            }
        }
    }
}
