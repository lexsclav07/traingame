class_name VehicleModels
## Procedural models of every vehicle. Dimensions follow the real trains where
## they are published (D set: 20.4 m cars, 3.03 m wide, 4.40 m tall; A4: 6 ft 8 in
## drivers, 3 ft 2 in bogie wheels, 71 ft over loco and tender).
## Static parts of each vehicle are merged with MeshBatch (one draw per
## material); doors, wheels, rods and the pantograph stay separate nodes
## because they move.


# ----------------------------------------------------------------- helpers
static func _rb(rot: Vector3) -> Basis:
	return Basis.from_euler(rot * (PI / 180.0))


static func _b(b: MeshBatch, mat: Material, size: Vector3, pos: Vector3, rot := Vector3.ZERO) -> void:
	b.box("p", mat, size, Transform3D(_rb(rot), pos))


static func _c(b: MeshBatch, mat: Material, r: float, h: float, pos: Vector3, rot := Vector3.ZERO, segs := 12, r_top := -1.0) -> void:
	b.cyl("p", mat, Transform3D(_rb(rot), pos), r if r_top < 0.0 else r_top, r, h, segs)


static func _t(b: MeshBatch, mat: Material, r_in: float, r_out: float, pos: Vector3, rot := Vector3.ZERO, rings := 24, segs := 8) -> void:
	var tm := TorusMesh.new()
	tm.inner_radius = r_in
	tm.outer_radius = r_out
	tm.rings = rings
	tm.ring_segments = segs
	b.mesh("p", mat, tm, Transform3D(_rb(rot), pos))


static func _l(b: MeshBatch, mat: Material, rings: Array, cap_start := true, cap_end := true) -> void:
	var mi := MU.loft(rings, mat, cap_start, cap_end)
	b.mesh("p", mat, mi.mesh, Transform3D())
	mi.free()


static func _glass(col: Color, key: String) -> StandardMaterial3D:
	var m := MU.mat(col, 0.04, 0.0, key)
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	return m


# =================================================================== Mariyung
static func mariyung_car(code: String, cab_front: bool, motor: bool, pan: bool, reversed: bool) -> Vehicle:
	var v := Vehicle.new()
	v.kind = "mariyung"
	v.name = code
	v.vlength = 20.43 if cab_front else 20.34
	var L := v.vlength
	v.pivot_front = 3.25
	v.pivot_rear = L - 3.25
	v.mass_tare = 54000.0 if motor else 46000.0
	v.axles = 4
	v.motored_axles = 4 if motor else 0
	v.brake_mass_ratio = 1.15
	v.reversed = reversed
	var m := v.make_model_root()
	var b := MeshBatch.new()
	var white := TX.painted(Color(0.9, 0.905, 0.91), 0.26, 0.1, "paint_wear", 0.6, 0.7, "nif_body")
	var black := TX.plastic(Color(0.035, 0.035, 0.04), 0.4, 4.0, "nif_black")
	var win := _glass(Color(0.025, 0.03, 0.035), "nif_win")
	var orange := TX.painted(Color(0.95, 0.45, 0.08), 0.3, 0.05, "grime", 0.5, 0.6, "nif_orange")
	var grey := TX.painted(Color(0.16, 0.165, 0.17), 0.65, 0.4, "grime", 0.6, 0.0, "nif_grey")
	var roof := TX.painted(Color(0.52, 0.54, 0.56), 0.55, 0.35, "grime", 0.3, 0.0, "nif_roof")
	var frame := MU.mat(Color(0.05, 0.055, 0.06), 0.45, 0.2, "nif_mullion")
	var hw := 1.515
	var body_start := 2.6 if cab_front else 0.3

	# ---- main shell
	var rings := []
	for z in [body_start, L - 0.3]:
		rings.append(MU.rounded_ring(hw, 1.05, 4.4, 0.55, z, 6))
	_l(b, white, rings, not cab_front, true)
	# lower-deck well between the vestibules, with the orange-lined skirt
	_b(b, white, Vector3(hw * 2.0, 0.66, L - 9.6), Vector3(0, 0.74, L * 0.5))
	_b(b, orange, Vector3(hw * 2.0 + 0.01, 0.1, L - 9.6), Vector3(0, 0.46, L * 0.5))
	_b(b, grey, Vector3(hw * 2.0 - 0.3, 0.06, L - 9.7), Vector3(0, 0.39, L * 0.5))
	# window bands (upper & lower deck between doors, mid level over the bogies)
	for sx in [-1.0, 1.0]:
		var x: float = sx * (hw + 0.004)
		for band in [[3.42, 0.8], [1.62, 0.74]]:
			var by: float = band[0]
			var bh: float = band[1]
			_b(b, win, Vector3(0.01, bh, L - 10.4), Vector3(x, by, L * 0.5))
			_b(b, frame, Vector3(0.02, 0.05, L - 10.3), Vector3(x * 1.001, by + bh * 0.5 + 0.02, L * 0.5))
			_b(b, frame, Vector3(0.02, 0.05, L - 10.3), Vector3(x * 1.001, by - bh * 0.5 - 0.02, L * 0.5))
			var pz := 5.3
			while pz < L - 5.2:
				_b(b, frame, Vector3(0.02, bh, 0.1), Vector3(x * 1.001, by, pz))
				pz += 1.32
		for wz in ([1.6] if not cab_front else []) + [L - 1.6]:
			_b(b, win, Vector3(0.01, 0.75, 1.9), Vector3(x, 2.65, wz))
			_b(b, frame, Vector3(0.006, 0.85, 2.0), Vector3(x * 0.996, 2.65, wz))
		# roof gutter and cant rail
		_b(b, roof, Vector3(0.03, 0.08, L - 0.8), Vector3(x * 1.002, 4.05, L * 0.5))
		# passenger information display beside each vestibule
		for dz in [4.15, L - 4.15]:
			for off in [-1.12, 1.12]:
				_b(b, black, Vector3(0.02, 0.16, 0.42), Vector3(x * 1.002, 3.32, dz + off))
	# ---- doors: two pairs per side, orange plug doors at the vestibules
	for dz in [4.15, L - 4.15]:
		for sx in [-1.0, 1.0]:
			# door frame seal and the open/close buttons on the body
			_b(b, black, Vector3(0.02, 2.06, 1.72), Vector3(sx * (hw + 0.006), 2.12, dz))
			_c(b, MU.mat(Color(0.2, 0.75, 0.3), 0.4, 0.0, "door_btn"), 0.035, 0.02, Vector3(sx * (hw + 0.02), 2.0, dz + 0.98), Vector3(0, 0, 90), 10)
			for leaf in [-1.0, 1.0]:
				var d := Node3D.new()
				m.add_child(d)
				var closed := Vector3(sx * (hw + 0.02), 2.12, dz + leaf * 0.41)
				d.position = closed
				MU.box(d, Vector3(0.04, 1.98, 0.8), Vector3.ZERO, orange)
				MU.box(d, Vector3(0.045, 0.95, 0.5), Vector3(0, 0.33, 0), win)
				MU.box(d, Vector3(0.046, 1.0, 0.04), Vector3(0, 0.33, -leaf * 0.27), black)
				MU.box(d, Vector3(0.05, 1.98, 0.02), Vector3(0, 0, -leaf * 0.395), black)
				var open_vec := Vector3(sx * 0.07, 0, leaf * 0.78)
				if sx < 0:
					v.doors_left.append([d, closed, open_vec])
				else:
					v.doors_right.append([d, closed, open_vec])
	# ---- cab nose / gangway
	if cab_front:
		_mariyung_nose(v, m, b, white, black, orange, win)
	else:
		_gangway(b, black, grey, 0.15, 1.0)
	_gangway(b, black, grey, L - 0.15, -1.0)
	# ---- under-frame equipment over the bogie ends & bogies
	for bz in [v.pivot_front, v.pivot_rear]:
		_emu_bogie(v, m, bz, motor, grey)
	for ez in [1.5 if not cab_front else 2.9, L - 1.5]:
		_b(b, grey, Vector3(2.3, 0.42, 1.5), Vector3(0, 0.84, ez))
		_b(b, black, Vector3(2.32, 0.06, 1.52), Vector3(0, 1.06, ez))
	# ---- roof: air-conditioning units with grilles, roof walk strip
	_b(b, roof, Vector3(2.3, 0.06, L - 1.0), Vector3(0, 4.39, L * 0.5))
	for az in [2.8, L - 2.8]:
		if pan and absf(az - (L - 3.6)) < 2.0:
			continue
		_b(b, roof, Vector3(1.9, 0.22, 2.4), Vector3(0, 4.5, az))
		for k in range(7):
			_b(b, frame, Vector3(1.5, 0.012, 0.06), Vector3(0, 4.615, az - 0.9 + k * 0.3))
		_c(b, frame, 0.28, 0.03, Vector3(0, 4.62, az + (0.8 if az < L * 0.5 else -0.8)), Vector3.ZERO, 16)
	if pan:
		_pantograph(v, m, b, L - 3.6, roof)
	b.commit(m, "Body")
	v.finish_model()
	return v


static func _gangway(b: MeshBatch, black: Material, grey: Material, z: float, dir: float) -> void:
	# rubber bellows with folds and a steel end frame
	for k in range(5):
		_b(b, black, Vector3(1.24 - (k % 2) * 0.06, 2.36 - (k % 2) * 0.06, 0.055), Vector3(0, 2.25, z - dir * (0.12 - k * 0.055)))
	_b(b, grey, Vector3(1.32, 2.44, 0.04), Vector3(0, 2.25, z + dir * 0.13))


static func _mariyung_nose(v: Vehicle, m: Node3D, b: MeshBatch, white: Material, black: Material, orange: Material, win: Material) -> void:
	# stations: [z, bottom, top, half-width, corner radius]
	var st := [[0.15, 0.62, 2.15, 1.32, 0.35], [0.55, 0.6, 3.0, 1.44, 0.5], [1.15, 0.62, 3.78, 1.5, 0.58],
		[1.9, 0.75, 4.28, 1.515, 0.58], [2.6, 1.05, 4.4, 1.515, 0.55]]
	var rings := []
	for s in st:
		rings.append(MU.rounded_ring(s[3], s[1], s[2], s[4], s[0], 6))
	var nose := MU.loft(rings, white, true, false)
	nose.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	nose.name = "Nose"
	m.add_child(nose)
	# black windscreen mask (outside only; the interactive cab draws the inside)
	var mask_rings := []
	for s in [[0.56, 2.25, 3.02, 1.38], [1.2, 2.25, 3.82, 1.44], [1.62, 2.25, 4.1, 1.45]]:
		var r := PackedVector3Array()
		r.append(Vector3(-s[3], s[1], s[0]))
		r.append(Vector3(s[3], s[1], s[0]))
		r.append(Vector3(s[3], s[2], s[0]))
		r.append(Vector3(-s[3], s[2], s[0]))
		mask_rings.append(r)
	var mask := MU.loft(mask_rings, MU.glass(Color(0.02, 0.03, 0.04, 0.55)), false, false)
	mask.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mask.position = Vector3(0, 0, -0.03)
	mask.scale = Vector3(1.012, 1, 1)
	m.add_child(mask)
	# destination display behind the top of the windscreen
	var dd := Node3D.new()
	m.add_child(dd)
	dd.position = Vector3(0, 3.93, 1.5)
	dd.rotation_degrees = Vector3(-29.7, 180, 0)
	MU.box(dd, Vector3(1.3, 0.2, 0.02), Vector3(0, 0, -0.012), MU.mat(Color(0.01, 0.01, 0.01), 0.6))
	var dest := MU.label(dd, "CENTRAL", Vector3(0, 0, 0.0), 0.0036, Color(1.0, 0.62, 0.15), Vector3.ZERO, 64)
	dest.name = "Destination"
	# skirt, coupler and the orange band at the front
	_b(b, orange, Vector3(2.7, 0.22, 0.4), Vector3(0, 0.95, 0.25))
	_b(b, black, Vector3(2.1, 0.38, 0.3), Vector3(0, 0.62, 0.12))
	_b(b, black, Vector3(1.4, 0.12, 0.08), Vector3(0, 0.4, 0.05))
	_c(b, black, 0.11, 0.6, Vector3(0, 0.98, 0.15), Vector3(90, 0, 0), 12)
	_b(b, black, Vector3(0.42, 0.36, 0.22), Vector3(0, 0.98, -0.12))
	_b(b, MU.mat(Color(0.4, 0.4, 0.42), 0.35, 0.8, "coupler_face"), Vector3(0.38, 0.3, 0.02), Vector3(0, 0.98, -0.235))
	# light clusters: black housing with headlight, marker (white) and tail (red)
	for sx in [-1.0, 1.0]:
		_b(b, black, Vector3(0.6, 0.42, 0.08), Vector3(sx * 0.88, 1.58, 0.4), Vector3(0, -sx * 8.0, 0))
		var hl := MU.lamp(Color(1.0, 0.96, 0.85), 0.0)
		hl.albedo_color = Color(0.7, 0.72, 0.75)
		var hm := MU.cyl(m, 0.085, 0.04, Vector3(sx * 1.02, 1.5, 0.37), hl, Vector3(90, 0, 0), 16)
		hm.name = "HeadLamp"
		MU.cyl(m, 0.085, 0.04, Vector3(sx * 0.8, 1.5, 0.37), hl, Vector3(90, 0, 0), 16)
		v.head_lamps.append(hl)
		var mk := MU.lamp(Color(1.0, 1.0, 0.95), 0.0)
		MU.box(m, Vector3(0.14, 0.09, 0.03), Vector3(sx * 1.02, 1.7, 0.375), mk)
		v.marker_lamps.append(mk)
		var tl := MU.lamp(Color(1.0, 0.05, 0.03), 0.0)
		MU.box(m, Vector3(0.14, 0.09, 0.03), Vector3(sx * 0.8, 1.7, 0.375), tl)
		v.tail_lamps.append(tl)
		# grab handle and step at the cab door
		_c(b, MU.mat(Color(0.7, 0.7, 0.72), 0.3, 0.9, "handrail"), 0.016, 0.9, Vector3(sx * 1.53, 2.0, 2.45), Vector3.ZERO, 8)
		_b(b, black, Vector3(0.12, 0.04, 0.5), Vector3(sx * 1.48, 0.62, 2.4))
	var spot := SpotLight3D.new()
	spot.light_color = Color(1.0, 0.95, 0.85)
	spot.spot_range = 320.0
	spot.spot_angle = 14.0
	spot.light_energy = 0.0
	spot.shadow_enabled = false
	m.add_child(spot)
	spot.position = Vector3(0, 1.5, -0.2)
	spot.rotation_degrees = Vector3(-1.5, 0, 0)
	v.head_lights.append(spot)
	var cab := Node3D.new()
	cab.name = "CabRoot"
	m.add_child(cab)
	v.cab_root = cab


static func _emu_bogie(v: Vehicle, m: Node3D, bz: float, motor: bool, grey: Material) -> void:
	var bn := Node3D.new()
	m.add_child(bn)
	bn.position = Vector3(0, 0, bz)
	var b := MeshBatch.new()
	var steel := TX.metal(Color(0.5, 0.5, 0.52), 0.35, false, 1.0, "wheel_steel")
	var dark := TX.painted(Color(0.08, 0.08, 0.085), 0.7, 0.2, "grime", 0.8, 0.0, "bogie_dark")
	var yellow := MU.mat(Color(0.75, 0.6, 0.1), 0.6, 0.0, "spring_yellow")
	# H-frame: two side beams dipped in the middle, transom
	_b(b, grey, Vector3(2.0, 0.26, 0.5), Vector3(0, 0.7, 0))
	for sx in [-1.0, 1.0]:
		var x: float = sx * 1.0
		_b(b, grey, Vector3(0.2, 0.3, 1.2), Vector3(x, 0.62, 0))
		for ez in [-1.0, 1.0]:
			_b(b, grey, Vector3(0.2, 0.24, 0.9), Vector3(x, 0.74, ez * 1.05), Vector3(ez * 8.0, 0, 0))
			_b(b, grey, Vector3(0.18, 0.18, 0.3), Vector3(x, 0.66, ez * 1.65))
			# axlebox with primary coil springs
			_b(b, dark, Vector3(0.24, 0.24, 0.3), Vector3(x * 1.02, 0.43, ez * 1.25))
			_c(b, yellow, 0.07, 0.16, Vector3(x * 1.02, 0.62, ez * 1.25 - 0.12), Vector3.ZERO, 8)
			_c(b, yellow, 0.07, 0.16, Vector3(x * 1.02, 0.62, ez * 1.25 + 0.12), Vector3.ZERO, 8)
		# secondary air springs and yaw dampers
		_c(b, dark, 0.2, 0.22, Vector3(x * 0.98, 0.98, 0), Vector3.ZERO, 14)
		_c(b, MU.mat(Color(0.2, 0.2, 0.22), 0.5, 0.6, "damper"), 0.04, 0.6, Vector3(x * 1.08, 0.82, 0.55), Vector3(90, 0, 0), 8)
	b.commit(bn, "Bogie")
	for az in [-1.25, 1.25]:
		var w := Node3D.new()
		bn.add_child(w)
		w.position = Vector3(0, 0.43, az)
		var wb := MeshBatch.new()
		for sx in [-1.0, 1.0]:
			_c(wb, steel, 0.43, 0.13, Vector3(sx * 0.72, 0, 0), Vector3(0, 0, 90), 20)
			_c(wb, dark, 0.3, 0.15, Vector3(sx * 0.72, 0, 0), Vector3(0, 0, 90), 16)
			# brake disc on the inside of the wheel
			_c(wb, MU.mat(Color(0.35, 0.33, 0.32), 0.45, 0.8, "disc"), 0.3, 0.05, Vector3(sx * 0.52, 0, 0), Vector3(0, 0, 90), 16)
		_c(wb, steel, 0.08, 1.6, Vector3.ZERO, Vector3(0, 0, 90), 8)
		wb.commit(w, "Wheelset")
		if motor:
			MU.box(bn, Vector3(0.8, 0.45, 0.45), Vector3(0, 0.48, az - 0.45 * signf(az)), grey)
		v.add_wheel(w, 0.43)


static func _pantograph(v: Vehicle, m: Node3D, b: MeshBatch, pz: float, roof: Material) -> void:
	var p := Node3D.new()
	p.name = "Pantograph"
	m.add_child(p)
	p.position = Vector3(0, 4.42, pz)
	var frame := TX.metal(Color(0.42, 0.42, 0.44), 0.45, false, 1.0, "pan_frame")
	var ins := MU.mat(Color(0.55, 0.15, 0.1), 0.4, 0.0, "pan_insulator")
	MU.box(p, Vector3(1.4, 0.06, 1.8), Vector3(0, 0.12, 0), frame)
	for sx in [-0.6, 0.6]:
		for sz in [-0.8, 0.8]:
			MU.cyl(p, 0.05, 0.14, Vector3(sx, 0.05, sz), ins, Vector3.ZERO, 8)
			for k in range(3):
				MU.cyl(p, 0.075, 0.015, Vector3(sx, 0.02 + k * 0.04, sz), ins, Vector3.ZERO, 10)
	# roof busbar from the pantograph to the equipment end
	_b(b, ins, Vector3(0.06, 0.06, 0.06), Vector3(0.35, 4.48, pz + 1.2))
	_c(b, MU.mat(Color(0.7, 0.45, 0.25), 0.4, 0.9, "busbar"), 0.02, 2.4, Vector3(0.35, 4.53, pz + 2.4), Vector3(90, 0, 0), 6)
	var lower := Node3D.new()
	p.add_child(lower)
	MU.box(lower, Vector3(0.09, 0.09, 1.0), Vector3(0, 0, -0.5), frame).scale = Vector3(1, 1, 1)
	var upper := Node3D.new()
	p.add_child(upper)
	MU.box(upper, Vector3(0.06, 0.06, 1.0), Vector3(0, 0, -0.5), frame)
	var head := Node3D.new()
	p.add_child(head)
	MU.box(head, Vector3(1.9, 0.05, 0.08), Vector3(0, 0, 0), MU.mat(Color(0.15, 0.15, 0.15), 0.5, 0.3))
	MU.box(head, Vector3(1.4, 0.03, 0.06), Vector3(0, 0.035, 0), MU.mat(Color(0.05, 0.05, 0.05), 0.4))
	for sx in [-1.0, 1.0]:
		MU.box(head, Vector3(0.25, 0.04, 0.06), Vector3(sx * 1.0, -0.06, 0), MU.mat(Color(0.15, 0.15, 0.15), 0.5, 0.3), Vector3(0, 0, sx * -35.0))
	v.pantograph = p
	v.pan_lower_arm = lower
	v.pan_upper_arm = upper
	v.pan_head = head
	update_pantograph(v, 0.0, 0.95)


## frac 0 = stowed, 1 = raised to wire_above_roof metres above the base.
static func update_pantograph(v: Vehicle, frac: float, wire_above_base: float) -> void:
	if v.pantograph == null:
		return
	var a := 1.55   # lower arm
	var b := 1.75   # upper arm
	var base := Vector3(0, 0.15, 0.75)
	var head_y := lerpf(0.42, wire_above_base, frac)
	var head := Vector3(0, head_y, -0.9)
	var d := (head - base).length()
	d = clampf(d, absf(a - b) + 0.01, a + b - 0.01)
	var to_head := (head - base).normalized()
	# knee points up/forward: rotate to_head about +X by the elbow angle
	var ang := acos(clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0))
	var knee := base + (Basis(Vector3.RIGHT, ang) * to_head) * a
	if knee.y < base.y:
		knee = base + (Basis(Vector3.RIGHT, -ang) * to_head) * a
	_place_arm(v.pan_lower_arm, base, knee)
	_place_arm(v.pan_upper_arm, knee, head)
	v.pan_head.position = head + Vector3(0, 0.05, 0)


static func _place_arm(arm: Node3D, from: Vector3, to: Vector3) -> void:
	var dir := to - from
	var l := dir.length()
	arm.transform = Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP if absf(dir.normalized().y) < 0.99 else Vector3.FORWARD), from)
	(arm.get_child(0) as Node3D).scale = Vector3(1, 1, l)
	(arm.get_child(0) as Node3D).position = Vector3(0, 0, -l * 0.5)


# ======================================================================= A4
static var garter_blue := Color(0.1, 0.19, 0.42)


static func _a4_mats() -> Dictionary:
	return {
		"blue": TX.painted(garter_blue, 0.24, 0.15, "grime", 0.3, 0.8, "garter_blue"),
		"black": TX.painted(Color(0.03, 0.03, 0.035), 0.32, 0.2, "grime", 0.3, 0.5, "loco_black"),
		"red": TX.painted(Color(0.5, 0.06, 0.05), 0.35, 0.1, "grime", 0.6, 0.4, "loco_red"),
		"steel": TX.metal(Color(0.66, 0.66, 0.68), 0.25, true, 3.0, "loco_steel"),
		"rod": TX.metal(Color(0.8, 0.8, 0.82), 0.14, true, 6.0, "rod_steel"),
		"stainless": TX.metal(Color(0.86, 0.87, 0.89), 0.12, false, 1.0, "stainless"),
		"brass": TX.painted(Color(0.8, 0.62, 0.3), 0.26, 1.0, "tarnish", 3.0, 0.0, "brass_t"),
		"dark": TX.painted(Color(0.05, 0.05, 0.05), 0.6, 0.3, "grime", 0.6, 0.0, "loco_dark"),
	}


static func a4_loco() -> Vehicle:
	var v := Vehicle.new()
	v.kind = "a4"
	v.name = "A4_4468"
	v.vlength = 14.1
	v.pivot_front = 2.25
	v.pivot_rear = 12.6
	v.mass_tare = 104600.0
	v.axles = 6
	v.motored_axles = 3
	v.brake_mass_ratio = 0.55
	var m := v.make_model_root()
	var b := MeshBatch.new()
	var mt := _a4_mats()
	var blue: Material = mt["blue"]
	var black: Material = mt["black"]
	var red: Material = mt["red"]
	var steel: Material = mt["steel"]
	var rod_steel: Material = mt["rod"]
	# streamlined casing, front (black) then garter blue back to the cab
	var stations := [
		[0.3, 0.92, 1.55, 0.86], [0.55, 0.98, 2.15, 1.08], [0.9, 1.04, 2.72, 1.24],
		[1.4, 1.1, 3.2, 1.33], [2.0, 1.12, 3.55, 1.37], [2.8, 1.12, 3.82, 1.37],
		[3.6, 1.12, 3.93, 1.37], [10.4, 1.12, 3.95, 1.37]]
	var front_rings := []
	var back_rings := []
	for i in range(stations.size()):
		var s: Array = stations[i]
		var r := MU.rounded_ring(s[3], s[1], s[2], s[3] * 0.92, s[0], 8)
		if i <= 4:
			front_rings.append(r)
		if i >= 4:
			back_rings.append(r)
	_l(b, black, front_rings, true, false)
	_l(b, blue, back_rings, false, true)
	# "cod's mouth" smokebox doors: hinged upper flap with a centre crease
	_c(b, MU.mat(Color(0.06, 0.06, 0.065), 0.35, 0.3, "smokebox_door"), 0.42, 0.04, Vector3(0, 1.85, 0.62), Vector3(78, 0, 0), 24)
	_b(b, mt["stainless"], Vector3(0.025, 1.3, 0.02), Vector3(0, 2.3, 0.7), Vector3(-52, 0, 0))
	for sx in [-1.0, 1.0]:
		_b(b, mt["stainless"], Vector3(0.12, 0.03, 0.03), Vector3(sx * 0.16, 1.62, 0.43), Vector3(0, 0, 0))
	# Kylchap double chimney: two openings in line on top
	for cz in [2.55, 3.05]:
		_c(b, black, 0.22, 0.05, Vector3(0, 3.86, cz), Vector3.ZERO, 16)
		_c(b, MU.mat(Color(0.01, 0.01, 0.01), 0.9, 0.0, "soot"), 0.17, 0.052, Vector3(0, 3.865, cz), Vector3.ZERO, 16)
	var smoke := Node3D.new()
	m.add_child(smoke)
	smoke.position = Vector3(0, 3.95, 2.8)
	v.smoke_point = smoke
	var whistle := Node3D.new()
	m.add_child(whistle)
	whistle.position = Vector3(0, 3.98, 3.7)
	v.whistle_point = whistle
	_c(b, mt["brass"], 0.06, 0.25, Vector3(0, 4.0, 3.7), Vector3.ZERO, 10)
	var sv := Node3D.new()
	m.add_child(sv)
	sv.position = Vector3(0, 3.98, 9.7)
	v.safety_valve_point = sv
	_c(b, mt["brass"], 0.05, 0.08, Vector3(-0.12, 3.97, 9.7), Vector3.ZERO, 10)
	_c(b, mt["brass"], 0.05, 0.08, Vector3(0.12, 3.97, 9.7), Vector3.ZERO, 10)
	# buffer beam, buffers, coupling, lamp irons and lamps
	_b(b, red, Vector3(2.6, 0.35, 0.15), Vector3(0, 1.06, 0.38))
	for sx in [-0.86, 0.86]:
		_c(b, steel, 0.2, 0.08, Vector3(sx, 1.06, 0.0), Vector3(90, 0, 0), 16)
		_c(b, black, 0.11, 0.34, Vector3(sx, 1.06, 0.2), Vector3(90, 0, 0), 12)
		_b(b, black, Vector3(0.36, 0.36, 0.04), Vector3(sx, 1.06, 0.33))
		var lamp := MU.lamp(Color(1.0, 0.92, 0.7), 0.0)
		_b(b, MU.mat(Color(0.85, 0.85, 0.82), 0.5, 0.0, "lamp_white"), Vector3(0.22, 0.28, 0.2), Vector3(sx * 0.9, 1.42, 0.45))
		_c(b, MU.mat(Color(0.85, 0.85, 0.82), 0.5, 0.0, "lamp_white"), 0.02, 0.12, Vector3(sx * 0.9, 1.62, 0.45), Vector3.ZERO, 6)
		MU.cyl(m, 0.065, 0.02, Vector3(sx * 0.9, 1.44, 0.34), lamp, Vector3(90, 0, 0), 12)
		v.head_lamps.append(lamp)
	_b(b, black, Vector3(0.12, 0.12, 0.35), Vector3(0, 1.06, 0.15))
	_t(b, steel, 0.03, 0.06, Vector3(0, 1.0, -0.05), Vector3(0, 90, 0), 12, 6)
	_c(b, MU.mat(Color(0.05, 0.05, 0.05), 0.8, 0.0, "hose"), 0.04, 0.5, Vector3(0.35, 0.95, 0.15), Vector3(60, 0, 0), 8)
	# nameplates on the casing sides and stainless running-board trim
	for sx in [-1.0, 1.0]:
		var np := Node3D.new()
		m.add_child(np)
		np.position = Vector3(sx * 1.385, 2.18, 3.25)
		np.rotation_degrees = Vector3(0, 90.0 * sx, 0)
		MU.box(np, Vector3(1.55, 0.2, 0.025), Vector3.ZERO, MU.mat(Color(0.03, 0.03, 0.035), 0.4, 0.2, "nameplate"))
		MU.box(np, Vector3(1.6, 0.25, 0.02), Vector3(0, 0, -0.006), mt["brass"])
		var nl := MU.label(np, "MALLARD", Vector3(0, -0.005, 0.016), 0.0021, Color(0.95, 0.85, 0.55), Vector3.ZERO, 96)
		nl.outline_size = 2
		nl.outline_modulate = Color(0.45, 0.35, 0.15)
		_b(b, mt["stainless"], Vector3(0.014, 0.035, 9.3), Vector3(sx * 1.374, 1.6, 6.0))
		_b(b, mt["stainless"], Vector3(0.014, 0.03, 9.6), Vector3(sx * 1.374, 1.14, 5.9))
		# recessed footsteps in the valance
		for fz in [1.9, 9.9]:
			_b(b, black, Vector3(0.05, 0.12, 0.3), Vector3(sx * 1.36, 1.3, fz))
	# frames
	_b(b, black, Vector3(1.9, 0.45, 12.6), Vector3(0, 0.85, 7.2))
	# wheels: bogie, coupled (6 ft 8 in, red with steel tyres), trailing
	for bz in [1.3, 3.2]:
		_steam_wheelset(v, m, bz, 0.483, red, steel, false, 10)
	var coupled := [4.2, 6.41, 8.62]
	for cz in coupled:
		_steam_wheelset(v, m, cz, 1.016, red, steel, true, 22)
	_steam_wheelset(v, m, 12.6, 0.559, red, steel, false, 12)
	# bogie and trailing truck frames, axleboxes and springs
	for bz in [1.3, 3.2, 12.6]:
		for sx in [-1.0, 1.0]:
			_b(b, mt["dark"], Vector3(0.12, 0.26, 0.42), Vector3(sx * 0.95, 0.5 if bz < 5.0 else 0.56, bz))
	_b(b, mt["dark"], Vector3(1.9, 0.14, 2.6), Vector3(0, 0.9, 2.25))
	# outside cylinders and motion (animated by Train)
	for sx in [-1.0, 1.0]:
		_c(b, black, 0.34, 1.1, Vector3(sx * 1.08, 1.02, 2.2), Vector3(90, 0, 0), 18)
		_c(b, steel, 0.35, 0.05, Vector3(sx * 1.08, 1.02, 1.64), Vector3(90, 0, 0), 18)
		_b(b, steel, Vector3(0.06, 0.22, 1.1), Vector3(sx * 1.1, 1.02, 3.3))    # slide bars
		var crod := MU.box(m, Vector3(0.07, 0.12, 4.42), Vector3.ZERO, rod_steel)    # coupling rod
		var conrod := MU.box(m, Vector3(0.07, 0.14, 3.4), Vector3.ZERO, rod_steel)  # connecting rod
		var xhead := MU.box(m, Vector3(0.12, 0.26, 0.32), Vector3.ZERO, steel)
		var prod := MU.box(m, Vector3(0.05, 0.05, 1.2), Vector3.ZERO, rod_steel)
		var key := "L" if sx < 0 else "R"
		v.rods[key] = {"coupling": crod, "conrod": conrod, "crosshead": xhead, "pistonrod": prod, "x": sx * 0.98}
		var cock := Node3D.new()
		m.add_child(cock)
		cock.position = Vector3(sx * 1.1, 0.75, 1.9)
		v.cocks_points.append(cock)
	v.rods["coupled_z"] = coupled
	v.rods["crank_r"] = 0.33
	v.rods["axle_y"] = 1.016
	# injector overflow pipes under the cab: live steam injector on the fireman's
	# (right) side, exhaust injector on the driver's (left) side
	for sx in [1.0, -1.0]:
		_c(b, mt["dark"], 0.03, 0.5, Vector3(sx * 1.22, 0.92, 11.6), Vector3.ZERO, 8)
		_c(b, mt["dark"], 0.03, 0.12, Vector3(sx * 1.22, 0.66, 11.66), Vector3(30, 0, 0), 8)
		var ov := Node3D.new()
		m.add_child(ov)
		ov.position = Vector3(sx * 1.22, 0.6, 11.7)
		v.overflow_points.append(ov)
	b.commit(m, "Body")
	# cab is built by the interactive cab builder
	var cab := Node3D.new()
	cab.name = "CabRoot"
	m.add_child(cab)
	v.cab_root = cab
	v.finish_model()
	return v


static func _steam_wheelset(v: Vehicle, m: Node3D, z: float, r: float, red: Material, steel: Material, driving: bool, spokes: int) -> void:
	var w := Node3D.new()
	m.add_child(w)
	w.position = Vector3(0, r, z)
	var b := MeshBatch.new()
	var spoke_mat := TX.painted(Color(0.42, 0.05, 0.04), 0.4, 0.05, "grime", 1.0, 0.3, "spoke_red")
	for sx in [-0.78, 0.78]:
		# steel tyre + red rim as rings, so the spokes show daylight between them
		_t(b, steel, r * 0.86, r, Vector3(sx, 0, 0), Vector3(0, 0, 90), 36, 8)
		_t(b, red, r * 0.8, r * 0.88, Vector3(sx, 0, 0), Vector3(0, 0, 90), 36, 6)
		_c(b, red, r * 0.2, 0.18, Vector3(sx, 0, 0), Vector3(0, 0, 90), 14)
		_c(b, steel, r * 0.09, 0.2, Vector3(sx, 0, 0), Vector3(0, 0, 90), 10)
		for k in range(spokes):
			var a := TAU * k / spokes
			# spokes taper toward the rim
			b.cyl("p", spoke_mat, Transform3D(Basis(Vector3.RIGHT, a), Vector3(sx, cos(a) * r * 0.5, sin(a) * r * 0.5)), 0.018, 0.03, r * 0.66, 6)
		if driving:
			# crank pin and the balance weight opposite it
			var alpha := 0.0 if sx < 0 else -TAU / 3.0      # Gresley 3-cylinder: cranks 120 deg apart
			_c(b, steel, 0.07, 0.3, Vector3(sx * 1.12, cos(alpha) * 0.33, sin(alpha) * 0.33), Vector3(0, 0, 90), 10)
			_b(b, spoke_mat, Vector3(0.09, r * 0.3, r * 0.75), Vector3(sx, -cos(alpha) * r * 0.6, -sin(alpha) * r * 0.6), Vector3(rad_to_deg(alpha), 0, 0))
	_c(b, steel, 0.11, 1.6, Vector3.ZERO, Vector3(0, 0, 90), 10)
	b.commit(w, "Wheelset")
	v.add_wheel(w, r, driving)


## Animate rods from the driving wheels' rotation angle (rad). Called by Train each frame.
static func update_motion(v: Vehicle, theta: float) -> void:
	if v.rods.is_empty():
		return
	var cz: Array = v.rods["coupled_z"]
	var rc: float = v.rods["crank_r"]
	var ay: float = v.rods["axle_y"]
	for key in ["L", "R"]:
		var parts: Dictionary = v.rods[key]
		var ph := theta + (0.0 if key == "L" else -TAU / 3.0)
		var off := Vector3(0, cos(ph) * rc, sin(ph) * rc)
		var x: float = parts["x"]
		var p1 := Vector3(x, ay, cz[0]) + off
		var p3 := Vector3(x, ay, cz[2]) + off
		var crod: Node3D = parts["coupling"]
		crod.position = (p1 + p3) * 0.5
		crod.rotation = Vector3.ZERO
		var pin := Vector3(x + 0.1 * signf(x), ay, cz[1]) + off
		var rod_len := 3.4
		var dy := pin.y - ay
		var xz := pin.z - sqrt(rod_len * rod_len - dy * dy)
		var xh := Vector3(x + 0.1 * signf(x), ay, xz)
		var conrod: Node3D = parts["conrod"]
		conrod.position = (xh + pin) * 0.5
		conrod.rotation = Vector3(-atan2(dy, pin.z - xz), 0, 0)
		var xhead: Node3D = parts["crosshead"]
		xhead.position = xh
		var prod: Node3D = parts["pistonrod"]
		prod.position = Vector3(xh.x, ay, xz - 0.6)


static func a4_tender() -> Vehicle:
	var v := Vehicle.new()
	v.kind = "tender"
	v.name = "Tender"
	v.vlength = 7.55
	v.pivot_front = 1.3
	v.pivot_rear = 6.3
	v.mass_tare = 33500.0
	v.mass_load = 8128.0 + 22730.0   # 8 tons coal + 5000 gallons water
	v.axles = 4
	v.brake_mass_ratio = 0.7
	var m := v.make_model_root()
	var b := MeshBatch.new()
	var mt := _a4_mats()
	var blue: Material = mt["blue"]
	var black: Material = mt["black"]
	var red: Material = mt["red"]
	var steel: Material = mt["steel"]
	var coal := TX.pbr("coal_albedo", "coal_normal", Color.WHITE, 0.55, 0.0, Vector3.ONE * 1.4, false, 1.0, "coal_heap")
	var rings := []
	for z in [0.15, 7.4]:
		rings.append(MU.rounded_ring(1.37, 1.12, 3.55, 0.35, z, 6))
	_l(b, blue, rings)
	# coal heaped in the bunker, sloping down toward the shovelling plate
	var heap := []
	for k in range(5):
		var t := float(k) / 4.0
		heap.append(MU.rounded_ring(1.2, 3.4, 3.62 + sin(t * PI) * 0.22 - t * 0.12, 0.35, 0.4 + t * 4.4, 4))
	_l(b, coal, heap)
	_b(b, black, Vector3(2.0, 0.4, 6.8), Vector3(0, 0.9, 3.8))
	# corridor gangway through the tender to the train (Mallard had a corridor tender)
	for k in range(4):
		_b(b, black, Vector3(0.82 - (k % 2) * 0.05, 1.95 - (k % 2) * 0.05, 0.05), Vector3(0, 2.25, 7.42 + k * 0.05))
	_b(b, MU.mat(Color(0.25, 0.14, 0.06), 0.4, 0.0, "tender_door"), Vector3(0.6, 1.7, 0.03), Vector3(0, 2.2, 7.41))
	# water filler, handrails, steps
	_c(b, black, 0.25, 0.12, Vector3(0, 3.6, 6.2), Vector3.ZERO, 16)
	for sx in [-1.0, 1.0]:
		_b(b, mt["stainless"], Vector3(0.014, 0.035, 7.2), Vector3(sx * 1.374, 1.6, 3.8))
		_b(b, mt["stainless"], Vector3(0.014, 0.03, 7.2), Vector3(sx * 1.374, 1.14, 3.8))
		_c(b, steel, 0.016, 1.2, Vector3(sx * 1.4, 2.4, 0.35), Vector3.ZERO, 8)
		_b(b, black, Vector3(0.05, 0.12, 0.35), Vector3(sx * 1.36, 1.3, 0.5))
		var l := MU.label(m, "L N E R", Vector3(sx * 1.38, 2.35, 3.8), 0.0075, Color(0.88, 0.89, 0.9), Vector3(0, 90 * sx, 0), 96)
		l.outline_size = 4
		l.outline_modulate = Color(0.3, 0.3, 0.32)
	for az in [1.3, 3.0, 4.6, 6.3]:
		_steam_wheelset(v, m, az, 0.635, red, steel, false, 12)
		for sx in [-1.0, 1.0]:
			_b(b, mt["dark"], Vector3(0.14, 0.3, 0.4), Vector3(sx * 0.98, 0.64, az))
			_b(b, mt["dark"], Vector3(0.1, 0.08, 0.9), Vector3(sx * 0.98, 0.84, az))
	for sx in [-0.86, 0.86]:
		_c(b, steel, 0.2, 0.08, Vector3(sx, 1.06, 7.55), Vector3(90, 0, 0), 16)
		_c(b, black, 0.11, 0.3, Vector3(sx, 1.06, 7.4), Vector3(90, 0, 0), 12)
		var tl := MU.lamp(Color(1.0, 0.05, 0.03), 0.0)
		MU.box(m, Vector3(0.18, 0.22, 0.18), Vector3(sx * 0.9, 1.45, 7.45), tl)
		v.tail_lamps.append(tl)
	_b(b, red, Vector3(2.6, 0.35, 0.12), Vector3(0, 1.06, 7.42))
	# water scoop between the bogies: lowered into the troughs by the fireman
	var sc := Node3D.new()
	sc.name = "Scoop"
	m.add_child(sc)
	sc.position = Vector3(0, 0.62, 3.8)
	MU.box(sc, Vector3(0.5, 0.06, 0.7), Vector3(0, 0, 0), mt["dark"], Vector3(-18, 0, 0))
	MU.box(sc, Vector3(0.06, 0.3, 0.7), Vector3(-0.25, 0.1, 0), mt["dark"], Vector3(-18, 0, 0))
	MU.box(sc, Vector3(0.06, 0.3, 0.7), Vector3(0.25, 0.1, 0), mt["dark"], Vector3(-18, 0, 0))
	_b(b, mt["dark"], Vector3(0.56, 0.5, 0.5), Vector3(0, 0.95, 4.1))
	v.scoop = sc
	b.commit(m, "Body")
	v.finish_model()
	return v


static func lner_coach(dyn: bool, last: bool) -> Vehicle:
	var v := Vehicle.new()
	v.kind = "coach"
	v.name = "DynamometerCar" if dyn else "Coach"
	v.vlength = 19.2
	v.pivot_front = 2.6
	v.pivot_rear = 16.6
	v.mass_tare = 34500.0 if dyn else 33000.0
	v.axles = 4
	v.brake_mass_ratio = 0.75
	var m := v.make_model_root()
	var b := MeshBatch.new()
	var teak := TX.pbr("teak_albedo", "teak_normal", Color(1.0, 0.94, 0.88), 0.32, 0.0, Vector3(0.7, 0.7, 0.7), false, 0.5, "teak_body")
	if not teak.clearcoat_enabled:
		teak.clearcoat_enabled = true
		teak.clearcoat = 0.6
		teak.clearcoat_roughness = 0.2
	var teak_dark := TX.pbr("teak_albedo", "teak_normal", Color(0.72, 0.62, 0.55), 0.35, 0.0, Vector3(0.7, 0.7, 0.7), false, 0.5, "teak_bead")
	var roof := TX.painted(Color(0.7, 0.7, 0.68), 0.75, 0.0, "grime", 0.3, 0.0, "coach_roof")
	var win := _glass(Color(0.05, 0.055, 0.06), "coach_win")
	var black := TX.painted(Color(0.04, 0.04, 0.04), 0.6, 0.2, "grime", 0.5, 0.0, "coach_black")
	var steel := TX.metal(Color(0.5, 0.5, 0.52), 0.35, false, 1.0, "wheel_steel")
	var gold := Color(0.95, 0.8, 0.4)
	_l(b, teak, [MU.rounded_ring(1.37, 1.05, 3.4, 0.08, 0.35), MU.rounded_ring(1.37, 1.05, 3.4, 0.08, 18.85)])
	_l(b, roof, [MU.rounded_ring(1.39, 3.36, 3.86, 0.5, 0.3, 6), MU.rounded_ring(1.39, 3.36, 3.86, 0.5, 18.9, 6)])
	# rain strips and roof ventilators
	for sx in [-1.0, 1.0]:
		_b(b, black, Vector3(0.03, 0.03, 18.4), Vector3(sx * 1.2, 3.72, 9.6))
	for vz in [2.0, 4.6, 7.2, 9.8, 12.4, 15.0, 17.4]:
		_c(b, roof, 0.09, 0.12, Vector3(0, 3.9, vz), Vector3.ZERO, 10)
		_c(b, roof, 0.12, 0.03, Vector3(0, 3.97, vz), Vector3.ZERO, 10)
	for sx in [-1.0, 1.0]:
		var x: float = sx * 1.375
		var wins := [3.0, 5.0, 9.0, 13.0, 15.5] if dyn else []
		if not dyn:
			var wz := 1.6
			while wz < 18.0:
				wins.append(wz)
				wz += 1.9
		for wz in wins:
			var wl := 1.3 if dyn else 1.25
			_b(b, win, Vector3(0.02, 0.78, wl), Vector3(x, 2.55, wz))
			# window frame and the upper sliding ventilator light
			_b(b, teak_dark, Vector3(0.025, 0.06, wl + 0.12), Vector3(x * 1.003, 2.97, wz))
			_b(b, teak_dark, Vector3(0.025, 0.06, wl + 0.12), Vector3(x * 1.003, 2.13, wz))
			_b(b, teak_dark, Vector3(0.025, 0.86, 0.06), Vector3(x * 1.003, 2.55, wz - wl * 0.5 - 0.03))
			_b(b, teak_dark, Vector3(0.025, 0.86, 0.06), Vector3(x * 1.003, 2.55, wz + wl * 0.5 + 0.03))
			if not dyn:
				_b(b, win, Vector3(0.02, 0.2, 0.6), Vector3(x, 3.12, wz))
				_b(b, teak_dark, Vector3(0.025, 0.26, 0.66), Vector3(x * 0.999, 3.12, wz))
		if dyn:
			MU.label(m, "DYNAMOMETER CAR", Vector3(sx * 1.39, 1.6, 9.6), 0.0035, gold, Vector3(0, 90 * sx, 0), 64)
		else:
			var lt := MU.label(m, "L N E R", Vector3(sx * 1.39, 1.62, 6.0), 0.0032, gold, Vector3(0, 90 * sx, 0), 64)
			lt.outline_size = 3
			lt.outline_modulate = Color(0.25, 0.12, 0.05)
			var nt := MU.label(m, "%d" % (22000 + int(v.get_instance_id() % 900)), Vector3(sx * 1.39, 1.62, 13.2), 0.0032, gold, Vector3(0, 90 * sx, 0), 64)
			nt.outline_size = 3
			nt.outline_modulate = Color(0.25, 0.12, 0.05)
		# panel beading: waist, cant and bottom mouldings
		for yy in [1.35, 2.05, 3.05, 3.3]:
			_b(b, teak_dark, Vector3(0.03, 0.04, 18.4), Vector3(x * 1.002, yy, 9.6))
		# end doors with droplights and brass handles
		for dz in [0.9, 18.3]:
			_b(b, teak_dark, Vector3(0.03, 2.1, 0.03), Vector3(x * 1.003, 2.1, dz - 0.38))
			_b(b, teak_dark, Vector3(0.03, 2.1, 0.03), Vector3(x * 1.003, 2.1, dz + 0.38))
			_b(b, win, Vector3(0.022, 0.6, 0.5), Vector3(x, 2.65, dz))
			_c(b, TX.painted(Color(0.8, 0.62, 0.3), 0.26, 1.0, "tarnish", 3.0, 0.0, "brass_t"), 0.012, 0.1, Vector3(x * 1.01, 2.2, dz + 0.28), Vector3(90, 0, 0), 6)
			_b(b, black, Vector3(0.18, 0.04, 0.4), Vector3(sx * 1.3, 0.85, dz))
	# gangways and ends
	for ez in [0.2, 19.0]:
		for k in range(4):
			_b(b, black, Vector3(1.2 - (k % 2) * 0.06, 2.3 - (k % 2) * 0.06, 0.06), Vector3(0, 2.2, ez + (k - 1.5) * 0.06))
	# underframe: solebars, truss rods, battery boxes, vacuum cylinders, dynamo
	_b(b, black, Vector3(2.0, 0.35, 16.5), Vector3(0, 0.88, 9.6))
	for sx in [-1.0, 1.0]:
		_b(b, black, Vector3(0.06, 0.3, 18.6), Vector3(sx * 1.2, 0.95, 9.6))
		_c(b, black, 0.02, 9.0, Vector3(sx * 0.9, 0.5, 9.6), Vector3(90, 0, 0), 6)
	_b(b, black, Vector3(0.7, 0.45, 1.2), Vector3(-0.6, 0.55, 7.0))
	_b(b, black, Vector3(0.7, 0.45, 1.2), Vector3(-0.6, 0.55, 12.2))
	_c(b, black, 0.28, 0.7, Vector3(0.5, 0.55, 8.5), Vector3(0, 0, 90), 14)
	_c(b, black, 0.28, 0.7, Vector3(0.5, 0.55, 10.7), Vector3(0, 0, 90), 14)
	_c(b, black, 0.15, 0.45, Vector3(0.75, 0.62, 5.0), Vector3(90, 0, 0), 12)
	# Gresley double-bolster bogies
	for bz in [2.6, 16.6]:
		var bn := Node3D.new()
		m.add_child(bn)
		bn.position = Vector3(0, 0, bz)
		var bb := MeshBatch.new()
		_b(bb, black, Vector3(2.2, 0.22, 1.0), Vector3(0, 0.72, 0))
		for sx in [-1.0, 1.0]:
			_b(bb, black, Vector3(0.12, 0.3, 3.5), Vector3(sx * 0.98, 0.62, 0))
			_b(bb, black, Vector3(0.1, 0.12, 2.0), Vector3(sx * 0.98, 0.42, 0))
			for az in [-1.3, 1.3]:
				_b(bb, black, Vector3(0.2, 0.28, 0.32), Vector3(sx * 1.0, 0.47, az))
				_b(bb, MU.mat(Color(0.12, 0.12, 0.12), 0.5, 0.6, "leaf_spring"), Vector3(0.1, 0.06, 0.9), Vector3(sx * 1.0, 0.7, az * 0.55))
		bb.commit(bn, "Bogie")
		for az in [-1.3, 1.3]:
			var w := Node3D.new()
			bn.add_child(w)
			w.position = Vector3(0, 0.47, az)
			var wb := MeshBatch.new()
			for wx in [-0.75, 0.75]:
				_c(wb, steel, 0.47, 0.13, Vector3(wx, 0, 0), Vector3(0, 0, 90), 18)
				_c(wb, black, 0.36, 0.15, Vector3(wx, 0, 0), Vector3(0, 0, 90), 16)
			_c(wb, steel, 0.08, 1.6, Vector3.ZERO, Vector3(0, 0, 90), 8)
			wb.commit(w, "Wheelset")
			v.add_wheel(w, 0.47)
	for sx in [-0.86, 0.86]:
		for ez in [0.1, 19.1]:
			_c(b, steel, 0.19, 0.06, Vector3(sx, 1.06, ez + (-0.15 if ez < 1.0 else 0.15)), Vector3(90, 0, 0), 14)
			_c(b, black, 0.1, 0.35, Vector3(sx, 1.06, ez), Vector3(90, 0, 0), 10)
	if last:
		var tl := MU.lamp(Color(1.0, 0.05, 0.03), 2.5)
		MU.box(m, Vector3(0.2, 0.25, 0.18), Vector3(0.6, 1.5, 19.25), tl)
		v.tail_lamps.append(tl)
	b.commit(m, "Body")
	v.finish_model()
	return v
