/* jsonw_abi_int.h: o que os arquivos da ABI (jsonw_abi*.c) dividem: o leitor por tras do handle e a devolucao de texto
 * com o contrato de tamanho (-2 = cap curto). Nao vai ao pacote publico. */
#ifndef JSONW_ABI_INT_H
#define JSONW_ABI_INT_H
#include "jsonw.h"
#include "../lib/wjsw.h"

/* com_visao (jsonw_visao): o handle so ve o que os escopos permitem; sub/idx = as colunas visiveis, esq = o esquema delas */
/* chave (jsonw_abi_chave.c): o indice por valor de um campo, montado por jsonw_indexar; NULL enquanto nao ha */
/* mem (jsonw_abrir_memoria): a copia dos bytes do arquivo, do proprio leitor; NULL quando aberto pelo caminho */
typedef struct { JwArquivo a; JwArena ar; JwValor *c; JwCampo raiz; Buf o; JwVisao vis; int com_visao; int *idx; JwEsquema sub; Buf esq;
                 void *chave; void *mem; } Leitor;
void jsonw_indice_free(void *ix);

static inline int jsonw_ncampos(const Leitor *l) { return l->com_visao ? l->sub.n : l->a.e->n; }
static inline int jsonw_campo_real(const Leitor *l, int c) { return c < 0 || c >= jsonw_ncampos(l) ? -1 : l->com_visao ? l->idx[c] : c; }
static inline int jsonw_oculta(Leitor *l, uint64_t i) {   /* linha de outro tenant (ou sessao sem tenant num arquivo que separa) */
    if (!l->com_visao) return 0;
    int r = l->vis.fechado || !jw_linha_visivel(&l->vis, i, &l->ar); jw_arena_limpar(&l->ar); return r;
}

static inline void jsonw_falha(char *erro, size_t n, const char *m) { if (erro && n) snprintf(erro, n, "%s", m); }
static inline int64_t jsonw_devolver(const Buf *o, char *saida, size_t cap) {
    if (!saida || o->n + 1 > cap) return -2;
    if (o->n) memcpy(saida, o->p, o->n);
    saida[o->n] = 0; return (int64_t)o->n;
}
#endif
