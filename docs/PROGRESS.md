# PROGRESS

## Status: milestone 1 complete — engine, capture pipeline, controller

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

### Weak — the honest list

1. **The hero is a greybox proxy.** Primitive capsules. It reads as a person
   running, which is the most that can be said for it. This is the single weakest
   thing on screen and it is next.
2. **No beauty benchmark yet.** Nothing in the repo has been taken to shippable
   visual quality. The greybox looks like a competent greybox.
3. **The bottom quarter of the frame is a flat slab.** Foreground occluders exist
   but barely clip the frame. Real levels need a proper near layer.
4. **No materials.** Everything is flat `StandardMaterial3D` albedo. No normal
   maps, no roughness variation, no detail, no decals, no triplanar.
5. **Nothing moves but the player.** No dust, no wind, no particles, no
   environmental motion at all.
6. **No audio.** Not one sound. The audio architecture does not exist yet.
7. **No collectibles, no HUD, no enemies, no hazards, no UI.**
8. **Corner correction is implemented but untested** — the lab has the lip, but no
   capture has driven a jump into it at the right angle yet.
9. **Ice/chain/bonus systems are data-modelled in `Gx` but have no scenes.**
10. **Performance is unprofiled** on real hardware. The software-renderer timings
    say nothing about the 60 fps at 1080p target.

### Known bugs
- None open. Fixed this iteration: the jump state was being clobbered back to RUN
  for one frame by the locomotion state update reading a stale `on_floor`.
