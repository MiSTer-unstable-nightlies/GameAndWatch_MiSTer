# MiSTer Migration Log

Date: 2026-05-09

## Goal

Split the MiSTer build out of the former multi-target layout and reshape the active project around the MiSTer template structure:

- `sys/` is the MiSTer framework, copied from upstream and kept unmodified.
- `rtl/` contains the Game & Watch core RTL plus MiSTer-only PLL/IP/vendor dependencies.
- Root project files (`GameAndWatch.qpf`, `GameAndWatch.qsf`, `GameAndWatch.srf`, `GameAndWatch.sv`, `files.qip`) follow the template convention.
- `releases/` is present for MiSTer release RBFs.

## Upstream Sources

- MiSTer template: https://github.com/MiSTer-devel/Template_MiSTer
- Template commit used for local copy: `cce023f4ea34a5088a5ce5b45c90ad2a4493c6ac`
- Existing SDRAM controller dependency: https://github.com/agg23/sdram-controller
- SDRAM controller commit vendored locally: `eb2afab0f54aa2f08399defe4e74d3c685efb3b2`

## Initial Findings

- The existing workspace is not a git checkout, so changes are recorded here rather than as git commits.
- The current MiSTer-like target was under `target/mimic`; `target/mimic/core_top.sv` was the old framework adapter.
- The old framework lived under `platform/mimic` and used OpenGateware/MiMiC-style `core_top` plumbing.
- The upstream MiSTer template expects the framework in `sys/` and a core adapter module named `emu`.
- The old build referenced `target/vendor/sdram-controller/sdram_burst.sv`, but that submodule directory was empty in this workspace.

## Changes Made

1. Copied upstream Template_MiSTer `sys/` into the repo root as `sys/`.
   - This folder is intended to remain byte-for-byte identical to upstream.
   - Core-specific logic is not placed in `sys/`.

2. Added MiSTer root project files:
   - `GameAndWatch.qpf`
   - `GameAndWatch.qsf`
   - `GameAndWatch.srf`
   - `GameAndWatch.sv`
   - `files.qip`
   - `clean.bat`

3. Migrated MiSTer-only support files into `rtl/`:
   - `target/mimic/pll/` -> MiSTer-template PLL layout (`rtl/pll.qip`, `rtl/pll.v`, generated files under `rtl/pll/`)
   - `target/shared/` -> `rtl/ip/`
   - `sdram-controller` -> `rtl/vendor/sdram-controller/`

4. Converted the old MiSTer wrapper:
   - Old module: `core_top` in `target/mimic/core_top.sv`
   - New module: `emu` in `GameAndWatch.sv`
   - Replaced OpenGateware `NSX_*` framework macros with MiSTer `MISTER_*` macros.
   - Added modern MiSTer framework ports `HDMI_BLACKOUT` and `HDMI_BOB_DEINT`.
   - Switched build date include from `build_id.vh` to template-generated `build_id.v`.
   - Kept the core hookup to `rtl/gameandwatch.sv` and the same OSD/menu options.

5. Removed legacy multi-target folders after confirming they were not referenced by the root MiSTer build:
   - `projects/`
   - `target/`
   - `platform/`
   - `pkg/`
   - `support/`
   - `.github/`
   - `.vscode/`

6. Removed stale root metadata from the old multi-target project:
   - `.gitmodules`
   - `gateware.json`

7. Trimmed unused RTL collateral that was not referenced by `files.qip`:
   - `rtl/gameandwatch.qip`
   - `rtl/test/`
   - `rtl/ip/shared.qip`
   - `rtl/pll/pll.ppf`
   - unused SDRAM controller examples/tests, keeping `rtl/vendor/sdram-controller/sdram_burst.sv` and its `LICENSE`

## Active Build Entry

Use the root-level project:

```sh
quartus_sh --flow compile GameAndWatch.qpf
```

The resulting release artifact should follow MiSTer naming convention:

```text
GameAndWatch_YYYYMMDD.rbf
```

## Verification Log

Completed:

- `sys/` was compared against a freshly fetched Template_MiSTer checkout and matched byte-for-byte.
- `find sys -type f | wc -l` returned `56`, matching the fetched template copy.
- `files.qip` path check found no missing files.
- Active project references were checked in `GameAndWatch.qsf` and `files.qip`; the build sources `sys/sys.tcl`, `sys/sys_analog.tcl`, `files.qip`, `GameAndWatch.sv`, and files under `rtl/`.
- Removed the redundant root `GameAndWatch.sdc`. The MiSTer framework SDC is already included by untouched `sys/sys.qip`, and the root SDC only duplicated `derive_pll_clocks`/`derive_clock_uncertainty` without adding core-specific constraints.
- The remaining top-level folders are `docs/`, `releases/`, `rtl/`, and `sys/`.
- Active root/build files were checked for stale references to removed folders and old project files; none were found.
- No `.DS_Store` files remain in the workspace.
- During build testing, Quartus expanded `GameAndWatch.qsf` and added a stale `set_global_assignment -name QIP_FILE rtl/pll/pll.qip`. Restored the clean local QSF; do not save generated/expanded assignments back into `GameAndWatch.qsf`.

Not completed locally:

- Quartus compile or analysis pass. `quartus_sh` is not available on PATH in this workspace.
- Verilator/Icarus syntax pass. `verilator` and `iverilog` are not available on PATH in this workspace.

Recommended external compile command:

```sh
quartus_sh --flow compile GameAndWatch.qpf
```

## Build Review - 2026-05-09
Key findings:

- Build completed and emitted `GameAndWatch.rbf`, but TimeQuest reported large negative setup/hold slack.
- The worst timing paths were mostly between unrelated framework/core clocks. The template SDC expects the core PLL instance to be named `pll`, but the migrated wrapper had instantiated it as `pll_core`, so `sys/sys_top.sdc` could not match the core PLL clock group.
- `sys/` was not changed. The core wrapper was changed to instantiate `pll pll (...)` so the untouched template SDC can recognize the core PLL clocks.
- The generated PLL outputs are `98.304 MHz` and `32.768 MHz`; the SDRAM controller had still been parameterized as `99.28704 MHz`. Updated the SDRAM controller parameter to `98.304`.
- Fixed several high-signal RTL warnings from the build report:
  - Explicitly sized small counter decrements and alpha constants.
  - Made `clock_melody` automatic and widened divider index expressions.
  - Initialized the SM5a `PDTW` temporary W-prime array from the current W-prime state before modifying it.
  - Added initial zero values for `normalize` output segment entries that are intentionally unused for some CPU families.

Not changed:

- `sys/` warnings from untouched MiSTer framework files.
- Optional resource-saving framework macros such as `MISTER_DISABLE_YC`, `MISTER_DISABLE_ALSA`, and `MISTER_DISABLE_ADAPTIVE`; those remove framework features and should be a deliberate project choice.

## Build Review - 2026-05-09, second build

Findings:

- The previous core PLL naming/timing-constraint issue is fixed; the framework SDC now recognizes the core PLL clocks.
- Setup timing is much closer but still not fully closed: worst setup slack is `-0.184 ns` on the core `98.304 MHz` clock, with all hold/recovery/removal checks passing.
- The core SDRAM controller's `SDRAM_nCS` output was still exposed by `rtl/gameandwatch.sv` but left unconnected in the MiSTer wrapper, while the board pin was tied low. Hooked the wrapper's `SDRAM_nCS` port directly to the core controller output.
- Cleaned the remaining `clock_melody` divider selection warnings by replacing the dynamic divider bit index with an explicit selector function and moving task temporaries to the task scope with defaults.
- Remaining framework warnings around `ascal`, `sys_top.sdc`, and open-drain/tri-state conversions are from untouched template/framework code or expected unused interfaces.
- Remaining core warnings are mostly cleanup candidates rather than obvious test blockers: `instructions.sv` interface warnings and vendor SDRAM controller truncation/unused-register warnings.

## Build Review - 2026-05-09, post video alignment fix

Findings:

- The Quartus flow completed successfully and emitted `GameAndWatch.rbf`.
- Timing is closed. Worst setup slack is `0.123 ns`, worst hold slack is `0.253 ns`, and all reported TNS values are `0.000`.
- Resource use remains comfortable: `9,968 / 41,910` ALMs (`24%`), `2,057,829 / 5,662,720` block memory bits (`36%`), `283 / 553` RAM blocks (`51%`), `36 / 112` DSP blocks (`32%`), and `3 / 6` PLLs (`50%`).
- The wrapper's audio outputs are wired through the normal MiSTer framework path: `GameAndWatch.sv` drives `AUDIO_L`, `AUDIO_R`, `AUDIO_S`, and `AUDIO_MIX`, and `sys/sys_top.v` feeds those into `audio_out`.
- No project macro is disabling ALSA/framework audio support; `MISTER_DISABLE_ALSA` remains commented out.
- The main report noise is still framework/generated-IP or vendor noise: `ascal` width/connectivity warnings inside untouched `sys/`, ignored `sys_top.sdc` filters for optional framework paths, generated IP notices, and SDRAM controller unused/truncation warnings.
- Remaining core cleanup candidates are informational rather than functional blockers: `instructions.sv` interface bidirectional-port warnings and mixed blocking/non-blocking assignment notices in several clocked blocks.

No code change was made from this review beyond documenting the findings.

## Build Review - 2026-05-09, after SDC cleanup

Findings:

- The Quartus flow completed successfully and emitted `GameAndWatch.rbf`.
- TimeQuest now reads only `sys/sys_top.sdc`, confirming the root SDC removal was picked up.
- Timing remains closed. Worst setup slack is `0.123 ns`, worst hold slack is `0.253 ns`, and all reported TNS values are `0.000`.
- Resource use is unchanged: `9,968 / 41,910` ALMs (`24%`), `2,057,829 / 5,662,720` block memory bits (`36%`), `283 / 553` RAM blocks (`51%`), `36 / 112` DSP blocks (`32%`), and `3 / 6` PLLs (`50%`).
- Remaining warnings are the same categories as the prior build: framework/generated-IP notices, untouched `sys/` scaler/SDC warnings, vendor SDRAM controller warnings, and core RTL hygiene warnings around interfaces or mixed blocking/non-blocking temporaries.

No additional code change was made from this review.

## Native 720 Timing Restore - 2026-05-09

The 360x240 15 kHz transport experiment was superseded after hardware review showed that the core's preservation-critical output should remain the original 720x720 cadence.

Changes made:

- Restored the native video counters to a 720x720 active image with 756 total horizontal pixels and 730 total vertical lines.
- Kept the current 32.768 MHz video PLL output as the canonical pixel clock, producing approximately 59.375 Hz refresh.
- Removed the `/5` pixel-enable divider from the main video path; `CE_PIXEL` is now asserted every video clock.
- Restored the core/video relationship to `CLOCK_RATIO(3)`, matching the 98.304 MHz system clock to 32.768 MHz video clock relationship.
- Updated the SM510 clock divider to `3000 - 1`, giving a 32.768 kHz CPU enable from the 98.304 MHz system clock.
- Restored the SDRAM image reader and LCD mask walker to consume the full 720x720 source image rather than sampling a 360x240 point grid.
- Updated the MiSTer `arcade_video` wrapper width from 360 to 720 so the framework receives the accurate native stream.

CRT note:

- 720x720 progressive at approximately 59.4 Hz is not a 15 kHz TV/PVM mode; its horizontal rate is about 43.3 kHz. A 15 kHz analog/direct-video path will need to be a derived/downsampled transport path, not the master video timing.

No `sys/` framework files were changed.

## Video Pipeline Revert - 2026-05-09

Reverted the post-CRT video pipeline experiments after hardware testing showed the analog output was broken.

Changes made:

- Removed the `arcade_video` helper from the active wrapper path and restored the refactor-era direct native video hookup: `CLK_VIDEO = clk_vid_33_095`, `CE_PIXEL = ce_pix`, raw RGB to `VGA_R/G/B`, raw syncs to `VGA_HS/VGA_VS`, and raw `de` to `VGA_DE`.
- Kept the restored old-core 720x720 source reader, counters, and LCD mask walker rather than the 360x240 CRT sampling path.
- Reverted the SM510 clock-divider tweak from `3000 - 1` back to the prior refactor value `12'hBF4 - 1`.
- Updated the README feature text back to the old-core style `720 x 720 pixel resolution`.

The earlier `Native 720 Timing Restore` section above is retained as history, but its wrapper-level `arcade_video #(720)` path is no longer active.

No `sys/` framework files were changed.

## Dual Video Path - 2026-05-10

- Snapshotted the restored native-video state under `releases/snapshots/pre_dual_video_20260510/` before changing the pipeline.
- Enabled `MISTER_FB=1` in `GameAndWatch.qsf` so the MiSTer framework can receive a 720x720 framebuffer from the core without modifying `sys/`.
- Added `rtl/video/fb_writer.sv`, a local DDRAM framebuffer writer for the canonical 720x720 RGB stream. This keeps the HDMI/scaler-facing image at the preservation target resolution.
- Added `rtl/video/analog_15khz.sv`, a separate VGA-port stream that downsamples the canonical 720x720 image to 360x240 and emits 416x262 timing at the existing 32.768 MHz video clock divided by 5. This produces an approximately 15.754 kHz analog line rate while leaving the native stream intact.
- Routed top-level `VGA_*` to the analog stream and routed the native stream only into the framebuffer writer under `MISTER_FB`. The Template_MiSTer `sys/` folder remains untouched.

## Dual Video Path Revert - 2026-05-10

- Reverted the failed dual-path framebuffer/VGA experiment after hardware testing reported no analog video and a `0x0 @ 0 kHz` analog mode.
- Restored the main project to the pre-dual-video native 720x720 direct stream: `CLK_VIDEO = clk_vid_33_095`, `CE_PIXEL = ce_pix`, raw RGB/sync/DE to `VGA_*`, and `MISTER_FB` disabled again.
- Removed `rtl/video/fb_writer.sv` and `rtl/video/analog_15khz.sv` from the main project and from `files.qip`.
- Kept the snapshot under `releases/snapshots/pre_dual_video_20260510/` as the known marker for the restored state.

No `sys/` framework files were changed.

## Button-Up Warning Cleanup - 2026-05-10

- Cleaned the remaining local `rtl/mask.sv` truncation warning by replacing the unsized decrement literal with a sized `1'b1`.
- This is a warning-only cleanup; no video, audio, ROM, or MiSTer framework plumbing was changed.

No `sys/` framework files were changed.


## Game & Watch Sound Path Restore - 2026-05-10

- Hardware testing found that Tiger titles still make sound, while normal Game & Watch titles do not.
- That split points at the CPU-type-specific `clock_melody()` path: Tiger uses the direct `R` path, while normal SM510 Game & Watch titles use the divider-gated path.
- Reverted `rtl/cpu/instructions.sv` `clock_melody()` to the upstream `agg23/fpga-gameandwatch` behavior, including the direct `divider[output_r_mask]` indexing and task-local temporaries.
- This intentionally backs out the earlier warning-cleanup helper in this area so the preservation-critical sound behavior matches the old working core first.

No `sys/` framework files were changed.

## SM511/SM512 Support Work - 2026-05-11

Started implementation on branch `SM511+12` after a read-only feasibility pass against the local RTL and current MAME SM511/SM512 references.

ROM generator changes:

- Kept the existing `.gnw` layout compatible for SM510/SM5a packages.
- Added SM511/SM512 to the generator's normal `supported` filter.
- Added melody ROM packaging for SM511-family packages: the program ROM is padded to `0x1000` bytes and the 256 byte melody ROM is appended at package byte offset `0x326240` (`ROM_DATA_ADDR + 0x1000`).
- Added optional `melodyHash` manifest plumbing so shared/parent melody ROMs can be found by SHA when a filename lookup is not enough.
- Left SM511 Tiger IDs out of the normal `supported` filter for now, but the packaging helper recognizes them as melody-ROM CPUs if generated explicitly.

RTL changes:

- Added a 256 byte melody ROM RAM in `rtl/gameandwatch.sv`, loaded from the appended ROM area at byte offsets `0x1000-0x10FF` after the main program ROM.
- Added SM511/SM512 melody address/data signals into `rtl/sm510.sv` and `rtl/cpu/instructions.sv`.
- Added the SM511/SM512 melody generator state, tone-cycle table, and `PRE`, `SME`, `RME`, and `TMEL` operations following MAME's phase/reset behavior.
- Added SM511/SM512 clock select handling: reset starts at the slower 8.192 kHz instruction rate and `CLKHI`/`CLKLO` switch between 16.384 kHz and 8.192 kHz.
- Added an SM511-family decode path for CPU IDs `1`, `2`, `6`, and `7`, including the moved/expanded opcode map (`ROT`, `DTA`, `KTA`, `ATX`, `PTW`, `TL`, `TML`, and the `0x60` extended opcodes).
- Split the W shift register from the S output latch so SM510 still updates S directly on `WR`/`WS`, while SM511/SM512 latch W to S via `PTW`.
- Added SM512 segment C RAM caching for addresses `0x50-0x5F` and propagated segment C through the LCD/video normalization path as mask line `x=3`.
- Changed BS from a single replicated bit to a 16-bit vector: SM510 still mirrors the single BS behavior across all mask columns, while SM511/SM512 expose BS column 0 from L/Y blinking and column 1 from X.

Documentation changes:

- Documented the appended SM511/SM512 melody ROM location in `docs/format.md`.
- Updated `docs/graphics.md` so the SVG segment-plane documentation includes SM512 `seg_c` as mask line `x=3`.
- Updated generator docs to reference the actual `rom generator/` folder instead of the earlier `support/` name and describe the SM511/SM512 melody packaging behavior.

Verification notes:

- `git diff --check` passed.
- `cargo`, `quartus_sh`, `verilator`, and `iverilog` were not available in this local tool environment, so Rust and HDL compile checks still need to be run on the build machine.

No `sys/` framework files were changed.
