use std::env;
use std::fs;
use std::path::Path;

fn main() {
    let manifest_path = Path::new("../manifest.json");
    println!("cargo:rerun-if-changed=../manifest.json");
    println!("cargo:rerun-if-changed=Cargo.toml");

    let manifest_content = fs::read_to_string(manifest_path)
        .expect("BUILD ERROR: Could not read ../manifest.json");

    let manifest: serde_json::Value = serde_json::from_str(&manifest_content)
        .expect("BUILD ERROR: ../manifest.json is not valid JSON");

    let manifest_version = manifest["version"]
        .as_str()
        .expect("BUILD ERROR: manifest.json is missing 'version' key");

    let cargo_version = env::var("CARGO_PKG_VERSION")
        .expect("BUILD ERROR: CARGO_PKG_VERSION is not set");

    let clean_manifest_ver = manifest_version.trim_start_matches('v');
    let clean_cargo_ver = cargo_version.trim_start_matches('v');

    if clean_manifest_ver != clean_cargo_ver {
        panic!(
            "\n\n[SSOT VIOLATION] Version mismatch detected!\n\
            -> manifest.json: '{}'\n\
            -> Cargo.toml:    '{}'\n\
            Ensure both versions match before compiling.\n\n",
            manifest_version, cargo_version
        );
    }
}
