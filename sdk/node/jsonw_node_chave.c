/* jsonw_node_chave.c: BUSCAR POR CHAVE no addon N-API: indexar(leitor, campo), temIndice(leitor, campo) e
 * chave(leitor, campo, valorJson) -> Array de linhas em ordem. Registradas por jsonw_node_chave_registrar (jsonw_node.c). */
#include <node_api.h>
#include "../jsonw.h"
#include <stdlib.h>

static napi_value erro_js(napi_env env, const char *m) { napi_throw_error(env, NULL, m); return NULL; }
static void *ponteiro(napi_env env, napi_value v) { void *p = NULL; napi_get_value_external(env, v, &p); return p; }
static int32_t inteiro(napi_env env, napi_value v) { int32_t i = -1; napi_get_value_int32(env, v, &i); return i; }

static napi_value indexar(napi_env env, napi_callback_info info) {
    size_t argc = 2; napi_value argv[2]; napi_get_cb_info(env, info, &argc, argv, NULL, NULL);
    if (jsonw_indexar(ponteiro(env, argv[0]), inteiro(env, argv[1]))) return erro_js(env, "campo sem indice");
    return NULL;
}
static napi_value tem_indice(napi_env env, napi_callback_info info) {
    size_t argc = 2; napi_value argv[2], r; napi_get_cb_info(env, info, &argc, argv, NULL, NULL);
    napi_get_boolean(env, jsonw_tem_indice(ponteiro(env, argv[0]), inteiro(env, argv[1])) == 1, &r); return r;
}
static napi_value chave(napi_env env, napi_callback_info info) {
    size_t argc = 3, t = 0; napi_value argv[3], r; napi_get_cb_info(env, info, &argc, argv, NULL, NULL);
    napi_get_value_string_utf8(env, argv[2], NULL, 0, &t); char *v = malloc(t + 1); if (!v) return erro_js(env, "sem memoria");
    napi_get_value_string_utf8(env, argv[2], v, t + 1, &t);
    size_t cap = 16; uint64_t *out = NULL; int64_t n;
    for (;;) {
        uint64_t *novo = realloc(out, cap * sizeof *out); if (!novo) { free(out); free(v); return erro_js(env, "sem memoria"); } out = novo;
        n = jsonw_chave(ponteiro(env, argv[0]), inteiro(env, argv[1]), v, t, out, cap);
        if (n < 0 || (size_t)n <= cap) break;
        cap = (size_t)n;
    }
    free(v);
    if (n == -2) { free(out); return erro_js(env, "valor nao e do tipo do campo"); }
    if (n < 0) { free(out); return erro_js(env, "campo invalido"); }
    napi_create_array_with_length(env, (size_t)n, &r);
    for (int64_t i = 0; i < n; i++) { napi_value x; napi_create_double(env, (double)out[i], &x); napi_set_element(env, r, (uint32_t)i, x); }
    free(out); return r;
}

void jsonw_node_chave_registrar(napi_env env, napi_value exports) {
    struct { const char *n; napi_callback f; } F[] = {{"indexar", indexar}, {"temIndice", tem_indice}, {"chave", chave}};
    for (size_t i = 0; i < sizeof F / sizeof *F; i++) { napi_value fn; napi_create_function(env, F[i].n, NAPI_AUTO_LENGTH, F[i].f, NULL, &fn); napi_set_named_property(env, exports, F[i].n, fn); }
}
