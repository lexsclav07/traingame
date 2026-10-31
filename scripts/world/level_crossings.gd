class_name LevelCrossings
extends Node3D
## Country roads crossing the line on the level. NSW: chip-seal road with
## line markings, concrete crossing panels, flashing lights, bells and boom
## gates worked by the approaching train (about 25 s warning). 1930s ECML:
## a tarred lane, timber crossing, and big white timber gates with red
## targets that the crossing keeper swings across the road before a train is
## due, with "W" whistle boards on the approach. Sites come from
## TerrainBuilder.crossings, which the other builders keep clear.

const RAMP := 14.0            # road approach grade 1 in 14 up to rail level
const PANEL_U := 3.6          # crossing panels reach this far each side of the centre line
const WARN_TIME := 27.0       # NSW: lights start this many seconds before the train
const BOOM_DELAY := 6.0       # booms start down this long after the lights
const BOOM_DOWN_T := 10.0
const BOOM_UP_T := 8.0
const GATE_SWING_T := 9.0
const GATE_DIST := 1700.0     # ECML: keeper shuts the gates when a train is this close

var track: Track
var terrain: TerrainBuilder
var nsw := true
var night := false
var xings: Array = []
var bell := 0.0               # loudness of the crossing bells at the camera, 0..1
var _t := 0.0
var _m := {}


func build(parent: Node3D, t: Track, ter: TerrainBuilder, q: int) -> void:
	track = t
	terrain = ter
	nsw = t.route["theme"] == "nsw"
	night = GameSettings.time_of_day != "day"
	name = "LevelCrossings"
	parent.add_child(self)
	_materials()
	for c in terrain.crossings:
		_build_one(c, q)


func _materials() -> void:
	var wet := GameSettings.weather == "rain"
	if nsw:
		_m["road"] = TX.pbr("gravel_albedo", "gravel_normal", Color(1.1, 1.1, 1.12), 0.86, 0.0, Vector3.ONE * 0.9, true, 0.7, "road_nsw")
		_m["panel"] = TX.pbr("concrete_albedo", "concrete_normal", Color(0.6, 0.6, 0.58), 0.9, 0.0, Vector3.ONE * 0.8, true, 1.0, "xing_panel")
	else:
		_m["road"] = TX.pbr("gravel_albedo", "gravel_normal", Color(1.15, 1.08, 1.0), 0.9, 0.0, Vector3.ONE * 0.9, true, 0.7, "road_ecml")
		_m["panel"] = TX.pbr("timber_albedo", "timber_normal", Color(0.72, 0.64, 0.56), 0.92, 0.0, Vector3(0.6, 2.0, 2.0), false, 1.2, "xing_planks")
	_m["shoulder"] = TX.pbr("gravel_albedo", "gravel_normal", Color(1.4, 1.3, 1.15), 0.95, 0.0, Vector3.ONE * 0.7, true, 1.0, "road_shoulder")
	_m["paint"] = MU.mat(Color(0.9, 0.9, 0.86), 0.55, 0.0, "road_paint")
	_m["galv"] = TX.metal(Color(0.62, 0.63, 0.64), 0.4, true, 4.0, "xing_galv")
	_m["white"] = TX.painted(Color(0.92, 0.92, 0.9), 0.45, 0.0, "grime", 0.8, 0.0, "xing_white")
	_m["red"] = MU.mat(Color(0.72, 0.05, 0.04), 0.45, 0.0, "xing_red")
	_m["black"] = MU.mat(Color(0.03, 0.03, 0.03), 0.55, 0.0, "xing_black")
	_m["grey"] = TX.painted(Color(0.55, 0.57, 0.58), 0.5, 0.2, "grime", 0.8, 0.0, "xing_cabinet")
	_m["conc"] = TX.pbr("concrete_albedo", "concrete_normal", Color(0.78, 0.77, 0.74), 0.9, 0.0, Vector3.ONE * 0.5, true, 1.0, "s_conc")
	_m["timber"] = TX.pbr("timber_albedo", "timber_normal", Color(0.9, 0.86, 0.8), 0.9, 0.0, Vector3(0.6, 2.0, 2.0), false, 1.0, "xing_post")
	if wet:
		for k in ["road", "panel", "shoulder", "paint"]:
			_m[k] = TX.wet(_m[k])


# ------------------------------------------------------------------ geometry
## Ground under the road: the track formation near the line, else the built terrain mesh.
func _ground(c: Dictionary, u: float, v: float) -> float:
	var o: Vector3 = c["o"]
	var r: Vector3 = c["r"]
	var fw: Vector3 = c["f"]
	var p := o + r * u + fw * v
	var th := track.pos_at(float(c["s"]) + v).y
	var au := absf(u)
	var g := -INF
	if au < 14.5:
		# rows of the formation mesh (TrackBuilder._formation) between which it is linear
		var lats := [2.7, 4.5, 7.0, 9.5, 11.0, 12.5, 14.5]
		var d := clampf(au, 2.7, 14.5)
		for k in range(lats.size() - 1):
			var a: float = lats[k]
			var b: float = lats[k + 1]
			if d <= b:
				var ha := _shoulder(p, r, u, a, th)
				var hb := _shoulder(p, r, u, b, th)
				g = lerpf(ha, hb, (d - a) / (b - a))
				break
	if au > 8.0:
		g = maxf(g, terrain.mesh_height(p.x, p.z))
	return g


func _shoulder(p: Vector3, r: Vector3, u: float, d: float, th: float) -> float:
	if d <= 3.0:
		return th - 0.6
	if d < TerrainBuilder.FORM_W:
		return th - 0.6 - (d - 3.0) * 0.02
	var q := p + r * (signf(u) * d - u)
	return terrain.shaped(q.x, q.z, d, th, false)


## Road surface height: on the ground, rising to rail level over the crossing.
func _road_y(c: Dictionary, u: float, v: float) -> float:
	var th := track.pos_at(float(c["s"]) + v).y
	var ramp := th - 0.012 - maxf(0.0, absf(u) - PANEL_U) / RAMP
	return maxf(_ground(c, u, v) + 0.06, ramp)


func _wp(c: Dictionary, u: float, v: float, y: float) -> Vector3:
	var o: Vector3 = c["o"]
	var p: Vector3 = o + (c["r"] as Vector3) * u + (c["f"] as Vector3) * v
	return Vector3(p.x, y, p.z)


## Rows of u positions for one approach (from the panel edge outwards).
func _rows(from_u: float, to_u: float) -> Array:
	var out := []
	var u := from_u
	var dir := signf(to_u - from_u)
	while absf(u - from_u) < absf(to_u - from_u):
		out.append(u)
		var step := 1.0 if absf(u) < 20.0 else (2.5 if absf(u) < 60.0 else 5.0)
		u += dir * step
	out.append(to_u)
	return out


func _build_one(c: Dictionary, q: int) -> void:
	var node := Node3D.new()
	node.name = "Crossing_%d" % int(c["s"])
	add_child(node)
	var hw: float = c["hw"]
	var lens: Array = c["len"]
	var road := SurfaceTool.new()
	road.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sh := SurfaceTool.new()
	sh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var paint := MeshBatch.new()
	# the two approaches, each from the crossing panels out to the road's end
	for side in [-1.0, 1.0]:
		var rows := _rows(side * PANEL_U, side * float(lens[0 if side < 0.0 else 1]))
		var cols := [-hw, -hw * 0.5, 0.0, hw * 0.5, hw]
		var grid := []
		var shl := []
		for u in rows:
			var row := PackedVector3Array()
			for v in cols:
				row.append(_wp(c, u, v, _road_y(c, u, v)))
			grid.append(row)
			# shoulders: a strip of gravel then a bank down into the ground
			var sr := PackedVector3Array()
			for sv in [-1.0, 1.0]:
				var ve: float = sv * hw
				var ye := _road_y(c, u, ve)
				var g := _ground(c, u, sv * (hw + 1.8))
				sr.append(_wp(c, u, sv * (hw + 0.6), ye - 0.03))
				sr.append(_wp(c, u, sv * (hw + 1.8), minf(ye - 0.5, g - 0.25)))
			shl.append(sr)
		for i in range(rows.size() - 1):
			var a: PackedVector3Array = grid[i]
			var b: PackedVector3Array = grid[i + 1]
			# u grows with i on the right-hand approach; keep the faces pointing up
			var p0 := a if side > 0.0 else b
			var p1 := b if side > 0.0 else a
			for j in range(cols.size() - 1):
				_tri(road, p0[j], p0[j + 1], p1[j + 1])
				_tri(road, p0[j], p1[j + 1], p1[j])
			var sa: PackedVector3Array = shl[i]
			var sb: PackedVector3Array = shl[i + 1]
			var s0 := sa if side > 0.0 else sb
			var s1 := sb if side > 0.0 else sa
			var e0 := p0
			var e1 := p1
			# left shoulder (v < 0): from the road edge outwards
			_quad_up(sh, s0[1], s0[0], s1[0], s1[1])
			_quad_up(sh, s0[0], e0[0], e1[0], s1[0])
			# right shoulder (v > 0)
			_quad_up(sh, e0[cols.size() - 1], s0[2], s1[2], e1[cols.size() - 1])
			_quad_up(sh, s0[2], s0[3], s1[3], s1[2])
		if nsw:
			_markings(paint, c, rows, hw, side)
	road.generate_normals()
	var rmi := MeshInstance3D.new()
	rmi.mesh = road.commit()
	rmi.material_override = _m["road"]
	rmi.name = "Road"
	node.add_child(rmi)
	sh.generate_normals()
	var smi := MeshInstance3D.new()
	smi.mesh = sh.commit()
	smi.material_override = _m["shoulder"]
	smi.name = "Shoulders"
	smi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(smi)
	if not paint.is_empty():
		var pm := paint.commit(node, "Markings")
		pm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_panels(node, c, hw)
	var x := {"s": float(c["s"]), "c": c, "active": false, "on_t": 0.0, "boom": 1.0, "gate": 1.0,
		"booms": [], "gates": [], "lamp_a": null, "lamp_b": null, "tip": null, "lights": []}
	if nsw:
		_nsw_protection(node, c, x, q)
	else:
		_ecml_gates(node, c, x)
	_whistle_board(node, c)
	# road traffic that queues while the crossing is closed
	var rng := RandomNumberGenerator.new()
	rng.seed = int(c["s"])
	x["rng"] = rng
	x["cars"] = []
	for sgn in [-1.0, 1.0]:
		var car: Node3D = RoadCars.modern(rng, night) if nsw else RoadCars.vintage(rng, night)
		car.visible = false
		node.add_child(car)
		x["cars"].append({"n": car, "sgn": sgn, "u": 0.0, "v": -sgn * hw * 0.5, "spd": 0.0, "state": "away",
			"len": float(car.get_meta("length"))})
	xings.append(x)


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, cc: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(cc)


## Quad given anticlockwise as seen from above (faces up after Godot's clockwise rule).
func _quad_up(st: SurfaceTool, a: Vector3, b: Vector3, cc: Vector3, d: Vector3) -> void:
	# a, b, c, d run around the quad; pick the winding whose normal points up
	var n := (cc - a).cross(b - a)
	if n.y >= 0.0:
		_tri(st, a, b, cc)
		_tri(st, a, cc, d)
	else:
		_tri(st, a, cc, b)
		_tri(st, a, d, cc)


## NSW line markings: broken centre line, edge lines and a stop line before the boom.
func _markings(b: MeshBatch, c: Dictionary, rows: Array, hw: float, side: float) -> void:
	var paint: Material = _m["paint"]
	var u_end: float = rows[rows.size() - 1]
	var lift := 0.012
	# edge lines (100 mm) and the broken centre line (3 m dash, 9 m gap)
	for i in range(rows.size() - 1):
		var ua: float = rows[i]
		var ub: float = rows[i + 1]
		for ve in [-hw + 0.25, hw - 0.25]:
			_strip(b, paint, c, ua, ub, ve, 0.05, lift)
		var mid := (absf(ua) + absf(ub)) * 0.5
		if absf(ua) > PANEL_U + 1.0 and fmod(mid - PANEL_U, 12.0) < 3.0:
			_strip(b, paint, c, ua, ub, 0.0, 0.05, lift)
	# stop line across the approach lane (traffic keeps left), 3 m before the boom
	var us := side * (PANEL_U + 4.6)
	_strip(b, paint, c, us - 0.15, us + 0.15, -side * hw * 0.5, hw * 0.5 - 0.3, lift)
	# give way / railway crossing hatching is left out; "RAIL X" would go here
	if absf(u_end) < 1.0:
		push_warning("level crossing road with no length")


func _strip(b: MeshBatch, mat: Material, c: Dictionary, ua: float, ub: float, v: float, hw: float, lift: float) -> void:
	var p0 := _wp(c, ua, v - hw, _road_y(c, ua, v - hw) + lift)
	var p1 := _wp(c, ub, v - hw, _road_y(c, ub, v - hw) + lift)
	var p2 := _wp(c, ub, v + hw, _road_y(c, ub, v + hw) + lift)
	var p3 := _wp(c, ua, v + hw, _road_y(c, ua, v + hw) + lift)
	if ub > ua:
		b.quad("paint", mat, p0, p1, p2, p3)
	else:
		b.quad("paint", mat, p1, p0, p3, p2)


## Crossing panels at rail-top level with flangeway gaps beside each rail.
func _panels(node: Node3D, c: Dictionary, hw: float) -> void:
	var b := MeshBatch.new()
	var mat: Material = _m["panel"]
	var o: Vector3 = c["o"]
	var r: Vector3 = c["r"]
	var fw: Vector3 = c["f"]
	# local frame: x = across the line (r), y = up, z = r x up (along the line)
	var basis := Basis(r, Vector3.UP, r.cross(Vector3.UP))
	var span := hw * 2.0 + 0.6
	var pieces := [[-0.64, 0.64], [0.79, PANEL_U], [-PANEL_U, -0.79]]
	for pc in pieces:
		var a: float = pc[0]
		var e: float = pc[1]
		if nsw:
			# precast concrete panels, 1.2 m wide along the road
			var vv := -span * 0.5
			while vv < span * 0.5 - 0.01:
				var w := minf(1.2, span * 0.5 - vv)
				var centre := o + r * ((a + e) * 0.5) + fw * (vv + w * 0.5) + Vector3.UP * (track.pos_at(float(c["s"]) + vv + w * 0.5).y - o.y - 0.012 - 0.1)
				b.box("p", mat, Vector3(e - a - 0.01, 0.2, w - 0.02), Transform3D(basis, centre))
				vv += w
		else:
			# timber planks laid along the rails
			var uu := a
			while uu < e - 0.01:
				var w := minf(0.23, e - uu)
				var centre := o + r * (uu + w * 0.5) + Vector3.UP * (-0.012 - 0.07)
				b.box("p", mat, Vector3(w - 0.015, 0.14, span), Transform3D(basis, centre))
				uu += w
	var mi := b.commit(node, "CrossingPanels")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Frame on the road: x = along +v * sgn (into the road for the assemblies), y = up.
func _road_frame(c: Dictionary, u: float, v: float, x_dir: Vector3) -> Transform3D:
	var y := _road_y(c, u, v)
	var z := x_dir.cross(Vector3.UP)
	return Transform3D(Basis(x_dir, Vector3.UP, z), _wp(c, u, v, y))


# ------------------------------------------------------------- NSW protection
func _nsw_protection(node: Node3D, c: Dictionary, x: Dictionary, q: int) -> void:
	var hw: float = c["hw"]
	var fw: Vector3 = c["f"]
	x["lamp_a"] = MU.lamp(Color(1.0, 0.1, 0.04), 0.0)
	x["lamp_b"] = MU.lamp(Color(1.0, 0.1, 0.04), 0.0)
	x["tip"] = MU.lamp(Color(1.0, 0.1, 0.04), 0.0)
	for sgn in [-1.0, 1.0]:
		# traffic approaching from this side (sgn) keeps left: its kerb is at
		# v = -sgn (hw + 0.9), and the boom swings out across its lane
		var into: Vector3 = fw * sgn
		var ku: float = sgn * (PANEL_U + 1.3)
		var kv: float = -sgn * (hw + 0.9)
		var xf := _road_frame(c, ku, kv, into)
		xf.origin.y = maxf(_ground(c, ku, kv), _road_y(c, ku, -sgn * hw) - 0.3) + 0.05
		var asm := Node3D.new()
		asm.name = "Boom"
		node.add_child(asm)
		asm.transform = xf
		_boom_mast(asm, x)
		var pivot := Node3D.new()
		pivot.name = "Pivot"
		asm.add_child(pivot)
		pivot.position = Vector3(0.42, 1.05, 0.0)
		_boom_arm(pivot, x, hw + 0.75)
		pivot.rotation.z = deg_to_rad(86.0)
		x["booms"].append(pivot)
		if night and q >= 1:
			var lt := OmniLight3D.new()
			lt.light_color = Color(1.0, 0.12, 0.05)
			lt.omni_range = 7.0
			lt.light_energy = 0.0
			lt.shadow_enabled = false
			asm.add_child(lt)
			lt.position = Vector3(0.0, 3.05, 0.0)
			x["lights"].append(lt)


## Mast with crossbuck, twin flashing lights each way, bell and the boom cabinet.
func _boom_mast(asm: Node3D, x: Dictionary) -> void:
	var b := MeshBatch.new()
	var galv: Material = _m["galv"]
	var white: Material = _m["white"]
	var red: Material = _m["red"]
	var black: Material = _m["black"]
	b.box("conc", _m["conc"], Vector3(0.8, 0.3, 0.8), Transform3D(Basis(), Vector3(0.15, 0.1, 0)))
	b.cyl("galv", galv, Transform3D(Basis(), Vector3(0, 2.3, 0)), 0.055, 0.065, 4.4, 10)
	# crossbuck: white boards with a red border, both faces
	for a in [45.0, -45.0]:
		var rb := Basis(Vector3(0, 0, 1), deg_to_rad(a))
		b.box("red", red, Vector3(1.24, 0.25, 0.03), Transform3D(rb, Vector3(0, 4.05, 0)))
		b.box("white", white, Vector3(1.16, 0.17, 0.045), Transform3D(rb, Vector3(0, 4.05, 0)))
	# light head: cross arm with two lamps facing each way
	b.box("black", black, Vector3(1.0, 0.1, 0.1), Transform3D(Basis(), Vector3(0, 3.05, 0)))
	for lx in [-0.4, 0.4]:
		for face in [-1.0, 1.0]:
			var z: float = face * 0.08
			b.cyl("black", black, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(lx, 3.05, z)), 0.27, 0.27, 0.03, 20)
			b.cyl("white", white, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(lx, 3.05, z - face * 0.005)), 0.29, 0.29, 0.02, 20)
			# hood over the lens
			b.cyl("black", black, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(lx, 3.07, z + face * 0.1)), 0.13, 0.13, 0.18, 12)
	# bell on top of the mast
	b.mesh("black", black, _dome(), Transform3D(Basis(), Vector3(0, 4.55, 0)))
	# boom mechanism cabinet beside the mast, on the road side
	b.box("grey", _m["grey"], Vector3(0.42, 1.0, 0.38), Transform3D(Basis(), Vector3(0.42, 0.55, 0)))
	b.box("grey", _m["grey"], Vector3(0.46, 0.06, 0.42), Transform3D(Basis(), Vector3(0.42, 1.07, 0)))
	var mi := b.commit(asm, "Mast")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# the lenses themselves (flashing, so separate materials)
	for i in range(2):
		var lx: float = [-0.4, 0.4][i]
		var lm: Material = x["lamp_a"] if i == 0 else x["lamp_b"]
		for face in [-1.0, 1.0]:
			var lens := MU.cyl(asm, 0.1, 0.02, Vector3(lx, 3.05, face * 0.105), lm, Vector3(90, 0, 0), 16)
			lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static var _dome_mesh: SphereMesh


static func _dome() -> SphereMesh:
	if _dome_mesh == null:
		_dome_mesh = SphereMesh.new()
		_dome_mesh.radius = 0.16
		_dome_mesh.height = 0.2
		_dome_mesh.is_hemisphere = true
		_dome_mesh.radial_segments = 14
		_dome_mesh.rings = 4
	return _dome_mesh


## Boom arm along +x from the pivot: red and white bands, lamps on top,
## counterweight behind the pivot.
func _boom_arm(pivot: Node3D, x: Dictionary, length: float) -> void:
	var b := MeshBatch.new()
	var band := 0.6
	var k := 0
	var xx := 0.15
	while xx < length - 0.01:
		var w := minf(band, length - xx)
		var mat: Material = _m["red"] if k % 2 == 0 else _m["white"]
		var taper := 1.0 - 0.35 * (xx / length)
		b.box("red" if k % 2 == 0 else "white", mat, Vector3(w, 0.11 * taper, 0.08 * taper), Transform3D(Basis(), Vector3(xx + w * 0.5, 0, 0)))
		xx += w
		k += 1
	b.box("galv", _m["galv"], Vector3(0.5, 0.16, 0.14), Transform3D(Basis(), Vector3(0.0, 0, 0)))
	b.box("black", _m["black"], Vector3(0.45, 0.32, 0.22), Transform3D(Basis(), Vector3(-0.42, 0, 0)))
	var mi := b.commit(pivot, "Arm")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# three lamps on the top of the arm: the tip one steady, the others flashing
	for i in range(3):
		var lx: float = length * [0.35, 0.68, 0.98][i]
		var lm: Material = x["tip"] if i == 2 else (x["lamp_a"] if i == 0 else x["lamp_b"])
		var lamp := MU.box(pivot, Vector3(0.07, 0.06, 0.1), Vector3(lx, 0.075, 0), lm)
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ------------------------------------------------------------- ECML gates
func _ecml_gates(node: Node3D, c: Dictionary, x: Dictionary) -> void:
	var hw: float = c["hw"]
	var fw: Vector3 = c["f"]
	var glen := hw * 2.0 + 0.3
	var lamp := MU.lamp(Color(1.0, 0.25, 0.08), 1.6 if night else 0.0)
	for sgn in [-1.0, 1.0]:
		# one gate each side of the line, hinged at opposite kerbs, so that
		# swung across the railway they fence it off along both road edges
		var u: float = sgn * (PANEL_U + 0.1)
		var v: float = sgn * (hw + 0.15)
		var hinge := _road_frame(c, u, v, fw * -sgn)
		hinge.origin.y = _road_y(c, u, v)
		var base := Node3D.new()
		base.name = "Gate"
		node.add_child(base)
		base.transform = hinge
		# hinge post and a catch post at the far kerb
		MU.box(base, Vector3(0.3, 2.0, 0.3), Vector3(-0.2, 0.9, 0), _m["timber"])
		MU.box(base, Vector3(0.3, 0.12, 0.3), Vector3(-0.2, 1.95, 0), _m["white"])
		MU.box(base, Vector3(0.22, 1.2, 0.22), Vector3(glen + 0.2, 0.5, 0), _m["timber"])
		var leaf := Node3D.new()
		leaf.name = "Leaf"
		base.add_child(leaf)
		_gate_leaf(leaf, glen, lamp)
		x["gates"].append(leaf)
	x["lamp_a"] = lamp


## A five-bar style timber crossing gate, painted white, with a red target.
func _gate_leaf(leaf: Node3D, glen: float, lamp: Material) -> void:
	var b := MeshBatch.new()
	var white: Material = _m["white"]
	var red: Material = _m["red"]
	b.box("w", white, Vector3(0.14, 1.45, 0.12), Transform3D(Basis(), Vector3(0.07, 0.82, 0)))
	b.box("w", white, Vector3(0.1, 1.2, 0.09), Transform3D(Basis(), Vector3(glen - 0.05, 0.75, 0)))
	for y in [0.25, 0.82, 1.42]:
		b.box("w", white, Vector3(glen, 0.1 if y > 1.0 else 0.08, 0.08), Transform3D(Basis(), Vector3(glen * 0.5, y, 0)))
	var xx := 0.3
	while xx < glen - 0.15:
		b.box("w", white, Vector3(0.035, 1.15, 0.035), Transform3D(Basis(), Vector3(xx, 0.83, 0)))
		xx += 0.16
	# diagonal brace from the bottom of the hinge stile up to the top rail
	var a := Vector3(0.12, 0.3, 0)
	var e := Vector3(glen * 0.72, 1.38, 0)
	b.box("w", white, Vector3((e - a).length(), 0.07, 0.06), Transform3D(Basis(Vector3(0, 0, 1), atan2(e.y - a.y, e.x - a.x)), (a + e) * 0.5))
	# red target disc on both faces
	for face in [-1.0, 1.0]:
		b.cyl("r", red, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(glen * 0.5, 0.85, face * 0.05)), 0.32, 0.32, 0.02, 24)
	# gate lamp on the top rail
	b.box("k", _m["black"], Vector3(0.16, 0.22, 0.16), Transform3D(Basis(), Vector3(glen * 0.5, 1.58, 0)))
	b.cyl("k", _m["black"], Transform3D(Basis(), Vector3(glen * 0.5, 1.72, 0)), 0.03, 0.09, 0.06, 10)
	var mi := b.commit(leaf, "Leaf")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for face in [-1.0, 1.0]:
		var l := MU.cyl(leaf, 0.05, 0.02, Vector3(glen * 0.5, 1.58, face * 0.085), lamp, Vector3(90, 0, 0), 12)
		l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## "W" whistle board 400 m before the crossing, facing the approaching train.
func _whistle_board(node: Node3D, c: Dictionary) -> void:
	var s := float(c["s"]) - 400.0
	for pl in track.route.get("platforms", []):
		if terrain.sdiff(s, pl[0]) > -20.0 and terrain.sdiff(s, pl[0] + pl[1]) < 20.0:
			s = float(pl[0]) - 25.0
	if terrain.is_bridge(s):
		return
	var f := track.flat_frame_at(s, -2.9)
	var p := Node3D.new()
	p.name = "WhistleBoard"
	node.add_child(p)
	p.global_transform = Transform3D(f.basis, f.origin + Vector3.UP * -0.6)
	var post: Material = _m["galv"] if nsw else _m["timber"]
	MU.box(p, Vector3(0.09, 2.5, 0.09), Vector3(0, 1.25, 0), post)
	MU.box(p, Vector3(0.62, 0.62, 0.04), Vector3(0, 2.5, 0.0), _m["white"])
	MU.box(p, Vector3(0.66, 0.66, 0.02), Vector3(0, 2.5, -0.03), _m["black"])
	MU.label(p, "W", Vector3(0, 2.5, 0.025), 0.009, Color(0.03, 0.03, 0.03), Vector3.ZERO, 96)


# ------------------------------------------------------------------ running
## Called every frame with the simulated time step: works the lights, bells,
## booms and gates from where the train is.
func update(dt: float, train: Train, cam_pos: Vector3) -> void:
	_t += dt
	bell = 0.0
	var tlen := train.total_length()
	for x in xings:
		var s: float = x["s"]
		var ahead := terrain.sdiff(s, train.front_s)           # > 0: in front of the train
		var behind := terrain.sdiff(train.front_s - tlen, s)   # > 0: behind the rear
		var v := train.speed
		var occupied := ahead <= 0.0 and behind <= 0.0
		var reach := GATE_DIST if not nsw else maxf(260.0, absf(v) * WARN_TIME)
		var want := occupied
		if v > -0.3:
			# running forwards (or stood): strike in ahead, clear once the rear is past
			if ahead > 0.0 and ahead < reach:
				want = true
			if behind > 0.0 and behind < 25.0:
				want = true
		else:
			# setting back
			if behind > 0.0 and behind < reach:
				want = true
			if ahead > 0.0 and ahead < 25.0:
				want = true
		if want and not x["active"]:
			x["on_t"] = 0.0
			_cars_arrive(x, false)
		x["active"] = want
		x["on_t"] = float(x["on_t"]) + dt
		if nsw:
			_run_nsw(x, dt, cam_pos)
		else:
			_run_gates(x, dt)
		_run_cars(x, dt)


func _run_nsw(x: Dictionary, dt: float, cam_pos: Vector3) -> void:
	var active: bool = x["active"]
	var boom: float = x["boom"]           # 1 = up, 0 = down
	if active and float(x["on_t"]) > BOOM_DELAY:
		boom = maxf(0.0, boom - dt / BOOM_DOWN_T)
	elif not active:
		boom = minf(1.0, boom + dt / BOOM_UP_T)
	x["boom"] = boom
	for p in x["booms"]:
		(p as Node3D).rotation.z = deg_to_rad(86.0) * _ease(boom)
	var flashing := active or boom < 0.97
	var ph := fmod(_t, 1.3) < 0.65
	var e_on := 7.0
	(x["lamp_a"] as StandardMaterial3D).emission_energy_multiplier = e_on if flashing and ph else 0.0
	(x["lamp_b"] as StandardMaterial3D).emission_energy_multiplier = e_on if flashing and not ph else 0.0
	(x["tip"] as StandardMaterial3D).emission_energy_multiplier = e_on if flashing else 0.0
	var lights: Array = x["lights"]
	for i in range(lights.size()):
		# the red glow on the road alternates with the lamps
		(lights[i] as OmniLight3D).light_energy = 1.6 if flashing and (ph == (i % 2 == 0)) else 0.0
	if flashing:
		var o: Vector3 = (x["c"] as Dictionary)["o"]
		var d := cam_pos.distance_to(o)
		bell = maxf(bell, 1.0 / (1.0 + pow(d / 45.0, 2.0)))


func _run_gates(x: Dictionary, dt: float) -> void:
	# gate: 1 = open to the road (across the railway), 0 = closed to the road
	var g: float = x["gate"]
	if x["active"]:
		g = maxf(0.0, g - dt / GATE_SWING_T)
	else:
		g = minf(1.0, g + dt / GATE_SWING_T)
	x["gate"] = g
	for leaf in x["gates"]:
		(leaf as Node3D).rotation.y = -PI * 0.5 * _ease(g)


func _ease(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


## Put everything straight into the state the train's position calls for
## (at the start, and after the train is moved).
func settle(train: Train) -> void:
	update(0.0, train, Vector3.ZERO)
	for x in xings:
		var on: bool = x["active"]
		x["on_t"] = 100.0 if on else 0.0
		x["boom"] = 0.0 if on else 1.0
		x["gate"] = 0.0 if on else 1.0
		for car in x["cars"]:
			if on and car["state"] == "arriving":
				# already queued at the stop line
				car["u"] = car["stop"]
				car["spd"] = 0.0
				car["state"] = "waiting"
			elif not on:
				car["state"] = "away"
				(car["n"] as Node3D).visible = false
	update(0.0, train, Vector3.ZERO)


# ---------------------------------------------------------------- road traffic
## The crossing has just closed: a car or two turn up and queue at the stop line.
func _cars_arrive(x: Dictionary, instantly: bool) -> void:
	var rng: RandomNumberGenerator = x["rng"]
	for car in x["cars"]:
		if car["state"] != "away":
			continue
		var sgn: float = car["sgn"]
		if rng.randf() > (0.7 if sgn < 0.0 else 0.5):
			continue
		var stop_u: float = sgn * (PANEL_U + (4.6 if nsw else 1.6) + 0.8 + float(car["len"]) * 0.5)
		car["stop"] = stop_u
		car["u"] = stop_u if instantly else sgn * 75.0
		car["spd"] = 0.0 if instantly else 12.0
		car["state"] = "arriving"
		(car["n"] as Node3D).visible = true
		_place_car(x, car)


func _run_cars(x: Dictionary, dt: float) -> void:
	var open: bool = (float(x["boom"]) > 0.98 if nsw else float(x["gate"]) > 0.98) and not x["active"]
	var c: Dictionary = x["c"]
	for car in x["cars"]:
		var st: String = car["state"]
		if st == "away":
			continue
		var sgn: float = car["sgn"]
		var u: float = car["u"]
		var spd: float = car["spd"]
		if st == "arriving":
			# brake smoothly to a stand at the stop line
			var left: float = absf(u - float(car["stop"]))
			spd = minf(12.0, sqrt(maxf(0.0, 2.0 * 2.5 * left)))
			if left < 0.05:
				spd = 0.0
				u = car["stop"]
				car["state"] = "waiting"
			if open:
				car["state"] = "going"
		elif st == "waiting":
			spd = 0.0
			if open:
				car["state"] = "going"
		else:
			spd = minf(spd + 2.2 * dt, 14.0)
		u -= sgn * spd * dt
		if car["state"] == "arriving" and sgn * (u - float(car["stop"])) < 0.0:
			u = car["stop"]
		car["u"] = u
		car["spd"] = spd
		var lens: Array = c["len"]
		var far: float = minf(160.0, float(lens[0 if sgn > 0.0 else 1]) - 6.0)
		if car["state"] == "going" and -sgn * u > far:
			car["state"] = "away"
			(car["n"] as Node3D).visible = false
			continue
		_place_car(x, car)


func _place_car(x: Dictionary, car: Dictionary) -> void:
	var c: Dictionary = x["c"]
	var sgn: float = car["sgn"]
	var u: float = car["u"]
	var v: float = car["v"]
	var half := float(car["len"]) * 0.32
	# facing the way it drives (-sgn r), pitched with the road
	var yf := _road_y(c, u - sgn * half, v)
	var yr := _road_y(c, u + sgn * half, v)
	var back: Vector3 = (c["r"] as Vector3) * sgn
	var pitch := atan2(yf - yr, half * 2.0)
	var basis := Basis(Vector3.UP.cross(back).normalized(), Vector3.UP, back)
	basis = basis.rotated(basis.x, pitch)
	(car["n"] as Node3D).global_transform = Transform3D(basis, _wp(c, u, v, (yf + yr) * 0.5))
