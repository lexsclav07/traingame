class_name MU
## Mesh and material helpers. All geometry in the game is built in code from
## these, so the project has no binary assets and every part is easy to tweak.

static var _mats := {}


static func mat(color: Color, rough := 0.7, metal := 0.0, key := "") -> StandardMaterial3D:
	var k := key if key != "" else "%s|%.2f|%.2f" % [color.to_html(), rough, metal]
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if color.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[k] = m
	return m


static func glass(tint := Color(0.55, 0.65, 0.7, 0.18)) -> StandardMaterial3D:
	var k := "glass|" + tint.to_html()
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	m.metallic = 0.3
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[k] = m
	return m


## A fresh (uncached) emissive material, so callers can animate its energy.
static func lamp(color: Color, energy := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color.darkened(0.6)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.roughness = 0.3
	return m


static func unshaded(color: Color) -> StandardMaterial3D:
	var k := "unsh|" + color.to_html()
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats[k] = m
	return m


static func noise_mat(base: Color, var_amt := 0.15, scale := 0.25, rough := 0.95, key := "") -> StandardMaterial3D:
	## Triplanar noise-textured material (ballast, ground, rock).
	var k := "noise|" + key + base.to_html()
	if _mats.has(k):
		return _mats[k]
	var nt := NoiseTexture2D.new()
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_CELLULAR if key.begins_with("ballast") else FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.frequency = 0.08
	fn.fractal_octaves = 3
	nt.noise = fn
	nt.width = 256
	nt.height = 256
	nt.seamless = true
	var grad := Gradient.new()
	grad.set_color(0, base.darkened(var_amt))
	grad.set_color(1, base.lightened(var_amt))
	nt.color_ramp = grad
	var m := StandardMaterial3D.new()
	m.albedo_texture = nt
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.roughness = rough
	_mats[k] = m
	return m


static func add(parent: Node, node: Node3D, pos := Vector3.ZERO, rot_deg := Vector3.ZERO) -> Node3D:
	parent.add_child(node)
	node.position = pos
	node.rotation_degrees = rot_deg
	return node


static func box(parent: Node, size: Vector3, pos: Vector3, material: Material, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = material
	add(parent, mi, pos, rot_deg)
	return mi


static func cyl(parent: Node, radius: float, height: float, pos: Vector3, material: Material, rot_deg := Vector3.ZERO, segs := 16, r_top := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = radius
	cm.top_radius = radius if r_top < 0.0 else r_top
	cm.height = height
	cm.radial_segments = segs
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = material
	add(parent, mi, pos, rot_deg)
	return mi


static func sphere(parent: Node, radius: float, pos: Vector3, material: Material, segs := 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = segs
	sm.rings = maxi(4, segs / 2)
	mi.mesh = sm
	mi.material_override = material
	add(parent, mi, pos)
	return mi


static func torus(parent: Node, r_inner: float, r_outer: float, pos: Vector3, material: Material, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r_inner
	tm.outer_radius = r_outer
	tm.rings = 24
	tm.ring_segments = 8
	mi.mesh = tm
	mi.material_override = material
	add(parent, mi, pos, rot_deg)
	return mi


static func label(parent: Node, text: String, pos: Vector3, px := 0.0012, color := Color(0.95, 0.95, 0.9), rot_deg := Vector3.ZERO, font_size := 32) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.pixel_size = px
	l.font_size = font_size
	l.modulate = color
	l.outline_size = 0
	l.double_sided = false
	l.shaded = false
	add(parent, l, pos, rot_deg)
	return l


## Loft a mesh through a list of closed rings (each ring same vertex count).
static func loft(rings: Array, material: Material, cap_start := true, cap_end := true, smooth := true) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0 if smooth else -1)
	var n: int = (rings[0] as PackedVector3Array).size()
	for r in range(rings.size() - 1):
		var a: PackedVector3Array = rings[r]
		var b: PackedVector3Array = rings[r + 1]
		for i in range(n):
			var j := (i + 1) % n
			st.add_vertex(a[i]); st.add_vertex(b[i]); st.add_vertex(b[j])
			st.add_vertex(a[i]); st.add_vertex(b[j]); st.add_vertex(a[j])
	st.set_smooth_group(-1)
	if cap_start:
		_cap(st, rings[0], true)
	if cap_end:
		_cap(st, rings[rings.size() - 1], false)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = material
	return mi


static func _cap(st: SurfaceTool, ring: PackedVector3Array, flip: bool) -> void:
	var c := Vector3.ZERO
	for p in ring:
		c += p
	c /= ring.size()
	for i in range(ring.size()):
		var j := (i + 1) % ring.size()
		# Godot front faces are clockwise: (b-a)x(c-a) must point *into* the solid.
		if flip:
			st.add_vertex(c); st.add_vertex(ring[i]); st.add_vertex(ring[j])
		else:
			st.add_vertex(c); st.add_vertex(ring[j]); st.add_vertex(ring[i])


## Extrude a 2D profile (x = lateral, y = up) along a list of frames.
static func extrude(profile: PackedVector2Array, frames: Array, st: SurfaceTool, closed := false, uv_v_scale := 1.0, dist: PackedFloat32Array = PackedFloat32Array()) -> void:
	var n := profile.size()
	var segs := n if closed else n - 1
	for f in range(frames.size() - 1):
		var ta: Transform3D = frames[f]
		var tb: Transform3D = frames[f + 1]
		var va := float(f) if dist.is_empty() else dist[f]
		var vb := float(f + 1) if dist.is_empty() else dist[f + 1]
		for i in range(segs):
			var j := (i + 1) % n
			var a0 := ta * Vector3(profile[i].x, profile[i].y, 0)
			var a1 := ta * Vector3(profile[j].x, profile[j].y, 0)
			var b0 := tb * Vector3(profile[i].x, profile[i].y, 0)
			var b1 := tb * Vector3(profile[j].x, profile[j].y, 0)
			var u0 := float(i) / segs
			var u1 := float(i + 1) / segs
			st.set_uv(Vector2(u0, va * uv_v_scale)); st.add_vertex(a0)
			st.set_uv(Vector2(u0, vb * uv_v_scale)); st.add_vertex(b0)
			st.set_uv(Vector2(u1, vb * uv_v_scale)); st.add_vertex(b1)
			st.set_uv(Vector2(u0, va * uv_v_scale)); st.add_vertex(a0)
			st.set_uv(Vector2(u1, vb * uv_v_scale)); st.add_vertex(b1)
			st.set_uv(Vector2(u1, va * uv_v_scale)); st.add_vertex(a1)


## Rounded-rectangle ring in the XY plane at depth z (for car bodies / cabs).
static func rounded_ring(half_w: float, y_bottom: float, y_top: float, radius: float, z: float, segs := 4) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var r := minf(radius, minf(half_w, y_top - y_bottom))
	# counter-clockwise (seen from +z) starting bottom-left
	pts.append(Vector3(-half_w, y_bottom, z))
	pts.append(Vector3(half_w, y_bottom, z))
	for i in range(segs + 1):
		var a := (PI * 0.5) * i / segs
		pts.append(Vector3(half_w - r + cos(a) * r, y_top - r + sin(a) * r, z))
	for i in range(segs + 1):
		var a := PI * 0.5 + (PI * 0.5) * i / segs
		pts.append(Vector3(-half_w + r + cos(a) * r, y_top - r + sin(a) * r, z))
	return pts
