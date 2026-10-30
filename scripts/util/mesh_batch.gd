class_name MeshBatch
extends RefCounted
## Collects geometry for many small objects into one mesh with one surface per
## material, so a whole village or a signal box worth of parts is a single draw
## per material instead of hundreds of nodes.
##
## Two kinds of surface (do not mix them under one key):
##  - primitive: append_from() of BoxMesh / CylinderMesh / any mesh (keeps its
##    normals and tangents; use triplanar materials for textures)
##  - manual: quads/triangles added with explicit UVs and flat normals; tangents
##    are generated on commit so UV-mapped normal maps work.

var _st := {}
var _mat := {}
var _manual := {}
var _order: Array[String] = []
static var _box_cache := {}


## Surfaces are keyed by (key, material) so different materials never share one.
func surf(key: String, mat: Material, manual := false) -> SurfaceTool:
	key = key + "#" + str(mat.get_instance_id() if mat else 0)
	if not _st.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_st[key] = st
		_mat[key] = mat
		_manual[key] = manual
		_order.append(key)
	return _st[key]


func is_empty() -> bool:
	return _st.is_empty()


## Append any mesh (all surfaces) transformed by xf.
func mesh(key: String, mat: Material, m: Mesh, xf: Transform3D) -> void:
	var st := surf(key, mat)
	for i in range(m.get_surface_count()):
		st.append_from(m, i, xf)


func box(key: String, mat: Material, size: Vector3, xf: Transform3D) -> void:
	var k := "%.3f,%.3f,%.3f" % [size.x, size.y, size.z]
	var bm: BoxMesh = _box_cache.get(k)
	if bm == null:
		bm = BoxMesh.new()
		bm.size = size
		_box_cache[k] = bm
	mesh(key, mat, bm, xf)


## Box given by its centre in the local frame 'base'.
func box_at(key: String, mat: Material, base: Transform3D, size: Vector3, centre: Vector3, rot := Basis()) -> void:
	box(key, mat, size, base * Transform3D(rot, centre))


func cyl(key: String, mat: Material, xf: Transform3D, r_top: float, r_bot: float, h: float, segs := 10) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = segs
	cm.rings = 1
	mesh(key, mat, cm, xf)


## Cylinder between two points.
func tube(key: String, mat: Material, a: Vector3, b: Vector3, r: float, segs := 8) -> void:
	var d := b - a
	var len := d.length()
	if len < 1e-4:
		return
	var basis := Basis(Quaternion(Vector3.UP, d / len)) if absf(d.normalized().y) < 0.9999 else Basis()
	if d.y < 0.0 and absf(d.normalized().y) >= 0.9999:
		basis = Basis(Vector3.RIGHT, PI)
	cyl(key, mat, Transform3D(basis, (a + b) * 0.5), r, r, len, segs)


## Quad p0..p3 = bottom-left, bottom-right, top-right, top-left as seen from
## the side it faces. uv defaults to the unit square.
func quad(key: String, mat: Material, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3,
		uv0 := Vector2(0, 1), uv1 := Vector2(1, 1), uv2 := Vector2(1, 0), uv3 := Vector2(0, 0)) -> void:
	var st := surf(key, mat, true)
	var n := (p1 - p0).cross(p3 - p0).normalized()
	st.set_normal(n)
	st.set_uv(uv0); st.add_vertex(p0)
	st.set_uv(uv3); st.add_vertex(p3)
	st.set_uv(uv2); st.add_vertex(p2)
	st.set_uv(uv0); st.add_vertex(p0)
	st.set_uv(uv2); st.add_vertex(p2)
	st.set_uv(uv1); st.add_vertex(p1)


## Triangle a, b, c clockwise as seen from the side it faces.
func tri(key: String, mat: Material, a: Vector3, b: Vector3, c: Vector3,
		ua := Vector2.ZERO, ub := Vector2.ZERO, uc := Vector2.ZERO) -> void:
	var st := surf(key, mat, true)
	var n := (c - a).cross(b - a).normalized()
	st.set_normal(n)
	st.set_uv(ua); st.add_vertex(a)
	st.set_uv(ub); st.add_vertex(b)
	st.set_uv(uc); st.add_vertex(c)


## A planar polygon given by world-space corners and a tiling size in metres,
## UVs from the plane's own axes (u along 'u_dir'). Fan-triangulated; convex only.
func poly(key: String, mat: Material, pts: Array, u_dir: Vector3, tile := Vector2.ONE) -> void:
	if pts.size() < 3:
		return
	var n := ((pts[2] as Vector3) - (pts[0] as Vector3)).cross((pts[1] as Vector3) - (pts[0] as Vector3)).normalized()
	var ud := (u_dir - n * u_dir.dot(n)).normalized()
	var vd := n.cross(ud)
	var o: Vector3 = pts[0]
	var uvs := []
	for p in pts:
		var q: Vector3 = p - o
		uvs.append(Vector2(q.dot(ud) / tile.x, -q.dot(vd) / tile.y))
	for i in range(1, pts.size() - 1):
		tri(key, mat, pts[0], pts[i], pts[i + 1], uvs[0], uvs[i], uvs[i + 1])


func commit_mesh() -> ArrayMesh:
	var am := ArrayMesh.new()
	for key in _order:
		var st: SurfaceTool = _st[key]
		if _manual[key]:
			st.generate_tangents()
		st.commit(am)
		am.surface_set_material(am.get_surface_count() - 1, _mat[key])
	return am


func commit(parent: Node, name := "Batch") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = commit_mesh()
	parent.add_child(mi)
	return mi
