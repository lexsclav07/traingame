class_name TreeGen
## Procedural trees: tapered branching trunk tubes (bark surface) plus
## alpha-tested leaf-cluster cards (leaf surface). LOD 0 = close up, 1 = far.

const SPECIES := {
	# trunk height, trunk radius, fork depth, children, spread (rad), leaf cards per tip, card size, hang
	"gum": {"h": [11.0, 18.0], "r": [0.28, 0.45], "depth": 3, "kids": [2, 3], "spread": [0.35, 0.75],
		"cards": 4, "card": [2.6, 3.8], "hang": 0.85, "fork_at": [0.5, 0.7], "lean": 0.12, "up": 0.35},
	"angophora": {"h": [7.0, 11.0], "r": [0.3, 0.5], "depth": 3, "kids": [2, 3], "spread": [0.5, 0.95],
		"cards": 4, "card": [2.4, 3.4], "hang": 0.6, "fork_at": [0.35, 0.5], "lean": 0.2, "up": 0.1},
	"oak": {"h": [4.0, 6.5], "r": [0.4, 0.65], "depth": 3, "kids": [3, 4], "spread": [0.6, 1.05],
		"cards": 7, "card": [2.8, 4.2], "hang": 0.15, "fork_at": [0.6, 0.8], "lean": 0.05, "up": 0.15},
	"ash": {"h": [7.0, 10.0], "r": [0.3, 0.45], "depth": 3, "kids": [2, 3], "spread": [0.4, 0.8],
		"cards": 6, "card": [2.6, 3.6], "hang": 0.3, "fork_at": [0.55, 0.75], "lean": 0.06, "up": 0.3},
}


static func make(species: String, seed_v: int, lod: int) -> ArrayMesh:
	var sp: Dictionary = SPECIES[species]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var bark := SurfaceTool.new()
	bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tips := []
	var h := rng.randf_range(sp["h"][0], sp["h"][1])
	var r := rng.randf_range(sp["r"][0], sp["r"][1])
	var lean := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized() * float(sp["lean"])
	var trunk_dir := (Vector3.UP + lean).normalized()
	var fork := rng.randf_range(sp["fork_at"][0], sp["fork_at"][1])
	_branch(bark, tips, Vector3.ZERO, trunk_dir, h * fork, r, 0, rng, sp, lod, h)
	var crown_center := Vector3.ZERO
	for t in tips:
		crown_center += t[0]
	crown_center /= maxf(tips.size(), 1)
	var cards: int = sp["cards"] if lod == 0 else maxi(1, int(sp["cards"]) / 2)
	for t in tips:
		for k in range(cards):
			var pos: Vector3 = t[0] + Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.6, 0.8), rng.randf_range(-1, 1)) * 1.1
			var size := rng.randf_range(sp["card"][0], sp["card"][1]) * (1.35 if lod == 1 else 1.0)
			_card(leaves, pos, size, rng, float(sp["hang"]), crown_center)
	var mesh := ArrayMesh.new()
	bark.generate_normals()
	bark.generate_tangents()
	bark.commit(mesh)
	leaves.generate_tangents()
	leaves.commit(mesh)
	return mesh


static func _branch(st: SurfaceTool, tips: Array, start: Vector3, dir: Vector3, length: float, radius: float,
		depth: int, rng: RandomNumberGenerator, sp: Dictionary, lod: int, tree_h: float) -> void:
	var segs := (5 if depth == 0 else 3) if lod == 0 else 2
	var sides := (8 if depth == 0 else (6 if depth == 1 else 4)) if lod == 0 else (5 if depth == 0 else 3)
	var pts := [start]
	var radii := [radius]
	var p := start
	var d := dir
	for i in range(segs):
		d = (d + Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 0.6), rng.randf_range(-1, 1)) * 0.12 + Vector3.UP * float(sp["up"]) * 0.15).normalized()
		p += d * length / segs
		pts.append(p)
		radii.append(radius * lerpf(1.0, 0.62, float(i + 1) / segs))
	if depth == 0:
		# buttress flare at the base of the trunk
		radii[0] = radius * 1.35
	_tube(st, pts, radii, sides)
	var max_depth: int = sp["depth"] if lod == 0 else 2
	if depth >= max_depth:
		tips.append([p, d])
		return
	var kids := rng.randi_range(sp["kids"][0], sp["kids"][1])
	var base_angle := rng.randf() * TAU
	for k in range(kids):
		var spread := rng.randf_range(sp["spread"][0], sp["spread"][1])
		var around := base_angle + TAU * k / kids + rng.randf_range(-0.4, 0.4)
		var side := Vector3(cos(around), 0, sin(around))
		var nd := (d * cos(spread) + side * sin(spread)).normalized()
		nd = (nd + Vector3.UP * float(sp["up"]) * 0.5).normalized()
		var nl := length * rng.randf_range(0.55, 0.8) if depth > 0 else tree_h * rng.randf_range(0.28, 0.42)
		var start_t := 1.0 if depth == 0 else rng.randf_range(0.65, 1.0)
		var sp_pt: Vector3 = pts[int(round(start_t * (pts.size() - 1)))]
		_branch(st, tips, sp_pt, nd, nl, radius * rng.randf_range(0.5, 0.68), depth + 1, rng, sp, lod, tree_h)
	# a few leaves along the outer limbs as well as at the tips
	if depth >= 1 and lod == 0:
		tips.append([pts[pts.size() / 2], d])


static func _tube(st: SurfaceTool, pts: Array, radii: Array, sides: int) -> void:
	var n := pts.size()
	var ref := Vector3.RIGHT
	var vacc := 0.0
	var rings := []
	for i in range(n):
		var p: Vector3 = pts[i]
		var t: Vector3 = (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		if absf(t.dot(ref)) > 0.9:
			ref = Vector3.FORWARD
		var b1 := t.cross(ref).normalized()
		var b2 := t.cross(b1).normalized()
		var ring := []
		for s in range(sides + 1):
			var a := TAU * s / sides
			ring.append(p + (b1 * cos(a) + b2 * sin(a)) * float(radii[i]))
		if i > 0:
			vacc += (p - (pts[i - 1] as Vector3)).length()
		rings.append([ring, vacc])
	for i in range(n - 1):
		var ra: Array = rings[i][0]
		var rb: Array = rings[i + 1][0]
		var va: float = rings[i][1] / 1.6
		var vb: float = rings[i + 1][1] / 1.6
		for s in range(sides):
			var u0 := float(s) / sides
			var u1 := float(s + 1) / sides
			# clockwise when seen from outside (Godot front faces)
			st.set_uv(Vector2(u0, va)); st.add_vertex(ra[s])
			st.set_uv(Vector2(u0, vb)); st.add_vertex(rb[s])
			st.set_uv(Vector2(u1, vb)); st.add_vertex(rb[s + 1])
			st.set_uv(Vector2(u0, va)); st.add_vertex(ra[s])
			st.set_uv(Vector2(u1, vb)); st.add_vertex(rb[s + 1])
			st.set_uv(Vector2(u1, va)); st.add_vertex(ra[s + 1])


static func _card(st: SurfaceTool, c: Vector3, size: float, rng: RandomNumberGenerator, hang: float, center: Vector3) -> void:
	var yaw := rng.randf() * TAU
	var right := Vector3(cos(yaw), 0, sin(yaw))
	# hanging foliage (gums) stays near vertical; spreading crowns tilt more
	var up := (Vector3.UP * (0.4 + hang) + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)) * (1.0 - hang)).normalized()
	up = (up - right * up.dot(right)).normalized()
	var outward := (c - center + Vector3(0, 1.5, 0)).normalized()
	var face_n := right.cross(up).normalized()
	if face_n.dot(outward) < 0.0:
		face_n = -face_n
	var nrm := (outward * 0.75 + face_n * 0.25).normalized()
	var hs := size * 0.5
	var p0 := c - right * hs - up * hs
	var p1 := c + right * hs - up * hs
	var p2 := c + right * hs + up * hs
	var p3 := c - right * hs + up * hs
	for v in [[p0, Vector2(0, 1)], [p2, Vector2(1, 0)], [p1, Vector2(1, 1)], [p0, Vector2(0, 1)], [p3, Vector2(0, 0)], [p2, Vector2(1, 0)]]:
		st.set_normal(nrm)
		st.set_uv(v[1])
		st.add_vertex(v[0])


## Grass clump: three crossed vertical cards.
static func grass_clump(width: float, height: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in range(3):
		var a := PI * k / 3.0
		var r := Vector3(cos(a), 0, sin(a)) * width * 0.5
		var p0 := -r
		var p1 := r
		var p2 := r + Vector3(0, height, 0)
		var p3 := -r + Vector3(0, height, 0)
		for v in [[p0, Vector2(0, 1)], [p2, Vector2(1, 0)], [p1, Vector2(1, 1)], [p0, Vector2(0, 1)], [p3, Vector2(0, 0)], [p2, Vector2(1, 0)]]:
			st.set_normal(Vector3.UP)
			st.set_uv(v[1])
			st.add_vertex(v[0])
	st.generate_tangents()
	return st.commit()


## Shrub / hedge clump: a ball of leaf cards. 'length' > 0 makes a hedge segment.
static func bush(seed_v: int, radius: float, height: float, length := 0.0) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 9 if length <= 0.0 else int(length * 1.6)
	for i in range(count):
		var c := Vector3(rng.randf_range(-radius, radius) * 0.6, rng.randf_range(0.35, 0.85) * height, rng.randf_range(-radius, radius) * 0.6)
		if length > 0.0:
			c.z = rng.randf_range(-length * 0.5, length * 0.5)
		_card(st, c, rng.randf_range(1.2, 2.0) * radius, rng, 0.2, Vector3(0, height * 0.3, c.z if length > 0.0 else 0.0))
	st.generate_tangents()
	return st.commit()


## Lumpy boulder for sandstone outcrops.
static func rock(seed_v: int) -> ArrayMesh:
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 12
	sm.rings = 8
	var arr := sm.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var fn := FastNoiseLite.new()
	fn.seed = seed_v
	fn.frequency = 0.9
	for i in range(v.size()):
		var p := v[i]
		var k := 1.0 + fn.get_noise_3dv(p * 1.3) * 0.35
		v[i] = Vector3(p.x * k * 1.3, p.y * k * 0.7, p.z * k)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = null
	arr[Mesh.ARRAY_TANGENT] = null
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var st := SurfaceTool.new()
	st.create_from(am, 0)
	st.generate_normals()
	return st.commit()
