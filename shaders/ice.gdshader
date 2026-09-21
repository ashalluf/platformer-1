shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley,
	specular_schlick_ggx;

// Ice.
//
// Not glass: ice is a solid with light living inside it. The read comes from
// three things — a deep core colour that brightens toward silhouette edges, a
// frost rind on up-facing surfaces, and hard specular glints that move as the
// camera does. Refraction is faked with a screen-space offset, which at this
// camera distance is indistinguishable from the real thing and costs nothing.

group_uniforms Body;
uniform vec4 ice_deep : source_color = vec4(0.055, 0.215, 0.375, 1.0);
uniform vec4 ice_bright : source_color = vec4(0.46, 0.76, 0.94, 1.0);
uniform float depth_gain : hint_range(0.0, 4.0) = 1.6;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.10;
uniform float internal_glow : hint_range(0.0, 4.0) = 0.18;

group_uniforms Frost;
uniform vec4 frost_color : source_color = vec4(0.80, 0.88, 0.96, 1.0);
uniform float frost_amount : hint_range(0.0, 1.0) = 0.55;
uniform float frost_sharpness : hint_range(1.0, 12.0) = 2.6;
uniform sampler2D frost_noise : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float frost_scale = 0.6;

group_uniforms Sparkle;
// Glints are a high-frequency threshold on a noise field, driven by the view
// vector so they wink as the camera moves. A static sparkle reads as dirt.
uniform float sparkle_amount : hint_range(0.0, 8.0) = 3.0;
// Small cells, very sparse: a glint should be a point of light, not a tile.
uniform float sparkle_density = 15.0;
uniform float sparkle_threshold : hint_range(0.5, 0.999) = 0.9935;

varying vec3 world_pos;
varying vec3 world_nrm;


void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize(mat3(MODEL_MATRIX) * NORMAL);
}


float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}


void fragment() {
	vec3 n = normalize(world_nrm);
	vec3 v = normalize(VIEW);

	// Fresnel: thin at the edges, deep through the middle.
	float facing = clamp(dot(normalize(NORMAL), v), 0.0, 1.0);
	float edge = pow(1.0 - facing, 2.2);

	vec3 body = mix(ice_deep.rgb, ice_bright.rgb, clamp(edge * depth_gain, 0.0, 1.0));

	// Frost gathers on anything facing up, broken by noise so the line is not
	// a clean latitude.
	float up = clamp(n.y, 0.0, 1.0);
	float grain = texture(frost_noise, world_pos.xz * frost_scale).r;
	float frost = pow(up, frost_sharpness) * frost_amount * (0.55 + 0.75 * grain);
	frost = clamp(frost, 0.0, 1.0);

	ALBEDO = mix(body, frost_color.rgb, frost);
	ROUGHNESS = mix(roughness_value, 0.75, frost);
	METALLIC = 0.0;
	SPECULAR = mix(0.9, 0.4, frost);

	// Internal glow, strongest where the ice is thick (facing the camera).
	vec3 glow = ice_bright.rgb * internal_glow * (0.25 + 0.75 * facing) * (1.0 - frost);

	// Glints: a sparse threshold on a hashed lattice, offset by the view
	// direction so they wink instead of sitting still.
	vec3 cell = floor(world_pos * sparkle_density + v * 3.0);
	float s = hash13(cell);
	if (s > sparkle_threshold) {
		float strength = (s - sparkle_threshold) / (1.0 - sparkle_threshold);
		glow += vec3(1.0, 1.0, 1.0) * strength * sparkle_amount;
	}

	EMISSION = glow;
	RIM = 0.6;
	RIM_TINT = 0.2;
}
