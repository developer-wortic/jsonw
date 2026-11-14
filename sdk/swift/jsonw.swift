// jsonw.swift: jsonW para Swift 6 (macOS, iOS, Linux), por cima da ABI C (libjsonw, módulo CJsonw).
//   let a = try Leitor("dados.jsw"); for i in 0..<a.linhas { print(try a.json(i)) }
//   let w = try Escritor("novo.jsw", esquema: "id:i64,nome:texto"); try w.gravar(#"{"id":1,"nome":"x"}"#); try w.fechar()
// Compilar: swiftc -I sdk/swift sdk/swift/*.swift sdk/libjsonw.a -o ler
import CJsonw

public enum ErroJsonW: Error, Equatable, CustomStringConvertible {
    case biblioteca(String)
    /// Linha de outro tenant depois de `visao(_:)` (-3 na ABI).
    case linhaOculta
    case ilegivel

    public var description: String {
        switch self {
        case .biblioteca(let texto): texto
        case .linhaOculta: "linha oculta pela visao"
        case .ilegivel: "linha ou campo ilegivel"
        }
    }
}

let tamanhoErro = 320

/// Chama com um buffer de erro; devolve o que a chamada devolveu e o texto do erro.
func comErro<T>(_ chamada: (UnsafeMutablePointer<CChar>, Int) -> T) -> (T, String) {
    withUnsafeTemporaryAllocation(of: CChar.self, capacity: tamanhoErro) { erro in
        erro.initialize(repeating: 0)
        let r = chamada(erro.baseAddress!, tamanhoErro)
        return (r, String(cString: erro.baseAddress!))
    }
}

/// Buffer que cresce até caber (-2 = curto).
func lerTexto(_ chamada: (UnsafeMutablePointer<CChar>, Int) throws(ErroJsonW) -> Int64) throws(ErroJsonW) -> String {
    var cap = 1 << 16
    while true {
        var b = [CChar](repeating: 0, count: cap)
        let n = try b.withUnsafeMutableBufferPointer { (p) throws(ErroJsonW) in try chamada(p.baseAddress!, cap) }
        switch n {
        case -2: cap *= 4
        case -3: throw .linhaOculta
        case ..<0: throw .ilegivel
        default: return b.withUnsafeBytes { String(decoding: $0.prefix(Int(n)), as: UTF8.self) }
        }
    }
}

public final class Leitor {
    let a: UnsafeMutableRawPointer
    public let linhas: UInt64
    public private(set) var esquema = ""
    public private(set) var campos: [String] = []

    public init(_ caminho: String) throws(ErroJsonW) {
        let (p, erro) = comErro { jsonw_abrir(caminho, $0, $1) }
        guard let p else { throw .biblioteca(erro) }
        a = p
        linhas = jsonw_linhas(p)
        lerEsquema()
    }

    deinit { jsonw_fechar(a) }

    private func lerEsquema() {
        esquema = String(cString: jsonw_esquema(a))
        campos = (0..<jsonw_campos(a)).map { String(cString: jsonw_campo_nome(a, $0)) }
    }

    public func json(_ i: UInt64) throws(ErroJsonW) -> String { try lerTexto { jsonw_linha_json(a, i, $0, $1) } }
    public func texto(_ i: UInt64) throws(ErroJsonW) -> String { try lerTexto { jsonw_linha_texto(a, i, $0, $1) } }
    public func campo(_ i: UInt64, _ k: Int) throws(ErroJsonW) -> String { try lerTexto { jsonw_campo_json(a, i, Int32(k), $0, $1) } }
    public func campo(_ i: UInt64, _ nome: String) throws(ErroJsonW) -> String { try campo(i, indice(nome)) }

    public func indice(_ nome: String) throws(ErroJsonW) -> Int {
        guard let k = campos.firstIndex(of: nome) else { throw .biblioteca("campo inexistente: \(nome)") }
        return k
    }

    public func conferir() throws(ErroJsonW) {
        let (r, erro) = comErro { jsonw_conferir(a, $0, $1) }
        if r != 0 { throw .biblioteca(erro) }
    }

    /// Trava o que a sessão vê ("pessoal vendas tenant:42"); linha de outro tenant = `.linhaOculta`.
    public func visao(_ escopos: String) throws(ErroJsonW) {
        let (r, erro) = comErro { jsonw_visao(a, escopos, $0, $1) }
        if r != 0 { throw .biblioteca(erro) }
        lerEsquema()
    }

    public func indexar(_ k: Int) throws(ErroJsonW) {
        if jsonw_indexar(a, Int32(k)) != 0 { throw .biblioteca("campo sem indice") }
    }

    public func temIndice(_ k: Int) -> Bool { jsonw_tem_indice(a, Int32(k)) == 1 }

    /// As linhas em que o campo k vale `valor` (o JSON do valor: "7", "\"RJ\""), em ordem crescente.
    public func chave(_ k: Int, _ valor: String) throws(ErroJsonW) -> [UInt64] {
        var cap = 16
        while true {
            var out = [UInt64](repeating: 0, count: cap)
            let n = valor.withCString { v in jsonw_chave(a, Int32(k), v, valor.utf8.count, &out, cap) }
            switch n {
            case -2: throw .biblioteca("valor nao e do tipo do campo")
            case ..<0: throw .biblioteca("campo invalido")
            case ...Int64(cap): return Array(out.prefix(Int(n)))
            default: cap = Int(n)
            }
        }
    }
}

/// O destino só aparece em `fechar()`; largado sem fechar, abandona e o destino fica como estava.
public final class Escritor {
    private var w: UnsafeMutableRawPointer?

    public init(_ caminho: String, esquema: String, compressao: Int32 = 1, hash: Int32 = 0, blocoKb: Int32 = 0) throws(ErroJsonW) {
        let (p, erro) = comErro { jsonw_criar(caminho, esquema, $0, $1) }
        guard let p else { throw .biblioteca(erro) }
        w = p
        jsonw_opcoes(p, compressao, hash, blocoKb)
    }

    deinit { if let w { jsonw_abandonar(w) } }

    public func gravar(_ json: String) throws(ErroJsonW) {
        let (r, erro) = comErro { e, ne in json.withCString { jsonw_gravar_json(w, $0, json.utf8.count, e, ne) } }
        if r != 0 { throw .biblioteca(erro) }
    }

    public func descarregar() { jsonw_descarregar(w) }

    public func fechar() throws(ErroJsonW) {
        guard let p = w.take() else { return }
        if jsonw_fechar_escritor(p) != 0 { throw .biblioteca("nao gravou tudo") }
    }

    public func abandonar() {
        if let p = w.take() { jsonw_abandonar(p) }
    }
}
