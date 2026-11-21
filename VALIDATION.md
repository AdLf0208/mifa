# mifa — validation record (0.2.0, first publication)

Package: `ports/mifa/mifa.hmod` — **61,784 B**, sha256
`a647e8b3043d2924f22f66d19980c856f95debd47f9750b84fa456522965f824`, **107 entries** (84 JSON +
22 PNG + `horizon-mod.toml`), declared version **0.2.0**, API `0.2`, `side = "both"`,
`capabilities = ["registries"]`, **no `[native]`**, **no packed `Cargo.lock`** (a content package
has no `Cargo.toml` at all: `build_in` refuses one).

Pin: Horizon `0a875da91dbb0fdcb7ba8c42c11341aa229af51a` + horizon-mixins
`e59da9094f0c2fdda6c627fe9eff22dec6a906f0`, game 26.3.

| Gate | Command | Result |
|---|---|---|
| the content rule | `python3 tools/gen_content.py --check` | `84 generated files, 0 drifted`, exit 0 |
| package check | `cargo horizon-mod check mifa.hmod` | `61784 bytes, SHA-256 a647e8b3…`, `no code: content only, nothing to run`, exit **0** (`check.log`) |
| `fits` on the pin | `cargo horizon-mod fits mifa.hmod --build 0a875da` | exit **2**, `… is a content mod, with no code to check against a build; \`fits\` doesn't apply.` |
| `fits` on another build | `cargo horizon-mod fits mifa.hmod --build 0b14f8a` | exit **2**, the same line |
| reproducible package | two `cargo horizon-mod build` runs, `rm -f Cargo.lock` before each | `cmp`-identical, both `a647e8b3…`, and identical to the delivered file |
| dependency matrix | `python3 tools/resolve_symbols.py` | **56 of 61** resolve (was 29 of 61 at `industrialforegoing` 0.2.2); the 5 blocked ones are named in `notes.md` |
| package verifier | `python3 ports/tools/verify-sdk-package.py mifa` | **1/1** |
| skills gate | `python3 ports/tools/check-skills.py --notes ports/mifa --strict` | PASS |
| the in-game leg | `bash tools/e2e.sh` (two-mod game: `industrialforegoing` 0.2.5 + `--dev-mod mifa.hmod`) | `PASS` + **`EXIT:0`** |
| the control | `NEGATIVE=1 bash tools/e2e.sh` (the same game without `--dev-mod`) | `FAIL` + **`EXIT:1`** — the parent's machine places, `mifa:speed_addon_3` is absent |
| the counterfactual | `SELFTEST=1 bash tools/e2e.sh` | `FAIL` + **`EXIT:1`** — asserts a fall of five where the tier 3 speed addon reads four |
| log gate | `python3 ports/tools/check-e2e-logs.py mifa-e2e --strict` | `logs=3 ok=3 missing-exit=0 bad-exit=0` |

## What the leg proves (in the parent's own readouts, not in this port's words)

- `content from 2 mod(s)` in the game's log, 0 load errors, an unknown id refused by the game;
- six machines, one per tier 3–8, each seated with a speed and an efficiency addon:
  `augments speed 4/5/6/7/8/9` and `efficiency 0.70/0.60/0.50/0.40/0.30/0.20` with bar maxima
  `70/60/50/39/30/19` — the **39** and **19** are the jar's `0.39999998`/`0.19999999` literals
  through the parent's `floor(100 * efficiency)`, so the port cannot pass by writing `0.4`;
- the rate, timed by the game: `58 → 26 over 8 ticks` (four a tick) on the tier 3 machine;
- a **crafted** speed tier 8 (`mifa:dissolution_chamber/speed_addon_8`, 1,600 ticks, 8,000 mB of
  ether gas) taken into the hand and seated → `speed 9`: the recipe's output carries the payload;
- a processing addon refused (the parent's `AugmentTypes` is Speed and Efficiency only) — recorded
  as a parent gap, not hidden;
- the netherite gear in a real smithing table from `#c:gears/diamond` + `#c:ingots/netherite`,
  inputs consumed, and an iron gear in the base leaving the result empty;
- the chamber's table `33/33` (the parent's 23 + this package's 10), and each of the 10 carried
  recipes matching its own grid, running, and emptying the input slots and the tank; the first at
  its full 200 ticks;
- the parent's own tier-2 craft beside this package's cheaper re-declaration — two crafts, one
  parent item;
- one wrong cell: `recipe none`, no FE, no fluid, no product.

## Reproduce

```sh
cd /home/adlf/Desktop/all_the_mods_10_rust_rewrite
python3 ports/mifa/tools/gen_content.py --check
python3 ports/mifa/tools/resolve_symbols.py
ports/tools/build-slot.sh run --job W1-mifa --port ports/mifa --step build -- \
    bash -c 'cd ports/mifa && cargo horizon-mod build'
cargo horizon-mod check ports/mifa/mifa.hmod
eval "$(ports/mifa/tools/build-game.sh)"
export GAME CTL RES HORIZON_RES E2E_TMP SOCK
ports/tools/build-slot.sh run --job W1-mifa-e2e --port ports/mifa --step e2e -- \
    bash ports/mifa/tools/e2e.sh
```
