shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley,
	specular_schlick_ggx;

// Open water, authored for a side-on camera that is almost level with it.
//
// This is the awkward case. Every water shader tutorial is written for a
// camera looking DOWN at a pool, where the swell silhouette and the depth
// gradient do all the work. Ours looks along the surface from four to fourteen
// units above it at a body of water a hundred to three hundred units away, so
// the entire sea compresses into a band a few percent of screen height tall.
// In that view three things carry the read and nothing else does:
//
//   1. The sun glitter path, because it is the only high-contrast element.
//   2. Fresnel, which at two degrees of grazing is essentially 1.0 — a distant
//      sea is a mirror of the sky, not a blue floor. Getting this wrong is the
//      single loudest tell in a CG seascape.
//   3. Aerial haze, because the band has to sit INTO the horizon, not in
//      front of it.
//
// The swell is still here and still physical, but its job is to break the
// horizon line and to feed foam, not to be looked at. Amplitudes are authored
// against the grazing view: 0.4 units at 150 units away is about five pixels
// of vertical wander at 1080p, which is exactly the amount that reads as a
// living sea rather than as a mountain range or as a ruler.
//
// `ice_amount` cross-fades the whole thing to a frozen shelf, so the Gulf of
// Sidra and the bonus-level ice sea are one shader with one set of presets.

group_uniforms Swell;
// One knob for "how big is the sea today". The three summed waves fan around
// this direction at fixed ratios rather than being tuned individually —
// twelve wave uniforms is a spectrum editor, not an art direction.
uniform vec2 wind_dir = vec2(0.92, 0.39);
uniform float wave_length = 42.0;
uniform float wave_amplitude : hint_range(0.0, 3.0) = 0.38;
// Gerstner Q, expressed as total horizontal pinch across all three waves.
// Above ~0.9 the crests self-intersect and the sea turns inside out.
uniform float wave_steepness : hint_range(0.0, 0.9) = 0.38;
uniform float wave_spread : hint_range(0.0, 1.6) = 0.55;
uniform float wave_speed : hint_range(0.0, 4.0) = 1.0;

group_uniforms Ripple;
uniform sampler2D ripple_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float ripple_scale = 0.11;
uniform float ripple_strength : hint_range(0.0, 2.0) = 0.65;
uniform float ripple_speed = 0.06;
// Ripple detail must be gone by the far edge or the sea aliases into a field
// of fizzing white dots. The energy it loses comes back as roughness below.
uniform float ripple_fade_start = 45.0;
uniform float ripple_fade_end = 280.0;

group_uniforms Body;
uniform vec4 shallow_color : source_color = vec4(0.310, 0.765, 0.753, 1.0);
uniform vec4 deep_color : source_color = vec4(0.106, 0.310, 0.447, 1.0);
// What the surface reflects at grazing incidence. Not the zenith sky — the
// two or three degrees of sky immediately above the horizon.
uniform vec4 sky_color : source_color = vec4(0.62, 0.68, 0.78, 1.0);
uniform float fresnel_power : hint_range(0.5, 8.0) = 4.0;
uniform float fresnel_strength : hint_range(0.0, 1.0) = 0.92;
// The sky reflection is NOT albedo — see the note in fragment(). This scales
// it, and it is the brightness of the whole sea band at distance.
uniform float sky_reflect : hint_range(0.0, 4.0) = 1.0;
uniform float roughness_near : hint_range(0.0, 1.0) = 0.06;
uniform float roughness_far : hint_range(0.0, 1.0) = 0.30;
// Godot maps this to F0 = 0.08 * specular, so 0.25 is water's real 0.02 at
// normal incidence. The engine's own GGX lobe is deliberately kept quiet: the
// grazing Fresnel and the glitter path above are modelled explicitly, and a
// second uncontrolled highlight from a 3.1-energy key at roughness 0.05 is a
// blown-out aliased mess, not a bonus.
uniform float specular_value : hint_range(0.0, 1.0) = 0.25;

group_uniforms Shore;
// Depth is authored, not sampled from the depth buffer: the shelf is a
// coastline feature we want control over, and the Gulf of Sidra genuinely
// does fall off a shelf rather than fade. Positive `shelf_distance` means the
// water deepens toward -Z (away from the camera); negative flips it.
uniform float shore_z = -100.0;
uniform float shelf_distance = 55.0;
uniform float shelf_hardness : hint_range(0.0, 1.0) = 0.62;
uniform float surf_width = 7.0;
uniform float surf_amount : hint_range(0.0, 2.0) = 0.75;
// 1.0 turns this mesh into the surf line itself: foam only, alpha everywhere
// else, so a thin strip can be laid over the shoreward edge of the sea.
uniform float strip_amount : hint_range(0.0, 1.0) = 0.0;

group_uniforms Foam;
uniform sampler2D foam_noise : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 foam_color : source_color = vec4(0.92, 0.94, 0.93, 1.0);
uniform float foam_scale = 0.16;
uniform float foam_amount : hint_range(0.0, 2.0) = 1.0;
// Crest steepness at which a wave starts to break. Compare against
// `wave_steepness` — foam appears on the top fraction of the swell.
uniform float foam_threshold : hint_range(0.0, 0.9) = 0.20;
uniform float foam_softness : hint_range(0.01, 0.6) = 0.16;

group_uniforms Sun;
// World-space direction TO the sun. WaterKit.sun_from_angles() derives this
// from the same Vector2 the LightingRig uses so the two cannot drift apart.
uniform vec3 sun_direction = vec3(0.50, 0.06, -0.86);
uniform vec4 sun_color : source_color = vec4(1.0, 0.565, 0.251, 1.0);
uniform float glitter_energy : hint_range(0.0, 20.0) = 4.5;
// The broad lobe draws the path; the tight lobe is the individual facets.
uniform float glitter_spread : hint_range(2.0, 400.0) = 48.0;
uniform float glitter_sharpness : hint_range(50.0, 4000.0) = 900.0;
uniform float sparkle_density = 2.2;
uniform float sparkle_threshold : hint_range(0.5, 0.999) = 0.972;

group_uniforms Haze;
uniform vec4 haze_color : source_color = vec4(0.835, 0.804, 0.741, 1.0);
uniform float haze_begin = 90.0;
uniform float haze_end = 420.0;
uniform float haze_strength : hint_range(0.0, 1.0) = 0.55;
// Brightness of the haze itself. Like the sky reflection, scattered light is
// not diffuse — see fragment().
uniform float haze_lift : hint_range(0.0, 3.0) = 0.60;

group_uniforms Ice;
uniform float ice_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 ice_color : source_color = vec4(0.82, 0.90, 0.97, 1.0);
uniform vec4 crack_color : source_color = vec4(0.62, 0.82, 0.95, 1.0);
uniform float crack_scale = 0.28;
uniform float crack_power : hint_range(1.0, 60.0) = 14.0;
uniform float crack_amount : hint_range(0.0, 1.0) = 0.55;
// How far below the surface the cracks sit. Drives the view-dependent
// parallax that makes them read as refracted rather than painted on.
uniform float crack_depth = 0.45;
uniform float frost_amount : hint_range(0.0, 1.0) = 0.30;

varying vec3 world_pos;
varying vec3 wave_nrm;
varying float wave_fold;


// One Gerstner contribution, accumulating displacement, both surface tangents
// and the folding term in one pass. The derivatives are analytic because a
// sampled normal on geometry this sparse would just be the flat plane back.
void gerstner(vec2 d, float wavelen, float amp, float share, vec2 p, float t,
		inout vec3 disp, inout vec3 tan_x, inout vec3 tan_z, inout float fold) {
	float k = TAU / max(wavelen, 0.01);
	// Deep-water dispersion. The long swell genuinely outruns the chop, and
	// that difference in speed is the whole reason a summed sea never looks
	// like a tiling pattern.
	float w = sqrt(9.81 * k);
	float f = k * dot(d, p) - w * t;
	float sf = sin(f);
	float cf = cos(f);

	// `share` is Q*A*k: the per-wave slice of total steepness. Parameterising
	// it this way means changing amplitude or wavelength can never push the
	// wave past self-intersection.
	float qa = share / k;
	float ak = amp * k;

	disp += vec3(qa * d.x * cf, amp * sf, qa * d.y * cf);
	tan_x += vec3(-share * d.x * d.x * sf, ak * d.x * cf, -share * d.x * d.y * sf);
	tan_z += vec3(-share * d.x * d.y * sf, ak * d.y * cf, -share * d.y * d.y * sf);
	fold += share * sf;
}


vec2 rot2(vec2 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(v.x * c - v.y * s, v.x * s + v.y * c);
}


float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}


// A sparse field of round, independently winking points.
//
// The obvious version — threshold a hash of floor(pos) and light the whole
// cell — is what the first pass of this shader did, and at grazing incidence
// a world-space square cell projects into a hard-edged horizontal rectangle.
// The sea came back looking like it had ticker tape on it. A jittered point
// with a smooth radial falloff fixes it, and the cells are compressed in Z so
// that after the grazing projection they land roughly square on screen.
float glint_field(vec2 p, float thresh, float t) {
	vec2 cell = floor(p);
	float s = hash13(vec3(cell, 0.0));
	if (s < thresh) {
		return 0.0;
	}
	vec2 jit = vec2(hash13(vec3(cell, 1.7)), hash13(vec3(cell, 5.1)));
	float k = (s - thresh) / max(1.0 - thresh, 1e-4);
	// Each glint carries its own phase, so the field twinkles instead of
	// sitting still or marching across the water as one block.
	k *= 0.45 + 0.55 * sin(t * 2.6 + s * 63.0);
	return smoothstep(0.42, 0.0, length(p - cell - jit)) * max(k, 0.0);
}


void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	// Ice stops the clock rather than flattening the sea: a frozen shelf keeps
	// the shape of the swell that was in it when it froze, which is what makes
	// it read as sea ice and not as a sheet of glass.
	float t = TIME * wave_speed * (1.0 - ice_amount);
	float amp = wave_amplitude * mix(1.0, 0.5, ice_amount);

	// A wind_dir left at (0,0) would NaN every vertex in the mesh.
	vec2 d0 = normalize(wind_dir + vec2(1e-5, 1e-5));
	float share = wave_steepness / 3.0;

	vec3 disp = vec3(0.0);
	vec3 tan_x = vec3(1.0, 0.0, 0.0);
	vec3 tan_z = vec3(0.0, 0.0, 1.0);
	float fold = 0.0;

	gerstner(d0, wave_length, amp, share, wp.xz, t, disp, tan_x, tan_z, fold);
	gerstner(rot2(d0, wave_spread), wave_length * 0.56, amp * 0.54, share,
		wp.xz, t, disp, tan_x, tan_z, fold);
	gerstner(rot2(d0, -wave_spread * 1.7), wave_length * 0.27, amp * 0.26, share,
		wp.xz, t, disp, tan_x, tan_z, fold);

	// Sea meshes are built axis-aligned and unscaled by WaterKit, so model
	// space and world space differ only by a translation and the world-space
	// displacement can go straight onto VERTEX.
	VERTEX += disp;
	world_pos = wp + disp;
	wave_nrm = normalize(cross(tan_z, tan_x));
	wave_fold = fold;
}


void fragment() {
	vec3 to_cam = CAMERA_POSITION_WORLD - world_pos;
	float dist = length(to_cam);
	vec3 view_w = to_cam / max(dist, 1e-4);
	vec2 wind_n = normalize(wind_dir + vec2(1e-5, 1e-5));

	float far_t = smoothstep(ripple_fade_start, ripple_fade_end, dist);

	// --- Normal -------------------------------------------------------------
	// Two ripple octaves drifting against each other at incommensurate scales.
	// One layer at one scale tiles visibly across a 400-unit sea; two never do.
	float rip = ripple_strength * (1.0 - far_t) * (1.0 - ice_amount * 0.8);
	vec2 rp = world_pos.xz * ripple_scale;
	vec2 drift = wind_n * (TIME * ripple_speed * (1.0 - ice_amount));
	vec3 r1 = texture(ripple_normal, rp + drift).xyz * 2.0 - 1.0;
	vec3 r2 = texture(ripple_normal, rp * 2.7 - drift * 1.6 + vec2(0.37, 0.61)).xyz * 2.0 - 1.0;
	// The plane is horizontal, so tangent space is trivially (X, Y up, Z): the
	// map's X/Y perturb world X/Z directly.
	vec3 wn = normalize(wave_nrm);
	vec3 n = normalize(wn + vec3(r1.x + r2.x * 0.6, 0.0, r1.y + r2.y * 0.6) * rip);

	// --- Depth colour -------------------------------------------------------
	float sd = shelf_distance >= 0.0 ? max(shelf_distance, 0.001) : min(shelf_distance, -0.001);
	float depth_t = clamp((shore_z - world_pos.z) / sd, 0.0, 1.0);
	// The shelf is a hard line, per the art direction — turquoise to indigo,
	// not a gradient. Jittered so it is a coastline and not a ruler.
	float jitter = (texture(foam_noise, world_pos.xz * 0.012).r - 0.5) * 0.20;
	float half_w = mix(0.5, 0.035, shelf_hardness);
	float shelf = smoothstep(0.5 - half_w, 0.5 + half_w, depth_t + jitter);
	vec3 albedo = mix(shallow_color.rgb, deep_color.rgb, shelf);

	// --- Fresnel ------------------------------------------------------------
	// Nearly all of this surface is seen within a couple of degrees of
	// grazing, where Fresnel reflectance is essentially 1.0 — the sea is a
	// mirror of the sky, not a blue floor.
	//
	// The reflection is deliberately NOT written into ALBEDO. At a sun
	// elevation of three degrees the surface normal gives N.L = 0.06, so
	// anything in ALBEDO receives six percent of the key and the whole band
	// renders as a dark stripe under a bright sky — which is exactly how the
	// first version of this looked. A reflection is specular: it does not care
	// what angle the sun makes with the water. So it goes out as emission,
	// and the diffuse body is attenuated by the same factor to conserve energy.
	float ndv = clamp(dot(n, view_w), 0.0, 1.0);
	float fres = clamp(fresnel_strength * pow(1.0 - ndv, fresnel_power), 0.0, 1.0);
	albedo *= 1.0 - fres * 0.85;

	// --- Foam ---------------------------------------------------------------
	float crest = smoothstep(foam_threshold, foam_threshold + foam_softness, wave_fold);
	float f1 = texture(foam_noise, world_pos.xz * foam_scale + drift * 0.5).r;
	float f2 = texture(foam_noise, world_pos.xz * foam_scale * 3.1 - drift).r;
	// Lace, not coverage: foam that reads as a solid white cap is polystyrene.
	float lace = smoothstep(0.34, 0.78, f1 * 0.62 + f2 * 0.48);
	float foam = crest * lace * foam_amount;

	// Shore break. Surging on a long period and along X so the waterline
	// breathes instead of sitting there as a painted stripe.
	float band = 1.0 - clamp(abs(shore_z - world_pos.z) / max(surf_width, 0.001), 0.0, 1.0);
	float surge = 0.58 + 0.42 * sin(TIME * 0.55 + world_pos.x * 0.055);
	float wash = pow(band, 1.5) * surge;
	float surf = wash * surf_amount * (0.45 + 0.55 * lace);
	foam = clamp(foam + surf + strip_amount * wash * 0.9, 0.0, 1.0);
	foam *= 1.0 - ice_amount;

	albedo = mix(albedo, foam_color.rgb, foam);

	float rough = mix(roughness_near, roughness_far, far_t);
	rough = mix(rough, 0.74, foam);

	// --- Sun glitter --------------------------------------------------------
	// Three terms, and which normal each one uses is the whole trick.
	//
	// The PATH is evaluated against the swell normal only. That normal is a
	// varying interpolated across five-unit triangles, so it cannot alias, and
	// the result is a smooth column running from the mirror point out to the
	// horizon along the sun's azimuth — the shape you actually want.
	//
	// The FACETS are evaluated against the rippled normal and are pure
	// high-frequency noise, so they are gated by a much wider lobe off the same
	// swell normal and faded out with distance. Glints scattered across the
	// whole sea are the fizzing-dots failure; glints only inside the path are
	// sea glitter.
	vec3 l = normalize(sun_direction);
	vec3 h = normalize(l + view_w);
	float nh_swell = clamp(dot(wn, h), 0.0, 1.0);
	float nh = clamp(dot(n, h), 0.0, 1.0);

	float path = pow(nh_swell, glitter_spread);
	float gate = pow(nh_swell, glitter_spread * 0.10);
	float near_t = 1.0 - far_t;
	float facet = pow(nh, glitter_sharpness) * near_t;

	// Z is compressed so the cells survive the grazing projection as dots.
	vec2 gp = vec2(world_pos.x, world_pos.z * 0.30) * sparkle_density + view_w.xz * 2.0;
	float wink = glint_field(gp, sparkle_threshold, TIME);

	float glitter = path * 0.85 + (facet + wink * 3.0 * near_t) * gate;
	glitter *= 1.0 - foam * 0.75;
	vec3 emission = sun_color.rgb * glitter * glitter_energy;

	// The sky reflection, warming as it approaches the sun's azimuth. A real
	// dawn sea is cool blue-grey everywhere except along the path, and one
	// flat reflection colour is what makes a CG one read as bronze sheet
	// metal. `gate` is already that azimuthal proximity, so it costs nothing.
	vec3 refl = mix(sky_color.rgb, sky_color.rgb * 0.35 + sun_color.rgb * 0.75, gate);
	emission += refl * fres * sky_reflect * (1.0 - foam * 0.85);

	// --- Ice ----------------------------------------------------------------
	if (ice_amount > 0.001) {
		// Cracks live under the surface, so the noise is sampled through a
		// view-dependent parallax offset: the deeper they sit, the more they
		// slide as the camera moves, and that slide is the whole refraction
		// read for a fraction of the cost of a refraction pass.
		vec2 par = (view_w.xz / max(abs(view_w.y), 0.20)) * crack_depth;
		float cn = texture(foam_noise, (world_pos.xz + par) * crack_scale).r;
		float ridge = clamp(1.0 - abs(cn * 2.0 - 1.0), 0.0, 1.0);
		float crack = pow(ridge, crack_power) * crack_amount;

		// A second, much finer pass of the same field: hairline fracture
		// networks inside the big plates.
		float cn2 = texture(foam_noise, (world_pos.xz + par * 0.4) * crack_scale * 4.3).r;
		crack += pow(clamp(1.0 - abs(cn2 * 2.0 - 1.0), 0.0, 1.0), crack_power * 1.8)
			* crack_amount * 0.5;
		crack = clamp(crack, 0.0, 1.0);

		float frost = frost_amount * (0.45 + 0.55 * f1);
		vec3 sheet = mix(mix(deep_color.rgb, ice_color.rgb, 0.45 + 0.55 * fres),
			ice_color.rgb, frost);
		sheet = mix(sheet, crack_color.rgb, crack);
		// Same energy conservation as open water, but gentler: ice scatters
		// internally, so it keeps more of its diffuse body under the mirror.
		sheet *= 1.0 - fres * 0.55;

		albedo = mix(albedo, sheet, ice_amount);
		rough = mix(rough, mix(0.05, 0.62, frost), ice_amount);
		// Cracks scatter light back out of the sheet. Small — they are a
		// highlight, not a neon sign.
		emission += crack_color.rgb * crack * 0.30 * ice_amount;
	}

	// --- Aerial perspective -------------------------------------------------
	// Without this the sea is a hard-edged band pasted in front of the horizon.
	// Depth fog alone is far too thin at these densities to do the job.
	//
	// And for the same reason as the sky reflection: haze is scattered light,
	// so putting it only into ALBEDO on a surface that receives six percent of
	// the key makes the far edge of the sea go DARKER with distance. Aerial
	// perspective that darkens is not aerial perspective. The emission is
	// mixed toward the haze rather than added to it, so the glitter path is
	// veiled by distance at the same rate the band is lifted.
	float haze = haze_strength * smoothstep(haze_begin, haze_end, dist);
	ALBEDO = mix(albedo, haze_color.rgb, haze);
	EMISSION = mix(emission, haze_color.rgb * haze_lift, haze);

	ROUGHNESS = clamp(rough, 0.02, 1.0);
	METALLIC = 0.0;
	SPECULAR = specular_value;
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	// Open sea is opaque. The surf strip is alpha everywhere it is not foam,
	// so it can be laid over the sea and over the sand without a seam.
	float strip_alpha = clamp(foam + wash * 0.30, 0.0, 1.0) * (1.0 - ice_amount);
	ALPHA = mix(1.0, strip_alpha, strip_amount);
}
