// jsonw_ops.swift: avaliar (extensão de Leitor), escolher e Reconhecedor. Compila junto com jsonw.swift.
import CJsonw

public extension Leitor {
    /// As k melhores linhas pelo pedido em JSON ({"pesos":..}, {"cosseno":..}, {"esparso":..}, {"grade":..}): [{"linha","nota"}].
    func avaliar(_ pedido: String, k: Int = 10) throws(ErroJsonW) -> String {
        try withUnsafeTemporaryAllocation(of: CChar.self, capacity: tamanhoErro) { (erro) throws(ErroJsonW) in
            erro.initialize(repeating: 0)
            return try lerTexto { (b, cap) throws(ErroJsonW) in
                let n = pedido.withCString { jsonw_avaliar(a, $0, pedido.utf8.count, k, b, cap, erro.baseAddress!, tamanhoErro) }
                if n == -1 { throw .biblioteca(String(cString: erro.baseAddress!)) }
                return n
            }
        }
    }
}

/// As posições das k maiores notas (maior primeiro; empate pela menor posição; NaN é a pior).
public func escolher(_ notas: [Double], k: Int) -> [UInt64] {
    var out = [UInt64](repeating: 0, count: max(k, 1))
    let m = notas.withUnsafeBufferPointer { jsonw_escolher($0.baseAddress, notas.count, k, &out) }
    return Array(out.prefix(Int(max(m, 0))))
}

/// Tabela de termos (termo:texto,forma:dic,sinal:dic,peso:f32,idioma:dic,origem:dic) -> termos e sinais achados no texto.
public final class Reconhecedor {
    private let r: UnsafeMutableRawPointer

    public init(_ termosJsw: String) throws(ErroJsonW) {
        let (p, erro) = comErro { jsonw_reconhecedor(termosJsw, $0, $1) }
        guard let p else { throw .biblioteca(erro) }
        r = p
    }

    deinit { jsonw_reconhecedor_fechar(r) }

    /// {"termos":[{termo,ini,fim,texto,sinal,peso}],"sinais":[{sinal,soma,vezes}]}
    public func reconhecer(_ texto: String) throws(ErroJsonW) -> String {
        try lerTexto { s, cap in texto.withCString { jsonw_reconhecer(r, $0, texto.utf8.count, s, cap) } }
    }
}
