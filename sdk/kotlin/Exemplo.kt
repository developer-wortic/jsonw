// Exemplo.kt: abre um .jsw e mostra as linhas em que <campo> vale <valor> (JSON), pelo indice (ou varrendo, com --varrer).
// kotlinc Jsonw.kt JsonwOps.kt Exemplo.kt -include-runtime -d e.jar; java -cp e.jar ExemploKt dados.jsw id 2
import kotlin.system.exitProcess

fun main(args: Array<String>) {
    if (args.size < 3) { System.err.println("uso: exemplo arquivo.jsw campo valor [--varrer]"); exitProcess(2) }
    Jsonw.Leitor(args[0]).use { a ->
        val k = a.campos.indexOf(args[1])
        if (k < 0) { System.err.println("campo ${args[1]} não existe"); exitProcess(1) }
        if (args.getOrNull(3) != "--varrer") a.indexar(k)
        val sb = StringBuilder()
        for (i in a.chave(k, args[2])) sb.append(a.json(i)).append('\n')
        System.out.write(sb.toString().toByteArray(Charsets.UTF_8)); System.out.flush()
    }
}
