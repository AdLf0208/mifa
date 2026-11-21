#!/usr/bin/env python3
"""Generate (and check) mifa's content files from the jar's own facts.

mifa is a content-only package: its whole product is 19 item declarations with
their `titanium:augments` payload, the recipes that make them, the two tags its
recipes bind to and the names the parent's keys would have built. Nothing about
it is executable, so the "rule" that a code port keeps in a pure `runtime.rs`
lives here as one table, and `--check` is its test: every file in the tree must
equal what the table generates, and every carried value must be the one the jar
declares.

    python3 tools/gen_content.py            # (re)write the files
    python3 tools/gen_content.py --check     # exit 1 when the tree drifted

The values are **the jar's own literals**, not recomputed: the parent's
`EfficiencyAddonItem` is `1 - tier * 0.1f`, whose f32 forms are
`0.39999998` (tier 6) and `0.19999999` (tier 8). Writing `0.4` instead would
change tier 6's bar from 39 ticks to 40 (`floor(100 * 0.39999998f)` = 39,
`floor(100 * 0.4f)` = 40), so the literals are part of the behaviour and the
differential asserts the 39.

Three adaptations from the jar, each recorded in notes.md:

* the files live in `data/mifa/` — the pin's fence allows a mod only its own
  namespaces plus `data/c/tags/`, so the jar's `data/industrialforegoing/recipe/`
  and `data/minecraft/recipe/` cannot be carried where upstream put them;
  the recipe ids become `mifa:…` and the parent's machine reads them all the same
  (`recipes_of_type`), because it keys on the recipe **type**, not the id.
* `neoforge:conditions` is dropped: it is a NeoForge loader key, and both the
  package's build and the game's loader refuse keys a loader does not know.
* ingredients are the pin's shorthand (`"minecraft:sculk"`, `"#c:rods/blaze"`)
  rather than the jar's `{"item": …}`/`{"tag": …}` objects: the parent's 23
  shipped recipes and the pin's own files use the shorthand, and API 36's raw
  reader is documented to read "the usual fields".

Blocked recipes are **not** generated (a recipe that cannot match is dead data):
their tiers are named in notes.md with the symbol that blocks them.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

PORT = Path(__file__).resolve().parents[1]

# ---------------------------------------------------------------------------
# The tables: everything the jar declares, verbatim
# ---------------------------------------------------------------------------

KINDS = ("efficiency", "processing", "speed")

# The parent's item classes stamp these; the jar's recipe outputs repeat them.
# tier -> (efficiency value, speed/processing value), as the jar writes them.
VALUES = {
    3: ("0.7", "4.0"),
    4: ("0.6", "5.0"),
    5: ("0.5", "6.0"),
    6: ("0.39999998", "7.0"),
    7: ("0.3", "8.0"),
    8: ("0.19999999", "9.0"),
}

# The re-declared parent tier-2 outputs (ModRecipeProvider), same literals.
TIER_TWO_VALUES = {"efficiency": "0.8", "processing": "3.0", "speed": "3.0"}

# `AugmentTypes`: which key of `titanium:augments` each kind writes.
KEY = {"efficiency": "Efficiency", "processing": "Processing", "speed": "Speed"}

# The per-kind catalyst pair the jar's `_3…_8` recipes share.
CATALYSTS = {
    "efficiency": ["#c:rods/blaze", "#c:rods/blaze"],
    "processing": [
        "#c:player_workstations/furnaces",
        "#c:player_workstations/crafting_tables",
    ],
    "speed": ["minecraft:sugar", "minecraft:sugar"],
}


def addon(kind: str, tier: int) -> dict:
    """One addon item file: the payload the parent's class would stamp."""
    efficiency, other = VALUES[tier]
    value = efficiency if kind == "efficiency" else other
    return {
        "components": {"titanium:augments": {KEY[kind]: json_number(value)}},
        "max_stack_size": 16,
        "template": "minecraft:stick",
    }


def json_number(text: str):
    """A JSON number that keeps the jar's literal: `0.39999998` stays that."""
    return float(text) if "." in text else int(text)


def recipe(kind: str, tier: int, previous: str, fluid: str, mb: int, ticks: int) -> dict:
    """One dissolution-chamber recipe, in the pin's shorthand ingredient form."""
    if tier == 3:
        head = [
            "#c:ores/netherite_scrap",
            "minecraft:netherite_scrap",
            "#c:glass_panes/colorless",
            "#c:glass_panes/colorless",
            "#c:gears/netherite",
            previous,
        ]
    elif tier == 7:
        head = [
            "minecraft:beacon",
            "#c:nether_stars",
            "#c:glass_panes/colorless",
            "#c:glass_panes/colorless",
            "#c:gears/netherite",
            previous,
        ]
    elif tier == 8:
        head = [
            "minecraft:dragon_head",
            "minecraft:dragon_breath",
            "#c:glass_panes/colorless",
            "#c:glass_panes/colorless",
            "#c:gears/netherite",
            previous,
        ]
    else:  # the re-declared parent tier 2: redstone, glass, the gear, the tier 1
        head = [
            "#c:dusts/redstone",
            "#c:dusts/redstone",
            "#c:glass_panes/colorless",
            "#c:glass_panes/colorless",
            "#c:gears/diamond",
            previous,
        ]
    output = (
        f"industrialforegoing:{kind}_addon_tier_2"
        if tier == 2
        else f"mifa:{kind}_addon_{tier}"
    )
    value = TIER_TWO_VALUES[kind] if tier == 2 else (
        VALUES[tier][0] if kind == "efficiency" else VALUES[tier][1]
    )
    return {
        "type": "industrialforegoing:dissolution_chamber",
        "input": head + CATALYSTS[kind],
        "inputFluid": {"amount": mb, "fluid": fluid},
        "output": {
            "components": {"titanium:augments": {KEY[kind]: json_number(value)}},
            "count": 1,
            "id": output,
        },
        "processingTime": ticks,
    }


# Carried: the tiers whose every ingredient resolves at the pin. `_4` (a
# `c:experience` fluid tag with no member — not even a fluid id the parent's
# reader takes), `_5` (`industrialforegoing:sludge`) and `_6`
# (`industrialforegoing:biofuel`) are the blocked ones, in notes.md.
CARRIED = [
    # (kind, tier, the previous tier item, fluid, mB, ticks, file stem)
    ("efficiency", 3, "industrialforegoing:efficiency_addon_tier_2",
     "industrialforegoing:pink_slime", 3000, 600, "efficiency_addon_3"),
    ("efficiency", 7, "mifa:efficiency_addon_6",
     "industrialforegoing:ether_gas", 7000, 1400, "efficiency_addon_7"),
    ("efficiency", 8, "mifa:efficiency_addon_7",
     "industrialforegoing:ether_gas", 8000, 1600, "efficiency_addon_8"),
    # `processing_addon_3` and the processing tier-2 re-declaration are not
    # carried: both name `industrialforegoing:processing_addon_tier_2`, and the
    # parent port ships no processing addon at all (its item set is the two
    # efficiency and the two speed tiers). notes.md carries the symbol.
    ("processing", 7, "mifa:processing_addon_6",
     "industrialforegoing:ether_gas", 7000, 1400, "processing_addon_7"),
    ("processing", 8, "mifa:processing_addon_7",
     "industrialforegoing:ether_gas", 8000, 1600, "processing_addon_8"),
    ("speed", 3, "industrialforegoing:speed_addon_tier_2",
     "industrialforegoing:pink_slime", 3000, 600, "speed_addon_3"),
    ("speed", 7, "mifa:speed_addon_6",
     "industrialforegoing:ether_gas", 7000, 1400, "speed_addon_7"),
    ("speed", 8, "mifa:speed_addon_7",
     "industrialforegoing:ether_gas", 8000, 1600, "speed_addon_8"),
    # ModRecipeProvider's re-declarations: the parent item, a cheaper craft.
    ("efficiency", 2, "industrialforegoing:efficiency_addon_tier_1",
     "industrialforegoing:latex", 1000, 200,
     "industrialforegoing.efficiency_addon_tier_2"),
    ("speed", 2, "industrialforegoing:speed_addon_tier_1",
     "industrialforegoing:latex", 1000, 200,
     "industrialforegoing.speed_addon_tier_2"),
]

# The convention tags this port must declare: the pin's prepared resources ship
# **no** `c:` group at all, so a tag nobody declares is empty and the recipe
# naming it is dropped by the parent's own table. Values are the convention's,
# the block whole (`c:ores/netherite_scrap` is the ore that drops the scrap).
CONVENTION_TAGS = {
    "c:rods/blaze": ["minecraft:blaze_rod"],
    "c:glass_panes/colorless": ["minecraft:glass_pane"],
    "c:dusts/redstone": ["minecraft:redstone"],
    "c:ores/netherite_scrap": ["minecraft:ancient_debris"],
    "c:obsidians/crying": ["minecraft:crying_obsidian"],
    "c:nether_stars": ["minecraft:nether_star"],
    "c:player_workstations/furnaces": [
        "minecraft:furnace",
        "minecraft:blast_furnace",
        "minecraft:smoker",
    ],
    "c:player_workstations/crafting_tables": ["minecraft:crafting_table"],
    "c:ingots/netherite": ["minecraft:netherite_ingot"],
}

# The jar's own five tags, carried as it ships them.
GEAR_TAGS = {
    "c:gears": [
        "#c:gears/iron",
        "#c:gears/gold",
        "#c:gears/diamond",
        "#c:gears/netherite",
    ],
    "c:gears/iron": ["industrialforegoing:iron_gear"],
    "c:gears/gold": ["industrialforegoing:gold_gear"],
    "c:gears/diamond": ["industrialforegoing:diamond_gear"],
    "c:gears/netherite": ["mifa:netherite_gear"],
}

NAMES = {
    "netherite_gear": "Netherite Gear",
}


def item_ids() -> list[str]:
    ids = [f"{kind}_addon_{tier}" for kind in KINDS for tier in VALUES]
    return ids + ["netherite_gear"]


def display_name(stem: str) -> str:
    """The name the parent's key chain would build (`Addon: Speed Tier 3`)."""
    if stem in NAMES:
        return NAMES[stem]
    kind, _, tier = stem.partition("_addon_")
    return f"Addon: {kind.capitalize()} Tier {tier}"


# ---------------------------------------------------------------------------
# The file map
# ---------------------------------------------------------------------------


def files() -> dict[str, str]:
    """Every generated file: relative path -> its exact content."""
    out: dict[str, str] = {}

    def put(path: str, value) -> None:
        out[path] = json.dumps(value, indent=2, sort_keys=True) + "\n"

    # The 19 items and their models (26.3's item definition + the model it names).
    for item in item_ids():
        if item == "netherite_gear":
            put(f"data/mifa/horizon/item/{item}.json", {"template": "minecraft:stick"})
        else:
            kind, _, tier = item.partition("_addon_")
            put(f"data/mifa/horizon/item/{item}.json", addon(kind, int(tier)))
        put(
            f"assets/mifa/items/{item}.json",
            {"model": {"type": "minecraft:model", "model": f"mifa:item/{item}"}},
        )
        put(
            f"assets/mifa/models/item/{item}.json",
            {
                "parent": "minecraft:item/generated",
                "textures": {"layer0": f"mifa:item/{item}"},
            },
        )

    # The names the jar has no keys for (the parent's `getDescriptionId()` builds
    # them at runtime); the creative tab is the jar's `itemGroup.mifa_addons`.
    lang = {f"item.mifa.{item}": display_name(item) for item in item_ids()}
    lang["itemGroup.mifa.addons"] = "More Industrial Foregoing Addons"
    put("assets/mifa/lang/en_us.json", lang)
    put(
        "data/mifa/horizon/creative_tab/addons.json",
        {
            "title": "itemGroup.mifa.addons",
            "icon": "mifa:speed_addon_8",
            "items": [f"mifa:{item}" for item in item_ids()],
        },
    )

    # The 12 carried chamber recipes.
    for kind, tier, previous, fluid, mb, ticks, stem in CARRIED:
        put(
            f"data/mifa/recipe/dissolution_chamber/{stem}.json",
            recipe(kind, tier, previous, fluid, mb, ticks),
        )

    # The one vanilla-type recipe: a smithing transform, in the pin's own shorthand.
    put(
        "data/mifa/recipe/netherite_gear_smithing.json",
        {
            "type": "minecraft:smithing_transform",
            "template": "minecraft:netherite_upgrade_smithing_template",
            "base": "#c:gears/diamond",
            "addition": "#c:ingots/netherite",
            "result": {"count": 1, "id": "mifa:netherite_gear"},
        },
    )

    # The tags, in `data/c/tags/item/<path>.json`.
    for tag, values in {**CONVENTION_TAGS, **GEAR_TAGS}.items():
        path = tag.split(":", 1)[1]
        put(f"data/c/tags/item/{path}.json", {"values": values})
    return out


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------


def main(argv: list[str]) -> int:
    check = "--check" in argv
    tree = files()
    drift = 0
    for name, text in sorted(tree.items()):
        path = PORT / name
        if check:
            want = text.encode()
            if not path.is_file():
                print(f"MISSING {name}")
                drift += 1
            elif path.read_bytes() != want:
                print(f"DRIFT   {name}")
                drift += 1
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
    if check:
        # Nothing in the tree that the table does not generate, for these roots.
        for root in ("data/mifa", "assets/mifa/lang", "assets/mifa/items", "assets/mifa/models"):
            for path in sorted((PORT / root).rglob("*.json")):
                name = str(path.relative_to(PORT))
                if name not in tree:
                    print(f"EXTRA   {name}")
                    drift += 1
        print(f"gen_content: {len(tree)} generated files, {drift} drifted")
        return 1 if drift else 0
    print(f"gen_content: wrote {len(tree)} files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
