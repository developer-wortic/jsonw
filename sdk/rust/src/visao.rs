//! Visão: o servidor multi-tenant trava no `Leitor` o que a sessão vê ("pessoal vendas tenant:42") antes de entregá-lo.
//! Esquema e campos ficam só com as colunas visíveis; linha de outro tenant vira `Erro::LinhaOculta`. Não destrava.

use crate::{Leitor, Resultado, com_erro, cstring, ffi};

impl Leitor {
    /// # Errors
    /// `Erro::Biblioteca` se os escopos são inválidos.
    pub fn visao(&mut self, escopos: &str) -> Resultado<()> {
        let e = cstring(escopos)?;
        match com_erro(|b, n| unsafe { ffi::jsonw_visao(self.a, e.as_ptr(), b, n) }) {
            (0, _) => {
                self.ler_esquema();
                Ok(())
            }
            (_, erro) => Err(erro),
        }
    }
}
