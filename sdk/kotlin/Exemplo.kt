// java -cp e.jar ExemploKt dados.jsw id 2: as linhas em que o campo vale o valor (JSON), pelo índice; --varrer para sem índice.
// kotlinc Jsonw.kt JsonwOps.kt Exemplo.kt -include-runtime -d e.jar
import kotlin.system.exitProcess

fun main(args: Array<String>) {
    if (args.size < 3) {
        System.err.println("uso: exemplo arquivo.jsw campo valor [--varrer]")
        exitProcess(2)
    }
    val (arquivo, campo, valor) = args
    val saida = System.out.bufferedWriter(Charsets.UTF_8)
    Jsonw.Leitor(arquivo).use { a ->
        val k = a.indice(campo)
        if (args.getOrNull(3) != "--varrer") a.indexar(k)
        a.chave(k, valor).forEach { saida.appendLine(a.json(it)) }
    }
    saida.flush()
}
