// cargo run --example ler -- arquivo.jsw -> JSONL; -- --avaliar arq pedido k; -- --reconhecer termos.jsw texto
fn main() {
    let a: Vec<String> = std::env::args().collect();
    if a.len() == 5 && a[1] == "--avaliar" {
        let l = jsonw::Leitor::abrir(&a[2]).expect("abrir");
        println!("{}", l.avaliar(&a[3], a[4].parse().expect("k")).unwrap_or_else(|e| { eprintln!("{}", e); std::process::exit(1) }));
    } else if a.len() == 6 && a[1] == "--visao" {   // --visao arq escopos pedido k: campos, as linhas visiveis (JSONL) e o avaliar
        let mut l = jsonw::Leitor::abrir(&a[2]).expect("abrir"); l.visao(&a[3]).unwrap_or_else(|e| { eprintln!("{}", e); std::process::exit(1) });
        println!("{}", l.campos.join(","));
        for i in 0..l.linhas { match l.json(i) { Ok(s) => println!("{}", s), Err(e) if e.oculta() => {}, Err(e) => { eprintln!("{}", e); std::process::exit(1) } } }
        println!("{}", l.avaliar(&a[4], a[5].parse().expect("k")).unwrap_or_else(|e| { eprintln!("{}", e); std::process::exit(1) }));
    } else if a.len() == 4 && a[1] == "--reconhecer" {
        let r = jsonw::Reconhecedor::abrir(&a[2]).unwrap_or_else(|e| { eprintln!("{}", e); std::process::exit(1) });
        println!("{}", r.reconhecer(&a[3]).expect("reconhecer"));
    } else {
        let l = jsonw::Leitor::abrir(a.get(1).expect("uso: ler arquivo.jsw")).expect("abrir");
        for i in 0..l.linhas { println!("{}", l.json(i).expect("linha")); }
    }
}
