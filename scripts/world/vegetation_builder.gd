class_name VegetationBuilder
extends RefCounted
## Forests, scrub, boulders and hedgerows. Instanced with MultiMesh in 1.5 km
## cells, with a detailed mesh close up and a cheap one far away.

const CELL := 1500.0

var track: Track
var terrain: TerrainBuilder
var theme := "nsw"
var quality := 2
var rng := RandomNumberGenerator.new()
var leaf_mats := {}
var bark_mats := {}


func build(parent: Node3D, t: Track, ter: TerrainBuilder, q: int) -> void:
	track = t
	terrain = ter
	theme = t.route["theme"]
	quality = q
	rng.seed = 4468 if theme == "ecml" else 2019
	var root := Node3D.new()
	root.name = "Vegetation"
	parent.add_child(root)
	_trees(root)
	if theme == "nsw":
		_shrubs(root)
		_rocks(root)
	else:
		_hedgerows(root)


# ----------------------------------------------------------------- materials
func _leaf_mat(species: String) -> ShaderMaterial:
	if leaf_mats.has(species):
		return leaf_mats[species]
	var m := TX.shader_mat("res://assets/shaders/foliage.gdshader")
	var tex := "leaves_gum"
	var tint := Color(1, 1, 1)
	var tvar := Color(0.82, 0.88, 0.78)
	var trans := Color(0.28, 0.32, 0.18)
	match species:
		"angophora":
			tint = Color(0.92, 1.0, 0.9)
		"oak":
			tex = "leaves_oak"
			tvar = Color(0.85, 0.95, 0.8)
		"ash":
			tex = "leaves_oak"
			tint = Color(1.05, 1.1, 0.95)
		"shrub":
			tex = "leaves_shrub"
			tint = Color(0.95, 1.0, 0.9)
		"hedge":
			tex = "leaves_oak"
			tint = Color(0.88, 1.0, 0.85)
	m.set_shader_parameter("leaf_tex", TX.t(tex))
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("tint_var", tvar)
	m.set_shader_parameter("translucency", trans)
	m.set_shader_parameter("wind_strength", 0.35 if GameSettings.weather == "rain" else 0.22)
	m.set_shader_parameter("sway_height", 0.012)
	leaf_mats[species] = m
	return m


func _bark_mat(species: String) -> StandardMaterial3D:
	if bark_mats.has(species):
		return bark_mats[species]
	var gum := species == "gum" or species == "angophora"
	var m := StandardMaterial3D.new()
	m.albedo_texture = TX.t("bark_gum_albedo" if gum else "bark_oak_albedo")
	m.normal_enabled = true
	m.normal_texture = TX.t("bark_gum_normal" if gum else "bark_oak_normal")
	m.normal_scale = 1.0
	m.roughness = 0.9
	m.uv1_scale = Vector3(1.0, 0.6, 1.0)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if species == "angophora":
		m.albedo_color = Color(0.95, 0.82, 0.72)
	bark_mats[species] = m
	return m


# ---------------------------------------------------------------------- trees
func _species_list() -> Array:
	return [["gum", 0.68], ["angophora", 0.32]] if theme == "nsw" else [["oak", 0.62], ["ash", 0.38]]


func _trees(root: Node3D) -> void:
	var count: int = ([3000, 7000, 11000, 16000] if theme == "nsw" else [1800, 3800, 6000, 8500])[quality]
	var variants := 3
	# meshes: [species][variant][lod]
	var meshes := {}
	for sp in _species_list():
		var list := []
		for v in range(variants):
			list.append([TreeGen.make(sp[0], 1000 + v * 17 + sp[0].length(), 0), TreeGen.make(sp[0], 1000 + v * 17 + sp[0].length(), 1)])
		meshes[sp[0]] = list
	var buckets := {}   # key "cx,cz|species|variant" -> Array[Transform3D]
	var reach := track.bounds.grow(2000.0)
	var tries := count * 5
	var placed := 0
	while tries > 0 and placed < count:
		tries -= 1
		var x: float
		var z: float
		if rng.randf() < 0.82:
			var ts := rng.randf() * track.length
			var lat := (17.0 + pow(rng.randf(), 2.2) * 900.0) * (1.0 if rng.randf() < 0.5 else -1.0)
			var fr := track.flat_frame_at(ts, lat)
			x = fr.origin.x
			z = fr.origin.z
		else:
			x = rng.randf_range(reach.position.x, reach.end.x)
			z = rng.randf_range(reach.position.y, reach.end.y)
		terrain.query(x, z)
		if terrain.q_d < 17.0:
			continue
		if theme == "ecml":
			# English trees: copses, field corners and hedgerows, not mid-field
			var clump := terrain.n_patch.get_noise_2d(x * 2.3, z * 2.3)
			if clump < 0.3 and rng.randf() > 0.12:
				continue
		else:
			# NSW bush is patchy: denser in gullies, sparser on open grassland
			var dens := terrain.n_patch.get_noise_2d(x * 1.7, z * 1.7) * 0.5 + 0.5
			if rng.randf() > 0.25 + dens * 0.9:
				continue
		var h := terrain.shaped(x, z, terrain.q_d, terrain.q_h, terrain.q_br)
		if h < terrain.water_y + 0.8:
			continue
		var sp := _pick_species()
		var v := rng.randi_range(0, variants - 1)
		var sc := rng.randf_range(0.75, 1.3)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), Vector3(x, h - 0.15, z))
		var key := "%d,%d|%s|%d" % [int(floor(x / CELL)), int(floor(z / CELL)), sp, v]
		if not buckets.has(key):
			buckets[key] = []
		buckets[key].append(xf)
		placed += 1
	var near_end: float = [350.0, 600.0, 900.0, 1300.0][quality]
	var far_end: float = [2200.0, 3200.0, 4500.0, 6000.0][quality]
	for key in buckets:
		var parts: PackedStringArray = key.split("|")
		var sp := parts[1]
		var v := int(parts[2])
		var list: Array = buckets[key]
		var near := _mmi(root, meshes[sp][v][0], list, [_bark_mat(sp), _leaf_mat(sp)])
		near.visibility_range_end = near_end
		near.visibility_range_end_margin = 60.0
		near.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		var far := _mmi(root, meshes[sp][v][1], list, [_bark_mat(sp), _leaf_mat(sp)])
		far.visibility_range_begin = near_end
		far.visibility_range_begin_margin = 60.0
		far.visibility_range_end = far_end
		far.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _pick_species() -> String:
	var r := rng.randf()
	var acc := 0.0
	for sp in _species_list():
		acc += float(sp[1])
		if r <= acc:
			return sp[0]
	return _species_list()[0][0]


func _mmi(root: Node3D, mesh: Mesh, xforms: Array, mats: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	# per-surface materials via a duplicate mesh is costly; set on the mesh itself
	for si in range(mini(mesh.get_surface_count(), mats.size())):
		mesh.surface_set_material(si, mats[si])
	root.add_child(mmi)
	return mmi


# --------------------------------------------------------------------- shrubs
func _shrubs(root: Node3D) -> void:
	var count: int = [600, 2200, 4500, 7000][quality]
	var meshes := []
	for v in range(3):
		var bm := TreeGen.bush(300 + v, rng.randf_range(0.8, 1.3), rng.randf_range(1.0, 1.8))
		bm.surface_set_material(0, _leaf_mat("shrub"))
		meshes.append(bm)
	var buckets := {}
	var placed := 0
	var tries := count * 4
	while placed < count and tries > 0:
		tries -= 1
		var ts := rng.randf() * track.length
		var lat := (9.0 + pow(rng.randf(), 1.6) * 380.0) * (1.0 if rng.randf() < 0.5 else -1.0)
		var fr := track.flat_frame_at(ts, lat)
		var x := fr.origin.x
		var z := fr.origin.z
		terrain.query(x, z)
		if terrain.q_d < 9.0:
			continue
		var h := terrain.shaped(x, z, terrain.q_d, terrain.q_h, terrain.q_br)
		if h < terrain.water_y + 0.5:
			continue
		var v := rng.randi_range(0, 2)
		var key := "%d,%d|%d" % [int(floor(x / CELL)), int(floor(z / CELL)), v]
		if not buckets.has(key):
			buckets[key] = []
		var sc := rng.randf_range(0.6, 1.4)
		buckets[key].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.8, 1.2), sc)), Vector3(x, h - 0.1, z)))
		placed += 1
	for key in buckets:
		var v := int(key.split("|")[1])
		var mmi := _mmi(root, meshes[v], buckets[key], [_leaf_mat("shrub")])
		mmi.visibility_range_end = [400.0, 700.0, 1000.0, 1400.0][quality]
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if quality >= 2 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ---------------------------------------------------------------------- rocks
func _rocks(root: Node3D) -> void:
	var count: int = [150, 450, 900, 1400][quality]
	var mat := TX.pbr("sandstone_albedo", "sandstone_normal", Color(1, 1, 1), 0.88, 0.0, Vector3.ONE * 0.12, true, 1.2, "rock_sandstone")
	var meshes := []
	for v in range(4):
		var rm := TreeGen.rock(500 + v)
		rm.surface_set_material(0, mat)
		meshes.append(rm)
	var buckets := {}
	var placed := 0
	var tries := count * 6
	while placed < count and tries > 0:
		tries -= 1
		var ts := rng.randf() * track.length
		var lat := (12.0 + pow(rng.randf(), 1.5) * 300.0) * (1.0 if rng.randf() < 0.5 else -1.0)
		var fr := track.flat_frame_at(ts, lat)
		var x := fr.origin.x
		var z := fr.origin.z
		terrain.query(x, z)
		if terrain.q_d < 11.0:
			continue
		var h := terrain.shaped(x, z, terrain.q_d, terrain.q_h, terrain.q_br)
		var h2 := terrain.height_at(x + 2.0, z)
		var h3 := terrain.height_at(x, z + 2.0)
		var slope := Vector2(h2 - h, h3 - h).length() / 2.0
		# outcrops on slopes and along the tops of cuttings
		if slope < 0.15 and rng.randf() > 0.15:
			continue
		if h < terrain.water_y + 0.2:
			continue
		var v := rng.randi_range(0, 3)
		var key := "%d,%d|%d" % [int(floor(x / CELL)), int(floor(z / CELL)), v]
		if not buckets.has(key):
			buckets[key] = []
		var sc := rng.randf_range(0.5, 2.6)
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.2, 0.2))
		buckets[key].append(Transform3D(b.scaled(Vector3.ONE * sc), Vector3(x, h - sc * 0.35, z)))
		placed += 1
	for key in buckets:
		var v := int(key.split("|")[1])
		var mmi := _mmi(root, meshes[v], buckets[key], [mat])
		mmi.visibility_range_end = [500.0, 900.0, 1400.0, 2000.0][quality]


# ------------------------------------------------------------------ hedgerows
func _hedgerows(root: Node3D) -> void:
	var seg_len := 18.0
	var band: float = [200.0, 350.0, 500.0, 700.0][quality]
	var hedge_mesh := TreeGen.bush(700, 1.0, 2.4, seg_len)
	hedge_mesh.surface_set_material(0, _leaf_mat("hedge"))
	var oak_mesh := TreeGen.make("oak", 1777, 0)
	var oak_far := TreeGen.make("oak", 1777, 1)
	var buckets := {}
	var oak_buckets := {}
	var fs := TerrainBuilder.FIELD_SIZE
	# walk the field grid lines (in rotated field space) near the railway
	var b := track.bounds.grow(band + 50.0)
	var corners := [b.position, Vector2(b.end.x, b.position.y), b.end, Vector2(b.position.x, b.end.y)]
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for cpt in corners:
		var rp := terrain.field_rot(cpt)
		lo = Vector2(minf(lo.x, rp.x), minf(lo.y, rp.y))
		hi = Vector2(maxf(hi.x, rp.x), maxf(hi.y, rp.y))
	for axis in range(2):
		var spacing: float = fs.x if axis == 0 else fs.y
		var other_spacing: float = fs.y if axis == 0 else fs.x
		var line_lo: float = lo.x if axis == 0 else lo.y
		var line_hi: float = hi.x if axis == 0 else hi.y
		var run_lo: float = lo.y if axis == 0 else lo.x
		var run_hi: float = hi.y if axis == 0 else hi.x
		var k := ceilf(line_lo / spacing)
		while k * spacing < line_hi:
			var u := k * spacing
			var w := run_lo
			while w < run_hi:
				var mid := w + seg_len * 0.5
				var fp := Vector2(u, mid) if axis == 0 else Vector2(mid, u)
				var wp := terrain.field_unrot(fp)
				w += seg_len
				# keep a few gaps (field gates) and only near the line
				if absf(fmod(mid, other_spacing)) < 6.0:
					continue
				terrain.query(wp.x, wp.y)
				if terrain.q_d < 26.0 or terrain.coarse_dist(wp.x, wp.y) > band:
					continue
				if rng.randf() < 0.15:
					continue
				var h := terrain.height_at(wp.x, wp.y)
				if h < terrain.water_y + 0.5:
					continue
				var dir_v := terrain.field_unrot(Vector2(0, 1) if axis == 0 else Vector2(1, 0))
				var yaw := atan2(dir_v.x, dir_v.y)
				var xf := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(1.0, rng.randf_range(0.8, 1.25), 1.0)), Vector3(wp.x, h - 0.2, wp.y))
				var key := "%d,%d" % [int(floor(wp.x / CELL)), int(floor(wp.y / CELL))]
				if not buckets.has(key):
					buckets[key] = []
				buckets[key].append(xf)
				if rng.randf() < 0.22:
					if not oak_buckets.has(key):
						oak_buckets[key] = []
					var sc := rng.randf_range(0.9, 1.35)
					oak_buckets[key].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), Vector3(wp.x, h - 0.2, wp.y)))
			k += 1.0
	for key in buckets:
		var mmi := _mmi(root, hedge_mesh, buckets[key], [_leaf_mat("hedge")])
		mmi.visibility_range_end = [700.0, 1200.0, 1800.0, 2600.0][quality]
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	for key in oak_buckets:
		var near := _mmi(root, oak_mesh, oak_buckets[key], [_bark_mat("oak"), _leaf_mat("oak")])
		near.visibility_range_end = [350.0, 600.0, 900.0, 1300.0][quality]
		var far := _mmi(root, oak_far, oak_buckets[key], [_bark_mat("oak"), _leaf_mat("oak")])
		far.visibility_range_begin = [350.0, 600.0, 900.0, 1300.0][quality]
		far.visibility_range_end = [2200.0, 3200.0, 4500.0, 6000.0][quality]
		far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
