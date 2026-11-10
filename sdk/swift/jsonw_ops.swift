// jsonw_ops.swift: as operacoes da ABI 1.1 para Swift: avaliar (extensao de Leitor), escolher e Reconhecedor. Compila junto:
//   swiftc -I sdk/swift sdk/swift/jsonw.swift sdk/swift/jsonw_ops.swift sdk/swift/main.swift sdk/libjsonw.a -o ler
import CJsonw
import Foundation

public extension Leitor {
    /// AVALIAR + ESCOLHER: pedido em JSON ({"pesos":{..}}, {"cosseno":{..}}, {"esparso":{..}}, {"grade":{..}}); devolve [{"linha","nota"}] das k melhores
    func avaliar(_ pedido: String, k: Int = 10) throws -> String {
        var erro = [CChar](repeating: 0, count: 300); var cap = 1 << 16
        while true {
            var b = [CChar](repeating: 0, count: cap)
            let n = b.withUnsafeMutableBufferPointer { bp in pedido.utf8CString.withUnsafeBufferPointer { jsonw_avaliar(a, $0.baseAddress, pedido.utf8.count, k, bp.baseAddress!, cap, &erro, 300) } }
            if n == -2 { cap *= 4; continue }
            if n < 0 { throw erroDe(erro) }
            return String(decoding: b[0..<Int(n)].map { UInt8(bitPattern: $0) }, as: UTF8.self)
        }
    }
}

/// posicoes das k maiores notas (maior primeiro; empate pela menor posicao; NaN e a pior)
public func escolher(_ notas: [Double], k: Int) -> [UInt64] {
    var out = [UInt64](repeating: 0, count: max(k, 1))
    let m = notas.withUnsafeBufferPointer { jsonw_escolher($0.baseAddress, notas.count, k, &out) }
    return m > 0 ? Array(out[0..<Int(m)]) : []
}

/// tabela de termos (termo:texto,forma:dic,sinal:dic,peso:f32,idioma:dic,origem:dic) -> reconhecedor
public final class Reconhecedor {
    let r: UnsafeMutableRawPointer
    public init(_ termosJsw: String) throws {
        var erro = [CChar](repeating: 0, count: 300)
        guard let p = jsonw_reconhecedor(termosJsw, &erro, 300) else { throw erroDe(erro) }
        r = p
    }
    deinit { jsonw_reconhecedor_fechar(r) }
    /// {"termos":[{termo,ini,fim,texto,sinal,peso}],"sinais":[{sinal,soma,vezes}]}
    public func reconhecer(_ texto: String) throws -> String {
        try lerTexto { s, cap in texto.utf8CString.withUnsafeBufferPointer { jsonw_reconhecer(r, $0.baseAddress, texto.utf8.count, s, cap) } }
    }
}
