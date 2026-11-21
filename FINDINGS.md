# mifa — jar inventory and dependency findings

> **Status, 2026-11-21 (third dispatch): this file is the record of what the jar and the parent
> contain; the block it ends with is gone.** `industrialforegoing` 0.2.3 shipped the
> `titanium:augments` component type and the augment slot, 0.2.5 shipped the dissolution chamber
> and its recipe type, and the gear items; the 61-symbol matrix now resolves **56** (was 29
> unresolved). The port is a **content-only package**, `mifa.hmod` 0.2.0, and `notes.md` is the
> current record: the family table, the coverage table, the five remaining symbols
> (`c:experience`, `industrialforegoing:sludge`, `:biofuel`, `:processing_addon_tier_1|2`) and the
> in-game leg. The sections below are kept as measured proof of the jar, the values and the
> upstream observations, not as a live gap list.

Jar: `ports/_shared/licence-cache/mifa-neoforge-1.21.x-2.1.0.jar`
SHA-256 `dab09f72c4df39efc5d7f8949e4ab02b7d5f74242ee17b8c26fb172c2761d49f`, 243,510 B, **127 files**.
`META-INF/neoforge.mods.toml`: `modId = "mifa"`, `version = "2.1.0"`, author `Christofmeg`,
`license = "The MIT License (MIT)"` (the jar ships no separate LICENSE file; the upstream repo's
`LICENSE` is the same MIT text — `audit_licences.py --mod mifa --fetch` → `AUDITED`, declared
`The MIT License (MIT)`, effective MIT, rank 0). Required dependency:
`industrialforegoing [1.21-3.6.24,)`.
Upstream read: `https://github.com/Christofmeg/MoreIndustrialForegoingAddons`, shallow clone at commit
**`5fc3ac843f03397f7a117152a081e42980ee2e52`** = tag `2.1.0` ("2.1.0: Fluid tags in tier 4 addons",
2025-03-10), the same version as the jar. The clone was deleted after the findings (AGENTS.md disk
hygiene); the excerpts read from it are in `ports/_shared/evidence/mifa/upstream-source.log` and
`.../if-addon-source.log`.
Raw measurements: `ports/_shared/evidence/mifa/{jar-inventory,recipes-tags,upstream-source,
if-addon-source,parent-port,sdk-surface,convention-tags}.log`.

## What the jar actually contains (measured, not from the name)

The mod's own description is exact: *"This mod adds additional efficiency, processing and speed
addons to Industrial Foregoing."* There is no block, no machine, no block entity, no menu, no
command, no entity and no worldgen in the jar.

| Half | Count | Detail |
|---|---:|---|
| blocks / blockstates / block models | **0** | `data/*/horizon/block/`, `blockstates/`, `models/block/` are all absent |
| items | **19** | 18 addons (3 kinds × tiers 3–8) + `netherite_gear` |
| item models | 19 | `assets/mifa/models/item/*.json`, all `minecraft:item/generated` |
| textures | 22 | 19 item textures + the three `*_addon_0` base textures the tiers derive from |
| lang | 1 | `assets/mifa/lang/en_us.json`, **3 keys** (see the naming finding below) |
| classes | 31 | 3 item classes, `ItemRegistry` (+18 anon subclasses), `TagRegistry` (+1), mod entry, constants, 5 datagen providers |
| recipes | **22** | 21 `industrialforegoing:dissolution_chamber` + 1 `minecraft:smithing_transform` |
| advancements | 23 | 18 addon unlocks + 3 re-declared parent tier-2 unlocks + the smithing unlock + a copy of vanilla's `recipes/root` |
| loot tables | 0 | nothing to loot |
| tags | 5 | `c:gears` + its four material sub-tags |
| menus / BE / entities / worldgen / commands | **0** | no `data/mifa/` directory exists at all |

`data/industrialforegoing/**` and `data/minecraft/**` are the only data namespaces; **the mod ships
no `data/mifa/` file**, so every recipe, advancement and tag it adds lands in the *parent's*
namespace or in the convention namespace.

## The 19 items, with the payload each carries

The augment value is a **data component on the item**, `titanium:augments` (Titanium's
`AugmentWrapper`), stamped by Industrial Foregoing's own item class when the item stack is created.
mifa's classes pass only a tier number.

| Item | Tier | `titanium:augments` | Where the value comes from |
|---|---:|---|---|
| `mifa:efficiency_addon_3…8` | 3…8 | `Efficiency` = 0.7, 0.6, 0.5, 0.39999998, 0.3, 0.19999999 | IF `EfficiencyAddonItem`: `1 - tier * 0.1f` |
| `mifa:speed_addon_3…8` | 3…8 | `Speed` = 4.0, 5.0, 6.0, 7.0, 8.0, 9.0 | IF `SpeedAddonItem`: `1 + tier` |
| `mifa:processing_addon_3…8` | 3…8 | `Processing` = 4.0 … 9.0 | IF `ProcessingAddonItem`: `1 + tier` |
| `mifa:netherite_gear` | — | none | IF `RecipelessCustomItem` (a plain item) |

The two `0.39999998` / `0.19999999` values are the f32 form of `1 - tier*0.1f` in the parent
class; they are recorded, not "fixed", because they are the parent's arithmetic.

## The recipe chain (every carried recipe, measured)

All 21 addon recipes are the **parent's machine type**, `industrialforegoing:dissolution_chamber`:
8 item inputs, an `inputFluid`, a `processingTime`, and an output that carries the augment
component. Nine of them name ingredients that only the parent ships
(`industrialforegoing:efficiency_addon_tier_1|2`, `…processing_addon_tier_1|2`,
`…speed_addon_tier_1|2`) and three of them *produce* parent items (the re-declared tier-2 recipes).

| Recipe group | Inputs (beyond 2× glass pane + `c:gears/netherite`) | Fluid | Time |
|---|---|---|---:|
| `*_addon_3` | `c:ores/netherite_scrap`, `netherite_scrap`, **parent tier 2**, 2× (`c:rods/blaze` \| `sugar` \| furnaces+crafting tables) | `industrialforegoing:pink_slime` 3,000 mB | 600 |
| `*_addon_4` | `sculk`, `echo_shard`, **own tier 3**, same catalysts | `c:experience` 4,000 mB (**tag**, not a fluid id) | 800 |
| `*_addon_5` | `c:obsidians/crying`, `totem_of_undying`, own tier 4 | `industrialforegoing:sludge` 5,000 mB | 1,000 |
| `*_addon_6` | `amethyst_block`, `shulker_shell`, own tier 5 | `industrialforegoing:biofuel` 6,000 mB | 1,200 |
| `*_addon_7` | `beacon`, `c:nether_stars`, own tier 6 | `industrialforegoing:ether_gas` 7,000 mB | 1,400 |
| `*_addon_8` | `dragon_head`, `dragon_breath`, own tier 7 | `industrialforegoing:ether_gas` 8,000 mB | 1,600 |
| 3 × re-declared tier 2 | `c:dusts/redstone` ×2, own tier 1, catalysts | `industrialforegoing:latex` 1,000 mB | 200 |

The one **vanilla-type** recipe is `minecraft:smithing_transform` →
`mifa:netherite_gear` from `#c:gears/diamond` + `#c:ingots/netherite` +
`minecraft:netherite_upgrade_smithing_template`.

The five tags, verbatim, and what their only value is:

```
data/c/tags/item/gears.json           -> #c:gears/iron, #c:gears/gold, #c:gears/diamond, #c:gears/netherite
data/c/tags/item/gears/iron.json      -> industrialforegoing:iron_gear        (a PARENT item)
data/c/tags/item/gears/gold.json      -> industrialforegoing:gold_gear        (a PARENT item)
data/c/tags/item/gears/diamond.json   -> industrialforegoing:diamond_gear     (a PARENT item)
data/c/tags/item/gears/netherite.json -> mifa:netherite_gear                  (the mod's own)
```

## Where the behaviour actually lives (all of it in the parent)

Read (shallow clones, deleted after the findings; excerpts in the evidence logs) from the parent at
`ce2852db4b34af3ab1b9637cff0b327d4bb561d5` (`Industrial-Foregoing`, branch `1.21`) and mifa at
`5fc3ac84` (tag `2.1.0`):

| Behaviour | Owner | Evidence |
|---|---|---|
| the augment value an addon carries | **parent** (`EfficiencyAddonItem.verifyComponentsAfterLoad` → `AugmentWrapper.setType(stack, AugmentTypes.EFFICIENCY, 1 - tier*0.1f)`; `SpeedAddonItem` the same with `1 + tier`) | `src/main/java/com/buuz135/industrial/item/addon/{AddonItem,SpeedAddonItem,EfficiencyAddonItem}.java` |
| right-click a machine with the addon → it goes into an augment slot | **parent** (`AddonItem.useOn`: `entity instanceof MachineTile<?>` → `machineTile.canAcceptAugment(stack)` → `getAugmentInventory()`) | same file |
| the speed/efficiency/processing multipliers being *applied* | **parent** (`MachineTile`'s augment inventory + Titanium's augment arithmetic) | parent `MachineTile` |
| the tooltip ("Speed +300 %", "Efficiency -30 %") | **parent** (`addTooltipDetails`) | same files |
| the tier number, the item id, the model/texture, the recipe | mifa | `ItemRegistry`, jar assets/data |

mifa's three item classes are 30 lines each and every one is the same shape:

```java
public class ModSpeedAddonItem extends SpeedAddonItem {
    public int tier;
    public ModSpeedAddonItem(int tier, TitaniumTab group) {
        super(tier, group);          // <- all behaviour, all values: the parent's class
        this.tier = tier;
    }
}
```

`ItemRegistry.generateFeatures` only registers items; `ModRecipeProvider` only writes data.

## Dependency surfaces mifa needs from its parent, and the parent port's state

The parent (`ports/industrialforegoing`, 0.2.2, ledger `ported`) is **the Water Condensator only**:
one block, one block entity, an FE buffer, a water tank, the condensation rule, four commands. Its
shipped content is 17 files and contains no item but the condensator's own block item
(`ports/_shared/evidence/mifa/parent-port.log`); its own coverage table says
`augments, comparator, config file — not ported (gaps 3, 7, 8)` and
`the other ~71 blocks and their recipes — not ported (gap 9)`, dissolution chamber included.

So mifa needs **four** parent surfaces that do not exist in the port:

| # | Surface mifa needs | Parent state | Symbol |
|---|---|---|---|
| 1 | a machine with an **augment inventory** that accepts an addon item | absent | `MachineTile.getAugmentInventory`, IF gap 3 |
| 2 | a machine that **reads `titanium:augments`** and applies Speed/Efficiency/Processing to its tick | absent (no augment reader anywhere; also `titanium` is a `library` row mapped to Horizon APIs, and `augment` appears **0×** in the whole SDK api-source) | `AugmentTypes`, Titanium |
| 3 | the **dissolution chamber** (the machine that runs all 21 recipes) | absent (one of the ~71 unported blocks) | `industrialforegoing:dissolution_chamber`, IF gap 9 |
| 4 | the **gear items** the tags and every recipe name | absent (the port ships no items) | `industrialforegoing:{iron,gold,diamond}_gear` |

Two further blockers are the port's own, not the parent's:- **`titanium:augments` is not a component type the pin knows.** A content item that names an
  unregistered component type fails when the content root is built (`docs/mods.md:162-167`:
  *"Unknown types fail when Horizon builds the content root"*), so the payload can only be carried
  by a native part that registers the type with `native_component_types` (API 65) — and then
  **nothing in the world reads it**.
- **The convention tags the recipes name are empty in a Horizon world.** The prepared 26.3
  resources ship **no `c:` tag group at all** (`block-tags.json`: 300 groups, 0 `c:`), and
  `docs/mods.md:287` says a mod may only *add to* `data/c/tags/`. So `c:rods/blaze`,
  `c:glass_panes/colorless`, `c:dusts/redstone`, `c:ores/netherite_scrap`, `c:obsidians/crying`,
  `c:nether_stars`, `c:player_workstations/*` are empty unless the port declares them, and
  `c:gears/diamond` is empty because its single value is the absent parent item.

## Upstream observations (recorded for whoever ports it later)

1. **The lang file is incomplete, and a naive carry shows raw translation keys.** The jar's
   `en_us.json` has three keys — `item.mifa.netherite_gear` and two creative-tab names. The 18
   addon items have **no `item.mifa.*` name** because the parent's class builds their name from
   the parent's keys (`getDescriptionId()` = `item.industrialforegoing.addon` +
   `item.industrialforegoing.{speed|efficiency|processing}` + `item.industrialforegoing.tier` +
   the tier). A port must declare the 18 names itself (`Speed Addon (Tier 3)`, …) or the items
   render as keys.
2. **The parent's tier-2 recipes are re-declared under a different id with different ingredients.**
   `ModRecipeProvider` registers a *second* recipe for `industrialforegoing:efficiency_addon_tier_2`
   (and processing/speed) from `c:dusts/redstone` ×2, glass panes ×2, `c:gears/diamond` ×1,
   `industrialforegoing:*_addon_tier_1`, and two catalysts — while the parent's own recipe at
   `data/industrialforegoing/recipe/dissolution_chamber/efficiency_addon_tier_2.json` uses
   redstone ×2, glass pane ×2, `c:gears/diamond` **×2**, blaze rods ×2 and no tier-1 addon. The
   dotted filename (`industrialforegoing.efficiency_addon_tier_2.json`) is
   `BuiltInRegistries.ITEM.getKey(...).toShortLanguageKey()`. Both load, so the game offers two
   different crafts for the same parent item, the mifa one cheaper. A port that carries it should
   either drop it (it is the parent's item, not mifa's) and say so, or reproduce it as the second
   recipe it is — with the duplicate stated.
3. **The tier-4 fluid is a tag, not a fluid id** (`{"amount": 4000, "tag": "c:experience"}`). It is
   deliberate for IF's own serializer (`SizedFluidIngredient`), but a port must resolve the tag
   itself: a mod fluid cannot live in a block-entity tank at this pin
   (`machines/native_fluids.rs:206` refuses anything but water/lava), so a dissolution-chamber
   slice would have to read `c:experience`'s membership from data, not insert it.

## Sources read (no decompilation)

| Source | What was extracted |
|---|---|
| the jar (`unzip`/`zipfile`) | file inventory, every recipe JSON, every tag JSON, `mods.toml`, `en_us.json`, item models |
| upstream mifa @ `5fc3ac84` (clone deleted) | the 3 item classes, `ItemRegistry`, `TagRegistry`, `ModRecipeProvider`, `ModLanguageProvider` — all behaviour delegated to the parent |
| upstream Industrial Foregoing @ `ce2852db` (clone deleted) | `AddonItem.useOn`, `SpeedAddonItem`/`EfficiencyAddonItem` augment values, recipes and tooltips |
| `ports/industrialforegoing` (our port) | shipped content, Part list, its own coverage table (gaps 3, 7, 8, 9) |
| `ports/_shared/sdk/0a875da/crates` + `surface.json` | `augment` 0 hits, `titanium` 0 hits; recipe surface is `register_raw_recipe_serializer`/`native_recipes_of_type` (API 36) for a machine the mod owns |
| `horizon/docs/{mods,native-mods}.md` | component-type registration (API 65), unknown component types fail, convention-tag rule, API 36 |

No jar was decompiled: the class list and every value come from the shipped JSON, the public
repository, and the parent's public repository.

## After-state (2026-11-21): what the three parent slices resolved

| Was missing | Now | Where |
|---|---|---|
| `titanium:augments` (component type) | registered by `ports/industrialforegoing` 0.2.3 (`fn component_types`) | `src/lib.rs` |
| the augment slot + the speed/efficiency arithmetic | `Machine::use_item_on` seats, `Augments::from_slots` reads, the readout prints both | `src/lib.rs`, `src/runtime.rs` |
| `industrialforegoing:dissolution_chamber` (machine **and** recipe type) | 0.2.5: block + block entity + its own type + a read-only serializer (API 36), 23 recipes | `src/chamber.rs`, `src/dissolution.rs` |
| `industrialforegoing:{iron,gold,diamond}_gear`, `{efficiency,speed}_addon_tier_1|2` | shipped by 0.2.3/0.2.5, with `c:gears/*` and `c:plastics` | `data/industrialforegoing/horizon/item/` |
| the convention tags (13 `c:` symbols) | declared by this package (9) and found in the parent (4) | `data/c/tags/item/` |

Still missing, and each one is a `blocked(<symbol>)` in `notes.md`: the `c:experience` fluid tag
(no member, and the parent's `fluid_of` does not read `tag`), the `sludge` and `biofuel` fluid keys
(the parent declares `latex`, `pink_slime`, `ether_gas` only), and the parent's
`processing_addon_tier_1|2` (the parent port ships no processing addon; its `AugmentType::ALL` also
has no `Processing`, so even the six processing items this package carries cannot be seated yet).

Measurement: `ports/_shared/evidence/mifa/resolve-symbols-after-0.2.5.log`
(`python3 tools/resolve_symbols.py`), 61 symbols, **56 resolve / 5 do not**.
