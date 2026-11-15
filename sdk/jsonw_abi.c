/* jsonw_abi.c: a ABI C (sdk/jsonw.h) por cima da lib/wjsw.h: handles opacos, linhas como JSON. E o que os SDKs chamam.
 * Handle NULL nunca derruba o processo (quem fechou e zerou o handle recebe erro, nao uma falha de memoria). */
#include "jsonw_abi_int.h"

#ifdef JW_BLINDAR
/* Ancora da blindagem: faz o .a puxar lib/blind_init.o (a medida de depurador na carga). */
#include "../lib/blind.h"
__attribute__((used)) static const int *const jw_ancora_blind = &blind_ancora;
#endif

typedef struct { JwEscritor *w; JwEsquema *e; JwCampo raiz; JwArena ar; } Escritor;

#define falha jsonw_falha
const char *jsonw_versao(void) { return JW_LIB_VERSAO; }

/* O que vem depois de abrir o arquivo, pelo caminho ou pela memoria: os valores de uma linha e a raiz do objeto. */
static Leitor *preparar(Leitor *l, char *erro, size_t nerro) {
    l->c = calloc((size_t)l->a.e->n, sizeof *l->c); l->raiz.nome = "linha"; l->raiz.tipo = JW_OBJ; l->raiz.sub = l->a.e;
    if (!l->c) { jw_fechar_arquivo(&l->a); free(l->mem); free(l); falha(erro, nerro, "sem memoria"); return NULL; }
    return l;
}

void *jsonw_abrir(const char *caminho, char *erro, size_t nerro) {
    if (!caminho) { falha(erro, nerro, "caminho nulo"); return NULL; }
    Leitor *l = calloc(1, sizeof *l); if (!l) { falha(erro, nerro, "sem memoria"); return NULL; }
    if (jw_abrir(&l->a, caminho, erro, nerro)) { jw_fechar_arquivo(&l->a); free(l); return NULL; }
    return preparar(l, erro, nerro);
}

/* Navegador, React Native, WASM e bytes que vieram pela rede: o leitor guarda a propria copia, e quem chamou pode soltar
 * os seus bytes logo depois. */
void *jsonw_abrir_memoria(const void *bytes, size_t n, char *erro, size_t nerro) {
    if (!bytes || !n) { falha(erro, nerro, "arquivo vazio"); return NULL; }
    Leitor *l = calloc(1, sizeof *l); if (!l) { falha(erro, nerro, "sem memoria"); return NULL; }
    if (!(l->mem = malloc(n))) { free(l); falha(erro, nerro, "sem memoria"); return NULL; }
    memcpy(l->mem, bytes, n);
    if (jw_abrir_memoria(&l->a, l->mem, n, erro, nerro)) { jw_fechar_arquivo(&l->a); free(l->mem); free(l); return NULL; }
    return preparar(l, erro, nerro);
}
void jsonw_fechar(void *x) {
    Leitor *l = x; if (!l) return;
    if (l->com_visao) { jw_visao_free(&l->vis); free(l->idx); free(l->sub.c); buf_free(&l->esq); }
    jsonw_indice_free(l->chave);
    jw_fechar_arquivo(&l->a); jw_arena_free(&l->ar); buf_free(&l->o); free(l->c); free(l->mem); free(l);
}
uint64_t jsonw_linhas(const void *x) { return x ? ((const Leitor *)x)->a.total : 0; }
int jsonw_campos(const void *x) { return x ? jsonw_ncampos(x) : 0; }
const char *jsonw_esquema(const void *x) { const Leitor *l = x; return !l ? "" : l->com_visao ? l->esq.p : l->a.esquema_txt.p; }
const char *jsonw_campo_nome(const void *x, int campo) { const Leitor *l = x; if (!l) return NULL; int k = jsonw_campo_real(l, campo); return k < 0 ? NULL : l->a.e->c[k].nome; }

static int64_t devolver(Leitor *l, char *saida, size_t cap) { return jsonw_devolver(&l->o, saida, cap); }
static int64_t linha(Leitor *l, uint64_t i, int modo, char *saida, size_t cap) {
    if (!l || i >= l->a.total) return -1;
    if (jsonw_oculta(l, i)) return -3;
    int n = jsonw_ncampos(l);
    for (int k = 0; k < n; k++) if (jw_valor(&l->a, i, jsonw_campo_real(l, k), &l->c[k], &l->ar)) { jw_arena_limpar(&l->ar); return -1; }
    JwValor v; memset(&v, 0, sizeof v); v.tipo = JW_OBJ; v.v = l->c; v.nv = (size_t)n;
    l->o.n = 0; jw_texto_escrever(&l->raiz, &v, modo, &l->o); jw_arena_limpar(&l->ar);
    return devolver(l, saida, cap);
}
int64_t jsonw_linha_json(void *x, uint64_t i, char *saida, size_t cap) { return linha(x, i, JW_SAI_JSON, saida, cap); }
int64_t jsonw_linha_texto(void *x, uint64_t i, char *saida, size_t cap) { return linha(x, i, JW_SAI_TEXTO, saida, cap); }
int64_t jsonw_campo_json(void *x, uint64_t i, int campo, char *saida, size_t cap) {
    Leitor *l = x; JwValor v; if (!l) return -1;
    int k = jsonw_campo_real(l, campo);
    if (k < 0 || i >= l->a.total) return -1;
    if (jsonw_oculta(l, i)) return -3;
    if (jw_valor(&l->a, i, k, &v, &l->ar)) { jw_arena_limpar(&l->ar); return -1; }
    l->o.n = 0; jw_texto_escrever(&l->a.e->c[k], &v, JW_SAI_JSON, &l->o); jw_arena_limpar(&l->ar);
    return devolver(l, saida, cap);
}
int jsonw_conferir(void *x, char *erro, size_t nerro) { Leitor *l = x; if (!l) { falha(erro, nerro, "handle nulo ou ja fechado"); return -1; } return jw_conferir(&l->a, erro, nerro); }

void *jsonw_criar(const char *caminho, const char *esquema, char *erro, size_t nerro) {
    if (!caminho || !esquema) { falha(erro, nerro, "caminho ou esquema nulo"); return NULL; }
    Escritor *w = calloc(1, sizeof *w); if (!w) { falha(erro, nerro, "sem memoria"); return NULL; }
    char e[200];
    if (!(w->e = jw_esquema(esquema, e, sizeof e))) { falha(erro, nerro, e); free(w); return NULL; }
    if (!(w->w = jw_criar(caminho, w->e))) { falha(erro, nerro, "nao criou o arquivo"); jw_esquema_free(w->e); free(w); return NULL; }
    w->raiz.nome = "linha"; w->raiz.tipo = JW_OBJ; w->raiz.sub = w->e;
    return w;
}
int jsonw_opcoes(void *x, int nivel, int hash_alg, int bloco_kb) {
    Escritor *w = x; if (!w) return -1;
    jw_compressao(w->w, nivel); if (bloco_kb > 0) jw_bloco_max(w->w, (size_t)bloco_kb << 10);
    return jw_hash_alg(w->w, hash_alg);
}
int jsonw_gravar_json(void *x, const char *json, size_t n, char *erro, size_t nerro) {
    Escritor *w = x; JwValor v; char e[200]; const char *p = json;
    if (!w || !json) { falha(erro, nerro, "handle nulo ou ja fechado"); return -1; }
    int r = jw_texto_ler(&p, json + n, &w->raiz, &v, &w->ar, e, sizeof e);
    if (r) { falha(erro, nerro, r == 1 ? "linha vazia" : e); jw_arena_limpar(&w->ar); return -1; }
    r = jw_linha(w->w, v.v); jw_arena_limpar(&w->ar);
    if (r) falha(erro, nerro, "valor nao cabe no esquema");
    return r ? -1 : 0;
}
int jsonw_descarregar(void *x) { return x ? jw_descarregar(((Escritor *)x)->w) : -1; }
static int soltar(Escritor *w, int r) { jw_esquema_free(w->e); jw_arena_free(&w->ar); free(w); return r; }
int jsonw_fechar_escritor(void *x) { Escritor *w = x; if (!w) return -1; return soltar(w, jw_fechar(w->w)); }
int jsonw_abandonar(void *x) { Escritor *w = x; if (!w) return -1; jw_abandonar(w->w); return soltar(w, 0); }   /* 0 = abandonado; o destino nao foi tocado */

int64_t jsonw_texto_para_json(const char *esquema, const char *texto, size_t n, char *saida, size_t cap, char *erro, size_t nerro) {
    if (!texto) { falha(erro, nerro, "texto nulo"); return -1; }
    char e[200]; JwEsquema *es = esquema && *esquema ? jw_esquema(esquema, e, sizeof e) : NULL;
    if (esquema && *esquema && !es) { falha(erro, nerro, e); return -1; }
    JwCampo raiz; memset(&raiz, 0, sizeof raiz); raiz.nome = "v"; raiz.tipo = es ? JW_OBJ : JW_QUALQUER; raiz.sub = es;
    JwArena ar = {0}; JwValor v; const char *p = texto; Buf o = {0}; int64_t r = -1;
    if (!jw_texto_ler(&p, texto + n, es ? &raiz : NULL, &v, &ar, e, sizeof e)) {
        jw_texto_escrever(es ? &raiz : &JW_CAMPO_QUALQUER, &v, JW_SAI_JSON, &o);
        if (o.n + 1 <= cap && saida) { memcpy(saida, o.p, o.n); saida[o.n] = 0; r = (int64_t)o.n; } else r = -2;
    } else falha(erro, nerro, e);
    buf_free(&o); jw_arena_free(&ar); jw_esquema_free(es);
    return r;
}
