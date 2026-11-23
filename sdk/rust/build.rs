// liga a libjsonw.a que o `make libjsonw` deixa na pasta sdk (um nivel acima)
fn main() {
    let sdk = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("..");
    println!("cargo:rustc-link-search=native={}", sdk.display());
    println!("cargo:rustc-link-lib=static=jsonw");
    println!("cargo:rerun-if-changed={}", sdk.join("libjsonw.a").display());
}
