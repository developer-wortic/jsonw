// ler arquivo.jsw -> JSONL; ler --gravar esquema entrada.jsonl saida.jsw; ler --avaliar arq pedido k; ler --reconhecer termos.jsw texto (prova do SDK Swift)
import Foundation

let args = CommandLine.arguments
do {
    if args.count == 5 && args[1] == "--gravar" {
        let w = try Escritor(args[4], esquema: args[2])
        for l in try String(contentsOfFile: args[3], encoding: .utf8).split(separator: "\n") where !l.trimmingCharacters(in: .whitespaces).isEmpty { try w.gravar(String(l)) }
        try w.fechar()
    } else if args.count == 5 && args[1] == "--avaliar" {
        let a = try Leitor(args[2])
        print(try a.avaliar(args[3], k: Int(args[4]) ?? 10))
    } else if args.count == 6 && args[1] == "--visao" {   // --visao arq escopos pedido k: campos, as linhas visiveis (JSONL) e o avaliar
        let a = try Leitor(args[2]); try a.visao(args[3]); print(a.campos.joined(separator: ","))
        for i in 0..<a.linhas { do { print(try a.json(i)) } catch is LinhaOculta {} }
        print(try a.avaliar(args[4], k: Int(args[5]) ?? 10))
    } else if args.count == 4 && args[1] == "--reconhecer" {
        let r = try Reconhecedor(args[2])
        print(try r.reconhecer(args[3]))
    } else {
        let a = try Leitor(args[1])
        var saida = ""
        for i in 0..<a.linhas { saida += try a.json(i); saida += "\n" }
        FileHandle.standardOutput.write(saida.data(using: .utf8)!)
    }
} catch { FileHandle.standardError.write("\(error)\n".data(using: .utf8)!); exit(1) }
