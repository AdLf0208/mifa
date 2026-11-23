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

# mifa — validation record, 0.2.1 (licence repair, supersedes the 0.2.0 numbers above)

Package: `ports/mifa/mifa.hmod` — **62,998 B**, sha256
`19f1ffcd80f62077197b5561fc07f1c9786369540156300716714bbf5ae7008a`, **108 entries** (84 JSON +
22 PNG + `horizon-mod.toml` + `LICENSE`), declared version **0.2.1**, API `0.2`, `side = "both"`,
`capabilities = ["registries"]`, **no `[native]`**, **no packed `Cargo.lock`**.

The archive changed because the review asked for the upstream MIT notice *inside* the package; the
content is the 0.2.0 content (the leg below re-proves it on the new bytes). `cargo horizon-mod
build` packs only `horizon-mod.toml` + `assets/` + `data/`, so `tools/pack_license.py` adds the root
entry deterministically after the build; `--check` compares the delivered file with build +
`LICENSE`.

| Gate | Command | Result |
|---|---|---|
| the content rule | `python3 tools/gen_content.py --check` | `84 generated files, 0 drifted`, exit 0 |
| licence entry | `unzip -l mifa.hmod \| grep LICENSE` | `1911 … LICENSE`; `cmp <(unzip -p mifa.hmod LICENSE) LICENSE` identical |
| package check | `cargo horizon-mod check mifa.hmod` | `mifa 0.2.1 (mod, API 0.2, both)`, `62998 bytes, SHA-256 19f1ffcd…`, `no code: content only, nothing to run`, exit **0** |
| `fits` on the pin | `cargo horizon-mod fits mifa.hmod --build 0a875da` | exit **2**, the tool's "a content mod … doesn't apply" (HANDOVER §0g) |
| reproducible package | `rm -f Cargo.lock` + `cargo horizon-mod build` + `tools/pack_license.py`, twice | `cmp`-identical, both `19f1ffcd…`, `Cargo.lock` absent after both |
| package verifier | `python3 ports/tools/verify-sdk-package.py mifa` | **1/1** |
| skills gate | `python3 ports/tools/check-skills.py --notes ports/mifa --strict` | PASS |
| the in-game leg | `bash tools/e2e.sh` (two-mod game) | `PASS` + **`EXIT:0`** |
| the control | `NEGATIVE=1 bash tools/e2e.sh` | `FAIL` + **`EXIT:1`** |
| the counterfactual | `SELFTEST=1 bash tools/e2e.sh` | `FAIL` + **`EXIT:1`** |
| log gate | `python3 ports/tools/check-e2e-logs.py mifa-e2e --strict` | `logs=3 ok=3 missing-exit=0 bad-exit=0` |

Evidence: `ports/_shared/evidence/mifa/license/` (builds, cmp, check, fits, verifier) and
`ports/_shared/evidence/mifa-e2e/` (the three legs).

# mifa — validation record, 0.2.2 (dependency declaration, supersedes the 0.2.1 numbers above)

Package: `ports/mifa/mifa.hmod` — **63,411 B**, sha256
`cb56241774645af99b4135a0fe01668b4bdac47eba40a75945b369f9f7849149`, **108 entries**, declared
version **0.2.2**, API `0.2`, `side = "both"`, `capabilities = ["registries"]`, **no `[native]`**,
**no packed `Cargo.lock`**, and now a `[dependencies]` table:

```toml
[dependencies]
industrialforegoing = { version = ">=0.2.5", reason = "…", url = "https://github.com/AdLf0208/industrialforegoing" }
```

**The floor is `>=0.2.5` because the package binds two parent surfaces registered in different
releases:** `titanium:augments` from parent **0.2.3** and the `dissolution_chamber` block, recipe
type and serializer from parent **0.2.5**. A requirement is satisfied only when both exist, so the
later one is the floor — the version the reviewer named, with no later version needed for any symbol
this package uses. Evidence: `ports/industrialforegoing/notes.md` §"Slice 3" and §"Slice 5";
`ports/_shared/evidence/mifa/resolve-symbols-after-0.2.5.log`.

| Gate | Command | Result |
|---|---|---|
| dependency gate | `python3 ports/tools/check-manifest-deps.py mifa` | `mifa  ok  declared=['industrialforegoing']`, exit 0 |
| the content rule | `python3 tools/gen_content.py --check` | `84 generated files, 0 drifted`, exit 0 (`sdk-test.log`) |
| package check | `cargo horizon-mod check mifa.hmod` | `mifa 0.2.2 (mod, API 0.2, both)`, `63411 bytes, SHA-256 cb562417…`, `no code: content only, nothing to run`, exit **0** (`dependency/final-check.log`) |
| reproducible package | `rm -f Cargo.lock` + `cargo horizon-mod build` + `tools/pack_license.py`, twice | `cmp`-identical, both `cb562417…`, `Cargo.lock` absent after both builds and after `check` |
| no probe lock | `unzip -l mifa.hmod \| grep -c Cargo.lock` | **0** in both archives |
| `fits` on the pin | `cargo horizon-mod fits mifa.hmod --build 0a875da` | exit **2**, `… is a content mod, with no code to check against a build; \`fits\` doesn't apply.` (HANDOVER §0g) |
| `fits` on another build | `cargo horizon-mod fits mifa.hmod --build 0b14f8a` | exit **2**, the same line |
| the parent compiles | `launcher native-build <delivered 0.2.5 source>` (`dependency/parent-build.log`) | `Compiling industrialforegoing (1 of 1)`, `native-0a875da-2e712ee48d45`, exit 0 |
| the refusal | `tools/dependency-refusal.sh` (unmodded Nightly + `--dev-mod`, no parent) | `Horizon: mod load refused: mifa requires missing mod industrialforegoing (… reason + url)`, exit **1** → `PASS` + `EXIT:0` |
| the refusal can fail | `SELFTEST=1 tools/dependency-refusal.sh` | **`EXIT:1`** |
| the in-game leg | `tools/e2e.sh` on the fresh 0.2.5 build + the 0.2.2 package | `PASS` + **`EXIT:0`**; chamber table `33/33` (parent 23 + this 10) |
| the control | `NEGATIVE=1 tools/e2e.sh` | `FAIL` + **`EXIT:1`** (`mifa:speed_addon_3` absent) |
| the counterfactual | `SELFTEST=1 tools/e2e.sh` | `FAIL` + **`EXIT:1`** (`tier 3: the speed the seated addon reads is 4, expected 5`) |
| log gate | `python3 ports/tools/check-e2e-logs.py mifa-e2e --strict` | `logs=3 ok=3 missing-exit=0 bad-exit=0`, exit 0 |
| package verifier | `python3 ports/tools/verify-sdk-package.py mifa` | **1/1** |
| skills gate | `python3 ports/tools/check-skills.py --notes ports/mifa --strict` | PASS |

The leg runs on the parent's **delivered 0.2.5 source**
(`~/.cache/horizon-e2e/0a875da/mifa-parent-0.2.5/industrialforegoing`, manifest `version = "0.2.5"`,
23 chamber recipes), not on `ports/industrialforegoing`: that tree is another job's in-flight 0.2.12
slice, and building it would test that slice rather than the floor. `tools/build-game.sh` takes it via
`MIFA_PARENT_SRC`, so the run is reproducible without touching the parent's port.

Reproduce:

```sh
cd /home/adlf/Desktop/all_the_mods_10_rust_rewrite
python3 ports/tools/check-manifest-deps.py mifa
bash ports/mifa/tools/dependency-refusal.sh                 # PASS + EXIT:0
SELFTEST=1 bash ports/mifa/tools/dependency-refusal.sh      # EXIT:1
BUILD_LOCAL=1 ports/tools/build-slot.sh run --job W1-mifa --port ports/mifa --step build -- \
    bash -c 'cd ports/mifa && rm -f Cargo.lock && CARGO_INCREMENTAL=0 cargo horizon-mod build && python3 tools/pack_license.py'
BUILD_LOCAL=1 ports/tools/build-slot.sh run --job W1-mifa --port ports/mifa --step build -- \
    bash -c 'MIFA_PARENT_SRC=$HOME/.cache/horizon-e2e/0a875da/mifa-parent-0.2.5/industrialforegoing \
             MIFA_GAME_DIR=$HOME/.cache/horizon-e2e/0a875da/mifa-two-mod-0.2.5 bash ports/mifa/tools/build-game.sh'
# then the three legs with GAME/CTL/RES/E2E_TMP/SOCK from that export, as in the 0.2.0 record.
```
