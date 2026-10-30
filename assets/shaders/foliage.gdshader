// Leaves, grass and shrubs: alpha-tested cards with wind sway, flutter,
// per-plant colour variation and light passing through the leaves.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D leaf_tex : source_color, filter_linear_mipmap_anisotropic;
uniform float alpha_cut = 0.45;
uniform vec3 tint : source_color = vec3(1.0);
uniform vec3 tint_var : source_color = vec3(0.85, 0.9, 0.8);
uniform float wind_strength = 0.3;
uniform float sway_height = 0.03;   // bend per metre of height
uniform vec3 translucency : source_color = vec3(0.3, 0.36, 0.18);
uniform float fade_radius = 0.0;    // grass: shrink away towards this distance from the camera
uniform float ao_bottom = 0.0;      // darken the base of grass cards
// grass: pull the colour toward the terrain it grows from (same texture,
// scale and macro tint as the terrain shader) so tufts sit in the ground
uniform float ground_blend = 0.0;
uniform sampler2D ground_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float ground_scale = 0.22;
uniform sampler2D macro_tex : filter_linear_mipmap, repeat_enable;
uniform float macro_scale = 0.0009;
uniform vec3 tint_dry : source_color = vec3(1.0);
uniform vec3 tint_lush : source_color = vec3(0.82, 0.95, 0.72);

varying float v_var;
varying float v_ao;
varying vec2 v_xz;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	v_xz = origin.xz;
	v_var = fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453);
	float h = max(VERTEX.y, 0.0);
	float ph = dot(origin, vec3(0.071, 0.0, 0.053));
	float gust = 0.6 + 0.4 * sin(TIME * 0.37 + origin.x * 0.01);
	float sway = (sin(TIME * 1.4 + ph) * 0.65 + sin(TIME * 3.1 + ph * 2.3) * 0.35) * gust;
	VERTEX.x += sway * wind_strength * h * sway_height * h;
	VERTEX.z += cos(TIME * 1.2 + ph * 1.3) * wind_strength * h * sway_height * h * 0.6;
	VERTEX += NORMAL * sin(TIME * 7.0 + VERTEX.x * 3.0 + VERTEX.z * 2.0 + ph) * 0.025 * wind_strength * min(h, 3.0);
	if (fade_radius > 0.0) {
		float dist = length((MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz - (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz);
		VERTEX *= smoothstep(fade_radius, fade_radius * 0.7, dist);
	}
	v_ao = UV.y;
}

void fragment() {
	vec4 c = texture(leaf_tex, UV);
	ALBEDO = c.rgb * mix(tint_var, vec3(1.0), v_var) * tint;
	if (ground_blend > 0.0) {
		vec3 macro = texture(macro_tex, v_xz * macro_scale).rgb;
		vec3 macro2 = texture(macro_tex, v_xz * macro_scale * 7.3 + vec2(0.5)).rgb;
		vec3 g = texture(ground_tex, v_xz * ground_scale).rgb;
		g *= mix(tint_dry, tint_lush, smoothstep(0.35, 0.75, macro.r));
		g *= 0.72 + 0.26 * macro2.g;
		float tipness = 1.0 - smoothstep(0.0, 1.0, v_ao);
		// keep the blades' own variation but centre it on the ground colour
		vec3 own = ALBEDO / max(dot(ALBEDO, vec3(0.333)), 0.02);
		vec3 matched = own * dot(g, vec3(0.333)) * mix(1.0, 1.25, tipness);
		ALBEDO = mix(ALBEDO, mix(g, matched, 0.55), ground_blend);
	}
	if (ao_bottom > 0.0) {
		ALBEDO *= mix(1.0, 1.0 - ao_bottom, smoothstep(0.4, 1.0, v_ao));
	}
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ROUGHNESS = 0.82;
	SPECULAR = 0.2;
	BACKLIGHT = translucency;
}
