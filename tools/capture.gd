class_name CaptureSession extends Node
## Capture harness — the project's eyes.
##
## Loads a level headlessly, drives the player with a scripted input timeline at
## a fixed timestep, and writes PNG screenshots plus a JSON manifest of gameplay
## state. Nothing in this project counts as verified until it has been through
## here and the frames have been looked at.
##
## Usage:
##   godot --path . --fixed-fps 60 -- --capture \
##       --level=res://levels/greybox/Greybox.tscn \
##       --input=demo --frames=900 --every=60 --out=captures/greybox --res=1280x720
##
## `tools/capture.sh` wraps that with a virtual display. CaptureRunner (an
## autoload) spots --capture and hands control here.
##
## Options:
##   --level=PATH      scene to load
##   --input=NAME      timeline from tools/CaptureScripts.gd, or `auto` for the
##                     traversal autopilot (default: demo)
##   --frames=N        total frames to simulate (default: 600)
##   --every=N         save a frame every N frames
##   --shots=a,b,c     explicit frame indices to save (overrides --every)
##   --warmup=N        frames to settle GI/AA before frame 0 (default: 24)
##   --res=WxH         render resolution (default: 1280x720)
##   --quality=0..3    GraphicsDirector tier (default: 2)
##   --out=DIR         output directory (default: captures/run)
##   --camera=x,y,z    lock the camera to a fixed point (beauty shots)
##   --look=x,y,z      point a locked camera at a target
##   --fov=F           override camera FOV
##   --finish-at=N     emit the stage's level_complete at frame N, so the
##                     result card can be shot without playing the level
##   --pause-at=N      stop simulating input after frame N (hold the pose)
##   --cheat=ice       award the remaining ICE SRIRACHAS at frame 120, to shoot
##                     and verify the chain reward without a perfect run
##   --spawn=X,Y       override the level's spawn point, to shoot any section
##                     of a long level without playing through to it

const DEFAULTS := {
	"level": "res://levels/greybox/Greybox.tscn",
	"input": "demo",
	"frames": 600,
	"every": 60,
	"warmup": 24,
	"res": "1280x720",
	"quality": 2,
	"out": "captures/run",
	"pause-at": -1,
	"finish-at": -1,
	"fov": -1.0,
}

var opts := {}
var shots: Array[int] = []
var manifest := []
var errors := []


func _ready() -> void:
	_parse_args()
	print_rich("[b]capture[/b] level=%s input=%s frames=%d -> %s" % [
		opts["level"], opts["input"], int(opts["frames"]), opts["out"]])

	_configure_viewport()
	var stage := await _load_level()
	if stage == null:
		get_tree().quit(1)
		return

	await _warmup()
	await _run(stage)
	_write_manifest()
	print("capture: wrote %d frames to %s" % [manifest.size(), opts["out"]])
	get_tree().quit(0)


# --- Setup ------------------------------------------------------------------

func _parse_args() -> void:
	opts = DEFAULTS.duplicate()
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--capture":
			continue
		if not arg.begins_with("--"):
			continue
		var body := arg.substr(2)
		var eq := body.find("=")
		if eq < 0:
			opts[body] = true
			continue
		var key := body.substr(0, eq)
		var value := body.substr(eq + 1)
		if key == "shots":
			for s: String in value.split(",", false):
				shots.append(int(s))
		elif DEFAULTS.has(key) and typeof(DEFAULTS[key]) == TYPE_INT:
			opts[key] = int(value)
		elif DEFAULTS.has(key) and typeof(DEFAULTS[key]) == TYPE_FLOAT:
			opts[key] = float(value)
		else:
			opts[key] = value

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + str(opts["out"])))


func _configure_viewport() -> void:
	var parts: PackedStringArray = str(opts["res"]).split("x")
	var w := int(parts[0])
	var h := int(parts[1]) if parts.size() > 1 else int(float(w) * 9.0 / 16.0)
	var window := get_tree().root
	window.size = Vector2i(w, h)
	window.content_scale_size = Vector2i(w, h)
	GraphicsDirector.enter_capture_mode(int(opts["quality"]))
	GraphicsDirector.apply_to_viewport(window)


func _load_level() -> Node:
	var path: String = opts["level"]
	if not ResourceLoader.exists(path):
		push_error("capture: level not found: " + path)
		return null
	var packed: PackedScene = load(path)
	var stage := packed.instantiate()
	get_tree().root.add_child(stage)
	get_tree().current_scene = stage
	await get_tree().process_frame
	await get_tree().process_frame
	return stage


## Let SDFGI cascades, volumetric fog and auto-exposure converge before the
## first saved frame — otherwise early shots read as dark and noisy.
func _warmup() -> void:
	for i in int(opts["warmup"]):
		await get_tree().process_frame


# --- Run --------------------------------------------------------------------

func _run(stage: Node) -> void:
	var autopilot: bool = str(opts["input"]) == "auto"
	var timeline: Array = CaptureScripts.get_timeline(str(opts["input"])).duplicate()
	var total := int(opts["frames"])
	var every := int(opts["every"])
	var pause_at := int(opts["pause-at"])
	var axis := 0.0
	var jump_held := false
	var next_event := 0
	var dt := 1.0 / 60.0

	for frame in total:
		var t := frame * dt
		var player := _find_player(stage)

		if autopilot:
			if player and (pause_at < 0 or frame < pause_at):
				var cmd_state := _autopilot(player)
				axis = cmd_state["axis"]
				jump_held = cmd_state["jump_held"]
			else:
				axis = 0.0
				jump_held = false
		elif pause_at < 0 or frame < pause_at:
			while next_event < timeline.size() and timeline[next_event][0] <= t:
				var cmd: String = timeline[next_event][1]
				match cmd:
					"right": axis = 1.0
					"left": axis = -1.0
					"stop": axis = 0.0
					"jump":
						jump_held = true
						if player: player.scripted_jump()
					"hold_jump": jump_held = true
					"jumprelease":
						jump_held = false
						if player:
							player.scripted_jump_release()
							if player.velocity.y > 0.0:
								player.velocity.y *= player.jump_cut_mult
					"dash":
						if player: player.scripted_dash()
					"fire":
						if player: player.set_scripted_fire(true)
					"firestop":
						if player: player.set_scripted_fire(false)
					_:
						push_warning("capture: unknown command " + cmd)
				next_event += 1
		else:
			axis = 0.0
			jump_held = false

		if player:
			player.accept_player_input = false
			player.set_scripted_input(axis, jump_held)

		if int(opts.get("finish-at", -1)) == frame and stage.has_signal("level_complete"):
			print("  finish: emitting level_complete at frame %d" % frame)
			stage.level_complete.emit()

		if frame == 120 and str(opts.get("cheat", "")) == "ice":
			Gx.add_ice_sriracha(Gx.ICE_SRIRACHA_TARGET - Gx.ice_sriracha)
			print("  cheat: ice run completed at frame 120")

		_apply_camera_override(stage)
		await get_tree().process_frame

		var due := shots.has(frame) if not shots.is_empty() else (frame % maxi(every, 1) == 0)
		if due:
			await _save_frame(frame, t, stage)


# --- Traversal autopilot ----------------------------------------------------
#
# A dumb but honest playtester: run right, jump over what it cannot walk
# through, dash across what it cannot jump. If a level change makes a section
# impassable, the manifest stops advancing and the run ends somewhere it
# shouldn't. Geometry-driven, so it survives level edits that break a timeline.

var _ap_hold_left := 0
var _ap_cooldown := 0
var _ap_dash_armed := false
var _ap_glide := false
var _ap_brake := 1.0
var _ap_glide_grace := 0
var _ap_stuck_frames := 0
var _ap_last_x := 0.0

const AP_PROBE_DEPTH := 5.0
const AP_STEP_REACH := 3.3


func _autopilot(player: PlayerController) -> Dictionary:
	var dir := 1.0
	var pos := player.global_position
	var space := player.get_world_3d().direct_space_state
	var grounded := player.is_on_floor()

	_ap_cooldown = maxi(_ap_cooldown - 1, 0)
	if _ap_hold_left > 0:
		_ap_hold_left -= 1

	# Progress watchdog: a wall it cannot clear reads as no forward motion.
	if absf(pos.x - _ap_last_x) < 0.02 and grounded:
		_ap_stuck_frames += 1
	else:
		_ap_stuck_frames = 0
	_ap_last_x = pos.x

	if grounded:
		_ap_dash_armed = false

	var gap_at := func(d: float) -> bool:
		return not _ray(space, pos + Vector3(d * dir, 1.2, 0.0),
			pos + Vector3(d * dir, -AP_PROBE_DEPTH, 0.0), player).is_empty()

	var wall_hit := _ray(space, pos + Vector3(0.0, 0.55, 0.0),
		pos + Vector3(1.05 * dir, 0.55, 0.0), player)

	var want_jump := false
	var hold := 18

	if grounded and _ap_cooldown == 0:
		if not wall_hit.is_empty():
			# Something in front: find its top and jump only if it is reachable.
			var probe := pos + Vector3(1.0 * dir, AP_STEP_REACH, 0.0)
			var top := _ray(space, probe, probe + Vector3(0.0, -AP_STEP_REACH - 0.5, 0.0), player)
			if top.is_empty():
				want_jump = true
				hold = 26
			else:
				var rise: float = top["position"].y - pos.y
				want_jump = rise > 0.25
				hold = int(clampf(remap(rise, 0.3, 3.2, 9.0, 26.0), 8.0, 26.0))
		elif not _landing_ahead(space, pos, dir, player).is_empty():
			# A ledge above and ahead: jump just high enough and ease off the
			# stick so he lands on it instead of sailing past.
			var ledge := _landing_ahead(space, pos, dir, player)
			var rise: float = ledge["position"].y - pos.y
			var reach: float = absf(ledge["position"].x - pos.x)
			want_jump = true
			hold = int(clampf(remap(rise, 0.4, 3.2, 10.0, 26.0), 9.0, 26.0))
			_ap_brake = 0.55 if reach < 6.5 else 1.0
		elif not gap_at.call(1.9) or not gap_at.call(3.0):
			want_jump = true
			# Size the hold to the gap: peek further ahead for the far edge.
			hold = 22
			if not gap_at.call(5.2):
				hold = 26
				_ap_dash_armed = true
			# A gap this long is not a jump — but only glide it if the far side
			# is BELOW him. Gliding at a ledge that is higher than he is just
			# sinks him into the pit in front of it.
			if not gap_at.call(8.5) and _descent_ahead(space, pos, dir, player):
				_ap_glide = true
				_ap_glide_grace = 8
				# A glide needs the full stick; the short-hop brake from the
				# previous jump would otherwise leave it short of the landing.
				_ap_brake = 1.0

	# Sweep the aim arc for anything on the enemy layer, then shoot at it.
	var eye := pos + Vector3(0.0, 1.05, 0.0)
	var found := false
	for step in 7:
		var a: float = lerpf(-0.9, 1.05, float(step) / 6.0)
		var probe := eye + Vector3(cos(a) * 17.0 * dir, sin(a) * 17.0, 0.0)
		if not _ray_mask(space, eye, probe, player, 8).is_empty():
			player.set_scripted_aim(a / player.max_aim_angle)
			found = true
			break
	if not found:
		player.set_scripted_aim(0.0)
	player.set_scripted_fire(found)

	if _ap_stuck_frames > 24:
		want_jump = true
		hold = 26
		_ap_stuck_frames = 0

	if want_jump:
		player.scripted_jump()
		_ap_hold_left = hold
		_ap_cooldown = 10

	# Dash out of the apex of a long jump.
	if _ap_dash_armed and not grounded and player.velocity.y < 2.0:
		player.scripted_dash()
		_ap_dash_armed = false

	# The glide flag is armed on the same frame the jump is issued, while he is
	# still touching the ground, so it gets a grace period before "landed"
	# is allowed to clear it.
	if _ap_glide:
		_ap_glide_grace = maxi(_ap_glide_grace - 1, 0)
		if grounded and _ap_glide_grace == 0:
			_ap_glide = false
		else:
			return {"axis": dir * _ap_brake, "jump_held": true}

	if _ap_hold_left == 0 and not grounded and player.velocity.y > 0.0:
		player.scripted_jump_release()

	if grounded:
		_ap_brake = 1.0
	return {"axis": dir * _ap_brake, "jump_held": _ap_hold_left > 0}


## True when the next ground the autopilot can find ahead is well below him —
## the shape of a glide, as opposed to a gap he should jump.
func _descent_ahead(space: PhysicsDirectSpaceState3D, pos: Vector3, dir: float,
		player: Node3D) -> bool:
	for d: float in [10.0, 14.0, 18.0, 24.0]:
		var top := pos + Vector3(d * dir, 2.0, 0.0)
		var hit := _ray(space, top, top + Vector3(0.0, -34.0, 0.0), player)
		if hit.is_empty():
			continue
		return hit["position"].y < pos.y - 2.5
	return false


## Looks for a surface above and ahead — a step up rather than a gap across.
func _landing_ahead(space: PhysicsDirectSpaceState3D, pos: Vector3, dir: float,
		player: Node3D) -> Dictionary:
	for d: float in [2.2, 3.4, 4.6, 6.0]:
		var top := pos + Vector3(d * dir, AP_STEP_REACH + 0.4, 0.0)
		var hit := _ray(space, top, top + Vector3(0.0, -AP_STEP_REACH - 0.3, 0.0), player)
		if hit.is_empty():
			continue
		var rise: float = hit["position"].y - pos.y
		if rise > 0.4 and rise < AP_STEP_REACH:
			return hit
	return {}


func _ray_mask(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3,
		exclude: Node3D, mask: int) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [exclude.get_rid()]
	q.collision_mask = mask
	q.collide_with_areas = false
	return space.intersect_ray(q)


func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3,
		exclude: Node3D) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [exclude.get_rid()]
	q.collide_with_areas = false
	return space.intersect_ray(q)


func _find_player(stage: Node) -> PlayerController:
	if "player" in stage and stage.player != null and is_instance_valid(stage.player):
		return stage.player
	return get_tree().get_first_node_in_group("player") as PlayerController


func _apply_camera_override(stage: Node) -> void:
	if not opts.has("camera"):
		if float(opts["fov"]) > 0.0:
			var cam := _stage_camera(stage)
			if cam: cam.fov = float(opts["fov"])
		return
	var cam := _stage_camera(stage)
	if cam == null:
		return
	cam.set_process(false)
	cam.global_position = _parse_vec3(str(opts["camera"]))
	if opts.has("look"):
		cam.look_at(_parse_vec3(str(opts["look"])), Vector3.UP)
	if float(opts["fov"]) > 0.0:
		cam.fov = float(opts["fov"])


func _stage_camera(stage: Node) -> Camera3D:
	if "camera" in stage and stage.camera != null and is_instance_valid(stage.camera):
		return stage.camera
	return get_tree().root.get_camera_3d()


func _parse_vec3(s: String) -> Vector3:
	var p := s.split(",")
	return Vector3(float(p[0]), float(p[1]) if p.size() > 1 else 0.0,
		float(p[2]) if p.size() > 2 else 0.0)


# --- Output -----------------------------------------------------------------

func _save_frame(frame: int, t: float, stage: Node) -> void:
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	var name_ := "%04d.png" % frame
	var path := "res://%s/%s" % [opts["out"], name_]
	var err := img.save_png(path)
	if err != OK:
		errors.append("save failed %s (%d)" % [path, err])
		return

	var entry := {"frame": frame, "time": snappedf(t, 0.001), "file": name_}
	var player := _find_player(stage)
	if player:
		entry["pos"] = [snappedf(player.global_position.x, 0.01), snappedf(player.global_position.y, 0.01)]
		entry["vel"] = [snappedf(player.velocity.x, 0.01), snappedf(player.velocity.y, 0.01)]
		entry["state"] = PlayerController.State.keys()[player.state]
		entry["on_floor"] = player.is_on_floor()
		entry["sriracha"] = Gx.sriracha
		entry["lives"] = Gx.lives
	entry["enemies"] = get_tree().get_nodes_in_group("enemy").size()
	entry["ice"] = Gx.ice_sriracha
	entry["chains"] = Gx.chain_count()
	manifest.append(entry)
	print("  f%04d t=%.2fs %s" % [frame, t, entry.get("state", "-")])


func _write_manifest() -> void:
	var data := {
		"level": opts["level"],
		"input": opts["input"],
		"resolution": opts["res"],
		"quality": opts["quality"],
		"frames": manifest,
		"errors": errors,
	}
	var f := FileAccess.open("res://%s/manifest.json" % opts["out"], FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()
