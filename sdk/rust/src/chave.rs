//! BUSCAR POR CHAVE (ABI 1.3.13) para Rust: as linhas em que um campo vale um valor (JSON do tipo do campo: "7", "\"RJ\""),
//! em ordem. Com indexar(campo), busca binaria no indice, sem varrer; sem indice, varre (tem_indice diz qual).
//!     a.indexar(0)?; let linhas = a.chave(0, "7")?;
use std::ffi::{c_char, c_int, c_void};
use crate::{Erro, Leitor};

extern "C" {
    fn jsonw_indexar(a: *mut c_void, campo: c_int) -> c_int;
    fn jsonw_tem_indice(a: *const c_void, campo: c_int) -> c_int;
    fn jsonw_chave(a: *mut c_void, campo: c_int, valor: *const c_char, n: usize, linhas: *mut u64, max: usize) -> i64;
}

impl Leitor {
    /// Monta o indice do campo neste leitor (troca o de outro campo).
    pub fn indexar(&mut self, campo: usize) -> Result<(), Erro> {
        if unsafe { jsonw_indexar(self.a, campo as c_int) } != 0 { return Err(Erro("campo sem indice".into())); }
        Ok(())
    }
    /// O campo ja tem indice neste leitor.
    pub fn tem_indice(&self, campo: usize) -> bool { unsafe { jsonw_tem_indice(self.a, campo as c_int) == 1 } }
    /// As linhas em que o campo vale `valor` (o JSON do valor, no tipo do campo), em ordem crescente.
    pub fn chave(&self, campo: usize, valor: &str) -> Result<Vec<u64>, Erro> {
        let mut v = vec![0u64; 16];
        loop {
            let n = unsafe { jsonw_chave(self.a, campo as c_int, valor.as_ptr() as *const c_char, valor.len(), v.as_mut_ptr(), v.len()) };
            if n == -2 { return Err(Erro("valor nao e do tipo do campo".into())); }
            if n < 0 { return Err(Erro("campo invalido".into())); }
            if n as usize <= v.len() { v.truncate(n as usize); return Ok(v); }
            v = vec![0u64; n as usize];
        }
    }
}
