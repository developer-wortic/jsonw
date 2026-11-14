/* Jsonw.kt: jsonW para Kotlin/JVM 22+ pela FFM (sem JNI e sem dependência), por cima da ABI C (libjsonw).
 *   Jsonw.Leitor("dados.jsw").use { a -> for (i in 0 until a.linhas) println(a.json(i)) }
 *   Jsonw.Escritor("novo.jsw", "id:i64,nome:texto").use { it.gravar("""{"id":1,"nome":"x"}""") }
 * Compilar: kotlinc Jsonw.kt JsonwOps.kt -include-runtime -d jsonw.jar
 * Rodar:    java --enable-native-access=ALL-UNNAMED -jar jsonw.jar arquivo.jsw */
import java.lang.foreign.Arena
import java.lang.foreign.FunctionDescriptor
import java.lang.foreign.Linker
import java.lang.foreign.MemorySegment
import java.lang.foreign.SymbolLookup
import java.lang.foreign.ValueLayout
import java.lang.invoke.MethodHandle
import java.nio.file.Files
import java.nio.file.Path

object Jsonw {
    internal val P = ValueLayout.ADDRESS
    internal val SZ = ValueLayout.JAVA_LONG
    private val I32 = ValueLayout.JAVA_INT
    private const val ERRO = 320L

    private val linker = Linker.nativeLinker()
    private val lib = carregar()

    /** A biblioteca: JSONW_LIB, a pasta atual, as de cima ou bin/<plataforma> do pacote. */
    private fun carregar(): SymbolLookup {
        val so = System.getProperty("os.name").lowercase()
        val maq = when (val m = System.getProperty("os.arch").lowercase()) {
            "aarch64" -> "arm64"
            "amd64" -> "x86_64"
            else -> m
        }
        val win = "win" in so
        val plat = "${if (win) "windows" else if ("mac" in so) "macos" else "linux"}-$maq"
        System.getenv("JSONW_LIB")?.takeIf { it.isNotEmpty() }?.let {
            return SymbolLookup.libraryLookup(Path.of(it).toAbsolutePath(), Arena.global())
        }
        val nomes = if (win) listOf("libjsonw.dll") else listOf("libjsonw.dylib", "libjsonw.so")
        val achada = listOf(".", "..", "../..", "bin/$plat", "../bin/$plat", "../../bin/$plat")
            .flatMap { base -> nomes.map { Path.of(base, it) } }
            .firstOrNull(Files::exists)
            ?: error("libjsonw nao encontrada para $plat: aponte JSONW_LIB para a biblioteca")
        return SymbolLookup.libraryLookup(achada.toAbsolutePath(), Arena.global())
    }

    internal fun fn(nome: String, d: FunctionDescriptor): MethodHandle =
        linker.downcallHandle(lib.find(nome).orElseThrow { IllegalStateException("libjsonw sem $nome") }, d)

    private val VERSAO = fn("jsonw_versao", FunctionDescriptor.of(P))
    private val ABRIR = fn("jsonw_abrir", FunctionDescriptor.of(P, P, P, SZ))
    private val FECHAR = fn("jsonw_fechar", FunctionDescriptor.ofVoid(P))
    private val LINHAS = fn("jsonw_linhas", FunctionDescriptor.of(SZ, P))
    private val CAMPOS = fn("jsonw_campos", FunctionDescriptor.of(I32, P))
    private val ESQUEMA = fn("jsonw_esquema", FunctionDescriptor.of(P, P))
    private val CAMPO_NOME = fn("jsonw_campo_nome", FunctionDescriptor.of(P, P, I32))
    private val LINHA_JSON = fn("jsonw_linha_json", FunctionDescriptor.of(SZ, P, SZ, P, SZ))
    private val LINHA_TEXTO = fn("jsonw_linha_texto", FunctionDescriptor.of(SZ, P, SZ, P, SZ))
    private val CAMPO_JSON = fn("jsonw_campo_json", FunctionDescriptor.of(SZ, P, SZ, I32, P, SZ))
    private val CONFERIR = fn("jsonw_conferir", FunctionDescriptor.of(I32, P, P, SZ))
    private val VISAO = fn("jsonw_visao", FunctionDescriptor.of(I32, P, P, P, SZ))
    private val INDEXAR = fn("jsonw_indexar", FunctionDescriptor.of(I32, P, I32))
    private val TEM_INDICE = fn("jsonw_tem_indice", FunctionDescriptor.of(I32, P, I32))
    private val CHAVE = fn("jsonw_chave", FunctionDescriptor.of(SZ, P, I32, P, SZ, P, SZ))
    private val CRIAR = fn("jsonw_criar", FunctionDescriptor.of(P, P, P, P, SZ))
    private val OPCOES = fn("jsonw_opcoes", FunctionDescriptor.of(I32, P, I32, I32, I32))
    private val GRAVAR = fn("jsonw_gravar_json", FunctionDescriptor.of(I32, P, P, SZ, P, SZ))
    private val DESCARREGAR = fn("jsonw_descarregar", FunctionDescriptor.of(I32, P))
    private val FECHAR_W = fn("jsonw_fechar_escritor", FunctionDescriptor.of(I32, P))
    private val ABANDONAR = fn("jsonw_abandonar", FunctionDescriptor.of(I32, P))

    /** Linha de outro tenant depois de visao() (-3 na ABI). */
    class LinhaOculta : RuntimeException("linha oculta pela visao")

    /** Erro devolvido pela biblioteca. */
    class Erro(msg: String) : RuntimeException(msg)

    internal fun str(p: MemorySegment): String =
        if (p.address() == 0L) "" else p.reinterpret(Long.MAX_VALUE).getString(0)

    private fun MemorySegment.tamanhoC(): Long = byteSize() - 1

    /** Buffer que cresce até caber (-2 = curto). */
    internal fun lerTexto(chamada: (MemorySegment, Long) -> Long): String = Arena.ofConfined().use { ar ->
        generateSequence(1L shl 16) { it * 4 }.firstNotNullOf { cap ->
            val b = ar.allocate(cap)
            when (val n = chamada(b, cap)) {
                -2L -> null
                -3L -> throw LinhaOculta()
                in Long.MIN_VALUE..-1L -> throw Erro("linha ou campo ilegivel")
                else -> b.asSlice(0, n).toArray(ValueLayout.JAVA_BYTE).toString(Charsets.UTF_8)
            }
        }
    }

    /** Chama com um buffer de erro; código diferente de 0 vira Erro com o texto da biblioteca. */
    private inline fun comErro(chamada: (Arena, MemorySegment) -> Int) = Arena.ofConfined().use { ar ->
        val erro = ar.allocate(ERRO)
        if (chamada(ar, erro) != 0) throw Erro(str(erro))
    }

    fun versao(): String = str(VERSAO.invokeExact() as MemorySegment)

    class Leitor(caminho: String) : AutoCloseable {
        internal var a: MemorySegment = Arena.ofConfined().use { ar ->
            val erro = ar.allocate(ERRO)
            val p = ABRIR.invokeExact(ar.allocateFrom(caminho), erro, ERRO) as MemorySegment
            if (p.address() == 0L) throw Erro(str(erro))
            p
        }
            private set
        val linhas: Long = LINHAS.invokeExact(a) as Long
        var esquema: String = ""
            private set
        var campos: List<String> = emptyList()
            private set

        init { lerEsquema() }

        private fun lerEsquema() {
            esquema = str(ESQUEMA.invokeExact(a) as MemorySegment)
            campos = List(CAMPOS.invokeExact(a) as Int) { str(CAMPO_NOME.invokeExact(a, it) as MemorySegment) }
        }

        fun json(i: Long): String = lerTexto { b, cap -> LINHA_JSON.invokeExact(a, i, b, cap) as Long }
        fun texto(i: Long): String = lerTexto { b, cap -> LINHA_TEXTO.invokeExact(a, i, b, cap) as Long }
        fun campo(i: Long, k: Int): String = lerTexto { b, cap -> CAMPO_JSON.invokeExact(a, i, k, b, cap) as Long }
        fun campo(i: Long, nome: String): String = campo(i, indice(nome))

        fun indice(nome: String): Int = campos.indexOf(nome).also { if (it < 0) throw Erro("campo inexistente: $nome") }

        fun conferir() = comErro { _, erro -> CONFERIR.invokeExact(a, erro, ERRO) as Int }

        /** Trava o que a sessão vê ("pessoal vendas tenant:42"); linha de outro tenant = LinhaOculta. */
        fun visao(escopos: String): Leitor = apply {
            comErro { ar, erro -> VISAO.invokeExact(a, ar.allocateFrom(escopos), erro, ERRO) as Int }
            lerEsquema()
        }

        fun indexar(k: Int) {
            if (INDEXAR.invokeExact(a, k) as Int != 0) throw Erro("campo sem indice")
        }

        fun temIndice(k: Int): Boolean = TEM_INDICE.invokeExact(a, k) as Int == 1

        /** As linhas em que o campo k vale `valor` (o JSON do valor: "7", "\"RJ\""), em ordem crescente. */
        fun chave(k: Int, valor: String): LongArray = Arena.ofConfined().use { ar ->
            val v = ar.allocateFrom(valor)
            var cap = 16L
            while (true) {
                val out = ar.allocate(ValueLayout.JAVA_LONG, cap)
                val n = CHAVE.invokeExact(a, k, v, v.tamanhoC(), out, cap) as Long
                when {
                    n == -2L -> throw Erro("valor nao e do tipo do campo")
                    n < 0 -> throw Erro("campo invalido")
                    n <= cap -> return@use out.asSlice(0, n * Long.SIZE_BYTES).toArray(ValueLayout.JAVA_LONG)
                }
                cap = n
            }
            @Suppress("UNREACHABLE_CODE") LongArray(0)
        }

        override fun close() {
            if (a.address() == 0L) return
            val h = a
            a = MemorySegment.NULL
            FECHAR.invokeExact(h)
        }
    }

    /** O destino só aparece no close(); abandonar() desiste e deixa o destino como estava. */
    class Escritor(
        caminho: String,
        esquema: String,
        compressao: Int = 1,
        hash: Int = 0,
        blocoKb: Int = 0,
    ) : AutoCloseable {
        private var w: MemorySegment = Arena.ofConfined().use { ar ->
            val erro = ar.allocate(ERRO)
            val p = CRIAR.invokeExact(ar.allocateFrom(caminho), ar.allocateFrom(esquema), erro, ERRO) as MemorySegment
            if (p.address() == 0L) throw Erro(str(erro))
            p
        }

        init { OPCOES.invokeExact(w, compressao, hash, blocoKb) as Int }

        fun gravar(json: String) = comErro { ar, erro ->
            val s = ar.allocateFrom(json)
            GRAVAR.invokeExact(w, s, s.tamanhoC(), erro, ERRO) as Int
        }

        fun descarregar() { DESCARREGAR.invokeExact(w) as Int }

        fun abandonar() {
            val h = tomar() ?: return
            ABANDONAR.invokeExact(h) as Int
        }

        override fun close() {
            val h = tomar() ?: return
            if (FECHAR_W.invokeExact(h) as Int != 0) throw Erro("nao gravou tudo")
        }

        private fun tomar(): MemorySegment? = w.takeIf { it.address() != 0L }?.also { w = MemorySegment.NULL }
    }
}

/** arq.jsw -> JSONL; --gravar esquema entrada.jsonl saida.jsw; --avaliar arq pedido k; --visao arq escopos pedido k; --reconhecer termos.jsw texto */
fun main(args: Array<String>) {
    val saida = System.out.bufferedWriter(Charsets.UTF_8)
    fun linha(s: String) = saida.appendLine(s)
    when {
        args.size == 4 && args[0] == "--avaliar" ->
            Jsonw.Leitor(args[1]).use { linha(it.avaliar(args[2], args[3].toLong())) }
        args.size == 5 && args[0] == "--visao" -> Jsonw.Leitor(args[1]).use { a ->
            a.visao(args[2])
            linha(a.campos.joinToString(","))
            for (i in 0 until a.linhas) runCatching { linha(a.json(i)) }.onFailure { if (it !is Jsonw.LinhaOculta) throw it }
            linha(a.avaliar(args[3], args[4].toLong()))
        }
        args.size == 3 && args[0] == "--reconhecer" ->
            JsonwOps.Reconhecedor(args[1]).use { linha(it.reconhecer(args[2])) }
        args.size == 4 && args[0] == "--gravar" -> Jsonw.Escritor(args[3], args[1]).use { w ->
            Files.readAllLines(Path.of(args[2])).filter(String::isNotBlank).forEach(w::gravar)
        }
        else -> Jsonw.Leitor(args[0]).use { a -> for (i in 0 until a.linhas) linha(a.json(i)) }
    }
    saida.flush()
}
