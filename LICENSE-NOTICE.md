# mifa — licence notices and where they were read from

The package (`mifa.hmod`) is MIT. Its `LICENSE` entry carries the upstream notice verbatim plus this
port's own section; this file is the repository's record of where each part was read from
(ARCHITECTURE.md §8).

## The mod

- **More Industrial Foregoing Addons 2.1.0**, author **Christofmeg**,
  <https://github.com/Christofmeg/MoreIndustrialForegoingAddons>.
- Jar: `mifa-neoforge-1.21.x-2.1.0.jar`, SHA-256
  `dab09f72c4df39efc5d7f8949e4ab02b7d5f74242ee17b8c26fb172c2761d49f` (kept as evidence at
  `ports/_shared/licence-cache/`).
- The jar ships **no** `LICENSE`/`COPYING`/`NOTICE` file: `unzip -l` lists only
  `META-INF/MANIFEST.MF` and `META-INF/neoforge.mods.toml`, and the latter declares
  `license = "The MIT License (MIT)"`.
- The licence text is therefore the **upstream repository's `LICENSE` at commit
  `5fc3ac843f03397f7a117152a081e42980ee2e52`** (tag `2.1.0`):
  `Copyright (c) 2024 Christofmeg`, the standard MIT permission paragraph and disclaimer.
  It is reproduced verbatim at the top of this port's `LICENSE` and inside `mifa.hmod`.
- Audit: `python3 ports/tools/audit_licences.py --mod mifa` → AUDITED, effective MIT, rank 0
  (`ports/_shared/licence-audit.csv`).

## This port

- **Horizon port of More Industrial Foregoing Addons**, `Copyright (c) 2026 AdLf0208`.
- The item names, model JSON and the recipe/tag data in `data/mifa/` and `assets/mifa/` are a
  rewrite of the upstream project's data for Minecraft 26.3 on Horizon (see `FINDINGS.md` and
  `notes.md`); they are distributed under the same MIT terms.
- Nothing in the package needs asset regeneration: the upstream art is MIT too, so the carried
  textures are the upstream ones (`notes.md`, "Licence").
