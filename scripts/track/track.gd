class_name Track
extends RefCounted
## Continuous track loop: centre line sampled every STEP metres with heading,
## curvature, grade, cant (superelevation) and line speed. Everything that
## needs to know "where is distance s on the line" asks this object.

const STEP := 2.0
const GAUGE := 1.435
const RAIL_SEP := 1.5          # rail centre to rail centre for cant geometry

var route: Dictionary
var length := 0.0
var n := 0
var px := PackedFloat32Array()
var py := PackedFloat32Array()
var pz := PackedFloat32Array()
var heading := PackedFloat32Array()
var curv := PackedFloat32Array()
var grade := PackedFloat32Array()
var cant := PackedFloat32Array()     # roll angle (rad), + leans left (left-hand curve)
var limit := PackedFloat32Array()    # km/h line speed at each sample
var bounds := Rect2()
var min_h := 0.0
var max_h := 0.0


func build(def: Dictionary) -> void:
	route = def
	var pieces := _make_pieces(def)
	_integrate(pieces)
	_build_profile(def["profile"])
	_build_cant()
	_compute_bounds()
	_recentre()


# ----------------------------------------------------------------- geometry
func _make_pieces(def: Dictionary) -> Array:
	var pieces := []   # [length, k0, k1, limit]
	var lt: float = def["transition"]
	var total := 0.0
	var last_arc := -1
	for seg in def["plan"]:
		if seg[0] == "S":
			pieces.append([float(seg[1]), 0.0, 0.0, float(seg[2])])
		else:
			var r: float = seg[1]
			var ang: float = deg_to_rad(seg[2])
			var k: float = signf(ang) / r
			var t: float = minf(lt, absf(ang) * r * 0.45)
			var arc_len: float = absf(ang) * r - t
			pieces.append([t, 0.0, k, float(seg[3])])
			pieces.append([arc_len, k, k, float(seg[3])])
			last_arc = pieces.size() - 1
			pieces.append([t, k, 0.0, float(seg[3])])
			total += ang
	# make the half-circuit turn exactly 180 degrees
	if last_arc >= 0 and absf(total - PI) > 1e-6:
		var p: Array = pieces[last_arc]
		p[0] = maxf(10.0, p[0] + (PI - total) / p[1])
	# pad so half length is a whole number of samples
	var half := 0.0
	for p in pieces:
		half += p[0]
	var pad := ceilf(half / STEP) * STEP - half
	if pad > 1e-4:
		pieces.append([pad, 0.0, 0.0, def["default_limit"]])
	return pieces


func _integrate(pieces: Array) -> void:
	var half_len := 0.0
	for p in pieces:
		half_len += p[0]
	var half_n := int(round(half_len / STEP))
	n = half_n * 2
	length = n * STEP
	for arr in [px, pz, heading, curv, limit]:
		arr.resize(n)
	var sub := 8
	var ds := STEP / sub
	var x := 0.0
	var z := 0.0
	var th := 0.0
	var piece_i := 0
	var piece_s := 0.0     # distance into current piece
	for i in range(half_n):
		var p: Array = pieces[piece_i]
		px[i] = x; pz[i] = z; heading[i] = th
		curv[i] = lerpf(p[1], p[2], clampf(piece_s / maxf(p[0], 0.001), 0.0, 1.0))
		limit[i] = p[3]
		for _k in range(sub):
			p = pieces[piece_i]
			var k: float = lerpf(p[1], p[2], clampf((piece_s + ds * 0.5) / maxf(p[0], 0.001), 0.0, 1.0))
			var th_mid := th + k * ds * 0.5
			x += cos(th_mid) * ds
			z -= sin(th_mid) * ds
			th += k * ds
			piece_s += ds
			while piece_i < pieces.size() - 1 and piece_s >= pieces[piece_i][0] - 1e-6:
				piece_s -= pieces[piece_i][0]
				piece_i += 1
	# second half: point symmetric copy => closes exactly
	var ex := x
	var ez := z
	for i in range(half_n):
		var j := i + half_n
		px[j] = ex - px[i]
		pz[j] = ez - pz[i]
		heading[j] = heading[i] + PI
		curv[j] = curv[i]
		limit[j] = limit[i]
	# curves get their limit a little before the transition starts (boards at approach)
	_extend_restrictions(150.0)


func _extend_restrictions(lead: float) -> void:
	var orig := limit.duplicate()
	var steps := int(lead / STEP)
	for i in range(n):
		var m := orig[i]
		for k in range(1, steps + 1):
			m = minf(m, orig[(i + k) % n])
		limit[i] = m


func _build_profile(profile: Array) -> void:
	var total := 0.0
	for e in profile:
		total += e[0]
	var scale := length / total
	var g := PackedFloat32Array()
	g.resize(n)
	var bounds_s := []
	var acc := 0.0
	for e in profile:
		acc += e[0] * scale
		bounds_s.append(acc)
	var idx := 0
	for i in range(n):
		var s := i * STEP
		while idx < profile.size() - 1 and s >= bounds_s[idx]:
			idx += 1
		g[i] = profile[idx][1] / 1000.0
	# close the height loop by adjusting the final section
	var rise := 0.0
	for i in range(n):
		rise += g[i] * STEP
	var last_len: float = profile[profile.size() - 1][0] * scale
	var start_last: float = length - last_len
	for i in range(n):
		if i * STEP >= start_last:
			g[i] -= rise / last_len
	# vertical curves: periodic moving average (keeps net rise zero)
	var w := int(200.0 / STEP)
	grade.resize(n)
	var run := 0.0
	for k in range(-w, w + 1):
		run += g[(k + n) % n]
	for i in range(n):
		grade[i] = run / (2 * w + 1)
		run += g[(i + w + 1) % n] - g[(i - w + n) % n]
	py.resize(n)
	var h := 0.0
	for i in range(n):
		py[i] = h
		h += grade[i] * STEP
	# drift correction (numerically tiny)
	var drift := h
	min_h = INF
	max_h = -INF
	for i in range(n):
		py[i] -= drift * i / n
		min_h = minf(min_h, py[i])
		max_h = maxf(max_h, py[i])
	for i in range(n):
		py[i] -= min_h
	max_h -= min_h
	min_h = 0.0


func _build_cant() -> void:
	cant.resize(n)
	for i in range(n):
		var v := limit[i]
		var e_mm := clampf(11.8 * v * v * absf(curv[i]) * 0.85, 0.0, 150.0)
		cant[i] = asin(e_mm / 1000.0 / RAIL_SEP) * signf(curv[i])


func _compute_bounds() -> void:
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for i in range(n):
		mn.x = minf(mn.x, px[i]); mn.y = minf(mn.y, pz[i])
		mx.x = maxf(mx.x, px[i]); mx.y = maxf(mx.y, pz[i])
	bounds = Rect2(mn, mx - mn)


## Keep coordinates small (float precision): centre the loop on the origin.
func _recentre() -> void:
	var c := bounds.get_center()
	for i in range(n):
		px[i] -= c.x
		pz[i] -= c.y
	bounds.position -= c


# ------------------------------------------------------------------ queries
func wrap_s(s: float) -> float:
	return fposmod(s, length)


func pos_at(s: float) -> Vector3:
	var f := wrap_s(s) / STEP
	var i0 := int(f) % n
	var i1 := (i0 + 1) % n
	var t := f - floorf(f)
	return Vector3(lerpf(px[i0], px[i1], t), lerpf(py[i0], py[i1], t), lerpf(pz[i0], pz[i1], t))


func heading_at(s: float) -> float:
	var f := wrap_s(s) / STEP
	var i0 := int(f) % n
	return lerp_angle(heading[i0], heading[(i0 + 1) % n], f - floorf(f))


func _sample(arr: PackedFloat32Array, s: float) -> float:
	var f := wrap_s(s) / STEP
	var i0 := int(f) % n
	return lerpf(arr[i0], arr[(i0 + 1) % n], f - floorf(f))


func grade_at(s: float) -> float:
	return _sample(grade, s)


func curv_at(s: float) -> float:
	return _sample(curv, s)


func cant_at(s: float) -> float:
	return _sample(cant, s)


func limit_at(s: float) -> float:
	return limit[int(wrap_s(s) / STEP) % n]


## Lowest line speed anywhere between two distances (train occupies [a, b]).
func min_limit_between(a: float, b: float) -> float:
	var m := INF
	var s := a
	while s <= b:
		m = minf(m, limit_at(s))
		s += STEP * 4.0
	return minf(m, limit_at(b))


func forward_at(s: float) -> Vector3:
	var h := heading_at(s)
	return Vector3(cos(h), grade_at(s), -sin(h)).normalized()


## Track frame: origin on the centre line at rail-top level; x = right,
## y = up (rolled by cant), -z = forward (increasing s).
func frame_at(s: float, lateral := 0.0, with_cant := true) -> Transform3D:
	var f := forward_at(s)
	var right := f.cross(Vector3.UP).normalized()
	var up := right.cross(f).normalized()
	if with_cant:
		var c := cant_at(s)
		if c != 0.0:
			var rb := Basis(f, -c)
			right = rb * right
			up = rb * up
	var b := Basis(right, up, -f)
	return Transform3D(b, pos_at(s) + right * lateral)


## Unrolled frame (for lineside objects that should stand vertical).
func flat_frame_at(s: float, lateral := 0.0) -> Transform3D:
	var h := heading_at(s)
	var f := Vector3(cos(h), 0, -sin(h))
	var right := f.cross(Vector3.UP).normalized()
	return Transform3D(Basis(right, Vector3.UP, -f), pos_at(s) + right * lateral)


## Speed-limit change points: [[s, new_limit], ...] for lineside boards / ETCS.
func limit_changes() -> Array:
	var out := []
	for i in range(n):
		var prev := limit[(i - 1 + n) % n]
		if limit[i] != prev:
			out.append([i * STEP, limit[i]])
	return out
