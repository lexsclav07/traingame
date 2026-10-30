// Rivers and dams: scrolling wave normals, Fresnel sky reflection, depth tint.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

uniform vec3 deep_color : source_color = vec3(0.04, 0.12, 0.13);
uniform vec3 shallow_color : source_color = vec3(0.12, 0.24, 0.22);
uniform sampler2D wave_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float wave_scale = 0.045;
uniform vec2 flow = vec2(0.02, 0.008);
uniform float rain = 0.0;

varying vec3 w_pos;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = w_pos.xz * wave_scale;
	vec3 n1 = texture(wave_nrm, uv + flow * TIME).xyz * 2.0 - 1.0;
	vec3 n2 = texture(wave_nrm, uv * 2.3 - flow.yx * TIME * 1.7).xyz * 2.0 - 1.0;
	vec3 n3 = texture(wave_nrm, uv * 9.0 + vec2(TIME * 0.3, -TIME * 0.21)).xyz * 2.0 - 1.0;
	vec3 tn = normalize(n1 + n2 * 0.6 + n3 * (0.15 + rain * 0.8));
	vec3 nw = normalize(vec3(tn.x * 0.35, 1.0, -tn.y * 0.35));
	float fres = pow(1.0 - clamp(dot(normalize(VIEW), normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz)), 0.0, 1.0), 4.0);
	ALBEDO = mix(deep_color, shallow_color, 0.35);
	METALLIC = 0.0;
	ROUGHNESS = 0.04 + rain * 0.1;
	SPECULAR = 0.6 + fres * 0.4;
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
}
