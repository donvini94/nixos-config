//! Proves the binary runs and reports the size of its input. This is the floor: below it,
//! the next person to touch this code rewrites it instead of changing it.

use std::io::Write as _;
use std::process::Command;

#[test]
fn reports_the_byte_count_of_its_input() {
    let mut f = tempfile::NamedTempFile::new().unwrap();
    write!(f, "hello").unwrap();

    let out = Command::new(env!("CARGO_BIN_EXE_CHANGEME"))
        .arg("--input")
        .arg(f.path())
        .output()
        .unwrap();

    assert!(out.status.success(), "stderr: {}", String::from_utf8_lossy(&out.stderr));
    assert_eq!(String::from_utf8_lossy(&out.stdout).trim(), "5");
}
