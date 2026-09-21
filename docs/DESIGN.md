# LIBYAN GANGSTAS — Creative Bible

This document is canon. The **Game Canon** section is fixed by the brief and must
not change. Everything after it is a decision made by this project; decisions
here are binding until deliberately revised, and revisions get written down.

---

## PART I — GAME CANON (fixed, do not change)

### Title
LIBYAN GANGSTAS

### Setting
Libya, specifically the eastern region. The levels are real places, and each must
be recognizable and full of local flavor: architecture, streets, landscapes,
signage in Arabic, cars, food, everyday life, and culture. A larger-than-life,
affectionate love letter to Libya, never a mockery of it.

### Protagonist
The Libyan Gangsta.

### Collectibles and lives
- **SRIRACHA BOTTLES** are the main collectible, in the same role bananas play in
  Donkey Kong Country: placed in trails, arcs, and clusters that guide the player
  through the level. Original bottle design — no real brand's label, logo, or rooster.
- **TUNA SANDWICH** = one extra life.

### Secret bonus levels: the Iced Out system
- Each main level hides exactly ONE **ICED OUT SRIRACHA** (diamond-encrusted,
  glowing). Hidden well enough to reward exploration, always fair to find.
- Touching it warps the player to a random **ICE bonus level**: frozen, icy,
  glittering, chill-themed. A pool of distinct ice levels to draw from.
- Inside, the player collects **100 ICE SRIRACHAS**.
- Collecting all 100 awards one **ICED OUT LIBYAN GANGSTA CHAIN**. 1 chain per
  level, so 5 in World 1.
- The warp-in, the bonus level, and the chain reward are spectacular, celebratory
  moments. Chains are tracked in the save file and shown in a collection screen.

### World 1 (build in this order)
1. **BREGA PRISON BREAKOUT** — opening level, cinematic opening, teaches movement.
2. **AJDABIYA**
3. **HIGHWAY TO BENGHAZI** — vehicle level, high speed, jumps, gaps, set pieces.
4. **GARYOUNIS UNIVERSITY**
5. **BENGHAZI** — World 1 finale, biggest and most spectacular, ends in a boss.

Each level: 1 hidden Iced Out Sriracha, Sriracha trails throughout, tuna
sandwiches as rewards, checkpoints, and at least one unforgettable moment.

---

## PART II — DECISIONS

### The hero: WANIS

**Name.** Wanis (ونيس). Short, punchy, unmistakably Libyan, reads in both scripts.
Everyone calls him *the Libyan Gangsta*; nobody calls him that to his face.

**Who he is.** Wanis ran the best sandwich cart in Benghazi. The tuna sandwich was
good. The hot sauce was better, and it was his — his own recipe, his own bottles,
made in his aunt's kitchen in Ajdabiya. He is not actually a gangster. He carries
himself like one because he believes presentation is everything, and because a man
with a gold chain gets served first.

**Look.** Broad shoulders, narrow waist, light on his feet. Short beard, curly
black hair, aviator shades pushed up on his forehead — never over his eyes,
because the audience needs to read his expression. A red jacket, sleeves shoved
up. A cream tank underneath. A gold chain. A shemagh knotted at the waist as a
sash that trails behind him, which is where all the follow-through lives.
And sandals — *shibshib*. He does the entire game in sandals. This is the joke
and it is also the point: he is exactly as unbothered as he looks.

**Two states.** Level 1 opens with him in a grey prison uniform, stripped of
everything. Midway through Brega he breaks open the confiscated-property cage and
gets his gear back. That is the level's unforgettable moment: a full costume
transformation that is *also* the mechanic unlock, in one beat.

**Silhouette rule.** Shoulder line, chain, trailing sash. If a frame is reduced to
pure black, those three things must still say who he is.

**Idle personality.** He does not stand still. He checks his chain. He looks off
at something. He adjusts the sash. He is bored, and being bored is a performance.

### Signature mechanics

Two, and only two, that belong to nobody else.

**1. HEAT DASH.** A committed horizontal dash, on the ground and in the air, one
air-dash per airtime, refunded on landing. It preserves momentum on exit rather
than dumping it, and a buffered jump during the dash cancels into a dash-jump that
keeps the speed — that is the movement ceiling and the thing good players will
chain. Collected Sriracha fills a **HEAT** gauge; at full heat the next dash is a
**BLAZE DASH**: faster, longer, invulnerable, breaks what normal dashes cannot,
and costs the whole gauge. Collectibles feed spectacle. The gauge is the reason to
take the risky Sriracha line.

**2. CHAIN WHIP.** He takes the chain off and uses it. Short-range attack for
combat, and a grapple on anchor points for traversal — one input, two uses,
context decides. Unlocked at the Brega transformation, so the second half of
Level 1 teaches it and the rest of World 1 escalates it.

Nothing else ships unless a level's design genuinely needs it.

### Collectible rules
- 100 Sriracha bottles → one extra life. The count persists across a run, not a level.
- 30 Sriracha → one full HEAT gauge. Heat is spent, lives are not.
- Tuna sandwich → one extra life, placed as a reward for a risk, never on the path.
- One Iced Out Sriracha per level → warps to a random ice bonus level.
- 100 Ice Srirachas inside → one Chain. 5 chains in World 1.

### Story
Boss **Taher** runs freight on the eastern coast road and decided Wanis's sauce was
a business he wanted. When Wanis refused to sell, a shipment went missing, some
paperwork appeared, and Wanis went to prison in Brega.

1. **Brega Prison Breakout** — he gets out, and he gets his jacket back.
2. **Ajdabiya** — his aunt's kitchen. The recipe. The first crates.
3. **Highway to Benghazi** — Taher's convoy, and a car that should not be doing this speed.
4. **Garyounis University** — the operation is running out of a campus building, because nobody searches a campus.
5. **Benghazi** — the old city, the Corniche, and Taher.

It is a revenge story about a sandwich cart. It is played completely straight.

### Audio identity
Malouf-derived modes and North African percussion against a modern low-end.
The Heat Dash has a *darbuka* hit in it. Every collectible sound is pitched up the
scale as the trail continues, so a Sriracha line is a melodic phrase.

---

## PART III — ART DIRECTION

**`docs/ART_DIRECTION.md` is the canon art-direction document.** It holds the visual
pillars, the World 1 colour script, shape-language and material rules, Wanis's complete
design in both costume states, the nine-layer depth recipe, the Godot implementation
spec, and the Level 1 beauty benchmark build order. It supersedes any art guidance
elsewhere in this file and defers to Part IV below on camera geometry and controller feel.

The three decisions that govern everything else:

1. **World 1 is one day** — sunrise (Brega) → mid-morning ghibli (Ajdabiya) → hard
   afternoon (Highway) → golden hour (Garyounis) → night (Benghazi). That is the only
   cohesion device the five levels need.
2. **Each level owns exactly one unique hue**, and the five occupy five different hue
   families: regime green, sabkha terra rossa, oleander pink, the gold dome, copper patina.
3. **Wanis is the only saturated thing in the frame.** World-surface albedo is capped at
   HSV S 0.55 / V 0.72 inside hue 340°–25°; that band belongs to the jacket and the
   Sriracha alone. Danger is signalled with hazard chevrons and a white flash, never red.

Colour script board: `docs/screenshots/2026-09-21_world1-colour-script.svg`

---

## PART IV — TECHNICAL CANON

### Authoring model
**Every scene is built by a GDScript builder, not a hand-edited `.tscn`.** `.tscn`
files are thin wrappers: a root node and a script. Levels are code, which makes
them diffable, parameterised, reviewable, and fast to iterate without a GUI editor.
`scripts/level/LevelKit.gd` is the vocabulary those builders speak.

### The 2.5D contract
Gameplay is 2D, locked to the X/Y plane at Z=0. Presentation is fully 3D. The
camera is side-on at Z=+16 with a 34° FOV — enough perspective to get parallax and
real depth, tight enough that the gameplay plane stays readable. The controller
zeroes `velocity.z` and snaps `position.z` every physics step; nothing in gameplay
is allowed to leave the plane.

### Controller feel spec
These numbers are the feel. Changing one changes the game.

| Property | Value | Why |
|---|---|---|
| Max run speed | 9.2 u/s | Reaches top speed in ~0.11 s — snappy, not twitchy |
| Ground accel / decel | 82 / 104 | Decel faster than accel: clean stops |
| Turn accel | 165 | Turning is nearly twice as sharp as accelerating |
| Air accel / decel / turn | 54 / 16 / 98 | Strong air control, but momentum is preserved |
| Jump height / time to apex | 3.15 u / 0.375 s | Derives gravity 44.8, jump velocity 16.8 |
| Fall gravity multiplier | 1.78 | Down is faster than up. Always |
| Apex gravity multiplier | 0.62 below 2.6 u/s | The hang. Makes a jump read as generous |
| Jump cut multiplier | 0.42 | Variable height on release |
| Coyote time | 0.11 s | Forgiveness off a ledge |
| Jump buffer | 0.13 s | Forgiveness before landing |
| Jump horizontal kick | 0.7 u/s | Jumping out of a run is committed |
| Dash speed / time | 23 u/s / 0.165 s | ~3.8 u of travel |
| Dash exit speed | 12.5 u/s | Exits *faster* than run speed — the reward |
| Blaze Dash | 30 u/s / 0.22 s | Costs a full HEAT gauge |
| Max fall speed | 34 u/s | Terminal velocity |

Corner correction nudges a rising jump sideways by up to 0.34 u when it clips a
ledge lip, because "I definitely cleared that" must be true.

### Verification contract
Nothing is done until it has been through `tools/capture.sh` and the frames have
been looked at. `--input=auto` runs a geometry-driven traversal autopilot: it runs
right, jumps what it cannot walk through, dashes what it cannot jump. If a level
edit makes a section impassable, the autopilot stops advancing and the manifest
shows exactly where. That is the automated playtest.
