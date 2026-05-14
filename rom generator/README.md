# Game & Watch ROM Generator

This folder contains the ROM packaging tooling for the Game & Watch MiSTer core.

The generator converts MAME Game & Watch artwork and ROM zips into `.gnw` packages that the FPGA core can load. It does not include MAME ROMs or artwork.

## Contents

- `src/` - Rust source for `fpga-gnw-romgenerator`
- `Cargo.toml` / `Cargo.lock` - Rust build metadata
- `extraction/` - TypeScript helper for generating `manifest.json` from MAME's `hh_sm510.cpp`

## Requirements

- Rust toolchain with `cargo`
- Node.js and npm, only if regenerating `manifest.json`
- A MAME-style folder containing `artwork/` and `roms/`

Expected MAME input layout:

```text
/MAME Folder/artwork/gnw_dkong.zip
/MAME Folder/roms/gnw_dkong.zip
```

## Build The Generator

From the repository root:

```sh
cargo build --manifest-path "rom generator/Cargo.toml" --release --locked
```

The binary will be written to:

```text
rom generator/target/release/fpga-gnw-romgenerator
```

You can also run it without separately invoking the built binary:

```sh
cargo run --manifest-path "rom generator/Cargo.toml" --release --locked -- --help
```

## Generate Or Provide The Manifest

The generator needs a `manifest.json` describing supported devices, CPU types, ROM hashes, screen setup, and input mapping.

To regenerate it from a local MAME source checkout:

```sh
cd "rom generator/extraction"
npm ci
npm run build -- /path/to/mame/src/mame/handheld/hh_sm510.cpp ../manifest.json
```

That writes `rom generator/manifest.json`, which the Rust generator can use directly.

## Generate ROM Packages

From the repository root:

```sh
cargo run --manifest-path "rom generator/Cargo.toml" --release --locked -- \
  --manifest-path "rom generator/manifest.json" \
  --mame-path "/path/to/MAME Folder" \
  --output-path "/path/to/output" \
  supported
```

The output directory must already exist.

The `supported` filter includes SM510, SM511, SM512, SM510 Tiger, and SM5a titles. SM511/SM512 packages include the fixed 4 KiB program ROM area plus the appended 256 byte melody ROM.

On MiSTer, generated `.gnw` files belong in:

```text
/games/Game and Watch/
```

## Useful Filters

Generate one game:

```sh
cargo run --manifest-path "rom generator/Cargo.toml" --release --locked -- \
  --manifest-path "rom generator/manifest.json" \
  --mame-path "/path/to/MAME Folder" \
  --output-path "/path/to/output" \
  specific gnw_dkong
```

Generate only installed supported games:

```sh
cargo run --manifest-path "rom generator/Cargo.toml" --release --locked -- \
  --manifest-path "rom generator/manifest.json" \
  --mame-path "/path/to/MAME Folder" \
  --output-path "/path/to/output" \
  --installed \
  supported
```

The Rust CLI is the source of truth for options:

```sh
cargo run --manifest-path "rom generator/Cargo.toml" --release --locked -- --help
```
