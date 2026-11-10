/* jsonw_node.c: jsonW para Node.js como addon N-API (sem node-gyp: `make node` na pasta sdk compila com o cc). Exposto em
 * index.js como Leitor/Escritor; cada linha vai e volta como JSON. */
#include <node_api.h>
#include "../jsonw.h"
#include <stdlib.h>
#include <string.h>

static napi_value erro_js(napi_env env, const char *m) { napi_throw_error(env, NULL, m); return NULL; }
static char *texto_arg(napi_env env, napi_value v, size_t *n) {
    size_t t = 0; napi_get_value_string_utf8(env, v, NULL, 0, &t); char *s = malloc(t + 1); napi_get_value_string_utf8(env, v, s, t + 1, &t); if (n) *n = t; return s;
}
static void *ponteiro(napi_env env, napi_value v) { void *p = NULL; napi_get_value_external(env, v, &p); return p; }

static napi_value abrir(napi_env env, napi_callback_info info) {
    size_t argc = 1; napi_value argv[1]; napi_get_cb_info(env, info, &argc, argv, NULL, NULL);
    char erro[200] = "", *cam = texto_arg(env, argv[0], NULL); void *a = jsonw_abrir(cam, erro, sizeof erro); free(cam);
    if (!a) return erro_js(env, erro);
    napi_value ext; napi_create_external(env, a, NULL, NULL, &ext); return ext;
}
static napi_value fechar(napi_env env, napi_callback_info info) { size_t argc = 1; napi_value argv[1]; napi_get_cb_info(env, info, &argc, argv, NULL, NULL); jsonw_fechar(ponteiro(env, argv[0])); return NULL; }
static napi_value linhas(napi_env env, napi_callback_info info) { size_t argc = 1; napi_value argv[1], r; napi_get_cb_info(env, info, &argc, argv, NULL, NULL); napi_create_double(env, (double)jsonw_linhas(ponteiro(env, argv[0])), &r); return r; }
static napi_value esquema(napi_env env, napi_callback_info info) { size_t argc = 1; napi_value argv[1], r; napi_get_cb_info(env, info, &argc, argv, NULL, NULL); napi_create_string_utf8(env, jsonw_esquema(ponteiro(env, argv[0])), NAPI_AUTO_LENGTH, &r); return r; }
static napi_value campos(napi_env env, napi_callback_info info) {
    size_t argc = 1; napi_value argv[1], r; napi_get_cb_info(env, info, &argc, argv, NULL, NULL); void *a = ponteiro(env, argv[0]);
    napi_create_array(env, &r);
    for (int i = 0; i < jsonw_campos(a); i++) { napi_value s; napi_create_string_utf8(env, jsonw_campo_nome(a, i), NAPI_AUTO_LENGTH, &s); napi_set_element(env, r, (uint32_t)i, s); }
    return r;
}
static napi_value linha_modo(napi_env env, napi_callback_info info, int modo) {
    size_t argc = 3; napi_value argv[3], r; napi_get_cb_info(env, info, &argc, argv, NULL, NULL); void *a = ponteiro(env, argv[0]);
    double i; napi_get_value_double(env, argv[1], &i); int campo = -1; if (argc > 2 && modo == 2) { napi_get_value_int32(env, argv[2], &campo); }
    if (!a) return erro_js(env, "leitor fechado");   /* usar depois do fechar() e erro de quem chama, nao queda do processo */
    if (!(i >= 0)) return erro_js(env, "linha invalida");
    size_t cap = 1 << 16; char *b = malloc(cap); int64_t n;
    for (;;) {
        n = modo == 0 ? jsonw_linha_json(a, (uint64_t)i, b, cap) : modo == 1 ? jsonw_linha_texto(a, (uint64_t)i, b, cap) : jsonw_campo_json(a, (uint64_t)i, campo, b, cap);
        if (n != -2) break;
        cap *= 4; b = realloc(b, cap);
    }
    if (n == -3) { free(b); napi_throw_error(env, "OCULTA", "linha oculta pela visao"); return NULL; }   /* outro tenant (depois de visao) */
    if (n < 0) { free(b); return erro_js(env, "linha ou campo ilegivel"); }
    napi_create_string_utf8(env, b, (size_t)n, &r); free(b); return r;
}
static napi_value linha_json(napi_env env, napi_callback_info info) { return linha_modo(env, info, 0); }
static napi_value linha_texto(napi_env env, napi_callback_info info) { return linha_modo(env, info, 1); }
static napi_value campo_json(napi_env env, napi_callback_info info) { return linha_modo(env, info, 2); }
static napi_value conferir(napi_env env, napi_callback_info info) {
    size_t argc = 1; napi_value argv[1], r; napi_get_cb_info(env, info, &argc, argv, NULL, NULL); char erro[200] = "";
    if (jsonw_conferir(ponteiro(env, argv[0]), erro, sizeof erro)) return erro_js(env, erro);
    napi_get_boolean(env, true, &r); return r;
}
static napi_value visao(napi_env env, napi_callback_info info) {   /* visao(leitor, escopos): trava o que a sessao ve */
    size_t argc = 2; napi_value argv[2]; napi_get_cb_info(env, info, &argc, argv, NULL, NULL); char erro[300] = "", *e = texto_arg(env, argv[1], NULL);
    int r = jsonw_visao(ponteiro(env, argv[0]), e, erro, sizeof erro); free(e);
    return r ? erro_js(env, erro) : NULL;
}
static napi_value criar(napi_env env, napi_callback_info info) {
    size_t argc = 5; napi_value argv[5]; napi_get_cb_info(env, info, &argc, argv, NULL, NULL);
    char erro[200] = "", *cam = texto_arg(env, argv[0], NULL), *esq = texto_arg(env, argv[1], NULL);
    void *w = jsonw_criar(cam, esq, erro, sizeof erro); free(cam); free(esq);
    if (!w) return erro_js(env, erro);
    int nivel = 1, hash = 0, bloco = 0;
    if (argc > 2) napi_get_value_int32(env, argv[2], &nivel); if (argc > 3) napi_get_value_int32(env, argv[3], &hash); if (argc > 4) napi_get_value_int32(env, argv[4], &bloco);
    jsonw_opcoes(w, nivel, hash, bloco);
    napi_value ext; napi_create_external(env, w, NULL, NULL, &ext); return ext;
}
static napi_value gravar(napi_env env, napi_callback_info info) {
    size_t argc = 2; napi_value argv[2]; napi_get_cb_info(env, info, &argc, argv, NULL, NULL);
    size_t n; char erro[200] = "", *s = texto_arg(env, argv[1], &n); int r = jsonw_gravar_json(ponteiro(env, argv[0]), s, n, erro, sizeof erro); free(s);
    if (r) return erro_js(env, erro);
    return NULL;
}
static napi_value descarregar(napi_env env, napi_callback_info info) { size_t argc = 1; napi_value argv[1]; napi_get_cb_info(env, info, &argc, argv, NULL, NULL); jsonw_descarregar(ponteiro(env, argv[0])); return NULL; }
static napi_value fechar_escritor(napi_env env, napi_callback_info info) {
    size_t argc = 1; napi_value argv[1]; napi_get_cb_info(env, info, &argc, argv, NULL, NULL);
    if (jsonw_fechar_escritor(ponteiro(env, argv[0]))) return erro_js(env, "nao gravou tudo");
    return NULL;
}
static napi_value abandonar(napi_env env, napi_callback_info info) {   /* desiste: fecha sem publicar; o destino fica como estava */
    size_t argc = 1; napi_value argv[1]; napi_get_cb_info(env, info, &argc, argv, NULL, NULL);
    jsonw_abandonar(ponteiro(env, argv[0])); return NULL;
}
static napi_value versao(napi_env env, napi_callback_info info) { (void)info; napi_value r; napi_create_string_utf8(env, jsonw_versao(), NAPI_AUTO_LENGTH, &r); return r; }

static napi_value iniciar(napi_env env, napi_value exports) {
    struct { const char *n; napi_callback f; } F[] = {{"abrir", abrir}, {"fechar", fechar}, {"linhas", linhas}, {"esquema", esquema}, {"campos", campos},
        {"linhaJson", linha_json}, {"linhaTexto", linha_texto}, {"campoJson", campo_json}, {"conferir", conferir}, {"visao", visao}, {"criar", criar}, {"gravar", gravar},
        {"descarregar", descarregar}, {"fecharEscritor", fechar_escritor}, {"abandonar", abandonar}, {"versao", versao}};
    for (size_t i = 0; i < sizeof F / sizeof *F; i++) { napi_value fn; napi_create_function(env, F[i].n, NAPI_AUTO_LENGTH, F[i].f, NULL, &fn); napi_set_named_property(env, exports, F[i].n, fn); }
    { void jsonw_node_ops_registrar(napi_env, napi_value); jsonw_node_ops_registrar(env, exports); }   /* avaliar, escolher, reconhecer (jsonw_node_ops.c) */
    return exports;
}
NAPI_MODULE(jsonw, iniciar)
