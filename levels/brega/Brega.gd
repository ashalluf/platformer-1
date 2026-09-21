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

const YARD_Y := BregaKit.YARD_Y
const DECK_Y := 0.0
const X_START := -14.0
const X_END := 384.0

var mats := {}
var _cage: PropertyCage


func _ready() -> void:
	level_id = "brega"
	level_title = "BREGA PRISON BREAKOUT"
	spawn_point = Vector3(-8.0, 1.4, 0.0)
	kill_plane_y = -30.0
	player_outfit = WanisBuilder.Outfit.PRISON
	music_theme = "brega"
	use_camera_bounds = true
	camera_bounds_min = Vector2(X_START + 6.0, -14.0)
	camera_bounds_max = Vector2(X_END - 6.0, 34.0)
	super._ready()
	camera.height_offset = 2.15
	camera.lateral_offset = 1.6


func _mood() -> LightingRig.Mood:
	return BregaKit.mood()


func _build_level() -> void:
	mats = BregaKit.palette()
	BregaKit.deep_layers(geometry, mats, X_START, X_END)
	BregaKit.mid_layers(geometry, mats, X_START, X_END)
	_section_a_walkway()
	_section_b_yard()
	_section_c_pipe_rack()
	_section_d_cage()
	_section_e_tank_farm()
	_section_f_fence()
	_atmosphere()


# --- A — THE WALKWAY --------------------------------------------------------
# He starts where the benchmark shot is framed. Flat, safe, and the first trail
# is a straight line at chest height: hold right.

func _section_a_walkway() -> void:
	PropKit.prefab_facade(geometry, X_START - 40.0, YARD_Y, 74.0, 10.6, -5.0,
		mats["slab"], {
			"name": "CellBlock", "joint_mat": mats["joint"], "dark_mat": mats["dark"],
			"hole_mat": mats["joint"], "depth": 5.0, "open_holes": 3,
		})
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

	TrailBuilder.line(geometry, Vector3(-3.0, DECK_Y + 0.8, 0.0),
		Vector3(11.0, DECK_Y + 0.8, 0.0), 8)
	# First gap: two steps down onto crates, so a miss is survivable.
	# Steps down off the end of the walkway into the yard. Crates, not a drop,
	# because this is the first time the floor moves and it should not punish.
	_crate_stack(Vector3(38.6, DECK_Y - 1.7, 0.0), 2)
	_crate_stack(Vector3(42.2, DECK_Y - 3.6, 0.0), 1)
	TrailBuilder.curve(geometry, Vector3(34.4, DECK_Y + 0.9, 0.0),
		Vector3(39.0, DECK_Y + 0.4, 0.0), 1.0, 6)


# --- B — THE YARD -----------------------------------------------------------
# Down on the sabkha. Wider, with gaps that want a double jump and the first
# SNITCH patrolling a beat the player can watch before committing.

func _section_b_yard() -> void:
	PropKit.deck(geometry, 44.0, YARD_Y + 1.2, 22.0, 0.0, mats["sabkha"], mats["rust"], YARD_Y - 1.2, "YardA")
	LevelKit.platform(geometry, 40.0, YARD_Y + 3.0, 5.0, mats["sabkha"], 9.0, 3.4, "YardStep")
	PropKit.deck(geometry, 72.0, YARD_Y + 1.2, 12.0, 0.0, mats["sabkha"], mats["rust"], YARD_Y - 1.2, "YardB")
	PropKit.deck(geometry, 92.0, YARD_Y + 2.6, 9.0, 0.0, mats["deck"], mats["rust"], YARD_Y - 1.2, "YardLedge")
	PropKit.deck(geometry, 105.0, YARD_Y + 4.4, 8.0, 0.0, mats["deck"], mats["rust"], YARD_Y - 1.2, "YardHigh")

	_crate_stack(Vector3(58.0, YARD_Y + 1.2, 0.0), 3)
	_crate_stack(Vector3(80.0, YARD_Y + 1.2, 0.0), 2)

	TrailBuilder.line(geometry, Vector3(47.0, YARD_Y + 2.1, 0.0),
		Vector3(60.0, YARD_Y + 2.1, 0.0), 7)
	# The gap that teaches the second jump: the arc peaks past what one jump reaches.
	TrailBuilder.curve(geometry, Vector3(66.5, YARD_Y + 2.3, 0.0),
		Vector3(72.5, YARD_Y + 2.3, 0.0), 2.4, 8)
	TrailBuilder.jump_arc(geometry, Vector3(84.5, YARD_Y + 2.2, 0.0), 1.0, 1.0, 8)
	TrailBuilder.cluster(geometry, Vector3(98.5, YARD_Y + 6.4, 0.0), 0.85, 8)

	# The first hazard in the game, alone, on flat ground with nothing else
	# happening: learn the collar.
	_vent(Vector3(52.0, YARD_Y + 0.08, 0.0), 0.0, 3.6)
	_drone(Vector3(63.0, YARD_Y + 5.2, 0.0), 4.5)
	_drone(Vector3(88.0, YARD_Y + 6.6, 0.0), 5.5)

	_checkpoint(Vector3(74.0, YARD_Y + 1.2, 0.0), 0)


# --- C — THE PIPE RACK ------------------------------------------------------
# Vertical. Climb the sleepers, then a drop too long to survive as a fall and
# exactly right as a glide. The trail hangs in the air to say so.

func _section_c_pipe_rack() -> void:
	PropKit.pipe_rack(geometry, Vector3(112.0, YARD_Y + 14.0, -3.2),
		Vector3(176.0, YARD_Y + 14.0, -3.2), 4, mats["rust"], mats["bund"], 10.0)

	var heights := [3.0, 5.0, 7.0, 9.0, 11.0]
	for i in heights.size():
		PropKit.deck(geometry, 114.0 + i * 6.0, YARD_Y + heights[i], 5.4, 0.0,
			mats["rust"], mats["steel"], YARD_Y - 1.2, "Sleeper%d" % i)
		TrailBuilder.line(geometry,
			Vector3(115.2 + i * 6.0, YARD_Y + heights[i] + 0.9, 0.0),
			Vector3(118.2 + i * 6.0, YARD_Y + heights[i] + 0.9, 0.0), 4)

	PropKit.deck(geometry, 144.0, YARD_Y + 12.4, 12.0, 0.0, mats["deck"], mats["steel"], YARD_Y - 1.2, "RackTop")
	LevelKit.prop(geometry, Vector3(150.0, YARD_Y + 13.7, -1.4), Vector3(12.0, 2.6, 0.5),
		mats["corrugated"], "RackScreen")

	# The glide. The catwalk on the far side is 22 units across and 9 down: a
	# jump falls short by a mile, a glide arrives with room.
	PropKit.deck(geometry, 168.0, YARD_Y + 4.6, 18.0, 0.0, mats["deck"], mats["rust"], YARD_Y - 1.2, "GlideLanding")
	TrailBuilder.line(geometry, Vector3(157.0, YARD_Y + 12.2, 0.0),
		Vector3(167.0, YARD_Y + 6.2, 0.0), 10)

	var sandwich := TunaSandwich.new()
	geometry.add_child(sandwich)
	sandwich.position = Vector3(163.5, YARD_Y + 11.0, 0.0)

	# First sentry of the level, high and alone, with a long run of cover under
	# it: the player meets the telegraph before they meet two of them.
	# Three on a stagger: a ripple you walk through, not a wall.
	for i in 3:
		_vent(Vector3(104.0 + i * 3.4, YARD_Y + 0.08, 0.0), float(i) * 0.9, 4.2)
	_turret(Vector3(126.0, YARD_Y + 12.6, 0.0))
	_drone(Vector3(132.0, YARD_Y + 9.0, 0.0), 5.0)
	_drone(Vector3(156.0, YARD_Y + 16.0, 0.0), 6.0)


# --- D — PROPERTY CAGE ------------------------------------------------------
# The beat. A dead-end store room, lit warm, with his own clothes on a shelf.

func _section_d_cage() -> void:
	PropKit.deck(geometry, 186.0, YARD_Y + 4.6, 38.0, 0.0, mats["deck"], mats["rust"], YARD_Y - 1.2, "StoreFloor")
	PropKit.prefab_facade(geometry, 186.0, YARD_Y + 4.6, 38.0, 7.0, -4.6, mats["slab"], {
		"name": "StoreWall", "joint_mat": mats["joint"], "dark_mat": mats["dark"],
		"hole_mat": mats["joint"], "depth": 4.0, "open_holes": 1,
	})
	PropKit.sign(geometry, "الأمانات", Vector3(204.0, YARD_Y + 9.4, -2.3), 0.52,
		MaterialLab.plaster(Color(0.60, 0.58, 0.54), 1.0), PropKit.FONT_KUFI)

	_cage = PropertyCage.new()
	geometry.add_child(_cage)
	_cage.position = Vector3(206.0, YARD_Y + 4.6, -0.6)
	_cage.opened.connect(_on_cage_opened)

	_checkpoint(Vector3(196.0, YARD_Y + 4.6, 0.0), 1)
	TrailBuilder.line(geometry, Vector3(189.0, YARD_Y + 5.5, 0.0),
		Vector3(202.0, YARD_Y + 5.5, 0.0), 7)


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

func _section_e_tank_farm() -> void:
	# Gaps here are all inside a plain running jump (about 6 units). This is the
	# section where he is newly armed and should feel powerful, not the section
	# that tests precision.
	PropKit.deck(geometry, 228.0, YARD_Y + 4.6, 16.0, 0.0, mats["deck"], mats["rust"], YARD_Y - 1.2, "FarmA")
	PropKit.deck(geometry, 249.0, YARD_Y + 6.2, 12.0, 0.0, mats["deck"], mats["rust"], YARD_Y - 1.2, "FarmB")
	PropKit.deck(geometry, 266.0, YARD_Y + 3.4, 14.0, 0.0, mats["deck"], mats["rust"], YARD_Y - 1.2, "FarmC")
	PropKit.deck(geometry, 284.0, YARD_Y + 5.0, 5.0, 0.0, mats["deck"], mats["rust"], YARD_Y - 1.2, "FarmStep")
	PropKit.deck(geometry, 295.0, YARD_Y + 6.8, 9.0, 0.0, mats["deck"], mats["rust"], YARD_Y - 1.2, "Catwalk")

	# A near tank the player runs past — depth in the gameplay band, not just
	# behind it.
	PropKit.storage_tank(geometry, Vector3(258.0, YARD_Y - 1.0, -44.0), 15.0, 19.0,
		mats["tank"], mats["bund"], mats["rust"], true, mats["tank_burnt"])

	TrailBuilder.jump_arc(geometry, Vector3(243.0, YARD_Y + 5.5, 0.0), 1.0, 1.0, 8)
	TrailBuilder.curve(geometry, Vector3(260.0, YARD_Y + 7.2, 0.0),
		Vector3(267.5, YARD_Y + 4.4, 0.0), 1.2, 7)
	TrailBuilder.cluster(geometry, Vector3(281.0, YARD_Y + 8.4, 0.0), 0.9, 8)

	_drone(Vector3(243.0, YARD_Y + 10.4, 0.0), 5.0)
	_drone(Vector3(274.0, YARD_Y + 11.2, 0.0), 6.5)
	_turret(Vector3(266.0, YARD_Y + 7.2, 0.0))
	# The first heavy, on open ground with a turret above it: the player has to
	# choose which telegraph to answer first.
	_walker(Vector3(258.0, YARD_Y + 0.2, 0.0), 6.5)
	for i in 4:
		_vent(Vector3(282.0 + i * 3.0, YARD_Y + 0.08, 0.0),
			float(i % 2) * 1.4, 4.6)
	_turret(Vector3(292.0, YARD_Y + 13.0, 0.0))
	_drone(Vector3(300.0, YARD_Y + 9.4, 0.0), 4.0)

	_checkpoint(Vector3(269.0, YARD_Y + 3.4, 0.0), 2)

	# The secret. Visible for about a second on the approach to the catwalk,
	# reachable only by gliding past the landing instead of onto it.
	# The obvious path steps across at height.
	PropKit.deck(geometry, 308.0, YARD_Y + 6.2, 6.0, 0.0, mats["deck"], mats["rust"], YARD_Y - 1.2, "FarmD")

	# The secret sits well below that step, in the shadow of the burnt tank.
	# On the approach it is visible for about a second through the gap; getting
	# to it means gliding past the step instead of landing on it.
	var iced := Sriracha.new()
	iced.variant = Sriracha.Variant.ICED_OUT
	iced.glow_energy = 6.0
	geometry.add_child(iced)
	iced.position = Vector3(304.0, YARD_Y - 3.4, 0.0)
	LevelKit.platform(geometry, 300.0, YARD_Y - 4.0, 8.0, mats["rust"], 0.5, 2.6, "SecretLedge")
	# And a way back up, so finding it is not a death sentence.
	LevelKit.platform(geometry, 310.0, YARD_Y - 1.4, 4.0, mats["rust"], 0.5, 2.6, "SecretStep")


# --- F — THE FENCE ----------------------------------------------------------
# Out. A chain of dash-glide gaps along the perimeter, then the gate.

func _section_f_fence() -> void:
	var xs := [317.0, 330.0, 343.0, 356.0]
	var ys := [6.0, 7.2, 5.2, 6.6]
	for i in xs.size():
		PropKit.deck(geometry, xs[i], YARD_Y + ys[i], 7.0, 0.0, mats["deck"], mats["rust"],
			YARD_Y - 1.2, "FencePad%d" % i)
		if i < xs.size() - 1:
			TrailBuilder.curve(geometry,
				Vector3(xs[i] + 7.5, YARD_Y + ys[i] + 1.4, 0.0),
				Vector3(xs[i + 1] - 0.5, YARD_Y + ys[i + 1] + 1.4, 0.0), 1.6, 7)

	var link := PropKit.chainlink_material(0.42, 30.0)
	PropKit.chainlink(geometry, 314.0, YARD_Y, 58.0, 5.0, -6.0, link, mats["rust"])

	_drone(Vector3(340.0, YARD_Y + 11.0, 0.0), 5.5)
	_drone(Vector3(356.0, YARD_Y + 10.0, 0.0), 4.5)
	_turret(Vector3(348.0, YARD_Y + 6.6, 0.0))
	_turret(Vector3(368.0, YARD_Y + 9.8, 0.0))
	_walker(Vector3(344.0, YARD_Y + 0.2, 0.0), 8.0)
	_walker(Vector3(372.0, YARD_Y + 0.2, 0.0), 5.0)

	# The gate out.
	PropKit.deck(geometry, 366.0, YARD_Y + 6.4, 16.0, 0.0, mats["deck"], mats["rust"], YARD_Y - 1.2, "GateDeck")
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


# --- Helpers ----------------------------------------------------------------

func _crate_stack(base: Vector3, count: int) -> void:
	for i in count:
		var c := LevelKit.box(geometry,
			base + Vector3(fmod(float(i) * 0.37, 0.4) - 0.2, 0.55 + i * 1.05, 0.0),
			Vector3(1.5, 1.05, 1.3), mats["crate"], "Crate%d" % i)
		c.rotation.z = fmod(float(i) * 0.13, 0.09) - 0.045
		c.add_to_group("surface_wood")


## A relief valve on a cycle. `phase` staggers a row so it ripples rather than
## firing as a wall, which is the difference between a rhythm and a hit.
func _vent(at: Vector3, phase := 0.0, h := 4.2) -> SteamVent:
	var v := SteamVent.new()
	geometry.add_child(v)
	v.global_position = at
	v.phase = phase
	v.height = h
	return v


## The heavy. Only where there is flat ground and room to get behind it.
func _walker(at: Vector3, span: float) -> HeavyWalker:
	var w := HeavyWalker.new()
	geometry.add_child(w)
	w.global_position = at
	w.patrol_span = span
	return w


## A wall-mounted sentry. Facing is always -x here: everything in this level
## is shooting at a man running east.
func _turret(at: Vector3) -> WallTurret:
	var t := WallTurret.new()
	geometry.add_child(t)
	t.global_position = at
	return t


func _drone(at: Vector3, span: float) -> SnitchDrone:
	var d := SnitchDrone.new()
	geometry.add_child(d)
	d.position = at
	d.patrol_span = span
	return d


func _checkpoint(at: Vector3, index: int) -> void:
	var c := Checkpoint.new()
	geometry.add_child(c)
	c.position = at
	c.index = index
	register_checkpoint(at + c.respawn_offset)
	c.reached.connect(reach_checkpoint)


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

	Audio.set_ambience("wind", -16.0)
