# External assets

Every external asset used in this project is logged here with its source URL and
license. CC0 / public domain only.

| Asset | Type | Source | License | Used in |
|---|---|---|---|---|
| Noto Naskh Arabic (Regular, Bold) | Font | https://fonts.google.com/noto/specimen/Noto+Naskh+Arabic | SIL Open Font License 1.1 | Arabic signage, painted wall text |
| Noto Kufi Arabic (Regular) | Font | https://fonts.google.com/noto/specimen/Noto+Kufi+Arabic | SIL Open Font License 1.1 | Display/institutional signage |

## Rules
- CC0 or public domain only, with one recorded exception: **fonts**.
- Everything else: CC0 or public domain. No exceptions.

### Recorded exception — fonts (SIL OFL 1.1, not CC0)

The Game Canon requires Arabic signage, and Arabic signage requires a font with
Arabic coverage and proper shaping. No CC0 Arabic font of shippable quality
exists. Noto is licensed under SIL OFL 1.1, which explicitly permits embedding,
modification and redistribution — including in commercial software — provided
the font files themselves are not sold on their own and any modified version is
renamed. That is compatible with shipping this game.

This is a deliberate, logged deviation from "CC0 only", not an oversight. If the
project owner wants strict CC0, the alternative is drawing Arabic letterforms as
geometry by hand, which is worse in every respect.
- Anything that does not match the art direction gets modified or replaced.
- Everything currently in the project is generated in code: procedural meshes,
  procedural materials, code-driven animation, procedural sky.

## Toolchain
| Tool | Version | Notes |
|---|---|---|
| Godot Engine | 4.7.2.stable | Forward+ renderer |
| Mesa / lavapipe | 25.2.8 | Software Vulkan — the capture pipeline renders without a GPU |
