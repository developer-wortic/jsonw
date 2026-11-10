/* prova_c.c: a ABI C direta: `prova_c arquivo.jsw` imprime JSONL; `prova_c --gravar esquema entrada.jsonl saida.jsw` grava;
 * `prova_c --avaliar arq pedido k` e `prova_c --reconhecer termos.jsw texto` imprimem o JSON das operacoes. */
#define _GNU_SOURCE   /* getline e ssize_t no glibc com -std=c11 */
#include "jsonw.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static char *cresce(int64_t (*fn)(void *, const char *, size_t, size_t, char *, size_t, char *, size_t), void *h, const char *t, size_t k, char *erro, size_t ne) {   /* chama ate caber (-2) */
    size_t cap = 1 << 16; char *b = malloc(cap); int64_t n;
    while ((n = fn(h, t, strlen(t), k, b, cap, erro, ne)) == -2) { cap *= 4; b = realloc(b, cap); }
    if (n < 0) { free(b); return NULL; }
    return b;
}
static int64_t reconhecer_(void *r, const char *t, size_t n, size_t k, char *s, size_t cap, char *e, size_t ne) { (void)k; (void)e; (void)ne; return jsonw_reconhecer(r, t, n, s, cap); }
int main(int argc, char **argv) {
    char erro[300] = "";
    if (argc == 5 && !strcmp(argv[1], "--gravar")) {
        void *w = jsonw_criar(argv[4], argv[2], erro, sizeof erro); if (!w) { fprintf(stderr, "%s\n", erro); return 1; }
        FILE *f = fopen(argv[3], "rb"); char *l = NULL; size_t cap = 0; ssize_t n;
        while ((n = getline(&l, &cap, f)) > 0) { if (n > 1 && jsonw_gravar_json(w, l, (size_t)n, erro, sizeof erro)) { fprintf(stderr, "%s\n", erro); return 1; } }
        free(l); fclose(f); return jsonw_fechar_escritor(w) ? 1 : 0;
    }
    if (argc == 5 && !strcmp(argv[1], "--avaliar")) {
        void *a = jsonw_abrir(argv[2], erro, sizeof erro); if (!a) { fprintf(stderr, "%s\n", erro); return 1; }
        char *s = cresce(jsonw_avaliar, a, argv[3], strtoull(argv[4], NULL, 10), erro, sizeof erro); if (!s) { fprintf(stderr, "%s\n", erro); return 1; }
        puts(s); free(s); jsonw_fechar(a); return 0;
    }
    if (argc == 4 && !strcmp(argv[1], "--reconhecer")) {
        void *r = jsonw_reconhecedor(argv[2], erro, sizeof erro); if (!r) { fprintf(stderr, "%s\n", erro); return 1; }
        char *s = cresce(reconhecer_, r, argv[3], 0, erro, sizeof erro); if (!s) return 1;
        puts(s); free(s); jsonw_reconhecedor_fechar(r); return 0;
    }
    if (argc == 6 && !strcmp(argv[1], "--visao")) {   /* --visao arq escopos pedido k: campos, as linhas visiveis (JSONL) e o avaliar */
        void *a = jsonw_abrir(argv[2], erro, sizeof erro); if (!a || jsonw_visao(a, argv[3], erro, sizeof erro)) { fprintf(stderr, "%s\n", erro); return 1; }
        for (int k = 0; k < jsonw_campos(a); k++) printf("%s%s", k ? "," : "", jsonw_campo_nome(a, k));
        printf("\n"); size_t cap = 1 << 16; char *b = malloc(cap);
        for (uint64_t i = 0; i < jsonw_linhas(a); i++) {
            int64_t k; while ((k = jsonw_linha_json(a, i, b, cap)) == -2) { cap *= 4; b = realloc(b, cap); }
            if (k == -3) continue;   /* outro tenant */
            if (k < 0) return 1;
            fwrite(b, 1, (size_t)k, stdout); fputc('\n', stdout);
        }
        char *s = cresce(jsonw_avaliar, a, argv[4], strtoull(argv[5], NULL, 10), erro, sizeof erro); if (!s) { fprintf(stderr, "%s\n", erro); return 1; }
        puts(s); free(s); free(b); jsonw_fechar(a); return 0;
    }
    if (argc < 2) return 2;
    void *a = jsonw_abrir(argv[1], erro, sizeof erro); if (!a) { fprintf(stderr, "%s\n", erro); return 1; }
    size_t cap = 1 << 16; char *b = malloc(cap);
    for (uint64_t i = 0; i < jsonw_linhas(a); i++) {
        int64_t k; while ((k = jsonw_linha_json(a, i, b, cap)) == -2) { cap *= 4; b = realloc(b, cap); }
        if (k < 0) { fprintf(stderr, "linha %llu ilegivel\n", (unsigned long long)i); return 1; }
        fwrite(b, 1, (size_t)k, stdout); fputc('\n', stdout);
    }
    free(b); jsonw_fechar(a); return 0;
}
