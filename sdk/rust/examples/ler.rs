//! cargo run --example ler -- arq.jsw -> JSONL; -- --avaliar arq pedido k; -- --visao arq escopos pedido k;
//! -- --reconhecer termos.jsw texto

use std::process::ExitCode;

use jsonw::{Erro, Leitor, Reconhecedor, Resultado};

fn k(texto: &str) -> Resultado<usize> {
    texto
        .parse()
        .map_err(|_| Erro::Biblioteca(format!("k invalido: {texto}")))
}

fn rodar(args: &[String]) -> Resultado<()> {
    match args {
        [_, op, arq, pedido, n] if op == "--avaliar" => {
            println!("{}", Leitor::abrir(arq)?.avaliar(pedido, k(n)?)?);
        }
        [_, op, arq, escopos, pedido, n] if op == "--visao" => {
            let mut a = Leitor::abrir(arq)?;
            a.visao(escopos)?;
            println!("{}", a.campos.join(","));
            for i in 0..a.linhas {
                match a.json(i) {
                    Ok(linha) => println!("{linha}"),
                    Err(Erro::LinhaOculta) => {}
                    Err(e) => return Err(e),
                }
            }
            println!("{}", a.avaliar(pedido, k(n)?)?);
        }
        [_, op, termos, texto] if op == "--reconhecer" => {
            println!("{}", Reconhecedor::abrir(termos)?.reconhecer(texto)?);
        }
        [_, arq] => {
            let a = Leitor::abrir(arq)?;
            for i in 0..a.linhas {
                println!("{}", a.json(i)?);
            }
        }
        _ => return Err(Erro::Biblioteca("uso: ler arquivo.jsw".into())),
    }
    Ok(())
}

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().collect();
    match rodar(&args) {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("{e}");
            ExitCode::FAILURE
        }
    }
}
