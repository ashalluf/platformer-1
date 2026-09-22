shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// The workhorse environment surface.
//
// World-space triplanar so geometry can be built, scaled and rotated in code
// without ever authoring a UV, plus the weathering cues that stop a stylized
// surface reading as plastic: wear on the edges light turns around, dust
// settling on up-facing planes, grime running up from the ground, and multi-
// frequency colour blotching that breaks tiling.
//
// All noise arrives as pre-generated textures. Nothing is evaluated per-pixel
// that could have been evaluated once at load, and everything that only reads
// up close is gated behind `detail_fade`.
//
// Texture budget, per pixel:
//   far  (detail_fade == 0):  3 macro + 2 macro_b + 3 detail  (+1 streak)  = 9
//   near (detail_fade  > 0):  the above + 1 parallax probe + 3 normal      = 13
// Every uniform added since the first version defaults to a shipping value,
// because MaterialLab.surface() does not set them — the default IS the look.

group_uniforms Base;
uniform vec4 base_color : source_color = vec4(0.60, 0.58, 0.54, 1.0);
uniform vec4 variation_color : source_color = vec4(0.45, 0.43, 0.40, 1.0);
uniform float variation_strength : hint_range(0.0, 1.0) = 0.40;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.0;
uniform float roughness_min : hint_range(0.0, 1.0) = 0.55;
uniform float roughness_max : hint_range(0.0, 1.0) = 0.95;
uniform vec4 emission_color : source_color = vec4(0.0);
uniform float emission_strength : hint_range(0.0, 8.0) = 0.0;

group_uniforms Tones;
// The third tone. Alpha is a flag, not an opacity: at 0 the shader derives a
// tone that sits between base and variation, desaturated and lifted a touch, so
// it can never push a preset brighter or darker overall than it already was.
// Set alpha to 1 and the rgb is used verbatim.
uniform vec4 variation_color_b : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform float variation_b_strength : hint_range(0.0, 1.0) = 0.45;
// Frequency multiplier for the second noise lookup. Deliberately irrational-ish
// against 1.0 so the two lookups never beat against each other into a pattern.
uniform float macro_scale_b : hint_range(0.5, 12.0) = 2.9;

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
// One-step offset mapping on the detail lookup, in tile units. Small on
// purpose: a single step cannot resolve a deep heightfield, and anything above
// about 0.05 starts to swim at grazing angles instead of reading as depth.
uniform float parallax_depth : hint_range(0.0, 0.12) = 0.024;

group_uniforms EdgeWear;
// Same alpha-as-flag convention as variation_color_b: 0 means "derive it".
uniform vec4 wear_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform float edge_wear : hint_range(0.0, 1.0) = 0.45;
uniform float edge_wear_lift : hint_range(0.0, 1.0) = 0.30;
uniform float edge_wear_rough : hint_range(0.0, 1.0) = 0.22;
uniform float curvature_gain : hint_range(0.0, 8.0) = 1.6;

group_uniforms Weathering;
uniform vec4 dust_color : source_color = vec4(0.72, 0.64, 0.48, 1.0);
uniform float dust_amount : hint_range(0.0, 1.0) = 0.40;
uniform float dust_sharpness : hint_range(1.0, 12.0) = 3.0;
uniform float dust_cavity : hint_range(0.0, 2.0) = 0.9;
uniform float dust_wash : hint_range(0.0, 1.0) = 0.55;
uniform float dust_color_variation : hint_range(0.0, 1.0) = 0.55;
uniform vec4 grime_color : source_color = vec4(0.16, 0.14, 0.12, 1.0);
uniform float grime_amount : hint_range(0.0, 1.0) = 0.30;
uniform float grime_origin_y = 0.0;
uniform float grime_falloff : hint_range(0.05, 30.0) = 2.2;
uniform float grime_streak : hint_range(0.0, 1.0) = 0.70;
// The run-off lookup is shared by grime and by the dust wash — one sample, two
// effects, and they line up, which is the whole point: water that deposits a
// stain below is the same water that scoured the dust above it.
uniform float streak_scale : hint_range(0.02, 2.0) = 0.16;
uniform float streak_stretch : hint_range(0.01, 1.0) = 0.085;
uniform float ao_strength : hint_range(0.0, 1.0) = 0.45;

group_uniforms Specular;
uniform float roughness_contrast : hint_range(0.5, 4.0) = 1.7;
uniform float roughness_macro : hint_range(0.0, 0.5) = 0.10;
uniform float aniso_polish : hint_range(0.0, 1.0) = 0.40;

varying vec3 world_pos;
varying vec3 world_nrm;
// Object space, because the chamfer detector below needs to know which way the
// mesh was BUILT, not which way it ended up rotated in the level.
varying vec3 obj_nrm;


void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize(mat3(MODEL_MATRIX) * NORMAL);
	obj_nrm = normalize(NORMAL);
}


vec3 tri_weights(vec3 n, float sharp) {
	vec3 w = pow(abs(n), vec3(sharp));
	return w / max(dot(w, vec3(1.0)), 1e-4);
}


vec4 tri_sample(sampler2D tex, vec3 p, vec3 w) {
	return texture(tex, p.zy) * w.x + texture(tex, p.xz) * w.y + texture(tex, p.xy) * w.z;
}


// Two planes instead of three. For a low-contrast tonal term the dropped plane
// is worth less than the fetch it costs, and the seam it leaves lands on the
// 45-degree band — which on this game's geometry is the chamfer, where the edge
// wear is already rewriting the colour anyway.
vec4 bi_sample(sampler2D tex, vec3 p, vec3 w) {
	vec2 uv_a = p.zy;
	vec2 uv_b = p.xz;
	float wa = w.x;
	float wb = w.y;
	if (w.z > min(w.x, w.y)) {
		if (w.x < w.y) {
			uv_a = p.xy;
			wa = w.z;
		} else {
			uv_b = p.xy;
			wb = w.z;
		}
	}
	float inv = 1.0 / max(wa + wb, 1e-4);
	return (texture(tex, uv_a) * wa + texture(tex, uv_b) * wb) * inv;
}


// The single cheapest plane to probe a height from. Only used as the first step
// of offset mapping, where being approximately right is the entire requirement.
vec2 dominant_uv(vec3 p, vec3 w) {
	if (w.x >= w.y && w.x >= w.z) {
		return p.zy;
	}
	if (w.y >= w.z) {
		return p.xz;
	}
	return p.xy;
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

	float dist = length(VERTEX);
	float detail_fade = 1.0 - smoothstep(detail_fade_start, detail_fade_end, dist);

	float macro = tri_sample(macro_noise, pm, w).r;
	// Second, decorrelated frequency. The offset matters as much as the scale:
	// without it the two lookups are the same noise zoomed, and they correlate
	// hard enough that the third tone just thickens the second one.
	float macro_b = bi_sample(macro_noise, pm * macro_scale_b + vec3(37.13, 11.71, 53.37), w).r;

	// --- Curvature ----------------------------------------------------------
	//
	// Two detectors, because this shader covers two kinds of mesh.
	//
	// 1. Smooth meshes (pipes, barrels, anything from a primitive): the world
	//    normal genuinely varies across the triangle, so screen-space
	//    derivatives give real curvature, and dot(dN, dP) / |dP|^2 gives it in
	//    1/metres, which keeps the band the same physical width at any distance.
	// 2. LevelKit's chamfered boxes: every face is FLAT-shaded on purpose, so
	//    the interpolated normal is constant over the triangle and fwidth() is
	//    exactly zero — including at the chamfer, which is the one place we most
	//    want wear. Derivatives cannot see a faceted bevel at all. What can is
	//    the object-space normal: a box face points down an axis, a chamfer
	//    strip sits at 45 degrees and a corner triangle at 54. So treat
	//    "axis-misaligned AND provably flat" as a bevel, and let fwidth's own
	//    zero be the proof of flatness.
	vec3 dn_x = dFdx(world_nrm);
	vec3 dn_y = dFdy(world_nrm);
	vec3 dp_x = dFdx(world_pos);
	vec3 dp_y = dFdy(world_pos);
	float curv = dot(dn_x, dp_x) / max(dot(dp_x, dp_x), 1e-8)
		+ dot(dn_y, dp_y) / max(dot(dp_y, dp_y), 1e-8);
	// Thresholded, not scaled. Curvature is in 1/metres, so a sphere of radius
	// one reads 2.0 and a 12 cm round-over reads ~16 — and only the second of
	// those is an EDGE. A linear ramp would lift a whole barrel by a third and
	// call it wear; this way gentle curvature costs nothing and `curvature_gain`
	// becomes the sensitivity dial for how tight a round has to be to count.
	float cs = curv * curvature_gain;
	float convex = smoothstep(2.0, 12.0, cs);
	float cavity = smoothstep(2.0, 12.0, -cs);

	vec3 nd = fwidth(world_nrm);
	float faceted = 1.0 - smoothstep(0.0005, 0.02, nd.x + nd.y + nd.z);
	vec3 axis = abs(obj_nrm);
	// Cuts off above 0.86 so a 30-degree authored slope stays a slope; a chamfer
	// (0.707) and a corner (0.577) are both fully inside.
	float bevel = (1.0 - smoothstep(0.74, 0.86, max(axis.x, max(axis.y, axis.z)))) * faceted;

	// Broken up by the macro noise rather than by detail, so the wear does not
	// pop in and out as detail fades with distance.
	float edge = clamp(max(bevel, convex), 0.0, 1.0) * edge_wear * (0.50 + 0.70 * macro_b);
	// Wear is a story about contact, and nothing knocks the sky-facing edge of a
	// wall — that edge collects dust instead. Without this the top chamfers, which
	// already tilt straight into the key light, came back reading as white icing
	// piped along the top of every block.
	edge *= mix(1.0, 0.45, clamp(n.y, 0.0, 1.0));
	edge = clamp(edge, 0.0, 1.0);

	// --- Detail, with one-step offset mapping -------------------------------
	vec3 pd_off = pd;
	if (parallax_depth > 0.0001 && detail_fade > 0.001) {
		float h_probe = texture(detail_mask, dominant_uv(pd, w)).r;
		vec3 view_w = normalize(world_pos - INV_VIEW_MATRIX[3].xyz);
		// Left unnormalised on purpose: |v_tan| is sin(view angle), which is the
		// classic offset limiter — zero shift head-on, most shift at grazing,
		// and no division by a near-zero z to blow up on silhouettes.
		vec3 v_tan = view_w - n * dot(view_w, n);
		pd_off = pd + v_tan * ((0.5 - h_probe) * parallax_depth * detail_fade);
	}
	float detail = tri_sample(detail_mask, pd_off, w).r;

	// --- Albedo -------------------------------------------------------------
	//
	// Macro is a gentle tonal drift across a wall, not a pattern. Anything with
	// visible edges here reads as camouflage from three metres away.
	float t1 = smoothstep(0.18, 0.82, macro) * variation_strength;
	vec3 albedo = mix(base_color.rgb, variation_color.rgb, t1);

	vec3 mid_tone = mix(base_color.rgb, variation_color.rgb, 0.6);
	float mid_lum = dot(mid_tone, vec3(0.2126, 0.7152, 0.0722));
	vec3 auto_b = mix(mid_tone, vec3(mid_lum), 0.35) * 1.07;
	vec3 tone_b = mix(auto_b, variation_color_b.rgb, variation_color_b.a);
	// Held back where the second tone already won, so the two reliably carve the
	// wall into three regions instead of stacking into one muddy average.
	float t2 = smoothstep(0.30, 0.78, macro_b) * variation_b_strength * (0.35 + 0.65 * (1.0 - t1));
	albedo = mix(albedo, tone_b, t2);

	albedo *= mix(1.0, 0.88 + 0.24 * detail, detail_fade);

	// --- Run-off ------------------------------------------------------------
	//
	// A vertically stretched lookup: the horizontal axis of whichever wall this
	// is, against a heavily compressed y, so features become vertical runs. One
	// sample, reused by grime (deposits) and dust (scours).
	float streak = 1.0;
	bool wants_streak = grime_amount > 0.0 || (dust_amount > 0.0 && dust_wash > 0.0);
	if (wants_streak) {
		float h_axis = abs(n.x) > abs(n.z) ? world_pos.z : world_pos.x;
		streak = texture(macro_noise,
			vec2(h_axis * streak_scale, world_pos.y * streak_scale * streak_stretch)).r;
	}

	// --- Dust ---------------------------------------------------------------
	//
	// Settles on anything facing the sky, packs into concave corners, and gets
	// scoured off higher up where rain actually reaches and runs.
	float up = clamp(n.y, 0.0, 1.0);
	float dust = pow(up, dust_sharpness) + cavity * dust_cavity * 0.45;
	dust *= dust_amount * (0.55 + 0.70 * detail);
	float wash_height = smoothstep(grime_origin_y + 0.2,
		grime_origin_y + grime_falloff * 2.5, world_pos.y);
	dust *= mix(1.0, 0.35 + 0.95 * streak, dust_wash * wash_height);
	dust = clamp(dust, 0.0, 1.0);
	// Real dust is never one tan: the fine stuff that blows in is paler and
	// greyer than the coarse grit that stays put.
	vec3 dust_tint = mix(dust_color.rgb * 0.86,
		min(dust_color.rgb * 1.10 + vec3(0.02, 0.015, 0.005), vec3(1.0)), macro_b);
	albedo = mix(albedo, mix(dust_color.rgb, dust_tint, dust_color_variation), dust);

	// --- Grime --------------------------------------------------------------
	//
	// Creeps up from the ground line, heaviest where macro noise is dark, and
	// broken into vertical runs so it reads as run-off rather than a gradient.
	float grime = 0.0;
	if (grime_amount > 0.0) {
		float h = exp(-max(world_pos.y - grime_origin_y, 0.0) / grime_falloff);
		grime = h * grime_amount * (0.35 + 0.85 * (1.0 - macro));
		grime *= mix(1.0, 0.25 + 1.05 * streak, grime_streak);
		grime = clamp(grime, 0.0, 1.0);
	}
	albedo = mix(albedo, grime_color.rgb, grime);

	// --- Edge wear ----------------------------------------------------------
	//
	// Applied last: an edge that gets knocked and rubbed is exactly the edge
	// that dirt does not survive on. Lift-toward-white rather than multiply, so
	// a dark asphalt kerb goes convincingly pale without a bright plaster wall
	// clipping to flat white.
	vec3 wear_base = base_color.rgb + (vec3(1.0) - base_color.rgb) * edge_wear_lift;
	float wear_lum = dot(wear_base, vec3(0.2126, 0.7152, 0.0722));
	vec3 wear_auto = mix(wear_base, vec3(wear_lum), 0.35);
	albedo = mix(albedo, mix(wear_auto, wear_color.rgb, wear_color.a), edge);

	ALBEDO = albedo;

	// --- Specular -----------------------------------------------------------
	//
	// The old mix used the detail noise raw, and fbm spends most of its life
	// near 0.5 — so the full roughness_min..max range the presets declare was
	// never actually reached. Push the contrast first, then drift the whole
	// thing with the medium noise so gloss varies in patches, not just grains.
	float rdet = clamp((detail - 0.5) * roughness_contrast + 0.5, 0.0, 1.0);
	float rough = mix(roughness_max, roughness_min, rdet);
	rough += (macro_b - 0.5) * roughness_macro * 2.0;
	rough += dust * 0.22 + grime * 0.12 + edge * edge_wear_rough;

	// Polished/damp horizontal surfaces. Scaled by (1 - roughness_min) so it
	// self-tunes from the preset: painted metal takes it, sand essentially
	// cannot, and anything already buried in dust or grime is excluded.
	float polish = smoothstep(0.72, 0.95, n.y) * aniso_polish
		* (1.0 - clamp(dust + grime, 0.0, 1.0)) * (1.0 - roughness_min);
	rough *= mix(1.0, 0.72, polish);

	ROUGHNESS = clamp(rough, 0.02, 1.0);
	METALLIC = metallic_value * (1.0 - clamp(dust + grime, 0.0, 1.0));

	if (normal_strength > 0.001 && detail_fade > 0.001) {
		vec3 wn = tri_normal(detail_normal, pd_off, w, n, normal_strength * detail_fade);
		if (polish > 0.001) {
			// An anisotropic hint without touching ANISOTROPY: LevelKit meshes
			// carry no tangent array, so ANISOTROPY_FLOW would be steered by
			// whatever TANGENT happens to be, which is nothing. Damping the
			// tilt along world Z instead holds the mirror direction constant
			// down the depth axis, and a highlight that cannot move in Z
			// smears in Z — wet concrete, from a side-on camera.
			vec3 pert = wn - n;
			pert.z *= mix(1.0, 0.22, polish);
			wn = normalize(n + pert);
		}
		NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	}

	float ao = clamp(0.30 + 0.90 * macro, 0.0, 1.0);
	// Corners hold shadow, edges catch light. Cheap, and it costs no samples
	// because the curvature was already paid for by the wear.
	ao *= 1.0 - 0.35 * cavity;
	ao += edge * 0.12;
	AO = mix(1.0, clamp(ao, 0.0, 1.0), ao_strength);
	AO_LIGHT_AFFECT = 0.55;

	if (emission_strength > 0.0) {
		EMISSION = emission_color.rgb * emission_strength;
	}
}
