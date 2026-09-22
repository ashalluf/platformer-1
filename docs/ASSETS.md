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
  procedural materials, code-driven animation, procedural sky, and **all audio**
  — every sound is synthesised as PCM at runtime by `scripts/audio/SfxForge.gd`.
  `docs/audio_demo.wav` is a rendered preview of that synthesis, not a source
  asset.

## Toolchain
| Tool | Version | Notes |
|---|---|---|
| Godot Engine | 4.7.2.stable | Forward+ renderer |
| Mesa / lavapipe | 25.2.8 | Software Vulkan — the capture pipeline renders without a GPU |

## Surface detail scans (added for the texture pass)

Normal and roughness maps only. Albedo is still generated in code, so these
cannot affect a colour: `MaterialLab.world_tint()` still governs every world
surface and the chroma law is unchanged. What they supply is the micro-surface
`surface_weathered.gdshader` was always built to take and was never given --
its `detail_normal` and `detail_mask` slots were being fed FastNoiseLite, which
has no structure to catch a light on.

Downscaled to 512x512 and re-encoded; the whole set is under 1 MB.

| Asset | Type | Source | License | Used in |
|---|---|---|---|---|
| Concrete033 | Normal + roughness | https://ambientcg.com/view?id=Concrete033 | CC0 1.0 | `concrete` family — structure, decks, walls |
| Plaster001 | Normal + roughness | https://ambientcg.com/view?id=Plaster001 | CC0 1.0 | `plaster` family — render, limewash, terracotta |
| PaintedMetal004 | Normal + roughness | https://ambientcg.com/view?id=PaintedMetal004 | CC0 1.0 | `metal` family — painted steel, galvanised |
| Rust004 | Normal + roughness | https://ambientcg.com/view?id=Rust004 | CC0 1.0 | `rust` family — handrails, rebar, drums |
| Ground054 | Normal + roughness | https://ambientcg.com/view?id=Ground054 | CC0 1.0 | `ground` family — sand, sabkha, bitumen |
| Fabric062 | Normal + roughness | https://ambientcg.com/view?id=Fabric062 | CC0 1.0 | `fabric` family — canvas, sacking, awnings |

ambientCG publishes everything under CC0 1.0 (public domain dedication), which
is the licence this project's rules ask for, so these need no attribution —
they are logged because the rules say to log them.
