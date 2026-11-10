/* JsonwOps.kt: as operacoes da ABI 1.1 para Kotlin/JVM 22+ (FFM): avaliar (extensao de Jsonw.Leitor), escolher e
 * Reconhecedor. Compila junto com Jsonw.kt: kotlinc Jsonw.kt JsonwOps.kt -include-runtime -d jsonw.jar */
import java.lang.foreign.*
import java.lang.invoke.MethodHandle

object JsonwOps {
    private val AVALIAR: MethodHandle = Jsonw.fn("jsonw_avaliar", FunctionDescriptor.of(Jsonw.SZ, Jsonw.P, Jsonw.P, Jsonw.SZ, Jsonw.SZ, Jsonw.P, Jsonw.SZ, Jsonw.P, Jsonw.SZ))
    private val ESCOLHER = Jsonw.fn("jsonw_escolher", FunctionDescriptor.of(Jsonw.SZ, Jsonw.P, Jsonw.SZ, Jsonw.SZ, Jsonw.P))
    private val RECONHECEDOR = Jsonw.fn("jsonw_reconhecedor", FunctionDescriptor.of(Jsonw.P, Jsonw.P, Jsonw.P, Jsonw.SZ))
    private val RECONHECEDOR_FECHAR = Jsonw.fn("jsonw_reconhecedor_fechar", FunctionDescriptor.ofVoid(Jsonw.P))
    private val RECONHECER = Jsonw.fn("jsonw_reconhecer", FunctionDescriptor.of(Jsonw.SZ, Jsonw.P, Jsonw.P, Jsonw.SZ, Jsonw.P, Jsonw.SZ))

    private fun bytes(ar: Arena, s: String): Pair<MemorySegment, Long> { val b = s.toByteArray(Charsets.UTF_8); val m = ar.allocate(b.size + 1L); m.copyFrom(MemorySegment.ofArray(b)); return Pair(m, b.size.toLong()) }

    /** AVALIAR + ESCOLHER: pedido em JSON ({"pesos":{..}}, {"cosseno":{..}}, ...); devolve [{"linha","nota"}] das k melhores */
    fun avaliar(a: Jsonw.Leitor, pedido: String, k: Long): String = Arena.ofConfined().use { ar ->
        val (p, n) = bytes(ar, pedido); val erro = ar.allocate(300)
        Jsonw.lerTexto { s, cap -> val r = AVALIAR.invokeExact(a.a, p, n, k, s, cap, erro, 300L) as Long; if (r == -1L) throw RuntimeException(Jsonw.str(erro)); r }
    }
    /** posicoes das k maiores notas (maior primeiro; empate pela menor posicao; NaN e a pior) */
    fun escolher(notas: DoubleArray, k: Long): LongArray = Arena.ofConfined().use { ar ->
        val v = ar.allocateFrom(ValueLayout.JAVA_DOUBLE, *notas); val out = ar.allocate(ValueLayout.JAVA_LONG, maxOf(k, 1L))
        val m = ESCOLHER.invokeExact(v, notas.size.toLong(), k, out) as Long
        out.asSlice(0, maxOf(m, 0L) * 8).toArray(ValueLayout.JAVA_LONG)
    }

    /** tabela de termos (termo:texto,forma:dic,sinal:dic,peso:f32,idioma:dic,origem:dic) -> reconhecedor */
    class Reconhecedor(termosJsw: String) : AutoCloseable {
        private var r: MemorySegment? = null
        init {
            Arena.ofConfined().use { ar ->
                val erro = ar.allocate(300); val p = RECONHECEDOR.invokeExact(ar.allocateFrom(termosJsw), erro, 300L) as MemorySegment
                if (p.address() == 0L) throw RuntimeException(Jsonw.str(erro)); r = p
            }
        }
        /** {"termos":[{termo,ini,fim,texto,sinal,peso}],"sinais":[{sinal,soma,vezes}]} */
        fun reconhecer(texto: String): String = Arena.ofConfined().use { ar -> val (t, n) = bytes(ar, texto); Jsonw.lerTexto { s, cap -> RECONHECER.invokeExact(r, t, n, s, cap) as Long } }
        override fun close() { r?.let { RECONHECEDOR_FECHAR.invokeExact(it); r = null } }
    }
}
fun Jsonw.Leitor.avaliar(pedido: String, k: Long = 10): String = JsonwOps.avaliar(this, pedido, k)
