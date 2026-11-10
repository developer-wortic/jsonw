/* prova_abi.c: o que a ABI garante a QUALQUER linguagem (1.2.1): handle nulo ou ja fechado devolve erro em vez de derrubar o
 * processo; jsonw_abandonar nao publica nada e deixa o destino como estava; tamanhos em int64_t; escolher com k maior que n.
 * `prova_abi <pasta>` (o prova.sh roda). */
#include "jsonw.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

static int falhas;
#define CONFERE(c, ...) do { if (!(c)) { falhas++; fprintf(stderr, "  FALHOU: " __VA_ARGS__); fprintf(stderr, "\n"); } } while (0)

static uint64_t linhas_de(const char *arq) { char e[200]; void *a = jsonw_abrir(arq, e, sizeof e); if (!a) return UINT64_MAX; uint64_t n = jsonw_linhas(a); jsonw_fechar(a); return n; }

int main(int argc, char **argv) {
    char erro[300] = "", s[512], arq[1200]; snprintf(arq, sizeof arq, "%s/prova-abi.jsw", argc > 1 ? argv[1] : "/tmp");
    /* handle nulo: toda funcao responde erro */
    CONFERE(jsonw_linhas(NULL) == 0 && jsonw_campos(NULL) == 0 && jsonw_campo_nome(NULL, 0) == NULL && !strcmp(jsonw_esquema(NULL), ""), "leitura de handle nulo");
    CONFERE(jsonw_linha_json(NULL, 0, s, sizeof s) == -1 && jsonw_linha_texto(NULL, 0, s, sizeof s) == -1 && jsonw_campo_json(NULL, 0, 0, s, sizeof s) == -1, "linha de handle nulo");
    CONFERE(jsonw_conferir(NULL, erro, sizeof erro) == -1 && jsonw_visao(NULL, "x", erro, sizeof erro) == -1, "conferir/visao de handle nulo");
    CONFERE(jsonw_avaliar(NULL, "{}", 2, 1, s, sizeof s, erro, sizeof erro) == -1 && jsonw_reconhecer(NULL, "x", 1, s, sizeof s) == -1, "operacoes de handle nulo");
    CONFERE(jsonw_gravar_json(NULL, "{}", 2, erro, sizeof erro) == -1 && jsonw_descarregar(NULL) == -1 && jsonw_fechar_escritor(NULL) == -1 && jsonw_abandonar(NULL) == -1 && jsonw_opcoes(NULL, 1, 0, 0) == -1, "escrita de handle nulo");
    jsonw_fechar(NULL); jsonw_reconhecedor_fechar(NULL);
    CONFERE(jsonw_abrir(NULL, erro, sizeof erro) == NULL && jsonw_criar(NULL, "a:i64", erro, sizeof erro) == NULL && jsonw_reconhecedor(NULL, erro, sizeof erro) == NULL, "caminho nulo");
    /* abandonar: o destino que ja existia fica como estava */
    void *w = jsonw_criar(arq, "id:i64,t:texto", erro, sizeof erro); CONFERE(w != NULL, "criar: %s", erro);
    if (w) { const char *l1 = "{\"id\":1,\"t\":\"o que ja estava\"}"; CONFERE(!jsonw_gravar_json(w, l1, strlen(l1), erro, sizeof erro) && !jsonw_fechar_escritor(w), "gravar a 1a versao: %s", erro); }
    w = jsonw_criar(arq, "id:i64,t:texto", erro, sizeof erro);
    for (int i = 0; w && i < 30; i++) { int n = snprintf(s, sizeof s, "{\"id\":%d,\"t\":\"novo\"}", i); jsonw_gravar_json(w, s, (size_t)n, erro, sizeof erro); }
    CONFERE(w && jsonw_abandonar(w) == 0 && linhas_de(arq) == 1, "abandonar publicou: o destino tinha 1 linha e ficou com %llu", (unsigned long long)linhas_de(arq));
    /* cap curto = -2 (e saida nula tambem), sem escrever fora */
    void *a = jsonw_abrir(arq, erro, sizeof erro);
    if (a) {
        char curto[4] = "zzz"; int64_t n = jsonw_linha_json(a, 0, curto, sizeof curto);
        CONFERE(n == -2 && !strcmp(curto, "zzz") && jsonw_linha_json(a, 0, NULL, 0) == -2, "cap curto: %lld", (long long)n);
        n = jsonw_linha_json(a, 0, s, sizeof s); CONFERE(n == (int64_t)strlen(s) && n > 10, "tamanho devolvido: %lld", (long long)n);
        CONFERE(jsonw_linha_json(a, 99, s, sizeof s) == -1 && jsonw_campo_json(a, 0, 7, s, sizeof s) == -1 && jsonw_campo_nome(a, -1) == NULL, "linha ou campo fora do arquivo");
        jsonw_fechar(a);
    } else CONFERE(0, "abrir: %s", erro);
    /* escolher: k maior que n devolve n; k = 0 ou vetor vazio devolve 0 */
    double notas[4] = {0.2, 0.9, 0.5, 0.9}; uint64_t pos[4] = {9, 9, 9, 9};
    CONFERE(jsonw_escolher(notas, 4, 1000000, pos) == 4 && pos[0] == 1 && pos[1] == 3 && pos[2] == 2 && pos[3] == 0, "escolher com k maior que n");
    CONFERE(jsonw_escolher(notas, 4, 0, pos) == 0 && jsonw_escolher(notas, 0, 3, pos) == 0 && jsonw_escolher(NULL, 4, 2, pos) == 0, "escolher vazio");
    CONFERE(!strcmp(jsonw_versao(), JSONW_VERSAO), "versao da biblioteca (%s) diferente do cabecalho (%s)", jsonw_versao(), JSONW_VERSAO);
    remove(arq);
    printf(falhas ? "prova-abi: %d FALHAS\n" : "prova-abi: TUDO CERTO\n", falhas);
    return falhas != 0;
}
