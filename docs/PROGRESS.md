# PROGRESS

**Status: Levels 1 and 2 playable end to end, plus three ICE bonus levels. Neither main
level passes the visual quality gate yet.**

Last doc pass: 2026-09-22 (second pass, lighting + foreground).

---

## 2026-09-22 — measured lighting pass

`tools/light_report.py` is new and is the reason this section can state numbers instead
of opinions. It reports three things from any capture directory: ground contrast
(brightest/darkest, 2nd-to-98th percentile), the fraction of world pixels below 0.25, and
the fraction above 0.98. It uses Rec.709 luminance — its first version used max(r,g,b)
and reported Brega's warm sunset at a median of 0.965, which was the red channel of an
orange image, not its brightness. Any conclusion drawn from that first version is void.

`tools/parse.sh` is also new: 25 seconds to parse-check all 82 scripts, no render. It
exists because `tools/check.sh` boots ONE scene, so a parse error in any level it does
not load passes clean — which is how a broken `Ajdabiya.gd` reached a three-minute
capture run. Run `parse.sh` after every edit, `verify_all.sh` before every commit.

### What the measurements found

The whole game was lit too flat, and the cause was the same everywhere: `sun_energy`,
`fill_energy`, `sky_energy`, `ambient_energy` and `sdfgi_energy` were five free numbers
per scene, and turning any of them up always improves the surface you happen to be
looking at. Before:

| scene | contrast | shadow % | median |
|---|---|---|---|
| Brega | 4.40 | 5.3 | 0.740 |
| Ajdabiya | 2.18 | 2.7 | 0.549 |
| Ice 01 / 02 / 03 | 2.15 / 1.6 / 1.1 | 0.0 | 0.83 |
| Greybox | 1.19 | 0.6 | 0.514 |
| Title | 6.86 | 37.1 | 0.310 |

Below about 2:1 nothing in a frame has form, and a normal map cannot resolve at all — it
exists only in the difference between N·L at two angles. The full PBR stack was being
paid for and discarded on three of those scenes.

`LightingRig.Mood.set_contrast(key, key_to_fill, sky_lift)` now derives fill, sky,
ambient, SDFGI and sun-indirect from one authored ratio. Six moods converted. GI had to
be folded in on a second pass: the first version re-lit Ajdabiya to 5.5:1 and it still
measured 2.3:1, because `sdfgi_energy` was hardcoded to 1.0 and a town of albedo-0.55
sand refills every shadow the budget carves.

### Brega's sun was below the horizon

`SkyForge.sun_direction` documents its convention plainly — pitch is negative above the
horizon — and the Brega sunset was authored at +6.0 in both the sky preset and the rig
mood. They agreed with each other, which is what that class exists to enforce, and they
agreed on a sun six degrees under the ground. Every upward-facing surface in Level 1 was
lit by sky and GI alone. Now -6.0 in both places.

### Ajdabiya's value structure was inverted

Measured band luminance in the market frame: near verge 0.96, market floor 0.74,
buildings 0.55. The brightest band in the picture was the empty one along the bottom, so
the eye was pulled out of the composition and into dead space every frame. `NearPavement`
and `NearVerge` were built from the mid-ground `kerb` and `dust` materials; they have
their own two-stops-down materials now, and a continuous near kerb with bollards, crates
and gutter weeds sits on top of them. Result: 2.18:1 -> 3.71:1, median 0.549 -> 0.505.

Two dead ends on the way there, both recorded so they are not repeated:
- Scattering dark scrub at z +5.5 as a foreground. It produced a handful of small black
  tufts at mid-frame that read as dead spiders on the road. A band that must be
  continuous cannot be made of scattered props.
- Extending the road slab from z +3 to z +11 to "fill the hole at the bottom of the
  frame". There was no hole: `AjdabiyaKit` already builds `NearPavement` and `NearVerge`
  for exactly that reason, with the diagnosis written above them. Reverted.

### Ice fog

IceBonus01/02/03 ran volumetric density at 0.0045 / 0.0070 / 0.0030 — three to seventeen
times every other level. Volumetric fog renders at a low internal resolution, so at that
density in an already-white scene it does not read as atmosphere, it reads as the whole
frame being out of focus, which is exactly what the captures showed. Now 0.0018 / 0.0022
/ 0.0014, aerial perspective 0.70 -> 0.42, DOF far planes pushed off the mid-ground.
Not yet re-captured.

---

## What exists

**Engine.** Godot 4.7.2 stable, Forward+. Runs headless in a container on Mesa/lavapipe
software Vulkan — there is no GPU here, and Forward+ with GI, SSAO, SSIL, SSR and
volumetric fog renders anyway at roughly 0.9 s/frame at 1280×720. Every screenshot in
this repo was produced that way.

**Architecture.** Autoloads: `Gx` (run state, progression, settings, save),
`InputDirector` (InputMap built in code, remappable, persisted), `GraphicsDirector` (four
quality tiers that scale cost, never look, and which own `shadow_max_distance` per tier),
`FX` (hit-stop, time warp, camera impulse through one accessibility slider), `SceneFlow`
(authored transitions), `MusicDirector`, `AudioDirector`, `CaptureRunner`. `Stage` is the
level base class: lighting, camera, spawn, checkpoints, respawn and kill plane for free.
`scripts/core/World.gd` is the canon level manifest, stated exactly once.

**Authoring.** Every scene is a GDScript builder; `.tscn` files are thin wrappers, so
levels are diffable. `LevelKit` is the vocabulary — and it has no `BoxMesh` in it: every
box is chamfered and cached by size, with collision left as a plain box.

**Controller.** The `DESIGN.md` Part IV feel spec, implemented and verified: separated
acceleration/deceleration/turn, coyote time, jump buffering, variable height, apex hang,
fall gravity multiplier, momentum-preserving dash, dash-jump cancel, air-dash refund,
corner correction, landing hit-stop and camera kick, plane lock. Plus double jump and the
thobe glide.

**Animation.** No keyframes anywhere. `WanisRig` drives a 20-bone skeleton procedurally —
poses are targets and bones ease toward them, so overlap and follow-through come free.
Run cycle with two bounces per stride, breathing idle with random glances, airborne tuck
and reach, dash pose, critically-damped squash/stretch, acceleration lean, Verlet shemagh
and chain. `beauty_pose` is the authored marketing alternative to the gameplay idle.

**Camera.** Critically damped follow, predictive look-ahead, an airborne vertical deadzone
so routine jumps do not slosh the frame, grounded anchor snap, speed-driven FOV, spring
impulses, trauma shake on simplex noise, zoom punch.

**Capture pipeline.** `tools/capture.sh` + `--capture`, fixed timestep under Xvfb, so
captures are deterministic no matter how slow the software renderer is. Writes PNGs plus
a JSON manifest of position/velocity/state/grounded per frame. Two input modes: scripted
timelines for feel tests, and `--input=auto`, a geometry-driven traversal autopilot that
raycasts ahead, jumps what it cannot walk through and dashes what it cannot jump. It is
the automated playtest — if a level edit breaks a section, the manifest stops advancing at
exactly that x. It has already caught five level bugs a human would have missed.

**Materials.** `MaterialLab` + `shaders/surface_weathered.gdshader` + `NoiseBank`.
World-space triplanar with whiteout normal blending, two decorrelated macro tones, edge
wear that finds the chamfer on flat-shaded geometry, dust by world normal, grime from a
per-material ground datum, shared run-off streaking, one-step offset mapping and
distance-faded detail. More than two dozen presets covering structure, metal, ground, civic
surfaces, fabric, vehicle paint, glass, skin and ice. **The chroma law is enforced in
code** by `world_tint()`, not left to discipline. Nothing ships as a texture file.

**Lighting.** `LightingRig` is a cinematographer in a box: a level declares a `Mood` and
gets key, sky fill, ground bounce, rim and hero fill, the Environment, shadow splits as
tier-proof fractions, `shafts()` (which places the fog volume downstream of the occluder,
the thing every level got wrong by hand), `ground_mist()`, `hero_pocket()`, bulb-preset
practicals with deterministic flicker, and a real lift/gamma/gain grade through a
generated LUT. It carries a written exposure reference and `debug_describe()` prints where
a mood lands the canon surfaces.

**Props.** `PropKit` — prefab facades with crane holes, deep-set windows with louvred
shutters, storage tanks with bunds and spiral stairs, prilling towers, flare lattices,
distillation columns, pressure vessels, drum stacks, perimeter walls, building massing,
stair heads, roof kits, market stalls, shopfronts, town facades, palms, eucalyptus,
chain-link, razor coils, pipe racks, walkways, catwalks, catenary cables, laundry lines,
lit windows, wall services, roof clutter, sandbags and Arabic signage via TextMesh.
**Arabic shaping and bidi work** — Godot's TextServer orders Naskh and Kufi correctly.

**The hero.** `MeshForge` sweeps cross-section rings along the skeleton with superellipse
profiles, per-ring bone weights and vertex colour as authoring data. White thobe, shemagh,
gold chain, sirwal, sandals, hair as an offset copy of the skull. `WeaponForge` builds the
rifle; `Rifle` is full-auto at 9.5 rounds/sec with muzzle flash, ejection, a pooled tracer
system and recoil bloom. **Recoil is movement tech**: fired airborne it pushes opposite
the aim, so firing down is a hover and firing up drops him faster.

**Combat and hazards.** `Enemy` is the base contract: telegraph before committing, flash
and recoil when hit, die in a way worth watching. SNITCH drone (patrol, sweep, visible
wind-up, charge, recovery window), SENTRY wall turret (the telegraph *is* the fight),
HARRAS heavy walker (shield plate on the leading face, so the answer is to get behind it),
and steam vents on a fixed warned cycle, phase-staggered so a row ripples. Enemy fire is a
slow visible `Bolt`, never hitscan — the player's rifle is instant because it is his.

**Collectibles, HUD, audio, music.** `Collectible` separates rule from feedback.
`TrailBuilder` places lines, real ballistic arcs computed from the controller's own
constants, shaped curves and reward clusters. The HUD is drawn, not assembled from engine
widgets. `SfxForge` synthesises every sound as PCM on first use, surface-aware footsteps
included; collect sounds walk a Hijaz scale so a trail plays a phrase. `MusicForge`
synthesises the score — Hijaz over a maqsoum pulse, five stems per theme started on the
same frame and never restarted, with intensity as a mix decision so combat can enter on
the next frame instead of the next bar. `tools/audio_demo.gd` and `tools/music_demo.gd`
render both to WAV so audio is reviewable the way screenshots are.

**UI.** Nothing is a themed `Control`; everything is `_draw` through `UIKit` and
`MenuList`. Title screen (which extends `BregaBeauty` outright, so the first frame of the
game is the benchmark frame), world map built from real quarter-degree coordinates, chain
collection screen, pause, settings, result card.

**Level 1 — Brega Prison Breakout.** 400 units, six sections: the walkway, the yard, the
pipe rack, the property cage, the tank farm, the fence. Each introduces one thing and then
asks for it again in a harder shape. Three checkpoints wired to real `Checkpoint` nodes, a
tuna sandwich, Sriracha trails throughout, a hidden Iced Out Sriracha below the catwalk in
section E, and a level exit. The transformation beat is built to be felt — hit-stop, a
bloom of light, slow motion, the camera pushing in, the costume landing on the flash — and
opening the cage spawns the drones the next section is built around. A full autopilot run
reaches the gate with 51 Sriracha collected.

**Level 2 — Ajdabiya Crossroads.** 334 units, built as the counterweight to Brega: sun up
and in front, the street lit, shadows short and hard blue, colour everywhere because
people put it there. Two lines through it — the street is safe, slow and generous; the
roofs are fast, exposed, better-paid and the only route to the Iced Out bottle — crossing
at four points, so the choice is never locked in. The minaret is skyline only.

**The Iced Out system is complete.** Find the bottle, warp, collect 100, earn the chain,
come back. `SceneFlow` owns the transition and it is authored, not a fade: frost crawls in
from the edges and from crystal seeds, and the warp back is the same effect reversed, so
the round trip feels like one move. Two ice levels in the pool. `IceHUD` is a count inside
a closing timer ring. All 100 stops the world, flashes, and drops the chain on a halo
light — verified `chains=1` in the capture manifest.

---

## Built but not adopted

Capability that exists in the repo and is improving no frame yet, as of this writing:

- **`DetailKit`** — the small-and-medium industrial and civic detail library (pipework
  with real terminations, cable trays, ladders, grating, handrails, switchgear, drainage,
  rubble, scaffold). Nothing calls it.
- **`SkyForge` + `shaders/sky.gdshader`** — the procedural sky with per-level presets that
  reads the scene's own key so the disc can never drift from the light. `LightingRig` still
  installs a `ProceduralSkyMaterial` and no level calls `SkyForge.apply()`.
- **`WaterKit` + `shaders/water.gdshader`** — the Gulf, the corniche and the frozen sea
  from one shader. No level calls it; Brega's sea is still an emissive slab.

---

## Fixed

**The hit-stop froze the game permanently on first use.** `FXDirector` counted the
hit-stop down with `delta / maxf(Engine.time_scale, 0.0001)`. The engine scales
`delta` by `time_scale` before `_process` sees it, so at scale 0.0 delta arrives as
0.0 and the quotient is still 0.0: `_hitstop_left` never decreased and time scale
never came back. Every `_process` delta in the game then read 0.0 forever.

On the title screen that surfaced as a dead menu. The hero spawns on the catwalk and
lands, `PlayerController` fires a landing hit-stop, `_t += delta` stops advancing, `_t`
never reaches `CAM_SETTLE`, and `_menu.accept_input` is never set true — while the menu
is already visible, because that happens earlier at `MENU_IN`. A drawn, highlighted,
permanently unresponsive title screen. It would have frozen on the first landing in
Brega just the same.

Now counted off `Time.get_ticks_usec()`. `SceneFlow`'s two transition tweens also
ignore time scale, so a wipe finishes whatever gameplay time is doing.

Also: `Enter` was bound to nothing. Every menu took "jump or attack" as confirm. There
is now a `confirm` action (Enter, keypad Enter, gamepad A) accepted everywhere those
were, and a key pressed during the title entrance skips it instead of being swallowed.

---

## Weak — the honest list

1. **The key is two to three stops hot.** `LightingRig`'s exposure reference works the
   AgX curve out in numbers: with a pale calcareous ground the key wants to be in the
   1.0–2.0 band, and the shipped moods run 3.1 (Brega) and 4.2 (Ajdabiya). Past linear
   ~1.5 you buy almost no screen value and only burn headroom, so the ground sits on the
   shoulder right next to the hero and the frame flattens. Brega half gets away with it
   because its key is behind the geometry; Ajdabiya, front-lit, does not. This is
   currently the single biggest thing standing between these levels and the gate.
2. **The benchmark still does not pass its own gate.** It is much closer than it was: the
   block sits low in the value range so the thobe owns the frame, the shadow side is cool
   against a warm key, a pole line and a conveyor gantry bridge the middle ground, the
   plant has columns, vessels, a stair tower and drum stacks instead of haze, the handrail
   was rebuilt as stanchions with a top rail, mid rail and toe plate, and one flare burns
   as a focal point. What was still wrong at the last review: the sun is a bright blob
   doing no storytelling and the eye goes to it first; the block has no large-scale value
   incident (a repaired bay, a scorched section, a balcony run) so at distance it is one
   dark rectangle.
3. **The canon numbers and the shipped numbers have drifted apart.** `ART_DIRECTION.md`
   prescribes `agx_white` 9.5 and `agx_contrast` 1.45; the moods ship the engine defaults
   16.29 / 1.25, which is flat. Same for `volumetric_sky_affect` (canon 0.0, shipped 1.0)
   and `sun_indirect_energy` (canon 1.3, shipped 1.0). The new grade LUT is implemented
   and **no mood uses it**, so both levels are still graded with global saturation and
   contrast, which is exactly what makes everything slide toward the same orange.
4. **One documented chroma-law violation.** The market stall awning drives colour through
   `vertex_color_use_as_albedo`, which `world_tint()` cannot see, and the madder stripe
   is authored at roughly S 0.75 / V 0.72 inside the reserved 340°–25° band, where the
   cap is S 0.55. Either author it inside the cap or move the awning to `canvas()`.
5. **Motion is implemented but barely reads.** Wind, sway, dust, plume and laundry all
   exist; at the distances these cameras use, almost none of them register. Needs bigger
   amplitudes and more value contrast against their backgrounds. The DRAPE rule says every
   screen carries one moving hanging element and most screens do not.
6. **Depth of field is off everywhere.** Godot's near blur is distance-from-camera and
   swallows the whole gameplay plane before it softens a foreground at Z = +7, so
   foreground separation is done with value and scale alone. Works, but it costs the
   cinematic near-defocus the art direction asks for.
7. **His hand does not land on the rail.** `beauty_pose` gives authored contrapposto with
   the head turned past the shoulders, but the arm is posed by eye rather than solved, so
   the hand floats near the rail instead of resting on it. There is no IK in the project.
8. **Level 2 is missing canon content.** No tuna sandwich anywhere in Ajdabiya (Brega and
   the greybox have one each). The ghibli — the dust storm the colour script says the
   second half is played inside — is not built, and neither is the terra rossa that is
   supposed to be the level's unique hue; the awning stripe set is carrying that job
   instead.
9. **Two themes, one arrangement.** Brega and the ice levels have a score. **Ajdabiya
   sets `music_theme = "brega"` and plays Level 1's music**, which is the kind of
   placeholder that stops being noticed. No transitions between themes, and no stinger
   for a beat as big as the transformation.
10. **Three enemies and one hazard, all originating in Level 1.** Still missing: anything
    that attacks from below, anything that changes the geometry (a crusher, a collapsing
    floor), and any use of water as a hazard.
11. **No controls screen and no first-run tutorial.** The UI suite is otherwise complete
    for World 1.
12. **Corner correction is implemented but untested.** The lab has the lip; no capture has
    driven a jump into it at the right angle.
13. **Performance is unprofiled on real hardware.** Software-renderer timings say nothing
    about 60 fps at 1080p, and the benchmark scene is heavy. Nobody has counted draw calls.
14. **The capture ritual is slipping.** Every screenshot in `docs/screenshots/` is dated
    the same day. Systems have landed since without a frame to show for them, which is
    how a project stops knowing what it looks like.

---

## Missing entirely

- Levels 3, 4 and 5, and the boss. Level 3 needs a vehicle controller that feels as good
  as the on-foot one; nothing of it exists.
- More ice levels for the random pool (two is a thin pool for five chains).
- The World 1 ending sequence.
- Any second world.

---

## Known bugs

None open. Fixed recently: a jump state clobbered back to RUN for one frame by the
locomotion update reading a stale `on_floor`; `StandardMaterial3D.specular` used as a
property name (a Godot 3 name — every specular tweak in the project was a silent no-op
that also spammed the log); collect bursts rendering as large red squares; fill and rim
lights each painting their own sun disc into the procedural sky; tracer particles emitted
from a marker under a scaled skeleton producing garbage transforms; `MenuList` laying
Arabic labels a full text-box width past the slab edge; and two props sharing a name so
lookups returned the wrong one. The engine log is clean — zero errors, zero warnings — on
a full autopilot run at high quality.

---

## Session record — 2026-09-22, the parallel build pass

Twenty-eight agents ran at once against disjoint file ownership, on a four-core box with
no GPU. Most of them delivered; most of them could not get a screenshot, because forty
concurrent software Vulkan renders on four cores is not a render farm. **So a large part
of what landed in this pass is verified by parse, by headless runtime and by geometry
measurement, and NOT by eye.** That is the honest state of it, and the next pass's first
job is to look at all of it.

What landed:

- **`MaterialLab`** grew to 28 presets and moved every metal to a physically correct 0.0
  or 1.0 (heavy rust is a dielectric; paint is a dielectric; bare mill sheet is a
  conductor). The chroma law is now enforced in code by `world_tint`, feathered over 10°
  around the reserved red band because iron oxide sits at hue 23. A `tone` dial on every
  world preset moves colour and dirt together, so shaded faces stop being hand-darkened.
- **`LightingRig`** gained grading (a real 33³ LUT with a soft knee), per-mood shadow
  splits expressed as fractions, a three-way fill with a ground bounce, `shafts()` /
  `ground_mist()` / `hero_pocket()`, eight bulb presets with flicker, and a physically
  anchored exposure reference. Its finding is the most important one in this pass:
  **nothing was feeding AgX at all** — `Mood.white` is dead — and both shipped keys run
  two to three stops hot, which is why the pale ground and the white thobe land on the
  same part of the shoulder.
- **New kits, none of them adopted by a level yet**: `SkyForge` (4 sky presets, and the
  straw dust band the art direction calls the most location-specific decision in the game
  is still not on screen anywhere), `WaterKit`, `DecalKit`, `FoliageKit`, `DetailKit`,
  `VehicleKit`, `FXKit`. This is now roadmap item one: a kit that no frame calls is dead
  code, however good it is.
- **Hero**: the rig pass found and fixed five real bugs — run arm swing was ipsilateral,
  the acceleration lean was applied to the screen-depth axis where nobody could see it,
  run and dash both leaned backwards, the rifle aim sign was inverted, and two lerps were
  fighting over the glide's body pitch. The rifle had no visible pistol grip at all: the
  old one extended up into the inside of the receiver.
- **`MeshForge.loft`** had a seam on every closed loft — the last quad interpolated U from
  0.94 back to 0, giving near-zero averaged tangents and a hard crease down every lofted
  mesh in the game. One extra vertex column fixes it.
- **ICE bonus 3, "THE CREVASSE"** — a descent built around the thobe glide, which nothing
  else in the game showcases. The pool is three.
- **Verification that actually compiles shaders.** `levels/lab/ShaderLab` mounts every
  `.gdshader` on the carrier its mode requires and `verify_all.sh` boots it, because
  neither `--import` nor `--check-only` validates shader source — both run the dummy
  rasterizer and will pass a file that is pure syntax error.

Verified after integration: `tools/verify_all.sh` reports ALL CLEAN — 14 scenes boot under
real Vulkan, every script parses, all twelve shaders compile.


---

## Session record — 2026-09-22, the parallel build pass

Twenty-eight agents ran at once against disjoint file ownership, on a four-core box with
no GPU. Most of them delivered; most of them could not get a screenshot, because forty
concurrent software Vulkan renders on four cores is not a render farm. **So a large part
of what landed in this pass is verified by parse, by headless runtime and by geometry
measurement, and NOT by eye.** That is the honest state of it, and the next pass's first
job is to look at all of it.

What landed:

- **`MaterialLab`** grew to 28 presets and moved every metal to a physically correct 0.0
  or 1.0 (heavy rust is a dielectric; paint is a dielectric; bare mill sheet is a
  conductor). The chroma law is now enforced in code by `world_tint`, feathered over 10°
  around the reserved red band because iron oxide sits at hue 23. A `tone` dial on every
  world preset moves colour and dirt together, so shaded faces stop being hand-darkened.
- **`LightingRig`** gained grading (a real 33³ LUT with a soft knee), per-mood shadow
  splits expressed as fractions, a three-way fill with a ground bounce, `shafts()` /
  `ground_mist()` / `hero_pocket()`, eight bulb presets with flicker, and a physically
  anchored exposure reference. Its finding is the most important one in this pass:
  **nothing was feeding AgX at all** — `Mood.white` is dead — and both shipped keys run
  two to three stops hot, which is why the pale ground and the white thobe land on the
  same part of the shoulder.
- **New kits, none of them adopted by a level yet**: `SkyForge` (4 sky presets, and the
  straw dust band the art direction calls the most location-specific decision in the game
  is still not on screen anywhere), `WaterKit`, `DecalKit`, `FoliageKit`, `DetailKit`,
  `VehicleKit`, `FXKit`. This is now roadmap item one: a kit that no frame calls is dead
  code, however good it is.
- **Hero**: the rig found and fixed five real bugs — run arm swing was ipsilateral, the
  acceleration lean was applied to the screen-depth axis where nobody could see it, run
  and dash both leaned backwards, the rifle aim sign was inverted, and two lerps were
  fighting over the glide's body pitch. The rifle had no visible pistol grip at all: the
  old one extended into the inside of the receiver.
- **`MeshForge.loft`** had a seam on every closed loft — the last quad interpolated U from
  0.94 back to 0, giving near-zero averaged tangents and a hard crease down every lofted
  mesh in the game. One extra vertex column fixes it.
- **ICE bonus 3, "THE CREVASSE"** — a descent built around the thobe glide, which nothing
  else in the game showcases. The pool is three.
- **Verification that actually compiles shaders.** `levels/lab/ShaderLab` mounts every
  `.gdshader` on the carrier its mode requires and `verify_all.sh` boots it, because
  neither `--import` nor `--check-only` validates shader source — both run the dummy
  rasterizer and will pass a file that is pure syntax error.

Verified after integration: `tools/verify_all.sh` reports ALL CLEAN — 14 scenes boot
under real Vulkan, every script parses, all twelve shaders compile.


### Post-integration capture pass, 2026-09-22

Every scene was re-shot at 1920x1080 on a quiet box and looked at. What the
frames actually say:

**The grade is the single biggest change this project has had.** Before it, the
Brega benchmark was one orange from the foreground column to the sky — the
near tower, the water tower and the far cracking plant all landed within about
a tenth of each other in value, and the frame read as a wash. `agx_white 9.5`,
`agx_contrast 1.45`, the key down from 3.1 to 2.0 and a cool-shadow / warm-
highlight split put four separate depth layers back in the frame in one pass.
The foreground now silhouettes cool against a warm sky, which is what the
colour script said it should do all along. Same treatment on Ajdabiya (key 4.2
to 2.3) took the street off the top of the AgX shoulder: nine albedo values
that were rendering as three now render as nine.

**Three real bugs the captures caught that nothing else would have:**
- `CharacterShowcase` shot the backdrop. The capture tool's traversal autopilot
  walked the subject seven metres off the plinth at 12.6 m/s, because a
  sign-off stand is not a level and nothing had told it so. It now pins him and
  runs a locked-off camera: `GameCamera` derives its height from a ground
  reference it resolves while the subject moves, so on a stand it never settles
  and shoots over his head.
- `MaterialShowcase` framed by width only and cropped four materials off the
  top and bottom. On a chart that is not composition, it is four materials
  nobody signed off.
- Gold and chrome rendered black on that chart. They were not broken — they are
  mirrors, and the studio had nothing in it to reflect. `SkyForge.apply(env,
  "studio")` fixed both, and is now the third scene adopting the sky kit.

**ICE 3 shipped fogged into a white-out.** Fog is charged per unit of depth and
the level is 110 units deep; it had been given Brega's numbers multiplied up
rather than divided down, so the whole crevasse rendered as one sheet of pale
blue. Fixed, plus the wall gradient now starts at a mid value rather than a
bright one — the snow shelves are the only thing in that level allowed near the
top of the range.

**The honest verdict: the environments are getting close, the hero is not.** On
the stand at 1080p he is the weakest thing in the game. The hands are mitts
with no fingers, the shemagh hangs like a board rather than cloth, the thobe is
a cone with no sleeve break or hem structure, and the rifle — which just got a
556-line detail pass — is almost entirely hidden behind the shemagh from the
angle the game actually uses. **He is now weakness #1, ahead of everything
currently listed.** The rig work underneath him is good; the model is not.
