// Cab windscreen: rain drops that refract the view, condensation on the inside
// that the demister clears from the bottom up, and washer fluid. The wiper
// blades clear drops and fluid where they sweep: for every point the shader
// works out how long ago a blade last passed it.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D drops_tex : filter_linear_mipmap, repeat_enable;
uniform vec2 glass_size = vec2(2.72, 1.94);      // metres (u across, v down)
uniform vec4 tint : source_color = vec4(0.75, 0.8, 0.82, 0.05);
uniform float rain = 0.0;                        // 0..1
uniform float mist = 0.0;                        // 0..1 condensation
uniform float wash = 0.0;                        // washer fluid strength 0..1
uniform float wash_age = 10000.0;                // s since the washer sprayed
uniform float wipe_phase = 0.0;                  // wiper cycles, parked at whole numbers
uniform float wipe_rate = 0.0;                   // cycles per second (0 = stopped)
uniform float wipe_idle = 10000.0;               // s since the wipers stopped
// pivot (metres from the left / bottom edge), arm length, enabled
uniform vec4 wiper_a = vec4(0.81, 0.075, 0.95, 0.0);
uniform vec4 wiper_b = vec4(1.81, 0.075, 0.95, 0.0);
uniform float sweep_start = 176.0;               // blade angle when parked (deg, 0 = across to the right)
uniform float sweep_deg = 120.0;
uniform float drop_scale = 1.4;                  // drop texture repeats per metre
uniform float speed = 0.0;                       // train speed (m/s): drops creep up the glass

float since_wipe(vec2 p, vec4 w) {
	if (w.w < 0.5) {
		return 10000.0;
	}
	vec2 d = p - w.xy;
	float r = length(d);
	if (r > w.z || r < 0.07) {
		return 10000.0;
	}
	float th = degrees(atan(d.y, d.x));
	float a = (sweep_start - th) / sweep_deg;    // 0..1 along the sweep
	if (a < 0.0 || a > 1.0) {
		return 10000.0;
	}
	// blade angle goes 0 -> 1 -> 0 over a cycle as 0.5 - 0.5 cos(2 pi phase)
	float ph1 = acos(clamp(1.0 - 2.0 * a, -1.0, 1.0)) / 6.2831853;
	float cur = fract(wipe_phase);
	float dph = min(fract(cur - ph1 + 1.0), fract(cur - (1.0 - ph1) + 1.0));
	if (wipe_rate > 0.0) {
		return dph / wipe_rate;
	}
	return wipe_idle + dph / 0.9;
}

void fragment() {
	vec2 p = vec2(UV.x * glass_size.x, (1.0 - UV.y) * glass_size.y);
	float t = min(since_wipe(p, wiper_a), since_wipe(p, wiper_b));
	// drops build up with time since the last wipe (two layers of sizes)
	vec2 duv = p * drop_scale + vec2(0.0, -TIME * speed * 0.004);
	vec4 d1 = texture(drops_tex, duv);
	vec4 d2 = texture(drops_tex, duv * 1.9 + vec2(0.37, 0.61));
	float wet = 1.0 - exp(-t * rain * 0.5);
	float on1 = step(d1.a, wet) * d1.b;
	float on2 = step(d2.a, wet * 0.85) * d2.b;
	// washer fluid lies wherever no blade has passed since the spray
	float fluid = t > wash_age ? wash : 0.0;
	vec2 slope = (d1.rg - 0.5) * on1 + (d2.rg - 0.5) * on2;
	vec2 off = -slope * 0.07 + vec2(sin(p.y * 17.0 + p.x * 4.0), cos(p.x * 13.0 + p.y * 3.0)) * 0.004 * fluid;
	vec3 col = textureLod(screen_tex, SCREEN_UV + off, 0.0).rgb;
	float drop = clamp(on1 + on2, 0.0, 1.0);
	// drops: lensed view with darker rims and a small glint
	col *= mix(1.0, 0.7 + 0.45 * smoothstep(0.3, 0.95, max(d1.b * step(d1.a, wet), d2.b * step(d2.a, wet * 0.85))), drop);
	vec3 n = normalize(vec3(slope * 2.0, 0.45));
	float glint = pow(max(dot(n, normalize(vec3(-0.35, 0.6, 0.72))), 0.0), 40.0) * drop;
	col += vec3(glint * 0.9);
	// condensation on the inside: a milky blur, clearing from the bottom up
	float h = 1.0 - UV.y;
	float strength = clamp(mist * 1.25, 0.0, 0.85);
	float line = 1.05 - mist * 1.35;
	float fog = strength * smoothstep(line - 0.18, line + 0.12, h);
	vec3 blurred = textureLod(screen_tex, SCREEN_UV, 3.5).rgb;
	col = mix(col, blurred * 0.75 + vec3(0.62, 0.64, 0.66) * 0.4, fog);
	ALBEDO = mix(col, tint.rgb, tint.a);
	ALPHA = clamp(max(max(drop, fluid * 0.7), fog) + tint.a, 0.0, 1.0);
}
