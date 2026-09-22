# ROADMAP

Ordered by impact. When in doubt, pick whatever most improves how the game looks.

Priority order is fixed and does not get renegotiated by whatever is hardest
this week: **1) visual quality, 2) game feel, 3) everything else, content
quantity included.** A screenshot that would not pass as official marketing for
a 2026 AAA release is a bug with the same severity as a crash.

## Now — the kits exist, the frames do not use them

A large parallel build pass produced a library that is, today, mostly dead code:
`SkyForge`, `WaterKit`, `DecalKit`, `FoliageKit`, `DetailKit`, `VehicleKit`,
`FXKit`, plus the upgraded `MaterialLab` (28 presets) and `LightingRig` (grading,
volumetrics, three-way fill, physically-anchored exposure). Almost none of it is
called from a level yet, which means it improves exactly zero pixels. Nothing
else on this list matters until that is fixed.

1. **Adopt `SkyForge`.** Every level still ships a `ProceduralSkyMaterial`. The
   straw dust band at the horizon — the most location-specific decision in the
   whole art direction — is not on screen anywhere in the game.
2. **Fix the exposure.** Both shipped moods run a key two to three stops hot
   (3.1 and 4.2 against the 1.0–2.0 the reference calls for), which puts the
   pale ground and the white thobe on the same part of the AgX shoulder — the
   hero cannot separate from the floor by value because he is the same value.
   Set `agx_white = 9.5` / `agx_contrast = 1.45` (nothing was feeding AgX at
   all; `Mood.white` is dead), bring the keys down, and recover the difference
   with `bounce_energy` and rim rather than with more key.
3. **Give each level a grade.** Cool shadows, warm highlights, per level. This
   is the direct fix for five levels sliding into one orange, and it is the
   lever `adjustment_saturation` structurally cannot pull.
4. **Weather every wall.** `DecalKit.scatter_on_wall` at 12–20 decals per screen
   of wall, `salt_masonry` in the bottom two metres of anything near the Gulf,
   `run_off` under every coping. Flat plaster is the other half of "blocky".
5. **Replant.** The four `PropKit.palm` / `PropKit.eucalyptus` call sites move to
   `FoliageKit.windbreak_row` / `street_trees` — better silhouettes, real wind,
   and a windbreak row goes from dozens of draw calls to three.
6. **The sea.** `WaterKit.sea` behind Brega and Benghazi. The glitter path is
   composition, not a setting: aim it at the right-third line.

## Next
7. Level 3: Highway to Benghazi (vehicle chapter, `VehicleKit` exists for it).
8. Level 4: Garyounis University.
9. Level 5: Benghazi, and the World 1 boss.
10. More ICE bonus levels — the warp picks from a pool and the pool is two.
11. World 1 ending sequence.
12. Boss-grade set piece for the end of Brega.

## Standing
- **Endless polish passes.** The game is never declared done.
- Every visual commit lands a dated capture in `docs/screenshots/`.
- `tools/verify_all.sh` before every commit. It boots every scene under real
  Vulkan, which is the only thing that compiles a shader — `--import` and
  `--check-only` both run the dummy rasterizer and will pass a shader that is
  pure syntax error.

## Engineering debt worth paying
- Object pooling for collectibles and particles before the first dense level.
- The chroma law is enforced in `MaterialLab.world_tint`, but a MultiMesh using
  `vertex_color_use_as_albedo` bypasses it entirely. The Ajdabiya market-stall
  awning currently does, at S 0.75 inside the reserved red band.
- Ajdabiya plays Brega's music (`music_theme = "brega"`) and has no tuna
  sandwich anywhere in it.
