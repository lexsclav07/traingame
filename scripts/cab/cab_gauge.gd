class_name CabGauge
extends Node3D
## Round dial gauge with one or more needles. The face lies in local XY and
## faces +Z. Needles are damped so they move like real instruments.

var min_v := 0.0
var max_v := 100.0
var a0 := 225.0          # degrees (from +X, counter-clockwise) at min
var a1 := -45.0          # at max
var radius := 0.07
var needles: Array[Node3D] = []
var targets: Array[float] = []
var shown: Array[float] = []
var damping := 6.0
var title := ""
var unit := ""
var face_mat: StandardMaterial3D


func build(r: float, mn: float, mx: float, major: float, minor: float, label_txt: String, unit_txt: String,
		needle_cols: Array = [Color(0.05, 0.05, 0.05)], face_col := Color(0.93, 0.91, 0.84),
		num_div := 1.0, bezel_col := Color(0.15, 0.15, 0.15), red_from := INF, sweep := 270.0) -> void:
	radius = r
	min_v = mn
	max_v = mx
	title = label_txt
	unit = unit_txt
	a0 = 90.0 + sweep * 0.5
	a1 = 90.0 - sweep * 0.5
	face_mat = StandardMaterial3D.new()
	face_mat.albedo_color = face_col
	face_mat.roughness = 0.6
	var face := MU.cyl(self, r, 0.01, Vector3(0, 0, -0.005), face_mat, Vector3(90, 0, 0), 32)
	face.name = "Face"
	MU.torus(self, r * 0.98, r * 1.12, Vector3(0, 0, 0.0), MU.mat(bezel_col, 0.3, 0.8), Vector3(90, 0, 0))
	# ticks
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tick_col := Color(0.05, 0.05, 0.05)
	var v := mn
	while v <= mx + 0.0001:
		var is_major := absf(fmod(v - mn + 0.0001, major)) < 0.001 or absf(fmod(v - mn + 0.0001, major) - major) < 0.002
		var ang := deg_to_rad(_angle_for(v))
		var dir := Vector2(cos(ang), sin(ang))
		var perp := Vector2(-dir.y, dir.x)
		var r1 := r * 0.92
		var r0 := r * (0.76 if is_major else 0.84)
		var w := r * (0.022 if is_major else 0.012)
		var p0 := dir * r0
		var p1 := dir * r1
		var col := tick_col if v < red_from else Color(0.8, 0.05, 0.05)
		var q := [p0 - perp * w, p1 - perp * w, p1 + perp * w, p0 + perp * w]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_color(col)
			var qp: Vector2 = q[idx]
			st.add_vertex(Vector3(qp.x, qp.y, 0.002))
		if is_major:
			var lab := MU.label(self, _fmt(v / num_div), Vector3(dir.x * r * 0.6, dir.y * r * 0.6, 0.003), r * 0.0028, Color(0.05, 0.05, 0.05), Vector3.ZERO, 32)
			lab.name = "N"
		v += minor
	var tm := StandardMaterial3D.new()
	tm.vertex_color_use_as_albedo = true
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var ticks := MeshInstance3D.new()
	ticks.mesh = st.commit()
	ticks.material_override = tm
	add_child(ticks)
	MU.label(self, label_txt, Vector3(0, -r * 0.42, 0.003), r * 0.0022, Color(0.1, 0.1, 0.1), Vector3.ZERO, 32)
	if unit_txt != "":
		MU.label(self, unit_txt, Vector3(0, r * 0.3, 0.003), r * 0.0018, Color(0.25, 0.25, 0.25), Vector3.ZERO, 32)
	for i in range(needle_cols.size()):
		var nd := Node3D.new()
		add_child(nd)
		nd.position = Vector3(0, 0, 0.006 + i * 0.002)
		var nm := MU.mat(needle_cols[i], 0.4)
		MU.box(nd, Vector3(r * 0.035, r * 0.88, 0.002), Vector3(0, r * 0.36, 0), nm)
		MU.cyl(nd, r * 0.07, 0.004, Vector3.ZERO, MU.mat(Color(0.1, 0.1, 0.1), 0.4), Vector3(90, 0, 0), 10)
		needles.append(nd)
		targets.append(mn)
		shown.append(mn)
		_place(i)
	# glass
	MU.cyl(self, r * 1.0, 0.002, Vector3(0, 0, 0.012), MU.glass(Color(0.8, 0.85, 0.9, 0.08)), Vector3(90, 0, 0), 24)


func _fmt(x: float) -> String:
	if absf(x - roundf(x)) < 0.01:
		return str(int(roundf(x)))
	return "%.1f" % x


func _angle_for(v: float) -> float:
	var t := clampf((v - min_v) / (max_v - min_v), -0.02, 1.02)
	return lerpf(a0, a1, t)


func set_value(i: int, v: float) -> void:
	if i < targets.size():
		targets[i] = v


func _place(i: int) -> void:
	needles[i].rotation_degrees = Vector3(0, 0, _angle_for(shown[i]) - 90.0)


func _process(delta: float) -> void:
	for i in range(needles.size()):
		var d := targets[i] - shown[i]
		if absf(d) > 1e-4:
			shown[i] += d * minf(1.0, damping * delta)
			_place(i)
