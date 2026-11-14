//! jsonW para Rust: `Leitor` e `Escritor` por cima da ABI C (libjsonw). Cada linha vai e volta como JSON.
//!
//! ```ignore
//! let a = jsonw::Leitor::abrir("dados.jsw")?;
//! for i in 0..a.linhas { println!("{}", a.json(i)?); }
//!
//! let mut w = jsonw::Escritor::criar("novo.jsw", "id:i64,nome:texto")?;
//! w.gravar(r#"{"id":1,"nome":"x"}"#)?;
//! w.fechar()?;
//! ```

mod chave;
mod ffi;
mod ops;
mod visao;

use std::ffi::{CStr, CString, c_char, c_int, c_void};
use std::fmt;

pub use ops::{Reconhecedor, escolher};

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Erro {
    /// O texto que a biblioteca devolveu.
    Biblioteca(String),
    /// Linha de outro tenant depois de [`Leitor::visao`] (-3 na ABI).
    LinhaOculta,
    Ilegivel,
    /// Caminho, esquema ou escopo com um byte nulo no meio.
    NuloNoTexto,
}

impl fmt::Display for Erro {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Biblioteca(texto) => f.write_str(texto),
            Self::LinhaOculta => f.write_str("linha oculta pela visao"),
            Self::Ilegivel => f.write_str("linha ou campo ilegivel"),
            Self::NuloNoTexto => f.write_str("texto com byte nulo"),
        }
    }
}

impl std::error::Error for Erro {}

pub type Resultado<T> = Result<T, Erro>;

const TAMANHO_ERRO: usize = 320;

pub(crate) fn cstring(s: &str) -> Resultado<CString> {
    CString::new(s).map_err(|_| Erro::NuloNoTexto)
}

/// Texto C da biblioteca (estático ou do handle) como `String`.
pub(crate) fn de_c(p: *const c_char) -> String {
    if p.is_null() {
        String::new()
    } else {
        unsafe { CStr::from_ptr(p) }.to_string_lossy().into_owned()
    }
}

/// Chama com um buffer de erro; devolve o retorno e, se houve, o texto do erro.
pub(crate) fn com_erro<T>(chamada: impl FnOnce(*mut c_char, usize) -> T) -> (T, Erro) {
    let mut erro = [0u8; TAMANHO_ERRO];
    let r = chamada(erro.as_mut_ptr().cast(), TAMANHO_ERRO);
    let n = erro.iter().position(|&b| b == 0).unwrap_or(erro.len());
    (
        r,
        Erro::Biblioteca(String::from_utf8_lossy(&erro[..n]).into_owned()),
    )
}

/// Buffer que cresce até caber (-2 = curto).
pub(crate) fn texto(mut chamada: impl FnMut(*mut c_char, usize) -> i64) -> Resultado<String> {
    let mut cap = 1usize << 16;
    loop {
        let mut b = vec![0u8; cap];
        match chamada(b.as_mut_ptr().cast(), cap) {
            -2 => cap *= 4,
            -3 => return Err(Erro::LinhaOculta),
            ..0 => return Err(Erro::Ilegivel),
            n => {
                b.truncate(tamanho(n));
                return String::from_utf8(b).map_err(|_| Erro::Ilegivel);
            }
        }
    }
}

/// Posição de campo como o `int` da ABI.
pub(crate) fn campo_c(campo: usize) -> Resultado<c_int> {
    c_int::try_from(campo).map_err(|_| Erro::Biblioteca("campo invalido".into()))
}

/// Tamanho devolvido pela ABI (já sem os códigos negativos) como `usize`.
pub(crate) fn tamanho(n: i64) -> usize {
    usize::try_from(n).expect("a ABI so devolve tamanhos que cabem na memoria")
}

#[must_use]
pub fn versao() -> String {
    de_c(ffi::jsonw_versao())
}

pub struct Leitor {
    pub(crate) a: *mut c_void,
    pub linhas: u64,
    pub esquema: String,
    pub campos: Vec<String>,
}

impl Leitor {
    /// # Errors
    /// O arquivo não existe, não é jsonW ou está corrompido.
    pub fn abrir(caminho: &str) -> Resultado<Self> {
        let c = cstring(caminho)?;
        let (a, erro) = com_erro(|e, n| unsafe { ffi::jsonw_abrir(c.as_ptr(), e, n) });
        if a.is_null() {
            return Err(erro);
        }
        let mut leitor = Self {
            a,
            linhas: unsafe { ffi::jsonw_linhas(a) },
            esquema: String::new(),
            campos: Vec::new(),
        };
        leitor.ler_esquema();
        Ok(leitor)
    }

    pub(crate) fn ler_esquema(&mut self) {
        self.esquema = de_c(unsafe { ffi::jsonw_esquema(self.a) });
        let n = unsafe { ffi::jsonw_campos(self.a) };
        self.campos = (0..n)
            .map(|i| de_c(unsafe { ffi::jsonw_campo_nome(self.a, i) }))
            .collect();
    }

    /// # Errors
    /// `Erro::LinhaOculta` com visão; `Erro::Ilegivel` se a linha não pôde ser lida.
    pub fn json(&self, i: u64) -> Resultado<String> {
        texto(|b, cap| unsafe { ffi::jsonw_linha_json(self.a, i, b, cap) })
    }

    /// # Errors
    /// Os mesmos de [`Leitor::json`].
    pub fn texto(&self, i: u64) -> Resultado<String> {
        texto(|b, cap| unsafe { ffi::jsonw_linha_texto(self.a, i, b, cap) })
    }

    /// # Errors
    /// Os mesmos de [`Leitor::json`], e `Erro::Biblioteca` se o campo não existe.
    pub fn campo(&self, i: u64, campo: usize) -> Resultado<String> {
        let k = campo_c(campo)?;
        texto(|b, cap| unsafe { ffi::jsonw_campo_json(self.a, i, k, b, cap) })
    }

    /// # Errors
    /// `Erro::Biblioteca` se não há campo com esse nome.
    pub fn indice(&self, nome: &str) -> Resultado<usize> {
        self.campos
            .iter()
            .position(|c| c == nome)
            .ok_or_else(|| Erro::Biblioteca(format!("campo inexistente: {nome}")))
    }

    /// # Errors
    /// `Erro::Biblioteca` com o bloco que não confere (crc32c, hash ou a cadeia).
    pub fn conferir(&self) -> Resultado<()> {
        match com_erro(|e, n| unsafe { ffi::jsonw_conferir(self.a, e, n) }) {
            (0, _) => Ok(()),
            (_, erro) => Err(erro),
        }
    }
}

impl Drop for Leitor {
    fn drop(&mut self) {
        unsafe { ffi::jsonw_fechar(self.a) }
    }
}

/// O destino só aparece em [`Escritor::fechar`]. Largado sem fechar (um `?` que saiu antes, um pânico), abandona:
/// o arquivo pela metade nunca toma o lugar do destino.
pub struct Escritor {
    w: *mut c_void,
}

impl Escritor {
    /// # Errors
    /// Esquema inválido ou destino sem permissão de escrita.
    pub fn criar(caminho: &str, esquema: &str) -> Resultado<Self> {
        let (c, e) = (cstring(caminho)?, cstring(esquema)?);
        let (w, erro) = com_erro(|b, n| unsafe { ffi::jsonw_criar(c.as_ptr(), e.as_ptr(), b, n) });
        if w.is_null() {
            Err(erro)
        } else {
            Ok(Self { w })
        }
    }

    pub fn opcoes(&mut self, compressao: i32, hash: i32, bloco_kb: i32) {
        unsafe { ffi::jsonw_opcoes(self.w, compressao, hash, bloco_kb) };
    }

    /// # Errors
    /// `Erro::Biblioteca` se a linha não cabe no esquema.
    pub fn gravar(&mut self, json: &str) -> Resultado<()> {
        match com_erro(|e, n| unsafe {
            ffi::jsonw_gravar_json(self.w, json.as_ptr().cast(), json.len(), e, n)
        }) {
            (0, _) => Ok(()),
            (_, erro) => Err(erro),
        }
    }

    pub fn descarregar(&mut self) {
        unsafe { ffi::jsonw_descarregar(self.w) };
    }

    pub fn abandonar(mut self) {
        unsafe { ffi::jsonw_abandonar(std::mem::replace(&mut self.w, std::ptr::null_mut())) };
    }

    /// # Errors
    /// `Erro::Biblioteca` se o disco recusou o fim da gravação; o destino fica como estava.
    pub fn fechar(mut self) -> Resultado<()> {
        let w = std::mem::replace(&mut self.w, std::ptr::null_mut());
        match unsafe { ffi::jsonw_fechar_escritor(w) } {
            0 => Ok(()),
            _ => Err(Erro::Biblioteca("nao gravou tudo".into())),
        }
    }
}

impl Drop for Escritor {
    fn drop(&mut self) {
        if !self.w.is_null() {
            unsafe { ffi::jsonw_abandonar(self.w) };
        }
    }
}
