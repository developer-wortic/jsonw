/* Jsonw.kt: jsonW (json Wondrous) para Kotlin/JVM 22+ (FFM, sem JNI nem dependencia), por cima da ABI C (libjsonw).
 *   Jsonw.Leitor("dados.jsw").use { a -> for (i in 0 until a.linhas) println(a.json(i)) }
 *   Jsonw.Escritor("novo.jsw", "id:i64,nome:texto").use { w -> w.gravar("""{"id":1,"nome":"x"}""") }
 * Compilar: kotlinc Jsonw.kt -include-runtime -d jsonw.jar; rodar: java --enable-native-access=ALL-UNNAMED -jar jsonw.jar arquivo.jsw */
import java.lang.foreign.*
import java.lang.invoke.MethodHandle
import java.nio.file.Files
import java.nio.file.Path

object Jsonw {
    internal val L: Linker = Linker.nativeLinker()
    internal val LIB: SymbolLookup = carregar()
    private fun carregar(): SymbolLookup {   /* a biblioteca: JSONW_LIB (caminho inteiro), a pasta atual, as de cima ou bin/<plataforma> do pacote */
        val so = System.getProperty("os.name").lowercase(); val maq = System.getProperty("os.arch").lowercase()
        val win = so.contains("win"); val mac = so.contains("mac")
        val plat = (if (win) "windows" else if (mac) "macos" else "linux") + "-" + (if (maq == "aarch64") "arm64" else if (maq == "amd64") "x86_64" else maq)
        val nomes = if (win) listOf("libjsonw.dll") else listOf("libjsonw.dylib", "libjsonw.so")
        val dito = System.getenv("JSONW_LIB")
        if (!dito.isNullOrEmpty()) return SymbolLookup.libraryLookup(Path.of(dito).toAbsolutePath(), Arena.global())
        for (base in listOf(".", "..", "../..", "bin/$plat", "../bin/$plat", "../../bin/$plat")) for (n in nomes) {
            val p = Path.of(base, n); if (Files.exists(p)) return SymbolLookup.libraryLookup(p.toAbsolutePath(), Arena.global())
        }
        throw RuntimeException("libjsonw nao encontrada para $plat: aponte JSONW_LIB para a biblioteca (bin/<plataforma>/ do pacote) ou rode da pasta sdk com ela ao lado")
    }
    internal fun fn(nome: String, d: FunctionDescriptor): MethodHandle = L.downcallHandle(LIB.find(nome).orElseThrow(), d)
    internal val P = ValueLayout.ADDRESS; internal val I32 = ValueLayout.JAVA_INT; internal val U64 = ValueLayout.JAVA_LONG; internal val SZ = ValueLayout.JAVA_LONG
    private val ABRIR = fn("jsonw_abrir", FunctionDescriptor.of(P, P, P, SZ)); private val FECHAR = fn("jsonw_fechar", FunctionDescriptor.ofVoid(P))
    private val LINHAS = fn("jsonw_linhas", FunctionDescriptor.of(U64, P)); private val CAMPOS = fn("jsonw_campos", FunctionDescriptor.of(I32, P))
    private val ESQUEMA = fn("jsonw_esquema", FunctionDescriptor.of(P, P)); private val CAMPO_NOME = fn("jsonw_campo_nome", FunctionDescriptor.of(P, P, I32))
    private val LINHA_JSON = fn("jsonw_linha_json", FunctionDescriptor.of(SZ, P, U64, P, SZ)); private val LINHA_TEXTO = fn("jsonw_linha_texto", FunctionDescriptor.of(SZ, P, U64, P, SZ))
    private val CAMPO_JSON = fn("jsonw_campo_json", FunctionDescriptor.of(SZ, P, U64, I32, P, SZ)); private val CONFERIR = fn("jsonw_conferir", FunctionDescriptor.of(I32, P, P, SZ))
    private val CRIAR = fn("jsonw_criar", FunctionDescriptor.of(P, P, P, P, SZ)); private val OPCOES = fn("jsonw_opcoes", FunctionDescriptor.of(I32, P, I32, I32, I32))
    private val GRAVAR = fn("jsonw_gravar_json", FunctionDescriptor.of(I32, P, P, SZ, P, SZ)); private val DESCARREGAR = fn("jsonw_descarregar", FunctionDescriptor.of(I32, P))
    private val FECHAR_W = fn("jsonw_fechar_escritor", FunctionDescriptor.of(I32, P)); private val ABANDONAR = fn("jsonw_abandonar", FunctionDescriptor.of(I32, P)); private val VERSAO = fn("jsonw_versao", FunctionDescriptor.of(P)); private val VISAO = fn("jsonw_visao", FunctionDescriptor.of(I32, P, P, P, SZ))
    class LinhaOculta : RuntimeException("linha oculta pela visao")   /* linha de outro tenant depois de visao() (-3 na ABI) */

    internal fun str(p: MemorySegment): String = p.reinterpret(Long.MAX_VALUE).getString(0)
    fun versao(): String = str(VERSAO.invokeExact() as MemorySegment)
    internal fun lerTexto(c: (MemorySegment, Long) -> Long): String {
        var cap = 1L shl 16
        Arena.ofConfined().use { ar ->
            while (true) {
                val b = ar.allocate(cap); val n = c(b, cap)
                if (n == -2L) { cap *= 4; continue }
                if (n == -3L) throw LinhaOculta()
                if (n < 0) throw RuntimeException("linha ou campo ilegivel")
                return String(b.asSlice(0, n).toArray(ValueLayout.JAVA_BYTE), Charsets.UTF_8)
            }
        }
    }

    class Leitor(caminho: String) : AutoCloseable {
        internal var a: MemorySegment? = null
        val linhas: Long
        var esquema: String private set
        var campos: List<String> private set
        init {
            Arena.ofConfined().use { ar ->
                val erro = ar.allocate(200)
                val p = ABRIR.invokeExact(ar.allocateFrom(caminho), erro, 200L) as MemorySegment
                if (p.address() == 0L) throw RuntimeException(str(erro))
                a = p; linhas = LINHAS.invokeExact(p) as Long; esquema = str(ESQUEMA.invokeExact(p) as MemorySegment)
                campos = (0 until (CAMPOS.invokeExact(p) as Int)).map { str(CAMPO_NOME.invokeExact(p, it) as MemorySegment) }
            }
        }
        fun json(i: Long): String = lerTexto { b, cap -> LINHA_JSON.invokeExact(a, i, b, cap) as Long }
        fun texto(i: Long): String = lerTexto { b, cap -> LINHA_TEXTO.invokeExact(a, i, b, cap) as Long }
        fun campo(i: Long, k: Int): String = lerTexto { b, cap -> CAMPO_JSON.invokeExact(a, i, k, b, cap) as Long }
        fun conferir() { Arena.ofConfined().use { ar -> val erro = ar.allocate(200); if ((CONFERIR.invokeExact(a, erro, 200L) as Int) != 0) throw RuntimeException(str(erro)) } }
        fun visao(escopos: String): Leitor {   /* trava o que a sessao ve ("pessoal vendas tenant:42"): esquema e campos so os visiveis; linha de outro tenant = LinhaOculta */
            Arena.ofConfined().use { ar -> val erro = ar.allocate(300); if ((VISAO.invokeExact(a, ar.allocateFrom(escopos), erro, 300L) as Int) != 0) throw RuntimeException(str(erro)) }
            esquema = str(ESQUEMA.invokeExact(a) as MemorySegment); campos = (0 until (CAMPOS.invokeExact(a) as Int)).map { str(CAMPO_NOME.invokeExact(a, it) as MemorySegment) }; return this
        }
        override fun close() { a?.let { FECHAR.invokeExact(it); a = null } }
    }
    class Escritor(caminho: String, esquema: String, compressao: Int = 1, hash: Int = 0, blocoKb: Int = 0) : AutoCloseable {
        private var w: MemorySegment? = null
        init {
            Arena.ofConfined().use { ar ->
                val erro = ar.allocate(200)
                val p = CRIAR.invokeExact(ar.allocateFrom(caminho), ar.allocateFrom(esquema), erro, 200L) as MemorySegment
                if (p.address() == 0L) throw RuntimeException(str(erro))
                w = p; OPCOES.invokeExact(p, compressao, hash, blocoKb) as Int
            }
        }
        fun gravar(json: String) {
            Arena.ofConfined().use { ar ->
                val b = json.toByteArray(Charsets.UTF_8); val s = ar.allocate(b.size + 1L); s.copyFrom(MemorySegment.ofArray(b)); val erro = ar.allocate(200)
                if ((GRAVAR.invokeExact(w, s, b.size.toLong(), erro, 200L) as Int) != 0) throw RuntimeException(str(erro))
            }
        }
        fun descarregar() { DESCARREGAR.invokeExact(w) as Int }
        /** desiste: fecha sem publicar; o destino fica como estava. Chame no catch de quem grava: o close() do use { } publica */
        fun abandonar() { w?.let { ABANDONAR.invokeExact(it) as Int; w = null } }
        override fun close() { w?.let { val r = FECHAR_W.invokeExact(it) as Int; w = null; if (r != 0) throw RuntimeException("nao gravou tudo") } }
    }
}

fun main(args: Array<String>) {   /* arquivo.jsw -> JSONL; --gravar esquema entrada.jsonl saida.jsw; --avaliar arq pedido k; --reconhecer termos.jsw texto */
    if (args.size == 4 && args[0] == "--avaliar") { Jsonw.Leitor(args[1]).use { a -> println(a.avaliar(args[2], args[3].toLong())) }; return }
    if (args.size == 5 && args[0] == "--visao") { Jsonw.Leitor(args[1]).use { a -> a.visao(args[2]); println(a.campos.joinToString(",")); for (i in 0 until a.linhas) { try { println(a.json(i)) } catch (o: Jsonw.LinhaOculta) { } }; println(a.avaliar(args[3], args[4].toLong())) }; return }
    if (args.size == 3 && args[0] == "--reconhecer") { JsonwOps.Reconhecedor(args[1]).use { r -> println(r.reconhecer(args[2])) }; return }
    if (args.size == 4 && args[0] == "--gravar") {
        Jsonw.Escritor(args[3], args[1]).use { w -> Files.readAllLines(Path.of(args[2])).filter { it.isNotBlank() }.forEach { w.gravar(it) } }
        return
    }
    Jsonw.Leitor(args[0]).use { a -> val sb = StringBuilder(); for (i in 0 until a.linhas) sb.append(a.json(i)).append('\n'); System.out.write(sb.toString().toByteArray(Charsets.UTF_8)); System.out.flush() }
}
