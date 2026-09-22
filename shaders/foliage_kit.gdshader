shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert_wrap,
	specular_schlick_ggx, world_vertex_coords;

// FoliageKit's wind. One shader for every plant in the game.
//
// The old foliage shader anchored sway to a per-MATERIAL ground height, which
// meant a level needed one material per ground plane and per plant height, and
// every instance of that material swayed in lockstep with the rest. This one
// moves all of that to per-instance data, so one material can drive a whole
// level's planting in a handful of MultiMesh draw calls:
//
//   INSTANCE_CUSTOM.x  phase      per-plant phase offset, hashed from position
//   INSTANCE_CUSTOM.y  lever      how free this element is, baked on the CPU
//                                 from its height above ITS OWN plant's root.
//                                 A trunk drum gets ~0.02, a crown frond ~1.0.
//                                 This is what keeps trunks planted while
//                                 canopies travel.
//   INSTANCE_CUSTOM.z  span       element length in metres, for the tip gradient
//   INSTANCE_CUSTOM.w  flutter    per-species chatter weight
//
//   COLOR.rgb          tint       per-instance tonal variation (and baked AO
//                                 for clumps buried inside a canopy)
//   COLOR.a            life       1 = green, 0 = dead. One MultiMesh can hold a
//                                 live crown and the dead fronds hanging off it.

uniform vec4 albedo : source_color = vec4(0.256, 0.330, 0.180, 1.0);
uniform vec4 tip_albedo : source_color = vec4(0.400, 0.430, 0.215, 1.0);
uniform vec4 dead_albedo : source_color = vec4(0.560, 0.500, 0.340, 1.0);
uniform float roughness_value : hint_range(0.0, 1.0) = 0.72;
uniform vec4 backlight_tint : source_color = vec4(0.22, 0.26, 0.12, 1.0);
uniform float rim_strength : hint_range(0.0, 3.0) = 0.8;
uniform vec4 rim_tint : source_color = vec4(1.0, 0.84, 0.62, 1.0);
uniform sampler2D detail : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float detail_scale = 0.35;
uniform float detail_amount : hint_range(0.0, 1.0) = 0.24;

uniform vec3 wind_dir = vec3(1.0, 0.0, 0.15);
uniform float wind_strength = 0.18;   // metres of travel at lever = 1
uniform float wind_speed = 0.8;       // species frequency: palms slow, grass fast
uniform float gust_speed = 1.35;
uniform float gust_strength = 1.6;    // multiple of wind_strength at the crest
uniform float gust_wavelength = 26.0; // metres between gust crests along the wind
uniform float flutter_strength = 0.035;

// Fallback path for a plain MeshInstance3D with no per-instance data.
uniform bool instanced = true;
uniform float base_y = 0.0;
uniform float anchor_height = 6.0;

varying float v_r;
varying float v_life;
varying vec3 v_tint;
varying vec3 v_world;

void vertex() {
	// MODEL_MATRIX carries the MultiMesh instance transform, so this is where
	// the element is attached to its plant — the frond's socket, not the
	// plant's root.
	vec3 origin = MODEL_MATRIX[3].xyz;

	float phase;
	float lever;
	float span;
	float flut;
	if (instanced) {
		phase = INSTANCE_CUSTOM.x;
		lever = INSTANCE_CUSTOM.y;
		span = max(INSTANCE_CUSTOM.z, 0.001);
		flut = INSTANCE_CUSTOM.w;
	} else {
		phase = origin.x * 0.7 + origin.z * 1.3;
		lever = clamp((VERTEX.y - base_y) / max(anchor_height, 0.001), 0.0, 1.0);
		lever *= lever;
		span = max(anchor_height, 0.001);
		flut = 1.0;
	}

	float r = clamp(length(VERTEX - origin) / span, 0.0, 1.0);
	v_r = r;
	v_life = COLOR.a;
	v_tint = COLOR.rgb;

	// The element as a whole is only as free as its attachment point, and
	// within the element the tip still travels further than the base.
	float w = lever * (0.30 + 0.70 * r * r);

	vec2 dir = normalize(wind_dir.xz + vec2(1e-5, 0.0));
	float along = dot(VERTEX.xz, dir);

	float breeze = sin(TIME * wind_speed + phase) * 0.62
		+ sin(TIME * wind_speed * 1.63 + phase * 2.1) * 0.38;

	// A gust is a wave running down the wind, not a switch thrown on the whole
	// row at once. Keying its phase to distance along the wind is what makes a
	// windbreak ripple end to end instead of breathing in unison, and it is the
	// single cheapest thing that stops a planted row reading as one object.
	float g = sin(TIME * gust_speed - along * (6.2831853 / max(gust_wavelength, 1.0))
		+ phase * 0.35);
	float pulse = max(g, 0.0);
	pulse *= pulse;   // gusts arrive and pass; they do not pull upwind

	float amount = (breeze + pulse * gust_strength) * wind_strength * w;
	VERTEX.xz += dir * amount;
	// A branch pivots on an arc; letting it slide sideways at constant height
	// is the tell that the sway is a texture trick.
	VERTEX.y -= abs(amount) * 0.30;

	float f = sin(TIME * wind_speed * 6.7 + along * 2.3 + phase * 3.7);
	VERTEX.xz += vec2(-dir.y, dir.x) * f * flutter_strength * flut * w;
	VERTEX.y += cos(TIME * wind_speed * 4.9 + phase * 2.3) * flutter_strength * flut * w * 0.7;

	v_world = VERTEX;
}

void fragment() {
	vec3 col = mix(albedo.rgb, tip_albedo.rgb, v_r);
	col = mix(dead_albedo.rgb, col, clamp(v_life, 0.0, 1.0));
	col *= v_tint;

	// World-space lookup. Sampling with the fragment VERTEX (which is view
	// space) makes the mottling swim across the canopy as the camera tracks —
	// on a side-scroller that reads as the tree being made of fog.
	float d = texture(detail, v_world.xz * detail_scale).r;
	ALBEDO = col * (1.0 - detail_amount * 0.5 + detail_amount * d);

	ROUGHNESS = roughness_value;
	SPECULAR = 0.3;   // house rule: 0.30 on every dielectric
	// Thin leaves pass light. Dead ones pass much less — they are lignified.
	BACKLIGHT = backlight_tint.rgb * clamp(v_life, 0.18, 1.0);

	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.4);
	EMISSION = rim_tint.rgb * rim * rim_strength * 0.12;
}
