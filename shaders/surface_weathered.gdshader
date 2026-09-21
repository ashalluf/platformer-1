shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// The workhorse environment surface.
//
// World-space triplanar so geometry can be built, scaled and rotated in code
// without ever authoring a UV, plus the three weathering cues that stop a
// stylized surface reading as plastic: dust settling on up-facing planes, grime
// creeping up from the ground, and macro colour blotching that breaks tiling.
//
// All noise arrives as pre-generated textures. Nothing is evaluated per-pixel
// that could have been evaluated once at load.

group_uniforms Base;
uniform vec4 base_color : source_color = vec4(0.60, 0.58, 0.54, 1.0);
uniform vec4 variation_color : source_color = vec4(0.45, 0.43, 0.40, 1.0);
uniform float variation_strength : hint_range(0.0, 1.0) = 0.40;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.0;
uniform float roughness_min : hint_range(0.0, 1.0) = 0.55;
uniform float roughness_max : hint_range(0.0, 1.0) = 0.95;
uniform vec4 emission_color : source_color = vec4(0.0);
uniform float emission_strength : hint_range(0.0, 8.0) = 0.0;

group_uniforms Detail;
uniform sampler2D macro_noise : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_mask : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float macro_scale = 0.055;
uniform float detail_scale = 0.85;
uniform float normal_strength : hint_range(0.0, 3.0) = 1.0;
uniform float triplanar_sharpness : hint_range(1.0, 16.0) = 5.0;
// Detail fades out with distance so far geometry does not shimmer.
uniform float detail_fade_start = 26.0;
uniform float detail_fade_end = 70.0;

group_uniforms Weathering;
uniform vec4 dust_color : source_color = vec4(0.72, 0.64, 0.48, 1.0);
uniform float dust_amount : hint_range(0.0, 1.0) = 0.40;
uniform float dust_sharpness : hint_range(1.0, 12.0) = 3.0;
uniform vec4 grime_color : source_color = vec4(0.16, 0.14, 0.12, 1.0);
uniform float grime_amount : hint_range(0.0, 1.0) = 0.30;
uniform float grime_origin_y = 0.0;
uniform float grime_falloff : hint_range(0.05, 30.0) = 2.2;
uniform float ao_strength : hint_range(0.0, 1.0) = 0.45;

varying vec3 world_pos;
varying vec3 world_nrm;


void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize(mat3(MODEL_MATRIX) * NORMAL);
}


vec3 tri_weights(vec3 n, float sharp) {
	vec3 w = pow(abs(n), vec3(sharp));
	return w / max(dot(w, vec3(1.0)), 1e-4);
}


vec4 tri_sample(sampler2D tex, vec3 p, vec3 w) {
	return texture(tex, p.zy) * w.x + texture(tex, p.xz) * w.y + texture(tex, p.xy) * w.z;
}


// Whiteout blend — the standard way to keep triplanar normals from cancelling
// out along the seams between projection planes.
vec3 tri_normal(sampler2D tex, vec3 p, vec3 w, vec3 n, float strength) {
	vec3 nx = texture(tex, p.zy).rgb * 2.0 - 1.0;
	vec3 ny = texture(tex, p.xz).rgb * 2.0 - 1.0;
	vec3 nz = texture(tex, p.xy).rgb * 2.0 - 1.0;
	nx.xy *= strength;
	ny.xy *= strength;
	nz.xy *= strength;
	nx = vec3(nx.xy + n.zy, abs(nx.z) * n.x);
	ny = vec3(ny.xy + n.xz, abs(ny.z) * n.y);
	nz = vec3(nz.xy + n.xy, abs(nz.z) * n.z);
	return normalize(nx.zyx * w.x + ny.xzy * w.y + nz.xyz * w.z);
}


void fragment() {
	vec3 n = normalize(world_nrm);
	vec3 w = tri_weights(n, triplanar_sharpness);
	vec3 pm = world_pos * macro_scale;
	vec3 pd = world_pos * detail_scale;

	float macro = tri_sample(macro_noise, pm, w).r;
	float detail = tri_sample(detail_mask, pd, w).r;

	float dist = length(VERTEX);
	float detail_fade = 1.0 - smoothstep(detail_fade_start, detail_fade_end, dist);

	// Macro is a gentle tonal drift across a wall, not a pattern. Anything with
	// visible edges here reads as camouflage from three metres away.
	vec3 albedo = mix(base_color.rgb, variation_color.rgb,
		smoothstep(0.18, 0.82, macro) * variation_strength);
	albedo *= mix(1.0, 0.88 + 0.24 * detail, detail_fade);

	// Dust settles on anything facing the sky.
	float up = clamp(n.y, 0.0, 1.0);
	float dust = pow(up, dust_sharpness) * dust_amount * (0.55 + 0.70 * detail);
	dust = clamp(dust, 0.0, 1.0);
	albedo = mix(albedo, dust_color.rgb, dust);

	// Grime creeps up from the ground line, heaviest where macro noise is dark.
	float grime = 0.0;
	if (grime_amount > 0.0) {
		float h = exp(-max(world_pos.y - grime_origin_y, 0.0) / grime_falloff);
		grime = clamp(h * grime_amount * (0.35 + 0.85 * (1.0 - macro)), 0.0, 1.0);
	}
	albedo = mix(albedo, grime_color.rgb, grime);

	ALBEDO = albedo;
	ROUGHNESS = clamp(mix(roughness_max, roughness_min, detail) + dust * 0.22 + grime * 0.12, 0.02, 1.0);
	METALLIC = metallic_value * (1.0 - clamp(dust + grime, 0.0, 1.0));

	if (normal_strength > 0.001 && detail_fade > 0.001) {
		vec3 wn = tri_normal(detail_normal, pd, w, n, normal_strength * detail_fade);
		NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	}

	AO = mix(1.0, clamp(0.30 + 0.90 * macro, 0.0, 1.0), ao_strength);
	AO_LIGHT_AFFECT = 0.55;

	if (emission_strength > 0.0) {
		EMISSION = emission_color.rgb * emission_strength;
	}
}
