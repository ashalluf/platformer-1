extends Node3D
## Compiles every shader in res://shaders/ on a real GPU and fails loudly.
##
## This scene exists because of a specific, expensive discovery: neither
## `--headless --import` nor `--headless --check-only` validates shader source.
## Both run the dummy rasterizer, which never hands the code to a compiler, so a
## shader with a syntax error imports silently, checks clean, and then paints a
## magenta rectangle the first time a player sees it.
##
## The only thing that catches it is a real Vulkan render of a material using
## that shader. Scenes cover the shaders they use; this scene covers the rest —
## every shader in the folder, including the ones no level has adopted yet.
## tools/verify_all.sh boots it like any other scene, so a broken shader is a
## build failure rather than a surprise at capture time.

const SHADER_DIR := "res://shaders"

var _skies: Array[Sky] = []
var _env: Environment


func _ready() -> void:
	var paths := _shader_paths()
	print("ShaderLab: %d shaders" % paths.size())

	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 0.0, 6.0)
	cam.current = true
	add_child(cam)

	var we := WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.10, 0.12, 0.16)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.6, 0.65, 0.75)
	_env.ambient_light_energy = 1.0
	we.environment = _env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, 34.0, 0.0)
	sun.light_energy = 1.4
	add_child(sun)

	# A grid wide enough for every shader we have, laid out in reading order so
	# a magenta cell in a screenshot maps straight back to a filename.
	var cols := 5
	var i := 0
	for p in paths:
		var sh: Shader = load(p)
		if sh == null:
			push_error("ShaderLab: failed to load %s" % p)
			continue
		var x := (i % cols) - (cols - 1) * 0.5
		var y := 1.2 - float(i / cols) * 1.4
		_mount(sh, p, Vector3(x * 1.3, y, 0.0))
		i += 1


func _shader_paths() -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(SHADER_DIR)
	if d == null:
		push_error("ShaderLab: cannot open %s" % SHADER_DIR)
		return out
	for f in d.get_files():
		if f.ends_with(".gdshader"):
			out.append("%s/%s" % [SHADER_DIR, f])
	out.sort()
	return out


## Attaches the shader to whatever kind of node its mode requires. A shader is
## only compiled when something actually draws with it, so every mode needs its
## own carrier — a spatial shader on a ColorRect compiles nothing.
func _mount(sh: Shader, path: String, at: Vector3) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = sh
	match sh.get_mode():
		Shader.MODE_SPATIAL:
			var mi := MeshInstance3D.new()
			mi.name = path.get_file()
			var q := QuadMesh.new()
			q.size = Vector2(1.1, 1.1)
			# Enough tessellation that a vertex-displacing shader (cloth, water,
			# foliage wind) has something to move.
			q.subdivide_width = 12
			q.subdivide_depth = 12
			mi.mesh = q
			mi.material_override = mat
			mi.position = at
			mi.extra_cull_margin = 8.0
			add_child(mi)
		Shader.MODE_SKY:
			var sky := Sky.new()
			sky.sky_material = mat
			_skies.append(sky)
			if _env.sky == null:
				_env.background_mode = Environment.BG_SKY
				_env.sky = sky
		Shader.MODE_CANVAS_ITEM:
			var r := ColorRect.new()
			r.name = path.get_file()
			r.material = mat
			r.size = Vector2(96.0, 54.0)
			r.position = Vector2(8.0 + fposmod(at.x + 3.0, 5.0) * 104.0, 8.0)
			add_child(r)
		Shader.MODE_PARTICLES:
			var p := GPUParticles3D.new()
			p.name = path.get_file()
			p.process_material = mat
			p.draw_pass_1 = QuadMesh.new()
			p.amount = 8
			p.position = at
			add_child(p)
		Shader.MODE_FOG:
			var fv := FogVolume.new()
			fv.name = path.get_file()
			fv.material = mat
			fv.size = Vector3.ONE
			fv.position = at
			add_child(fv)
		_:
			push_error("ShaderLab: unhandled mode for %s" % path)


## Cycles through every sky shader, since only one can be bound at a time and
## an unbound sky shader is an uncompiled sky shader.
func _process(_delta: float) -> void:
	if _skies.size() < 2:
		return
	var idx := int(Engine.get_frames_drawn() / 12.0) % _skies.size()
	if _env.sky != _skies[idx]:
		_env.sky = _skies[idx]
