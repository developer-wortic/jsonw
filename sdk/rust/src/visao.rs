//! a visao (ABI 1.2) para Rust: o servidor multi-tenant trava no Leitor o que a sessao ve ("pessoal vendas tenant:42") antes
//! de entrega-lo: esquema e campos so das colunas visiveis; linha de outro tenant = Erro com oculta() == true; avaliar recusa
//! campo escondido e so devolve linhas da sessao. Nao destrava.
use std::ffi::{c_char, c_int, c_void, CStr, CString};
use crate::{erro_de, Erro, Leitor};

extern "C" {
    fn jsonw_visao(a: *mut c_void, escopos: *const c_char, erro: *mut c_char, nerro: usize) -> c_int;
    fn jsonw_campos(a: *const c_void) -> c_int;
    fn jsonw_esquema(a: *const c_void) -> *const c_char;
    fn jsonw_campo_nome(a: *const c_void, campo: c_int) -> *const c_char;
}

impl Leitor {
    pub fn visao(&mut self, escopos: &str) -> Result<(), Erro> {
        let e = CString::new(escopos).map_err(|x| Erro(x.to_string()))?; let mut erro = [0u8; 300];
        if unsafe { jsonw_visao(self.a, e.as_ptr(), erro.as_mut_ptr() as *mut c_char, 300) } != 0 { return Err(erro_de(&erro)); }
        self.esquema = unsafe { CStr::from_ptr(jsonw_esquema(self.a)) }.to_string_lossy().into_owned();
        let n = unsafe { jsonw_campos(self.a) };
        self.campos = (0..n).map(|i| unsafe { CStr::from_ptr(jsonw_campo_nome(self.a, i)) }.to_string_lossy().into_owned()).collect();
        Ok(())
    }
}
