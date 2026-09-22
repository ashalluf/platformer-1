# LIBYAN GANGSTAS — ART DIRECTION (WORLD 1)

**Status: CANON.** Every number in this document is a decision. Numbers marked
**SHIPPED** are in the repo right now and you match them. Numbers marked **TARGET**
belong to a level that does not exist yet and are the brief for whoever builds it.
If you disagree with something here, change this document first and say why. Do not
quietly build something else.

Authority: supersedes any art guidance in `DESIGN.md` Part III. Defers to `DESIGN.md`
Part IV (technical canon) on camera geometry and controller feel.

**How to read it.** §1–§6 before you build anything. §7 if you touch the hero, §8 if
you touch the UI. §9 when Godot fights you — most of it is a list of engine defaults
that are wrong for this game. §10 is one banned word. §11 is the standard, and nothing
is finished until it passes §11.

---

## 1. Pillars

**One: this is the Mediterranean, not the Sahara.** World 1 is coastal, salt-eaten,
Italian-and-Soviet-inflected, sun-bleached pastel — bone white, oatmeal, apricot, faded
mint, chalky sky-blue — on pale calcareous ground with red interior sand bleeding into
it. The palette is *drained*, not *brown*. Anyone reaching for dune ochre, camel
silhouettes or a generic desert filter has misunderstood the game.

**Two: it is always the hour that flatters.** Midday exists in World 1 only as a
deliberate hostility in Level 3. Every other level is lit at a raking angle — sunrise,
mid-morning, golden hour, sodium night — because low sun is what turns flat prefab
concrete into architecture, and because an 18%-of-screen-height hero needs a rim.

**Three: density behind, silence in front.** Backgrounds are ferociously detailed and
atmospherically compressed. The gameplay plane is comparatively sparse, higher in
contrast, sharper, and lit by its own rig. The player never hunts for the floor.

**Four: surfaces carry history, not just age.** Weathering here is political and
climatic archaeology — regime green under a slogan under a crossing-out under a 2011
tricolour, all sun-faded together; salt spalling that exposes rebar; sand drift that
maps who still lives here. A wall states what happened to it.

**Five: Wanis owns the top of the value range.** He wears a white thobe; the world is
capped below it and spends its saturation on mid values. **Value contrast, not hue
contrast, is the readability strategy.** This rule does more than every post-process in
the engine combined, and §2 enforces it numerically.

---

## 2. Colour script

World 1 is **one day**, running forward across five levels: sunrise → mid-morning →
hard afternoon → golden hour → night. That is the cohesion device. Nothing else needs
to tie the levels together and nothing may violate it.

Two constants across all five:

- **Ground stays in the pale calcareous family** (`#D6CEBC` → `#EFE6D2`) with red
  interior "Heix" sand (`#B5784A`) drifting into it.
- **Shadow is never neutral and never black** — warm ochre-violet `#6B5F55` by day,
  cool navy `#2A3A56` by night.

### The chroma law, and where it is enforced

**No world-surface albedo may exceed HSV S 0.55 / V 0.72 inside hue 340°–25°** — the red
sector. That band belongs to Wanis's shemagh and to the Sriracha. Outside the band the
ceiling is S 0.58, because nothing out there competes with the hero and Libyan shutter
paint genuinely is vivid. Damage and danger are signalled with hazard yellow-black
chevrons and a white hit-flash, never red.

**This is not an honour system.** `MaterialLab.world_tint()` clamps it, and every world
preset runs its tint through it, because a level author in a hurry types a punchy red for
a shutter once and never thinks about it again. The band edge is feathered over 10°
rather than being a hard sector test: iron oxide lands at hue ~23°, one degree inside,
and a hard edge there would either wash every rust run in Brega into mud or leave a
crimson wall legal at 26°.

Four exemptions exist in code and no others may be invented:

1. **`cloth()` and `skin()`** — they build Wanis's costume and the Sriracha's cap and
   band, which are precisely what the band is reserved for.
2. **`emissive()` and `ice()`** — light and fantasy, not albedo. The law is about what a
   surface reflects.

World fabric does **not** use `cloth()`. Awnings, sacks and tarpaulins use `canvas()` and
`sacking()`, which are clamped like everything else. One live loophole to know about: a
`MultiMesh` that drives colour through `vertex_color_use_as_albedo` — the market stall
awning does — passes no tint through the clamp at all, so those colours are governed by
the law **by hand**. Author them inside the cap. A market awning is allowed to be the
most colourful thing in the street; it is never allowed to out-value the thobe, and it
only appears where the stall itself is in shade.

### Level 1 — BREGA PRISON BREAKOUT — SHIPPED

*05:52. Pre-dawn blue cracking into first direct sun. The transformation beat lands on
the frame the sun clears the horizon.*

Built in `levels/brega/BregaKit.gd` (`mood()`, `palette()`) and matched exactly by
`BregaBeauty` and by `levels/menu/TitleScreen.gd`. If you change one, change all three.

| | |
|---|---|
| **Key** | `sun_angles = (-3.5, 150.0)` — 3.5° altitude, behind and screen-right. `sun_color` 2200 K `#FF9040`, `sun_energy` 3.1, `angular_distance` 1.1, `sun_disc_size` 0.34 |
| **Key into fog** | 3.0 in the benchmark frame, **1.3 in the playable level** — in gameplay the camera spends its life looking along the key, and 3.0 puts a hot white wash across the bottom right of every frame |
| **Fill** | `(18.0, -28.0)`, `#798BB8` cool sabkha/sky bounce, energy 0.54. Weak on purpose: the playing field is behind the key and must stay in shade |
| **Rim** | `(-4.0, 128.0)`, `#FFB877`, energy 8.0, `rim_cull_mask = 2` (hero layer only) |
| **Hero fill** | `(-14.0, -30.0)`, energy **1.45** in level / 2.5 in the benchmark, `#D1D4E6`. 2.5 of a cold light on a white robe in gameplay turns him blue |
| **Sky** | top `#2B3A55`, horizon `#C97B45`, ground horizon `#D5CDBD`, `sky_curve` 0.11, `ambient_energy` 0.29 |
| **Fog** | colour `#D5CDBD`, `fog_density` 0.00052, `sun_scatter` **0.15** (0.35 blooms the whole right of frame to paper), emission `#0F0B09`, `anisotropy` 0.78, volumetric 0.00040 (level) / 0.00068 (benchmark) |
| **Grade** | AgX, exposure 1.08, `glow_intensity` 0.12, `glow_hdr_threshold` 2.2, saturation 1.14, contrast 1.06 |
| **Level-unique colour** | **REGIME GREEN `#2E7A3F`**, faded to `#5E8A5C` on sun faces. This level and no other in World 1. |

Supporting palette (as `BregaKit.palette()` names them): slab, joint, dark, wall, deck,
rail, rebar, rust, tank, tank_burnt, bund, tower, steel, sabkha, mud, sand, trunk, leaf,
door, green, shutter, bag, crate, corrugated. Salt spalling on slab/wall/deck climbs
from `YARD_Y = -6.6`, not from the gameplay plane — the grime datum is the yard floor.

### Level 2 — AJDABIYA CROSSROADS — SHIPPED

*Mid-morning, clear, high and hard. Two hours later and forty kilometres east.*

Built in `levels/ajdabiya/AjdabiyaKit.gd`. **Ajdabiya is the counterweight to Brega.**
Brega is a dead plant at first light: key behind the geometry, cold shadow, no people,
almost no colour. Ajdabiya is a town — the sun is up and *in front*, the street is lit,
shadows are short and hard blue, and colour is everywhere because people put it there.

| | |
|---|---|
| **Key** | `(-47.0, 38.0)` — front-three-quarter over the player's shoulder. `#FFEDD0` ≈ 4800 K, energy 4.2, `angular_distance` 0.6, `disc_size` 0.30, into fog 0.9 |
| **Fill** | `(-26.0, -168.0)`, `#5C80C7` hard blue sky bounce, energy 0.80 — at this hour the sky *is* the whole shadow |
| **Rim** | `(-14.0, 196.0)`, `#FFE0B8`, energy 2.6, hero layer only |
| **Hero fill** | `(-18.0, -36.0)`, `#DBE0F0`, energy 1.1 |
| **Sky** | top `#2F548F`, horizon `#A3B3C2`, `sky_curve` 0.22, `ambient_energy` 0.42 |
| **Fog** | `#B3B7B8`, density 0.00055, `sun_scatter` 0.10, `anisotropy` 0.55, volumetric 0.00035 |
| **Grade** | AgX, exposure 1.0, glow 0.10 @ threshold 2.4, saturation 1.10, contrast 1.12 |
| **Level-unique colour** | The awning stripe set: madder `#B83D2E`, petrol `#2E5C75`, sage `#3D6642`, each against cream `#D6C7B2`. Saturation lives in painted metal and cloth, never in render. |

**TARGET, not built:** the ghibli. The brief has the dust storm arriving at the
midpoint and the second half played inside it — key dropping to energy 0.42 with
`angular_distance` 6.0, fill going omnidirectional, fog to `#B5713F` at 15× density,
horizon gone. Also unbuilt: **sabkha terra rossa `#9C4E33`**, the red mud under the
cracked salt crust. When either lands, move these lines up into the shipped table.

### Level 3 — HIGHWAY TO BENGHAZI — TARGET

*13:40. The hardest, flattest light in the game, on purpose. The read is horizontal
velocity, not surface modelling.*

Sun altitude 61°, azimuth 205° SSW slightly behind-left; 5500 K `#FFE2C8`; key energy
1.60, `angular_distance` 0.9, `shadow_opacity` 0.90, shadow max distance 70 (long, for
the road). Fill: sky ambient plus an **asphalt bounce from below**, energy 0.22
`#8E8880` — bounce from below is what stops the car reading as a sticker. Rim energy
3.2 `#9FC4E8`, the strongest and coolest in World 1, because at speed the hero and the
vehicle are the only things the eye can lock onto. Fog `#DCCBAE`, long, so the road has
a real vanishing point. Heat haze `strength` 0.016 at the road surface falling to zero
at y = 0.45 of frame height, never above that line.

Level-unique colour: **OLEANDER PINK `#E58FA6`** on the central reservation, the one
living saturated thing on a dead road, repeating at a spacing that itself reads as speed.

### Level 4 — GARYOUNIS UNIVERSITY — TARGET

*17:35. Golden hour raking lengthwise through two-storey viaducts. The prettiest level
in World 1 and it is allowed to know it.*

Sun altitude 9° → 4°, azimuth 268° W — almost dead down the camera-left axis, so light
runs *along* the concrete canyons instead of across them. 3050 K → 2400 K. Key energy
1.50, `angular_distance` 1.4. Fill: deep viaduct shade lit by sky alone, ambient
`#6E86A8` at 0.85 — the coolest fill in the game, and the maximum warm-key/cool-shade
split. Fog `#E2B98A`, volumetric density 0.028, **anisotropy 0.86**. This is the sun
shaft level: shafts through every gap, arch and brise-soleil fin, with
`use_filter = 0` for hard shaft edges.

Level-unique colour: **THE GOLD DOME `#C9A227`** on the administration block plus its
bounce — the only warm-metal ambient term in World 1, and the level's landmark.

### Level 5 — BENGHAZI — TARGET

*19:05 dusk → 21:00 night. Corniche at blue hour, the old city after dark, the boss
under floodlight and a high moon.*

The sun is a horizon-glow driver only: altitude −4°, energy 0.12 `#FF6A3A`, no shadows.
It paints the sky and the sea, not the world. **The real key is the moon** — altitude
52°, 8200 K `#C8D8FF`, energy 0.55, `angular_distance` 0.6 (moon shadows are crisp).

**The practicals are the level.** Sodium vapour 1900 K `#FFA13B` at omni energy 3.5,
range 9.0, cutting hard cones through the fog; shopfront fluorescents 5200 K `#DFF0E8`;
headlights `#FFF0D8`; wedding-convoy hazards `#FFB020`, flashing. Ambient `#2A3A56` at
0.55 — **never lift it to make something visible; add a practical instead.** The rim is
a cool moon 2.0 `#8FB8E8` plus opportunistic warm sodium from whichever practical he is
passing, so the rim hue changes as he walks. That is the level's best trick.

Level-unique colour: **COPPER PATINA `#5FA391`** — the cathedral domes and the still
water of the lake. The only teal in World 1, and the boss arena is lit to make it sing.

### How the five read as one game

- The ground family never changes; only the light on it does.
- Shadow is warm ochre-violet by day and cool navy by night, never neutral grey.
- Each level owns exactly one unique hue, and the five occupy five hue families: green,
  awning-madder/terra rossa, pink, gold, teal. No two compete.
- **Aerial perspective is always warm** — distance goes pale straw-grey, never cool
  blue. Saharan dust load, not temperate haze. This is the single most location-specific
  lighting fact in the game.
- The horizon sky band is bleached straw `#D5CDBD` in every daytime level and only goes
  blue at high zenith angles.

---

## 3. Shape language

**World 1 runs from the orthogonal to the arched.** Level 1 is right angles: prefab
panels, pipe racks, bund walls, everything the same age. Level 3 is the pivot — pure
horizontals, a dead-straight dual carriageway. Level 5 is arcs: Italian arcades, barrel
vaults, oriels, four copper domes. Levels 2 and 4 interpolate. A player who cannot
articulate it will still feel the geometry opening up as World 1 progresses.

### Three silhouette registers

Every object belongs to exactly one.

- **SLAB** — flat-topped, hard-edged, repeated at a fixed module. Prefab panels, bund
  walls, Jersey barriers, boundary walls, catwalk decks. This is the gameplay plane's
  native language: **if it is standable, it is a slab.** Non-negotiable.
- **STACK** — vertical cylinders and shafts. Prilling towers, flare stacks, storage
  tanks, minarets, Horton spheres, palms, lamp posts. Background rhythm and landmarks.
- **DRAPE** — anything that hangs, sags or catches wind. Cable catenaries, laundry
  lines, torn shade cloth, snagged bags, frond skirts, the shemagh tail. **Every screen
  must contain at least one DRAPE element in motion.** This is the anti-deadness rule.

### The chamfer law

**There is no `BoxMesh` in this project.** A box with perfect ninety-degree edges is
the loudest blockout signal there is. Real edges are cast, chipped, rendered over, or
simply small enough that light wraps them — and that wrap *is* the edge highlight.
Without it a wall has no edge, only a place where two flat values meet.

`LevelKit.chamfer_mesh()` is the only box in the game. The bevel scales with the object
(`bevel_for()`: 7% of the smallest dimension, clamped 14–85 mm), meshes are cached by
size so a thousand identical blocks share one, and **collision stays a plain
`BoxShape3D`** — the chamfer is centimetres and must never change where anything stands.
Faces are flat-shaded on purpose: a chamfer smooth-shaded into its faces stops being an
edge highlight and becomes a gradient.

`surface_weathered` detects that chamfer and puts the edge wear on it (§4).

### Forbidden geometry

Nothing standable may be round-topped, bevelled past the chamfer law, or sloped between
12° and 38° — the "am I supposed to stand on this" band. Decorative geometry has no such
restriction and should break the grid constantly.

### Three rules for detail, from `DetailKit`

**IT IS READ IN PROFILE.** The camera is side-on; an object's silhouette in X and Y is
all the player ever gets. Anything whose character lives in plan — a flange bolt ring,
a hand-wheel, a ladder cage hoop — is tilted, stood off the wall, or oversized until it
reads as a shape rather than a line.

**70 mm IS THE FLOOR.** At 10–40 world units a member thinner than about 70 mm falls
between pixels and the object goes bald. Build every tube, rail, rung and bar two to
three times heavier than the real component. Where that is a big lie, say so in a
comment. The walkway handrail was balusters at 900 mm pitch and read as a smear of
sticks; it is now stanchions at 1.85 m with knee braces, a top rail, a mid rail and a
toe plate — two long horizontals and a few uprights, which is a silhouette you can read.

**NOTHING ENDS IN MID-AIR.** A pipe stops at a flange, a blank or a valve. A rail stops
at a return or a post. A conduit stops in a box. An unterminated run is the second
loudest greybox tell after the sharp edge.

### Detail on a shaded surface must be silhouette

In a backlit level nothing on a wall reads by its own value, so every piece of detail
has to stand off the face and break the outline: downpipes with shoes and brackets,
conduit into junction boxes, split-unit condensers, aerials, dishes, header tanks,
sagging cables. `PropKit.wall_services` and `PropKit.roof_clutter` exist for exactly
this. Anything under about 70 mm at gameplay distance disappears — see above.

### Massing before texture

A wall is never a single plane. It has a plinth, a string course at every floor line, a
cornice before the parapet, and at least one bay stepping forward off the rest
(`PropKit.building_massing`). Each is a few centimetres of geometry and each buys a hard
shadow line across the whole facade, which at gameplay distance is worth more than any
amount of surface detail. The stairhead on a roof is the one person-sized object up
there, and it is what gives the rest of the roofline its scale.

---

## 4. Material rules

Every environment surface in the game comes from `MaterialLab` and runs one shader,
`shaders/surface_weathered.gdshader`. A wall in Brega and a wall in Benghazi are the same
material family with different inputs. **Nothing ships as a texture file** — noise comes
from `NoiseBank` at load.

### The laws

**Constant roughness is banned.** The shader varies roughness from a detail lookup with
`roughness_contrast` applied first (raw fbm lives near 0.5 and never reaches the declared
min/max), then drifts it with a second decorrelated noise so gloss varies in patches, not
only in grains. Nothing else on the pitfall list matters if this one is broken.

**`metallic_specular = 0.30` on every dielectric** — `MaterialLab.DIELECTRIC_SPECULAR`.
The 0.5 default is the plasticky-sheen tell.

**Metallic is a switch, not a dial.** There is no physical state between a conductor and
a dielectric, so do not lerp one. Iron oxide is a dielectric and bare steel is a
conductor: heavy rust is `metallic 0.0` and reads matte and chalky, and the old
half-metallic version read like painted plastic. Paint is a dielectric film — the player
sees the binder, never the steel under it — so painted metal is `metallic 0.0` too. The
0.15 that used to be there was a fudge for "it should look a bit metal" and it bought a
grey sheen over every colour in the level.

**Weathering is generated, not authored.** `PropKit.gradient_decal` builds a 64 px
falloff image in three modes — *streak* (strong at the top, running down, soft off both
sides), *band* (strong at the bottom, fading up), *radial* (a soft blob). A
one-dimensional gradient cannot fade on two axes, and a dirt run that does not fade
sideways reads as a grey rectangle stuck to the wall.

**A polished metal in a dark room renders black,** because a mirror with nothing to
reflect is black. Either give the room an environment the metal can reflect, or brush it:
roughness ~0.30–0.38 and a real diffuse underneath, so the key spreads into a sheen.
`brushed_aluminium()` exists for this. Mirror chrome is a reward, not a texture — it is
for the gold chain, the steel tea set, and car trim.

### The tone dial

Every world preset takes `tone` as its last parameter, running −1 to +1. It is the level
author's one dial for making a surface darker, lighter or dirtier without inventing a
colour by hand, and hand-picked albedos are how five levels drift apart.

- **+1** — full sun-bleach: south and west faces, chalked render, salt-burnt paint.
  Value up, saturation down hard, per the aspect rule. Dust rises with it.
- **0** — the preset as authored.
- **−1** — deep shade, soot, damp, the underside of a canopy. Grime rises with it.

Negative tone does **not** multiply toward grey. A neutral-multiplied shadow is the
single most common tell of a hobby scene, so the dark end drops blue fastest and then
leans into a warm soot. Preset signatures are append-only and the first parameter is
always the tint, because a few hundred call sites pass positionally.

### The preset library

All of these run one shader, `shaders/surface_weathered.gdshader`, unless the row says
`StandardMaterial3D`. **Nothing ships as a texture file** — noise comes from `NoiseBank`
at load. The shader's own uniforms ship tuned, so `MaterialLab.surface()` sets only what
a preset has an opinion about; everything else inherits the shader's look.

| Group | Presets | Notes |
|---|---|---|
| **Structure** | `concrete`, `plaster`, `limewash`, `salt_masonry`, `wet_concrete` | Panel joints are *modelled*, 12 mm deep, never textured. Limewash is thin enough that block coursing ghosts through and it crazes wherever the block moves. `salt_masonry` is the bottom two metres of everything within 100 m of the Gulf, and it is the material that makes Brega read as coastal. `wet_concrete` both darkens albedo and collapses roughness on up-faces — darkening alone reads as dirt, not water. |
| **Metal** | `rusted_metal`, `painted_metal`, `galvanised`, `corrugated`, `brushed_aluminium`, `chrome`, `gold` | Rust is never a uniform tint: three values in one patch, always with a bleed streak running down from the source. Knocked edges on rusted stock go back to bright steel before they go back to rust. Galvanising goes white-powdery carbonate within two summers, which is every roof tank in Libya. Corrugated ridges come from an analytic normal, so a wall of it costs two triangles. |
| **Ground** | `sand`, `asphalt`, `packed_earth` | Sand's variation is derived from its tint, never fixed — a fixed bright variation gives a dark sand bright patches, which is what kept the yard floor the lightest thing in every frame. Two sands, and they *meet*: pink-buff drift lines where red Heix runs into bone-white calcareous. |
| **Civic surfaces** | `painted_wood`, `ceramic_tile`, `terracotta`, `bitumen` | Paint on timber crazes along the grain long before it fades, and rubbed edges go back to silvered wood. Tile is almost entirely a specular read: glossy faces against matte grout with a bevel catching the sun along every course. Bitumen never stops being black, which makes it the darkest value available for composition. |
| **Fabric** (`StandardMaterial3D`) | `canvas`, `sacking`, `cloth` | `canvas` is backlit on purpose: thin enough that the sun comes through, so it throws a coloured pool onto the wall behind it — the cheapest beautiful thing you can put in a Libyan street. `backlight = (0.25, 0.22, 0.16)`, warm and darker than the albedo, because light through one layer of cotton has lost its blue. **`cloth` is the hero exemption and is not chroma-clamped; world fabric uses `canvas` and `sacking`.** |
| **Vehicles** (`StandardMaterial3D`) | `auto_paint` | Two specular lobes — a tight bright one from the lacquer and a broad soft one from the basecoat. A car reads as a car because of its clearcoat. Metallic stays 0.0 at both ends of `flake`. |
| **Glass** | `glass`, `dusty_glass` | Mostly *absent*: blown out, boarded, or sandblasted opaque. Where intact it is the only place SSR is enabled. |
| **Characters** (`StandardMaterial3D`) | `skin` | SSS on, strength 0.28, skin mode on. Not chroma-clamped. |
| **Special** | `ice`, `emissive` | `shaders/ice.gdshader`: deep core brightening to the silhouette by Fresnel, frost rind on up-faces broken by noise, hard glints on a hashed lattice offset by the view vector so they wink as the camera moves. Neither is clamped — they are light, not albedo. |
| **Foliage** | `PropKit.foliage_material` | Wind by world position, anchored by height above each plant's base, so trunks stay planted while canopies travel. Alpha-to-coverage — MSAA does not antialias alpha scissor. Planted species appear in rows and avenues only; wild growth is separated low mounds with bare ground between every plant, never continuous cover. |

### The weathering law, and where the shader implements it

Four rules. They apply to every asset. Reject assets that break them.

1. **Gravity.** Every stain runs down. Every scupper, AC unit, bolt, bracket, nozzle and
   crack produces a hard-edged vertical streak below it, longer than you think. The
   shader gets this from one vertically-stretched lookup shared by grime and by the dust
   wash — the water that deposits a stain below is the same water that scoured the dust
   above it, and they line up. A wall without downward streaks is unfinished.
2. **Aspect.** South and west faces bleach and chalk. North faces, porch undersides,
   window reveals and anything under a canopy keep their saturation. Free, and the most
   honest weathering cue available.
3. **Wind.** Sand ramps into leeward corners and the windward face is scoured — paint
   stripped to bare render from 0 to 1.5 m only, glass frosted, signs scoured on the
   south face.
4. **Occupancy.** Sand depth on a threshold is a map of abandonment. Swept step = someone
   lives here. Drift over the sill = nobody has come out in years. This is how you author
   which buildings feel alive without a single NPC.

Three shader behaviours worth knowing before you tune a preset:

- **Dust settles by world normal**, packs into concavity, and is scoured off higher up
  where rain reaches and runs. Its tint varies with macro noise because real dust is
  never one tan: the fine stuff that blows in is paler and greyer than the coarse grit
  that stays.
- **Grime climbs from a per-material ground datum** (`grime_origin_y`), not from y = 0.
  Every level sets it: Brega uses the yard floor at −6.6, Ajdabiya the street at 0. Get
  this wrong and the salt spalling starts in mid-air.
- **Edge wear lands on the chamfer and lifts toward white**, and it is *held back on
  sky-facing edges* — wear is a story about contact, and nothing knocks the top of a
  wall. That edge collects dust instead. Without that damping the top chamfers came back
  reading as white icing piped along every block.

### Emissives and additive

**An additive flame above about 1.5 energy tonemaps to white and stops being fire.**
Keep the energy low and let the colour carry it. The benchmark flare runs
`MaterialLab.emissive(#FF5C12, 1.1)` with `BLEND_MODE_ADD` and alpha 0.75, and the heat
comes from an `OmniLight3D` beside it, not from a brighter quad. Control *what* glows
with `emission_energy_multiplier`, never by lowering the glow threshold.

### Forbidden — reject on sight

- Black shadows. Pure white. Neutral-grey concrete. Cool-blue aerial perspective.
- Brown loam, dark soil, grass, moss, temperate deciduous trees.
- Cobblestone, medina alleys or organic winding lanes anywhere in Brega — it was built
  from prefab parts in one go on a grid and there is no old town.
- Tuk-tuks, rickshaws, camels in a city, snake charmers, keffiyeh-and-agal headdress, or
  a minaret as the only skyline element.
- A Hilux with a weapon in the bed. It carries crates, tea urns, a couch, sheep before
  Eid. Never a gun.
- Gaddafi as a visual gag. The green flag as decoration. Alcohol of any kind.
- Rubble as comedy or as scenery. Where destruction appears, something is being rebuilt
  around it — a new café in a half-rebuilt villa is the honest version.
- Arabic as disconnected glyphs, mirrored, stretched non-uniformly, or in a faux-Arabic
  Latin face. Arabic is cursive and RTL, and Godot's TextServer shapes and orders it
  correctly — `PropKit.sign` already does this. Libyan signage uses **Western digits**.
- Bilingual street signage. Libyan road and street signage is Arabic-only and sparse.
  Bilingual safety signage *inside* the plant is correct and is the only exception.
- Any surface albedo outside sRGB 50–240, or breaking the chroma law in §2.
- Symmetric decal placement. Constant roughness. Tiling that visibly repeats within one
  screen width.

### Typography, assigned by function

- **Naskh** — official and state. Road signs, plant identification, clinic and pharmacy
  fascias, the `ليبيا` on number plates, Green Book slogans.
- **Kufic** — monumental and institutional. Mosque inscriptions, commemorative plaques,
  university and corporate marks, tile work, place names printed flat on the world map.
- **Ruq'ah** — the vernacular hand. Hand-painted shop signs, revolutionary graffiti,
  price cards. White or yellow letters on a saturated field with a drop shadow, the paint
  sun-faded and flaking so letters are partly missing.

Number plates: 520 × 110 mm, black on white, `1-12345`, `ليبيا` in Naskh at the right.
White private, yellow commercial, blue public service, red diplomatic.

### The four-layer wall

The highest-value environmental storytelling asset in the game. It appears in Levels 1,
2 and 5. Bottom to top: a field of **regime green** `#1E7A3C` faded to `#5E8A5C` where
the sun hits; a **slogan** painted over it in white or yellow Naskh; a **crossing-out**
in black or red; **2011 revolutionary graffiti** over the top in red-black-green with
star and crescent, sprayed fast in Ruq'ah; and sandblasting and UV fade making all four
partly legible at once. The whole political history of the level with no dialogue.

---

## 5. Lighting model

**A level never builds lights.** It declares a `LightingRig.Mood` and calls
`LightingRig.build()`. One place is what stops World 1 drifting into five
different-looking games, and every value in §2 is a field on that Mood.

### Exposure: read this before you change any energy

The whole thing is one equation and one curve.

```
linear_radiance = linear_albedo x light_energy x N.L
```

Godot folds the Lambert 1/pi into the light's energy, so energy 1.0 puts a pure-white
surface facing the light at linear 1.0. **`linear_albedo` is not the hex you typed.**
Hex is sRGB and the shader multiplies in linear, and the two are a long way apart in the
darks: `#D8CEB6` prison slab is linear 0.687, `#A8A296` concrete is 0.392, `#4A4741`
asphalt is **0.068** — four times darker than a colour picker suggests. Most of "why is
my dark material black" is that line and nothing else.

AgX then maps linear to screen, and it has a shoulder: past linear ~1.5 you buy almost no
screen value, you only burn headroom. **That is exactly how a level drifts.** The author
cannot see the wall getting brighter, so they push the key, and the hero — who was
already on the shoulder — stops separating from it.

Wanis's thobe is linear 0.905 and the pale calcareous ground is 0.863. They are
practically the same albedo, **so his separation has to come from light, never from
material value.** The targets:

| Band | Screen | Linear |
|---|---|---|
| Deep shade / interior | 0.30–0.40 | 0.055–0.110 |
| Shaded world surface | 0.42–0.52 | 0.120–0.200 |
| Key-lit world surface | 0.66–0.78 | 0.455–1.000 |
| Hero thobe, front-lit | 0.80–0.86 | 1.15–2.00 |
| Hero rim / chain specular | 0.92–0.97 | 3.50–9.00 |
| Anything at all | never 1.00 | AgX clips hard at 16.5 |

A level whose ground is pale calcareous wants a key in the **1.0–2.0** band, not 3+.
`Mood.debug_describe()` prints where a mood lands the canon surfaces and warns when
key-lit mid concrete passes the 0.78 ceiling. Print it from a level's `_ready` and the
screenshot stops being an opinion.

**Known deviation:** the shipped moods run key energy 3.1 (Brega) and 4.2 (Ajdabiya),
two to three stops above that band. Brega half gets away with it because its key is
behind the geometry and almost nothing in frame has an N.L above 0.2. Ajdabiya, front-lit,
does not — the pale ground sits on the shoulder right next to the hero and the frame
flattens. When you retune either, bring the key down and add bounce; do not compensate
with exposure.

### The rig: one key, three fills

| Light | Job | Rules |
|---|---|---|
| **Key** | The sun. The only shadow caster. | Splits **0.06 / 0.15 / 0.35 as fractions**, blend on. `GraphicsDirector` rewrites `shadow_max_distance` per quality tier (70 / 110 / 160 / 220), so anything expressed in metres is advisory and fractions are what survive. Bias 0.03, `normal_bias` 0.8, opacity 0.84, `angular_distance` 0.6–1.4 — **the 0.0 default gives razor edges at every distance and is the clearest CG tell there is.** Only the key writes into the volumetrics. |
| **Fill 1 — sky** | The dome. Decides what shadow looks like. | Cool and broad. From above-front in a daylight level, from below-front where the ground is the brighter source (Brega's sabkha). No shadows, no fog contribution, `specular` 0.35 — a sky fill has no specular in the real world. Always the complement of the key. |
| **Fill 2 — bounce** | Ground bounce. | Warm, from below, tinted by the sky's own ground colour. **Off by default; switch it on before you reach for more key.** It is the cheapest way to stop an object reading as a sticker pasted on the background. |
| **Fill 3 — rim** | Separation. | `rim_cull_mask = 2`, the hero layer only. A rim that also lights the world is a second key and it flattens everything. |
| **Hero fill** | Front value on the hero in a backlit world. | Hero layer only. The single most useful light in a backlit scene: the world sits in true shade while he keeps a readable front. Keep it warm-neutral — a cold light on a white robe turns him blue, and he reads as warm white against a cool world. |

The hero carries render layers 1 **and** 2, so there is no mask that means "the world but
not the hero." **Light him more; never light the world less.**

### A backlit surface stays in shade

In Brega the key is low and behind the geometry, so the whole playing field faces away
from it. **Do not "fix" a flat wall by lighting its front.** It would be a lie and it
would cost the hero his contrast. Put the wall low in the value range, keep the fill cool
and weak, and let him be the brightest thing in the frame. The only saturated colour
allowed on the shadow side is a light somebody left on — `PropKit.lit_window` is the
cheapest way to make a dark mass read as a building with people in it, and in a backlit
frame it is the only warm accent the shadow side gets.

### Sun shafts

A shaft is not a post-process. It is volumetric fog the key writes into, minus the parts
an occluder shadows. Three things have to be true at once or you get nothing:

1. `sun_fog_energy` high enough that the key is actually in the fog,
2. `fog_anisotropy` ≥ ~0.55 — the 0.2 default scatters evenly and the beam never gathers,
3. **a `FogVolume` downstream of the occluder and on the camera's side of it.**

(3) is the one every level got wrong by hand, and `LightingRig.shafts()` now fixes it:
you pass the position of the thing *cutting* the light — the pipe rack, the brise-soleil,
the gap between two towers — not where you want the beams, and it places the volume on
the far side along the key direction. Corollary worth internalising: in a front-lit level
the physically correct placement is behind the occluder and out of sight, so **pick a
foreground occluder instead.** `shafts_height_falloff` stays at 0 — a shaft that thins
with height dies before it leaves the occluder; ground mist is the one that wants 1.0–1.5.
Low-frequency noise through the beam is the dust-in-the-light read and it is the
difference between a shaft and a triangle of haze.

Two companions on the same machinery: `ground_mist()` (height falloff, soft edges so the
box never shows) and `hero_pocket()` (negative-density ellipsoid parented to the camera
rig, so he never hazes out while the background stays atmospheric — strictly better than
lowering the global fog, which flattens every layer at once).

### Practicals

Practicals are `LightingRig.practical()` / `practical_spot()`, never a hand-rolled
`OmniLight3D`. Pick a **bulb** and override only what the shot needs: `SODIUM` (1900 K,
the World 1 night signature), `INCANDESCENT`, `FLUORESCENT`, `HEADLIGHT`, `FLARE`,
`HAZARD`, `CASE`, `MOONSPILL`. Each carries a colour, energy, range, fog contribution,
quadratic attenuation and a default flicker (`HUM`, `FAIL`, `FIRE`, `BLINK`) that is
deterministic, so a capture of a flickering lamp is not a lottery. Five levels
hand-rolling five different ideas of what a street lamp is worth is exactly the drift
this exists to stop.

Use `light_negative = true` omnis to sculpt darkness back into over-lit corners — a
standard film trick Godot supports natively, and there is one under the walkway in the
benchmark. Budget 1–3 `AreaLight3D` per scene; clustered lighting means one in the
frustum costs on every rendered object.

### Grade

Saturation and contrast are global scalars. They cannot make the shadows cool while the
highlights stay warm, which is the entire job of a grade and **the reason every level was
sliding toward the same orange.** The Mood carries a real one: `grade_lift` /
`grade_gamma` / `grade_gain`, shadow and highlight split-tone around 0.5 grey,
temperature and tint, feeding a generated 33³ LUT on `adjustment_color_correction`.
`set_three_way(shadows, mids, highs)` is the colourist-shaped front door. Identity values
build no LUT at all, so a mood that does not grade pays nothing.

For the cool-shade half of "warm key, cool shadow", push `grade_shadow_tint` toward
`(0.45, 0.48, 0.58)` rather than dropping global saturation.

### Environment defaults that ship

```
background_mode        = BG_SKY           # ambient from the sky, never from a clear colour
ambient_light_source   = AMBIENT_SOURCE_SKY, sky_contribution 1.0
tonemap_mode           = TONE_MAPPER_AGX  # ACES desaturates our brights; AgX holds them
agx_white / agx_contrast                  # the real knobs. `tonemap_white` is IGNORED
                                          # under AgX. Target 9.5 / 1.45; engine
                                          # default 16.29 / 1.25 is flat
ssao   radius 1.1  intensity 2.2
ssil   radius 2.2  intensity 0.9          # the 5.0 radius default bleeds background onto him
ssr    max_steps 48                       # wet stone, intact glass, chrome, water only
sdfgi  4 cascades, min_cell 0.2, occlusion on, bounce feedback 0.6
glow   SOFTLIGHT, bloom 0.0, luminance cap 5.0, levels [0, 0, 0.6, 1.0, 1.0, 0, 0]
fog    sky_affect 0.0, aerial_perspective 0.16
vfog   gi_inject 1.0, length 90, detail_spread 2.0, temporal_reprojection 0.68
```

Five of those are load-bearing:

- **`glow_bloom = 0.0`.** Above zero it lifts *everything* into the glow buffer
  regardless of threshold. The number one cause of washout. `GLOW_BLEND_MODE_ADD` is the
  washout machine; SOFTLIGHT ships, SCREEN is acceptable, ADD never.
- **`glow_levels/1` and `/2` at zero.** Those two are the tight halo beside every bright
  edge, and that halo *is* the cheap-bloom signature. The wide cinematic falloff lives
  in 4–6.
- **`glow_luminance_cap = 5.0`.** At the 12.0 default one blown sun pixel floods the
  whole frame.
- **`volumetric_fog_anisotropy` ≥ 0.55.** The sun-shaft knob, and it costs one float.
- **`temporal_reprojection_amount = 0.68`.** The 0.9 default blends 90% of the last frame
  and smears fog trails behind everything when the world slides sideways. Side-scroller
  critical.

Two engine defaults the Mood still ships rather than the canon value, so that adopting
them is a deliberate per-level change: `volumetric_sky_affect` (canon 0.0 — crisp sky,
fog only in the world) and `sun_indirect_energy` (canon 1.3).

Depth of field lives on `CameraAttributesPractical`, not on `Environment`, and it is
currently **off in both shipped levels**: Godot's near blur is distance-from-camera and
swallows the entire gameplay plane before it softens a foreground at Z = +7. Foreground
separation is done with value and scale instead (§6).

---

## 6. Depth-layer recipe

Camera at **Z = +16**, **FOV 34°**, `KEEP_HEIGHT`, per `DESIGN.md` Part IV. That is
fixed — it is tuned into the controller and the camera code. Visible vertical extent at
the gameplay plane is 2 × 16 × tan(17°) = **9.78 units**, so a 1.78 m Wanis is **18.2%
of screen height**. Every layer below is sized against that.

Parallax is free and physically correct: a layer at distance *d* from the camera moves at
16/*d* of the gameplay layer's screen rate, in X and Y, under zoom, and under
`frustum_offset`. **No `Parallax2D`, no `ParallaxBackground`, ever.**

| # | Layer | Z | Dist | Parallax | Contents |
|---|---|---|---|---|---|
| 8 | **Foreground occluder** | +9 | 7 | 2.29× | Near-black shapes: razor coils, a dead trunk, a pipe-rack leg, an arcade column. Clips one or two frame edges. |
| 7 | **Foreground frame** | +5…+8 | 8–11 | 1.45–2× | Readable but desaturated: chain-link, a parapet lip, a kerb run, tyres, drums, pallets, posts. Never crosses the band the player traverses. |
| 6 | **Gameplay plane** | **0** (props −1.2…+1.2) | 16 | 1.00× | Everything standable, collectible, hostile. Full PBR, world triplanar, highest contrast, sharpest. **Nothing else is ever at Z = 0.** |
| 5 | **Near background** | −5 | 21 | 0.76× | The wall behind the action. Full materials, saturation −12%. The four-layer wall lives here. |
| 4 | **Mid background** | −13…−22 | 29–38 | 0.42–0.55× | The yard, the perimeter wall, the pole line, the windbreak, the far terrace. Simplified materials, saturation −24%. |
| 3 | **Deep background** | −26…−75 | 42–91 | 0.18–0.38× | The plant bank, the tank farm, the second band of town. Silhouette-driven, saturation −35%, no shadow casting. |
| 2 | **Far landscape** | −140…−220 | 156–236 | 0.07–0.10× | Sabkha plain, the sea, the dust band. Single material, no normal maps. |
| 1 | **Horizon skyline** | −300 | 316 | 0.05× | Prilling towers, the flare stack, the minaret, cathedral domes. Near-flat, heavily blended to fog. Landmarks: visible from most of their level. |
| 0 | **Sky + atmosphere** | −420…−900 | — | ~0.02× | The sky material, the straw dust band, one drifting plume. Effectively infinite. |

**Every screen must carry content in at least six of the nine layers.** A screen with
only gameplay, near background and sky is a greybox regardless of how good the materials
are. The benchmark frame is required to hit seven.

### Layer separation comes from material value, not from fog

Fog puts every layer on the same sheet of paper. Give each depth band its own albedo step
and keep the fog thin enough that the steps survive. In Brega the plant bank at Z −26…−40
is deliberately darker than the tank farm at −75 behind it, and that value step is why it
reads. This was the recorded failure of the first benchmark pass: two fifths of the frame
was empty haze with a sun in it, and the fix was geometry with its own value, not more
atmosphere.

### A foreground prop is sized to the near frustum, not to the world

At Z = +7 the frame is about six world units across. A beam the length of the walkway
blacks out the image. Foreground elements are small and there are many of them
(`BregaKit.foreground_band`), and one of the five variants is a low kerb run — a
horizontal that crosses the bottom of frame instead of another object sitting in it.

### The middle ground is the thing that is always missing

Every frame in World 1 first landed as "a dark building on the left and bright haze on
the right, with nothing between them." The between is a pole line with catenary cables
and a conveyor gantry on legs, both starting behind the block and walking out into the
light so the eye has a way across. Build the bridge before you add more detail to either
end. A **catenary, never a straight line** — a straight cable is the fastest way to make
a skyline look untouched by gravity.

### Between-layer atmosphere

`GPUParticles3D` dust planes at roughly Z = +3, −9 and −22, `local_coords = false`,
drifting on the ghibli axis. They catch the key, and they are what makes the sun shafts
visible at all. Set `visibility_aabb` explicitly — the 8-unit default makes particles
vanish mid-effect under a scrolling camera and it is the most common particle bug in the
genre. A negative-density `FogVolume` ellipsoid parented to the camera carves a clear
pocket so the hero never hazes out while the background stays atmospheric; this is
strictly better than globally lowering the fog.

---

## 7. The hero: Wanis, the Libyan Gangsta

### Binding canon

- **White thobe.** The robe is the silhouette and it is the brightest value in every
  frame. Against a world capped at S 0.55 / V 0.72 this is a stronger readability lever
  than hue contrast, and it is why the saturated-red reservation belongs entirely to the
  shemagh and the Sriracha.
- **The shemagh** — deep madder red, over the shoulder and down the back. Velocity
  vector and silhouette-breaker: it breaks the body envelope by 40% of body width.
- **A fully automatic AK-pattern rifle**, part of the silhouette: slung across the back
  at rest, shouldered when firing. Built by `WeaponForge` — stamped receiver, wood
  furniture, gas tube above the barrel, and the curved magazine that carries the shape.
- **Moveset:** run, variable jump, double jump with a rotation flourish, Heat Dash, and
  the thobe glide — hold jump while falling and the robe fills like a parachute,
  flattening the descent to 3.4 u/s with wider lateral authority. **A distinct
  silhouette, not a slower fall.** Recoil is movement tech: fired airborne it pushes him
  opposite the aim, so firing down is a hover and firing up drops him faster.

### Palette

Applied with the dark-bottom placement rule: dark low, lighter and higher-chroma at the
chest, so he reads as grounded with a bright centre.

| Zone | Share | Hex | Notes |
|---|---|---|---|
| Thobe | 58% | `#F4F1EA` base, `#DCD6C8` shade, `#FFFDF6` sun | Cotton. Fine weave shaded in-shader, never textured. |
| Sirwal below the hem | 12% | `#999487` | The value step that keeps the hem line crisp. |
| Shemagh | 11% | `#9A1D16` base, `#5E120E` shade | The only saturated hue he carries. |
| Hair + beard + shades | 12% | `#0E0C0D` | The dark top mass. Matte, roughness 0.74. |
| Skin | 5% | `#BD8052` | Subsurface on. |
| Gold chain | 1% | `#F2BD42` | Metallic 1.0, roughness 0.16. The glint. |
| Sandals | 1% | `#57381F` | Oversized per the rule below. |

The Sriracha bottle sits at `#F03A16` with emission — hotter, brighter and smaller than
anything he wears, so the two never read as the same object.

### Proportions

**5.25 heads tall**, 1.78 m in world units, head 0.339 m. That band keeps face legibility
at gameplay scale (his head is 3.2% of screen height, so expression survives), supports a
real wardrobe, and clears both death zones: 3 heads reads as a licensed toy, 7 heads
loses mascot iconicity.

One exaggeration and one only: **the sandals and the feet in them are 1.35× scale.**
Everything else is honest. Low centre of gravity — lower leg shortened 6%, weight carried
forward, so landings read as weight and ground contact is never ambiguous. Shoulder width
1.95 head-widths (past life — at gameplay scale a realistic neck fuses head to torso),
waist 1.18, hands 1.15×.

### Silhouette

Three masses, and nothing else may compete.

1. **The head mass** — curly black hair, full and rounded, with shades pushed up on the
   forehead as a hard horizontal notch across its top third. Never over the eyes.
2. **The shoulder line** — the widest part of him, and straight, not sloped. In thobe
   state the robe carries it; the rifle crosses it diagonally at rest.
3. **The shemagh tail** — trailing cloth that moves independently, breaking the envelope
   by 40% of body width.

Plus the ground read: oversized sandals, 8% of the silhouette, locked to the player's eye
during platforming.

**Negative space is mandatory.** There is a gap between arm and torso in every idle pose
and a gap between the legs at jump apex. Solid blobs read as props. Asymmetry gets one
element — the left sleeve rolled higher than the right — and that is the whole budget.

### Costume, and its grounding

He is not a gangster. He ran the best sandwich cart in Benghazi and his own hot sauce
built it. He dresses like this because presentation is everything and because a man with
a gold chain gets served first. Explicitly **not** a keffiyeh and agal: that is a Gulf
and Levantine signifier and it is the clearest possible tell that someone researched
"Arab" rather than "Libyan."

No Amazigh motif appears on him. Amazigh geometry has a grammar — motifs sit at the
body's openings because that is where the evil eye enters — and a diamond on a shoulder
because it looks good is exactly the failure mode. If Amazigh design enters this game it
enters woven into cloth, struck into metal, or not at all.

### Secondary motion

Four systems, ranked. Nothing else moves.

1. **The shemagh tail** — Verlet chain solved in `_physics_process`. The hero's most
   important asset after the silhouette. Authored override curves on dash, hard landing
   and wall-kick, blending back to sim over ~10 frames: pure sim on a platformer's
   instantaneous velocity changes is the cheap look, pure hand-key is unaffordable, the
   blend is the expensive one.
2. **The gold chain** — shorter, stiffer Verlet chain. Deterministic and cheap, so it
   can never look wrong in a screenshot. Swings across the chest on turns, lifts on dash.
3. **Hem and cuffs** — spring chains driven by chest-bone acceleration. This is what
   sells the weight of a landing.
4. **Hair** — four chunky masses on short springs. No strands.

`WanisRig` drives the skeleton procedurally: poses are targets and bones ease toward
them, so overlap and follow-through come free. There is no keyframe data in the project
and no IK — in a side-on game the arms are posed to the rifle rather than the rifle
solved to the arms.

### Idle personality

He is bored, and being bored is a performance. Continuous: breathing at 0.28 Hz with a
shoulder counter-drift, weight shifting between feet every 4.5 s ± 1.2. At 7 s: one of
four fidgets, random without repeat — checks the chain and lets it drop, re-seats the
shades, rolls a shoulder, scuffs a sandal. At 19 s: the personality beat — he looks
off-screen at something the player cannot see, holds three seconds, and looks back
unimpressed. He is waiting for you. Contextual: leans over a ledge edge, leans a shoulder
on a wall, tugs the sash straight after a long sprint, checks the thobe for damage before
he checks himself. His single adjective is **unbothered**.

### State A — PRISON, and the transformation

Level 1 opens with everything stripped. It is a silhouette problem solved deliberately:
in prison state he has **one mass, not three.** Washed pale blue-grey two-piece uniform
`#8E96A0` at roughness 0.86, loose and shapeless so the shoulder wedge is gone. No
shemagh, no chain, no shades — **nothing trails, so nothing reads as velocity**, and the
player feels slow before the controller is ever slowed. Hair flattened and dust-matted.
Skin desaturated 22% with a grime mask heaviest at forearms and shins. The animation
layer runs a posture offset — spine flexed 6°, head dropped 4°, stride shortened 8% —
so the same physics reads as diminished.

**The transformation** is the confiscated-property cage at the exact moment the sun
clears the horizon: the level's unforgettable moment and the mechanic unlock in one beat.
The chain comes out first and catches the new sun — the first specular highlight in the
game, and nothing on screen is allowed to be brighter than it for those four frames. Then
the thobe on an authored 12-frame snap, then the shemagh unfurling on a curve before
handing to the sim, then the shades, then a dissolve-front wiping the grime off the skin
in world coordinates so it reads coherently across the whole body. Hit-stop, a bloom of
light, a slow-motion window, and the camera pushing in. The costume swap lands **on** the
flash, never before it. Opening the cage also changes the level: it spawns the drones the
next section is built around.

**Test:** reduce the first and last frames to pure black at 25% scale. The first must be
an unidentifiable single mass. The last must be unmistakably Wanis.

### A character in a marketing frame is never in the gameplay idle

The gameplay idle is symmetrical, which is correct in play and is a mannequin in a still.
`WanisRig.beauty_pose` is the authored alternative: weight on the back leg, hips tilted
toward the free leg, spine counter-curved, shoulders against the hips, head turned past
the shoulders. Every capture intended as a screenshot sets it.

---

## 8. UI

**Nothing in the UI is a themed `Control`.** A focused Godot `Button` draws a rectangle
with a blue outline, and that is the exact default look this project is not allowed to
have. `UIKit` draws cut-corner skewed slabs, letterspaced type, chevrons, rules and chain
pips; `MenuList` owns its own selection, input and drawing. Everything is `_draw`, so it
scales to any resolution and carries the game's shapes rather than the engine's.

Rules:

- **The HUD is minimal during gameplay.** Bottle, sandwich and chain glyphs are polygons.
  The HEAT gauge only asserts itself as it fills.
- **A ring beats a bar when the quantity is time.** The ice HUD is a count inside a
  closing timer ring, because a bar needs a label to say what it measures and a ring
  does not.
- **The title screen is the beauty benchmark.** `TitleScreen` extends `BregaBeauty`
  outright — same geometry, same colour script, same lighting — so the first frame of the
  game is literally the frame every level has to match, and the title can never look like
  a different game. Type sits in the left column behind a soft wedge of shade, and
  anything visually noisy is moved out of that column: a black tangle behind cream type
  is a fight neither side wins.
- **Arabic is laid out RTL and shaped.** `draw_string` lays out from `pos`, so a
  right-aligned box starts at the right edge *minus* its width. Getting this wrong puts
  the label a full text-box width off the slab, and it has happened once already.
- **Locked content is shown, not hidden.** Unbuilt levels are pinned on the world map and
  refuse entry with a red shudder, because the shape of the world is the promise.
- **Terrain colour on the map is soft-edged.** A shape of a second colour laid on a map
  reads as a sticker however irregular its outline; what sells it is the edge going away.
  Sabkha and the Jebel green are radial alpha falloffs generated at load, not polygons.

---

## 9. Implementation notes and pitfalls

Godot 4.7.2, Forward+, GDScript. Property names are exact.

### What the engine actually does today

| Area | Shipped | Note |
|---|---|---|
| Scene authoring | GDScript builders; `.tscn` files are thin wrappers | Levels are diffable and parameterised |
| Geometry | `LevelKit.chamfer_mesh` only, cached by size | No `BoxMesh` anywhere |
| Materials | `MaterialLab` + `surface_weathered` + `NoiseBank` | No texture files ship |
| Lighting | `LightingRig.Mood` → key / sky fill / bounce / rim / hero fill, plus `shafts()`, `ground_mist()`, `hero_pocket()`, `practical()` and a generated grade LUT | §5. `Mood.debug_describe()` prints exposure landings and warns when the key is hot |
| Quality tiers | `GraphicsDirector`, four tiers | It owns `directional_shadow_max_distance` (70 / 110 / 160 / 220), so express shadow splits as fractions. Tiers scale cost, never look |
| Sky | `ProceduralSkyMaterial`, installed by `LightingRig` | `SkyForge` + `shaders/sky.gdshader` exist as the replacement and **no level adopts them yet** |
| GI | **SDFGI**, 4 cascades, 0.2 min cell | See the open question below |
| Tonemap | AgX, exposure per level | `Environment.tonemap_white` is **ignored under AgX**; `Mood.white` is therefore inert. Grade with lights, not exposure |
| DOF | Off in both shipped levels | Near blur swallows the gameplay plane; separation is value and scale |
| Checkpoints | `Checkpoint` placed in both shipped levels | — |
| Ice pool | `IceBonus01`, `IceBonus02` | The warp draws from both |
| Water | `WaterKit` + `shaders/water.gdshader` | Built; **no level adopts it yet** |
| Detail library | `DetailKit` | Built; **nothing calls it yet** |

**Open question — GI.** SDFGI is camera-centred and streams cascades as the camera moves,
and our camera moves fast in X forever, so newly-streamed geometry is visibly dark for
several frames. The alternative is chained `VoxelGI` volumes baked at level load
(`VoxelGI.bake()` is exposed to scripting; `LightmapGI.bake()` is not, in any build, so
lightmaps are impossible for a headless code-authored project). Nobody has built the
chain yet. Whoever does: 8 VoxelGI nodes render at once and only 2 blend per pixel, so
space them so at most 2 overlap anywhere, and mark Wanis, enemies and every moving prop
`GI_MODE_DYNAMIC` or they bake in and leave ghost lighting behind them.

### Engine facts that cost a day each

- **Godot winds FRONT faces clockwise.** Emitting a quad counter-clockwise hides every
  outward face and leaves the inside of the box visible — and the inside of a backlit
  wall faces the sun, which is why the first chamfered box lit the whole level like noon.
- **A degenerate UV chart returns garbage tangents.** Mapping every face of a box with
  one formula gives the top and bottom faces a constant V; the garbage tangent that
  follows is enough to make the renderer light a back-facing wall as though it faced the
  sun. `LevelKit._planar_uv` picks the two axes the face does *not* point down.
- **`ProceduralSkyMaterial` draws a sun disc for every directional light.** Fill and rim
  lights were each painting a second and third sun into the sky. Non-shadow lights are
  `SKY_MODE_LIGHT_ONLY`.
- **`StandardMaterial3D.specular` is a Godot 3 property name.** Every specular tweak
  written against it was a silent no-op that also spammed the log. It is
  `metallic_specular`.
- **Procedural `ArrayMesh` has no tangents and no LODs.** Call
  `SurfaceTool.generate_tangents()` or normal maps are silently wrong; build through
  `ImporterMesh` and `generate_lods()` if you want `lod_bias` to do anything.
- **Skinned AABBs come from the rest pose.** Set `extra_cull_margin` ≈ 0.8 on every
  skinned mesh or the hero pops out of existence at a screen edge when a limb extends —
  which in a side-scroller is exactly when he enters frame.
- **A particle system whose emitter is buried under a scaled skeleton inherits garbage
  transforms.** The tracer pool owns its own placement for this reason.
- **`MultiMesh` has no per-instance frustum culling.** Set `transform_format` *before*
  `instance_count`, set `custom_aabb` explicitly, chunk by X and toggle `visible`.
- **`vertex_color_is_srgb` defaults false**, so code-authored hex vertex colours blow out.
- **MSAA does not antialias alpha-scissor foliage.** Use
  `ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE`.
- **The editor's preview sun and preview sky do not exist at runtime.** A scene that
  looks fine in a viewport renders black in a capture. Capture is the only truth.

### Check these first when a frame looks cheap

1. Constant roughness. Nothing else on this list matters if this one is true.
2. Ambient is black (`BG_CLEAR_COLOR` + `AMBIENT_SOURCE_BG` + black clear colour).
3. `glow_bloom > 0.0`, or `glow_levels/1-2` carrying energy.
4. `volumetric_fog_anisotropy` at the 0.2 default — no sun shaft will ever form.
5. `light_angular_distance = 0.0` — razor shadow edges at every distance.
6. `shadow_enabled = false`, which is the `Light3D` default.
7. `shadow_normal_bias = 2.0` default, detaching small props' shadows.
8. `ssil_radius = 5.0` default, bleeding the background onto the hero.
9. `Camera3D.near = 0.05` — z-fighting and poor SSAO/SSR/contact shadows.
10. `GPUParticles3D.visibility_aabb` left at the 8-unit default.
11. `gi_mode = GI_MODE_STATIC` on something that moves.
12. Fog doing the job that a value step between layers should be doing.

---

## 10. Terminology

Volumetric light shafts are called **sun shafts** or **light shafts** in this project.
**Never the other term.** This applies to code, comments, commit messages, documentation,
capture filenames and conversation, without exception and regardless of context.

Other fixed names: the hero is **Wanis**; the collectible is a **Sriracha bottle**; the
secret is the **Iced Out Sriracha**; the reward is a **chain**; the dust storm is a
**ghibli**; the salt flat is **sabkha**; the red interior sand is **Heix**.

---

## 11. The benchmark, and how a frame is judged

### The benchmark

**"FIRST LIGHT, EXERCISE YARD"** — `levels/brega/BregaBeauty.gd`. One screen at final
shippable quality. Every later level has to match or beat it, and the title screen *is*
it.

The moment: Wanis, still in prison grey, has come through the block door onto the raised
walkway above the exercise yard. The sun is two minutes from clearing the horizon behind
a dead fertiliser plant. He has stopped, because he can see the way out and it is a long
way off. He is not doing anything. That is correct — the shot is a held breath.

Composition: horizon at y ≈ 0.46, his feet at 0.62, his head at 0.44 so it **breaks the
horizon line**, which is what makes a small figure read as the subject. He stands a third
in from the left facing screen-right, so two thirds of the frame is the distance he has
to cover. The walkway rail runs a hard horizontal from the left edge and stops at a
broken post, and the eye falls off the end of it into the yard.

One standing deviation from the original brief, and it is the right call: the cell block
runs the **left 55% only** and stops just past him, instead of the full frame width. At
Z = −5 a 10 m block subtends more of the frame than a 71 m tower at Z = −300, so running
it full width buries every layer behind it. The left of frame is the prison he is
leaving; the right is the distance he has to cover.

Layers, front to back: razor wire and a dead casuarina at +9; chain-link at +5; the
walkway, rail, green door and the first two Srirachas at 0; the cell block facade with
the four-layer wall at −5; the yard, perimeter wall, pole line and windbreak at −14; the
pipe rack at −22; the plant bank at −26…−40; the tank farm at −75 with one burnt tank at
the golden section; the sabkha plain and the Gulf at −140; the prilling towers and the
flare stack at −300; the sky.

**The most eloquent object in the frame is the flare.** A plant that stopped running,
with one tip still burning and a plume leaning downwind — it is the focal point the right
of the image did not have, and the only motion big enough to read at that distance.

### The twelve details that make this Libya and not generic ruins

1. **Crane holes** — one circular hole at the centre of every prefab panel, most mortared
   shut, three knocked through. Nobody who has not been there invents this.
2. **The four-layer wall** — the level's whole political history, legible at once.
3. **The dead flare stack** — a cold black lattice with nothing burning on it.
4. **Prilling towers taller than any minaret** — a fertiliser plant is the skyline here.
   Getting that hierarchy right is the whole location.
5. **Two sands meeting** — red Heix against bone-white calcareous, pink-buff where they mix.
6. **Salt crust** — polygonally cracked, puffed and blistered, dark mud in the tyre ruts.
7. **A planted windbreak, dead in a straight line** — the irrigation stopped. A dead tree
   in a straight line is unmistakably planted.
8. **Sand depth as the abandonment map** — drifted over every dark sill, swept in a clean
   arc where the green door still swings.
9. **Salt spalling, not impact damage** — every spall at a slab edge, lintel or column
   base, with the brown crack stain arriving before the spall.
10. **The green steel door** — mid-blue and bottle-green doors are everywhere on this
    coast, and it is the only place the eye rests on the left.
11. **The sodium lamp still burning at dawn** — nobody turned it off because nobody is here.
12. **The straw-white horizon** — the sky does not go blue near the ground. This single
    decision is what stops the frame reading as Spain, Arizona, or nowhere.

### The quality gate

The standard is: **every screenshot must pass as an official marketing frame for a AAA
2026 release.** That is not a feeling; it is eight checks, and a frame fails if any one
of them fails.

1. **Value structure.** Desaturate the frame. There must be a clear dark mass, a clear
   mid, and a clear light, and the hero must sit at the top of the range. No pixel is
   pure black or pure white; the darkest shadow sits in the `#6B5F55` family by day,
   `#2A3A56` by night. If the greyscale is one grey soup, nothing else will save it.
2. **Silhouette density.** Every important object reads as a shape at 25% scale with the
   image reduced to black. If a thing only exists because of its surface detail, it does
   not exist.
3. **Colour discipline.** One level-unique hue, present. The chroma law held (§2). No
   saturated accent anywhere except the three named exceptions. Shadow is not grey.
   Aerial perspective is warm.
4. **Focal point.** Exactly one, and you can say what it is in four words. Nothing else in
   the frame out-values or out-saturates it. The eye does not go to the sun first — a
   bright blob doing no storytelling is a failure, not a light source.
5. **Foreground / mid / background.** Content in six of the nine layers, and the middle
   ground is not empty. Foreground is sized to the near frustum and does not black out
   the image. Layer separation comes from value steps, not from fog.
6. **Storytelling detail.** At least three things in the frame say what happened here and
   who used to live here. Not decoration: evidence. Weathering obeys gravity, aspect, wind
   and occupancy.
7. **Edge treatment.** No perfect ninety-degree edges. Chamfers catch the key. Nothing
   ends in mid-air. Nothing important is under 70 mm. Cables are catenaries.
8. **Motion.** At least three independent things move, and at least one of them is a
   DRAPE element. A still frame of a dead world is still a dead world.

### How to judge your own capture

In this order. Do not skip to the last question — everyone wants to, and the first three
are where frames actually fail.

1. **Squint, or desaturate it.** What are the three big value masses? If you cannot name
   them, stop and fix the lighting. Nothing below this line matters yet.
2. **Where does your eye go first, before you decide?** Say it out loud. If the answer is
   "the sun", "a bright patch of ground" or "I don't know", the frame has no subject.
3. **Reduce it to black at 25%.** Does the hero read? Does the composition — the
   horizontals, the landmark verticals, the diagonal that points at him? If the answer is
   no, the problem is shape, not shading.
4. **Cover the hero with your thumb.** Is the rest of the frame still a place? Is there
   still something happening in the middle ground? A frame that only works because
   somebody is standing in it is a backdrop.
5. **Count the layers.** Six or it goes back. Then ask what each one is doing that its
   neighbours are not — if two adjacent layers have the same value, they are one layer.
6. **Find the brightest pixel and the most saturated pixel.** Are they where you meant
   them to be? Is either of them something you did not choose?
7. **Follow the water.** Pick three fittings and check that something runs down from each.
   Check the streaks fade sideways as well as down. Check the grime starts at the ground
   the level actually has, not at y = 0.
8. **Look at every edge that catches the key.** Are they chamfers or are they corners? Is
   any top chamfer reading as white icing? Is any ninety-degree edge left?
9. **What is moving?** Name three. Name the DRAPE one.
10. **What does this tell you about the people?** If the answer is nothing, add a lit
    window, a swept threshold, a laundry line or a light somebody left on before you add
    another pipe.
11. **Would you put it on a store page?** Only now. And if the honest answer is "it is
    much better than it was", that is a no — write down what is still wrong in
    `docs/PROGRESS.md` and go again.

### Acceptance criteria for the benchmark specifically

1. Reduced to pure black at 25%, the hero reads as a single ambiguous human mass —
   correct for prison state — and the composition still reads: rail, wall, towers, stack.
2. Content present in at least seven of the nine depth layers.
3. No pixel pure black or pure white.
4. The sun shafts through the pipe rack are visible without being pointed out.
5. His feet are unambiguously on the deck at 100% zoom.
6. At least three independent things in motion.
7. A stranger shown the frame with no context says "somewhere on the North African
   coast," not "a desert" and not "a ruin."

Anything less and it goes back. This frame sets the bar for four more levels and a boss.
