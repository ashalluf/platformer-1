shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley,
	specular_schlick_ggx, world_vertex_coords;

// Wind for anything rooted to the ground: canopies, scrub, palm fronds, banners.
//
// Two scales of motion — a slow whole-plant lean and a faster per-branch
// flutter — phase-offset by world position so a row of trees never moves in
// lockstep. Anchoring is by height above the plant's base, passed in as
// `base_y`, so trunks stay planted while tops travel.

uniform vec4 albedo : source_color = vec4(0.21, 0.24, 0.18, 1.0);
uniform float roughness_value : hint_range(0.0, 1.0) = 0.92;
uniform vec3 wind_dir = vec3(1.0, 0.0, 0.0);
uniform float wind_strength = 0.35;
uniform float wind_speed = 0.9;
uniform float gust_speed = 2.6;
uniform float gust_strength = 0.35;
uniform float base_y = 0.0;
uniform float anchor_height = 6.0;
uniform float rim_strength : hint_range(0.0, 2.0) = 0.8;
uniform vec4 rim_tint : source_color = vec4(1.0, 0.84, 0.62, 1.0);
uniform sampler2D detail : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float detail_scale = 1.4;

varying float sway_amount;

void vertex() {
	// world_vertex_coords: VERTEX is already in world space here.
	float h = clamp((VERTEX.y - base_y) / max(anchor_height, 0.001), 0.0, 1.0);
	// Squared falloff: the top of a tree moves four times as far as its middle.
	float w = h * h;
	float phase = VERTEX.x * 0.13 + VERTEX.z * 0.19;

	float lean = sin(TIME * wind_speed + phase) * 0.6
		+ sin(TIME * wind_speed * 1.7 + phase * 2.1) * 0.4;
	float gust = sin(TIME * gust_speed + phase * 3.3) * 0.5
		+ sin(TIME * gust_speed * 2.3 + phase * 1.6) * 0.5;

	float amount = (lean * wind_strength + gust * gust_strength * wind_strength) * w;
	VERTEX += normalize(wind_dir) * amount;
	VERTEX.y -= abs(amount) * 0.25;   // leaning costs height, like a real branch
	sway_amount = amount;
}

void fragment() {
	float d = texture(detail, VERTEX.xy * detail_scale * 0.01).r;
	ALBEDO = albedo.rgb * (0.82 + 0.30 * d);
	ROUGHNESS = roughness_value;
	SPECULAR = 0.2;
	// Thin leaves light up when the sun is behind them.
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.2);
	EMISSION = rim_tint.rgb * rim * rim_strength * 0.16;
}
