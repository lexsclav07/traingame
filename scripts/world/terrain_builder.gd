class_name TerrainBuilder
extends RefCounted
## Builds chunked terrain around the track. Near the line the ground is shaped
## into a proper formation with cuttings and embankments (steep sandstone faces
## on the NSW route); where the line is high above a valley it becomes a bridge.

const CELL := 5.0            # corridor lookup grid resolution
const R_STAMP := 160.0       # how far the railway shapes the land
const NEAR_RES := 10.0
const FAR_RES := 40.0
const CHUNK := 640.0
const FORM_W := 11.0         # half width of the flat formation (under the ribbon mesh)
const MARGIN := 2600.0
const BRIDGE_FILL := 13.0    # fill deeper than this -> bridge instead of embankment

var track: Track
var route: Dictionary
var theme := "nsw"
var amp := 40.0
var area := Rect2()
const TILE := 64               # corridor cells per sparse tile side
var tiles_x := 0
var tiles := {}                # tile index -> offset into the corridor arrays
var corr_d := PackedFloat32Array()
var corr_h := PackedFloat32Array()
var corr_br := PackedByteArray()
var q_d := 0.0                 # results of the last corridor query
var q_h := 0.0
var q_br := false
var chunk_near := PackedByteArray()
var chunks_x := 0
var chunks_z := 0
var ref_cell := 300.0
var ref_w := 0
var ref_h := 0
var ref_vals := PackedFloat32Array()
var bridge := PackedByteArray()   # per track sample
var water_y := -10.0
var cut_slope := 0.6
var fill_slope := 1.6
var n_big := FastNoiseLite.new()
var n_small := FastNoiseLite.new()
var n_patch := FastNoiseLite.new()


func setup(t: Track, r: Dictionary) -> void:
	track = t
	route = r
	theme = r["theme"]
	amp = r["terrain_amp"]
	water_y = r["water_level"]
	cut_slope = 0.55 if theme == "nsw" else 1.4
	fill_slope = 1.6 if theme == "nsw" else 2.0
	n_big.seed = 1938 if theme == "ecml" else 2019
	n_big.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_big.frequency = 1.0 / (1400.0 if theme == "nsw" else 2600.0)
	n_big.fractal_type = FastNoiseLite.FRACTAL_FBM
	n_big.fractal_octaves = 4
	n_small.seed = n_big.seed + 7
	n_small.frequency = 1.0 / 120.0
	n_small.fractal_octaves = 2
	n_patch.seed = n_big.seed + 13
	n_patch.noise_type = FastNoiseLite.TYPE_CELLULAR
	n_patch.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	n_patch.frequency = 1.0 / 260.0
	area = t.bounds.grow(MARGIN)
	_build_ref()
	_mark_bridges()
	_stamp_corridor()


# ---------------------------------------------------------- natural ground
func _build_ref() -> void:
	ref_w = int(area.size.x / ref_cell) + 2
	ref_h = int(area.size.y / ref_cell) + 2
	ref_vals.resize(ref_w * ref_h)
	var samples := []
	var stride := int(150.0 / Track.STEP)
	for i in range(0, track.n, stride):
		samples.append(Vector3(track.px[i], track.py[i], track.pz[i]))
	var mean := 0.0
	for s in samples:
		mean += s.y
	mean /= samples.size()
	for gz in range(ref_h):
		for gx in range(ref_w):
			var x := area.position.x + gx * ref_cell
			var z := area.position.y + gz * ref_cell
			var wsum := 0.01
			var hsum := mean * 0.01
			for s in samples:
				var dx: float = s.x - x
				var dz: float = s.z - z
				var w := 1.0 / (dx * dx + dz * dz + 40000.0)
				w = w * w * 1e12
				wsum += w
				hsum += w * s.y
			ref_vals[gz * ref_w + gx] = hsum / wsum


func _ref(x: float, z: float) -> float:
	var fx := clampf((x - area.position.x) / ref_cell, 0.0, ref_w - 1.001)
	var fz := clampf((z - area.position.y) / ref_cell, 0.0, ref_h - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var a := lerpf(ref_vals[iz * ref_w + ix], ref_vals[iz * ref_w + ix + 1], tx)
	var b := lerpf(ref_vals[(iz + 1) * ref_w + ix], ref_vals[(iz + 1) * ref_w + ix + 1], tx)
	return lerpf(a, b, tz)


## Natural ground height. Relief is softened near the line (railways follow the land).
func nat(x: float, z: float, d: float) -> float:
	var f := 0.35 + 0.65 * smoothstep(15.0, R_STAMP, d)
	var big := n_big.get_noise_2d(x, z)
	if theme == "nsw":
		big = big * 1.25 - 0.12          # deeper gullies -> creeks and the river
	return _ref(x, z) + amp * big * f + n_small.get_noise_2d(x, z) * (2.5 if theme == "nsw" else 1.2)


# ------------------------------------------------------------- the railway
func _mark_bridges() -> void:
	bridge.resize(track.n)
	for i in range(track.n):
		var fill: float = track.py[i] - nat(track.px[i], track.pz[i], 0.0)
		bridge[i] = 1 if fill > BRIDGE_FILL else 0
	# close short gaps, drop very short bridges
	_morph(bridge, 1, 20)
	_morph(bridge, 0, 12)


func _morph(arr: PackedByteArray, fill_val: int, max_run: int) -> void:
	# replace runs of (1 - fill_val) shorter than max_run that sit between fill_val
	var other := 1 - fill_val
	var i := 0
	while i < arr.size():
		if arr[i] == other:
			var j := i
			while j < arr.size() and arr[j] == other:
				j += 1
			if j - i < max_run and i > 0 and j < arr.size():
				for k in range(i, j):
					arr[k] = fill_val
			i = j
		else:
			i += 1


func is_bridge(s: float) -> bool:
	return bridge[int(track.wrap_s(s) / Track.STEP) % track.n] == 1


func _stamp_corridor() -> void:
	tiles_x = int(area.size.x / (CELL * TILE)) + 1
	chunks_x = int(ceil(area.size.x / CHUNK))
	chunks_z = int(ceil(area.size.y / CHUNK))
	chunk_near.resize(chunks_x * chunks_z)
	chunk_near.fill(0)
	var ox := area.position.x
	var oz := area.position.y
	for i in range(0, track.n, 2):
		var h: float = track.heading[i]
		var sx := sin(h)
		var cz := cos(h)
		var bx: float = track.px[i]
		var bz: float = track.pz[i]
		var th: float = track.py[i]
		var br: int = bridge[i]
		var lat := -R_STAMP
		while lat <= R_STAMP:
			var cx := int((bx + sx * lat - ox) / CELL)
			var cy := int((bz + cz * lat - oz) / CELL)
			if cx >= 0 and cy >= 0:
				var key := (cy / TILE) * tiles_x + (cx / TILE)
				var off: int = tiles.get(key, -1)
				if off < 0:
					off = corr_d.size()
					tiles[key] = off
					corr_d.resize(off + TILE * TILE)
					corr_h.resize(off + TILE * TILE)
					corr_br.resize(off + TILE * TILE)
					for k in range(off, off + TILE * TILE):
						corr_d[k] = 1e9
				var li := off + (cy % TILE) * TILE + (cx % TILE)
				var a := absf(lat)
				if a < corr_d[li]:
					corr_d[li] = a
					corr_h[li] = th
					corr_br[li] = br
			lat += 4.0
		var ci := int((bx - ox) / CHUNK)
		var cj := int((bz - oz) / CHUNK)
		for dj in range(-1, 2):
			for di in range(-1, 2):
				var a2 := ci + di
				var b2 := cj + dj
				if a2 >= 0 and b2 >= 0 and a2 < chunks_x and b2 < chunks_z:
					var cxw := ox + (a2 + 0.5) * CHUNK
					var czw := oz + (b2 + 0.5) * CHUNK
					if absf(cxw - bx) < CHUNK * 0.5 + R_STAMP and absf(czw - bz) < CHUNK * 0.5 + R_STAMP:
						chunk_near[b2 * chunks_x + a2] = 1


## Sets q_d (distance to line, R_STAMP if far), q_h (line height), q_br (bridge).
func query(x: float, z: float) -> void:
	q_d = R_STAMP
	q_h = 0.0
	q_br = false
	var cx := int((x - area.position.x) / CELL)
	var cy := int((z - area.position.y) / CELL)
	if cx < 0 or cy < 0:
		return
	var off: int = tiles.get((cy / TILE) * tiles_x + (cx / TILE), -1)
	if off < 0:
		return
	var li := off + (cy % TILE) * TILE + (cx % TILE)
	var d := corr_d[li]
	if d < R_STAMP:
		q_d = d
		q_h = corr_h[li]
		q_br = corr_br[li] == 1


func shaped(x: float, z: float, d: float, th: float, br: bool) -> float:
	var nh := nat(x, z, d)
	if d >= R_STAMP or (br and d > 3.0):
		return nh
	if d < FORM_W:
		return th - 2.2
	var base := th - 0.55
	var e := d - FORM_W
	return base + clampf(nh - base, -e / fill_slope, e / cut_slope)


func height_at(x: float, z: float) -> float:
	query(x, z)
	return shaped(x, z, q_d, q_h, q_br)


# ---------------------------------------------------------------- meshing
var terrain_material: StandardMaterial3D


func color_at(x: float, z: float, h: float, ny: float, d: float) -> Color:
	return _color(x, z, h, ny, d)


func build(parent: Node3D, quality: int) -> void:
	terrain_material = _terrain_material()
	var mat := terrain_material
	var root := Node3D.new()
	root.name = "Terrain"
	parent.add_child(root)
	for cj in range(chunks_z):
		for ci in range(chunks_x):
			var near := chunk_near[cj * chunks_x + ci] == 1
			var res := NEAR_RES if near else FAR_RES
			if quality == 0 and near:
				res = 16.0
			var mi := _chunk(ci, cj, res, mat)
			root.add_child(mi)
	var water := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = area.size
	water.mesh = pm
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.12, 0.25, 0.28) if theme == "nsw" else Color(0.18, 0.24, 0.26)
	wm.roughness = 0.08
	wm.metallic = 0.35
	water.material_override = wm
	water.position = Vector3(area.get_center().x, water_y, area.get_center().y)
	water.name = "Water"
	root.add_child(water)


func _chunk(ci: int, cj: int, res: float, mat: Material) -> MeshInstance3D:
	var cells := int(CHUNK / res)
	var ox := area.position.x + ci * CHUNK
	var oz := area.position.y + cj * CHUNK
	var g := cells + 3           # one extra ring of heights for normals
	var hs := PackedFloat32Array()
	hs.resize(g * g)
	var ds := PackedFloat32Array()
	ds.resize(g * g)
	for j in range(g):
		for i in range(g):
			var x := ox + (i - 1) * res
			var z := oz + (j - 1) * res
			query(x, z)
			hs[j * g + i] = shaped(x, z, q_d, q_h, q_br)
			ds[j * g + i] = q_d
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var vn := cells + 1
	for j in range(vn):
		for i in range(vn):
			var gi := (j + 1) * g + (i + 1)
			var x := ox + i * res
			var z := oz + j * res
			var h := hs[gi]
			verts.append(Vector3(x, h, z))
			var nrm := Vector3(hs[gi - 1] - hs[gi + 1], 2.0 * res, hs[gi - g] - hs[gi + g]).normalized()
			norms.append(nrm)
			cols.append(_color(x, z, h, nrm.y, ds[gi]))
	for j in range(cells):
		for i in range(cells):
			var a := j * vn + i
			idx.append_array([a, a + 1, a + vn, a + 1, a + vn + 1, a + vn])
	# skirts hide cracks between near / far chunks
	var edges := [[0, 0, 1, 0], [cells, 0, 0, 1], [cells, cells, -1, 0], [0, cells, 0, -1]]
	for e in edges:
		var si: int = e[0]
		var sj: int = e[1]
		for k in range(cells):
			var i0: int = si + e[2] * k
			var j0: int = sj + e[3] * k
			var i1: int = i0 + e[2]
			var j1: int = j0 + e[3]
			var a: int = j0 * vn + i0
			var b: int = j1 * vn + i1
			var base := verts.size()
			verts.append(verts[a] - Vector3(0, 25, 0)); norms.append(norms[a]); cols.append(cols[a])
			verts.append(verts[b] - Vector3(0, 25, 0)); norms.append(norms[b]); cols.append(cols[b])
			idx.append_array([a, base, b, b, base, base + 1])
			idx.append_array([a, b, base, b, base + 1, base])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.material_override = mat
	mi.name = "T_%d_%d" % [ci, cj]
	return mi


func _color(x: float, z: float, h: float, ny: float, d: float) -> Color:
	var p := n_patch.get_noise_2d(x, z)
	var fine := n_small.get_noise_2d(x * 3.0, z * 3.0)
	var c: Color
	if theme == "nsw":
		var grass := Color(0.47, 0.45, 0.27).lerp(Color(0.36, 0.38, 0.2), p * 0.5 + 0.5)
		var litter := Color(0.38, 0.31, 0.22)
		c = grass.lerp(litter, clampf(fine * 0.8 + 0.3, 0.0, 1.0))
		var rock := Color(0.74, 0.55, 0.36).lerp(Color(0.62, 0.43, 0.3), fine * 0.5 + 0.5)
		c = c.lerp(rock, smoothstep(0.86, 0.6, ny))
	else:
		var fields := [Color(0.33, 0.47, 0.2), Color(0.42, 0.53, 0.24), Color(0.72, 0.64, 0.36),
			Color(0.45, 0.36, 0.25), Color(0.3, 0.42, 0.18)]
		var fi := int((p * 0.5 + 0.5) * 4.99)
		c = (fields[fi] as Color).lerp(Color(0.3, 0.42, 0.2), 0.15 + fine * 0.1)
		c = c.lerp(Color(0.45, 0.4, 0.3), smoothstep(0.8, 0.55, ny))
	# beaches / mud near water
	c = c.lerp(Color(0.55, 0.5, 0.38), smoothstep(water_y + 2.5, water_y + 0.2, h))
	# cess and formation: trampled ash / gravel
	c = c.lerp(Color(0.42, 0.39, 0.34), smoothstep(16.0, 9.0, d))
	return c


func _terrain_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	var nt := NoiseTexture2D.new()
	var fn := FastNoiseLite.new()
	fn.frequency = 0.05
	fn.fractal_octaves = 4
	nt.noise = fn
	nt.seamless = true
	nt.width = 512
	nt.height = 512
	var grad := Gradient.new()
	grad.set_color(0, Color(0.72, 0.72, 0.72))
	grad.set_color(1, Color(1.18, 1.18, 1.18))
	nt.color_ramp = grad
	m.albedo_texture = nt
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * 0.08
	m.roughness = 0.97
	return m


# ------------------------------------------------------------------ trees
func scatter_trees(parent: Node3D, quality: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var count: int = [2500, 6000, 11000][quality] if theme == "nsw" else [1500, 3500, 6500][quality]
	var trunks := []
	var crowns := []
	var tries: int = count * 4
	var center := track.bounds.get_center()
	var reach := track.bounds.grow(1600.0)
	while tries > 0 and trunks.size() < count:
		tries -= 1
		var x: float
		var z: float
		if rng.randf() < 0.8:
			# most trees within sight of the line
			var ts := rng.randf() * track.length
			var lat := (22.0 + pow(rng.randf(), 2.0) * 700.0) * (1.0 if rng.randf() < 0.5 else -1.0)
			var fr := track.flat_frame_at(ts, lat)
			x = fr.origin.x
			z = fr.origin.z
		else:
			x = rng.randf_range(reach.position.x, reach.end.x)
			z = rng.randf_range(reach.position.y, reach.end.y)
		query(x, z)
		if q_d < 18.0:
			continue
		if theme == "ecml":
			# English trees grow in hedgerows and copses
			var clump := n_patch.get_noise_2d(x * 2.3, z * 2.3)
			if clump < 0.25 and rng.randf() > 0.15:
				continue
		var h := shaped(x, z, q_d, q_h, q_br)
		if h < water_y + 0.8:
			continue
		var sc := rng.randf_range(0.7, 1.35)
		var rot := rng.randf() * TAU
		var t := Transform3D(Basis(Vector3.UP, rot).scaled(Vector3.ONE * sc), Vector3(x, h - 0.2, z))
		trunks.append(t)
		crowns.append(t)
	var trunk_mesh: Mesh
	var crown_mesh: Mesh
	var trunk_mat: StandardMaterial3D
	var crown_mat: StandardMaterial3D
	if theme == "nsw":
		trunk_mesh = _cyl_mesh(0.25, 0.12, 12.0)
		trunk_mat = MU.mat(Color(0.7, 0.66, 0.6), 0.9)        # pale gum bark
		crown_mesh = _crown_mesh(5.0, 5.0, 9.5, true)
		crown_mat = MU.mat(Color(0.36, 0.42, 0.3), 0.95)      # grey-green eucalypt leaves
	else:
		trunk_mesh = _cyl_mesh(0.35, 0.22, 6.0)
		trunk_mat = MU.mat(Color(0.3, 0.25, 0.2), 0.95)
		crown_mesh = _crown_mesh(5.0, 4.6, 8.5, false)
		crown_mat = MU.mat(Color(0.2, 0.33, 0.14), 0.95)
	# bucket into 1 km cells so distant groups are culled (helps laptops / integrated GPUs)
	var cells := {}
	for i in range(trunks.size()):
		var o: Vector3 = (trunks[i] as Transform3D).origin
		var key := Vector2i(int(floor(o.x / 1000.0)), int(floor(o.z / 1000.0)))
		if not cells.has(key):
			cells[key] = []
		cells[key].append(trunks[i])
	var far: float = [1800.0, 2800.0, 4000.0][quality]
	for key in cells:
		var list: Array = cells[key]
		_multimesh(parent, trunk_mesh, trunk_mat, list, "Trunks").visibility_range_end = far * 0.7
		_multimesh(parent, crown_mesh, crown_mat, list, "Crowns").visibility_range_end = far


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


func _cyl_mesh(rb: float, rt: float, h: float) -> Mesh:
	var cm := CylinderMesh.new()
	cm.bottom_radius = rb
	cm.top_radius = rt
	cm.height = h
	cm.radial_segments = 6
	cm.rings = 1
	var st := SurfaceTool.new()
	st.append_from(cm, 0, Transform3D(Basis(), Vector3(0, h * 0.5, 0)))
	return st.commit()


func _crown_mesh(radius: float, height: float, base_y: float, sparse: bool) -> Mesh:
	var st := SurfaceTool.new()
	var blobs := 7 if sparse else 5
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 if sparse else 9
	for b in range(blobs):
		var sm := SphereMesh.new()
		var r := radius * rng.randf_range(0.5, 0.75)
		sm.radius = r
		sm.height = r * (1.3 if sparse else 1.7)
		sm.radial_segments = 7
		sm.rings = 4
		var off := Vector3(rng.randf_range(-1, 1) * radius * 0.45, base_y + rng.randf_range(-0.3, 0.6) * height * 0.5, rng.randf_range(-1, 1) * radius * 0.45)
		if b == 0:
			off = Vector3(0, base_y + height * 0.2, 0)
		st.append_from(sm, 0, Transform3D(Basis(), off))
	return st.commit()
