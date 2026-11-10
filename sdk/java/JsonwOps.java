/* JsonwOps.java: as operacoes da ABI 1.1 para Java 22+ (FFM): AVALIAR + ESCOLHER (pedido em JSON -> as k melhores),
 * ESCOLHER das suas notas e RECONHECER (tabela de termos -> Reconhecedor). Fica ao lado de Jsonw.java (mesmo pacote; o
 * `java Jsonw.java` compila os dois). Pedido e resposta em JSON (String). */
import java.lang.foreign.*;
import java.lang.invoke.MethodHandle;
import java.nio.charset.StandardCharsets;

public final class JsonwOps {
    static final MethodHandle AVALIAR = Jsonw.fn("jsonw_avaliar", FunctionDescriptor.of(Jsonw.SZ, Jsonw.P, Jsonw.P, Jsonw.SZ, Jsonw.SZ, Jsonw.P, Jsonw.SZ, Jsonw.P, Jsonw.SZ)),
        ESCOLHER = Jsonw.fn("jsonw_escolher", FunctionDescriptor.of(Jsonw.SZ, Jsonw.P, Jsonw.SZ, Jsonw.SZ, Jsonw.P)),
        RECONHECEDOR = Jsonw.fn("jsonw_reconhecedor", FunctionDescriptor.of(Jsonw.P, Jsonw.P, Jsonw.P, Jsonw.SZ)),
        RECONHECEDOR_FECHAR = Jsonw.fn("jsonw_reconhecedor_fechar", FunctionDescriptor.ofVoid(Jsonw.P)),
        RECONHECER = Jsonw.fn("jsonw_reconhecer", FunctionDescriptor.of(Jsonw.SZ, Jsonw.P, Jsonw.P, Jsonw.SZ, Jsonw.P, Jsonw.SZ));

    static MemorySegment bytes(Arena ar, String s, long[] n) { byte[] b = s.getBytes(StandardCharsets.UTF_8); MemorySegment m = ar.allocate(b.length + 1); m.copyFrom(MemorySegment.ofArray(b)); n[0] = b.length; return m; }

    /** AVALIAR + ESCOLHER: pedido {"pesos":{..}} | {"cosseno":{..}} | {"esparso":{..}} | {"grade":{..}}; devolve [{"linha","nota"}] das k melhores. */
    public static String avaliar(Jsonw.Leitor a, String pedido, long k) {
        try (Arena ar = Arena.ofConfined()) {
            long[] n = new long[1]; MemorySegment p = bytes(ar, pedido, n), erro = ar.allocate(300);
            return Jsonw.lerTexto((s, cap) -> { long r = (long) AVALIAR.invokeExact(a.a, p, n[0], k, s, cap, erro, 300L); if (r == -1) throw new RuntimeException(Jsonw.str(erro)); return r; });
        }
    }
    /** Posicoes das k maiores notas (maior primeiro; empate pela menor posicao; NaN e a pior). */
    public static long[] escolher(double[] notas, long k) {
        try (Arena ar = Arena.ofConfined()) {
            MemorySegment v = ar.allocateFrom(ValueLayout.JAVA_DOUBLE, notas), out = ar.allocate(ValueLayout.JAVA_LONG, Math.max(k, 1));
            long m = (long) ESCOLHER.invokeExact(v, (long) notas.length, k, out);
            return out.asSlice(0, Math.max(m, 0) * 8).toArray(ValueLayout.JAVA_LONG);
        } catch (RuntimeException e) { throw e; } catch (Throwable t) { throw new RuntimeException(t); }
    }

    /** Tabela de termos (termo:texto,forma:dic,sinal:dic,peso:f32,idioma:dic,origem:dic) -> reconhecedor. */
    public static final class Reconhecedor implements AutoCloseable {
        MemorySegment r;
        public Reconhecedor(String termosJsw) {
            try (Arena ar = Arena.ofConfined()) {
                MemorySegment erro = ar.allocate(300); r = (MemorySegment) RECONHECEDOR.invokeExact(ar.allocateFrom(termosJsw), erro, 300L);
                if (r.address() == 0) throw new RuntimeException(Jsonw.str(erro));
            } catch (RuntimeException e) { throw e; } catch (Throwable t) { throw new RuntimeException(t); }
        }
        /** {"termos":[{termo,ini,fim,texto,sinal,peso}],"sinais":[{sinal,soma,vezes}]} */
        public String reconhecer(String texto) {
            try (Arena ar = Arena.ofConfined()) { long[] n = new long[1]; MemorySegment t = bytes(ar, texto, n); return Jsonw.lerTexto((s, cap) -> (long) RECONHECER.invokeExact(r, t, n[0], s, cap)); }
        }
        public void close() { try { if (r != null) { RECONHECEDOR_FECHAR.invokeExact(r); r = null; } } catch (Throwable t) { throw new RuntimeException(t); } }
    }
}
