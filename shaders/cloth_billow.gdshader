shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Wanis's thobe and shemagh.
//
// Everything in here exists to make a lofted tube of triangles read as woven
// cotton in motion. Four things do that work, roughly in order of how much
// they matter at gameplay distance:
//
//   1. the sheen lobe  - cotton is retro-reflective, so it lights up along the
//                        silhouette rather than at the mirror direction. That
//                        edge is how the player tracks the hero against a busy
//                        background, so it is the most important term here.
//   2. folds           - a robe with no creases is a lampshade.
//   3. translucency    - thin white cotton in front of a low sun glows.
//   4. the weave       - only legible close up, but its absence is most of why
//                        procedural cloth looks like vacuum-formed plastic.
//
// Vertex colour carries the authoring data from WanisBuilder: R is hem weight
// (0 at the collar, 1 at the hem), G is a per-ring phase offset so the flutter
// is not in lockstep. Driving `billow` from the controller is what turns the
// robe into a parachute during a glide.
//
// Skinning has already been applied by the time vertex() runs, so displacing
// VERTEX here rides on top of the animated pose.
//
// We take over light() to get a real sheen lobe, which means the diffuse and
// specular BRDFs below are hand-rolled; `diffuse_burley` / `specular_schlick_ggx`
// no longer apply to direct light and are kept only because ambient, GI and the
// vertex-lit fallback still go through the engine's path. Godot multiplies
// DIFFUSE_LIGHT by ALBEDO after light() returns, so nothing written to
// DIFFUSE_LIGHT is pre-tinted by albedo here.
//
// cull_back is load-bearing: this mesh winds front faces clockwise, and with
// culling off the sleeve interiors draw across the chest.

uniform vec4 albedo : source_color = vec4(0.955, 0.945, 0.915, 1.0);
uniform float roughness_value : hint_range(0.0, 1.0) = 0.86;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.0;

group_uniforms Billow;
uniform float billow : hint_range(0.0, 1.0) = 0.0;
uniform float billow_spread = 0.34;
uniform float billow_lift = 0.10;
uniform float flutter = 0.045;
uniform float flutter_speed = 9.0;
// The hem is a free edge with no mass behind it; the chest is pinned by the
// shoulders. One global flutter frequency made the whole robe shiver as a
// single sheet, which is the tell-tale sign of vertex-animated cloth. The hem
// now ripples this many times faster than the collar.
uniform float flutter_gradient : hint_range(1.0, 4.0) = 2.1;
// Ambient motion even when standing still - cloth is never perfectly static.
uniform float idle_sway = 0.010;
uniform float idle_speed = 1.7;
// Direction and amount the cloth streams, in model space. Driven from the
// controller's velocity, so the robe and shemagh lag behind the body.
uniform vec3 trail_dir = vec3(0.0, 0.0, -1.0);
uniform float trail_amount : hint_range(0.0, 1.0) = 0.0;
uniform float trail_reach = 0.30;

group_uniforms Sheen;
// rim_strength / rim_tint keep their artist meaning - "how hot is the edge, and
// what colour" - but they now drive a Charlie sheen lobe instead of a view-space
// fresnel pasted into EMISSION. The old term glowed just as brightly inside an
// unlit cell as it did in the sun; this one is lit by actual lights.
uniform float rim_strength : hint_range(0.0, 2.0) = 0.55;
uniform vec4 rim_tint : source_color = vec4(1.0, 0.92, 0.80, 1.0);
// Width of the sheen lobe. Low is a tight silky edge; high is the broad haze of
// a fuzzy cotton nap. Cotton sits high.
uniform float sheen_roughness : hint_range(0.02, 1.0) = 0.42;
// The lobe is physically dim at artist-friendly rim_strength values, so this
// maps the 0.5-0.9 range the materials already use onto a visible edge. Pull it
// down if the hero starts reading as satin.
uniform float sheen_gain : hint_range(0.0, 6.0) = 2.0;

group_uniforms Weave;
uniform float weave_scale = 110.0;
uniform float weave_depth : hint_range(0.0, 1.0) = 0.10;
// Threads are not square in UV: U wraps one ring (~0.4 m) while V spans the
// whole garment (~1 m), so the weft needs its own multiplier to come out
// roughly square on screen.
uniform float weave_aspect : hint_range(0.1, 4.0) = 0.6;

group_uniforms Folds;
uniform float fold_depth : hint_range(0.0, 1.0) = 0.45;
// Creases per turn around the garment. Rounded to a whole number internally so
// the pattern meets itself across the UV seam instead of leaving a stripe down
// the front of him.
uniform float fold_scale : hint_range(1.0, 24.0) = 7.0;
uniform float ao_from_hem : hint_range(0.0, 1.0) = 0.35;

group_uniforms Translucency;
uniform float translucency : hint_range(0.0, 1.0) = 0.55;
uniform vec4 translucency_tint : source_color = vec4(1.0, 0.80, 0.62, 1.0);
// How much a shadow kills the glow. A backlit robe self-shadows on the camera
// side, which is precisely the side we want glowing, so the shadow term is
// deliberately only partly applied. 1.0 is honest and looks dead.
uniform float translucency_shadow : hint_range(0.0, 1.0) = 0.35;

group_uniforms Dust;
uniform float dust_amount : hint_range(0.0, 1.0) = 0.50;
uniform vec4 dust_color : source_color = vec4(0.46, 0.37, 0.26, 1.0);
// How far up the garment the dirt reaches, as a fraction of its length. Keyed
// to UV.y rather than to a model-space height: UV.y is 0 at the first ring and
// 1 at the last for every surface the loft produces, so this means the same
// thing on the skirt, the sleeves and the shemagh no matter where the rig
// happens to have parented or offset the skeleton.
uniform float dust_reach : hint_range(0.0, 1.0) = 0.32;

varying float hem_w;
varying float fold;
varying float ring_phase;
varying float dust_w;
// Seamless angular basis around the garment, and the same direction carried
// into view space. See the fold code in fragment() for why neither UV.x nor
// the generated TANGENT is usable for anything low-frequency on this mesh.
varying vec2 ring_dir;
varying vec3 around_vs;


void vertex() {
	hem_w = COLOR.r;
	ring_phase = COLOR.g;
	float phase = COLOR.g * TAU;

	// Push outward in the horizontal plane, scaled by hem weight.
	vec3 radial = vec3(VERTEX.x, 0.0, VERTEX.z);
	float radial_len = length(radial);
	if (radial_len > 0.0001) {
		radial /= radial_len;
	} else {
		radial = vec3(0.0, 0.0, 1.0);
	}

	// Ring tangent: the direction that runs *around* the garment. Handed to the
	// fragment stage in both model and view space, because that is the axis the
	// folds tilt the normal along.
	ring_dir = radial.xz;
	around_vs = normalize((MODELVIEW_MATRIX * vec4(-radial.z, 0.0, radial.x, 0.0)).xyz);

	dust_w = smoothstep(1.0 - clamp(dust_reach, 0.001, 1.0), 1.0, UV.y);

	float t = TIME;
	float speed = flutter_speed * mix(1.0, flutter_gradient, hem_w);
	float ripple = sin(t * speed + phase + VERTEX.x * 6.0)
		* 0.6 + sin(t * speed * 1.61 + phase * 2.3) * 0.4;
	float sway = sin(t * idle_speed + phase) * 0.6 + sin(t * idle_speed * 1.43 + phase * 1.7) * 0.4;

	float amount = hem_w * billow;
	VERTEX += radial * (amount * billow_spread + hem_w * sway * idle_sway);
	VERTEX += trail_dir * (trail_amount * trail_reach * hem_w);
	VERTEX.y += amount * billow_lift + ripple * flutter * amount
		+ trail_amount * hem_w * 0.10 + ripple * flutter * trail_amount * hem_w * 1.4;

	// Folds deepen as the robe inflates; used to shade the creases.
	fold = ripple * amount;
}


// Two-tap value noise. Cheap, and the dust only needs it to stop being a clean
// gradient - anything fancier is wasted on a mask this soft.
float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(41.7, 289.3))) * 43758.5453);
}


float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}


void fragment() {
	vec2 uv = UV;

	// This mesh's tangent frame cannot be trusted, so build our own.
	//
	// MeshForge.loft closes each ring with `s2 = (s + 1) % steps`, which means
	// the final quad of every ring interpolates UV.x from 0.95 straight back to
	// 0. That one face is degenerate in U, and because its face tangent points
	// the opposite way to its neighbour's, generate_tangents() averages the two
	// into near-nothing at that vertex column. Using TANGENT/BINORMAL here puts
	// a hard stripe down the side of the robe. `around_vs` comes from the ring
	// geometry instead and has no seam.
	vec3 n0 = normalize(NORMAL);
	vec3 a_raw = around_vs - n0 * dot(n0, around_vs);
	float a_len = length(a_raw);
	vec3 t_around = vec3(0.0);
	vec3 t_down = vec3(0.0);
	if (a_len > 0.001) {
		t_around = a_raw / a_len;
		t_down = cross(n0, t_around);
	}

	// --- Weave --------------------------------------------------------------
	// UV is garment-aligned by construction: U wraps one lofted ring, V runs
	// collar to hem. The threads therefore follow the cloth through any pose,
	// which world-space or triplanar noise never does. High frequency is safe on
	// UV.x despite the seam face, because the AA term below collapses to zero
	// exactly where the period goes degenerate.
	vec2 thread = vec2(uv.x * weave_scale, uv.y * weave_scale * weave_aspect);
	vec2 tw = thread * TAU;

	// Fade the weave out as its period approaches a pixel. Without this the robe
	// boils with moire the moment the camera pulls back to gameplay distance,
	// which is most of the time.
	vec2 px = fwidth(thread);
	float weave_aa = clamp(1.0 - max(px.x, px.y) * 2.0, 0.0, 1.0);

	float warp_s = sin(tw.x);
	float weft_s = sin(tw.y);
	// Plain weave: each thread only sits on top where the crossing thread dips
	// under it. That alternation is what makes this read as woven rather than as
	// a grid of scratches. cos() is the slope of the ridge, so it is the term
	// that belongs in the normal.
	float warp = cos(tw.x) * (0.55 + 0.45 * weft_s);
	float weft = cos(tw.y) * (0.55 - 0.45 * warp_s);
	float weave_amp = weave_depth * weave_aa;
	float weave_h = (warp_s + weft_s) * 0.5;

	vec3 n = n0
		+ t_around * (warp * weave_amp * 0.80)
		+ t_down * (weft * weave_amp * 0.80);

	// --- Folds --------------------------------------------------------------
	// Creases run down the garment, so they vary around the ring and stay
	// continuous along it. The angle is reconstructed from the interpolated ring
	// direction rather than from UV.x, so it survives the seam; rounding the
	// count to a whole number keeps `fs * theta` continuous across atan's branch
	// cut, which a fractional count would tear open down his side.
	float theta = atan(ring_dir.y, ring_dir.x);
	float fs = max(1.0, floor(fold_scale + 0.5));
	// The per-ring phase drifts the creases sideways as they descend, so they
	// wander like fabric instead of reading as flutes on a column.
	float fa = theta * fs + sin(uv.y * 3.4 + ring_phase * TAU) * 0.5;
	float creases = sin(fa) * 0.72 + sin(fa * 2.0 + ring_phase * 4.1) * 0.28;

	// Cloth only creases where it has slack to gather: low on the skirt, and far
	// harder once the robe inflates and the extra circumference has to go
	// somewhere. `fold` carries this frame's vertex ripple, so the creases pulse
	// with the billow instead of sitting there like a decal. The standing term
	// is deliberately generous - a hanging robe is not smooth, and the first
	// pass of this shader read as vinyl because it only creased under billow.
	float compress = clamp(hem_w * (0.75 + 0.90 * billow) + abs(fold) * 2.0, 0.0, 1.6);
	float fold_amt = fold_depth * compress;
	n += t_around * (cos(fa) * fold_amt * 0.90);
	NORMAL = normalize(n);

	// --- Dust ---------------------------------------------------------------
	// A man who has just come out of a prison yard does not have a clean hem.
	// Mottled rather than a clean band: a straight gradient across a robe reads
	// as a shader, not as dirt.
	float grime = vnoise(vec2(uv.x * 9.0, uv.y * 5.0));
	float dust = clamp(dust_w * (0.55 + 0.90 * grime), 0.0, 1.0) * dust_amount;

	// --- Surface ------------------------------------------------------------
	float weave_dark = (0.5 - 0.5 * weave_h) * weave_amp;
	float shade = 1.0 - weave_dark * 0.35;
	// Crease valleys lose ambient before they lose direct light, so the fold
	// darkening goes into albedo and AO, not into the normal alone. On a hero
	// this bright the robe sits near the top of the tonemapper's range, where
	// albedo detail gets crushed - the AO path is what keeps the creases legible.
	float crease_dark = clamp(-creases, 0.0, 1.0) * fold_amt * 0.45;
	shade *= 1.0 - crease_dark;

	vec3 base = albedo.rgb * shade;
	base = mix(base, dust_color.rgb * (0.85 + 0.30 * grime), dust);

	ALBEDO = base;
	// Thread tops catch slightly more light than the valleys; dust is flat matte.
	ROUGHNESS = clamp(roughness_value - 0.10 * (0.5 + 0.5 * weave_h) + dust * 0.14, 0.05, 1.0);
	METALLIC = metallic_value;
	AO = clamp(mix(1.0, 1.0 - hem_w * 0.35, ao_from_hem)
		- crease_dark * 0.60 - weave_dark * 0.25, 0.0, 1.0);
	AO_LIGHT_AFFECT = 0.4;
	SPECULAR = 0.18;
	// Nothing here is self-lit any more. The edge glow now comes from the sheen
	// lobe and the transmission term in light(), both of which need a light.
}


// Charlie sheen distribution (Estevez & Kulla). The cheap velvet lobe: it peaks
// at grazing angles instead of at the mirror direction, which is exactly the
// retro-reflection that makes a cotton robe light up along its silhouette.
float sheen_d(float ndh, float alpha) {
	float inv_a = 1.0 / alpha;
	// Floor on sin^2 keeps pow() finite when the half-vector lines up with the
	// normal and the exponent is large.
	float sin2 = max(1.0 - ndh * ndh, 0.0078125);
	return (2.0 + inv_a) * pow(sin2, inv_a * 0.5) / TAU;
}


// Ashikhmin's visibility term - the cheap partner to Charlie. No real
// shadowing-masking, just enough to keep the lobe bounded at the horizon; the
// NdotL it gets multiplied by caps the whole product at 0.25.
float sheen_v(float ndl, float ndv) {
	return 1.0 / (4.0 * (ndl + ndv - ndl * ndv));
}


void light() {
	vec3 N = normalize(NORMAL);
	vec3 L = normalize(LIGHT);
	vec3 V = normalize(VIEW);
	vec3 H = normalize(L + V);

	float ndl = dot(N, L);
	float cndl = clamp(ndl, 0.0, 1.0);
	float ndv = clamp(dot(N, V), 0.0001, 1.0);
	float ndh = clamp(dot(N, H), 0.0, 1.0);
	float vdh = clamp(dot(V, H), 0.0, 1.0);

	// Thickness proxy: the skirt is one unlined layer of cotton, the shoulders
	// have a body right behind them. Hem weight already encodes that split.
	float thin = mix(0.25, 1.0, hem_w);

	// --- Wrapped diffuse ----------------------------------------------------
	// Thin cotton scatters light a little way past the terminator, which is what
	// softens the shading break down the side of a robe. Divided by (1+w)^2 so
	// widening the wrap does not also brighten him.
	float wrap = translucency * thin * 0.7;
	float diff = clamp((ndl + wrap) / ((1.0 + wrap) * (1.0 + wrap)), 0.0, 1.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * (diff / PI);

	// --- Transmission -------------------------------------------------------
	// Light coming through from behind, strongest when we are nearly looking
	// into the light through the cloth. This gets multiplied by ALBEDO by the
	// engine, so a white thobe glows cream and the red shemagh glows red, which
	// is what actually happens.
	//
	// A backlit robe self-shadows on the camera side - precisely the side we
	// want glowing - so for directional lights the shadow is only partly
	// applied. Point and spot lights keep full attenuation, otherwise the glow
	// would ignore distance falloff entirely.
	float back = clamp(-ndl, 0.0, 1.0);
	float through = pow(clamp(dot(V, -L), 0.0, 1.0), 3.0);
	float trans_att = ATTENUATION;
	if (LIGHT_IS_DIRECTIONAL) {
		trans_att = mix(1.0, ATTENUATION, translucency_shadow);
	}
	DIFFUSE_LIGHT += LIGHT_COLOR * translucency_tint.rgb
		* (translucency * thin * (back * 0.30 + through * 0.85) * trans_att / PI);

	// --- Sheen --------------------------------------------------------------
	// Dust flattens the nap, so a dirty hem should not sheen like a clean
	// shoulder. Uses the smooth vertex gradient rather than the mottled fragment
	// mask - per-light noise is not worth the ALU for a term this soft.
	float sheen_mask = 1.0 - dust_w * dust_amount * 0.75;
	float alpha = clamp(sheen_roughness, 0.02, 1.0);
	float sheen = sheen_d(ndh, alpha) * sheen_v(cndl + 0.0001, ndv) * cndl;
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * rim_tint.rgb
		* (rim_strength * sheen_gain * sheen * sheen_mask);

	// --- Base specular ------------------------------------------------------
	// A weak, very rough GGX underneath. Cotton is not glossy, but with nothing
	// here the cloth goes dead flat whenever the key light is head-on, where the
	// sheen lobe is zero by construction.
	float a = max(ROUGHNESS * ROUGHNESS, 0.002);
	float a2 = a * a;
	float dd = ndh * ndh * (a2 - 1.0) + 1.0;
	float ggx = a2 / (PI * dd * dd);
	float vis = 0.5 / max(mix(2.0 * cndl * ndv, cndl + ndv, a), 0.0001);
	float f0 = SPECULAR_AMOUNT * 2.0 * 0.04;
	float fres = mix(f0, 1.0, pow(1.0 - vdh, 5.0));
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * (ggx * vis * cndl * fres);
}
