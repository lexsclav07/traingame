class_name GaugeFace
extends Control
## Draws a dial face (ticks, numerals, red zone, legends) into a SubViewport so
## the 3D gauge can use it as a crisp texture. Rendered once, then baked into a
## mipmapped ImageTexture by CabGauge.

var face_col := Color(0.95, 0.93, 0.86)
var ink := Color(0.06, 0.06, 0.06)
var min_v := 0.0
var max_v := 100.0
var major := 10.0
var minor := 2.0
var num_div := 1.0
var red_from := INF
var a0 := 225.0
var a1 := -45.0
var title := ""
var unit := ""
var extra := ""
var style := "steam"      # "steam" (enamel, serif-ish proportions) or "modern"


func _ang(v: float) -> float:
	var t := clampf((v - min_v) / (max_v - min_v), 0.0, 1.0)
	return deg_to_rad(lerpf(a0, a1, t))


func _pt(c: Vector2, a: float, r: float) -> Vector2:
	return c + Vector2(cos(a), -sin(a)) * r


func _draw() -> void:
	var s := size.x
	var c := Vector2(s, s) * 0.5
	var R := s * 0.5
	var font := ThemeDB.fallback_font
	# enamel face with a soft darkening toward the rim
	for i in range(24):
		var t := float(i) / 23.0
		draw_circle(c, R * (1.0 - t * 0.5), face_col.darkened(0.12 * (1.0 - t) * (1.0 - t)))
	draw_circle(c, R * 0.5, face_col)
	draw_arc(c, R * 0.985, 0.0, TAU, 128, ink.lerp(face_col, 0.35), R * 0.02, true)
	# red zone
	if red_from < max_v:
		var ra := _ang(red_from)
		var rb := _ang(max_v)
		draw_arc(c, R * 0.86, -ra, -rb, 48, Color(0.78, 0.08, 0.05), R * 0.07, true)
	# scale arc
	if style == "modern":
		draw_arc(c, R * 0.9, -_ang(min_v), -_ang(max_v), 96, ink, R * 0.012, true)
	# ticks
	var v := min_v
	var n := 0
	while v <= max_v + minor * 0.01:
		var is_major := absf(fmod(v - min_v + major * 0.001, major)) < major * 0.01
		var is_half := not is_major and absf(fmod(v - min_v + major * 0.001, major * 0.5)) < major * 0.01
		var a := _ang(v)
		var r1 := R * 0.9
		var r0 := R * (0.74 if is_major else (0.8 if is_half else 0.84))
		var w := R * (0.026 if is_major else (0.016 if is_half else 0.01))
		var col := ink if v < red_from - 1e-4 else Color(0.62, 0.04, 0.03)
		draw_line(_pt(c, a, r0), _pt(c, a, r1), col, w, true)
		if is_major:
			var txt := _fmt(v / num_div)
			var fs := int(R * (0.15 if txt.length() < 3 else 0.13))
			var ts := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			var p := _pt(c, a, R * 0.58)
			draw_string(font, p + Vector2(-ts.x * 0.5, ts.y * 0.32), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
		v += minor
		n += 1
		if n > 400:
			break
	# legends
	if title != "":
		var fs2 := int(R * 0.1)
		var ts2 := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2)
		draw_string(font, c + Vector2(-ts2.x * 0.5, R * 0.42), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, ink)
	if unit != "":
		var fs3 := int(R * 0.09)
		var ts3 := font.get_string_size(unit, HORIZONTAL_ALIGNMENT_LEFT, -1, fs3)
		draw_string(font, c + Vector2(-ts3.x * 0.5, -R * 0.24), unit, HORIZONTAL_ALIGNMENT_LEFT, -1, fs3, ink.lerp(face_col, 0.12))
	if extra != "":
		var fs4 := int(R * 0.06)
		var ts4 := font.get_string_size(extra, HORIZONTAL_ALIGNMENT_LEFT, -1, fs4)
		draw_string(font, c + Vector2(-ts4.x * 0.5, R * 0.62), extra, HORIZONTAL_ALIGNMENT_LEFT, -1, fs4, ink.lerp(face_col, 0.4))
	# boss
	draw_circle(c, R * 0.06, ink.lerp(face_col, 0.15))


func _fmt(x: float) -> String:
	if absf(x - roundf(x)) < 0.01:
		return str(int(roundf(x)))
	return "%.1f" % x
