//! As operacoes da ABI 1.1: AVALIAR + ESCOLHER (pedido em JSON -> as k melhores), ESCOLHER das suas notas e RECONHECER
//! (tabela de termos -> Reconhecedor; texto -> termos e sinais). Pedido e resposta em JSON (texto).
use crate::{erro_de, texto, Erro, Leitor};
use std::ffi::{c_char, c_void, CString};

extern "C" {
    fn jsonw_avaliar(a: *mut c_void, pedido: *const c_char, n: usize, k: usize, saida: *mut c_char, cap: usize, erro: *mut c_char, nerro: usize) -> i64;
    fn jsonw_escolher(notas: *const f64, n: usize, k: usize, linhas: *mut u64) -> i64;
    fn jsonw_reconhecedor(termos: *const c_char, erro: *mut c_char, nerro: usize) -> *mut c_void;
    fn jsonw_reconhecedor_fechar(r: *mut c_void);
    fn jsonw_reconhecer(r: *mut c_void, texto: *const c_char, n: usize, saida: *mut c_char, cap: usize) -> i64;
}

impl Leitor {
    /// Pedido `{"pesos":{..}}` | `{"cosseno":{..}}` | `{"esparso":{..}}` | `{"grade":{..}}`; devolve `[{"linha","nota"}]` das k melhores.
    pub fn avaliar(&self, pedido: &str, k: usize) -> Result<String, Erro> {
        let mut erro = [0u8; 300];
        let r = texto(|b, cap| unsafe { jsonw_avaliar(self.a, pedido.as_ptr() as *const c_char, pedido.len(), k, b, cap, erro.as_mut_ptr() as *mut c_char, 300) });
        if r.is_err() && erro[0] != 0 { return Err(erro_de(&erro)); }
        r
    }
}

/// Posicoes das k maiores notas (maior primeiro; empate pela menor posicao; NaN e a pior).
pub fn escolher(notas: &[f64], k: usize) -> Vec<u64> {
    if notas.is_empty() || k == 0 { return Vec::new(); }
    let mut out = vec![0u64; k];
    let m = unsafe { jsonw_escolher(notas.as_ptr(), notas.len(), k, out.as_mut_ptr()) };
    out.truncate(if m < 0 { 0 } else { m as usize });
    out
}

/// Tabela de termos (termo:texto,forma:dic,sinal:dic,peso:f32,idioma:dic,origem:dic) -> reconhecedor.
pub struct Reconhecedor { r: *mut c_void }
impl Reconhecedor {
    pub fn abrir(termos_jsw: &str) -> Result<Reconhecedor, Erro> {
        let c = CString::new(termos_jsw).map_err(|e| Erro(e.to_string()))?; let mut erro = [0u8; 300];
        let r = unsafe { jsonw_reconhecedor(c.as_ptr(), erro.as_mut_ptr() as *mut c_char, 300) };
        if r.is_null() { return Err(erro_de(&erro)); }
        Ok(Reconhecedor { r })
    }
    /// `{"termos":[{termo,ini,fim,texto,sinal,peso}],"sinais":[{sinal,soma,vezes}]}`
    pub fn reconhecer(&self, t: &str) -> Result<String, Erro> {
        texto(|b, cap| unsafe { jsonw_reconhecer(self.r, t.as_ptr() as *const c_char, t.len(), b, cap) })
    }
}
impl Drop for Reconhecedor { fn drop(&mut self) { unsafe { jsonw_reconhecedor_fechar(self.r) } } }
