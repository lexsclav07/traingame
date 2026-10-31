class_name Animals
extends RefCounted
## Livestock and wildlife in the paddocks beside the line: Angus and Hereford
## cattle and mobs of grey kangaroos in NSW; flocks of sheep and Friesian or
## Shorthorn cattle on the English pastures. Low-poly models instanced with
## MultiMesh, standing or grazing, kept away from the line, roads and water.

var track: Track
var terrain: TerrainBuilder
var rng := RandomNumberGenerator.new()
var nsw := true
var _xf := {}          # "herd|model" -> Array of transforms (one MultiMesh per herd,
					   # so visibility ranges work from each herd's own position)
var _herds := 0
var _mesh := {}        # model key -> Mesh


func build(parent: Node3D, t: Track, ter: TerrainBuilder, q: int) -> void:
	track = t
	terrain = ter
	nsw = t.route["theme"] == "nsw"
	rng.seed = 5150
	var root := Node3D.new()
	root.name = "Animals"
	parent.add_child(root)
	if nsw:
		for i in range([3, 5, 8, 10][q]):
			_herd(["angus", "angus", "hereford"][rng.randi() % 3], rng.randi_range(4, 12), 18.0, false)
		for i in range([1, 3, 4, 6][q]):
			_herd("roo", rng.randi_range(3, 8), 14.0, false)
	else:
		for i in range([4, 7, 10, 14][q]):
			_herd("sheep", rng.randi_range(10, 28), 22.0, true)
		for i in range([2, 3, 5, 6][q]):
			_herd(["friesian", "shorthorn"][rng.randi() % 2], rng.randi_range(4, 10), 20.0, true)
	var vis: float = [500.0, 800.0, 1100.0, 1500.0][q]
	for key in _xf:
		var xs: Array = _xf[key]
		if xs.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _model(key.get_slice("|", 1))
		mm.instance_count = xs.size()
		for i in range(xs.size()):
			mm.set_instance_transform(i, xs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.name = key.get_slice("|", 1).capitalize() + "_" + key.get_slice("|", 0)
		mmi.visibility_range_end = vis
		mmi.visibility_range_end_margin = 60.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		root.add_child(mmi)


## One herd / flock / mob around a centre that suits it.
func _herd(kind: String, n: int, spread: float, pasture_only: bool) -> void:
	for attempt in range(60):
		var s := rng.randf() * track.length
		var lat := rng.randf_range(45.0, 320.0) * (1.0 if rng.randf() < 0.5 else -1.0)
		var c := track.flat_frame_at(s, lat).origin
		if not _ground_ok(c.x, c.z, pasture_only, 30.0):
			continue
		var heading := rng.randf() * TAU
		var placed := 0
		_herds += 1
		for k in range(n * 3):
			if placed >= n:
				break
			var a := rng.randf() * TAU
			var r := sqrt(rng.randf()) * spread
			var x := c.x + cos(a) * r
			var z := c.z + sin(a) * r
			if not _ground_ok(x, z, pasture_only, 26.0):
				continue
			var y := terrain.mesh_height(x, z)
			# animals in a group mostly face the same way, grazing into the wind
			var yaw := heading + rng.randf_range(-0.9, 0.9)
			var sc := rng.randf_range(0.88, 1.12)
			var variant := "%d|%s_%s" % [_herds, kind, "graze" if rng.randf() < 0.65 else "stand"]
			# tilt with the ground slope
			var hx := terrain.mesh_height(x + 0.8, z) - terrain.mesh_height(x - 0.8, z)
			var hz := terrain.mesh_height(x, z + 0.8) - terrain.mesh_height(x, z - 0.8)
			var up := Vector3(-hx / 1.6, 1.0, -hz / 1.6).normalized()
			var b := Basis(Vector3.UP, yaw)
			var axis := Vector3.UP.cross(up)
			if axis.length() > 0.001:
				b = Basis(axis.normalized(), Vector3.UP.angle_to(up)) * b
			if not _xf.has(variant):
				_xf[variant] = []
			_xf[variant].append(Transform3D(b.scaled(Vector3.ONE * sc), Vector3(x, y - 0.02, z)))
			placed += 1
		return


func _ground_ok(x: float, z: float, pasture_only: bool, min_d: float) -> bool:
	terrain.query(x, z)
	if terrain.q_d < min_d or terrain.road_dist(x, z) < 12.0:
		return false
	var h := terrain.shaped(x, z, terrain.q_d, terrain.q_h, terrain.q_br)
	if h < terrain.water_y + 1.0:
		return false
	var slope := absf(terrain.height_at(x + 3.0, z) - terrain.height_at(x - 3.0, z)) + absf(terrain.height_at(x, z + 3.0) - terrain.height_at(x, z - 3.0))
	if slope > 2.4:
		return false
	if pasture_only:
		var fs := TerrainBuilder.FIELD_SIZE
		var fp := terrain.field_rot(Vector2(x, z))
		var cell := Vector2(floor(fp.x / fs.x), floor(fp.y / fs.y))
		if GrassField._hash12(cell + Vector2(17.0, 17.0)) >= 0.5:
			return false          # stubble or plough
	return true


# ------------------------------------------------------------------ models
func _model(key: String) -> Mesh:
	if _mesh.has(key):
		return _mesh[key]
	var parts := key.split("_")
	var kind: String = parts[0]
	var graze: bool = parts.size() > 1 and parts[1] == "graze"
	var b := MeshBatch.new()
	match kind:
		"sheep":
			_sheep(b, graze)
		"roo":
			_roo(b, graze)
		_:
			_cow(b, kind, graze)
	var m := b.commit_mesh()
	_mesh[key] = m
	return m


static func _ell(b: MeshBatch, key: String, mat: Material, size: Vector3, pos: Vector3, rot := Basis()) -> void:
	b.mesh(key, mat, _unit_sphere(), Transform3D(rot * Basis.from_scale(size), pos))


static var _sph: SphereMesh


static func _unit_sphere() -> SphereMesh:
	if _sph == null:
		_sph = SphereMesh.new()
		_sph.radius = 0.5
		_sph.height = 1.0
		_sph.radial_segments = 12
		_sph.rings = 7
	return _sph


## Sheep, facing -Z: woolly body, black or white face, thin dark legs.
func _sheep(b: MeshBatch, graze: bool) -> void:
	var wool := TX.pbr("fabric_albedo", "fabric_normal", Color(1.25, 1.2, 1.08), 0.98, 0.0, Vector3.ONE * 5.0, false, 1.4, "sheep_wool")
	var face := MU.mat(Color(0.05, 0.045, 0.04), 0.7, 0.0, "sheep_face")
	_ell(b, "w", wool, Vector3(0.62, 0.58, 1.1), Vector3(0, 0.66, 0.05))
	_ell(b, "w", wool, Vector3(0.42, 0.38, 0.4), Vector3(0, 0.78, -0.42))
	var hy := 0.35 if graze else 0.82
	var hz := -0.68 if graze else -0.7
	var tilt := Basis(Vector3.RIGHT, -1.0 if graze else -0.35)
	_ell(b, "f", face, Vector3(0.17, 0.2, 0.32), Vector3(0, hy, hz), tilt)
	for sx in [-1.0, 1.0]:
		b.box("f", face, Vector3(0.12, 0.04, 0.06), Transform3D(Basis(Vector3.FORWARD, sx * 0.4), Vector3(sx * 0.1, hy + 0.08, hz + 0.1)))
		for lz in [-0.3, 0.32]:
			b.cyl("f", face, Transform3D(Basis(), Vector3(sx * 0.15, 0.2, lz)), 0.035, 0.04, 0.42, 6)


## Cattle, facing -Z. Angus all black, Hereford red with a white face and
## belly, Friesian black and white, Shorthorn roan.
func _cow(b: MeshBatch, kind: String, graze: bool) -> void:
	var cols := {"angus": [Color(0.04, 0.035, 0.035), Color(0.04, 0.035, 0.035), Color(0.04, 0.035, 0.035)],
		"hereford": [Color(0.42, 0.16, 0.07), Color(0.9, 0.88, 0.82), Color(0.9, 0.88, 0.82)],
		"friesian": [Color(0.05, 0.05, 0.05), Color(0.92, 0.92, 0.9), Color(0.92, 0.92, 0.9)],
		"shorthorn": [Color(0.55, 0.32, 0.2), Color(0.85, 0.8, 0.75), Color(0.55, 0.32, 0.2)]}
	var c: Array = cols.get(kind, cols["angus"])
	var hide := TX.pbr("fabric_albedo", "", c[0], 0.75, 0.0, Vector3.ONE * 3.0, false, 1.0, "cow_" + kind + "_1")
	var pale := TX.pbr("fabric_albedo", "", c[1], 0.75, 0.0, Vector3.ONE * 3.0, false, 1.0, "cow_" + kind + "_2")
	var face := TX.pbr("fabric_albedo", "", c[2], 0.7, 0.0, Vector3.ONE * 3.0, false, 1.0, "cow_" + kind + "_3")
	var hoof := MU.mat(Color(0.05, 0.04, 0.04), 0.6, 0.0, "cow_hoof")
	var horn := MU.mat(Color(0.8, 0.75, 0.62), 0.5, 0.0, "cow_horn")
	# barrel, chest and rump
	_ell(b, "h", hide, Vector3(0.78, 0.82, 1.95), Vector3(0, 1.08, 0.05))
	_ell(b, "h", hide, Vector3(0.7, 0.78, 0.7), Vector3(0, 1.1, -0.72))
	_ell(b, "h", hide, Vector3(0.72, 0.74, 0.7), Vector3(0, 1.12, 0.78))
	if kind != "angus":
		# pale belly (Friesian / Hereford) or roan flank patches
		_ell(b, "p", pale, Vector3(0.66, 0.42, 1.5), Vector3(0, 0.82, 0.05))
		if kind == "friesian":
			_ell(b, "p", pale, Vector3(0.79, 0.5, 0.55), Vector3(0, 1.18, 0.25))
			_ell(b, "p", pale, Vector3(0.8, 0.45, 0.4), Vector3(0, 1.0, -0.55))
	# neck and head (down to the grass when grazing)
	var hpos := Vector3(0, 0.42, -1.38) if graze else Vector3(0, 1.28, -1.3)
	var npos := Vector3(0, 0.78, -1.1) if graze else Vector3(0, 1.22, -1.05)
	_ell(b, "h", hide, Vector3(0.4, 0.55, 0.62), npos, Basis(Vector3.RIGHT, 0.9 if graze else 0.3))
	_ell(b, "f", face, Vector3(0.3, 0.36, 0.56), hpos, Basis(Vector3.RIGHT, 1.2 if graze else 0.25))
	for sx in [-1.0, 1.0]:
		var ear := hpos + Vector3(sx * 0.2, 0.12, 0.12)
		b.box("h", hide, Vector3(0.16, 0.05, 0.1), Transform3D(Basis(Vector3.FORWARD, sx * 0.3), ear))
		if kind == "hereford" or kind == "shorthorn":
			b.cyl("o", horn, Transform3D(Basis(Vector3.FORWARD, sx * 1.1), hpos + Vector3(sx * 0.16, 0.2, 0.1)), 0.015, 0.03, 0.18, 6)
		# legs and hooves
		for lz in [-0.68, 0.72]:
			b.cyl("h", hide if kind != "friesian" else pale, Transform3D(Basis(), Vector3(sx * 0.22, 0.42, lz)), 0.07, 0.085, 0.8, 7)
			b.cyl("k", hoof, Transform3D(Basis(), Vector3(sx * 0.22, 0.05, lz)), 0.075, 0.08, 0.1, 7)
	# tail
	b.cyl("h", hide, Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(0, 0.85, 1.12)), 0.02, 0.03, 0.75, 5)


## Eastern grey kangaroo, facing -Z: grazing on all fours with the tail on
## the ground, or sitting up on its haunches with the ears pricked.
func _roo(b: MeshBatch, graze: bool) -> void:
	var fur := TX.pbr("fabric_albedo", "", Color(0.6, 0.53, 0.47), 0.85, 0.0, Vector3.ONE * 4.0, false, 1.0, "roo_fur")
	var pale := TX.pbr("fabric_albedo", "", Color(0.82, 0.78, 0.72), 0.85, 0.0, Vector3.ONE * 4.0, false, 1.0, "roo_pale")
	var dark := MU.mat(Color(0.12, 0.1, 0.09), 0.7, 0.0, "roo_dark")
	if graze:
		_ell(b, "f", fur, Vector3(0.42, 0.5, 0.95), Vector3(0, 0.55, 0.05), Basis(Vector3.RIGHT, 0.35))
		_ell(b, "f", fur, Vector3(0.36, 0.5, 0.55), Vector3(0, 0.42, 0.42))
		_ell(b, "f", fur, Vector3(0.18, 0.2, 0.32), Vector3(0, 0.22, -0.55), Basis(Vector3.RIGHT, 0.9))
		for sx in [-1.0, 1.0]:
			b.box("d", dark, Vector3(0.05, 0.16, 0.08), Transform3D(Basis(Vector3.FORWARD, sx * 0.25), Vector3(sx * 0.06, 0.36, -0.48)))
			b.cyl("d", dark, Transform3D(Basis(Vector3.RIGHT, 0.4), Vector3(sx * 0.1, 0.12, -0.3)), 0.025, 0.03, 0.26, 5)
		b.cyl("f", fur, Transform3D(Basis(Vector3.RIGHT, PI * 0.5 - 0.12), Vector3(0, 0.12, 1.05)), 0.03, 0.09, 0.95, 7)
	else:
		_ell(b, "f", fur, Vector3(0.4, 0.82, 0.42), Vector3(0, 0.82, 0.05), Basis(Vector3.RIGHT, -0.2))
		_ell(b, "p", pale, Vector3(0.3, 0.6, 0.2), Vector3(0, 0.82, -0.1), Basis(Vector3.RIGHT, -0.2))
		_ell(b, "f", fur, Vector3(0.38, 0.42, 0.62), Vector3(0, 0.28, 0.12))
		_ell(b, "f", fur, Vector3(0.17, 0.22, 0.32), Vector3(0, 1.32, -0.08), Basis(Vector3.RIGHT, 0.3))
		for sx in [-1.0, 1.0]:
			b.box("d", dark, Vector3(0.05, 0.18, 0.08), Transform3D(Basis(Vector3.FORWARD, sx * 0.15), Vector3(sx * 0.06, 1.5, -0.02)))
			b.cyl("d", dark, Transform3D(Basis(Vector3.RIGHT, -0.7), Vector3(sx * 0.1, 0.95, -0.22)), 0.02, 0.025, 0.25, 5)
			b.box("d", dark, Vector3(0.08, 0.06, 0.38), Transform3D(Basis(), Vector3(sx * 0.12, 0.03, -0.12)))
		b.cyl("f", fur, Transform3D(Basis(Vector3.RIGHT, PI * 0.5 + 0.25), Vector3(0, 0.2, 0.62)), 0.03, 0.1, 0.95, 7)
