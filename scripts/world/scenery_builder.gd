class_name SceneryBuilder
extends RefCounted
## Overhead wiring, telegraph poles, speed boards, distance posts, platforms,
## buildings and fences.

const CONTACT_H := 5.4       # contact wire height above rail (NSW-style)
const MESSENGER_H := 6.6
const SPAN := 55.0

var track: Track
var terrain: TerrainBuilder
var theme := "nsw"
var platform_lights: Array[OmniLight3D] = []


func build(parent: Node3D, t: Track, ter: TerrainBuilder, quality: int) -> void:
	track = t
	terrain = ter
	theme = t.route["theme"]
	var root := Node3D.new()
	root.name = "Scenery"
	parent.add_child(root)
	if t.route.get("electrified", false):
		_overhead(root)
	else:
		_telegraph(root)
	_speed_boards(root)
	_distance_posts(root)
	_platforms(root)
	_buildings(root, quality)
	_trough_boards(root)


# --------------------------------------------------------------- overhead
func _overhead(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Overhead"
	root.add_child(node)
	var mast_mat := MU.mat(Color(0.5, 0.52, 0.5), 0.6, 0.5)
	var wire_mat := MU.mat(Color(0.32, 0.24, 0.16), 0.5, 0.7, "wire")
	var mast_mesh := BoxMesh.new()
	mast_mesh.size = Vector3(0.25, 8.2, 0.25)
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(4.0, 0.08, 0.08)
	var masts := []
	var arms := []
	var contact := []
	var messenger := []
	var droppers := []
	var count := int(track.length / SPAN)
	var span := track.length / count
	for i in range(count):
		var s := i * span
		var k := track.curv_at(s)
		var side := -1.0 if k > 0.0001 else 1.0        # masts on the outside of curves
		var f := track.flat_frame_at(s)
		var ground := f.origin.y - 0.6
		var mpos := f.origin + f.basis.x * (3.4 * side)
		var mb := f.basis
		masts.append(Transform3D(mb, Vector3(mpos.x, ground + 4.1, mpos.z)))
		var arm_c := f.origin + f.basis.x * (1.6 * side)
		arms.append(Transform3D(mb, arm_c + Vector3(0, MESSENGER_H + 0.35, 0)))
		arms.append(Transform3D(mb.scaled(Vector3(0.9, 1, 1)), arm_c + Vector3(0, CONTACT_H + 0.25, 0)))
		# wires to the next mast
		var stag := 0.2 if i % 2 == 0 else -0.2
		var s_next := (i + 1) * span
		var stag_next := -stag
		var subdiv := 6
		for j in range(subdiv):
			var ta := float(j) / subdiv
			var tb := float(j + 1) / subdiv
			var fa := track.frame_at(lerpf(s, s_next, ta))
			var fb := track.frame_at(lerpf(s, s_next, tb))
			var ca := fa.origin + fa.basis.x * lerpf(stag, stag_next, ta) + Vector3.UP * CONTACT_H
			var cb := fb.origin + fb.basis.x * lerpf(stag, stag_next, tb) + Vector3.UP * CONTACT_H
			contact.append([ca, cb])
			var sag_a := 4.0 * ta * (1.0 - ta) * 0.75
			var sag_b := 4.0 * tb * (1.0 - tb) * 0.75
			var ma := fa.origin + Vector3.UP * (MESSENGER_H - sag_a)
			var mb2 := fb.origin + Vector3.UP * (MESSENGER_H - sag_b)
			messenger.append([ma, mb2])
			if j > 0:
				droppers.append([ca + Vector3.UP * 0.02, ma])
	_multimesh(node, mast_mesh, mast_mat, masts)
	_multimesh(node, arm_mesh, mast_mat, arms)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for seg in contact:
		_wire(st, seg[0], seg[1], 0.014)
	for seg in messenger:
		_wire(st, seg[0], seg[1], 0.011)
	for seg in droppers:
		_wire(st, seg[0], seg[1], 0.005)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = wire_mat
	mi.name = "Wires"
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)


## A wire drawn as two crossed thin quads so it reads from any angle.
func _wire(st: SurfaceTool, a: Vector3, b: Vector3, w: float) -> void:
	var dir := (b - a).normalized()
	var side := dir.cross(Vector3.UP).normalized()
	if side.length() < 0.1:
		side = Vector3.RIGHT
	var up := side.cross(dir).normalized()
	for off in [side * w, up * w]:
		st.add_vertex(a - off); st.add_vertex(b - off); st.add_vertex(b + off)
		st.add_vertex(a - off); st.add_vertex(b + off); st.add_vertex(a + off)
		st.add_vertex(a - off); st.add_vertex(b + off); st.add_vertex(b - off)
		st.add_vertex(a - off); st.add_vertex(a + off); st.add_vertex(b + off)


# -------------------------------------------------------------- telegraph
func _telegraph(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Telegraph"
	root.add_child(node)
	var pole_mat := MU.mat(Color(0.26, 0.2, 0.15), 0.95)
	var wire_mat := MU.mat(Color(0.12, 0.12, 0.12), 0.6, 0.3, "twire")
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.09
	pole_mesh.bottom_radius = 0.13
	pole_mesh.height = 8.0
	pole_mesh.radial_segments = 6
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(1.7, 0.09, 0.09)
	var poles := []
	var arms := []
	var tops := []
	var lat := -7.5
	var spacing := 55.0
	var count := int(track.length / spacing)
	spacing = track.length / count
	for i in range(count):
		var s := i * spacing
		var f := track.flat_frame_at(s, lat)
		var ground := terrain.height_at(f.origin.x, f.origin.z)
		if terrain.is_bridge(s):
			ground = f.origin.y - 0.6
		poles.append(Transform3D(f.basis, Vector3(f.origin.x, ground + 3.8, f.origin.z)))
		var row := []
		for a in range(3):
			var ay := ground + 7.4 - a * 0.55
			arms.append(Transform3D(f.basis, Vector3(f.origin.x, ay, f.origin.z)))
			for wx in [-0.7, -0.35, 0.35, 0.7]:
				row.append(Vector3(f.origin.x, ay + 0.08, f.origin.z) + f.basis.x * wx)
		tops.append(row)
	_multimesh(node, pole_mesh, pole_mat, poles)
	_multimesh(node, arm_mesh, pole_mat, arms)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(tops.size()):
		var a: Array = tops[i]
		var b: Array = tops[(i + 1) % tops.size()]
		for w in range(a.size()):
			var p0: Vector3 = a[w]
			var p1: Vector3 = b[w]
			var steps := 4
			var prev := p0
			for k in range(1, steps + 1):
				var t := float(k) / steps
				var p := p0.lerp(p1, t) - Vector3.UP * (4.0 * t * (1.0 - t) * 0.45)
				_wire(st, prev, p, 0.008)
				prev = p
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = wire_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "TelegraphWires"
	node.add_child(mi)


# ---------------------------------------------------------- speed boards
func _speed_boards(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "SpeedBoards"
	root.add_child(node)
	var post := MU.mat(Color(0.75, 0.75, 0.72), 0.6, 0.3)
	var face := MU.mat(Color(0.97, 0.97, 0.95), 0.6)
	var back := MU.mat(Color(0.2, 0.2, 0.2), 0.8)
	var imperial: bool = track.route["units"] == "imperial"
	for ch in track.limit_changes():
		var s: float = ch[0]
		var v: float = ch[1]
		var f := track.flat_frame_at(s, -2.9)
		var b := Node3D.new()
		node.add_child(b)
		b.transform = f
		MU.box(b, Vector3(0.09, 2.6, 0.09), Vector3(0, 1.0 - 0.6, 0), post)
		var txt := "%d" % int(round(v / 1.609344 / 5.0) * 5.0) if imperial else "%d" % int(v)
		if imperial:
			# 1930s cast "speed restriction" sign: black on white, mph
			MU.box(b, Vector3(0.95, 0.75, 0.05), Vector3(0, 2.0, 0), face)
			MU.box(b, Vector3(0.97, 0.77, 0.03), Vector3(0, 2.0, -0.03), back)
			MU.label(b, txt, Vector3(0, 2.02, 0.03), 0.006, Color(0.05, 0.05, 0.05), Vector3(0, 0, 0), 96)
		else:
			# NSW-style: black numerals on a white board
			MU.box(b, Vector3(0.8, 0.8, 0.05), Vector3(0, 2.1, 0), face)
			MU.box(b, Vector3(0.84, 0.84, 0.03), Vector3(0, 2.1, -0.03), back)
			MU.label(b, txt, Vector3(0, 2.1, 0.03), 0.007, Color(0.02, 0.02, 0.02), Vector3(0, 0, 0), 96)


func _distance_posts(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "DistancePosts"
	root.add_child(node)
	var white := MU.mat(Color(0.92, 0.92, 0.9), 0.6)
	var black := Color(0.05, 0.05, 0.05)
	if track.route["units"] == "imperial":
		var start: float = track.route.get("mile_post_start", 0.0)
		var quarter := 1609.344 / 4.0
		var q := 0
		while q * quarter < track.length:
			var s := q * quarter
			var f := track.flat_frame_at(s, -2.6)
			var p := Node3D.new()
			node.add_child(p)
			p.transform = f
			var miles := start + q * 0.25
			MU.box(p, Vector3(0.12, 1.1, 0.12), Vector3(0, -0.05, 0), white)
			if q % 4 == 0:
				MU.box(p, Vector3(0.5, 0.45, 0.05), Vector3(0, 0.65, 0), white)
				MU.label(p, "%d" % int(miles), Vector3(0, 0.65, 0.03), 0.004, black, Vector3.ZERO, 64)
			else:
				var frac: String = ["", "1/4", "1/2", "3/4"][q % 4]
				MU.box(p, Vector3(0.4, 0.3, 0.05), Vector3(0, 0.6, 0), white)
				MU.label(p, frac, Vector3(0, 0.6, 0.03), 0.003, black, Vector3.ZERO, 64)
			q += 1
	else:
		var start_km: float = track.route.get("km_post_start", 0.0)
		var k := 0
		while k * 500.0 < track.length:
			var s := k * 500.0
			var f := track.flat_frame_at(s, -2.7)
			var p := Node3D.new()
			node.add_child(p)
			p.transform = f
			MU.box(p, Vector3(0.1, 1.2, 0.1), Vector3(0, 0.0, 0), white)
			MU.box(p, Vector3(0.42, 0.22, 0.04), Vector3(0, 0.7, 0), white)
			MU.label(p, "%.3f" % (start_km + s / 1000.0), Vector3(0, 0.7, 0.025), 0.0022, black, Vector3.ZERO, 64)
			k += 1


# -------------------------------------------------------------- platforms
func _platforms(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Platforms"
	root.add_child(node)
	var conc := MU.noise_mat(Color(0.47, 0.46, 0.43) if theme == "nsw" else Color(0.5, 0.42, 0.36), 0.1, 0.6, 0.92, "platform_" + theme)
	var edge := MU.mat(Color(0.95, 0.85, 0.15), 0.7) if theme == "nsw" else MU.mat(Color(0.92, 0.92, 0.88), 0.7)
	var roof := MU.mat(Color(0.3, 0.33, 0.36), 0.6, 0.4) if theme == "nsw" else MU.mat(Color(0.35, 0.2, 0.14), 0.8)
	var name_txt := "WATTLE GULLY" if theme == "nsw" else "CORBY GLEN"
	for pl in track.route.get("platforms", []):
		var s0: float = pl[0]
		var plen: float = pl[1]
		var side: float = pl[2]
		var top := 1.05 if theme == "nsw" else 0.92
		var edge_x := 1.62 if theme == "nsw" else 1.48
		var depth := 5.0
		var frames := []
		var s := s0
		while s <= s0 + plen:
			frames.append(track.flat_frame_at(s))
			s += 4.0
		var a := edge_x * side
		var b := (edge_x + depth) * side
		var lo := minf(a, b)
		var hi := maxf(a, b)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		MU.extrude(PackedVector2Array([Vector2(lo, top), Vector2(hi, top), Vector2(hi, -1.2), Vector2(lo, -1.2)]), frames, st, true)
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = conc
		node.add_child(mi)
		var est := SurfaceTool.new()
		est.begin(Mesh.PRIMITIVE_TRIANGLES)
		var ex0 := edge_x * side
		var ex1 := (edge_x + 0.45) * side
		MU.extrude(PackedVector2Array([Vector2(minf(ex0, ex1), top + 0.005), Vector2(maxf(ex0, ex1), top + 0.005)]), frames, est)
		est.generate_normals()
		var emi := MeshInstance3D.new()
		emi.mesh = est.commit()
		emi.material_override = edge
		node.add_child(emi)
		# shelter, lamps and name boards
		var mid := s0 + plen * 0.5
		var fm := track.flat_frame_at(mid, (edge_x + 3.2) * side)
		var shelter := Node3D.new()
		node.add_child(shelter)
		shelter.transform = fm
		shelter.position.y += top
		for zz in [-6.0, 6.0]:
			for xx in [-1.0, 1.0]:
				MU.box(shelter, Vector3(0.12, 2.8, 0.12), Vector3(xx, 1.4, zz), MU.mat(Color(0.2, 0.25, 0.3), 0.5, 0.6))
		MU.box(shelter, Vector3(2.8, 0.12, 13.0), Vector3(0, 2.85, 0), roof)
		MU.box(shelter, Vector3(0.6, 0.45, 4.0), Vector3(0, 0.45, 0), MU.mat(Color(0.4, 0.3, 0.22), 0.8))
		for k in range(5):
			var ls := s0 + 20.0 + k * (plen - 40.0) / 4.0
			var lf := track.flat_frame_at(ls, (edge_x + 2.2) * side)
			var lamp := Node3D.new()
			node.add_child(lamp)
			lamp.transform = lf
			lamp.position.y += top
			MU.box(lamp, Vector3(0.1, 4.0, 0.1), Vector3(0, 2.0, 0), MU.mat(Color(0.18, 0.2, 0.18), 0.5, 0.5))
			MU.box(lamp, Vector3(0.35, 0.18, 0.35), Vector3(0, 4.05, 0), MU.lamp(Color(1.0, 0.85, 0.6), 0.0))
			var ol := OmniLight3D.new()
			ol.light_color = Color(1.0, 0.82, 0.55)
			ol.omni_range = 14.0
			ol.light_energy = 0.0
			ol.shadow_enabled = false
			lamp.add_child(ol)
			ol.position = Vector3(0, 3.8, 0)
			platform_lights.append(ol)
			if k == 1 or k == 3:
				var nb := Node3D.new()
				lamp.add_child(nb)
				nb.position = Vector3(0, 2.6, 0)
				nb.rotation_degrees = Vector3(0, 90, 0)
				var board_col := Color(0.1, 0.2, 0.45) if theme == "nsw" else Color(0.1, 0.25, 0.55)
				MU.box(nb, Vector3(2.6, 0.45, 0.05), Vector3.ZERO, MU.mat(board_col, 0.6))
				MU.label(nb, name_txt, Vector3(0, 0, 0.03), 0.0032, Color.WHITE, Vector3.ZERO, 64)
				MU.label(nb, name_txt, Vector3(0, 0, -0.03), 0.0032, Color.WHITE, Vector3(0, 180, 0), 64)


func set_night_lights(on: bool) -> void:
	for l in platform_lights:
		l.light_energy = 2.0 if on else 0.0
		var lamp_mesh := l.get_parent().get_child(1) as MeshInstance3D
		if lamp_mesh and lamp_mesh.material_override is StandardMaterial3D:
			(lamp_mesh.material_override as StandardMaterial3D).emission_energy_multiplier = 3.0 if on else 0.0


# --------------------------------------------------------------- buildings
func _buildings(root: Node3D, quality: int) -> void:
	var node := Node3D.new()
	node.name = "Buildings"
	root.add_child(node)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var count: int = [10, 22, 40][quality]
	var wall_cols := [Color(0.85, 0.82, 0.74), Color(0.62, 0.38, 0.3), Color(0.78, 0.72, 0.6)] if theme == "nsw" else [Color(0.62, 0.32, 0.24), Color(0.7, 0.62, 0.5), Color(0.55, 0.3, 0.22)]
	var roof_cols := [Color(0.35, 0.36, 0.38), Color(0.55, 0.25, 0.18)] if theme == "nsw" else [Color(0.25, 0.22, 0.22), Color(0.45, 0.22, 0.16)]
	var placed := 0
	var tries := 0
	while placed < count and tries < count * 20:
		tries += 1
		var s := rng.randf() * track.length
		var lat := rng.randf_range(35.0, 260.0) * (1.0 if rng.randf() > 0.5 else -1.0)
		var f := track.flat_frame_at(s, lat)
		terrain.query(f.origin.x, f.origin.z)
		if terrain.q_d < 25.0:
			continue
		var h := terrain.height_at(f.origin.x, f.origin.z)
		if h < terrain.water_y + 1.5:
			continue
		var house := Node3D.new()
		node.add_child(house)
		house.position = Vector3(f.origin.x, h, f.origin.z)
		house.rotation.y = track.heading_at(s) + rng.randf_range(-0.3, 0.3)
		var w := rng.randf_range(7.0, 12.0)
		var d := rng.randf_range(6.0, 9.0)
		var hh := rng.randf_range(3.0, 5.5)
		MU.box(house, Vector3(w, hh + 2.0, d), Vector3(0, (hh + 2.0) * 0.5 - 2.0, 0), MU.mat(wall_cols[rng.randi() % wall_cols.size()], 0.85))
		var roof := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(w + 0.6, 2.4, d + 0.6)
		roof.mesh = pm
		roof.material_override = MU.mat(roof_cols[rng.randi() % roof_cols.size()], 0.75)
		house.add_child(roof)
		roof.position = Vector3(0, hh + 1.2, 0)
		roof.rotation_degrees = Vector3(0, 90, 0) if rng.randf() > 0.5 else Vector3.ZERO
		MU.box(house, Vector3(0.7, 1.6, 0.7), Vector3(w * 0.3, hh + 2.0, d * 0.2), MU.mat(Color(0.5, 0.3, 0.25), 0.9))
		placed += 1


func _trough_boards(root: Node3D) -> void:
	for tr in track.route.get("troughs", []):
		for s in [tr[0] - 400.0, tr[0]]:
			var f := track.flat_frame_at(s, -2.8)
			var b := Node3D.new()
			root.add_child(b)
			b.transform = f
			MU.box(b, Vector3(0.1, 2.6, 0.1), Vector3(0, 0.6, 0), MU.mat(Color(0.2, 0.2, 0.2), 0.8))
			MU.box(b, Vector3(1.4, 0.5, 0.05), Vector3(0, 1.9, 0), MU.mat(Color(0.95, 0.95, 0.92), 0.7))
			MU.label(b, "WATER TROUGHS" if s < tr[0] else "TROUGHS", Vector3(0, 1.9, 0.03), 0.0022, Color(0.05, 0.05, 0.05), Vector3.ZERO, 64)


func _multimesh(parent: Node3D, mesh: Mesh, mat: Material, xforms: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	parent.add_child(mmi)
	return mmi
