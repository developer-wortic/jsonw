/* jsonw_node_ops.c: as operacoes da ABI 1.1 no addon N-API (avaliar, escolher, reconhecedor, reconhecedorFechar,
 * reconhecer), registradas em exports por jsonw_node_ops_registrar (chamado de jsonw_node.c). Pedido e resposta em JSON. */
#include <node_api.h>
#include "../jsonw.h"
#include <stdlib.h>
#include <string.h>

static napi_value erro_js(napi_env env, const char *m) { napi_throw_error(env, NULL, m); return NULL; }
static char *texto_arg(napi_env env, napi_value v, size_t *n) {
    size_t t = 0; napi_get_value_string_utf8(env, v, NULL, 0, &t); char *s = malloc(t + 1); napi_get_value_string_utf8(env, v, s, t + 1, &t); if (n) *n = t; return s;
}
static void *ponteiro(napi_env env, napi_value v) { void *p = NULL; napi_get_value_external(env, v, &p); return p; }
static napi_value texto_js(napi_env env, const char *b, int64_t n) { napi_value r; napi_create_string_utf8(env, b, (size_t)n, &r); return r; }

static napi_value avaliar(napi_env env, napi_callback_info info) {   /* avaliar(leitor, pedidoJson, k) -> texto JSON */
    size_t argc = 3; napi_value argv[3]; napi_get_cb_info(env, info, &argc, argv, NULL, NULL);
    size_t n; char erro[300] = "", *p = texto_arg(env, argv[1], &n); double k = 10; if (argc > 2) napi_get_value_double(env, argv[2], &k);
    if (!(k >= 0)) k = 0;   /* negativo ou NaN: nada (a conversao para size_t seria indefinida) */
    size_t cap = 1 << 16; char *b = malloc(cap); int64_t r;
    while ((r = jsonw_avaliar(ponteiro(env, argv[0]), p, n, k > 9e15 ? (size_t)9e15 : (size_t)k, b, cap, erro, sizeof erro)) == -2) { cap *= 4; b = realloc(b, cap); }
    free(p); if (r < 0) { free(b); return erro_js(env, erro); }
    napi_value s = texto_js(env, b, r); free(b); return s;
}
static napi_value escolher(napi_env env, napi_callback_info info) {   /* escolher(Float64Array|Array, k) -> Array de posicoes */
    size_t argc = 2; napi_value argv[2], r; napi_get_cb_info(env, info, &argc, argv, NULL, NULL);
    uint32_t n = 0; napi_get_array_length(env, argv[0], &n); double k = 1; napi_get_value_double(env, argv[1], &k);
    bool tipado = false; napi_is_typedarray(env, argv[0], &tipado);
    double *v = malloc((n ? n : 1) * sizeof *v);
    if (tipado) { napi_typedarray_type t; size_t len; void *d; napi_get_typedarray_info(env, argv[0], &t, &len, &d, NULL, NULL); n = (uint32_t)len; v = realloc(v, (len ? len : 1) * sizeof *v); for (size_t i = 0; i < len; i++) v[i] = t == napi_float64_array ? ((double *)d)[i] : t == napi_float32_array ? ((float *)d)[i] : 0; }
    else for (uint32_t i = 0; i < n; i++) { napi_value e; napi_get_element(env, argv[0], i, &e); napi_get_value_double(env, e, &v[i]); }
    size_t kk = !(k >= 0) ? 0 : k > (double)n ? n : (size_t)k;   /* k negativo, NaN ou maior que n: no maximo n posicoes (k gigante pedia memoria que nao existe) */
    uint64_t *out = malloc((kk ? kk : 1) * sizeof *out);
    int64_t m = jsonw_escolher(v, n, kk, out);
    napi_create_array(env, &r); for (int64_t i = 0; i < m; i++) { napi_value x; napi_create_double(env, (double)out[i], &x); napi_set_element(env, r, (uint32_t)i, x); }
    free(v); free(out); return r;
}
static napi_value reconhecedor(napi_env env, napi_callback_info info) {
    size_t argc = 1; napi_value argv[1]; napi_get_cb_info(env, info, &argc, argv, NULL, NULL);
    char erro[300] = "", *cam = texto_arg(env, argv[0], NULL); void *r = jsonw_reconhecedor(cam, erro, sizeof erro); free(cam);
    if (!r) return erro_js(env, erro);
    napi_value ext; napi_create_external(env, r, NULL, NULL, &ext); return ext;
}
static napi_value reconhecedor_fechar(napi_env env, napi_callback_info info) { size_t argc = 1; napi_value argv[1]; napi_get_cb_info(env, info, &argc, argv, NULL, NULL); jsonw_reconhecedor_fechar(ponteiro(env, argv[0])); return NULL; }
static napi_value reconhecer(napi_env env, napi_callback_info info) {   /* reconhecer(r, texto) -> texto JSON */
    size_t argc = 2; napi_value argv[2]; napi_get_cb_info(env, info, &argc, argv, NULL, NULL);
    size_t n; char *t = texto_arg(env, argv[1], &n); size_t cap = 1 << 16; char *b = malloc(cap); int64_t r;
    while ((r = jsonw_reconhecer(ponteiro(env, argv[0]), t, n, b, cap)) == -2) { cap *= 4; b = realloc(b, cap); }
    free(t); if (r < 0) { free(b); return erro_js(env, "reconhecedor fechado"); }
    napi_value s = texto_js(env, b, r); free(b); return s;
}

void jsonw_node_ops_registrar(napi_env env, napi_value exports) {
    struct { const char *n; napi_callback f; } F[] = {{"avaliar", avaliar}, {"escolher", escolher}, {"reconhecedor", reconhecedor}, {"reconhecedorFechar", reconhecedor_fechar}, {"reconhecer", reconhecer}};
    for (size_t i = 0; i < sizeof F / sizeof *F; i++) { napi_value fn; napi_create_function(env, F[i].n, NAPI_AUTO_LENGTH, F[i].f, NULL, &fn); napi_set_named_property(env, exports, F[i].n, fn); }
}
