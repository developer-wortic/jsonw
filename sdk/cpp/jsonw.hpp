// jsonw.hpp: jsonW (json Wondrous) para C++23, por cima da ABI C (jsonw.h). Cada linha vai e volta como JSON.
//   jsonw::Leitor a{"dados.jsw"};
//   for (std::uint64_t i = 0; i < a.linhas(); ++i) std::println("{}", a.json(i));
//   jsonw::Escritor w{"novo.jsw", "id:i64,nome:texto"};
//   w.gravar(R"({"id":1,"nome":"x"})");
//   w.fechar();
#pragma once
#include "../jsonw.h"

#include <cstdint>
#include <exception>
#include <memory>
#include <span>
#include <stdexcept>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

namespace jsonw {

[[nodiscard]] inline std::string versao() { return jsonw_versao(); }

// Linha que a visão esconde (outro tenant depois de visao()); a ABI devolve -3.
struct Oculta : std::runtime_error {
    Oculta() : std::runtime_error{"linha oculta pela visao"} {}
};

namespace detalhe {

template <auto Fechar>
struct Fecha {
    void operator()(void *p) const noexcept { Fechar(p); }
};
template <auto Fechar>
using Alca = std::unique_ptr<void, Fecha<Fechar>>;

// Chama a função da ABI com um buffer que cresce até caber (-2 = curto).
template <class F>
[[nodiscard]] std::string texto(F &&f) {
    for (std::size_t cap = 1 << 16;; cap *= 4) {
        std::string b(cap, '\0');
        const std::int64_t n = f(b.data(), cap);
        if (n == -2) continue;
        if (n == -3) throw Oculta{};
        if (n < 0) throw std::runtime_error{"linha ou campo ilegivel"};
        b.resize(static_cast<std::size_t>(n));
        return b;
    }
}

inline void exigir(bool ok, const char *erro) {
    if (!ok) throw std::runtime_error{erro};
}

}  // namespace detalhe

class Leitor {
    detalhe::Alca<jsonw_fechar> a_;

public:
    explicit Leitor(const std::string &caminho) {
        char erro[256] = "";
        a_.reset(jsonw_abrir(caminho.c_str(), erro, sizeof erro));
        detalhe::exigir(a_ != nullptr, erro);
    }

    [[nodiscard]] std::uint64_t linhas() const { return jsonw_linhas(a_.get()); }
    [[nodiscard]] std::string esquema() const { return jsonw_esquema(a_.get()); }

    [[nodiscard]] std::vector<std::string> campos() const {
        std::vector<std::string> v;
        const int n = jsonw_campos(a_.get());
        v.reserve(static_cast<std::size_t>(n > 0 ? n : 0));
        for (int i = 0; i < n; ++i) v.emplace_back(jsonw_campo_nome(a_.get(), i));
        return v;
    }

    [[nodiscard]] std::string json(std::uint64_t i) {
        return detalhe::texto([&](char *b, std::size_t c) { return jsonw_linha_json(a_.get(), i, b, c); });
    }
    [[nodiscard]] std::string texto(std::uint64_t i) {
        return detalhe::texto([&](char *b, std::size_t c) { return jsonw_linha_texto(a_.get(), i, b, c); });
    }
    [[nodiscard]] std::string campo(std::uint64_t i, int k) {
        return detalhe::texto([&](char *b, std::size_t c) { return jsonw_campo_json(a_.get(), i, k, b, c); });
    }

    void conferir() {
        char erro[256] = "";
        detalhe::exigir(jsonw_conferir(a_.get(), erro, sizeof erro) == 0, erro);
    }

    // Busca por chave: as linhas em que o campo k vale `valor` (JSON do tipo do campo), em ordem crescente.
    void indexar(int k) { detalhe::exigir(jsonw_indexar(a_.get(), k) == 0, "campo sem indice"); }
    [[nodiscard]] bool tem_indice(int k) const { return jsonw_tem_indice(a_.get(), k) == 1; }

    [[nodiscard]] std::vector<std::uint64_t> chave(int k, std::string_view valor) {
        std::vector<std::uint64_t> v(16);
        for (;;) {
            const std::int64_t n = jsonw_chave(a_.get(), k, valor.data(), valor.size(), v.data(), v.size());
            if (n == -2) throw std::runtime_error{"valor nao e do tipo do campo"};
            if (n < 0) throw std::runtime_error{"campo invalido"};
            const auto total = static_cast<std::size_t>(n);
            const bool coube = total <= v.size();
            v.resize(total);
            if (coube) return v;
        }
    }

    // Trava o que a sessão vê ("pessoal vendas tenant:42"): campos e esquema só os visíveis; linha de outro tenant = Oculta.
    void visao(const std::string &escopos) {
        char erro[320] = "";
        detalhe::exigir(jsonw_visao(a_.get(), escopos.c_str(), erro, sizeof erro) == 0, erro);
    }

    // Pedido em JSON ({"pesos":{..}}, {"cosseno":{..}}, ...) -> as k melhores, [{"linha":..,"nota":..}].
    [[nodiscard]] std::string avaliar(std::string_view pedido, std::size_t k = 10) {
        char erro[320] = "";
        return detalhe::texto([&](char *b, std::size_t c) {
            const std::int64_t n = jsonw_avaliar(a_.get(), pedido.data(), pedido.size(), k, b, c, erro, sizeof erro);
            if (n == -1) throw std::runtime_error{erro};
            return n;
        });
    }
};

// As posições das k maiores notas (maior primeiro; empate pela menor posição; NaN é a pior).
[[nodiscard]] inline std::vector<std::uint64_t> escolher(std::span<const double> notas, std::size_t k) {
    std::vector<std::uint64_t> p(k ? k : 1);
    const std::int64_t m = jsonw_escolher(notas.data(), notas.size(), k, p.data());
    p.resize(m > 0 ? static_cast<std::size_t>(m) : 0);
    return p;
}

// Tabela de termos (termo:texto,forma:dic,sinal:dic,peso:f32,idioma:dic,origem:dic) -> termos e sinais achados no texto.
class Reconhecedor {
    detalhe::Alca<jsonw_reconhecedor_fechar> r_;

public:
    explicit Reconhecedor(const std::string &termos_jsw) {
        char erro[320] = "";
        r_.reset(jsonw_reconhecedor(termos_jsw.c_str(), erro, sizeof erro));
        detalhe::exigir(r_ != nullptr, erro);
    }

    [[nodiscard]] std::string reconhecer(std::string_view texto) {
        return detalhe::texto([&](char *b, std::size_t c) { return jsonw_reconhecer(r_.get(), texto.data(), texto.size(), b, c); });
    }
};

class Escritor {
    void *w_ = nullptr;
    int excecoes_ = std::uncaught_exceptions();

public:
    Escritor(const std::string &caminho, const std::string &esquema, int compressao = 1, int hash = 0, int bloco_kb = 0) {
        char erro[256] = "";
        w_ = jsonw_criar(caminho.c_str(), esquema.c_str(), erro, sizeof erro);
        detalhe::exigir(w_ != nullptr, erro);
        jsonw_opcoes(w_, compressao, hash, bloco_kb);
    }
    // Destruído por uma exceção em voo: abandona, e o arquivo pela metade não é publicado.
    ~Escritor() {
        if (!w_) return;
        if (std::uncaught_exceptions() > excecoes_) jsonw_abandonar(w_);
        else jsonw_fechar_escritor(w_);
    }
    Escritor(const Escritor &) = delete;
    Escritor &operator=(const Escritor &) = delete;

    void gravar(std::string_view json) {
        char erro[256] = "";
        detalhe::exigir(jsonw_gravar_json(w_, json.data(), json.size(), erro, sizeof erro) == 0, erro);
    }
    void descarregar() { jsonw_descarregar(w_); }
    void fechar() {
        if (!w_) return;
        const int r = jsonw_fechar_escritor(std::exchange(w_, nullptr));
        detalhe::exigir(r == 0, "nao gravou tudo");
    }
    // Desiste: fecha sem publicar; o destino fica como estava.
    void abandonar() {
        if (w_) jsonw_abandonar(std::exchange(w_, nullptr));
    }
};

}  // namespace jsonw
