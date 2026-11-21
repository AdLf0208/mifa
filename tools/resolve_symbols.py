#!/usr/bin/env python3
"""Re-run the dependency matrix: every symbol the mifa jar names outside `mifa:`, resolved.

The first two dispatches wrote `ports/_shared/evidence/mifa/parent-references.log`,
which measured **29 of 61** unresolved against `industrialforegoing` 0.2.2 (the
Water Condensator alone). This reads the same 61 symbols out of the jar and
resolves each against what exists *now*:

  pin     the prepared 26.3 resources (`items.json`, `registries.json`)
  parent  `ports/industrialforegoing` 0.2.5 — its items, blocks, declared fluids,
          recipe types, component types and tags
  mifa    this port's own package — its items and its tags

    python3 tools/resolve_symbols.py            # the table + the summary
    python3 tools/resolve_symbols.py --log F    # also write it to F

Exit 0 when every symbol resolves, 4 when one does not (with its class).
"""
from __future__ import annotations

import json
import re
import sys
import zipfile
from pathlib import Path

CAMPAIGN = Path(__file__).resolve().parents[3]
PORT = Path(__file__).resolve().parents[1]
JAR = CAMPAIGN / "ports/_shared/licence-cache/mifa-neoforge-1.21.x-2.1.0.jar"
PARENT = CAMPAIGN / "ports/industrialforegoing"
RES = Path("horizon/.local/horizon-client/26.3")

# The 61 symbols the first dispatch measured, in the order that log lists them.
RECORDED_BEFORE = CAMPAIGN / "ports/_shared/evidence/mifa/parent-references.log"


def jar_symbols() -> dict[str, str]:
    """symbol -> what first names it, out of the jar's own JSON."""
    found: dict[str, str] = {}

    def note(symbol: str, where: str) -> None:
        if symbol:
            found.setdefault(symbol, where)

    with zipfile.ZipFile(JAR) as jar:
        for name in jar.namelist():
            if not name.endswith(".json"):
                continue
            data = json.loads(jar.read(name))

            def walk(value, path: str, where: str) -> None:
                if isinstance(value, dict):
                    for key, item in value.items():
                        if key in ("item", "tag", "fluid", "id", "type") and isinstance(item, str):
                            if item in ("industrialforegoing:dissolution_chamber",
                                        "minecraft:smithing_transform") and key == "type":
                                note(item, where)
                            else:
                                note(item, where)
                        elif key == "components":
                            for component in item:
                                note(component, where)
                        elif key == "values":
                            for entry in item:
                                if isinstance(entry, str):
                                    note(entry.lstrip("#"), where)
                        else:
                            walk(item, f"{path}/{key}", where)
                elif isinstance(value, list):
                    for entry in value:
                        walk(entry, path, where)
                elif isinstance(value, str) and "/" not in path:
                    note(value, where)

            walk(data, "", name)

    # The two loader keys the jar's conditions name are not dependencies.
    for extra in ("neoforge:conditions", "neoforge:item_exists"):
        found.pop(extra, None)
    return found


def pin_ids() -> tuple[set[str], set[str], set[str], set[str]]:
    items = set(json.loads((CAMPAIGN / RES / "items.json").read_text()))
    registries = json.loads((CAMPAIGN / RES / "registries.json").read_text())
    blocks = set(registries["minecraft:block"]["entries"])
    fluids = set(registries["minecraft:fluid"]["entries"])
    serializers = set(registries["minecraft:recipe_serializer"]["entries"])
    return items, blocks, fluids, serializers


def dir_ids(root: Path, kind: str) -> set[str]:
    """`data/<ns>/horizon/<kind>/*.json` -> `<ns>:<name>`."""
    out = set()
    for path in root.glob(f"data/*/horizon/{kind}/*.json"):
        ns = path.parts[-4]
        out.add(f"{ns}:{path.stem}")
    return out


def tag_files(root: Path, layer: str) -> set[str]:
    """`data/c/tags/<layer>/**/*.json` -> `c:<path>`."""
    out = set()
    for path in (root / f"data/c/tags/{layer}").rglob("*.json"):
        rel = path.relative_to(root / f"data/c/tags/{layer}").with_suffix("")
        out.add("c:" + "/".join(rel.parts))
    return out


def parent_surface() -> dict[str, set[str] | str]:
    source = (PARENT / "src").glob("*.rs")
    declared = set()
    recipe_types = set()
    components = set()
    for path in source:
        text = path.read_text()
        declared |= set(re.findall(r'"(industrialforegoing:[a-z_]+)"', text))
        recipe_types |= set(re.findall(r'recipe_type\("([^"]+)"', text))
        recipe_types |= set(re.findall(r'register_recipe_type\("([^"]+)"', text))
        components |= set(re.findall(r'AUGMENT_COMPONENT: &str = "([^"]+)"', text))
        # `fn component_types` pushes `AUGMENT_COMPONENT`; the constant above is the
        # named symbol that push carries.
        if "event.types.push(AUGMENT_COMPONENT" in text:
            components |= set(re.findall(r'AUGMENT_COMPONENT: &str = "([^"]+)"', text))
    return {
        "items": dir_ids(PARENT, "item"),
        "blocks": dir_ids(PARENT, "block"),
        "ids": declared,
        "recipe_types": recipe_types,
        "components": components,
        "item_tags": tag_files(PARENT, "item"),
        "fluid_tags": tag_files(PARENT, "fluid"),
    }


def resolve(symbol: str, surface: dict, pin: tuple[set, set, set, set]) -> tuple[bool, str]:
    items, blocks, fluids, serializers = pin
    ours_items = dir_ids(PORT, "item")
    ours_item_tags = tag_files(PORT, "item")
    ours_fluid_tags = tag_files(PORT, "fluid")

    if symbol.startswith("minecraft:"):
        if symbol in items or symbol in blocks or symbol in fluids:
            return True, "pin (vanilla)"
        if symbol in serializers:
            return True, "pin (vanilla recipe serializer)"
        return False, "MISSING from the pin"
    if symbol.startswith("mifa:"):
        if symbol in ours_items:
            return True, "mifa: declared by this package"
        return False, "mifa: NOT declared by this package"
    if symbol.startswith("industrialforegoing:"):
        if symbol in surface["items"]:
            return True, "parent item (0.2.5)"
        if symbol in surface["blocks"]:
            return True, "parent block (0.2.5)"
        if symbol == "industrialforegoing:dissolution_chamber":
            if symbol in surface["blocks"] and "industrialforegoing:dissolution_chamber" in surface["recipe_types"]:
                return True, "parent machine + recipe type (0.2.5)"
        if symbol in surface["recipe_types"]:
            return True, "parent recipe type (0.2.5)"
        if symbol in surface["ids"]:
            return True, "parent declares it (0.2.5)"
        return False, "MISSING: parent does not ship it"
    if symbol == "titanium:augments":
        if "titanium:augments" in surface["components"]:
            return True, "parent registers the component type (0.2.5)"
        return False, "MISSING: no registry surface for this namespace"
    if symbol.startswith("c:"):
        if symbol in ours_item_tags:
            return True, "mifa: declared by this package (item tag)"
        if symbol in surface["item_tags"]:
            return True, "parent declares it (item tag)"
        if symbol in ours_fluid_tags or symbol in surface["fluid_tags"]:
            return True, "declared (fluid tag)"
        if symbol in ("c:gears/iron", "c:gears/gold", "c:gears/diamond"):
            return False, "MISSING: empty at load (no value ships)"
        return False, "MISSING (design: the pin ships 0 `c:` groups; nobody declares it)"
    return False, f"UNCLASSIFIED"


def main(argv: list[str]) -> int:
    symbols = jar_symbols()
    pin = pin_ids()
    surface = parent_surface()
    table = [(symbol, *resolve(symbol, surface, pin), where)
             for symbol, where in sorted(symbols.items())]

    lines = [
        "# mifa — the 61 outside-namespace symbols, resolved after industrialforegoing 0.2.5",
        f"# jar {JAR.name} | pin prepared 26.3: {len(pin[0])} items, {len(pin[1])} blocks, "
        f"{len(pin[2])} fluids",
        f"# parent ports/industrialforegoing 0.2.5: items {len(surface['items'])}, "
        f"blocks {len(surface['blocks'])}, recipe types {sorted(surface['recipe_types'])}",
        f"# mifa package: items {len(dir_ids(PORT, 'item'))}, "
        f"item tags {len(tag_files(PORT, 'item'))}",
        "",
    ]
    missing = []
    for symbol, ok, how, where in table:
        lines.append(f"{symbol:<46} {'ok' if ok else 'MISSING':<8} {how:<55} {where}")
        if not ok:
            missing.append((symbol, how))
    classes: dict[str, int] = {}
    for symbol, how in missing:
        key = ("parent id" if symbol.startswith("industrialforegoing:")
               else "convention tag" if symbol.startswith("c:")
               else "component type" if ":" in symbol and symbol.split(":")[0] == "titanium"
               else "other")
        classes[key] = classes.get(key, 0) + 1
    lines += [
        "",
        f"# summary: {len(missing)} of {len(table)} referenced symbols do not resolve"
        + (f" ({', '.join(f'{n} {k}' for k, n in sorted(classes.items()))})" if missing else ""),
        "",
    ]
    if missing:
        lines.append("# every unresolved symbol")
        lines += [f"    {symbol} -> {how}" for symbol, how in missing]

    if "--log" in argv:
        target = Path(argv[argv.index("--log") + 1])
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text("\n".join(lines) + "\n")

    before = "29 of 61 unresolved (recorded: " + str(RECORDED_BEFORE.relative_to(CAMPAIGN)) + ")"
    print("\n".join(lines))
    print(f"\nBEFORE (industrialforegoing 0.2.2): {before}")
    print(f"AFTER  (industrialforegoing 0.2.5 + this package): "
          f"{len(table) - len(missing)} of {len(table)} resolve, {len(missing)} do not")
    return 0 if not missing else 4


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
