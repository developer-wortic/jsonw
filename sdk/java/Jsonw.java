/* Jsonw.java: jsonW (json Wondrous) para Java 22+ (FFM, sem JNI nem dependencia), por cima da ABI C (libjsonw).
 *   try (var a = new Jsonw.Leitor("dados.jsw")) { for (long i = 0; i < a.linhas; i++) System.out.println(a.json(i)); }
 *   try (var w = new Jsonw.Escritor("novo.jsw", "id:i64,nome:texto")) { w.gravar("{\"id\":1,\"nome\":\"x\"}"); }
 * Rodar: java --enable-native-access=ALL-UNNAMED Jsonw.java arquivo.jsw  (com libjsonw.dylib/.so na pasta sdk) */
import java.lang.foreign.*;
import java.lang.invoke.MethodHandle;
import java.nio.file.*;
import java.util.*;

public final class Jsonw {
    static final Linker L = Linker.nativeLinker();
    static final SymbolLookup LIB = carregar();
    static SymbolLookup carregar() {   /* a biblioteca: JSONW_LIB (caminho inteiro), a pasta atual, as de cima ou bin/<plataforma> do pacote */
        String so = System.getProperty("os.name").toLowerCase(), maq = System.getProperty("os.arch").toLowerCase();
        boolean win = so.contains("win"), mac = so.contains("mac");
        String plat = (win ? "windows" : mac ? "macos" : "linux") + "-" + (maq.equals("aarch64") ? "arm64" : maq.equals("amd64") ? "x86_64" : maq);
        String[] nomes = win ? new String[]{"libjsonw.dll"} : new String[]{"libjsonw.dylib", "libjsonw.so"};
        String dito = System.getenv("JSONW_LIB");
        if (dito != null && !dito.isEmpty()) return SymbolLookup.libraryLookup(Path.of(dito).toAbsolutePath(), Arena.global());
        for (String base : new String[]{".", "..", "../..", "bin/" + plat, "../bin/" + plat, "../../bin/" + plat}) for (String n : nomes) {
            Path p = Path.of(base, n); if (Files.exists(p)) return SymbolLookup.libraryLookup(p.toAbsolutePath(), Arena.global());
        }
        throw new RuntimeException("libjsonw nao encontrada para " + plat + ": aponte JSONW_LIB para a biblioteca (bin/<plataforma>/ do pacote) ou rode da pasta sdk com ela ao lado");
    }
    static MethodHandle fn(String nome, FunctionDescriptor d) { return L.downcallHandle(LIB.find(nome).orElseThrow(), d); }
    static final ValueLayout.OfLong U64 = ValueLayout.JAVA_LONG; static final AddressLayout P = ValueLayout.ADDRESS; static final ValueLayout.OfInt I32 = ValueLayout.JAVA_INT; static final ValueLayout.OfLong SZ = ValueLayout.JAVA_LONG;
    static final MethodHandle ABRIR = fn("jsonw_abrir", FunctionDescriptor.of(P, P, P, SZ)), FECHAR = fn("jsonw_fechar", FunctionDescriptor.ofVoid(P)),
        LINHAS = fn("jsonw_linhas", FunctionDescriptor.of(U64, P)), CAMPOS = fn("jsonw_campos", FunctionDescriptor.of(I32, P)),
        ESQUEMA = fn("jsonw_esquema", FunctionDescriptor.of(P, P)), CAMPO_NOME = fn("jsonw_campo_nome", FunctionDescriptor.of(P, P, I32)),
        LINHA_JSON = fn("jsonw_linha_json", FunctionDescriptor.of(SZ, P, U64, P, SZ)), LINHA_TEXTO = fn("jsonw_linha_texto", FunctionDescriptor.of(SZ, P, U64, P, SZ)),
        CAMPO_JSON = fn("jsonw_campo_json", FunctionDescriptor.of(SZ, P, U64, I32, P, SZ)), CONFERIR = fn("jsonw_conferir", FunctionDescriptor.of(I32, P, P, SZ)),
        CRIAR = fn("jsonw_criar", FunctionDescriptor.of(P, P, P, P, SZ)), OPCOES = fn("jsonw_opcoes", FunctionDescriptor.of(I32, P, I32, I32, I32)),
        GRAVAR = fn("jsonw_gravar_json", FunctionDescriptor.of(I32, P, P, SZ, P, SZ)), DESCARREGAR = fn("jsonw_descarregar", FunctionDescriptor.of(I32, P)),
        FECHAR_W = fn("jsonw_fechar_escritor", FunctionDescriptor.of(I32, P)), ABANDONAR = fn("jsonw_abandonar", FunctionDescriptor.of(I32, P)), VERSAO = fn("jsonw_versao", FunctionDescriptor.of(P)), VISAO = fn("jsonw_visao", FunctionDescriptor.of(I32, P, P, P, SZ));

    static String str(MemorySegment p) { return p.reinterpret(Long.MAX_VALUE).getString(0); }
    public static String versao() { try { return str((MemorySegment) VERSAO.invokeExact()); } catch (Throwable t) { throw new RuntimeException(t); } }
    public static final class LinhaOculta extends RuntimeException { LinhaOculta() { super("linha oculta pela visao"); } }   /* linha de outro tenant depois de visao() (-3 na ABI) */
    interface Chamada { long rodar(MemorySegment b, long cap) throws Throwable; }
    static String lerTexto(Chamada c) {
        long cap = 1 << 16;
        try (Arena ar = Arena.ofConfined()) {
            for (;;) {
                MemorySegment b = ar.allocate(cap); long n = c.rodar(b, cap);
                if (n == -2) { cap *= 4; continue; }
                if (n == -3) throw new LinhaOculta();
                if (n < 0) throw new RuntimeException("linha ou campo ilegivel");
                return new String(b.asSlice(0, n).toArray(ValueLayout.JAVA_BYTE), java.nio.charset.StandardCharsets.UTF_8);
            }
        } catch (RuntimeException e) { throw e; } catch (Throwable t) { throw new RuntimeException(t); }
    }

    public static final class Leitor implements AutoCloseable {
        MemorySegment a; public final long linhas; public String esquema; public final List<String> campos = new ArrayList<>();
        public Leitor(String caminho) {
            try (Arena ar = Arena.ofConfined()) {
                MemorySegment erro = ar.allocate(200);
                a = (MemorySegment) ABRIR.invokeExact(ar.allocateFrom(caminho), erro, 200L);
                if (a.address() == 0) throw new RuntimeException(str(erro));
                linhas = (long) LINHAS.invokeExact(a); esquema = str((MemorySegment) ESQUEMA.invokeExact(a));
                int n = (int) CAMPOS.invokeExact(a); for (int i = 0; i < n; i++) campos.add(str((MemorySegment) CAMPO_NOME.invokeExact(a, i)));
            } catch (RuntimeException e) { throw e; } catch (Throwable t) { throw new RuntimeException(t); }
        }
        public String json(long i) { return lerTexto((b, cap) -> (long) LINHA_JSON.invokeExact(a, i, b, cap)); }
        public String texto(long i) { return lerTexto((b, cap) -> (long) LINHA_TEXTO.invokeExact(a, i, b, cap)); }
        public String campo(long i, int k) { return lerTexto((b, cap) -> (long) CAMPO_JSON.invokeExact(a, i, k, b, cap)); }
        public void conferir() { try (Arena ar = Arena.ofConfined()) { MemorySegment erro = ar.allocate(200); if ((int) CONFERIR.invokeExact(a, erro, 200L) != 0) throw new RuntimeException(str(erro)); } catch (RuntimeException e) { throw e; } catch (Throwable t) { throw new RuntimeException(t); } }
        public Leitor visao(String escopos) {   /* trava o que a sessao ve ("pessoal vendas tenant:42"): esquema e campos so os visiveis; linha de outro tenant = LinhaOculta */
            try (Arena ar = Arena.ofConfined()) { MemorySegment erro = ar.allocate(300); if ((int) VISAO.invokeExact(a, ar.allocateFrom(escopos), erro, 300L) != 0) throw new RuntimeException(str(erro)); esquema = str((MemorySegment) ESQUEMA.invokeExact(a)); campos.clear(); int n = (int) CAMPOS.invokeExact(a); for (int i = 0; i < n; i++) campos.add(str((MemorySegment) CAMPO_NOME.invokeExact(a, i))); } catch (RuntimeException e) { throw e; } catch (Throwable t) { throw new RuntimeException(t); }
            return this;
        }
        public void close() { try { if (a != null) { FECHAR.invokeExact(a); a = null; } } catch (Throwable t) { throw new RuntimeException(t); } }
    }

    public static final class Escritor implements AutoCloseable {
        MemorySegment w;
        public Escritor(String caminho, String esquema) { this(caminho, esquema, 1, 0, 0); }
        public Escritor(String caminho, String esquema, int compressao, int hash, int blocoKb) {
            try (Arena ar = Arena.ofConfined()) {
                MemorySegment erro = ar.allocate(200);
                w = (MemorySegment) CRIAR.invokeExact(ar.allocateFrom(caminho), ar.allocateFrom(esquema), erro, 200L);
                if (w.address() == 0) throw new RuntimeException(str(erro));
                int r = (int) OPCOES.invokeExact(w, compressao, hash, blocoKb);
            } catch (RuntimeException e) { throw e; } catch (Throwable t) { throw new RuntimeException(t); }
        }
        public void gravar(String json) {
            try (Arena ar = Arena.ofConfined()) {
                byte[] b = json.getBytes(java.nio.charset.StandardCharsets.UTF_8); MemorySegment s = ar.allocate(b.length + 1); s.copyFrom(MemorySegment.ofArray(b)); MemorySegment erro = ar.allocate(200);
                if ((int) GRAVAR.invokeExact(w, s, (long) b.length, erro, 200L) != 0) throw new RuntimeException(str(erro));
            } catch (RuntimeException e) { throw e; } catch (Throwable t) { throw new RuntimeException(t); }
        }
        public void descarregar() { try { int r = (int) DESCARREGAR.invokeExact(w); } catch (Throwable t) { throw new RuntimeException(t); } }
        /** Desiste: fecha sem publicar; o destino fica como estava. Chame no catch de quem grava: o close() do try-with-resources publica. */
        public void abandonar() { try { if (w != null) { int r = (int) ABANDONAR.invokeExact(w); w = null; } } catch (Throwable t) { throw new RuntimeException(t); } }
        public void close() { try { if (w != null) { int r = (int) FECHAR_W.invokeExact(w); w = null; if (r != 0) throw new RuntimeException("nao gravou tudo"); } } catch (RuntimeException e) { throw e; } catch (Throwable t) { throw new RuntimeException(t); } }
    }

    public static void main(String[] args) {   /* java Jsonw.java arquivo.jsw -> JSONL; --avaliar arq pedido k; --reconhecer termos.jsw texto (JsonwOps.java) */
        if (args.length == 4 && args[0].equals("--avaliar")) { try (Leitor a = new Leitor(args[1])) { System.out.println(JsonwOps.avaliar(a, args[2], Long.parseLong(args[3]))); } return; }
        if (args.length == 5 && args[0].equals("--visao")) { try (Leitor a = new Leitor(args[1]).visao(args[2])) { System.out.println(String.join(",", a.campos)); for (long i = 0; i < a.linhas; i++) { try { System.out.println(a.json(i)); } catch (LinhaOculta o) { } } System.out.println(JsonwOps.avaliar(a, args[3], Long.parseLong(args[4]))); } return; }
        if (args.length == 3 && args[0].equals("--reconhecer")) { try (JsonwOps.Reconhecedor r = new JsonwOps.Reconhecedor(args[1])) { System.out.println(r.reconhecer(args[2])); } return; }
        try (Leitor a = new Leitor(args[0])) { for (long i = 0; i < a.linhas; i++) System.out.println(a.json(i)); }
    }
}
