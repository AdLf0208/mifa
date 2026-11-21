#!/usr/bin/env bash
# The two-mod game mifa's e2e runs on: **Industrial Foregoing 0.2.5 and nothing else**,
# exported beside the campaign's Nightly so a launch with `--dev-mod ports/mifa/mifa.hmod`
# is the two-mod game and the same launch without that flag is the control.
#
# Why a dedicated instance: the campaign's shared `e2e` instance carries every port built
# on this box (30-odd `lib*.so`), and several of them declare `c:` tags this package's
# recipes bind to. A clean instance makes the tag values this package's and the parent's
# alone, which is what "a machine is a two-mod game" means for the evidence.
#
#   tools/build-game.sh          # build (or reuse) and export, then print the exports
#   eval "$(tools/build-game.sh)" && tools/e2e.sh
#
# Everything lives under the campaign's shared root (`~/.cache/horizon-e2e`), so the
# Nightly and the prepared 26.3 resources are the ones already installed — never `/tmp`.
set -uo pipefail

TOOLS=$(cd "$(dirname "$0")" && pwd)
PORT=$(cd "$TOOLS/.." && pwd)
CAMPAIGN=$(cd "$PORT/../.." && pwd)
LAUNCHER_DIR=$CAMPAIGN/ports/_shared/bin/launcher-0.2.92
LAUNCHER=$LAUNCHER_DIR/horizon-launcher
SDK_PIN=0a875da91dbb0fdcb7ba8c42c11341aa229af51a
MIXINS_PIN=e59da9094f0c2fdda6c627fe9eff22dec6a906f0
PIN=${SDK_PIN:0:7}
INSTANCE=${MIFA_INSTANCE:-mifa-e2e}
E2E_ROOT=${HORIZON_E2E_ROOT:-$HOME/.cache/horizon-e2e}
DATA=$E2E_ROOT/root/data
CONFIG=$E2E_ROOT/root/config
HOME_DIR=$E2E_ROOT/root/home
VERSIONS=$DATA/horizon-launcher/versions
OUT=${MIFA_GAME_DIR:-$E2E_ROOT/$PIN/mifa-two-mod}
RES_VERSION=26.3

say() { printf '%s: %s\n' "${0##*/}" "$*" >&2; }
die() { printf '%s: %s\n' "${0##*/}" "$*" >&2; exit "${2:-1}"; }

launcher() {
    env XDG_DATA_HOME="$DATA" XDG_CONFIG_HOME="$CONFIG" HOME="$HOME_DIR" \
        "$LAUNCHER" "$@"
}

[ -x "$LAUNCHER" ] || die "no launcher at $LAUNCHER (run launcher-game.sh ensure)" 2
mkdir -p "$DATA" "$CONFIG" "$HOME_DIR" || die "cannot create $E2E_ROOT" 3

# The Nightly this campaign is pinned to, and the prepared resources it must have.
TAG=$(launcher versions --installed --json 2>/dev/null \
    | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: d={}
print(next((v for v in d.get("installed",[]) if v.endswith("-'$PIN'")), ""))')
[ -n "$TAG" ] || die "the launcher has no Nightly at $PIN; run ports/tools/launcher-game.sh ensure" 5
[ -f "$VERSIONS/$TAG/.local/horizon-client/$RES_VERSION/horizon-resources.json" ] \
    || die "$TAG is not prepared for $RES_VERSION; run ports/tools/launcher-game.sh build <mod>" 7

# One instance, made once; the parent is its only installed native mod.
launcher instance list --json 2>/dev/null | python3 -c '
import json,sys
try: d=json.load(sys.stdin)
except Exception: d=[]
print(" ".join(i.get("id","") for i in d))' | grep -qw "$INSTANCE" \
    || launcher instance create "$INSTANCE" --json >&2 || die "instance create failed" 8

# Reuse an export whose parent build is current: compare the manifest it packaged.
PACKAGED=$OUT/horizon-native-mods/industrialforegoing/horizon-mod.toml
if [ -f "$PACKAGED" ] && cmp -s "$PACKAGED" "$CAMPAIGN/ports/industrialforegoing/horizon-mod.toml" \
   && [ -x "$OUT/horizon-client" ]; then
    say "reusing the two-mod export in $OUT (the parent's manifest is unchanged)"
else
    say "native-build industrialforegoing into instance $INSTANCE (no other mod installed)"
    launcher native-build "$CAMPAIGN/ports/industrialforegoing" --instance "$INSTANCE" \
        --trust-native-code --json >&2 || die "native-build failed for industrialforegoing" 10
    # The build's own version folder: the newest native-* tag carrying the parent.
    BUILT=""
    for candidate in $(ls -1t "$VERSIONS" | grep '^native-' || true); do
        [ -f "$VERSIONS/$candidate/horizon-native-mods/industrialforegoing/horizon-mod.toml" ] || continue
        cmp -s "$VERSIONS/$candidate/horizon-native-mods/industrialforegoing/horizon-mod.toml" \
               "$CAMPAIGN/ports/industrialforegoing/horizon-mod.toml" && { BUILT=$candidate; break; }
    done
    [ -n "$BUILT" ] || die "no built version carries industrialforegoing" 10
    say "built $BUILT; exporting to $OUT"
    rm -rf "$OUT"
    mkdir -p "$OUT" || die "cannot create $OUT" 3
    for f in "$VERSIONS/$BUILT"/horizon-client "$VERSIONS/$BUILT"/horizon-ctl \
             "$VERSIONS/$BUILT"/lib*.so "$VERSIONS/$BUILT"/horizon-wasm-std.wasm; do
        [ -e "$f" ] || continue
        ln -f "$f" "$OUT/" 2>/dev/null || cp -a "$f" "$OUT/"
    done
    cp -a "$VERSIONS/$BUILT/horizon-native-mods" "$OUT/"
    [ -f "$VERSIONS/$BUILT/native-mods.json" ] && cp -a "$VERSIONS/$BUILT/native-mods.json" "$OUT/"
fi

# Exactly one native mod: the two-mod claim is mifa's `--dev-mod` on top of this.
COUNT=$(ls -1 "$OUT/horizon-native-mods" 2>/dev/null | wc -l)
[ "$COUNT" = 1 ] || die "the export carries $COUNT native mods, expected industrialforegoing alone" 11
[ -x "$OUT/horizon-client" ] || die "$OUT/horizon-client is missing" 11
say "two-mod export at $OUT: industrialforegoing only, + mifa via --dev-mod"

printf 'export GAME=%q\n' "$OUT/horizon-client"
printf 'export CTL=%q\n' "$OUT/horizon-ctl"
printf 'export CONTROL_GAME=%q\n' "$OUT/horizon-client"
printf 'export MIFA_PKG=%q\n' "$PORT/mifa.hmod"
printf 'export RES=%q\n' "$VERSIONS/$TAG/.local/horizon-client/$RES_VERSION"
printf 'export HORIZON_RES=%q\n' "$VERSIONS/$TAG/.local/horizon-client/$RES_VERSION"
printf 'export E2E_TMP=%q\n' "$E2E_ROOT/scratch"
printf 'export SOCK=%q\n' "$E2E_ROOT/scratch/mifa-e2e.sock"
