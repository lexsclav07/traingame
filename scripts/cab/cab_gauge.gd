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
var face_style := "steam"
var face_extra := ""
var _p := {}
var _fallback: Array[Node] = []


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
	_p = {"face": face_col, "min": mn, "max": mx, "major": major, "minor": minor, "num_div": num_div, "red": red_from, "title": label_txt, "unit": unit_txt}
	face_mat = StandardMaterial3D.new()
	face_mat.albedo_color = face_col
	face_mat.roughness = 0.45
	face_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var face := MeshInstance3D.new()
	face.mesh = _disc(r)
	face.material_override = face_mat
	face.name = "Face"
	add_child(face)
	face.position = Vector3(0, 0, 0.0005)
	MU.cyl(self, r * 1.04, 0.012, Vector3(0, 0, -0.006), MU.mat(bezel_col.darkened(0.3), 0.4, 0.7), Vector3(90, 0, 0), 32)
	MU.torus(self, r * 0.98, r * 1.12, Vector3(0, 0, 0.0), MU.mat(bezel_col, 0.22, 0.85), Vector3(90, 0, 0))
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
			_fallback.append(lab)
		v += minor
	var tm := StandardMaterial3D.new()
	tm.vertex_color_use_as_albedo = true
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var ticks := MeshInstance3D.new()
	ticks.mesh = st.commit()
	ticks.material_override = tm
	add_child(ticks)
	_fallback.append(ticks)
	_fallback.append(MU.label(self, label_txt, Vector3(0, -r * 0.42, 0.003), r * 0.0022, Color(0.1, 0.1, 0.1), Vector3.ZERO, 32))
	if unit_txt != "":
		_fallback.append(MU.label(self, unit_txt, Vector3(0, r * 0.3, 0.003), r * 0.0018, Color(0.25, 0.25, 0.25), Vector3.ZERO, 32))
	for i in range(needle_cols.size()):
		var nd := Node3D.new()
		add_child(nd)
		nd.position = Vector3(0, 0, 0.006 + i * 0.002)
		var nm := MU.mat(needle_cols[i], 0.35, 0.2)
		var needle := MeshInstance3D.new()
		needle.mesh = _needle_mesh(r)
		needle.material_override = nm
		nd.add_child(needle)
		MU.cyl(nd, r * 0.075, 0.005, Vector3.ZERO, MU.mat(needle_cols[i].darkened(0.2), 0.3, 0.5), Vector3(90, 0, 0), 12)
		needles.append(nd)
		targets.append(mn)
		shown.append(mn)
		_place(i)
	# glass
	var gm := MU.glass(Color(0.8, 0.85, 0.9, 0.06))
	MU.cyl(self, r * 1.0, 0.002, Vector3(0, 0, 0.012), gm, Vector3(90, 0, 0), 24)


func _ready() -> void:
	_bake_face()


## Flat disc facing +Z with UVs mapping the unit square onto it.
func _disc(r: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3(0, 0, 1))
	var n := 48
	for i in range(n):
		var a0r := TAU * i / n
		var a1r := TAU * (i + 1) / n
		var p0 := Vector2(cos(a0r), sin(a0r))
		var p1 := Vector2(cos(a1r), sin(a1r))
		st.set_uv(Vector2(0.5, 0.5)); st.add_vertex(Vector3.ZERO)
		st.set_uv(Vector2(0.5 + p1.x * 0.5, 0.5 - p1.y * 0.5)); st.add_vertex(Vector3(p1.x * r, p1.y * r, 0))
		st.set_uv(Vector2(0.5 + p0.x * 0.5, 0.5 - p0.y * 0.5)); st.add_vertex(Vector3(p0.x * r, p0.y * r, 0))
	st.generate_tangents()
	return st.commit()


## Tapered pointer with a short tail, lying along +Y.
func _needle_mesh(r: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3(0, 0, 1))
	var tip := Vector3(0, r * 0.84, 0)
	var bl := Vector3(-r * 0.03, 0, 0)
	var br := Vector3(r * 0.03, 0, 0)
	var tl := Vector3(-r * 0.045, -r * 0.2, 0)
	var tr := Vector3(r * 0.045, -r * 0.2, 0)
	for tri in [[bl, tip, br], [tl, bl, br], [tl, br, tr]]:
		for p in tri:
			st.add_vertex(p)
	return st.commit()


## Draw the face into a SubViewport, then keep it as a mipmapped texture.
func _bake_face() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var px := 512 if radius > 0.06 else 384
	var vp := SubViewport.new()
	vp.size = Vector2i(px, px)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var f := GaugeFace.new()
	f.size = Vector2(px, px)
	f.face_col = _p["face"]
	f.ink = Color(0.92, 0.92, 0.9) if (_p["face"] as Color).get_luminance() < 0.4 else Color(0.06, 0.06, 0.06)
	f.min_v = _p["min"]
	f.max_v = _p["max"]
	f.major = _p["major"]
	f.minor = _p["minor"]
	f.num_div = _p["num_div"]
	f.red_from = _p["red"]
	f.a0 = a0
	f.a1 = a1
	f.title = _p["title"]
	f.unit = _p["unit"]
	f.extra = face_extra
	f.style = face_style
	vp.add_child(f)
	add_child(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	if img != null and not img.is_empty():
		img.generate_mipmaps()
		face_mat.albedo_texture = ImageTexture.create_from_image(img)
		face_mat.albedo_color = Color.WHITE
		for n in _fallback:
			if is_instance_valid(n):
				n.queue_free()
		_fallback.clear()
	vp.queue_free()


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
