class_name TrackBuilder
extends RefCounted
## Rails, sleepers, ballast, formation shoulders, bridges and water troughs.

const CHUNK_LEN := 250.0
const RAIL_X := 0.7535       # rail-head centre offset for 1435 mm gauge

var track: Track
var terrain: TerrainBuilder
var theme := "nsw"


func build(parent: Node3D, t: Track, ter: TerrainBuilder, quality: int) -> void:
	track = t
	terrain = ter
	theme = t.route["theme"]
	var root := Node3D.new()
	root.name = "Track"
	parent.add_child(root)
	var rail_mat := MU.mat(Color(0.36, 0.25, 0.18), 0.85, 0.35, "rail_side")
	var head_mat := MU.mat(Color(0.82, 0.82, 0.84), 0.22, 0.95, "rail_head")
	var ballast_mat := MU.noise_mat(Color(0.36, 0.36, 0.37) if theme == "nsw" else Color(0.33, 0.31, 0.28), 0.25, 3.0, 0.98, "ballast_" + theme)
	var form_mat := ter.terrain_material
	var sleeper_mesh := BoxMesh.new()
	var sleeper_mat: Material
	if theme == "nsw":
		sleeper_mesh.size = Vector3(2.5, 0.2, 0.26)
		sleeper_mat = MU.mat(Color(0.5, 0.49, 0.47), 0.9)
	else:
		sleeper_mesh.size = Vector3(2.6, 0.13, 0.25)
		sleeper_mat = MU.mat(Color(0.24, 0.18, 0.13), 0.95)
	var chair_mesh := BoxMesh.new()
	chair_mesh.size = Vector3(0.17, 0.09, 0.32)
	var clip_mat := MU.mat(Color(0.2, 0.18, 0.17), 0.7, 0.4)
	var rail_profile := _rail_profile()
	var head_profile := PackedVector2Array([Vector2(-0.034, 0.0015), Vector2(0.034, 0.0015)])
	var spacing: float = track.route["sleeper_spacing"]
	var chunks := int(ceil(track.length / CHUNK_LEN))
	for c in range(chunks):
		var s0 := c * CHUNK_LEN
		var s1 := minf(track.length, s0 + CHUNK_LEN)
		var node := Node3D.new()
		node.name = "TC%d" % c
		root.add_child(node)
		var frames_l := []
		var frames_r := []
		var frames_c := []
		var dist := PackedFloat32Array()
		var s := s0
		while true:
			frames_l.append(track.frame_at(s, -RAIL_X))
			frames_r.append(track.frame_at(s, RAIL_X))
			frames_c.append(track.frame_at(s))
			dist.append(s)
			if s >= s1 - 0.001:
				break
			s = minf(s + Track.STEP, s1)
		# rails
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		MU.extrude(rail_profile, frames_l, st, true)
		MU.extrude(rail_profile, frames_r, st, true)
		st.generate_normals()
		_add_mesh(node, st.commit(), rail_mat, "Rails")
		var hst := SurfaceTool.new()
		hst.begin(Mesh.PRIMITIVE_TRIANGLES)
		MU.extrude(head_profile, frames_l, hst)
		MU.extrude(head_profile, frames_r, hst)
		hst.generate_normals()
		_add_mesh(node, hst.commit(), head_mat, "RailHeads")
		# ballast (or bridge deck)
		var bst := SurfaceTool.new()
		bst.begin(Mesh.PRIMITIVE_TRIANGLES)
		MU.extrude(PackedVector2Array([Vector2(-2.7, -0.6), Vector2(-1.85, -0.22), Vector2(1.85, -0.22), Vector2(2.7, -0.6)]), frames_c, bst)
		bst.generate_normals()
		_add_mesh(node, bst.commit(), ballast_mat, "Ballast")
		_formation(node, s0, s1, form_mat)
		# sleepers (+ cast-iron chairs on the 1930s line)
		var sl := []
		var ch := []
		var ss := ceilf(s0 / spacing) * spacing
		while ss < s1:
			var f := track.frame_at(ss)
			sl.append(f.translated_local(Vector3(0, -0.255 if theme == "nsw" else -0.225, 0)))
			if theme == "ecml":
				ch.append(f.translated_local(Vector3(-RAIL_X, -0.13, 0)))
				ch.append(f.translated_local(Vector3(RAIL_X, -0.13, 0)))
			else:
				ch.append(f.translated_local(Vector3(-RAIL_X - 0.06, -0.15, 0)).scaled_local(Vector3(0.35, 0.5, 0.4)))
				ch.append(f.translated_local(Vector3(RAIL_X + 0.06, -0.15, 0)).scaled_local(Vector3(0.35, 0.5, 0.4)))
			ss += spacing
		var mmi := _multimesh(node, sleeper_mesh, sleeper_mat, sl, "Sleepers")
		mmi.visibility_range_end = 900.0 if quality > 0 else 450.0
		var cmi := _multimesh(node, chair_mesh, clip_mat, ch, "Chairs")
		cmi.visibility_range_end = 300.0
	_bridges(root)
	_troughs(root)


func _rail_profile() -> PackedVector2Array:
	# clockwise when looking along the track (Godot front faces are clockwise)
	if theme == "ecml":   # bullhead rail, as used on the LNER main line in 1938
		return PackedVector2Array([Vector2(-0.034, 0), Vector2(0.034, 0), Vector2(0.034, -0.04),
			Vector2(0.011, -0.05), Vector2(0.011, -0.1), Vector2(0.03, -0.11), Vector2(0.03, -0.143),
			Vector2(-0.03, -0.143), Vector2(-0.03, -0.11), Vector2(-0.011, -0.1), Vector2(-0.011, -0.05),
			Vector2(-0.034, -0.04)])
	return PackedVector2Array([Vector2(-0.036, 0), Vector2(0.036, 0), Vector2(0.036, -0.036),
		Vector2(0.009, -0.05), Vector2(0.009, -0.13), Vector2(0.075, -0.148), Vector2(0.075, -0.159),
		Vector2(-0.075, -0.159), Vector2(-0.075, -0.148), Vector2(-0.009, -0.13), Vector2(-0.009, -0.05),
		Vector2(-0.036, -0.036)])


## Cess, cutting and embankment shoulders from the ballast toe out to the terrain.
func _formation(node: Node3D, s0: float, s1: float, mat: Material) -> void:
	var lats := [2.7, 4.5, 7.0, 9.5, 11.0, 12.5, 14.5]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows_l := []
	var rows_r := []
	var cols_l := []
	var cols_r := []
	var s := s0
	var any := false
	while true:
		if not terrain.is_bridge(s):
			any = true
		var f := track.flat_frame_at(s)
		var th := f.origin.y
		var right := f.basis.x
		var left_row := PackedVector3Array()
		var right_row := PackedVector3Array()
		for k in range(lats.size() - 1, -1, -1):
			left_row.append(_shoulder_point(f.origin - right * lats[k], th, lats[k]))
		for k in range(lats.size()):
			right_row.append(_shoulder_point(f.origin + right * lats[k], th, lats[k]))
		cols_l.append(_row_colors(left_row, lats, true))
		cols_r.append(_row_colors(right_row, lats, false))
		rows_l.append(left_row)
		rows_r.append(right_row)
		if s >= s1 - 0.001:
			break
		s = minf(s + Track.STEP * 2.0, s1)
	if not any:
		return
	for side in range(2):
		var rows: Array = rows_l if side == 0 else rows_r
		var cols: Array = cols_l if side == 0 else cols_r
		for r in range(rows.size() - 1):
			var a: PackedVector3Array = rows[r]
			var b: PackedVector3Array = rows[r + 1]
			var ca: PackedColorArray = cols[r]
			var cb: PackedColorArray = cols[r + 1]
			for k in range(a.size() - 1):
				st.set_color(ca[k]); st.add_vertex(a[k])
				st.set_color(cb[k]); st.add_vertex(b[k])
				st.set_color(cb[k + 1]); st.add_vertex(b[k + 1])
				st.set_color(ca[k]); st.add_vertex(a[k])
				st.set_color(cb[k + 1]); st.add_vertex(b[k + 1])
				st.set_color(ca[k + 1]); st.add_vertex(a[k + 1])
	st.generate_normals()
	_add_mesh(node, st.commit(), mat, "Formation")


func _row_colors(row: PackedVector3Array, lats: Array, left: bool) -> PackedColorArray:
	var out := PackedColorArray()
	var m := row.size()
	for k in range(m):
		var lat: float = lats[m - 1 - k] if left else lats[k]
		var k2 := k + 1 if k < m - 1 else k - 1
		var run := absf(float(lats[m - 1 - k2] if left else lats[k2]) - lat)
		var rise := absf(row[k2].y - row[k].y)
		var ny := cos(atan2(rise, maxf(run, 0.01)))
		out.append(terrain.color_at(row[k].x, row[k].z, row[k].y, ny, lat))
	return out


func _shoulder_point(p: Vector3, th: float, d: float) -> Vector3:
	var y := th - 0.6
	if d >= TerrainBuilder.FORM_W:
		y = terrain.shaped(p.x, p.z, d, th, false)
	elif d > 3.0:
		y = th - 0.6 - (d - 3.0) * 0.02        # drainage fall across the cess
	return Vector3(p.x, y, p.z)


func _bridges(root: Node3D) -> void:
	var steel := MU.mat(Color(0.25, 0.27, 0.29) if theme == "nsw" else Color(0.18, 0.18, 0.2), 0.6, 0.6)
	var conc := MU.noise_mat(Color(0.66, 0.62, 0.55) if theme == "nsw" else Color(0.55, 0.42, 0.33), 0.1, 0.5, 0.95, "pier_" + theme)
	var i := 0
	while i < track.n:
		if terrain.bridge[i] == 1:
			var j := i
			while j < track.n and terrain.bridge[j] == 1:
				j += 1
			var s0 := i * Track.STEP - 6.0
			var s1 := j * Track.STEP + 6.0
			var node := Node3D.new()
			node.name = "Bridge_%d" % i
			root.add_child(node)
			# deck girders + parapets
			var frames := []
			var s := s0
			while s <= s1:
				frames.append(track.frame_at(s))
				s += Track.STEP * 2.0
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			MU.extrude(PackedVector2Array([Vector2(-2.9, -0.6), Vector2(2.9, -0.6), Vector2(2.9, -2.3), Vector2(-2.9, -2.3)]), frames, st, true)
			MU.extrude(PackedVector2Array([Vector2(-3.0, 0.7), Vector2(-2.8, 0.7), Vector2(-2.8, -0.6), Vector2(-3.0, -0.6)]), frames, st, true)
			MU.extrude(PackedVector2Array([Vector2(2.8, 0.7), Vector2(3.0, 0.7), Vector2(3.0, -0.6), Vector2(2.8, -0.6)]), frames, st, true)
			st.generate_normals()
			_add_mesh(node, st.commit(), steel, "Deck")
			# piers
			var ps := s0 + 4.0
			while ps <= s1 - 4.0:
				var f := track.flat_frame_at(ps)
				var ground := terrain.height_at(f.origin.x, f.origin.z)
				var top := f.origin.y - 2.3
				var h := top - ground + 2.0
				if h > 1.0:
					MU.box(node, Vector3(4.6, h, 2.2), Vector3(f.origin.x, top - h * 0.5, f.origin.z), conc, Vector3(0, rad_to_deg(track.heading_at(ps)) + 90.0, 0))
				ps += 32.0
			i = j
		else:
			i += 1


func _troughs(root: Node3D) -> void:
	var water := MU.mat(Color(0.3, 0.4, 0.45), 0.05, 0.4)
	var steel := MU.mat(Color(0.28, 0.26, 0.24), 0.7, 0.5)
	for tr in track.route.get("troughs", []):
		var frames := []
		var s: float = tr[0]
		while s <= tr[0] + tr[1]:
			frames.append(track.frame_at(s))
			s += Track.STEP * 2.0
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		MU.extrude(PackedVector2Array([Vector2(-0.3, -0.04), Vector2(-0.26, -0.04), Vector2(-0.26, -0.18), Vector2(0.26, -0.18), Vector2(0.26, -0.04), Vector2(0.3, -0.04), Vector2(0.3, -0.22), Vector2(-0.3, -0.22)]), frames, st, true)
		st.generate_normals()
		var node := Node3D.new()
		node.name = "WaterTroughs"
		root.add_child(node)
		_add_mesh(node, st.commit(), steel, "Trough")
		var wst := SurfaceTool.new()
		wst.begin(Mesh.PRIMITIVE_TRIANGLES)
		MU.extrude(PackedVector2Array([Vector2(-0.26, -0.06), Vector2(0.26, -0.06)]), frames, wst)
		wst.generate_normals()
		_add_mesh(node, wst.commit(), water, "TroughWater")


func _add_mesh(parent: Node3D, mesh: Mesh, mat: Material, nm: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.name = nm
	parent.add_child(mi)
	return mi


func _multimesh(parent: Node3D, mesh: Mesh, mat: Material, xforms: Array, nm: String) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.name = nm
	parent.add_child(mmi)
	return mmi
