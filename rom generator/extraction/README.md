# Manifest Extractor

This helper reads MAME's `hh_sm510.cpp` and writes a `manifest.json` file for the ROM generator.

It uses MAME source definitions to collect:

- Game metadata
- CPU/device preset
- Screen layout type and dimensions
- ROM filename and SHA1 hash
- Parent ROM ownership
- Input mapping
- Grounded input port behavior

## Usage

From this folder:

```sh
npm ci
npm run build -- /path/to/mame/src/mame/handheld/hh_sm510.cpp ../manifest.json
```

The second argument is optional. If omitted, the extractor writes `manifest.json` in the current directory.

The ROM generator expects the manifest either next to the generator's working directory or passed explicitly with:

```sh
--manifest-path /path/to/manifest.json
```
