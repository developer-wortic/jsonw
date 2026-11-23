/* prova_chave.c: a BUSCA POR CHAVE da ABI (jsonw_indexar, jsonw_tem_indice, jsonw_chave), com e sem indice, e a medida.
 *   prova_chave             casos: chave unica, repetida, ausente, valor vazio, tipo errado, campo invalido, max curto, visao
 *   prova_chave --medir N   arquivo de N linhas: mediana de 200 buscas por varredura e pelo indice (e o tempo de montar) */
#include "jsonw.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static int ruins;
static void caso(const char *nome, int ok) { printf("  %s %s\n", ok ? "ok    " : "FALHOU", nome); ruins += !ok; }
static double agora(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec * 1e3 + t.tv_nsec / 1e6; }
static int cmpd(const void *a, const void *b) { double x = *(const double *)a, y = *(const double *)b; return x < y ? -1 : x > y; }

static void gravar(const char *arq, long n) {   /* id unico, uf repetida, nome com vazio, tenant para a visao */
    char e[200], l[200]; void *w = jsonw_criar(arq, "id:i64,uf:dic,nome:texto,tenant:i64+tenant", e, sizeof e);
    if (!w) { fprintf(stderr, "%s\n", e); exit(1); }
    static const char *UF[] = {"SP", "RJ", "MG", "RS"};
    for (long i = 0; i < n; i++) {
        int m = snprintf(l, sizeof l, "{\"id\":%ld,\"uf\":\"%s\",\"nome\":\"%s\",\"tenant\":%ld}", i + 1, UF[i % 4], i % 5 == 1 ? "" : "empresa", 1 + i % 2);
        if (jsonw_gravar_json(w, l, (size_t)m, e, sizeof e)) { fprintf(stderr, "%s\n", e); exit(1); }
    }
    if (jsonw_fechar_escritor(w)) exit(1);
}

static int64_t busca(void *a, int c, const char *v, uint64_t *out, size_t max) { return jsonw_chave(a, c, v, strlen(v), out, max); }

static void casos(const char *arq) {
    char e[200]; uint64_t o[64]; gravar(arq, 20); void *a = jsonw_abrir(arq, e, sizeof e); if (!a) { puts(e); exit(1); }
    for (int com = 0; com < 2; com++) {
        if (com) caso("indexar id e uf", !jsonw_indexar(a, 0) && jsonw_tem_indice(a, 0) && !jsonw_tem_indice(a, 1) && !jsonw_indexar(a, 1) && jsonw_tem_indice(a, 1) && !jsonw_tem_indice(a, 0) && !jsonw_indexar(a, 0));
        else caso("sem indice: tem_indice = 0", !jsonw_tem_indice(a, 0));
        const char *m = com ? " (indice)" : " (varredura)"; char t[80];
        snprintf(t, sizeof t, "chave unica id=7 -> linha 6%s", m); caso(t, busca(a, 0, "7", o, 64) == 1 && o[0] == 6);
        snprintf(t, sizeof t, "chave ausente id=999 -> 0%s", m); caso(t, busca(a, 0, "999", o, 64) == 0);
        snprintf(t, sizeof t, "tipo errado id=\"abc\" -> -2%s", m); caso(t, busca(a, 0, "\"abc\"", o, 64) == -2);
        if (com) jsonw_indexar(a, 1);
        snprintf(t, sizeof t, "chave repetida uf=\"RJ\" -> 5 linhas em ordem%s", m); caso(t, busca(a, 1, "\"RJ\"", o, 64) == 5 && o[0] == 1 && o[4] == 17);
        snprintf(t, sizeof t, "max curto: devolve o total (5), escreve 2%s", m); { uint64_t p[3] = {0, 0, 99}; caso(t, busca(a, 1, "\"RJ\"", p, 2) == 5 && p[0] == 1 && p[1] == 5 && p[2] == 99); }
        if (com) jsonw_indexar(a, 2);
        snprintf(t, sizeof t, "valor vazio nome=\"\" -> 4 linhas%s", m); caso(t, busca(a, 2, "\"\"", o, 64) == 4 && o[0] == 1);
    }
    caso("campo invalido -> -1", busca(a, 9, "1", o, 64) == -1 && jsonw_indexar(a, 9) == -1);
    caso("handle nulo -> -1", jsonw_chave(NULL, 0, "1", 1, o, 64) == -1 && !jsonw_tem_indice(NULL, 0));
    jsonw_fechar(a);
    a = jsonw_abrir(arq, e, sizeof e); caso("visao tenant:1", !jsonw_visao(a, "tenant:1", e, sizeof e));
    { int64_t n1 = busca(a, 1, "\"SP\"", o, 64); int certo = n1 == 5; for (int64_t i = 0; i < n1 && i < 64; i++) certo &= (o[i] % 2 == 0); caso("visao: uf=\"SP\" so linhas pares (tenant 1), varredura", certo); }
    jsonw_indexar(a, 1);
    { int64_t n1 = busca(a, 1, "\"SP\"", o, 64); int certo = n1 == 5; for (int64_t i = 0; i < n1 && i < 64; i++) certo &= (o[i] % 2 == 0); caso("visao: uf=\"SP\" so linhas pares (tenant 1), indice", certo); }
    { int64_t n2 = busca(a, 1, "\"RJ\"", o, 64); caso("visao: uf=\"RJ\" e do tenant 2: 0 linhas, indice", n2 == 0); }
    jsonw_fechar(a);
}

static void medir(const char *arq, long n) {
    char e[200]; double t0 = agora(); gravar(arq, n); printf("  gravou %ld linhas em %.0f ms\n", n, agora() - t0);
    void *a = jsonw_abrir(arq, e, sizeof e); if (!a) { puts(e); exit(1); }
    double v[200]; char k[32]; uint64_t o[4]; srand(42);
    for (int r = 0; r < 2; r++) {
        if (r) { t0 = agora(); jsonw_indexar(a, 0); printf("  montar o indice: %.1f ms\n", agora() - t0); }
        int erradas = 0;
        for (int i = 0; i < 200; i++) {
            long id = 1 + (long)(((double)rand() / RAND_MAX) * (n - 1)); int m = snprintf(k, sizeof k, "%ld", id);
            double s = agora(); int64_t q = jsonw_chave(a, 0, k, (size_t)m, o, 4); v[i] = agora() - s;
            erradas += !(q == 1 && o[0] == (uint64_t)(id - 1));
        }
        qsort(v, 200, sizeof *v, cmpd);
        printf("  %s: mediana %.4f ms, p95 %.4f ms, máx %.4f ms (200 buscas, %d erradas)\n", r ? "indice    " : "varredura ", v[100], v[189], v[199], erradas);
        ruins += erradas;
    }
    jsonw_fechar(a); remove(arq);
}

int main(int argc, char **argv) {
    printf("jsonw %s\n", jsonw_versao());
    if (argc == 3 && !strcmp(argv[1], "--medir")) medir("/tmp/prova_chave_medida.jsw", atol(argv[2]));
    else { casos("/tmp/prova_chave.jsw"); remove("/tmp/prova_chave.jsw"); }
    printf("%s (%d falhas)\n", ruins ? "VERMELHO" : "TUDO CERTO", ruins); return ruins != 0;
}
