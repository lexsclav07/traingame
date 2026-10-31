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
	build_coarse_distance()
	_plan_crossings()


# ------------------------------------------------------- level crossings
## Country roads cross the line on the level at a few places: straight track,
## away from stations, bridges and water troughs, where the land is flat
## enough for a road to meet the rails without big ramps. Everything that
## places scenery asks road_dist() so trees, fences and grass leave the road
## clear. Each crossing: {s, o (rail-top centre), r (right), f (forward),
## hw (road half width), len (road length to the left / right)}.
var crossings: Array = []
var build_q := 2


func _plan_crossings() -> void:
	crossings.clear()
	var want := 2 if theme == "nsw" else 3
	var cands := []
	var s := 200.0
	while s < track.length - 200.0:
		s += 20.0
		if not _crossing_site_ok(s):
			continue
		var cost := _crossing_cost(s)
		if cost < 1e8:
			cands.append([cost, s])
	cands.sort_custom(func(a, b): return a[0] < b[0])
	for c in cands:
		var ok := true
		for x in crossings:
			if absf(sdiff(c[1], x["s"])) < 2500.0:
				ok = false
		if ok:
			crossings.append(_make_crossing(c[1]))
		if crossings.size() >= want:
			break
	crossings.sort_custom(func(a, b): return a["s"] < b["s"])


## Signed distance from b to a along the loop (shortest way round).
func sdiff(a: float, b: float) -> float:
	var d := fposmod(a - b, track.length)
	return d - track.length if d > track.length * 0.5 else d


func _crossing_site_ok(s: float) -> bool:
	var k := -100.0
	while k <= 100.0:
		if absf(track.curv_at(s + k)) > 1e-6 or absf(track.cant_at(s + k)) > 1e-4:
			return false
		if is_bridge(s + k * 1.5):
			return false
		k += 20.0
	for p in route.get("platforms", []):
		if sdiff(s, p[0]) > -350.0 and sdiff(s, p[0] + p[1]) < 350.0:
			return false
	for tr in route.get("troughs", []):
		if sdiff(s, tr[0]) > -350.0 and sdiff(s, tr[0] + tr[1]) < 350.0:
			return false
	return true


## How far the land beside the line strays from formation level (lower = flatter).
func _crossing_cost(s: float) -> float:
	var f := track.flat_frame_at(s)
	var th := f.origin.y
	var cost := 0.0
	for side in [-1.0, 1.0]:
		for d in [14.0, 20.0, 28.0, 40.0, 60.0, 90.0, 120.0]:
			var p: Vector3 = f.origin + f.basis.x * side * d
			var h := height_at(p.x, p.z)
			if h < water_y + 1.0:
				return 1e9
			cost += absf(h - (th - 0.55)) * (2.5 if d < 30.0 else 1.0)
	return cost


func _make_crossing(s: float) -> Dictionary:
	var f := track.flat_frame_at(s)
	var lens := []
	for side in [-1.0, 1.0]:
		# carry the road on until it would climb a steep bank or reach water
		var d := 120.0
		var prev := height_at(f.origin.x + f.basis.x.x * side * d, f.origin.z + f.basis.x.z * side * d)
		while d < 420.0:
			var p: Vector3 = f.origin + f.basis.x * side * (d + 10.0)
			var h := height_at(p.x, p.z)
			if h < water_y + 1.0 or absf(h - prev) > 1.6:
				break
			prev = h
			d += 10.0
		lens.append(d)
	return {"s": s, "o": f.origin, "r": f.basis.x, "f": -f.basis.z,
		"hw": 3.3 if theme == "nsw" else 2.7, "len": lens}


## Distance from (x, z) to the nearest road centre line (INF if there are none).
func road_dist(x: float, z: float) -> float:
	var best := INF
	for c in crossings:
		var o: Vector3 = c["o"]
		var dx := x - o.x
		var dz := z - o.z
		var r: Vector3 = c["r"]
		var fw: Vector3 = c["f"]
		var u := dx * r.x + dz * r.z
		var v := dx * fw.x + dz * fw.z
		var lens: Array = c["len"]
		var uc := clampf(u, -float(lens[0]), float(lens[1]))
		best = minf(best, Vector2(u - uc, v).length())
	return best


func near_crossing(s: float, margin: float) -> bool:
	for c in crossings:
		if absf(sdiff(s, c["s"])) < margin:
			return true
	return false


## Height of the built terrain mesh at (x, z): the same grid and triangle split
## as _chunk(), so a road laid on it never sinks into the ground.
func mesh_height(x: float, z: float) -> float:
	var ci := clampi(int((x - area.position.x) / CHUNK), 0, chunks_x - 1)
	var cj := clampi(int((z - area.position.y) / CHUNK), 0, chunks_z - 1)
	var near := chunk_near[cj * chunks_x + ci] == 1
	var res := NEAR_RES if near else FAR_RES
	if build_q == 0 and near:
		res = 16.0
	var ox := area.position.x + ci * CHUNK
	var oz := area.position.y + cj * CHUNK
	var fx := (x - ox) / res
	var fz := (z - oz) / res
	var i := int(floor(fx))
	var j := int(floor(fz))
	var tx := fx - i
	var tz := fz - j
	var h00 := height_at(ox + i * res, oz + j * res)
	var h10 := height_at(ox + (i + 1) * res, oz + j * res)
	var h01 := height_at(ox + i * res, oz + (j + 1) * res)
	var h11 := height_at(ox + (i + 1) * res, oz + (j + 1) * res)
	# triangles (a, a+1, a+vn) and (a+1, a+vn+1, a+vn), split on the 10-01 diagonal
	if tx + tz <= 1.0:
		return h00 + (h10 - h00) * tx + (h01 - h00) * tz
	return h11 + (h01 - h11) * (1.0 - tx) + (h10 - h11) * (1.0 - tz)


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
var terrain_material: ShaderMaterial


func color_at(x: float, z: float, h: float, ny: float, d: float) -> Color:
	return _color(x, z, h, ny, d)


func build(parent: Node3D, quality: int) -> void:
	build_q = quality
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
	var wm := TX.shader_mat("res://assets/shaders/water.gdshader")
	wm.set_shader_parameter("wave_nrm", TX.t("water_normal"))
	wm.set_shader_parameter("rain", 1.0 if GameSettings.weather == "rain" else 0.0)
	if theme != "nsw":
		wm.set_shader_parameter("deep_color", Color(0.06, 0.1, 0.09))
		wm.set_shader_parameter("shallow_color", Color(0.14, 0.2, 0.16))
	water.material_override = wm
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.position = Vector3(area.get_center().x, water_y, area.get_center().y)
	water.name = "Water"
	root.add_child(water)
	build_backdrop(root)


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


## Splat weights for the terrain shader (see assets/shaders/terrain.gdshader):
## r = main ground, g = rock, b = secondary (litter / rough grass), a = cess gravel.
func _color(x: float, z: float, h: float, ny: float, d: float) -> Color:
	var fine := n_small.get_noise_2d(x * 2.0, z * 2.0)
	var rock := smoothstep(0.88, 0.62, ny)
	var gravel := smoothstep(5.2, 3.7, d) * clampf(0.9 + fine * 0.4, 0.0, 1.0)
	var main := 1.0
	var second := 0.0
	if theme == "nsw":
		# bush floor: leaf litter in patches, more on slopes and under the trees
		var bush := n_patch.get_noise_2d(x * 1.7, z * 1.7) * 0.5 + 0.5
		second = clampf((bush - 0.35) * 1.6 + fine * 0.5 + (1.0 - ny) * 1.5, 0.0, 1.0)
		if d < 22.0:
			second *= 0.4          # mown railway corridor
	else:
		# farmland outside the railway fence, rough grass inside it and on banks
		second = smoothstep(26.0, 16.0, d) + (1.0 - ny) * 2.0
		second = clampf(second, 0.0, 1.0)
	# muddy banks near water
	var mud := smoothstep(water_y + 2.0, water_y + 0.3, h)
	second = maxf(second, mud)
	main = clampf(1.0 - second, 0.0, 1.0)
	var c := Color(main, 0.0, second, 0.0)
	c = c.lerp(Color(0.0, 1.0, 0.0, 0.0), rock)
	c = c.lerp(Color(0.0, 0.0, 0.0, 1.0), gravel)
	return c


func _terrain_material() -> ShaderMaterial:
	var m := TX.shader_mat("res://assets/shaders/terrain.gdshader")
	var nsw := theme == "nsw"
	m.set_shader_parameter("grass_alb", TX.t("grass_dry_albedo" if nsw else "grass_green_albedo"))
	m.set_shader_parameter("grass_nrm", TX.t("grass_dry_normal" if nsw else "grass_green_normal"))
	m.set_shader_parameter("rock_alb", TX.t("sandstone_albedo" if nsw else "clay_albedo"))
	m.set_shader_parameter("rock_nrm", TX.t("sandstone_normal" if nsw else "clay_normal"))
	m.set_shader_parameter("soil_alb", TX.t("litter_albedo" if nsw else "grass_dry_albedo"))
	m.set_shader_parameter("soil_nrm", TX.t("litter_normal" if nsw else "grass_dry_normal"))
	m.set_shader_parameter("gravel_alb", TX.t("gravel_albedo"))
	m.set_shader_parameter("gravel_nrm", TX.t("gravel_normal"))
	m.set_shader_parameter("field_alb", TX.t("stubble_albedo"))
	m.set_shader_parameter("field_nrm", TX.t("stubble_normal"))
	m.set_shader_parameter("plough_alb", TX.t("plough_albedo"))
	m.set_shader_parameter("plough_nrm", TX.t("plough_normal"))
	m.set_shader_parameter("macro_tex", TX.t("macro_variation"))
	m.set_shader_parameter("use_fields", 0.0 if nsw else 1.0)
	m.set_shader_parameter("rock_scale", 0.06 if nsw else 0.1)
	m.set_shader_parameter("wetness", 0.7 if GameSettings.weather == "rain" else 0.0)
	if not nsw:
		m.set_shader_parameter("grass_tint_dry", Color(1, 1, 1))
	return m


## Field layout shared with the shader (for hedgerows): rotated grid of fields.
const FIELD_SIZE := Vector2(260.0, 190.0)
const FIELD_ANGLE := 0.4


func field_rot(p: Vector2) -> Vector2:
	var c := cos(FIELD_ANGLE)
	var s := sin(FIELD_ANGLE)
	return Vector2(c * p.x - s * p.y, s * p.x + c * p.y)


func field_unrot(p: Vector2) -> Vector2:
	var c := cos(FIELD_ANGLE)
	var s := sin(FIELD_ANGLE)
	return Vector2(c * p.x + s * p.y, -s * p.x + c * p.y)


# ----------------------------------------------------------- distant hills
## A ring of hills from the edge of the terrain out to ~16 km so the horizon
## is never empty. Heights rise away from the terrain edge.
func build_backdrop(parent: Node3D) -> void:
	var c := area.get_center()
	var segs := 256
	var rings := 18
	var r_out := maxf(area.size.x, area.size.y) * 0.5 + 14000.0
	var hn := FastNoiseLite.new()
	hn.seed = n_big.seed + 99
	hn.frequency = 1.0 / 5000.0
	hn.fractal_octaves = 4
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var mean_h := (track.max_h + track.min_h) * 0.5
	for i in range(segs):
		var a := TAU * i / segs
		var dir := Vector2(cos(a), sin(a))
		# distance from centre to the terrain rectangle edge along this direction
		var tx := (area.size.x * 0.5 - 1.0) / maxf(absf(dir.x), 1e-4)
		var tz := (area.size.y * 0.5 - 1.0) / maxf(absf(dir.y), 1e-4)
		var r_in := minf(tx, tz)
		for j in range(rings + 1):
			var f := float(j) / rings
			var r := lerpf(r_in, r_out, pow(f, 1.4))
			var p := c + dir * r
			var edge_h := nat(p.x, p.y, R_STAMP) if j == 0 else 0.0
			var hill := hn.get_noise_2d(p.x, p.y) * 0.5 + 0.5
			var rise := smoothstep(0.0, 0.35, f)
			var amp_h := (420.0 if theme == "nsw" else 160.0) * hill * hill + (60.0 if theme == "nsw" else 25.0)
			var y := lerpf(nat(c.x + dir.x * r_in, c.y + dir.y * r_in, R_STAMP), mean_h + amp_h, rise) if j > 0 else edge_h
			verts.append(Vector3(p.x, y - 0.5, p.y))
			var rockiness := 0.25 * hill if theme == "nsw" else 0.0
			cols.append(Color(1.0 - rockiness, rockiness, 0.35 if theme == "nsw" else 0.0, 0.0))
	for i in range(segs):
		var i2 := (i + 1) % segs
		for j in range(rings):
			var a0 := i * (rings + 1) + j
			var b0 := i2 * (rings + 1) + j
			idx.append_array([a0, a0 + 1, b0, b0, a0 + 1, b0 + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var st := SurfaceTool.new()
	st.create_from(am, 0)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = terrain_material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "DistantHills"
	parent.add_child(mi)


# ------------------------------------------------------- coarse distance grid
## Distance to the line on a 100 m grid (chamfer transform), for placing things
## far from the track (hedgerows, distant houses) without per-sample searches.
const COARSE := 100.0
var coarse_w := 0
var coarse_h := 0
var coarse := PackedFloat32Array()


func build_coarse_distance() -> void:
	coarse_w = int(area.size.x / COARSE) + 1
	coarse_h = int(area.size.y / COARSE) + 1
	coarse.resize(coarse_w * coarse_h)
	coarse.fill(1e9)
	for i in range(0, track.n, 10):
		var cx := int((track.px[i] - area.position.x) / COARSE)
		var cz := int((track.pz[i] - area.position.y) / COARSE)
		if cx >= 0 and cz >= 0 and cx < coarse_w and cz < coarse_h:
			coarse[cz * coarse_w + cx] = 0.0
	var dg := COARSE * 1.41421
	for z in range(coarse_h):
		for x in range(coarse_w):
			var i := z * coarse_w + x
			var v := coarse[i]
			if x > 0: v = minf(v, coarse[i - 1] + COARSE)
			if z > 0: v = minf(v, coarse[i - coarse_w] + COARSE)
			if x > 0 and z > 0: v = minf(v, coarse[i - coarse_w - 1] + dg)
			if x < coarse_w - 1 and z > 0: v = minf(v, coarse[i - coarse_w + 1] + dg)
			coarse[i] = v
	for z in range(coarse_h - 1, -1, -1):
		for x in range(coarse_w - 1, -1, -1):
			var i := z * coarse_w + x
			var v := coarse[i]
			if x < coarse_w - 1: v = minf(v, coarse[i + 1] + COARSE)
			if z < coarse_h - 1: v = minf(v, coarse[i + coarse_w] + COARSE)
			if x < coarse_w - 1 and z < coarse_h - 1: v = minf(v, coarse[i + coarse_w + 1] + dg)
			if x > 0 and z < coarse_h - 1: v = minf(v, coarse[i + coarse_w - 1] + dg)
			coarse[i] = v


func coarse_dist(x: float, z: float) -> float:
	var cx := int((x - area.position.x) / COARSE)
	var cz := int((z - area.position.y) / COARSE)
	if cx < 0 or cz < 0 or cx >= coarse_w or cz >= coarse_h:
		return 1e9
	return coarse[cz * coarse_w + cx]
