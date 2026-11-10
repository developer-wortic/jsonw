// ler arquivo.jsw -> JSONL; ler --avaliar arq pedido k; ler --reconhecer termos.jsw texto (prova do SDK C++)
#include "jsonw.hpp"
#include <iostream>
int main(int argc, char **argv) {
    if (argc < 2) { std::cerr << "uso: ler arquivo.jsw | --avaliar arq pedido k | --reconhecer termos.jsw texto\n"; return 2; }
    try {
        std::string m = argv[1];
        if (m == "--avaliar" && argc > 4) { jsonw::Leitor a(argv[2]); std::cout << a.avaliar(argv[3], std::stoul(argv[4])) << "\n"; return 0; }
        if (m == "--visao" && argc > 5) {   // --visao arq escopos pedido k: campos, as linhas visiveis (JSONL) e o avaliar
            jsonw::Leitor a(argv[2]); a.visao(argv[3]); auto c = a.campos();
            for (size_t k = 0; k < c.size(); k++) std::cout << (k ? "," : "") << c[k];
            std::cout << "\n";
            for (uint64_t i = 0; i < a.linhas(); i++) try { std::cout << a.json(i) << "\n"; } catch (const jsonw::Oculta &) {}
            std::cout << a.avaliar(argv[4], std::stoul(argv[5])) << "\n"; return 0;
        }
        if (m == "--reconhecer" && argc > 3) { jsonw::Reconhecedor r(argv[2]); std::cout << r.reconhecer(argv[3]) << "\n"; return 0; }
        jsonw::Leitor a(argv[1]);
        for (uint64_t i = 0; i < a.linhas(); i++) std::cout << a.json(i) << "\n";
    } catch (const std::exception &e) { std::cerr << e.what() << "\n"; return 1; }
    return 0;
}
