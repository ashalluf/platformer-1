class_name FXKit
## The effects library: every puff, spark, streak, ribbon and flash in the game,
## built from code, returned as a node, owned by the caller.
##
## Gameplay code should never hand-build a GPUParticles3D again. It asks here,
## gets a node back, and either parents it itself or hands it to `spawn()`.
## Everything is a `static func` with no state and no tree access, so a builder
## can be called from a pool, from a level builder, or from inside a physics
## callback without caring where it is.
##
## HOUSE RULES BAKED IN (each one paid for in a capture that looked wrong):
##
##  * `ParticleProcessMaterial.scale_min/max` is a *variation* dial, not a size
##    dial. Absolute size always comes from the QuadMesh. Every quad below has
##    an explicit `size` and scale_* stays near 1.0.
##  * Additive sparks on an expanding shell pile up at the rim and read as a
##    white ring with a hole in it. Bursts here are small, short and dim:
##    velocity under ~4 m/s, life under ~0.35 s, alpha around 0.5.
##  * Nothing fire-coloured goes above ~1.5 brightness. Above that the
##    tonemapper flattens it to white and it stops being fire.
##  * GPU particles emitted from a marker under a scaled skeleton produce
##    garbage transforms. Anything that must be placed exactly — shell casings,
##    tracers — is an explicit simulated node, not a particle system.
##
##
## ---------------------------------------------------------------------------
## BUDGET — what is safe on screen at once at 1080p/60
## ---------------------------------------------------------------------------
## The hard limit is transparent overdraw, not particle count: 40 big soft
## puffs cost far more than 400 grit specks. Rule of thumb for the gameplay
## layer: keep live one-shot particles under ~200 and the sum of soft-puff
## screen area under about one screen.
##
##   effect            particles   live at once   how to spawn
##   ---------------------------------------------------------------------
##   footstep           10          6             POOL — fires 3-4x/second
##   landing_dust       24 + ring   2             spawn
##   dash_streak        12 + card   2             POOL — dash chains
##   speed_lines        26 cont.    1             build once, toggle emitting
##   glide_ribbons      18 cont.    1             build once on the rig
##   muzzle_smoke        8          POOL of 4     POOL — 9.5 rounds/second
##   shell_casings       3 meshes   POOL of 6     POOL — simulated, not GPU
##   bullet_impact      14          POOL of 8     POOL — mandatory, full-auto
##   ricochet            6          POOL of 4     POOL
##   debris_chunks      16          3             spawn
##   smoke_ball         12          3             spawn
##   arc_flash           3 ribbons  2             spawn
##   shockwave           1 card     3             spawn
##   sriracha_pop        8          8             POOL — trails collect fast
##   dust_motes        120-460 cont 2-3 per level place in the level, never spawn
##   wind_grit          90 cont.    2 per level   place in the level
##   plastic_bags        5 cont.    2 per level   place in the level
##   birds              9 nodes     1 flock       place in the level
##   water_spray        22          3             spawn
##   frost_crystals      7 shards   2             spawn
##   haze card          -           4 on screen   place in the level
##
## POOL means: build N once, reuse them, never allocate during play. Anything
## that can fire more than about twice a second must be pooled — at 9.5 rounds
## per second the rifle would otherwise allocate a scene tree's worth of
## particle nodes a minute and hand the GC the bill mid-firefight. Use
## `FXKit.Pool`.
##
## Heat haze cards each force a screen copy: keep them small in screen area and
## keep the count low. Four is comfortable, ten is not.
##
## `density` scales every particle count for the quality tier. GraphicsDirector
## should set it when it applies a tier (LOW 0.45, MEDIUM 0.7, HIGH/ULTRA 1.0);
## it defaults to full so nothing depends on that wiring existing.

const HAZE_SHADER := preload("res://shaders/heat_haze.gdshader")
const PARTICLE_SHADER := preload("res://shaders/fx_particle.gdshader")

## Particle-count multiplier for the current quality tier.
static var density := 1.0

## The level's key light, as the fake-scatter in fx_particle.gdshader wants it.
## Brega first light by default: a low, warm sun and cold sky fill. Levels call
## `set_key()` once in their builder and every puff built afterwards is lit to
## match — this is the single biggest reason smoke ever looks like it belongs in
## a scene rather than on top of it.
static var key_color := Color(1.00, 0.78, 0.54)
static var shadow_color := Color(0.34, 0.41, 0.55)
static var key_dir := Vector3(-0.55, -0.62, -0.45).normalized()

const SRIRACHA_TINT := Color(1.00, 0.36, 0.20)
const ICE_TINT := Color(0.72, 0.90, 1.00)
const ARC_TINT := Color(0.62, 0.86, 1.00)
const BRASS_TINT := Color(0.86, 0.66, 0.30)

## Per-surface response. `grit` is the heavy chip colour, `tint` the airborne
## dust, `spark` how much of a bullet hit comes back as sparks rather than dust.
const SURFACES := {
	&"concrete": {"tint": Color(0.74, 0.71, 0.66), "grit": Color(0.55, 0.52, 0.47), "spark": 0.15},
	&"sand": {"tint": Color(0.86, 0.75, 0.55), "grit": Color(0.70, 0.60, 0.42), "spark": 0.0},
	&"asphalt": {"tint": Color(0.48, 0.47, 0.46), "grit": Color(0.26, 0.26, 0.26), "spark": 0.2},
	&"metal": {"tint": Color(0.64, 0.66, 0.70), "grit": Color(0.52, 0.54, 0.58), "spark": 1.0},
	&"rust": {"tint": Color(0.60, 0.38, 0.23), "grit": Color(0.42, 0.24, 0.14), "spark": 0.55},
	&"wood": {"tint": Color(0.62, 0.48, 0.32), "grit": Color(0.42, 0.31, 0.19), "spark": 0.05},
	&"tile": {"tint": Color(0.80, 0.78, 0.74), "grit": Color(0.62, 0.60, 0.56), "spark": 0.25},
	&"ice": {"tint": Color(0.88, 0.95, 1.00), "grit": Color(0.72, 0.86, 0.98), "spark": 0.3},
	&"water": {"tint": Color(0.76, 0.88, 0.92), "grit": Color(0.60, 0.78, 0.84), "spark": 0.0},
	&"flesh": {"tint": Color(0.52, 0.30, 0.26), "grit": Color(0.38, 0.18, 0.16), "spark": 0.0},
}


## Re-key every effect built from here on. Call it once per level, from the
## builder, with the level's sun.
static func set_key(key: Color, shadow: Color, direction: Vector3) -> void:
	key_color = key
	shadow_color = shadow
	key_dir = direction.normalized()


static func surface_tint(surface: StringName) -> Color:
	var c: Color = _surface(surface)["tint"]
	return c


static func _surface(surface: StringName) -> Dictionary:
	var d: Dictionary = SURFACES.get(surface, SURFACES[&"concrete"])
	return d


# --- Shared resources -------------------------------------------------------
#
# Generated once and handed out by reference. A hundred puffs share one noise
# image; a hundred copies of it would be 25 MB of identical grey.

static var _tex_cache: Dictionary = {}
static var _mat_cache: Dictionary = {}


static func erode_noise() -> Texture2D:
	return NoiseBank.texture(
		NoiseBank.noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.020, 4, FastNoiseLite.FRACTAL_FBM,
			0.55, 2.1, 913),
		256, null, "fx_erode")


static func warp_noise() -> Texture2D:
	return NoiseBank.texture(
		NoiseBank.noise(FastNoiseLite.TYPE_SIMPLEX, 0.012, 3, FastNoiseLite.FRACTAL_FBM,
			0.5, 2.0, 271),
		256, null, "fx_warp")


## Soft radial alpha. Used as the shape mask where a puff wants a rounder,
## denser core than the shader's own falloff gives it.
static func soft_texture(size := 64) -> ImageTexture:
	return _texture("soft%d" % size, func() -> ImageTexture:
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		for y in size:
			for x in size:
				var u := (float(x) + 0.5) / float(size) - 0.5
				var v := (float(y) + 0.5) / float(size) - 0.5
				var d := clampf(1.0 - Vector2(u, v).length() * 2.0, 0.0, 1.0)
				d = d * d * (3.0 - 2.0 * d)
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, d))
		return ImageTexture.create_from_image(img))


## A soft annulus — the shockwave. A ring has to actually be a ring: a radial
## blob scaled up reads as a flash, not as a pressure wave leaving the impact.
static func ring_texture(size := 128) -> ImageTexture:
	return _texture("ring%d" % size, func() -> ImageTexture:
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		for y in size:
			for x in size:
				var u := (float(x) + 0.5) / float(size) - 0.5
				var v := (float(y) + 0.5) / float(size) - 0.5
				var d := Vector2(u, v).length() * 2.0
				# Thin bright rim, short inner falloff, hard outer cut.
				var a := clampf(1.0 - absf(d - 0.86) / 0.17, 0.0, 1.0)
				a = pow(a, 1.7) * clampf((1.0 - d) * 6.0, 0.0, 1.0)
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
		return ImageTexture.create_from_image(img))


## A short streak: bright core, fading tails. Speed lines and dash cards.
static func streak_texture(size := 64) -> ImageTexture:
	return _texture("streak%d" % size, func() -> ImageTexture:
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		for y in size:
			for x in size:
				var u := (float(x) + 0.5) / float(size)
				var v := (float(y) + 0.5) / float(size)
				var a := pow(sin(u * PI), 2.2) * pow(sin(v * PI), 1.1)
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(a, 0.0, 1.0)))
		return ImageTexture.create_from_image(img))


static func _texture(key: String, factory: Callable) -> ImageTexture:
	if not _tex_cache.has(key):
		_tex_cache[key] = factory.call()
	return _tex_cache[key]


# --- Materials --------------------------------------------------------------

## The house smoke/dust material. `opts` keys, all optional:
##   softness, alpha, brightness, erode, erode_scale, erode_softness,
##   scatter, back_scatter, depth_fade, fade_in, fade_out, shape (Texture2D),
##   spin, cache (false to get a private copy you may mutate).
static func smoke_material(tint: Color, opts: Dictionary = {}) -> ShaderMaterial:
	var key := "smoke:%s:%s:%s" % [tint, opts, key_color]
	if opts.get("cache", true) and _mat_cache.has(key):
		return _mat_cache[key]

	var m := ShaderMaterial.new()
	m.shader = PARTICLE_SHADER
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("soft_edge", opts.get("softness", 0.75))
	m.set_shader_parameter("alpha_scale", opts.get("alpha", 1.0))
	m.set_shader_parameter("brightness", opts.get("brightness", 1.0))
	m.set_shader_parameter("fade_in", opts.get("fade_in", 0.10))
	m.set_shader_parameter("fade_out", opts.get("fade_out", 0.45))
	m.set_shader_parameter("shape_tex", opts.get("shape", soft_texture()))
	m.set_shader_parameter("erode_noise", erode_noise())
	m.set_shader_parameter("erode_amount", opts.get("erode", 0.65))
	m.set_shader_parameter("erode_scale", opts.get("erode_scale", 1.6))
	m.set_shader_parameter("erode_softness", opts.get("erode_softness", 0.22))
	m.set_shader_parameter("rotation_random", opts.get("spin", 3.14))
	m.set_shader_parameter("key_color", opts.get("key", key_color))
	m.set_shader_parameter("shadow_color", opts.get("shadow", shadow_color))
	m.set_shader_parameter("key_dir", key_dir)
	m.set_shader_parameter("scatter", opts.get("scatter", 0.55))
	m.set_shader_parameter("back_scatter", opts.get("back_scatter", 0.45))
	# Small, fast puffs sit close to the floor they came off, so they need the
	# most depth fade; big slow plumes hang in open air and need almost none.
	m.set_shader_parameter("depth_fade", opts.get("depth_fade", 0.45))
	m.set_shader_parameter("near_fade", opts.get("near_fade", 0.35))

	if opts.get("cache", true):
		_mat_cache[key] = m
	return m


## Unshaded additive card. Sparks, flashes, tracer-adjacent things — anything
## that is light rather than matter. Deliberately a StandardMaterial3D: the
## particle shader billboards by hand, which fights velocity alignment.
static func spark_material(tint: Color, alpha := 0.55, tex: Texture2D = null) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(tint.r, tint.g, tint.b, alpha)
	m.albedo_texture = tex
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.disable_receive_shadows = true
	m.vertex_color_use_as_albedo = true
	# Sparks pass in front of pipework constantly; fading them as they approach
	# a surface stops the hard quad edge from showing up on it.
	m.proximity_fade_enabled = true
	m.proximity_fade_distance = 0.25
	return m


## The heat haze card material. `opts`: noise_scale, drift (Vector2), churn,
## rise, height_falloff, edge_power, opacity, tint, tint_amount, lift,
## occlusion_bias, near_fade.
static func haze_material(strength := 0.012, source_v := 1.0,
		opts: Dictionary = {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = HAZE_SHADER
	m.set_shader_parameter("warp_noise", warp_noise())
	m.set_shader_parameter("strength", strength)
	m.set_shader_parameter("source_v", source_v)
	m.set_shader_parameter("noise_scale", opts.get("noise_scale", 1.7))
	m.set_shader_parameter("drift", opts.get("drift", Vector2(0.04, -0.34)))
	m.set_shader_parameter("churn", opts.get("churn", 1.0))
	m.set_shader_parameter("rise", opts.get("rise", 0.30))
	m.set_shader_parameter("height_falloff", opts.get("height_falloff", 1.6))
	m.set_shader_parameter("edge_power", opts.get("edge_power", 1.5))
	m.set_shader_parameter("opacity", opts.get("opacity", 1.0))
	m.set_shader_parameter("envelope_break", opts.get("envelope_break", 0.35))
	m.set_shader_parameter("tint", opts.get("tint", Color(1.0, 0.88, 0.74)))
	m.set_shader_parameter("tint_amount", opts.get("tint_amount", 0.10))
	m.set_shader_parameter("lift", opts.get("lift", 0.02))
	m.set_shader_parameter("occlusion_bias", opts.get("occlusion_bias", 0.25))
	m.set_shader_parameter("occlusion_feather", opts.get("occlusion_feather", 0.60))
	m.set_shader_parameter("near_fade", opts.get("near_fade", 1.20))
	return m


## A heat haze card, ready to hang in the world. Face it at the camera (the
## side-on rig means leaving it in the XY plane is right almost always) and put
## it BETWEEN the camera and whatever is boiling — it distorts what is behind
## it, so a card buried inside the flare stack does nothing.
##
##   hot ground:   haze(Vector2(8, 1.6), 0.008, {"source_v": 1.0})
##   vent mouth:   haze(Vector2(1.4, 3.0), 0.016, {"rise": 0.5})
##   flare tip:    haze(Vector2(6, 7), 0.014, {"source_v": 0.72, "churn": 0.6})
static func haze(size: Vector2, strength := 0.012, opts: Dictionary = {}) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "HeatHaze"
	var quad := QuadMesh.new()
	quad.size = size
	mi.mesh = quad
	mi.material_override = haze_material(strength, opts.get("source_v", 1.0), opts)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	# Transparent sorting is by origin distance; nudging the card forward keeps
	# it in front of the transparent plume it usually shares a spot with.
	mi.sorting_offset = opts.get("sorting_offset", 0.5)
	return mi


# --- Particle plumbing ------------------------------------------------------

static func _amount(count: int) -> int:
	return maxi(1, int(round(float(count) * density)))


## Every one-shot burst in this file starts here: armed, world-space, culled
## against a generous box, and set to free itself when the last particle dies.
## `local_coords = false` is what stops a burst from riding the node that fired
## it — a puff that follows the player is the single most obvious tell that an
## effect is fake.
static func _burst(amount: int, lifetime: float, reach := 3.0) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = _amount(amount)
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	p.emitting = true
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3.ONE * -reach, Vector3.ONE * reach * 2.0)
	p.finished.connect(p.queue_free)
	return p


## The continuous counterpart: ambience that lives as long as its level does.
static func _stream(amount: int, lifetime: float, box: AABB) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = _amount(amount)
	p.lifetime = lifetime
	p.one_shot = false
	p.local_coords = false
	p.emitting = true
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = box
	# Ambience must look established the moment the level fades in, not seed
	# itself in front of the player over the first four seconds.
	p.preprocess = lifetime * 0.85
	p.fixed_fps = 30
	p.interpolate = true
	return p


static func _quad(size: float, mat: Material, aspect := 1.0) -> QuadMesh:
	var q := QuadMesh.new()
	# Absolute size lives here. ParticleProcessMaterial.scale_* is variation
	# only — it has never been trustworthy for real-world size.
	q.size = Vector2(size * aspect, size)
	q.material = mat
	return q


static func shrink_curve(from := 1.0, to := 0.0, mid := -1.0) -> CurveTexture:
	var c := Curve.new()
	c.add_point(Vector2(0.0, from))
	if mid >= 0.0:
		c.add_point(Vector2(0.45, mid))
	c.add_point(Vector2(1.0, to))
	var t := CurveTexture.new()
	t.curve = c
	return t


static func grow_curve(from := 0.35, to := 1.5) -> CurveTexture:
	var c := Curve.new()
	c.add_point(Vector2(0.0, from))
	c.add_point(Vector2(1.0, to))
	var t := CurveTexture.new()
	t.curve = c
	return t


static func ramp(stops: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(stops.map(func(s: Array) -> float: return s[0]))
	g.colors = PackedColorArray(stops.map(func(s: Array) -> Color: return s[1]))
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


## Orient local +Y along `normal`. Every impact effect is authored pointing up
## and rotated into place, which is also what makes them poolable: the hit
## direction lives in the node's transform, never baked into the material.
static func basis_from_normal(normal: Vector3) -> Basis:
	var n := normal.normalized()
	if n.length_squared() < 0.5:
		n = Vector3.UP
	var ref := Vector3.BACK if absf(n.z) < 0.95 else Vector3.RIGHT
	var x := ref.cross(n).normalized()
	if x.length_squared() < 0.5:
		x = Vector3.RIGHT
	var z := x.cross(n).normalized()
	return Basis(x, n, z)


# --- Materials: matter ------------------------------------------------------

## Chips, grit, brass flecks — bits with mass. Alpha blended and unshaded: a
## chip is a dark speck against a bright plant, and lighting a 3 cm quad
## correctly costs more than it could ever be worth.
static func chip_material(tint: Color, alpha := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(tint.r, tint.g, tint.b, alpha)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.disable_receive_shadows = true
	return m


## For particles that are STRETCHED ALONG THEIR VELOCITY — speed lines, wind
## ribbons, ricochets, droplets. Billboarding is left off on purpose: the node's
## `transform_align` is doing the orienting, and a material that also billboards
## fights it and produces a flickering mess.
static func streak_material(tint: Color, alpha := 0.6, additive := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.albedo_color = Color(tint.r, tint.g, tint.b, alpha)
	m.albedo_texture = streak_texture()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.disable_receive_shadows = true
	return m


# --- Movement ---------------------------------------------------------------

## Dust kicked backwards off a footfall. Surface-tinted, small, and thrown
## AGAINST the run direction — a puff that drifts forward reads as the ground
## exploding rather than as a foot pushing off it.
##
## Adopt in: PlayerController's `footstep` signal, via a pool.
static func footstep(surface := &"concrete", facing := 1, power := 1.0) -> GPUParticles3D:
	var s := _surface(surface)
	var p := _burst(10, 0.45, 1.5)
	p.name = "Footstep"

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.07
	pm.direction = Vector3(-float(facing) * 0.75, 1.0, 0.0)
	pm.spread = 26.0
	pm.initial_velocity_min = 0.45 * power
	pm.initial_velocity_max = 1.55 * power
	pm.gravity = Vector3(0.0, -1.1, 0.0)
	pm.damping_min = 2.0
	pm.damping_max = 5.0
	pm.scale_min = 0.75
	pm.scale_max = 1.35
	# Dust expands as it loses energy. Shrinking dust reads as a sprite fading.
	pm.scale_curve = grow_curve(0.55, 1.6)
	pm.angular_velocity_min = -120.0
	pm.angular_velocity_max = 120.0
	p.process_material = pm

	p.draw_pass_1 = _quad(0.22, smoke_material(s["tint"], {
		"softness": 0.9, "alpha": 0.45, "erode": 0.7, "erode_scale": 2.1,
		"depth_fade": 0.30, "scatter": 0.6, "fade_out": 0.55,
	}))
	return p


## The landing. A ring that leaves the feet outward, a ground shockwave card,
## and a handful of heavier chips for the hard ones. `power` is the 0..1 impact
## the controller already computes, and everything scales off it so a drop from
## a kerb and a drop from a gantry are the same effect at different volumes.
##
## Adopt in: PlayerController's `landed(impact)` signal.
static func landing_dust(power := 1.0, surface := &"concrete") -> Node3D:
	var s := _surface(surface)
	var root := Timed.new()
	root.name = "LandingDust"
	root.life = 1.2

	var p := _burst(int(lerpf(12.0, 26.0, power)), lerpf(0.45, 0.75, power), 3.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 0.26
	pm.emission_ring_inner_radius = 0.10
	pm.emission_ring_height = 0.02
	pm.direction = Vector3(0.0, 1.0, 0.0)
	pm.spread = 14.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 0.9
	# The ring is radial velocity, not spread: spread alone gives a dome, and a
	# dome is an explosion. A landing pushes air out sideways along the floor.
	pm.radial_velocity_min = lerpf(1.4, 3.6, power)
	pm.radial_velocity_max = lerpf(2.4, 5.4, power)
	pm.gravity = Vector3(0.0, -1.6, 0.0)
	pm.damping_min = 4.0
	pm.damping_max = 9.0
	pm.scale_min = 0.8
	pm.scale_max = 1.5
	pm.scale_curve = grow_curve(0.45, 1.8)
	pm.angular_velocity_min = -90.0
	pm.angular_velocity_max = 90.0
	p.process_material = pm
	p.draw_pass_1 = _quad(lerpf(0.26, 0.42, power), smoke_material(s["tint"], {
		"softness": 0.88, "alpha": lerpf(0.30, 0.55, power), "erode": 0.6,
		"depth_fade": 0.35, "scatter": 0.62, "fade_out": 0.5,
	}))
	root.add_child(p)

	# The pressure ring on the deck. Sells the weight far better than more dust.
	var ring := Card.new()
	ring.texture = ring_texture()
	ring.tint = s["tint"]
	ring.alpha = lerpf(0.18, 0.40, power)
	ring.size = Vector2.ONE * lerpf(1.0, 1.9, power)
	ring.ground = true
	ring.from_scale = Vector3(0.25, 1.0, 0.25)
	ring.to_scale = Vector3(1.0, 1.0, 1.0)
	ring.life = lerpf(0.22, 0.34, power)
	ring.position.y = 0.035
	root.add_child(ring)

	if power > 0.45:
		var chips := _burst(int(lerpf(3.0, 9.0, power)), 0.6, 3.0)
		var cm := ParticleProcessMaterial.new()
		cm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		cm.emission_sphere_radius = 0.16
		cm.direction = Vector3(0.0, 1.0, 0.0)
		cm.spread = 62.0
		cm.initial_velocity_min = 1.4 * power
		cm.initial_velocity_max = 3.6 * power
		cm.gravity = Vector3(0.0, -16.0, 0.0)
		cm.angular_velocity_min = -700.0
		cm.angular_velocity_max = 700.0
		cm.scale_min = 0.6
		cm.scale_max = 1.3
		chips.process_material = cm
		chips.draw_pass_1 = _quad(0.045, chip_material(s["grit"], 0.95))
		root.add_child(chips)

	return root


## The dash. A stretched card that grows and fades along the dash axis, plus
## grit torn off the ground behind him. Deliberately one card and not a trail:
## the dash is 0.165 s long and a trail system cannot even start in that time.
##
## Adopt in: PlayerController's `dash_started` signal.
static func dash_streak(facing := 1, tint := Color(1.0, 0.86, 0.66), charged := false) -> Node3D:
	var root := Timed.new()
	root.name = "DashStreak"
	root.life = 0.7

	var card := Card.new()
	card.texture = streak_texture()
	card.tint = tint
	card.alpha = 0.55 if charged else 0.38
	card.size = Vector2(2.4 if charged else 1.9, 0.85)
	card.additive = true
	# Stretches out along the dash and thins as it goes: the shape does the
	# speed, the fade only gets out of the way.
	card.from_scale = Vector3(0.45, 1.0, 1.0)
	card.to_scale = Vector3(1.75, 0.35, 1.0)
	card.life = 0.24
	card.position = Vector3(-float(facing) * 0.55, 0.0, 0.0)
	root.add_child(card)

	var p := _burst(12 if charged else 8, 0.4, 3.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.12, 0.45, 0.12)
	pm.direction = Vector3(-float(facing), 0.25, 0.0)
	pm.spread = 22.0
	pm.initial_velocity_min = 3.0
	pm.initial_velocity_max = 7.5
	pm.gravity = Vector3(0.0, -3.0, 0.0)
	pm.damping_min = 6.0
	pm.damping_max = 14.0
	pm.scale_min = 0.7
	pm.scale_max = 1.4
	pm.scale_curve = grow_curve(0.7, 1.5)
	p.process_material = pm
	p.draw_pass_1 = _quad(0.20, smoke_material(Color(0.78, 0.72, 0.64), {
		"softness": 0.92, "alpha": 0.32, "erode": 0.75, "depth_fade": 0.3,
	}))
	root.add_child(p)
	return root


## Air tearing past. Continuous, built once and left parented to the camera rig
## or the player; the caller toggles `emitting` and pushes `amount_ratio` with
## speed so the lines thicken as he accelerates instead of appearing at a
## threshold.
static func speed_lines(facing := 1, intensity := 1.0) -> GPUParticles3D:
	var p := _stream(26, 0.32, AABB(Vector3(-9, -5, -5), Vector3(18, 10, 10)))
	p.name = "SpeedLines"
	p.preprocess = 0.0
	p.emitting = false
	p.amount_ratio = clampf(intensity, 0.05, 1.0)
	# Velocity alignment is what makes these lines rather than dashes.
	p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	# Emitted in a shell around him, skewed ahead, so they sweep past the
	# camera rather than spawning in his face.
	pm.emission_box_extents = Vector3(2.2, 1.6, 1.4)
	pm.emission_shape_offset = Vector3(float(facing) * 2.6, 0.2, 0.0)
	pm.direction = Vector3(-float(facing), 0.0, 0.0)
	pm.spread = 4.0
	pm.initial_velocity_min = 16.0
	pm.initial_velocity_max = 30.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.6
	pm.scale_max = 1.6
	pm.color_ramp = ramp([[0.0, Color(1, 1, 1, 0.0)], [0.25, Color(1, 1, 1, 0.55)],
		[1.0, Color(1, 1, 1, 0.0)]])
	p.process_material = pm

	p.draw_pass_1 = _quad(1.05, streak_material(Color(1.0, 0.95, 0.88), 0.30), 0.045)
	return p


## Wind coming off the thobe in a glide. Long, soft, near-white ribbons that
## peel backwards off the hem — the readable tell that the glide is engaged,
## and the thing that makes the thobe look like fabric catching air rather than
## a cape asset.
##
## Parent it to the rig at the hem. It is world-space internally, so the
## ribbons stay where they were shed instead of riding him.
##
## Adopt in: WanisRig / PlayerController `glide_changed`.
static func glide_ribbons(span := 1.10, facing := 1) -> GPUParticles3D:
	var p := _stream(18, 0.55, AABB(Vector3(-6, -6, -4), Vector3(12, 12, 8)))
	p.name = "GlideRibbons"
	p.preprocess = 0.0
	p.emitting = false
	p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.06, span * 0.5, 0.30)
	pm.direction = Vector3(-float(facing), 0.18, 0.0)
	pm.spread = 12.0
	pm.initial_velocity_min = 2.4
	pm.initial_velocity_max = 5.2
	pm.gravity = Vector3(0.0, -0.9, 0.0)
	pm.damping_min = 1.0
	pm.damping_max = 3.0
	pm.scale_min = 0.7
	pm.scale_max = 1.5
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.35
	pm.turbulence_noise_scale = 1.6
	pm.color_ramp = ramp([[0.0, Color(1, 1, 1, 0.0)], [0.2, Color(1, 1, 1, 0.5)],
		[1.0, Color(1, 1, 1, 0.0)]])
	p.process_material = pm

	# Mix, not additive: this is moving air, and additive wind over a bright
	# dawn sky just bleaches a hole in the frame.
	p.draw_pass_1 = _quad(0.62, streak_material(Color(0.94, 0.96, 1.0), 0.22, false), 0.16)
	return p


# --- Combat -----------------------------------------------------------------
#
# Everything here is authored to be spawned at a WORLD position, never parented
# under the rig. Particles emitted from a marker buried under the squash-and-
# stretch node inherit its scale and come out as garbage — that is the same
# trap the tracers had to be rewritten to escape. Take `muzzle.global_position`
# and fire the effect into the scene root.

## The smoke that hangs off the barrel between rounds. Thin on purpose: at 9.5
## rounds a second an opaque puff per shot buries the hero inside four
## seconds of held fire.
##
## Adopt in: Rifle, on `fired` — via a pool of 4.
static func muzzle_smoke(facing := 1) -> GPUParticles3D:
	var p := _burst(8, 0.55, 2.0)
	p.name = "MuzzleSmoke"

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.04
	pm.direction = Vector3(float(facing), 0.22, 0.0)
	pm.spread = 24.0
	pm.initial_velocity_min = 0.9
	pm.initial_velocity_max = 2.6
	# Propellant smoke is hot: it climbs once it has stopped being pushed.
	pm.gravity = Vector3(0.0, 0.5, 0.0)
	pm.damping_min = 6.0
	pm.damping_max = 13.0
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	pm.scale_curve = grow_curve(0.4, 2.1)
	pm.angular_velocity_min = -160.0
	pm.angular_velocity_max = 160.0
	p.process_material = pm

	p.draw_pass_1 = _quad(0.13, smoke_material(Color(0.80, 0.76, 0.70), {
		"softness": 0.95, "alpha": 0.24, "erode": 0.8, "erode_scale": 2.4,
		"brightness": 1.1, "depth_fade": 0.25, "scatter": 0.7, "fade_out": 0.6,
	}))
	return p


## Ejected brass that actually lands. Simulated by hand rather than by GPU
## particles for two reasons: particles cannot bounce off level geometry
## without a collision volume authored for them, and brass that sinks through
## the deck is worse than no brass at all. It also gives us a `bounced` signal
## with a world position, so the audio pass can put a real clink where the
## casing hit.
##
## Adopt in: Rifle, replacing the skeleton-parented `_shells` — via a pool of 6.
static func shell_casings(facing := 1, count := 1) -> ShellBurst:
	var b := ShellBurst.new()
	b.name = "ShellCasings"
	b.count = clampi(count, 1, 6)
	b.facing = facing
	return b


## Where the round lands: a dust puff, chips, sparks on anything hard, and a
## two-frame point light. Authored pointing along local +Y — `impact()` rotates
## it onto the surface normal, which is also what lets it be pooled.
##
## Adopt in: Rifle._impact — via a pool of 8. This is the one that MUST be
## pooled; full auto against a wall allocates otherwise.
static func bullet_impact(surface := &"concrete", power := 1.0) -> Node3D:
	var s := _surface(surface)
	var root := Timed.new()
	root.name = "BulletImpact"
	root.life = 1.0

	var dust := _burst(6, 0.34, 2.0)
	var dm := ParticleProcessMaterial.new()
	dm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	dm.emission_sphere_radius = 0.04
	dm.direction = Vector3.UP
	dm.spread = 48.0
	dm.initial_velocity_min = 0.8
	dm.initial_velocity_max = 2.4
	dm.gravity = Vector3(0.0, -1.4, 0.0)
	dm.damping_min = 5.0
	dm.damping_max = 11.0
	dm.scale_curve = grow_curve(0.5, 1.9)
	dust.process_material = dm
	dust.draw_pass_1 = _quad(0.16, smoke_material(s["tint"], {
		"softness": 0.92, "alpha": 0.40, "erode": 0.72, "depth_fade": 0.22,
		"scatter": 0.6, "fade_out": 0.55,
	}))
	root.add_child(dust)

	var chips := _burst(5, 0.5, 2.5)
	var cm := ParticleProcessMaterial.new()
	cm.direction = Vector3.UP
	cm.spread = 52.0
	cm.initial_velocity_min = 2.0 * power
	cm.initial_velocity_max = 5.5 * power
	cm.gravity = Vector3(0.0, -18.0, 0.0)
	cm.damping_min = 1.0
	cm.damping_max = 4.0
	cm.angular_velocity_min = -900.0
	cm.angular_velocity_max = 900.0
	chips.process_material = cm
	chips.draw_pass_1 = _quad(0.035, chip_material(s["grit"], 0.9))
	root.add_child(chips)

	var spark_amount: float = s["spark"]
	if spark_amount > 0.05:
		# Small, short, dim. An additive spark burst that is allowed to expand
		# piles up at its own rim and turns into a white ring with a hole in it.
		var sparks := _burst(int(ceilf(6.0 * spark_amount)), 0.22, 2.5)
		var sm := ParticleProcessMaterial.new()
		sm.direction = Vector3.UP
		sm.spread = 40.0
		sm.initial_velocity_min = 2.2
		sm.initial_velocity_max = 4.0
		sm.gravity = Vector3(0.0, -12.0, 0.0)
		sm.damping_min = 6.0
		sm.damping_max = 14.0
		sm.scale_curve = shrink_curve()
		sparks.process_material = sm
		sparks.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
		sparks.draw_pass_1 = _quad(0.13,
			streak_material(Color(1.0, 0.86, 0.55), 0.5), 0.13)
		root.add_child(sparks)

		var flash := Flash.new()
		flash.light_color = Color(1.0, 0.84, 0.58)
		flash.energy = 2.4 * spark_amount
		flash.omni_range = 2.0
		flash.life = 0.06
		root.add_child(flash)

	return root


## A round that did not bite: a fast bright streak away from the surface along
## the reflected path, with the sparks it tore off. Cheap, and the single best
## reason to shoot at a steel pipe.
##
## Adopt in: Rifle._hitscan on glancing angles against metal — via a pool of 4.
static func ricochet(direction := Vector3.RIGHT, normal := Vector3.UP,
		tint := Color(1.0, 0.82, 0.48)) -> GPUParticles3D:
	var p := _burst(6, 0.26, 4.0)
	p.name = "Ricochet"
	# Bake the bounce into the node's basis, not into the process material, so
	# a pooled instance only has to be re-aimed.
	p.basis = basis_from_normal(direction.normalized().bounce(normal.normalized()))
	p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY

	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 16.0
	pm.initial_velocity_min = 8.0
	pm.initial_velocity_max = 17.0
	pm.gravity = Vector3(0.0, -16.0, 0.0)
	pm.damping_min = 2.0
	pm.damping_max = 6.0
	pm.scale_curve = shrink_curve(1.0, 0.1)
	pm.color_ramp = ramp([[0.0, Color(1, 1, 1, 0.9)], [0.7, Color(1, 1, 1, 0.5)],
		[1.0, Color(1, 1, 1, 0.0)]])
	p.process_material = pm
	p.draw_pass_1 = _quad(0.40, streak_material(tint, 0.6), 0.06)
	return p


# --- Enemy destruction ------------------------------------------------------

## Chunks of the thing that just stopped existing. Real chamfered geometry, lit
## by the scene, tumbling — the only part of a death that says "made of
## something" rather than "made of sprites".
##
## Adopt in: Enemy._debris.
static func debris_chunks(tint := Color(0.66, 0.62, 0.56), count := 16,
		power := 1.0) -> GPUParticles3D:
	var p := _burst(count, 1.1, 5.0)
	p.name = "Debris"

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.24
	pm.direction = Vector3.UP
	pm.spread = 68.0
	pm.initial_velocity_min = 2.2 * power
	pm.initial_velocity_max = 6.4 * power
	pm.gravity = Vector3(0.0, -19.0, 0.0)
	pm.damping_min = 0.5
	pm.damping_max = 2.5
	pm.angular_velocity_min = -540.0
	pm.angular_velocity_max = 540.0
	pm.scale_min = 0.55
	pm.scale_max = 1.5
	# Chunks do not shrink until the very end, then they are simply gone —
	# debris that fades while it is still in the air reads as smoke.
	pm.scale_curve = shrink_curve(1.0, 0.0, 1.0)
	p.process_material = pm

	# The chamfer cache hands out SHARED meshes. Never set a material on one —
	# it would repaint every block in the level. Override on the instance.
	# draw_passes has to be grown BEFORE the second pass is assigned, or the
	# setter rejects it out of bounds and the small chunks silently never
	# appear. Two sizes, because debris that is all one size reads as a pattern.
	p.draw_passes = 2
	p.draw_pass_1 = LevelKit.chamfer_mesh(Vector3(0.14, 0.11, 0.12))
	p.draw_pass_2 = LevelKit.chamfer_mesh(Vector3(0.07, 0.07, 0.06))
	p.material_override = LevelKit.material(tint, 0.82, 0.05)
	return p


## The ball of smoke a death leaves behind. Slow, erodes into rags, lit by the
## level key — it is what stops the debris from looking like it came out of
## nowhere.
static func smoke_ball(tint := Color(0.34, 0.31, 0.29), radius := 0.55) -> GPUParticles3D:
	var p := _burst(12, 0.95, 4.0)
	p.name = "SmokeBall"

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = radius * 0.45
	pm.direction = Vector3.UP
	pm.spread = 80.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 1.9
	pm.gravity = Vector3(0.0, 0.7, 0.0)
	pm.damping_min = 2.0
	pm.damping_max = 5.0
	pm.scale_min = 0.7
	pm.scale_max = 1.4
	pm.scale_curve = grow_curve(0.45, 2.0)
	pm.angular_velocity_min = -70.0
	pm.angular_velocity_max = 70.0
	p.process_material = pm

	p.draw_pass_1 = _quad(radius * 1.5, smoke_material(tint, {
		"softness": 0.85, "alpha": 0.55, "erode": 0.7, "erode_scale": 1.3,
		"depth_fade": 0.6, "scatter": 0.5, "back_scatter": 0.6, "fade_out": 0.6,
	}))
	return p


## Something electrical letting go: branching arcs in the gameplay plane, a
## hard blue-white flash, and a spit of sparks. For the drone and the turret,
## where a dust cloud would be wrong.
##
## Adopt in: SnitchDrone / WallTurret death.
static func arc_flash(radius := 0.55, tint := ARC_TINT) -> ArcFlash:
	var a := ArcFlash.new()
	a.name = "ArcFlash"
	a.radius = radius
	a.tint = tint
	return a


## A pressure ring on the ground. Landings, deaths, boss slams, chain rewards.
static func shockwave(radius := 1.4, life := 0.3, tint := Color(1.0, 0.92, 0.80),
		alpha := 0.35) -> Card:
	var c := Card.new()
	c.name = "Shockwave"
	c.texture = ring_texture()
	c.tint = tint
	c.alpha = alpha
	c.size = Vector2.ONE * radius
	c.ground = true
	c.additive = true
	c.from_scale = Vector3(0.2, 1.0, 0.2)
	c.to_scale = Vector3.ONE
	c.life = life
	return c


# --- Collectibles -----------------------------------------------------------

## The sriracha pop. Small, warm, and over in a quarter of a second, because
## there are two hundred of these in a level and any one of them that demands
## attention is a level's worth of noise.
##
## Adopt in: Collectible._burst (the base pop) — via a pool of 8.
static func sriracha_pop(tint := SRIRACHA_TINT, scale := 1.0) -> Node3D:
	var root := Timed.new()
	root.name = "CollectPop"
	root.life = 0.6

	var p := _burst(8, 0.24, 2.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.07 * scale
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 1.4 * scale
	pm.initial_velocity_max = 3.2 * scale
	pm.gravity = Vector3(0.0, -7.0, 0.0)
	pm.damping_min = 8.0
	pm.damping_max = 16.0
	pm.scale_curve = shrink_curve()
	p.process_material = pm
	p.draw_pass_1 = _quad(0.045 * scale, spark_material(tint, 0.5))
	root.add_child(p)

	# One soft flash under the sparks gives the pop a centre. Without it the
	# sparks read as debris rather than as something being taken.
	var flash := Card.new()
	flash.texture = soft_texture()
	flash.tint = tint
	flash.alpha = 0.5
	flash.additive = true
	flash.size = Vector2.ONE * 0.5 * scale
	flash.from_scale = Vector3(0.35, 0.35, 1.0)
	flash.to_scale = Vector3(1.25, 1.25, 1.0)
	flash.life = 0.16
	root.add_child(flash)
	return root


# --- Ambient ----------------------------------------------------------------
#
# These are level furniture, not events: build them once in the level builder,
# park them where the camera will pass, and leave them running. None of them
# should ever be spawned from gameplay code.

## Motes hanging in a shaft of light. This is the effect that makes sun shafts
## through the pipe rack visible at all — volumetric fog gives the beam, the
## motes give it something to land on.
static func dust_motes(extents := Vector3(14, 6, 4), amount := 160, size := 0.05,
		tint := Color(1.0, 0.88, 0.70)) -> GPUParticles3D:
	var p := _stream(amount, 14.0,
		AABB(-extents, extents * 2.0))
	p.name = "DustMotes"

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extents * 0.5
	pm.direction = Vector3(1.0, 0.10, 0.0)
	pm.spread = 24.0
	pm.initial_velocity_min = 0.18
	pm.initial_velocity_max = 0.45
	pm.gravity = Vector3(0.0, -0.02, 0.0)
	pm.scale_min = 0.5
	pm.scale_max = 1.8
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.14
	pm.turbulence_noise_scale = 2.2
	p.process_material = pm

	var m := spark_material(tint, 0.22)
	# Wide proximity fade: a mote that clips into a pipe stops being a mote and
	# becomes a bright square stuck to it.
	m.proximity_fade_distance = 1.4
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	p.draw_pass_1 = _quad(size, m)
	return p


## Sand driving along the ground. Fast, low, velocity-stretched, and mixed
## rather than additive — grit is matter, and additive grit over a dawn sky
## turns into a haze of white dashes.
static func wind_grit(extents := Vector3(24, 3, 5), wind := Vector3(7.0, 0.6, 0.0),
		amount := 90, tint := Color(0.84, 0.74, 0.55)) -> GPUParticles3D:
	var life := maxf(extents.x / maxf(wind.length(), 0.5), 1.5)
	var p := _stream(amount, life, AABB(-extents, extents * 2.0))
	p.name = "WindGrit"
	p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(extents.x * 0.5, extents.y * 0.5, extents.z * 0.5)
	pm.direction = wind.normalized()
	pm.spread = 12.0
	pm.initial_velocity_min = wind.length() * 0.7
	pm.initial_velocity_max = wind.length() * 1.4
	pm.gravity = Vector3(0.0, -0.4, 0.0)
	pm.scale_min = 0.5
	pm.scale_max = 1.6
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.5
	pm.turbulence_noise_scale = 1.4
	pm.color_ramp = ramp([[0.0, Color(1, 1, 1, 0.0)], [0.15, Color(1, 1, 1, 0.75)],
		[0.8, Color(1, 1, 1, 0.55)], [1.0, Color(1, 1, 1, 0.0)]])
	p.process_material = pm
	p.draw_pass_1 = _quad(0.30, streak_material(tint, 0.35, false), 0.06)
	return p


## Plastic bags on the wind. Five of them, tumbling, never in a hurry. Pure
## environmental storytelling: nothing in a frame says "a real place that
## people left" faster than one bag going past a chain-link fence.
static func plastic_bags(extents := Vector3(20, 5, 6), wind := Vector3(3.2, 0.5, 0.0),
		count := 5, tint := Color(0.88, 0.89, 0.86)) -> GPUParticles3D:
	var life := maxf(extents.x / maxf(wind.length(), 0.4), 6.0)
	var p := _stream(count, life, AABB(-extents, extents * 2.0))
	p.name = "PlasticBags"

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extents * 0.5
	pm.direction = wind.normalized()
	pm.spread = 30.0
	pm.initial_velocity_min = wind.length() * 0.5
	pm.initial_velocity_max = wind.length() * 1.2
	# Barely any gravity: a bag is mostly air, and the lift is the whole charm.
	pm.gravity = Vector3(0.0, -0.25, 0.0)
	pm.damping_min = 0.2
	pm.damping_max = 0.8
	pm.angular_velocity_min = -220.0
	pm.angular_velocity_max = 220.0
	pm.scale_min = 0.7
	pm.scale_max = 1.5
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.1
	pm.turbulence_noise_scale = 0.9
	pm.color_ramp = ramp([[0.0, Color(1, 1, 1, 0.0)], [0.1, Color(1, 1, 1, 0.85)],
		[0.85, Color(1, 1, 1, 0.85)], [1.0, Color(1, 1, 1, 0.0)]])
	p.process_material = pm
	# No texture: a plain rotating quad reads as a sheet catching the light,
	# which is exactly what a bag is.
	p.draw_pass_1 = _quad(0.20, chip_material(tint, 0.6))
	return p


## Birds, far off. Not particles — nine nodes with two wings each, flapping out
## of phase and banking on a slow sine. Particles cannot flap, and flapping is
## the entire read at this distance.
##
## Put them at z = -30 or further back with a small wing span; they are a
## motion cue in the sky, not wildlife.
static func birds(count := 9, span := 30.0, opts: Dictionary = {}) -> BirdFlock:
	var f := BirdFlock.new()
	f.name = "Birds"
	f.count = maxi(count, 1)
	f.span = span
	f.wing = opts.get("wing", 0.34)
	f.speed = opts.get("speed", 1.9)
	f.tint = opts.get("tint", Color(0.10, 0.10, 0.13))
	f.spread = opts.get("spread", Vector3(0.0, 3.0, 4.0))
	f.flap = opts.get("flap", 3.4)
	return f


# --- Water and ice ----------------------------------------------------------

## A splash: heavy droplets stretched along their arc, and the mist they drag
## up behind them.
static func water_spray(power := 1.0, tint := Color(0.80, 0.90, 0.96)) -> Node3D:
	var root := Timed.new()
	root.name = "WaterSpray"
	root.life = 1.4

	var drops := _burst(int(14.0 * power) + 6, 0.65, 4.0)
	drops.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	var dm := ParticleProcessMaterial.new()
	dm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	dm.emission_ring_axis = Vector3.UP
	dm.emission_ring_radius = 0.18
	dm.emission_ring_inner_radius = 0.05
	dm.emission_ring_height = 0.02
	dm.direction = Vector3.UP
	dm.spread = 26.0
	dm.initial_velocity_min = 2.6 * power
	dm.initial_velocity_max = 6.0 * power
	dm.radial_velocity_min = 1.0
	dm.radial_velocity_max = 2.6
	dm.gravity = Vector3(0.0, -17.0, 0.0)
	dm.scale_min = 0.5
	dm.scale_max = 1.5
	dm.color_ramp = ramp([[0.0, Color(1, 1, 1, 0.9)], [0.75, Color(1, 1, 1, 0.7)],
		[1.0, Color(1, 1, 1, 0.0)]])
	drops.process_material = dm
	drops.draw_pass_1 = _quad(0.16, streak_material(tint, 0.55, false), 0.22)
	root.add_child(drops)

	var mist := _burst(8, 0.8, 3.0)
	var mm := ParticleProcessMaterial.new()
	mm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mm.emission_sphere_radius = 0.16
	mm.direction = Vector3.UP
	mm.spread = 70.0
	mm.initial_velocity_min = 0.5
	mm.initial_velocity_max = 1.8
	mm.gravity = Vector3(0.0, -0.9, 0.0)
	mm.damping_min = 3.0
	mm.damping_max = 7.0
	mm.scale_curve = grow_curve(0.5, 2.2)
	mist.process_material = mm
	mist.draw_pass_1 = _quad(0.26, smoke_material(tint, {
		"softness": 0.95, "alpha": 0.3, "erode": 0.7, "depth_fade": 0.4,
		"scatter": 0.75, "back_scatter": 0.6, "brightness": 1.15,
	}))
	root.add_child(mist)
	return root


## Frost taking hold: shards growing out of a surface in a staggered ripple,
## with glitter coming off them as they go. The ice world's signature reveal —
## a checkpoint freezing over, a platform crusting up under the player's feet.
static func frost_crystals(radius := 0.7, count := 7, hold := 1.4) -> FrostBloom:
	var f := FrostBloom.new()
	f.name = "FrostBloom"
	f.radius = radius
	f.count = maxi(count, 1)
	f.hold = hold
	return f


# --- Dispatch ---------------------------------------------------------------

## One call for gameplay code. `kind` is an event, optionally with a surface
## after a colon:
##
##   FXKit.impact(&"bullet:metal", hit.position, hit.normal, world)
##   FXKit.impact(&"land:sand", foot, Vector3.UP, world)
##   FXKit.impact(&"death:electrical", drone.global_position, Vector3.UP, world)
##
## Known kinds: step, land, bullet, ricochet, death, electrical, collect,
## splash, frost, dash. Unknown kinds fall back to a bullet impact rather than
## returning null, because an effect nobody tuned is still better than a hole
## in the feedback where a designer expected one.
##
## With `into`, the effect is parented there and starts immediately. Without,
## you get the node parked at `position` to place yourself.
static func impact(kind: StringName, position: Vector3, normal := Vector3.UP,
		into: Node = null) -> Node3D:
	var parts := String(kind).split(":")
	var event := parts[0]
	var surface: StringName = StringName(parts[1]) if parts.size() > 1 else &"concrete"

	var fx: Node3D
	var orient := true
	match event:
		"step":
			fx = footstep(surface, 1)
			orient = false
		"land":
			fx = landing_dust(1.0, surface)
			orient = false
		"ricochet":
			fx = ricochet(Vector3(normal.y, -normal.x, 0.0), normal)
			orient = false
		"death":
			fx = Timed.new()
			fx.name = "Death"
			(fx as Timed).life = 1.6
			fx.add_child(debris_chunks(surface_tint(surface), 16))
			fx.add_child(smoke_ball(Color(0.32, 0.29, 0.27), 0.55))
			fx.add_child(shockwave(1.5, 0.3))
			orient = false
		"electrical":
			fx = arc_flash(0.55)
			orient = false
		"collect":
			fx = sriracha_pop()
			orient = false
		"splash":
			fx = water_spray(1.0)
			orient = false
		"frost":
			fx = frost_crystals(0.7)
			orient = false
		"dash":
			fx = dash_streak(1)
			orient = false
		_:
			fx = bullet_impact(surface)

	if orient:
		fx.basis = basis_from_normal(normal)
	fx.position = position
	if into != null:
		return spawn(into, fx, position)
	return fx


## Put an effect in the world. `top_level` first, position before parenting:
## an effect added and THEN positioned emits its first frame at the origin,
## which on a one-shot burst is most of the effect.
static func spawn(parent: Node, fx: Node3D, at: Vector3) -> Node3D:
	fx.top_level = true
	fx.position = at
	parent.add_child(fx)
	return fx


# --- Nodes that animate themselves ------------------------------------------
#
# Anything here that plays once implements `replay()`: reset your clock, start
# again. That one convention is what makes every effect in this file poolable,
# including the composites — `Pool` walks the tree, restarts the particle
# systems and calls `replay()` on everything else.


## A container that frees itself once its slowest child has finished.
class Timed extends Node3D:
	var life := 1.0
	var pooled := false
	var _left := 0.0

	func _ready() -> void:
		_left = life

	func replay() -> void:
		_left = life
		visible = true

	func _process(delta: float) -> void:
		if _left <= 0.0:
			return
		_left -= delta
		if _left > 0.0:
			return
		if pooled:
			visible = false
		else:
			queue_free()


## A single quad that scales and fades once: shockwave rings, dash streaks,
## collect flashes. Driven by hand rather than by a Tween — a tween cannot be
## re-fired cleanly from a pool, and this is four lines of lerp.
class Card extends Node3D:
	var texture: Texture2D
	var tint := Color.WHITE
	var alpha := 0.5
	var size := Vector2.ONE
	var additive := true
	var ground := false          ## lie flat on the floor instead of facing the camera
	var from_scale := Vector3(0.3, 0.3, 1.0)
	var to_scale := Vector3.ONE
	var life := 0.3
	var pooled := false

	var _mat: StandardMaterial3D
	var _t := 0.0

	func _ready() -> void:
		var q := QuadMesh.new()
		q.size = size
		q.orientation = PlaneMesh.FACE_Y if ground else PlaneMesh.FACE_Z
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive \
			else BaseMaterial3D.BLEND_MODE_MIX
		_mat.albedo_texture = texture
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mat.disable_receive_shadows = true
		# A ring lying 3 cm above a deck WILL intersect the first slope it meets.
		# Proximity fade turns that intersection into a fade instead of a cut.
		_mat.proximity_fade_enabled = true
		_mat.proximity_fade_distance = 0.30
		q.material = _mat

		var mi := MeshInstance3D.new()
		mi.name = "Card"
		mi.mesh = q
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		add_child(mi)
		_apply(0.0)

	func replay() -> void:
		_t = 0.0
		visible = true
		_apply(0.0)

	func _process(delta: float) -> void:
		if _t >= life:
			return
		_t += delta
		var k := clampf(_t / maxf(life, 0.001), 0.0, 1.0)
		_apply(k)
		if k < 1.0:
			return
		if pooled:
			visible = false
		else:
			queue_free()

	func _apply(k: float) -> void:
		# Out-eased growth, steeper alpha decay: the card has to be gone before
		# it has finished moving, or the eye follows the fade instead of the hit.
		scale = from_scale.lerp(to_scale, 1.0 - pow(1.0 - k, 2.4))
		if _mat != null:
			_mat.albedo_color = Color(tint.r, tint.g, tint.b, alpha * pow(1.0 - k, 1.6))


## A light that exists for two frames. Muzzle flashes, impact sparks, arcs.
class Flash extends OmniLight3D:
	var energy := 3.0
	var life := 0.08
	var pooled := false
	var _t := 0.0

	func _ready() -> void:
		shadow_enabled = false
		light_energy = energy
		# Without this a flash does nothing in a dusty plant: the fog is most of
		# what the player actually sees of it.
		light_volumetric_fog_energy = 4.0

	func replay() -> void:
		_t = 0.0
		light_energy = energy

	func _process(delta: float) -> void:
		if _t >= life:
			return
		_t += delta
		var k := 1.0 - clampf(_t / maxf(life, 0.001), 0.0, 1.0)
		light_energy = energy * k * k
		if k > 0.0:
			return
		if pooled:
			light_energy = 0.0
		else:
			queue_free()


## Brass, simulated. Three casings, gravity, one bounce off whatever is under
## the shooter, then they lie there and fade. See `shell_casings()` for why
## this is not a particle system.
class ShellBurst extends Node3D:
	signal bounced(at: Vector3)

	const GRAVITY := 26.0

	var count := 3
	var facing := 1
	var life := 1.9
	var pooled := false

	var _shells: Array[MeshInstance3D] = []
	var _vel: Array[Vector3] = []
	var _spin: Array[Vector3] = []
	var _hits: Array[int] = []
	var _floor_local := INF
	var _t := 0.0

	func _ready() -> void:
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.008
		mesh.bottom_radius = 0.010
		mesh.height = 0.038
		mesh.radial_segments = 6
		var mat := MaterialLab.gold(FXKit.BRASS_TINT)
		for i in count:
			var mi := MeshInstance3D.new()
			mi.name = "Shell%d" % i
			mi.mesh = mesh
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			_shells.append(mi)
			_vel.append(Vector3.ZERO)
			_spin.append(Vector3.ZERO)
			_hits.append(0)
		_launch()

	func replay() -> void:
		_t = 0.0
		_floor_local = INF
		visible = true
		_launch()

	func _launch() -> void:
		for i in _shells.size():
			var mi := _shells[i]
			mi.position = Vector3(randf_range(-0.02, 0.02), randf_range(-0.02, 0.02), 0.0)
			mi.rotation = Vector3(randf_range(0.0, TAU), randf_range(0.0, TAU), 0.0)
			mi.scale = Vector3.ONE
			# Up and behind: brass leaves the port, it does not lead the shot.
			_vel[i] = Vector3(
				-float(facing) * randf_range(0.6, 1.6),
				randf_range(2.4, 3.8),
				randf_range(-0.4, 0.4))
			_spin[i] = Vector3(randf_range(-16.0, 16.0), randf_range(-16.0, 16.0), 0.0)
			_hits[i] = 0

	func _physics_process(_delta: float) -> void:
		if _floor_local != INF:
			return
		# Probed here rather than in _ready: the space state is only reliably
		# available inside the physics step. One ray for the whole burst — the
		# casings all land on the same deck, and three rays per shot at ten
		# shots a second is a lot of physics for brass.
		var space := get_world_3d().direct_space_state
		var from := global_position + Vector3(0.0, 0.25, 0.0)
		var q := PhysicsRayQueryParameters3D.create(from, from - Vector3(0.0, 8.0, 0.0))
		q.collision_mask = 1
		var hit := space.intersect_ray(q)
		_floor_local = (hit["position"].y - global_position.y) if not hit.is_empty() else -3.0

	func _process(delta: float) -> void:
		if _t >= life:
			return
		_t += delta
		var floor_y: float = _floor_local if _floor_local != INF else -3.0

		for i in _shells.size():
			var mi := _shells[i]
			if _hits[i] < 2:
				_vel[i].y -= GRAVITY * delta
				var p := mi.position + _vel[i] * delta
				if p.y <= floor_y and _vel[i].y < 0.0:
					p.y = floor_y
					_hits[i] += 1
					if _hits[i] >= 2 or absf(_vel[i].y) < 1.2:
						_hits[i] = 2
						_vel[i] = Vector3.ZERO
						_spin[i] = Vector3.ZERO
						mi.rotation.x = PI * 0.5   # settle on its side
					else:
						_vel[i].y = -_vel[i].y * 0.34
						_vel[i].x *= 0.55
						_vel[i].z *= 0.55
						_spin[i] *= 0.45
					bounced.emit(global_position + p)
				mi.position = p
				mi.rotation += _spin[i] * delta

			# Shrink out over the last third rather than sinking or blinking.
			var fade := clampf((_t - life * 0.66) / (life * 0.34), 0.0, 1.0)
			if fade > 0.0:
				mi.scale = Vector3.ONE * (1.0 - fade)

		if _t < life:
			return
		if pooled:
			visible = false
		else:
			queue_free()


## Something electrical failing. Branching ribbons in the gameplay plane,
## regenerated a few times over a quarter of a second, plus a hard flash and a
## spit of sparks.
##
## The arcs are ribbons rather than line primitives because Godot draws lines
## one pixel wide at any resolution, and a one-pixel arc at 1080p is a
## scratch on the lens, not a discharge.
class ArcFlash extends Node3D:
	var radius := 0.55
	var tint := Color(0.62, 0.86, 1.00)
	var arcs := 3
	var life := 0.26
	var step := 0.045            ## how often the arcs re-strike
	var pooled := false

	var _mi: MeshInstance3D
	var _light: Flash
	var _t := 0.0
	var _next := 0.0

	func _ready() -> void:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.disable_receive_shadows = true
		# Bright, but nowhere near the point where the tonemapper flattens it:
		# an arc reads as electricity because of its SHAPE, and a blown-out one
		# has no shape left.
		mat.albedo_color = Color(tint.r * 1.35, tint.g * 1.3, tint.b * 1.2, 0.85)

		_mi = MeshInstance3D.new()
		_mi.name = "Arcs"
		_mi.material_override = mat
		_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		add_child(_mi)

		_light = Flash.new()
		_light.light_color = tint
		_light.energy = 5.0
		_light.omni_range = radius * 7.0
		_light.life = life * 0.7
		add_child(_light)

		var sparks := FXKit._burst(7, 0.28, 3.0)
		sparks.name = "ArcSparks"
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = radius * 0.4
		pm.direction = Vector3.UP
		pm.spread = 180.0
		pm.initial_velocity_min = 1.8
		pm.initial_velocity_max = 3.6
		pm.gravity = Vector3(0.0, -10.0, 0.0)
		pm.damping_min = 8.0
		pm.damping_max = 15.0
		pm.scale_curve = FXKit.shrink_curve()
		sparks.process_material = pm
		sparks.draw_pass_1 = FXKit._quad(0.05, FXKit.spark_material(tint, 0.5))
		add_child(sparks)

		_strike()

	func replay() -> void:
		_t = 0.0
		_next = 0.0
		visible = true
		_strike()

	func _process(delta: float) -> void:
		if _t >= life:
			return
		_t += delta
		if _t >= _next:
			_next = _t + step
			_strike()
		if _t < life:
			return
		_mi.mesh = null
		if pooled:
			visible = false
		else:
			queue_free()

	## Rebuilds the whole arc set. Allocating a mesh six times over a quarter of
	## a second is a cost worth paying: this runs on a death, not every frame.
	func _strike() -> void:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for a in arcs:
			var dir := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0).normalized()
			var start := Vector3(randf_range(-0.08, 0.08), randf_range(-0.08, 0.08), 0.0)
			var end := dir * radius * randf_range(0.7, 1.3)
			_bolt(st, start, end, 6, radius * 0.16)
		var mesh := st.commit()
		_mi.mesh = mesh

	func _bolt(st: SurfaceTool, from: Vector3, to: Vector3, segments: int,
			jitter: float) -> void:
		var prev := from
		for i in range(1, segments + 1):
			var t := float(i) / float(segments)
			var p := from.lerp(to, t)
			if i < segments:
				# Jitter falls off toward the ends so the bolt still connects
				# the two points it is supposed to connect.
				var k := sin(t * PI)
				p += Vector3(randf_range(-jitter, jitter), randf_range(-jitter, jitter), 0.0) * k
			_ribbon(st, prev, p, lerpf(0.022, 0.006, t))
			prev = p

	func _ribbon(st: SurfaceTool, a: Vector3, b: Vector3, width: float) -> void:
		var d := b - a
		if d.length_squared() < 1e-8:
			return
		# Perpendicular in the gameplay plane. The camera is side-on, so a
		# ribbon built in XY is already facing it; cull is disabled, which is
		# what makes the winding question moot for a two-sided glow card.
		var n := Vector3(-d.y, d.x, 0.0).normalized() * width
		st.add_vertex(a - n)
		st.add_vertex(a + n)
		st.add_vertex(b + n)
		st.add_vertex(a - n)
		st.add_vertex(b + n)
		st.add_vertex(b - n)


## Birds in the far distance. Nine nodes, two wings each, flapping out of phase.
class BirdFlock extends Node3D:
	var count := 9
	var span := 30.0             ## how far they travel before wrapping around
	var wing := 0.34
	var speed := 1.9
	var flap := 3.4
	var spread := Vector3(0.0, 3.0, 4.0)
	var tint := Color(0.10, 0.10, 0.13)

	var _birds: Array[Node3D] = []
	var _wings: Array[Node3D] = []
	var _phase := PackedFloat32Array()
	var _rate := PackedFloat32Array()
	var _bob := PackedFloat32Array()

	func _ready() -> void:
		var mesh := _wing_mesh()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.92)
		# Two-sided: a bird is a silhouette from either side and mirroring the
		# mesh for the far wing would flip its winding for nothing.
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.disable_receive_shadows = true

		for i in count:
			var bird := Node3D.new()
			bird.name = "Bird%d" % i
			bird.position = Vector3(
				randf_range(-span * 0.5, span * 0.5),
				randf_range(-spread.y, spread.y),
				randf_range(-spread.z, spread.z))
			add_child(bird)
			for s in [1.0, -1.0]:
				var w := MeshInstance3D.new()
				w.mesh = mesh
				w.material_override = mat
				w.scale = Vector3(1.0, 1.0, s)
				w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				bird.add_child(w)
				_wings.append(w)
			_birds.append(bird)
			_phase.append(randf_range(0.0, TAU))
			_rate.append(randf_range(0.8, 1.25))
			_bob.append(randf_range(0.5, 1.4))

	func _wing_mesh() -> Mesh:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		# A swept wing out along +Z. Flapping is a rotation about X, which is
		# also the direction of flight — exactly how a real one works.
		st.add_vertex(Vector3(0.0, 0.0, 0.0))
		st.add_vertex(Vector3(-wing * 0.30, 0.0, wing))
		st.add_vertex(Vector3(wing * 0.42, 0.0, wing * 0.82))
		st.generate_normals()
		return st.commit()

	func _process(delta: float) -> void:
		for i in _birds.size():
			var bird := _birds[i]
			_phase[i] += delta * flap * _rate[i]
			bird.position.x += speed * _rate[i] * delta
			if bird.position.x > span * 0.5:
				bird.position.x = -span * 0.5
			# A slow vertical drift on its own sine keeps the flock from
			# reading as a row of sprites on a rail.
			bird.position.y += sin(_phase[i] * 0.21) * _bob[i] * delta
			var beat := sin(_phase[i])
			# Down-stroke is faster than the recovery; that asymmetry is most of
			# what makes a flap look like a flap.
			var a := (beat * 0.55 + 0.25) if beat > 0.0 else (beat * 0.32 + 0.25)
			_wings[i * 2].rotation.x = -a
			_wings[i * 2 + 1].rotation.x = a
			bird.rotation.z = beat * 0.08


## Frost taking a surface: shards pushing out of it in a staggered ripple,
## holding, then retreating. The growth uses an overshoot so each crystal
## snaps into place instead of inflating.
class FrostBloom extends Node3D:
	var radius := 0.7
	var count := 7
	var grow := 0.30
	var hold := 1.4
	var retreat := 0.35
	var pooled := false

	var _shards: Array[MeshInstance3D] = []
	var _base: Array[Vector3] = []
	var _delay := PackedFloat32Array()
	var _t := 0.0

	func _ready() -> void:
		var mat := MaterialLab.ice(0.85, Color(0.16, 0.42, 0.62))
		for i in count:
			var h := randf_range(0.18, 0.40) * (radius / 0.7)
			var mi := MeshInstance3D.new()
			mi.name = "Shard%d" % i
			# chamfer_mesh, never BoxMesh: a sharp-edged crystal has no edge
			# highlight and reads as a grey prism.
			mi.mesh = LevelKit.chamfer_mesh(Vector3(h * 0.34, h, h * 0.30))
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var ang := TAU * float(i) / float(count) + randf_range(-0.25, 0.25)
			var r := radius * randf_range(0.25, 1.0)
			mi.position = Vector3(cos(ang) * r, h * 0.35, sin(ang) * r * 0.45)
			# Splayed outward, like something that grew rather than was placed.
			mi.rotation = Vector3(randf_range(-0.35, 0.35), randf_range(0.0, TAU),
				cos(ang) * -0.45)
			mi.scale = Vector3(0.01, 0.01, 0.01)
			add_child(mi)
			_shards.append(mi)
			_base.append(Vector3.ONE)
			_delay.append(float(i) * 0.045 + randf_range(0.0, 0.03))

		var glitter := FXKit._burst(10, 0.7, 3.0)
		glitter.name = "Glitter"
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = radius * 0.8
		pm.direction = Vector3.UP
		pm.spread = 60.0
		pm.initial_velocity_min = 0.3
		pm.initial_velocity_max = 1.1
		pm.gravity = Vector3(0.0, -0.8, 0.0)
		pm.damping_min = 1.0
		pm.damping_max = 3.0
		pm.scale_curve = FXKit.shrink_curve(1.0, 0.0, 0.9)
		glitter.process_material = pm
		glitter.draw_pass_1 = FXKit._quad(0.035, FXKit.spark_material(FXKit.ICE_TINT, 0.6))
		add_child(glitter)

	func replay() -> void:
		_t = 0.0
		visible = true
		for mi in _shards:
			mi.scale = Vector3(0.01, 0.01, 0.01)

	func _process(delta: float) -> void:
		var total := grow + hold + retreat
		if _t >= total:
			return
		_t += delta
		for i in _shards.size():
			var k := clampf((_t - _delay[i]) / grow, 0.0, 1.0)
			# Overshoot on the way in: the crystal arrives, it does not inflate.
			var s := 1.0 + 1.70158 * pow(k - 1.0, 3.0) + 1.70158 * pow(k - 1.0, 2.0)
			if _t > grow + hold:
				s *= 1.0 - clampf((_t - grow - hold) / retreat, 0.0, 1.0)
			_shards[i].scale = _base[i] * maxf(s, 0.01)
		if _t < total:
			return
		if pooled:
			visible = false
		else:
			queue_free()


## Reuse for anything that fires more than about twice a second.
##
##   var impacts := FXKit.Pool.create(world, func() -> Node3D:
##       return FXKit.bullet_impact(&"metal"), 8)
##   impacts.fire(hit_position, FXKit.basis_from_normal(hit_normal))
##
## Build it once, hold the reference, never allocate again. The pool takes
## ownership: it quiets the self-free wiring on everything it adopts and
## restarts it on `fire()`.
class Pool extends Node3D:
	var _items: Array[Node3D] = []
	var _next := 0

	static func create(parent: Node, builder: Callable, size := 6) -> Pool:
		var pool := Pool.new()
		pool.name = "FXPool"
		parent.add_child(pool)
		for i in maxi(size, 1):
			var n: Node3D = builder.call()
			if n == null:
				continue
			pool._adopt(n)
		return pool

	func _adopt(n: Node3D) -> void:
		_quiet(n)
		n.top_level = true
		n.visible = false
		add_child(n)
		_items.append(n)

	## Oldest instance wins. A ring buffer is the right answer here: when the
	## pool is too small the effect you steal is the one nobody is looking at
	## any more, and the alternative — allocating — is the thing we came to
	## avoid.
	func fire(at: Vector3, basis := Basis.IDENTITY) -> Node3D:
		if _items.is_empty():
			return null
		var n := _items[_next]
		_next = (_next + 1) % _items.size()
		n.position = at
		n.basis = basis
		n.visible = true
		_wake(n)
		return n

	func size() -> int:
		return _items.size()

	static func _quiet(n: Node) -> void:
		if n is GPUParticles3D:
			var p := n as GPUParticles3D
			if p.finished.is_connected(p.queue_free):
				p.finished.disconnect(p.queue_free)
			p.emitting = false
		if n.has_method("replay"):
			n.set("pooled", true)
		for c in n.get_children():
			_quiet(c)

	static func _wake(n: Node) -> void:
		if n is GPUParticles3D:
			(n as GPUParticles3D).restart()
		if n.has_method("replay"):
			n.call("replay")
		for c in n.get_children():
			_wake(c)
