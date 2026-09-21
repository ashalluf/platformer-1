shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley,
	specular_schlick_ggx, shadows_disabled;

// Chain-link and lattice, drawn on a single quad.
//
// Two diagonal wire families with a procedural alpha mask. Alpha-to-coverage,
// not scissor alone, because MSAA does not antialias a scissored edge and a
// fence is nothing but edges. Distance fade thins the wire toward the
// vanishing point instead of letting it alias into a grey film.

uniform vec4 wire_color : source_color = vec4(0.42, 0.40, 0.37, 1.0);
uniform float cells = 26.0;            // cells across the quad
uniform float wire_width : hint_range(0.01, 0.4) = 0.085;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.55;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.85;
uniform float rust : hint_range(0.0, 1.0) = 0.35;
uniform vec4 rust_color : source_color = vec4(0.40, 0.21, 0.12, 1.0);
uniform sampler2D rust_noise : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float fade_start = 30.0;
uniform float fade_end = 90.0;

void fragment() {
	vec2 uv = UV * cells;
	// Two diagonals: a chain-link mesh is a woven pair, not a square grid.
	float a = abs(fract(uv.x + uv.y) - 0.5);
	float b = abs(fract(uv.x - uv.y) - 0.5);
	float wire = 1.0 - smoothstep(wire_width * 0.5, wire_width, min(a, b));

	float dist = length(VERTEX);
	float fade = 1.0 - smoothstep(fade_start, fade_end, dist);
	ALPHA = wire * mix(0.25, 1.0, fade);

	float r = texture(rust_noise, UV * 3.0).r;
	ALBEDO = mix(wire_color.rgb, rust_color.rgb, rust * smoothstep(0.45, 0.85, r));
	ROUGHNESS = mix(roughness_value, 0.92, rust * r);
	METALLIC = metallic_value * (1.0 - rust * r);
	ALPHA_ANTIALIASING_EDGE = 0.35;
	ALPHA_TEXTURE_COORDINATE = vec2(ALPHA, 0.0);
}
