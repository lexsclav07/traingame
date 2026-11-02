class_name GrassField
extends Node3D
## Dense grass clumps in tiles around the camera. Tiles are rebuilt as the
## camera moves along the line, a few per frame so it never stalls.

const TILE := 12.0

var terrain: TerrainBuilder
var cam: Camera3D
var radius_tiles := 5
var per_tile := 110
var tiles := {}            # Vector2i -> MultiMeshInstance3D
var pool: Array[MultiMeshInstance3D] = []
var mesh: ArrayMesh
var mat: ShaderMaterial
var _queue: Array[Vector2i] = []
var _center := Vector2i(999999, 999999)


func setup(ter: TerrainBuilder, camera: Camera3D, quality: int) -> void:
	terrain = ter
	cam = camera
	radius_tiles = [3, 4, 5, 7][quality]
	per_tile = [60, 120, 190, 260][quality]
	var nsw := terrain.theme == "nsw"
	mesh = TreeGen.grass_clump(0.8, 0.6 if nsw else 0.45)
	mat = TX.shader_mat("res://assets/shaders/foliage.gdshader")
	mat.set_shader_parameter("leaf_tex", TX.t("grass_blades_dry" if nsw else "grass_blades_green"))
	mat.set_shader_parameter("alpha_cut", 0.4)
	mat.set_shader_parameter("tint", Color(0.95, 0.95, 0.88) if nsw else Color(0.9, 1.0, 0.88))
	mat.set_shader_parameter("tint_var", Color(0.85, 0.82, 0.7) if nsw else Color(0.8, 0.9, 0.75))
	mat.set_shader_parameter("wind_strength", {"rain": 0.5, "fog": 0.1}.get(GameSettings.weather, 0.32))
	mat.set_shader_parameter("sway_height", 0.35)
	mat.set_shader_parameter("fade_radius", (radius_tiles + 0.3) * TILE)
	mat.set_shader_parameter("ao_bottom", 0.3)
	mat.set_shader_parameter("translucency", Color(0.16, 0.18, 0.08))
	# match the terrain underneath (see terrain_builder._terrain_material)
	var tm: ShaderMaterial = terrain.terrain_material
	if tm:
		mat.set_shader_parameter("ground_blend", 0.75)
		mat.set_shader_parameter("up_normal", 0.75)
		mat.set_shader_parameter("ground_tex", tm.get_shader_parameter("grass_alb"))
		mat.set_shader_parameter("ground_scale", 0.22)
		mat.set_shader_parameter("macro_tex", tm.get_shader_parameter("macro_tex"))
		var td = tm.get_shader_parameter("grass_tint_dry")
		var tl = tm.get_shader_parameter("grass_tint_lush")
		mat.set_shader_parameter("tint_dry", td if td != null else Color(1, 1, 1))
		mat.set_shader_parameter("tint_lush", tl if tl != null else Color(0.82, 0.95, 0.72))
	mesh.surface_set_material(0, mat)


func _process(_delta: float) -> void:
	if cam == null or per_tile <= 0:
		return
	var p := cam.global_position
	var c := Vector2i(int(floor(p.x / TILE)), int(floor(p.z / TILE)))
	if c != _center:
		_center = c
		var want := {}
		for dz in range(-radius_tiles, radius_tiles + 1):
			for dx in range(-radius_tiles, radius_tiles + 1):
				if dx * dx + dz * dz <= radius_tiles * radius_tiles + 1:
					want[Vector2i(c.x + dx, c.y + dz)] = true
		for key in tiles.keys():
			if not want.has(key):
				var mmi: MultiMeshInstance3D = tiles[key]
				mmi.visible = false
				pool.append(mmi)
				tiles.erase(key)
		_queue.clear()
		for key in want:
			if not tiles.has(key):
				_queue.append(key)
		# nearest first
		_queue.sort_custom(func(a, b): return (a - c).length_squared() < (b - c).length_squared())
	var budget := 6
	while budget > 0 and not _queue.is_empty():
		var key: Vector2i = _queue.pop_front()
		if not tiles.has(key):
			tiles[key] = _build(key)
		budget -= 1


## Same field layout and pasture/arable choice as the terrain shader.
func _grassy_field(x: float, z: float) -> bool:
	var fs := TerrainBuilder.FIELD_SIZE
	var fp := terrain.field_rot(Vector2(x, z))
	var cell := Vector2(floor(fp.x / fs.x), floor(fp.y / fs.y))
	if _hash12(cell + Vector2(17.0, 17.0)) < 0.5:
		return true
	var local := fp - Vector2(cell.x * fs.x, cell.y * fs.y)
	var edge := minf(minf(local.x, fs.x - local.x), minf(local.y, fs.y - local.y))
	return edge < 6.0


static func _hash12(p: Vector2) -> float:
	var p3 := Vector3(p.x, p.y, p.x) * 0.1031
	p3 = Vector3(p3.x - floor(p3.x), p3.y - floor(p3.y), p3.z - floor(p3.z))
	var dd := p3.dot(Vector3(p3.y, p3.z, p3.x) + Vector3.ONE * 33.33)
	p3 += Vector3.ONE * dd
	var v := (p3.x + p3.y) * p3.z
	return v - floor(v)


func _build(key: Vector2i) -> MultiMeshInstance3D:
	var mmi: MultiMeshInstance3D
	if pool.is_empty():
		mmi = MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = per_tile
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
	else:
		mmi = pool.pop_back()
	mmi.visible = true
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var fields := terrain.theme != "nsw"
	var mm := mmi.multimesh
	var used := 0
	for i in range(per_tile):
		var x := (key.x + rng.randf()) * TILE
		var z := (key.y + rng.randf()) * TILE
		terrain.query(x, z)
		var d := terrain.q_d
		var sc := rng.randf_range(0.65, 1.35)
		if d < 3.3:
			continue                    # ballast
		if terrain.road_dist(x, z) < 4.2:
			continue                    # a road crossing the line
		if d < 7.0 and rng.randf() < 0.75:
			continue                    # sparse on the cess
		if fields and d > 22.0 and not _grassy_field(x, z):
			continue                    # stubble and plough: grass only on the headlands
		var h := terrain.shaped(x, z, d, terrain.q_h, terrain.q_br)
		if h < terrain.water_y + 0.25:
			continue
		var hx := terrain.shaped(x + 0.8, z, d, terrain.q_h, terrain.q_br)
		var hz := terrain.shaped(x, z + 0.8, d, terrain.q_h, terrain.q_br)
		if absf(hx - h) > 0.7 or absf(hz - h) > 0.7:
			continue                    # rock faces
		# sit on the terrain as it is actually meshed (the analytic shape differs
		# from the triangles on cutting edges and embankment shoulders)
		var hm := terrain.mesh_height(x, z)
		if absf(hm - h) > 0.6:
			continue                    # steep break in the ground: no clump here
		mm.set_instance_transform(used, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.8, 1.3), sc)), Vector3(x, hm - 0.05, z)))
		used += 1
	mm.visible_instance_count = used
	return mmi
