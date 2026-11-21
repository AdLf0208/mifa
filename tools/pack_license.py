#!/usr/bin/env python3
"""Pack the delivered `mifa.hmod`: the builder's archive plus the licence entry.

`cargo horizon-mod build` packs only what `horizon_mods::Content::read` lists —
`horizon-mod.toml`, `assets/` and `data/` (the pin's
`crates/cargo-horizon-mod/src/main.rs`, `build_in`) — and a content path must be
lowercase (`content.rs`, `check_path`), so a content mod's root `LICENSE` cannot
ride in the archive the builder writes. The registry review asked for the
upstream MIT notice *inside* the package, so this step re-writes the built
archive and adds `LICENSE` at the root: the port's own file, which carries the
upstream copyright and permission notice verbatim plus this port's notice.

It is deterministic, which is what makes "two rebuilds are byte-identical" a
real check: the builder's entry order, compression method and its 1980-01-01
timestamps are kept, and the one added entry uses the same timestamp and
compression. `cargo horizon-mod check` accepts the result (it reads the
manifest and the content paths, and ignores the extra entry).

    python3 tools/pack_license.py            # write <port>/mifa.hmod
    python3 tools/pack_license.py --check    # exit 1 when the delivered file differs
    python3 tools/pack_license.py --print    # write the archive to stdout

Run it after every `cargo horizon-mod build`; the port's `notes.md` records the
ladder that uses it.
"""

from __future__ import annotations

import io
import sys
import zipfile
from pathlib import Path

PORT = Path(__file__).resolve().parents[1]
BUILT = PORT / "target/horizon-mod/mifa.hmod"
DELIVERED = PORT / "mifa.hmod"
LICENSE = PORT / "LICENSE"

# The timestamp the builder stamps every entry with (the zip epoch), and the
# only sane value for a reproducible archive: a real mtime would make two
# builds differ for no reason.
EPOCH = (1980, 1, 1, 0, 0, 0)


def pack() -> bytes:
    """The delivered archive: the built one, with `LICENSE` after the manifest."""
    if not BUILT.is_file():
        raise SystemExit(f"{BUILT} is missing: run `cargo horizon-mod build` first")
    licence = LICENSE.read_bytes()
    sink = io.BytesIO()
    with zipfile.ZipFile(BUILT) as src, zipfile.ZipFile(sink, "w") as out:
        first = True
        for info in src.infolist():
            out.writestr(_entry(info.filename, info.compress_type),
                         src.read(info.filename), compress_type=info.compress_type)
            if first:
                # The builder writes `horizon-mod.toml` first; the licence sits
                # beside it, before the content.
                out.writestr(_entry("LICENSE", info.compress_type), licence,
                             compress_type=info.compress_type)
                first = False
    return sink.getvalue()


def _entry(name: str, compress_type: int) -> zipfile.ZipInfo:
    info = zipfile.ZipInfo(name, date_time=EPOCH)
    info.compress_type = compress_type
    info.external_attr = 0o644 << 16
    info.create_system = 3
    return info


def main(argv: list[str]) -> int:
    data = pack()
    if "--print" in argv:
        sys.stdout.buffer.write(data)
        return 0
    if "--check" in argv:
        if not DELIVERED.is_file():
            print(f"MISSING {DELIVERED.name}")
            return 1
        if DELIVERED.read_bytes() != data:
            print(f"DRIFT   {DELIVERED.name}: rebuild + repack changes it")
            return 1
        print(f"ok      {DELIVERED.name} == build + LICENSE ({len(data)} B)")
        return 0
    DELIVERED.write_bytes(data)
    with zipfile.ZipFile(DELIVERED) as zf:
        names = zf.namelist()
    print(f"wrote {DELIVERED} ({len(data)} B, {len(names)} entries)")
    if "LICENSE" not in names:
        print("FAIL: LICENSE is not in the archive", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
