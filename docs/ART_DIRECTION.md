# LIBYAN GANGSTAS — WORLD 1 ART DIRECTION

**Status: CANON.** This document is not a mood board and not a menu. Every value in
it is a decision. Build from it. If you disagree with something here, change the
document first and say why — do not quietly build something else.

Authority: supersedes any art guidance in `DESIGN.md` Part III. Defers to
`DESIGN.md` Part IV (technical canon) on camera geometry and controller feel.

---

## Visual pillars

**One: this is the Mediterranean, not the Sahara.** World 1 is a coastal, salt-eaten,
Italian-and-Soviet-inflected, sun-bleached pastel world — bone white, oatmeal, apricot,
faded mint, chalky sky-blue — sitting on pale calcareous ground with red interior sand
bleeding into it. The palette is *drained*, not *brown*. Anyone who reaches for dune
ochre, camel silhouettes or a generic desert filter has misunderstood the game.

**Two: it is always the hour that flatters.** Midday does not exist in World 1 except
as a deliberate hostility in Level 3. Every other level is lit at a raking angle —
sunrise, golden hour, blue hour, sodium night — because low sun is what turns flat
prefab concrete into architecture, and because a 15%-of-screen-height hero needs a rim.

**Three: density behind, silence in front.** Backgrounds are ferociously detailed and
atmospherically compressed; the gameplay plane is comparatively sparse, higher-contrast,
sharper, and lit by its own light rig. The player never has to hunt for the floor.

**Four: surfaces carry history, not just age.** Weathering here is political and
climatic archaeology — regime green under a Green Book slogan under a crossing-out
under a 2011 tricolour, all sun-faded together; salt spalling that exposes rebar; sand
drift that maps who still lives here. A wall states what happened to it.

**Five: Wanis is the only saturated thing in the frame.** The world is capped in chroma
and the hero is not. That single rule does more for readability than every post-process
in the engine combined, and it is enforced numerically in the palette section below.

---

## Colour script

World 1 is **one day**, running forward across five levels. That is the cohesion device:
sunrise → mid-morning → hard afternoon → golden hour → night. Nothing else needs to tie
the levels together, and nothing is allowed to violate it.

The constant across all five: **ground is always in the pale calcareous family**
(`#D6CEBC` → `#EFE6D2`) with red interior "Heix" sand (`#B5784A`) drifting into it, and
**shadow is never neutral and never black** — `#6B5F55` warm ochre-violet by day,
`#2A3A56` cool by night.

Chroma law, enforced project-wide: **no world-surface albedo may exceed HSV S 0.55 /
V 0.72 within hue 340°–25° (the red sector).** That band is reserved for Wanis's jacket
and the Sriracha. Damage and danger are signalled with hazard yellow-black chevrons and
a white hit-flash, never red.

---

### Level 1 — BREGA PRISON BREAKOUT
*05:52 → 06:40. Pre-dawn blue cracking into first direct sun. The transformation beat
lands on the exact frame the sun clears the horizon.*

| | |
|---|---|
| **Sun altitude** | 2° at spawn → 11° at level end |
| **Sun azimuth** | 101° ESE — screen-right and 22° behind the camera plane. He is back-lit and rim-lit for the whole level. |
| **Colour temp** | 1950 K `#FF8A2E` at spawn → 2850 K `#FFA657` at the transformation |
| **Key** | `DirectionalLight3D`, energy 0.35 → 1.45 ramped over the level, `light_angular_distance` 1.1, `shadow_opacity` 0.82 |
| **Fill** | Sabkha/sky bounce. Second directional from below-front, energy 0.30, `#A7B6C8` pre-dawn → `#CBBBA2` after sunrise. No shadows. |
| **Rim** | Character cull-mask only, from behind-right, energy 2.6, `#FFB877` |
| **Fog** | Depth fog `#3A4152` pre-dawn → `#C9B394` post-sunrise. `fog_depth_begin` 22, `fog_depth_end` 380, `fog_depth_curve` 1.4, `fog_aerial_perspective` 1.0. Volumetric density 0.016, anisotropy 0.78. |
| **Level-unique colour** | **REGIME GREEN `#2E7A3F`**, faded to `#5E8A5C` on sun faces. The crossed-out Green Book wall. It appears in this level and in no other level of World 1. |

Supporting palette: prison slab beige `#D8CEB6`, perimeter wall grey `#B4AEA2`, tank-shell
chalked cream `#E4E0D4`, fresh rust `#C1652A`, aged rust `#5E3220`, sabkha crust `#E8E2D2`,
wet sabkha `#5C5040`, dead eucalyptus `#7D8B6A`, prison uniform `#8E96A0`.

---

### Level 2 — AJDABIYA
*09:10 → 10:30. Clear mid-morning for the first half. The ghibli arrives at the midpoint
and the second half is played inside it.*

| | |
|---|---|
| **Sun altitude** | 34°, then progressively obscured |
| **Sun azimuth** | 118° ESE-SE, high screen-right |
| **Colour temp** | **Clear:** 4900 K `#FFDABB`. **Ghibli:** 2500 K `#FF9B44`, sun reduced to a disc you can look at |
| **Key** | Clear: energy 1.35, `angular_distance` 0.8. Ghibli: energy 0.42, `angular_distance` 6.0 (the disc smears into a glow) |
| **Fill** | Clear: directional 0.42, `#8FA8C4`. Ghibli: fill goes omnidirectional — ambient energy 0.75 → 1.60, ambient colour `#B5713F`. The world becomes sourceless. |
| **Rim** | Clear: 2.2 `#FFD2A0`. Ghibli: 1.1 `#E08B4A` — dropped in energy but shifted warm-bright so Wanis still reads against the brown. This is the one place the rim is allowed to be non-physical. |
| **Fog** | Clear: `#D9C3A4`, depth density 0.012, `depth_end` 380. Ghibli: `#B5713F`, depth density 0.075, `depth_end` 70, volumetric 0.055. Horizon disappears entirely. |
| **Level-unique colour** | **SABKHA TERRA ROSSA `#9C4E33`** — the red mud under the cracked salt crust, and red Heix sand tongues lying across the asphalt. The only earth-red in the game. |

Supporting palette: dust plain `#D8C5A0`, render `#E6DCC6`, concrete block `#C2B49C`,
shadowed concrete `#8E9A8C`, salt bloom `#F4F1E8`, gate sage `#5E8A5C` (the western gate
is deliberately faded so it never competes with the terra rossa), painted shutters `#3E5A6B`.

---

### Level 3 — HIGHWAY TO BENGHAZI
*13:40 → 15:20. The hardest, flattest light in the game, on purpose. This is the vehicle
level; the read is horizontal velocity, not surface modelling.*

| | |
|---|---|
| **Sun altitude** | 61° |
| **Sun azimuth** | 205° SSW, slightly behind-left. Short shadows rake forward-right and slide under the car. |
| **Colour temp** | 5500 K `#FFE2C8` |
| **Key** | energy 1.60, `angular_distance` 0.9, `shadow_opacity` 0.90, `directional_shadow_max_distance` 70 (long, for the road) |
| **Fill** | Sky ambient 1.0 plus an asphalt bounce directional from below, energy 0.22, `#8E8880`. Bounce from below is what stops the car reading as a sticker. |
| **Rim** | energy 3.2, `#9FC4E8` — the strongest and coolest rim in World 1, because at speed the hero and vehicle are the only things the eye can lock onto. |
| **Fog** | `#DCCBAE`, depth density 0.009, `depth_begin` 30, `depth_end` 520 — long, so the road has a real vanishing point. Volumetric 0.006, anisotropy 0.55. |
| **Signature atmospheric** | Heat haze. `strength` 0.016 at the road surface, falling linearly to 0 at y = 0.45 of frame height. Never above that line. |
| **Level-unique colour** | **OLEANDER PINK `#E58FA6`** on the central reservation — the one living, saturated thing on a dead road, repeating at a spacing that itself reads as speed. Leaf `#3E5F3C`. |

Supporting palette: asphalt `#4A4741` bleached to `#6E6A62`, faded lane paint `#CFC9B8`,
sand drift `#DDCBA6`, tamarisk `#8A9683`, rusted guardrail `#8A5A3C`, highway sign green
`#1F6B3A`, Hilux white `#F2F2EE`.

---

### Level 4 — GARYOUNIS UNIVERSITY
*17:35 → 18:20. Golden hour raking lengthwise through the two-storey viaducts. This is
the prettiest level in World 1 and it is allowed to know it.*

| | |
|---|---|
| **Sun altitude** | 9° → 4° |
| **Sun azimuth** | 268° W — almost dead down the camera-left axis, so light runs *along* the concrete canyons rather than across them |
| **Colour temp** | 3050 K `#FFB068` → 2400 K `#FF9942` |
| **Key** | energy 1.50, `angular_distance` 1.4 (large, soft, low sun), `shadow_opacity` 0.78 |
| **Fill** | Deep viaduct shade is lit by sky alone. Ambient `#6E86A8` at 0.85 — the coolest fill in the game. Maximum warm-key / cool-shade split; this is the level that proves the lighting model. |
| **Rim** | energy 2.4, `#FFC98A` |
| **Fog** | `#E2B98A`, volumetric density 0.028, anisotropy **0.86**. This is the god-ray level: shafts through every gap between blocks, every viaduct arch, every brise-soleil fin. `use_filter = 0` here for hard shaft edges. |
| **Level-unique colour** | **THE GOLD DOME `#C9A227`** on the central administration block, plus its bounce — the only warm-metal ambient term anywhere in World 1. It is visible from most of the level and it is the level's landmark. |

Supporting palette: board-marked raw concrete `#A8A296` warm / `#8C8C88` shade, bush-hammered
`#B5AFA2`, shattered glazing `#9FB3B8`, sandbag hessian `#9E8D6B`, ficus canopy `#2C4A2E`,
Washingtonia frond `#6B8E4E`.

---

### Level 5 — BENGHAZI
*19:05 dusk → 21:00 night. Corniche at blue hour, the old city after dark, the boss under
floodlight and a high moon.*

| | |
|---|---|
| **Sun altitude** | −4°. A horizon-glow driver only: energy 0.12, `#FF6A3A`, no shadows. It exists to paint the sky and the sea, not the world. |
| **Key (real)** | **Moon.** `DirectionalLight3D`, altitude 52°, azimuth 84°, 8200 K `#C8D8FF`, energy 0.55, `angular_distance` 0.6 (sharp — moon shadows are crisp) |
| **Practicals ARE the level** | Sodium vapour 1900 K `#FFA13B`, OmniLight energy 3.5 range 9.0 — these make hard visible cones through the fog. Shopfront fluorescents 5200 K `#DFF0E8`. Headlights `#FFF0D8`. Wedding-convoy hazards `#FFB020`, flashing. Café glass-front display counters `#EAF6EE`. |
| **Fill** | Ambient `#2A3A56` at 0.55. Never lift it to make things visible — add a practical instead. |
| **Rim** | Cool moon rim 2.0 `#8FB8E8`, plus opportunistic warm sodium rim from whichever practical Wanis is passing. The rim hue changes as he walks. That is the level's best trick. |
| **Fog** | `#1F2C44`, volumetric density 0.035, emission `#0C1220` (so shadowed fog never crushes to black), anisotropy 0.70 |
| **Level-unique colour** | **COPPER PATINA `#5FA391`** — the cathedral's four domes and the still water of 23rd July Lake. The only teal in World 1. The boss arena is lit specifically to make it sing. |

Supporting palette: calcarenite `#E3D9C2`, flaking plaster `#E8C9A0` / `#D9A9A0` / `#BFCBBF`,
cathedral plaster `#F0EBE0`, lagoon `#4E7A70`, Mediterranean `#2E6F93`, arcade shadow `#1B2536`,
wet corniche stone `#6E7A80`.

---

### How the five read as one game

- Ground family never changes; only the light on it does.
- Shadow is warm ochre-violet by day and cool navy by night, and is never neutral grey.
- Every level has exactly one unique hue and they occupy five different hue families:
  green (L1), earth-red (L2), pink (L3), gold (L4), teal (L5). No two compete.
- Aerial perspective is always **warm** — distance goes pale straw-grey, never cool blue.
  This is a Saharan dust load, not temperate haze, and it is the single most
  location-specific lighting fact in the game.
- The horizon sky band is `#D5CDBD` bleached straw in every daytime level and only goes
  blue `#4A7FA8` at high zenith angles.

---

## Shape language & material rules

### Shape language

**World 1 runs from the orthogonal to the arched.** Level 1 is a world of right angles:
prefab concrete panels, pipe racks, bund walls, a Doxiadis grid, everything the same age.
Level 3 is the pivot — pure horizontals, a dead-straight dual carriageway with a median
line. Level 5 is a world of arcs: Italian arcades, barrel vaults, oriels, four copper
domes. Levels 2 and 4 interpolate. A player who cannot articulate it will still feel the
level geometry opening up as World 1 progresses.

Three silhouette registers, and every object belongs to exactly one:

- **SLAB** — flat-topped, hard-edged, repeated at a fixed module. Prefab panels, bund
  walls, Jersey barriers, boundary walls, catwalk decks. This is the gameplay plane's
  native language: **if it is standable, it is a slab.** Non-negotiable readability rule.
- **STACK** — vertical cylinders and shafts. Prilling towers, flare stacks, storage tanks,
  minarets, Horton spheres, palms, lamp posts. Background rhythm and landmarks.
- **DRAPE** — anything that hangs, sags, catches wind. Cable catenaries, laundry lines,
  torn shade cloth, snagged plastic bags, frond skirts, the jard tail. **Every screen
  must contain at least one DRAPE element in motion.** This is the anti-deadness rule.

Forbidden geometry: nothing standable may be round-topped, bevelled more than 2 cm, or
sloped between 12° and 38° (the "am I supposed to stand on this" band). Decorative
geometry has no such restriction and should break the grid constantly.

### Material rules

All values are `StandardMaterial3D` / spatial-shader targets. `metallic_specular` is
**0.30** on every dielectric in the game (the 0.5 default is the plasticky-sheen tell).
**Constant roughness is banned.** Every material carries a low-frequency roughness noise
spanning at least 0.18 in range. Every material carries a detail normal.

| Surface | Albedo | Roughness | Metallic | Rules |
|---|---|---|---|---|
| **Concrete (raw / board-marked)** | `#A8A296` – `#C4BDAE` | 0.68 – 0.88 | 0.0 | World-triplanar, sharpness 5.0, 4 m repeat. Panel joints are *modelled*, 12 mm deep, not textured. Board marking runs one axis only, never both. Slab-edge spalling exposes 2–3 rebars with a rust halo bleeding down. |
| **Plaster / render (painted)** | pastels, §Colour script | 0.55 – 0.78 | 0.0 | Block coursing ghosts through where render is thin. Chalking lifts value +12% and drops saturation −30% on south and west faces only. Bottom 60–90 cm is a darker plinth band or bare cement. |
| **Rust** | fresh `#C1652A` / mid `#8C4A2A` / aged `#5E3220` | 0.72 – 0.92 | 0.35 – 0.6 | Never a uniform tint. Always three values in one patch, always with a **bleed streak running downward** from the source. Heavy section exfoliates in laminated flakes with a 3–5 mm relief. Galvanised goes white-powdery first, then patchy orange. |
| **Sand** | continental `#B5784A` / beach `#EDE6D4` | 0.90 – 0.98 | 0.0 | Two sands, and they *meet*: drift lines where they mix are pink-buff. Sand never lies evenly — leeward piles, doorway fills, buried bottom pipe, wind-carved ripple fields. Vertex-colour mask drives a sand-over-surface blend on every static mesh. |
| **Palm / foliage** | frond `#6B8E4E`, dead eucalyptus `#7D8B6A`, halophyte `#8FA08C` | 0.62 – 0.80 | 0.0 | `DIFFUSE_LAMBERT_WRAP`. `ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE`. `backlight = Color(0.22, 0.26, 0.12)`. Planted species (palm, ficus, casuarina) mark human intervention and only appear in rows or avenues. Wild growth is separated low mounds with bare ground between every plant, never continuous cover. |
| **Glass** | — | 0.06 clean / 0.34 salt-pitted | 0.0 | Mostly *absent*: blown out, boarded, or frosted opaque by sandblasting. Where intact, it is the only place SSR is enabled. Sandblasted glass is a diffuse `#C6CEC8` at roughness 0.6, not transparent. |
| **Cloth** | jard `#EAE0CC`, hessian `#9E8D6B`, shade tarp `#C8BCA0` | 0.78 – 0.92 | 0.0 | `backlight_enabled = true`, `backlight = Color(0.25, 0.22, 0.16)`. Sun-perished cloth frays at load points and fades top-down. Every cloth in the world has wind on it. |
| **Water** | shallow `#4FC3C0`, deep `#1B4F72`, lagoon `#4E7A70` | 0.02 – 0.14 | 0.0 | Gulf of Sidra is *clear and pale over white sand*, then falls off a shelf to lapis. Hard turquoise-to-indigo transition line, not a gradient. Lagoon water is still, brackish, mirror-flat, green. Oil-stained water near the terminal gets an iridescent thin-film term and black waterline staining on concrete. |
| **Chrome / bright metal** | `#D8DCE0` | 0.10 – 0.28 | 1.0 | Almost never clean. Aluminium pipe jacketing is dented, peeling at the bands, showing dirty yellow mineral wool where torn. Chrome exists for exactly three things: the gold chain, the steel tea *alla* set, and car trim. It is a reward, not a texture. |

### Weathering law

Four rules. They apply to every asset in the game and reviewers should reject assets
that break them.

1. **Gravity.** Every stain runs down. Every scupper, AC unit, bolt, bracket, nozzle and
   crack produces a hard-edged vertical streak below it, and the streak is longer than
   you think. A wall without downward streaks is unfinished.
2. **Aspect.** South and west faces are bleached and chalked. North faces, porch
   undersides, window reveals and anything under a canopy retain saturation. That
   differential is the most honest weathering cue available and it is free.
3. **Wind.** Sand ramps into leeward corners and the windward face is scoured — paint
   stripped to bare render from 0 to 1.5 m only, glass frosted, signs scoured on the
   south face only.
4. **Occupancy.** Sand depth on a threshold is a map of abandonment. Swept step = someone
   lives here. Drift over the sill = nobody has come out in years. Use this to author
   which buildings feel alive without a single NPC.

### Forbidden

Reject on sight, no discussion:

- Black shadows. Pure white. Neutral-grey concrete. Cool-blue aerial perspective.
- Brown loam, dark soil, grass, moss, temperate deciduous trees.
- Cobblestone, medina alleys or organic winding lanes anywhere in Brega (it was built
  from prefab parts in one go on a grid — there is no old town).
- Tuk-tuks, rickshaws, camels in a city, snake charmers, keffiyeh-and-agal headdress,
  minarets as the only skyline element.
- A Hilux with a weapon in the bed. The Hilux carries crates, tea urns, a couch, sheep
  before Eid. Never a gun.
- Gaddafi as a visual gag. The green flag as decoration. Alcohol of any kind.
- Rubble as comedy or as scenery. Where destruction appears, something is being rebuilt
  around it — a new café in a half-rebuilt villa is the honest version.
- Arabic rendered as disconnected glyphs, mirrored, stretched non-uniformly, or in a
  faux-Arabic Latin face. Arabic is cursive and RTL; ship a shaping library. Libyan
  signage uses **Western digits** (1234567890), never Eastern Arabic numerals.
- Bilingual street signage. Libya's road and street signage is Arabic-only and sparse.
  Bilingual safety signage *inside the plant* is correct and is the only exception.
- Any surface albedo outside sRGB 50–240, or exceeding the red-sector chroma cap.
- Symmetric decal placement. Constant roughness. Tiling that visibly repeats within one
  screen width.

### Typography, assigned by function

Three scripts, three jobs, never mixed up:

- **Naskh** — official and state. Road signs (green with white Arabic for highway
  direction, blue for service, white-with-red-ring regulatory), plant identification,
  clinic and pharmacy fascias, the `ليبيا` on number plates, Green Book slogans.
- **Kufic** — monumental and institutional. Mosque inscriptions, commemorative plaques,
  university and corporate marks, tile work.
- **Ruq'ah** — the vernacular hand. Hand-painted shop signs, revolutionary graffiti,
  price cards. White or yellow letters on a saturated field with a drop-shadow, paint
  sun-faded and flaking so letters are partly missing.

Number plates: 520 × 110 mm, black on white, `1-12345`, `ليبيا` in Naskh at the right.
White private, yellow commercial, blue public service, red diplomatic.

### The four-layer wall

The single highest-value environmental storytelling asset in the game. It appears in
Levels 1, 2 and 5 and is authored as one shader, not as hand-placed decals. Bottom to top:

1. A field of **regime green** `#1E7A3C`, faded to `#5E8A5C` where the sun hits.
2. A **Green Book slogan** painted over it in white or yellow Naskh.
3. A **crossing-out** in black or red.
4. **2011 revolutionary graffiti** over the top — red-black-green tricolour with star and
   crescent, sprayed fast in Ruq'ah.
5. Sandblasting and UV fade making all four partly legible at once.

---

## The hero: Wanis, the Libyan Gangsta

### Proportions

**5.25 heads tall.** 1.78 m in world units, head 0.339 m. This band keeps face
legibility at gameplay scale (his head is 3.2% of screen height — expression survives),
supports a real wardrobe, and sits clear of both death zones: 3 heads reads as a
licensed toy, 7 heads loses mascot iconicity.

One non-canonical exaggeration and one only: **the sandals and the feet in them are 1.35×
scale.** Everything else is honest. Low centre of gravity — lower leg shortened 6%, weight
carried forward, so landings read as weight and ground contact is never ambiguous.

Shoulder width 1.95 head-widths (exaggerated past life — at gameplay scale a realistic
neck fuses the head to the torso). Waist 1.18 head-widths. Hands 1.15× scale.

### Silhouette

**Three masses, and nothing else is permitted to compete.**

1. **The head mass** — curly black hair, full and rounded, with aviator shades pushed up
   on the forehead reading as a hard horizontal notch across the top third of it. Never
   over the eyes; the audience must read his expression.
2. **The shoulder wedge** — the red jacket, sleeves shoved to the elbow, collar standing.
   The shoulder line is the widest part of him and it is straight, not sloped.
3. **The jard tail** — a 1.1 m cloth tail trailing from the waist sash, breaking the body
   envelope by 40% of body width and moving independently. This is the velocity vector
   and the silhouette-breaker.

Plus the ground read: oversized sandals, 8% of the silhouette, locked to the player's eye
during platforming.

Negative space is mandatory. There is a gap between arm and torso in every idle pose and a
gap between the legs at jump apex. Solid blobs read as props.

Asymmetry, one element: **the left sleeve is rolled higher than the right.** That is the
whole asymmetry budget and it is enough.

### Palette

Applied with TF2's placement rule — dark at the bottom, lighter and higher-chroma at the
chest, so he reads as grounded with a bright centre.

| Zone | Share | Hex | Notes |
|---|---|---|---|
| Jard sash + tank + inner shirt (cream) | 46% | `#EAE0CC` base, `#D8CCB2` shade, `#F4EDDD` sun | Handwoven wool. Slubby weave normal at 3 mm scale. |
| Trousers + sandal straps (dark low block) | 28% | `#2E3A52` denim, `#1F2738` shade | The dark bottom. Never lighten it. |
| Jacket (the accent) | 22% | `#C4392E` base, `#8E2419` shade, `#E0584A` sun | HSV S 0.76 V 0.77. Matte, roughness 0.74. The only large red mass in the game. |
| Gold chain | 4% | `#D9A93C`, spec `#FFE9A8` | Metallic 1.0, roughness 0.18. Highest chroma in the frame, at the chest, where the eye is asked to go. |
| Skin | — | `#A9724B` base, `#7A4A30` shade, SSS transmittance `#C7523A` | |
| Hair + beard | — | `#1B1512`, rim break `#3A2C22` | Four chunky masses, never strands. |
| Sandals (shibshib) | — | `#8A5C3A` leather, `#5E3D24` sole | |

The Sriracha bottle sits at `#F03A16` with emission — hotter, brighter and smaller than the
jacket, so the two never read as the same object. The jacket is matte; the bottle glows.

### Costume, and its grounding

He is not a gangster. He ran the best sandwich cart in Benghazi and his own hot sauce
built it. He dresses like this because presentation is everything and because a man with a
gold chain gets served first. The costume has to carry that, which means it sits exactly
on the seam between two real registers:

**Contemporary street.** Post-2011 Libya has a genuine, documented youth street culture —
graffiti that was unthinkable under Gaddafi, hip-hop that was an act of rebellion to
listen to, and Western daily dress in every Libyan city. Jeans, a tank, a jacket, slides.
That is what a young man in Benghazi actually wears, and building him in permanent
traditional dress would make him a diorama.

**Inherited textile.** The **jard** (جرد) is a single uncut length of handwoven wool,
4–6 m by 1.5 m, historically woven by women on a *masda* over a process that could take a
year, worn across all of Libyan society, and inseparable from Omar al-Mukhtar. Properly
worn it is knotted at a *tukmiya* on the left arm, leaving the right arm free, with the
remainder brought up over the head.

**Wanis's jard is his father's, and he wears it wrong.** Cut down, wrapped twice at the
waist, knotted at the left hip, tail left long and frayed. Every elder in the game
disapproves and at least one says so. That tension is the character — the object is
culturally load-bearing, the way he wears it is entirely his own, and it is the same
object that gives the silhouette its trailing mass. Costume applied last is a costume;
this is applied first.

Explicitly **not** a keffiyeh and agal. That is a Gulf and Levantine signifier and using it
is the clearest possible tell that someone researched "Arab" rather than "Libyan."

No Amazigh motif appears on him. Amazigh geometry has a grammar — motifs are placed at the
body's openings because those are where the evil eye enters — and a diamond on a shoulder
because it looks good is exactly the failure mode. If Amazigh design enters this game it
enters woven into cloth, struck into metal, or not at all.

### Secondary motion

Four systems, ranked. Nothing else moves.

1. **The jard tail — 9-segment Verlet chain**, solved in `_physics_process`, 8 constraint
   iterations, gravity 12.0, damping 0.94, stiffness 0.62, max segment stretch 1.04. It is
   already implemented in the repo and it is the hero's most important asset after the
   silhouette. **Authored override curves on dash, hard landing and wall-kick**, blending
   back to sim over 10 frames. Pure sim on a platformer's instantaneous velocity changes
   is the cheap look; pure hand-key is unaffordable; the blend is the AAA look.
2. **The gold chain — 6-segment Verlet chain**, shorter and stiffer (stiffness 0.80,
   damping 0.88). Deterministic and cheap, so it can never look wrong in a screenshot.
   It swings across the chest on turns and lifts on the dash.
3. **Jacket hem and sleeve cuffs** — 3-bone spring chains driven by chest-bone
   acceleration. Spring 22.0, damping 0.72. This is what sells the weight of a landing.
4. **Hair** — four chunky masses on 2-bone springs, spring 30.0, damping 0.80. No strands.

### Idle personality

He is bored, and being bored is a performance. Three tiers plus a contextual set.

- **Tier 0, continuous** — breathing, 0.28 Hz, with a 2 px chest rise and a shoulder
  counter-drift. Weight shifts between feet every 4.5 s ± 1.2 s.
- **Tier 1, at 7 s** — one of four fidgets, random without repeat: checks the chain and
  lets it drop; re-seats the shades on his forehead; rolls one shoulder; scuffs a sandal.
- **Tier 2, at 19 s** — the personality beat. He looks off-screen at something the player
  cannot see, holds three seconds, and looks back unimpressed. He is waiting for you.
- **Contextual** — at a ledge edge he leans over and looks down. Against a wall he leans
  a shoulder on it. After a long sprint he tugs the sash straight. After taking damage he
  checks the jacket for damage before he checks himself.

Sonic taught impatience in four frames of foot-tap. Wanis's single adjective is
**unbothered**, and Tier 2 has to teach it without a line of dialogue.

### State A — PRISON

Level 1 opens with everything stripped. This is a silhouette problem solved deliberately:
in prison state he has **one mass, not three.**

- Two-piece uniform, washed pale blue-grey `#8E96A0`, shade `#6B727C`, roughness 0.86,
  loose and shapeless so the shoulder wedge is gone. Stencilled in black on the back:
  a Naskh institution mark and five Latin digits.
- No jacket. No chain. No shades. No sash. No tail — **nothing trails, so nothing reads
  as velocity**, and the player feels slow before the controller is ever slowed.
- Hair flattened and dust-matted, so the head mass loses its round silhouette. Beard
  overgrown and unshaped.
- Barefoot, with one broken plastic slide he keeps losing — a recurring gag, and the
  ground contact is deliberately *less* crisp than it will be later.
- Skin carries a dust layer: albedo desaturated 22%, roughness raised to 0.62, a grime
  vertex mask heaviest at the forearms and shins.

He also moves differently. Same feel spec numbers — the controller does not change — but
the animation layer runs a posture offset: spine flexed 6°, head dropped 4°, arms held
closer, stride shortened 8%. Same physics, read as diminished.

### The transformation

**The confiscated-property cage, at the exact moment the sun clears the horizon.** It is
the level's unforgettable moment and it is the mechanic unlock in the same beat: Chain
Whip is what he gets back.

Beat by beat, at 60 fps:

| Frame | Beat |
|---|---|
| 0–12 | He reaches the cage. Camera pushes in, FOV 34 → 29. Volumetric density lifts 0.016 → 0.030. |
| 12 | He rips the mesh. Hit-stop 5 frames. Camera trauma 0.35. |
| 17–34 | **The sun clears the horizon.** Key energy ramps 0.35 → 1.45 over 17 frames, temp 1950 K → 2850 K. This is scripted, not ambient — the level has been waiting for this. |
| 22 | Chain out of the cage first. It arcs, catches the new sun, and the gold hits `#FFE9A8` at emission 3.0 — the first specular highlight in the game. Glow picks it up. |
| 26–38 | Jacket. Authored, not simulated: it snaps onto the shoulder line in 12 frames and the shoulder wedge returns. Dust burst, 140 particles, `#D8CCB2`, lifetime 0.9. |
| 34–46 | The jard. The tail unfurls to full 1.1 m over 12 frames on an authored curve, then hands to the Verlet sim with a 10-frame blend. This is the silhouette completing. |
| 40 | Shades up to the forehead. One frame. No ceremony. |
| 44–52 | The dust layer wipes off the skin — a dissolve-front on the grime mask, driven by triplanar world coords so it reads coherently across the whole body. |
| 52–64 | He rolls the left sleeve. Posture offset releases: spine to 0°, head to 0°, stride to 100%. |
| 64 | Control returns. HEAT gauge and Chain Whip appear in the HUD for the first time. |

The audio beat lands at frame 22 with the chain — a single darbuka hit, and the level's
music enters on the next bar. Nothing on screen is allowed to be brighter than that chain
between frames 22 and 26.

**Test:** reduce frames 0 and 64 to pure black at 25% scale. Frame 0 must be an
unidentifiable single mass. Frame 64 must be unmistakably Wanis. If both are true, the
transformation works.

---

## Depth-layer recipe

Camera is at **Z = +16** with **FOV 34°**, per `DESIGN.md` Part IV. That is fixed —
it is tuned into the controller and camera code. `near` is raised to **0.5** (from the
0.05 default) for roughly 10× depth-buffer precision; nothing in a side-scroller is ever
within 0.5 m of the camera. `far = 1200`. `keep_aspect = KEEP_HEIGHT`.

Visible vertical extent at the gameplay plane = 2 × 16 × tan(17°) = **9.78 units**, so a
1.78 m Wanis is **18.2% of screen height**. That is correct framing and every layer below
is sized against it.

Parallax is free and physically correct: a layer at distance *d* from the camera moves at
16/*d* of the gameplay layer's screen rate, in X and Y, under zoom, and under
`frustum_offset`. **No `Parallax2D`, no `ParallaxBackground`, ever.**

| # | Layer | Z | Dist | Parallax | Cull bit | Contents |
|---|---|---|---|---|---|---|
| 8 | **Foreground occluder** | +9 | 7 | 2.29× | 5 | Near-black at 24% alpha, heavy near-DOF. Razor-wire coils, a dead casuarina trunk, a pipe-rack leg, an arcade column, a palm bole. Clips one or two frame edges. `proximity_fade_distance = 1.0`. |
| 7 | **Foreground frame** | +5 | 11 | 1.45× | 5 | Readable but desaturated 40%. Chain-link mesh, a parapet lip, oleander mass, a parked Hilux rear quarter. Never crosses the horizontal band the player traverses. |
| 6 | **Gameplay plane** | **0** (props −1.2 … +1.2) | 16 | 1.00× | 1 | Everything standable, everything collectible, every enemy and hazard. Full PBR, world-triplanar, highest contrast, sharpest, lit by its own key. **Nothing else is ever at Z = 0.** |
| 5 | **Near background** | −5 | 21 | 0.76× | 2 | The wall behind the action — prison slab facade, villa boundary wall, arcade back wall, viaduct underside. Full materials, slight aerial fade, saturation −12%. This is where the four-layer wall lives. |
| 4 | **Mid background** | −14 | 30 | 0.53× | 2 | The next street, the second row of tanks, the campus block opposite, the far carriageway. Simplified materials (no heightmap, no triplanar), saturation −24%, fog-tinted. |
| 3 | **Deep background** | −34 | 50 | 0.32× | 3 | Tank farm, villa grid, the campus mass, the lagoon. Silhouette-driven. Saturation −35%. `lod_bias = 2.5`. No shadow casting. |
| 2 | **Far landscape** | −90 | 106 | 0.15× | 3 | Sabkha plain, the sea, the Jebel line, the industrial complex entire. Far-DOF. Heavy aerial perspective toward the fog colour. Single-material, no normal maps. |
| 1 | **Horizon skyline** | −260 | 276 | 0.058× | 4 | The prilling towers, the flare stack, the cathedral domes, the Tibesti tower. Near-flat, 70% blended to fog. These are landmarks and they must be visible from most of their level. |
| 0 | **Sky dome + atmosphere** | −900 | 916 | 0.017× | 4 | Custom sky shader: gradient ramp, dust band, sun disc, procedural cloud noise. Plus one drifting smoke or dust plume plane. Parallax 0.017× reads as effectively infinite. |

**Every screen must carry content in at least six of the nine layers.** A screen with only
gameplay + near BG + sky is a greybox, regardless of how good the materials are.

Between-layer atmosphere: `GPUParticles3D` dust planes at Z = +3, −9 and −22, drifting on
the ghibli axis. `local_coords = false`. `visibility_aabb` set explicitly to
`AABB(Vector3(-36,-24,-12), Vector3(72,48,24))` — the 8-unit default makes particles vanish
mid-effect in a scrolling camera and it is the single most common particle bug in the genre.

Light rigs are per-layer via `light_cull_mask`: the gameplay plane's key runs at 1.30×
the background key's energy, giving figure-ground separation no post-process can fake.

A negative-density `FogVolume` ellipsoid, `size = Vector3(13, 9, 9)`, `density = -2.0`,
parented to the camera, carves a clear pocket so Wanis never hazes out while the
background stays atmospheric. This is strictly better than globally lowering fog.

---

## Godot implementation notes

Godot 4.7.2, Forward+. Property names are exact.

### `project.godot` — the diff against what is in the repo now

```ini
[rendering]
; AA: FXAA on top of MSAA throws away MSAA's sharpness. Pick crisp.
anti_aliasing/quality/msaa_3d=2                          ; keep 4x
anti_aliasing/quality/screen_space_aa=0                  ; WAS 1 (FXAA) — remove
anti_aliasing/quality/use_debanding=true                 ; WAS absent (false). Mandatory:
                                                         ; our skies and fog are huge gradients
anti_aliasing/screen_space_roughness_limiter/amount=0.4

; 4.7 features currently unused
lights_and_shadows/contact_shadow/enabled=true           ; grounds his feet — #1 readability cue
lights_and_shadows/contact_shadow/shadow_length=1
lights_and_shadows/contact_shadow/surface_thickness=0.01
lights_and_shadows/multi_bounce_occlusion/enabled=true   ; AO picks up surrounding albedo
                                                         ; instead of going grey-dirt

global_illumination/gi/use_half_resolution=false         ; WAS true — blobby, stair-stepped GI
global_illumination/voxel_gi/quality=1

environment/ssao/half_size=false                         ; WAS absent (true) — chunky at 1080p
environment/ssil/half_size=false
environment/ssil/quality=2                               ; WAS 1

environment/subsurface_scattering/subsurface_scattering_quality=3   ; WAS 2
environment/subsurface_scattering/subsurface_scattering_scale=0.025 ; WAS default 0.05, which
                                                         ; bleeds scatter across his whole face

camera/depth_of_field/depth_of_field_bokeh_quality=2     ; WAS 1
camera/depth_of_field/depth_of_field_bokeh_shape=2       ; circle, WAS hexagon
camera/depth_of_field/depth_of_field_use_jitter=true     ; kills bokeh banding

textures/default_filters/anisotropic_filtering_level=4   ; 16x, WAS 3 (8x)
```

### GI strategy: VoxelGI chained on X. Not SDFGI, not lightmaps.

**`LightmapGI` exposes zero methods to scripting.** `bake()` is not in the scripting API
at all, in any build. This project is headless and code-authored, so lightmaps are
impossible without a custom engine build. Do not plan around them.

**SDFGI is wrong for this game.** It is camera-centred and streams cascades as the camera
moves. Our camera moves fast in X, constantly, forever. `frames_to_converge = 5` means
30 frames — half a second — of visibly dark newly-streamed geometry, continuously.

**`VoxelGI.bake(from_node, create_visual_debug)` IS exposed and works in exported
projects.** That is the unlock. Bake at level load from `LevelKit`.

```
VoxelGI.size          = Vector3(32, 24, 24)
VoxelGI.subdiv        = SUBDIV_128       # ≈0.25 u/voxel at this size
spacing               = 28 units on X    # 4 units of overlap
VoxelGIData.energy    = 1.2
VoxelGIData.propagation = 0.65           # outdoors; 0.50 in the prison interiors
VoxelGIData.dynamic_range = 4.0          # high-contrast sun
VoxelGIData.normal_bias = 0.2            # only if striping appears
VoxelGIData.interior  = true             # prison interiors — kills sky leak
VoxelGIData.use_two_bounces = true
```

**Hard limit: 8 VoxelGI nodes render at once and only 2 blend per pixel.** Overlapping 3+
flickers. Generate one volume per 28 X-units and enable/disable by camera proximity so at
most 3 are active and at most 2 overlap anywhere.

Geometry must be `gi_mode = GI_MODE_STATIC` to bake. **Wanis, enemies and any moving prop
must be `GI_MODE_DYNAMIC`** or they bake in and leave ghost lighting behind them.

**Procedural vertex-colour AO is the lightmap substitute.** We generate geometry in code,
so run a hemisphere raycast occlusion pass at build time — 48 rays per vertex — and write
it to `ArrayMesh` `ARRAY_COLOR`. Read `COLOR.r` in the shader as a diffuse multiplier, not
via `vertex_color_use_as_albedo`, so it darkens without tinting. Cache to disk keyed by a
level hash. This is what makes a code-generated scene read as expensive at zero runtime cost.

Reflection probes chain the same way: `size = Vector3(40, 28, 30)`, spacing 30 on X,
`blend_distance = 5.0` (the 1.0 default pops hard), `update_mode = UPDATE_ONCE` (captures
over 6 frames at runtime — no editor needed), `box_projection = true` in corridors and
`false` in open desert, `interior = true` and `enable_shadows = true` on the one or two
hero interior probes. At most **one** `UPDATE_ALWAYS` probe in the entire project, and
probably zero.

### Environment

The default combination of `background_mode = BG_CLEAR_COLOR` + `ambient_light_source =
AMBIENT_SOURCE_BG` + black clear colour means **ambient light is literally black.** That
one default is responsible for most "why does my Godot scene look dead" scenes ever made.

```
background_mode         = BG_SKY
ambient_light_source    = AMBIENT_SOURCE_SKY
reflected_light_source  = REFLECTION_SOURCE_SKY
ambient_light_sky_contribution = 1.0
ambient_light_energy    = per level, §Colour script

tonemap_mode            = TONE_MAPPER_AGX
tonemap_exposure        = 1.0            # grade with lights, never with exposure
tonemap_agx_white       = 9.5            # 16.29 default is flat
tonemap_agx_contrast    = 1.45           # AgX-internal contrast: pre-display-encode,
                                         # no gamut clipping. This is why AgX over ACES —
                                         # ACES desaturates our brights and kills the jacket.
adjustment_enabled      = true
adjustment_saturation   = 1.15           # recover what AgX pulls out of highlights
adjustment_contrast     = 1.0            # leave — use tonemap_agx_contrast instead
adjustment_color_correction = <Texture3D LUT, generated per level>
```

`tonemap_white` is **ignored** under AgX. Build the LUT procedurally in GDScript: 32
`Image`s of 32×32 `FORMAT_RGB8`, lift/gamma/gain + split-tone + per-hue saturation math
per texel, then `ImageTexture3D.create()`. One generator, one parameter set per level,
zero external assets, and every level gets a distinct identity. Author assuming
post-tonemap sRGB input — the pipeline order is tonemap → brightness/contrast/saturation → LUT.

Sky is a custom `ShaderMaterial`, not `ProceduralSkyMaterial`: gradient ramp, a bleached
straw dust band at the horizon that is thicker than any temperate sky would have, a sun
disc, and low-frequency cloud noise. The horizon band is the most location-specific
lighting decision in the project.

### The sun

```
light_angular_distance          = 0.8 – 1.4    # DEFAULT IS 0.0 — razor shadows at all
                                               # distances, the clearest CG tell there is.
                                               # Real sun ≈ 0.53°; we go softer for style.
shadow_enabled                  = true         # default is FALSE, easy to forget
shadow_bias                     = 0.03
shadow_normal_bias              = 0.8          # default 2.0 detaches small props' shadows
shadow_opacity                  = 0.78 – 0.90  # per level; lets ambient lift the shadow
directional_shadow_mode         = SHADOW_PARALLEL_4_SPLITS
directional_shadow_max_distance = 50           # NOT 100. Near-doubles texel density free.
                                               # 70 on Level 3 only, for the road.
directional_shadow_split_1/2/3  = 0.06 / 0.15 / 0.35
directional_shadow_blend_splits = true
light_indirect_energy           = 1.3
light_volumetric_fog_energy     = 2.0 – 3.5    # god rays live here
```

Fill lights get `light_volumetric_fog_energy = 0.0`. If fills feed the fog, the fog turns
into flat grey soup. Rim light is character-cull-mask-only,
`shadow_enabled = false` except on Levels 4 and 5 where SSS transmittance needs it.

Use `light_negative = true` omnis to sculpt darkness back into over-lit corners. It is a
standard film trick and Godot supports it natively.

`AreaLight3D` (new in 4.7) for prison strip lights, shopfront glass counters and window
light slabs. Emits along −Z. `area_attenuation = 2.0` for physically-accurate falloff,
`area_normalize_energy = true`, `light_size = 0.5` for PCSS softness. **Budget 1–3 per
scene** — clustered lighting means an AreaLight in the frustum costs on every rendered
object.

### Volumetric fog

```
volumetric_fog_enabled  = true
volumetric_fog_density  = per level, 0.006 – 0.055
volumetric_fog_albedo   = Color(1.00, 0.93, 0.82)   # tint to the dust, never pure white
volumetric_fog_emission = Color(0.06, 0.045, 0.035) # lifts fog out of black in shadow
volumetric_fog_anisotropy = 0.55 – 0.86             # ★ THE GOD-RAY KNOB. The 0.2 default
                                                    # means no shaft will ever form.
volumetric_fog_length   = 95
volumetric_fog_detail_spread = 1.6
volumetric_fog_gi_inject = 0.45
volumetric_fog_ambient_inject = 0.25
volumetric_fog_sky_affect = 0.0                     # crisp sky, fog only in the world
volumetric_fog_temporal_reprojection_amount = 0.68  ; ★ SIDE-SCROLLER CRITICAL. The 0.9
                                                    ; default blends 90% of last frame and
                                                    ; smears fog trails behind everything
                                                    ; when the world slides sideways.
```

Project `environment/volumetric_fog/use_filter`: **0 on Level 4** (hard god-ray shafts),
1 everywhere else (soft ambient dust). Volumetric fog has finite range, so always pair it
with non-volumetric depth fog for the far layers.

`FogVolume` uses: `CONE` aligned to a window spot for prison dust shafts (`density 1.5`,
`edge_fade 0.45`, 64³ `NoiseTexture3D` density texture, translated 0.15 u/s along the
shaft); `BOX` for ground mist (`height_falloff 1.2`); `ELLIPSOID` with negative density
for the hero pocket. `FogMaterial.emission` does not cast light on anything — it only
makes the fog itself glow.

### Glow

```
glow_enabled           = true
glow_blend_mode        = GLOW_BLEND_MODE_SCREEN      # ADDITIVE is the washout machine
glow_bloom             = 0.0    ; ★ KEEP AT ZERO. Above zero it lifts EVERYTHING into the
                                ; glow buffer regardless of threshold. #1 cause of washout.
glow_hdr_threshold     = 1.22
glow_hdr_scale         = 2.5
glow_hdr_luminance_cap = 5.0    ; ★ 12.0 default lets one blown sun pixel flood the frame
glow_intensity         = 0.55
glow_normalized        = true
glow_levels/1          = 0.0    ; ★ levels 1–2 are the tight halo beside every bright edge.
glow_levels/2          = 0.0    ;   That halo IS the cheap-bloom signature. Zero them.
glow_levels/3          = 0.3
glow_levels/4          = 0.7
glow_levels/5          = 1.0    ; the wide cinematic halo lives in 4–6
glow_levels/6          = 0.6
glow_levels/7          = 0.2
```

Control *what* glows with material `emission_energy_multiplier > 1.0`, never by lowering
the threshold. Use `glow_map` to suppress glow in the lower sixth of the frame where the
HUD lives.

### Screen space

```
ssao_enabled      = true
ssao_radius       = 1.0        # correct at 1.78 m hero scale
ssao_intensity    = 1.3        # 2.0 default is heavy-handed
ssao_power        = 2.0
ssao_horizon      = 0.10       # 0.06 default halos around silhouettes
ssao_light_affect = 0.1        # small amount stops AO reading as painted-on dirt

ssil_enabled      = true
ssil_radius       = 2.2        # ★ 5.0 default bleeds the whole background onto Wanis
ssil_intensity    = 0.75

ssr_enabled       = true       # wet corniche stone, intact glass, chrome, lagoon ONLY
ssr_max_steps     = 48
ssr_depth_tolerance = 0.2
```

### Camera

```
projection      = PROJECTION_PERSPECTIVE
fov             = 34.0
near            = 0.5          # WAS 0.05. ~10x depth precision. Cheapest quality win here.
far             = 1200.0
keep_aspect     = KEEP_HEIGHT

CameraAttributesPractical:
  dof_blur_far_enabled     = true
  dof_blur_far_distance    = 38.0      # just past the mid background
  dof_blur_far_transition  = 26.0
  dof_blur_near_enabled    = true
  dof_blur_near_distance   = 10.0
  dof_blur_near_transition = 5.0
  dof_blur_amount          = 0.10
```

For camera lead and off-centre framing, use `PROJECTION_FRUSTUM` with
`frustum_offset = Vector2(±0.05 … ±0.28, ±0.10)` driven by facing and velocity. This shifts
the *projection*, not the camera, so verticals stay vertical and background parallax stays
stable. Panning the camera transform instead introduces perspective rotation that makes
backgrounds swim. **Never orthographic** — zero inter-layer parallax turns every
background into a sticker.

### Materials

`metallic_specular = 0.30` on all dielectrics. `roughness` never constant. Detail normals
from `NoiseTexture2D` + `FastNoiseLite(TYPE_SIMPLEX_SMOOTH, octaves 5, frequency 0.02)`,
`seamless = true`, `as_normal_map = true`, `bump_strength` 8–16 stone, 2–4 painted metal,
with `uv2_scale = Vector3(12,12,12)`.

World-triplanar on gameplay-plane and near-BG geometry: `uv1_triplanar = true`,
`uv1_world_triplanar = true`, `uv1_triplanar_sharpness = 5.0`, `uv1_scale = 0.25`
(4 m repeat). This kills the "tiled prototype blocks" read on code-generated geometry.
Regular UV on layers 3 and below — triplanar is 3 samples per map.

`heightmap_scale = 0.05` where used. **The 5.0 default is 60–250× too large.**
`distance_fade_mode = DISTANCE_FADE_PIXEL_DITHER`, not alpha — better performance, no
transparency sorting. `proximity_fade_enabled = true` on every fog card, particle quad,
water edge and foreground silhouette element.

Decals carry the storytelling: rust runs, water stains, cracks, tyre marks, Arabic
signage, graffiti. `size = Vector3(2.0, 2.0, 0.6)` — thin on the projection axis so they
don't wrap corners. `normal_fade = 0.6`. `distance_fade_enabled = true, begin = 40`. For
grime that adds only roughness and normal, keep an albedo texture for alpha masking but
set `albedo_mix = 0.0` and supply `texture_orm`. **Decals cannot affect transparency.**

### Wanis's shading

```
subsurf_scatter_enabled               = true
subsurf_scatter_strength              = 0.26        # NOT 1.0 — that's the waxy mannequin
subsurf_scatter_skin_mode             = true        # switches to the red-shifted skin kernel
subsurf_scatter_texture               = <mask: thick at cheeks/nose, thin at brow/jaw>
subsurf_scatter_transmittance_enabled = true
subsurf_scatter_transmittance_color   = Color(0.78, 0.30, 0.22)
subsurf_scatter_transmittance_depth   = 0.10
subsurf_scatter_transmittance_boost   = 0.25
```

Transmittance is computed from the shadow map, so it needs a light *behind* him with
shadows enabled. Watch for godot#123422 (crash enabling transmittance + SSS on a
`BaseMaterial3D`); if it bites, fall back to a custom spatial shader writing
`SSS_STRENGTH` / `SSS_TRANSMITTANCE_*` directly.

Skin roughness is never uniform: 0.32 forehead and nose bridge, 0.52 cheeks, 0.68 near the
hairline. Eyes get a separate cornea mesh with `clearcoat_enabled = true`, `clearcoat = 1.0`,
`clearcoat_roughness = 0.03` — 4.7 fixed clearcoat energy conservation, so it is finally
trustworthy, and eyes are the single biggest AAA-versus-hobby tell. Hair uses
`anisotropy_enabled = true` with a flowmap. Jacket and jard use `backlight_enabled = true`.

**`extra_cull_margin = 0.8` on every skinned mesh.** Skinned AABBs are computed from the
rest pose, so an animated character pops out of existence at screen edges when a limb
extends. In a side-scroller that happens exactly when the hero enters frame — constantly.

### Shaders to write

Ranked by impact. Seven exist or are half-built; the rest are new.

1. `surface_weathered.gdshader` *(exists — extend)* — triplanar PBR base + vertex-colour
   AO + grime mask + sand-drift blend. The workhorse. Every static surface uses it.
2. `wall_archaeology.gdshader` **(new, highest value)** — the four-layer wall as one
   shader: regime green, slogan, crossing-out, tricolour, differential UV fade, sandblast
   scour band at 0–1.5 m. Parameterised so one shader authors hundreds of unique walls.
3. `hero_rim.gdshader` **(new)** — Fresnel rim with a **directional gate**:
   `smoothstep(0.0, 0.3, dot(NORMAL, -rim_dir))`. Without the gate it is a uniform glow
   outline and reads as a sticker. `rim_power` 3.2, `rim_energy` 0.6–2.0. Do not rely on
   `BaseMaterial3D.rim` — it is light-coupled and `rim_tint` mushes it toward albedo.
4. `sky_libya.gdshader` **(new)** — gradient ramp, straw dust band, sun disc, cloud noise.
   Per-level parameter set. The colour script lives here.
5. `heat_haze.gdshader` **(new, Level 3)** — screen-texture UV offset from scrolling noise,
   `strength` 0.016, masked to `1.0 - UV.y` so it's strongest at the road. Sample the depth
   texture to reject pixels in front of the shimmer plane so Wanis never wobbles.
6. `cloth_billow.gdshader` *(exists — extend)* — jard, laundry, shade tarps, flags.
7. `foliage_wind.gdshader` **(new)** — world-position phase so instances desync,
   `INSTANCE_CUSTOM.x` for per-instance offset, vertex-colour masks (red = trunk-to-tip,
   green = tip flutter). `wind_strength` 0.05 grass → 0.25 palm frond.
8. `sriracha_glass.gdshader` **(new)** — the collectible. Thin-walled glass, red fluid
   inside, emissive at `#F03A16`, gentle spin, catches the key.
9. `iced_out.gdshader` **(new)** — diamond dispersion. Do **not** use `TRANSPARENCY_ALPHA`;
   gem sorting is a nightmare. Fake it opaquely: screen-texture lookup with per-channel
   chromatic offset (`r × 0.98`, `g × 1.00`, `b × 1.02`), a second perturbed lookup for
   fake internal facets, and `EMISSION += step(0.96, sparkle) * color * 12.0` so it blows
   past the glow threshold. Pair with tiny additive `GPUParticles3D` twinkles that survive
   outside the silhouette.
10. `water_sidra.gdshader` **(new)** — depth-driven turquoise-to-indigo with a hard shelf
    line, caustics on the shallow floor, and a thin-film iridescence term near the terminal.
11. `dissolve.gdshader` **(new)** — triplanar world-coord noise front, emissive edge at
    `vec3(3.0, 1.2, 0.2)` so it blooms. Used for the transformation grime wipe, enemy
    defeats, and warp-ins.
12. `rust_bleed.gdshader` **(new, decal)** — a parameterised downward streak that takes a
    source point and a length. Placed procedurally under every bolt, bracket and scupper.

### Particles

`transform_format = TRANSFORM_3D` must be set **before** `instance_count` on every
`MultiMesh`. `use_custom_data = true` and pack `(wind_phase, scale_variation, colour_seed,
time_offset)` into `INSTANCE_CUSTOM` so 5,000 fronds don't sway in lockstep. Set
`custom_aabb` explicitly or Godot computes one so large it never culls.

**MultiMesh has no per-instance frustum culling** — "millions of objects will be always or
never drawn." Chunk every MultiMesh at 32 X-units and toggle `visible` from camera
position. `cast_shadow = SHADOW_CASTING_SETTING_OFF` on all background debris and foliage
multimeshes.

Procedural `ArrayMesh` has **no LODs and no tangents.** Call
`SurfaceTool.generate_tangents()` or normal maps are silently wrong. Build through
`ImporterMesh` and call `generate_lods(25.0, 60.0, [])` at build time, cached — it is the
only way `lod_bias` does anything for code-generated geometry.

`GPUParticles3D`: `fixed_fps = 30` + `interpolate = true` for dust (halves sim cost);
`fixed_fps = 0` for sparks and impact debris or you see stepping. `amount_ratio` scales
density at runtime for free — changing `amount` reallocates and restarts the system.
`collision_base_size` raised to roughly match particle size.
`GPUParticlesCollisionHeightField3D` with `UPDATE_MODE_ALWAYS` follows the camera and bakes
at runtime, which is the only collision option available to a headless pipeline —
`GPUParticlesCollisionSDF3D` needs an editor bake.

### Pitfall list — check these first when something looks cheap

1. Ambient light is black (`BG_CLEAR_COLOR` + `AMBIENT_SOURCE_BG` + black clear colour).
2. `tonemap_mode = LINEAR` with `tonemap_white = 1.0`. Both defaults. Clipped and flat.
3. The editor's preview sun and preview sky **do not exist at runtime**. A scene that
   looks fine in a viewport renders black in a capture.
4. `Camera3D.near = 0.05` — z-fighting, poor SSAO/SSR/contact shadows.
5. `light_angular_distance = 0.0` — razor shadow edges at every distance.
6. `shadow_enabled = false` is the `Light3D` default.
7. `shadow_normal_bias = 2.0` default detaches small props' shadows (peter-panning).
8. `glow_bloom > 0.0` — guaranteed washout.
9. `glow_levels/1` and `/2` carrying energy — the cheap-bloom halo.
10. `ssil_radius = 5.0` default bleeds the background onto the hero.
11. `volumetric_fog_anisotropy = 0.2` default — no god ray will ever form.
12. `volumetric_fog_temporal_reprojection_amount = 0.9` — smeared fog trails under
    horizontal scroll.
13. `GPUParticles3D.visibility_aabb` 8-unit default — particles vanish mid-effect.
14. MSAA does not antialias alpha-scissor foliage. Set
    `ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE`.
15. `gi_mode = GI_MODE_STATIC` on moving objects — baked in, leaves ghosts.
16. `extra_cull_margin = 0.0` on skinned meshes — hero pops at screen edges.
17. `vertex_color_is_srgb = false` default — code-authored hex vertex colours blow out.
18. Constant roughness. Nothing else on this list matters if this one is true.

---

## Level 1 beauty benchmark shot

### **"FIRST LIGHT, EXERCISE YARD"**

One screen. Built at final shippable quality before any more of Level 1 exists. This is a
build order, not a mood board — every number is buildable as written.

**The moment.** Wanis, still in prison grey, has come through the block door onto the
raised walkway above the exercise yard. The sun is two minutes from clearing the horizon
behind the dead fertiliser plant. He is not running yet. He has stopped, because he can
see the way out and it is a long way off.

### Composition

16:9, 1920×1080. Horizon at **y = 0.46**. Wanis's feet at **y = 0.62**, his head at
**y = 0.44** — his head breaks the horizon line, which is what makes a small figure read
as the subject. He stands at **x = 0.31**, facing screen-right, so two-thirds of the frame
is the distance he has to cover. He is **18.2%** of frame height.

The frame's structural lines: the walkway rail runs a hard horizontal at y = 0.66 from
x = 0.00 to x = 0.44 and then stops at a broken post — the eye falls off the end of it
into the yard. The pipe rack enters at upper-right and runs down-left on a 14° diagonal,
pointing at him. The two prilling towers stand at x = 0.71 and x = 0.79, the flare stack at
x = 0.90. Rule-of-thirds intersection at (0.33, 0.33) is empty sky, deliberately — the
composition breathes there.

### Layer by layer

**Layer 8 — Foreground occluder, Z = +9.** A single coil of razor wire, out of focus,
crossing the top-left corner from (0.00, 0.00) to (0.19, 0.22). Near-black, 24% alpha,
heavy near-DOF. It reads as a shape, not as wire. One dead casuarina trunk at the extreme
bottom-right, x = 0.94–1.00, rising the full frame height, silvered bone-white, so the
right edge is closed.

**Layer 7 — Foreground frame, Z = +5.** Chain-link fence, 50 mm mesh, running the bottom
edge from x = 0.00 to x = 0.38, top of the mesh at y = 0.78 so it never crosses his body.
Sand drifted into its base. Three plastic bags snagged in it, moving. Desaturated 40%.

**Layer 6 — Gameplay plane, Z = 0.** The walkway: a precast concrete deck, 1.2 m wide,
with a 90 mm steel rail on the outboard side, three balusters missing. Wanis on it. The
deck's leading 40 cm is spalled, exposing two rebars, orange-brown, with a rust halo
bleeding down the underside. A green-painted steel door, `#2F5D46`, standing half open
behind him at x = 0.16 — the door he just came through, and it is the only saturated
non-hero colour in the left third. A puddle of sand has drifted across the threshold of it,
and there is a clean swept arc where the door swung. Two sriracha bottles on the deck ahead
of him at x = 0.48 and x = 0.55, glowing, starting the trail.

**Layer 5 — Near background, Z = −5.** The cell block's long facade, running the full frame
width behind him. **This is the four-layer wall.** Prefab beige slabs, `#D8CEB6`, 3.0 m ×
1.2 m module, joint lines 12 mm deep, **one circular crane hole at the centre of every
panel** — most mortared shut, three visibly knocked through. Panel joints carry the water
staining and the rust bleed. The bottom 50 cm is fretted back to blockwork by salt. Small
deep-set windows on a 3.0 m rhythm, half with bent louvred shutters in faded `#6B4A32`, one
hanging off a single hinge. One window head is fan-blackened by an old fire. Across three
panels at x = 0.55–0.78: the regime-green field `#2E7A3F`, a Green Book slogan in white
Naskh over it, a black crossing-out over that, and a red-black-green tricolour with star
and crescent sprayed over all of it, all four sun-faded together. Sandbags on the roof
parapet, split and spilling.

**Layer 4 — Mid background, Z = −14.** The yard floor, cracked concrete going to sabkha
crust, `#E8E2D2`, polygonally cracked and blistered, with tyre ruts cutting through to dark
mud `#5C5040`. The second block opposite, its own crane-hole grid, partly hidden by the
first. A perimeter wall, `#B4AEA2`, 4.5 m, razor wire on top, running to the right edge. A
dead eucalyptus windbreak row — seven trunks in a dead-straight planted line, four of them
silvered and leafless, three with sparse `#7D8B6A` foliage. Sand drifted over the line.

**Layer 3 — Deep background, Z = −34.** The tank farm. Six storage tanks, 42 m diameter,
chalked cream `#E4E0D4` going `#BFB7A4` in the chalked zones, vertical rust bleed from
every ladder bracket, the bottom metre exfoliating orange. Spiral staircases wrap two of
them. Each sits in a pale rubble bund wall a third its height. One tank is burnt: scorched
matte black-brown above the fire line, roof collapsed inward, steel heat-warped in soft
vertical buckles. That tank is the one at the golden-section point.

**Layer 2 — Far landscape, Z = −90.** The sabkha plain running flat to the horizon,
blinding pale, with the pipe-rack corridor crossing it on concrete sleepers. The Gulf of
Sidra visible as a thin turquoise band `#4FC3C0` in the upper-right gap between the towers,
falling to `#1B4F72`. No cliffs, no hills — this coast is dead flat and that flatness is
the point.

**Layer 1 — Horizon skyline, Z = −260.** The two urea prilling towers, 62 m and 71 m, plain
windowless concrete shafts, vertically streaked, 70% blended to fog. The flare stack beside
them: a cold black steel lattice with nothing burning on it. **That dead flare stack is the
most eloquent object in the shot** — it says the plant stopped, the town emptied, and
nobody is coming.

**Layer 0 — Sky, Z = −900.** Pre-dawn gradient: zenith `#2B3A55`, mid `#6B5F6E`, horizon
band `#C97B45` warming to `#FFA657` at the sun point behind the towers. The bleached straw
dust band `#D5CDBD` sits above the horizon glow, thick — this is Saharan aerosol, and it is
thicker than any temperate sky would be. A high thin cloud deck catching the first light.

### Lighting

| Light | Setup |
|---|---|
| **Key** | `DirectionalLight3D`. Altitude **3.5°**, azimuth **101°** — behind and screen-right. 2200 K `#FF9040`, `light_energy` 0.85, `light_angular_distance` 1.1, `shadow_enabled` true, `shadow_bias` 0.03, `shadow_normal_bias` 0.8, `shadow_opacity` 0.82, `directional_shadow_max_distance` 50, splits 0.06/0.15/0.35, `blend_splits` true, `light_volumetric_fog_energy` 3.2, `light_indirect_energy` 1.3. Shadows rake nearly the full width of the frame to the left. |
| **Fill** | `DirectionalLight3D`, altitude −18° (from below-front, the sabkha bounce), `#B8B0A0`, `light_energy` 0.34, `shadow_enabled` false, `light_volumetric_fog_energy` 0.0. This is what stops the shadow side going dead. |
| **Sky ambient** | `AMBIENT_SOURCE_SKY`, `ambient_light_energy` 0.92. Pre-dawn sky is a huge cool source and it is doing real work on every up-facing surface. |
| **Rim** | `DirectionalLight3D`, `light_cull_mask` = character bit only. From behind-right, `#FFB877`, `light_energy` 2.6, `light_specular` 0.3, `shadow_enabled` false. He is back-lit and near-silhouette; this rim is the only reason he reads at all, and it is the shot's thesis. |
| **Practical 1** | `AreaLight3D` inside the open green door, `area_size = Vector2(0.9, 2.05)`, 3100 K `#FFB877`, energy 2.2, `area_range` 4.5. A failing corridor strip light behind him. It puts a warm slab on the deck and edges his left shoulder. |
| **Practical 2** | `OmniLight3D` sodium `#FFA13B` on a lattice pole at Z = −14, x = 0.86, energy 3.0, range 11. Still burning at dawn because nobody turned it off. It throws a hard cone through the fog. |
| **Negative** | `OmniLight3D`, `light_negative = true`, energy 0.6, range 6, placed under the walkway to sink the deck's underside into proper dark. |

### Atmosphere

- Volumetric fog: density **0.016**, albedo `Color(1.00, 0.93, 0.82)`, emission
  `Color(0.06, 0.045, 0.035)`, **anisotropy 0.78**, `length` 95,
  `temporal_reprojection_amount` 0.68, `sky_affect` 0.0.
- Depth fog: `#3A4152`, `depth_begin` 22, `depth_end` 380, `depth_curve` 1.4,
  `aerial_perspective` 1.0, `sun_scatter` 0.35.
- The key at `light_volumetric_fog_energy` 3.2 plus anisotropy 0.78 produces **shafts
  through the pipe rack** at upper-right and through the gap between the two prilling
  towers. Those shafts are the single most expensive-looking thing in the frame and they
  cost one float.
- `FogVolume` `BOX`, `size = Vector3(80, 3.5, 24)`, `density` 0.55, `height_falloff` 1.2,
  `edge_fade` 0.5, sitting on the yard floor at Z = −14. Ground mist in the low yard,
  because the sabkha is damp before sunrise. It makes the eucalyptus row read as depth.
- `FogVolume` `ELLIPSOID`, `size = Vector3(13, 9, 9)`, `density` **−2.0**, parented to the
  camera. The hero pocket.
- Dust `GPUParticles3D` at Z = +3, −9 and −22. 180 / 300 / 420 particles, `amount_ratio`
  1.0, `fixed_fps` 30, `interpolate` true, `local_coords` false, drifting left-to-right at
  0.35 u/s on the ghibli axis, `visibility_aabb = AABB(Vector3(-36,-24,-12),
  Vector3(72,48,24))`. Small, `proximity_fade_enabled = true`. They catch the key and they
  are what makes the shafts visible.
- Three plastic bags on the chain-link, on cloth sim, at 0.6 Hz. The DRAPE rule.

### Wanis's pose and framing

Prison state. **Contrapposto, weight on the right leg, left knee soft.** Shoulders square
to camera-right, head turned 12° further right than the shoulders — he is looking at the
perimeter wall, not at the yard. Right hand rests on the broken rail post. Left arm hangs.
Spine flexed 6°, head dropped 4° — the diminished posture offset.

He is back-lit, so his body is 70% in shadow, lifted only by the sabkha fill and the door's
warm slab. The rim runs the top of his shoulders, the right edge of his jaw, and the crown
of his hair. His face is readable but dark. **The one hot pixel on him is a single specular
hit on the left cheekbone from the door practical.**

His contact shadow grounds the right sandal-less foot on the deck — `contact_shadow`
enabled, `shadow_length` 1. Without it he floats, and this frame lives or dies on whether
his feet are on the ground.

He is not doing anything. That is correct. The shot is a held breath.

### The twelve details that make this Libya and not generic ruins

1. **The crane holes.** One circular hole at the centre of every prefab panel, mortared
   shut, three knocked through. Abu Salim's panels had them for the crane hook, and inmates
   reopened them to talk through the walls. Nobody who has not been there would invent this.
2. **The four-layer wall.** Regime green under a Green Book slogan under a crossing-out
   under the tricolour. The whole political history of the level, legible at once, with no
   dialogue.
3. **The dead flare stack.** A cold black lattice with no flame. Brega's plant has exported
   nothing since 2011.
4. **The prilling towers, taller than any minaret.** A fertiliser plant is the skyline here,
   not a mosque. Getting that hierarchy right is the whole location.
5. **Two sands meeting.** Red continental "Heix" sand drifting in from the south against
   bone-white calcareous beach sand, with pink-buff drift lines where they mix. Visible in
   the yard corner at x = 0.62.
6. **The salt crust.** Polygonally cracked, puffed and blistered where salt crystallised
   and lifted it, dark mud showing through the tyre ruts. Nothing grows on it.
7. **The planted windbreak, dead in a straight line.** Eucalyptus and casuarina planted by
   the oil company to hold back the sand, irrigation stopped, failing back to desert in
   visible rows. A dead tree in a straight line is unmistakably planted.
8. **Sand depth as the abandonment map.** Drifted over the threshold of every dark window;
   a clean swept arc where the green door still swings. Someone still uses that one door.
9. **Salt spalling, not impact damage.** Chloride corrodes the rebar, the rust expands past
   3× volume, and the cover concrete cracks and falls. The brown stain from a crack comes
   first; the spall follows. Every spall in this shot is at a slab edge, a lintel or a
   column base — where it actually happens.
10. **The green steel door.** Mid-blue and bottle-green doors and gates are everywhere in
    coastal Libya. It is the right colour and it is the only place the eye rests on the left.
11. **The sodium lamp still burning at dawn.** Dirty amber, buzzing, throwing a hard cone
    through the mist. Nobody turned it off because nobody is here.
12. **The straw-white horizon.** The sky does not go blue near the horizon. Saharan aerosol
    bleaches it, distance goes pale *warm* grey rather than cool blue, and this single
    decision is what stops the frame reading as Spain, Arizona, or nowhere.

### Acceptance criteria

The shot is done when all seven are true:

1. Reduced to pure black at 25% scale, the hero silhouette reads as a single ambiguous
   human mass — **correct for prison state** — and the composition still reads: rail,
   wall, towers, stack.
2. Content is present in **at least seven of the nine depth layers**.
3. No pixel in the frame is pure black or pure white. Shadow sits in the `#6B5F55`
   family at its darkest.
4. The god-ray shafts through the pipe rack are visible without being pointed out.
5. His feet are unambiguously on the deck — contact shadow reads at 100% zoom.
6. At least three independent things are in motion: bags, dust, and the ground mist.
7. A stranger shown the frame with no context says "somewhere on the North African coast,"
   not "a desert" and not "a ruin."

Anything less and it goes back. This frame sets the bar for four more levels and a boss.
