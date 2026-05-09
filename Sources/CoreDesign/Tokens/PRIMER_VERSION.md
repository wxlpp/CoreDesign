# Primer Primitives Version Lock

| Field | Value |
|---|---|
| Version | `v11.8.0` |
| Released | 2026-05-08 |
| Reference | https://github.com/primer/primitives/tree/v11.8.0 |
| Locked at | 2026-05-09 |
| Locked by | issue #2 |

## Why this exists

CoreDesign v2 takes GitHub's [Primer Primitives](https://github.com/primer/primitives) as its visual north star. To prevent drift across parallel implementation tasks (where different agents could query Primer at different times and get different values), this file pins one specific Primer release as the canonical source.

All Swift token files in `Sources/CoreDesign/Tokens/` reference this file in their header (`// Source of truth: Tokens/PRIMER_VERSION.md`) instead of inlining a version string. Single source = no drift.

## Token source mapping

| CoreDesign token | Primer source (under `src/tokens/`) |
|---|---|
| `CoreSpacing` | `functional/spacing/space.json5` (`xxs`–`xl`) + base.size for `xxl`–`huge` |
| `CoreRadius` | `functional/size/radius.json5` |
| `CoreBorderWidth` | `functional/size/border.json5` (`borderWidth.*`) |
| `CoreTypography` (issue #3) | `functional/typography/` |
| `CoreElevation` (issue #4) | `functional/shadow/shadow.json5` |
| `CoreControlMetrics` (issue #5) | derived from above; no direct Primer source |
| Surface / Border / Content semantic colors (issue #6) | `functional/color/` |

Browse the locked snapshot: https://github.com/primer/primitives/tree/v11.8.0/src/tokens

## Decision log

- **2026-05-09** — Locked to `v11.8.0` (latest stable as of issue #2 implementation date) per `.claude/prds/coredesign-v2-tokens.md` Architecture Decision #5.

## Re-locking procedure

If a future epic needs to update Primer alignment:

1. Pick a new tag from https://github.com/primer/primitives/releases.
2. Diff token files between the two versions: `gh api repos/primer/primitives/compare/v11.8.0...vX.Y.Z`.
3. Update this file: `Version` / `Released` / `Reference` / `Locked at` / append a Decision Log entry.
4. Audit each consuming Swift token file for value changes.
5. **Do not change** the `// Source of truth: Tokens/PRIMER_VERSION.md` header in token files — the indirection is the whole point.
