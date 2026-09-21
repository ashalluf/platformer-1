class_name MaterialLab
## The project's material library.
##
## Every surface comes from here. Presets are tuned by eye against capture
## screenshots, not by guessing at physical values, and they all share one
## weathering shader so a wall in Brega and a wall in Benghazi are the same
## material family with different inputs.

const SURFACE_SHADER := preload("res://shaders/surface_weathered.gdshader")

static var _cache: Dictionary = {}


## Core factory. Every preset below is a call to this with different numbers.
static func surface(p: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SURFACE_SHADER

	m.set_shader_parameter("base_color", p.get("color", Color(0.6, 0.58, 0.54)))
	m.set_shader_parameter("variation_color", p.get("variation", _shade(p.get("color", Color(0.6, 0.58, 0.54)), 0.88)))
	m.set_shader_parameter("variation_strength", p.get("variation_strength", 0.45))
	m.set_shader_parameter("metallic_value", p.get("metallic", 0.0))
	m.set_shader_parameter("roughness_min", p.get("roughness_min", 0.55))
	m.set_shader_parameter("roughness_max", p.get("roughness_max", 0.92))
	m.set_shader_parameter("emission_color", p.get("emission", Color.BLACK))
	m.set_shader_parameter("emission_strength", p.get("emission_strength", 0.0))

	m.set_shader_parameter("macro_noise", p.get("macro", NoiseBank.macro(p.get("seed", 11))))
	m.set_shader_parameter("detail_mask", p.get("mask", NoiseBank.grain(p.get("seed", 11) + 12)))
	m.set_shader_parameter("detail_normal", p.get("normal",
		NoiseBank.detail_normal(p.get("seed", 11) + 60, p.get("normal_freq", 0.12), p.get("bump", 1.6))))
	m.set_shader_parameter("macro_scale", p.get("macro_scale", 0.09))
	m.set_shader_parameter("detail_scale", p.get("detail_scale", 0.85))
	m.set_shader_parameter("normal_strength", p.get("normal_strength", 1.0))
	m.set_shader_parameter("triplanar_sharpness", p.get("sharpness", 5.0))
	m.set_shader_parameter("detail_fade_start", p.get("fade_start", 26.0))
	m.set_shader_parameter("detail_fade_end", p.get("fade_end", 70.0))

	m.set_shader_parameter("dust_color", p.get("dust_color", Color(0.66, 0.58, 0.43)))
	m.set_shader_parameter("dust_amount", p.get("dust", 0.28))
	m.set_shader_parameter("dust_sharpness", p.get("dust_sharpness", 3.0))
	m.set_shader_parameter("grime_color", p.get("grime_color", Color(0.15, 0.13, 0.11)))
	m.set_shader_parameter("grime_amount", p.get("grime", 0.30))
	m.set_shader_parameter("grime_origin_y", p.get("grime_origin", 0.0))
	m.set_shader_parameter("grime_falloff", p.get("grime_falloff", 2.2))
	m.set_shader_parameter("ao_strength", p.get("ao", 0.45))
	return m


static func _shade(c: Color, f: float) -> Color:
	return Color(c.r * f, c.g * f, c.b * f, c.a)


static func _cached(key: String, factory: Callable) -> ShaderMaterial:
	if not _cache.has(key):
		_cache[key] = factory.call()
	return _cache[key]


# --- Presets ----------------------------------------------------------------

## Poured concrete: prison walls, sea defences, road structures.
static func concrete(tint := Color(0.52, 0.51, 0.48), wear := 1.0) -> ShaderMaterial:
	return surface({
		"color": tint,
		"variation": _shade(tint, 0.80),
		"variation_strength": 0.55,
		"roughness_min": 0.62, "roughness_max": 0.95,
		"mask": NoiseBank.pits(37),
		"normal": NoiseBank.rough_normal(83, 0.05, 2.4),
		"detail_scale": 0.55, "macro_scale": 0.11,
		"normal_strength": 0.9,
		"dust": 0.22 * wear, "grime": 0.50 * wear, "grime_falloff": 2.4,
		"ao": 0.55,
	})


## Painted lime plaster — the ubiquitous Libyan wall. Chalky, sun-bleached,
## stained dark where it meets the ground.
static func plaster(tint := Color(0.86, 0.80, 0.68), wear := 1.0) -> ShaderMaterial:
	return surface({
		"color": tint,
		"variation": _shade(tint, 0.89),
		"variation_strength": 0.50,
		"roughness_min": 0.72, "roughness_max": 0.98,
		"mask": NoiseBank.streaks(53),
		"normal": NoiseBank.detail_normal(71, 0.09, 1.1),
		"detail_scale": 0.42, "macro_scale": 0.07,
		"normal_strength": 0.55,
		"dust": 0.18 * wear, "grime": 0.58 * wear, "grime_falloff": 1.8,
		"grime_color": Color(0.30, 0.25, 0.19),
		"ao": 0.40,
	})


## Rusted steel: bars, pipework, tank shells, anything by the sea in Brega.
static func rusted_metal(tint := Color(0.42, 0.22, 0.13), rust := 1.0) -> ShaderMaterial:
	return surface({
		"color": tint,
		"variation": Color(0.28, 0.22, 0.17),
		"variation_strength": 0.70,
		"metallic": 0.55 * (1.0 - 0.4 * rust),
		"roughness_min": 0.38, "roughness_max": 0.92,
		"mask": NoiseBank.pits(41),
		"normal": NoiseBank.rough_normal(91, 0.09, 2.8),
		"detail_scale": 0.9, "macro_scale": 0.16,
		"normal_strength": 1.1,
		"dust": 0.18, "grime": 0.35 * rust, "grime_color": Color(0.20, 0.10, 0.06),
		"ao": 0.5,
	})


## Painted sheet metal: doors, gates, signage backs, vehicle panels.
static func painted_metal(tint := Color(0.18, 0.32, 0.42), wear := 0.6) -> ShaderMaterial:
	return surface({
		"color": tint,
		"variation": _shade(tint, 0.80),
		"variation_strength": 0.40,
		"metallic": 0.15,
		"roughness_min": 0.26, "roughness_max": 0.60,
		"mask": NoiseBank.grain(29),
		"normal": NoiseBank.detail_normal(67, 0.16, 0.8),
		"detail_scale": 1.2, "macro_scale": 0.12,
		"normal_strength": 0.45,
		"dust": 0.22 * wear, "grime": 0.28 * wear,
		"ao": 0.3,
	})


## Corrugated steel roofing and fencing — the ridges come from the normal map,
## not from geometry, so a wall of it costs two triangles.
static func corrugated(tint := Color(0.46, 0.45, 0.43), period := 26.0) -> ShaderMaterial:
	return surface({
		"color": tint,
		"variation": _shade(tint, 0.76),
		"variation_strength": 0.5,
		"metallic": 0.35,
		"roughness_min": 0.40, "roughness_max": 0.80,
		"mask": NoiseBank.corrugation_mask(period),
		"normal": NoiseBank.corrugation_normal(period, 2.6),
		"detail_scale": 1.0, "macro_scale": 0.12,
		"normal_strength": 1.3, "sharpness": 8.0,
		"dust": 0.35, "grime": 0.25,
		"ao": 0.35,
	})


## Drifted sand and dry ground.
static func sand(tint := Color(0.78, 0.68, 0.50)) -> ShaderMaterial:
	return surface({
		"color": tint,
		"variation": Color(0.70, 0.61, 0.45),
		"variation_strength": 0.45,
		"roughness_min": 0.85, "roughness_max": 1.0,
		"mask": NoiseBank.grain(19),
		"normal": NoiseBank.detail_normal(77, 0.42, 0.45),
		"detail_scale": 3.2, "macro_scale": 0.16,
		"normal_strength": 0.7,
		"dust": 0.0, "grime": 0.10, "ao": 0.30,
	})


## Asphalt and worn road surface.
static func asphalt(tint := Color(0.20, 0.20, 0.21)) -> ShaderMaterial:
	return surface({
		"color": tint,
		"variation": Color(0.26, 0.25, 0.24),
		"variation_strength": 0.6,
		"roughness_min": 0.55, "roughness_max": 0.90,
		"mask": NoiseBank.pits(43),
		"normal": NoiseBank.rough_normal(89, 0.20, 1.4),
		"detail_scale": 1.5, "macro_scale": 0.13,
		"normal_strength": 0.8,
		"dust": 0.30, "grime": 0.12, "ao": 0.45,
	})


# --- Non-weathering materials (StandardMaterial3D) --------------------------

## Skin, with subsurface scattering. Characters only.
static func skin(tint := Color(0.78, 0.56, 0.38)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = 0.48
	m.metallic = 0.0
	m.subsurf_scatter_enabled = true
	m.subsurf_scatter_strength = 0.28
	m.subsurf_scatter_skin_mode = true
	m.rim_enabled = true
	m.rim = 0.45
	m.rim_tint = 0.3
	m.specular = 0.4
	return m


## Cloth with a soft sheen and no metallic component.
static func cloth(tint := Color(0.78, 0.22, 0.14), rough := 0.78) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = rough
	m.metallic = 0.0
	m.rim_enabled = true
	m.rim = 0.35
	m.rim_tint = 0.55
	m.specular = 0.25
	return m


## Polished gold — the chain, and later the Iced Out set dressing.
static func gold(tint := Color(1.0, 0.78, 0.30)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.metallic = 1.0
	m.metallic_specular = 0.85
	m.roughness = 0.16
	return m


static func chrome(tint := Color(0.88, 0.90, 0.93), rough := 0.10) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.metallic = 1.0
	m.roughness = rough
	return m


static func glass(tint := Color(0.55, 0.68, 0.72, 0.30)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.metallic = 0.25
	m.roughness = 0.08
	m.refraction_enabled = false
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func emissive(tint: Color, energy := 2.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.emission_enabled = true
	m.emission = tint
	m.emission_energy_multiplier = energy
	m.roughness = 0.4
	return m
