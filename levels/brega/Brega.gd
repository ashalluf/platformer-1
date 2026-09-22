extends Stage
## LEVEL 1 — BREGA PRISON BREAKOUT.
##
## Six sections, built in the order the player meets them. Each one introduces
## exactly one thing and then asks for it again in a harder shape.
##
##   A  THE WALKWAY      run, jump, Sriracha trails            prison grey
##   B  THE YARD         double jump, the first SNITCH
##   C  THE PIPE RACK    the thobe glide, over a long drop
##   D  PROPERTY CAGE    the transformation. Thobe, chain, rifle.
##   E  THE TANK FARM    vertical aim and run-and-gun
##   F  THE FENCE        dash-glide chains, and out
##
## The hidden Iced Out Sriracha is in section E, behind the burnt tank: visible
## from the approach for about a second, reachable only by gliding off the
## catwalk instead of landing on it.
##
##
## ---------------------------------------------------------------------------
## STAGING — what this level is telling you happened
## ---------------------------------------------------------------------------
##
## A man got out of a cell about four minutes ago and the plant has not caught
## up with it yet. That is the only story note, and every section carries one
## piece of physical evidence for it, placed where the eye already is:
##
##   A  the green door forced from the inside, the bar he did it with still on
##      the deck, a dropped meal tray, his lost slide, a knotted bedsheet off
##      the roof parapet, cell doors standing open down the block, files blown
##      along the walkway, a sheared conduit venting, and the amber alarm
##      beacon still turning above the door.
##   B  the guard tower searchlight sweeping an empty yard, the gate office
##      turned over — desk on its side, cabinet emptied, paper across the
##      sabkha — and the delivery truck abandoned half-unloaded.
##   C  a relief valve venting into the rack, snagged bags in the steel, and
##      the gantry that came down years before any of this.
##   D  the property store: the hasp cut, the door standing open, a trolley
##      tipped, a trail of other men's confiscated belongings across the floor
##      leading to the one cage that matters.
##   E  the truck that burned where it stopped, and a catwalk hanging off its
##      bolts pointing down into the dark.
##   F  the wire pushed back and a strip of prison cloth left on it.
##
##
## ---------------------------------------------------------------------------
## LANDMARKS — navigational anchors, with their x positions
## ---------------------------------------------------------------------------
##
## A 400-unit run needs things you can name to yourself. Each of these is in
## the mid or deep layer, tall enough to be visible for 40-70 units of travel,
## and each one is the only object of its kind in the level — repeat one and it
## stops being a landmark and becomes wallpaper.
##
##   x =  62   THE WATER TOWER       four splayed legs, "ماء" on the belly
##   x = 138   THE COLLAPSED GANTRY  a conveyor span down in the yard, nose in
##   x = 206   THE PROPERTY STORE    the only warm-lit interior in the level
##   x = 258   TANK 7                the unit number, two storeys tall
##   x = 296   THE BURNT-OUT TRUCK   nosed into a bund wall, still black
##   x = 338   THE WIRE BREACH       the hole someone else already made
##   x = 376   THE GATE              the way out
##
##
## ---------------------------------------------------------------------------
## READABILITY — the one rule, applied everywhere
## ---------------------------------------------------------------------------
##
## The backdrop is deliberately busy and the key is behind it, so every surface
## the player can stand on is in shade against a bright haze. Silhouette alone
## will not carry it. So:
##
##   1. EVERY standable leading edge carries a painted nosing — a 130 mm band
##      of sun-faded hazard ochre along the front face, with four black
##      chevron blocks over the last 1.8 m at each end. Continuous band =
##      "this is floor". Broken into chevrons = "this is where it stops, jump."
##      That is the whole language and it is the same on concrete, steel and
##      sabkha. `_nose()` applies it; `_deck()` guarantees no deck can be built
##      without it.
##   2. NOTHING else in the play band is allowed to present a flat horizontal
##      top within 0.6 m of a real platform height. Dressing either sits behind
##      z = -1.8, in front of z = +2.2, or lies flat on a deck that is already
##      standable.
##   3. Foreground dressing is always in the near-black register (`mats.dark`).
##      The camera-facing side of everything in this level is in shade, so a
##      foreground object that is merely "dark grey" reads as mid-ground.

const YARD_Y: float = BregaKit.YARD_Y
const DECK_Y := 0.0
const X_START := -14.0
const X_END := 384.0

## Landmark anchors — see the header. Kept as constants so the dressing, the
## trails and any future signposting all read from one place.
const LM_WATER_TOWER := 62.0
const LM_COLLAPSED_GANTRY := 138.0
const LM_PROPERTY_STORE := 206.0
const LM_TANK_SEVEN := 258.0
const LM_BURNT_TRUCK := 296.0
const LM_WIRE_BREACH := 338.0
const LM_GATE := 376.0

## The property store's interior volume. Section D is the only interior in the
## level and half its dressing depends on these three numbers agreeing.
const STORE_FLOOR: float = YARD_Y + 4.6
const STORE_BACK_Z: float = -3.4
const STORE_SOFFIT: float = STORE_FLOOR + 4.0

var mats := {}
var dress := {}
var _cage: PropertyCage


func _ready() -> void:
	level_id = "brega"
	level_title = "BREGA PRISON BREAKOUT"
	spawn_point = Vector3(-8.0, 1.4, 0.0)
	kill_plane_y = -30.0
	player_outfit = WanisBuilder.Outfit.PRISON
	music_theme = ""   # no score: the game runs on ambience and SFX alone
	use_camera_bounds = true
	camera_bounds_min = Vector2(X_START + 6.0, -14.0)
	camera_bounds_max = Vector2(X_END - 6.0, 34.0)
	super._ready()
	camera.height_offset = 2.15
	camera.lateral_offset = 1.6


func _mood() -> LightingRig.Mood:
	return BregaKit.mood()


## The level is played against the sky for its whole length — every gap in the
## plant is a hole with dawn behind it. A two-stop gradient cannot carry that.
## SkyForge reads the scene's own key light, so the disc, the warm band round
## it and the aerial haze all land wherever the rig aimed the sun — the sky and
## the lighting cannot drift apart.
func _sky_preset() -> String:
	return "brega_sunset"


func _build_level() -> void:
	mats = BregaKit.palette()
	dress = _dress_palette()
	BregaKit.deep_layers(geometry, mats, X_START, X_END)
	BregaKit.mid_layers(geometry, mats, X_START, X_END)
	_section_a_walkway()
	_section_b_yard()
	_section_c_pipe_rack()
	_section_d_cage()
	_section_e_tank_farm()
	_section_f_fence()
	_layer_green()
	_atmosphere()


## The staging palette: everything the environment kit does not already carry.
## Kept separate from `mats` so it is obvious at a glance which colours belong
## to the place and which belong to the story being told on top of it.
func _dress_palette() -> Dictionary:
	return {
		# Plant nosing paint. Sun-killed ochre, not a warning yellow: this is
		# paint that was applied in 1979 and has been in the salt ever since.
		"hazard": MaterialLab.painted_metal(Color(0.455, 0.335, 0.088), 1.0),
		"chevron": MaterialLab.painted_metal(Color(0.048, 0.046, 0.044), 0.9),
		# Paper reads as value, not as detail — it is the only near-white in
		# the world layer and it is what makes "turned over" legible.
		"paper": MaterialLab.plaster(Color(0.560, 0.540, 0.495), 0.25),
		"paint": MaterialLab.plaster(Color(0.600, 0.575, 0.530), 1.0),
		"cloth": MaterialLab.cloth(Color(0.515, 0.495, 0.455), 0.95),
		"prison_cloth": MaterialLab.cloth(Color(0.300, 0.325, 0.355), 0.92),
		"leather": MaterialLab.cloth(Color(0.230, 0.150, 0.088), 0.82),
		"tin": MaterialLab.painted_metal(Color(0.300, 0.305, 0.315), 0.55),
		"plastic": MaterialLab.painted_metal(Color(0.145, 0.230, 0.255), 0.85),
		"dado": MaterialLab.plaster(Color(0.150, 0.178, 0.205), 1.0),
		"interior": MaterialLab.plaster(Color(0.208, 0.186, 0.160), 1.0),
		"burnt": MaterialLab.concrete(Color(0.062, 0.052, 0.048), 0.4),
		"amber": MaterialLab.emissive(Color(1.0, 0.66, 0.15), 2.6),
		"bulb": MaterialLab.emissive(Color(1.0, 0.80, 0.52), 5.0),
	}


## Planting.
##
## The benchmark scene has had a full green layer since it was built; the level
## you actually play had none, because its only greenery was the windbreak and
## that was drawn with PropKit spheres. Everything here is FoliageKit: real leaf
## geometry, wind shader, MultiMesh-batched per species.
##
## The rule for a refinery on the Gulf of Sidra is that nothing grows where it
## was not planted or where it was not left alone. So: municipal rows along the
## approach roads, scrub only where a slab edge or a bund has collected enough
## windblown sand to hold a root, and one bougainvillea at the gatehouse — the
## single saturated note in a level otherwise made of rust and ochre, placed at
## the exit so it reads as the world outside.
func _layer_green() -> void:
	var green := Node3D.new()
	green.name = "Planting"
	geometry.add_child(green)

	# The administrative frontage: a council-planted row behind the perimeter,
	# running the length of the plant. Whitewashed feet, which is both accurate
	# and the cheapest way to put a bright value at every trunk base.
	FoliageKit.street_trees(green, Vector3(-6.0, YARD_Y, -27.5),
		Vector3(196.0, YARD_Y, -27.5), 12.5, {
			"seed": 41, "gap": 0.16, "jitter": 1.1, "whitewash": true,
			"shadows": false,
			"mix": {"date_palm": 0.58, "fan_palm": 0.26, "ficus": 0.16},
		})

	# A second, deeper and taller row past the property store, seen through the
	# gap the second block leaves at 218..236. Two rows at different depths and
	# scales is what stops planting reading as one cut-out band.
	FoliageKit.street_trees(green, Vector3(204.0, YARD_Y - 1.4, -38.0),
		Vector3(320.0, YARD_Y - 1.4, -38.0), 16.0, {
			"seed": 47, "gap": 0.22, "jitter": 1.8, "whitewash": false,
			"shadows": false,
			"mix": {"date_palm": 0.46, "fan_palm": 0.54},
		})

	# Scrub only at the junctions — where the yard slab meets the perimeter,
	# and along the bund toes. Two flat planes meeting at a hard line is the
	# most artificial edge in the level and this is what softens it.
	FoliageKit.scrub_band(green, Vector3(-10.0, YARD_Y, -19.2),
		Vector3(384.0, YARD_Y, -19.2), 0.22, {
			"seed": 53, "band": 1.4, "min_gap": 2.2, "shadows": false,
			"mix": {"grass": 0.50, "tamarisk": 0.30, "prickly_pear": 0.20},
		})

	# The near verge, in the gameplay band. Sparse and low so it never covers a
	# ledge edge, but close enough that it reads as individual leaves rather
	# than as mass — which is the whole reason to have foliage this close.
	FoliageKit.scrub_band(green, Vector3(8.0, YARD_Y, 5.4),
		Vector3(300.0, YARD_Y, 5.4), 0.10, {
			"seed": 59, "band": 0.9, "min_gap": 4.0,
			"mix": {"grass": 0.44, "prickly_pear": 0.38, "tamarisk": 0.18},
		})

	# The one saturated magenta the palette allows, over the gatehouse wall.
	# It is the last thing before the exit and it is the first colour in the
	# level that was not put there by corrosion.
	FoliageKit.bougainvillea(green, Vector3(LM_GATE - 9.0, YARD_Y + 4.2, -4.6),
		Vector3(LM_GATE + 3.0, YARD_Y + 4.6, -4.6), {"seed": 67, "density": 1.15})


# --- A — THE WALKWAY --------------------------------------------------------
# He starts where the benchmark shot is framed. Flat, safe, and the first trail
# is a straight line at chest height: hold right.
#
# Dressed as the last four minutes of the breakout, front-loaded: everything in
# the first fifteen units is evidence, because that is the stretch the player
# spends standing still learning the controls and looking around.

func _section_a_walkway() -> void:
	PropKit.prefab_facade(geometry, X_START - 40.0, YARD_Y, 74.0, 10.6, -5.0,
		mats["slab"], {
			"name": "CellBlock", "joint_mat": mats["joint"], "dark_mat": mats["dark"],
			"hole_mat": mats["joint"], "depth": 5.0, "open_holes": 3,
		})
	# The wall the player spends the opening minute looking at.
	DecalKit.scatter_on_wall(geometry, X_START - 40.0, YARD_Y, 74.0, 10.6, -5.0, {
		"preset": "plant", "density": 1.2, "name": "CellBlockWeather",
		"graffiti": 0.40,
	}, 4021)
	DecalKit.run_off(geometry, X_START - 40.0, YARD_Y + 10.6, 74.0, -5.0, {
		"length": 3.1, "width": 0.30, "clusters": 10,
	}, 4022)
	LevelKit.prop(geometry, Vector3(34.0, YARD_Y + 5.3, -5.0), Vector3(0.5, 10.6, 5.2),
		mats["joint"], "BlockEndWall")

	# The wall: regime green, a slogan, a crossing-out, a tricolour.
	var gx := -2.0
	LevelKit.prop(geometry, Vector3(gx, YARD_Y + 9.6, -2.46), Vector3(8.6, 1.9, 0.10),
		mats["green"], "RegimeGreenField")
	PropKit.sign(geometry, "التقدم للجميع", Vector3(gx, YARD_Y + 9.95, -2.40), 0.62,
		MaterialLab.plaster(Color(0.62, 0.60, 0.56), 1.0), PropKit.FONT_NASKH_BOLD)
	LevelKit.prop(geometry, Vector3(gx, YARD_Y + 9.7, -2.36), Vector3(8.2, 0.17, 0.06),
		MaterialLab.plaster(Color(0.105, 0.098, 0.090), 1.0), "CrossOut")
	var tri := [Color(0.400, 0.145, 0.125), Color(0.105, 0.098, 0.090), Color(0.165, 0.318, 0.212)]
	for i in 3:
		LevelKit.prop(geometry, Vector3(gx + 1.4, YARD_Y + 8.85 + i * 0.40, -2.32),
			Vector3(3.4, 0.38, 0.05), MaterialLab.plaster(tri[i], 1.0), "Tricolour%d" % i)
	PropKit.sandbag_row(geometry, -14.0, YARD_Y + 10.6, 16.0, -3.6, mats["bag"], 2)

	PropKit.walkway(geometry, X_START - 20.0, DECK_Y, 68.0, 0.0,
		mats["deck"], mats["rail"], mats["rebar"], [3, 4, 9])
	# The walkway is the first floor the player ever stands on, so it gets the
	# same nosing language as every deck after it — taught here, obeyed there.
	_nose(X_START - 20.0, DECK_Y, 68.0, 0.60)
	LevelKit.prop(geometry, Vector3(33.2, DECK_Y + 0.42, 0.55), Vector3(0.07, 0.84, 0.07),
		mats["rail"], "BrokenPost")

	# The green door he came through.
	var door := LevelKit.prop(geometry, Vector3(-11.2, DECK_Y + 1.02, -2.10),
		Vector3(0.96, 2.06, 0.06), mats["door"], "GreenDoor")
	door.position += Vector3(0.42, 0.0, 0.30)
	door.rotation.y = -1.05
	LevelKit.prop(geometry, Vector3(-11.6, DECK_Y + 1.05, -2.35), Vector3(1.25, 2.30, 0.28),
		mats["joint"], "DoorJamb")
	PropKit.sign(geometry, "خطر", Vector3(-9.8, DECK_Y + 1.60, -2.38), 0.22,
		MaterialLab.plaster(Color(0.10, 0.09, 0.08), 1.0), PropKit.FONT_KUFI)

	_a_forced_door()
	_a_evidence()
	_a_frame()

	TrailBuilder.line(geometry, Vector3(-3.0, DECK_Y + 0.8, 0.0),
		Vector3(11.0, DECK_Y + 0.8, 0.0), 8)
	# The walkway is 68 units long and the original trail stopped at x = 11,
	# which left twenty units of empty deck with nothing pulling the eye along
	# it. A slow shallow wave carries the read to the step-down.
	TrailBuilder.curve(geometry, Vector3(15.0, DECK_Y + 0.8, 0.0),
		Vector3(30.0, DECK_Y + 0.8, 0.0), 0.75, 8)
	# First gap: two steps down onto crates, so a miss is survivable.
	# Steps down off the end of the walkway into the yard. Crates, not a drop,
	# because this is the first time the floor moves and it should not punish.
	_crate_stack(Vector3(38.6, DECK_Y - 1.7, 0.0), 2)
	_crate_stack(Vector3(42.2, DECK_Y - 3.6, 0.0), 1)
	TrailBuilder.curve(geometry, Vector3(34.4, DECK_Y + 0.9, 0.0),
		Vector3(39.0, DECK_Y + 0.4, 0.0), 1.0, 6)


## The door, and the four objects that say how it opened. All of them are inside
## the first camera frame of the game, because that frame is the only one the
## player will study.
func _a_forced_door() -> void:
	# The bar he levered it with, dropped where he dropped it. Bent, because a
	# straight one would read as a prop on a shelf.
	var bar := LevelKit.prop(geometry, Vector3(-9.35, DECK_Y + 0.07, -0.34),
		Vector3(1.35, 0.055, 0.055), mats["rebar"], "PryBar")
	bar.rotation = Vector3(0.0, 0.42, 0.10)
	LevelKit.prop(geometry, Vector3(-8.66, DECK_Y + 0.09, -0.24),
		Vector3(0.34, 0.05, 0.05), mats["rebar"], "PryBarTip").rotation = Vector3(0.0, 0.92, 0.34)

	# The hasp and its padlock, torn out of the jamb with the screws still in.
	LevelKit.prop(geometry, Vector3(-10.1, DECK_Y + 0.05, -0.62),
		Vector3(0.22, 0.05, 0.09), mats["steel"], "TornHasp").rotation.y = 0.7
	LevelKit.prop(geometry, Vector3(-10.35, DECK_Y + 0.08, -0.55),
		Vector3(0.12, 0.14, 0.05), mats["steel"], "Padlock").rotation.z = 0.5

	# Splintered jamb where the lock was, showing pale concrete under the paint.
	LevelKit.prop(geometry, Vector3(-11.02, DECK_Y + 1.05, -2.28),
		Vector3(0.16, 0.34, 0.09), dress["paint"], "JambBreak")

	# A meal tray and its mug, dropped and kicked. The tray landed face down —
	# that reads at a glance, a tray the right way up reads as a table.
	var tray := LevelKit.prop(geometry, Vector3(-6.45, DECK_Y + 0.05, -0.28),
		Vector3(0.62, 0.045, 0.44), dress["tin"], "MealTray")
	tray.rotation = Vector3(0.0, 0.55, 0.13)
	_cyl_prop(geometry, Vector3(-5.92, DECK_Y + 0.09, -0.12), 0.075, 0.13,
		dress["tin"], "Mug", Vector3(PI * 0.5, 0.0, 0.3), 10)
	LevelKit.prop(geometry, Vector3(-6.05, DECK_Y + 0.025, -0.44),
		Vector3(0.52, 0.012, 0.38), dress["interior"], "Spill").rotation.y = 0.3

	# The broken plastic slide he keeps losing. It is a running gag and it is
	# also the clearest possible "a person came through here at speed".
	LevelKit.prop(geometry, Vector3(-4.1, DECK_Y + 0.05, 0.22),
		Vector3(0.31, 0.055, 0.13), dress["plastic"], "LostSlide").rotation = Vector3(0.0, 1.1, 0.0)

	# The alarm. Nobody has come to turn it off, which is the good news.
	_beacon(Vector3(-10.4, DECK_Y + 2.62, -2.30), 2.4, 5.0)

	# A conduit sheared off the wall when the door went, venting a thin white
	# feather into the beacon light. Behind the play plane and away from the
	# running line, so it never reads as a hazard.
	LevelKit.prop(geometry, Vector3(-12.4, DECK_Y + 1.50, -2.34),
		Vector3(0.10, 0.90, 0.10), mats["rust"], "ShearedConduit").rotation.z = 0.24
	_vapour(Vector3(-12.2, DECK_Y + 1.95, -2.30), Vector3(0.55, 1.0, 0.0), 38, 0.30)


## Everything further down the walkway. Spaced on a long rhythm so the player
## discovers one thing per two seconds of running rather than a pile at once.
func _a_evidence() -> void:
	# Cell doors standing open down the block: the same green as his own door,
	# swung out of the facade at different angles. Nine units apart, which is
	# about one per screen.
	for i in 5:
		var x := -26.0 + i * 9.4
		var d := LevelKit.prop(geometry, Vector3(x, YARD_Y + 5.6, -2.34),
			Vector3(0.90, 1.95, 0.05), mats["door"], "CellDoor%d" % i)
		d.rotation.y = -0.55 - fmod(float(i) * 0.37, 0.75)
		LevelKit.prop(geometry, Vector3(x - 0.55, YARD_Y + 5.6, -2.48),
			Vector3(1.18, 2.18, 0.22), mats["joint"], "CellJamb%d" % i)

	# The knotted bedsheet, off the roof parapet past the fourth cell door.
	# This is the DRAPE element section A owes, and the one piece of staging in
	# the level that is a plan rather than a mess.
	_bedsheet(Vector3(15.6, YARD_Y + 10.5, -2.60), 4.1)

	# Files blown along the deck and up against the toe plate. The only near
	# white in the world layer, so it carries a long way.
	_papers(-2.0, 24.0, DECK_Y + 0.02, -0.25, 34, 0.55, 2207)
	_papers(-13.0, -2.0, YARD_Y + 0.06, -8.0, 22, 1.4, 991)

	# The guard's chair, on its back, and the bucket he kicked over.
	var chair := LevelKit.prop(geometry, Vector3(19.4, DECK_Y + 0.28, -0.30),
		Vector3(0.46, 0.46, 0.44), dress["plastic"], "TippedChair")
	chair.rotation = Vector3(-1.32, 0.35, 0.0)
	LevelKit.prop(geometry, Vector3(19.35, DECK_Y + 0.52, -0.05),
		Vector3(0.44, 0.06, 0.42), dress["plastic"], "ChairBack").rotation = Vector3(-1.32, 0.35, 0.0)
	_cyl_prop(geometry, Vector3(22.8, DECK_Y + 0.14, -0.36), 0.20, 0.30,
		dress["tin"], "Bucket", Vector3(PI * 0.52, 0.4, 0.0), 10)

	# A stack of ration crates against the wall, one burst. Somebody was going
	# to move these tonight and now nobody is.
	for i in 3:
		var c := LevelKit.prop(geometry, Vector3(27.4 + fmod(float(i) * 0.31, 0.3),
			DECK_Y + 0.28 + i * 0.52, -0.70), Vector3(0.86, 0.52, 0.66),
			mats["crate"], "RationCrate%d" % i)
		c.rotation.y = fmod(float(i) * 0.7, 0.4) - 0.2
	LevelKit.prop(geometry, Vector3(29.1, DECK_Y + 0.13, -0.40),
		Vector3(0.80, 0.26, 0.62), mats["crate"], "BurstCrate").rotation = Vector3(0.0, 0.5, 0.42)


## Section A's foreground band. BregaKit scatters generic junk every six to
## twelve units; these three are authored, placed where the composition needs a
## near-black shape and nowhere else.
func _a_frame() -> void:
	# A stanchion with a length of chain hanging off it, closing the left edge
	# of the opening frame.
	LevelKit.prop(geometry, Vector3(-6.2, DECK_Y - 0.55, 6.4),
		Vector3(0.20, 3.20, 0.20), mats["dark"], "FgStanchion")
	PropKit.cable(geometry, Vector3(-6.2, DECK_Y + 0.85, 6.4),
		Vector3(-2.9, DECK_Y + 0.40, 6.6), 0.55, mats["dark"], 8, 0.05)

	# Shade cloth torn off its frame, hanging and moving. Section A's DRAPE.
	var sway := Sway.new()
	sway.name = "FgShadeCloth"
	sway.position = Vector3(12.4, DECK_Y + 1.85, 5.9)
	sway.axis = Vector3(0.25, 0.1, 1.0)
	sway.amplitude = 0.10
	sway.speed = 0.9
	sway.gust_amplitude = 0.07
	sway.gust_speed = 2.6
	geometry.add_child(sway)
	LevelKit.prop(sway, Vector3(0.0, -0.85, 0.0), Vector3(1.55, 1.75, 0.03),
		mats["dark"], "ClothPanel")
	LevelKit.prop(sway, Vector3(0.55, -1.75, 0.02), Vector3(0.45, 0.60, 0.03),
		mats["dark"], "ClothTear").rotation.z = 0.35

	# A kerb run crossing the bottom of frame — a horizontal, not another
	# object sitting in the corner.
	LevelKit.prop(geometry, Vector3(26.0, DECK_Y - 1.65, 7.2),
		Vector3(11.0, 0.38, 0.6), mats["dark"], "FgKerb")


# --- B — THE YARD -----------------------------------------------------------
# Down on the sabkha. Wider, with gaps that want a double jump and the first
# SNITCH patrolling a beat the player can watch before committing.
#
# The yard is the level's one genuinely open section and it is dressed for air:
# a tall landmark, one sweeping light, and a long low haze that separates the
# play decks from the plant band behind them.

func _section_b_yard() -> void:
	_deck(44.0, YARD_Y + 1.2, 22.0, mats["sabkha"], mats["rust"], "YardA")
	LevelKit.platform(geometry, 40.0, YARD_Y + 3.0, 5.0, mats["sabkha"], 9.0, 3.4, "YardStep")
	_nose(40.0, YARD_Y + 3.0, 5.0, 1.70)
	_deck(72.0, YARD_Y + 1.2, 12.0, mats["sabkha"], mats["rust"], "YardB")
	_deck(92.0, YARD_Y + 2.6, 9.0, mats["deck"], mats["rust"], "YardLedge")
	_deck(105.0, YARD_Y + 4.4, 8.0, mats["deck"], mats["rust"], "YardHigh")

	_crate_stack(Vector3(58.0, YARD_Y + 1.2, 0.0), 3)
	_crate_stack(Vector3(80.0, YARD_Y + 1.2, 0.0), 2)

	_b_water_tower()
	_b_gate_office()
	_b_abandoned_truck()
	_b_frame()

	TrailBuilder.line(geometry, Vector3(47.0, YARD_Y + 2.1, 0.0),
		Vector3(60.0, YARD_Y + 2.1, 0.0), 7)
	# The gap that teaches the second jump: the arc peaks past what one jump reaches.
	TrailBuilder.curve(geometry, Vector3(66.5, YARD_Y + 2.3, 0.0),
		Vector3(72.5, YARD_Y + 2.3, 0.0), 2.4, 8)
	TrailBuilder.jump_arc(geometry, Vector3(84.5, YARD_Y + 2.2, 0.0), 1.0, 1.0, 8)
	TrailBuilder.cluster(geometry, Vector3(98.5, YARD_Y + 6.4, 0.0), 0.85, 8)
	# The high line. A second double jump off the top ledge buys a cluster that
	# is visible from the approach — the level's first "that is optional, and I
	# want it" moment, which is the habit section E's secret depends on.
	TrailBuilder.column(geometry, Vector3(109.0, YARD_Y + 5.4, 0.0), 2.0, 3)
	TrailBuilder.cluster(geometry, Vector3(109.0, YARD_Y + 8.0, 0.0), 0.80, 7)

	# The first hazard in the game, alone, on flat ground with nothing else
	# happening: learn the collar.
	_vent(Vector3(52.0, YARD_Y + 0.08, 0.0), 0.0, 3.6)
	_drone(Vector3(63.0, YARD_Y + 5.2, 0.0), 4.5)
	_drone(Vector3(88.0, YARD_Y + 6.6, 0.0), 5.5)
	# On the long yard deck, where there is room to dash past it.
	_walker(Vector3(56.0, YARD_Y + 1.5, 0.0), 7.0)

	_checkpoint(Vector3(74.0, YARD_Y + 1.2, 0.0), 0)


## LANDMARK, x = 62. The water tower, with the guard tower under it and the
## searchlight on top of that. Everything the eye wants in the middle of an
## open section is in one vertical stack, so the yard has a centre.
func _b_water_tower() -> void:
	var z := -24.0
	var base := YARD_Y
	# Four splayed legs with two rings of cross-bracing. The splay is what
	# separates a water tower from a chimney at silhouette distance.
	var tops: Array[Vector3] = []
	for i in 4:
		var sx := -1.0 if i < 2 else 1.0
		var sz := -1.0 if i % 2 == 0 else 1.0
		var leg := LevelKit.prop(geometry,
			Vector3(LM_WATER_TOWER + sx * 2.3, base + 7.6, z + sz * 2.3),
			Vector3(0.30, 15.6, 0.30), mats["steel"], "WaterTowerLeg%d" % i)
		leg.rotation.z = -sx * 0.085
		leg.rotation.x = sz * 0.085
		tops.append(Vector3(LM_WATER_TOWER + sx * 1.0, base + 15.2, z + sz * 1.0))
	for ring in 2:
		var ry := base + 4.6 + ring * 5.4
		for sz2: float in [-2.0, 2.0]:
			LevelKit.prop(geometry, Vector3(LM_WATER_TOWER, ry, z + sz2),
				Vector3(4.4, 0.16, 0.16), mats["steel"], "TowerBand")
			for dir: float in [-1.0, 1.0]:
				var br := LevelKit.prop(geometry, Vector3(LM_WATER_TOWER, ry + 1.35, z + sz2),
					Vector3(0.12, 5.5, 0.12), mats["steel"], "TowerBrace")
				br.rotation.z = dir * 0.62

	# The tank: a drum with a conical cap and a skirt, and a ladder up one leg.
	_cyl_prop(geometry, Vector3(LM_WATER_TOWER, base + 17.6, z), 3.5, 5.2,
		mats["tank"], "WaterTowerTank", Vector3.ZERO, 20)
	_cyl_prop(geometry, Vector3(LM_WATER_TOWER, base + 20.8, z), 3.6, 1.5,
		mats["tank"], "WaterTowerCap", Vector3.ZERO, 20, 0.9)
	_cyl_prop(geometry, Vector3(LM_WATER_TOWER, base + 15.0, z), 3.7, 0.22,
		mats["rust"], "WaterTowerSkirt", Vector3.ZERO, 20)
	for i in 14:
		LevelKit.prop(geometry, Vector3(LM_WATER_TOWER + 2.3, base + 1.0 + i * 1.08, z + 2.55),
			Vector3(0.62, 0.05, 0.05), mats["rust"], "TowerRung%d" % i)
	# Plant identification, Naskh, painted straight onto the shell. Bleed
	# streaks under the manway, because every stain in this game runs down.
	PropKit.sign(geometry, "ماء", Vector3(LM_WATER_TOWER, base + 17.2, z + 3.55), 1.5,
		dress["paint"], PropKit.FONT_NASKH)
	for i in 4:
		LevelKit.prop(geometry, Vector3(LM_WATER_TOWER - 2.2 + i * 1.5, base + 16.4, z + 3.5),
			Vector3(0.22, 3.4 - fmod(float(i) * 1.7, 1.2), 0.08), mats["rust"], "TowerBleed%d" % i)

	# The guard tower under it, and the searchlight that is still looking for
	# him. One sweeping light does more staging work than fifty static props.
	var tx := LM_WATER_TOWER - 7.0
	var tz := -18.0
	for i in 4:
		var sx := -1.0 if i < 2 else 1.0
		var sz := -1.0 if i % 2 == 0 else 1.0
		LevelKit.prop(geometry, Vector3(tx + sx * 0.9, YARD_Y + 3.4, tz + sz * 0.9),
			Vector3(0.22, 6.8, 0.22), mats["steel"], "GuardLeg%d" % i)
	LevelKit.prop(geometry, Vector3(tx, YARD_Y + 6.9, tz), Vector3(3.2, 0.3, 3.2),
		mats["steel"], "GuardDeck")
	LevelKit.prop(geometry, Vector3(tx, YARD_Y + 7.9, tz), Vector3(2.7, 1.7, 2.7),
		mats["wall"], "GuardCab")
	LevelKit.prop(geometry, Vector3(tx, YARD_Y + 8.5, tz + 1.36), Vector3(2.3, 0.75, 0.06),
		mats["dark"], "GuardGlass")
	LevelKit.prop(geometry, Vector3(tx, YARD_Y + 9.0, tz), Vector3(3.8, 0.12, 3.8),
		mats["corrugated"], "GuardRoof").rotation.x = 0.05
	_searchlight(Vector3(tx + 1.5, YARD_Y + 9.2, tz + 1.2), 8.5)


## The gate office, turned over. This is the "scattered files and an overturned
## desk" beat and it wants to be one readable tableau, not a scatter: a lit
## interior with a black rectangle of a window and the furniture outside it.
func _b_gate_office() -> void:
	var x := 70.0
	var z := -3.0
	LevelKit.prop(geometry, Vector3(x, YARD_Y + 1.7, z), Vector3(6.4, 3.4, 2.6),
		mats["slab"], "GateOffice")
	LevelKit.prop(geometry, Vector3(x, YARD_Y + 3.55, z), Vector3(6.9, 0.28, 3.0),
		mats["joint"], "GateOfficeCap")
	# The window is smashed: a dark void with the frame still in it and glass
	# on the ground below.
	LevelKit.prop(geometry, Vector3(x + 1.1, YARD_Y + 2.3, z + 1.30),
		Vector3(2.0, 1.15, 0.06), mats["dark"], "OfficeVoid")
	for i in 3:
		LevelKit.prop(geometry, Vector3(x + 0.3 + i * 0.8, YARD_Y + 2.3, z + 1.34),
			Vector3(0.06, 1.15, 0.05), mats["joint"], "OfficeMullion%d" % i)
	LevelKit.prop(geometry, Vector3(x + 1.1, YARD_Y + 2.86, z + 1.36),
		Vector3(2.15, 0.10, 0.10), mats["joint"], "OfficeLintel")
	# Its door swung back on one hinge.
	var d := LevelKit.prop(geometry, Vector3(x - 2.1, YARD_Y + 1.05, z + 1.5),
		Vector3(0.95, 2.10, 0.06), mats["door"], "OfficeDoor")
	d.rotation.y = -1.35
	d.position += Vector3(0.40, 0.0, 0.32)
	PropKit.sign(geometry, "مخزن", Vector3(x + 2.4, YARD_Y + 3.05, z + 1.34), 0.28,
		dress["paint"], PropKit.FONT_KUFI)

	# The desk, on its side, half out of the door. A desk standing up reads as
	# furniture; a desk on its side reads as an event.
	var desk := LevelKit.prop(geometry, Vector3(x - 3.1, YARD_Y + 0.58, z + 1.9),
		Vector3(1.75, 0.10, 0.85), dress["leather"], "DeskTop")
	desk.rotation = Vector3(0.0, 0.32, 1.50)
	LevelKit.prop(geometry, Vector3(x - 3.55, YARD_Y + 0.55, z + 1.95),
		Vector3(1.70, 0.80, 0.08), dress["leather"], "DeskSide").rotation = Vector3(0.0, 0.32, 1.50)
	for i in 2:
		var dr := LevelKit.prop(geometry, Vector3(x - 2.2 - i * 0.7, YARD_Y + 0.14, z + 2.4),
			Vector3(0.62, 0.20, 0.46), dress["leather"], "Drawer%d" % i)
		dr.rotation.y = 0.4 + i * 0.5

	# The filing cabinet, emptied. All four drawers out is the read.
	LevelKit.prop(geometry, Vector3(x + 3.8, YARD_Y + 0.85, z + 1.4),
		Vector3(0.70, 1.70, 0.60), dress["tin"], "Cabinet")
	for i in 3:
		LevelKit.prop(geometry, Vector3(x + 4.25, YARD_Y + 0.55 + i * 0.44, z + 1.78),
			Vector3(0.62, 0.30, 0.52), dress["tin"], "CabDrawer%d" % i).rotation.y = 0.10 * i

	# And the paper, everywhere, drifting out toward the play plane. This is
	# the only place in the level where near-white lies on the ground, so it is
	# also a landmark of sorts.
	_papers(x - 6.5, x + 7.0, YARD_Y + 0.05, z + 2.6, 52, 2.4, 3311)
	# Three sheets still in the air, caught on the wind.
	for i in 3:
		var s := Sway.new()
		s.name = "LooseSheet%d" % i
		s.position = Vector3(x - 1.0 + i * 3.1, YARD_Y + 2.3 + fmod(float(i) * 1.3, 1.1), -0.9)
		s.axis = Vector3(0.4, 1.0, 0.3)
		s.amplitude = 0.55
		s.speed = 1.7 + i * 0.4
		s.gust_amplitude = 0.42
		s.position_amplitude = 0.35
		geometry.add_child(s)
		LevelKit.prop(s, Vector3.ZERO, Vector3(0.26, 0.34, 0.010), dress["paper"], "Sheet")


## The delivery that never finished. A truck with the tailgate down and the
## load half off is a stronger object than a wreck, because a wreck is scenery
## and this is an interruption.
func _b_abandoned_truck() -> void:
	var at := Vector3(88.0, YARD_Y, -8.0)
	_truck(at, 5.6, 2.1, mats["rust"], false)
	# Tailgate down, crates walked off the back and one split open.
	LevelKit.prop(geometry, at + Vector3(-3.1, 0.62, 0.0), Vector3(0.10, 1.05, 1.9),
		mats["rust"], "Tailgate").rotation.z = 1.25
	for i in 3:
		var c := LevelKit.prop(geometry, at + Vector3(-4.4 - i * 1.25, 0.46 - i * 0.12, 0.3 * i),
			Vector3(0.95, 0.72, 0.80), mats["crate"], "LoadCrate%d" % i)
		c.rotation = Vector3(0.0, fmod(float(i) * 0.9, 1.1), fmod(float(i) * 0.5, 0.3))
	_papers(at.x - 8.0, at.x - 3.0, YARD_Y + 0.05, at.z + 1.2, 18, 1.6, 771)


## Section B's foreground. Open section, so the near band stays sparse — one
## silhouette per screen, never two.
func _b_frame() -> void:
	PropKit.eucalyptus(geometry, Vector3(50.5, YARD_Y - 2.4, 7.8), 12.5,
		mats["dark"], mats["dark"], false, 47)
	LevelKit.prop(geometry, Vector3(78.0, YARD_Y - 1.2, 6.6),
		Vector3(9.0, 0.44, 0.60), mats["dark"], "FgBundLip")
	var drum := LevelKit.prop(geometry, Vector3(101.5, YARD_Y - 0.6, 6.2),
		Vector3(0.85, 1.25, 0.85), mats["dark"], "FgDrum")
	drum.rotation.z = 0.24
	PropKit.razor_coil(geometry, Vector3(64.0, YARD_Y + 1.6, 8.4),
		Vector3(69.5, YARD_Y + 1.1, 8.4), 0.34, mats["dark"], 9, "FgRazor")


# --- C — THE PIPE RACK ------------------------------------------------------
# Vertical. Climb the sleepers, then a drop too long to survive as a fall and
# exactly right as a glide. The trail hangs in the air to say so.
#
# Atmosphere brief: a forest of pipes with shafts of light between them. That
# is built literally — three near vertical risers the player climbs BETWEEN, a
# low horizontal bank behind him, and a thin fog slab on the camera side of
# both so the key cuts through the gaps.

func _section_c_pipe_rack() -> void:
	PropKit.pipe_rack(geometry, Vector3(112.0, YARD_Y + 14.0, -3.2),
		Vector3(176.0, YARD_Y + 14.0, -3.2), 4, mats["rust"], mats["bund"], 10.0)

	var heights := [3.0, 5.0, 7.0, 9.0, 11.0]
	for i in heights.size():
		_deck(114.0 + i * 6.0, YARD_Y + heights[i], 5.4, mats["rust"], mats["steel"],
			"Sleeper%d" % i)
		TrailBuilder.line(geometry,
			Vector3(115.2 + i * 6.0, YARD_Y + heights[i] + 0.9, 0.0),
			Vector3(118.2 + i * 6.0, YARD_Y + heights[i] + 0.9, 0.0), 4)

	_deck(144.0, YARD_Y + 12.4, 12.0, mats["deck"], mats["steel"], "RackTop")
	LevelKit.prop(geometry, Vector3(150.0, YARD_Y + 13.7, -1.4), Vector3(12.0, 2.6, 0.5),
		mats["corrugated"], "RackScreen")

	# The glide. The catwalk on the far side is 22 units across and 9 down: a
	# jump falls short by a mile, a glide arrives with room.
	_deck(168.0, YARD_Y + 4.6, 18.0, mats["deck"], mats["rust"], "GlideLanding")
	TrailBuilder.line(geometry, Vector3(157.0, YARD_Y + 12.2, 0.0),
		Vector3(167.0, YARD_Y + 6.2, 0.0), 10)

	var sandwich := TunaSandwich.new()
	geometry.add_child(sandwich)
	sandwich.position = Vector3(163.5, YARD_Y + 11.0, 0.0)

	_c_pipe_forest()
	_c_collapsed_gantry()
	_c_life()

	# The high line again, above the rack top, where the player has already
	# stopped to look at the sandwich.
	TrailBuilder.cluster(geometry, Vector3(148.0, YARD_Y + 15.8, 0.0), 0.85, 7)

	# First sentry of the level, high and alone, with a long run of cover under
	# it: the player meets the telegraph before they meet two of them.
	# Three on a stagger: a ripple you walk through, not a wall.
	for i in 3:
		_vent(Vector3(104.0 + i * 3.4, YARD_Y + 0.08, 0.0), float(i) * 0.9, 4.2)
	_turret(Vector3(126.0, YARD_Y + 12.6, 0.0))
	_drone(Vector3(132.0, YARD_Y + 9.0, 0.0), 5.0)
	_drone(Vector3(156.0, YARD_Y + 16.0, 0.0), 6.0)


## The forest. Near risers at z = +3.8 that the camera passes behind, a low
## bank at z = -2.9 that the climb happens in front of. Both are pipes, so the
## section is legible as one place rather than as a climbing wall with a
## backdrop.
func _c_pipe_forest() -> void:
	for spec: Array in [[117.0, 17.0, 0.44], [129.5, 20.5, 0.52], [141.0, 15.0, 0.40],
			[159.0, 18.5, 0.48], [175.0, 16.0, 0.42]]:
		var x: float = spec[0]
		var h: float = spec[1]
		var r: float = spec[2]
		_cyl_prop(geometry, Vector3(x, YARD_Y + h * 0.5 - 1.0, 3.8), r, h,
			mats["dark"], "FgRiser", Vector3.ZERO, 12)
		# An elbow at the top so the riser goes somewhere instead of stopping.
		_cyl_prop(geometry, Vector3(x + 0.9, YARD_Y + h - 1.0, 3.8), r, 2.0,
			mats["dark"], "FgElbow", Vector3(0.0, 0.0, PI * 0.5), 12)
		# Flanges: without a band every metre or so a pipe is a cylinder, and a
		# cylinder is not a pipe.
		for b in int(h / 3.4):
			_cyl_prop(geometry, Vector3(x, YARD_Y - 0.4 + b * 3.4, 3.8), r * 1.25, 0.22,
				mats["dark"], "FgFlange", Vector3.ZERO, 12)

	# The low bank behind the climb, running the whole section on sleepers.
	for i in 5:
		_cyl_prop(geometry, Vector3(148.0, YARD_Y + 1.1 + i * 0.52, -2.90), 0.24, 86.0,
			mats["rust"], "BankPipe%d" % i, Vector3(0.0, 0.0, PI * 0.5), 10)
	for i in 12:
		LevelKit.prop(geometry, Vector3(106.0 + i * 7.2, YARD_Y + 0.45, -2.90),
			Vector3(0.7, 0.9, 1.6), mats["bund"], "BankSleeper%d" % i)

	# A valve station on the rack top: wheels, a manifold, a caged ladder. It
	# is the only complex silhouette in the section and it sits exactly where
	# the glide launches from, so the launch point has a name.
	LevelKit.prop(geometry, Vector3(153.5, YARD_Y + 13.2, -2.3),
		Vector3(2.6, 1.5, 0.8), mats["rust"], "Manifold")
	for i in 3:
		var wheel := _cyl_prop(geometry, Vector3(152.6 + i * 0.9, YARD_Y + 14.4, -2.1),
			0.34, 0.08, mats["rust"], "ValveWheel%d" % i, Vector3(PI * 0.5, 0.0, 0.0), 12)
		wheel.rotation.z = fmod(float(i) * 0.9, 1.0)
		LevelKit.prop(geometry, Vector3(152.6 + i * 0.9, YARD_Y + 14.0, -2.1),
			Vector3(0.10, 0.72, 0.10), mats["rust"], "ValveStem%d" % i)


## LANDMARK, x = 138. The gantry that came down. It is the only strong diagonal
## in a section built entirely of verticals and horizontals, which is why it is
## visible — and legible — from sixty units away.
func _c_collapsed_gantry() -> void:
	var z := -16.5
	# The span, off its legs at the far end and driven into the yard floor.
	var span := LevelKit.prop(geometry, Vector3(LM_COLLAPSED_GANTRY, YARD_Y + 4.6, z),
		Vector3(26.0, 1.5, 2.0), mats["bund"], "FallenSpan")
	span.rotation.z = deg_to_rad(-27.0)
	var lid := LevelKit.prop(geometry, Vector3(LM_COLLAPSED_GANTRY, YARD_Y + 5.4, z),
		Vector3(26.0, 0.22, 2.3), mats["steel"], "FallenSpanLid")
	lid.rotation.z = deg_to_rad(-27.0)
	# The leg that failed, folded under it, and the one that held.
	var buckled := LevelKit.prop(geometry, Vector3(LM_COLLAPSED_GANTRY + 6.0, YARD_Y + 1.6, z),
		Vector3(0.42, 5.2, 0.42), mats["steel"], "BuckledLeg")
	buckled.rotation.z = deg_to_rad(52.0)
	LevelKit.prop(geometry, Vector3(LM_COLLAPSED_GANTRY - 13.5, YARD_Y + 5.2, z),
		Vector3(0.42, 10.4, 0.42), mats["steel"], "StandingLeg")
	LevelKit.prop(geometry, Vector3(LM_COLLAPSED_GANTRY - 13.5, YARD_Y + 10.0, z),
		Vector3(3.4, 0.16, 1.9), mats["steel"], "SpanSaddle")
	# What it was carrying, spilled in a cone under the low end. Years old:
	# sand has already drifted up one side of it.
	for i in 5:
		var m := LevelKit.prop(geometry,
			Vector3(LM_COLLAPSED_GANTRY + 11.0 + fmod(float(i) * 3.3, 4.0),
				YARD_Y + 0.35 - i * 0.05, z + fmod(float(i) * 2.1, 3.0) - 1.5),
			Vector3(4.2 - i * 0.5, 0.75 - i * 0.09, 3.0), mats["sand"], "SpillHeap%d" % i)
		m.rotation.y = fmod(float(i) * 0.7, 0.5)


## Life in the steel: bags, a bird, and one relief valve venting. Nothing in
## this section moves on its own otherwise, and a still frame of a pipe rack is
## a photograph of scaffolding.
func _c_life() -> void:
	for i in 3:
		_snagged_bag(Vector3(122.0 + i * 17.0, YARD_Y + 10.5 + fmod(float(i) * 3.7, 3.0), -2.2),
			0.55 + i * 0.12, 1.1 + i * 0.3)

	# A relief valve lifting. Behind the play plane and away from the running
	# line so it is never mistaken for the collar vents underfoot.
	LevelKit.prop(geometry, Vector3(162.0, YARD_Y + 9.4, -3.5),
		Vector3(0.28, 1.6, 0.28), mats["rust"], "ReliefStack")
	_cyl_prop(geometry, Vector3(162.0, YARD_Y + 10.3, -3.5), 0.30, 0.32,
		mats["rust"], "ReliefHead", Vector3.ZERO, 10)
	_vapour(Vector3(162.0, YARD_Y + 10.6, -3.5), Vector3(0.35, 1.0, 0.0), 62, 0.75)

	# Ladder up the rack: a vertical with rungs in it, which is the fastest way
	# to give a steel structure human scale.
	for i in 16:
		LevelKit.prop(geometry, Vector3(168.6, YARD_Y + 5.4 + i * 0.62, -2.6),
			Vector3(0.56, 0.05, 0.05), mats["rust"], "RackRung%d" % i)
	for side: float in [-0.28, 0.28]:
		LevelKit.prop(geometry, Vector3(168.6 + side, YARD_Y + 10.4, -2.6),
			Vector3(0.07, 10.6, 0.07), mats["rust"], "RackStringer")


# --- D — PROPERTY CAGE ------------------------------------------------------
# The beat the level is built around. He walks in wearing prison grey and walks
# out in the thobe, with the chain and the rifle.
#
# Staged as a room and not as a corridor with a prop in it:
#
#   * a real interior — back wall, painted dado, end wall, soffit and beams —
#     which matters because the key travels toward -x and +z, so a box closed
#     on its -z and +x sides is in genuine shade. The only light inside is the
#     one bulb over the counter. That is the whole lighting design of the beat.
#   * a counter with the ledger still open on it, and two runs of shelving
#     behind mesh, carrying other men's belongings, numbered and tagged.
#   * evidence that somebody has already been through: hasp cut, door open,
#     trolley tipped, a line of dropped possessions across the floor that
#     points straight at the cage.
#   * a proscenium at z = +2.4 — two near-black posts and a header, spaced so
#     both sit at the edges of frame when he is at the cage at x = 206. He is
#     inside a rectangle at the moment it happens. That is the shot.

func _section_d_cage() -> void:
	_deck(186.0, STORE_FLOOR, 38.0, mats["deck"], mats["rust"], "StoreFloor")
	PropKit.prefab_facade(geometry, 186.0, YARD_Y + 4.6, 38.0, 7.0, -4.6, mats["slab"], {
		"name": "StoreWall", "joint_mat": mats["joint"], "dark_mat": mats["dark"],
		"hole_mat": mats["joint"], "depth": 4.0, "open_holes": 1,
	})

	_d_room()
	_d_shelving()
	_d_counter()
	_d_ransacked()
	_d_proscenium()

	_cage = PropertyCage.new()
	geometry.add_child(_cage)
	_cage.position = Vector3(206.0, YARD_Y + 4.6, -0.6)
	_cage.opened.connect(_on_cage_opened)

	_checkpoint(Vector3(196.0, YARD_Y + 4.6, 0.0), 1)
	TrailBuilder.line(geometry, Vector3(189.0, YARD_Y + 5.5, 0.0),
		Vector3(202.0, YARD_Y + 5.5, 0.0), 7)


## The shell of the room. Built as a closed box on the sun side so the interior
## is genuinely unlit — everything here exists to make one hanging bulb matter.
func _d_room() -> void:
	var f := STORE_FLOOR
	var w := 23.0
	var cx := 207.5

	# Back wall, with a painted dado to waist height. Institutional interiors
	# on this coast are always two-tone, and the line is what gives a flat wall
	# a horizon.
	LevelKit.prop(geometry, Vector3(cx, f + 2.4, STORE_BACK_Z),
		Vector3(w, 4.8, 0.35), dress["interior"], "StoreBackWall")
	LevelKit.prop(geometry, Vector3(cx, f + 0.55, STORE_BACK_Z + 0.20),
		Vector3(w, 1.10, 0.06), dress["dado"], "StoreDado")
	LevelKit.prop(geometry, Vector3(cx, f + 1.13, STORE_BACK_Z + 0.22),
		Vector3(w, 0.05, 0.05), dress["paint"], "DadoLine")
	# Floor carried back under the shelving, so the counter and racks are
	# standing on something.
	LevelKit.prop(geometry, Vector3(cx, f - 0.22, STORE_BACK_Z + 1.6),
		Vector3(w, 0.44, 3.4), mats["deck"], "StoreInnerFloor")

	# The end wall. This is the one that does the lighting work: without it the
	# low sun rakes straight down the room from +x and the interior is not an
	# interior at all.
	LevelKit.prop(geometry, Vector3(219.2, f + 2.3, STORE_BACK_Z + 1.5),
		Vector3(0.45, 4.6, 3.4), dress["interior"], "StoreEndWall")

	# Soffit and beams. The beams are what stop a ceiling reading as a lid.
	LevelKit.prop(geometry, Vector3(cx, STORE_SOFFIT, STORE_BACK_Z + 1.6),
		Vector3(w, 0.35, 3.4), dress["interior"], "StoreSoffit")
	for i in 5:
		LevelKit.prop(geometry, Vector3(198.5 + i * 4.6, STORE_SOFFIT - 0.35,
			STORE_BACK_Z + 1.6), Vector3(0.34, 0.40, 3.3), mats["joint"], "StoreBeam%d" % i)

	# Two dead fluorescent fittings hanging crooked, so the one that works
	# reads as the exception.
	for i in 2:
		var t := LevelKit.prop(geometry, Vector3(199.5 + i * 15.0, STORE_SOFFIT - 0.72, -1.9),
			Vector3(1.55, 0.10, 0.16), dress["tin"], "DeadTube%d" % i)
		t.rotation.z = 0.16 - i * 0.34
		LevelKit.prop(geometry, Vector3(199.2 + i * 15.0, STORE_SOFFIT - 0.40, -1.9),
			Vector3(0.04, 0.55, 0.04), mats["steel"], "TubeHanger%d" % i)

	# The one working light. Over the counter, on a cord, moving a little —
	# and every value in the room is set relative to it.
	_hanging_bulb(Vector3(203.4, STORE_SOFFIT - 0.30, -1.55), 1.35)


## Two runs of shelving behind mesh, flanking the cage. The point of this
## section is that his things were taken off him and filed, so the shelves have
## to look filed: level boards, even spacing, painted bay numbers, and only
## then the mess of what is actually on them.
func _d_shelving() -> void:
	_shelf_bay(Vector3(197.2, STORE_FLOOR, -2.75), 6.6, 4, 11, 5101)
	_shelf_bay(Vector3(209.0, STORE_FLOOR, -2.75), 8.8, 4, 12, 6203)

	# Mesh across both bays. The cage itself sits in the 4-unit gap between
	# them, which is why the eye goes there.
	var link := PropKit.chainlink_material(0.38, 16.0)
	PropKit.chainlink(geometry, 196.6, STORE_FLOOR, 7.4, 3.9, -2.15, link, mats["rust"])
	PropKit.chainlink(geometry, 208.4, STORE_FLOOR, 9.8, 3.9, -2.15, link, mats["rust"])
	# A rail over the top of both, tying the two runs into one screen.
	LevelKit.prop(geometry, Vector3(207.5, STORE_FLOOR + 3.95, -2.15),
		Vector3(22.0, 0.10, 0.10), mats["rust"], "MeshHeadRail")


## The counter: a hatch in the mesh where property was handed back across. The
## ledger is open on it, which is the detail that says a man sat here and wrote
## down every object he took off every person who came through that door.
func _d_counter() -> void:
	var f := STORE_FLOOR
	var x := 200.4
	LevelKit.prop(geometry, Vector3(x, f + 0.94, -2.05), Vector3(4.2, 0.12, 1.05),
		dress["leather"], "CounterTop")
	LevelKit.prop(geometry, Vector3(x, f + 0.44, -2.35), Vector3(4.0, 0.88, 0.10),
		dress["leather"], "CounterFront")
	LevelKit.prop(geometry, Vector3(x, f + 1.02, -2.50), Vector3(4.2, 0.18, 0.08),
		dress["paint"], "CounterLip")
	# The ledger, open, two leaves at a shallow angle.
	for side: float in [-1.0, 1.0]:
		var page := LevelKit.prop(geometry, Vector3(x - 1.1 + side * 0.26, f + 1.02, -2.0),
			Vector3(0.50, 0.018, 0.36), dress["paper"], "LedgerPage")
		page.rotation.z = side * 0.09
	LevelKit.prop(geometry, Vector3(x - 1.1, f + 0.99, -2.0),
		Vector3(1.06, 0.05, 0.40), dress["leather"], "LedgerBoard")
	# A mug, a lamp that does not work, and a spike of receipts.
	_cyl_prop(geometry, Vector3(x + 0.5, f + 1.06, -1.95), 0.075, 0.14,
		dress["tin"], "CounterMug", Vector3.ZERO, 10)
	LevelKit.prop(geometry, Vector3(x + 1.5, f + 1.10, -2.15),
		Vector3(0.22, 0.20, 0.22), dress["tin"], "DeskLampShade").rotation.z = 0.5
	LevelKit.prop(geometry, Vector3(x + 1.5, f + 1.00, -2.15),
		Vector3(0.05, 0.22, 0.05), dress["tin"], "DeskLampStem")
	for i in 5:
		LevelKit.prop(geometry, Vector3(x + 0.95, f + 1.02 + i * 0.012, -2.22),
			Vector3(0.28, 0.010, 0.20), dress["paper"], "Receipt%d" % i).rotation.y = 0.2 * i


## The ransacking. Every object here is placed on a line from the store door to
## the cage, so the mess reads as a path and doubles as a silent arrow.
func _d_ransacked() -> void:
	var f := STORE_FLOOR

	# The store's own door, forced and standing open at the entrance.
	var door := LevelKit.prop(geometry, Vector3(195.6, f + 1.10, -2.30),
		Vector3(1.00, 2.20, 0.07), mats["door"], "StoreDoor")
	door.rotation.y = -1.25
	door.position += Vector3(0.45, 0.0, 0.34)
	LevelKit.prop(geometry, Vector3(195.2, f + 1.12, -2.60), Vector3(1.30, 2.44, 0.30),
		mats["joint"], "StoreDoorJamb")
	# The hasp, cut, and the bolt-croppers left behind.
	LevelKit.prop(geometry, Vector3(196.4, f + 0.06, -1.40),
		Vector3(0.26, 0.05, 0.10), mats["steel"], "CutHasp").rotation.y = 0.9
	var crop := LevelKit.prop(geometry, Vector3(197.3, f + 0.07, -1.15),
		Vector3(1.05, 0.07, 0.09), mats["steel"], "BoltCroppers")
	crop.rotation = Vector3(0.0, 0.28, 0.06)

	# The trolley they were loading onto, tipped.
	var trolley := LevelKit.prop(geometry, Vector3(211.8, f + 0.42, -1.55),
		Vector3(1.50, 0.10, 0.85), dress["tin"], "Trolley")
	trolley.rotation = Vector3(0.0, 0.2, 1.36)
	for side: float in [-0.34, 0.34]:
		_cyl_prop(geometry, Vector3(211.3, f + 0.16, -1.55 + side), 0.16, 0.08,
			mats["dark"], "TrolleyWheel", Vector3(PI * 0.5, 0.0, 0.0), 10)

	# The line of dropped belongings, running door to cage. Other men's things:
	# a shoe, a belt, a wallet, a watch, a folded shirt, a cassette. None of it
	# is his, and that is the point — his is the one still behind the bars.
	var spill := [
		[198.6, Vector3(0.30, 0.11, 0.15), dress["leather"], 0.7],
		[199.9, Vector3(0.44, 0.05, 0.06), dress["leather"], 0.2],
		[201.6, Vector3(0.22, 0.07, 0.17), dress["leather"], 1.1],
		[202.8, Vector3(0.36, 0.10, 0.28), dress["cloth"], 0.4],
		[203.9, Vector3(0.13, 0.04, 0.09), dress["tin"], 0.9],
		[204.8, Vector3(0.18, 0.06, 0.12), dress["plastic"], 0.3],
	]
	for s: Array in spill:
		var p := LevelKit.prop(geometry, Vector3(s[0], f + 0.05, -1.25),
			s[1], s[2], "Dropped")
		p.rotation.y = s[3]
	_papers(196.5, 212.0, f + 0.03, -1.6, 30, 1.5, 8821)

	# A shelf that came down at the far end, with its contents underneath.
	var board := LevelKit.prop(geometry, Vector3(216.0, f + 0.55, -2.60),
		Vector3(3.2, 0.09, 0.85), dress["leather"], "FallenShelf")
	board.rotation.z = deg_to_rad(-19.0)
	for i in 4:
		LevelKit.prop(geometry, Vector3(214.9 + i * 0.68, f + 0.14, -2.35),
			Vector3(0.36, 0.26, 0.30), dress["cloth"], "FallenBundle%d" % i).rotation.y = 0.5 * i


## The frame. Two near-black posts and a header at z = +2.4, placed so that
## with the camera on him at the cage both posts sit hard against the edges of
## frame and the header crosses the top. He is held inside a rectangle for the
## whole of the transformation, and the fascia over his head names the room.
func _d_proscenium() -> void:
	var z := 2.4
	for x: float in [201.4, 212.8]:
		LevelKit.prop(geometry, Vector3(x, STORE_FLOOR + 1.6, z),
			Vector3(0.55, 12.0, 0.50), mats["dark"], "ProsceniumPost")
	LevelKit.prop(geometry, Vector3(207.1, STORE_FLOOR + 4.60, z),
		Vector3(24.0, 0.70, 0.50), mats["dark"], "ProsceniumHeader")
	# A deeper reveal above it, so the header is a soffit edge and not a beam
	# hanging in space.
	LevelKit.prop(geometry, Vector3(207.1, STORE_FLOOR + 5.10, z - 0.55),
		Vector3(24.0, 0.40, 1.60), mats["dark"], "ProsceniumReveal")
	# The fascia. الأمانات — "the property store". It used to be lost on the
	# back wall above the roofline; on the fascia it is the sign you read on
	# the approach and the caption over his head when it happens.
	PropKit.sign(geometry, "الأمانات", Vector3(206.4, STORE_FLOOR + 4.45, z + 0.28), 0.50,
		dress["paint"], PropKit.FONT_KUFI)


func _process(_delta: float) -> void:
	# Music intensity follows how much trouble is nearby, so the score reacts
	# without anyone writing a cue.
	if not is_instance_valid(player):
		return
	var near := 0
	for e: Node in get_tree().get_nodes_in_group("enemy"):
		if e is Node3D and absf((e as Node3D).global_position.x - player.global_position.x) < 26.0:
			near += 1
	Music.set_intensity(clampf(0.25 + float(near) * 0.28, 0.0, 1.0))


func _on_cage_opened() -> void:
	# Everything after the cage is a different game, and the level says so:
	# the trail turns into a firing range.
	for i in 3:
		_drone(Vector3(230.0 + i * 12.0, YARD_Y + 7.0 + i * 1.4, 0.0), 4.0)
	_turret(Vector3(224.0, YARD_Y + 8.4, 0.0))


# --- E — THE TANK FARM ------------------------------------------------------
# Armed. Drones at height, so the player has to look up and aim up. The Iced
# Out Sriracha is behind the burnt tank, off the catwalk.
#
# Atmosphere brief: vast and hot. That is bought with air, not with props — a
# long thin overhead pipe bridge to lid the sky, low bund walls to push the
# ground away, birds at height, and a wide warm haze. The section is the most
# open in the level and is dressed to stay that way.

func _section_e_tank_farm() -> void:
	# Gaps here are all inside a plain running jump (about 6 units). This is the
	# section where he is newly armed and should feel powerful, not the section
	# that tests precision.
	_deck(228.0, YARD_Y + 4.6, 16.0, mats["deck"], mats["rust"], "FarmA")
	_deck(249.0, YARD_Y + 6.2, 12.0, mats["deck"], mats["rust"], "FarmB")
	_deck(266.0, YARD_Y + 3.4, 14.0, mats["deck"], mats["rust"], "FarmC")
	_deck(284.0, YARD_Y + 5.0, 5.0, mats["deck"], mats["rust"], "FarmStep")
	_deck(295.0, YARD_Y + 6.8, 9.0, mats["deck"], mats["rust"], "Catwalk")

	# A near tank the player runs past — depth in the gameplay band, not just
	# behind it.
	PropKit.storage_tank(geometry, Vector3(258.0, YARD_Y - 1.0, -44.0), 15.0, 19.0,
		mats["tank"], mats["bund"], mats["rust"], true, mats["tank_burnt"])
	_e_tank_seven()
	_e_bunds()
	_e_pipe_bridge()
	_e_burnt_truck()
	_flock(Vector3(268.0, YARD_Y + 23.0, -34.0), 44.0, 38.0)

	TrailBuilder.jump_arc(geometry, Vector3(243.0, YARD_Y + 5.5, 0.0), 1.0, 1.0, 8)
	TrailBuilder.curve(geometry, Vector3(260.0, YARD_Y + 7.2, 0.0),
		Vector3(267.5, YARD_Y + 4.4, 0.0), 1.2, 7)
	TrailBuilder.cluster(geometry, Vector3(281.0, YARD_Y + 8.4, 0.0), 0.9, 8)
	# High line over the second deck, which is also the safest place in the
	# section to stand still and shoot from.
	TrailBuilder.cluster(geometry, Vector3(254.5, YARD_Y + 9.7, 0.0), 0.85, 7)

	_drone(Vector3(243.0, YARD_Y + 10.4, 0.0), 5.0)
	_drone(Vector3(274.0, YARD_Y + 11.2, 0.0), 6.5)
	_turret(Vector3(266.0, YARD_Y + 7.2, 0.0))
	# The first heavy, on open ground with a turret above it: the player has to
	# choose which telegraph to answer first.
	_walker(Vector3(272.0, YARD_Y + 3.7, 0.0), 4.5)
	for i in 4:
		_vent(Vector3(282.0 + i * 3.0, YARD_Y + 0.08, 0.0),
			float(i % 2) * 1.4, 4.6)
	_turret(Vector3(292.0, YARD_Y + 13.0, 0.0))
	_drone(Vector3(300.0, YARD_Y + 9.4, 0.0), 4.0)

	_checkpoint(Vector3(269.0, YARD_Y + 3.4, 0.0), 2)

	# The secret. Visible for about a second on the approach to the catwalk,
	# reachable only by gliding past the landing instead of onto it.
	# The obvious path steps across at height.
	_deck(308.0, YARD_Y + 6.2, 6.0, mats["deck"], mats["rust"], "FarmD")

	# The secret sits well below that step, in the shadow of the burnt tank.
	# On the approach it is visible for about a second through the gap; getting
	# to it means gliding past the step instead of landing on it.
	var iced := Sriracha.new()
	iced.variant = Sriracha.Variant.ICED_OUT
	iced.glow_energy = 6.0
	geometry.add_child(iced)
	iced.position = Vector3(304.0, YARD_Y - 3.4, 0.0)
	LevelKit.platform(geometry, 300.0, YARD_Y - 4.0, 8.0, mats["rust"], 0.5, 2.6, "SecretLedge")
	_nose(300.0, YARD_Y - 4.0, 8.0, 1.30)
	# And a way back up, so finding it is not a death sentence.
	LevelKit.platform(geometry, 310.0, YARD_Y - 1.4, 4.0, mats["rust"], 0.5, 2.6, "SecretStep")
	_nose(310.0, YARD_Y - 1.4, 4.0, 1.30)

	_e_hanging_catwalk()


## LANDMARK, x = 258. The unit number, painted two storeys tall on the near
## tank. A number on a tank is the most location-specific way to tell a player
## where they are without a map, and it is exactly what a real terminal does.
func _e_tank_seven() -> void:
	var face_z := -29.0
	PropKit.sign(geometry, "7", Vector3(LM_TANK_SEVEN + 1.6, YARD_Y + 4.6, face_z + 0.25), 4.6,
		dress["paint"], PropKit.FONT_NASKH)
	PropKit.sign(geometry, "خزان", Vector3(LM_TANK_SEVEN - 2.6, YARD_Y + 6.4, face_z + 0.25), 1.5,
		dress["paint"], PropKit.FONT_NASKH)
	# Hand-painted things run. The streak under the paint is what stops it
	# reading as a decal.
	for i in 3:
		LevelKit.prop(geometry, Vector3(LM_TANK_SEVEN + 0.4 + i * 1.3, YARD_Y + 1.6, face_z + 0.18),
			Vector3(0.20, 3.6 - fmod(float(i) * 1.9, 1.4), 0.10), mats["rust"], "NumberRun%d" % i)
	# A fire point below it: a rack of extinguishers and a hose reel. The one
	# piece of plant furniture that reads instantly at any distance.
	LevelKit.prop(geometry, Vector3(LM_TANK_SEVEN - 7.0, YARD_Y + 0.9, -30.5),
		Vector3(2.2, 1.8, 0.6), mats["rust"], "FirePointRack")
	for i in 3:
		_cyl_prop(geometry, Vector3(LM_TANK_SEVEN - 7.7 + i * 0.7, YARD_Y + 0.95, -30.1),
			0.16, 1.0, mats["rust"], "Extinguisher%d" % i, Vector3.ZERO, 10)
	PropKit.sign(geometry, "إطفاء", Vector3(LM_TANK_SEVEN - 7.0, YARD_Y + 2.1, -30.1), 0.42,
		dress["paint"], PropKit.FONT_NASKH)


## Low bund walls behind the play decks. Without them the decks in this section
## sit against open haze and read as floating; with them there is a continuous
## horizontal a metre behind the running line for them to sit against.
func _e_bunds() -> void:
	var z := -3.6
	for spec: Array in [[226.0, 22.0], [252.0, 16.0], [272.0, 20.0], [297.0, 18.0]]:
		var x: float = spec[0]
		var w: float = spec[1]
		LevelKit.prop(geometry, Vector3(x + w * 0.5, YARD_Y + 0.85, z),
			Vector3(w, 1.70, 0.65), mats["bund"], "Bund")
		LevelKit.prop(geometry, Vector3(x + w * 0.5, YARD_Y + 1.78, z),
			Vector3(w + 0.3, 0.16, 0.85), mats["joint"], "BundCoping")
		# Oil has been over the top of this one more than once.
		for i in int(w / 5.0):
			LevelKit.prop(geometry, Vector3(x + 2.0 + i * 5.0, YARD_Y + 0.95, z + 0.36),
				Vector3(0.55, 1.55, 0.06), dress["burnt"], "BundStain%d" % i)


## An overhead pipe bridge crossing the whole section at height. It lids the
## sky, which is the only way to make an open section feel like a plant rather
## than a field, and it is deliberately above every drone's patrol so it is
## never confused with something to stand on.
func _e_pipe_bridge() -> void:
	var y := YARD_Y + 18.0
	var z := -6.5
	LevelKit.prop(geometry, Vector3(268.0, y, z), Vector3(72.0, 0.45, 1.9),
		mats["steel"], "BridgeDeck")
	for i in 4:
		_cyl_prop(geometry, Vector3(268.0, y + 0.55 + i * 0.40, z), 0.18, 72.0,
			mats["rust"], "BridgePipe%d" % i, Vector3(0.0, 0.0, PI * 0.5), 10)
	for i in 6:
		var lx := 236.0 + i * 13.0
		LevelKit.prop(geometry, Vector3(lx, YARD_Y + 8.7, z), Vector3(0.40, 18.6, 0.40),
			mats["steel"], "BridgeLeg%d" % i)
		for dir: float in [-1.0, 1.0]:
			var br := LevelKit.prop(geometry, Vector3(lx + dir * 1.4, y - 2.1, z),
				Vector3(0.14, 5.1, 0.14), mats["steel"], "BridgeBrace")
			br.rotation.z = dir * 0.52


## LANDMARK, x = 296. It burned where it stopped and nobody moved it. Nosed
## into the bund, cab gone, one wheel off and lying flat. The blackest object
## in the level, which is why it holds the eye in the brightest section.
func _e_burnt_truck() -> void:
	var at := Vector3(LM_BURNT_TRUCK, YARD_Y, -8.6)
	_truck(at, 6.4, 2.3, dress["burnt"], true)
	# The wheel that came off.
	_cyl_prop(geometry, at + Vector3(-4.6, 0.16, 1.6), 0.62, 0.30,
		mats["dark"], "LooseWheel", Vector3(0.0, 0.0, 0.0), 14)
	# Scorch up the bund behind it, running the way the flames went.
	LevelKit.prop(geometry, at + Vector3(3.2, 1.3, 5.0), Vector3(4.6, 2.6, 0.08),
		dress["burnt"], "TruckScorch")
	# Ash and glass in a fan in front of it.
	for i in 5:
		LevelKit.prop(geometry, at + Vector3(-1.5 + i * 1.7, 0.05, 2.2 + fmod(float(i) * 1.9, 2.0)),
			Vector3(2.4 - fmod(float(i) * 0.9, 1.2), 0.04, 1.6), dress["burnt"],
			"Ash%d" % i).rotation.y = fmod(float(i) * 1.1, 0.8)


## A catwalk section hanging off its bolts at one end, pointing down into the
## dark under the step. It is the only object in the level that points at
## anything, and what it points at is the Iced Out Sriracha.
##
## It carries no nosing and sits at z = -2.4 in the dark register, which under
## this level's one readability rule means "not floor" — so it can lean over
## the gap without ever reading as a route.
func _e_hanging_catwalk() -> void:
	var z := -2.4
	var span := LevelKit.prop(geometry, Vector3(306.5, YARD_Y + 3.4, z),
		Vector3(7.4, 0.30, 1.5), mats["rust"], "HangingCatwalk")
	span.rotation.z = deg_to_rad(-58.0)
	LevelKit.prop(geometry, Vector3(304.2, YARD_Y + 5.6, z), Vector3(0.9, 0.4, 1.6),
		mats["rust"], "CatwalkBolts")
	# Its handrail came with it, bent.
	var rail := LevelKit.prop(geometry, Vector3(306.9, YARD_Y + 3.6, z + 0.6),
		Vector3(7.0, 0.07, 0.07), mats["rust"], "HangingRail")
	rail.rotation.z = deg_to_rad(-52.0)
	# Three bottles going over the edge. Enough to say "there is something
	# below"; not enough to say what, which is the whole deal with this one.
	TrailBuilder.curve(geometry, Vector3(305.6, YARD_Y + 5.4, 0.0),
		Vector3(304.4, YARD_Y + 1.6, 0.0), 0.4, 3)


# --- F — THE FENCE ----------------------------------------------------------
# Out. A chain of dash-glide gaps along the perimeter, then the gate.
#
# Atmosphere brief: wire and glare. The wire is literal — a second fence run in
# the FOREGROUND, between the camera and the play plane, from x = 314 to the
# breach at 334. He runs behind it, goes through the hole somebody else already
# made, and from x = 343 onward there is nothing in front of him at all. The
# veil lifting is the section's staging beat and it costs one skipped span.

func _section_f_fence() -> void:
	var xs := [317.0, 330.0, 343.0, 356.0]
	var ys := [6.0, 7.2, 5.2, 6.6]
	for i in xs.size():
		_deck(xs[i], YARD_Y + ys[i], 7.0, mats["deck"], mats["rust"], "FencePad%d" % i)
		if i < xs.size() - 1:
			TrailBuilder.curve(geometry,
				Vector3(xs[i] + 7.5, YARD_Y + ys[i] + 1.4, 0.0),
				Vector3(xs[i + 1] - 0.5, YARD_Y + ys[i + 1] + 1.4, 0.0), 1.6, 7)

	var link := PropKit.chainlink_material(0.42, 30.0)
	PropKit.chainlink(geometry, 314.0, YARD_Y, 58.0, 5.0, -6.0, link, mats["rust"])
	_f_perimeter_signs()
	_f_near_wire()
	_f_floodlights()
	_f_gatehouse()

	_drone(Vector3(340.0, YARD_Y + 11.0, 0.0), 5.5)
	_drone(Vector3(356.0, YARD_Y + 10.0, 0.0), 4.5)
	_turret(Vector3(348.0, YARD_Y + 6.6, 0.0))
	_turret(Vector3(368.0, YARD_Y + 9.8, 0.0))
	_walker(Vector3(346.0, YARD_Y + 5.4, 0.0), 2.4)

	# The gate out.
	_deck(366.0, YARD_Y + 6.4, 16.0, mats["deck"], mats["rust"], "GateDeck")
	LevelKit.prop(geometry, Vector3(376.0, YARD_Y + 9.4, -1.6), Vector3(6.0, 6.0, 0.4),
		mats["rust"], "GateLeaf")
	for i in 10:
		LevelKit.prop(geometry, Vector3(373.2 + i * 0.62, YARD_Y + 9.4, -1.5),
			Vector3(0.09, 5.8, 0.08), mats["steel"], "GateBar%d" % i)
	PropKit.sign(geometry, "البوابة", Vector3(376.0, YARD_Y + 12.9, -1.5), 0.48,
		MaterialLab.plaster(Color(0.58, 0.55, 0.50), 1.0), PropKit.FONT_KUFI)
	TrailBuilder.line(geometry, Vector3(370.0, YARD_Y + 7.4, 0.0),
		Vector3(379.0, YARD_Y + 7.4, 0.0), 6)

	# The exit. Reaching it ends the level.
	var exit := Area3D.new()
	exit.name = "LevelExit"
	exit.collision_layer = 0
	exit.collision_mask = 2
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 6.0, 3.0)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	exit.add_child(cs)
	exit.position = Vector3(378.0, YARD_Y + 9.4, 0.0)
	geometry.add_child(exit)
	exit.body_entered.connect(_on_exit_entered)


## Hazard plates wired to the perimeter mesh, on the pitch a real one uses —
## every thirty metres and always at a corner.
func _f_perimeter_signs() -> void:
	for x: float in [321.0, 344.0, 365.0]:
		LevelKit.prop(geometry, Vector3(x, YARD_Y + 3.2, -5.94), Vector3(1.30, 0.86, 0.05),
			dress["hazard"], "WarningPlate")
		LevelKit.prop(geometry, Vector3(x, YARD_Y + 3.2, -5.92), Vector3(1.16, 0.70, 0.04),
			dress["chevron"], "WarningField")
		PropKit.sign(geometry, "منطقة محظورة", Vector3(x, YARD_Y + 3.06, -5.88), 0.24,
			dress["paint"], PropKit.FONT_NASKH)


## LANDMARK, x = 338. The breach.
##
## The near fence runs from 314 and stops dead at 334; it picks up again at 343
## and immediately ends. Between the two the mesh is cut and rolled back on
## itself, the posts are bent out, the sand is scraped, and there is a strip of
## prison cloth left on the wire. Somebody went through here before him —
## which is the last piece of story the level tells, and it tells it without a
## word.
func _f_near_wire() -> void:
	var z := 4.4
	var base := YARD_Y + 2.0
	var near := PropKit.chainlink_material(0.55, 24.0)
	PropKit.chainlink(geometry, 314.0, base, 20.0, 6.2, z, near, mats["dark"])
	PropKit.chainlink(geometry, LM_WIRE_BREACH + 5.0, base, 6.0, 6.2, z, near, mats["dark"])
	PropKit.razor_coil(geometry, Vector3(314.0, base + 6.4, z),
		Vector3(334.0, base + 6.4, z), 0.34, mats["dark"], 22, "NearRazor")

	# The rolled-back flap: two panels of mesh bent out of plane on the hinge
	# of the cut. Quads, because a chain-link flap is a surface and not a solid.
	for spec: Array in [[334.4, 0.60, -0.42], [342.6, -0.62, 0.40]]:
		var fx: float = spec[0]
		var yaw: float = spec[1]
		var roll: float = spec[2]
		var flap := MeshInstance3D.new()
		flap.name = "WireFlap"
		var q := QuadMesh.new()
		q.size = Vector2(3.4, 4.6)
		flap.mesh = q
		flap.material_override = near
		flap.position = Vector3(fx, base + 3.0, z + 0.5)
		flap.rotation = Vector3(0.0, yaw, roll)
		geometry.add_child(flap)
		# The post it was wired to, bent out with it.
		var post := LevelKit.prop(geometry, Vector3(fx, base + 3.1, z),
			Vector3(0.11, 6.2, 0.11), mats["dark"], "BentPost")
		post.rotation.z = -roll * 0.9

	# Sand scraped aside under the cut, and the drift piled where it went.
	LevelKit.prop(geometry, Vector3(LM_WIRE_BREACH, base - 0.15, z + 0.3),
		Vector3(8.4, 0.55, 1.5), mats["dark"], "BreachDrift")

	# The strip of prison cloth on the wire. Moving — it is the only thing in
	# the section that is, and the eye goes straight to it.
	var s := Sway.new()
	s.name = "SnaggedCloth"
	s.position = Vector3(LM_WIRE_BREACH + 3.6, base + 4.2, z + 0.15)
	s.axis = Vector3(0.3, 0.15, 1.0)
	s.amplitude = 0.42
	s.speed = 1.5
	s.gust_amplitude = 0.30
	s.gust_speed = 4.1
	geometry.add_child(s)
	LevelKit.prop(s, Vector3(0.0, -0.45, 0.0), Vector3(0.26, 0.90, 0.03),
		dress["prison_cloth"], "ClothStrip").rotation.z = 0.18


## Three sodium floods still burning on the perimeter at dawn, because nobody
## turned them off. They are the "glare" half of this section's brief: hard
## warm cones in the fog, aimed down the fence line and across the run.
func _f_floodlights() -> void:
	for spec: Array in [[322.0, 9.2], [349.0, 10.4], [371.0, 9.0]]:
		var x: float = spec[0]
		var h: float = spec[1]
		LevelKit.prop(geometry, Vector3(x, YARD_Y + h * 0.5, -6.6),
			Vector3(0.22, h, 0.22), mats["steel"], "FloodPole")
		LevelKit.prop(geometry, Vector3(x + 0.5, YARD_Y + h, -6.4),
			Vector3(1.1, 0.12, 0.12), mats["steel"], "FloodArm")
		LevelKit.prop(geometry, Vector3(x + 1.0, YARD_Y + h - 0.18, -6.2),
			Vector3(0.55, 0.30, 0.42), dress["tin"], "FloodHead")
		var lamp := OmniLight3D.new()
		lamp.name = "Flood"
		lamp.light_color = Color(1.0, 0.631, 0.231)
		lamp.light_energy = 5.2
		lamp.omni_range = 15.0
		lamp.light_volumetric_fog_energy = 4.0
		lamp.shadow_enabled = false
		lamp.position = Vector3(x + 1.0, YARD_Y + h - 0.42, -6.0)
		geometry.add_child(lamp)


## The gate furniture. A gate on its own is a wall with a shape in it; a gate
## with a hut, a barrier, a stop line and a windsock is a place people used to
## have to stop at.
func _f_gatehouse() -> void:
	var f := YARD_Y + 6.4
	# The hut, set back, with its window dark.
	LevelKit.prop(geometry, Vector3(369.0, f + 1.55, -3.6), Vector3(3.2, 3.1, 2.6),
		mats["slab"], "GateHut")
	LevelKit.prop(geometry, Vector3(369.0, f + 3.25, -3.6), Vector3(3.7, 0.26, 3.0),
		mats["joint"], "GateHutCap")
	LevelKit.prop(geometry, Vector3(369.0, f + 2.10, -2.28), Vector3(1.55, 0.95, 0.06),
		mats["dark"], "GateHutGlass")
	LevelKit.prop(geometry, Vector3(370.6, f + 1.05, -2.28), Vector3(0.85, 1.95, 0.06),
		mats["door"], "GateHutDoor")

	# Boom barrier, up. A raised barrier is a better read than a broken one:
	# it says the last person through did not stop.
	LevelKit.prop(geometry, Vector3(372.0, f + 0.55, -2.0), Vector3(0.30, 1.10, 0.30),
		dress["tin"], "BoomPost")
	var boom := LevelKit.prop(geometry, Vector3(372.9, f + 2.60, -2.0),
		Vector3(4.6, 0.18, 0.18), dress["hazard"], "Boom")
	boom.rotation.z = deg_to_rad(64.0)
	for i in 4:
		var band := LevelKit.prop(geometry,
			Vector3(372.3 + i * 0.42, f + 1.30 + i * 0.86, -1.94),
			Vector3(0.42, 0.20, 0.20), dress["chevron"], "BoomBand%d" % i)
		band.rotation.z = deg_to_rad(64.0)

	# Painted stop line and the bay markings, worn to nothing in the wheel
	# tracks. Paint on the deck is edge-on to this camera, so it goes on the
	# riser instead, where it can actually be seen.
	LevelKit.prop(geometry, Vector3(371.4, f - 0.16, 1.66), Vector3(0.34, 0.24, 0.03),
		dress["paint"], "StopMark")
	PropKit.sign(geometry, "قف", Vector3(373.6, f + 0.55, -1.44), 0.36,
		dress["paint"], PropKit.FONT_NASKH)

	# The windsock: this section's DRAPE element, and the only thing at the end
	# of the level that moves against the sky.
	LevelKit.prop(geometry, Vector3(363.0, YARD_Y + 9.0, -5.2), Vector3(0.18, 12.0, 0.18),
		mats["steel"], "SockMast")
	var sock := Sway.new()
	sock.name = "Windsock"
	sock.position = Vector3(363.2, YARD_Y + 14.7, -5.2)
	sock.axis = Vector3(0.0, 0.25, 1.0)
	sock.amplitude = 0.16
	sock.speed = 0.8
	sock.gust_amplitude = 0.14
	sock.gust_speed = 3.2
	geometry.add_child(sock)
	for i in 4:
		var seg := LevelKit.prop(sock, Vector3(0.75 + i * 0.85, -0.10 - i * 0.07, 0.0),
			Vector3(0.85, 0.66 - i * 0.10, 0.66 - i * 0.10),
			dress["hazard"] if i % 2 == 0 else dress["paint"], "SockBand%d" % i)
		seg.rotation.z = -0.05 * i


var _completed := false

func _on_exit_entered(body: Node3D) -> void:
	if _completed or not (body is PlayerController):
		return
	_completed = true
	Gx.levels_cleared[level_id] = {"sriracha": Gx.sriracha}
	Gx.save_game()
	FX.hitstop(0.10)
	FX.zoom_punch(-5.0, 0.7)
	Audio.play_2d("life", -2.0, 1.0)
	print("LEVEL COMPLETE: brega, sriracha=%d" % Gx.sriracha)
	level_complete.emit()


# --- Readability ------------------------------------------------------------

## A deck, plus the nosing that makes it legible. Every catwalk in this level
## goes through here so that no future edit can add a platform and forget the
## one thing that makes platforms readable against this backdrop.
func _deck(left_x: float, top_y: float, width: float, deck_mat: Material,
		beam_mat: Material, name_: String) -> StaticBody3D:
	var body := PropKit.deck(geometry, left_x, top_y, width, 0.0, deck_mat, beam_mat,
		YARD_Y - 1.2, name_)
	_nose(left_x, top_y, width)
	return body


## The painted nosing: a continuous band along the front face of a standable
## surface, broken into black chevron blocks over the last 1.8 m at each end.
##
## It goes on the FRONT face, not the top. The camera in this game has zero
## pitch — see GameCamera, `rotation = Vector3.ZERO` — so every top surface in
## the level is exactly edge-on and paint applied to one is invisible. This is
## the single most important geometric fact about dressing a 2.5D level and it
## is worth stating out loud.
func _nose(left_x: float, top_y: float, width: float, front_z := 1.60) -> void:
	var cx := left_x + width * 0.5
	LevelKit.prop(geometry, Vector3(cx, top_y + 0.08, front_z + 0.05),
		Vector3(width, 0.13, 0.03), dress["hazard"], "Nosing")
	var blocks := mini(4, int(width / 0.9))
	for side: float in [-1.0, 1.0]:
		for i in blocks:
			var bx := cx + side * (width * 0.5 - 0.20 - float(i) * 0.44)
			LevelKit.prop(geometry, Vector3(bx, top_y + 0.08, front_z + 0.07),
				Vector3(0.22, 0.13, 0.03), dress["chevron"], "Chevron")


# --- Helpers ----------------------------------------------------------------

func _crate_stack(base: Vector3, count: int) -> void:
	for i in count:
		var c := LevelKit.box(geometry,
			base + Vector3(fmod(float(i) * 0.37, 0.4) - 0.2, 0.55 + i * 1.05, 0.0),
			Vector3(1.5, 1.05, 1.3), mats["crate"], "Crate%d" % i)
		c.rotation.z = fmod(float(i) * 0.13, 0.09) - 0.045
		c.add_to_group("surface_wood")


## LevelKit only speaks in boxes, and a plant is mostly cylinders. Local rather
## than pushed into PropKit because nothing outside this level needs it yet.
func _cyl_prop(parent: Node3D, pos: Vector3, radius: float, height: float,
		mat: Material, name_ := "Cyl", rot := Vector3.ZERO, sides := 16,
		top_radius := -1.0) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.bottom_radius = radius
	m.top_radius = radius if top_radius < 0.0 else top_radius
	m.height = height
	m.radial_segments = sides
	m.rings = 1
	var mi := MeshInstance3D.new()
	mi.name = name_
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## Loose paper on the ground, as one MultiMesh. Individually they would be a
## hundred draw calls for the cheapest storytelling in the level.
func _papers(x0: float, x1: float, y: float, z: float, count: int,
		spread: float, seed_: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = LevelKit.chamfer_mesh(Vector3(0.26, 0.012, 0.34))
	mm.instance_count = count
	for i in count:
		var p := Vector3(rng.randf_range(x0, x1), y + rng.randf_range(0.0, 0.05),
			z + rng.randf_range(-spread, spread))
		var b := Basis(Vector3.UP, rng.randf_range(0.0, TAU))
		b = b.rotated(Vector3.FORWARD, rng.randf_range(-0.14, 0.14))
		mm.set_instance_transform(i, Transform3D(b, p))
	var node := MultiMeshInstance3D.new()
	node.name = "Papers"
	node.multimesh = mm
	node.material_override = dress["paper"]
	geometry.add_child(node)


## A stripped vehicle hulk. Two masses and four wheels is enough at this
## distance; what sells it is that the cab is a different height from the bed
## and that the wheels are flat to the ground.
func _truck(at: Vector3, length: float, height: float, body_mat: Material,
		burnt := false) -> void:
	LevelKit.prop(geometry, at + Vector3(0.0, height * 0.46, 0.0),
		Vector3(length, height * 0.58, 2.1), body_mat, "TruckBed")
	LevelKit.prop(geometry, at + Vector3(length * 0.30, height * 0.86, 0.0),
		Vector3(length * 0.36, height * 0.52, 2.0), body_mat, "TruckCab")
	LevelKit.prop(geometry, at + Vector3(length * 0.30, height * 1.12, 0.0),
		Vector3(length * 0.30, 0.10, 2.1), body_mat, "TruckRoof")
	if not burnt:
		LevelKit.prop(geometry, at + Vector3(length * 0.44, height * 0.92, 0.0),
			Vector3(0.08, height * 0.34, 1.7), mats["dark"], "TruckGlass")
	for i in 4:
		var sx := -0.34 if i < 2 else 0.34
		var sz := -1.0 if i % 2 == 0 else 1.0
		_cyl_prop(geometry, at + Vector3(length * sx, 0.30, sz * 1.0), 0.32, 0.26,
			mats["dark"], "TruckWheel%d" % i, Vector3(PI * 0.5, 0.0, 0.0), 12)
	# Sand has drifted up the leeward side of anything that has stood still.
	LevelKit.prop(geometry, at + Vector3(-length * 0.1, 0.16, -1.2),
		Vector3(length * 0.8, 0.38, 1.1), mats["sand"], "TruckDrift")


## A rotating alarm beacon: a dome you can see and a narrow spot you can see
## the beam of. Built as a pivot with a looping tween because a beacon that
## sweeps is the difference between "there was an alarm" and "the alarm is
## still going".
func _beacon(at: Vector3, period := 2.4, energy := 5.0) -> void:
	var pivot := Node3D.new()
	pivot.name = "AlarmBeacon"
	pivot.position = at
	geometry.add_child(pivot)
	LevelKit.prop(pivot, Vector3(0.0, 0.0, 0.0), Vector3(0.30, 0.26, 0.30),
		dress["amber"], "BeaconDome")
	LevelKit.prop(pivot, Vector3(0.0, -0.20, 0.0), Vector3(0.36, 0.12, 0.36),
		mats["steel"], "BeaconBase")
	LevelKit.prop(pivot, Vector3(0.0, -0.52, 0.0), Vector3(0.10, 0.56, 0.10),
		mats["steel"], "BeaconStem")

	var spot := SpotLight3D.new()
	spot.name = "BeaconBeam"
	spot.light_color = Color(1.0, 0.66, 0.22)
	spot.light_energy = energy
	spot.spot_range = 13.0
	spot.spot_angle = 22.0
	spot.spot_angle_attenuation = 1.6
	spot.shadow_enabled = false
	spot.light_volumetric_fog_energy = 3.2
	# Emits along -Z; yawed a quarter turn so the beam leaves the dome
	# sideways and the pivot sweeps it round.
	spot.rotation = Vector3(deg_to_rad(-12.0), deg_to_rad(90.0), 0.0)
	pivot.add_child(spot)

	var glow := OmniLight3D.new()
	glow.name = "BeaconGlow"
	glow.light_color = Color(1.0, 0.62, 0.18)
	glow.light_energy = 1.6
	glow.omni_range = 3.2
	glow.shadow_enabled = false
	pivot.add_child(glow)

	var tw := create_tween().set_loops()
	tw.tween_property(pivot, "rotation:y", TAU, period).from(0.0)


## The guard tower searchlight, sweeping. Ping-pong rather than a full rotation
## because a light that leaves the yard and comes back reads as somebody
## looking, and a light that spins reads as a disco.
func _searchlight(at: Vector3, energy := 8.5) -> void:
	var spot := SpotLight3D.new()
	spot.name = "Searchlight"
	spot.position = at
	spot.light_color = Color(1.0, 0.86, 0.66)
	spot.light_energy = energy
	spot.spot_range = 46.0
	spot.spot_angle = 12.0
	spot.spot_angle_attenuation = 1.3
	spot.shadow_enabled = false
	spot.light_volumetric_fog_energy = 4.5
	# Tilted down and turned to face the camera side of the yard.
	spot.rotation = Vector3(deg_to_rad(-19.0), PI, 0.0)
	geometry.add_child(spot)
	LevelKit.prop(spot, Vector3(0.0, 0.0, 0.30), Vector3(0.52, 0.52, 0.46),
		dress["tin"], "SearchlightHousing")

	var tw := create_tween().set_loops()
	tw.tween_property(spot, "rotation:y", PI + 0.62, 5.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(0.8)
	tw.tween_property(spot, "rotation:y", PI - 0.62, 5.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(0.5)


## The one working light in the property store: a bulb in a wire cage on a
## cord, drifting. Its omni is the only light source inside the room, so the
## whole interior is graded off this one number.
func _hanging_bulb(at: Vector3, cord := 1.2) -> void:
	var sway := Sway.new()
	sway.name = "StoreBulb"
	sway.position = at
	sway.axis = Vector3(0.35, 0.0, 1.0)
	sway.amplitude = 0.035
	sway.speed = 0.55
	sway.gust_amplitude = 0.022
	sway.gust_speed = 1.7
	geometry.add_child(sway)

	LevelKit.prop(sway, Vector3(0.0, -cord * 0.5, 0.0), Vector3(0.03, cord, 0.03),
		mats["steel"], "Cord")
	LevelKit.prop(sway, Vector3(0.0, -cord - 0.10, 0.0), Vector3(0.11, 0.16, 0.11),
		mats["steel"], "Lampholder")
	LevelKit.prop(sway, Vector3(0.0, -cord - 0.26, 0.0), Vector3(0.14, 0.18, 0.14),
		dress["bulb"], "Bulb")
	# The wire guard. Four ribs is enough to read as a cage and to throw a
	# striped shadow, which is what makes the light feel like a real fitting.
	for i in 4:
		var rib := LevelKit.prop(sway, Vector3(0.0, -cord - 0.26, 0.0),
			Vector3(0.05, 0.42, 0.05), mats["steel"], "CageRib%d" % i)
		rib.rotation = Vector3(0.0, float(i) * 0.785, 0.34)
	var shade := LevelKit.prop(sway, Vector3(0.0, -cord - 0.02, 0.0),
		Vector3(0.52, 0.10, 0.52), dress["tin"], "Shade")
	shade.rotation.x = 0.0

	var lamp := OmniLight3D.new()
	lamp.name = "BulbLight"
	lamp.light_color = Color(1.0, 0.80, 0.52)
	lamp.light_energy = 4.6
	lamp.omni_range = 8.0
	lamp.omni_attenuation = 1.4
	# No shadow. An omni shadow is six faces of the whole scene every frame,
	# and the room is already closed on its sun side — there is nothing for it
	# to occlude that the geometry is not occluding already.
	lamp.shadow_enabled = false
	lamp.light_volumetric_fog_energy = 3.0
	lamp.position = Vector3(0.0, -cord - 0.26, 0.0)
	sway.add_child(lamp)


## Shelving: uprights, level boards, a painted bay number, then the belongings.
## The order matters — build the rack first and fill it afterwards, or it looks
## like a heap with planks in it.
func _shelf_bay(at: Vector3, width: float, levels: int, bay_number: int,
		seed_: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var h := 3.6
	var uprights := maxi(2, int(width / 2.6) + 1)
	for i in uprights:
		var x := at.x + width * float(i) / float(uprights - 1)
		LevelKit.prop(geometry, Vector3(x, at.y + h * 0.5, at.z),
			Vector3(0.10, h, 0.60), mats["steel"], "ShelfUpright")
	for lv in levels:
		var y := at.y + 0.55 + lv * 0.82
		LevelKit.prop(geometry, Vector3(at.x + width * 0.5, y, at.z),
			Vector3(width, 0.07, 0.62), dress["leather"], "ShelfBoard")
		# Contents. Small, varied, and never touching each other: a shelf of
		# identical boxes is a texture, a shelf of different objects is a
		# hundred people's belongings.
		var n := int(width / 0.95)
		for i in n:
			var px := at.x + 0.42 + float(i) * (width - 0.8) / float(maxi(n - 1, 1))
			px += rng.randf_range(-0.10, 0.10)
			var kind := rng.randi() % 5
			var size := Vector3.ZERO
			var mat: Material = dress["cloth"]
			match kind:
				0:
					size = Vector3(0.52, 0.34, 0.40)   # a bundle tied in cloth
					mat = dress["cloth"]
				1:
					size = Vector3(0.62, 0.22, 0.42)   # a case, laid flat
					mat = dress["leather"]
				2:
					size = Vector3(0.30, 0.44, 0.26)   # a stack of ledgers
					mat = dress["paper"]
				3:
					size = Vector3(0.38, 0.18, 0.30)   # a tin box
					mat = dress["tin"]
				_:
					size = Vector3(0.26, 0.30, 0.34)   # shoes, paired
					mat = dress["leather"]
			var item := LevelKit.prop(geometry,
				Vector3(px, y + 0.035 + size.y * 0.5, at.z + rng.randf_range(-0.06, 0.06)),
				size, mat, "Belonging")
			item.rotation.y = rng.randf_range(-0.30, 0.30)
			# The tag. One pale speck per object, which at this distance is
			# what makes the shelf read as catalogued rather than dumped.
			LevelKit.prop(geometry,
				Vector3(px + size.x * 0.4, y + 0.06, at.z + 0.30),
				Vector3(0.07, 0.10, 0.008), dress["paper"], "Tag")
	# Bay number, stencilled on the end upright. Western digits, per house rules.
	PropKit.sign(geometry, str(bay_number),
		Vector3(at.x + 0.02, at.y + h - 0.45, at.z + 0.34), 0.26,
		dress["paint"], PropKit.FONT_NASKH)


## A knotted bedsheet off the parapet. Segmented and tapering, with the knots
## modelled, because a plain strip reads as a banner.
func _bedsheet(top: Vector3, length: float) -> void:
	var segs := 6
	var sway := Sway.new()
	sway.name = "BedsheetRope"
	sway.position = top
	sway.axis = Vector3(0.2, 0.0, 1.0)
	sway.amplitude = 0.055
	sway.speed = 0.7
	sway.gust_amplitude = 0.045
	sway.gust_speed = 2.4
	geometry.add_child(sway)
	for i in segs:
		var t := float(i) / float(segs - 1)
		var y := -length * t
		var w := 0.30 - t * 0.07
		var seg := LevelKit.prop(sway, Vector3(t * 0.22, y - length / float(segs) * 0.5, t * 0.10),
			Vector3(w, length / float(segs), 0.07), dress["cloth"], "SheetSeg%d" % i)
		seg.rotation.z = 0.05 - t * 0.14
		if i < segs - 1:
			LevelKit.prop(sway, Vector3(t * 0.22, y - length / float(segs), t * 0.10),
				Vector3(w * 1.5, 0.16, 0.14), dress["cloth"], "SheetKnot%d" % i)
	# The frayed end, still two metres short of the ground.
	LevelKit.prop(sway, Vector3(0.24, -length - 0.18, 0.12), Vector3(0.20, 0.36, 0.05),
		dress["cloth"], "SheetTail").rotation.z = 0.4


## A plastic bag caught in the steel. Per the anti-deadness rule, every screen
## in this game has to carry something hanging that moves.
func _snagged_bag(at: Vector3, amp := 0.55, speed := 1.2) -> void:
	var pivot := Sway.new()
	pivot.name = "SnaggedBag"
	pivot.position = at
	pivot.amplitude = amp
	pivot.speed = speed
	pivot.gust_amplitude = 0.38
	pivot.axis = Vector3(0.35, 0.2, 1.0)
	geometry.add_child(pivot)
	LevelKit.prop(pivot, Vector3(0.0, -0.32, 0.0), Vector3(0.40, 0.56, 0.05),
		mats["bag"], "Bag").rotation.z = 0.2


## A thin white feather of vapour. Deliberately weak and deliberately behind
## the play plane: the level already has steam vents that hurt, and a
## decorative plume that looks like one of them is a cheat.
func _vapour(at: Vector3, dir: Vector3, amount: int, scale_: float) -> void:
	var p := GPUParticles3D.new()
	p.name = "Vapour"
	p.position = at
	p.amount = amount
	p.lifetime = 3.4
	p.preprocess = 1.4
	p.fixed_fps = 30
	p.interpolate = true
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-14, -6, -8), Vector3(28, 24, 16))

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.10
	pm.direction = dir
	pm.spread = 9.0
	pm.initial_velocity_min = 3.0
	pm.initial_velocity_max = 5.4
	pm.gravity = Vector3(0.5, 0.35, 0.0)
	pm.damping_min = 1.4
	pm.damping_max = 3.0
	pm.scale_min = scale_ * 0.5
	pm.scale_max = scale_ * 2.4
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.35
	pm.turbulence_noise_scale = 1.6
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.92, 0.90, 0.86, 0.0))
	ramp.set_color(1, Color(0.86, 0.85, 0.83, 0.0))
	ramp.add_point(0.20, Color(0.95, 0.93, 0.90, 0.40))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	p.process_material = pm

	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var sm := StandardMaterial3D.new()
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(1, 1, 1, 1)
	sm.albedo_texture = PropKit._decal_texture("radial")
	sm.vertex_color_use_as_albedo = true
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.proximity_fade_enabled = true
	sm.proximity_fade_distance = 1.0
	sm.disable_receive_shadows = true
	quad.material = sm
	p.draw_pass_1 = quad
	geometry.add_child(p)


## Birds over the tank farm. Nine dark specks on one slow tweened pass, high
## enough that they read as distance rather than as gameplay. Cheapest possible
## answer to "nothing should feel dead" in the level's emptiest section.
func _flock(at: Vector3, span: float, period: float) -> void:
	var root := Node3D.new()
	root.name = "Flock"
	root.position = at
	geometry.add_child(root)
	for i in 9:
		var off := Vector3(fmod(float(i) * 5.7, 9.0) - 4.5,
			sin(float(i) * 2.1) * 2.2, fmod(float(i) * 3.3, 6.0) - 3.0)
		var b := LevelKit.prop(root, off, Vector3(0.55, 0.06, 0.16),
			mats["dark"], "Bird%d" % i)
		b.rotation = Vector3(0.0, sin(float(i) * 1.3) * 0.4, sin(float(i) * 0.9) * 0.25)
	var tw := create_tween().set_loops()
	tw.tween_property(root, "position:x", at.x + span, period)\
		.from(at.x - span).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(root, "position:x", at.x - span, period)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## A relief valve on a cycle. `phase` staggers a row so it ripples rather than
## firing as a wall, which is the difference between a rhythm and a hit.
func _vent(at: Vector3, phase := 0.0, h := 4.2) -> SteamVent:
	var v := SteamVent.new()
	v.position = at
	v.phase = phase
	v.height = h
	geometry.add_child(v)
	return v


## The heavy. Only where there is flat ground and room to get behind it.
func _walker(at: Vector3, span: float) -> HeavyWalker:
	var w := HeavyWalker.new()
	w.position = at
	w.patrol_span = span
	geometry.add_child(w)
	return w


## A wall-mounted sentry. Facing is always -x here: everything in this level
## is shooting at a man running east.
func _turret(at: Vector3) -> WallTurret:
	var t := WallTurret.new()
	t.position = at
	geometry.add_child(t)
	return t


## Position and span go on BEFORE the node enters the tree. Enemies read their
## own position in _setup to anchor a patrol, and _setup runs inside _ready —
## so adding first and placing after gave every one of them an origin of
## (0, 0, 0) and a beat that walked back to the start of the level.
func _drone(at: Vector3, span: float) -> SnitchDrone:
	var d := SnitchDrone.new()
	d.position = at
	d.patrol_span = span
	geometry.add_child(d)
	return d


func _checkpoint(at: Vector3, index: int) -> void:
	var c := Checkpoint.new()
	geometry.add_child(c)
	c.position = at
	c.index = index
	register_checkpoint(at + c.respawn_offset)
	c.reached.connect(reach_checkpoint)


# --- Atmosphere -------------------------------------------------------------

## One global ground mist plus one local volume per section, because the brief
## for each section is different: B is open and hazy, C is shafts between
## pipes, D is a closed room with one bulb in it, E is wide and hot, F is
## glare. Fog is the cheapest way to make a 400-unit run feel like a journey
## instead of a strip, and the densities are deliberately small — the mood's
## global volumetric density is 0.0004, so 0.005 here is already a lot.
func _atmosphere() -> void:
	var fv := FogVolume.new()
	fv.name = "YardMist"
	fv.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	fv.size = Vector3(X_END - X_START + 120.0, 3.2, 40.0)
	fv.position = Vector3((X_START + X_END) * 0.5, YARD_Y + 0.4, -18.0)
	var fm := FogMaterial.new()
	# 0.026 with the old bright palette read as ground haze; against the new
	# one it is a white sheet across the bottom third of every frame.
	fm.density = 0.005
	fm.albedo = Color(1.0, 0.93, 0.82)
	fm.emission = Color(0.06, 0.045, 0.035)
	fm.height_falloff = 1.2
	fm.edge_fade = 0.5
	fv.material = fm
	add_child(fv)

	# B — open and hazy. A long shallow slab across the yard so the play decks
	# separate from the plant band, and so the searchlight beam has something
	# to be a beam in.
	_fog(Vector3(76.0, YARD_Y + 2.2, -9.0), Vector3(88.0, 6.0, 26.0), 0.0060,
		"YardHaze", 1.1, 0.45)

	# C — shafts. The key travels toward -x and +z, so a volume only produces
	# visible shafts if it sits on the CAMERA side of whatever is cutting them.
	# These sit in front of the pipe bank and behind the near risers.
	var shafts := _fog(Vector3(146.0, YARD_Y + 8.0, 0.4), Vector3(78.0, 20.0, 9.0),
		0.0048, "PipeRackShafts", 0.0, 0.30)
	(shafts.material as FogMaterial).albedo = Color(1.0, 0.90, 0.76)
	_dust(Vector3(146.0, YARD_Y + 7.0, -0.5), Vector3(76.0, 20.0, 8.0), 180, 0.05)

	# D — the room. A small, denser pocket so the one bulb has something to
	# light, and so the doorway reads as a threshold you cross into air.
	var store := _fog(Vector3(207.5, STORE_FLOOR + 1.9, -1.6), Vector3(23.0, 4.2, 4.0),
		0.0140, "StoreAir", 0.0, 0.40)
	(store.material as FogMaterial).albedo = Color(1.0, 0.88, 0.70)

	# E — wide and hot. Thin, tall and very long: the read is distance, not
	# density. Lifted off the deck so the running line itself stays crisp.
	_fog(Vector3(270.0, YARD_Y + 5.5, -14.0), Vector3(100.0, 16.0, 34.0), 0.0042,
		"FarmHeat", 0.6, 0.55)
	_dust(Vector3(270.0, YARD_Y + 4.0, -10.0), Vector3(96.0, 20.0, 18.0), 200, 0.09)

	# F — glare. Denser, and pushed toward the gate, so the last forty units
	# are a bright wall he walks into rather than more of the same yard.
	var glare := _fog(Vector3(358.0, YARD_Y + 5.0, -3.0), Vector3(56.0, 14.0, 18.0),
		0.0105, "GateGlare", 0.35, 0.45)
	(glare.material as FogMaterial).albedo = Color(1.0, 0.91, 0.78)
	_dust(Vector3(352.0, YARD_Y + 5.0, 0.0), Vector3(60.0, 16.0, 10.0), 160, 0.07)

	Audio.set_ambience("wind", -16.0)


func _fog(pos: Vector3, size: Vector3, density: float, name_: String,
		falloff := 1.2, edge := 0.5) -> FogVolume:
	var fv := FogVolume.new()
	fv.name = name_
	fv.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	fv.size = size
	fv.position = pos
	var fm := FogMaterial.new()
	fm.density = density
	fm.albedo = Color(1.0, 0.93, 0.82)
	fm.emission = Color(0.06, 0.045, 0.035)
	fm.height_falloff = falloff
	fm.edge_fade = edge
	fv.material = fm
	add_child(fv)
	return fv


## Drifting dust between the layers. These are what make a shaft visible at
## all, and what stops the gap between the play plane and the plant band
## reading as empty air.
func _dust(pos: Vector3, extents: Vector3, amount: int, scale_: float) -> void:
	var p := GPUParticles3D.new()
	p.name = "Dust"
	p.position = pos
	p.amount = amount
	p.lifetime = 16.0
	p.preprocess = 6.0
	p.fixed_fps = 30
	p.interpolate = true
	p.local_coords = false
	# The 8-unit default AABB makes particles vanish mid-effect under a
	# scrolling camera; set it to the emitter's own volume, explicitly.
	p.visibility_aabb = AABB(-extents, extents * 2.0)

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extents * 0.5
	pm.direction = Vector3(1.0, 0.14, 0.0)
	pm.spread = 22.0
	pm.initial_velocity_min = 0.22
	pm.initial_velocity_max = 0.52
	pm.gravity = Vector3(0.0, -0.02, 0.0)
	pm.scale_min = 0.55
	pm.scale_max = 1.8
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.15
	pm.turbulence_noise_scale = 2.2
	p.process_material = pm

	p.draw_pass_1 = FXKit.sprite_pass(scale_, Color(1.0, 0.86, 0.68),
		{"alpha": 0.20, "proximity": 1.4})
	add_child(p)
