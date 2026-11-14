/* exemplo.c: abre um .jsw e mostra as linhas em que <campo> vale <valor> (JSON), pelo indice (ou varrendo, com --varrer).
 * cc -I.. exemplo.c ../libjsonw.a -lm && ./a.out dados.jsw id 2 */
#include "jsonw.h"
#include <stdio.h>
#include <string.h>
int main(int argc, char **argv) {
    if (argc < 4) { fprintf(stderr, "uso: exemplo arquivo.jsw campo valor [--varrer]\n"); return 2; }
    char erro[200], v[1 << 16]; uint64_t linhas[64]; void *a = jsonw_abrir(argv[1], erro, sizeof erro); if (!a) { fprintf(stderr, "%s\n", erro); return 1; }
    int k = -1; for (int i = 0; i < jsonw_campos(a); i++) if (!strcmp(jsonw_campo_nome(a, i), argv[2])) k = i;
    if (k < 0) { fprintf(stderr, "campo %s não existe\n", argv[2]); jsonw_fechar(a); return 1; }
    if (argc < 5 || strcmp(argv[4], "--varrer")) jsonw_indexar(a, k);
    int64_t n = jsonw_chave(a, k, argv[3], strlen(argv[3]), linhas, 64);
    for (int64_t i = 0; i < n && i < 64; i++) if (jsonw_linha_json(a, linhas[i], v, sizeof v) >= 0) puts(v);
    jsonw_fechar(a); return n < 0;
}
