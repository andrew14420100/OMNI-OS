// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
fn main() {
    let dir = std::env::var("CARGO_MANIFEST_DIR").unwrap();
    println!("cargo:rustc-link-arg-bins=-T{dir}/linker.ld");
    println!("cargo:rustc-link-arg-bins=--no-pie");
    println!("cargo:rustc-link-arg-bins=-zmax-page-size=4096");
    println!("cargo:rerun-if-changed=linker.ld");
}
