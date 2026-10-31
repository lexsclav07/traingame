class_name SceneryBuilder
extends RefCounted
## Lineside scenery: overhead wiring (NSW) or a telegraph route (ECML), signals,
## speed boards, distance posts, the station (platform, building, canopy, lamps,
## seats, name boards), boundary fences and the houses and farms along the line.
## Most of it is merged into a few big meshes (MeshBatch) or MultiMeshes so the
## whole route costs a handful of draw calls.

const CONTACT_H := 5.4       # contact wire height above rail (NSW-style)
const MESSENGER_H := 6.6
const SPAN := 55.0
const FENCE_CHUNK := 400.0

var track: Track
var terrain: TerrainBuilder
var theme := "nsw"
var quality := 2
var platform_lights: Array[OmniLight3D] = []
## materials that glow after dark (lamp glasses, lit windows, semaphore lamps)
var night_mats: Array[StandardMaterial3D] = []
var _plat_ranges := []
var _m := {}


func build(parent: Node3D, t: Track, ter: TerrainBuilder, q: int) -> void:
	track = t
	terrain = ter
	theme = t.route["theme"]
	quality = q
	_materials()
	if GameSettings.weather == "rain":
		for k in ["paving", "coping", "conc", "tactile", "brick", "stone", "timber"]:
			_m[k] = TX.wet(_m[k])
	var root := Node3D.new()
	root.name = "Scenery"
	parent.add_child(root)
	_platforms(root)
	if t.route.get("electrified", false):
		_overhead(root)
	else:
		_telegraph(root)
	_speed_boards(root)
	_distance_posts(root)
	_buildings(root, q)
	_trough_boards(root)
	_fences(root, q)
	_signals(root)
	if theme == "nsw":
		_cable_troughing(root, q)


func _materials() -> void:
	var nsw := theme == "nsw"
	_m["conc"] = TX.pbr("concrete_albedo", "concrete_normal", Color(0.82, 0.81, 0.78), 0.9, 0.0, Vector3.ONE * 0.5, true, 1.0, "s_conc")
	_m["coping"] = TX.pbr("concrete_albedo", "concrete_normal", Color(0.92, 0.91, 0.88) if nsw else Color(0.86, 0.82, 0.74), 0.85, 0.0, Vector3.ONE * 0.8, true, 1.0, "s_coping")
	_m["brick"] = TX.pbr("brick_albedo", "brick_normal", Color.WHITE, 0.92, 0.0, Vector3.ONE * 0.55, true, 1.0, "s_brick")
	_m["brick_dark"] = TX.pbr("brick_albedo", "brick_normal", Color(0.78, 0.72, 0.7), 0.92, 0.0, Vector3.ONE * 0.55, true, 1.0, "s_brick_dark")
	_m["brick_cream"] = TX.pbr("brick_albedo", "brick_normal", Color(1.35, 1.3, 1.1), 0.92, 0.0, Vector3.ONE * 0.55, true, 1.0, "s_brick_cream")
	_m["stone"] = TX.pbr("stone_albedo", "stone_normal", Color.WHITE, 0.9, 0.0, Vector3.ONE * 0.42, true, 1.0, "s_stone")
	_m["paving"] = TX.uv("paving_albedo", "paving_normal", Color(0.86, 0.85, 0.82) if nsw else Color(0.8, 0.74, 0.66), 0.88, 0.0, Vector2(2.4, 2.4), 1.0, "s_paving")
	_m["tactile"] = TX.uv("tactile_albedo", "tactile_normal", Color.WHITE, 0.7, 0.0, Vector2(0.6, 0.6), 1.0, "s_tactile")
	_m["yellow"] = TX.painted(Color(0.95, 0.76, 0.08), 0.6, 0.0, "grime", 0.5, 0.0, "s_yellow")
	_m["white"] = TX.painted(Color(0.9, 0.9, 0.86), 0.55, 0.0, "grime", 0.5, 0.0, "s_white")
	_m["cream"] = TX.painted(Color(0.88, 0.82, 0.66), 0.55, 0.0, "grime", 0.5, 0.0, "s_cream")
	_m["green"] = TX.painted(Color(0.12, 0.28, 0.18), 0.5, 0.0, "grime", 0.5, 0.0, "s_green")
	_m["black"] = TX.painted(Color(0.035, 0.035, 0.035), 0.55, 0.1, "grime", 0.5, 0.0, "s_black")
	_m["dark_steel"] = TX.painted(Color(0.14, 0.16, 0.15), 0.5, 0.4, "grime", 0.5, 0.0, "s_darksteel")
	_m["galv"] = TX.metal(Color(0.62, 0.64, 0.64), 0.55, true, 1.5, "galv")
	_m["timber"] = TX.pbr("timber_albedo", "timber_normal", Color(1.5, 1.4, 1.3), 0.9, 0.0, Vector3.ONE * 0.8, true, 1.0, "s_timber")
	_m["board"] = TX.pbr("weatherboard_albedo", "weatherboard_normal", Color(0.95, 0.93, 0.86), 0.8, 0.0, Vector3.ONE / 1.2, true, 1.0, "s_board")
	_m["iron_red"] = TX.uv("roofiron_albedo", "roofiron_normal", Color(0.78, 0.36, 0.3), 0.5, 0.35, Vector2(1.22, 1.22), 1.0, "s_iron_red")
	_m["iron_green"] = TX.uv("roofiron_albedo", "roofiron_normal", Color(0.4, 0.55, 0.42), 0.5, 0.35, Vector2(1.22, 1.22), 1.0, "s_iron_green")
	_m["iron_grey"] = TX.uv("roofiron_albedo", "roofiron_normal", Color(0.95, 0.96, 0.97), 0.42, 0.55, Vector2(1.22, 1.22), 1.0, "s_iron_grey")
	_m["iron_tank"] = TX.pbr("roofiron_albedo", "roofiron_normal", Color(0.95, 0.96, 0.97), 0.42, 0.55, Vector3.ONE / 1.22, true, 1.0, "s_iron_tank")
	_m["slate"] = TX.uv("slate_albedo", "slate_normal", Color.WHITE, 0.55, 0.0, Vector2(2.0, 2.0), 1.0, "s_slate")
	_m["tile"] = TX.uv("rooftile_albedo", "rooftile_normal", Color.WHITE, 0.75, 0.0, Vector2(1.8, 2.1), 1.0, "s_tile")
	_m["window"] = TX.uv("window_albedo", "", Color.WHITE, 0.18, 0.0, Vector2.ONE, 1.0, "s_window")
	var lit := (_m["window"] as StandardMaterial3D).duplicate() as StandardMaterial3D
	lit.emission_enabled = true
	lit.emission = Color(1.0, 0.72, 0.42)
	lit.emission_texture = TX.t("window_mask")
	lit.emission_energy_multiplier = 0.0
	_m["window_lit"] = lit
	night_mats.append(lit)
	_m["door"] = TX.uv("door_albedo", "", Color.WHITE, 0.55, 0.0, Vector2.ONE, 1.0, "s_door")
	var glass := MU.lamp(Color(1.0, 0.86, 0.62), 0.0)
	_m["lamp_glass"] = glass
	night_mats.append(glass)


func _side_profile(pts: Array, side: float) -> PackedVector2Array:
	## Profiles are written for the right-hand side (x = distance out from the
	## track centre), clockwise looking along the line. Mirror for the left.
	var out := PackedVector2Array()
	if side > 0.0:
		for p in pts:
			out.append(p)
	else:
		for i in range(pts.size() - 1, -1, -1):
			var p: Vector2 = pts[i]
			out.append(Vector2(-p.x, p.y))
	return out


## Extrude a profile that may change from frame to frame (same point count).
## UVs: u = metres around the profile, v = metres along. Optional end caps.
func _extrude(st: SurfaceTool, profiles: Array, frames: Array, dists: PackedFloat32Array, closed := false, caps := false) -> void:
	var n: int = (profiles[0] as PackedVector2Array).size()
	var segs := n if closed else n - 1
	st.set_smooth_group(-1)
	for f in range(frames.size() - 1):
		var ta: Transform3D = frames[f]
		var tb: Transform3D = frames[f + 1]
		var pa: PackedVector2Array = profiles[f]
		var pb: PackedVector2Array = profiles[f + 1]
		var u := 0.0
		for i in range(segs):
			var j := (i + 1) % n
			var a0 := ta * Vector3(pa[i].x, pa[i].y, 0)
			var a1 := ta * Vector3(pa[j].x, pa[j].y, 0)
			var b0 := tb * Vector3(pb[i].x, pb[i].y, 0)
			var b1 := tb * Vector3(pb[j].x, pb[j].y, 0)
			var du := pa[i].distance_to(pa[j])
			st.set_uv(Vector2(u, dists[f])); st.add_vertex(a0)
			st.set_uv(Vector2(u, dists[f + 1])); st.add_vertex(b0)
			st.set_uv(Vector2(u + du, dists[f + 1])); st.add_vertex(b1)
			st.set_uv(Vector2(u, dists[f])); st.add_vertex(a0)
			st.set_uv(Vector2(u + du, dists[f + 1])); st.add_vertex(b1)
			st.set_uv(Vector2(u + du, dists[f])); st.add_vertex(a1)
			u += du
	if caps:
		for e in [0, frames.size() - 1]:
			var fr: Transform3D = frames[e]
			var pr: PackedVector2Array = profiles[e]
			for i in range(1, n - 1):
				var a := fr * Vector3(pr[0].x, pr[0].y, 0)
				var b := fr * Vector3(pr[i].x, pr[i].y, 0)
				var c := fr * Vector3(pr[i + 1].x, pr[i + 1].y, 0)
				st.set_uv(Vector2(pr[0].x, pr[0].y)); st.add_vertex(a)
				if e == 0:
					st.set_uv(Vector2(pr[i].x, pr[i].y)); st.add_vertex(b)
					st.set_uv(Vector2(pr[i + 1].x, pr[i + 1].y)); st.add_vertex(c)
				else:
					st.set_uv(Vector2(pr[i + 1].x, pr[i + 1].y)); st.add_vertex(c)
					st.set_uv(Vector2(pr[i].x, pr[i].y)); st.add_vertex(b)


func _strip_mesh(parent: Node3D, mat: Material, profiles: Array, frames: Array, dists: PackedFloat32Array, closed := false, caps := false, name := "") -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_extrude(st, profiles, frames, dists, closed, caps)
	st.generate_normals()
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	if name != "":
		mi.name = name
	parent.add_child(mi)
	return mi


# --------------------------------------------------------------- overhead
func _overhead(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Overhead"
	root.add_child(node)
	var wire_mat := TX.metal(Color(0.55, 0.38, 0.25), 0.45, false, 1.0, "wire")
	var mast_mesh := _mast_assembly()
	var masts := []
	var contact := []
	var messenger := []
	var droppers := []
	var count := int(track.length / SPAN)
	var span := track.length / count
	for i in range(count):
		var s := i * span
		var k := track.curv_at(s)
		var side := -1.0 if k > 0.0001 else 1.0        # masts on the outside of curves
		if _on_platform(s, 12.0) and side == float(_platform_side(s)):
			side = -side
		var f := track.flat_frame_at(s)
		var ground := f.origin.y - 0.62
		var mpos := f.origin + f.basis.x * (3.4 * side)
		# the assembly's +X points at the track
		var mb := f.basis if side < 0.0 else Basis(-f.basis.x, f.basis.y, -f.basis.z)
		masts.append(Transform3D(mb, Vector3(mpos.x, ground, mpos.z)))
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
	var mmi := _multimesh(node, mast_mesh, null, masts)
	mmi.name = "Masts"
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


## Overhead line structure: H-section mast on a concrete footing, cantilever
## (top tube, diagonal and registration tube), registration arm and insulators.
## Local +X points at the track; y = 0 is the cess level.
func _mast_assembly() -> ArrayMesh:
	var b := MeshBatch.new()
	var galv: Material = _m["galv"]
	var ins := MU.mat(Color(0.36, 0.2, 0.12), 0.25, 0.0, "insulator")
	var conc: Material = _m["conc"]
	var I := Transform3D()
	b.box("conc", conc, Vector3(0.8, 0.7, 0.8), Transform3D(Basis(), Vector3(0, 0.0, 0)))
	for fx in [-0.12, 0.12]:
		b.box("galv", galv, Vector3(0.022, 7.75, 0.26), Transform3D(Basis(), Vector3(fx, 4.2, 0)))
	b.box("galv", galv, Vector3(0.24, 7.75, 0.018), Transform3D(Basis(), Vector3(0, 4.2, 0)))
	b.box("galv", galv, Vector3(0.34, 0.03, 0.32), Transform3D(Basis(), Vector3(0, 8.08, 0)))
	b.box("galv", galv, Vector3(0.36, 0.06, 0.36), Transform3D(Basis(), Vector3(0, 0.38, 0)))
	var y_top := 7.32        # messenger support (messenger 6.6 m above rail = 7.22 above cess)
	var y_reg := 6.3         # registration tube, above the contact wire (6.02)
	b.tube("galv", galv, Vector3(0.12, y_top, 0), Vector3(3.62, y_top, 0), 0.03)
	b.tube("galv", galv, Vector3(0.12, y_reg, 0), Vector3(3.3, y_top - 0.04, 0), 0.027)
	b.tube("galv", galv, Vector3(0.12, y_reg, 0), Vector3(3.1, y_reg, 0), 0.025)
	b.tube("galv", galv, Vector3(2.85, y_reg, 0), Vector3(3.42, 6.06, 0), 0.016)
	b.tube("galv", galv, Vector3(3.4, y_top, 0), Vector3(3.4, y_top - 0.12, 0), 0.012)
	for iy in [y_top, y_reg]:
		b.tube("ins", ins, Vector3(0.24, iy, 0), Vector3(0.82, iy, 0), 0.03)
		for k in range(5):
			b.cyl("ins", ins, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.3 + k * 0.12, iy, 0)), 0.08, 0.08, 0.018, 12)
	return b.commit_mesh()


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
	var wire_mat := MU.mat(Color(0.1, 0.1, 0.1), 0.6, 0.3, "twire")
	# one pole assembly: creosoted pole, three cross-arms with porcelain insulators, stay
	var b := MeshBatch.new()
	var pole: Material = TX.pbr("timber_albedo", "timber_normal", Color(0.75, 0.7, 0.65), 0.92, 0.0, Vector3(2.0, 0.4, 2.0), false, 1.0, "s_pole")
	var arm_mat: Material = TX.pbr("timber_albedo", "timber_normal", Color(1.1, 1.0, 0.9), 0.9, 0.0, Vector3.ONE, false, 1.0, "s_arm")
	var porc := MU.mat(Color(0.92, 0.92, 0.9), 0.15, 0.0, "porcelain")
	var iron := MU.mat(Color(0.12, 0.11, 0.1), 0.6, 0.6, "ironwork")
	b.cyl("pole", pole, Transform3D(Basis(), Vector3(0, 4.0, 0)), 0.1, 0.14, 8.6, 9)
	b.cyl("pole", pole, Transform3D(Basis(), Vector3(0, 8.35, 0)), 0.02, 0.1, 0.14, 9)
	var tops := []
	for a in range(3):
		var ay := 7.6 - a * 0.55
		b.box("arm", arm_mat, Vector3(1.75, 0.1, 0.1), Transform3D(Basis(), Vector3(0, ay, 0.12)))
		for sx in [-1.0, 1.0]:
			b.tube("iron", iron, Vector3(0.0, ay - 0.45, 0.07), Vector3(0.55 * sx, ay - 0.04, 0.12), 0.012, 5)
		for wx in [-0.75, -0.42, 0.42, 0.75]:
			b.cyl("iron", iron, Transform3D(Basis(), Vector3(wx, ay + 0.08, 0.12)), 0.012, 0.012, 0.1, 5)
			b.cyl("porc", porc, Transform3D(Basis(), Vector3(wx, ay + 0.15, 0.12)), 0.025, 0.045, 0.1, 8)
			tops.append(Vector3(wx, ay + 0.17, 0.12))
	b.tube("iron", iron, Vector3(0, 6.8, 0), Vector3(0, -0.2, -3.6), 0.01, 4)
	var pole_mesh := b.commit_mesh()
	var poles := []
	var rows := []
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
		var xf := Transform3D(f.basis, Vector3(f.origin.x, ground - 0.3, f.origin.z))
		poles.append(xf)
		var row := []
		for tp in tops:
			row.append(xf * (tp as Vector3))
		rows.append(row)
	_multimesh(node, pole_mesh, null, poles).name = "Poles"
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(rows.size()):
		var a: Array = rows[i]
		var c: Array = rows[(i + 1) % rows.size()]
		for w in range(a.size()):
			var p0: Vector3 = a[w]
			var p1: Vector3 = c[w]
			var steps := 4
			var prev := p0
			for k in range(1, steps + 1):
				var t := float(k) / steps
				var p := p0.lerp(p1, t) - Vector3.UP * (4.0 * t * (1.0 - t) * 0.45)
				_wire(st, prev, p, 0.006)
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
	var post: Material = _m["galv"]
	var face := MU.mat(Color(0.97, 0.97, 0.95), 0.6)
	var back: Material = _m["dark_steel"]
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
func _on_platform(s: float, margin := 0.0) -> bool:
	for pl in track.route.get("platforms", []):
		var a: float = pl[0] - margin
		var b: float = pl[0] + pl[1] + margin
		var ss := track.wrap_s(s)
		if ss >= a and ss <= b:
			return true
	return false


func _platform_side(s: float) -> int:
	for pl in track.route.get("platforms", []):
		if s >= pl[0] - 20.0 and s <= pl[0] + pl[1] + 20.0:
			return int(pl[2])
	return 0


func _platforms(root: Node3D) -> void:
	var nsw := theme == "nsw"
	for pl in track.route.get("platforms", []):
		var node := Node3D.new()
		node.name = "Station"
		root.add_child(node)
		var s0: float = pl[0]
		var plen: float = pl[1]
		var side: float = pl[2]
		_plat_ranges.append([s0 - 30.0, s0 + plen + 30.0])
		var top := 1.05 if nsw else 0.92        # above rail
		var edge := 1.62 if nsw else 1.48       # coping nose from track centre
		var depth := 6.0
		var ramp := 9.0
		var frames := []
		var tops := PackedFloat32Array()
		var dists := PackedFloat32Array()
		var s := s0 - ramp
		while s <= s0 + plen + ramp + 0.01:
			frames.append(track.flat_frame_at(s))
			var t := 1.0
			if s < s0:
				t = (s - (s0 - ramp)) / ramp
			elif s > s0 + plen:
				t = (s0 + plen + ramp - s) / ramp
			tops.append(lerpf(-0.5, top, clampf(t, 0.0, 1.0)))
			dists.append(s - s0)
			s += 2.0
		var body := []
		var coping := []
		var paving := []
		var tactile := []
		var yline := []
		var fence := []
		var back := edge + depth
		var pave_from := edge + (1.15 if nsw else 0.55)
		var fence_h := 1.25 if nsw else 1.05
		for i in range(frames.size()):
			var tp := tops[i]
			body.append(_side_profile([Vector2(edge, tp - 0.004), Vector2(back, tp - 0.004), Vector2(back, -1.6), Vector2(edge, -1.6)], side))
			coping.append(_side_profile([Vector2(edge - 0.06, tp + 0.002), Vector2(edge + 0.55, tp + 0.002), Vector2(edge + 0.55, tp - 0.15), Vector2(edge - 0.06, tp - 0.15)], side))
			paving.append(_side_profile([Vector2(pave_from, tp + 0.001), Vector2(back, tp + 0.001)], side))
			tactile.append(_side_profile([Vector2(edge + 0.55, tp + 0.003), Vector2(edge + 1.15, tp + 0.003)], side))
			yline.append(_side_profile([Vector2(edge - 0.06, tp + 0.004), Vector2(edge + 0.08, tp + 0.004)], side))
			fence.append(PackedVector2Array([Vector2((back - 0.1) * side, tp + fence_h), Vector2((back - 0.1) * side, tp)]))
		_strip_mesh(node, _m["conc"] if nsw else _m["brick"], body, frames, dists, true, true, "PlatformWall")
		_strip_mesh(node, _m["coping"], coping, frames, dists, true, true, "Coping")
		_strip_mesh(node, _m["paving"], paving, frames, dists, false, false, "Paving")
		if nsw:
			_strip_mesh(node, _m["tactile"], tactile, frames, dists, false, false, "Tactile")
			_strip_mesh(node, _m["yellow"], yline, frames, dists, false, false, "EdgeLine")
		# back fence (cut-out texture) except where the building stands
		var fence_mat := TX.cutout("fence_palisade" if nsw else "fence_picket", Color.WHITE, 0.5 if nsw else 0.7, 0.3 if nsw else 0.0,
				Vector2(fence_h, 1.04 if nsw else 0.6), "s_fence_" + theme)
		var bl := 18.0 if nsw else 15.0
		var bmid := s0 + plen * 0.45
		var fa := []
		var fb := []
		var fd := PackedFloat32Array()
		var segs := []
		for i in range(frames.size()):
			var ds := dists[i] + s0
			if absf(ds - bmid) < bl * 0.5 + 0.5:
				if fa.size() > 1:
					segs.append([fa.duplicate(), fb.duplicate(), fd.duplicate()])
				fa.clear(); fb.clear(); fd.clear()
				continue
			fa.append(fence[i]); fb.append(frames[i]); fd.append(dists[i])
		if fa.size() > 1:
			segs.append([fa, fb, fd])
		for sg in segs:
			var mi := _strip_mesh(node, fence_mat, sg[0], sg[1], sg[2], false, false, "Fence")
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		# furniture, lamps, boards and the station building
		var b := MeshBatch.new()
		_station_building(b, s0, plen, side, top, back, bl, bmid)
		_platform_furniture(node, b, s0, plen, side, top, edge, back, bmid, bl + 6.0)
		b.commit(node, "StationBuildings")


## Station building behind the platform with a canopy over the platform.
func _station_building(b: MeshBatch, s0: float, plen: float, side: float, top: float, back: float, bl: float, bmid: float) -> void:
	var nsw := theme == "nsw"
	var bd := 6.0
	var f := track.flat_frame_at(bmid)
	var right := f.basis.x
	var fwd := -f.basis.z
	var along := fwd * (-side)
	var toward := right * (-side)
	var origin := f.origin + right * side * (back + bd * 0.5)
	var xf := Transform3D(Basis(along, Vector3.UP, toward), origin)
	var wall_h := 3.6
	var wall: Material = _m["brick"] if nsw else _m["stone"]
	var hw := bl * 0.5
	var hd := bd * 0.5
	# walls (down into the ground behind the platform), plinth, string course
	b.box_at("wall", wall, xf, Vector3(bl, wall_h + 3.0, bd), Vector3(0, top + wall_h * 0.5 - 1.5, 0))
	b.box_at("trim", _m["cream"] if nsw else _m["coping"], xf, Vector3(bl + 0.08, 0.14, bd + 0.08), Vector3(0, top + wall_h - 0.5, 0))
	b.box_at("plinth", _m["brick_dark"], xf, Vector3(bl + 0.06, 0.45, bd + 0.06), Vector3(0, top + 0.2, 0))
	# openings along both long faces: door, window, window, door ...
	var pattern := ["w", "d", "w", "w", "d", "w"] if nsw else ["w", "d", "w", "d", "w"]
	for face in [1.0, -1.0]:
		var n := pattern.size()
		for i in range(n):
			var x := -hw + (i + 0.5) * bl / n
			var kind: String = pattern[i]
			if kind == "d":
				_opening(b, xf, x, face * (hd + 0.012), face, top + 0.05, 1.05, 2.25, "door", _door_mat(Color(0.35, 0.18, 0.1) if nsw else Color(0.2, 0.3, 0.22)))
			else:
				_opening(b, xf, x, face * (hd + 0.012), face, top + 0.95, 1.1, 1.75, "win", _m["window_lit"])
				b.box_at("trim", _m["cream"] if nsw else _m["coping"], xf, Vector3(1.3, 0.08, 0.16), Vector3(x, top + 0.9, face * (hd + 0.06)))
	# end walls get one window each
	for ex in [-1.0, 1.0]:
		_opening_side(b, xf, ex * (hw + 0.012), ex, 0.0, top + 0.95, 1.1, 1.75, _m["window_lit"])
	# roof
	var roof_mat: Material = _m["iron_red"] if nsw else _m["slate"]
	if nsw:
		_hip_roof(b, xf, bl, bd, top + wall_h, 26.0, 0.45, "roof", roof_mat, _m["cream"])
	else:
		_gable_roof(b, xf, bl, bd, top + wall_h, 40.0, 0.4, "roof", roof_mat, "gable", wall, _m["cream"])
	# chimneys
	for cx in [-hw * 0.55, hw * 0.45]:
		var ch_h := (bd * 0.5) * tan(deg_to_rad(26.0 if nsw else 40.0)) + 1.3
		b.box_at("chimney", _m["brick"], xf, Vector3(0.75, ch_h + 0.6, 0.6), Vector3(cx, top + wall_h + (ch_h + 0.6) * 0.5 - 0.3, -0.2))
		b.box_at("chimney_cap", _m["coping"], xf, Vector3(0.9, 0.12, 0.75), Vector3(cx, top + wall_h + ch_h + 0.36, -0.2))
		b.cyl("pot", _m["brick_dark"], xf * Transform3D(Basis(), Vector3(cx, top + wall_h + ch_h + 0.6, -0.2)), 0.11, 0.13, 0.42, 8)
	# canopy over the platform: falls toward the track, carried on brackets and columns
	var c_len := bl + 6.0
	var c_out := 4.2
	var c_hi := top + wall_h - 0.15
	var c_lo := c_hi - 0.45
	var p_back_l := xf * Vector3(-c_len * 0.5, c_hi, hd)
	var p_back_r := xf * Vector3(c_len * 0.5, c_hi, hd)
	var p_front_l := xf * Vector3(-c_len * 0.5, c_lo, hd + c_out)
	var p_front_r := xf * Vector3(c_len * 0.5, c_lo, hd + c_out)
	var canopy_mat: Material = _m["iron_grey"] if nsw else _m["iron_red"]
	var cm := "canopy"
	# top (seen from above / the cab) and underside (seen from the platform)
	b.poly(cm, canopy_mat, [p_front_l, p_back_l, p_back_r, p_front_r], along, Vector2(1.22, 1.22))
	b.poly(cm + "_under", _m["cream"] if nsw else _m["white"], [p_front_l, p_front_r, p_back_r, p_back_l], along, Vector2(2, 2))
	# valance along the front edge
	var val_mat := TX.cutout("valance", Color(0.92, 0.88, 0.76) if nsw else Color(0.86, 0.84, 0.78), 0.6, 0.0, Vector2(1.0, 1.0), "s_valance_" + theme)
	var vh := 0.32
	var steps := int(c_len / 0.8)
	for i in range(steps):
		var x0 := -c_len * 0.5 + i * 0.8
		var x1 := x0 + 0.8
		var q0 := xf * Vector3(x0, c_lo - vh, hd + c_out)
		var q1 := xf * Vector3(x1, c_lo - vh, hd + c_out)
		var q2 := xf * Vector3(x1, c_lo + 0.02, hd + c_out)
		var q3 := xf * Vector3(x0, c_lo + 0.02, hd + c_out)
		b.quad("valance", val_mat, q0, q1, q2, q3, Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector2(0, 0))
	# end valances
	for ex in [-1.0, 1.0]:
		var e0 := xf * Vector3(ex * c_len * 0.5, c_hi - vh, hd)
		var e1 := xf * Vector3(ex * c_len * 0.5, c_lo - vh, hd + c_out)
		var e2 := xf * Vector3(ex * c_len * 0.5, c_lo + 0.02, hd + c_out)
		var e3 := xf * Vector3(ex * c_len * 0.5, c_hi + 0.02, hd)
		b.quad("valance", val_mat, e0, e1, e2, e3, Vector2(1, 0), Vector2(1, c_out / 0.8), Vector2(0, c_out / 0.8), Vector2(0, 0))
	# columns with capitals and bracket arms
	var col_mat: Material = _m["green"] if nsw else _m["cream"]
	var ncol := int(c_len / 4.5)
	for i in range(ncol + 1):
		var x := -c_len * 0.5 + 0.4 + i * (c_len - 0.8) / ncol
		var cz := hd + c_out - 0.6
		var y_top := lerpf(c_hi, c_lo, (c_out - 0.6) / c_out)
		b.cyl("col", col_mat, xf * Transform3D(Basis(), Vector3(x, (top + y_top) * 0.5, cz)), 0.075, 0.09, y_top - top, 10)
		b.cyl("col", col_mat, xf * Transform3D(Basis(), Vector3(x, top + 0.12, cz)), 0.14, 0.15, 0.24, 10)
		b.cyl("col", col_mat, xf * Transform3D(Basis(), Vector3(x, y_top - 0.12, cz)), 0.16, 0.08, 0.2, 10)
		b.tube("col", col_mat, xf * Vector3(x, y_top - 0.75, cz), xf * Vector3(x, y_top - 0.05, cz - 1.0), 0.035, 6)
		b.tube("col", col_mat, xf * Vector3(x, y_top - 0.75, cz), xf * Vector3(x, y_top - 0.05, cz + 0.55), 0.035, 6)
		# rafter
		b.box("col", col_mat, Vector3(0.08, 0.14, c_out), xf * Transform3D(Basis(Vector3.RIGHT, atan2(c_hi - c_lo, c_out)), Vector3(x, (c_hi + c_lo) * 0.5 - 0.1, hd + c_out * 0.5)))


## Window or door quad on a long face (normal = local +Z * face).
func _opening(b: MeshBatch, xf: Transform3D, x: float, z: float, face: float, y0: float, w: float, h: float, key: String, mat: Material) -> void:
	var dx := w * 0.5 * face
	var p0 := xf * Vector3(x - dx, y0, z)
	var p1 := xf * Vector3(x + dx, y0, z)
	var p2 := xf * Vector3(x + dx, y0 + h, z)
	var p3 := xf * Vector3(x - dx, y0 + h, z)
	b.quad(key + str(mat.get_instance_id()), mat, p0, p1, p2, p3)
	# reveal / frame surround
	var trim: Material = _m["cream"] if theme == "nsw" else _m["white"]
	var base := xf * Transform3D(Basis(), Vector3(x, y0 + h * 0.5, z))
	b.box("trim", trim, Vector3(w + 0.16, 0.08, 0.06), base * Transform3D(Basis(), Vector3(0, h * 0.5 + 0.04, 0)))
	b.box("trim", trim, Vector3(0.08, h, 0.06), base * Transform3D(Basis(), Vector3(-w * 0.5 - 0.04, 0, 0)))
	b.box("trim", trim, Vector3(0.08, h, 0.06), base * Transform3D(Basis(), Vector3(w * 0.5 + 0.04, 0, 0)))


## Window on an end face (normal = local +X * face).
func _opening_side(b: MeshBatch, xf: Transform3D, x: float, face: float, z: float, y0: float, w: float, h: float, mat: Material) -> void:
	var dz := w * 0.5 * face
	var p0 := xf * Vector3(x, y0, z + dz)
	var p1 := xf * Vector3(x, y0, z - dz)
	var p2 := xf * Vector3(x, y0 + h, z - dz)
	var p3 := xf * Vector3(x, y0 + h, z + dz)
	b.quad("win" + str(mat.get_instance_id()), mat, p0, p1, p2, p3)
	var trim: Material = _m["cream"] if theme == "nsw" else _m["white"]
	b.box("trim", trim, Vector3(0.16, 0.08, w + 0.2), xf * Transform3D(Basis(), Vector3(x + face * 0.04, y0 - 0.04, z)))


func _door_mat(col: Color) -> Material:
	return TX.uv("door_albedo", "", col * 1.25, 0.5, 0.0, Vector2.ONE, 1.0, "door_" + col.to_html())


func _roof_tile(mat: Material) -> Vector2:
	if mat == _m.get("tile"):
		return Vector2(1.8, 2.1)
	if mat == _m.get("iron_red") or mat == _m.get("iron_grey") or mat == _m.get("iron_green"):
		return Vector2(1.22, 1.22)
	return Vector2(2.0, 2.0)


## Hipped roof over a w x d rectangle (local frame xf, walls up to y_w).
func _hip_roof(b: MeshBatch, xf: Transform3D, w: float, d: float, y_w: float, pitch_deg: float, over: float, key: String, mat: Material, soffit: Material) -> void:
	var tn := tan(deg_to_rad(pitch_deg))
	var W := w * 0.5 + over
	var D := d * 0.5 + over
	var y_e := y_w - over * tn
	var y_r := y_e + D * tn
	var R := maxf(W - D, 0.0)
	var tile := _roof_tile(mat)
	var EL := xf * Vector3(-W, y_e, D)
	var ER := xf * Vector3(W, y_e, D)
	var BL := xf * Vector3(W, y_e, -D)
	var BR := xf * Vector3(-W, y_e, -D)
	var RL := xf * Vector3(-R, y_r, 0)
	var RR := xf * Vector3(R, y_r, 0)
	var ax := xf.basis.x
	var az := xf.basis.z
	b.poly(key, mat, [EL, RL, RR, ER], ax, tile)
	b.poly(key, mat, [BL, RR, RL, BR], -ax, tile)
	b.poly(key, mat, [ER, RR, BL], -az, tile)
	b.poly(key, mat, [BR, RL, EL], az, tile)
	b.poly("soffit", soffit, [xf * Vector3(-W, y_e, D), xf * Vector3(W, y_e, D), xf * Vector3(W, y_e, -D), xf * Vector3(-W, y_e, -D)], ax, Vector2(2, 2))
	# fascia boards and ridge capping
	for zz in [-D, D]:
		b.box_at("fascia", soffit, xf, Vector3(2.0 * W, 0.16, 0.04), Vector3(0, y_e - 0.06, zz))
	for xx in [-W, W]:
		b.box_at("fascia", soffit, xf, Vector3(0.04, 0.16, 2.0 * D), Vector3(xx, y_e - 0.06, 0))
	if R > 0.0:
		b.box_at("ridge", _m["galv"], xf, Vector3(2.0 * R + 0.1, 0.06, 0.22), Vector3(0, y_r + 0.01, 0))


## Gabled roof, ridge along local X; the gable ends are filled with 'wall'.
func _gable_roof(b: MeshBatch, xf: Transform3D, w: float, d: float, y_w: float, pitch_deg: float, over: float, key: String, mat: Material, wall_key: String, wall: Material, trim: Material) -> void:
	var tn := tan(deg_to_rad(pitch_deg))
	var W := w * 0.5 + over * 0.6
	var D := d * 0.5 + over
	var y_e := y_w - over * tn
	var y_r := y_e + D * tn
	var tile := _roof_tile(mat)
	var ax := xf.basis.x
	var EL := xf * Vector3(-W, y_e, D)
	var ER := xf * Vector3(W, y_e, D)
	var RL := xf * Vector3(-W, y_r, 0)
	var RR := xf * Vector3(W, y_r, 0)
	var BL := xf * Vector3(W, y_e, -D)
	var BR := xf * Vector3(-W, y_e, -D)
	b.poly(key, mat, [EL, RL, RR, ER], ax, tile)
	b.poly(key, mat, [BL, RR, RL, BR], -ax, tile)
	# undersides of the overhangs
	b.poly("soffit", trim, [ER, RR, RL, EL], ax, Vector2(2, 2))
	b.poly("soffit", trim, [BR, RL, RR, BL], ax, Vector2(2, 2))
	# gable triangles in the wall material
	var hw := w * 0.5
	var hd := d * 0.5
	var y_a := y_w + hd * tn
	b.poly(wall_key, wall, [xf * Vector3(hw, y_w, hd), xf * Vector3(hw, y_a, 0), xf * Vector3(hw, y_w, -hd)], -xf.basis.z, Vector2(2, 2))
	b.poly(wall_key, wall, [xf * Vector3(-hw, y_w, -hd), xf * Vector3(-hw, y_a, 0), xf * Vector3(-hw, y_w, hd)], xf.basis.z, Vector2(2, 2))
	# barge boards
	for ex in [-W, W]:
		for sz in [-1.0, 1.0]:
			var a := Vector3(ex, y_e, sz * D)
			var c := Vector3(ex, y_r, 0)
			b.box("fascia", trim, Vector3(0.05, 0.2, (c - a).length()), xf * Transform3D(Basis(Vector3.RIGHT, atan2(y_r - y_e, D) * sz), (a + c) * 0.5 - Vector3(0, 0.08, 0)))
	b.box_at("ridge_g", _m["brick_dark"] if mat == _m.get("tile") else _m["coping"], xf, Vector3(2.0 * W, 0.1, 0.22), Vector3(0, y_r + 0.02, 0))


func _platform_furniture(node: Node3D, b: MeshBatch, s0: float, plen: float, side: float, top: float, edge: float, back: float, bmid: float, c_len: float) -> void:
	var nsw := theme == "nsw"
	var name_txt := "WATTLE GULLY" if nsw else "CORBY GLEN"
	var pole_mat: Material = _m["dark_steel"] if nsw else _m["green"]
	# lamps
	var lamp_s := []
	var n_lamps := int(plen / 26.0)
	for k in range(n_lamps + 1):
		var ls := s0 + 10.0 + k * (plen - 20.0) / n_lamps
		if absf(ls - bmid) > c_len * 0.5 + 2.0:
			lamp_s.append([ls, false])
	for k in [-1, 0, 1]:
		lamp_s.append([bmid + k * c_len * 0.3, true])
	for entry in lamp_s:
		var ls: float = entry[0]
		var under: bool = entry[1]
		var lf := track.flat_frame_at(ls, (back - 2.2 if under else edge + 3.0) * side)
		var base := Transform3D(lf.basis, lf.origin + Vector3.UP * top)
		var light_y := 4.2 if nsw else 3.3
		if under:
			# hanging lamp under the canopy
			var hy := 3.05 if nsw else 2.95
			b.box("lamp_pole", pole_mat, Vector3(0.02, 0.4, 0.02), base * Transform3D(Basis(), Vector3(0, hy + 0.35, 0)))
			b.box("lamp_head", _m["galv"] if nsw else pole_mat, Vector3(0.5, 0.1, 0.3), base * Transform3D(Basis(), Vector3(0, hy + 0.12, 0)))
			b.box("lamp_glass", _m["lamp_glass"], Vector3(0.44, 0.06, 0.24), base * Transform3D(Basis(), Vector3(0, hy + 0.05, 0)))
			light_y = hy - 0.1
		elif nsw:
			b.cyl("lamp_pole", pole_mat, base * Transform3D(Basis(), Vector3(0, 2.3, 0)), 0.05, 0.075, 4.6, 8)
			b.box("lamp_pole", pole_mat, Vector3(0.12, 0.06, 0.9), base * Transform3D(Basis(), Vector3(0, 4.55, 0)))
			b.box("lamp_head", _m["galv"], Vector3(0.36, 0.1, 0.62), base * Transform3D(Basis(), Vector3(0, 4.5, 0)))
			b.box("lamp_glass", _m["lamp_glass"], Vector3(0.3, 0.03, 0.54), base * Transform3D(Basis(), Vector3(0, 4.44, 0)))
		else:
			b.cyl("lamp_pole", pole_mat, base * Transform3D(Basis(), Vector3(0, 0.3, 0)), 0.11, 0.14, 0.6, 8)
			b.cyl("lamp_pole", pole_mat, base * Transform3D(Basis(), Vector3(0, 1.75, 0)), 0.045, 0.07, 2.9, 8)
			b.box("lamp_pole", pole_mat, Vector3(0.7, 0.04, 0.04), base * Transform3D(Basis(), Vector3(0, 2.9, 0)))
			b.cyl("lamp_glass", _m["lamp_glass"], base * Transform3D(Basis(), Vector3(0, 3.42, 0)), 0.2, 0.13, 0.45, 4)
			b.cyl("lamp_pole", pole_mat, base * Transform3D(Basis(), Vector3(0, 3.75, 0)), 0.02, 0.26, 0.22, 4)
			b.cyl("lamp_pole", pole_mat, base * Transform3D(Basis(), Vector3(0, 3.2, 0)), 0.14, 0.14, 0.05, 4)
		var ol := OmniLight3D.new()
		ol.light_color = Color(1.0, 0.82, 0.55) if not nsw else Color(1.0, 0.92, 0.8)
		ol.omni_range = 16.0
		ol.omni_attenuation = 1.2
		ol.light_energy = 0.0
		ol.shadow_enabled = false
		node.add_child(ol)
		ol.global_transform = Transform3D(Basis(), base * Vector3(0, light_y, 0))
		platform_lights.append(ol)
	# seats
	for k in range(4):
		var ss := s0 + 30.0 + k * (plen - 60.0) / 3.0
		var sf := track.flat_frame_at(ss, (back - 0.9) * side)
		var base := Transform3D(sf.basis, sf.origin + Vector3.UP * top)
		if nsw:
			b.box("seat", _m["galv"], Vector3(0.45, 0.04, 1.9), base * Transform3D(Basis(), Vector3(0, 0.45, 0)))
			b.box("seat", _m["galv"], Vector3(0.04, 0.45, 1.9), base * Transform3D(Basis(Vector3.BACK, -0.2 * side), Vector3(side * 0.24, 0.72, 0)))
			for zz in [-0.8, 0.8]:
				b.box("seat_leg", _m["dark_steel"], Vector3(0.4, 0.45, 0.05), base * Transform3D(Basis(), Vector3(0, 0.22, zz)))
		else:
			for yy in [0.42, 0.46]:
				b.box("seat_wood", _m["timber"], Vector3(0.2, 0.035, 2.0), base * Transform3D(Basis(), Vector3(-0.1 + (yy - 0.42) * 5.0, yy, 0)))
			b.box("seat_wood", _m["timber"], Vector3(0.035, 0.32, 2.0), base * Transform3D(Basis(), Vector3(side * 0.22, 0.75, 0)))
			for zz in [-0.85, 0.85]:
				b.box("seat_leg", _m["black"], Vector3(0.5, 0.8, 0.05), base * Transform3D(Basis(), Vector3(0, 0.4, zz)))
	# running-in boards near each end, facing the line
	for ss in [s0 + 18.0, s0 + plen - 18.0]:
		var bf := track.flat_frame_at(ss, (back - 1.4) * side)
		var nb := Node3D.new()
		node.add_child(nb)
		nb.transform = Transform3D(bf.basis.rotated(Vector3.UP, -PI * 0.5 * side), bf.origin + Vector3.UP * top)
		var board := Color(0.08, 0.16, 0.38) if nsw else Color(0.02, 0.02, 0.02)
		MU.box(nb, Vector3(4.2, 0.85, 0.06), Vector3(0, 2.3, 0), MU.mat(board, 0.6))
		MU.box(nb, Vector3(4.32, 0.97, 0.04), Vector3(0, 2.3, -0.02), _m["white"] if nsw else _m["cream"])
		for px in [-1.6, 1.6]:
			MU.box(nb, Vector3(0.1, 2.75, 0.1), Vector3(px, 1.37, -0.08), pole_mat)
		MU.label(nb, name_txt, Vector3(0, 2.3, 0.035), 0.0062, Color(0.97, 0.97, 0.95), Vector3.ZERO, 96)
		MU.label(nb, name_txt, Vector3(0, 2.3, -0.045), 0.0062, Color(0.97, 0.97, 0.95), Vector3(0, 180, 0), 96)


func set_night_lights(on: bool) -> void:
	for l in platform_lights:
		l.light_energy = 2.2 if on else 0.0
	for m in night_mats:
		m.emission_energy_multiplier = (2.2 if m == _m.get("window_lit") else 4.0) if on else 0.0


# --------------------------------------------------------------- buildings
func _buildings(root: Node3D, q: int) -> void:
	var node := Node3D.new()
	node.name = "Buildings"
	root.add_child(node)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var count: int = [10, 22, 40, 56][q]
	var nsw := theme == "nsw"
	var b := MeshBatch.new()
	var placed := 0
	var tries := 0
	var spots := []
	while placed < count and tries < count * 30:
		tries += 1
		var s := rng.randf() * track.length
		var lat := rng.randf_range(32.0, 240.0) * (1.0 if rng.randf() > 0.5 else -1.0)
		var f := track.flat_frame_at(s, lat)
		terrain.query(f.origin.x, f.origin.z)
		if terrain.q_d < 24.0:
			continue
		var h := terrain.height_at(f.origin.x, f.origin.z)
		if h < terrain.water_y + 1.5:
			continue
		# reasonably level ground only
		var slope := absf(terrain.height_at(f.origin.x + 6.0, f.origin.z) - terrain.height_at(f.origin.x - 6.0, f.origin.z)) + absf(terrain.height_at(f.origin.x, f.origin.z + 6.0) - terrain.height_at(f.origin.x, f.origin.z - 6.0))
		if slope > 3.5:
			continue
		var too_close := false
		for sp in spots:
			if (sp as Vector3).distance_to(f.origin) < 22.0:
				too_close = true
				break
		if too_close:
			continue
		spots.append(f.origin)
		var rot := track.heading_at(s) + rng.randf_range(-0.35, 0.35) + (PI if rng.randf() > 0.5 else 0.0)
		# face the house roughly toward the line
		var xf := Transform3D(Basis(Vector3.UP, rot), Vector3(f.origin.x, h - 0.05, f.origin.z))
		if not nsw and rng.randf() < 0.22:
			_barn(b, xf, rng)
		else:
			_house(b, xf, rng, nsw)
		placed += 1
	var mi := b.commit(node, "Houses")
	mi.visibility_range_end = 2600.0


func _house(b: MeshBatch, xf: Transform3D, rng: RandomNumberGenerator, nsw: bool) -> void:
	var w := rng.randf_range(9.0, 13.0)
	var d := rng.randf_range(7.0, 9.5)
	var wall_h := rng.randf_range(2.9, 3.3) if nsw else rng.randf_range(5.0, 5.6)   # ECML cottages: two storeys
	var floor_y := 0.45
	var style := rng.randf()
	var wall: Material
	var wall_key := "h_wall_"
	if nsw:
		if style < 0.5:
			wall = TX.pbr("weatherboard_albedo", "weatherboard_normal", [Color(0.95, 0.93, 0.86), Color(0.86, 0.9, 0.82), Color(0.95, 0.88, 0.72), Color(0.8, 0.85, 0.88)][rng.randi() % 4], 0.8, 0.0, Vector3.ONE / 1.2, true, 1.0, "")
			wall_key += "board" + str(wall.get_instance_id())
		else:
			wall = _m["brick"] if rng.randf() < 0.6 else _m["brick_dark"]
			wall_key += "brick" + str(wall.get_instance_id())
	else:
		wall = [_m["brick"], _m["brick_dark"], _m["stone"], _m["brick_cream"]][rng.randi() % 4]
		wall_key += str(wall.get_instance_id())
	var trim: Material = _m["white"] if rng.randf() < 0.6 else _m["cream"]
	var top_y := floor_y + wall_h
	b.box_at(wall_key, wall, xf, Vector3(w, top_y + 1.8, d), Vector3(0, (top_y - 1.8) * 0.5, 0))
	if nsw and style < 0.5:
		b.box_at("h_stumps", _m["brick_dark"], xf, Vector3(w + 0.04, floor_y + 1.8, d + 0.04), Vector3(0, (floor_y - 1.8) * 0.5, 0))
	# windows and door on the long faces, one or two windows on the ends
	var lit: Material = _m["window_lit"] if rng.randf() < 0.45 else _m["window"]
	var floors := 1 if nsw else 2
	var ncol := maxi(2, int(w / 2.8))
	var door_i := rng.randi() % ncol
	for face in [1.0, -1.0]:
		for fl in range(floors):
			for i in range(ncol):
				var x := -w * 0.5 + (i + 0.5) * w / ncol
				var y0 := floor_y + 0.9 + fl * 2.4
				if fl == 0 and face > 0.0 and i == door_i:
					_opening(b, xf, x, face * (d * 0.5 + 0.012), face, floor_y, 0.95, 2.1, "door", _door_mat([Color(0.15, 0.3, 0.2), Color(0.45, 0.12, 0.1), Color(0.12, 0.2, 0.4), Color(0.3, 0.2, 0.12)][rng.randi() % 4]))
				else:
					_opening(b, xf, x, face * (d * 0.5 + 0.012), face, y0, 0.9, 1.35, "win", lit)
					b.box("trim", trim, Vector3(1.1, 0.07, 0.14), xf * Transform3D(Basis(), Vector3(x, y0 - 0.04, face * (d * 0.5 + 0.05))))
	for ex in [-1.0, 1.0]:
		for fl in range(floors):
			_opening_side(b, xf, ex * (w * 0.5 + 0.012), ex, 0.0, floor_y + 0.9 + fl * 2.4, 0.9, 1.3, lit)
	# roof
	var roof: Material
	if nsw:
		roof = [_m["iron_red"], _m["iron_green"], _m["iron_grey"], _m["tile"]][rng.randi() % 4]
	else:
		roof = _m["slate"] if rng.randf() < 0.55 else _m["tile"]
	var key := "h_roof" + str(roof.get_instance_id())
	if nsw and rng.randf() < 0.7:
		_hip_roof(b, xf, w, d, top_y, rng.randf_range(24.0, 30.0), 0.5, key, roof, trim)
	else:
		_gable_roof(b, xf, w, d, top_y, rng.randf_range(35.0, 45.0) if not nsw else 28.0, 0.35, key, roof, wall_key + "_g", wall, trim)
	# chimneys
	var nch := 1 if nsw else 2
	for c in range(nch):
		var cx := (w * 0.3 if c == 0 else -w * 0.3) if nsw else (w * 0.5 - 0.4) * (1.0 if c == 0 else -1.0)
		var rise := d * 0.5 * tan(deg_to_rad(40.0 if not nsw else 28.0)) + 1.0
		var cm: Material = _m["brick"] if wall != _m["stone"] else _m["stone"]
		b.box_at("h_chim" + str(cm.get_instance_id()), cm, xf, Vector3(0.7, rise + 1.0, 0.55), Vector3(cx, top_y + (rise + 1.0) * 0.5 - 0.5, 0.1 if nsw else 0.0))
		b.cyl("pot", _m["brick_dark"], xf * Transform3D(Basis(), Vector3(cx, top_y + rise + 0.68, 0.1 if nsw else 0.0)), 0.1, 0.12, 0.38, 8)
	# NSW: veranda across the front, and a corrugated rainwater tank
	if nsw:
		if rng.randf() < 0.65:
			var vd := 2.4
			var y_hi := top_y - 0.15
			var y_lo := top_y - 0.6
			var v_mat: Material = _m["iron_grey"] if rng.randf() < 0.5 else roof
			if v_mat == _m["tile"]:
				v_mat = _m["iron_red"]
			var a0 := xf * Vector3(-w * 0.5, y_hi, d * 0.5)
			var a1 := xf * Vector3(w * 0.5, y_hi, d * 0.5)
			var a2 := xf * Vector3(w * 0.5, y_lo, d * 0.5 + vd)
			var a3 := xf * Vector3(-w * 0.5, y_lo, d * 0.5 + vd)
			b.poly("h_veranda", v_mat, [a3, a0, a1, a2], xf.basis.x, Vector2(1.22, 1.22))
			b.poly("soffit", trim, [a3, a2, a1, a0], xf.basis.x, Vector2(2, 2))
			b.box_at("h_deck", _m["timber"], xf, Vector3(w, 0.12, vd), Vector3(0, floor_y - 0.06, d * 0.5 + vd * 0.5))
			var nposts := maxi(3, int(w / 2.4) + 1)
			for i in range(nposts):
				var px := -w * 0.5 + 0.1 + i * (w - 0.2) / (nposts - 1)
				b.box_at("trim", trim, xf, Vector3(0.1, y_lo - floor_y, 0.1), Vector3(px, (y_lo + floor_y) * 0.5, d * 0.5 + vd - 0.1))
			b.box_at("trim", trim, xf, Vector3(w, 0.05, 0.05), Vector3(0, floor_y + 0.9, d * 0.5 + vd - 0.1))
		if rng.randf() < 0.6:
			var tx := (w * 0.5 + 1.4) * (1.0 if rng.randf() < 0.5 else -1.0)
			b.cyl("h_tank", _m["iron_tank"], xf * Transform3D(Basis(), Vector3(tx, 1.45, -d * 0.25)), 1.05, 1.05, 2.1, 16)
			b.cyl("h_tank", _m["iron_tank"], xf * Transform3D(Basis(), Vector3(tx, 2.6, -d * 0.25)), 0.15, 1.08, 0.22, 16)
			b.box_at("h_stand", _m["timber"], xf, Vector3(2.3, 0.4, 2.3), Vector3(tx, 0.2, -d * 0.25))


func _barn(b: MeshBatch, xf: Transform3D, rng: RandomNumberGenerator) -> void:
	var w := rng.randf_range(16.0, 24.0)
	var d := rng.randf_range(8.0, 10.0)
	var h := rng.randf_range(5.0, 6.0)
	var wall: Material = _m["brick"] if rng.randf() < 0.7 else _m["stone"]
	var wk := "h_wall_" + str(wall.get_instance_id())
	b.box_at(wk, wall, xf, Vector3(w, h + 1.6, d), Vector3(0, (h - 1.6) * 0.5, 0))
	_gable_roof(b, xf, w, d, h, 38.0, 0.3, "h_roof" + str((_m["tile"] as Material).get_instance_id()), _m["tile"], wk + "_g", wall, _m["timber"])
	# big cart doors
	var dm := _door_mat(Color(0.25, 0.2, 0.15))
	_opening(b, xf, 0.0, d * 0.5 + 0.012, 1.0, 0.0, 3.2, 3.6, "door", dm)
	for i in range(3):
		var x := -w * 0.5 + (i + 0.5) * w / 3.0
		if absf(x) < 2.5:
			continue
		b.box_at("h_vent", _m["black"], xf, Vector3(0.12, 0.6, 0.02), Vector3(x, h * 0.6, d * 0.5 + 0.01))


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


# ------------------------------------------------------------------ fences
## Post-and-wire boundary fences either side of the railway, in chunks so
## distant ones can be culled.
func _fences(root: Node3D, q: int) -> void:
	if q == 0:
		return
	var nsw := theme == "nsw"
	var node := Node3D.new()
	node.name = "Fences"
	root.add_child(node)
	var post_mesh := CylinderMesh.new()
	if nsw:
		post_mesh.top_radius = 0.055
		post_mesh.bottom_radius = 0.065
		post_mesh.radial_segments = 6
		post_mesh.material = TX.pbr("timber_albedo", "timber_normal", Color(1.7, 1.65, 1.55), 0.95, 0.0, Vector3(3, 0.6, 3), false, 1.0, "s_fpost")
	else:
		post_mesh.top_radius = 0.045
		post_mesh.bottom_radius = 0.07
		post_mesh.radial_segments = 4
		post_mesh.material = _m["coping"]
	post_mesh.height = 1.45
	post_mesh.rings = 1
	var wire_mat := TX.cutout("fence_wire", Color.WHITE, 0.5, 0.6, Vector2(1.0, 1.0), "s_fwire")
	var vis: float = [0.0, 380.0, 520.0, 700.0][q]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var nchunks := int(ceil(track.length / FENCE_CHUNK))
	for side in [-1.0, 1.0]:
		for c in range(nchunks):
			var posts := []
			var b := MeshBatch.new()
			var prev := Vector3.INF
			var prev_v := 0.0
			var s := c * FENCE_CHUNK
			var s_end := minf((c + 1) * FENCE_CHUNK, track.length)
			while s < s_end + 0.01:
				var lat: float = side * (16.0 + sin(s * 0.004 + side) * 2.5)
				var f := track.flat_frame_at(s, lat)
				var ok := not terrain.is_bridge(s) and not _on_platform(s, 25.0)
				var h := terrain.height_at(f.origin.x, f.origin.z)
				if h < terrain.water_y + 0.3:
					ok = false
				if ok:
					var p := Vector3(f.origin.x, h, f.origin.z)
					var tilt := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, 0.05))
					posts.append(Transform3D(tilt.rotated(Vector3.UP, rng.randf() * TAU), p + Vector3.UP * 0.55))
					if prev != Vector3.INF and prev.distance_to(p) < 6.0:
						var v := prev_v + prev.distance_to(p)
						b.quad("wire", wire_mat, prev + Vector3.UP * 0.25, p + Vector3.UP * 0.25, p + Vector3.UP * 1.18, prev + Vector3.UP * 1.18,
								Vector2(1, prev_v), Vector2(1, v), Vector2(0, v), Vector2(0, prev_v))
						prev_v = v
					prev = p
				else:
					prev = Vector3.INF
				s += 3.0
			if posts.is_empty():
				continue
			var mmi := _multimesh(node, post_mesh, null, posts)
			mmi.visibility_range_end = vis
			mmi.visibility_range_end_margin = 40.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			if not b.is_empty():
				var wmi := b.commit(node, "Wire")
				wmi.visibility_range_end = vis * 0.6
				wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# --------------------------------------------------------- cable troughing
## Concrete cable troughing along the cess (signalling and power cables),
## in chunks so the far ones are culled.
func _cable_troughing(root: Node3D, q: int) -> void:
	var node := Node3D.new()
	node.name = "CableTroughing"
	root.add_child(node)
	var mat := TX.pbr("concrete_albedo", "concrete_normal", Color(0.72, 0.71, 0.68), 0.92, 0.0, Vector3.ONE * 1.2, true, 1.0, "s_trough")
	var lat := -3.35
	var y0 := -0.64
	var prof := PackedVector2Array([Vector2(lat - 0.17, y0 + 0.2), Vector2(lat + 0.17, y0 + 0.2), Vector2(lat + 0.17, y0 - 0.1), Vector2(lat - 0.17, y0 - 0.1)])
	var lid := PackedVector2Array([Vector2(lat - 0.18, y0 + 0.215), Vector2(lat + 0.18, y0 + 0.215)])
	var chunk := 500.0
	var vis: float = [250.0, 400.0, 550.0, 750.0][q]
	var c := 0.0
	while c < track.length - 1.0:
		var frames := []
		var dists := PackedFloat32Array()
		var profs := []
		var lids := []
		var s := c
		var e := minf(c + chunk, track.length)
		while s <= e + 0.01:
			if terrain.is_bridge(s) or _on_platform(s, 10.0):
				if frames.size() > 1:
					_trough_piece(node, mat, profs, lids, frames, dists, vis)
				frames = []
				dists = PackedFloat32Array()
				profs = []
				lids = []
			else:
				frames.append(track.flat_frame_at(s))
				dists.append(s)
				profs.append(prof)
				lids.append(lid)
			s += 3.0
		if frames.size() > 1:
			_trough_piece(node, mat, profs, lids, frames, dists, vis)
		c += chunk


func _trough_piece(node: Node3D, mat: Material, profs: Array, lids: Array, frames: Array, dists: PackedFloat32Array, vis: float) -> void:
	var mi := _strip_mesh(node, mat, profs, frames, dists, true, true, "Trough")
	mi.visibility_range_end = vis
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var li := _strip_mesh(node, mat, lids, frames, dists, false, false, "Lids")
	li.visibility_range_end = vis


# ----------------------------------------------------------------- signals
## Cosmetic signals showing a clear aspect: NSW colour lights on the automatic
## sections; ECML upper-quadrant semaphores (distant, home, starter) worked
## from the station and at intermediate block posts.
func _signals(root: Node3D) -> void:
	var nsw := theme == "nsw"
	var b := MeshBatch.new()
	var spots := []     # [s, kind]
	for pl in track.route.get("platforms", []):
		var s0: float = pl[0]
		var plen: float = pl[1]
		if nsw:
			spots.append([s0 + plen + 20.0, "colour"])
		else:
			spots.append([s0 + plen + 25.0, "home"])
			spots.append([s0 - 160.0, "home"])
			spots.append([s0 - 1150.0, "distant"])
	var step := 1400.0 if nsw else 3200.0
	var k := 1
	while k * step < track.length - 300.0:
		var s := k * step + 250.0
		var clear := true
		for sp in spots:
			var dd := absf(track.wrap_s(s - (sp[0] as float) + track.length * 0.5) - track.length * 0.5)
			if dd < 500.0:
				clear = false
		if clear and not _on_platform(s, 60.0) and not terrain.is_bridge(s):
			if nsw:
				spots.append([s, "colour"])
			else:
				spots.append([s, "home"])
				spots.append([s - 1000.0, "distant"])
		k += 1
	for sp in spots:
		var s := track.wrap_s(sp[0])
		if terrain.is_bridge(s):
			s += 40.0
		var f := track.flat_frame_at(s, -3.1)
		var xf := Transform3D(f.basis, f.origin + Vector3.UP * -0.62)
		match sp[1]:
			"colour":
				_colour_light(b, xf)
			"home":
				_semaphore(b, xf, false)
			"distant":
				_semaphore(b, xf, true)
	var mi := b.commit(root, "Signals")
	mi.visibility_range_end = 3000.0


## NSW three-aspect colour light: face toward +Z (approaching trains), track at +X.
func _colour_light(b: MeshBatch, xf: Transform3D) -> void:
	var post: Material = _m["galv"]
	var black: Material = _m["black"]
	var off := MU.mat(Color(0.03, 0.03, 0.03), 0.08, 0.0, "lens_off")
	var green := MU.lamp(Color(0.25, 1.0, 0.55), 6.0)
	b.box("sig_conc", _m["conc"], Vector3(0.7, 0.5, 0.7), xf * Transform3D(Basis(), Vector3(0, 0.0, 0)))
	b.cyl("sig_post", post, xf * Transform3D(Basis(), Vector3(0, 2.3, 0)), 0.085, 0.1, 4.4, 10)
	var head := xf * Transform3D(Basis(), Vector3(0.18, 4.75, 0.08))
	b.box("sig_black", black, Vector3(0.42, 1.2, 0.26), head)
	b.box("sig_black", black, Vector3(0.78, 1.55, 0.03), head * Transform3D(Basis(), Vector3(0, 0, -0.14)))
	b.box("sig_white", _m["white"], Vector3(0.84, 1.61, 0.02), head * Transform3D(Basis(), Vector3(0, 0, -0.155)))
	for i in range(3):
		var ly := 0.36 - i * 0.36
		var lens_xf := head * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, ly, 0.135))
		if i == 0:
			b.cyl("sig_green", green, lens_xf, 0.1, 0.1, 0.02, 14)
		else:
			b.cyl("sig_off", off, lens_xf, 0.1, 0.1, 0.02, 14)
		b.box("sig_black", black, Vector3(0.3, 0.025, 0.22), head * Transform3D(Basis(Vector3.RIGHT, -0.25), Vector3(0, ly + 0.14, 0.23)))
	# lineside equipment case on a concrete plinth, further from the track
	var case_mat := TX.painted(Color(0.55, 0.57, 0.58), 0.5, 0.4, "grime", 0.8, 0.0, "s_case")
	b.box("sig_conc", _m["conc"], Vector3(1.3, 0.25, 0.8), xf * Transform3D(Basis(), Vector3(-1.6, 0.1, -0.6)))
	b.box("sig_case", case_mat, Vector3(1.1, 1.45, 0.62), xf * Transform3D(Basis(), Vector3(-1.6, 0.95, -0.6)))
	b.box("sig_case", case_mat, Vector3(1.18, 0.06, 0.7), xf * Transform3D(Basis(), Vector3(-1.6, 1.7, -0.6)))
	b.box("sig_black", _m["black"], Vector3(0.04, 0.12, 0.02), xf * Transform3D(Basis(), Vector3(-1.2, 1.0, -0.28)))
	# identification plate and ladder
	b.box("sig_white", _m["white"], Vector3(0.32, 0.22, 0.02), xf * Transform3D(Basis(), Vector3(0, 2.6, 0.11)))
	for rx in [-0.18, 0.18]:
		b.box("sig_post", post, Vector3(0.035, 3.6, 0.035), xf * Transform3D(Basis(), Vector3(rx, 1.95, -0.22)))
	for r in range(11):
		b.box("sig_post", post, Vector3(0.36, 0.025, 0.025), xf * Transform3D(Basis(), Vector3(0, 0.45 + r * 0.3, -0.22)))


## LNER upper-quadrant semaphore, arm 'off' (raised 45 degrees).
func _semaphore(b: MeshBatch, xf: Transform3D, distant: bool) -> void:
	var white: Material = _m["white"]
	var black: Material = _m["black"]
	var post_h := 7.6
	b.box("sem_post", white, Vector3(0.24, post_h, 0.24), xf * Transform3D(Basis(), Vector3(0, post_h * 0.5, 0)))
	b.box("sem_black", black, Vector3(0.27, 1.2, 0.27), xf * Transform3D(Basis(), Vector3(0, 0.45, 0)))
	b.cyl("sem_black", black, xf * Transform3D(Basis(), Vector3(0, post_h + 0.12, 0)), 0.03, 0.12, 0.24, 8)
	b.cyl("sem_black", black, xf * Transform3D(Basis(), Vector3(0, post_h + 0.33, 0)), 0.0, 0.06, 0.25, 8)
	var arm_mat := MU.mat(Color(0.95, 0.75, 0.05), 0.5) if distant else MU.mat(Color(0.75, 0.05, 0.04), 0.5)
	var stripe := black if distant else white
	var pivot := xf * Transform3D(Basis(Vector3.BACK, -PI * 0.25), Vector3(-0.15, post_h - 0.9, 0.14))
	b.box("sem_arm" + ("d" if distant else "h"), arm_mat, Vector3(1.45, 0.26, 0.035), pivot * Transform3D(Basis(), Vector3(-0.78, 0, 0)))
	if distant:
		# fishtail notch and chevron
		b.box("sem_notch", MU.mat(Color(0.35, 0.45, 0.55), 0.6, 0.0, "sky_notch"), Vector3(0.18, 0.12, 0.04), pivot * Transform3D(Basis(Vector3.BACK, 0.0), Vector3(-1.44, 0, 0.002)))
		for sgn in [-1.0, 1.0]:
			b.box("sem_black", stripe, Vector3(0.3, 0.05, 0.01), pivot * Transform3D(Basis(Vector3.BACK, sgn * 0.6), Vector3(-1.12, sgn * 0.05, 0.022)))
	else:
		b.box("sem_white", stripe, Vector3(0.16, 0.27, 0.01), pivot * Transform3D(Basis(), Vector3(-1.18, 0, 0.022)))
	# spectacle with red and green glasses; the green one sits in front of the lamp when off
	b.box("sem_black", black, Vector3(0.12, 0.62, 0.03), pivot * Transform3D(Basis(), Vector3(0.12, -0.25, 0.0)))
	if not _m.has("sem_green"):
		_m["sem_green"] = MU.lamp(Color(0.3, 1.0, 0.6), 0.0)
		night_mats.append(_m["sem_green"])
	var green: StandardMaterial3D = _m["sem_green"]
	b.cyl("sem_green", green, xf * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, post_h - 1.35, 0.17)), 0.08, 0.08, 0.02, 12)
	b.box("sem_black", black, Vector3(0.22, 0.3, 0.2), xf * Transform3D(Basis(), Vector3(0.0, post_h - 1.35, 0.05)))
	# ladder and stage
	for rx in [-0.2, 0.2]:
		b.box("sem_black", black, Vector3(0.035, post_h - 1.6, 0.035), xf * Transform3D(Basis(), Vector3(rx, (post_h - 1.6) * 0.5, -0.3)))
	for r in range(int((post_h - 1.8) / 0.3)):
		b.box("sem_black", black, Vector3(0.4, 0.025, 0.025), xf * Transform3D(Basis(), Vector3(0, 0.3 + r * 0.3, -0.3)))
	b.box("sem_black", black, Vector3(0.6, 0.04, 0.5), xf * Transform3D(Basis(), Vector3(0, post_h - 1.6, -0.12)))


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
