//! cargo run --example exemplo -- dados.jsw id 2: as linhas em que o campo vale o valor (JSON), pelo índice;
//! --varrer no fim para buscar sem índice.

use std::process::ExitCode;

use jsonw::{Leitor, Resultado};

fn rodar(arquivo: &str, campo: &str, valor: &str, varrer: bool) -> Resultado<()> {
    let mut a = Leitor::abrir(arquivo)?;
    let k = a.indice(campo)?;
    if !varrer {
        a.indexar(k)?;
    }
    for i in a.chave(k, valor)? {
        println!("{}", a.json(i)?);
    }
    Ok(())
}

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().collect();
    let [_, arquivo, campo, valor, resto @ ..] = args.as_slice() else {
        eprintln!("uso: exemplo arquivo.jsw campo valor [--varrer]");
        return ExitCode::from(2);
    };
    match rodar(arquivo, campo, valor, resto.first().is_some_and(|m| m == "--varrer")) {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("{e}");
            ExitCode::FAILURE
        }
    }
}
