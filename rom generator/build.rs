use std::error::Error;
use vergen::EmitBuilder;

fn main() -> Result<(), Box<dyn Error>> {
    // Stamp generated ROMs with the source commit when this is built from a git checkout.
    // Release archives and copied source trees may not have .git metadata, so keep the
    // generator buildable and use an explicit fallback string.
    if EmitBuilder::builder().git_sha(true).emit().is_err() {
        println!("cargo:rustc-env=VERGEN_GIT_SHA=unknown");
    }

    Ok(())
}
