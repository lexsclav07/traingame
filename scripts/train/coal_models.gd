class_name CoalModels
## Pacific National 92 class (UGL C44aci, GE-based) and Hunter Valley
## aluminium coal hoppers. Vehicle space as everywhere else: z = distance back
## from the front coupler face, y = up from rail top, x = right.
##  C44aci: 22.0 m over couplers, 139 t with a coal-service fuel load, Co-Co,
##  1016 mm wheels, GE 7FDL-16, "safety" cab at the No. 1 end, enlarged
##  radiator with wings at the No. 2 end. Pacific National blue and yellow.
##  Coal hopper: 16.234 m coupled length, 23 t tare, 120 t gross (30 t axles).
## Static parts are merged per material (MeshBatch); the wagons share their
## meshes so a 90-wagon train builds quickly.

const DECK := 1.62          # walkway deck, above rail
const HOOD_HW := 1.0        # long hood half width
const FRAME_HW := 1.47      # deck / frame half width
const CAB_Z0 := 2.08        # cab front wall (windscreen)
const CAB_Z1 := 4.6         # cab rear wall
const CAB_TOP := 4.15
const NOSE_Z := 0.95        # nose front face
const NOSE_TOP := 2.78
const WIN_Y0 := 2.9         # windscreen bottom / top
const WIN_Y1 := 3.72
const HOOD_TOP := 3.92
const RAD_Z0 := 18.9        # radiator compartment
const RAD_Z1 := 21.3
const ENG_DOOR_Z0 := 10.2           # openable engine room doors (left side): two leaves
const ENG_DOOR_W := 0.42            # each leaf, hinged at the outer edges
const ENG_DOOR_Y := [1.8, 3.55]
const BAT_BOX := [4.78, 5.58, 1.76, 2.56]   # battery box door: z0, z1, y0, y1 (left side of the hood)
const WAGON_L := 16.234
const HB_Y := 2.98                  # handbrake wheel centre height (No. 2 end)

static var pn_blue := Color(0.06, 0.14, 0.34)
static var pn_yellow := Color(0.98, 0.72, 0.04)


static func mats() -> Dictionary:
	var glass := MU.mat(Color(0.02, 0.025, 0.03), 0.05, 0.0, "pn_glass")
	return {
		"blue": TX.painted(pn_blue, 0.32, 0.15, "grime", 0.25, 0.45, "pn_blue"),
		"yellow": TX.painted(pn_yellow, 0.36, 0.05, "grime", 0.3, 0.35, "pn_yellow"),
		"black": TX.painted(Color(0.035, 0.035, 0.04), 0.55, 0.3, "grime", 0.4, 0.0, "pn_black"),
		"dark": TX.painted(Color(0.12, 0.12, 0.125), 0.6, 0.35, "grime", 0.5, 0.0, "pn_dark"),
		"grille": MU.mat(Color(0.05, 0.05, 0.055), 0.7, 0.45, "pn_grille"),
		"steel": TX.metal(Color(0.6, 0.6, 0.62), 0.35, true, 3.0, "pn_steel"),
		"rail": TX.painted(Color(0.95, 0.74, 0.08), 0.42, 0.1, "grime", 0.8, 0.0, "pn_handrail"),
		"glass": glass,
		"white": MU.mat(Color(0.92, 0.92, 0.9), 0.5, 0.0, "pn_white"),
		"rubber": MU.mat(Color(0.03, 0.03, 0.03), 0.85, 0.0, "pn_rubber"),
		"interior": MU.mat(Color(0.02, 0.02, 0.022), 0.9, 0.0, "pn_engine_room"),
	}


static func _b(b: MeshBatch, mat: Material, size: Vector3, pos: Vector3, rot := Vector3.ZERO) -> void:
	b.box("p", mat, size, Transform3D(Basis.from_euler(rot * (PI / 180.0)), pos))


static func _c(b: MeshBatch, mat: Material, r: float, h: float, pos: Vector3, rot := Vector3.ZERO, segs := 12, r_top := -1.0) -> void:
	b.cyl("p", mat, Transform3D(Basis.from_euler(rot * (PI / 180.0)), pos), r if r_top < 0.0 else r_top, r, h, segs)


## Box spanning two corners (min, max).
static func _span(b: MeshBatch, mat: Material, lo: Vector3, hi: Vector3) -> void:
	b.box("p", mat, (hi - lo).abs(), Transform3D(Basis(), (lo + hi) * 0.5))


# ================================================================= 92 class
static func c44aci(number: String) -> Vehicle:
	var v := Vehicle.new()
	v.kind = "c44"
	v.name = "PN_" + number
	v.vlength = 22.0
	v.pivot_front = 4.0
	v.pivot_rear = 18.0
	v.mass_tare = 139000.0
	v.axles = 6
	v.motored_axles = 6
	v.brake_mass_ratio = 0.3
	var m := v.make_model_root()
	var mt := mats()
	var b := MeshBatch.new()
	var blue: Material = mt["blue"]
	var yellow: Material = mt["yellow"]
	var black: Material = mt["black"]
	var dark: Material = mt["dark"]
	_frame(b, mt)
	_nose_and_cab(b, m, v, mt, number)
	_long_hood(b, m, v, mt)
	_radiator(b, m, v, mt)
	_underframe(b, mt)
	_handrails(b, mt)
	for bz in [v.pivot_front, v.pivot_rear]:
		_bogie(v, m, mt, bz)
	# lettering: PACIFIC NATIONAL on the hood, number on the cab sides
	for sx in [-1.0, 1.0]:
		# behind the engine room doors, clear of the air intakes
		var ln := MU.label(m, "PACIFIC NATIONAL", Vector3(sx * (HOOD_HW + 0.006), 3.1, 14.95), 0.0079, Color(0.95, 0.95, 0.95), Vector3(0, 90.0 * sx, 0), 96)
		ln.double_sided = false
		var nl := MU.label(m, number, Vector3(sx * (FRAME_HW + 0.006), 2.4, 3.3), 0.0042, Color(0.97, 0.97, 0.97), Vector3(0, 90.0 * sx, 0), 96)
		nl.double_sided = false
	var fl := MU.label(m, number, Vector3(0, 2.2, NOSE_Z - 0.006), 0.0032, Color(0.05, 0.05, 0.05), Vector3(0, 180, 0), 96)
	fl.double_sided = false
	b.commit(m, "Body")
	var cab := Node3D.new()
	cab.name = "CabRoot"
	m.add_child(cab)
	v.cab_root = cab
	v.finish_model()
	return v


## Inside of a box: six quads facing inwards (rooms seen through an opening).
static func _room(b: MeshBatch, mat: Material, lo: Vector3, hi: Vector3) -> void:
	var x0 := lo.x
	var x1 := hi.x
	var y0 := lo.y
	var y1 := hi.y
	var z0 := lo.z
	var z1 := hi.z
	b.quad("room", mat, Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y0, z0), Vector3(x0, y0, z0))
	b.quad("room", mat, Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1))
	b.quad("room", mat, Vector3(x0, y0, z1), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x0, y1, z1))
	b.quad("room", mat, Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0))
	b.quad("room", mat, Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x0, y1, z0))
	b.quad("room", mat, Vector3(x1, y0, z1), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x1, y1, z1))


## Underframe, walkway deck, headstocks, pilots, couplers and corner steps.
static func _frame(b: MeshBatch, mt: Dictionary) -> void:
	var blue: Material = mt["blue"]
	var yellow: Material = mt["yellow"]
	var black: Material = mt["black"]
	var dark: Material = mt["dark"]
	# deck plate and side sills (yellow safety stripe along the bottom)
	_span(b, dark, Vector3(-FRAME_HW, DECK - 0.05, 0.35), Vector3(FRAME_HW, DECK, 21.65))
	for sx in [-1.0, 1.0]:
		_span(b, blue, Vector3(sx * FRAME_HW - 0.035, 1.17, 0.35), Vector3(sx * FRAME_HW + 0.035, DECK - 0.01, 21.65))
		_span(b, yellow, Vector3(sx * FRAME_HW - 0.04, 1.17, 0.35), Vector3(sx * FRAME_HW + 0.04, 1.27, 21.65))
	_span(b, black, Vector3(-0.85, 1.12, 0.4), Vector3(0.85, 1.58, 21.6))
	# headstocks with the anticlimber, painted yellow
	for z in [0.47, 21.53]:
		_b(b, yellow, Vector3(FRAME_HW * 2.0, 0.55, 0.24), Vector3(0, 1.33, z))
		_b(b, black, Vector3(FRAME_HW * 2.0 - 0.1, 0.06, 0.06), Vector3(0, 1.62, z - 0.12 * signf(11.0 - z)))
	# pilots (snowploughs): sloped plates below the headstocks
	for pz in [[0.3, -1.0], [21.7, 1.0]]:
		var z: float = pz[0]
		var dir: float = pz[1]
		_b(b, yellow, Vector3(2.7, 0.62, 0.06), Vector3(0, 0.62, z + dir * 0.05), Vector3(28.0 * -dir, 0, 0))
		for sx in [-1.0, 1.0]:
			_b(b, black, Vector3(0.06, 0.62, 0.36), Vector3(sx * 1.3, 0.8, z + dir * 0.02))
		_coupler(b, mt, 0.0 if dir < 0.0 else 22.0, dir)
	# steps at the four corners, below the porches
	for c in [[0.62, -1.0], [21.38, 1.0]]:
		var cz: float = c[0]
		for sx in [-1.0, 1.0]:
			for k in range(3):
				var y := 0.42 + k * 0.4
				_b(b, mt["steel"], Vector3(0.5, 0.035, 0.24), Vector3(sx * 1.2, y, cz))
			_b(b, yellow, Vector3(0.04, 1.25, 0.26), Vector3(sx * 1.45, 0.98, cz))
			_b(b, yellow, Vector3(0.04, 1.25, 0.26), Vector3(sx * 0.95, 0.98, cz))


static func _coupler(b: MeshBatch, mt: Dictionary, z_face: float, dir: float) -> void:
	var steel: Material = mt["steel"]
	var dark: Material = mt["dark"]
	_b(b, dark, Vector3(0.36, 0.36, 0.3), Vector3(0, 0.88, z_face - dir * 0.18))      # knuckle head
	_b(b, steel, Vector3(0.1, 0.22, 0.14), Vector3(0.08, 0.88, z_face - dir * 0.04))   # knuckle
	_b(b, dark, Vector3(0.22, 0.22, 0.6), Vector3(0, 0.9, z_face - dir * 0.55))        # shank
	# uncoupling lever across the headstock
	b.tube("p", steel, Vector3(-1.2, 1.18, z_face - dir * 0.4), Vector3(0.1, 1.05, z_face - dir * 0.36), 0.015, 6)


## Nose, safety cab shell, windows, roof equipment and front lights.
static func _nose_and_cab(b: MeshBatch, m: Node3D, v: Vehicle, mt: Dictionary, number: String) -> void:
	var blue: Material = mt["blue"]
	var yellow: Material = mt["yellow"]
	var black: Material = mt["black"]
	var glass: Material = mt["glass"]
	# nose: rounded top front edge
	var rings := []
	for s in [[NOSE_Z, 2.5, 1.12, 0.22], [NOSE_Z + 0.2, NOSE_TOP - 0.02, 1.2, 0.28], [CAB_Z0 + 0.02, NOSE_TOP, 1.22, 0.3]]:
		rings.append(MU.rounded_ring(s[2], DECK, s[1], s[3], s[0], 5))
	var lo := MU.loft(rings, yellow, true, true)
	b.mesh("p", yellow, lo.mesh, Transform3D())
	lo.free()
	# nose door outline, number board recess, sand fillers
	_b(b, black, Vector3(0.6, 0.012, 0.012), Vector3(-0.55, 2.62, NOSE_Z + 0.12), Vector3(-30, 0, 0))
	for sx in [-1.0, 1.0]:
		_c(b, mt["dark"], 0.06, 0.05, Vector3(sx * 0.95, DECK + 0.02, 0.7), Vector3.ZERO, 10)
	# cab front wall (yellow) around the two windscreens
	var z0 := CAB_Z0
	var t := 0.06
	_span(b, yellow, Vector3(-FRAME_HW + 0.02, NOSE_TOP - 0.02, z0), Vector3(FRAME_HW - 0.02, WIN_Y0, z0 + t))
	_span(b, yellow, Vector3(-FRAME_HW + 0.02, WIN_Y1, z0), Vector3(FRAME_HW - 0.02, CAB_TOP, z0 + t))
	_span(b, yellow, Vector3(-0.07, WIN_Y0, z0), Vector3(0.07, WIN_Y1, z0 + t))
	for sx in [-1.0, 1.0]:
		_span(b, yellow, Vector3(minf(sx * 1.3, sx * (FRAME_HW - 0.02)), WIN_Y0, z0), Vector3(maxf(sx * 1.3, sx * (FRAME_HW - 0.02)), WIN_Y1, z0 + t))
		# the part of the cab front wider than the nose, down to the deck
		_span(b, yellow, Vector3(minf(sx * 1.22, sx * (FRAME_HW - 0.02)), DECK, z0), Vector3(maxf(sx * 1.22, sx * (FRAME_HW - 0.02)), NOSE_TOP, z0 + t))
		# windscreens: one-sided outward-facing glass (culled from inside the cab)
		var xa: float = sx * 0.07
		var xb: float = sx * 1.3
		var x0 := minf(xa, xb)
		var x1 := maxf(xa, xb)
		b.quad("glass", glass, Vector3(x1, WIN_Y0, z0 - 0.002), Vector3(x0, WIN_Y0, z0 - 0.002), Vector3(x0, WIN_Y1, z0 - 0.002), Vector3(x1, WIN_Y1, z0 - 0.002))
		# rubber surrounds and the wiper parks
		_b(b, mt["rubber"], Vector3(x1 - x0 + 0.03, 0.03, 0.02), Vector3((x0 + x1) * 0.5, WIN_Y0 + 0.01, z0 - 0.01))
		_b(b, mt["rubber"], Vector3(x1 - x0 + 0.03, 0.03, 0.02), Vector3((x0 + x1) * 0.5, WIN_Y1 - 0.01, z0 - 0.01))
	# cab sides with sliding windows, and the doors in the rear wall
	for sx in [-1.0, 1.0]:
		var xo: float = sx * FRAME_HW
		var x_in: float = sx * (FRAME_HW - 0.05)
		var xl := minf(xo, x_in)
		var xr := maxf(xo, x_in)
		_span(b, blue, Vector3(xl, DECK, z0), Vector3(xr, WIN_Y0, CAB_Z1))
		_span(b, blue, Vector3(xl, WIN_Y1, z0), Vector3(xr, CAB_TOP, CAB_Z1))
		_span(b, yellow, Vector3(xl, WIN_Y0, z0), Vector3(xr, WIN_Y1, 2.42))         # yellow wraps round the front corner
		_span(b, blue, Vector3(xl, WIN_Y0, 3.78), Vector3(xr, WIN_Y1, CAB_Z1))
		_span(b, blue, Vector3(xl, WIN_Y0, 3.08), Vector3(xr, WIN_Y1, 3.14))          # window frame between the panes
		var gx: float = sx * (FRAME_HW + 0.002)
		# (faces outwards: seen from outside, bottom-left first)
		if sx > 0.0:
			b.quad("glass", glass, Vector3(gx, WIN_Y0, 3.78), Vector3(gx, WIN_Y0, 2.42), Vector3(gx, WIN_Y1, 2.42), Vector3(gx, WIN_Y1, 3.78))
		else:
			b.quad("glass", glass, Vector3(gx, WIN_Y0, 2.42), Vector3(gx, WIN_Y0, 3.78), Vector3(gx, WIN_Y1, 3.78), Vector3(gx, WIN_Y1, 2.42))
		# yellow front edge of the cab side, below the window
		_span(b, yellow, Vector3(xl - 0.001, DECK, z0), Vector3(xr + 0.001, WIN_Y0, 2.42))
		# rear wall either side of the hood, with the cab doors to the walkways
		var xd0 := minf(sx * (HOOD_HW + 0.02), sx * (FRAME_HW - 0.02))
		var xd1 := maxf(sx * (HOOD_HW + 0.02), sx * (FRAME_HW - 0.02))
		_span(b, blue, Vector3(xd0, 3.55, CAB_Z1 - 0.06), Vector3(xd1, CAB_TOP, CAB_Z1))
		# the cab door, with its window open through to the cab
		_span(b, blue, Vector3(xd0, DECK, CAB_Z1 - 0.03), Vector3(xd1, 2.75, CAB_Z1))
		_span(b, blue, Vector3(xd0, 3.35, CAB_Z1 - 0.03), Vector3(xd1, 3.55, CAB_Z1))
		_span(b, blue, Vector3(xd0, 2.75, CAB_Z1 - 0.03), Vector3(xd0 + 0.08, 3.35, CAB_Z1))
		_span(b, blue, Vector3(xd1 - 0.08, 2.75, CAB_Z1 - 0.03), Vector3(xd1, 3.35, CAB_Z1))
		b.quad("glass", glass, Vector3(xd0 + 0.08, 2.75, CAB_Z1 + 0.004), Vector3(xd1 - 0.08, 2.75, CAB_Z1 + 0.004), Vector3(xd1 - 0.08, 3.35, CAB_Z1 + 0.004), Vector3(xd0 + 0.08, 3.35, CAB_Z1 + 0.004))
		_b(b, mt["steel"], Vector3(0.03, 0.12, 0.03), Vector3(sx * (HOOD_HW + 0.08), 2.55, CAB_Z1 + 0.02))
		# grab rails beside the doors
		_c(b, mt["rail"], 0.016, 1.1, Vector3(sx * (FRAME_HW - 0.06), 2.6, CAB_Z1 + 0.06), Vector3.ZERO, 8)
	# roof: slight crown, air conditioner, horn, antennas
	var roof_rings := []
	for z in [z0 - 0.04, CAB_Z1 + 0.02]:
		roof_rings.append(MU.rounded_ring(FRAME_HW + 0.02, CAB_TOP - 0.06, CAB_TOP + 0.08, 0.16, z, 4))
	var rl := MU.loft(roof_rings, blue, true, true)
	b.mesh("p", blue, rl.mesh, Transform3D())
	rl.free()
	_b(b, mt["dark"], Vector3(1.1, 0.24, 0.95), Vector3(0.45, CAB_TOP + 0.2, 3.7))
	_b(b, mt["grille"], Vector3(0.9, 0.012, 0.75), Vector3(0.45, CAB_TOP + 0.325, 3.7))
	# Nathan K5 five-chime horn
	_b(b, mt["dark"], Vector3(0.5, 0.05, 0.12), Vector3(-0.45, CAB_TOP + 0.12, 2.95))
	for k in range(5):
		var hl: float = [0.36, 0.3, 0.26, 0.22, 0.32][k]
		_c(b, mt["steel"], 0.04, hl, Vector3(-0.65 + k * 0.1, CAB_TOP + 0.18, 2.95 - hl * 0.3), Vector3(90, 0, 0), 10, 0.025)
	_c(b, black, 0.01, 0.5, Vector3(-1.0, CAB_TOP + 0.33, 3.9), Vector3.ZERO, 6)
	_c(b, black, 0.012, 0.3, Vector3(1.05, CAB_TOP + 0.23, 2.6), Vector3.ZERO, 6)
	# headlights (twin, in the header above the windscreens), ditch lights
	# low on the front porch, white markers and red tail markers on the nose
	var head := MU.lamp(Color(1.0, 0.97, 0.88), 0.0)
	var ditch := MU.lamp(Color(1.0, 0.95, 0.85), 0.0)
	var marker := MU.lamp(Color(1.0, 1.0, 0.92), 0.0)
	var tail := MU.lamp(Color(1.0, 0.06, 0.03), 0.0)
	for sx in [-1.0, 1.0]:
		_c(b, black, 0.13, 0.08, Vector3(sx * 0.42, 3.94, z0 - 0.02), Vector3(90, 0, 0), 16)
		MU.cyl(m, 0.1, 0.02, Vector3(sx * 0.42, 3.94, z0 - 0.065), head, Vector3(90, 0, 0), 16)
		_b(b, black, Vector3(0.22, 0.22, 0.12), Vector3(sx * 1.26, 1.92, 0.42))
		_c(b, black, 0.012, 0.3, Vector3(sx * 1.26, 1.72, 0.42), Vector3.ZERO, 6)
		MU.cyl(m, 0.075, 0.02, Vector3(sx * 1.26, 1.92, 0.355), ditch, Vector3(90, 0, 0), 14)
		_b(b, black, Vector3(0.2, 0.12, 0.05), Vector3(sx * 0.92, 2.45, NOSE_Z - 0.01))
		MU.box(m, Vector3(0.07, 0.07, 0.02), Vector3(sx * 0.87, 2.45, NOSE_Z - 0.04), marker)
		MU.box(m, Vector3(0.07, 0.07, 0.02), Vector3(sx * 0.97, 2.45, NOSE_Z - 0.04), tail)
	v.head_lamps.append(head)
	v.marker_lamps.append(marker)
	v.tail_lamps.append(tail)
	v.extra["ditch_lamps"] = [ditch]
	var spot := SpotLight3D.new()
	spot.light_color = Color(1.0, 0.95, 0.86)
	spot.spot_range = 420.0
	spot.spot_angle = 11.0
	spot.light_energy = 0.0
	spot.shadow_enabled = false
	m.add_child(spot)
	spot.position = Vector3(0, 3.9, 1.6)
	spot.rotation_degrees = Vector3(-1.4, 0, 0)
	v.head_lights.append(spot)
	var dls := []
	for sx in [-1.0, 1.0]:
		var dl := SpotLight3D.new()
		dl.light_color = Color(1.0, 0.94, 0.84)
		dl.spot_range = 120.0
		dl.spot_angle = 22.0
		dl.light_energy = 0.0
		dl.shadow_enabled = false
		m.add_child(dl)
		dl.position = Vector3(sx * 1.26, 1.92, 0.25)
		dl.rotation_degrees = Vector3(-3.0, -sx * 6.0, 0)
		dls.append(dl)
	v.extra["ditch_lights"] = dls


## Long hood: dynamic brake section behind the cab, engine room with two
## openable doors on the left (the doors themselves belong to the cab
## script), battery box, exhaust stack and door panel lines.
static func _long_hood(b: MeshBatch, m: Node3D, v: Vehicle, mt: Dictionary) -> void:
	var blue: Material = mt["blue"]
	var dark: Material = mt["dark"]
	var grille: Material = mt["grille"]
	var z0 := CAB_Z1
	var z1 := RAD_Z0
	var rr := 0.18
	# roof with rounded edges
	_span(b, blue, Vector3(-HOOD_HW + rr, HOOD_TOP - 0.06, z0), Vector3(HOOD_HW - rr, HOOD_TOP, z1))
	for sx in [-1.0, 1.0]:
		_c(b, blue, rr, z1 - z0, Vector3(sx * (HOOD_HW - rr), HOOD_TOP - rr, (z0 + z1) * 0.5), Vector3(90, 0, 0), 14)
	# right side: one piece; left side: pieces around the battery box and the
	# engine room door opening
	var t := 0.05
	_span(b, blue, Vector3(HOOD_HW - t, DECK, z0), Vector3(HOOD_HW, HOOD_TOP - rr, z1))
	var xl := -HOOD_HW
	var dz0: float = ENG_DOOR_Z0
	var dz1: float = ENG_DOOR_Z0 + ENG_DOOR_W * 2.0
	var dy0: float = ENG_DOOR_Y[0]
	var dy1: float = ENG_DOOR_Y[1]
	var bz0: float = BAT_BOX[0]
	var bz1: float = BAT_BOX[1]
	var by0: float = BAT_BOX[2]
	var by1: float = BAT_BOX[3]
	_span(b, blue, Vector3(xl, DECK, z0), Vector3(xl + t, HOOD_TOP - rr, bz0))
	_span(b, blue, Vector3(xl, DECK, bz0), Vector3(xl + t, by0, bz1))
	_span(b, blue, Vector3(xl, by1, bz0), Vector3(xl + t, HOOD_TOP - rr, bz1))
	_span(b, blue, Vector3(xl, DECK, bz1), Vector3(xl + t, HOOD_TOP - rr, dz0))
	_span(b, blue, Vector3(xl, DECK, dz0), Vector3(xl + t, dy0, dz1))
	_span(b, blue, Vector3(xl, dy1, dz0), Vector3(xl + t, HOOD_TOP - rr, dz1))
	_span(b, blue, Vector3(xl, DECK, dz1), Vector3(xl + t, HOOD_TOP - rr, z1))
	# battery box: a recess with the cells and the isolating switch behind its door
	_span(b, dark, Vector3(xl + 0.02, by0, bz0), Vector3(xl + 0.6, by0 + 0.02, bz1))
	_span(b, dark, Vector3(xl + 0.58, by0, bz0), Vector3(xl + 0.6, by1, bz1))
	_span(b, dark, Vector3(xl + 0.02, by0, bz0), Vector3(xl + 0.6, by1, bz0 + 0.02))
	_span(b, dark, Vector3(xl + 0.02, by0, bz1 - 0.02), Vector3(xl + 0.6, by1, bz1))
	_span(b, dark, Vector3(xl + 0.02, by1 - 0.02, bz0), Vector3(xl + 0.6, by1, bz1))
	# battery cables to the isolating switch
	for k in range(2):
		b.tube("p", MU.mat(Color(0.05, 0.05, 0.05), 0.8, 0.0, "battery_cable"), Vector3(xl + 0.3, by0 + 0.36, bz0 + 0.12 + k * 0.51), Vector3(xl + 0.55, by0 + 0.5, (bz0 + bz1) * 0.5 + (k - 0.5) * 0.1), 0.012, 6)
	for k in range(4):
		var cz := bz0 + 0.12 + k * 0.17
		_b(b, MU.mat(Color(0.15, 0.15, 0.16), 0.6, 0.0, "battery_cell"), Vector3(0.36, 0.3, 0.14), Vector3(xl + 0.36, by0 + 0.17, cz))
		_c(b, MU.mat(Color(0.55, 0.12, 0.08), 0.5, 0.0, "battery_term"), 0.018, 0.04, Vector3(xl + 0.3, by0 + 0.34, cz), Vector3.ZERO, 6)
	# engine room behind the doors (walls seen from inside), the V16's block,
	# cylinder heads, exhaust manifold, turbocharger and a walkway grating
	var rz0 := dz0 - 1.3
	var rz1 := dz1 + 1.3
	_room(b, mt["interior"], Vector3(xl + 0.06, DECK + 0.01, rz0), Vector3(HOOD_HW - 0.06, HOOD_TOP - 0.08, rz1))
	var eng := TX.painted(Color(0.42, 0.44, 0.46), 0.5, 0.4, "grime", 1.0, 0.0, "engine_grey")
	_span(b, eng, Vector3(-0.42, DECK, rz0 + 0.1), Vector3(0.42, 2.55, rz1 - 0.1))
	for sx in [-1.0, 1.0]:
		var nk := 8
		for k in range(nk):
			var hz := rz0 + 0.3 + k * (rz1 - rz0 - 0.6) / (nk - 1)
			_b(b, eng, Vector3(0.26, 0.24, 0.26), Vector3(sx * 0.42, 2.72, hz), Vector3(0, 0, sx * -38.0))
			_b(b, mt["dark"], Vector3(0.14, 0.05, 0.16), Vector3(sx * 0.5, 2.86, hz), Vector3(0, 0, sx * -38.0))
			_c(b, mt["steel"], 0.04, 0.3, Vector3(sx * 0.62, 2.95, hz), Vector3(0, 0, sx * 50.0), 8)
		_c(b, mt["steel"], 0.07, rz1 - rz0 - 0.4, Vector3(sx * 0.16, 3.05, (rz0 + rz1) * 0.5), Vector3(90, 0, 0), 12)
		_c(b, MU.mat(Color(0.55, 0.42, 0.2), 0.5, 0.6, "fuel_line"), 0.012, rz1 - rz0 - 0.4, Vector3(sx * 0.3, 2.58, (rz0 + rz1) * 0.5), Vector3(90, 0, 0), 6)
	_c(b, mt["steel"], 0.24, 0.55, Vector3(0, 3.25, rz1 - 0.35), Vector3(90, 0, 0), 16)
	_b(b, mt["grille"], Vector3(0.4, 0.03, rz1 - rz0 - 0.1), Vector3(xl + 0.28, DECK + 0.08, (rz0 + rz1) * 0.5))
	# the interior is lit dimly by an engine room lamp (on with the lights breaker)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.92, 0.75)
	lamp.omni_range = 3.5
	lamp.light_energy = 0.0
	lamp.shadow_enabled = false
	m.add_child(lamp)
	lamp.position = Vector3(-0.5, 3.6, (dz0 + dz1) * 0.5)
	v.extra["engine_room_light"] = lamp
	# door panel lines and handles along both sides
	for sx in [-1.0, 1.0]:
		var x: float = sx * (HOOD_HW + 0.004)
		var zz := 6.9
		while zz < z1 - 0.5:
			if not (sx < 0.0 and zz > dz0 - 0.05 and zz < dz1 + 0.05):
				_b(b, MU.mat(Color(0.03, 0.05, 0.11), 0.6, 0.2, "pn_seam"), Vector3(0.006, 1.95, 0.012), Vector3(x, DECK + 1.1, zz))
			if not (sx < 0.0 and zz > dz0 - 0.2 and zz < dz1 + 0.2):
				_b(b, mt["steel"], Vector3(0.03, 0.1, 0.03), Vector3(x + sx * 0.015, 2.45, zz + 0.25))
			zz += 1.25
	# dynamic brake grids behind the cab: raised hatch with the blower grille
	_span(b, dark, Vector3(-0.85, HOOD_TOP - 0.02, z0 + 0.2), Vector3(0.85, HOOD_TOP + 0.16, z0 + 2.3))
	for k in range(12):
		var gz := z0 + 0.32 + k * 0.165
		_b(b, grille, Vector3(1.6, 0.02, 0.05), Vector3(0, HOOD_TOP + 0.17, gz))
	# the grid blower in its ring guard (it spins up when the dynamic brake is set up)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.4
	ring.outer_radius = 0.45
	ring.rings = 24
	ring.ring_segments = 6
	b.mesh("p", grille, ring, Transform3D(Basis(), Vector3(0, HOOD_TOP + 0.2, z0 + 1.25)))
	for k in range(2):
		_b(b, grille, Vector3(0.86, 0.015, 0.02), Vector3(0, HOOD_TOP + 0.23, z0 + 1.25), Vector3(0, 45.0 + k * 90.0, 0))
	var dbf := Node3D.new()
	m.add_child(dbf)
	dbf.position = Vector3(0, HOOD_TOP + 0.19, z0 + 1.25)
	for k in range(5):
		var blade := MU.box(dbf, Vector3(0.36, 0.01, 0.1), Vector3.ZERO, mt["dark"], Vector3(14, k * 72.0, 0))
		blade.position = Basis(Vector3.UP, deg_to_rad(k * 72.0)) * Vector3(0.2, 0, 0)
	MU.cyl(dbf, 0.08, 0.06, Vector3.ZERO, mt["dark"], Vector3.ZERO, 10)
	v.extra["db_fan"] = dbf
	for sx in [-1.0, 1.0]:
		for k in range(6):
			_b(b, grille, Vector3(0.012, 0.05, 1.6), Vector3(sx * (HOOD_HW + 0.006), 3.0 + k * 0.1, z0 + 1.25))
	# exhaust stack over the engine
	_b(b, dark, Vector3(0.62, 0.16, 0.36), Vector3(0, HOOD_TOP + 0.08, 11.6))
	_b(b, MU.mat(Color(0.01, 0.01, 0.01), 0.95, 0.0, "soot"), Vector3(0.5, 0.01, 0.24), Vector3(0, HOOD_TOP + 0.165, 11.6))
	var ex := Node3D.new()
	ex.name = "Exhaust"
	m.add_child(ex)
	ex.position = Vector3(0, HOOD_TOP + 0.2, 11.6)
	v.extra["exhaust"] = ex
	# air intake filters and the inertial filter box ahead of the radiator
	for sx in [-1.0, 1.0]:
		_b(b, grille, Vector3(0.012, 0.7, 1.1), Vector3(sx * (HOOD_HW + 0.006), 3.2, ENG_DOOR_Z0 - 0.8))


## Radiator compartment at the No. 2 end with the side "wings", two big fans
## (they turn with the engine) and the rear platform.
static func _radiator(b: MeshBatch, m: Node3D, v: Vehicle, mt: Dictionary) -> void:
	var blue: Material = mt["blue"]
	var yellow: Material = mt["yellow"]
	var grille: Material = mt["grille"]
	var dark: Material = mt["dark"]
	var wing_y := 2.6
	var top := HOOD_TOP + 0.2
	_span(b, blue, Vector3(-HOOD_HW, DECK, RAD_Z0), Vector3(HOOD_HW, wing_y, RAD_Z1))
	_span(b, blue, Vector3(-FRAME_HW + 0.05, wing_y, RAD_Z0), Vector3(FRAME_HW - 0.05, top, RAD_Z1))
	for sx in [-1.0, 1.0]:
		# sloped underside of the wings
		_b(b, blue, Vector3(0.62, 0.05, RAD_Z1 - RAD_Z0), Vector3(sx * (HOOD_HW + 0.2), wing_y - 0.1, (RAD_Z0 + RAD_Z1) * 0.5), Vector3(0, 0, sx * 28.0))
		# radiator cores behind grilles on the wing sides
		var x: float = sx * (FRAME_HW - 0.04)
		_span(b, MU.mat(Color(0.1, 0.1, 0.1), 0.8, 0.3, "radiator_core"), Vector3(minf(x, x + sx * 0.01), 2.85, RAD_Z0 + 0.1), Vector3(maxf(x, x + sx * 0.01), top - 0.12, RAD_Z1 - 0.1))
		for k in range(14):
			_b(b, grille, Vector3(0.025, top - 3.0, 0.03), Vector3(x + sx * 0.012, (2.85 + top - 0.12) * 0.5, RAD_Z0 + 0.2 + k * 0.155))
	# rear wall painted yellow, red tail markers, and the handbrake mount
	_span(b, yellow, Vector3(-FRAME_HW + 0.05, DECK, RAD_Z1 - 0.02), Vector3(FRAME_HW - 0.05, top, RAD_Z1 + 0.02))
	var tail := MU.lamp(Color(1.0, 0.06, 0.03), 0.0)
	for sx in [-1.0, 1.0]:
		_b(b, MU.mat(Color(0.03, 0.03, 0.03), 0.6, 0.0, "pn_lamp_box"), Vector3(0.2, 0.12, 0.05), Vector3(sx * 1.15, 3.75, RAD_Z1 + 0.03))
		MU.box(m, Vector3(0.08, 0.08, 0.02), Vector3(sx * 1.15, 3.75, RAD_Z1 + 0.06), tail)
	v.extra["rear_tail"] = tail
	# handbrake: wheel above the porch handrail, chain casing down to the bogie
	_c(b, dark, 0.06, 0.12, Vector3(-0.7, HB_Y, RAD_Z1 + 0.06), Vector3(90, 0, 0), 10)
	_b(b, dark, Vector3(0.12, 0.16, 0.08), Vector3(-0.7, HB_Y, RAD_Z1 + 0.04))
	_b(b, dark, Vector3(0.08, HB_Y - 1.2, 0.06), Vector3(-0.7, (HB_Y + 1.2) * 0.5, RAD_Z1 + 0.05))
	# cooling fans on the roof, each in a shroud under a guard
	var fans := []
	for fz in [RAD_Z0 + 0.65, RAD_Z0 + 1.8]:
		var tm := TorusMesh.new()
		tm.inner_radius = 0.66
		tm.outer_radius = 0.74
		tm.rings = 32
		tm.ring_segments = 6
		b.mesh("p", dark, tm, Transform3D(Basis(), Vector3(0, top + 0.02, fz)))
		_c(b, mt["interior"], 0.68, 0.02, Vector3(0, top - 0.01, fz), Vector3.ZERO, 28)
		for k in range(8):
			_b(b, grille, Vector3(1.42, 0.015, 0.025), Vector3(0, top + 0.07, fz - 0.6 + k * 0.17))
		var fan := Node3D.new()
		m.add_child(fan)
		fan.position = Vector3(0, top + 0.01, fz)
		for k in range(6):
			MU.box(fan, Vector3(0.6, 0.012, 0.16), Vector3(0.33, 0, 0), dark, Vector3(12, k * 60.0, 0)).position = Basis(Vector3.UP, deg_to_rad(k * 60.0)) * Vector3(0.34, 0, 0)
		MU.cyl(fan, 0.12, 0.06, Vector3.ZERO, dark, Vector3.ZERO, 12)
		fans.append(fan)
	v.extra["fans"] = fans


## Fuel tank (13,500 L coal-service tank), air reservoirs, sand boxes.
static func _underframe(b: MeshBatch, mt: Dictionary) -> void:
	var black: Material = mt["black"]
	var rings := []
	for z in [6.5, 6.75, 15.25, 15.5]:
		var shrink := 0.06 if (z == 6.5 or z == 15.5) else 0.0
		rings.append(MU.rounded_ring(1.25 - shrink, 0.44 + shrink, 1.16, 0.22, z, 4))
	var lo := MU.loft(rings, black, true, true)
	b.mesh("p", black, lo.mesh, Transform3D())
	lo.free()
	for sx in [-1.0, 1.0]:
		# fuel gauges, filler and the in-line refuelling fitting
		_b(b, mt["white"], Vector3(0.012, 0.42, 0.1), Vector3(sx * 1.256, 0.8, 9.0))
		_b(b, mt["white"], Vector3(0.012, 0.42, 0.1), Vector3(sx * 1.256, 0.8, 13.0))
		_c(b, mt["dark"], 0.07, 0.08, Vector3(sx * 1.25, 1.0, 11.0), Vector3(0, 0, 90), 12)
		# main reservoirs above the tank ends
		_c(b, mt["dark"], 0.2, 2.6, Vector3(sx * 0.7, 1.0, 17.0 if sx < 0 else 5.0), Vector3(90, 0, 0), 14)


static func _handrails(b: MeshBatch, mt: Dictionary) -> void:
	var rail: Material = mt["rail"]
	var top := DECK + 1.0
	for sx in [-1.0, 1.0]:
		var x: float = sx * (FRAME_HW - 0.04)
		# along the walkway from the cab door to the radiator
		b.tube("p", rail, Vector3(x, top, CAB_Z1 + 0.15), Vector3(x, top, RAD_Z0 - 0.2), 0.02, 6)
		b.tube("p", rail, Vector3(x, DECK + 0.5, CAB_Z1 + 0.15), Vector3(x, DECK + 0.5, RAD_Z0 - 0.2), 0.016, 6)
		var z := CAB_Z1 + 0.15
		while z <= RAD_Z0 - 0.1:
			b.tube("p", rail, Vector3(x, DECK, z), Vector3(x, top, z), 0.02, 6)
			z += 1.6
		# front and rear porches
		for pz in [[0.42, NOSE_Z], [RAD_Z1, 21.58]]:
			b.tube("p", rail, Vector3(x, top, pz[0]), Vector3(x, top, pz[1]), 0.02, 6)
			b.tube("p", rail, Vector3(x, DECK, pz[0]), Vector3(x, top, pz[0]), 0.02, 6)
		b.tube("p", rail, Vector3(x, top, 0.42), Vector3(sx * 0.55, top, 0.42), 0.02, 6)
		b.tube("p", rail, Vector3(sx * 0.55, DECK, 0.42), Vector3(sx * 0.55, top, 0.42), 0.02, 6)
		b.tube("p", rail, Vector3(x, top, 21.58), Vector3(sx * 0.55, top, 21.58), 0.02, 6)
		b.tube("p", rail, Vector3(sx * 0.55, DECK, 21.58), Vector3(sx * 0.55, top, 21.58), 0.02, 6)


## Three-axle fixed-frame pedestal bogie with AC traction motors.
static func _bogie(v: Vehicle, m: Node3D, mt: Dictionary, bz: float) -> void:
	var bn := Node3D.new()
	m.add_child(bn)
	bn.position = Vector3(0, 0, bz)
	var b := MeshBatch.new()
	var dark: Material = mt["dark"]
	var black: Material = mt["black"]
	var spring := MU.mat(Color(0.75, 0.6, 0.08), 0.6, 0.0, "pn_spring")
	for sx in [-1.0, 1.0]:
		var x: float = sx * 1.02
		_b(b, dark, Vector3(0.18, 0.36, 4.7), Vector3(x, 0.92, 0))
		_b(b, dark, Vector3(0.18, 0.2, 4.9), Vector3(x, 1.12, 0))
		for az in [-2.0, 0.0, 2.0]:
			_b(b, black, Vector3(0.26, 0.3, 0.36), Vector3(x * 1.03, 0.51, az))          # axlebox
			_c(b, spring, 0.09, 0.26, Vector3(x * 1.03, 0.8, az - 0.13), Vector3.ZERO, 8)
			_c(b, spring, 0.09, 0.26, Vector3(x * 1.03, 0.8, az + 0.13), Vector3.ZERO, 8)
			# brake cylinder and shoe
			_c(b, dark, 0.07, 0.22, Vector3(x * 0.92, 0.85, az + 0.62), Vector3(90, 0, 0), 8)
			_b(b, black, Vector3(0.1, 0.3, 0.08), Vector3(x * 0.72, 0.52, az + 0.53))
		# sand pipes to the leading wheels
		b.tube("p", black, Vector3(x, 1.0, -2.3), Vector3(x * 0.72, 0.15, -2.45), 0.015, 5)
	# transoms and the AC traction motors between the axles
	for az in [-1.0, 1.0]:
		_b(b, dark, Vector3(2.0, 0.22, 0.3), Vector3(0, 0.95, az * 1.0))
	for az in [-2.0, 0.0, 2.0]:
		_c(b, black, 0.38, 1.2, Vector3(0, 0.52, az + 0.62 if az < 1.0 else az - 0.62), Vector3(0, 0, 90), 16)
	var bm := b.commit(bn, "Bogie")
	bm.visibility_range_end = 900.0
	var steel: Material = mt["steel"]
	for az in [-2.0, 0.0, 2.0]:
		var w := Node3D.new()
		bn.add_child(w)
		w.position = Vector3(0, 0.508, az)
		var wb := MeshBatch.new()
		for sx in [-1.0, 1.0]:
			_c(wb, steel, 0.508, 0.14, Vector3(sx * 0.71, 0, 0), Vector3(0, 0, 90), 22)
			_c(wb, dark, 0.36, 0.15, Vector3(sx * 0.71, 0, 0), Vector3(0, 0, 90), 16)
		_c(wb, steel, 0.09, 1.55, Vector3.ZERO, Vector3(0, 0, 90), 8)
		wb.commit(w, "Wheelset")
		v.add_wheel(w, 0.508)


# ============================================================ coal hopper
static var _wagon_meshes := {}


## Aluminium bottom-discharge coal hopper; loaded with a heaped coal top.
## The last wagon carries the end-of-train marker (flashing red).
static func coal_wagon(loaded: bool, idx: int, last: bool) -> Vehicle:
	var v := Vehicle.new()
	v.kind = "coal"
	v.name = "Wagon_%02d" % idx
	v.vlength = WAGON_L
	v.pivot_front = 2.6
	v.pivot_rear = WAGON_L - 2.6
	v.mass_tare = 23000.0
	v.mass_load = 97000.0 if loaded else 0.0
	v.axles = 4
	v.brake_mass_ratio = 0.1
	var m := v.make_model_root()
	var body := MeshInstance3D.new()
	body.mesh = _wagon_mesh("body")
	body.name = "Body"
	m.add_child(body)
	body.visibility_range_end = 3200.0
	var inside := MeshInstance3D.new()
	inside.mesh = _wagon_mesh("coal" if loaded else "empty")
	inside.name = "Load"
	m.add_child(inside)
	inside.visibility_range_end = 2400.0
	inside.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for bz in [v.pivot_front, v.pivot_rear]:
		var bn := Node3D.new()
		m.add_child(bn)
		bn.position = Vector3(0, 0, bz)
		var bmi := MeshInstance3D.new()
		bmi.mesh = _wagon_mesh("bogie")
		bmi.visibility_range_end = 500.0
		bn.add_child(bmi)
		for az in [-0.915, 0.915]:
			var w := MeshInstance3D.new()
			w.mesh = _wagon_mesh("wheels")
			w.visibility_range_end = 350.0
			bn.add_child(w)
			w.position = Vector3(0, 0.42, az)
			v.add_wheel(w, 0.42)
	if last:
		# end-of-train marker on the rear coupler
		var eot := MU.lamp(Color(1.0, 0.06, 0.03), 0.0)
		MU.box(m, Vector3(0.3, 0.32, 0.22), Vector3(0.0, 1.32, WAGON_L - 0.15), MU.mat(Color(0.85, 0.7, 0.05), 0.5, 0.0, "eot_case"))
		MU.cyl(m, 0.06, 0.03, Vector3(0, 1.58, WAGON_L - 0.12), eot, Vector3(90, 0, 0), 12)
		v.tail_lamps.append(eot)
	v.finish_model()
	return v


static func _wagon_mesh(key: String) -> Mesh:
	if _wagon_meshes.has(key):
		return _wagon_meshes[key]
	var b := MeshBatch.new()
	match key:
		"body":
			_wagon_body(b)
		"coal":
			_wagon_coal(b, true)
		"empty":
			_wagon_coal(b, false)
		"bogie":
			_wagon_bogie(b)
		"wheels":
			var steel := TX.metal(Color(0.55, 0.53, 0.52), 0.35, false, 1.0, "wagon_wheel")
			var rust := TX.pbr("rust_albedo", "", Color(0.7, 0.55, 0.45), 0.85, 0.2, Vector3.ONE * 2.0, false, 1.0, "wagon_rust")
			for sx in [-1.0, 1.0]:
				_c(b, steel, 0.42, 0.13, Vector3(sx * 0.71, 0, 0), Vector3(0, 0, 90), 18)
				_c(b, rust, 0.3, 0.14, Vector3(sx * 0.71, 0, 0), Vector3(0, 0, 90), 14)
			_c(b, rust, 0.08, 1.55, Vector3.ZERO, Vector3(0, 0, 90), 8)
	var mesh := b.commit_mesh()
	_wagon_meshes[key] = mesh
	return mesh


static func _wagon_body(b: MeshBatch) -> void:
	# aluminium, dulled and streaked with coal dust
	var alu := TX.painted(Color(0.6, 0.6, 0.59), 0.5, 0.55, "grime", 0.45, 0.0, "wagon_alu")
	var dirty := TX.painted(Color(0.42, 0.42, 0.42), 0.6, 0.4, "grime", 0.5, 0.0, "wagon_dirty")
	var dark := TX.painted(Color(0.1, 0.1, 0.1), 0.6, 0.3, "grime", 0.5, 0.0, "wagon_dark")
	var blue := TX.painted(pn_blue, 0.4, 0.1, "grime", 0.5, 0.0, "wagon_blue")
	var yellow := TX.painted(pn_yellow, 0.45, 0.05, "grime", 0.5, 0.0, "wagon_yellow")
	var L := WAGON_L
	var z0 := 0.62
	var z1 := L - 0.62
	var hw := 1.45
	var top := 3.9
	var sill := 1.22
	# side walls with extruded stakes and the top chord
	for sx in [-1.0, 1.0]:
		var x: float = sx * hw
		_span(b, alu, Vector3(minf(x, x - sx * 0.03), sill, z0), Vector3(maxf(x, x - sx * 0.03), top - 0.06, z1))
		b.tube("p", alu, Vector3(x, top - 0.05, z0), Vector3(x, top - 0.05, z1), 0.07, 10)
		_span(b, dirty, Vector3(minf(x, x + sx * 0.05), sill - 0.06, z0 - 0.1), Vector3(maxf(x, x + sx * 0.05), sill + 0.12, z1 + 0.1))
		var z := z0 + 0.45
		while z < z1 - 0.3:
			_b(b, alu, Vector3(0.06, top - sill - 0.15, 0.09), Vector3(x + sx * 0.03, (sill + top) * 0.5 - 0.05, z))
			z += 1.06
		# owner's mark and wagon number panel
		_b(b, blue, Vector3(0.01, 0.6, 0.9), Vector3(x + sx * 0.065, 3.1, 3.4))
		_b(b, dark, Vector3(0.01, 0.22, 1.4), Vector3(x + sx * 0.065, 1.55, L * 0.5))
	# end walls, sloping into the hoppers
	for e in [[z0, 1.0], [z1, -1.0]]:
		var ez: float = e[0]
		var d: float = e[1]
		_b(b, alu, Vector3(hw * 2.0, top - 2.6, 0.04), Vector3(0, (top + 2.6) * 0.5 - 0.03, ez))
		_b(b, alu, Vector3(hw * 2.0 - 0.06, 0.04, 2.6), Vector3(0, 1.95, ez + d * 1.05), Vector3(d * 36.0, 0, 0))
		b.tube("p", alu, Vector3(-hw, top - 0.05, ez), Vector3(hw, top - 0.05, ez), 0.07, 10)
		# end platform, ladder and the handbrake wheel at the "B" end
		_span(b, dark, Vector3(-hw + 0.1, 1.1, ez - d * 0.55), Vector3(hw - 0.1, 1.16, ez))
		for k in range(4):
			_b(b, yellow, Vector3(0.5, 0.025, 0.03), Vector3(-1.1, 1.5 + k * 0.45, ez - d * 0.04))
	var tm := TorusMesh.new()
	tm.inner_radius = 0.2
	tm.outer_radius = 0.235
	b.mesh("p", dark, tm, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.75, 2.55, z0 - 0.06)))
	# hopper chutes and the bottom discharge doors between the bogies
	for hz in [[4.1, 7.9], [8.35, 12.15]]:
		var a: float = hz[0]
		var c: float = hz[1]
		_b(b, alu, Vector3(hw * 2.0 - 0.1, 0.04, (c - a) * 0.62), Vector3(0, 0.95, a + (c - a) * 0.25), Vector3(-38, 0, 0))
		_b(b, alu, Vector3(hw * 2.0 - 0.1, 0.04, (c - a) * 0.62), Vector3(0, 0.95, c - (c - a) * 0.25), Vector3(38, 0, 0))
		_span(b, dirty, Vector3(-hw + 0.2, 0.52, (a + c) * 0.5 - 0.6), Vector3(hw - 0.2, 0.62, (a + c) * 0.5 + 0.6))
		for sx in [-1.0, 1.0]:
			_b(b, alu, Vector3(0.04, 0.7, c - a), Vector3(sx * (hw - 0.08), 0.92, (a + c) * 0.5))
	# centre sill, bolsters, couplers, air brake reservoirs and valve
	_span(b, dark, Vector3(-0.22, 0.75, 0.25), Vector3(0.22, 1.18, L - 0.25))
	for bz in [2.6, L - 2.6]:
		_span(b, dark, Vector3(-hw + 0.05, 0.85, bz - 0.25), Vector3(hw - 0.05, 1.22, bz + 0.25))
	var mt := mats()
	_coupler(b, mt, 0.0, -1.0)
	_coupler(b, mt, L, 1.0)
	_c(b, dark, 0.22, 1.4, Vector3(0.75, 0.95, 13.3), Vector3(90, 0, 0), 12)
	_b(b, dark, Vector3(0.4, 0.35, 0.35), Vector3(0.75, 0.95, 12.3))
	# brake pipe and hoses at each end
	b.tube("p", dark, Vector3(0.35, 0.95, 0.3), Vector3(0.35, 0.95, L - 0.3), 0.025, 6)
	for e in [[0.05, 0.3], [L - 0.05, L - 0.3]]:
		b.tube("p", mt["rubber"], Vector3(0.35, 0.95, e[1]), Vector3(0.3, 0.72, e[0]), 0.03, 6)


static func _wagon_coal(b: MeshBatch, loaded: bool) -> void:
	if not loaded:
		# looking into an empty wagon: coal-dusted sloping floors
		var floor_m := TX.pbr("coal_albedo", "coal_normal", Color(0.45, 0.45, 0.45), 0.85, 0.0, Vector3.ONE * 0.8, false, 0.6, "wagon_dust")
		for hz in [[0.7, 8.0], [8.2, WAGON_L - 0.7]]:
			_span(b, floor_m, Vector3(-1.4, 1.35, hz[0]), Vector3(1.4, 1.42, hz[1]))
		return
	var coal := TX.pbr("coal_albedo", "coal_normal", Color(0.85, 0.85, 0.85), 0.62, 0.0, Vector3.ONE * 1.2, false, 1.3, "wagon_coal")
	# heaped load: a smooth ridge along the wagon, tapering at the ends
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	var nx := 10
	var nz := 24
	var z0 := 0.7
	var z1 := WAGON_L - 0.7
	var pts := []
	for j in range(nz + 1):
		var row := []
		var z := lerpf(z0, z1, float(j) / nz)
		var end_f := clampf(minf(z - z0, z1 - z) / 1.6, 0.0, 1.0)
		end_f = end_f * end_f * (3.0 - 2.0 * end_f)
		for i in range(nx + 1):
			var x := lerpf(-1.42, 1.42, float(i) / nx)
			var ridge := 1.0 - pow(absf(x) / 1.42, 1.6)
			var bumps := sin(z * 3.1 + x * 5.0) * 0.025 + sin(z * 7.3 - x * 3.0) * 0.015
			var y := 3.84 + (0.42 * ridge + bumps) * end_f
			row.append(Vector3(x, y, z))
		pts.append(row)
	for j in range(nz):
		for i in range(nx):
			var a: Vector3 = pts[j][i]
			var c: Vector3 = pts[j][i + 1]
			var d: Vector3 = pts[j + 1][i]
			var e: Vector3 = pts[j + 1][i + 1]
			# faces up: (b-a) x (c-a) must point down (Godot clockwise front faces)
			st.add_vertex(a); st.add_vertex(c); st.add_vertex(e)
			st.add_vertex(a); st.add_vertex(e); st.add_vertex(d)
	st.generate_normals()
	b.mesh("coal", coal, st.commit(), Transform3D())


static func _wagon_bogie(b: MeshBatch) -> void:
	var dark := TX.painted(Color(0.09, 0.085, 0.08), 0.65, 0.3, "grime", 0.6, 0.0, "wagon_bogie")
	var spring := MU.mat(Color(0.3, 0.3, 0.3), 0.6, 0.3, "wagon_spring")
	for sx in [-1.0, 1.0]:
		var x: float = sx * 0.98
		# cast side frame: bottom chord, top chord and the window for the springs
		_b(b, dark, Vector3(0.14, 0.12, 2.5), Vector3(x, 0.42, 0))
		_b(b, dark, Vector3(0.14, 0.12, 1.4), Vector3(x, 0.78, 0))
		for e in [-1.0, 1.0]:
			_b(b, dark, Vector3(0.14, 0.45, 0.14), Vector3(x, 0.6, e * 0.62), Vector3(e * -25.0, 0, 0))
			_b(b, dark, Vector3(0.2, 0.22, 0.28), Vector3(x * 1.02, 0.43, e * 0.915))      # bearing adapter
		for k in range(3):
			_c(b, spring, 0.06, 0.24, Vector3(x, 0.58, -0.16 + k * 0.16), Vector3.ZERO, 8)
	_b(b, dark, Vector3(2.0, 0.25, 0.36), Vector3(0, 0.72, 0))            # bolster
	for e in [-1.0, 1.0]:
		_b(b, dark, Vector3(1.8, 0.08, 0.08), Vector3(0, 0.45, e * 0.55))   # brake beams
