#!/usr/bin/env bash
# In-game check for mifa: the 18 addons above tier 2 and the recipes the parent can run.
#
# The game is **two mods**: Industrial Foregoing 0.2.5 (built into the game) and this
# package (`--dev-mod ports/mifa/mifa.hmod`). Nothing here tests the parent's own slice;
# every assertion is about what this package adds to it:
#
#   P  the package loads (no recipe/advancement/item load error) and an unknown id is refused;
#   A  all 19 items exist and carry the names the jar has no keys for;
#   B  the augment payloads, one machine per tier (tier 3..8): seating speed tier t makes a
#      Water Condensator's bar fall 1+t a tick, and efficiency tier t shortens its bar to
#      floor(100 * (1 - t * 0.1)) — 70, 60, 50, **39**, 30, **19**: the two float literals
#      the jar writes (`0.39999998`, `0.19999999`) are what make tier 6 a 39-tick bar, so a
#      port that wrote `0.4` would read 40 and this leg fails;
#   C  the **crafted** speed tier 8 seats and reads nine a tick — the recipe's output carries
#      its `titanium:augments` component through the chamber;
#   D  the smithing recipe: the netherite gear (`#c:gears/diamond` + `#c:ingots/netherite`)
#      in a real smithing table, the three inputs consumed, and a wrong base leaves the
#      result empty;
#   E  the 10 carried chamber recipes: each matches its own grid (id and bar length), runs to
#      the same product with every input slot emptied and the recipe's fluid taken; the
#      chamber's table reports **33/33** recipes (the parent's 23 + this package's 10), which
#      is only true when every `c:` tag this package declares has a member;
#   F  a wrong-ingredient control: the same grid with one cell wrong matches nothing, takes no
#      fluid and spends no FE;
#   G  the parent's own tier-2 recipe still matches — both crafts exist for one parent item.
#
# The chamber's bar is driven with `/industrialforegoing progress` (the parent's own harness
# command) so a 1,600-tick recipe finishes in one tick; leg E's first recipe still runs its
# full 200 ticks with the game's clock checked, so the tick path is measured, not assumed.
#
# SELFTEST=1 flips leg B's tier-3 fall (four a tick -> five) so the run MUST exit 1.
# NEGATIVE=1 is the control leg: the **same** game launched without `--dev-mod`, so the parent
# is there and this package is not. It asserts the package's item is known and MUST exit 1 at
# that assertion; the parent's machine is asserted first, so the control is not vacuous.
#
#   eval "$(ports/mifa/tools/build-game.sh)"
#   ports/tools/build-slot.sh run --job e2e-mifa --port ports/mifa --step e2e -- \
#       bash ports/mifa/tools/e2e.sh
#
# Every mod command goes through `ctl chat`, not `ctl command`: the console path bypasses the
# native `perform_command` hook, and `ctl command` exits 0 even on a refusal — every reply
# below is parsed, never inferred from the exit status. The last line is `EXIT:<status>`.
set -Eeuo pipefail
export LC_ALL=C

PORT=$(cd "$(dirname "$0")/.." && pwd)
PKG=$PORT/mifa.hmod
CTL=${CTL:-}
GAME=${GAME:-}
RES=${RES:-${HORIZON_RES:-/home/adlf/Desktop/horizon/.local/horizon-client/26.3}}
SOCK=${SOCK:-${E2E_TMP:-/tmp/opencode}/mifa-e2e.sock}
SELFTEST=${SELFTEST:-0}
NEGATIVE=${NEGATIVE:-0}
KEEP=${KEEP:-0}
WORLD=MifaE2E

# The End, in the void: machines at x=200,203,..,215 (one per tier, three apart so the
# next one is never between the crosshair and the target), the chamber at x=226, the
# smithing table at x=238. Away from the central island and its ambient item entities.
MX0=200
CX=226
SX=238
CHAMBER_ID=industrialforegoing:dissolution_chamber
MACHINE_ID=industrialforegoing:water_condensator
Y=101
# tier:expected speed:expected efficiency string:expected bar maximum
TIERS="3:4:0.70:70 4:5:0.60:60 5:6:0.50:50 6:7:0.40:39 7:8:0.30:30 8:9:0.20:19"
DIAMOND_GEAR=industrialforegoing:diamond_gear
TIER_ONE_EFFICIENCY=industrialforegoing:efficiency_addon_tier_1
TIER_TWO_EFFICIENCY=industrialforegoing:efficiency_addon_tier_2
TIER_TWO_SPEED=industrialforegoing:speed_addon_tier_2
GEAR=mifa:netherite_gear

[ -n "$CTL" ] || {
    echo "CTL is unset: eval \"\$(ports/mifa/tools/build-game.sh)\"" >&2
    exit 1
}
[ -n "$GAME" ] || {
    echo "GAME is unset: eval \"\$(ports/mifa/tools/build-game.sh)\"" >&2
    exit 1
}
[ -x "$CTL" ] || { echo "missing horizon-ctl: $CTL" >&2; exit 1; }
[ -x "$GAME" ] || { echo "missing horizon-client: $GAME" >&2; exit 1; }
[ -d "$RES/assets" ] || { echo "missing prepared resources: $RES" >&2; exit 1; }
[ -f "$PKG" ] || { echo "missing package: $PKG" >&2; exit 1; }

# `/tmp` is a 7.5 GB tmpfs; the launcher exports a scratch root on the data disk.
SCRATCH=$(mktemp -d "${E2E_TMP:-/tmp/opencode}"/mifa-home.XXXXXX)
export HORIZON_HOME=$SCRATCH/game
export HORIZON_LAUNCHER_HOME=$SCRATCH/launcher
export XDG_DATA_HOME=$SCRATCH/data
export XDG_CONFIG_HOME=$SCRATCH/config
export HORIZON_NO_AUDIO=1
mkdir -p "$(dirname "$SOCK")" "$XDG_CONFIG_HOME"
rm -f "$SOCK"

ctl() { "$CTL" --socket "$SOCK" --timeout 180 "$@"; }
say() { ctl chat "/$1" >/dev/null; }
fail() { echo "FAIL: $*" >&2; ctl logs --lines 60 >&2 || true; exit 1; }
on_error() { echo "FAIL: line $1: '$2' exited $?" >&2; ctl logs --lines 40 >&2 || true; }
trap 'on_error "$LINENO" "$BASH_COMMAND"' ERR

cleanup() {
    local status=$?
    ctl quit >/dev/null 2>&1 || true
    sleep 1
    pkill -f "$WORLD" 2>/dev/null || true
    if [ "$KEEP" = 1 ]; then
        echo "kept scratch: $SCRATCH" >&2
    else
        rm -rf "$SCRATCH" 2>/dev/null || true
    fi
    # The last line of every run: `check-e2e-logs.py` reads it as the verdict.
    echo "EXIT:$status"
}
trap cleanup EXIT

launch() {
    local dev=()
    [ "$NEGATIVE" = 1 ] || dev=(--dev-mod "$PKG")
    rm -f "$SOCK"
    cd "$SCRATCH"
    # `--offscreen`, not `--headless`: a smithing table's menu is read through `ctl screen`,
    # which needs the client's screen half; headless has none (`ctl screen` times out).
    "$CTL" --socket "$SOCK" launch --game "$GAME" --world "$WORLD" --seed 20261105 --creative \
        --offscreen --wait --resources "$RES" "${dev[@]}" >/dev/null
    ctl wait-ready 120 >/dev/null
    ctl wait 40 >/dev/null
}

block_name() { ctl block "$1" "$2" "$3" | jq -r '.name // .block // empty'; }
held() { ctl inventory | jq -r --arg item "$1" '.counts[$item] // 0'; }
expect() { [ "$2" = "$3" ] || fail "$1 is $2, expected $3"; }

# The End's void, cleared and floored, with the player on it.
arena() {
    ctl command "execute in minecraft:the_end run tp @s 200.5 104 0.5" >/dev/null
    local loaded=false
    for _ in $(seq 1 120); do
        ctl wait 5 >/dev/null
        if [ "$(ctl block 226 100 0 | jq -r '.loaded // false')" = true ] \
           && [ "$(ctl block 238 100 0 | jq -r '.loaded // false')" = true ]; then
            loaded=true
            break
        fi
    done
    [ "$loaded" = true ] || fail "the End arena chunks never loaded"
    ctl command "execute in minecraft:the_end run fill 190 100 -8 250 100 8 minecraft:stone" >/dev/null
    ctl wait 6 >/dev/null
    ctl command "execute in minecraft:the_end run fill 190 101 -8 250 108 8 minecraft:air" >/dev/null
    ctl wait 6 >/dev/null
    ctl command "execute in minecraft:the_end run kill @e[type=!player]" >/dev/null
    ctl command "execute in minecraft:the_end run tp @s 200.5 101 0.5" >/dev/null
    ctl wait 20 >/dev/null
    [ "$(block_name 226 100 0)" = "minecraft:stone" ] || fail "the arena floor is not stone"
}

# --- the machines (legs B and C) -------------------------------------------

# Place a condensator at X 101 0 from a fresh item and leave the player two blocks west.
place_machine() { # place_machine X
    local x=$1
    ctl command "item replace entity @s hotbar.0 with $MACHINE_ID 1" >/dev/null
    ctl wait 4 >/dev/null
    ctl select 1 >/dev/null
    ctl command "execute in minecraft:the_end run tp @s $((x + 2)).5 $Y 0.5" >/dev/null
    ctl wait 6 >/dev/null
    ctl look-at-block "$x" $((Y - 1)) 0 up >/dev/null 2>&1 || fail "cannot aim at the floor under $x"
    ctl wait 6 >/dev/null
    ctl place "$x" "$Y" 0 --item "$MACHINE_ID" >/dev/null || fail "the machine did not place at $x"
    ctl wait 6 >/dev/null
    [ "$(block_name "$x" "$Y" 0)" = "$MACHINE_ID" ] \
        || fail "the machine did not place at $x (got '$(block_name "$x" "$Y" 0)')"
}

# Give one addon, select it, aim at the machine and right-click it.
seat_addon() { # seat_addon X ITEM
    local x=$1 item=$2
    ctl command "give @s $item 1" >/dev/null
    ctl wait 6 >/dev/null
    ctl select "$item" >/dev/null 2>&1 || fail "the addon $item is not in the hotbar"
    ctl command "execute in minecraft:the_end run tp @s $((x + 2)).5 $Y 0.5" >/dev/null
    ctl wait 6 >/dev/null
    ctl look-at-block "$x" "$Y" 0 >/dev/null 2>&1 || fail "cannot aim at the machine at $x"
    ctl wait 6 >/dev/null
    ctl use-item >/dev/null || fail "the right-click with $item on the machine failed"
    ctl wait 8 >/dev/null
}

# A fresh readout reply. The chat line lands a tick or two after the command, so a fixed
# wait read the wrong reply twice: once another position's (tier 4 read the tier 3
# machine) and once the same line twice (the rate window). Each position's pattern keeps
# its previous line, and a reply counts only when it differs from that one — the readout
# carries its game time, so two replies for one position are never identical.
# The last line read per position belongs to the caller: `fresh_line` runs inside
# `$(…)`, so its own assignment would not survive the subshell.
declare -A LAST_INFO=()
fresh_line() { # fresh_line PATTERN COMMAND PREVIOUS-LINE
    local pat=$1 prev=${3:-} tries=0 line
    say "${2:-}"
    while [ "$tries" -lt 60 ]; do
        # `ctl messages` is **newest first** (`agent.rs`: "order": "newest first"), so
        # the newest matching line is the first one, not the last.
        line=$(ctl messages 24 | jq -r '.chat[]' | grep -m1 "$pat" || true)
        if [ -n "$line" ] && [ "$line" != "$prev" ]; then
            printf '%s' "$line"
            return 0
        fi
        ctl wait 2 >/dev/null
        tries=$((tries + 1))
        # A chat command sent while the previous one is still in flight is sometimes
        # dropped by the client (two reads back to back showed it); re-send rather
        # than read a stale line, which is what a fixed wait did.
        if [ $((tries % 8)) = 0 ]; then
            say "${2:-}"
        fi
    done
    return 1
}

# `/industrialforegoing info X 101 0`, parsed into ENERGY, WATER, SOURCES, PROGRESS,
# PROGRESS_MAX, SPEED, EFFICIENCY, FACING and T.
info() { # info X
    local x=$1
    local line
    line=$(fresh_line "Water Condensator at \\[$x, $Y, 0\\]: [0-9-]*/[0-9]* FE, " \
        "industrialforegoing info $x $Y 0" "${LAST_INFO[$x]:-}") \
        || fail "no /industrialforegoing info reply for $x"
    LAST_INFO[$x]=$line
    eval "$(python3 "$PORT/tools/parse_info.py" "$line")"
    [ "${ok:-0}" = 1 ] || fail "the info line did not parse: $line"
    echo "  $line" >&2
}

# --- the chamber and the smithing table (legs D and E) ---------------------

place_chamber() {
    ctl command "item replace entity @s hotbar.0 with $CHAMBER_ID 1" >/dev/null
    ctl wait 6 >/dev/null
    ctl select 1 >/dev/null
    ctl command "execute in minecraft:the_end run tp @s $((CX - 2)).5 $Y 0.5" >/dev/null
    ctl wait 6 >/dev/null
    ctl look-at-block "$CX" $((Y - 1)) 0 up >/dev/null 2>&1 || fail "cannot aim at the chamber's floor"
    ctl wait 8 >/dev/null
    ctl place "$CX" "$Y" 0 --item "$CHAMBER_ID" >/dev/null || fail "the chamber did not place"
    ctl wait 6 >/dev/null
    [ "$(block_name "$CX" "$Y" 0)" = "$CHAMBER_ID" ] || fail "the chamber did not place at $CX"
}

cbar() {
    local line
    line=$(fresh_line "Dissolution Chamber at \\[$CX, $Y, 0\\]: [0-9-]*/[0-9]* FE, input " \
        "industrialforegoing info $CX $Y 0" "${LAST_INFO[chamber]:-}") \
        || fail "no /industrialforegoing info reply for the chamber"
    LAST_INFO[chamber]=$line
    eval "$(python3 "$PORT/tools/parse_chamber.py" "$line")"
    [ "${ok:-0}" = 1 ] || fail "the chamber info line did not parse: $line"
    echo "  $line" >&2
}

csay() { # csay "progress 0"
    local sub=${1%% *} rest=""
    [ "$sub" != "$1" ] && rest=${1#* }
    say "industrialforegoing $sub $CX $Y 0${rest:+ $rest}"
}

feed() { # feed SLOT ITEM
    ctl command "item replace block $CX $Y 0 container.$1 with $2 1" >/dev/null \
        || fail "could not put $2 into the chamber's input slot $1"
    ctl wait 1 >/dev/null
}

empty_chamber() {
    for slot in 0 1 2 3 4 5 6 7 8 9 10; do
        ctl command "item replace block $CX $Y 0 container.$slot with minecraft:air" >/dev/null
    done
    csay "fluid latex 0" >/dev/null
    ctl wait 3 >/dev/null
}

chamber_slot() { # chamber_slot N
    ctl container "$CX" "$Y" 0 | jq -r --argjson n "$1" \
        '.slots[$n] | if . == null then "empty" else "\(.item) x\(.count)" end'
}

# One carried recipe: its own grid, its fluid, its bar length, its product, and the
# inputs and fluid consumed. The bar is set one tick short, so the operation completes
# on the next tick; leg E's first case runs its full length instead (`FULL=1`).
run_recipe() { # run_recipe STEM TICKS FLUID MB OUTPUT FULL ITEM...
    local stem=$1 ticks=$2 fluid=$3 mb=$4 output=$5 full=$6
    shift 6
    empty_chamber
    csay "energy 10000" >/dev/null
    csay "progress 0" >/dev/null
    csay "fluid ${fluid#industrialforegoing:} $mb" >/dev/null
    local slot=0
    for item in "$@"; do
        feed "$slot" "$item"
        slot=$((slot + 1))
    done
    [ "$slot" = 8 ] || fail "$stem has $slot ingredients, expected 8"
    cbar
    expect "$stem: the recipe its grid matches" "$F_RECIPE" "mifa:dissolution_chamber/$stem"
    expect "$stem: the bar's length" "$F_LENGTH" "$ticks"
    if [ "$full" = 1 ]; then
        # 90 FE a tick against a 10,000 FE buffer: 200 ticks is 18,000 FE, so the
        # buffer is topped up in windows and the bar must climb through them.
        local windows=$((ticks / 50 + 1))
        for _ in $(seq 1 "$windows"); do
            csay "energy 10000" >/dev/null
            ctl wait 55 >/dev/null
        done
    else
        csay "progress $((ticks - 1))" >/dev/null
        ctl wait 4 >/dev/null
    fi
    cbar
    expect "$stem: the product" "$(chamber_slot 8)" "$output x1"
    expect "$stem: the input slots after the run" "$F_ITEMS" 0
    expect "$stem: the fluid the run took" "$F_FIN" 0
    echo "  $stem -> $(chamber_slot 8), ${mb} mB of $fluid, bar $ticks" >&2
}

# The smithing table's slots (`ctl screen`: 600 template, 601 base, 602 addition,
# 650 result; 0-35 the player's inventory).
table_place() { # table_place ITEM SLOT
    local item=$1 target=$2 src
    src=$(ctl screen | jq -r --arg i "$item" '.slots[] | select(.item==$i and .slot<100) | .slot' | head -1)
    [ -n "$src" ] || fail "no $item in the player's inventory to place in the smithing table"
    ctl click-slot "$src" >/dev/null
    ctl wait 1 >/dev/null
    ctl click-slot "$target" >/dev/null
    ctl wait 1 >/dev/null
    ctl click-slot "$src" >/dev/null
    ctl wait 1 >/dev/null
}

open_smithing() {
    ctl command "execute in minecraft:the_end run setblock $SX $Y 0 minecraft:smithing_table" >/dev/null
    ctl command "execute in minecraft:the_end run tp @s $((SX - 1)).5 $Y 0.5" >/dev/null
    ctl wait 6 >/dev/null
    ctl look-at-block "$SX" $Y 0 >/dev/null 2>&1 || fail "cannot aim at the smithing table"
    ctl wait 6 >/dev/null
    ctl interact "$SX" "$Y" 0 >/dev/null || fail "the smithing table did not open"
    ctl wait 6 >/dev/null
    [ "$(ctl screen | jq -r '.screen // ""')" = "station" ] || fail "no smithing menu is open"
}

# ==========================================================================
# launch
# ==========================================================================
echo "== launch ($([ "$NEGATIVE" = 1 ] && echo 'control: parent only' || echo 'two mods: industrialforegoing + mifa')) =="
launch
ctl command "difficulty peaceful" >/dev/null
arena

if [ "$NEGATIVE" = 1 ]; then
    # The control leg: the same game without `--dev-mod`. The parent must be there (its
    # machine places), so the only difference is this package — and its item must be
    # unknown, which the assertion below turns into the expected EXIT:1.
    echo "== N: the parent is in the control game, this package is not =="
    place_machine "$MX0"
    echo "  control: $(block_name "$MX0" "$Y" 0) placed"
    ctl command "give @s mifa:speed_addon_3 1" >/dev/null || true
    ctl wait 6 >/dev/null
    expect "the control game's count of mifa:speed_addon_3 (the package is off)" \
        "$(held mifa:speed_addon_3)" 1
    fail "the control leg should have stopped above"
fi

echo "== P: the package loads, and an unknown id is refused =="
LOAD_ERRORS=$(ctl logs --lines 600 | grep -c -E "\[load-items/ERROR\]|\[horizon-recipes/ERROR\]|\[horizon-advancements/ERROR\]|unknown component type" || true)
expect "the load errors in the game's log" "${LOAD_ERRORS:-0}" 0
# `ctl command` answers `ok: true` for a command the game refused inside (the trap this
# campaign has paid for twice), so the refusal is read from the game's own chat line.
ctl command "give @s mifa:not_an_item 1" >/dev/null
ctl wait 4 >/dev/null
UNKNOWN=$(ctl messages 3 | jq -r '.chat[]' | grep -c "Unknown item 'mifa:not_an_item'" || true)
expect "the game's refusal of an unknown id" "${UNKNOWN:-0}" 1
# The parent's own recipe table also reports the chamber is theirs, not a mifa block.
echo "  no load errors; an unknown id was refused"

echo "== A: the 19 items exist, and the 18 names this package must declare =="
# The names are read in one pass after every give: a `give`'s chat line lands a tick or
# two behind the command's reply, so matching each line to its own give is a race — the
# set is what is asserted, and every name is unique.
GAVE=()
for item in $(python3 - "$PORT" <<'PY2'
import sys
sys.path.insert(0, sys.argv[1] + "/tools")
import gen_content
print(" ".join(gen_content.item_ids()))
PY2
); do
    REPLY=$(ctl command "give @s mifa:$item 1" | jq -r '.ok // false')
    expect "the give reply for mifa:$item" "$REPLY" true
    GAVE+=("mifa:$item")
done
ctl wait 12 >/dev/null
NAMED=$(ctl messages 80 | jq -r '.chat[]' | grep -c 'Gave 1 \[' || true)
expect "the 19 give announcements" "${NAMED:-0}" 19
for item in "${GAVE[@]}"; do
    EXPECTED=$(python3 - "$PORT" "$item" <<'PY2'
import sys
sys.path.insert(0, sys.argv[1] + "/tools")
import gen_content
print(gen_content.display_name(sys.argv[2].split(":", 1)[1]))
PY2
)
    SEEN=$(ctl messages 80 | jq -r '.chat[]' | grep -c "Gave 1 \[$EXPECTED\]" || true)
    expect "the name this package declares for $item" "${SEEN:-0}" 1
    [ "$(held "$item")" -ge 1 ] || fail "$item is not in the inventory after its give"
done
echo "  19 items given, 19 names read back (e.g. '${GAVE[3]}' is '$(python3 - "$PORT" <<'PY2'
import sys
sys.path.insert(0, sys.argv[1] + "/tools")
import gen_content
print(gen_content.display_name("efficiency_addon_6"))
PY2
)')"

echo "== B: the augment payloads, one machine per tier =="
ctl command "clear @s" >/dev/null
ctl wait 4 >/dev/null
ORDINAL=0
for row in $TIERS; do
    IFS=: read -r tier speed eff barmax <<<"$row"
    x=$((MX0 + ORDINAL * 3))
    ORDINAL=$((ORDINAL + 1))
    place_machine "$x"
    seat_addon "$x" "mifa:speed_addon_$tier"
    seat_addon "$x" "mifa:efficiency_addon_$tier"
    info "$x"
    expect "tier $tier: the speed the seated addon reads" "$SPEED" "$speed"
    expect "tier $tier: the efficiency the seated addon reads" "$EFFICIENCY" "$eff"
    if [ "$SELFTEST" = 1 ] && [ "$tier" = 3 ]; then
        echo "(selftest: asserting a fall of $((speed + 1)) a tick)"
        expect "tier 3: the speed the seated addon reads" "$SPEED" "$((speed + 1))"
    fi
    expect "tier $tier: the bar the efficiency scales to" "$PROGRESS_MAX" "$barmax"
    expect "tier $tier: the speed addon the seat took from the hand" \
        "$(held "mifa:speed_addon_$tier")" 0
    expect "tier $tier: the efficiency addon the seat took from the hand" \
        "$(held "mifa:efficiency_addon_$tier")" 0
    echo "  tier $tier at x=$x: speed $SPEED, efficiency $EFFICIENCY, bar $PROGRESS_MAX/…" >&2
done

echo "== B2: the rate, measured: speed 4 falls four a tick where an empty slot falls one =="
# The tier 3 machine at MX0 carries speed 4 (and efficiency 0.70, a 70-tick bar). The
# bar's fall over a window the game itself times (`t=` in the readout) is the assertion.
say "industrialforegoing progress $MX0 $Y 0 70"
ctl wait 2 >/dev/null
info "$MX0"
P1=$PROGRESS T1=$T
ctl wait 4 >/dev/null
info "$MX0"
FELL=$((P1 - PROGRESS)) TICKS=$((T - T1))
[ "$TICKS" -gt 0 ] || fail "the two reads carry the same game time"
[ "$TICKS" -lt 16 ] || fail "a $TICKS-tick window can cross a finished bar"
EXPECTED=$((4 * TICKS))
if [ "$SELFTEST" = rate ]; then
    echo "(selftest: asserting a fall of $((EXPECTED + 1)))"
    EXPECTED=$((EXPECTED + 1))
fi
expect "the fall of a tier 3 speed addon over $TICKS ticks" "$FELL" "$EXPECTED"
echo "  tier 3 speed: $P1 -> $PROGRESS over $TICKS ticks (four a tick)"

echo "== B3: a processing addon is refused by the parent's reader (the measured gap) =="
# `AugmentTypes` in the parent port is Speed and Efficiency only, so a `Processing`
# component decodes to nothing and `use_item_on` passes: the item must stay in the hand
# and the machine must not change. This is the parent's gap, recorded, not this port's.
ctl command "give @s mifa:processing_addon_3 1" >/dev/null
ctl wait 6 >/dev/null
ctl select mifa:processing_addon_3 >/dev/null 2>&1 || fail "the processing addon is not in the hotbar"
ctl command "execute in minecraft:the_end run tp @s $((MX0 + 2)).5 $Y 0.5" >/dev/null
ctl wait 6 >/dev/null
ctl look-at-block "$MX0" "$Y" 0 >/dev/null
ctl wait 6 >/dev/null
ctl use-item >/dev/null || true
ctl wait 8 >/dev/null
info "$MX0"
expect "the speed after a refused processing addon" "$SPEED" 4
expect "the processing addon the seat refused to take" "$(held mifa:processing_addon_3)" 1
echo "  a Processing addon stays in the hand: the parent reads Speed and Efficiency only"

echo "== D: the netherite gear, in a real smithing table =="
ctl command "clear @s" >/dev/null
ctl wait 4 >/dev/null
open_smithing
ctl command "give @s minecraft:netherite_upgrade_smithing_template 1" >/dev/null
ctl command "give @s $DIAMOND_GEAR 1" >/dev/null
ctl command "give @s minecraft:netherite_ingot 1" >/dev/null
ctl wait 8 >/dev/null
table_place minecraft:netherite_upgrade_smithing_template 600
table_place "$DIAMOND_GEAR" 601
table_place minecraft:netherite_ingot 602
ctl wait 6 >/dev/null
RESULT=$(ctl screen | jq -r '[.slots[] | select(.slot == 650) | .item][0] // "empty"')
expect "the smithing result (#c:gears/diamond + #c:ingots/netherite)" "$RESULT" "$GEAR"
ctl click-slot 650 >/dev/null
ctl wait 6 >/dev/null
expect "the gear the smithing table gave" "$(held "$GEAR")" 1
LEFT=$(ctl screen | jq -r '[.slots[] | select(.slot >= 600 and .item != null)] | length')
expect "the smithing inputs consumed" "$LEFT" 0
echo "  smithing: $DIAMOND_GEAR + ingot -> $GEAR, the three inputs consumed"

# The control: the same table with a wrong base leaves the result empty.
ctl close >/dev/null
ctl wait 4 >/dev/null
open_smithing
ctl command "give @s minecraft:netherite_upgrade_smithing_template 1" >/dev/null
ctl command "give @s industrialforegoing:iron_gear 1" >/dev/null
ctl command "give @s minecraft:netherite_ingot 1" >/dev/null
ctl wait 8 >/dev/null
table_place minecraft:netherite_upgrade_smithing_template 600
table_place industrialforegoing:iron_gear 601
table_place minecraft:netherite_ingot 602
ctl wait 6 >/dev/null
CONTROL=$(ctl screen | jq -r '[.slots[] | select(.slot == 650) | .item][0] // "empty"')
expect "the smithing control's result (an iron gear is not #c:gears/diamond)" "$CONTROL" "empty"
ctl close >/dev/null
echo "  control: an iron gear in the base leaves the result empty"

echo "== E: the carried chamber recipes =="
ctl command "clear @s" >/dev/null
place_chamber
cbar
expect "the chamber's recipe table (the parent's 23 + this package's 10)" \
    "$F_RECIPES/$F_RECIPES_TOTAL" "33/33"

# The plate the four chamber runs of each kind share: the tag members are the concrete
# items (`#c:ores/netherite_scrap` is ancient debris, `#c:gears/netherite` is the gear
# leg D just made), which is how a tag ingredient is exercised for real.
ANCIENT=minecraft:ancient_debris
SCRAP=minecraft:netherite_scrap
GLASS=minecraft:glass_pane
BLAZE=minecraft:blaze_rod
SUGAR=minecraft:sugar
FURNACE=minecraft:furnace
TABLE=minecraft:crafting_table
STAR=minecraft:nether_star
HEAD=minecraft:dragon_head
BREATH=minecraft:dragon_breath
BEACON=minecraft:beacon
REDSTONE=minecraft:redstone

# 1. the full 200-tick re-declared parent tier 2 (the game's own clock, no forcing).
run_recipe industrialforegoing.efficiency_addon_tier_2 200 industrialforegoing:latex 1000 \
    "$TIER_TWO_EFFICIENCY" 1 \
    "$REDSTONE" "$REDSTONE" "$GLASS" "$GLASS" "$DIAMOND_GEAR" "$TIER_ONE_EFFICIENCY" "$BLAZE" "$BLAZE"

# 2. tier 3, the chain's entry (600 ticks, forced).
run_recipe speed_addon_3 600 industrialforegoing:pink_slime 3000 mifa:speed_addon_3 0 \
    "$ANCIENT" "$SCRAP" "$GLASS" "$GLASS" "$GEAR" "$TIER_TWO_SPEED" "$SUGAR" "$SUGAR"
run_recipe efficiency_addon_3 600 industrialforegoing:pink_slime 3000 mifa:efficiency_addon_3 0 \
    "$ANCIENT" "$SCRAP" "$GLASS" "$GLASS" "$GEAR" "$TIER_TWO_EFFICIENCY" "$BLAZE" "$BLAZE"
run_recipe processing_addon_7 1400 industrialforegoing:ether_gas 7000 mifa:processing_addon_7 0 \
    "$BEACON" "$STAR" "$GLASS" "$GLASS" "$GEAR" mifa:processing_addon_6 "$FURNACE" "$TABLE"
run_recipe processing_addon_8 1600 industrialforegoing:ether_gas 8000 mifa:processing_addon_8 0 \
    "$HEAD" "$BREATH" "$GLASS" "$GLASS" "$GEAR" mifa:processing_addon_7 "$FURNACE" "$TABLE"
run_recipe efficiency_addon_7 1400 industrialforegoing:ether_gas 7000 mifa:efficiency_addon_7 0 \
    "$BEACON" "$STAR" "$GLASS" "$GLASS" "$GEAR" mifa:efficiency_addon_6 "$BLAZE" "$BLAZE"
run_recipe efficiency_addon_8 1600 industrialforegoing:ether_gas 8000 mifa:efficiency_addon_8 0 \
    "$HEAD" "$BREATH" "$GLASS" "$GLASS" "$GEAR" mifa:efficiency_addon_7 "$BLAZE" "$BLAZE"
run_recipe speed_addon_7 1400 industrialforegoing:ether_gas 7000 mifa:speed_addon_7 0 \
    "$BEACON" "$STAR" "$GLASS" "$GLASS" "$GEAR" mifa:speed_addon_6 "$SUGAR" "$SUGAR"
run_recipe industrialforegoing.speed_addon_tier_2 200 industrialforegoing:latex 1000 \
    "$TIER_TWO_SPEED" 0 \
    "$REDSTONE" "$REDSTONE" "$GLASS" "$GLASS" "$DIAMOND_GEAR" "industrialforegoing:speed_addon_tier_1" "$SUGAR" "$SUGAR"

run_recipe speed_addon_8 1600 industrialforegoing:ether_gas 8000 mifa:speed_addon_8 0 \
    "$HEAD" "$BREATH" "$GLASS" "$GLASS" "$GEAR" mifa:speed_addon_7 "$SUGAR" "$SUGAR"
echo "== C: the crafted speed tier 8 seats and reads nine a tick =="
# The product of the last recipe, moved from the chamber's output into the hand and
# seated: if the recipe's `titanium:augments` component were dropped, the seat would be
# refused and the machine would keep the empty-slot speed of 1.
expect "the crafted product in the chamber's output (the last recipe)" \
    "$(chamber_slot 8)" "mifa:speed_addon_8 x1"
ctl command "item replace entity @s hotbar.1 from block $CX $Y 0 container.8" >/dev/null
ctl wait 6 >/dev/null
expect "the crafted speed tier 8 in the hand" "$(held mifa:speed_addon_8)" 1
x=$((MX0 + 6 * 3))
place_machine "$x"
ctl select mifa:speed_addon_8 >/dev/null 2>&1 || fail "the crafted addon is not in the hotbar"
ctl command "execute in minecraft:the_end run tp @s $((x + 2)).5 $Y 0.5" >/dev/null
ctl wait 6 >/dev/null
ctl look-at-block "$x" "$Y" 0 >/dev/null
ctl wait 6 >/dev/null
ctl use-item >/dev/null
ctl wait 8 >/dev/null
info "$x"
expect "the speed the crafted tier 8 addon reads (1 + 8)" "$SPEED" 9
expect "the crafted addon the seat took from the hand" "$(held mifa:speed_addon_8)" 0
echo "  a crafted speed tier 8: $SPEED a tick"

echo "== F: a wrong ingredient in the same grid matches nothing =="
empty_chamber
csay "energy 10000" >/dev/null
csay "progress 0" >/dev/null
csay "fluid pink_slime 3000" >/dev/null
feed 0 "$ANCIENT"
feed 1 minecraft:iron_ingot          # the wrong cell: the recipe wants netherite scrap
feed 2 "$GLASS"
feed 3 "$GLASS"
feed 4 "$GEAR"
feed 5 "$TIER_TWO_SPEED"
feed 6 "$SUGAR"
feed 7 "$SUGAR"
ctl wait 40 >/dev/null
cbar
expect "the control grid's recipe" "$F_RECIPE" none
expect "the control grid's bar" "$F_PROGRESS" 0
expect "the control grid's buffer (nothing spent)" "$F_ENERGY" 10000
expect "the control grid's product" "$(chamber_slot 8)" empty
expect "the control grid's fluid (nothing taken)" "$F_FIN" 3000
echo "  one wrong cell: no recipe, no FE, no fluid, no product"

echo "== G: the parent's own tier-2 recipe still matches (two crafts, one item) =="
# `ModRecipeProvider` re-declares the parent's tier 2 cheaper; both files load, so the
# same parent item has two crafts. The parent's own wants two diamond gears and no tier-1
# addon, and this package's wants one gear and the tier-1 addon — leg E matched this
# package's, this matches the parent's.
empty_chamber
csay "energy 10000" >/dev/null
csay "progress 0" >/dev/null
csay "fluid latex 1000" >/dev/null
feed 0 "$REDSTONE"
feed 1 "$REDSTONE"
feed 2 "$GLASS"
feed 3 "$GLASS"
feed 4 "$DIAMOND_GEAR"
feed 5 "$DIAMOND_GEAR"
feed 6 "$BLAZE"
feed 7 "$BLAZE"
cbar
expect "the parent's own tier-2 recipe" "$F_RECIPE" \
    "industrialforegoing:dissolution_chamber/efficiency_addon_tier_2"
csay "progress 199" >/dev/null
ctl wait 4 >/dev/null
cbar
expect "the parent's own tier-2 product" "$(chamber_slot 8)" "$TIER_TWO_EFFICIENCY x1"
echo "  both crafts exist: this package's (one gear + tier 1) and the parent's (two gears)"

echo "PASS: the package loads and its 19 items exist with their own names; a speed tier 3 addon seats and its bar falls four a tick, and every tier 3-8 seats with the parent's own multiplier (speed 1+t, efficiency 1-t*0.1, the bar 70/60/50/39/30/19 — the jar's float literals); a crafted speed tier 8 seats and reads nine; a processing addon is refused (the parent reads Speed and Efficiency only); the netherite gear crafts in a smithing table from #c:gears/diamond and #c:ingots/netherite with the inputs consumed and a wrong base empty; the chamber reports 33/33 recipes and the 10 carried ones each match their own grid, run to their product and consume every input and the recipe's fluid; a wrong cell matches nothing; and the parent's own tier-2 craft still exists beside this package's"
