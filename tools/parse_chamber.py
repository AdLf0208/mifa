#!/usr/bin/env python3
"""Parse a `/industrialforegoing info` line of a **dissolution chamber** into shell variables.

Called by `tools/e2e.sh` as `eval "$(python3 tools/parse_chamber.py "$LINE")"`: it prints one
`NAME=value` line per field, all shell-quoted, plus `ok=1` when the line is a chamber's (and
`ok=0` with nothing else when it is not). The line is the machine's whole state:

    Dissolution Chamber at [202, 101, 0]: 1000/10000 FE, input industrialforegoing:latex
    1750/8000 mB, output empty 0/16000 mB, progress 0/0, recipe none, items 2, recipes 23/23,
    capability industrialforegoing:latex 1750 mB, augments speed 1 efficiency 1.00,
    facing west, t=375
"""
import re
import shlex
import sys

PATTERN = re.compile(
    r"Dissolution Chamber at \[(?P<x>-?\d+), (?P<y>-?\d+), (?P<z>-?\d+)\]: "
    r"(?P<energy>-?\d+)/(?P<efe>-?\d+) FE, "
    r"input (?P<fluid>\S+) (?P<fin>-?\d+)/(?P<ficap>-?\d+) mB, "
    r"output (?P<of>empty|\S+) (?P<fo>-?\d+)/(?P<ofcap>-?\d+) mB, "
    r"progress (?P<progress>-?\d+)/(?P<length>-?\d+), "
    r"recipe (?P<recipe>\S+), "
    r"items (?P<items>-?\d+), "
    r"recipes (?P<recipes>-?\d+)/(?P<recipes_total>-?\d+), "
    r"capability (?P<capfluid>\S+) (?P<capmb>-?\d+) mB, "
    r"augments speed (?P<speed>-?\d+) efficiency (?P<efficiency>\d+\.\d+), "
    r"facing (?P<facing>\S+), t=(?P<t>-?\d+)$"
)


def main() -> int:
    line = sys.argv[1] if len(sys.argv) > 1 else ""
    match = PATTERN.search(line)
    if not match:
        print("ok=0")
        return 0
    print("ok=1")
    for key, value in match.groupdict().items():
        print(f"F_{key.upper()}={shlex.quote(value)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
