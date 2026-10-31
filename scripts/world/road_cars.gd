class_name RoadCars
extends RefCounted
## Simple road vehicles that wait at the level crossings: modern cars, utes and
## SUVs on the NSW line, 1930s saloons on the ECML. Built facing -Z (forward),
## x = right, y = up from the road, centred on the wheelbase.


static func _paint(col: Color, key: String) -> Material:
	return TX.painted(col, 0.18, 0.55, "grime", 0.6, 0.9, "car_" + key + col.to_html())


static func _lamp(col: Color, on: bool) -> Material:
	var m := MU.lamp(col, 2.5 if on else 0.4)
	return m


## A modern car. kind: 0 hatch, 1 sedan, 2 SUV, 3 ute.
static func modern(rng: RandomNumberGenerator, night: bool) -> Node3D:
	var car := Node3D.new()
	car.name = "Car"
	var kind := rng.randi() % 4
	var cols := [Color(0.92, 0.92, 0.9), Color(0.75, 0.76, 0.78), Color(0.08, 0.08, 0.09), Color(0.55, 0.05, 0.06),
		Color(0.1, 0.18, 0.4), Color(0.3, 0.32, 0.34), Color(0.85, 0.85, 0.8), Color(0.15, 0.3, 0.2)]
	var col: Color = cols[rng.randi() % cols.size()]
	var body := _paint(col, "m")
	var glass := MU.mat(Color(0.05, 0.06, 0.07), 0.05, 0.0, "car_glass")
	var dark := MU.mat(Color(0.04, 0.04, 0.045), 0.6, 0.0, "car_trim")
	var tyre := MU.mat(Color(0.03, 0.03, 0.03), 0.85, 0.0, "car_tyre")
	var rim := TX.metal(Color(0.7, 0.71, 0.73), 0.3, false, 1.0, "car_rim")
	var L: float = [4.1, 4.75, 4.7, 5.3][kind]
	var hw: float = [0.87, 0.9, 0.94, 0.93][kind]
	var h_belt: float = [0.95, 0.95, 1.12, 1.1][kind]
	var h_roof: float = [1.48, 1.44, 1.72, 1.8][kind]
	var gnd: float = [0.16, 0.15, 0.22, 0.24][kind]
	var b := MeshBatch.new()
	# lower body: bumper, bonnet, body sides, boot / tub
	var z0 := -L * 0.5
	var rings := []
	var hood_z := z0 + (0.95 if kind != 3 else 1.05)
	for s in [[z0, gnd + 0.12, gnd + 0.5, hw - 0.08, 0.14], [z0 + 0.18, gnd, h_belt - 0.15, hw - 0.02, 0.2],
			[hood_z, gnd, h_belt - 0.02, hw, 0.22], [L * 0.5 - 0.25, gnd, h_belt, hw, 0.2], [L * 0.5, gnd + 0.1, h_belt - 0.08, hw - 0.06, 0.16]]:
		rings.append(MU.rounded_ring(s[3], s[1], s[2], s[4], s[0], 4))
	var lo := MU.loft(rings, body, true, true)
	b.mesh("body", body, lo.mesh, Transform3D())
	lo.free()
	# glasshouse: windscreen rake, roof, rear glass (a ute has a short cab)
	var g_end := L * 0.5 - (0.35 if kind != 3 else 2.0)
	var gr := []
	for s in [[hood_z + 0.02, h_belt - 0.02, h_belt + 0.02, hw - 0.06], [hood_z + 0.75, h_belt - 0.02, h_roof, hw - 0.14],
			[g_end - (0.55 if kind != 2 else 0.15), h_belt - 0.02, h_roof, hw - 0.14], [g_end, h_belt - 0.02, h_belt + (0.08 if kind != 2 else 0.5), hw - 0.08]]:
		gr.append(MU.rounded_ring(s[3], s[1], s[2], 0.12, s[0], 3))
	var gl := MU.loft(gr, glass, false, true)
	b.mesh("glass", glass, gl.mesh, Transform3D())
	gl.free()
	# roof panel and pillars in body colour over the glass
	var roof_len := g_end - (0.55 if kind != 2 else 0.15) - (hood_z + 0.75)
	b.box("body", body, Vector3((hw - 0.14) * 2.0 + 0.02, 0.05, roof_len + 0.05), Transform3D(Basis(), Vector3(0, h_roof + 0.01, hood_z + 0.75 + roof_len * 0.5)))
	for sx in [-1.0, 1.0]:
		var mid := hood_z + 0.75 + roof_len * 0.45
		b.box("body", body, Vector3(0.05, h_roof - h_belt, 0.1), Transform3D(Basis(), Vector3(sx * (hw - 0.1), (h_roof + h_belt) * 0.5, mid)))
		# mirrors
		b.box("body", body, Vector3(0.18, 0.1, 0.08), Transform3D(Basis(), Vector3(sx * (hw + 0.08), h_belt + 0.08, hood_z + 0.3)))
	if kind == 3:
		# ute tub sides and tailgate
		for sx in [-1.0, 1.0]:
			b.box("body", body, Vector3(0.05, 0.42, 1.85), Transform3D(Basis(), Vector3(sx * (hw - 0.03), h_belt + 0.2, L * 0.5 - 1.05)))
		b.box("body", body, Vector3(hw * 2.0 - 0.06, 0.42, 0.05), Transform3D(Basis(), Vector3(0, h_belt + 0.2, L * 0.5 - 0.05)))
	# grille, bumpers, plates
	b.box("trim", dark, Vector3(hw * 1.1, 0.16, 0.04), Transform3D(Basis(), Vector3(0, gnd + 0.42, z0 + 0.01)))
	b.box("trim", dark, Vector3(hw * 1.9, 0.12, 0.08), Transform3D(Basis(), Vector3(0, gnd + 0.16, z0 + 0.06)))
	b.box("trim", dark, Vector3(hw * 1.9, 0.12, 0.08), Transform3D(Basis(), Vector3(0, gnd + 0.18, L * 0.5 - 0.02)))
	b.box("plate", MU.mat(Color(0.95, 0.95, 0.9), 0.5, 0.0, "car_plate"), Vector3(0.37, 0.12, 0.01), Transform3D(Basis(), Vector3(0, gnd + 0.33, L * 0.5 + 0.01)))
	var mi := b.commit(car, "Body")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# lamps
	var head := _lamp(Color(1.0, 0.96, 0.88), night)
	var tail := _lamp(Color(1.0, 0.06, 0.03), night)
	for sx in [-1.0, 1.0]:
		MU.box(car, Vector3(0.3, 0.1, 0.02), Vector3(sx * (hw - 0.22), h_belt - 0.2, z0 + 0.2), head)
		MU.box(car, Vector3(0.26, 0.12, 0.02), Vector3(sx * (hw - 0.18), h_belt - 0.18, L * 0.5 + 0.005), tail)
	# wheels
	var wb: float = [2.5, 2.75, 2.75, 3.1][kind]
	var wr: float = [0.31, 0.32, 0.36, 0.37][kind]
	for wz in [-wb * 0.5, wb * 0.5]:
		for sx in [-1.0, 1.0]:
			MU.cyl(car, wr, 0.21, Vector3(sx * (hw - 0.12), wr, wz), tyre, Vector3(0, 0, 90), 16)
			MU.cyl(car, wr * 0.62, 0.02, Vector3(sx * (hw - 0.01), wr, wz), rim, Vector3(0, 0, 90), 12)
	car.set_meta("length", L)
	return car


## A 1930s saloon: long bonnet, upright windscreen, separate wings and
## running boards, spare wheel on the back. Mostly black, some maroon or green.
static func vintage(rng: RandomNumberGenerator, night: bool) -> Node3D:
	var car := Node3D.new()
	car.name = "Car"
	var cols := [Color(0.03, 0.03, 0.035), Color(0.03, 0.03, 0.035), Color(0.25, 0.04, 0.05), Color(0.06, 0.14, 0.09), Color(0.1, 0.1, 0.16)]
	var col: Color = cols[rng.randi() % cols.size()]
	var body := _paint(col, "v")
	var black := MU.mat(Color(0.02, 0.02, 0.02), 0.45, 0.0, "car_v_black")
	var chrome := TX.metal(Color(0.85, 0.85, 0.86), 0.15, false, 1.0, "car_chrome")
	var glass := MU.mat(Color(0.06, 0.07, 0.08), 0.05, 0.0, "car_glass")
	var tyre := MU.mat(Color(0.04, 0.04, 0.04), 0.85, 0.0, "car_tyre")
	var L := rng.randf_range(3.6, 4.3)
	var hw := 0.72
	var b := MeshBatch.new()
	var z0 := -L * 0.5
	# chassis, running boards
	b.box("k", black, Vector3(hw * 1.6, 0.14, L - 0.5), Transform3D(Basis(), Vector3(0, 0.42, 0.05)))
	for sx in [-1.0, 1.0]:
		b.box("k", black, Vector3(0.22, 0.04, L * 0.45), Transform3D(Basis(), Vector3(sx * (hw + 0.08), 0.36, 0.0)))
		# front and rear wings, sloping down to the running board
		var fz := z0 + 0.62
		b.box("b", body, Vector3(0.24, 0.06, 0.9), Transform3D(Basis(Vector3.RIGHT, 0.0), Vector3(sx * (hw + 0.06), 0.75, fz - 0.05)))
		b.box("b", body, Vector3(0.24, 0.06, 0.55), Transform3D(Basis(Vector3.RIGHT, -0.75), Vector3(sx * (hw + 0.07), 0.56, fz + 0.55)))
		var rz := L * 0.5 - 0.55
		b.box("b", body, Vector3(0.24, 0.06, 0.85), Transform3D(Basis(), Vector3(sx * (hw + 0.06), 0.75, rz)))
		b.box("b", body, Vector3(0.24, 0.06, 0.5), Transform3D(Basis(Vector3.RIGHT, 0.75), Vector3(sx * (hw + 0.07), 0.56, rz - 0.6)))
		# headlamps on the wings
		b.cyl("c", chrome, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(sx * 0.45, 0.95, z0 + 0.32)), 0.11, 0.11, 0.16, 12)
	# bonnet and radiator
	var bon_len := L * 0.32
	b.box("b", body, Vector3(hw * 1.15, 0.5, bon_len), Transform3D(Basis(), Vector3(0, 0.78, z0 + 0.2 + bon_len * 0.5)))
	b.box("c", chrome, Vector3(hw * 1.2, 0.58, 0.06), Transform3D(Basis(), Vector3(0, 0.8, z0 + 0.18)))
	b.box("k", black, Vector3(hw * 1.0, 0.48, 0.02), Transform3D(Basis(), Vector3(0, 0.8, z0 + 0.145)))
	# cabin: upright and tall, windows in a dark band
	var cab_z0 := z0 + 0.2 + bon_len
	var cab_len := L - 0.55 - 0.2 - bon_len
	b.box("b", body, Vector3(hw * 2.0, 0.55, cab_len), Transform3D(Basis(), Vector3(0, 0.83, cab_z0 + cab_len * 0.5)))
	b.box("g", glass, Vector3(hw * 1.96, 0.46, cab_len - 0.12), Transform3D(Basis(), Vector3(0, 1.34, cab_z0 + cab_len * 0.5)))
	for k in range(3):
		var pz: float = cab_z0 + 0.04 + k * (cab_len - 0.08) * 0.5
		b.box("b", body, Vector3(hw * 2.0 + 0.01, 0.48, 0.07), Transform3D(Basis(), Vector3(0, 1.34, pz)))
	b.box("b", body, Vector3(hw * 2.0, 0.08, cab_len + 0.06), Transform3D(Basis(), Vector3(0, 1.61, cab_z0 + cab_len * 0.5)))
	# boot with the spare wheel
	b.box("b", body, Vector3(hw * 1.9, 0.5, 0.4), Transform3D(Basis(), Vector3(0, 0.8, L * 0.5 - 0.35)))
	b.cyl("k", tyre, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.88, L * 0.5 - 0.08)), 0.3, 0.3, 0.12, 16)
	var mi := b.commit(car, "Body")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var head := _lamp(Color(1.0, 0.9, 0.7), night)
	for sx in [-1.0, 1.0]:
		MU.cyl(car, 0.09, 0.02, Vector3(sx * 0.45, 0.95, z0 + 0.235), head, Vector3(90, 0, 0), 12)
	MU.box(car, Vector3(0.08, 0.06, 0.02), Vector3(-0.4, 0.75, L * 0.5 - 0.14), _lamp(Color(1.0, 0.08, 0.03), night))
	# tall, thin wheels
	for wz in [z0 + 0.62, L * 0.5 - 0.55]:
		for sx in [-1.0, 1.0]:
			MU.cyl(car, 0.33, 0.12, Vector3(sx * (hw - 0.02), 0.33, wz), tyre, Vector3(0, 0, 90), 16)
			MU.cyl(car, 0.12, 0.13, Vector3(sx * (hw - 0.02), 0.33, wz), chrome, Vector3(0, 0, 90), 10)
	car.set_meta("length", L)
	return car
