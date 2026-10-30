class_name A4Cab
extends Cab
## Footplate of an LNER A4 (left-hand drive). Built in loco model space:
## cab from z = 10.4 (front, behind the boiler casing) to z = 14.05, floor y = 1.5.

const FLOOR := 1.5
const BACKHEAD_Z := 10.8
var water_cols: Array[MeshInstance3D] = []
var cutoff_pointer: Node3D
var fire_zone_mats: Array[StandardMaterial3D] = []
var fire_zone_meshes: Array[MeshInstance3D] = []
var firebox_mat: StandardMaterial3D
var fire_light: OmniLight3D
var gauge_light: OmniLight3D
var door_l: Node3D
var door_r: Node3D
var shovel: Node3D
var scoop_ind: Label3D


func build(cab_root: Node3D) -> void:
	cab_root.add_child(self)
	var blue := MU.mat(VehicleModels.garter_blue, 0.3, 0.15, "garter_blue_cab")
	var lining := MU.mat(Color(0.55, 0.47, 0.36), 0.8, 0.0, "a4_cab_lining")
	var black := MU.mat(Color(0.05, 0.05, 0.055), 0.45, 0.3, "backhead")
	var brass := MU.mat(Color(0.78, 0.6, 0.28), 0.25, 0.9, "brass")
	var copper := MU.mat(Color(0.72, 0.42, 0.26), 0.3, 0.85, "copper")
	var steel := MU.mat(Color(0.55, 0.55, 0.57), 0.3, 0.85, "cab_steel")
	var wood := MU.noise_mat(Color(0.42, 0.3, 0.2), 0.12, 2.0, 0.85, "floorboards")
	var red := MU.mat(Color(0.6, 0.08, 0.06), 0.4, 0.2, "valve_red")
	var glass := MU.glass(Color(0.75, 0.82, 0.85, 0.12))

	# ------------------------------------------------------------ structure
	MU.box(self, Vector3(2.7, 0.06, 3.5), Vector3(0, FLOOR - 0.03, 12.3), wood)
	# spectacle plate: V-shaped front with a window each side of the boiler
	for sx in [-1.0, 1.0]:
		var f := frame(self, Vector3(sx * 1.0, 0, 10.62), Vector3(0, -sx * 30.0, 0))
		MU.box(f, Vector3(0.82, 1.6, 0.04), Vector3(0, 2.3, 0), blue)
		MU.box(f, Vector3(0.82, 0.24, 0.04), Vector3(0, 3.85, 0), blue)
		MU.box(f, Vector3(0.12, 0.65, 0.04), Vector3(-0.35, 3.42, 0), blue)
		MU.box(f, Vector3(0.12, 0.65, 0.04), Vector3(0.35, 3.42, 0), blue)
		MU.box(f, Vector3(0.6, 0.62, 0.01), Vector3(0, 3.42, 0), glass)
	# side sheets with a sliding window
	for sx in [-1.0, 1.0]:
		var x: float = sx * 1.355
		MU.box(self, Vector3(0.03, 1.1, 3.15), Vector3(x, FLOOR + 0.55, 12.45), blue)
		MU.box(self, Vector3(0.03, 0.62, 3.15), Vector3(x, 3.66, 12.45), blue)
		MU.box(self, Vector3(0.03, 0.75, 0.7), Vector3(x, 2.975, 11.2), blue)
		MU.box(self, Vector3(0.03, 0.75, 0.9), Vector3(x, 2.975, 13.55), blue)
		MU.box(self, Vector3(0.01, 0.7, 1.4), Vector3(x, 2.975, 12.3), glass)
		MU.box(self, Vector3(0.01, 0.95, 3.0), Vector3(x - sx * 0.02, FLOOR + 0.5, 12.45), lining)
		var num := MU.label(self, "4468", Vector3(sx * 1.375, 2.25, 12.4), 0.0055, Color(0.85, 0.86, 0.88), Vector3(0, 90.0 * sx, 0), 96)
		num.outline_size = 3
		num.outline_modulate = Color(0.25, 0.25, 0.28)
		# wind deflector glass outside the window
		MU.box(self, Vector3(0.01, 0.6, 0.3), Vector3(sx * 1.43, 3.0, 11.1), glass, Vector3(0, sx * 25.0, 0))
	MU.box(self, Vector3(2.76, 0.06, 3.5), Vector3(0, 3.98, 12.3), blue)
	MU.box(self, Vector3(2.6, 0.02, 3.4), Vector3(0, 3.94, 12.3), lining)
	MU.box(self, Vector3(0.5, 0.12, 0.6), Vector3(0, 4.05, 12.6), blue)          # roof ventilator

	# --------------------------------------------------------------- backhead
	var bh := frame(self, Vector3(0, 0, BACKHEAD_Z), Vector3.ZERO)
	# plate around the firehole (opening 0.46 x 0.34 centred y = 1.98)
	MU.box(bh, Vector3(1.9, 0.31, 0.06), Vector3(0, FLOOR + 0.155, 0), black)
	MU.box(bh, Vector3(0.72, 0.36, 0.06), Vector3(-0.59, 1.98, 0), black)
	MU.box(bh, Vector3(0.72, 0.36, 0.06), Vector3(0.59, 1.98, 0), black)
	MU.box(bh, Vector3(1.9, 0.86, 0.06), Vector3(0, 2.58, 0), black)
	MU.cyl(bh, 0.95, 0.06, Vector3(0, 3.0, 0), black, Vector3(90, 0, 0), 40)
	MU.torus(bh, 0.24, 0.29, Vector3(0, 1.98, 0.04), steel, Vector3(90, 0, 0))
	# firehole doors (slide apart)
	door_l = Node3D.new()
	bh.add_child(door_l)
	door_l.position = Vector3(-0.12, 1.98, 0.05)
	MU.box(door_l, Vector3(0.25, 0.38, 0.03), Vector3.ZERO, steel)
	door_r = Node3D.new()
	bh.add_child(door_r)
	door_r.position = Vector3(0.12, 1.98, 0.05)
	MU.box(door_r, Vector3(0.25, 0.38, 0.03), Vector3.ZERO, steel)
	# steam manifold (turret) and pipes
	MU.cyl(bh, 0.07, 0.6, Vector3(0, 3.62, 0.1), brass, Vector3(0, 0, 90), 12)
	for px in [-0.5, -0.25, 0.25, 0.5]:
		MU.cyl(bh, 0.018, 0.9, Vector3(px, 3.1, 0.07), copper, Vector3.ZERO, 8)
	MU.cyl(bh, 0.02, 1.1, Vector3(-0.82, 2.5, 0.08), copper, Vector3.ZERO, 8)
	MU.cyl(bh, 0.02, 1.1, Vector3(0.82, 2.5, 0.08), copper, Vector3.ZERO, 8)

	# ------------------------------------------------------- firebox interior
	firebox_mat = MU.lamp(Color(1.0, 0.45, 0.15), 0.0)
	firebox_mat.albedo_color = Color(0.25, 0.12, 0.08)
	var fb := frame(self, Vector3(0, 0, 0), Vector3.ZERO)
	MU.box(fb, Vector3(0.05, 1.5, 1.2), Vector3(-0.92, 2.05, 10.15), firebox_mat)
	MU.box(fb, Vector3(0.05, 1.5, 1.2), Vector3(0.92, 2.05, 10.15), firebox_mat)
	MU.box(fb, Vector3(1.9, 0.05, 1.2), Vector3(0, 2.78, 10.15), firebox_mat)
	MU.box(fb, Vector3(1.9, 1.5, 0.05), Vector3(0, 2.05, 9.55), firebox_mat)
	MU.box(fb, Vector3(1.9, 0.05, 1.2), Vector3(0, 1.3, 10.15), MU.mat(Color(0.05, 0.04, 0.04), 0.9))     # ashpan
	MU.box(fb, Vector3(1.8, 0.1, 0.6), Vector3(0, 2.5, 9.85), MU.mat(Color(0.55, 0.3, 0.2), 0.9), Vector3(-12, 0, 0))   # brick arch
	var zone_pos := [Vector3(-0.45, 0, 10.45), Vector3(0.45, 0, 10.45), Vector3(-0.45, 0, 9.85), Vector3(0.45, 0, 9.85)]
	for i in range(4):
		var zm := MU.lamp(Color(1.0, 0.5, 0.15), 0.0)
		zm.albedo_color = Color(0.08, 0.07, 0.07)
		var mi := MU.box(fb, Vector3(0.88, 0.1, 0.58), zone_pos[i] + Vector3(0, 1.42, 0), zm)
		fire_zone_mats.append(zm)
		fire_zone_meshes.append(mi)
		var zc := button("fire_zone_%d" % i, "Grate: %s" % A4Sim.ZONE_NAMES[i], fb, zone_pos[i] + Vector3(0, 1.5, 0), Vector3(-90, 0, 0), Color(0, 0, 0, 0),
			"Click to fire a shovelful here (door must be open). Keep the fire even, a little thicker at the back corners.", 0.001)
		zc.pick_extent = Vector3(0.4, 0.27, 0.08)
		zc.pick_offset = Vector3.ZERO
		zc.get_child(0).visible = false
	fire_light = OmniLight3D.new()
	fire_light.light_color = Color(1.0, 0.55, 0.25)
	fire_light.omni_range = 4.5
	fire_light.light_energy = 0.0
	fire_light.shadow_enabled = false
	add_child(fire_light)
	fire_light.position = Vector3(0, 1.95, 11.1)

	# ------------------------------------------------------------- gauges
	gauge("boiler", bh, Vector3(0.0, 3.42, 0.09), Vector3.ZERO, 0.095, 0, 300, 50, 10, "BOILER", "lb/sq in", [Color(0.05, 0.05, 0.05)], Color(0.95, 0.93, 0.86), 1.0, 250.0, 270.0, Color(0.7, 0.55, 0.25))
	gauge("chest", bh, Vector3(-0.36, 3.33, 0.08), Vector3(0, 0, 0), 0.068, 0, 300, 50, 10, "STEAM CHEST", "lb/sq in", [Color(0.05, 0.05, 0.05)], Color(0.95, 0.93, 0.86), 1.0, INF, 270.0, Color(0.7, 0.55, 0.25))
	gauge("vacuum", bh, Vector3(-0.66, 3.02, 0.08), Vector3(0, 0, 0), 0.075, 0, 30, 5, 1, "VACUUM", "ins", [Color(0.05, 0.05, 0.05), Color(0.8, 0.1, 0.05)], Color(0.95, 0.93, 0.86), 1.0, INF, 270.0, Color(0.7, 0.55, 0.25))
	gauge("steam_heat", bh, Vector3(0.62, 3.2, 0.08), Vector3.ZERO, 0.05, 0, 100, 20, 5, "CARRIAGE", "HEAT", [Color(0.05, 0.05, 0.05)], Color(0.95, 0.93, 0.86), 1.0, INF, 270.0, Color(0.7, 0.55, 0.25))
	gauge("speed", self, Vector3(-1.08, 3.02, 11.0), Vector3(0, 12, 0), 0.075, 0, 120, 20, 5, "SPEED", "m.p.h.", [Color(0.9, 0.9, 0.9)], Color(0.06, 0.06, 0.07), 1.0, INF, 300.0, Color(0.25, 0.25, 0.25))
	# turn the speed indicator's numbers white on its black face
	for ch in gauges["speed"].get_children():
		if ch is Label3D:
			(ch as Label3D).modulate = Color(0.92, 0.92, 0.9)

	# ------------------------------------------------- water gauge glasses
	for sx in [-1.0, 1.0]:
		var gx: float = sx * 0.47
		var gf := frame(bh, Vector3(gx, 0, 0.09), Vector3.ZERO)
		MU.box(gf, Vector3(0.06, 0.06, 0.06), Vector3(0, 2.25, 0), brass)
		MU.box(gf, Vector3(0.06, 0.06, 0.06), Vector3(0, 2.77, 0), brass)
		MU.cyl(gf, 0.012, 0.48, Vector3(0, 2.51, 0.0), MU.glass(Color(0.9, 0.95, 1.0, 0.25)), Vector3.ZERO, 10)
		var col := MU.box(gf, Vector3(0.018, 0.46, 0.018), Vector3(0, 2.28, 0.0), MU.mat(Color(0.25, 0.35, 0.45, 0.8), 0.1))
		water_cols.append(col)
		# protector frame with the diagonal 'Klinger' stripes behind the glass
		MU.box(gf, Vector3(0.05, 0.48, 0.005), Vector3(0, 2.51, -0.025), MU.mat(Color(0.95, 0.95, 0.95), 0.6))
		for k in range(6):
			MU.box(gf, Vector3(0.05, 0.008, 0.002), Vector3(0, 2.32 + k * 0.08, -0.02), MU.mat(Color(0.1, 0.1, 0.3), 0.6), Vector3(0, 0, 35))
		button("gauge_test_%s" % ("l" if sx < 0 else "r"), "Gauge glass test cocks", gf, Vector3(0.06, 2.2, 0.02), Vector3.ZERO, Color(0.75, 0.6, 0.28),
			"Blow through the gauge glass to prove it is reading truly (do this when preparing the engine).", 0.012)

	# ---------------------------------------------------- driver's controls
	var reg := lever("regulator", "Regulator", bh, Vector3(-0.1, 3.08, 0.1), Vector3(0, 0, 90), 0.5,
		Vector3(0, 0, 28), Vector3(0, 0, -75), steel, MU.mat(Color(0.1, 0.08, 0.06), 0.5),
		"Admits steam to the cylinders. First 12% opens the small first valve (pilot) for gentle starting; beyond that the main valve.")
	reg.drag_scale = 0.003
	reg.notches = [[0.0, "SHUT"], [0.12, "FIRST VALVE"], [1.0, "FULL"]]
	reg.custom_state = func(): return "SHUT" if reg.value < 0.005 else ("first valve %d%%" % int(reg.value / 0.12 * 100.0) if reg.value <= 0.12 else "main valve %d%%" % int((reg.value - 0.12) / 0.88 * 100.0))
	var rev := wheel("reverser", "Reversing screw (cut-off)", self, Vector3(-1.05, 2.3, 11.35), Vector3(0, 30, 0), 0.17, -75.0, 75.0, 0.0, 13.0, steel,
		"Sets direction and cut-off. Full gear (65-75%) to start, then wind back towards 15-25% as speed rises. Mid gear = 0.", 6)
	rev.unit = "%"
	rev.custom_state = func(): return "%d%% %s" % [int(absf(rev.value)), "FORWARD" if rev.value > 0.5 else ("BACKWARD" if rev.value < -0.5 else "MID GEAR")]
	# cut-off indicator
	var ind := frame(self, Vector3(-1.3, 2.62, 11.42), Vector3(0, 70, 0))
	MU.box(ind, Vector3(0.06, 0.34, 0.01), Vector3.ZERO, MU.mat(Color(0.9, 0.88, 0.8), 0.6))
	for i in range(7):
		var cv := 75 - i * 25
		text("%d" % absi(cv), ind, Vector3(0.0, 0.15 - i * 0.05, 0.007), Vector3.ZERO, 0.00025, Color(0.05, 0.05, 0.05))
	text("FORE", ind, Vector3(0, 0.185, 0.007), Vector3.ZERO, 0.0002, Color(0.05, 0.05, 0.05))
	text("BACK", ind, Vector3(0, -0.185, 0.007), Vector3.ZERO, 0.0002, Color(0.05, 0.05, 0.05))
	cutoff_pointer = Node3D.new()
	ind.add_child(cutoff_pointer)
	MU.box(cutoff_pointer, Vector3(0.08, 0.006, 0.006), Vector3(0, 0, 0.01), MU.mat(Color(0.8, 0.1, 0.05), 0.4))

	var brk := lever("brake", "Vacuum brake valve", self, Vector3(-0.8, 2.82, 10.98), Vector3(90, 0, 0), 0.24,
		Vector3(0, 0, -40), Vector3(0, 0, 80), steel, MU.mat(Color(0.08, 0.08, 0.08), 0.5),
		"Driver's brake valve. RELEASE/RUNNING at the left; move right to admit air to the train pipe and apply the brakes progressively.")
	brk.notches = [[0.0, "RUNNING"], [0.3, "LAP"], [1.0, "FULL APPLICATION"]]
	brk.custom_state = func(): return "RUNNING (off)" if brk.value < 0.08 else "APPLYING %d%%" % int((brk.value - 0.08) / 0.92 * 100.0)
	lever("large_ejector", "Large ejector", self, Vector3(-0.62, 2.98, 10.93), Vector3(90, 0, 0), 0.14,
		Vector3(0, 0, -30), Vector3(0, 0, 60), brass, MU.mat(Color(0.08, 0.08, 0.08), 0.5),
		"Steam to the large ejector: quickly creates vacuum (21 in) to release the brakes. Shut it once the vacuum is up.", 0.018)
	wheel("small_ejector", "Small ejector valve", bh, Vector3(-0.47, 3.62, 0.12), Vector3.ZERO, 0.04, 0.0, 1.0, 0.0, 2.0, red,
		"Keeps the vacuum up against leaks while running. Normally left open whenever the engine is in use.", 4, false)
	var wh := lever("whistle", "Chime whistle", bh, Vector3(-0.22, 3.82, 0.12), Vector3(180, 0, 0), 0.2,
		Vector3.ZERO, Vector3(-45, 0, 0), steel, MU.mat(Color(0.1, 0.08, 0.06), 0.5), "Pull for Mallard's three-note chime whistle.")
	wh.spring_to = 0.0
	var sand := lever("sanders", "Steam sanding valve", self, Vector3(-1.3, 2.15, 11.75), Vector3(0, 90, 0), 0.16,
		Vector3(-20, 0, 0), Vector3(40, 0, 0), steel, MU.mat(Color(0.08, 0.08, 0.08), 0.5),
		"Blows sand under the driving wheels for grip when slipping or on wet rail.", 0.016)
	sand.notches = [[0.0, "OFF"], [1.0, "ON"]]
	sand.notch_only = true
	var cocks := lever("cocks", "Cylinder drain cocks", self, Vector3(-0.85, FLOOR, 11.55), Vector3.ZERO, 0.62,
		Vector3(18, 0, 0), Vector3(-36, 0, 0), steel, MU.mat(Color(0.08, 0.08, 0.08), 0.5),
		"Open when starting from cold to blow condensed water out of the cylinders. Close once she's warmed through.", 0.02)
	cocks.notches = [[0.0, "SHUT"], [1.0, "OPEN"]]
	cocks.notch_only = true
	wheel("inj_exh_steam", "Exhaust injector steam valve", bh, Vector3(-0.27, 3.82, 0.12), Vector3.ZERO, 0.04, 0.0, 1.0, 0.0, 1.5, red,
		"Davies & Metcalfe exhaust steam injector. Uses exhaust steam when the regulator is open (economical, hot feed). Open the water valve first!", 4, false)
	var iew := lever("inj_exh_water", "Exhaust injector water valve", self, Vector3(-1.0, FLOOR, 13.55), Vector3.ZERO, 0.45,
		Vector3(20, 0, 0), Vector3(-50, 0, 0), steel, MU.mat(Color(0.5, 0.06, 0.05), 0.5),
		"Water from the tender to the exhaust injector. About half-open is right; too little or too much and it wastes at the overflow.", 0.02)
	iew.drag_scale = 0.003
	wheel("blower", "Blower valve", bh, Vector3(0.18, 3.72, 0.12), Vector3.ZERO, 0.05, 0.0, 1.0, 0.0, 2.0, red,
		"Steam jet up the chimney to draw the fire when the regulator is shut. Put it on BEFORE shutting off at speed (prevents blowback).", 4, false)

	# ---------------------------------------------------- fireman's controls
	wheel("inj_live_steam", "Live steam injector steam valve", bh, Vector3(0.42, 3.62, 0.12), Vector3.ZERO, 0.045, 0.0, 1.0, 0.0, 1.5, red,
		"Live steam injector (fireman's side). Works from boiler steam, so use it when standing. Water valve first, then steam.", 4, false)
	var ilw := lever("inj_live_water", "Live injector water valve", self, Vector3(1.0, FLOOR, 13.55), Vector3.ZERO, 0.45,
		Vector3(20, 0, 0), Vector3(-50, 0, 0), steel, MU.mat(Color(0.5, 0.06, 0.05), 0.5),
		"Water to the live steam injector. About half-open is right.", 0.02)
	ilw.drag_scale = 0.003
	wheel("steam_heat", "Carriage steam heat valve", bh, Vector3(0.7, 2.98, 0.12), Vector3.ZERO, 0.035, 0.0, 1.0, 0.0, 1.0, red,
		"Steam to heat the carriages (winter). Costs steam.", 4, false)
	var fd := lever("firedoor", "Firehole doors", bh, Vector3(0.36, 1.98, 0.11), Vector3(0, 0, -90), 0.2,
		Vector3(0, 0, -15), Vector3(0, 0, 50), steel, MU.mat(Color(0.08, 0.08, 0.08), 0.5),
		"Open to fire. A small gap lets in secondary air over the fire (less smoke); wide open lets cold air in and steam pressure falls.", 0.018)
	fd.custom_state = func(): return "SHUT" if fd.value < 0.03 else ("ON THE LATCH (%d%%)" % int(fd.value * 100.0) if fd.value < 0.5 else "OPEN")
	var dfront := lever("damper_front", "Front damper", self, Vector3(0.45, FLOOR, 11.25), Vector3.ZERO, 0.38,
		Vector3(15, 0, 0), Vector3(-45, 0, 0), steel, MU.mat(Color(0.08, 0.08, 0.08), 0.5),
		"Ashpan front damper: lets air under the grate. Open when working hard.", 0.018)
	var dback := lever("damper_back", "Back damper", self, Vector3(0.7, FLOOR, 11.25), Vector3.ZERO, 0.38,
		Vector3(15, 0, 0), Vector3(-45, 0, 0), steel, MU.mat(Color(0.08, 0.08, 0.08), 0.5),
		"Ashpan back damper: the main air supply under the grate.", 0.018)
	dfront.notches = [[0.0, "SHUT"], [0.5, "HALF"], [1.0, "OPEN"]]
	dback.notches = [[0.0, "SHUT"], [0.5, "HALF"], [1.0, "OPEN"]]
	var hb := wheel("handbrake", "Tender hand brake", self, Vector3(1.0, 2.35, 13.85), Vector3(-90, 0, 0), 0.15, 0.0, 1.0, 1.0, 8.0, MU.mat(Color(0.12, 0.12, 0.12), 0.5, 0.5),
		"Screw hand brake on the tender (fireman's side). Must be off before moving!", 4)
	hb.custom_state = func(): return "ON" if hb.value > 0.95 else ("OFF" if hb.value < 0.02 else "%d%% on" % int(hb.value * 100.0))
	MU.cyl(self, 0.035, 0.85, Vector3(1.0, 1.92, 13.85), MU.mat(Color(0.12, 0.12, 0.12), 0.5, 0.5), Vector3.ZERO, 8)
	var sc := wheel("scoop", "Water scoop", self, Vector3(-0.35, 2.3, 13.92), Vector3(-90, 0, 0), 0.15, 0.0, 1.0, 0.0, 3.0, MU.mat(Color(0.12, 0.12, 0.12), 0.5, 0.5),
		"Lowers the scoop to pick up water from the troughs (above ~30 mph). Wind it up again before the troughs end!", 4)
	sc.custom_state = func(): return "UP" if sc.value < 0.05 else ("DOWN" if sc.value > 0.95 else "%d%% down" % int(sc.value * 100.0))
	MU.cyl(self, 0.035, 0.8, Vector3(-0.35, 1.9, 13.92), MU.mat(Color(0.12, 0.12, 0.12), 0.5, 0.5), Vector3.ZERO, 8)
	button("firelighters", "Firelighters", self, Vector3(0.62, FLOOR + 0.2, 13.75), Vector3(-60, 0, 0), Color(0.6, 0.45, 0.2),
		"Paraffin-soaked firelighters. With coal spread over the grate and the door open, click to light the fire.", 0.05)
	MU.cyl(self, 0.12, 0.3, Vector3(0.62, FLOOR + 0.15, 13.8), MU.mat(Color(0.3, 0.3, 0.32), 0.5, 0.6), Vector3.ZERO, 12)
	button("coal", "Coal hole (shovel)", self, Vector3(0.15, 1.85, 14.12), Vector3(0, 180, 0), Color(0.05, 0.05, 0.05),
		"Take a shovelful of coal. Then click part of the grate through the open firehole. (Keyboard: E fires straight to the selected part of the grate.)", 0.14)
	var gl := toggle("gauge_lamp", "Gauge lamp", bh, Vector3(0.0, 3.9, 0.08), Vector3.ZERO, ["OFF", "ON"], 0, "Lights the gauges at night.")
	gl.title = "Gauge lamp"
	gauge_light = OmniLight3D.new()
	gauge_light.light_color = Color(1.0, 0.85, 0.6)
	gauge_light.omni_range = 1.4
	gauge_light.light_energy = 0.0
	add_child(gauge_light)
	gauge_light.position = Vector3(0, 3.55, 11.1)

	# ------------------------------------------------- tender front & seats
	MU.box(self, Vector3(2.6, 1.9, 0.05), Vector3(0, FLOOR + 1.15, 14.28), blue)
	MU.box(self, Vector3(0.7, 0.55, 0.06), Vector3(0.15, 1.85, 14.26), MU.mat(Color(0.03, 0.03, 0.03), 0.9))
	MU.box(self, Vector3(1.2, 0.04, 0.5), Vector3(0.1, FLOOR + 0.02, 14.05), steel)       # shovel plate
	MU.box(self, Vector3(0.6, 0.25, 0.4), Vector3(0.15, 1.65, 14.45), MU.noise_mat(Color(0.06, 0.06, 0.07), 0.3, 6.0, 0.9, "coal"))
	gauge("tender_water", self, Vector3(-0.9, 2.55, 14.24), Vector3(0, 180, 0), 0.06, 0, 5000, 1000, 250, "TENDER", "gallons", [Color(0.05, 0.05, 0.05)], Color(0.95, 0.93, 0.86), 1000.0)
	for sx in [-1.0, 1.0]:
		MU.box(self, Vector3(0.4, 0.05, 0.35), Vector3(sx * 1.05, 2.2, 12.9), wood)
		MU.box(self, Vector3(0.05, 0.7, 0.05), Vector3(sx * 1.05, 1.85, 12.9), steel)
	# shovel (moves when firing)
	shovel = Node3D.new()
	add_child(shovel)
	shovel.position = Vector3(0.55, FLOOR + 0.05, 13.4)
	MU.box(shovel, Vector3(0.26, 0.02, 0.32), Vector3(0, 0.02, -0.16), steel)
	MU.cyl(shovel, 0.015, 0.8, Vector3(0, 0.06, 0.25), MU.mat(Color(0.45, 0.32, 0.2), 0.7), Vector3(80, 0, 0), 6)

	# ---------------------------------------------------------------- views
	add_view("Driver (seated)", Vector3(-0.92, 2.78, 12.85), 0.0, -6.0)
	add_view("Fireman", Vector3(0.45, 2.95, 13.3), 8.0, -28.0)
	add_view("Look out (driver's side)", Vector3(-1.62, 3.12, 12.3), 0.0, -4.0)
	add_view("Look out (fireman's side)", Vector3(1.62, 3.12, 12.3), 0.0, -4.0)
	add_view("Standing (driver)", Vector3(-0.7, 3.15, 12.6), 6.0, -12.0)


var _anim_shovel := 0.0


func update_visuals(sim: A4Sim, delta: float) -> void:
	gauges["boiler"].set_value(0, sim.p_gauge)
	gauges["chest"].set_value(0, maxf(0.0, (sim.chest_p - A4Sim.ATM) / A4Sim.PSI))
	gauges["vacuum"].set_value(0, sim.tp_vac)
	gauges["vacuum"].set_value(1, sim.veh_res[0] if sim.veh_res.size() > 0 else 0.0)
	gauges["steam_heat"].set_value(0, val("steam_heat") * minf(sim.p_gauge, 80.0))
	gauges["speed"].set_value(0, absf(sim.train.speed) / 0.44704)
	gauges["tender_water"].set_value(0, sim.tender_water / 4.546)
	# water in the glasses (bounces a little when steaming hard)
	var lv := clampf(sim.level + sin(Time.get_ticks_msec() * 0.011) * 0.01 * clampf(sim.cyl_flow, 0.0, 1.0), -0.05, 1.05)
	for col in water_cols:
		var h := clampf(lv, 0.0, 1.0) * 0.46
		col.visible = lv > 0.0
		col.scale = Vector3(1, maxf(h / 0.46, 0.001), 1)
		col.position.y = 2.28 + h * 0.5 - 0.0
	cutoff_pointer.position.y = clampf(sim.cutoff / 0.75, -1.0, 1.0) * 0.15
	# firehole doors and the fire
	var door := val("firedoor")
	door_l.position.x = -0.12 - door * 0.24
	door_r.position.x = 0.12 + door * 0.24
	var flicker := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.023) * sin(Time.get_ticks_msec() * 0.0071)
	var hottest := 0.0
	for i in range(4):
		var t: float = sim.zone_t[i]
		hottest = maxf(hottest, t)
		var glow := clampf((t - 450.0) / 900.0, 0.0, 1.3)
		var mat := fire_zone_mats[i]
		mat.emission = Color(1.0, 0.35 + 0.45 * clampf((t - 900.0) / 500.0, 0.0, 1.0), 0.1 + 0.4 * clampf((t - 1150.0) / 300.0, 0.0, 1.0))
		mat.emission_energy_multiplier = glow * 3.0 * flicker
		var thick := clampf(sim.zones[i] / 720.0, 0.005, 0.35)
		fire_zone_meshes[i].scale = Vector3(1, thick / 0.1 + 0.05, 1)
		fire_zone_meshes[i].position.y = 1.36 + thick * 0.5
	var fglow := clampf((hottest - 450.0) / 900.0, 0.0, 1.2)
	firebox_mat.emission_energy_multiplier = fglow * 1.6 * flicker
	fire_light.light_energy = fglow * (0.25 + door * 2.2) * flicker
	gauge_light.light_energy = 0.6 if val("gauge_lamp") > 0.5 else 0.0
	# shovel swing
	if sim.sound.get("shovel", false):
		sim.sound["shovel"] = false
		_anim_shovel = 1.0
	_anim_shovel = maxf(0.0, _anim_shovel - delta * 1.6)
	var a := sin(_anim_shovel * PI)
	shovel.position = Vector3(0.55 - a * 0.45, FLOOR + 0.05 + a * 0.4, 13.4 - a * 2.2)
	shovel.rotation_degrees = Vector3(-a * 20.0, 0, 0)
	shovel.visible = true
	# firing zones only clickable through the open door
	for i in range(4):
		controls["fire_zone_%d" % i].enabled = door > 0.45
