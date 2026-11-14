//! Busca por chave: as linhas em que um campo vale um valor (o JSON do valor no tipo do campo: "7", "\"RJ\""), em ordem.
//! Com `indexar(campo)`, busca binária no índice; sem índice, varre.

use crate::{Erro, Leitor, Resultado, campo_c, ffi, tamanho};

impl Leitor {
    /// Monta o índice do campo neste leitor (troca o de outro campo).
    ///
    /// # Errors
    /// `Erro::Biblioteca` se o campo não existe ou não aceita índice.
    pub fn indexar(&mut self, campo: usize) -> Resultado<()> {
        match unsafe { ffi::jsonw_indexar(self.a, campo_c(campo)?) } {
            0 => Ok(()),
            _ => Err(Erro::Biblioteca("campo sem indice".into())),
        }
    }

    #[must_use]
    pub fn tem_indice(&self, campo: usize) -> bool {
        campo_c(campo).is_ok_and(|k| unsafe { ffi::jsonw_tem_indice(self.a, k) } == 1)
    }

    /// As linhas em que o campo vale `valor`, em ordem crescente.
    ///
    /// # Errors
    /// `Erro::Biblioteca` se o campo não existe ou se `valor` não é do tipo do campo.
    pub fn chave(&self, campo: usize, valor: &str) -> Resultado<Vec<u64>> {
        let k = campo_c(campo)?;
        let mut v = vec![0u64; 16];
        loop {
            let n = unsafe {
                ffi::jsonw_chave(
                    self.a,
                    k,
                    valor.as_ptr().cast(),
                    valor.len(),
                    v.as_mut_ptr(),
                    v.len(),
                )
            };
            match n {
                -2 => return Err(Erro::Biblioteca("valor nao e do tipo do campo".into())),
                ..0 => return Err(Erro::Biblioteca("campo invalido".into())),
                n if tamanho(n) <= v.len() => {
                    v.truncate(tamanho(n));
                    return Ok(v);
                }
                n => v = vec![0u64; tamanho(n)],
            }
        }
    }
}
