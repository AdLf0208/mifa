#!/usr/bin/env bash
# The dependency floor, proved by the loader: an unmodded game plus this package is refused
# **by name**, and the same package in the parent's game loads (that half is `tools/e2e.sh`).
#
# The game is the Nightly the instance plays, exported with **zero** native mods (the same
# hardlink export `build-game.sh` makes, minus the parent) so the run is the differential of
# the two-mod game: one variable, whether `industrialforegoing` is installed.
#
#   tools/dependency-refusal.sh          # the refusal: exit 0 when it is named and the game stops
#   SELFTEST=1 tools/dependency-refusal.sh  # the counterfactual: asserts the refusal is ABSENT,
#                                           # so it MUST exit 1 — this is what makes the grep evidence
#
# The last line is `EXIT:<status>`; `check-e2e-logs.py` reads it.
set -Eeuo pipefail
export LC_ALL=C

PORT=$(cd "$(dirname "$0")/.." && pwd)
PKG=$PORT/mifa.hmod
CAMPAIGN=$(cd "$PORT/../.." && pwd)
SDK_PIN=0a875da91dbb0fdcb7ba8c42c11341aa229af51a
PIN=${SDK_PIN:0:7}
E2E_ROOT=${HORIZON_E2E_ROOT:-$HOME/.cache/horizon-e2e}
DATA=$E2E_ROOT/root/data
CONFIG=$E2E_ROOT/root/config
HOME_DIR=$E2E_ROOT/root/home
VERSIONS=$DATA/horizon-launcher/versions
LAUNCHER=$CAMPAIGN/ports/_shared/bin/launcher-0.2.92/horizon-launcher
OUT=${MIFA_NO_PARENT_DIR:-$E2E_ROOT/$PIN/mifa-no-parent}
RES_VERSION=26.3
SELFTEST=${SELFTEST:-0}
WORLD=MifaNoParent

say() { printf '%s: %s\n' "${0##*/}" "$*" >&2; }
die() { printf '%s: %s\n' "${0##*/}" "$*" >&2; exit "${2:-1}"; }

[ -x "$LAUNCHER" ] || die "no launcher at $LAUNCHER" 2
[ -f "$PKG" ] || die "missing package: $PKG" 2

# The Nightly the instance plays, and the resources it was prepared with.
TAG=$(env XDG_DATA_HOME="$DATA" XDG_CONFIG_HOME="$CONFIG" HOME="$HOME_DIR" \
    "$LAUNCHER" versions --installed --json 2>/dev/null \
    | python3 -c 'import json,sys
try:
    d = json.load(sys.stdin)
except Exception:
    d = {}
print(next((v for v in d.get("installed", []) if v.endswith("-'$PIN'")), ""))')
[ -n "$TAG" ] || die "the launcher has no Nightly at $PIN" 5
RES=$VERSIONS/$TAG/.local/horizon-client/$RES_VERSION
[ -d "$RES/assets" ] || die "$TAG is not prepared for $RES_VERSION" 7

# The export: three hardlinks and no `horizon-native-mods/` at all — the control game is the
# two-mod game minus the one variable this leg changes.
mkdir -p "$OUT" || die "cannot create $OUT" 3
for f in horizon-client horizon-ctl horizon-wasm-std.wasm; do
    [ -e "$OUT/$f" ] || ln -f "$VERSIONS/$TAG/$f" "$OUT/$f" || die "cannot link $f" 3
done
[ -d "$OUT/horizon-native-mods" ] && die "$OUT carries native mods; it must carry none" 4
[ -x "$OUT/horizon-client" ] || die "$OUT/horizon-client is missing" 3
export GAME=$OUT/horizon-client
export CTL=$OUT/horizon-ctl

SCRATCH=$(mktemp -d "${E2E_TMP:-/tmp/opencode}"/mifa-no-parent.XXXXXX)
LOG=$SCRATCH/refusal.log
cleanup() {
    local status=$?
    if [ "${KEEP:-0}" = 1 ]; then
        say "kept scratch: $SCRATCH"
    else
        rm -rf "$SCRATCH" 2>/dev/null || true
    fi
    echo "EXIT:$status"
}
trap cleanup EXIT

# One launch, no ctl: the loader refuses before a world exists, so there is nothing to drive.
cd "$SCRATCH"
status=0
env HORIZON_HOME=$SCRATCH/game HORIZON_LAUNCHER_HOME=$SCRATCH/launcher \
    XDG_DATA_HOME=$SCRATCH/data XDG_CONFIG_HOME=$SCRATCH/config HORIZON_NO_AUDIO=1 \
    "$GAME" --resources "$RES" --world "$WORLD" --seed 20261105 --creative --headless \
    --dev-mod "$PKG" > "$LOG" 2>&1 || status=$?
cat "$LOG"

EXPECTED='mod load refused: mifa requires missing mod industrialforegoing ('
URL='https://github.com/AdLf0208/industrialforegoing'

# SELFTEST=1 inverts the assertion: the refusal must be ABSENT, so the run has to fail.
if [ "$SELFTEST" = 1 ]; then
    if grep -Fq "$EXPECTED" "$LOG"; then
        echo "SELFTEST: the refusal is present, so the assertion can fail — inverted run fails as required" >&2
        exit 1
    fi
    echo "SELFTEST-BAD: the refusal did not happen; the assertion would pass vacuously" >&2
    exit 0
fi

[ "$status" -ne 0 ] || die "the game started with no parent installed (exit $status)" 10
grep -Fq "$EXPECTED" "$LOG" || die "the loader did not name mifa and industrialforegoing" 11
grep -Fq "$URL" "$LOG" || die "the refusal does not carry the dependency's url" 11
if grep -Fq 'content from' "$LOG"; then
    die "the game loaded content although the dependency is absent" 11
fi
echo "PASS: with industrialforegoing absent the loader refused: $(grep -F "$EXPECTED" "$LOG" | head -1)"
echo "      exit=$status (the game stopped), and with the parent installed the same package loads (tools/e2e.sh)"
