// ./exemplo dados.jsw id 2: as linhas em que o campo vale o valor (JSON), pelo índice; --varrer no fim para buscar sem índice.
// c++ -std=c++23 -I.. exemplo.cpp ../libjsonw.a -lm -o exemplo
#include "jsonw.hpp"

#include <algorithm>
#include <print>
#include <span>
#include <string_view>

int main(int argc, char **argv) try {
    const std::span args{argv, static_cast<std::size_t>(argc)};
    if (args.size() < 4) {
        std::println(stderr, "uso: exemplo arquivo.jsw campo valor [--varrer]");
        return 2;
    }
    jsonw::Leitor a{args[1]};
    const auto campos = a.campos();
    const auto achado = std::ranges::find(campos, std::string_view{args[2]});
    if (achado == campos.end()) {
        std::println(stderr, "campo {} não existe", args[2]);
        return 1;
    }
    const auto k = static_cast<int>(achado - campos.begin());
    if (args.size() < 5 || std::string_view{args[4]} != "--varrer") a.indexar(k);
    for (const auto i : a.chave(k, args[3])) std::println("{}", a.json(i));
} catch (const std::exception &e) {
    std::println(stderr, "{}", e.what());
    return 1;
}
