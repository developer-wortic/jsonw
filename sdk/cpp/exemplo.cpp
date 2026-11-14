// exemplo.cpp: abre um .jsw e mostra as linhas em que <campo> vale <valor> (JSON), pelo indice (ou varrendo, com --varrer).
// c++ -std=c++17 -I.. exemplo.cpp ../libjsonw.a -lm && ./a.out dados.jsw id 2
#include "jsonw.hpp"
#include <algorithm>
#include <iostream>
int main(int argc, char **argv) {
    if (argc < 4) { std::cerr << "uso: exemplo arquivo.jsw campo valor [--varrer]\n"; return 2; }
    jsonw::Leitor a(argv[1]);
    auto c = a.campos(); auto p = std::find(c.begin(), c.end(), argv[2]);
    if (p == c.end()) { std::cerr << "campo " << argv[2] << " não existe\n"; return 1; }
    int k = int(p - c.begin());
    if (argc < 5 || std::string(argv[4]) != "--varrer") a.indexar(k);
    for (uint64_t i : a.chave(k, argv[3])) std::cout << a.json(i) << "\n";
}
