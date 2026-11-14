// Prova do SDK C++: ler arquivo.jsw -> JSONL | --avaliar arq pedido k | --visao arq escopos pedido k | --reconhecer termos.jsw texto
#include "jsonw.hpp"

#include <print>
#include <string>
#include <string_view>

int main(int argc, char **argv) {
    if (argc < 2) {
        std::println(stderr, "uso: ler arquivo.jsw | --avaliar arq pedido k | --visao arq escopos pedido k | --reconhecer termos.jsw texto");
        return 2;
    }
    try {
        const std::string_view modo = argv[1];
        if (modo == "--avaliar" && argc > 4) {
            jsonw::Leitor a{argv[2]};
            std::println("{}", a.avaliar(argv[3], std::stoul(argv[4])));
            return 0;
        }
        if (modo == "--visao" && argc > 5) {
            jsonw::Leitor a{argv[2]};
            a.visao(argv[3]);
            const auto campos = a.campos();
            for (std::size_t k = 0; k < campos.size(); ++k) std::print("{}{}", k ? "," : "", campos[k]);
            std::println("");
            for (std::uint64_t i = 0; i < a.linhas(); ++i) {
                try {
                    std::println("{}", a.json(i));
                } catch (const jsonw::Oculta &) {
                }
            }
            std::println("{}", a.avaliar(argv[4], std::stoul(argv[5])));
            return 0;
        }
        if (modo == "--reconhecer" && argc > 3) {
            jsonw::Reconhecedor r{argv[2]};
            std::println("{}", r.reconhecer(argv[3]));
            return 0;
        }
        jsonw::Leitor a{argv[1]};
        for (std::uint64_t i = 0; i < a.linhas(); ++i) std::println("{}", a.json(i));
    } catch (const std::exception &e) {
        std::println(stderr, "{}", e.what());
        return 1;
    }
    return 0;
}
