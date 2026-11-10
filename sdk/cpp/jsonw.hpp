/* jsonw.hpp: jsonW (json Wondrous) para C++17, RAII por cima da ABI C (jsonw.h). Cada linha vai e volta como JSON (string).
 *   jsonw::Leitor a("dados.jsw"); for (auto i = 0u; i < a.linhas(); i++) std::cout << a.json(i) << "\n";
 *   jsonw::Escritor w("novo.jsw", "id:i64,nome:texto"); w.gravar(R"({"id":1,"nome":"x"})"); w.fechar(); */
#pragma once
#include "../jsonw.h"
#include <exception>
#include <stdexcept>
#include <string>
#include <vector>

namespace jsonw {
inline std::string versao() { return jsonw_versao(); }
struct Oculta : std::runtime_error { Oculta() : std::runtime_error("linha oculta pela visao") {} };   // linha de outro tenant depois de visao() (-3 na ABI)

template <class F> std::string texto_(F f) {
    size_t cap = 1 << 16;
    for (;;) {
        std::string b(cap, '\0'); int64_t n = f(&b[0], cap);
        if (n == -2) { cap *= 4; continue; }
        if (n == -3) throw Oculta();
        if (n < 0) throw std::runtime_error("linha ou campo ilegivel");
        b.resize((size_t)n); return b;
    }
}

class Leitor {
    void *a_;
public:
    explicit Leitor(const std::string &caminho) {
        char erro[200] = ""; a_ = jsonw_abrir(caminho.c_str(), erro, sizeof erro);
        if (!a_) throw std::runtime_error(erro);
    }
    ~Leitor() { if (a_) jsonw_fechar(a_); }
    Leitor(const Leitor &) = delete; Leitor &operator=(const Leitor &) = delete;
    uint64_t linhas() const { return jsonw_linhas(a_); }
    std::string esquema() const { return jsonw_esquema(a_); }
    std::vector<std::string> campos() const { std::vector<std::string> v; for (int i = 0; i < jsonw_campos(a_); i++) v.push_back(jsonw_campo_nome(a_, i)); return v; }
    std::string json(uint64_t i) { return texto_([&](char *b, size_t c) { return jsonw_linha_json(a_, i, b, c); }); }
    std::string texto(uint64_t i) { return texto_([&](char *b, size_t c) { return jsonw_linha_texto(a_, i, b, c); }); }
    std::string campo(uint64_t i, int k) { return texto_([&](char *b, size_t c) { return jsonw_campo_json(a_, i, k, b, c); }); }
    void conferir() { char erro[200] = ""; if (jsonw_conferir(a_, erro, sizeof erro)) throw std::runtime_error(erro); }
    /* visao (1.2): trava o que a sessao ve ("pessoal vendas tenant:42"): campos e esquema so os visiveis, linha de outro tenant = Oculta */
    void visao(const std::string &escopos) { char erro[300] = ""; if (jsonw_visao(a_, escopos.c_str(), erro, sizeof erro)) throw std::runtime_error(erro); }
    /* AVALIAR + ESCOLHER: pedido em JSON ({"cosseno":{"campo":"vet","consulta":[..]}}, {"pesos":{..}}, ...) -> as k melhores, [{"linha","nota"}] */
    std::string avaliar(const std::string &pedido, size_t k = 10) {
        char erro[300] = "";
        return texto_([&](char *b, size_t c) { int64_t n = jsonw_avaliar(a_, pedido.data(), pedido.size(), k, b, c, erro, sizeof erro); if (n == -1) throw std::runtime_error(erro); return n; });
    }
};

/* ESCOLHER das suas notas: posicoes das k maiores (maior primeiro; empate pela menor posicao; NaN e a pior) */
inline std::vector<uint64_t> escolher(const std::vector<double> &notas, size_t k) {
    std::vector<uint64_t> p(k ? k : 1); int64_t m = jsonw_escolher(notas.data(), notas.size(), k, p.data()); p.resize(m > 0 ? (size_t)m : 0); return p;
}

/* RECONHECER: a tabela de termos (termo:texto,forma:dic,sinal:dic,peso:f32,idioma:dic,origem:dic) vira o reconhecedor;
 * reconhecer(texto) -> {"termos":[{termo,ini,fim,texto,sinal,peso}],"sinais":[{sinal,soma,vezes}]} */
class Reconhecedor {
    void *r_;
public:
    explicit Reconhecedor(const std::string &termos_jsw) { char erro[300] = ""; r_ = jsonw_reconhecedor(termos_jsw.c_str(), erro, sizeof erro); if (!r_) throw std::runtime_error(erro); }
    ~Reconhecedor() { if (r_) jsonw_reconhecedor_fechar(r_); }
    Reconhecedor(const Reconhecedor &) = delete; Reconhecedor &operator=(const Reconhecedor &) = delete;
    std::string reconhecer(const std::string &texto) { return texto_([&](char *b, size_t c) { return jsonw_reconhecer(r_, texto.data(), texto.size(), b, c); }); }
};

class Escritor {
    void *w_; int excecoes_ = std::uncaught_exceptions();
public:
    Escritor(const std::string &caminho, const std::string &esquema, int compressao = 1, int hash = 0, int bloco_kb = 0) {
        char erro[200] = ""; w_ = jsonw_criar(caminho.c_str(), esquema.c_str(), erro, sizeof erro);
        if (!w_) throw std::runtime_error(erro);
        jsonw_opcoes(w_, compressao, hash, bloco_kb);
    }
    /* destruido por uma excecao em voo (quem gravava saiu por erro): abandona, o arquivo pela metade nao e publicado */
    ~Escritor() { if (!w_) return; if (std::uncaught_exceptions() > excecoes_) jsonw_abandonar(w_); else jsonw_fechar_escritor(w_); }
    Escritor(const Escritor &) = delete; Escritor &operator=(const Escritor &) = delete;
    void gravar(const std::string &json) { char erro[200] = ""; if (jsonw_gravar_json(w_, json.data(), json.size(), erro, sizeof erro)) throw std::runtime_error(erro); }
    void descarregar() { jsonw_descarregar(w_); }
    void fechar() { if (!w_) return; int r = jsonw_fechar_escritor(w_); w_ = nullptr; if (r) throw std::runtime_error("nao gravou tudo"); }
    void abandonar() { if (!w_) return; jsonw_abandonar(w_); w_ = nullptr; }   /* desiste: fecha sem publicar; o destino fica como estava */
};
}
