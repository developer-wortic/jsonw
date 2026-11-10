//! jsonW (json Wondrous) para Rust: Leitor e Escritor por cima da ABI C (libjsonw). Cada linha vai e volta como JSON.
//! ```ignore
//! let a = jsonw::Leitor::abrir("dados.jsw")?; for i in 0..a.linhas { let s = a.json(i)?; }
//! let mut w = jsonw::Escritor::criar("novo.jsw", "id:i64,nome:texto")?; w.gravar(r#"{"id":1,"nome":"x"}"#)?; w.fechar()?;
//! ```
use std::ffi::{c_char, c_int, c_void, CStr, CString};
mod ops;
mod visao;   /* Leitor::visao (ABI 1.2): src/visao.rs */
pub use ops::{escolher, Reconhecedor};   /* avaliar (em Leitor), escolher, Reconhecedor: src/ops.rs */

extern "C" {
    fn jsonw_versao() -> *const c_char;
    fn jsonw_abrir(caminho: *const c_char, erro: *mut c_char, nerro: usize) -> *mut c_void;
    fn jsonw_fechar(a: *mut c_void);
    fn jsonw_linhas(a: *const c_void) -> u64;
    fn jsonw_campos(a: *const c_void) -> c_int;
    fn jsonw_esquema(a: *const c_void) -> *const c_char;
    fn jsonw_campo_nome(a: *const c_void, campo: c_int) -> *const c_char;
    fn jsonw_linha_json(a: *mut c_void, linha: u64, saida: *mut c_char, cap: usize) -> i64;
    fn jsonw_linha_texto(a: *mut c_void, linha: u64, saida: *mut c_char, cap: usize) -> i64;
    fn jsonw_campo_json(a: *mut c_void, linha: u64, campo: c_int, saida: *mut c_char, cap: usize) -> i64;
    fn jsonw_conferir(a: *mut c_void, erro: *mut c_char, nerro: usize) -> c_int;
    fn jsonw_criar(caminho: *const c_char, esquema: *const c_char, erro: *mut c_char, nerro: usize) -> *mut c_void;
    fn jsonw_opcoes(w: *mut c_void, nivel: c_int, hash: c_int, bloco_kb: c_int) -> c_int;
    fn jsonw_gravar_json(w: *mut c_void, json: *const c_char, n: usize, erro: *mut c_char, nerro: usize) -> c_int;
    fn jsonw_descarregar(w: *mut c_void) -> c_int;
    fn jsonw_fechar_escritor(w: *mut c_void) -> c_int;
    fn jsonw_abandonar(w: *mut c_void) -> c_int;
}

#[derive(Debug)]
pub struct Erro(pub String);
impl std::fmt::Display for Erro { fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result { write!(f, "{}", self.0) } }
impl std::error::Error for Erro {}
impl Erro { pub fn oculta(&self) -> bool { self.0 == OCULTA } }   /* linha de outro tenant depois de visao() */
pub const OCULTA: &str = "linha oculta pela visao";

fn erro_de(buf: &[u8]) -> Erro { let n = buf.iter().position(|&b| b == 0).unwrap_or(buf.len()); Erro(String::from_utf8_lossy(&buf[..n]).into_owned()) }
pub fn versao() -> String { unsafe { CStr::from_ptr(jsonw_versao()).to_string_lossy().into_owned() } }

fn texto(mut f: impl FnMut(*mut c_char, usize) -> i64) -> Result<String, Erro> {
    let mut cap = 1usize << 16;
    loop {
        let mut b = vec![0u8; cap];
        let n = f(b.as_mut_ptr() as *mut c_char, cap);
        if n == -2 { cap *= 4; continue; }
        if n == -3 { return Err(Erro(OCULTA.into())); }
        if n < 0 { return Err(Erro("linha ou campo ilegivel".into())); }
        b.truncate(n as usize);
        return Ok(String::from_utf8(b).map_err(|e| Erro(e.to_string()))?);
    }
}

pub struct Leitor { pub(crate) a: *mut c_void, pub linhas: u64, pub esquema: String, pub campos: Vec<String> }
impl Leitor {
    pub fn abrir(caminho: &str) -> Result<Leitor, Erro> {
        let c = CString::new(caminho).map_err(|e| Erro(e.to_string()))?; let mut erro = [0u8; 200];
        let a = unsafe { jsonw_abrir(c.as_ptr(), erro.as_mut_ptr() as *mut c_char, 200) };
        if a.is_null() { return Err(erro_de(&erro)); }
        let linhas = unsafe { jsonw_linhas(a) };
        let esquema = unsafe { CStr::from_ptr(jsonw_esquema(a)) }.to_string_lossy().into_owned();
        let n = unsafe { jsonw_campos(a) };
        let campos = (0..n).map(|i| unsafe { CStr::from_ptr(jsonw_campo_nome(a, i)) }.to_string_lossy().into_owned()).collect();
        Ok(Leitor { a, linhas, esquema, campos })
    }
    pub fn json(&self, i: u64) -> Result<String, Erro> { texto(|b, cap| unsafe { jsonw_linha_json(self.a, i, b, cap) }) }
    pub fn texto(&self, i: u64) -> Result<String, Erro> { texto(|b, cap| unsafe { jsonw_linha_texto(self.a, i, b, cap) }) }
    pub fn campo(&self, i: u64, campo: usize) -> Result<String, Erro> { texto(|b, cap| unsafe { jsonw_campo_json(self.a, i, campo as c_int, b, cap) }) }
    pub fn conferir(&self) -> Result<(), Erro> {
        let mut erro = [0u8; 200];
        if unsafe { jsonw_conferir(self.a, erro.as_mut_ptr() as *mut c_char, 200) } != 0 { return Err(erro_de(&erro)); }
        Ok(())
    }
}
impl Drop for Leitor { fn drop(&mut self) { unsafe { jsonw_fechar(self.a) } } }

pub struct Escritor { w: *mut c_void }
impl Escritor {
    pub fn criar(caminho: &str, esquema: &str) -> Result<Escritor, Erro> {
        let c = CString::new(caminho).map_err(|e| Erro(e.to_string()))?; let e = CString::new(esquema).map_err(|e| Erro(e.to_string()))?; let mut erro = [0u8; 200];
        let w = unsafe { jsonw_criar(c.as_ptr(), e.as_ptr(), erro.as_mut_ptr() as *mut c_char, 200) };
        if w.is_null() { return Err(erro_de(&erro)); }
        Ok(Escritor { w })
    }
    pub fn opcoes(&mut self, compressao: i32, hash: i32, bloco_kb: i32) { unsafe { jsonw_opcoes(self.w, compressao, hash, bloco_kb); } }
    pub fn gravar(&mut self, json: &str) -> Result<(), Erro> {
        let mut erro = [0u8; 200];
        if unsafe { jsonw_gravar_json(self.w, json.as_ptr() as *const c_char, json.len(), erro.as_mut_ptr() as *mut c_char, 200) } != 0 { return Err(erro_de(&erro)); }
        Ok(())
    }
    pub fn descarregar(&mut self) { unsafe { jsonw_descarregar(self.w); } }
    /// Desiste: fecha sem publicar; o destino fica como estava (e o que acontece tambem quando o Escritor e largado sem fechar()).
    pub fn abandonar(mut self) { unsafe { jsonw_abandonar(self.w); } self.w = std::ptr::null_mut(); }
    pub fn fechar(mut self) -> Result<(), Erro> {
        let r = unsafe { jsonw_fechar_escritor(self.w) }; self.w = std::ptr::null_mut();
        if r != 0 { Err(Erro("nao gravou tudo".into())) } else { Ok(()) }
    }
}
/* largado sem fechar() (um `?` que saiu antes, um panico): ABANDONA. So fechar() publica; o arquivo pela metade nunca toma o
 * lugar do destino. */
impl Drop for Escritor { fn drop(&mut self) { if !self.w.is_null() { unsafe { jsonw_abandonar(self.w); } } } }
