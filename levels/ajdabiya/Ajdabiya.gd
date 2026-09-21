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

const STREET_Y := AjdabiyaKit.STREET_Y
const X_START := -14.0
const X_END := 320.0

var mats := {}
var _completed := false
var _heat := 0.0


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


func _build_level() -> void:
	mats = AjdabiyaKit.palette()
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


## Section A — the market. Street level, dense, slow, and safe. It teaches the
## two lines by putting the first roof ladder in plain sight and a whole row of
## awnings under it.
func _section_a_market() -> void:
	var shutters: Array = [mats["shutter_blue"], mats["shutter_green"], mats["shutter_red"]]
	var awnings := [
		[Color(0.72, 0.24, 0.18), Color(0.86, 0.80, 0.70)],
		[Color(0.18, 0.36, 0.46), Color(0.84, 0.78, 0.66)],
		[Color(0.24, 0.40, 0.26), Color(0.82, 0.76, 0.64)],
	]

	# The near terrace: the wall the player runs along, with its roof as the
	# high line above him.
	_terrace(-16.0, 74.0, 6.4, 0)

	for i in 7:
		var x := -6.0 + i * 9.0
		var pair: Array = awnings[i % awnings.size()]
		PropKit.market_stall(geometry, Vector3(x, STREET_Y, 1.0), 3.2,
			mats["steel"], pair[0], pair[1], mats["crate"], i)
		if i % 2 == 0:
			_crates(Vector3(x + 4.4, STREET_Y, 0.4), 2 + i % 2)

	TrailBuilder.line(geometry, Vector3(-2.0, STREET_Y + 1.1, 0.0),
		Vector3(14.0, STREET_Y + 1.1, 0.0), 9)
	TrailBuilder.line(geometry, Vector3(22.0, STREET_Y + 1.1, 0.0),
		Vector3(38.0, STREET_Y + 1.1, 0.0), 9)

	# The first way up, unmissable: a stack of crates to a stall roof to a
	# balcony to the parapet.
	_crates(Vector3(48.0, STREET_Y, 0.0), 3)
	_ledge(52.0, STREET_Y + 2.2, 3.0)
	_ledge(57.0, STREET_Y + 4.1, 3.0)
	TrailBuilder.curve(geometry, Vector3(49.5, STREET_Y + 2.6, 0.0),
		Vector3(58.0, STREET_Y + 5.6, 0.0), 1.4, 9)

	_checkpoint(Vector3(30.0, STREET_Y + 0.1, 0.0), 0)
	_drone(Vector3(40.0, STREET_Y + 4.4, 0.0), 5.0)


## Section B — the roofs. The fast line, over the market and on east: parapets,
## gaps that need the double jump, and a glide down into the next street.
func _section_b_roofs() -> void:
	var tops := [
		[74.0, 6.4, 13.0], [91.0, 7.6, 11.0], [106.0, 6.0, 14.0],
		[124.0, 8.4, 10.0], [138.0, 7.0, 12.0],
	]
	for i in tops.size():
		var spec: Array = tops[i]
		_terrace(spec[0], spec[0] + spec[2], spec[1], i + 1)
		if i < tops.size() - 1:
			var next: Array = tops[i + 1]
			TrailBuilder.curve(geometry,
				Vector3(spec[0] + spec[2] + 0.5, STREET_Y + spec[1] + 1.8, 0.0),
				Vector3(next[0] - 0.5, STREET_Y + next[1] + 1.8, 0.0), 1.6, 8)

	# The street below stays open the whole way, so falling is a demotion and
	# not a death.
	for i in 5:
		PropKit.market_stall(geometry, Vector3(80.0 + i * 12.0, STREET_Y, 1.0),
			3.0, mats["steel"], Color(0.70, 0.30, 0.20), Color(0.84, 0.78, 0.66),
			mats["crate"], 20 + i)

	_drone(Vector3(98.0, STREET_Y + 11.5, 0.0), 6.0)
	_turret(Vector3(116.0, STREET_Y + 9.4, 0.0))
	_walker(Vector3(130.0, STREET_Y + 8.6, 0.0), 3.2)
	_checkpoint(Vector3(107.0, STREET_Y + 6.1, 0.0), 1)


## Section C — the crossroads itself. The road opens out, the terrace stops,
## and the crossing is made on a stalled bus, a roundabout sign and two
## shipping containers. This is the level's one wide, empty, bright frame.
func _section_c_roundabout() -> void:
	var x := 154.0
	LevelKit.prop(geometry, Vector3(x + 18.0, STREET_Y + 0.14, -4.0),
		Vector3(40.0, 0.28, 12.0), mats["kerb"], "Island")
	# The sign gantry over the junction: the one place the level says where it
	# is, in Arabic, the way the road actually signs it.
	LevelKit.prop(geometry, Vector3(x + 10.0, STREET_Y + 3.4, -1.4),
		Vector3(0.28, 6.8, 0.28), mats["steel"], "GantryLegA")
	LevelKit.prop(geometry, Vector3(x + 28.0, STREET_Y + 3.4, -1.4),
		Vector3(0.28, 6.8, 0.28), mats["steel"], "GantryLegB")
	LevelKit.box(geometry, Vector3(x + 19.0, STREET_Y + 6.9, -1.4),
		Vector3(20.0, 0.5, 1.0), mats["steel"], "GantryBeam")
	var board := LevelKit.prop(geometry, Vector3(x + 19.0, STREET_Y + 8.0, -1.6),
		Vector3(9.0, 1.8, 0.2), mats["shutter_green"], "SignBoard")
	PropKit.sign(geometry, "بنغازي", Vector3(x + 21.0, STREET_Y + 8.1, -1.44),
		0.62, mats["cloth"], PropKit.FONT_NASKH_BOLD)
	PropKit.sign(geometry, "أجدابيا", Vector3(x + 16.0, STREET_Y + 7.6, -1.44),
		0.40, mats["cloth"], PropKit.FONT_NASKH)
	board.rotation.y = 0.0

	# The bus: stalled across two lanes, and the first big step up.
	_bus(Vector3(x + 4.0, STREET_Y, -1.0))
	_container(Vector3(x + 26.0, STREET_Y, -1.0), 6.0, 2.6, mats["shutter_blue"])
	_container(Vector3(x + 33.0, STREET_Y + 2.6, -1.4), 5.0, 2.6, mats["shutter_red"])

	TrailBuilder.jump_arc(geometry, Vector3(x + 12.0, STREET_Y + 3.4, 0.0), 1.0, 1.0, 8)
	TrailBuilder.cluster(geometry, Vector3(x + 29.0, STREET_Y + 6.4, 0.0), 0.9, 8)

	_turret(Vector3(x + 34.0, STREET_Y + 8.6, 0.0))
	_drone(Vector3(x + 16.0, STREET_Y + 10.0, 0.0), 6.5)
	_checkpoint(Vector3(x + 2.0, STREET_Y + 0.1, 0.0), 2)


## Section D — the back street. Narrow, shaded, and vertical: the far side of
## the crossroads is a service alley with balconies, and the Iced Out bottle is
## at the top of it.
func _section_d_backstreet() -> void:
	var x := 208.0
	_terrace(x - 4.0, x + 46.0, 9.2, 30)

	var rungs := [
		[x + 2.0, 2.4, 3.2], [x + 8.0, 4.2, 2.8], [x + 14.0, 6.0, 3.0],
		[x + 20.0, 4.6, 2.6], [x + 26.0, 7.2, 3.4], [x + 33.0, 5.4, 3.0],
		[x + 39.0, 8.0, 3.2],
	]
	for i in rungs.size():
		var r: Array = rungs[i]
		_ledge(r[0], STREET_Y + r[1], r[2])
		if i > 0:
			var p: Array = rungs[i - 1]
			TrailBuilder.curve(geometry,
				Vector3(p[0] + p[2] * 0.5, STREET_Y + p[1] + 1.5, 0.0),
				Vector3(r[0] - r[2] * 0.5, STREET_Y + r[1] + 1.5, 0.0), 1.3, 6)

	for i in 4:
		_vent(Vector3(x + 5.0 + i * 9.0, STREET_Y + 0.06, 0.0), float(i % 2) * 1.3, 4.0)

	_walker(Vector3(x + 22.0, STREET_Y + 0.2, 0.0), 6.0)
	_turret(Vector3(x + 30.0, STREET_Y + 11.0, 0.0))
	_drone(Vector3(x + 36.0, STREET_Y + 12.4, 0.0), 5.0)

	# THE ICED OUT BOTTLE. On the highest ledge in the level, past the last
	# rung, reachable only by gliding off the parapet above the alley.
	var iced := Sriracha.new()
	iced.variant = Sriracha.Variant.ICED_OUT
	geometry.add_child(iced)
	iced.position = Vector3(x + 44.0, STREET_Y + 12.4, 0.0)

	_checkpoint(Vector3(x + 21.0, STREET_Y + 4.6, 0.0), 3)


## Section E — the east gate. The road out, a last run along the roofs, and the
## exit under the sign for the coast road.
func _section_e_east_gate() -> void:
	var x := 262.0
	_terrace(x, x + 22.0, 7.4, 40)
	_ledge(x + 26.0, STREET_Y + 5.8, 4.0)
	_ledge(x + 34.0, STREET_Y + 4.2, 4.0)
	_ledge(x + 42.0, STREET_Y + 2.6, 5.0)

	TrailBuilder.curve(geometry, Vector3(x + 23.0, STREET_Y + 9.0, 0.0),
		Vector3(x + 44.0, STREET_Y + 4.4, 0.0), 2.2, 14)

	for i in 3:
		PropKit.market_stall(geometry, Vector3(x + 6.0 + i * 8.0, STREET_Y, 1.0),
			3.0, mats["steel"], Color(0.20, 0.38, 0.48), Color(0.84, 0.78, 0.66),
			mats["crate"], 60 + i)

	_turret(Vector3(x + 20.0, STREET_Y + 9.6, 0.0))
	_drone(Vector3(x + 32.0, STREET_Y + 9.0, 0.0), 5.0)

	# The gate.
	for side in 2:
		LevelKit.prop(geometry, Vector3(x + 50.0, STREET_Y + 3.0, -3.0 + side * 6.0),
			Vector3(1.6, 6.0, 1.6), mats["render_c"], "GatePier%d" % side)
	LevelKit.prop(geometry, Vector3(x + 50.0, STREET_Y + 6.4, 0.0),
		Vector3(1.8, 0.9, 8.0), mats["block"], "GateBeam")
	PropKit.sign(geometry, "الطريق الساحلي",
		Vector3(x + 50.0, STREET_Y + 6.45, 0.95), 0.44, mats["cloth"],
		PropKit.FONT_NASKH)

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


# --- Pieces -----------------------------------------------------------------

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
	AjdabiyaKit.town_facade(geometry, mats, left_x + 0.6, STREET_Y + 3.8,
		w - 1.2, height - 4.3, -4.96, seed_ + 3)

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


## A balcony ledge: the alley's rungs and the market's way up.
func _ledge(x: float, y: float, w: float) -> StaticBody3D:
	var body := LevelKit.box(geometry, Vector3(x, y - 0.14, 0.0),
		Vector3(w, 0.28, 1.6), mats["block"], "Ledge")
	LevelKit.prop(body, Vector3(0.0, 0.52, 0.75), Vector3(w, 0.06, 0.06),
		mats["rust"], "LedgeRail")
	for i in 3:
		LevelKit.prop(body, Vector3(-w * 0.4 + i * w * 0.4, 0.26, 0.75),
			Vector3(0.05, 0.52, 0.05), mats["rust"], "LedgeBaluster%d" % i)
	# Brackets under it, because a slab sticking out of a wall reads as a bug.
	for i in 2:
		var br := LevelKit.prop(body, Vector3(-w * 0.3 + i * w * 0.6, -0.36, 0.0),
			Vector3(0.7, 0.10, 0.10), mats["rust"], "Bracket%d" % i)
		br.rotation.z = -0.7
	return body


func _crates(at: Vector3, rows: int) -> void:
	for r in rows:
		for c in maxi(1, 2 - r):
			LevelKit.box(geometry,
				at + Vector3(c * 0.78 + r * 0.30, 0.34 + r * 0.66, 0.0),
				Vector3(0.74, 0.62, 0.74), mats["crate"], "Crate")


func _container(at: Vector3, length: float, height: float, mat: Material) -> void:
	var body := LevelKit.box(geometry, at + Vector3(length * 0.5, height * 0.5, 0.0),
		Vector3(length, height, 2.4), mat, "Container")
	# Corrugation ribs, so it is a container and not a coloured brick.
	for i in int(length / 0.42):
		LevelKit.prop(body, Vector3(-length * 0.5 + 0.21 + i * 0.42, 0.0, 1.22),
			Vector3(0.10, height * 0.92, 0.06), mat, "Rib%d" % i)
	LevelKit.prop(body, Vector3(0.0, height * 0.5 - 0.08, 1.24),
		Vector3(length, 0.16, 0.08), mats["rust"], "TopRail")
	LevelKit.prop(body, Vector3(0.0, -height * 0.5 + 0.08, 1.24),
		Vector3(length, 0.16, 0.08), mats["rust"], "BottomRail")


## The bus: stalled across the junction and repainted more than once.
func _bus(at: Vector3) -> void:
	var body := LevelKit.box(geometry, at + Vector3(5.0, 1.55, 0.0),
		Vector3(10.0, 2.5, 2.6), mats["shutter_blue"], "Bus")
	LevelKit.prop(body, Vector3(0.0, 1.40, 0.0), Vector3(9.4, 0.3, 2.5),
		mats["cloth"], "BusRoof")
	# A band of windows, dark and continuous: the read that says "bus".
	LevelKit.prop(body, Vector3(-0.4, 0.42, 1.31), Vector3(8.2, 0.9, 0.06),
		mats["dark"], "BusGlass")
	for i in 5:
		LevelKit.prop(body, Vector3(-3.6 + i * 1.8, 0.42, 1.33),
			Vector3(0.10, 0.94, 0.06), mats["steel"], "BusMullion%d" % i)
	for side in 2:
		LevelKit.prop(body, Vector3(-3.2 + side * 6.4, -1.05, 1.15),
			Vector3(1.0, 1.0, 0.5), mats["dark"], "BusWheel%d" % side)
	LevelKit.prop(body, Vector3(-5.05, 0.1, 0.0), Vector3(0.2, 1.8, 2.4),
		mats["shutter_red"], "BusFront")


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
