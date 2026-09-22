extends Stage
## LEVEL 2 — AJDABIYA CROSSROADS.
##
## Every road east goes through this town, and this is the morning after the
## breakout. He is in his own clothes now with a rifle and a chain, and the
## level is built around that: Brega was a climb out of a hole, this is a run
## along a street with the roofs as the high road.
##
## Two lines through it, and they are the level's whole structure. The street
## is the safe, slow, generous line: awnings to run under, stalls to break
## sightlines, cover from anything above. The roofs are the fast line: longer
## gaps, less cover, better sriracha and the only way to the Iced Out bottle.
## The two lines cross at four points so the choice is never locked in.
##
## THE READABILITY CONTRACT
## -----------------------
## This level is dense on purpose, so it needs one rule that never breaks, and
## the player learns it in the first ten seconds of the market:
##
##   A pale, clean cast-coping NOSING along the camera-side edge means you can
##   stand on it. Nothing that is only dressing ever wears one.
##
## The nosing is `mats["nose"]` and it is the only material in the level with
## that value (0.66 against a town that lives between 0.33 and 0.56) and the
## only one with the ground grime turned off, so it stays a clean bright line
## even where everything around it is stained. It sits 90 mm proud of the slab
## behind it, which means it also catches the mid-morning key as a hard
## highlight and throws a shadow down the face below it.
##
## The three signals, in the order the eye picks them up:
##   1. EDGE LIP     — the nosing, proud and unbroken along every walkable edge.
##   2. VALUE STEP   — a walkable top is always a flat matte grey deck (block,
##                     0.33, no saturation at all) with the brightest line in
##                     the level drawn along its front edge, so the pair reads
##                     as one shape at any distance. Dressing is the opposite
##                     of both halves: near-black (steel 0.075, tank 0.055) or
##                     saturated (awnings, shutters, laundry, produce, the one
##                     magenta bougainvillea). Nothing in Ajdabiya is both
##                     desaturated grey and horizontal except a floor.
##   3. DEPTH BAND   — collision only ever exists across z = 0. Dressing is
##                     pushed behind z = -1.2 or in front of z = +0.9 and is
##                     built so that it never crosses the play plane, so if it
##                     overlaps him on screen it is not something he can land
##                     on. The arcade piers, the water tanks, the laundry and
##                     the cables all live in that front band on purpose: they
##                     occlude, and occlusion that never kills you is the
##                     cheapest depth cue there is.

const STREET_Y := AjdabiyaKit.STREET_Y
const X_START := -14.0
const X_END := 320.0

## The arcade. Every terrace roof in this town cantilevers seven units over the
## pavement, which without support is a slab hanging in the air — the single
## loudest unfinished-geometry tell in the level. A colonnade on the kerb line
## explains it, gives the street the covered, shaded character the design asks
## of it, and turns the run into a rhythm of verticals passing the camera.
##
## The pitch is deliberately wide: at 9.2 u/s a pier passes every 0.7 s, which
## reads as architecture. Anything tighter strobes.
const PIER_PITCH := 6.4
const PIER_Z := 2.32

## Produce. The market's whole colour budget, and the only place in the level
## where fully saturated small objects are allowed at street level.
const PRODUCE_COLOURS := [
	Color(0.560, 0.090, 0.070),   # tomatoes
	Color(0.760, 0.340, 0.050),   # oranges
	Color(0.150, 0.330, 0.110),   # peppers, mint, mloukhia
	Color(0.250, 0.110, 0.280),   # aubergine
	Color(0.720, 0.600, 0.120),   # lemons
	Color(0.330, 0.170, 0.090),   # dates
]

var mats := {}
var _completed := false


func _ready() -> void:
	level_id = "ajdabiya"
	level_title = "AJDABIYA CROSSROADS"
	spawn_point = Vector3(-8.0, STREET_Y + 1.2, 0.0)
	kill_plane_y = STREET_Y - 24.0
	music_theme = "brega"
	player_outfit = WanisBuilder.Outfit.STREET
	super._ready()
	Audio.set_ambience("wind", -20.0)


func _mood() -> LightingRig.Mood:
	return AjdabiyaKit.mood()


## SkyForge reads the rig's own key light, so this sky puts its disc, its warm
## band and its haze exactly where AjdabiyaKit.mood() aimed the sun. The
## gradient sky underneath it is fine for a dawn; a mid-morning coast is milky
## to the horizon and needs the dust band, or the top of every frame in the
## level is a clean blue that belongs to a different country.
func _sky_preset() -> String:
	return "ajdabiya_morning"


func _build_level() -> void:
	mats = AjdabiyaKit.palette()
	_extend_palette()
	AjdabiyaKit.deep_layers(geometry, mats, X_START, X_END)
	AjdabiyaKit.far_terrace(geometry, mats, X_START, X_END)
	AjdabiyaKit.street_dressing(geometry, mats, X_START, X_END)
	_street()
	_section_a_market()
	_section_b_roofs()
	_section_c_roundabout()
	_section_d_backstreet()
	_section_e_east_gate()
	_atmosphere()


## Materials this level owns on top of the shared town palette. They are built
## once and shared, because every one of them is used a few hundred times.
func _extend_palette() -> void:
	# The readability material. Pale, barely worn, and — critically — with the
	# ground grime switched off, so a nosing nine metres up on a roof parapet
	# is the same clean value as one on the first step of the market stair.
	mats["nose"] = MaterialLab.concrete(Color(0.680, 0.645, 0.575), 0.30)
	mats["nose"].set_shader_parameter("grime_amount", 0.06)
	mats["nose"].set_shader_parameter("dust_amount", 0.30)

	# Kerb paint. Black and white bands on every kerb and pier base in eastern
	# Libya, and the fastest way to make a traffic island read as a road thing.
	mats["paint"] = MaterialLab.painted_metal(Color(0.780, 0.755, 0.700), 0.95)
	mats["tarp"] = MaterialLab.cloth(Color(0.120, 0.300, 0.400), 0.95)
	mats["tarp"].cull_mode = BaseMaterial3D.CULL_DISABLED
	mats["reed"] = MaterialLab.cloth(Color(0.480, 0.390, 0.220), 0.98)
	mats["reed"].cull_mode = BaseMaterial3D.CULL_DISABLED
	mats["burnt"] = MaterialLab.rusted_metal(Color(0.075, 0.068, 0.064), 0.7)
	mats["fur"] = MaterialLab.cloth(Color(0.380, 0.230, 0.110), 0.94)
	mats["bulb"] = MaterialLab.emissive(Color(1.0, 0.80, 0.52), 3.2)
	# Bougainvillea over the alley wall: the one magenta in the whole game, and
	# it is worth it — in a town of ochre and blue shadow it stops the eye dead.
	mats["bougain"] = PropKit.foliage_material(
		Color(0.560, 0.120, 0.320), STREET_Y, 6.0, 0.55)
	mats["scrub"] = PropKit.foliage_material(
		Color(0.300, 0.300, 0.180), STREET_Y, 1.2, 0.85)
	var produce: Array = []
	for c: Color in PRODUCE_COLOURS:
		produce.append(MaterialLab.cloth(c, 0.62))
	mats["produce"] = produce
	mats["drip"] = PropKit.gradient_decal(Color(0.16, 0.15, 0.13), 0.55, "streak")
	mats["oil"] = PropKit.gradient_decal(Color(0.05, 0.05, 0.05), 0.60, "radial")


## The street plane, its kerbs, and the near terrace the roofs sit on.
func _street() -> void:
	var span := X_END - X_START
	var mid := (X_START + X_END) * 0.5
	LevelKit.box(geometry, Vector3(mid, STREET_Y - 1.0, -6.0),
		Vector3(span + 80.0, 2.0, 18.0), mats["road"], "Street")
	LevelKit.prop(geometry, Vector3(mid, STREET_Y + 0.06, 2.6),
		Vector3(span + 80.0, 0.10, 1.4), mats["kerb"], "KerbNear")
	LevelKit.prop(geometry, Vector3(mid, STREET_Y + 0.10, -14.2),
		Vector3(span + 80.0, 0.22, 1.2), mats["kerb"], "KerbFar")

	# Lamp standards down the near side, tall enough to be roof-height marks.
	for i in int(span / 26.0) + 1:
		var x := X_START + i * 26.0
		LevelKit.prop(geometry, Vector3(x, STREET_Y + 3.1, 2.2),
			Vector3(0.16, 6.2, 0.16), mats["steel"], "LampPost%d" % i)
		LevelKit.prop(geometry, Vector3(x - 0.5, STREET_Y + 6.1, 2.2),
			Vector3(1.2, 0.12, 0.12), mats["steel"], "LampArm%d" % i)
		var head := LevelKit.prop(geometry, Vector3(x - 1.0, STREET_Y + 6.0, 2.2),
			Vector3(0.5, 0.16, 0.3), mats["shade"], "LampHead%d" % i)
		head.rotation.z = 0.12
		# Painted base band: the same black-and-white the kerbs get, which is
		# what ties the lamp to the road instead of leaving it a black stick.
		LevelKit.prop(geometry, Vector3(x, STREET_Y + 0.55, 2.2),
			Vector3(0.24, 1.1, 0.24), mats["paint"], "LampBand%d" % i)


# --- A — THE MARKET ---------------------------------------------------------
# Street level, dense, slow and safe. It teaches the two lines by building a
# proper way up in plain sight and putting a whole covered souk under it.

func _section_a_market() -> void:
	_terrace(-16.0, 74.0, 6.4, 0)
	_arcade(-16.0, 74.0, 6.4, 0, [47.0, 53.0])
	_roof_dressing(-16.0, 74.0, STREET_Y + 6.4, 0, {"parapets": 2, "hut": 0.0})

	# THE SOUK, IN TWO ROWS. Authored, not stepped: widths, gaps, contents and
	# colours all vary, because seven identical stalls at nine-unit centres is
	# a fence rather than a market.
	#
	# The rows are the important part. A single row of counters at z = +1 puts
	# a continuous waist-high wall between the camera and the man, and the more
	# stalls you add the worse it gets. A real covered souk has two: one backed
	# against the shopfronts under the arcade and one out at the kerb, with the
	# aisle between them. So he runs down the aisle — half the stalls are
	# behind him where they cost nothing and read as depth, the front row is
	# broken into short runs with real gaps, and the frame gets three planes of
	# market instead of one hedge.
	#   [x, width, awning, contents, row]  row: 1 = kerb side, -1 = shop side
	var row := [
		[-7.0, 3.4, 0, "produce", 1], [-2.6, 2.6, 1, "sacks", -1],
		[2.6, 3.8, 2, "produce", 1], [7.0, 2.4, 0, "tea", -1],
		[12.4, 4.0, 1, "produce", 1], [17.4, 2.8, 2, "cart", -1],
		[22.0, 3.6, 0, "produce", 1], [26.6, 3.0, 1, "sacks", -1],
		[31.8, 3.8, 2, "produce", 1], [36.6, 2.6, 0, "tea", -1],
		[41.4, 3.4, 1, "produce", 1],
	]
	var awnings := [
		[Color(0.72, 0.24, 0.18), Color(0.86, 0.80, 0.70)],
		[Color(0.18, 0.36, 0.46), Color(0.84, 0.78, 0.66)],
		[Color(0.24, 0.40, 0.26), Color(0.82, 0.76, 0.64)],
	]
	for i in row.size():
		var s: Array = row[i]
		var x: float = s[0]
		var w: float = s[1]
		var pair: Array = awnings[int(s[2])]
		var near: bool = int(s[4]) > 0
		var sz := 1.20 if near else -2.90
		PropKit.market_stall(geometry, Vector3(x, STREET_Y, sz), w,
			mats["steel"], pair[0], pair[1], mats["crate"], i)
		# What is actually ON the stall. A market with bare counters is a row
		# of tables, and the produce is the only saturated thing the level
		# allows down at eye level.
		match String(s[3]):
			"produce":
				_produce_heap(Vector3(x - w * 0.22, STREET_Y + 1.02, sz - 0.05),
					w * 0.44, i)
				_produce_heap(Vector3(x + w * 0.26, STREET_Y + 1.02, sz - 0.05),
					w * 0.38, i + 5)
				_produce_heap(Vector3(x + 0.1, STREET_Y + 0.18, sz + 0.75),
					w * 0.5, i + 11)
			"sacks":
				_sack_pile(Vector3(x, STREET_Y, sz + 0.45), i)
			"tea":
				_tea_table(Vector3(x, STREET_Y, sz + 0.55), i)
			"cart":
				_handcart(Vector3(x, STREET_Y, sz + 0.40), i)
		# Hanging scales and a bare bulb on the stall frame: the two silhouettes
		# that say "shop" from a distance, and in the shaded back row the bulb
		# is the only light source in the arcade.
		if i % 2 == 0:
			LevelKit.prop(geometry, Vector3(x + w * 0.4, STREET_Y + 1.95, sz - 0.05),
				Vector3(0.05, 0.42, 0.05), mats["steel"], "ScaleHook")
			LevelKit.prop(geometry, Vector3(x + w * 0.4, STREET_Y + 1.70, sz - 0.05),
				Vector3(0.44, 0.07, 0.30), mats["steel"], "ScalePan")
		else:
			LevelKit.prop(geometry, Vector3(x - w * 0.3, STREET_Y + 1.88, sz - 0.05),
				Vector3(0.05, 0.30, 0.05), mats["steel"], "BulbFlex")
			LevelKit.prop(geometry, Vector3(x - w * 0.3, STREET_Y + 1.70, sz - 0.05),
				Vector3(0.14, 0.16, 0.14), mats["bulb"], "Bulb")

	# Shade sails strung from the arcade piers back over the stalls. They are
	# the reason the market floor is dappled instead of flat, and the gap left
	# at x = 46..58 is not an accident: that is where the sun lands, and the
	# light is the invitation up.
	for i in 6:
		var sx := -6.0 + i * 7.6
		_shade_sail(sx, STREET_Y + 3.15, 6.6, i)

	# Empty boxes stacked between the stalls: the floor of a market is never
	# clean and a swept one reads as a set. Staggered front and back, because
	# a continuous line of anything at knee height across the bottom of the
	# frame is a hedge, and the aisle has to stay open.
	for i in 6:
		var lx := -4.0 + i * 8.2
		_crates(Vector3(lx, STREET_Y, 1.85 if i % 2 == 0 else -2.30), 1 + i % 2)

	TrailBuilder.line(geometry, Vector3(-2.0, STREET_Y + 1.1, 0.0),
		Vector3(14.0, STREET_Y + 1.1, 0.0), 9)
	TrailBuilder.line(geometry, Vector3(22.0, STREET_Y + 1.1, 0.0),
		Vector3(38.0, STREET_Y + 1.1, 0.0), 9)

	# THE WAY UP. It used to be a stack of crates, which reads as debris you
	# happen to be able to climb. This is an invitation: a swept masonry
	# loading dock at the end of the souk with a barrow ramp onto it, a painted
	# blue handrail up the side of it, and full sun on both because the shade
	# sails deliberately stop short at x = 38.
	#
	# A RAMP, not a flight of steps. This controller has no step-up: a 300 mm
	# riser is a wall it stops dead against, and a staircase you cannot walk
	# up is a worse invitation than no invitation at all. Cast treads are laid
	# on top of the slope as decoration, which is also what a real barrow ramp
	# has on it so the wheels do not slide.
	_dock_ramp(43.2, 45.8, 1.2)
	var dock := LevelKit.box(geometry, Vector3(48.4, STREET_Y + 0.6, 0.0),
		Vector3(6.0, 1.2, 2.8), mats["render_c"], "LoadingDock")
	_nose(48.4, STREET_Y + 1.2, 6.0, 1.28)
	LevelKit.prop(dock, Vector3(0.0, -0.20, 1.42), Vector3(6.0, 0.30, 0.10),
		mats["paint"], "DockPaint")
	# Handrail up the ramp. Painted the same blue as the shutters, because a
	# handrail is the one object in a street whose only job is to say "up".
	for i in 5:
		LevelKit.prop(geometry,
			Vector3(43.4 + float(i) * 0.62, STREET_Y + 0.52 + float(i) * 0.29, 1.32),
			Vector3(0.07, 0.94, 0.07), mats["shutter_blue"], "RailPost%d" % i)
	var rail := LevelKit.prop(geometry, Vector3(44.6, STREET_Y + 1.32, 1.32),
		Vector3(3.2, 0.08, 0.08), mats["shutter_blue"], "StairRail")
	rail.rotation.z = 0.43
	_produce_heap(Vector3(50.6, STREET_Y + 1.28, 0.9), 1.2, 41)
	_sack_pile(Vector3(46.4, STREET_Y + 1.2, -1.05), 42)

	# The balconies, at the heights they were tuned at, now carried on painted
	# steel posts instead of floating out of nothing.
	_ledge(52.0, STREET_Y + 2.2, 3.0, {"posts": true, "floor_y": STREET_Y + 1.2})
	_ledge(57.0, STREET_Y + 4.1, 3.0, {"posts": true, "floor_y": STREET_Y})

	TrailBuilder.line(geometry, Vector3(41.0, STREET_Y + 1.1, 0.0),
		Vector3(44.0, STREET_Y + 1.1, 0.0), 3)
	TrailBuilder.curve(geometry, Vector3(44.4, STREET_Y + 1.5, 0.0),
		Vector3(48.4, STREET_Y + 2.2, 0.0), 0.6, 6)
	TrailBuilder.curve(geometry, Vector3(49.5, STREET_Y + 2.6, 0.0),
		Vector3(58.0, STREET_Y + 5.6, 0.0), 1.4, 9)
	# The reward for taking the climb rather than staying on the street.
	var sandwich := TunaSandwich.new()
	geometry.add_child(sandwich)
	sandwich.position = Vector3(57.5, STREET_Y + 5.3, 0.0)

	_checkpoint(Vector3(30.0, STREET_Y + 0.1, 0.0), 0)
	_drone(Vector3(40.0, STREET_Y + 4.4, 0.0), 5.0)


# --- B — THE ROOFS ----------------------------------------------------------
# The fast line. Five blocks, four four-unit gaps, and everything that lives on
# an eastern Libyan roof between them: parapets to hop, stairwell heads to land
# on, black water tanks to run behind, laundry hanging in the front band and a
# cat's cradle of somebody's cable strung across every gap.

func _section_b_roofs() -> void:
	var tops := [
		[74.0, 6.4, 13.0], [91.0, 7.6, 11.0], [106.0, 6.0, 14.0],
		[124.0, 8.4, 10.0], [138.0, 7.0, 12.0],
	]
	var dressing := [
		{"parapets": 1, "hut": 0.0, "laundry": 2},
		{"parapets": 0, "hut": 0.0, "laundry": 1, "coop": true},
		{"parapets": 1, "hut": 0.42, "laundry": 2},
		{"parapets": 0, "hut": 0.0, "laundry": 1, "rug": true},
		{"parapets": 1, "hut": 0.58, "laundry": 2, "coop": true},
	]
	for i in tops.size():
		var spec: Array = tops[i]
		var left: float = spec[0]
		var top: float = STREET_Y + float(spec[1])
		var w: float = spec[2]
		_terrace(left, left + w, spec[1], i + 1)
		_arcade(left, left + w, spec[1], i + 1)
		_roof_dressing(left, left + w, top, i + 1, dressing[i])
		# A run of bottles along each roof, so the fast line is legible as a
		# line and not as five separate decisions.
		TrailBuilder.line(geometry, Vector3(left + 1.6, top + 1.0, 0.0),
			Vector3(left + w - 1.6, top + 1.0, 0.0), int(w / 2.2))
		if i < tops.size() - 1:
			var next: Array = tops[i + 1]
			TrailBuilder.curve(geometry,
				Vector3(left + w + 0.5, top + 1.8, 0.0),
				Vector3(next[0] - 0.5, STREET_Y + float(next[1]) + 1.8, 0.0), 1.6, 8)
			_cables(left + w, top, next[0], STREET_Y + float(next[1]), i + 3)

	# The street below stays open the whole way, so falling is a demotion and
	# not a death — and it is dressed, because half the players will be down
	# there and the other half are looking down at it.
	for i in 5:
		# Same two-row souk as section A, so the street reads as one continuous
		# market running under all five blocks rather than restarting per roof.
		var sz := 1.20 if i % 2 == 0 else -2.90
		PropKit.market_stall(geometry, Vector3(80.0 + i * 12.0, STREET_Y, sz),
			3.0, mats["steel"], Color(0.70, 0.30, 0.20), Color(0.84, 0.78, 0.66),
			mats["crate"], 20 + i)
		_produce_heap(Vector3(80.0 + i * 12.0, STREET_Y + 1.02, sz - 0.05), 1.3, 60 + i)
		_crates(Vector3(85.0 + i * 12.0, STREET_Y, 1.85 if i % 2 else -2.30), 1 + i % 2)
	_handcart(Vector3(99.0, STREET_Y, 1.6), 81)
	TrailBuilder.line(geometry, Vector3(78.0, STREET_Y + 1.1, 0.0),
		Vector3(96.0, STREET_Y + 1.1, 0.0), 8)
	TrailBuilder.line(geometry, Vector3(112.0, STREET_Y + 1.1, 0.0),
		Vector3(132.0, STREET_Y + 1.1, 0.0), 9)

	# CROSSING POINT. The gap between the second and third block sits straight
	# over the street, and a column of bottles falling into it says the two
	# lines are one decision, not two routes.
	TrailBuilder.column(geometry, Vector3(104.0, STREET_Y + 1.4, 0.0), 5.0, 6)

	_drone(Vector3(98.0, STREET_Y + 11.5, 0.0), 6.0)
	_turret(Vector3(116.0, STREET_Y + 9.4, 0.0))
	_walker(Vector3(130.0, STREET_Y + 8.6, 0.0), 3.2)
	_checkpoint(Vector3(107.0, STREET_Y + 6.1, 0.0), 1)


# --- C — THE CROSSROADS -----------------------------------------------------
# The road opens out, the terrace stops, and for about forty units there is
# nothing overhead. It is the level's one wide bright frame, so it is staged
# like one: a landmark on the skyline (the gantry), a mass in the middle
# (the minibus and the containers), an island with a dead fountain behind, and
# a burnt shell and a stack of tyres anchoring the foreground.

func _section_c_roundabout() -> void:
	var x := 154.0

	# The island. Pushed behind the play plane on purpose — it is dressing, it
	# has no nosing, and the player runs in front of it rather than through it.
	LevelKit.prop(geometry, Vector3(x + 18.0, STREET_Y + 0.14, -5.6),
		Vector3(40.0, 0.28, 8.8), mats["kerb"], "Island")
	for i in 20:
		# Black-and-white kerb banding, the universal Libyan traffic island.
		LevelKit.prop(geometry, Vector3(x + 0.0 + i * 2.0, STREET_Y + 0.16, -1.3),
			Vector3(1.0, 0.30, 0.34),
			mats["paint"] if i % 2 == 0 else mats["shade"], "KerbBand%d" % i)
	_roundabout(Vector3(x + 19.0, STREET_Y, -8.0))

	# The sign gantry over the junction: the one place the level says where it
	# is, in Arabic, the way the road actually signs it.
	LevelKit.prop(geometry, Vector3(x + 10.0, STREET_Y + 3.4, -1.4),
		Vector3(0.28, 6.8, 0.28), mats["steel"], "GantryLegA")
	LevelKit.prop(geometry, Vector3(x + 28.0, STREET_Y + 3.4, -1.4),
		Vector3(0.28, 6.8, 0.28), mats["steel"], "GantryLegB")
	LevelKit.box(geometry, Vector3(x + 19.0, STREET_Y + 6.9, -1.4),
		Vector3(20.0, 0.5, 1.0), mats["steel"], "GantryBeam")
	# Lattice under the beam, and a foot with a painted band at each leg: a
	# gantry made of two sticks and a plank is a diagram, not a structure.
	for i in 9:
		var br := LevelKit.prop(geometry,
			Vector3(x + 10.6 + i * 2.1, STREET_Y + 6.25, -1.4),
			Vector3(0.10, 1.5, 0.10), mats["steel"], "GantryBrace%d" % i)
		br.rotation.z = 0.62 if i % 2 == 0 else -0.62
	for leg: float in [10.0, 28.0]:
		LevelKit.prop(geometry, Vector3(x + leg, STREET_Y + 0.22, -1.4),
			Vector3(0.9, 0.44, 0.9), mats["block"], "GantryFoot")
		LevelKit.prop(geometry, Vector3(x + leg, STREET_Y + 0.95, -1.4),
			Vector3(0.34, 1.0, 0.34), mats["paint"], "GantryBand")
	var board := LevelKit.prop(geometry, Vector3(x + 19.0, STREET_Y + 8.0, -1.6),
		Vector3(9.0, 1.8, 0.2), mats["shutter_green"], "SignBoard")
	LevelKit.prop(geometry, Vector3(x + 19.0, STREET_Y + 8.0, -1.52),
		Vector3(9.3, 0.08, 0.06), mats["cloth"], "SignBorderTop")
	PropKit.sign(geometry, "بنغازي", Vector3(x + 21.0, STREET_Y + 8.1, -1.44),
		0.62, mats["cloth"], PropKit.FONT_NASKH_BOLD)
	PropKit.sign(geometry, "أجدابيا", Vector3(x + 16.0, STREET_Y + 7.6, -1.44),
		0.40, mats["cloth"], PropKit.FONT_NASKH)
	board.rotation.y = 0.0

	# The minibus: stalled across two lanes with its bonnet up, and the first
	# big step up. Deepened to three units so its roof is a surface you land on
	# reliably rather than a sliver clipping the edge of the player capsule.
	_bus(Vector3(x + 4.0, STREET_Y, -0.9))
	_container(Vector3(x + 26.0, STREET_Y, -0.8), 6.0, 2.6, mats["shutter_blue"], 0)
	_container(Vector3(x + 33.0, STREET_Y + 2.6, -0.8), 5.0, 2.6, mats["shutter_red"], 1)
	# A second row behind them, stacked two high. The red box the player lands
	# on then reads as the front of a yard rather than a container balanced on
	# nothing — which is what it was.
	var stack: Array = [mats["shutter_green"], mats["rust"], mats["shutter_blue"]]
	for i in 3:
		LevelKit.prop(geometry, Vector3(x + 25.0 + float(i) * 6.4, STREET_Y + 1.3, -3.8),
			Vector3(6.2, 2.6, 2.6), stack[i], "YardContainer%d" % i)
	LevelKit.prop(geometry, Vector3(x + 31.4, STREET_Y + 3.9, -3.8),
		Vector3(6.2, 2.6, 2.6), mats["shutter_red"], "YardContainerTop")

	# Foreground anchors. The wide frame needs something big and dark near the
	# camera or it reads as a backdrop with a man in front of it.
	_burnt_car(Vector3(x + 13.5, STREET_Y, 2.0), 0.16)
	_tyres(Vector3(x + 22.5, STREET_Y, 2.6), 5, 7)
	_barrel(Vector3(x + 1.0, STREET_Y, 2.4), true)
	_barrel(Vector3(x + 1.9, STREET_Y, 2.9), false)
	PropKit.sandbag_row(geometry, x + 29.0, STREET_Y, 6.0, 2.5, mats["crate"], 2)
	_kiosk(Vector3(x + 40.0, STREET_Y, -4.6))

	# Traffic signal, dead, on the corner. Nothing in this town has power this
	# morning and the level should say so once rather than explain it.
	LevelKit.prop(geometry, Vector3(x + 37.0, STREET_Y + 2.2, -2.2),
		Vector3(0.18, 4.4, 0.18), mats["steel"], "SignalPost")
	LevelKit.prop(geometry, Vector3(x + 37.0, STREET_Y + 4.9, -2.2),
		Vector3(0.42, 1.25, 0.34), mats["shade"], "SignalHead")
	for i in 3:
		LevelKit.prop(geometry, Vector3(x + 37.0, STREET_Y + 5.3 - i * 0.36, -2.04),
			Vector3(0.22, 0.22, 0.06), mats["dark"], "SignalLens%d" % i)

	TrailBuilder.jump_arc(geometry, Vector3(x + 12.0, STREET_Y + 3.4, 0.0), 1.0, 1.0, 8)
	TrailBuilder.line(geometry, Vector3(x - 6.0, STREET_Y + 1.1, 0.0),
		Vector3(x + 2.0, STREET_Y + 1.1, 0.0), 5)
	TrailBuilder.curve(geometry, Vector3(x + 21.0, STREET_Y + 3.6, 0.0),
		Vector3(x + 27.0, STREET_Y + 3.6, 0.0), 1.1, 6)
	TrailBuilder.cluster(geometry, Vector3(x + 29.0, STREET_Y + 6.4, 0.0), 0.9, 8)

	_turret(Vector3(x + 34.0, STREET_Y + 8.6, 0.0))
	_drone(Vector3(x + 16.0, STREET_Y + 10.0, 0.0), 6.5)
	_checkpoint(Vector3(x + 2.0, STREET_Y + 0.1, 0.0), 2)


# --- D — THE BACK STREET ----------------------------------------------------
# Narrow, shaded and vertical. The far side of the crossroads is a service lane
# with the wall pulled right up behind the play plane, so the balconies grow
# out of it instead of hovering in a void, and the colonnade on the other side
# closes the slot. The Iced Out bottle is at the top of it.

func _section_d_backstreet() -> void:
	var x := 208.0
	# The climb. Heights and spacing are exactly as tuned; what changed is that
	# every one of them is now a balcony bolted to a wall you can see behind
	# it, with a nosing on its front edge and a painted rail above.
	var rungs := [
		[x + 2.0, 2.4, 3.2], [x + 8.0, 4.2, 2.8], [x + 14.0, 6.0, 3.0],
		[x + 20.0, 4.6, 2.6], [x + 26.0, 7.2, 3.4], [x + 33.0, 5.4, 3.0],
		[x + 39.0, 8.0, 3.2],
	]
	_alley_block(x - 4.0, x + 46.0, 9.2, 30, rungs)
	_arcade(x - 4.0, x + 46.0, 9.2, 30, [], true)
	_roof_dressing(x - 4.0, x + 46.0, STREET_Y + 9.2, 30,
		{"parapets": 3, "hut": 0.30, "laundry": 3, "rug": true, "coop": true})

	for i in rungs.size():
		var r: Array = rungs[i]
		_ledge(r[0], STREET_Y + float(r[1]), r[2], {"wall_z": -1.5, "seed": i})
		if i > 0:
			var p: Array = rungs[i - 1]
			TrailBuilder.curve(geometry,
				Vector3(p[0] + float(p[2]) * 0.5, STREET_Y + float(p[1]) + 1.5, 0.0),
				Vector3(r[0] - float(r[2]) * 0.5, STREET_Y + float(r[1]) + 1.5, 0.0),
				1.3, 6)

	for i in 4:
		_vent(Vector3(x + 5.0 + i * 9.0, STREET_Y + 0.06, 0.0), float(i % 2) * 1.3, 4.0)

	# The floor of the lane. A service alley is where a street puts the things
	# it does not want seen, and that is the entire character of the section.
	# Nothing here sits in the 640 mm of depth the player capsule occupies.
	# The skip is the exception on purpose — it goes in the FRONT band with
	# the colonnade, so he runs behind it and the lane gets a foreground.
	_skip(Vector3(x + 2.8, STREET_Y, 1.45))
	_bin(Vector3(x + 11.5, STREET_Y, -1.05), mats["shutter_green"], 0.1)
	_bin(Vector3(x + 12.7, STREET_Y, -1.10), mats["shutter_blue"], -0.06)
	_crates(Vector3(x + 17.0, STREET_Y, -1.15), 2)
	_tyres(Vector3(x + 24.0, STREET_Y, -1.20), 3, 21)
	_bin(Vector3(x + 30.0, STREET_Y, -1.05), mats["rust"], 0.04)
	_sack_pile(Vector3(x + 36.0, STREET_Y, -1.15), 22)

	# The dead end, and the only living thing in the level that is not trying
	# to kill him.
	_blocked_alley(Vector3(x + 42.5, STREET_Y, -1.4))

	# Bougainvillea over the wall above the dead end: the magenta note, and the
	# only place in the level it appears.
	_bougainvillea(Vector3(x + 43.0, STREET_Y + 3.6, -1.2), 5.0, 7)
	_bougainvillea(Vector3(x + 9.0, STREET_Y + 5.0, -1.2), 3.6, 9)

	_walker(Vector3(x + 22.0, STREET_Y + 0.2, 0.0), 6.0)
	_turret(Vector3(x + 30.0, STREET_Y + 11.0, 0.0))
	_drone(Vector3(x + 36.0, STREET_Y + 12.4, 0.0), 5.0)

	var sandwich := TunaSandwich.new()
	geometry.add_child(sandwich)
	sandwich.position = Vector3(x + 20.0, STREET_Y + 6.0, 0.0)

	# THE ICED OUT BOTTLE. Still on the highest thing in the level, but the
	# last step up to it is now a thing you can see from the bottom of the
	# alley: the roof's water tank stand, with a nosing on it like everything
	# else you can stand on. Fair, and still only findable by going up.
	var stand := LevelKit.box(geometry, Vector3(x + 41.5, STREET_Y + 10.0, 0.0),
		Vector3(2.4, 1.6, 2.2), mats["block"], "TankStand")
	_nose(x + 41.5, STREET_Y + 10.8, 2.4, 0.98)
	LevelKit.prop(stand, Vector3(0.0, 1.25, -0.9), Vector3(1.5, 0.9, 1.5),
		mats["tank"], "RoofTank")
	var iced := Sriracha.new()
	iced.variant = Sriracha.Variant.ICED_OUT
	geometry.add_child(iced)
	iced.position = Vector3(x + 44.0, STREET_Y + 12.4, 0.0)

	_checkpoint(Vector3(x + 21.0, STREET_Y + 4.6, 0.0), 3)


# --- E — THE EAST GATE ------------------------------------------------------
# The road out. The gate is an event: the town stops, the scrub starts, and the
# last thing in Ajdabiya is a checkpoint hut nobody is manning any more.

func _section_e_east_gate() -> void:
	var x := 262.0
	_terrace(x, x + 22.0, 7.4, 40)
	_arcade(x, x + 22.0, 7.4, 40)
	_roof_dressing(x, x + 22.0, STREET_Y + 7.4, 40, {"parapets": 1, "hut": 0.0, "laundry": 2})

	# The last three roofs of the town, stepping down to the road. They are
	# roofs, not balconies: parapet, nosing, an aerial, and nothing hanging off
	# the front, so the descending rhythm reads as buildings getting smaller.
	_ledge(x + 26.0, STREET_Y + 5.8, 4.0, {"roof": true, "seed": 1})
	_ledge(x + 34.0, STREET_Y + 4.2, 4.0, {"roof": true, "seed": 2})
	_ledge(x + 42.0, STREET_Y + 2.6, 5.0, {"roof": true, "seed": 3})

	TrailBuilder.curve(geometry, Vector3(x + 23.0, STREET_Y + 9.0, 0.0),
		Vector3(x + 44.0, STREET_Y + 4.4, 0.0), 2.2, 14)
	TrailBuilder.line(geometry, Vector3(x + 45.0, STREET_Y + 3.6, 0.0),
		Vector3(x + 51.0, STREET_Y + 3.6, 0.0), 5)

	for i in 3:
		var sz := 1.20 if i % 2 == 0 else -2.90
		PropKit.market_stall(geometry, Vector3(x + 6.0 + i * 8.0, STREET_Y, sz),
			3.0, mats["steel"], Color(0.20, 0.38, 0.48), Color(0.84, 0.78, 0.66),
			mats["crate"], 60 + i)
		_produce_heap(Vector3(x + 6.0 + i * 8.0, STREET_Y + 1.02, sz - 0.05), 1.2, 70 + i)

	_turret(Vector3(x + 20.0, STREET_Y + 9.6, 0.0))
	_drone(Vector3(x + 32.0, STREET_Y + 9.0, 0.0), 5.0)

	# The blue direction sign before the gate. Ordinary road furniture, and the
	# thing that tells you the level is about to end without a word of UI.
	for side in 2:
		LevelKit.prop(geometry, Vector3(x + 37.4 + side * 3.2, STREET_Y + 2.6, -2.6),
			Vector3(0.16, 5.2, 0.16), mats["steel"], "DirPost%d" % side)
	LevelKit.prop(geometry, Vector3(x + 39.0, STREET_Y + 5.4, -2.6),
		Vector3(4.6, 1.5, 0.16), mats["sign"], "DirBoard")
	PropKit.sign(geometry, "بنغازي ١٥٠", Vector3(x + 39.0, STREET_Y + 5.45, -2.48),
		0.40, mats["cloth"], PropKit.FONT_NASKH)

	# The checkpoint hut, its barrier left up, and the sandbags nobody is
	# behind. Staged off the play plane so it frames the gate without ever
	# being something he tries to land on.
	_checkpoint_hut(Vector3(x + 45.0, STREET_Y, -4.4))
	_barrier(Vector3(x + 47.0, STREET_Y, -1.9))
	PropKit.sandbag_row(geometry, x + 43.0, STREET_Y, 4.0, -2.4, mats["crate"], 3)
	_barrel(Vector3(x + 44.0, STREET_Y, 2.3), true)

	# The gate.
	for side in 2:
		LevelKit.prop(geometry, Vector3(x + 50.0, STREET_Y + 3.0, -3.0 + side * 6.0),
			Vector3(1.6, 6.0, 1.6), mats["render_c"], "GatePier%d" % side)
		LevelKit.prop(geometry, Vector3(x + 50.0, STREET_Y + 6.15, -3.0 + side * 6.0),
			Vector3(2.0, 0.34, 2.0), mats["kerb"], "GateCap%d" % side)
		LevelKit.prop(geometry, Vector3(x + 50.0, STREET_Y + 0.55, -3.0 + side * 6.0),
			Vector3(1.9, 1.1, 1.9), mats["paint"], "GateBand%d" % side)
		# A lamp on each pier, aimed inward across the road.
		LevelKit.prop(geometry, Vector3(x + 50.0, STREET_Y + 6.75, -3.0 + side * 6.0),
			Vector3(0.5, 0.9, 0.5), mats["steel"], "GateLamp%d" % side)
	LevelKit.prop(geometry, Vector3(x + 50.0, STREET_Y + 6.4, 0.0),
		Vector3(1.8, 0.9, 8.0), mats["block"], "GateBeam")
	LevelKit.prop(geometry, Vector3(x + 50.0, STREET_Y + 7.0, 0.0),
		Vector3(2.2, 0.32, 8.4), mats["kerb"], "GateBeamCap")
	PropKit.sign(geometry, "الطريق الساحلي",
		Vector3(x + 50.0, STREET_Y + 6.45, 0.95), 0.44, mats["cloth"],
		PropKit.FONT_NASKH)

	# The town thinning into scrub. Past the gate the ground stops being a
	# street: sand drifts across the tarmac, the kerb breaks up, and the last
	# man-made thing is a guardrail heading for the coast road.
	for i in 12:
		var sx := x + 44.0 + i * 1.6
		LevelKit.prop(geometry, Vector3(sx, STREET_Y + 0.05, -7.0 + fmod(float(i) * 3.3, 6.0)),
			Vector3(2.6, 0.12, 2.2), mats["dust"], "SandDrift%d" % i)
	for i in 14:
		_scrub(x + 40.0 + i * 1.9, -9.0 - fmod(float(i) * 4.7, 7.0), i)
		if i % 3 == 0:
			_scrub(x + 41.0 + i * 1.9, 3.4 + fmod(float(i) * 1.7, 1.4), i + 40)
	for i in 5:
		LevelKit.prop(geometry, Vector3(x + 53.0 + i * 3.2, STREET_Y + 0.62, -4.4),
			Vector3(0.14, 1.24, 0.14), mats["steel"], "GuardPost%d" % i)
	LevelKit.prop(geometry, Vector3(x + 59.0, STREET_Y + 1.15, -4.3),
		Vector3(16.0, 0.34, 0.10), mats["paint"], "GuardRail")

	var exit := Area3D.new()
	exit.name = "Exit"
	exit.collision_layer = 0
	exit.collision_mask = 2
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.5, 7.0, 4.0)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	exit.add_child(cs)
	geometry.add_child(exit)
	exit.position = Vector3(x + 52.0, STREET_Y + 3.4, 0.0)
	exit.body_entered.connect(_on_exit_entered)


# --- Structure --------------------------------------------------------------

## A run of terrace: the solid block, its roof as a platform, shopfronts along
## the street and the roof kit on top.
func _terrace(left_x: float, right_x: float, height: float, seed_: int) -> void:
	var w := right_x - left_x
	LevelKit.box(geometry, Vector3(left_x + w * 0.5, STREET_Y + height * 0.5, -9.0),
		Vector3(w, height, 8.0), mats["render"], "Terrace%d" % seed_)
	# The roof itself is the platform, at z = 0 where the player lives.
	LevelKit.box(geometry, Vector3(left_x + w * 0.5, STREET_Y + height - 0.25, -1.5),
		Vector3(w, 0.5, 7.0), mats["block"], "TerraceRoof%d" % seed_)
	PropKit.roof_kit(geometry, left_x + 0.8, STREET_Y + height, w - 1.6, -5.0,
		mats["block"], mats["tank"], mats["rebar"], seed_)
	PropKit.building_massing(geometry, left_x, STREET_Y, w, height, -5.0,
		mats["render_c"], mats["block"], 0, seed_)
	AjdabiyaKit.town_facade(geometry, mats, left_x + 0.6, STREET_Y + 3.8,
		w - 1.2, height - 4.3, -4.96, seed_ + 3)
	# One stairwell per terrace, set back behind the play line.
	PropKit.stair_head(geometry,
		Vector3(left_x + w * 0.5 + fmod(float(seed_) * 3.7, 4.0) - 2.0,
			STREET_Y + height, -4.2),
		mats["render_b"], mats["shutter_blue"], mats["block"])

	var shutters: Array = [mats["shutter_blue"], mats["shutter_green"], mats["shutter_red"]]
	var bays := maxi(1, int(w / 4.6))
	for i in bays:
		PropKit.shopfront(geometry,
			Vector3(left_x + (float(i) + 0.5) * (w / float(bays)), STREET_Y, -4.9),
			w / float(bays) - 0.5, 3.4, mats["render_b"],
			shutters[(seed_ + i) % shutters.size()], mats["sign"],
			(seed_ + i) % 3 == 0)
	# An awning over every other bay, throwing a hard shadow on the wall.
	for i in bays:
		if (seed_ + i) % 2 != 0:
			continue
		var a := LevelKit.prop(geometry,
			Vector3(left_x + (float(i) + 0.5) * (w / float(bays)), STREET_Y + 3.5, -3.7),
			Vector3(w / float(bays) - 0.6, 0.08, 2.0), mats["cloth"], "Awning%d_%d" % [seed_, i])
		a.rotation.x = -0.16


## The back street's block. Same roof, same height, same everything the
## traversal cares about — but the face is pulled forward to z = -1.5 instead
## of z = -4.9, which is the whole difference between a lane and a plaza.
## The balconies then grow out of a wall the player can see behind them, and
## with the colonnade on the other side the slot is three and a half units
## wide, which is what "narrow" means in a game shot from sixteen units back.
func _alley_block(left_x: float, right_x: float, height: float, seed_: int,
		rungs: Array = []) -> void:
	var w := right_x - left_x
	var cx := left_x + w * 0.5
	LevelKit.box(geometry, Vector3(cx, STREET_Y + height * 0.5, -4.6),
		Vector3(w, height, 6.2), mats["render"], "AlleyBlock%d" % seed_)
	LevelKit.box(geometry, Vector3(cx, STREET_Y + height - 0.25, -1.5),
		Vector3(w, 0.5, 7.0), mats["block"], "TerraceRoof%d" % seed_)
	PropKit.roof_kit(geometry, left_x + 0.8, STREET_Y + height, w - 1.6, -4.0,
		mats["block"], mats["tank"], mats["rebar"], seed_)
	PropKit.building_massing(geometry, left_x, STREET_Y, w, height, -1.6,
		mats["render_c"], mats["block"], 0, seed_)

	# Windows, NOT the shared town facade. That builder hangs a balcony off
	# every other bay, and this wall already has seven of them bolted to it —
	# the ones the player stands on. Two sets of balconies on one face at
	# arm's length from each other is the fastest way to make a climbable thing
	# stop reading as climbable.
	#
	# And where a rung IS, the wall gets the door that balcony belongs to
	# instead of a window, so every platform in the section has a reason to be
	# there. A window with a slab cutting through its sill is the kind of
	# small wrongness that reads as "generated" even when nobody can name it.
	var floors := maxi(1, int((height - 3.0) / 2.9))
	var cols := maxi(2, int(w / 3.4))
	for f in floors:
		var wy := STREET_Y + 3.6 + float(f) * 2.9
		for c in cols:
			var wx := left_x + (float(c) + 0.5) * (w / float(cols))
			var blocked := false
			for r: Array in rungs:
				if absf(float(r[0]) - wx) < float(r[2]) * 0.5 + 0.9 \
						and absf(STREET_Y + float(r[1]) - wy) < 1.7:
					blocked = true
					break
			if blocked:
				continue
			PropKit.window(geometry, Vector3(wx, wy, -1.48), Vector2(0.78, 1.20),
				0.24, mats["render_b"], mats["shade"],
				mats["shutter_blue"] if (seed_ + c + f) % 3 == 0 else null,
				-0.5 if (seed_ + c) % 4 == 0 else -0.12)

	# The door onto each balcony, with its lintel and the light inside it.
	for i in rungs.size():
		var r: Array = rungs[i]
		var ry := STREET_Y + float(r[1])
		LevelKit.prop(geometry, Vector3(float(r[0]), ry + 1.05, -1.42),
			Vector3(0.92, 2.05, 0.10), mats["dark"], "BalconyDoorVoid%d" % i)
		LevelKit.prop(geometry, Vector3(float(r[0]) + 0.24, ry + 1.05, -1.36),
			Vector3(0.44, 2.05, 0.06),
			mats["shutter_blue"] if i % 2 == 0 else mats["shutter_green"],
			"BalconyDoor%d" % i)
		LevelKit.prop(geometry, Vector3(float(r[0]), ry + 2.20, -1.34),
			Vector3(1.24, 0.18, 0.28), mats["block"], "BalconyLintel%d" % i)

	# Ground floor of a back street: service doors, meter boxes, a standpipe
	# and a lot of stained render. No shopfronts — nobody sells anything here.
	var bays := maxi(1, int(w / 5.0))
	for i in bays:
		var bx := left_x + (float(i) + 0.5) * (w / float(bays))
		LevelKit.prop(geometry, Vector3(bx, STREET_Y + 1.05, -1.42),
			Vector3(1.0, 2.1, 0.10),
			mats["shutter_green"] if i % 2 == 0 else mats["shutter_red"], "AlleyDoor%d" % i)
		LevelKit.prop(geometry, Vector3(bx, STREET_Y + 2.22, -1.36),
			Vector3(1.3, 0.16, 0.26), mats["block"], "DoorLintel%d" % i)
		LevelKit.prop(geometry, Vector3(bx + 1.5, STREET_Y + 1.45, -1.36),
			Vector3(0.42, 0.55, 0.22), mats["steel"], "MeterBox%d" % i)
		# Downpipe, and the stain that runs from the bottom of it.
		LevelKit.prop(geometry, Vector3(bx - 1.9, STREET_Y + height * 0.42, -1.34),
			Vector3(0.16, height * 0.84, 0.16), mats["rust"], "Downpipe%d" % i)
		_decal(Vector3(bx - 1.9, STREET_Y + 1.6, -1.30), Vector2(1.1, 3.2), mats["drip"])

	# Air conditioners, each with the stain of twenty summers under it. This is
	# the detail that dates a Libyan back street more than any signage.
	for i in maxi(2, int(w / 7.0)):
		var ax := left_x + 2.5 + float(i) * (w / float(maxi(2, int(w / 7.0))))
		var ay := STREET_Y + 3.2 + fmod(float(i) * 2.7, 4.2)
		_ac_unit(Vector3(ax, ay, -1.34), i)


## The colonnade under the overhang. Piers on the kerb line, a capital, a
## painted base band and a cross beam back under the soffit. It is what stops
## a seven-unit cantilever reading as a slab someone forgot to finish.
##
## Non-colliding on purpose: at z = +2.32 the piers are two full units in front
## of the player capsule, so they pass across him and never catch him. That is
## the whole trick of the front band — occlusion with no consequence.
func _arcade(left_x: float, right_x: float, height: float, seed_: int,
		skip_ranges: Array = [], lamps := false) -> void:
	var soffit := STREET_Y + height - 0.5
	var x := left_x + PIER_PITCH * 0.5
	var i := 0
	while x < right_x - 1.0:
		var skip := false
		if skip_ranges.size() >= 2 and x > float(skip_ranges[0]) and x < float(skip_ranges[1]):
			skip = true
		# A lamp standard stands where a pier would: the two are on the same
		# line and the street only ever built one of them.
		if fmod(x - X_START, 26.0) < 1.4:
			skip = true
		if not skip:
			LevelKit.prop(geometry, Vector3(x, (STREET_Y + soffit) * 0.5, PIER_Z),
				Vector3(0.40, soffit - STREET_Y, 0.44), mats["render_c"], "Pier%d_%d" % [seed_, i])
			LevelKit.prop(geometry, Vector3(x, soffit - 0.26, PIER_Z),
				Vector3(0.62, 0.30, 0.66), mats["render_b"], "PierCap%d_%d" % [seed_, i])
			LevelKit.prop(geometry, Vector3(x, STREET_Y + 0.14, PIER_Z),
				Vector3(0.58, 0.28, 0.62), mats["block"], "PierBase%d_%d" % [seed_, i])
			LevelKit.prop(geometry, Vector3(x, STREET_Y + 0.72, PIER_Z),
				Vector3(0.46, 0.90, 0.50), mats["paint"], "PierBand%d_%d" % [seed_, i])
			# The beam it carries, running back under the roof slab.
			LevelKit.prop(geometry, Vector3(x, soffit - 0.17, -1.4),
				Vector3(0.32, 0.34, 6.8), mats["render_b"], "Soffit%d_%d" % [seed_, i])
			if lamps and i % 3 == 1:
				LevelKit.prop(geometry, Vector3(x, soffit - 0.70, 0.6),
					Vector3(0.035, 0.75, 0.035), mats["steel"], "Flex%d" % i)
				LevelKit.prop(geometry, Vector3(x, soffit - 1.15, 0.6),
					Vector3(0.22, 0.24, 0.22), mats["bulb"], "ArcadeBulb%d" % i)
		x += PIER_PITCH
		i += 1
	# A fascia along the front edge of the slab, tying the capitals together.
	LevelKit.prop(geometry, Vector3((left_x + right_x) * 0.5, soffit - 0.12,
		PIER_Z - 0.22), Vector3(right_x - left_x, 0.36, 0.30),
		mats["render_b"], "Fascia%d" % seed_)


## Everything that lives on a flat roof in this town, and the reason the fast
## line stopped being a row of slabs.
##
## Read the z values as the depth contract: the parapet nosing runs along the
## front at +1.88 where it is unmissable, the tanks and laundry sit in the
## front band at +1.2 to +1.6 so the player runs BEHIND them, the aerials and
## coops go back at -3.4 to -4.4 against the sky, and the only things that
## cross z = 0 are the two things he is meant to land on: the division
## parapets and the stairwell head.
func _roof_dressing(left_x: float, right_x: float, top_y: float, seed_: int,
		opts := {}) -> void:
	var w := right_x - left_x
	var cx := left_x + w * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_ * 911 + 17

	# 1. THE EDGE. The unbroken pale lip along the camera-side edge of every
	#    roof, plus a short return at each end behind the play line so the
	#    corner reads as a corner and not as a cut.
	_nose(cx, top_y, w, 1.88, 0.38)
	for side in 2:
		LevelKit.prop(geometry,
			Vector3(left_x + float(side) * w, top_y + 0.01, -2.95),
			Vector3(0.38, 0.16, 4.1), mats["nose"], "RoofReturn%d" % side)
		# The parapet returning down the end wall: a roof that stops in a clean
		# line has no thickness.
		LevelKit.prop(geometry,
			Vector3(left_x + float(side) * w, top_y - 0.45, -1.6),
			Vector3(0.30, 0.70, 6.6), mats["render_b"], "RoofEnd%d" % side)

	# 2. DIVISION PARAPETS. Neighbours build to the line and put a low block
	#    wall between properties, so a run of roofs is a run of hurdles. They
	#    collide, they are 0.62 high against a 3.15 jump, and they are never
	#    within three units of an edge so they can never eat a tuned gap.
	var parapets := int(opts.get("parapets", 0))
	for i in parapets:
		var px := left_x + w * (float(i) + 1.0) / float(parapets + 1)
		if px - left_x < 3.4 or right_x - px < 3.4:
			continue
		LevelKit.box(geometry, Vector3(px, top_y + 0.31, -1.5),
			Vector3(0.34, 0.62, 6.6), mats["render_c"], "Division%d_%d" % [seed_, i])
		LevelKit.prop(geometry, Vector3(px, top_y + 0.68, -1.5),
			Vector3(0.48, 0.14, 6.8), mats["nose"], "DivisionCap%d_%d" % [seed_, i])
		# Telegraph it. Every hop in this level is drawn in the air first.
		TrailBuilder.curve(geometry, Vector3(px - 2.2, top_y + 1.0, 0.0),
			Vector3(px + 2.2, top_y + 1.0, 0.0), 1.0, 5)

	# 3. THE STAIRWELL HEAD. The one person-sized thing on a roof, which is
	#    what gives the rest of it scale — and here it is also a platform,
	#    because the fast line should have something to go over as well as
	#    across.
	var hut_t := float(opts.get("hut", 0.0))
	if hut_t > 0.0:
		var hx := left_x + w * hut_t
		_roof_hut(hx, top_y, seed_)
		TrailBuilder.curve(geometry, Vector3(hx - 3.0, top_y + 1.2, 0.0),
			Vector3(hx + 3.0, top_y + 1.2, 0.0), 1.9, 7)

	# 4. THE FRONT BAND. Water tanks on stands, and the player running behind
	#    them. Black against a lit roof, so they read as silhouette holes.
	#    Rationed hard — one every fourteen units at most. Foreground
	#    occlusion is a depth cue in ones and twos and a fence in sixes, and
	#    this is the line where he is timing jumps.
	var tanks := clampi(int(w / 14.0), 1, 4)
	for i in tanks:
		var tx := left_x + w * (float(i) + 0.7) / float(tanks + 1)
		if tx > right_x - 1.4 or tx < left_x + 1.4:
			continue
		LevelKit.prop(geometry, Vector3(tx, top_y + 0.20, 1.32),
			Vector3(1.0, 0.40, 0.80), mats["rebar"], "FrontStand%d" % i)
		LevelKit.prop(geometry, Vector3(tx, top_y + 0.86, 1.32),
			Vector3(0.90, 0.92, 0.84), mats["tank"], "FrontTank%d" % i)
		LevelKit.prop(geometry, Vector3(tx, top_y + 1.40, 1.32),
			Vector3(0.16, 0.22, 0.16), mats["rust"], "TankInlet%d" % i)

	# 5. LAUNDRY, in the front band. Hung high enough that the bottom of the
	#    cloth clears a standing man by a hand's width: he runs under it and
	#    it crosses the frame in front of him, which is the whole point, but
	#    it never sits over his head or his feet where it would cost a read.
	var lines := int(opts.get("laundry", 0))
	var colours := [
		Color(0.72, 0.26, 0.20), Color(0.20, 0.38, 0.50), Color(0.86, 0.82, 0.70),
		Color(0.26, 0.42, 0.28), Color(0.78, 0.60, 0.22),
	]
	for i in lines:
		var lx := left_x + w * (float(i) + 0.6) / float(lines + 1)
		var span: float = minf(4.4, w * 0.35)
		if lx - span * 0.5 < left_x + 0.6 or lx + span * 0.5 > right_x - 0.6:
			continue
		for side in 2:
			LevelKit.prop(geometry,
				Vector3(lx + (float(side) - 0.5) * span, top_y + 1.55, 1.62),
				Vector3(0.09, 3.1, 0.09), mats["steel"], "LineMast%d_%d" % [i, side])
		PropKit.laundry_line(geometry,
			Vector3(lx - span * 0.5, top_y + 2.95, 1.62),
			Vector3(lx + span * 0.5, top_y + 2.95, 1.62), 0.16,
			mats["rust"], colours, seed_ * 13 + i)

	# 6. THE SKYLINE BAND. Aerials, dishes and the cable poles they hang off,
	#    all the way at the back where they are pure silhouette.
	PropKit.roof_clutter(geometry, left_x + 1.0, top_y, w - 2.0, -3.6,
		mats["steel"], seed_ * 29 + 7)
	for i in maxi(1, int(w / 9.0)):
		var mx := left_x + 2.0 + float(i) * 8.5
		if mx > right_x - 1.5:
			continue
		_pole(mx, top_y, rng.randf_range(2.6, 4.2), -4.4)

	if bool(opts.get("coop", false)):
		_pigeon_loft(Vector3(left_x + w * 0.72, top_y, -3.2), seed_)
	if bool(opts.get("rug", false)):
		# A rug hung over the front parapet to air. One saturated rectangle on
		# a roofline is worth more than any amount of surface detail.
		var rug := LevelKit.prop(geometry,
			Vector3(left_x + w * 0.34, top_y - 0.55, 2.0),
			Vector3(2.4, 1.5, 0.05),
			MaterialLab.cloth(Color(0.52, 0.16, 0.14), 0.94), "Rug")
		rug.rotation.z = 0.03
		LevelKit.prop(geometry, Vector3(left_x + w * 0.34, top_y - 0.55, 2.04),
			Vector3(2.0, 1.1, 0.02),
			MaterialLab.cloth(Color(0.80, 0.66, 0.34), 0.94), "RugField")

	# A pile of breeze blocks and a bag of cement: every roof on this coast is
	# waiting for its next storey.
	if rng.randf() < 0.75:
		var bx := left_x + rng.randf_range(2.0, maxf(2.1, w - 2.0))
		for i in 5:
			LevelKit.prop(geometry,
				Vector3(bx + fmod(float(i) * 0.31, 0.5), top_y + 0.11 + float(i) * 0.22, -3.0),
				Vector3(0.9, 0.22, 0.44), mats["block"], "BreezeBlock%d" % i)


## A rooftop stairwell head you can land on. Colliding, centred on the play
## plane, 1.8 up against a 3.15 jump — an easy hop that adds a beat of height
## to a flat run and a person-sized box to a roofline with no scale on it.
func _roof_hut(x: float, top_y: float, seed_: int) -> void:
	var body := LevelKit.box(geometry, Vector3(x, top_y + 0.9, -0.8),
		Vector3(2.4, 1.8, 3.0), mats["render_c"], "StairHead%d" % seed_)
	_nose(x, top_y + 1.8, 2.7, 0.82, 0.40)
	# The cap is flush with the surface he lands on, not 50 mm above it. A
	# decorative coping standing proud of a platform's own top buries his feet.
	LevelKit.prop(body, Vector3(0.0, 0.80, -0.1), Vector3(2.7, 0.20, 3.3),
		mats["nose"], "HutCap")
	LevelKit.prop(body, Vector3(0.0, -0.36, 1.53), Vector3(0.9, 1.5, 0.10),
		mats["shutter_blue"], "HutDoor")
	LevelKit.prop(body, Vector3(0.0, 0.45, 1.56), Vector3(1.15, 0.16, 0.22),
		mats["block"], "HutLintel")
	LevelKit.prop(body, Vector3(0.85, 0.28, 1.54), Vector3(0.30, 0.40, 0.18),
		mats["steel"], "HutMeter")
	# Rebar out of the roof of the hut, like everything else in the town.
	for i in 3:
		LevelKit.prop(body, Vector3(-0.7 + i * 0.7, 1.30, -0.6),
			Vector3(0.05, 0.55, 0.05), mats["rebar"], "HutRebar%d" % i)


## The cat's cradle. Every flat roof on this coast is tied to the next by
## somebody's cable, and a gap with five wires crossing it reads as a street
## you could fall into rather than a hole between two slabs.
##
## Nothing here is ever below head height across the play plane: a wire drawn
## through the player's chest looks like a bug, and a wire above him looks like
## a town.
func _cables(ax: float, ay: float, bx: float, by: float, seed_: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_ * 77 + 5
	var zs := [-4.4, -3.2, -1.6, 0.4, 1.7]
	for i in zs.size():
		if rng.randf() < 0.2:
			continue
		var z: float = zs[i] + rng.randf_range(-0.25, 0.25)
		var lift := rng.randf_range(0.5, 1.6)
		if absf(z) < 1.4:
			lift = rng.randf_range(2.4, 3.6)
		PropKit.cable(geometry,
			Vector3(ax - 0.4, ay + lift, z),
			Vector3(bx + 0.4, by + lift + rng.randf_range(-0.5, 0.7), z),
			rng.randf_range(0.5, 1.3), mats["steel"], 10,
			rng.randf_range(0.035, 0.055))
	# And two long ones away across the road to the facing terrace. The cradle
	# has to go somewhere — a wire that ends in mid-air is a wire nobody
	# strung — and sending them into the deep background rather than down to
	# the near kerb keeps every one of them clear of the jump he is about to
	# make through this gap.
	PropKit.cable(geometry, Vector3(ax - 3.0, ay + 1.4, -4.4),
		Vector3(ax + 7.0, STREET_Y + 8.4, -20.0), 2.4, mats["steel"], 12, 0.045)
	PropKit.cable(geometry, Vector3(bx + 3.0, by + 1.2, -4.4),
		Vector3(bx - 5.0, STREET_Y + 7.6, -20.0), 2.0, mats["steel"], 12, 0.04)


## A cable pole on a roof: a mast with a crossarm and a fan of wires leaving
## it. Always at the back, always silhouette.
func _pole(x: float, top_y: float, h: float, z: float) -> void:
	LevelKit.prop(geometry, Vector3(x, top_y + h * 0.5, z),
		Vector3(0.12, h, 0.12), mats["steel"], "CablePole")
	LevelKit.prop(geometry, Vector3(x, top_y + h - 0.25, z),
		Vector3(1.5, 0.09, 0.09), mats["steel"], "CableArm")
	for i in 3:
		LevelKit.prop(geometry, Vector3(x - 0.6 + i * 0.6, top_y + h - 0.12, z),
			Vector3(0.11, 0.18, 0.11), mats["shade"], "Insulator%d" % i)


# --- Platform pieces --------------------------------------------------------

## The nosing. THE readability primitive — see the contract at the top of the
## file. 90 mm proud of the surface behind it, in the one pale unstained
## material the level reserves for "you can stand here".
func _nose(x: float, top_y: float, w: float, z: float, depth := 0.34) -> MeshInstance3D:
	return LevelKit.prop(geometry, Vector3(x, top_y + 0.01, z),
		Vector3(w, 0.16, depth), mats["nose"], "Nose")


## The barrow ramp onto the loading dock. One sloped collider at about 25
## degrees — well inside the controller's 52 — with cast treads and a pale
## kerb laid on top of it as decoration, so it reads as a stepped ramp and
## behaves as a slope.
func _dock_ramp(x0: float, x1: float, rise: float) -> void:
	var angle := atan2(rise, x1 - x0)
	LevelKit.ramp(geometry, Vector2(x0, STREET_Y), Vector2(x1, STREET_Y + rise),
		2.8, mats["render_c"], 1.0, "DockRamp")
	var n := 7
	for i in n:
		var t := (float(i) + 0.5) / float(n)
		# Treads follow the slope, so they sit ON the surface he runs up.
		var tread := LevelKit.prop(geometry,
			Vector3(lerpf(x0, x1, t), STREET_Y + rise * t + 0.05, 0.9),
			Vector3((x1 - x0) / float(n) - 0.06, 0.09, 1.9), mats["nose"], "Tread%d" % i)
		tread.rotation.z = angle
	# A kerb up the outer edge, because a ramp with no edge reads as a wedge.
	var kerb := LevelKit.prop(geometry,
		Vector3((x0 + x1) * 0.5, STREET_Y + rise * 0.5 + 0.14, 1.36),
		Vector3(x1 - x0 + 0.2, 0.26, 0.24), mats["nose"], "RampKerb")
	kerb.rotation.z = angle


## A balcony, a rooftop or a canopy depending on what is asked for, but always
## the same slab at the same height, because the traversal is tuned on it.
##
##   wall_z   the face it is bolted to. Brackets and a fillet reach back to it,
##            which is the difference between a balcony and a floating step.
##   posts    carried on painted steel posts down to `floor_y` instead.
##   roof     dressed as the top of a small building: parapet, no rail.
func _ledge(x: float, y: float, w: float, opts := {}) -> StaticBody3D:
	var body := LevelKit.box(geometry, Vector3(x, y - 0.14, 0.0),
		Vector3(w, 0.28, 1.6), mats["block"], "Ledge")
	_nose(x, y, w, 0.70, 0.28)
	var seed_ := int(opts.get("seed", 0))

	if bool(opts.get("roof", false)):
		# A roof, not a balcony: a parapet along the back and the ends, so the
		# silhouette is a box with a lip, and nothing hangs off the front.
		LevelKit.prop(body, Vector3(0.0, 0.40, -0.72), Vector3(w, 0.52, 0.22),
			mats["render_c"], "LedgeParapet")
		LevelKit.prop(body, Vector3(0.0, 0.68, -0.72), Vector3(w + 0.1, 0.12, 0.34),
			mats["kerb"], "LedgeParapetCap")
		# The building it is the top of, carried all the way down to the street
		# and set back behind the play plane so he never runs through it. A
		# roof with nothing under it is the other half of the floating-slab
		# problem the arcade solves everywhere else.
		var mh: float = maxf(0.6, (y - 0.28) - STREET_Y)
		LevelKit.prop(body, Vector3(0.0, STREET_Y + mh * 0.5 - (y - 0.14), -1.3),
			Vector3(w * 0.92, mh, 1.6), mats["render"], "LedgeMass")
		LevelKit.prop(body, Vector3(w * 0.28, 1.3, -0.6), Vector3(0.08, 1.7, 0.08),
			mats["steel"], "LedgeMast")
		for e in 3:
			LevelKit.prop(body, Vector3(w * 0.28, 1.05 + e * 0.28, -0.6),
				Vector3(0.75 - e * 0.1, 0.055, 0.055), mats["steel"], "LedgeAerial%d" % e)
		return body

	# Rail and balusters, in painted steel rather than bare rust: this is a
	# street somebody lives on.
	LevelKit.prop(body, Vector3(0.0, 0.52, 0.75), Vector3(w, 0.06, 0.06),
		mats["rust"], "LedgeRail")
	for i in 3:
		LevelKit.prop(body, Vector3(-w * 0.4 + i * w * 0.4, 0.26, 0.75),
			Vector3(0.05, 0.52, 0.05), mats["rust"], "LedgeBaluster%d" % i)

	var wall_z := float(opts.get("wall_z", 99.0))
	if wall_z < 10.0:
		# Bolted to a real wall: a fillet back to the face and two raking
		# brackets under it, which is how a cantilever actually stands up.
		var reach: float = absf(-0.8 - wall_z)
		LevelKit.prop(body, Vector3(0.0, -0.02, -0.8 - reach * 0.5),
			Vector3(w * 0.96, 0.24, reach + 0.1), mats["block"], "LedgeFillet")
		for i in 2:
			var br := LevelKit.prop(body,
				Vector3(-w * 0.32 + i * w * 0.64, -0.45, -0.55),
				Vector3(1.3, 0.11, 0.11), mats["rust"], "Bracket%d" % i)
			br.rotation.z = -0.62
		# What is actually on a balcony: a satellite dish, a plant, a bucket.
		if seed_ % 2 == 0:
			LevelKit.prop(body, Vector3(w * 0.3, 0.30, 0.35),
				Vector3(0.44, 0.40, 0.44), mats["crate"], "Pot")
			LevelKit.prop(body, Vector3(w * 0.3, 0.72, 0.35),
				Vector3(0.62, 0.55, 0.55), mats["palm"], "PotPlant")
		else:
			LevelKit.prop(body, Vector3(-w * 0.32, 0.46, 0.30),
				Vector3(0.10, 0.70, 0.10), mats["steel"], "DishPole")
			var dish := LevelKit.prop(body, Vector3(-w * 0.32, 0.88, 0.42),
				Vector3(0.80, 0.80, 0.10), mats["render_b"], "Dish")
			dish.rotation.x = 0.5
		return body

	if bool(opts.get("posts", false)):
		# Carried on painted posts down to the floor below: a shop canopy, and
		# an honest one.
		var floor_y := float(opts.get("floor_y", STREET_Y))
		var drop := (y - 0.28) - floor_y
		if drop > 0.4:
			for i in 2:
				LevelKit.prop(geometry,
					Vector3(x - w * 0.36 + i * w * 0.72, floor_y + drop * 0.5, 0.72),
					Vector3(0.14, drop, 0.14), mats["shutter_blue"], "LedgePost%d" % i)
			var brace := LevelKit.prop(geometry,
				Vector3(x + w * 0.2, y - 0.75, 0.72), Vector3(1.2, 0.09, 0.09),
				mats["shutter_blue"], "LedgeBrace")
			brace.rotation.z = -0.7
	return body


func _crates(at: Vector3, rows: int) -> void:
	for r in rows:
		for c in maxi(1, 2 - r):
			LevelKit.prop(geometry,
				at + Vector3(c * 0.78 + r * 0.30, 0.34 + r * 0.66, 0.0),
				Vector3(0.74, 0.62, 0.74), mats["crate"], "Crate")


## A shipping container. Deep enough that its top is a surface the player
## capsule lands squarely on rather than a sliver at the edge of it — a
## platform you fall through half the time is worse than no platform.
func _container(at: Vector3, length: float, height: float, mat: Material,
		seed_ := 0) -> void:
	var body := LevelKit.box(geometry, at + Vector3(length * 0.5, height * 0.5, 0.0),
		Vector3(length, height, 3.2), mat, "Container")
	_nose(at.x + length * 0.5, at.y + height, length, at.z + 1.48, 0.28)
	# Corrugation ribs, so it is a container and not a coloured brick.
	for i in int(length / 0.42):
		LevelKit.prop(body, Vector3(-length * 0.5 + 0.21 + i * 0.42, 0.0, 1.62),
			Vector3(0.10, height * 0.92, 0.06), mat, "Rib%d" % i)
	LevelKit.prop(body, Vector3(0.0, height * 0.5 - 0.08, 1.64),
		Vector3(length, 0.16, 0.08), mats["rust"], "TopRail")
	LevelKit.prop(body, Vector3(0.0, -height * 0.5 + 0.08, 1.64),
		Vector3(length, 0.16, 0.08), mats["rust"], "BottomRail")
	# Corner castings and the door end with its locking bars: the two details
	# that separate a container from a box with lines on it.
	for i in 4:
		LevelKit.prop(body,
			Vector3((-0.5 + float(i % 2)) * length, (-0.5 + float(i / 2)) * height, 1.5),
			Vector3(0.36, 0.34, 0.36), mats["rust"], "Casting%d" % i)
	for i in 4:
		LevelKit.prop(body, Vector3(length * 0.5 - 0.04, 0.0, -1.0 + i * 0.66),
			Vector3(0.06, height * 0.86, 0.09), mats["rust"], "LockBar%d" % i)
	if seed_ % 2 == 0:
		# A ladder welded up one end: the honest way onto a container.
		for i in 5:
			LevelKit.prop(body, Vector3(-length * 0.5 - 0.10, -height * 0.42 + i * 0.5, 0.9),
				Vector3(0.52, 0.06, 0.06), mats["rust"], "Rung%d" % i)
	_decal(Vector3(at.x + length * 0.3, at.y + height * 0.6, at.z + 1.66),
		Vector2(1.6, height * 0.7), mats["drip"])


## The minibus: stalled across the junction, bonnet up, repainted more than
## once. Its roof is the first big step up in the level, so it is three units
## deep and carries a nosing like every other surface he is meant to land on.
func _bus(at: Vector3) -> void:
	var body := LevelKit.box(geometry, at + Vector3(5.0, 1.55, 0.0),
		Vector3(10.0, 2.5, 3.0), mats["shutter_blue"], "Bus")
	_nose(at.x + 5.0, at.y + 2.8, 9.6, at.z + 1.42, 0.30)
	LevelKit.prop(body, Vector3(0.0, 1.10, 0.0), Vector3(9.4, 0.3, 2.9),
		mats["cloth"], "BusRoof")
	# A band of windows, dark and continuous: the read that says "bus".
	LevelKit.prop(body, Vector3(-0.4, 0.42, 1.51), Vector3(8.2, 0.9, 0.06),
		mats["dark"], "BusGlass")
	for i in 5:
		LevelKit.prop(body, Vector3(-3.6 + i * 1.8, 0.42, 1.53),
			Vector3(0.10, 0.94, 0.06), mats["steel"], "BusMullion%d" % i)
	for side in 2:
		LevelKit.prop(body, Vector3(-3.2 + side * 6.4, -1.05, 1.35),
			Vector3(1.0, 1.0, 0.5), mats["dark"], "BusWheel%d" % side)
	LevelKit.prop(body, Vector3(-5.05, 0.1, 0.0), Vector3(0.2, 1.8, 2.8),
		mats["shutter_red"], "BusFront")
	# A painted flash down the side, a route board in the windscreen, and the
	# roof rack every intercity minibus on this coast carries.
	LevelKit.prop(body, Vector3(0.0, -0.35, 1.52), Vector3(9.8, 0.34, 0.05),
		mats["cloth"], "BusFlash")
	LevelKit.prop(body, Vector3(0.0, -0.62, 1.52), Vector3(9.8, 0.16, 0.05),
		mats["shutter_red"], "BusFlashB")
	# The rack and its load live on the BACK half of the roof only. He runs
	# along this roof at z = 0; luggage he walks through is worse than no
	# luggage, so all of it is pushed a clear unit behind him.
	for i in 4:
		LevelKit.prop(body, Vector3(-3.6 + i * 2.4, 1.45, -1.0),
			Vector3(0.09, 0.42, 1.8), mats["steel"], "RackHoop%d" % i)
	LevelKit.prop(body, Vector3(-1.4, 1.72, -1.0), Vector3(2.6, 0.55, 1.7),
		mats["reed"], "RoofLoad")
	LevelKit.prop(body, Vector3(2.2, 1.68, -1.1), Vector3(1.5, 0.5, 1.3),
		mats["tarp"], "RoofLoadB")
	# Bonnet up, and the reason it is parked across two lanes.
	var bonnet := LevelKit.prop(body, Vector3(-5.2, 1.25, 0.2),
		Vector3(1.6, 0.10, 2.4), mats["shutter_blue"], "Bonnet")
	bonnet.rotation.z = -1.15
	LevelKit.prop(geometry, at + Vector3(-0.6, 0.30, 1.9),
		Vector3(0.5, 0.60, 0.5), mats["rust"], "ToolBox")
	_decal(at + Vector3(-0.2, 0.03, 0.6), Vector2(2.6, 2.0), mats["oil"],
		Vector3(-PI * 0.5, 0.0, 0.0))


# --- Crossroads dressing ----------------------------------------------------

## The roundabout: a raised planting ring and the fountain in the middle of it
## that has been dry since before he was born. It is the landmark that makes
## the junction a place rather than a widening of the road.
func _roundabout(at: Vector3) -> void:
	var seg := 16
	for i in seg:
		var a := TAU * float(i) / float(seg)
		var p := at + Vector3(cos(a) * 6.2, 0.22, sin(a) * 3.4)
		var k := LevelKit.prop(geometry, p, Vector3(2.6, 0.44, 0.5),
			mats["paint"] if i % 2 == 0 else mats["shade"], "RingKerb%d" % i)
		k.rotation.y = -a + PI * 0.5
	LevelKit.prop(geometry, at + Vector3(0.0, 0.16, 0.0),
		Vector3(11.8, 0.32, 6.4), mats["dust"], "RingFill")

	# Three dry basins stepping up, a rusted riser and no water. Concrete that
	# has been in the sun this long goes pale and chalky, which is why the
	# fountain is the lightest thing in the frame and reads as a landmark.
	var tiers := [[5.2, 0.9], [3.4, 1.5], [1.9, 2.1]]
	for i in tiers.size():
		var t: Array = tiers[i]
		LevelKit.prop(geometry, at + Vector3(0.0, float(t[1]) * 0.5, 0.0),
			Vector3(float(t[0]), float(t[1]), float(t[0]) * 0.62), mats["render_c"], "Basin%d" % i)
		LevelKit.prop(geometry, at + Vector3(0.0, float(t[1]) + 0.08, 0.0),
			Vector3(float(t[0]) + 0.3, 0.22, float(t[0]) * 0.62 + 0.3), mats["kerb"], "BasinLip%d" % i)
	LevelKit.prop(geometry, at + Vector3(0.0, 2.7, 0.0),
		Vector3(0.28, 1.2, 0.28), mats["rust"], "FountainRiser")
	LevelKit.prop(geometry, at + Vector3(0.0, 3.35, 0.0),
		Vector3(0.7, 0.18, 0.7), mats["rust"], "FountainRose")
	_decal(at + Vector3(0.0, 1.0, 1.8), Vector2(2.4, 1.6), mats["drip"])

	# Planting that survived: two date palms and a dead shrub, plus the litter
	# that collects in a dry basin.
	PropKit.palm(geometry, at + Vector3(-4.4, 0.4, -1.2), 7.4,
		mats["trunk"], mats["palm"], 71)
	PropKit.palm(geometry, at + Vector3(4.8, 0.4, -1.8), 8.6,
		mats["trunk"], mats["palm"], 72)
	for i in 4:
		_scrub(at.x - 3.0 + i * 2.2, at.z + 1.4, 90 + i)
	# A flag mast on the island, bare. Nobody has run anything up it lately.
	LevelKit.prop(geometry, at + Vector3(-6.8, 3.2, -0.6),
		Vector3(0.14, 6.4, 0.14), mats["paint"], "FlagMast")


## A burnt-out saloon on its rims. The one piece of real damage in the level,
## and the foreground anchor for the widest frame in it.
func _burnt_car(at: Vector3, yaw := 0.0) -> void:
	var root := Node3D.new()
	root.name = "BurntCar"
	root.position = at
	root.rotation.y = yaw
	geometry.add_child(root)
	LevelKit.prop(root, Vector3(0.0, 0.58, 0.0), Vector3(4.4, 0.86, 1.85),
		mats["burnt"], "Body")
	var cabin := LevelKit.prop(root, Vector3(-0.15, 1.20, 0.0),
		Vector3(2.4, 0.62, 1.70), mats["burnt"], "Cabin")
	cabin.rotation.z = 0.05
	# Window apertures with nothing in them: fire takes the glass first, and
	# the black holes are what say "burnt" at a glance.
	LevelKit.prop(root, Vector3(-0.15, 1.24, 0.86), Vector3(2.1, 0.46, 0.05),
		mats["dark"], "CabinVoid")
	for w in 2:
		# Resting on brake drums, no tyres.
		LevelKit.prop(root, Vector3(-1.4 + w * 2.8, 0.20, 0.86),
			Vector3(0.40, 0.40, 0.14), mats["rust"], "Drum%d" % w)
	LevelKit.prop(root, Vector3(2.35, 0.55, 0.0), Vector3(0.18, 0.8, 1.7),
		mats["rust"], "BootLid")
	# A door off, lying beside it.
	var door := LevelKit.prop(root, Vector3(-0.4, 0.07, 1.65),
		Vector3(1.4, 0.10, 0.95), mats["burnt"], "DoorOff")
	door.rotation = Vector3(0.0, 0.3, 0.04)
	_decal(at + Vector3(0.0, 0.03, 0.0), Vector2(6.0, 4.0), mats["oil"],
		Vector3(-PI * 0.5, 0.0, 0.0))


func _tyres(at: Vector3, count: int, seed_: int) -> void:
	for i in count:
		var t := LevelKit.prop(geometry,
			at + Vector3(fmod(float(seed_ + i) * 0.37, 0.34) - 0.17,
				0.14 + float(i) * 0.26, fmod(float(i) * 0.71, 0.3) - 0.15),
			Vector3(1.02, 0.26, 1.02), mats["dark"], "Tyre%d" % i)
		t.rotation.y = fmod(float(seed_ * 7 + i * 13), 1.5)


func _barrel(at: Vector3, banded: bool) -> void:
	LevelKit.prop(geometry, at + Vector3(0.0, 0.46, 0.0),
		Vector3(0.66, 0.92, 0.66), mats["rust"], "Barrel")
	if banded:
		for i in 2:
			LevelKit.prop(geometry, at + Vector3(0.0, 0.26 + float(i) * 0.40, 0.0),
				Vector3(0.70, 0.22, 0.70), mats["paint"], "BarrelBand%d" % i)


## A roadside kiosk: shuttered, painted, with a bench outside it. Small, but it
## is the thing that gives the junction a human scale.
func _kiosk(at: Vector3) -> void:
	LevelKit.prop(geometry, at + Vector3(0.0, 1.35, 0.0), Vector3(3.0, 2.7, 2.4),
		mats["render_b"], "Kiosk")
	LevelKit.prop(geometry, at + Vector3(0.0, 2.80, 0.0), Vector3(3.4, 0.22, 2.8),
		mats["kerb"], "KioskCap")
	LevelKit.prop(geometry, at + Vector3(0.0, 1.45, 1.24), Vector3(2.2, 1.3, 0.08),
		mats["shutter_red"], "KioskShutter")
	var awn := LevelKit.prop(geometry, at + Vector3(0.0, 2.35, 1.9),
		Vector3(3.0, 0.07, 1.5), mats["cloth"], "KioskAwning")
	awn.rotation.x = -0.20
	LevelKit.prop(geometry, at + Vector3(1.9, 0.42, 1.2), Vector3(1.6, 0.12, 0.45),
		mats["crate"], "Bench")
	for i in 2:
		LevelKit.prop(geometry, at + Vector3(1.3 + i * 1.2, 0.18, 1.2),
			Vector3(0.10, 0.36, 0.40), mats["steel"], "BenchLeg%d" % i)


# --- Back street dressing ---------------------------------------------------

## A split unit and the twenty summers of stain under it. On a shaded wall
## there is no light to give a surface structure, so all of its character has
## to be silhouette standing off the face — which is also what a real one is.
func _ac_unit(at: Vector3, seed_: int) -> void:
	LevelKit.prop(geometry, at, Vector3(0.90, 0.58, 0.44), mats["cloth"], "AC")
	LevelKit.prop(geometry, at + Vector3(0.0, 0.0, 0.22), Vector3(0.72, 0.44, 0.04),
		mats["shade"], "ACGrille")
	LevelKit.prop(geometry, at + Vector3(0.0, -0.34, -0.02), Vector3(1.02, 0.08, 0.40),
		mats["rust"], "ACBracket")
	# The drip line and its stain. This is the section's one wet note.
	LevelKit.prop(geometry, at + Vector3(0.38, -0.9, 0.06), Vector3(0.05, 1.1, 0.05),
		mats["rust"], "ACDrain")
	_decal(at + Vector3(0.38, -1.9, 0.18), Vector2(0.9, 3.0), mats["drip"])
	if seed_ % 2 == 0:
		LevelKit.prop(geometry, at + Vector3(-0.85, -0.1, 0.02),
			Vector3(0.10, 1.6, 0.10), mats["rust"], "Conduit")


func _bin(at: Vector3, mat: Material, lean := 0.0) -> void:
	var b := LevelKit.prop(geometry, at + Vector3(0.0, 0.55, 0.0),
		Vector3(0.90, 1.10, 0.80), mat, "Bin")
	b.rotation.z = lean
	LevelKit.prop(b, Vector3(0.0, 0.60, 0.0), Vector3(1.0, 0.12, 0.90),
		mats["shade"], "BinLid")
	for i in 2:
		LevelKit.prop(b, Vector3(-0.34 + i * 0.68, -0.52, 0.30),
			Vector3(0.24, 0.24, 0.10), mats["dark"], "BinWheel%d" % i)


## An open skip full of somebody's demolition. Rubble rather than rubbish: a
## back street in a town that is always half-rebuilding.
func _skip(at: Vector3) -> void:
	var s := LevelKit.prop(geometry, at + Vector3(0.0, 0.75, 0.0),
		Vector3(3.4, 1.5, 1.6), mats["rust"], "Skip")
	s.rotation.z = -0.02
	LevelKit.prop(s, Vector3(0.0, 0.80, 0.0), Vector3(3.55, 0.14, 1.75),
		mats["rust"], "SkipLip")
	for i in 2:
		LevelKit.prop(s, Vector3(-1.2 + i * 2.4, 0.0, 0.83),
			Vector3(0.12, 1.4, 0.06), mats["rust"], "SkipRib%d" % i)
	for i in 7:
		var r := LevelKit.prop(geometry,
			at + Vector3(-1.2 + fmod(float(i) * 0.93, 2.4), 1.55 + fmod(float(i) * 0.31, 0.3),
				-0.4 + fmod(float(i) * 0.57, 0.8)),
			Vector3(0.55, 0.30, 0.45), mats["block"], "Rubble%d" % i)
		r.rotation = Vector3(fmod(float(i) * 0.7, 0.5), fmod(float(i) * 1.3, 1.5), fmod(float(i) * 0.4, 0.4))


## The dead end. Breeze block across the lane, a sheet of corrugated leaning on
## it, and a cat that has been sitting there since before any of this started.
func _blocked_alley(at: Vector3) -> void:
	LevelKit.prop(geometry, at + Vector3(0.0, 1.6, 0.0), Vector3(4.6, 3.2, 1.0),
		mats["render_b"], "AlleyWall")
	LevelKit.prop(geometry, at + Vector3(0.0, 3.28, 0.0), Vector3(4.9, 0.24, 1.2),
		mats["kerb"], "AlleyWallCap")
	for i in 6:
		LevelKit.prop(geometry, at + Vector3(-1.8 + i * 0.72, 0.3 + fmod(float(i) * 0.4, 0.5), 0.6),
			Vector3(0.9, 0.22, 0.44), mats["block"], "LooseBlock%d" % i)
	var sheet := LevelKit.prop(geometry, at + Vector3(1.5, 0.9, 0.7),
		Vector3(1.6, 1.9, 0.06), mats["rust"], "Corrugated")
	sheet.rotation.z = 0.22
	_cat(at + Vector3(-1.6, 0.0, 0.9), -1.0)


## A cat on a wall in a back street in Ajdabiya. She is not a hazard, she is
## not a collectible and nothing happens if you touch her. Every level in this
## game gets exactly one thing that is only there because it is there.
func _cat(at: Vector3, face := 1.0) -> void:
	var root := Node3D.new()
	root.name = "Cat"
	root.position = at
	root.rotation.y = 0.35 * face
	geometry.add_child(root)
	LevelKit.prop(root, Vector3(0.0, 0.20, 0.0), Vector3(0.46, 0.24, 0.20),
		mats["fur"], "CatBody")
	LevelKit.prop(root, Vector3(0.22 * face, 0.38, 0.0), Vector3(0.19, 0.18, 0.17),
		mats["fur"], "CatHead")
	for i in 2:
		var ear := LevelKit.prop(root,
			Vector3(0.22 * face, 0.50, -0.06 + i * 0.12), Vector3(0.07, 0.10, 0.05),
			mats["fur"], "CatEar%d" % i)
		ear.rotation.z = 0.2 * face
	var tail := LevelKit.prop(root, Vector3(-0.30 * face, 0.16, 0.0),
		Vector3(0.30, 0.06, 0.06), mats["fur"], "CatTail")
	tail.rotation.z = 0.9 * face


## Bougainvillea spilling over a wall. The only magenta in the game, and worth
## every pixel: in a town of ochre and blue shadow it stops the eye dead and
## tells you somebody has been watering something.
func _bougainvillea(at: Vector3, w: float, seed_: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_ * 131 + 3
	for i in int(w * 2.2):
		var t := float(i) / float(maxi(1, int(w * 2.2) - 1))
		var drop := sin(t * PI) * rng.randf_range(0.6, 1.9)
		var b := LevelKit.prop(geometry,
			at + Vector3((t - 0.5) * w, -drop * 0.5 + rng.randf_range(-0.2, 0.2),
				rng.randf_range(-0.15, 0.35)),
			Vector3(rng.randf_range(0.6, 1.1), rng.randf_range(0.5, 1.0),
				rng.randf_range(0.4, 0.7)), mats["bougain"], "Bougain%d" % i)
		b.rotation = Vector3(rng.randf_range(0.0, 1.0), rng.randf_range(0.0, TAU), 0.0)
	# The green under the colour, or it reads as a pink cloud.
	for i in int(w):
		LevelKit.prop(geometry,
			at + Vector3((float(i) / maxf(1.0, w - 1.0) - 0.5) * w, -0.35, -0.2),
			Vector3(1.3, 0.8, 0.8), mats["palm"], "BougainLeaf%d" % i)


# --- East gate dressing -----------------------------------------------------

## The hut at the edge of town. Somebody sat in this for years; the barrier is
## up and the window is dark and there is nobody in it this morning.
func _checkpoint_hut(at: Vector3) -> void:
	LevelKit.prop(geometry, at + Vector3(0.0, 1.55, 0.0), Vector3(3.6, 3.1, 3.0),
		mats["render_c"], "HutBox")
	LevelKit.prop(geometry, at + Vector3(0.0, 3.22, 0.0), Vector3(4.2, 0.26, 3.6),
		mats["kerb"], "HutRoof")
	LevelKit.prop(geometry, at + Vector3(0.0, 1.95, 1.54), Vector3(1.9, 1.0, 0.08),
		mats["dark"], "HutGlass")
	LevelKit.prop(geometry, at + Vector3(0.0, 2.50, 1.58), Vector3(2.2, 0.16, 0.22),
		mats["block"], "HutSill")
	LevelKit.prop(geometry, at + Vector3(-1.3, 1.05, 1.52), Vector3(0.9, 2.0, 0.08),
		mats["shutter_green"], "HutDoor")
	var shade := LevelKit.prop(geometry, at + Vector3(0.0, 3.05, 2.2),
		Vector3(4.0, 0.08, 2.0), mats["reed"], "HutShade")
	shade.rotation.x = -0.12
	for i in 2:
		LevelKit.prop(geometry, at + Vector3(-1.7 + i * 3.4, 1.7, 2.9),
			Vector3(0.12, 3.4, 0.12), mats["steel"], "ShadePost%d" % i)
	LevelKit.prop(geometry, at + Vector3(2.4, 0.46, 1.4), Vector3(0.66, 0.92, 0.66),
		mats["rust"], "HutBarrel")


## The boom, left up. A raised barrier is a far better silhouette than a
## lowered one and it says the same thing: this used to be controlled.
func _barrier(at: Vector3) -> void:
	LevelKit.prop(geometry, at + Vector3(0.0, 0.55, 0.0), Vector3(0.46, 1.1, 0.46),
		mats["steel"], "BarrierPost")
	LevelKit.prop(geometry, at + Vector3(0.0, 1.15, 0.0), Vector3(0.62, 0.22, 0.62),
		mats["rust"], "BarrierPivot")
	# The boom pivots at the post head and stands almost vertical. Its centre
	# is half a boom-length up the rotated axis from the pivot, not half a
	# boom-length along x — a raised barrier whose foot floats beside its
	# hinge is the sort of thing nobody can name but everybody sees.
	var dir := Vector2(cos(1.25), sin(1.25))
	var pivot := Vector3(0.0, 1.15, 0.0)
	var boom := LevelKit.prop(geometry,
		at + pivot + Vector3(dir.x * 2.7, dir.y * 2.7, 0.0),
		Vector3(5.4, 0.18, 0.18), mats["paint"], "Boom")
	boom.rotation.z = 1.25
	for i in 4:
		var d := 0.7 + float(i) * 1.3
		var band := LevelKit.prop(geometry,
			at + pivot + Vector3(dir.x * d, dir.y * d, 0.02),
			Vector3(0.62, 0.20, 0.20), mats["shutter_red"], "BoomBand%d" % i)
		band.rotation.z = 1.25
	LevelKit.prop(geometry, at + Vector3(0.55, 1.35, 0.0), Vector3(0.40, 0.40, 0.40),
		mats["dark"], "Counterweight")


## A tuft of desert scrub. Built as a handful of flattened boxes on the foliage
## shader so it moves, because the last thing the level shows is the town
## giving up and the wind taking over.
func _scrub(x: float, z: float, seed_: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_ * 271 + 13
	var n := rng.randi_range(3, 5)
	for i in n:
		var b := LevelKit.prop(geometry,
			Vector3(x + rng.randf_range(-0.4, 0.4), STREET_Y + rng.randf_range(0.15, 0.45),
				z + rng.randf_range(-0.4, 0.4)),
			Vector3(rng.randf_range(0.5, 0.9), rng.randf_range(0.25, 0.6),
				rng.randf_range(0.4, 0.8)), mats["scrub"], "Scrub%d" % i)
		b.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(0.0, TAU),
			rng.randf_range(-0.3, 0.3))


# --- Market dressing --------------------------------------------------------

## A heap of produce on a counter. A MultiMesh of small spheres: one draw call
## per heap, and the only place in the level where full saturation sits at eye
## level. Without it a market stall is a table with a coloured roof.
func _produce_heap(at: Vector3, w: float, seed_: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_ * 457 + 19
	var fruit := SphereMesh.new()
	fruit.radius = 0.085
	fruit.height = 0.17
	fruit.radial_segments = 7
	fruit.rings = 4
	var rows := 3
	var per := maxi(3, int(w / 0.19))
	var xf: Array[Transform3D] = []
	for r in rows:
		var span := w * (1.0 - float(r) * 0.28)
		for c in maxi(1, per - r * 2):
			var t := (float(c) + 0.5) / float(maxi(1, per - r * 2))
			xf.append(Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)),
				at + Vector3((t - 0.5) * span, float(r) * 0.14,
					rng.randf_range(-0.18, 0.18))))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = fruit
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var node := MultiMeshInstance3D.new()
	node.name = "Produce"
	node.multimesh = mm
	var produce: Array = mats["produce"]
	node.material_override = produce[seed_ % produce.size()]
	geometry.add_child(node)
	# The crate it is heaped in, so it does not float.
	LevelKit.prop(geometry, at + Vector3(0.0, -0.10, 0.0),
		Vector3(w + 0.14, 0.22, 0.56), mats["crate"], "ProduceCrate")


func _sack_pile(at: Vector3, seed_: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_ * 313 + 7
	for i in 5:
		var s := LevelKit.prop(geometry,
			at + Vector3(rng.randf_range(-0.6, 0.6), 0.28 + float(i % 3) * 0.44,
				rng.randf_range(-0.25, 0.25)),
			Vector3(0.66, 0.46, 0.52), mats["reed"], "Sack%d" % i)
		s.rotation = Vector3(0.0, rng.randf_range(0.0, TAU), rng.randf_range(-0.2, 0.2))
	# One open, with what is in it showing. A closed sack is a lump.
	_produce_heap(at + Vector3(0.0, 1.30, 0.0), 0.55, seed_ + 3)


## Three stools and a tin table. The tea is the social unit of this street and
## the silhouette of a low round table with stools round it is unmistakable.
func _tea_table(at: Vector3, seed_: int) -> void:
	LevelKit.prop(geometry, at + Vector3(0.0, 0.62, 0.0), Vector3(0.95, 0.07, 0.95),
		mats["shutter_blue"], "TeaTop")
	LevelKit.prop(geometry, at + Vector3(0.0, 0.31, 0.0), Vector3(0.14, 0.62, 0.14),
		mats["steel"], "TeaStem")
	LevelKit.prop(geometry, at + Vector3(0.0, 0.04, 0.0), Vector3(0.55, 0.08, 0.55),
		mats["steel"], "TeaFoot")
	for i in 3:
		var a := TAU * float(i) / 3.0 + float(seed_) * 0.4
		LevelKit.prop(geometry, at + Vector3(cos(a) * 0.95, 0.22, sin(a) * 0.55),
			Vector3(0.44, 0.44, 0.44),
			mats["shutter_red"] if i % 2 == 0 else mats["shutter_green"], "Stool%d" % i)
	# The pot and two glasses on it.
	LevelKit.prop(geometry, at + Vector3(0.0, 0.76, 0.0), Vector3(0.20, 0.22, 0.20),
		mats["steel"], "TeaPot")
	for i in 2:
		LevelKit.prop(geometry, at + Vector3(-0.22 + i * 0.44, 0.70, 0.18),
			Vector3(0.08, 0.10, 0.08), mats["cloth"], "Glass%d" % i)


## A two-wheeled barrow, the market's only vehicle. Tipped up on its handles
## when it is not in use, which is a much better silhouette than flat.
func _handcart(at: Vector3, seed_: int) -> void:
	var root := Node3D.new()
	root.name = "Handcart"
	root.position = at
	root.rotation.y = 0.2 + fmod(float(seed_) * 0.3, 0.4)
	geometry.add_child(root)
	var bed := LevelKit.prop(root, Vector3(0.0, 0.78, 0.0), Vector3(1.9, 0.12, 1.0),
		mats["crate"], "CartBed")
	bed.rotation.z = -0.22
	LevelKit.prop(root, Vector3(0.0, 1.02, -0.5), Vector3(1.9, 0.42, 0.08),
		mats["crate"], "CartSide")
	for i in 2:
		LevelKit.prop(root, Vector3(-1.35, 0.30 + float(i) * 0.1, -0.4 + float(i) * 0.8),
			Vector3(1.3, 0.08, 0.08), mats["steel"], "CartHandle%d" % i)
	LevelKit.prop(root, Vector3(0.55, 0.32, 0.46), Vector3(0.62, 0.62, 0.12),
		mats["dark"], "CartWheel")
	_produce_heap(Vector3(at.x, at.y + 0.95, at.z), 1.2, seed_ + 17)


## A shade sail strung from the arcade back over the stalls. Cheap geometry, a
## hard shadow on the market floor, and the dapple is most of what makes the
## souk read as covered rather than as a row of objects in the open.
func _shade_sail(x: float, y: float, w: float, seed_: int) -> void:
	var cloth: Material = mats["reed"] if seed_ % 2 == 0 else mats["tarp"]
	for i in 3:
		# Set back toward the wall and a metre above the stall awnings: he runs
		# under it, and the one thing a canopy must never do is hide the man
		# at the top of a jump.
		var panel := LevelKit.prop(geometry,
			Vector3(x + float(i) * (w / 3.0), y - fmod(float(i + seed_) * 0.17, 0.26),
				0.35 + float(i % 2) * 0.45),
			Vector3(w / 3.0 - 0.1, 0.05, 2.3), cloth, "Sail%d_%d" % [seed_, i])
		panel.rotation.x = -0.1 + fmod(float(i) * 0.13, 0.2)
		panel.rotation.z = fmod(float(i + seed_) * 0.09, 0.08) - 0.04
	# The rope it hangs from, back to the wall.
	PropKit.cable(geometry, Vector3(x - 0.3, y + 0.3, PIER_Z - 0.3),
		Vector3(x + w * 0.5, y + 0.9, -3.6), 0.25, mats["rust"], 8, 0.03)


## A pigeon loft. Every third roof on this coast has one, they are the reason
## the sky over a Libyan town is never empty, and the mesh front is the one
## fine-grained texture on an otherwise blocky roofline.
func _pigeon_loft(at: Vector3, seed_: int) -> void:
	LevelKit.prop(geometry, at + Vector3(0.0, 0.85, 0.0), Vector3(2.2, 1.7, 1.3),
		mats["crate"], "Loft")
	LevelKit.prop(geometry, at + Vector3(0.0, 1.78, 0.0), Vector3(2.5, 0.14, 1.6),
		mats["rust"], "LoftRoof")
	for i in 7:
		LevelKit.prop(geometry, at + Vector3(-0.95 + float(i) * 0.32, 0.95, 0.68),
			Vector3(0.05, 1.3, 0.05), mats["steel"], "LoftBar%d" % i)
	LevelKit.prop(geometry, at + Vector3(0.0, 0.16, 0.95), Vector3(2.0, 0.08, 0.7),
		mats["crate"], "LoftBoard")
	for i in 3:
		LevelKit.prop(geometry,
			at + Vector3(-0.6 + float(i) * 0.6, 0.28, 0.95 + fmod(float(seed_ + i) * 0.11, 0.2)),
			Vector3(0.17, 0.16, 0.10), mats["cloth"], "Pigeon%d" % i)


# --- Small helpers ----------------------------------------------------------

## A generated grime or oil decal on a flat surface. Cheaper than geometry and
## it is what stops a rendered wall being one flat value from top to bottom.
func _decal(at: Vector3, size: Vector2, mat: Material,
		rot := Vector3.ZERO) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size
	var mi := MeshInstance3D.new()
	mi.name = "Decal"
	mi.mesh = q
	mi.material_override = mat
	mi.position = at
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	geometry.add_child(mi)
	return mi


func _atmosphere() -> void:
	# Dust hanging in the street, lit by a high sun: the one atmospheric in a
	# level that is otherwise clear.
	var fv := FogVolume.new()
	fv.name = "StreetDust"
	fv.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	fv.size = Vector3(X_END - X_START + 80.0, 6.0, 24.0)
	fv.position = Vector3((X_START + X_END) * 0.5, STREET_Y + 2.4, -6.0)
	var fm := FogMaterial.new()
	fm.density = 0.006
	fm.albedo = Color(1.0, 0.96, 0.90)
	fm.emission = Color(0.03, 0.03, 0.03)
	fm.height_falloff = 0.9
	fm.edge_fade = 0.45
	fv.material = fm
	add_child(fv)

	# The back street gets its own, denser and taller. A narrow shaded slot
	# with a hard sun over it is where the sun shafts live, and the fog volume
	# is what lets the colonnade cast them.
	var alley := FogVolume.new()
	alley.name = "AlleyHaze"
	alley.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	alley.size = Vector3(54.0, 12.0, 9.0)
	alley.position = Vector3(229.0, STREET_Y + 5.0, -0.5)
	var am := FogMaterial.new()
	# Brega learned this the hard way: anything past about 0.02 in a box this
	# size stops being air and becomes a white sheet over the section.
	am.density = 0.010
	am.albedo = Color(1.0, 0.95, 0.88)
	am.emission = Color(0.04, 0.035, 0.03)
	am.height_falloff = 0.4
	am.edge_fade = 0.6
	alley.material = am
	add_child(alley)

	# And a thin one over the junction, so the widest frame in the level has
	# some air in it instead of reading as a vacuum.
	var junction := FogVolume.new()
	junction.name = "JunctionAir"
	junction.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	junction.size = Vector3(60.0, 14.0, 30.0)
	junction.position = Vector3(175.0, STREET_Y + 5.0, -8.0)
	var jm := FogMaterial.new()
	jm.density = 0.008
	jm.albedo = Color(1.0, 0.97, 0.92)
	jm.emission = Color(0.03, 0.03, 0.03)
	jm.height_falloff = 0.5
	jm.edge_fade = 0.55
	junction.material = jm
	add_child(junction)


# --- Spawns -----------------------------------------------------------------

func _drone(at: Vector3, span: float) -> SnitchDrone:
	var d := SnitchDrone.new()
	d.position = at
	d.patrol_span = span
	geometry.add_child(d)
	return d


func _turret(at: Vector3) -> WallTurret:
	var t := WallTurret.new()
	t.position = at
	geometry.add_child(t)
	return t


func _walker(at: Vector3, span: float) -> HeavyWalker:
	var w := HeavyWalker.new()
	w.position = at
	w.patrol_span = span
	geometry.add_child(w)
	return w


func _vent(at: Vector3, phase := 0.0, h := 4.0) -> SteamVent:
	var v := SteamVent.new()
	v.position = at
	v.phase = phase
	v.height = h
	geometry.add_child(v)
	return v


func _checkpoint(at: Vector3, index: int) -> void:
	var c := Checkpoint.new()
	geometry.add_child(c)
	c.position = at
	c.index = index
	register_checkpoint(at + c.respawn_offset)
	c.reached.connect(reach_checkpoint)


func _on_exit_entered(body: Node3D) -> void:
	if _completed or not (body is PlayerController):
		return
	_completed = true
	Gx.levels_cleared[level_id] = {"sriracha": Gx.sriracha}
	Gx.save_game()
	FX.hitstop(0.10)
	FX.zoom_punch(-5.0, 0.7)
	Audio.play_2d("life", -2.0, 1.0)
	level_complete.emit()
