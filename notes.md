# mifa — port notes (third dispatch: the content package, 0.2.0)

Port of **More Industrial Foregoing Addons 2.1.0**
(`mifa-neoforge-1.21.x-2.1.0.jar`, MIT, SHA-256
`dab09f72c4df39efc5d7f8949e4ab02b7d5f74242ee17b8c26fb172c2761d49f`, 243,510 B), Minecraft Java
1.21.1 / NeoForge; upstream `https://github.com/Christofmeg/MoreIndustrialForegoingAddons`,
commit `5fc3ac843f03397f7a117152a081e42980ee2e52` (tag `2.1.0`). Target pin: Horizon
**`0a875da91dbb0fdcb7ba8c42c11341aa229af51a`** + horizon-mixins
`e59da9094f0c2fdda6c627fe9eff22dec6a906f0`, game 26.3, API `0.2`. Delivered: `mifa.hmod`,
**0.2.0**, a **first publication** (the id is not on `main`).

**Licence: MIT — rank 0 (permissive).** Read from the jar (`META-INF/neoforge.mods.toml`:
`license = "The MIT License (MIT)"`; `audit_licences.py --mod mifa --fetch` → `AUDITED`,
effective MIT) and the upstream `LICENSE` (MIT, © Christofmeg). Not relicensed, no asset
regeneration needed (the art is MIT too). Publishing still needs the maintainer's approval
(ARCHITECTURE.md §8).

**Class + tier: `content` / `machines`, role add-on** (`ports/ledger.csv`; provenance
`ports/_shared/source-map/atm10-sources.csv`). The ledger is the authority and is not
contradicted: the row's `machines` describes what the mod *serves* — an Industrial Foregoing
machine reads the addons — not what its jar contains, and **the jar contains no machine**. The
first two dispatches recorded that mismatch as a block; this one records it as the **shape**:
19 content items whose whole behaviour is the parent's.

## The two blockers are gone (what changed since the last dispatch)

| # | Blocker (2nd dispatch) | Now |
|---|---|---|
| 1 | `titanium:augments` was a component type nothing registered, so a content item naming it failed the content root | `industrialforegoing` **0.2.3** registers the type (`fn component_types` → `event.types.push(AUGMENT_COMPONENT)`) and reads it in `AddonItem.useOn`'s port: right-clicking a machine seats an item whose `titanium:augments` decodes |
| 2 | `industrialforegoing:dissolution_chamber` did not exist, so all 21 recipes were dead data | **0.2.5** ships the machine, its own recipe type **and** a read-only serializer for it (API 36), with 23 of the jar's own recipes; its decoder reads any `industrialforegoing:dissolution_chamber` file the load finds, whatever namespace the file is in |
| 3 | the parent's gear items and tier-1/tier-2 addons did not exist | 0.2.3/0.2.5 ship `{iron,gold,diamond}_gear`, `{efficiency,speed}_addon_tier_1|2` and declare `c:gears/*`, `c:plastics` |

## The resolution matrix, re-run (`tools/resolve_symbols.py`)

Every symbol the jar names outside `mifa:` — **61** including its own 19 items — resolved
against the prepared 26.3 registries, `ports/industrialforegoing` 0.2.5 and this package:

| | unresolved |
|---|---:|
| **before** (2nd dispatch, `industrialforegoing` 0.2.2, recorded in `ports/_shared/evidence/mifa/parent-references.log`) | **29 of 61** |
| **after** (`industrialforegoing` 0.2.5 + this package) | **5 of 61** |

Evidence: `ports/_shared/evidence/mifa/resolve-symbols-after-0.2.5.log` (one line per symbol).
The five that still do not resolve, and what each blocks:

| Symbol | Why it does not resolve | Blocks |
|---|---|---|
| `c:experience` | a **fluid** tag; the pin ships 0 `c:` groups and five fluids (`empty`, `water`, `flowing_water`, `lava`, `flowing_lava`), so it has no member, and the parent's `fluid_of` reads `fluid`/`id`, not `tag` | `*_addon_4` (3 recipes) |
| `industrialforegoing:sludge` | the parent declares three fluid keys (`latex`, `pink_slime`, `ether_gas`); `sludge` is not one, and `declare_fluid` refuses a namespace that is not the caller's | `*_addon_5` (3 recipes) |
| `industrialforegoing:biofuel` | same | `*_addon_6` (3 recipes) |
| `industrialforegoing:processing_addon_tier_1` | the parent port ships **no processing addon at all** (its item set is the two efficiency and the two speed tiers) | `processing_addon_3` (1 recipe) |
| `industrialforegoing:processing_addon_tier_2` | same (and the re-declared processing tier-2 recipe produces an item nobody ships, so it is dropped rather than carried) | the re-declared processing tier-2 (1 recipe) |

Nothing else is missing: the 15 parent symbols now resolve (13 of 15 before the fluid check, and
`dissolution_chamber` resolves as a block *and* a recipe type), the `titanium:augments` component
type resolves, 13 of the 14 `c:` symbols resolve, all 13 declared by this package
(`c:gears/{iron,gold,diamond}` are also in the parent; `c:experience` is the fifth unresolved one), and every vanilla symbol resolved in both runs.

## Shape: a content-only package, and why (a deliberate departure from the brief's step 2)

The brief says to scaffold from `template-native-v2` and to keep a pure `runtime.rs`. This slice
ships **no Rust**, for a reason that is the whole finding: **every behaviour mifa has belongs to
the parent**. Measured, not assumed:

- the jar has 0 blocks, 0 block entities, 0 menus, 0 commands, 0 entities, 0 worldgen and 0
  `data/mifa/` files; its three item classes are 30-line subclasses that pass a tier number to the
  parent's `SpeedAddonItem`/`EfficiencyAddonItem`/`ProcessingAddonItem`, and `ItemRegistry` only
  registers (FINDINGS.md, from the upstream source);
- the values the items carry are the parent's arithmetic (`1 + tier`, `1 - tier * 0.1`);
- seating an addon is the parent's `AddonItem.useOn` (our port's `Machine::use_item_on`), reading
  a machine is the parent's `/industrialforegoing info`, and running a recipe is the parent's
  chamber;
- the parent itself carries **its own** addons the same way: `data/industrialforegoing/horizon/item/
  efficiency_addon_tier_1.json` is a content item whose `components.titanium:augments` is the whole
  payload, and its chamber then seats it. This package is that shape, six tiers further out.

So the deliverable is `horizon-mod.toml` + `assets/mifa/` + `data/mifa/` + `data/c/tags/item/`,
built by `cargo horizon-mod build` into one flat `.hmod` with no `Cargo.toml`, no `src/` and no
`[native]` block. The campaign has done this deliberately before: `simplylight` **retired** its
native 0.2.0 package for a content one, and `verify-sdk-package.py` has a content-only branch. The
brief's native evidence items are replaced as follows, so nothing is silently dropped:

| brief's native gate | this slice |
|---|---|
| `cargo test` count | the rule lives in `tools/gen_content.py`'s tables and its `--check` (84 files, 0 drifted); the **in-game** assertions are the behavioural gate |
| `cargo clippy`/`fmt` | not applicable (no Rust) |
| `Compiling mifa (1 of 1)` | `cargo horizon-mod build` re-runs on the bumped manifest: **107 entries**, 61,784 B, `a647e8b3…` (the trap the brief names is real — the first package was stale and still carried two recipe files the tree had dropped: the game then reported `recipes 33/35`) |
| `fits` exit 0, `made for` | `fits` **exits 2** for a content package — `… is a content mod, with no code to check against a build; fits doesn't apply.` — which HANDOVER §0g records as the tool's "not applicable" status, never 0, and `verify-sdk-package.py` accepts for a package with no `src/`; run against **both** `0a875da` and `0b14f8a`, the same line each |

## Family table (every family in the jar → what this package does with it)

| Family | Files in the jar | Disposition | Where it is proven |
|---|---:|---|---|
| blocks, blockstates, block models | 0 | — | none exist |
| machines / block entities / menus | 0 | — | none exist; the machine that consumes these items is the parent's |
| **items: `{efficiency,speed,processing}_addon_3…8`** (18) | 18 models, 18 textures, 0 lang keys | **carried** | leg A (19 items, 19 names), leg B (each tier's payload seated and read) |
| **item: `netherite_gear`** | 1 model, 1 texture, 1 lang key | **carried** | leg D (crafted in a smithing table); `c:gears/netherite` |
| **recipes: 21 × `industrialforegoing:dissolution_chamber`** | 21 | **10 carried**, 10 `blocked`, 1 dropped | leg E (each matches its own grid, runs, consumes its inputs and fluid), leg G (two crafts) |
| recipe: 1 × `minecraft:smithing_transform` | 1 | **carried** | leg D (+ a wrong-base control) |
| **tags: `c:gears` + 4 children** | 5 | **carried** | resolved by the recipes (leg E's grid feeds `#c:gears/netherite`) |
| **tags: the 9 conventional item tags the recipes name** | 0 (the jar relies on the pack) | **declared here** | leg E: the chamber's table reports 33/33 only because every one resolves, and each grid feeds a member |
| advancements | 23 | `not ported` | they are recipe-book unlocks whose `recipe` field points at `industrialforegoing:dissolution_chamber/…` ids that do not exist here; the recipes are carried as `mifa:…`, and the pin's content model shows no recipe book. The parent carries its own |
| creative tab (`itemGroup.mifa_addons`) | 0 files (Java tab) | **carried** (`creative_tab/addons.json`, the 19 items) | carried, **not asserted in game**: `ctl` has no reader for creative tabs at this pin. The tab's items are exactly the 19 ids leg A gives and names |
| commands / config / GUI / worldgen / entities / loot tables | 0 | — | none exist |

Per-family `blocked` symbols, so the gap is a line and not a shrug:

| Blocked | Symbol | Assertion that would prove it when it lands |
|---|---|---|
| `{efficiency,processing,speed}_addon_4` (3) | `c:experience` (fluid tag, no member; the parent's `fluid_of` does not read `tag`) | the same `run_recipe` call with `fluid experience 4000` |
| `{efficiency,processing,speed}_addon_5` (3) | `industrialforegoing:sludge` (undeclared fluid) | `run_recipe …_addon_5 1000 sludge 5000` |
| `{efficiency,processing,speed}_addon_6` (3) | `industrialforegoing:biofuel` | `run_recipe …_addon_6 1200 biofuel 6000` |
| `processing_addon_3` (1) | `industrialforegoing:processing_addon_tier_2` (the parent ships no processing addon) | `run_recipe processing_addon_3 600 pink_slime 3000` |
| the processing tier-2 re-declaration (1, **dropped**) | `industrialforegoing:processing_addon_tier_2` as an **output** nobody ships | the parent shipping the item; then it is one more file in `gen_content.CARRIED` |
| the `Processing` payload's **effect** (6 items carried) | the parent's `AugmentType::ALL` is `[Speed, Efficiency]` — a `Processing` component decodes to nothing, so `use_item_on` refuses the seat | leg B3 measures the refusal today; when the parent reads `Processing`, one more `expect` on the machine's readout |

## Coverage table (what the leg actually asserts)

`ports/_shared/evidence/mifa-e2e/e2e-default.log` — `PASS` + `EXIT:0`; control
(`e2e-negative.log`) and `SELFTEST=1` (`e2e-selftest.log`) both `FAIL` + `EXIT:1`;
`check-e2e-logs.py mifa-e2e --strict` → 3/3 ok.

| What | State | Phase / assertion |
|---|---|---|
| the package loads beside the parent, with its recipes and items | `tested` | P: 0 `load-items`/`horizon-recipes`/`unknown component type` errors in the log; the game logged `content from 2 mod(s)` |
| an unknown id is refused | `tested` | P: `/give mifa:not_an_item` → the game's own `Unknown item 'mifa:not_an_item'` (the exit status of `ctl command` is `ok:true` for this, so the reply is parsed) |
| the 19 items exist and are named | `tested` | A: 19 gives, 19 `Gave 1 [<name>]` lines, 19 inventory counts |
| speed tier t makes the bar fall `1 + t` | `tested` | B: tiers 3–8 read `speed 4,5,6,7,8,9`; B2 measures the rate (58 → 26 over 8 ticks, four a tick) |
| efficiency tier t scales the bar to `floor(100 * (1 - t*0.1))` | `tested` | B: `efficiency 0.70/0.60/0.50/0.40/0.30/0.20` with bars `70/60/50/**39**/30/**19**` — the jar's `0.39999998`/`0.19999999` literals are what make 39 and 19, so a port that wrote `0.4`/`0.2` fails here |
| a **crafted** addon carries its payload | `tested` | C: the chamber's `speed_addon_8` output is taken into the hand (count 1) and seated → `speed 9` |
| the smithing recipe (`#c:gears/diamond` + `#c:ingots/netherite`) | `tested` | D: a real smithing table, result `mifa:netherite_gear`, the three inputs consumed, and an iron gear in the base leaves the result empty |
| the 10 carried chamber recipes: match, run, consume | `tested` | E: `recipes 33/33`; each `run_recipe` asserts the matched id, its bar length (200/600/1400/1600), its product in output slot 8, `items 0` and `input … 0 mB`; the first runs its full 200 ticks (9820 → 10000 FE with windowed refills) |
| the parent's own tier-2 craft still exists beside this package's | `tested` | G: the parent's `industrialforegoing:dissolution_chamber/efficiency_addon_tier_2` (two diamond gears, no tier-1) matches and yields the same item this package's cheaper one does |
| a wrong ingredient matches nothing | `tested` | F: one cell wrong → `recipe none`, bar 0, buffer untouched, fluid untouched, no product |
| the creative tab | **carried, not asserted** | no `ctl` reader for creative tabs at this pin; the tab lists exactly the 19 `/give`-proven ids |
| the `Processing` tiers' effect | `blocked(parent)` | B3: the item is refused and stays in the hand, because the parent's reader has no `Processing` |
| 10 blocked recipes | `blocked(symbol)` | the table above |
| advancements | `not ported` | the reason above |

## Upstream observations, and what this port did with them

1. **The jar has no `mifa:` names for 18 of its 19 items.** The parent's `getDescriptionId()`
   builds them from its own keys (`Addon: <Kind> Tier <n>`), so a naive carry renders raw keys.
   This package declares all 19 (`assets/mifa/lang/en_us.json`, generated from `gen_content`'s
   table), and leg A reads each one back from the game's own `Gave 1 [<name>]` line.
2. **`ModRecipeProvider` re-declares the parent's tier-2 recipes, cheaper, under a dotted id.**
   Verified against the shipped parent: its own `efficiency_addon_tier_2` wants `c:dusts/redstone`
   ×2, glass panes ×2, **`c:gears/diamond` ×2**, blaze rods ×2 and no tier-1 addon; mifa's
   `industrialforegoing.efficiency_addon_tier_2` wants the same with **one** diamond gear and the
   parent's `efficiency_addon_tier_1` in the sixth slot. **Both are carried** (efficiency and
   speed; processing's is dropped with its symbol), because both load upstream and the duplicate
   is the fact: leg E matches this package's, leg G matches the parent's, both yielding
   `industrialforegoing:<kind>_addon_tier_2`. The recipe ids are
   `mifa:dissolution_chamber/industrialforegoing.<kind>_addon_tier_2` (see the namespace note).
3. **The tier-4 fluid is a tag, not a fluid id** (`{"amount": 4000, "tag": "c:experience"}`).
   Deliberate upstream for IF's `SizedFluidIngredient`, unreadable by the parent's decoder
   (`fluid_of` takes `fluid`/`id`), and empty at this pin. Recorded as `blocked(c:experience)`; not
   rewritten to a fluid id, because inventing `minecraft:water` there would be a fabricated recipe.

## Adaptations (no upstream defect was found; these are the platform's shape)

- **Namespace.** The pin's fence allows a mod its own namespaces plus `data/c/tags/` and
  `data/minecraft/tags/`; upstream ships `data/industrialforegoing/recipe/…` and
  `data/minecraft/recipe/netherite_gear_smithing.json`, neither of which a package may carry. The
  recipes live at `data/mifa/recipe/…` and their ids are `mifa:…`. The parent's chamber keys on
  the recipe **type**, so it reads them all the same (proved: `recipes 33/33` and each match).
- **`neoforge:conditions` dropped.** A NeoForge loader key; the pin's loader does not know it.
- **Ingredients in the pin's shorthand.** `"minecraft:sculk"` / `"#c:rods/blaze"` instead of the
  jar's `{"item": …}`/`{"tag": …}` objects: the parent's 23 shipped recipes and the pin's own
  files use it, and API 36's reader is documented to read "the usual fields".
- **The 9 convention tags are declared here.** The prepared 26.3 resources ship no `c:` group at
  all, so a recipe naming `c:rods/blaze` would decode to nothing. Values are the convention's
  (`c:ores/netherite_scrap` is `minecraft:ancient_debris`, the ore that drops the scrap;
  `c:player_workstations/furnaces` is furnace/blast furnace/smoker;
  `c:glass_panes/colorless` is the plain pane). `c:gears/{iron,gold,diamond}` are declared by the
  parent with its own items and declared here again as the jar does, with `c:gears/netherite`
  adding this package's gear.
- **No advancements.** See the family table.

## Red → green (the order the work actually went)

1. **Red (in game, first run):** `FAIL: the reply to an unknown id is true, expected false` — the
   unknown-id check read `ctl command`'s exit status, which is `ok:true` even when the game refuses
   the item. Fixed to assert the game's `Unknown item …` line; that is the campaign's own trap.
2. **Red:** `FAIL: mifa:efficiency_addon_4 is named 'Gave 1 [Addon: Efficiency Tier 3]'` — a chat
   line lands a tick or two after the command; fixed by reading the names as a set after all 19.
3. **Red:** `FAIL: tier 4: the speed the seated addon reads is 4, expected 5` — the readout was
   read from the previous position's reply. Root cause found in the SDK rather than guessed:
   `ctl messages` is **newest first** (`agent.rs`: `"order": "newest first"`), so `grep | tail -1`
   took the *oldest* line. Fixed with a position-specific pattern and the newest line
   (`grep -m1`), plus a re-send when a chat command is dropped (two reads back to back).
4. **Red:** `FAIL: the chamber's recipe table … is 33/35` — the delivered package was stale and
   still carried two recipe files the tree had dropped (the cached-package trap). Rebuilt: `107
   entries`, `61,784 B`, `a647e8b3…`; the game then reported `33/33`.
5. **Red:** `FAIL: … the recipe its grid matches is none` — the fluid was never set: Brigadier's
   `word` type has no colon, so `fluid <pos> industrialforegoing:latex 1000` is a parse error and
   the port's own `qualify_fluid` prefixes the namespace. Bare `latex` / `pink_slime` / `ether_gas`
   fixed it.
6. **Red:** `FAIL: the crafted speed tier 8 in the hand is 0` — leg C moved `container.8` assuming
   the last recipe made tier 8; the last recipe was the re-declared tier-2. Reordered and added an
   assertion on the output slot before the move.
7. **Green:** `PASS` + `EXIT:0` (`e2e-default.log`), and the two counterfactuals red
   (`EXIT:1` each).

## Evidence index

`ports/_shared/evidence/mifa/`:

| File | What it measures |
|---|---|
| `resolve-symbols-after-0.2.5.log` | the 61 symbols, one line each, with the 5 still unresolved |
| `gen-content-check.log` | the generator: 84 generated files, 0 drifted |
| `check.log` | `cargo horizon-mod check` on the delivered bytes: sha256, bytes, `no code: content only` |
| `fits-0a875da.log`, `fits-0b14f8a.log` | `fits` exit 2 with the tool's "doesn't apply" line, on two builds |
| `jar-inventory.log`, `recipes-tags.log`, `upstream-source.log`, `if-addon-source.log`, `parent-port.log`, `sdk-surface.log`, `convention-tags.log`, `parent-references.log`, `block-decision.md` | the **first two dispatches'** measurements, kept: the jar inventory, every recipe and tag, the upstream classes, the parent's old surface, the SDK greps, and the 29-of-61 matrix |

`ports/_shared/evidence/mifa-e2e/`: `e2e-default.log` (PASS + EXIT:0), `e2e-negative.log`
(control: the same game without `--dev-mod`; FAIL + EXIT:1), `e2e-selftest.log`
(`SELFTEST=1`; FAIL + EXIT:1).

## Next slice

**The tier-4 chain, once a liquid-XP fluid exists** — the gap line is
`c:experience -> MISSING` in `resolve-symbols-after-0.2.5.log`, which blocks `*_addon_4` and, with
the parent exporting sludge/biofuel, `*_addon_5|6` too. It fits the tier (`machines`: a chamber
recipe is the product) and needs no code here: one `run_recipe` line per recipe the moment the
fluid id exists, plus the processing chain when the parent ships `processing_addon_tier_1|2` and
its reader learns `Processing` (then `processing_addon_3` and the six `Processing` payloads become
seatable, and B3 becomes a positive assertion). The cheapest next step is a **parent** slice, not
this one: declare `sludge`/`biofuel` and the two processing addons, and this port gains 8 recipes
and 6 measurable addons.

Skills: superpowers/using-superpowers,brainstorming,writing-plans,test-driven-development,systematic-debugging,verification-before-completion; BeautifulRust/none (no Rust change — the slice is content-only by measurement; `rust-best-practices` was read for the shape decision and does not apply to a package with no crate)
