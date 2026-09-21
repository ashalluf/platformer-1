# PROGRESS

## Status: Level 1 playable end to end

### Built

**Engine & environment**
- Godot 4.7.2 stable, Forward+ renderer. Running headless in a container on
  Mesa/lavapipe software Vulkan — there is no GPU here, and Forward+ with SDFGI,
  SSAO, SSIL, SSR and volumetric fog renders anyway at roughly 0.9 s/frame at
  1280×720. Every screenshot in this repo was produced that way.
- `project.godot` tuned for quality: 4096 directional shadows, MSAA 2×, high soft
  shadow filtering, SSAO/SSIL/SSR quality, subsurface scattering, volumetric fog
  volume 96×128.

**Architecture**
- Autoloads: `Gx` (run state, progression, settings, save), `InputDirector`
  (InputMap built in code, remappable, persisted), `GraphicsDirector` (four
  quality tiers that scale cost, never look), `FX` (hit-stop, time warp, camera
  impulse routing through one accessibility slider), `CaptureRunner`.
- `Stage` base class: every level gets lighting, camera, spawn, checkpoints,
  respawn and kill plane for free.
- `LightingRig`: a level declares a mood — sun angle, colour temperature, fog,
  key/fill/rim — and the environment is built from it. One place stops World 1
  drifting into five different-looking games.
- `LevelKit`: code-authored geometry. All scenes are GDScript builders; `.tscn`
  files are thin wrappers. Levels are diffable.

**Controller** — the feel spec in `DESIGN.md` Part IV, implemented and verified:
acceleration/deceleration/turn separation, coyote time, jump buffering, variable
jump height, apex hang, fall gravity multiplier, momentum-preserving dash,
dash-jump cancel, air-dash refund on landing, corner correction, landing impact
scaled hit-stop and camera kick, plane lock.

**Procedural animation** — no keyframes anywhere. Run cycle with two bounces per
stride and shoulder counter-rotation, breathing idle with random head glances,
airborne tuck and reach poses, dash pose, critically-damped squash/stretch spring,
acceleration-driven lean, and a verlet sash with follow-through.

**Camera** — critically damped follow, predictive look-ahead, an airborne vertical
deadzone so routine jumps do not slosh the frame, grounded anchor snap,
speed-driven FOV, spring impulses, trauma shake on simplex noise, zoom punch.

**Capture pipeline** — `tools/capture.sh` + `--capture`. Fixed timestep under
Xvfb, so captures are deterministic no matter how slow the software renderer is.
Writes PNGs plus a JSON manifest of position/velocity/state/grounded per frame.
Two input modes:
- **scripted timelines** (`tools/CaptureScripts.gd`) for feel-specific tests
- **`--input=auto`**, a geometry-driven traversal autopilot that raycasts ahead,
  jumps what it cannot walk through and dashes what it cannot jump. It is the
  automated playtest: if a level edit breaks a section, the manifest stops
  advancing at exactly that x.

**Greybox movement lab** — a calibration range, not a level: run-up with height
rulers, three step heights, three gap widths bracketing a running jump, a corner
correction lip, up/down ramps, a dash-only gap, and a pit for the respawn path.
Verified: the autopilot clears all of it end to end, including the dash gap.

### Added since milestone 1

**Material system** — `shaders/surface_weathered.gdshader` plus `MaterialLab` and
`NoiseBank`. World-space triplanar with whiteout normal blending, macro tonal
drift, dust accumulating on up-facing planes by world normal, grime creeping up
from a per-material ground datum, and distance-faded detail. Concrete, lime
plaster, rusted steel, painted sheet, corrugated roofing (analytic sine ridges,
two triangles), sand, asphalt, subsurface skin, cloth, gold, chrome, glass.
Nothing ships as a texture file.

**Wanis** — a procedural skinned character. `MeshForge` sweeps cross-section
rings along a 20-bone skeleton with superellipse profiles, per-ring bone weights,
partial arcs and vertex colour as authoring data. White thobe, shemagh, gold
chain, sirwal, sandals, hair built as an offset copy of the skull. `WanisRig`
drives the skeleton procedurally; poses are targets and bones ease toward them,
so overlap and follow-through come free.

**Moveset** — double jump with a rotation flourish, and the thobe glide: hold
jump while falling and the robe fills like a parachute, flattening the descent to
3.4 u/s with wider lateral authority. It is a distinct silhouette, not a slower
fall.

**PropKit** — prefab facades with crane holes, deep-set windows with louvred
shutters, storage tanks with bunds and spiral stairs, prilling towers, flare
lattices, chain-link (procedural alpha, alpha-to-coverage), razor coils,
eucalyptus, pipe racks, walkways, sandbag rows, and Arabic signage via TextMesh.

**Arabic signage works.** Godot's TextServer shapes and orders Naskh and Kufi
correctly. The Green Book-era wall carries a slogan, a crossing-out and a
tricolour, all faded by the same sun.

**Beauty benchmark v1** — `levels/brega/BregaBeauty.tscn`, "First Light,
Exercise Yard". Nine depth layers, a back-lit 3.5° key, a hero-only fill and rim
on a dedicated render layer, volumetric haze, a ground-mist FogVolume, a negative
light under the walkway, three practicals, and the first two Sriracha bottles.

**The rifle.** `WeaponForge` builds a stamped-receiver 7.62 pattern rifle —
wood furniture, gas tube above the barrel, and the curved magazine that carries
the silhouette. `Rifle` is full-automatic at 9.5 rounds per second with muzzle
flash, an ejection port, a pooled tracer system and recoil bloom. Recoil is
deliberately a movement tool: fired airborne it pushes him back hard enough to
extend a jump backwards or stall a fall, so the rifle is part of the traversal
kit rather than a separate system. He runs and guns; the legs keep whatever the
locomotion state was doing while the upper body holds the weapon.

**Environmental motion.** `shaders/foliage_wind.gdshader` drives canopies with
two scales of motion phase-offset by world position, anchored by height above
each plant's base. `Sway` gives rigid hanging things the same treatment.

**Two real rendering bugs found by capture and fixed.** Every directional light
was painting its own sun disc into the procedural sky, so fill and rim lights
were each drawing a second and third sun — fill and rim are now `SKY_MODE_LIGHT_ONLY`.
And GPU-particle tracers emitted from a marker buried under a scaled skeleton
produced garbage transforms that rendered as bars pinned to the sky; tracers are
now an explicit pool that owns its own placement.

**Collectibles, trails and HUD.** `Collectible` separates the rule from the
feedback: a magnet pull, a pop, a spark burst, optional hit-stop and camera
nudge, identical for everything and escalating only in scale. Sriracha feeds the
count and the HEAT gauge; the tuna sandwich — split baguette, tuna, harissa
stripe, olives, egg — gives a life. `TrailBuilder` places lines, real ballistic
jump arcs computed from the controller's own constants, shaped curves, reward
clusters and pointing columns. The HUD is drawn, not assembled from engine
widgets: bottle, sandwich and chain glyphs are polygons, and the HEAT gauge only
asserts itself as it fills.

**Audio exists.** `SfxForge` synthesises every sound as PCM on first use — no
audio files ship. Footsteps are surface-aware (the collider names its own
material by group), the Heat Dash is a darbuka hit under a noise whoosh, and
collect sounds walk up a Hijaz scale so a Sriracha trail plays a phrase instead
of repeating one click forty times. `AudioDirector` owns the buses, pools 24
positional and 8 non-positional players, and drives volumes from the settings.
`tools/audio_demo.gd` renders the whole palette to `docs/audio_demo.wav` so
audio can be reviewed the way screenshots are.

**Combat.** `Enemy` is the base contract: telegraph before committing, flash
and recoil on being hit, die in a way worth watching. World 1's prison enemies
are Brega's automated security — a tonal decision as much as a design one, since
full-auto gunplay against machines stays playful in a way gunplay against people
would not. The SNITCH drone patrols, sweeps, stiffens and brightens to white
during a visible wind-up, charges, then leaves a recovery window that is the
player's turn. The rifle is hitscan with cosmetic tracers, and **vertical aim**
(hold up or down) exists because without it the rifle could not touch anything
that was not exactly level with him. Recoil now pushes opposite the aim, so
firing downward is a hover and firing upward drops him faster — two pieces of
movement tech out of one line. One touch costs a life, DKC-style, with a
generous invulnerability window and a visibility flicker.

**LEVEL 1 EXISTS.** `levels/brega/Brega.tscn` is a 400-unit level in six
sections, each introducing one thing and then asking for it again in a harder
shape:

| | | |
|---|---|---|
| A | THE WALKWAY | run, jump, trails — in prison grey |
| B | THE YARD | double jump, the first SNITCH |
| C | THE PIPE RACK | the thobe glide, over a drop no jump can cross |
| D | PROPERTY CAGE | the transformation: thobe, chain, shemagh, rifle |
| E | THE TANK FARM | vertical aim and run-and-gun |
| F | THE FENCE | dash and glide chains, and out through the gate |

Three checkpoints, a tuna sandwich, Sriracha trails throughout, a hidden Iced
Out Sriracha below the catwalk in section E, and a level exit. `BregaKit` holds
the shared environment so the benchmark shot and the playable level are the same
place rather than two copies of it.

The transformation beat is built to be felt: hit-stop, a bloom of light, a
slow-motion window, the camera pushing in, and the costume swap landing on the
flash rather than before it. Opening the cage also changes the level — it spawns
the drones that section E is built around.

**The autopilot found five level bugs before a human would have.** Twenty units
of missing floor between the walkway and the yard; a cage whose set dressing was
solid and blocked the beat; a glide flag that cleared itself on the frame it was
set; an eight-unit gap with a rise that no jump clears; and a glide armed at a
ledge *above* the player, which sank him into the pit in front of it. A full run
now reaches the gate with 51 Sriracha collected.

**Two more silent bugs fixed.** `StandardMaterial3D.specular` is a Godot 3
property name — every specular tweak in the project was a no-op that also
spammed the log. And collect bursts were rendering as large red squares. The
engine log is now completely clean: zero errors, zero warnings, on a full
autopilot run at high quality.

**docs/ART_DIRECTION.md** is canon for World 1: visual pillars, a per-level
colour script, shape and material rules, the depth-layer recipe, Godot settings
with a pitfall list, and the benchmark build order.

### Weak — the honest list

1. **The benchmark does not pass its own quality gate yet.** It splits into
   "dark building on the left, bright haze on the right" without enough
   transition between them. It is atmospheric and it is not yet a marketing
   frame. Specific failures: the sun shafts the brief calls for are not
   forming; the material detail is invisible at the distances the camera
   actually uses, so surfaces read as flat colour; the panel joint grid is
   mechanical; the crane holes read as polka dots; the awning cluster at lower
   left is awkwardly placed.
2. **Motion is implemented but barely visible.** Wind, sway and dust all exist
   now; at the distances the benchmark camera uses, none of them read. Needs
   bigger amplitudes and more contrast against their backgrounds.
3. **Wanis stands in the default idle.** The benchmark calls for authored
   contrapposto with a hand on the broken rail post and the head turned 12°
   past the shoulders. Levels cannot pose the character yet.
4. **The rifle has nothing to shoot.** Tracers fly and vanish; there is no
   impact, no decal, no enemy, no damage. Recoil movement tech is implemented
   but untested against real level geometry.
5. **No music.** SFX and an ambience bed exist; there is no score. The Libyan /
   North African musical identity in DESIGN.md is unbuilt.
6. **One enemy type, in the greybox only.** The turret and the heavy walker
   from the enemy plan do not exist, no enemy appears in Brega, and there are
   no hazards — no spikes, no crushers, no fire, no water.
7. **No menus.** No title screen, no pause, no settings, no World 1 map, no
   chain collection screen. The HUD is the only UI.
8. **Checkpoints are a data structure with no scene.** `Stage` tracks them;
   nothing places or triggers them.
9. **The Iced Out warp and ice bonus levels do not exist** beyond `Gx` counters
   and a bottle variant.
10. **Corner correction is implemented but untested** — the lab has the lip, but
    no capture has driven a jump into it at the right angle.
11. **Performance is unprofiled** on real hardware. Software-renderer timings say
    nothing about the 60 fps at 1080p target, and the benchmark scene is heavy.
12. **Depth of field is off.** Godot's near-blur radius swallows the whole
    gameplay plane; foreground separation is currently done with value alone.

### Known bugs
- None open. Fixed this iteration: the jump state was being clobbered back to RUN
  for one frame by the locomotion state update reading a stale `on_floor`.
