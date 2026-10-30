// Sky with sun, haze, drifting clouds, stars and moon.
// Colours and cloud cover are set per time of day / weather by EnvironmentBuilder.
shader_type sky;
render_mode use_debanding;

uniform vec3 zenith_color : source_color = vec3(0.18, 0.38, 0.72);
uniform vec3 horizon_color : source_color = vec3(0.68, 0.78, 0.88);
uniform vec3 ground_color : source_color = vec3(0.32, 0.31, 0.28);
uniform vec3 sun_glow_color : source_color = vec3(1.0, 0.85, 0.6);
uniform vec3 cloud_lit : source_color = vec3(1.0, 0.98, 0.95);
uniform vec3 cloud_shadow : source_color = vec3(0.55, 0.6, 0.68);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.45;
uniform float cloud_softness : hint_range(0.01, 1.0) = 0.22;
uniform float cloud_scale = 0.00012;
uniform vec2 wind = vec2(4.0, 1.5);
uniform float sky_energy = 1.0;
uniform float night = 0.0;
uniform float sun_size = 0.9997;
uniform sampler2D cloud_tex : filter_linear_mipmap, repeat_enable;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 sun = normalize(LIGHT0_DIRECTION);
	float h = d.y;
	float mu = dot(d, sun);

	// base gradient: zenith -> horizon, with a thin bright horizon band
	float t = pow(clamp(h, 0.0, 1.0), 0.45);
	vec3 col = mix(horizon_color, zenith_color, t);
	col += horizon_color * 0.25 * exp(-max(h, 0.0) * 18.0);
	// forward (Mie) scattering glow around the sun
	float glow = pow(max(mu, 0.0), 6.0) * 0.35 + pow(max(mu, 0.0), 64.0) * 0.6;
	col += sun_glow_color * glow * (1.0 - night) * clamp(LIGHT0_ENERGY, 0.0, 2.0);
	// sun disk (or moon at night)
	if (LIGHT0_ENABLED && h > -0.02) {
		float disk = smoothstep(sun_size, sun_size + 0.00015, mu);
		if (night > 0.5) {
			col += vec3(0.85, 0.88, 0.95) * disk * 1.2;
		} else {
			col += LIGHT0_COLOR * disk * 30.0;
		}
	}
	// stars
	if (night > 0.0 && h > 0.0) {
		vec3 p = d * 420.0;
		float s = hash(floor(p));
		float star = step(0.9985, s) * (0.5 + 0.5 * sin(TIME * 2.0 + s * 300.0));
		col += vec3(star) * night * smoothstep(0.0, 0.25, h) * 1.4;
	}
	// clouds on a flat layer 2 km up
	if (h > 0.0) {
		vec2 uv = d.xz / (h + 0.06) * 2000.0 * cloud_scale + wind * TIME * cloud_scale;
		vec4 c = texture(cloud_tex, uv);
		vec4 c2 = texture(cloud_tex, uv * 3.7 + vec2(0.37, 0.11));
		float shape = c.r * 0.75 + c2.g * 0.35 - 0.1;
		float dens = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + cloud_softness, shape);
		// thicker clouds have darker bases; edges toward the sun light up
		float thick = smoothstep(1.0 - cloud_cover, 1.0, shape + c2.b * 0.2);
		vec3 ccol = mix(cloud_lit, cloud_shadow, thick * 0.85);
		ccol += sun_glow_color * pow(max(mu, 0.0), 8.0) * (1.0 - thick) * 0.8 * (1.0 - night);
		ccol *= mix(1.0, 0.06, night);
		float fade = smoothstep(0.0, 0.12, h);
		col = mix(col, ccol, dens * fade);
	}
	// below the horizon: hazy ground
	if (h < 0.0) {
		col = mix(horizon_color, ground_color, clamp(-h * 6.0, 0.0, 1.0));
	}
	COLOR = col * sky_energy;
}
