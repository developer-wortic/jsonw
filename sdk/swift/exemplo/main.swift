// exemplo: abre um .jsw e mostra as linhas em que <campo> vale <valor> (JSON), pelo indice (ou varrendo, com --varrer).
// swiftc -I .. ../jsonw.swift ../jsonw_ops.swift main.swift ../../libjsonw.a -o exemplo && ./exemplo dados.jsw id 2
import Foundation

let args = CommandLine.arguments
guard args.count >= 4 else { FileHandle.standardError.write("uso: exemplo arquivo.jsw campo valor [--varrer]\n".data(using: .utf8)!); exit(2) }
do {
    let a = try Leitor(args[1])
    guard let k = a.campos.firstIndex(of: args[2]) else { FileHandle.standardError.write("campo \(args[2]) não existe\n".data(using: .utf8)!); exit(1) }
    if args.count < 5 || args[4] != "--varrer" { try a.indexar(k) }
    for i in try a.chave(k, args[3]) { print(try a.json(i)) }
} catch {
    FileHandle.standardError.write("\(error)\n".data(using: .utf8)!); exit(1)
}
