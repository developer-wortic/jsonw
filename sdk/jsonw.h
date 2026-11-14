/* jsonw.h: a ABI C estavel do jsonW (json Wondrous, jsonw.org) para os SDKs de outras linguagens. So tipos simples: handle
 * opaco, texto, inteiros. Cada linha entra e sai como JSON (ou jsonW-texto) UTF-8; esta e a interface publica inteira, e por
 * cima dela estao os SDKs de cada linguagem. Toda funcao que falha devolve -1 (ou NULL) e poe a razao em `erro` (UTF-8, terminado em 0).
 * Tamanhos e contagens voltam em int64_t (1.2.1): o mesmo tamanho em todo sistema (o `long` de antes tem 32 bits no Windows e
 * 64 no Linux e no macOS; quem ja ligou com a versao anterior continua funcionando). Handle NULL (ou ja fechado e zerado por
 * quem chama) nunca derruba o processo: a funcao devolve erro. */
#ifndef JSONW_H
#define JSONW_H
#include <stddef.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
#define JSONW_VERSAO "1.3.12"
#ifndef JSONW_API
#  if defined(_WIN32)
#    define JSONW_API __declspec(dllexport)
#  else
#    define JSONW_API __attribute__((visibility("default")))
#  endif
#endif
JSONW_API const char *jsonw_versao(void);

/* ler */
JSONW_API void *jsonw_abrir(const char *caminho, char *erro, size_t nerro);          /* mmap; NULL se nao abriu */
JSONW_API void jsonw_fechar(void *a);
JSONW_API uint64_t jsonw_linhas(const void *a);
JSONW_API int jsonw_campos(const void *a);
JSONW_API const char *jsonw_esquema(const void *a);                                   /* texto canonico do esquema */
JSONW_API const char *jsonw_campo_nome(const void *a, int campo);
JSONW_API int64_t jsonw_linha_json(void *a, uint64_t linha, char *saida, size_t cap);   /* a linha como JSON; devolve o tamanho (sem o 0), -1 = erro, -2 = cap curto (chame de novo com cap maior), -3 = linha que a visao esconde */
JSONW_API int64_t jsonw_linha_texto(void *a, uint64_t linha, char *saida, size_t cap);  /* idem em jsonW-texto */
JSONW_API int64_t jsonw_campo_json(void *a, uint64_t linha, int campo, char *saida, size_t cap);   /* so um campo (acesso direto, sem decodificar o resto) */
JSONW_API int jsonw_conferir(void *a, char *erro, size_t nerro);                       /* crc32c + hash de cada bloco e a cadeia do arquivo */
/* visao (1.2): servidor multi-tenant trava no handle o que a sessao pode ver ("pessoal vendas tenant:42") ANTES de entrega-lo.
 * Dali em diante campos/esquema/nomes sao so das colunas visiveis, linha de outro tenant devolve -3, avaliar recusa campo
 * escondido e grade e so devolve linhas da sessao. Nao destrava (de novo = -1). Sem chamar: o arquivo inteiro, como antes.
 * O tenant e um numero inteiro (coluna i64 chamada tenant ou tenant_id, ou marcada +tenant); coluna tenant de texto nao separa
 * nada e fecha a visao: nenhuma linha sai (so "tenant:todos" abre). */
JSONW_API int jsonw_visao(void *a, const char *escopos, char *erro, size_t nerro);

/* gravar (arquivo novo, troca atomica no fechar) */
JSONW_API void *jsonw_criar(const char *caminho, const char *esquema, char *erro, size_t nerro);
JSONW_API int jsonw_opcoes(void *w, int nivel_compressao, int hash_alg, int bloco_kb);  /* 0..2; 0 sha256 / 1 blake3; bloco em KiB (0 = padrao 1 MiB) */
JSONW_API int jsonw_gravar_json(void *w, const char *json, size_t n, char *erro, size_t nerro);   /* uma linha em JSON ou jsonW-texto */
JSONW_API int jsonw_descarregar(void *w);
JSONW_API int jsonw_fechar_escritor(void *w);                                          /* 0 = tudo gravado e o arquivo no lugar */
JSONW_API int jsonw_abandonar(void *w);   /* (1.2.1) desiste: fecha SEM publicar; o destino fica como estava (ou nao aparece). Para quem sai por erro no meio da gravacao */

/* texto: validar e converter sem arquivo */
JSONW_API int64_t jsonw_texto_para_json(const char *esquema, const char *texto, size_t n, char *saida, size_t cap, char *erro, size_t nerro);

/* operacoes (1.1): pedido e resposta em JSON; saida curta devolve -2 (chame de novo com cap maior), erro -1 com a razao */
JSONW_API int64_t jsonw_avaliar(void *a, const char *pedido, size_t n, size_t k, char *saida, size_t cap, char *erro, size_t nerro);
   /* AVALIAR + ESCOLHER: pedido {"pesos":{"campo":peso,..}} | {"cosseno":{"campo":"v","consulta":[..]}} (coluna vf32, vf16, vq8 ou vq4)
    * | {"esparso":{"campo":"m","consulta":{"indice":peso}}} | {"grade":{"campos":[..],"arquivo":"g.jsw","linha":0,"campo":"g","saida":0}}
    * (+ "threads":n); saida = as k melhores linhas, [{"linha":4,"nota":2.5},...], da maior nota para a menor (empate: linha menor).
    * Le so as colunas do pedido, em paralelo. */
JSONW_API int64_t jsonw_escolher(const double *notas, size_t n, size_t k, uint64_t *linhas);   /* ESCOLHER das suas notas: linhas[min(k, n)] recebe as posicoes das k maiores; devolve quantas */
JSONW_API void *jsonw_reconhecedor(const char *termos_jsw, char *erro, size_t nerro);        /* RECONHECER: tabela de termos (termo:texto,forma:dic,sinal:dic,peso:f32,idioma:dic,origem:dic) -> reconhecedor */
JSONW_API void jsonw_reconhecedor_fechar(void *r);
JSONW_API int64_t jsonw_reconhecer(void *r, const char *texto, size_t n, char *saida, size_t cap);
   /* {"termos":[{"termo":linha,"ini":..,"fim":..,"texto":"..","sinal":"..","peso":..}],"sinais":[{"sinal":"..","soma":..,"vezes":..}]} (sinais da maior soma para a menor) */

/* sinais da comunicacao (1.3.0, recursos 16 e 17): mede COMO a pessoa falou ou escreveu; cada medida sai como UMA linha de
 * jsonW-texto no esquema de jsonw_sinal_esquema (gravavel direto com jsonw_gravar_json). Saida curta -2, erro -1. */
#define JSONW_SINAL_AUDIO 16
#define JSONW_SINAL_TEXTO 17
JSONW_API const char *jsonw_sinal_esquema(int qual);   /* JSONW_SINAL_AUDIO ou JSONW_SINAL_TEXTO; NULL se outro */
JSONW_API int64_t jsonw_sinal_audio(const int16_t *pcm, size_t n, int taxa, const char *origem, const char *chave, char *saida, size_t cap, char *erro, size_t nerro);
   /* PCM 16 bits mono, n amostras, taxa em Hz: duracao, pausas, articulacao, intensidade, F0, jitter, shimmer, HNR, formantes,
    * MFCC (vf32[13]), centroide, respiracoes (algoritmos do Praat/eGeMAPS, em C). Medida que nao existe sai null. */
JSONW_API int64_t jsonw_sinal_texto(const char *texto, size_t n, const char *lexico_jsw, const char *origem, const char *chave, char *saida, size_t cap, char *erro, size_t nerro);
   /* UTF-8: forma (caixa alta, pontuacao, emoji, kaomoji, repeticao), lexico (lexico-pt.jsw pelo RECONHECER: intensificadores,
    * polaridade, negacao, pronomes, passiva, disfluencias) e indicios de ironia; lexico_jsw NULL = so a forma */

/* video (1.3.0, recurso 18): quem chama decodifica e entrega os quadros em RGB24 (na cadencia que quiser; 2 por segundo
 * basta) e o som em PCM 16 bits mono. O jsonW corta as cenas (Otsu sobre a diferenca entre quadros, so se a serie for
 * bimodal), mede cada cena (luz, contraste, saturacao, movimento, cores vf32[12], forma vf32[64] para cosseno, dHash e os
 * sinais do audio do trecho) e monta o mosaico dos quadros de cada cena. */
#define JSONW_SINAL_VIDEO 18
JSONW_API void *jsonw_video_novo(int largura, int altura, double fps, char *erro, size_t nerro);
JSONW_API int jsonw_video_quadro(void *v, const uint8_t *rgb, size_t passo);          /* passo = bytes por linha (0 = 3*largura); 0 = ok */
JSONW_API int jsonw_video_audio(void *v, const int16_t *pcm, size_t n, int taxa);     /* o tempo 0 e o do 1o quadro; 0 = ok */
JSONW_API int64_t jsonw_video_cenas(void *v);                                          /* corta e devolve quantas cenas */
JSONW_API int64_t jsonw_video_cena(void *v, int64_t cena, const char *origem, const char *chave, char *saida, size_t cap);   /* a cena como UMA linha de jsonW-texto (esquema 18) */
JSONW_API int64_t jsonw_video_mosaico(void *v, int64_t cena, int colunas, int linhas, uint8_t *rgb, size_t cap, int *largura, int *altura);
   /* RGB24 da grade colunas x linhas (miniaturas de 160 px, borda branca de 4 px); devolve os bytes, -2 com cap curto (largura e altura ja vem) */
JSONW_API void jsonw_video_fechar(void *v);
#ifdef __cplusplus
}
#endif
#endif
