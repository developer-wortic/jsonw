/* prova_visao.c: a visao na ABI (jsonw_visao, 1.2), pela libjsonw.a como um SDK a usa: depois de travar "tenant:1" o handle
 * nao mostra a coluna +pessoal (nem no esquema, nem por indice, nem no avaliar), linha do tenant 2 da -3 e o avaliar so
 * devolve linhas do tenant 1. `make prova-visao` (sdk/Makefile). */
#include "jsonw.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>

static int falhas;
#define CONFERE(c, ...) do { if (!(c)) { falhas++; fprintf(stderr, "  FALHOU: " __VA_ARGS__); fprintf(stderr, "\n"); } } while (0)

int main(void) {
    char erro[300], s[4096]; const char *arq = "/tmp/prova-visao-abi.jsw";
    void *w = jsonw_criar(arq, "id:i64,nota:f64,renda:f64+pessoal,tenant:i64+tenant", erro, sizeof erro);
    if (!w) { fprintf(stderr, "criar: %s\n", erro); return 1; }
    for (int i = 0; i < 100; i++) { snprintf(s, sizeof s, "{\"id\":%d,\"nota\":%d,\"renda\":%d.5,\"tenant\":%d}", i, i % 7, 1000 * i, 1 + (i & 1)); CONFERE(!jsonw_gravar_json(w, s, strlen(s), erro, sizeof erro), "gravar: %s", erro); }
    CONFERE(!jsonw_fechar_escritor(w), "fechar escritor");
    void *a = jsonw_abrir(arq, erro, sizeof erro); if (!a) { fprintf(stderr, "abrir: %s\n", erro); return 1; }
    CONFERE(jsonw_campos(a) == 4 && jsonw_linha_json(a, 1, s, sizeof s) > 0 && strstr(s, "renda"), "sem visao: o arquivo inteiro");
    CONFERE(!jsonw_visao(a, "tenant:1", erro, sizeof erro), "visao: %s", erro);
    CONFERE(jsonw_visao(a, "pessoal tenant:todos", erro, sizeof erro) == -1, "a visao destravou");
    CONFERE(jsonw_campos(a) == 3 && !strstr(jsonw_esquema(a), "renda") && !jsonw_campo_nome(a, 3), "esquema com a coluna escondida: %s", jsonw_esquema(a));
    for (int k = 0; k < jsonw_campos(a); k++) CONFERE(strcmp(jsonw_campo_nome(a, k), "renda"), "campo %d e a renda", k);
    CONFERE(jsonw_linha_json(a, 1, s, sizeof s) == -3, "linha do tenant 2 saiu");
    CONFERE(jsonw_linha_json(a, 0, s, sizeof s) > 0 && !strstr(s, "renda") && strstr(s, "\"nota\""), "linha do tenant 1: %s", s);
    CONFERE(jsonw_campo_json(a, 1, 1, s, sizeof s) == -3, "campo da linha do tenant 2 saiu");
    CONFERE(jsonw_campo_json(a, 0, 3, s, sizeof s) == -1, "indice 3 (a renda no arquivo) respondeu");
    CONFERE(jsonw_avaliar(a, "{\"pesos\":{\"renda\":1}}", 21, 5, s, sizeof s, erro, sizeof erro) == -1, "avaliar usou a renda");
    int64_t n = jsonw_avaliar(a, "{\"pesos\":{\"nota\":1}}", 20, 100, s, sizeof s, erro, sizeof erro);
    int impar = 0, itens = 0; for (const char *p = s; n > 0 && (p = strstr(p, "\"linha\":")); p += 8) { itens++; if (atoi(p + 8) & 1) impar++; }
    CONFERE(n > 0 && itens == 50 && !impar, "avaliar: %d itens, %d do tenant 2 (%s)", itens, impar, erro);
    jsonw_fechar(a); unlink(arq);
    printf(falhas ? "prova-visao: %d FALHAS\n" : "prova-visao: TUDO CERTO\n", falhas);
    return falhas != 0;
}
