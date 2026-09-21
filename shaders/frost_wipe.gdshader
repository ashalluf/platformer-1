shader_type canvas_item;

// Screen transition: frost crawling in from the edges and from crystal seeds,
// rather than a fade. A fade says "loading"; this says "something happened".

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 frost_color : source_color = vec4(0.82, 0.94, 1.0, 1.0);
uniform vec4 deep_color : source_color = vec4(0.06, 0.16, 0.30, 1.0);
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float edge_softness : hint_range(0.01, 0.5) = 0.16;
uniform float crystal_scale = 5.0;

void fragment() {
	vec2 uv = UV;
	// Distance from the nearest edge, so frost grows inward from all four.
	float edge = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y)) * 2.0;

	// Crystal seeds break the front into facets instead of a clean ring.
	float n = texture(noise_tex, uv * crystal_scale).r;
	float field = edge * 0.72 + n * 0.28;

	float p = progress * 1.25;
	float mask = smoothstep(p, p - edge_softness, field);

	// The leading edge is brighter than the fill — frost rime.
	float rim = smoothstep(p - edge_softness, p - edge_softness * 0.35, field)
		- smoothstep(p - edge_softness * 0.35, p, field);

	vec3 col = mix(deep_color.rgb, frost_color.rgb, 0.35 + 0.65 * n);
	col += frost_color.rgb * rim * 1.6;
	COLOR = vec4(col, clamp(mask, 0.0, 1.0));
}
