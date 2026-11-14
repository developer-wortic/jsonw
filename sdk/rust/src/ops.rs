//! Avaliar (em `Leitor`), escolher e `Reconhecedor`. Pedido e resposta em JSON.

use std::ffi::c_void;

use crate::{Leitor, Resultado, com_erro, cstring, ffi, texto};

impl Leitor {
    /// As k melhores linhas pelo pedido (`{"pesos":..}`, `{"cosseno":..}`, `{"esparso":..}`, `{"grade":..}`):
    /// `[{"linha","nota"}]`.
    ///
    /// # Errors
    /// `Erro::Biblioteca` com o motivo, se o pedido é inválido ou cita campo escondido pela visão.
    pub fn avaliar(&self, pedido: &str, k: usize) -> Resultado<String> {
        let mut erro_da_biblioteca = None;
        let r = texto(|b, cap| {
            let (n, erro) = com_erro(|e, ne| unsafe {
                ffi::jsonw_avaliar(
                    self.a,
                    pedido.as_ptr().cast(),
                    pedido.len(),
                    k,
                    b,
                    cap,
                    e,
                    ne,
                )
            });
            if n == -1 {
                erro_da_biblioteca = Some(erro);
            }
            n
        });
        match erro_da_biblioteca {
            Some(erro) => Err(erro),
            None => r,
        }
    }
}

/// As posições das k maiores notas (maior primeiro; empate pela menor posição; NaN é a pior).
#[must_use]
pub fn escolher(notas: &[f64], k: usize) -> Vec<u64> {
    if notas.is_empty() || k == 0 {
        return Vec::new();
    }
    let mut out = vec![0u64; k];
    let m = unsafe { ffi::jsonw_escolher(notas.as_ptr(), notas.len(), k, out.as_mut_ptr()) };
    out.truncate(usize::try_from(m).unwrap_or(0));
    out
}

/// Tabela de termos (termo:texto,forma:dic,sinal:dic,peso:f32,idioma:dic,origem:dic) -> termos e sinais achados no texto.
pub struct Reconhecedor {
    r: *mut c_void,
}

impl Reconhecedor {
    /// # Errors
    /// O arquivo não existe ou não é uma tabela de termos.
    pub fn abrir(termos_jsw: &str) -> Resultado<Self> {
        let c = cstring(termos_jsw)?;
        let (r, erro) = com_erro(|e, n| unsafe { ffi::jsonw_reconhecedor(c.as_ptr(), e, n) });
        if r.is_null() {
            Err(erro)
        } else {
            Ok(Self { r })
        }
    }

    /// `{"termos":[{termo,ini,fim,texto,sinal,peso}],"sinais":[{sinal,soma,vezes}]}`
    ///
    /// # Errors
    /// `Erro::Ilegivel` se o reconhecedor não pôde ler o texto.
    pub fn reconhecer(&self, t: &str) -> Resultado<String> {
        texto(|b, cap| unsafe { ffi::jsonw_reconhecer(self.r, t.as_ptr().cast(), t.len(), b, cap) })
    }
}

impl Drop for Reconhecedor {
    fn drop(&mut self) {
        unsafe { ffi::jsonw_reconhecedor_fechar(self.r) }
    }
}
