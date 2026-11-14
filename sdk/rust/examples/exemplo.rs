//! exemplo: abre um .jsw e mostra as linhas em que <campo> vale <valor> (JSON), pelo indice (ou varrendo, com --varrer).
//! cargo run --example exemplo -- dados.jsw id 2
fn main() -> Result<(), jsonw::Erro> {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 4 { eprintln!("uso: exemplo arquivo.jsw campo valor [--varrer]"); std::process::exit(2); }
    let mut a = jsonw::Leitor::abrir(&args[1])?;
    let Some(k) = a.campos.iter().position(|c| c == &args[2]) else {
        eprintln!("campo {} não existe", args[2]); std::process::exit(1);
    };
    if args.get(4).map(String::as_str) != Some("--varrer") { a.indexar(k)?; }
    for i in a.chave(k, &args[3])? { println!("{}", a.json(i)?); }
    Ok(())
}
