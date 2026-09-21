shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Wanis's thobe.
//
// The robe inflates and flutters from the hem up. Vertex colour carries the
// authoring data: R is hem weight (0 at the collar, 1 at the hem), G is a phase
// offset per ring so the flutter is not in lockstep. Driving `billow` from the
// controller is what turns the robe into a parachute during a glide.
//
// Skinning has already been applied by the time vertex() runs, so displacing
// VERTEX here rides on top of the animated pose.

uniform vec4 albedo : source_color = vec4(0.955, 0.945, 0.915, 1.0);
uniform float roughness_value : hint_range(0.0, 1.0) = 0.86;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.0;

group_uniforms Billow;
uniform float billow : hint_range(0.0, 1.0) = 0.0;
uniform float billow_spread = 0.34;
uniform float billow_lift = 0.10;
uniform float flutter = 0.045;
uniform float flutter_speed = 9.0;
// Ambient motion even when standing still — cloth is never perfectly static.
uniform float idle_sway = 0.010;
uniform float idle_speed = 1.7;
// Direction and amount the cloth streams, in model space. Driven from the
// controller's velocity, so the robe and shemagh lag behind the body.
uniform vec3 trail_dir = vec3(0.0, 0.0, -1.0);
uniform float trail_amount : hint_range(0.0, 1.0) = 0.0;
uniform float trail_reach = 0.30;

group_uniforms Surface;
uniform float rim_strength : hint_range(0.0, 2.0) = 0.55;
uniform vec4 rim_tint : source_color = vec4(1.0, 0.92, 0.80, 1.0);
// Fine weave, shaded rather than textured: cheap, and it never tiles.
uniform float weave_scale = 110.0;
uniform float weave_depth : hint_range(0.0, 1.0) = 0.10;
uniform float ao_from_hem : hint_range(0.0, 1.0) = 0.35;

varying float hem_w;
varying float fold;


void vertex() {
	hem_w = COLOR.r;
	float phase = COLOR.g * TAU;

	// Push outward in the horizontal plane, scaled by hem weight.
	vec3 radial = vec3(VERTEX.x, 0.0, VERTEX.z);
	float radial_len = length(radial);
	if (radial_len > 0.0001) {
		radial /= radial_len;
	} else {
		radial = vec3(0.0, 0.0, 1.0);
	}

	float t = TIME;
	float ripple = sin(t * flutter_speed + phase + VERTEX.x * 6.0)
		* 0.6 + sin(t * flutter_speed * 1.61 + phase * 2.3) * 0.4;
	float sway = sin(t * idle_speed + phase) * 0.6 + sin(t * idle_speed * 1.43 + phase * 1.7) * 0.4;

	float amount = hem_w * billow;
	VERTEX += radial * (amount * billow_spread + hem_w * sway * idle_sway);
	VERTEX += trail_dir * (trail_amount * trail_reach * hem_w);
	VERTEX.y += amount * billow_lift + ripple * flutter * amount
		+ trail_amount * hem_w * 0.10 + ripple * flutter * trail_amount * hem_w * 1.4;

	// Folds deepen as the robe inflates; used to shade the creases.
	fold = ripple * amount;
}


void fragment() {
	// Weave: two crossed high-frequency bands, so the cloth catches a grain in
	// raking light without ever showing a repeat.
	float weave = sin(UV.x * weave_scale * TAU) * sin(UV.y * weave_scale * TAU * 0.6);
	float shade = 1.0 - weave_depth * 0.5 * (0.5 + 0.5 * weave);

	// Creases read darker; the hem picks up a touch of contact occlusion.
	shade *= 1.0 - clamp(abs(fold) * 2.2, 0.0, 0.35);

	ALBEDO = albedo.rgb * shade;
	ROUGHNESS = clamp(roughness_value - 0.10 * (0.5 + 0.5 * weave), 0.05, 1.0);
	METALLIC = metallic_value;
	AO = mix(1.0, clamp(1.0 - hem_w * 0.35, 0.0, 1.0), ao_from_hem);
	AO_LIGHT_AFFECT = 0.4;

	// Cloth backlighting: white cotton in strong sun glows at the edges.
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.6);
	SPECULAR = 0.18;
	EMISSION = rim_tint.rgb * rim * rim_strength * 0.18;
}
