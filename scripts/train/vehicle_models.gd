class_name VehicleModels
## Procedural models of every vehicle. Dimensions follow the real trains where
## they are published (D set: 20.4 m cars, 3.03 m wide, 4.40 m tall; A4: 6 ft 8 in
## drivers, 3 ft 2 in bogie wheels, 71 ft over loco and tender).


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
	var white := MU.mat(Color(0.88, 0.89, 0.9), 0.32, 0.3, "nif_body")
	var black := MU.mat(Color(0.05, 0.05, 0.06), 0.25, 0.2, "nif_black")
	var win := MU.mat(Color(0.06, 0.08, 0.1), 0.08, 0.5, "nif_win")
	var orange := MU.mat(Color(0.95, 0.43, 0.07), 0.35, 0.1, "nif_orange")
	var grey := MU.mat(Color(0.2, 0.21, 0.23), 0.6, 0.4, "nif_grey")
	var hw := 1.515
	var body_start := 2.6 if cab_front else 0.3

	# ---- main shell
	var rings := []
	for z in [body_start, L - 0.3]:
		rings.append(MU.rounded_ring(hw, 1.05, 4.4, 0.55, z))
	var shell := MU.loft(rings, white, not cab_front, true)
	m.add_child(shell)
	# lower-deck well between the vestibules
	MU.box(m, Vector3(hw * 2.0, 0.66, L - 9.6), Vector3(0, 0.74, L * 0.5), white)
	MU.box(m, Vector3(hw * 2.0 + 0.01, 0.12, L - 9.6), Vector3(0, 0.47, L * 0.5), orange)
	# window bands (upper & lower deck between doors, mid level over the bogies)
	for sx in [-1.0, 1.0]:
		var x: float = sx * (hw + 0.004)
		MU.box(m, Vector3(0.01, 0.78, L - 10.4), Vector3(x, 3.42, L * 0.5), win)
		MU.box(m, Vector3(0.01, 0.72, L - 10.4), Vector3(x, 1.62, L * 0.5), win)
		var pz := 5.3
		while pz < L - 5.2:
			MU.box(m, Vector3(0.02, 0.8, 0.16), Vector3(x * 1.001, 3.42, pz), white)
			MU.box(m, Vector3(0.02, 0.74, 0.16), Vector3(x * 1.001, 1.62, pz), white)
			pz += 1.32
		if not cab_front:
			MU.box(m, Vector3(0.01, 0.75, 1.9), Vector3(x, 2.65, 1.6), win)
		MU.box(m, Vector3(0.01, 0.75, 1.9), Vector3(x, 2.65, L - 1.6), win)
		MU.box(m, Vector3(0.015, 0.1, L - 0.8), Vector3(x * 1.001, 4.05, L * 0.5), MU.mat(Color(0.25, 0.27, 0.3), 0.4, 0.4))
	# ---- doors: two pairs per side, orange plug doors at the vestibules
	for dz in [4.15, L - 4.15]:
		for sx in [-1.0, 1.0]:
			for leaf in [-1.0, 1.0]:
				var d := Node3D.new()
				m.add_child(d)
				var closed := Vector3(sx * (hw + 0.02), 2.12, dz + leaf * 0.41)
				d.position = closed
				MU.box(d, Vector3(0.04, 1.98, 0.8), Vector3.ZERO, orange)
				MU.box(d, Vector3(0.045, 0.9, 0.5), Vector3(0, 0.35, 0), win)
				var open_vec := Vector3(sx * 0.07, 0, leaf * 0.78)
				if sx < 0:
					v.doors_left.append([d, closed, open_vec])
				else:
					v.doors_right.append([d, closed, open_vec])
	# ---- cab nose
	if cab_front:
		_mariyung_nose(v, m, white, black, orange, win)
	else:
		MU.box(m, Vector3(1.1, 2.3, 0.3), Vector3(0, 2.2, 0.15), black)   # gangway
	MU.box(m, Vector3(1.1, 2.3, 0.3), Vector3(0, 2.2, L - 0.15), black)
	# ---- under-frame & bogies
	for bz in [v.pivot_front, v.pivot_rear]:
		_emu_bogie(v, m, bz, motor, grey)
	MU.box(m, Vector3(2.4, 0.5, 1.6), Vector3(0, 0.82, 1.5 if not cab_front else 2.9), grey)
	# ---- roof
	MU.box(m, Vector3(2.2, 0.08, L - 1.0), Vector3(0, 4.39, L * 0.5), MU.mat(Color(0.55, 0.57, 0.6), 0.6, 0.4))
	if pan:
		_pantograph(v, m, L - 3.6)
	v.finish_model()
	return v


static func _mariyung_nose(v: Vehicle, m: Node3D, white: Material, black: Material, orange: Material, win: Material) -> void:
	# stations: [z, bottom, top, half-width, corner radius]
	var st := [[0.15, 0.62, 2.15, 1.32, 0.35], [0.55, 0.6, 3.0, 1.44, 0.5], [1.15, 0.62, 3.78, 1.5, 0.58],
		[1.9, 0.75, 4.28, 1.515, 0.58], [2.6, 1.05, 4.4, 1.515, 0.55]]
	var rings := []
	for s in st:
		rings.append(MU.rounded_ring(s[3], s[1], s[2], s[4], s[0]))
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
	MU.box(m, Vector3(2.7, 0.22, 0.4), Vector3(0, 0.95, 0.25), orange)
	MU.box(m, Vector3(2.0, 0.35, 0.3), Vector3(0, 0.62, 0.12), black)       # anticlimber / skirt
	MU.box(m, Vector3(0.5, 0.4, 0.5), Vector3(0, 1.0, -0.05), black)        # Dellner coupler head
	# lights: headlights low, marker lights (white) and tail lights (red) high
	for sx in [-1.0, 1.0]:
		var hl := MU.lamp(Color(1.0, 0.96, 0.85), 0.0)
		MU.box(m, Vector3(0.32, 0.14, 0.05), Vector3(sx * 0.95, 1.45, 0.42), hl).name = "HeadLamp"
		v.head_lamps.append(hl)
		var mk := MU.lamp(Color(1.0, 1.0, 0.95), 0.0)
		MU.box(m, Vector3(0.12, 0.12, 0.05), Vector3(sx * 0.95, 1.72, 0.48), mk)
		v.marker_lamps.append(mk)
		var tl := MU.lamp(Color(1.0, 0.05, 0.03), 0.0)
		MU.box(m, Vector3(0.12, 0.12, 0.05), Vector3(sx * 0.7, 1.72, 0.5), tl)
		v.tail_lamps.append(tl)
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
	var b := Node3D.new()
	m.add_child(b)
	b.position = Vector3(0, 0, bz)
	var steel := MU.mat(Color(0.45, 0.45, 0.47), 0.4, 0.8, "wheel_steel")
	MU.box(b, Vector3(2.1, 0.28, 3.1), Vector3(0, 0.75, 0), grey)
	for sx in [-1.0, 1.0]:
		MU.box(b, Vector3(0.18, 0.42, 3.4), Vector3(sx * 1.0, 0.62, 0), grey)
		MU.cyl(b, 0.16, 0.5, Vector3(sx * 1.0, 0.95, -0.45), MU.mat(Color(0.12, 0.12, 0.12), 0.7), Vector3.ZERO, 8)  # air spring
		MU.cyl(b, 0.16, 0.5, Vector3(sx * 1.0, 0.95, 0.45), MU.mat(Color(0.12, 0.12, 0.12), 0.7), Vector3.ZERO, 8)
	for az in [-1.25, 1.25]:
		var w := Node3D.new()
		b.add_child(w)
		w.position = Vector3(0, 0.43, az)
		for sx in [-1.0, 1.0]:
			MU.cyl(w, 0.43, 0.13, Vector3(sx * 0.72, 0, 0), steel, Vector3(0, 0, 90), 18)
		MU.cyl(w, 0.08, 1.6, Vector3.ZERO, steel, Vector3(0, 0, 90), 8)
		if motor:
			MU.box(w, Vector3(0.8, 0.45, 0.45), Vector3(0, 0.05, -0.45 * signf(az)), grey)
		v.add_wheel(w, 0.43)


static func _pantograph(v: Vehicle, m: Node3D, pz: float) -> void:
	var p := Node3D.new()
	p.name = "Pantograph"
	m.add_child(p)
	p.position = Vector3(0, 4.42, pz)
	var frame := MU.mat(Color(0.3, 0.3, 0.32), 0.5, 0.6)
	var ins := MU.mat(Color(0.6, 0.15, 0.1), 0.6)
	MU.box(p, Vector3(1.4, 0.06, 1.8), Vector3(0, 0.12, 0), frame)
	for sx in [-0.6, 0.6]:
		for sz in [-0.8, 0.8]:
			MU.cyl(p, 0.05, 0.14, Vector3(sx, 0.05, sz), ins, Vector3.ZERO, 6)
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
	var blue := MU.mat(garter_blue, 0.22, 0.15, "garter_blue")
	var black := MU.mat(Color(0.03, 0.03, 0.035), 0.3, 0.2, "loco_black")
	var red := MU.mat(Color(0.5, 0.06, 0.05), 0.35, 0.1, "loco_red")
	var steel := MU.mat(Color(0.62, 0.62, 0.64), 0.25, 0.9, "loco_steel")
	var rod_steel := MU.mat(Color(0.75, 0.75, 0.78), 0.18, 0.95, "rod_steel")
	# streamlined casing, front (black) then garter blue back to the cab
	var stations := [
		[0.3, 0.92, 1.55, 0.86], [0.55, 0.98, 2.15, 1.08], [0.9, 1.04, 2.72, 1.24],
		[1.4, 1.1, 3.2, 1.33], [2.0, 1.12, 3.55, 1.37], [2.8, 1.12, 3.82, 1.37],
		[3.6, 1.12, 3.93, 1.37], [10.4, 1.12, 3.95, 1.37]]
	var front_rings := []
	var back_rings := []
	for i in range(stations.size()):
		var s: Array = stations[i]
		var r := MU.rounded_ring(s[3], s[1], s[2], s[3] * 0.92, s[0], 6)
		if i <= 4:
			front_rings.append(r)
		if i >= 4:
			back_rings.append(r)
	m.add_child(MU.loft(front_rings, black, true, false))
	m.add_child(MU.loft(back_rings, blue, false, true))
	# smokebox door ("cod's mouth" outline) and number plate area
	MU.cyl(m, 0.42, 0.04, Vector3(0, 1.85, 0.62), MU.mat(Color(0.08, 0.08, 0.09), 0.4), Vector3(78, 0, 0), 20)
	# Kylchap double chimney: two openings in line on top
	for cz in [2.55, 3.05]:
		MU.cyl(m, 0.22, 0.05, Vector3(0, 3.86, cz), black, Vector3.ZERO, 14)
	var smoke := Node3D.new()
	m.add_child(smoke)
	smoke.position = Vector3(0, 3.95, 2.8)
	v.smoke_point = smoke
	var whistle := Node3D.new()
	m.add_child(whistle)
	whistle.position = Vector3(0, 3.98, 3.7)
	v.whistle_point = whistle
	MU.cyl(m, 0.06, 0.25, Vector3(0, 4.0, 3.7), MU.mat(Color(0.75, 0.6, 0.3), 0.3, 0.9), Vector3.ZERO, 8)
	var sv := Node3D.new()
	m.add_child(sv)
	sv.position = Vector3(0, 3.98, 9.7)
	v.safety_valve_point = sv
	# buffer beam, buffers, coupling, lamps
	MU.box(m, Vector3(2.6, 0.35, 0.15), Vector3(0, 1.06, 0.38), red)
	for sx in [-0.86, 0.86]:
		MU.cyl(m, 0.2, 0.42, Vector3(sx, 1.06, 0.12), steel, Vector3(90, 0, 0), 12)
		MU.cyl(m, 0.08, 0.2, Vector3(sx, 1.06, 0.35), black, Vector3(90, 0, 0), 8)
		var lamp := MU.lamp(Color(1.0, 0.92, 0.7), 0.0)
		MU.box(m, Vector3(0.22, 0.28, 0.2), Vector3(sx * 0.9, 1.42, 0.45), MU.mat(Color(0.85, 0.85, 0.82), 0.5))
		MU.box(m, Vector3(0.12, 0.12, 0.02), Vector3(sx * 0.9, 1.44, 0.34), lamp)
		v.head_lamps.append(lamp)
	MU.box(m, Vector3(0.12, 0.12, 0.35), Vector3(0, 1.06, 0.15), black)
	# side valances (1938 pattern, skirting the wheels) and running board line
	for sx in [-1.0, 1.0]:
		MU.box(m, Vector3(0.012, 0.03, 9.3), Vector3(sx * 1.372, 1.6, 6.0), steel)
	# frames
	MU.box(m, Vector3(1.9, 0.45, 12.6), Vector3(0, 0.85, 7.2), black)
	# wheels: bogie, coupled (6 ft 8 in, red with steel tyres), trailing
	# coupled wheels sit ahead of the wide firebox; the trailing truck carries the firebox and cab
	for bz in [1.3, 3.2]:
		_steam_wheelset(v, m, bz, 0.483, red, steel, false, 10)
	var coupled := [4.2, 6.41, 8.62]
	for cz in coupled:
		_steam_wheelset(v, m, cz, 1.016, red, steel, true, 22)
	_steam_wheelset(v, m, 12.6, 0.559, red, steel, false, 12)
	# outside cylinders and motion (animated by Train)
	for sx in [-1.0, 1.0]:
		MU.cyl(m, 0.34, 1.1, Vector3(sx * 1.08, 1.02, 2.2), black, Vector3(90, 0, 0), 14)
		MU.box(m, Vector3(0.06, 0.22, 1.1), Vector3(sx * 1.1, 1.02, 3.3), steel)    # slide bars
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
	var spoke_mat := MU.mat(Color(0.42, 0.05, 0.04), 0.4, 0.05, "spoke_red")
	for sx in [-0.78, 0.78]:
		# steel tyre + red rim as rings, so the spokes show daylight between them
		MU.torus(w, r * 0.86, r, Vector3(sx, 0, 0), steel, Vector3(0, 0, 90))
		MU.torus(w, r * 0.8, r * 0.88, Vector3(sx, 0, 0), red, Vector3(0, 0, 90))
		MU.cyl(w, r * 0.2, 0.18, Vector3(sx, 0, 0), red, Vector3(0, 0, 90), 12)
		for k in range(spokes):
			var a := TAU * k / spokes
			MU.box(w, Vector3(0.05, r * 0.66, 0.055), Vector3(sx, cos(a) * r * 0.5, sin(a) * r * 0.5), spoke_mat, Vector3(rad_to_deg(a), 0, 0))
		if driving:
			# crank pin and the balance weight opposite it
			var alpha := 0.0 if sx < 0 else -TAU / 3.0      # Gresley 3-cylinder: cranks 120 deg apart
			MU.cyl(w, 0.07, 0.3, Vector3(sx * 1.12, cos(alpha) * 0.33, sin(alpha) * 0.33), steel, Vector3(0, 0, 90), 8)
			MU.box(w, Vector3(0.09, r * 0.3, r * 0.75), Vector3(sx, -cos(alpha) * r * 0.6, -sin(alpha) * r * 0.6), spoke_mat, Vector3(rad_to_deg(alpha), 0, 0))
	MU.cyl(w, 0.11, 1.6, Vector3.ZERO, steel, Vector3(0, 0, 90), 8)
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
	var blue := MU.mat(garter_blue, 0.22, 0.15, "garter_blue")
	var black := MU.mat(Color(0.03, 0.03, 0.035), 0.3, 0.2, "loco_black")
	var red := MU.mat(Color(0.5, 0.06, 0.05), 0.35, 0.1, "loco_red")
	var steel := MU.mat(Color(0.62, 0.62, 0.64), 0.25, 0.9, "loco_steel")
	var rings := []
	for z in [0.15, 7.4]:
		rings.append(MU.rounded_ring(1.37, 1.12, 3.55, 0.35, z))
	m.add_child(MU.loft(rings, blue))
	MU.box(m, Vector3(2.5, 0.35, 4.6), Vector3(0, 3.65, 2.7), MU.noise_mat(Color(0.06, 0.06, 0.07), 0.3, 6.0, 0.9, "coal"))
	MU.box(m, Vector3(2.0, 0.4, 6.8), Vector3(0, 0.9, 3.8), black)
	for sx in [-1.0, 1.0]:
		MU.box(m, Vector3(0.012, 0.03, 7.2), Vector3(sx * 1.372, 1.6, 3.8), steel)
		var l := MU.label(m, "L N E R", Vector3(sx * 1.38, 2.35, 3.8), 0.0075, Color(0.85, 0.86, 0.88), Vector3(0, 90 * sx, 0), 96)
		l.outline_size = 4
		l.outline_modulate = Color(0.3, 0.3, 0.32)
	for az in [1.3, 3.0, 4.6, 6.3]:
		_steam_wheelset(v, m, az, 0.635, red, steel, false, 12)
	for sx in [-0.86, 0.86]:
		MU.cyl(m, 0.2, 0.42, Vector3(sx, 1.06, 7.45), steel, Vector3(90, 0, 0), 12)
		var tl := MU.lamp(Color(1.0, 0.05, 0.03), 0.0)
		MU.box(m, Vector3(0.18, 0.22, 0.18), Vector3(sx * 0.9, 1.45, 7.45), tl)
		v.tail_lamps.append(tl)
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
	var teak := MU.mat(Color(0.5, 0.29, 0.13), 0.28, 0.05, "teak")
	var teak_dark := MU.mat(Color(0.36, 0.2, 0.09), 0.35, 0.05, "teak_dark")
	var roof := MU.mat(Color(0.72, 0.72, 0.7), 0.7, 0.05, "coach_roof")
	var win := MU.mat(Color(0.08, 0.09, 0.1), 0.1, 0.4, "coach_win")
	var black := MU.mat(Color(0.04, 0.04, 0.04), 0.6)
	var steel := MU.mat(Color(0.45, 0.45, 0.47), 0.4, 0.8, "wheel_steel")
	m.add_child(MU.loft([MU.rounded_ring(1.37, 1.05, 3.4, 0.08, 0.35), MU.rounded_ring(1.37, 1.05, 3.4, 0.08, 18.85)], teak))
	m.add_child(MU.loft([MU.rounded_ring(1.39, 3.36, 3.86, 0.5, 0.3), MU.rounded_ring(1.39, 3.36, 3.86, 0.5, 18.9)], roof))
	for sx in [-1.0, 1.0]:
		var x: float = sx * 1.375
		if dyn:
			for wz in [3.0, 5.0, 9.0, 13.0, 15.5]:
				MU.box(m, Vector3(0.02, 0.75, 1.3), Vector3(x, 2.55, wz), win)
			MU.label(m, "DYNAMOMETER CAR", Vector3(sx * 1.39, 1.6, 9.6), 0.0035, Color(0.95, 0.85, 0.55), Vector3(0, 90 * sx, 0), 64)
		else:
			var wz := 1.6
			while wz < 18.0:
				MU.box(m, Vector3(0.02, 0.78, 1.25), Vector3(x, 2.55, wz), win)
				MU.box(m, Vector3(0.02, 0.22, 0.6), Vector3(x, 3.1, wz), win)
				wz += 1.9
		# panel beading
		for yy in [1.35, 2.05, 3.05]:
			MU.box(m, Vector3(0.03, 0.04, 18.4), Vector3(x * 1.002, yy, 9.6), teak_dark)
	MU.box(m, Vector3(1.2, 2.3, 0.4), Vector3(0, 2.2, 0.2), black)
	MU.box(m, Vector3(1.2, 2.3, 0.4), Vector3(0, 2.2, 19.0), black)
	MU.box(m, Vector3(2.0, 0.35, 16.5), Vector3(0, 0.88, 9.6), black)
	for bz in [2.6, 16.6]:
		var b := Node3D.new()
		m.add_child(b)
		b.position = Vector3(0, 0, bz)
		MU.box(b, Vector3(2.2, 0.3, 3.2), Vector3(0, 0.7, 0), black)
		for az in [-1.3, 1.3]:
			var w := Node3D.new()
			b.add_child(w)
			w.position = Vector3(0, 0.47, az)
			for wx in [-0.75, 0.75]:
				MU.cyl(w, 0.47, 0.13, Vector3(wx, 0, 0), steel, Vector3(0, 0, 90), 16)
			MU.cyl(w, 0.08, 1.6, Vector3.ZERO, steel, Vector3(0, 0, 90), 8)
			v.add_wheel(w, 0.47)
	for sx in [-0.86, 0.86]:
		MU.cyl(m, 0.19, 0.4, Vector3(sx, 1.06, 0.1), steel, Vector3(90, 0, 0), 10)
		MU.cyl(m, 0.19, 0.4, Vector3(sx, 1.06, 19.1), steel, Vector3(90, 0, 0), 10)
	if last:
		var tl := MU.lamp(Color(1.0, 0.05, 0.03), 2.5)
		MU.box(m, Vector3(0.2, 0.25, 0.18), Vector3(0.6, 1.5, 19.25), tl)
		v.tail_lamps.append(tl)
	v.finish_model()
	return v
