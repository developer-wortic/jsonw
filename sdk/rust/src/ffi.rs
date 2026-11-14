//! A ABI C (jsonw.h), num lugar só.

use std::ffi::{c_char, c_int, c_void};

unsafe extern "C" {
    pub safe fn jsonw_versao() -> *const c_char;
    pub fn jsonw_abrir(caminho: *const c_char, erro: *mut c_char, nerro: usize) -> *mut c_void;
    pub fn jsonw_fechar(a: *mut c_void);
    pub fn jsonw_linhas(a: *const c_void) -> u64;
    pub fn jsonw_campos(a: *const c_void) -> c_int;
    pub fn jsonw_esquema(a: *const c_void) -> *const c_char;
    pub fn jsonw_campo_nome(a: *const c_void, campo: c_int) -> *const c_char;
    pub fn jsonw_linha_json(a: *mut c_void, linha: u64, saida: *mut c_char, cap: usize) -> i64;
    pub fn jsonw_linha_texto(a: *mut c_void, linha: u64, saida: *mut c_char, cap: usize) -> i64;
    pub fn jsonw_campo_json(
        a: *mut c_void,
        linha: u64,
        campo: c_int,
        saida: *mut c_char,
        cap: usize,
    ) -> i64;
    pub fn jsonw_conferir(a: *mut c_void, erro: *mut c_char, nerro: usize) -> c_int;
    pub fn jsonw_visao(
        a: *mut c_void,
        escopos: *const c_char,
        erro: *mut c_char,
        nerro: usize,
    ) -> c_int;
    pub fn jsonw_indexar(a: *mut c_void, campo: c_int) -> c_int;
    pub fn jsonw_tem_indice(a: *const c_void, campo: c_int) -> c_int;
    pub fn jsonw_chave(
        a: *mut c_void,
        campo: c_int,
        valor: *const c_char,
        n: usize,
        linhas: *mut u64,
        max: usize,
    ) -> i64;
    pub fn jsonw_criar(
        caminho: *const c_char,
        esquema: *const c_char,
        erro: *mut c_char,
        nerro: usize,
    ) -> *mut c_void;
    pub fn jsonw_opcoes(w: *mut c_void, nivel: c_int, hash: c_int, bloco_kb: c_int) -> c_int;
    pub fn jsonw_gravar_json(
        w: *mut c_void,
        json: *const c_char,
        n: usize,
        erro: *mut c_char,
        nerro: usize,
    ) -> c_int;
    pub fn jsonw_descarregar(w: *mut c_void) -> c_int;
    pub fn jsonw_fechar_escritor(w: *mut c_void) -> c_int;
    pub fn jsonw_abandonar(w: *mut c_void) -> c_int;
    pub fn jsonw_avaliar(
        a: *mut c_void,
        pedido: *const c_char,
        n: usize,
        k: usize,
        saida: *mut c_char,
        cap: usize,
        erro: *mut c_char,
        nerro: usize,
    ) -> i64;
    pub fn jsonw_escolher(notas: *const f64, n: usize, k: usize, linhas: *mut u64) -> i64;
    pub fn jsonw_reconhecedor(
        termos: *const c_char,
        erro: *mut c_char,
        nerro: usize,
    ) -> *mut c_void;
    pub fn jsonw_reconhecedor_fechar(r: *mut c_void);
    pub fn jsonw_reconhecer(
        r: *mut c_void,
        texto: *const c_char,
        n: usize,
        saida: *mut c_char,
        cap: usize,
    ) -> i64;
}
