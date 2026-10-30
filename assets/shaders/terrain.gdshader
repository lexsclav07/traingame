// Terrain: texture splatting from vertex weights.
//  COLOR.r = main ground (NSW: grass   / ECML: farmland, picked per field)
//  COLOR.g = rock (cuttings, steep slopes) - triplanar so strata stay horizontal
//  COLOR.b = secondary (NSW: leaf litter, bare earth / ECML: rough railway grass)
//  COLOR.a = cess gravel beside the ballast
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D grass_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D field_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D field_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D plough_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D plough_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D macro_tex : filter_linear_mipmap, repeat_enable;

uniform float grass_scale = 0.22;
uniform float rock_scale = 0.07;
uniform float soil_scale = 0.2;
uniform float gravel_scale = 0.45;
uniform float field_scale = 0.09;
uniform float macro_scale = 0.0009;
uniform float use_fields = 0.0;
uniform vec2 field_size = vec2(260.0, 190.0);
uniform float field_angle = 0.4;
uniform vec3 grass_tint_dry : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 grass_tint_lush : source_color = vec3(0.82, 0.95, 0.72);
uniform float wetness = 0.0;
uniform float normal_strength = 1.0;

varying vec3 w_pos;
varying vec3 w_nrm;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

mat2 rot(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat2(vec2(c, s), vec2(-s, c));
}

// two differently scaled & rotated lookups to hide tiling
vec4 tex2(sampler2D t, vec2 uv) {
	vec4 a = texture(t, uv);
	vec4 b = texture(t, rot(0.9) * uv * 0.31 + vec2(0.17, 0.53));
	return mix(a, b, 0.38);
}

vec3 nrm(vec4 s) {
	return s.xyz * 2.0 - 1.0;
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec4 w = max(COLOR, vec4(0.0));
	float wsum = w.r + w.g + w.b + w.a + 1e-4;
	w /= wsum;
	vec2 uv = w_pos.xz;
	vec3 macro = texture(macro_tex, uv * macro_scale).rgb;
	vec3 macro2 = texture(macro_tex, uv * macro_scale * 7.3 + vec2(0.5)).rgb;

	// ---- main ground
	vec3 g_alb;
	vec3 g_n;
	float g_rough = 0.95;
	if (use_fields > 0.5) {
		vec2 fp = rot(field_angle) * uv;
		vec2 cell = floor(fp / field_size);
		vec2 local = fract(fp / field_size) * field_size;
		float edge = min(min(local.x, field_size.x - local.x), min(local.y, field_size.y - local.y));
		float kind = hash12(cell + 17.0);
		vec2 fuv = rot(floor(hash12(cell + 3.0) * 2.0) * 1.5708) * fp * field_scale;
		vec3 pasture = tex2(grass_alb, uv * grass_scale).rgb * mix(vec3(0.9, 1.0, 0.85), vec3(1.05, 1.0, 0.9), hash12(cell + 9.0));
		vec3 pasture_n = nrm(tex2(grass_nrm, uv * grass_scale));
		if (kind < 0.5) {
			g_alb = pasture;
			g_n = pasture_n;
		} else if (kind < 0.78) {
			g_alb = texture(field_alb, fuv).rgb * mix(0.9, 1.08, hash12(cell + 5.0));
			g_n = nrm(texture(field_nrm, fuv));
		} else {
			g_alb = texture(plough_alb, fuv).rgb;
			g_n = nrm(texture(plough_nrm, fuv));
		}
		// grass headland round every field (hedges grow on the boundary)
		float headland = 1.0 - smoothstep(3.0, 7.0, edge);
		g_alb = mix(g_alb, pasture * 0.8, headland);
		g_n = mix(g_n, pasture_n, headland);
	} else {
		g_alb = tex2(grass_alb, uv * grass_scale).rgb;
		g_alb *= mix(grass_tint_dry, grass_tint_lush, smoothstep(0.35, 0.75, macro.r));
		g_n = nrm(tex2(grass_nrm, uv * grass_scale));
	}
	g_alb *= 0.72 + 0.26 * macro2.g;

	// ---- secondary: litter / rough grass
	vec3 s_alb = tex2(soil_alb, uv * soil_scale).rgb * (0.85 + 0.3 * macro.b);
	vec3 s_n = nrm(tex2(soil_nrm, uv * soil_scale));

	// ---- gravel cess
	vec3 c_alb = texture(gravel_alb, uv * gravel_scale).rgb * 0.66 * mix(vec3(1.0), vec3(1.06, 0.98, 0.88), use_fields < 0.5 ? 1.0 : 0.0);
	vec3 c_n = nrm(texture(gravel_nrm, uv * gravel_scale));

	// ---- rock, triplanar
	vec3 bw = pow(abs(w_nrm), vec3(4.0));
	bw /= (bw.x + bw.y + bw.z);
	vec3 rx = texture(rock_alb, w_pos.zy * rock_scale).rgb;
	vec3 ry = texture(rock_alb, w_pos.xz * rock_scale).rgb;
	vec3 rz = texture(rock_alb, w_pos.xy * rock_scale).rgb;
	vec3 r_alb = (rx * bw.x + ry * bw.y + rz * bw.z) * (0.85 + 0.3 * macro2.r);
	vec3 nx = nrm(texture(rock_nrm, w_pos.zy * rock_scale));
	vec3 ny = nrm(texture(rock_nrm, w_pos.xz * rock_scale));
	vec3 nz = nrm(texture(rock_nrm, w_pos.xy * rock_scale));
	vec3 rnx = vec3(nx.xy + w_nrm.zy, w_nrm.x);
	vec3 rny = vec3(ny.xy + w_nrm.xz, w_nrm.y);
	vec3 rnz = vec3(nz.xy + w_nrm.xy, w_nrm.z);
	vec3 rock_world_n = normalize(rnx.zyx * bw.x + rny.xzy * bw.y + rnz.xyz * bw.z);

	// ---- blend
	vec3 alb = g_alb * w.r + r_alb * w.g + s_alb * w.b + c_alb * w.a;
	vec3 tn = g_n * w.r + s_n * w.b + c_n * w.a;           // top-projected tangent normals
	float top_w = w.r + w.b + w.a;
	vec3 top_world = normalize(w_nrm + vec3(tn.x, 0.0, -tn.y) * normal_strength);
	vec3 n_world = normalize(mix(rock_world_n, top_world, top_w / max(top_w + w.g, 1e-4)));

	float rough = 0.96 * w.r + 0.82 * w.g + 0.94 * w.b + 0.9 * w.a;
	// rain: darker, glossier ground
	alb *= mix(1.0, 0.62, wetness);
	rough = mix(rough, 0.35, wetness * 0.8);
	ALBEDO = alb;
	ROUGHNESS = rough;
	SPECULAR = 0.35;
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
}
