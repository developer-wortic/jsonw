// jsonw.swift: jsonW (json Wondrous) para Swift (macOS, iOS, Linux), por cima da ABI C (libjsonw, modulo CJsonw).
//   let a = try Leitor("dados.jsw"); for i in 0..<a.linhas { print(try a.json(i)) }
//   let w = try Escritor("novo.jsw", esquema: "id:i64,nome:texto"); try w.gravar(#"{"id":1,"nome":"x"}"#); try w.fechar()
// Compilar: swiftc -I sdk/swift sdk/swift/jsonw.swift sdk/swift/main.swift sdk/libjsonw.a -o ler
import CJsonw
import Foundation

public struct ErroJsonW: Error, CustomStringConvertible { public let description: String }
public struct LinhaOculta: Error {}   // linha de outro tenant depois de visao() (-3 na ABI)

func erroDe(_ b: [CChar]) -> ErroJsonW { ErroJsonW(description: String(cString: b)) }

func lerTexto(_ f: (UnsafeMutablePointer<CChar>, Int) -> Int64) throws -> String {   // Int64: o int64_t da ABI (igual em todo sistema)
    var cap = 1 << 16
    while true {
        var b = [CChar](repeating: 0, count: cap)
        let n = b.withUnsafeMutableBufferPointer { f($0.baseAddress!, cap) }
        if n == -2 { cap *= 4; continue }
        if n == -3 { throw LinhaOculta() }
        if n < 0 { throw ErroJsonW(description: "linha ou campo ilegivel") }
        return String(decoding: b[0..<Int(n)].map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}

public final class Leitor {
    let a: UnsafeMutableRawPointer
    public let linhas: UInt64
    public private(set) var esquema: String
    public private(set) var campos: [String]
    public init(_ caminho: String) throws {
        var erro = [CChar](repeating: 0, count: 200)
        guard let p = jsonw_abrir(caminho, &erro, 200) else { throw erroDe(erro) }
        a = p; linhas = jsonw_linhas(p); esquema = String(cString: jsonw_esquema(p))
        campos = (0..<Int(jsonw_campos(p))).map { String(cString: jsonw_campo_nome(p, Int32($0))) }
    }
    deinit { jsonw_fechar(a) }
    public func json(_ i: UInt64) throws -> String { try lerTexto { jsonw_linha_json(a, i, $0, $1) } }
    public func texto(_ i: UInt64) throws -> String { try lerTexto { jsonw_linha_texto(a, i, $0, $1) } }
    public func campo(_ i: UInt64, _ k: Int) throws -> String { try lerTexto { jsonw_campo_json(a, i, Int32(k), $0, $1) } }
    public func conferir() throws { var erro = [CChar](repeating: 0, count: 200); if jsonw_conferir(a, &erro, 200) != 0 { throw erroDe(erro) } }
    // visao (1.2): trava o que a sessao ve ("pessoal vendas tenant:42"): esquema e campos so os visiveis; linha de outro tenant = LinhaOculta
    public func visao(_ escopos: String) throws {
        var erro = [CChar](repeating: 0, count: 300); if jsonw_visao(a, escopos, &erro, 300) != 0 { throw erroDe(erro) }
        esquema = String(cString: jsonw_esquema(a)); campos = (0..<Int(jsonw_campos(a))).map { String(cString: jsonw_campo_nome(a, Int32($0))) }
    }
}

public final class Escritor {
    var w: UnsafeMutableRawPointer?
    public init(_ caminho: String, esquema: String, compressao: Int32 = 1, hash: Int32 = 0, blocoKb: Int32 = 0) throws {
        var erro = [CChar](repeating: 0, count: 200)
        guard let p = jsonw_criar(caminho, esquema, &erro, 200) else { throw erroDe(erro) }
        w = p; jsonw_opcoes(p, compressao, hash, blocoKb)
    }
    deinit { if let p = w { jsonw_abandonar(p) } }   // largado sem fechar(): abandona (so fechar() publica; nada pela metade no destino)
    public func gravar(_ json: String) throws {
        var erro = [CChar](repeating: 0, count: 200)
        let r = json.utf8CString.withUnsafeBufferPointer { jsonw_gravar_json(w, $0.baseAddress, json.utf8.count, &erro, 200) }
        if r != 0 { throw erroDe(erro) }
    }
    public func descarregar() { jsonw_descarregar(w) }
    public func fechar() throws { guard let p = w else { return }; w = nil; if jsonw_fechar_escritor(p) != 0 { throw ErroJsonW(description: "nao gravou tudo") } }
    public func abandonar() { guard let p = w else { return }; w = nil; jsonw_abandonar(p) }   // desiste: fecha sem publicar; o destino fica como estava
}
