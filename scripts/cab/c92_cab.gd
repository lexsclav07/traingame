class_name C92Cab
extends Cab
## The two cabs of a pair of Pacific National 92 class locomotives, and the
## controls outside them: battery boxes, engine room doors, handbrakes and the
## coupling between the units (brake pipe and main reservoir angle cocks, MU
## jumper). Each part is built in its own locomotive's vehicle space (z back
## from the front coupler face, y up from rail top, x right; -Z is forward).
## Control ids carry the unit's prefix: "l_" front unit, "t_" second unit.
##
## The driver sits on the left (NSW practice) at a desktop control console:
## automatic and independent brake handles on the left, throttle, dynamic
## brake and reverser on the right, the two computer displays ahead. Behind
## the seats are the engine control panel (breakers, engine start) and the air
## brake cabinet, each behind a door that has to be opened first.

const PFX := ["l_", "t_"]
const FLOOR := 1.64
const ZF := 2.14             # inside of the cab front wall
const ZR := 4.52             # inside of the rear wall
const XW := 1.405            # inside of the side walls
const ROOF := 4.05
const WIN_Y0 := 2.9          # windscreen and side windows
const WIN_Y1 := 3.72
const SEAT_Z := 3.42
const PANE_W := 1.23
const PANE_H := 0.82

var cab2: Node3D                              # the second unit's cab (this node is the first)
var units: Array[Vehicle] = []
var roots: Array[Node3D] = []
var screens: Array[LocoScreen] = []           # unit 1 main, status, unit 2 main, status
var pane_mats: Array[ShaderMaterial] = []     # windscreen panes: unit 1 left, right, unit 2 left, right
var wiper_arms: Array[Node3D] = []            # same order
var dome_lights: Array[OmniLight3D] = []
var dome_mats: Array[StandardMaterial3D] = []
var desk_lights: Array[OmniLight3D] = []
var walk_lights: Array[OmniLight3D] = []      # three per unit
var walk_mats: Array[StandardMaterial3D] = []
var mu_connected: Node3D
var mu_stowed: Node3D
var _bound := false
var _wiper_prev := [0.0, 0.0]
var _wiper_idle := [1e4, 1e4]


## Builds the cab of the lead unit and, if there is one, the second unit's
## (trail = null for a single locomotive).
func build_both(lead: Vehicle, trail: Vehicle) -> void:
	name = "C92Cab"
	lead.cab_root.add_child(self)
	roots = [self]
	units = [lead]
	if trail:
		cab2 = Node3D.new()
		cab2.name = "C92Cab2"
		trail.cab_root.add_child(cab2)
		roots.append(cab2)
		units.append(trail)
	var mt := _mats()
	for u in range(units.size()):
		var b := MeshBatch.new()
		_shell(roots[u], b, mt, u)
		_driver_desk(roots[u], b, mt, PFX[u], u)
		_second_desk(roots[u], b, mt, PFX[u], u)
		_seat(b, mt, -0.72)
		_seat(b, mt, 0.72)
		_ecp(roots[u], b, mt, PFX[u])
		_brake_cabinet(roots[u], b, mt, PFX[u])
		_outside(roots[u], b, mt, PFX[u], u)
		b.commit(roots[u], "CabInterior")
	if trail:
		_coupling(self, cab2, mt)
	_views()


static func _mats() -> Dictionary:
	return {
		"wall": TX.painted(Color(0.46, 0.48, 0.46), 0.6, 0.0, "paint_wear", 1.6, 0.0, "c92_wall"),
		"desk": TX.plastic(Color(0.2, 0.205, 0.21), 0.62, 8.0, "c92_desk"),
		"panel": TX.plastic(Color(0.09, 0.095, 0.1), 0.55, 8.0, "c92_panel"),
		"floor": TX.pbr("rubber_albedo", "rubber_normal", Color(0.5, 0.5, 0.52), 0.85, 0.0, Vector3.ONE * 1.6, false, 1.0, "c92_floor"),
		"seat": TX.pbr("fabric_albedo", "fabric_normal", Color(0.16, 0.17, 0.2), 0.95, 0.0, Vector3.ONE * 3.0, false, 1.0, "c92_seat"),
		"steel": TX.metal(Color(0.62, 0.62, 0.64), 0.35, true, 6.0, "c92_steel"),
		"black": TX.plastic(Color(0.035, 0.035, 0.04), 0.55, 8.0, "c92_black"),
		"rubber": MU.mat(Color(0.03, 0.03, 0.03), 0.8, 0.0, "c92_rubber"),
		"cabinet": TX.painted(Color(0.6, 0.62, 0.61), 0.5, 0.1, "paint_wear", 1.6, 0.0, "c92_cabinet"),
		"blue": TX.painted(CoalModels.pn_blue, 0.32, 0.15, "grime", 0.25, 0.45, "pn_blue"),
		"yellow": TX.painted(CoalModels.pn_yellow, 0.36, 0.05, "grime", 0.3, 0.35, "pn_yellow"),
		"glass": MU.glass(Color(0.7, 0.75, 0.78, 0.06)),
		"red": MU.mat(Color(0.72, 0.06, 0.04), 0.4, 0.0, "c92_red"),
		"copper": MU.mat(Color(0.72, 0.45, 0.25), 0.35, 0.9, "c92_copper"),
		"pipe": MU.mat(Color(0.25, 0.26, 0.27), 0.5, 0.5, "c92_pipe"),
		"hose": MU.mat(Color(0.04, 0.04, 0.04), 0.85, 0.0, "c92_hose"),
		"white": MU.mat(Color(0.9, 0.9, 0.88), 0.6, 0.0, "c92_white"),
	}


# ------------------------------------------------------------- geometry
static func _span(b: MeshBatch, mat: Material, lo: Vector3, hi: Vector3) -> void:
	b.box("p", mat, (hi - lo).abs(), Transform3D(Basis(), (lo + hi) * 0.5))


static func _bx(b: MeshBatch, mat: Material, size: Vector3, pos: Vector3, rot := Vector3.ZERO) -> void:
	b.box("p", mat, size, Transform3D(Basis.from_euler(rot * (PI / 180.0)), pos))


static func _cy(b: MeshBatch, mat: Material, r: float, h: float, pos: Vector3, rot := Vector3.ZERO, segs := 12) -> void:
	b.cyl("p", mat, Transform3D(Basis.from_euler(rot * (PI / 180.0)), pos), r, r, h, segs)


## Box placed in a frame's local space (the frame's transform relative to the batch's parent).
static func _fbx(b: MeshBatch, mat: Material, f: Node3D, size: Vector3, lpos: Vector3, lrot := Vector3.ZERO) -> void:
	b.box("p", mat, size, f.transform * Transform3D(Basis.from_euler(lrot * (PI / 180.0)), lpos))


static func _fcy(b: MeshBatch, mat: Material, f: Node3D, r: float, h: float, lpos: Vector3, lrot := Vector3.ZERO, segs := 12) -> void:
	b.cyl("p", mat, f.transform * Transform3D(Basis.from_euler(lrot * (PI / 180.0)), lpos), r, r, h, segs)


## A sagging hose or cable through the given points (a tube per segment).
static func _hose(b: MeshBatch, mat: Material, pts: Array, r: float) -> void:
	for i in range(pts.size() - 1):
		b.tube("p", mat, pts[i], pts[i + 1], r, 8)


static func _sag(a: Vector3, c: Vector3, drop: float, n := 6) -> Array:
	var out := []
	for i in range(n + 1):
		var t := float(i) / n
		out.append(a.lerp(c, t) - Vector3(0, drop * 4.0 * t * (1.0 - t), 0))
	return out


# ---------------------------------------------------------------- shell
func _shell(root: Node3D, b: MeshBatch, mt: Dictionary, _u: int) -> void:
	var wall: Material = mt["wall"]
	var dark: Material = mt["panel"]
	# the mouse cannot reach through the cab's walls, nose or windscreen
	add_blocker(root, Vector3(0, 2.85, 4.56), Vector3(1.47, 1.23, 0.04), null)
	add_blocker(root, Vector3(0, 2.68, 1.55), Vector3(1.47, 1.06, 0.6), null)
	for sx in [-1.0, 1.0]:
		add_blocker(root, Vector3(sx * 1.445, 2.26, 3.33), Vector3(0.025, 0.64, 1.19), null)
		add_blocker(root, Vector3(sx * 1.445, 3.94, 3.33), Vector3(0.025, 0.22, 1.19), null)
	_span(b, mt["floor"], Vector3(-1.4, 1.62, ZF), Vector3(1.4, FLOOR, ZR))
	_span(b, wall, Vector3(-1.4, ROOF, ZF), Vector3(1.4, ROOF + 0.02, ZR + 0.04))
	for sx in [-1.0, 1.0]:
		var x0 := minf(sx * XW, sx * (XW - 0.02))
		var x1 := maxf(sx * XW, sx * (XW - 0.02))
		_span(b, wall, Vector3(x0, FLOOR, ZF), Vector3(x1, WIN_Y0 - 0.02, ZR))
		_span(b, wall, Vector3(x0, WIN_Y1 + 0.02, ZF), Vector3(x1, ROOF, ZR))
		_span(b, wall, Vector3(x0, WIN_Y0 - 0.02, ZF), Vector3(x1, WIN_Y1 + 0.02, 2.42))
		_span(b, wall, Vector3(x0, WIN_Y0 - 0.02, 3.08), Vector3(x1, WIN_Y1 + 0.02, 3.14))
		_span(b, wall, Vector3(x0, WIN_Y0 - 0.02, 3.78), Vector3(x1, WIN_Y1 + 0.02, ZR))
		# side windows from inside (the outer glass faces outwards only)
		for zz in [[2.42, 3.08], [3.14, 3.78]]:
			_span(b, mt["glass"], Vector3(sx * 1.445 - 0.002, WIN_Y0, zz[0]), Vector3(sx * 1.445 + 0.002, WIN_Y1, zz[1]))
			# rubber seals and the sliding window's catch
			_span(b, mt["rubber"], Vector3(x0 - 0.01, WIN_Y0 - 0.025, zz[0]), Vector3(x1, WIN_Y0, zz[1]))
			_span(b, mt["rubber"], Vector3(x0 - 0.01, WIN_Y1, zz[0]), Vector3(x1, WIN_Y1 + 0.025, zz[1]))
		_bx(b, mt["steel"], Vector3(0.03, 0.12, 0.03), Vector3(sx * (XW - 0.035), 3.3, 3.11))
		for zz2 in [[2.42, 3.08], [3.14, 3.78]]:
			var r0 := minf(sx * 1.405, sx * 1.47)
			var r1 := maxf(sx * 1.405, sx * 1.47)
			_span(b, mt["rubber"], Vector3(r0, WIN_Y0 - 0.012, zz2[0]), Vector3(r1, WIN_Y0, zz2[1]))
			_span(b, mt["rubber"], Vector3(r0, WIN_Y1, zz2[0]), Vector3(r1, WIN_Y1 + 0.012, zz2[1]))
			_span(b, mt["rubber"], Vector3(r0, WIN_Y0, zz2[0]), Vector3(r1, WIN_Y1, zz2[0] + 0.012))
			_span(b, mt["rubber"], Vector3(r0, WIN_Y0, zz2[1] - 0.012), Vector3(r1, WIN_Y1, zz2[1]))
		# arm rests along the side walls and a grab handle by each side window
		_span(b, dark, Vector3(minf(sx * (XW - 0.1), sx * (XW - 0.02)), 2.5, 2.95), Vector3(maxf(sx * (XW - 0.1), sx * (XW - 0.02)), 2.56, 3.95))
		_cy(b, mt["steel"], 0.012, 0.4, Vector3(sx * (XW - 0.05), 3.35, 3.95), Vector3.ZERO, 8)
		# cab heater under each window
		_span(b, dark, Vector3(minf(sx * (XW - 0.16), sx * (XW - 0.02)), FLOOR + 0.05, 3.85), Vector3(maxf(sx * (XW - 0.16), sx * (XW - 0.02)), FLOOR + 0.42, 4.4))
		for k in range(6):
			_bx(b, mt["black"], Vector3(0.005, 0.3, 0.012), Vector3(sx * (XW - 0.163), FLOOR + 0.24, 3.92 + k * 0.08))
	# front wall round the windscreens
	_span(b, wall, Vector3(-1.4, WIN_Y1 + 0.02, ZF - 0.01), Vector3(1.4, ROOF, ZF + 0.01))
	_span(b, wall, Vector3(-0.07, WIN_Y0, ZF - 0.01), Vector3(0.07, WIN_Y1 + 0.02, ZF + 0.01))
	for sx in [-1.0, 1.0]:
		_span(b, wall, Vector3(minf(sx * 1.3, sx * 1.4), WIN_Y0, ZF - 0.01), Vector3(maxf(sx * 1.3, sx * 1.4), WIN_Y1 + 0.02, ZF + 0.01))
		# rubber round the screens, sun visor on its rail
		var xa := minf(sx * 0.07, sx * 1.3)
		var xb := maxf(sx * 0.07, sx * 1.3)
		_span(b, mt["rubber"], Vector3(xa, WIN_Y1 - 0.012, 2.072), Vector3(xb, WIN_Y1 + 0.02, ZF + 0.02))
		_span(b, mt["rubber"], Vector3(xa, WIN_Y0 - 0.02, 2.072), Vector3(xb, WIN_Y0 + 0.012, ZF + 0.02))
		_span(b, mt["rubber"], Vector3(xa - 0.02, WIN_Y0, 2.072), Vector3(xa + 0.012, WIN_Y1, ZF + 0.02))
		_span(b, mt["rubber"], Vector3(xb - 0.012, WIN_Y0, 2.072), Vector3(xb + 0.02, WIN_Y1, ZF + 0.02))
		_bx(b, mt["steel"], Vector3(1.2, 0.015, 0.015), Vector3(sx * 0.685, WIN_Y1 + 0.06, ZF + 0.05))
		_bx(b, MU.glass(Color(0.05, 0.06, 0.04, 0.75)), Vector3(0.5, 0.18, 0.006), Vector3(sx * 0.95, WIN_Y1 - 0.03, ZF + 0.07), Vector3(-12, 0, 0))
	# rear wall (the long hood is behind it) and the linings of the two cab doors
	_span(b, wall, Vector3(-1.02, FLOOR, ZR), Vector3(1.02, ROOF, ZR + 0.06))
	for sx in [-1.0, 1.0]:
		var xd0 := minf(sx * 1.02, sx * 1.4)
		var xd1 := maxf(sx * 1.02, sx * 1.4)
		var dz := 4.555
		var cabm: Material = mt["cabinet"]
		_span(b, wall, Vector3(xd0, 3.55, ZR + 0.02), Vector3(xd1, ROOF, ZR + 0.05))
		_span(b, cabm, Vector3(xd0 + 0.01, FLOOR, dz), Vector3(xd1 - 0.01, 2.75, dz + 0.01))
		_span(b, cabm, Vector3(xd0 + 0.01, 3.35, dz), Vector3(xd1 - 0.01, 3.55, dz + 0.01))
		_span(b, cabm, Vector3(xd0 + 0.01, 2.75, dz), Vector3(xd0 + 0.09, 3.35, dz + 0.01))
		_span(b, cabm, Vector3(xd1 - 0.09, 2.75, dz), Vector3(xd1 - 0.01, 3.35, dz + 0.01))
		_span(b, mt["glass"], Vector3(xd0 + 0.09, 2.75, dz + 0.004), Vector3(xd1 - 0.09, 3.35, dz + 0.006))
		_span(b, mt["black"], Vector3(xd0 + 0.01, FLOOR, dz - 0.004), Vector3(xd1 - 0.01, FLOOR + 0.25, dz))   # kick plate
		_bx(b, mt["steel"], Vector3(0.03, 0.14, 0.04), Vector3(sx * 1.1, 2.6, dz - 0.02))
		_bx(b, mt["steel"], Vector3(0.1, 0.02, 0.03), Vector3(sx * 1.13, 2.6, dz - 0.04))
	# fire extinguisher by the right-hand door, first aid box by the left
	_cy(b, mt["red"], 0.07, 0.46, Vector3(1.22, FLOOR + 0.28, 4.4), Vector3.ZERO, 14)
	_cy(b, mt["black"], 0.03, 0.08, Vector3(1.22, FLOOR + 0.55, 4.4), Vector3.ZERO, 8)
	_bx(b, mt["white"], Vector3(0.3, 0.22, 0.12), Vector3(-1.22, 3.75, 4.44))
	_bx(b, mt["red"], Vector3(0.1, 0.03, 0.002), Vector3(-1.22, 3.75, 4.379))
	_bx(b, mt["red"], Vector3(0.03, 0.1, 0.002), Vector3(-1.22, 3.75, 4.379))
	# ceiling: dome light, air-conditioning vents, radio speaker
	var dome := MU.lamp(Color(1.0, 0.96, 0.88), 0.0)
	dome.albedo_color = Color(0.85, 0.85, 0.82)
	_bx(b, dark, Vector3(0.5, 0.03, 0.3), Vector3(0, ROOF - 0.01, 3.4))
	MU.box(root, Vector3(0.44, 0.012, 0.24), Vector3(0, ROOF - 0.03, 3.4), dome)
	dome_mats.append(dome)
	for sx in [-1.0, 1.0]:
		_bx(b, dark, Vector3(0.36, 0.02, 0.14), Vector3(sx * 0.72, ROOF - 0.01, 2.6))
		for k in range(5):
			_bx(b, mt["black"], Vector3(0.32, 0.006, 0.01), Vector3(sx * 0.72, ROOF - 0.022, 2.55 + k * 0.025))
	_cy(b, dark, 0.07, 0.03, Vector3(0.0, ROOF - 0.01, 2.5), Vector3.ZERO, 16)
	var dl := OmniLight3D.new()
	dl.light_color = Color(1.0, 0.95, 0.85)
	dl.omni_range = 3.6
	dl.light_energy = 0.0
	dl.shadow_enabled = false
	root.add_child(dl)
	dl.position = Vector3(0, ROOF - 0.12, 3.4)
	dome_lights.append(dl)
	add_fill(Vector3(0, 3.75, 3.4), 3.6, 1.3, Color(1.0, 0.97, 0.92), root)
	add_fill(Vector3(0, 2.3, 3.7), 2.6, 0.6, Color(1.0, 0.96, 0.9), root)
	# windscreens: rain on the glass, cleared by the wipers (one per pane)
	for sx in [-1.0, 1.0]:
		var sm := TX.shader_mat("res://assets/shaders/windscreen.gdshader")
		sm.set_shader_parameter("drops_tex", TX.t("raindrops"))
		sm.set_shader_parameter("glass_size", Vector2(PANE_W, PANE_H))
		sm.set_shader_parameter("wiper_a", Vector4(PANE_W * 0.5, 0.03, 0.6, 1.0))
		sm.set_shader_parameter("wiper_b", Vector4(0.0, 0.0, 0.0, 0.0))
		sm.set_shader_parameter("sweep_start", 174.0)
		sm.set_shader_parameter("sweep_deg", 168.0)
		sm.set_shader_parameter("rain", {"rain": 1.0, "fog": 0.06}.get(GameSettings.weather, 0.0))
		sm.set_shader_parameter("drop_scale", 3.2 if GameSettings.weather == "fog" else 1.4)
		var qm := QuadMesh.new()
		qm.size = Vector2(PANE_W, PANE_H)
		var ws := MeshInstance3D.new()
		ws.mesh = qm
		ws.material_override = sm
		ws.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ws.name = "Windscreen"
		root.add_child(ws)
		ws.position = Vector3(sx * 0.685, (WIN_Y0 + WIN_Y1) * 0.5, 2.11)
		pane_mats.append(sm)
		# wiper: motor spindle at the bottom of the pane, arm and blade outside the glass
		var pivot := Node3D.new()
		root.add_child(pivot)
		pivot.position = Vector3(sx * 0.685, WIN_Y0 + 0.03, 2.05)
		var arm := Node3D.new()
		pivot.add_child(arm)
		MU.box(arm, Vector3(0.012, 0.58, 0.01), Vector3(0, 0.3, 0.0), mt["black"])
		MU.box(arm, Vector3(0.02, 0.56, 0.012), Vector3(0, 0.32, 0.008), mt["rubber"])
		MU.cyl(arm, 0.018, 0.03, Vector3.ZERO, mt["black"], Vector3(90, 0, 0), 10)
		arm.rotation_degrees = Vector3(0, 0, 84)
		wiper_arms.append(arm)


# ---------------------------------------------------------- driver's desk
func _driver_desk(root: Node3D, b: MeshBatch, mt: Dictionary, p: String, u: int) -> void:
	var desk: Material = mt["desk"]
	var dark: Material = mt["panel"]
	var steel: Material = mt["steel"]
	var black := MU.mat(Color(0.05, 0.05, 0.05), 0.4, 0.0, "c92_knob")
	# body against the front wall with a knee well under the overhanging top
	_span(b, desk, Vector3(-1.395, FLOOR, ZF), Vector3(-0.03, 2.5, 2.46))
	_span(b, desk, Vector3(-1.395, 2.5, ZF), Vector3(-0.03, 2.885, 2.33))
	for x in [-1.395, -0.05]:
		_span(b, desk, Vector3(x, FLOOR, 2.46), Vector3(x + 0.02, 2.55, 2.95))
		_span(b, desk, Vector3(x, 2.5, 2.3), Vector3(x + 0.02, 2.9, 2.62))
	_span(b, dark, Vector3(-1.395, 2.875, ZF), Vector3(-0.03, 2.895, 2.345))        # glare shield
	_bx(b, steel, Vector3(1.0, 0.03, 0.2), Vector3(-0.72, FLOOR + 0.2, 2.62), Vector3(-25, 0, 0))   # footrest
	_cy(b, mt["black"], 0.025, 1.3, Vector3(-0.712, 2.548, 2.955), Vector3(0, 0, 90), 12)     # padded edge
	var dt := frame(root, Vector3(-0.712, 2.565, 2.705), Vector3(-82, 0, 0))
	_fbx(b, desk, dt, Vector3(1.365, 0.5, 0.04), Vector3(0, 0, -0.02))
	var ip := frame(root, Vector3(-0.712, 2.745, 2.395), Vector3(-22, 0, 0))
	_fbx(b, dark, ip, Vector3(1.365, 0.32, 0.03), Vector3(0, 0, -0.015))
	# brake handle quadrants: the handles pivot below the desk top and move along
	# a slot, with each position engraved beside it
	var quad := MU.mat(Color(0.13, 0.135, 0.14), 0.45, 0.4, "c92_quadrant")
	_fbx(b, quad, dt, Vector3(0.13, 0.24, 0.012), Vector3(-0.555, 0.06, 0.006))
	_fbx(b, quad, dt, Vector3(0.11, 0.2, 0.012), Vector3(-0.38, 0.02, 0.006))
	_fbx(b, quad, dt, Vector3(0.43, 0.22, 0.012), Vector3(0.455, 0.03, 0.006))

	# ------------------------------------------------------ brake handles
	var ab := _slot_lever(p + "auto_brake", "Automatic brake", dt, b, mt, Vector2(-0.53, 0.06), 0.16, -38.0, 76.0, 0.096, steel, black,
		"Train brake (brake pipe). RELEASE fully forward; pull back through MINIMUM and the service zone to FULL SERVICE. SUPPRESSION resets a penalty (PCS). Fully back = EMERGENCY. Keys ; and '.", 0.024,
		[[0.0, "RELEASE"], [1.0, "MIN"], [5.0, "FULL"], [6.0, "SUPPR"], [8.0, "EMERG"]], 8.0, false)
	ab.min_v = 0.0
	ab.max_v = 8.0
	ab.drag_scale = 0.003
	ab.key_step = 0.5 / 8.0
	ab.scroll_step = 0.5 / 8.0
	for k in C92Sim.AUTO_LABELS:
		ab.notches.append([float(k), C92Sim.AUTO_LABELS[k]])
	ab.setup_part(ab.part)
	ab.custom_state = func() -> String:
		for k in C92Sim.AUTO_LABELS:
			if absf(float(k) - ab.value) < 0.01:
				return C92Sim.AUTO_LABELS[k]
		if ab.value < 1.0:
			return "RELEASE"
		return "SERVICE (%d kPa)" % int(50.0 + (ab.value - 1.0) / 4.0 * 100.0)
	var ib := _slot_lever(p + "ind_brake", "Independent brake", dt, b, mt, Vector2(-0.37, 0.02), 0.13, -32.0, 64.0, 0.096, steel, black,
		"Locomotive brakes only (both units, through the MU pipes). Forward = RELEASE, back = FULL (450 kPa). Keys [ and ].", 0.02,
		[[0.0, "REL"], [1.0, "FULL"]], 1.0, true)
	ib.min_v = 0.0
	ib.max_v = 1.0
	ib.notches = [[0.0, "RELEASE"], [1.0, "FULL"]]
	ib.setup_part(ib.part)
	text("INDEPENDENT", dt, Vector3(-0.38, 0.135, 0.013), Vector3.ZERO, 0.00034)
	text("AUTOMATIC", dt, Vector3(-0.555, 0.195, 0.013), Vector3.ZERO, 0.00034)
	button(p + "bail_off", "Bail off", dt, Vector3(-0.37, -0.15, 0.0), Vector3.ZERO, Color(0.82, 0.82, 0.8),
		"Hold to release the automatic brake on the locomotives only, leaving the wagons braked (stops the units sliding their wheels). Key B (hold).", 0.015, false, false, "BAIL OFF")
	button(p + "horn", "Horn", dt, Vector3(-0.2, -0.16, 0.0), Vector3.ZERO, Color(0.22, 0.22, 0.24),
		"Nathan five-chime air horn (hold). Sounding it also starts the ditch lights flashing in AUTO. Space bar.", 0.02, false, false, "HORN")
	# ------------------------------------------------- power controller
	button(p + "sand", "Sand", dt, Vector3(0.0, -0.16, 0.0), Vector3.ZERO, Color(0.8, 0.68, 0.25),
		"Hold to sand the rails under the leading wheels of both units: more grip when starting or on wet rail. Key X.", 0.016, false, false, "SAND")
	button(p + "alerter", "Alerter reset", dt, Vector3(0.15, -0.15, 0.0), Vector3.ZERO, Color(1.0, 0.8, 0.1),
		"Vigilance: when the alerter sounds (60 s without using a control while moving) press within 10 s, or a penalty brake application opens the PCS. Key Q.", 0.026, false, true, "ALERTER")
	var th := _slot_lever(p + "throttle", "Throttle", dt, b, mt, Vector2(0.32, 0.02), 0.15, 28.0, -56.0, 0.113, steel, black,
		"Power: IDLE, then notches 1-8 (push away from you). Each notch raises engine speed and load in every unit that answers this cab. Interlocked with the dynamic brake. Keys D / A.", 0.026,
		[[0.0, "IDLE"], [2.0, "2"], [4.0, "4"], [6.0, "6"], [8.0, "8"]], 8.0, false)
	th.min_v = 0.0
	th.max_v = 8.0
	th.notch_only = true
	th.drag_scale = 0.004
	th.notches.append([0.0, "IDLE"])
	for k in range(1, 9):
		th.notches.append([float(k), "NOTCH %d" % k])
	th.setup_part(th.part)
	var dbl := _slot_lever(p + "dynbrake", "Dynamic brake", dt, b, mt, Vector2(0.46, 0.02), 0.15, -28.0, 56.0, 0.113, steel, MU.mat(Color(0.55, 0.07, 0.04), 0.45, 0.0, "c92_db_knob"),
		"Dynamic brake: OFF, SET UP (grid blowers running, no retarding force), then pull back for more braking: the traction motors become generators feeding the roof grids. Throttle must be at IDLE. Keys A / D.", 0.024,
		[[0.0, "OFF"], [1.0, "SET UP"], [5.0, "50%"], [9.0, "MAX"]], 9.0, true)
	dbl.min_v = 0.0
	dbl.max_v = 9.0
	dbl.notches = [[0.0, "OFF"], [1.0, "SET UP"], [9.0, "MAX"]]
	dbl.scroll_step = 0.5 / 9.0
	dbl.key_step = 1.0 / 9.0
	dbl.drag_scale = 0.0035
	dbl.setup_part(dbl.part)
	dbl.custom_state = func() -> String:
		if dbl.value < 0.5:
			return "OFF"
		if dbl.value < 1.05:
			return "SET UP"
		return "BRAKING %d %%" % int((dbl.value - 1.0) / 8.0 * 100.0)
	var rv := _slot_lever(p + "reverser", "Reverser", dt, b, mt, Vector2(0.6, 0.04), 0.1, 30.0, -60.0, 0.078, steel, MU.mat(Color(0.75, 0.75, 0.78), 0.3, 0.8, "c92_rev_knob"),
		"FORWARD (away from you), CENTRE or REVERSE. Leave it in CENTRE in a trailing unit. Only move it at a stand. Keys W / S.", 0.018,
		[[0.0, "REV"], [1.0, "CTR"], [2.0, "FWD"]], 2.0, true)
	rv.min_v = 0.0
	rv.max_v = 2.0
	rv.notch_only = true
	rv.notches = [[0.0, "REVERSE"], [1.0, "CENTRE"], [2.0, "FORWARD"]]
	rv.setup_part(rv.part)
	for t0 in [["THROTTLE", 0.32], ["DYN BRAKE", 0.46], ["REVERSER", 0.6]]:
		text(t0[0], dt, Vector3(t0[1], 0.125, 0.013), Vector3.ZERO, 0.00034)
	# ------------------------------------- overhead console: lights, wipers
	var ov := frame(root, Vector3(-0.72, 3.9, 2.25), Vector3(33.5, 0, 0))
	_fbx(b, dark, ov, Vector3(0.92, 0.2, 0.04), Vector3(0, 0, -0.02))
	_span(b, dark, Vector3(-1.18, 3.94, ZF), Vector3(-0.26, ROOF, 2.32))
	rotary(p + "headlights", "Headlights", ov, Vector3(-0.36, 0.01, 0.0), Vector3.ZERO, ["OFF", "DIM", "BRIGHT"], 0,
		"Twin headlights: DIM when meeting other trains or in stations, BRIGHT on the open line. Key L.", 0.016, 50.0)
	rotary(p + "ditch", "Ditch lights", ov, Vector3(-0.24, 0.01, 0.0), Vector3.ZERO, ["OFF", "ON", "AUTO"], 0,
		"ON: steady. AUTO: they flash alternately for 15 s each time the horn is sounded (level crossings). Only work with the headlights on.", 0.016, 50.0)
	toggle(p + "markers", "Marker lights", ov, Vector3(-0.13, 0.01, 0.0), Vector3.ZERO, ["OFF", "ON"], 0, "White marker lights on the nose.")
	rotary(p + "wipers", "Windscreen wipers", ov, Vector3(-0.03, 0.01, 0.0), Vector3.ZERO, ["OFF", "SLOW", "FAST"], 0, "", 0.016, 50.0)
	toggle(p + "gauge_light", "Gauge and desk lights", ov, Vector3(0.08, 0.01, 0.0), Vector3.ZERO, ["OFF", "ON"], 0, "")
	toggle(p + "cab_light", "Cab light", ov, Vector3(0.17, 0.01, 0.0), Vector3.ZERO, ["OFF", "ON"], 0, "")
	toggle(p + "walkway_lights", "Walkway lights", ov, Vector3(0.26, 0.01, 0.0), Vector3.ZERO, ["OFF", "ON"], 0,
		"Lights the side walkways, steps and the No. 2 end (for going out to the battery box, engine room, handbrake or the other unit at night).")
	for t in [["HEAD", -0.36], ["DITCH", -0.24], ["MARKER", -0.13], ["WIPER", -0.03], ["GAUGE", 0.08], ["CAB", 0.17], ["WALKWAY", 0.26]]:
		text(t[0], ov, Vector3(t[1], -0.075, 0.002), Vector3.ZERO, 0.00034)

	# --------------------------------------------- instrument panel ahead
	var red := Color(0.85, 0.1, 0.05)
	var blk := Color(0.05, 0.05, 0.05)
	gauge(p + "air1", ip, Vector3(-0.565, 0.02, 0.004), Vector3.ZERO, 0.058, 0, 1100, 200, 50, "MR / EQ", "kPa", [red, blk])
	gauge(p + "air2", ip, Vector3(-0.425, 0.02, 0.004), Vector3.ZERO, 0.058, 0, 1100, 200, 50, "BP / BC", "kPa", [blk, red])
	screens.append(LocoScreen.make(ip, "main", u, Vector2i(480, 360), Vector2(0.26, 0.195), Vector3(-0.2, 0.025, 0.004), Vector3.ZERO))
	screens.append(LocoScreen.make(ip, "status", u, Vector2i(480, 360), Vector2(0.26, 0.195), Vector3(0.1, 0.025, 0.004), Vector3.ZERO))
	for sx2 in [-0.2, 0.1]:
		# display bezel (just behind the screen surface)
		_fbx(b, mt["black"], ip, Vector3(0.285, 0.22, 0.012), Vector3(sx2, 0.025, -0.004))
	var keys := [["scr_engine", "ENGINE"], ["scr_air", "AIR"], ["scr_alarms", "ALARMS"]]
	for i in range(3):
		var k2: Array = keys[i]
		button(p + k2[0], "Display key: " + k2[1], ip, Vector3(0.1 + (i - 1) * 0.08, -0.115, 0.0), Vector3.ZERO, Color(0.3, 0.33, 0.38),
			"Shows the %s page on the right-hand display." % k2[1].to_lower(), 0.011, false, false, k2[1])
	gauge(p + "loadmeter", ip, Vector3(0.37, 0.02, 0.004), Vector3.ZERO, 0.058, -600, 600, 200, 50, "LOAD", "kN", [blk])
	gauge(p + "speedo", ip, Vector3(0.53, 0.02, 0.004), Vector3.ZERO, 0.06, 0, 120, 20, 5, "SPEED", "km/h", [blk])
	# engine control switches under the meters
	toggle(p + "sw_control", "CONTROL switch", ip, Vector3(0.33, -0.12, 0.0), Vector3.ZERO, ["OFF", "ON"], 0,
		"Makes this the controlling cab: power to the throttle, reverser and the MU trainline. ON in the cab you drive from only, OFF in the trailing unit.")
	toggle(p + "sw_engine_run", "ENGINE RUN switch", ip, Vector3(0.43, -0.12, 0.0), Vector3.ZERO, ["OFF", "ON"], 0,
		"Lets the throttle raise engine speed in every unit that answers this cab.")
	toggle(p + "sw_gen_field", "GENERATOR FIELD switch", ip, Vector3(0.53, -0.12, 0.0), Vector3.ZERO, ["OFF", "ON"], 0,
		"Excites the main alternators, so the units load when the throttle is opened.")
	for t2 in [["CONTROL", 0.33], ["ENGINE RUN", 0.43], ["GEN FIELD", 0.53]]:
		text(t2[0], ip, Vector3(t2[1], -0.063, 0.002), Vector3.ZERO, 0.00028)
	var lamps_def := [["lamp_pcs", Color(1.0, 0.1, 0.05), "PCS OPEN"], ["lamp_slip", Color(1.0, 0.65, 0.1), "WHEEL SLIP"],
		["lamp_db", Color(0.3, 1.0, 0.4), "DYN BRAKE"], ["lamp_sand", Color(0.95, 0.95, 1.0), "SAND"],
		["lamp_hb", Color(1.0, 0.12, 0.05), "HANDBRAKE"], ["lamp_comp", Color(0.95, 0.95, 1.0), "COMPRESSOR"],
		["lamp_ctrl", Color(0.3, 1.0, 0.4), "IN CONTROL"]]
	for i in range(lamps_def.size()):
		var ld: Array = lamps_def[i]
		lamp(p + ld[0], ip, Vector3(-0.6 + i * 0.07, -0.12, 0.004), Vector3.ZERO, ld[1], ld[2], 0.023, true)
	text("PACIFIC NATIONAL  " + LocoScreen.NUMBERS[u], ip, Vector3(0.45, 0.135, 0.002), Vector3.ZERO, 0.00034, Color(0.7, 0.72, 0.75))
	# desk light under the glare shield
	var gl := OmniLight3D.new()
	gl.light_color = Color(1.0, 0.92, 0.8)
	gl.omni_range = 1.1
	gl.light_specular = 0.0
	gl.light_energy = 0.0
	gl.shadow_enabled = false
	root.add_child(gl)
	gl.position = Vector3(-0.72, 2.84, 2.5)
	desk_lights.append(gl)


## A desk lever whose pivot sits 'depth' below the desk top, so the shaft moves
## along a slot in the quadrant plate; each label is engraved beside the slot
## where the shaft stands at that position (labels on the right if 'right').
func _slot_lever(id: String, title: String, f: Node3D, b: MeshBatch, mt: Dictionary, at: Vector2, above: float,
		a0: float, sweep: float, depth: float, mat: Material, knob: Material, help: String, knob_r: float,
		marks: Array, vmax: float, right: bool) -> CabControl:
	var ctl := lever(id, title, f, Vector3(at.x, at.y, -depth), Vector3(90, 0, 0), above + depth,
		Vector3(a0, 0, 0), Vector3(sweep, 0, 0), mat, knob, help, knob_r)
	var y_at := func(v: float) -> float:
		return at.y - depth * tan(deg_to_rad(a0 + sweep * v / vmax))
	var ya: float = y_at.call(0.0)
	var yb: float = y_at.call(vmax)
	_fbx(b, mt["black"], f, Vector3(0.024, absf(ya - yb) + 0.03, 0.002), Vector3(at.x, (ya + yb) * 0.5, 0.0125))
	for mk in marks:
		var y: float = y_at.call(float(mk[0]))
		var lb := text(mk[1], f, Vector3(at.x + (0.019 if right else -0.019), y, 0.013), Vector3.ZERO, 0.00034)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if right else HORIZONTAL_ALIGNMENT_RIGHT
		# a tick on the slot's edge
		_fbx(b, mt["white"], f, Vector3(0.006, 0.0015, 0.001), Vector3(at.x + (0.015 if right else -0.015), y, 0.0132))
	return ctl


# ------------------------------------------------------ second person's desk
func _second_desk(root: Node3D, b: MeshBatch, mt: Dictionary, p: String, _u: int) -> void:
	var desk: Material = mt["desk"]
	var dark: Material = mt["panel"]
	_span(b, desk, Vector3(0.03, FLOOR, ZF), Vector3(1.395, 2.48, 2.46))
	_span(b, desk, Vector3(0.03, 2.48, ZF), Vector3(1.395, 2.875, 2.33))
	for x in [0.03, 1.375]:
		_span(b, desk, Vector3(x, FLOOR, 2.46), Vector3(x + 0.02, 2.53, 2.88))
		_span(b, desk, Vector3(x, 2.48, 2.3), Vector3(x + 0.02, 2.89, 2.6))
	_span(b, dark, Vector3(0.03, 2.865, ZF), Vector3(1.395, 2.885, 2.345))
	_bx(b, mt["steel"], Vector3(1.0, 0.03, 0.2), Vector3(0.72, FLOOR + 0.2, 2.62), Vector3(-25, 0, 0))
	var sd := frame(root, Vector3(0.712, 2.545, 2.67), Vector3(-82, 0, 0))
	_fbx(b, desk, sd, Vector3(1.365, 0.44, 0.04), Vector3(0, 0, -0.02))
	var sp := frame(root, Vector3(0.712, 2.72, 2.39), Vector3(-22, 0, 0))
	_fbx(b, dark, sp, Vector3(1.365, 0.3, 0.03), Vector3(0, 0, -0.015))
	var red := Color(0.85, 0.1, 0.05)
	var blk := Color(0.05, 0.05, 0.05)
	gauge(p + "bp2", sp, Vector3(-0.5, 0.0, 0.004), Vector3.ZERO, 0.055, 0, 1100, 200, 50, "BP / BC", "kPa", [blk, red])
	gauge(p + "speedo2", sp, Vector3(-0.36, 0.0, 0.004), Vector3.ZERO, 0.055, 0, 120, 20, 5, "SPEED", "km/h", [blk])
	# train radio: control head with a lit display, handset on the desk
	_fbx(b, mt["black"], sp, Vector3(0.24, 0.12, 0.05), Vector3(0.0, 0.03, 0.025))
	_fbx(b, MU.mat(Color(0.25, 0.45, 0.3), 0.3, 0.0, "c92_radio_lcd"), sp, Vector3(0.12, 0.04, 0.004), Vector3(0.0, 0.05, 0.051))
	for k in range(6):
		_fbx(b, MU.mat(Color(0.2, 0.2, 0.22), 0.5, 0.0, "c92_radio_key"), sp, Vector3(0.025, 0.018, 0.012), Vector3(-0.07 + k * 0.028, 0.0, 0.055))
	_fbx(b, mt["black"], sd, Vector3(0.07, 0.2, 0.05), Vector3(-0.1, 0.0, 0.025))
	_fbx(b, mt["black"], sd, Vector3(0.05, 0.18, 0.04), Vector3(-0.1, 0.0, 0.065))
	text("TRAIN RADIO", sp, Vector3(0.0, 0.11, 0.002), Vector3.ZERO, 0.00034)
	# emergency brake valve (red handle) and the emergency fuel cut-off
	var ev := lever(p + "emerg_valve", "Emergency brake valve", sd, Vector3(0.32, 0.02, 0.0), Vector3(90, 0, 0), 0.12,
		Vector3(-25, 0, 0), Vector3(55, 0, 0), mt["steel"], mt["red"],
		"Pull to vent the brake pipe straight to atmosphere: emergency brakes on the whole train. Push it back once stopped.", 0.022)
	ev.min_v = 0.0
	ev.max_v = 1.0
	ev.notch_only = true
	ev.notches = [[0.0, "CLOSED"], [1.0, "OPEN - EMERGENCY"]]
	ev.setup_part(ev.part)
	text("EMERGENCY BRAKE", sd, Vector3(0.32, 0.15, 0.002), Vector3.ZERO, 0.00036, Color(1.0, 0.85, 0.8))
	mushroom(p + "efco", "Emergency fuel cut-off", sd, Vector3(0.52, 0.1, 0.0), Vector3.ZERO,
		"Cuts the fuel to BOTH engines at once (fire or emergency). It latches in: pull it back out to reset.")
	text("FUEL CUT-OFF", sd, Vector3(0.52, 0.17, 0.002), Vector3.ZERO, 0.00036, Color(1.0, 0.85, 0.8))


func _seat(b: MeshBatch, mt: Dictionary, x: float) -> void:
	var fabric: Material = mt["seat"]
	var dark: Material = mt["black"]
	var steel: Material = mt["steel"]
	var top := FLOOR + 0.68
	var cush := []
	for i in range(6):
		var t := float(i) / 5.0
		var bulge := sin(t * PI) * 0.025
		cush.append(MU.rounded_ring(0.25 + bulge * 0.5, top - 0.11, top + bulge, 0.05, SEAT_Z - 0.25 + t * 0.5, 3))
	var lo := MU.loft(cush, fabric)
	b.mesh("p", fabric, lo.mesh, Transform3D(Basis(), Vector3(x, 0, 0)))
	lo.free()
	var bxf := Transform3D(Basis.from_euler(Vector3(deg_to_rad(12.0), 0, 0)), Vector3(x, top + 0.02, SEAT_Z + 0.25))
	var br := []
	for i in range(5):
		var t := float(i) / 4.0
		var hw := 0.25 - 0.03 * t + sin(t * PI) * 0.01
		var r := PackedVector3Array()
		for k in range(16):
			var a := TAU * k / 16.0
			r.append(Vector3(cos(a) * hw, t * 0.68, 0.04 - sin(a) * (0.065 + 0.012 * sin(t * PI))))
		br.append(r)
	var bm := MU.loft(br, fabric)
	b.mesh("p", fabric, bm.mesh, bxf)
	bm.free()
	b.box("p", fabric, Vector3(0.3, 0.17, 0.1), bxf * Transform3D(Basis(), Vector3(0, 0.82, 0.06)))
	b.box("p", dark, Vector3(0.48, 0.62, 0.02), bxf * Transform3D(Basis(), Vector3(0, 0.33, 0.115)))
	for sx in [-1.0, 1.0]:
		b.box("p", steel, Vector3(0.025, 0.12, 0.025), bxf * Transform3D(Basis(), Vector3(sx * 0.08, 0.72, 0.06)))
		_bx(b, dark, Vector3(0.07, 0.05, 0.36), Vector3(x + sx * 0.32, top + 0.22, SEAT_Z + 0.02))
		_bx(b, dark, Vector3(0.04, 0.22, 0.04), Vector3(x + sx * 0.32, top + 0.1, SEAT_Z + 0.17))
	# gas strut pedestal on a swivel base bolted to the floor
	_cy(b, steel, 0.045, 0.34, Vector3(x, FLOOR + 0.36, SEAT_Z), Vector3.ZERO, 10)
	_cy(b, dark, 0.075, 0.2, Vector3(x, FLOOR + 0.1, SEAT_Z), Vector3.ZERO, 12)
	_bx(b, dark, Vector3(0.46, 0.03, 0.42), Vector3(x, top - 0.125, SEAT_Z))
	_bx(b, dark, Vector3(0.5, 0.02, 0.5), Vector3(x, FLOOR + 0.01, SEAT_Z))


# ------------------------------------------------- engine control panel
## A circuit breaker: black body with a toggle handle (up = ON).
func breaker(id: String, title: String, parent: Node3D, pos: Vector3, help := "") -> CabControl:
	var ctl := _host(parent, pos, Vector3.ZERO)
	_register(ctl, id, title, help)
	ctl.kind = CabControl.Kind.TOGGLE
	ctl.labels = ["OFF", "ON"]
	MU.box(ctl, Vector3(0.036, 0.075, 0.04), Vector3(0, 0, 0.02), MU.mat(Color(0.07, 0.07, 0.075), 0.6, 0.0, "cb_body"))
	MU.box(ctl, Vector3(0.028, 0.012, 0.002), Vector3(0, 0.026, 0.041), MU.mat(Color(0.92, 0.92, 0.9), 0.5, 0.0, "cb_label"))
	var pivot := Node3D.new()
	ctl.add_child(pivot)
	pivot.position = Vector3(0, -0.005, 0.04)
	pivot.rotation_degrees = Vector3(35, 0, 0)
	MU.box(pivot, Vector3(0.016, 0.012, 0.03), Vector3(0, 0, 0.014), MU.mat(Color(0.14, 0.14, 0.14), 0.45, 0.0, "cb_handle"))
	ctl.rot_axis = Vector3(-70, 0, 0)
	ctl.setup_part(pivot)
	ctl.pick_extent = Vector3(0.022, 0.042, 0.035)
	ctl.pick_offset = Vector3(0, 0, 0.03)
	return ctl


## While its door is shut, a cabinet stops the mouse reaching anything inside.
func _shut_in(root: Node3D, door_id: String, x0: float, x1: float, y0: float, y1: float, zf: float) -> void:
	add_blocker(root, Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, (zf + ZR) * 0.5), Vector3((x1 - x0) * 0.5, (y1 - y0) * 0.5, (ZR - zf) * 0.5), controls[door_id])


func _cabinet_box(b: MeshBatch, mt: Dictionary, x0: float, x1: float, y0: float, y1: float, zf: float) -> void:
	var cabm: Material = mt["cabinet"]
	_span(b, cabm, Vector3(x0, y0, zf), Vector3(x0 + 0.02, y1, ZR))
	_span(b, cabm, Vector3(x1 - 0.02, y0, zf), Vector3(x1, y1, ZR))
	_span(b, cabm, Vector3(x0, y1 - 0.02, zf), Vector3(x1, y1, ZR))
	_span(b, cabm, Vector3(x0, y0, zf), Vector3(x1, y0 + 0.02, ZR))
	_span(b, cabm, Vector3(x0, FLOOR, zf + 0.04), Vector3(x1, y0, ZR))         # locker under it
	_span(b, mt["black"], Vector3(x0 + 0.1, FLOOR + 0.2, zf + 0.035), Vector3(x0 + 0.16, FLOOR + 0.24, zf + 0.04))
	_span(b, mt["panel"], Vector3(x0 + 0.02, y0 + 0.02, ZR - 0.012), Vector3(x1 - 0.02, y1 - 0.02, ZR))


func _ecp(root: Node3D, b: MeshBatch, mt: Dictionary, p: String) -> void:
	var x0 := -1.0
	var x1 := -0.08
	var y0 := 2.08
	var y1 := 3.95
	var zf := 4.24
	_cabinet_box(b, mt, x0, x1, y0, y1, zf)
	door(p + "ecp_door", "Engine control panel door", root, Vector3(x0, (y0 + y1) * 0.5, zf), Vector3(0, 180, 0), Vector2(x1 - x0, y1 - y0),
		mt["cabinet"], "Behind it: the circuit breakers, the engine control switch, fuel prime and engine start / stop.", false, 100.0, "ENGINE CONTROL")
	var ep := frame(root, Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, ZR - 0.012), Vector3(0, 180, 0))
	_shut_in(root, p + "ecp_door", x0, x1, y0, y1, zf)
	text("ENGINE CONTROL PANEL", ep, Vector3(0, 0.6, 0.002), Vector3.ZERO, 0.0007)
	# engine starting controls
	rotary(p + "ecs", "Engine control switch", ep, Vector3(-0.27, 0.4, 0.0), Vector3.ZERO, ["ISOLATE", "RUN"], 0,
		"ISOLATE: the engine idles and ignores the throttle, and can be started. RUN: the unit loads when the controlling cab asks for power.", 0.03, 90.0)
	text("ENGINE CONTROL SWITCH", ep, Vector3(-0.27, 0.49, 0.002), Vector3.ZERO, 0.00042)
	button(p + "fuel_prime", "Fuel prime", ep, Vector3(-0.04, 0.4, 0.0), Vector3.ZERO, Color(0.12, 0.12, 0.12),
		"Hold to run the fuel pump and prime the injectors before starting (watch the fuel pressure rise above 200 kPa).", 0.02, false, false, "FUEL PRIME")
	button(p + "engine_start", "Engine start", ep, Vector3(0.1, 0.4, 0.0), Vector3.ZERO, Color(0.15, 0.6, 0.2),
		"Hold to crank the engine (the main alternator motors it round on the battery) until it fires. ECS must be in ISOLATE.", 0.02, false, false, "ENGINE START")
	button(p + "engine_stop", "Engine stop", ep, Vector3(0.24, 0.4, 0.0), Vector3.ZERO, Color(0.75, 0.08, 0.05),
		"Shuts this engine down (cuts its fuel).", 0.02, false, false, "ENGINE STOP")
	gauge(p + "batv", ep, Vector3(0.36, 0.4, 0.004), Vector3.ZERO, 0.045, 0, 100, 20, 5, "BATTERY", "V", [Color(0.05, 0.05, 0.05)])
	# twelve breakers in two rows
	var names := {"cb_control": "CONTROL", "cb_local": "LOCAL CONTROL", "cb_fuel": "FUEL PUMP", "cb_computer": "COMPUTER",
		"cb_excite": "EXCITATION", "cb_tcc1": "TRACTION 1", "cb_tcc2": "TRACTION 2", "cb_comp": "COMPRESSOR",
		"cb_lights": "LIGHTS", "cb_cabair": "CAB A/C", "cb_radio": "RADIO", "cb_alerter": "ALERTER"}
	var helps := {"cb_control": "Control circuits: the computer, fuel pump and cab controls all need it.",
		"cb_local": "Local control and battery charging from the auxiliary alternator.",
		"cb_fuel": "Fuel pump motor. Off = the engine stops for want of fuel.",
		"cb_computer": "Locomotive computer and the desk displays (25 s to boot).",
		"cb_excite": "Main alternator excitation: no load without it.",
		"cb_tcc1": "Traction converter 1 (truck 1 motors): half the tractive effort.",
		"cb_tcc2": "Traction converter 2 (truck 2 motors): half the tractive effort.",
		"cb_comp": "Air compressor control (governor and unloader).",
		"cb_lights": "Headlights, ditch, marker, cab, walkway and engine room lights.",
		"cb_cabair": "Cab air-conditioning.", "cb_radio": "Train radio.",
		"cb_alerter": "Alerter (vigilance) system."}
	for i in range(C92Sim.BREAKERS.size()):
		var id: String = C92Sim.BREAKERS[i]
		var col := i % 6
		var row := i / 6
		var pos := Vector3(-0.34 + col * 0.136, 0.13 - row * 0.25, 0.0)
		breaker(p + id, "Circuit breaker: " + names[id].capitalize(), ep, pos, helps[id])
		text(names[id], ep, pos + Vector3(0, -0.07, 0.002), Vector3.ZERO, 0.00036)
		text("ON", ep, pos + Vector3(0, 0.05, 0.002), Vector3.ZERO, 0.0003, Color(0.75, 0.78, 0.8))
	# instruction plate
	var plate := "COLD START\n1  BATTERY SWITCH ON (BATTERY BOX, LEFT WALKWAY)\n2  ALL BREAKERS ON, WAIT FOR THE COMPUTER\n3  ECS TO ISOLATE\n4  HOLD FUEL PRIME UNTIL FUEL PRESSURE > 200 kPa\n5  HOLD ENGINE START UNTIL THE ENGINE FIRES\n6  ECS TO RUN WHEN READY TO LOAD"
	_span(b, mt["white"], Vector3((x0 + x1) * 0.5 - 0.3, 2.41, ZR - 0.016), Vector3((x0 + x1) * 0.5 + 0.3, 2.66, ZR - 0.012))
	var pl := text(plate, ep, Vector3(-0.27, -0.48, 0.006), Vector3.ZERO, 0.00042, Color(0.1, 0.1, 0.1))
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	for id2 in [p + "ecs", p + "fuel_prime", p + "engine_start", p + "engine_stop"]:
		controls[id2].set_meta("behind", p + "ecp_door")
	for id3 in C92Sim.BREAKERS:
		controls[p + id3].set_meta("behind", p + "ecp_door")


func _brake_cabinet(root: Node3D, b: MeshBatch, mt: Dictionary, p: String) -> void:
	var x0 := 0.08
	var x1 := 1.0
	var y0 := 2.08
	var y1 := 3.95
	var zf := 4.24
	_cabinet_box(b, mt, x0, x1, y0, y1, zf)
	door(p + "brake_door", "Air brake cabinet door", root, Vector3(x1, (y0 + y1) * 0.5, zf), Vector3(0, 180, 0), Vector2(x1 - x0, y1 - y0),
		mt["cabinet"], "Behind it: the brake valve cut-out (LEAD / TRAIL), the dead engine cock and the air gauges.", true, 100.0, "AIR BRAKE")
	var bp := frame(root, Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, ZR - 0.012), Vector3(0, 180, 0))
	_shut_in(root, p + "brake_door", x0, x1, y0, y1, zf)
	text("AIR BRAKE", bp, Vector3(0, 0.6, 0.002), Vector3.ZERO, 0.0007)
	var blk := Color(0.05, 0.05, 0.05)
	var gs := [["bk_mr", "MAIN RES"], ["bk_er", "EQ RES"], ["bk_bp", "BRAKE PIPE"], ["bk_bc", "BRAKE CYL"]]
	for i in range(4):
		var g: Array = gs[i]
		gauge(p + g[0], bp, Vector3(-0.27 + i * 0.18, 0.42, 0.004), Vector3.ZERO, 0.055, 0, 1100, 200, 50, g[1], "kPa", [blk])
	rotary(p + "brake_mode", "Brake valve cut-out (LEAD / TRAIL)", bp, Vector3(-0.18, 0.12, 0.0), Vector3.ZERO, ["LEAD", "TRAIL"], 0,
		"LEAD: this unit's brake valve is cut in and controls the train brakes. TRAIL: cut out, for the second unit (and any cab you are not driving from). Only one unit may be in LEAD.", 0.035, 90.0)
	text("BRAKE VALVE", bp, Vector3(-0.18, 0.23, 0.002), Vector3.ZERO, 0.00045)
	cock(p + "dead_engine", "Dead engine cock", bp, Vector3(0.22, 0.1, 0.0), Vector3.ZERO, false,
		"Open only when this unit's engine is shut down and it is hauled: its main reservoir then charges from the brake pipe.")
	text("DEAD ENGINE", bp, Vector3(0.22, 0.24, 0.002), Vector3.ZERO, 0.00045)
	controls[p + "brake_mode"].set_meta("behind", p + "brake_door")
	controls[p + "dead_engine"].set_meta("behind", p + "brake_door")
	# pipework: relay valve, control valve and the brake pipe / MR pipes
	var pipe: Material = mt["pipe"]
	var cu: Material = mt["copper"]
	_fbx(b, mt["black"], bp, Vector3(0.24, 0.18, 0.12), Vector3(-0.16, -0.3, 0.06))
	_fbx(b, mt["black"], bp, Vector3(0.18, 0.22, 0.1), Vector3(0.2, -0.3, 0.05))
	text("RELAY VALVE", bp, Vector3(-0.16, -0.18, 0.002), Vector3.ZERO, 0.00036)
	text("CONTROL VALVE", bp, Vector3(0.2, -0.16, 0.002), Vector3.ZERO, 0.00036)
	for k in range(3):
		_fcy(b, pipe if k != 1 else cu, bp, 0.014, 1.2, Vector3(-0.39 + k * 0.035, -0.25, 0.03), Vector3.ZERO, 8)
	_fcy(b, cu, bp, 0.01, 0.7, Vector3(0.0, -0.5, 0.025), Vector3(0, 0, 90), 8)
	_fcy(b, pipe, bp, 0.014, 0.7, Vector3(0.0, -0.12, 0.03), Vector3(0, 0, 90), 8)


# ----------------------------------------------------------- outside
func _outside(root: Node3D, b: MeshBatch, mt: Dictionary, p: String, _u: int) -> void:
	var blue: Material = mt["blue"]
	# battery box on the left walkway, behind the cab
	door(p + "bat_door", "Battery box door (front leaf)", root, Vector3(-1.0, 2.16, 4.78), Vector3(0, -90, 0), Vector2(0.4, 0.8), blue,
		"Battery box. Open both leaves to reach the battery isolating switch.", true, 100.0, "BATTERY")
	door(p + "bat2_door", "Battery box door (rear leaf)", root, Vector3(-1.0, 2.16, 5.58), Vector3(0, -90, 0), Vector2(0.4, 0.8), blue,
		"Battery box.", false, 100.0)
	knife(p + "bat_switch", "Battery isolating switch", root, Vector3(-0.42, 2.33, 5.18), Vector3(0, -90, 0),
		"Connects the 74 V battery to this locomotive: the first switch in a cold start, and the last one off.")
	controls[p + "bat_switch"].set_meta("behind", p + "bat_door")
	# each leaf closes off its half of the box
	add_blocker(root, Vector3(-0.71, 2.16, 4.98), Vector3(0.29, 0.4, 0.2), controls[p + "bat_door"])
	add_blocker(root, Vector3(-0.71, 2.16, 5.38), Vector3(0.29, 0.4, 0.2), controls[p + "bat2_door"])
	# engine room doors (double, latched open across the walkway)
	door(p + "eng1_door", "Engine room door (front leaf)", root, Vector3(-1.0, 2.675, CoalModels.ENG_DOOR_Z0), Vector3(0, -90, 0),
		Vector2(CoalModels.ENG_DOOR_W, 1.75), blue, "Engine room: the 16-cylinder GE engine and its turbocharger.", true, 95.0)
	door(p + "eng2_door", "Engine room door (rear leaf)", root, Vector3(-1.0, 2.675, CoalModels.ENG_DOOR_Z0 + CoalModels.ENG_DOOR_W * 2.0), Vector3(0, -90, 0),
		Vector2(CoalModels.ENG_DOOR_W, 1.75), blue, "Engine room.", false, 95.0)
	# handbrake at the No. 2 end
	var hb := wheel(p + "handbrake", "Handbrake", root, Vector3(-0.7, CoalModels.HB_Y, CoalModels.RAD_Z1 + 0.16), Vector3.ZERO, 0.2, 0.0, 1.0, 0.0, 3.0,
		MU.mat(Color(0.06, 0.06, 0.06), 0.5, 0.3, "c92_hb_wheel"),
		"Locomotive handbrake (No. 2 end). Holds the unit with the air off. Turn clockwise to apply, anticlockwise to release (drag or scroll). Release it before moving!", 6, true)
	hb.custom_state = func() -> String:
		if hb.value > 0.97:
			return "APPLIED"
		if hb.value < 0.03:
			return "RELEASED"
		return "%d %% applied" % int(hb.value * 100.0)
	MU.label(root, "HANDBRAKE", Vector3(-0.7, CoalModels.HB_Y + 0.3, CoalModels.RAD_Z1 + 0.03), 0.0007, Color(0.05, 0.05, 0.05), Vector3.ZERO, 32)
	# walkway lights: under the cab roof at both rear corners, and over the No. 2 end
	var spots := [Vector3(-1.25, 3.95, 4.72), Vector3(1.25, 3.95, 4.72), Vector3(0.0, 4.08, CoalModels.RAD_Z1 + 0.08)]
	for sp in spots:
		var lm := MU.lamp(Color(1.0, 0.93, 0.8), 0.0)
		_bx(b, mt["black"], Vector3(0.16, 0.08, 0.1), sp + Vector3(0, 0.04, 0.0))
		MU.box(root, Vector3(0.12, 0.012, 0.07), sp, lm)
		walk_mats.append(lm)
		var wl := OmniLight3D.new()
		wl.light_color = Color(1.0, 0.92, 0.78)
		wl.omni_range = 7.5
		wl.light_energy = 0.0
		wl.shadow_enabled = false
		root.add_child(wl)
		wl.position = sp - Vector3(0, 0.1, 0)
		walk_lights.append(wl)


## Coupling between the No. 2 end of the front unit and the nose of the second:
## brake pipe and main reservoir hoses with their angle cocks, and the MU jumper.
func _coupling(r1: Node3D, r2: Node3D, mt: Dictionary) -> void:
	var gap := 22.0                  # second unit's front coupler face, in the front unit's space
	var b := MeshBatch.new()
	var hose: Material = mt["hose"]
	for e in [[-0.42, "bp", "Brake pipe"], [0.42, "mr", "Main reservoir equalising"]]:
		var x: float = e[0]
		var tip: String = "Open the angle cocks on both sides of a coupled hose; close them before uncoupling. A closed brake pipe cock with the train coupled = no brakes behind it!" if e[1] == "bp" else "Joins the two units' main reservoirs and carries the independent brake to the second unit."
		cock("l_%s_cock" % e[1], "%s cock (front unit, No. 2 end)" % e[2], r1, Vector3(x, 1.05, 21.7), Vector3(0, -90, 0), true, tip)
		cock("t_%s_cock" % e[1], "%s cock (second unit, No. 1 end)" % e[2], r2, Vector3(x, 1.05, 0.3), Vector3(0, -90, 0), true, tip)
		# hose with its glad hands, coupled across the gap
		_hose(b, hose, _sag(Vector3(x, 0.98, 21.72), Vector3(x, 0.98, gap + 0.28), 0.36), 0.026)
		_bx(b, MU.mat(Color(0.3, 0.3, 0.32), 0.4, 0.7, "glad_hand"), Vector3(0.07, 0.05, 0.12), Vector3(x, 0.62, gap))
	# MU receptacles either side of the gap, and the jumper cable
	for z in [21.68, gap + 0.32]:
		_bx(b, mt["black"], Vector3(0.16, 0.14, 0.08), Vector3(-0.95, 1.32, z))
		_cy(b, MU.mat(Color(0.3, 0.3, 0.3), 0.4, 0.6, "mu_socket"), 0.045, 0.03, Vector3(-0.95, 1.32, z + (0.04 if z < gap else -0.04)), Vector3(90, 0, 0), 12)
	_bx(b, mt["black"], Vector3(0.12, 0.12, 0.06), Vector3(-0.7, 1.32, 21.68))          # dummy (stowage) socket
	b.commit(r1, "Coupling")
	var mu := _host(r1, Vector3(-0.95, 1.32, 21.72), Vector3(0, -90, 0))
	_register(mu, "mu_jumper", "MU jumper cable",
		"The multiple-unit control cable between the units: throttle, reverser, dynamic brake, sand and alarms. Stowed = the second unit will not follow the controlling cab.")
	mu.kind = CabControl.Kind.TOGGLE
	mu.labels = ["STOWED", "CONNECTED"]
	mu.value = 1.0
	mu.pick_extent = Vector3(0.14, 0.12, 0.08)
	mu.pick_offset = Vector3(0, 0, 0.04)
	var cable := MU.mat(Color(0.05, 0.05, 0.05), 0.75, 0.0, "mu_cable")
	mu_connected = Node3D.new()
	r1.add_child(mu_connected)
	var bc := MeshBatch.new()
	_hose(bc, cable, _sag(Vector3(-0.95, 1.3, 21.76), Vector3(-0.95, 1.3, gap + 0.28), 0.55, 8), 0.03)
	bc.commit(mu_connected, "Jumper")
	mu_stowed = Node3D.new()
	r1.add_child(mu_stowed)
	var bs := MeshBatch.new()
	_hose(bs, cable, _sag(Vector3(-0.95, 1.3, 21.76), Vector3(-0.7, 1.3, 21.74), 0.5, 8), 0.03)
	bs.commit(mu_stowed, "Jumper")
	mu_stowed.visible = false


# --------------------------------------------------------------- views
func _views() -> void:
	add_view("Driver", Vector3(-0.72, 3.12, 3.38), 0.0, -10.0)
	add_view("Second person's seat", Vector3(0.72, 3.12, 3.38), 0.0, -8.0)
	add_view("Engine control panel", Vector3(-0.05, 3.35, 3.48), 152.0, -15.0)
	add_view("Air brake cabinet", Vector3(0.05, 3.35, 3.48), -152.0, -15.0)
	add_view("Leaning out (left)", Vector3(-1.62, 3.25, 3.2), -172.0, -6.0, null, true)
	add_view("Battery box (left walkway)", Vector3(-1.38, 2.62, 5.18), -90.0, -30.0, null, true)
	add_view("Engine room doors", Vector3(-1.4, 3.3, CoalModels.ENG_DOOR_Z0 + CoalModels.ENG_DOOR_W), -90.0, -28.0, null, true)
	add_view("Handbrake (No. 2 end)", Vector3(-0.62, 3.3, 22.1), 0.0, -28.0, null, true)
	if cab2 == null:
		quick_views = ["Driver", "Engine control panel", "Battery box (left walkway)", "Handbrake (No. 2 end)", "Air brake cabinet"]
		return
	add_view("Coupling between the units", Vector3(-2.0, 1.5, 22.6), -69.0, -16.0, null, true)
	add_view("Second unit: driver", Vector3(-0.72, 3.12, 3.38), 0.0, -10.0, cab2)
	add_view("Second unit: engine control panel", Vector3(-0.05, 3.35, 3.48), 152.0, -15.0, cab2)
	add_view("Second unit: air brake cabinet", Vector3(0.05, 3.35, 3.48), -152.0, -15.0, cab2)
	add_view("Second unit: battery box", Vector3(-1.38, 2.62, 5.18), -90.0, -30.0, cab2, true)
	add_view("Second unit: engine room doors", Vector3(-1.4, 3.3, CoalModels.ENG_DOOR_Z0 + CoalModels.ENG_DOOR_W), -90.0, -28.0, cab2, true)
	add_view("Second unit: handbrake", Vector3(-0.62, 3.3, 22.1), 0.0, -28.0, cab2, true)
	quick_views = ["Driver", "Engine control panel", "Battery box (left walkway)", "Coupling between the units", "Second unit: driver"]


## Outside, or in a cab whose lights are off, the crew use a torch at night.
func needs_torch(view_name: String) -> bool:
	if view_outside.get(view_name, false):
		return true
	var u := 1 if cab2 and view_anchor.get(view_name, self) == cab2 else 0
	return dome_lights[u].light_energy <= 0.0 and desk_lights[u].light_energy <= 0.0


# -------------------------------------------------------------- update
func update_visuals(sim: C92Sim, delta: float) -> void:
	if not _bound:
		_bound = true
		for s in screens:
			s.sim = sim
	var c := maxi(sim.ctrl, 0)
	for u in range(units.size()):
		var p: String = PFX[u]
		var pw: bool = sim._powered(u)
		var live: bool = pw and val(p + "cb_control") > 0.5
		var lights_ok: bool = pw and val(p + "cb_lights") > 0.5
		# pneumatic gauges read whatever is in the pipes
		gauges[p + "air1"].set_value(0, sim.mr[u])
		gauges[p + "air1"].set_value(1, sim.er[u])
		gauges[p + "air2"].set_value(0, sim.bp[u])
		gauges[p + "air2"].set_value(1, sim.loco_bc[u])
		gauges[p + "bp2"].set_value(0, sim.bp[u])
		gauges[p + "bp2"].set_value(1, sim.loco_bc[u])
		gauges[p + "bk_mr"].set_value(0, sim.mr[u])
		gauges[p + "bk_er"].set_value(0, sim.er[u])
		gauges[p + "bk_bp"].set_value(0, sim.bp[u])
		gauges[p + "bk_bc"].set_value(0, sim.loco_bc[u])
		gauges[p + "batv"].set_value(0, sim.bat_v[u])
		# electrical instruments need the control circuits
		var spd := absf(sim.train.speed) * 3.6 if live else 0.0
		gauges[p + "speedo"].set_value(0, spd)
		gauges[p + "speedo2"].set_value(0, spd)
		gauges[p + "loadmeter"].set_value(0, (sim.te[u] - sim.db[u]) / 1000.0 if live else 0.0)
		# desk lamps
		set_lamp(p + "lamp_pcs", live and sim.pcs_open, 0.0)
		set_lamp(p + "lamp_slip", live and sim.slip[u], 0.3)
		set_lamp(p + "lamp_db", live and sim.db[u] > 2000.0)
		set_lamp(p + "lamp_sand", live and sim.ctrl >= 0 and val(PFX[c] + "sand") > 0.5)
		set_lamp(p + "lamp_hb", live and (val("l_handbrake") > 0.3 or val("t_handbrake") > 0.3))
		set_lamp(p + "lamp_comp", live and sim.comp_loaded[u])
		set_lamp(p + "lamp_ctrl", live and sim.ctrl == u)
		set_lamp(p + "alerter", live and sim.alerter_warn and sim.ctrl == u, 0.5)
		# lights
		var gauge_on := live and val(p + "gauge_light") > 0.5
		desk_lights[u].light_energy = 0.35 if gauge_on else 0.0
		var dome_on := lights_ok and val(p + "cab_light") > 0.5
		dome_lights[u].light_energy = 1.3 if dome_on else 0.0
		dome_mats[u].emission_energy_multiplier = 2.4 if dome_on else 0.0
		# seen from outside at night, a lit cab glows through its windows
		var cg: StandardMaterial3D = units[u].extra.get("cab_glass")
		if cg:
			cg.emission_energy_multiplier = 0.45 if dome_on else (0.06 if gauge_on else 0.0)
		var walk_on := lights_ok and val(p + "walkway_lights") > 0.5
		for k in range(3):
			walk_lights[u * 3 + k].light_energy = 1.1 if walk_on else 0.0
			walk_mats[u * 3 + k].emission_energy_multiplier = 3.0 if walk_on else 0.0
		# wipers: the blade angle follows the sim's wiper phase
		var ph: float = sim.wiper_phase[u]
		var moving: bool = absf(ph - float(_wiper_prev[u])) > 1e-6
		_wiper_idle[u] = 0.0 if moving else float(_wiper_idle[u]) + delta
		var rate := 0.0
		if moving:
			rate = 0.6 if int(val(p + "wipers")) <= 1 else 1.0
		_wiper_prev[u] = ph
		var a := 0.5 - 0.5 * cos(ph * TAU)
		for k in range(2):
			wiper_arms[u * 2 + k].rotation_degrees = Vector3(0, 0, 84.0 - a * 168.0)
			var sm := pane_mats[u * 2 + k]
			sm.set_shader_parameter("wipe_phase", ph)
			sm.set_shader_parameter("wipe_rate", rate)
			sm.set_shader_parameter("wipe_idle", _wiper_idle[u])
			sm.set_shader_parameter("speed", absf(sim.train.speed))
	if mu_connected:
		var conn := val("mu_jumper") > 0.5
		mu_connected.visible = conn
		mu_stowed.visible = not conn
