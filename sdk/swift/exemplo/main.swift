// ./exemplo dados.jsw id 2: as linhas em que o campo vale o valor (JSON), pelo índice; --varrer no fim para buscar sem índice.
// swiftc -I .. ../jsonw.swift ../jsonw_ops.swift main.swift ../../libjsonw.a -o exemplo
import Foundation

func sair(_ texto: String, _ codigo: Int32) -> Never {
    FileHandle.standardError.write(Data("\(texto)\n".utf8))
    exit(codigo)
}

let args = CommandLine.arguments
guard args.count >= 4 else { sair("uso: exemplo arquivo.jsw campo valor [--varrer]", 2) }

do {
    let a = try Leitor(args[1])
    let k = try a.indice(args[2])
    if args.count < 5 || args[4] != "--varrer" { try a.indexar(k) }
    for i in try a.chave(k, args[3]) { print(try a.json(i)) }
} catch {
    sair("\(error)", 1)
}
