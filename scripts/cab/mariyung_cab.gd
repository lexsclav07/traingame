class_name MariyungCab
extends Cab
## Driving cab of a D set driving car, built in car model space
## (cab from the windscreen at z ~0.6 to the rear wall at z = 2.55, floor y = 1.25).
## Layout follows modern NSW EMU practice: central driving position, combined
## traction/brake controller on the left, ETCS DMI and TMS screens ahead.

const FLOOR := 1.25
var console: Node3D
var desk: Node3D
var dmi: CabScreen
var tms: CabScreen
var wipers: Array[Node3D] = []
var cab_light: OmniLight3D
var desk_light: OmniLight3D
var cctv_cam: Camera3D
var cctv_vp: SubViewport
var _cctv_t := 0.0
var ceiling_lamp: StandardMaterial3D


func build(cab_root: Node3D) -> void:
	cab_root.add_child(self)
	var wall := TX.painted(Color(0.8, 0.805, 0.81), 0.55, 0.0, "paint_wear", 2.0, 0.0, "nif_cab_wall")
	var dark := TX.plastic(Color(0.11, 0.115, 0.125), 0.5, 8.0, "nif_cab_dark")
	var desk_mat := TX.plastic(Color(0.19, 0.195, 0.205), 0.62, 8.0, "nif_desk")
	var floor_mat := TX.pbr("rubber_albedo", "rubber_normal", Color(0.8, 0.8, 0.85), 0.85, 0.0, Vector3.ONE * 1.6, false, 1.0, "nif_floor")
	var seat_mat := TX.pbr("fabric_albedo", "fabric_normal", Color(0.22, 0.3, 0.5), 0.95, 0.0, Vector3.ONE * 3.0, false, 1.0, "nif_seat")
	var glass := MU.glass(Color(0.75, 0.8, 0.82, 0.07))
	var steel := TX.metal(Color(0.62, 0.62, 0.64), 0.35, true, 6.0, "nif_steel")
	var black := TX.plastic(Color(0.04, 0.04, 0.045), 0.55, 8.0, "nif_black")
	var rubber := MU.mat(Color(0.03, 0.03, 0.03), 0.8, 0.0, "nif_rubber")

	# ------------------------------------------------------------ shell
	MU.box(self, Vector3(2.9, 0.05, 2.0), Vector3(0, FLOOR - 0.025, 1.55), floor_mat)
	for sx in [-1.0, 1.0]:
		var x: float = sx * 1.43
		MU.box(self, Vector3(0.05, 1.2, 1.9), Vector3(x, FLOOR + 0.6, 1.6), wall)
		MU.box(self, Vector3(0.05, 0.7, 1.9), Vector3(x, 3.6, 1.6), wall)
		MU.box(self, Vector3(0.05, 0.8, 0.6), Vector3(x, 2.85, 0.95), wall)
		MU.box(self, Vector3(0.05, 0.8, 0.35), Vector3(x, 2.85, 2.375), wall)
		MU.box(self, Vector3(0.01, 0.8, 0.95), Vector3(x, 2.85, 1.725), glass)
		# A-pillars
		MU.box(self, Vector3(0.1, 1.95, 0.12), Vector3(sx * 1.36, 3.12, 1.1), dark, Vector3(29.7, 0, 0))
	MU.box(self, Vector3(2.9, 0.05, 1.0), Vector3(0, 3.98, 2.05), wall)
	MU.box(self, Vector3(2.9, 0.25, 0.12), Vector3(0, 3.92, 1.6), dark)                 # windscreen header
	MU.box(self, Vector3(2.9, 2.75, 0.05), Vector3(0, FLOOR + 1.375, 2.575), wall)      # rear wall
	MU.box(self, Vector3(0.75, 2.0, 0.02), Vector3(0.75, FLOOR + 1.0, 2.545), MU.mat(Color(0.7, 0.71, 0.72), 0.5))  # door to saloon
	MU.box(self, Vector3(2.72, 1.94, 0.006), Vector3(0, 3.12, 1.1), glass, Vector3(29.7, 0, 0))   # windscreen
	# wipers
	for wx in [-0.55, 0.45]:
		var pivot := Node3D.new()
		add_child(pivot)
		pivot.position = Vector3(wx, 2.32, 0.68)
		pivot.rotation_degrees = Vector3(29.7, 0, 0)
		var arm := Node3D.new()
		pivot.add_child(arm)
		# arm and blade sit outside the glass
		MU.box(arm, Vector3(0.012, 0.95, 0.01), Vector3(0, 0.48, -0.05), black)
		MU.box(arm, Vector3(0.02, 0.06, 0.02), Vector3(0, 0.02, -0.045), black)
		wipers.append(arm)

	# ------------------------------------------------------------- desk
	MU.box(self, Vector3(2.75, 0.72, 0.45), Vector3(0, FLOOR + 0.36, 0.85), desk_mat)
	MU.box(self, Vector3(0.5, 0.72, 0.5), Vector3(-1.1, FLOOR + 0.36, 1.3), desk_mat)
	MU.box(self, Vector3(0.5, 0.72, 0.5), Vector3(1.1, FLOOR + 0.36, 1.3), desk_mat)
	desk = frame(self, Vector3(0, 1.99, 1.28), Vector3(-82, 0, 0))
	MU.box(desk, Vector3(2.72, 0.48, 0.04), Vector3(0, 0, -0.02), desk_mat)
	console = frame(self, Vector3(0, 2.13, 0.865), Vector3(-54.9, 0, 0))
	MU.box(console, Vector3(2.72, 0.46, 0.04), Vector3(0, 0, -0.02), dark)

	# ----------------------------------------------------- screens (console)
	var sim_ref: MariyungSim = null
	dmi = CabScreen.make(console, "dmi", sim_ref, Vector2i(400, 330), Vector2(0.3, 0.2475), Vector3(-0.42, 0.03, 0.003), Vector3.ZERO)
	tms = CabScreen.make(console, "tms", sim_ref, Vector2i(480, 330), Vector2(0.36, 0.2475), Vector3(0.05, 0.03, 0.003), Vector3.ZERO)
	_cctv(console)
	# bezel keys under the screens
	var dmi_keys := [["dmi_data", "DATA", "ETCS: validate train data (length, max speed, braking)."],
		["dmi_start", "START", "ETCS: Start of Mission. Enters Staff Responsible until the first balise."],
		["dmi_ack", "ACK", "ETCS: acknowledge (e.g. after a trip, once stopped)."]]
	for i in range(3):
		var k: Array = dmi_keys[i]
		button(k[0], "DMI key: " + k[1], console, Vector3(-0.42 + (i - 1) * 0.1, -0.135, 0.004), Vector3.ZERO, Color(0.3, 0.33, 0.38), k[2], 0.011, false, false, k[1])
	var tms_keys := [["tms_status", "STATUS"], ["tms_brakes", "BRAKES"], ["tms_doors", "DOORS"], ["tms_faults", "FAULTS"], ["tms_btest", "BRK TEST"]]
	for i in range(5):
		var k2: Array = tms_keys[i]
		button(k2[0], "TMS key: " + k2[1], console, Vector3(0.05 + (i - 2) * 0.072, -0.135, 0.004), Vector3.ZERO, Color(0.3, 0.33, 0.38),
			"Automatic brake test: stopped, controller in B7/EB, MR above 700 kPa." if k2[0] == "tms_btest" else "Show the TMS %s page." % k2[1].to_lower(), 0.01, false, false, k2[1])
	# gauges on the console ends
	gauge("air", console, Vector3(-0.97, 0.03, 0.01), Vector3.ZERO, 0.07, 0, 1000, 200, 50, "MR / BC", "kPa", [Color(0.85, 0.1, 0.05), Color(0.05, 0.05, 0.05)], Color(0.94, 0.94, 0.92), 1.0)
	gauge("line_v", console, Vector3(0.93, 0.07, 0.01), Vector3.ZERO, 0.05, 0, 2000, 500, 100, "LINE", "V", [Color(0.05, 0.05, 0.05)], Color(0.94, 0.94, 0.92), 1000.0)
	gauge("bat_v", console, Vector3(1.1, 0.07, 0.01), Vector3.ZERO, 0.05, 0, 150, 50, 10, "BATTERY", "V", [Color(0.05, 0.05, 0.05)], Color(0.94, 0.94, 0.92))
	# indicator lamps across the top of the console
	var lamps_def := [["lamp_doors", Color(0.2, 1.0, 0.3), "DOORS CLOSED"], ["lamp_eb", Color(1.0, 0.1, 0.05), "EMERG BRAKE"],
		["lamp_vig", Color(1.0, 0.8, 0.1), "VIGILANCE"], ["lamp_dsd", Color(1.0, 0.3, 0.1), "SAFETY PEDAL"],
		["lamp_brakes", Color(1.0, 0.6, 0.1), "BRAKES ON"], ["lamp_wsp", Color(1.0, 0.6, 0.1), "SLIP/SLIDE"],
		["lamp_comp", Color(0.95, 0.95, 1.0), "COMPRESSOR"], ["lamp_siv", Color(0.95, 0.95, 1.0), "AUX CONV"],
		["lamp_line", Color(0.95, 0.95, 1.0), "LINE VOLTS"], ["lamp_hold", Color(1.0, 0.6, 0.1), "HOLD BRAKE"]]
	for i in range(lamps_def.size()):
		var ld: Array = lamps_def[i]
		lamp(ld[0], console, Vector3(-0.83 + i * 0.185, 0.19, 0.004), Vector3.ZERO, ld[1], ld[2], 0.016, true)

	# --------------------------------------------------- left wing (power)
	var tbc := lever("tbc", "Traction / brake controller", desk, Vector3(-0.72, -0.02, 0.0), Vector3(90, 0, 0), 0.2,
		Vector3(52, 0, 0), Vector3(-78, 0, 0), steel, MU.mat(Color(0.1, 0.1, 0.1), 0.4),
		"Combined power/brake handle. Forward = power P1-P4. Back = brake B1-B7 (blended regenerative + EP friction). Fully back = EB (emergency).", 0.03)
	tbc.min_v = -8.0
	tbc.max_v = 4.0
	tbc.value = -8.0
	tbc.notch_only = true
	tbc.drag_scale = 0.0035
	for k in range(-8, 5):
		tbc.notches.append([float(k), MariyungSim.TBC_LABELS[k]])
	tbc.setup_part(tbc.part)
	for k in range(-8, 5, 2):
		var a := deg_to_rad(52.0 - 78.0 * (k + 8) / 12.0)
		text(MariyungSim.TBC_LABELS[k], desk, Vector3(-0.84, -0.02 - sin(a) * 0.13, 0.002), Vector3.ZERO, 0.00042)
	rotary("direction", "Direction controller", desk, Vector3(-1.02, 0.05, 0.0), Vector3.ZERO, ["R", "N", "F"], 1,
		"Reverse / Neutral / Forward. Only moves at a stand with the controller in brake or coast.", 0.024, 50.0)
	var horn := lever("horn", "Horn", desk, Vector3(-1.16, -0.12, 0.0), Vector3(90, 0, 0), 0.09,
		Vector3(28, 0, 0), Vector3(-56, 0, 0), steel, MU.mat(Color(0.15, 0.15, 0.15), 0.4), "Push forward for the high tone, pull back for the low tone.", 0.018)
	horn.min_v = -1.0
	horn.max_v = 1.0
	horn.value = 0.0
	horn.spring_to = 0.0
	horn.setup_part(horn.part)
	horn.custom_state = func(): return "HIGH" if horn.value > 0.5 else ("LOW" if horn.value < -0.5 else "off")
	button("door_rel_left", "Door release LEFT", desk, Vector3(-1.0, 0.17, 0.0), Vector3.ZERO, Color(1.0, 0.75, 0.1),
		"Releases the doors on the LEFT side (only at a stand). Check the platform side first!", 0.017, false, true, "L DOORS")

	# ------------------------------------------------------ centre of desk
	rotary("master_key", "Master key switch", desk, Vector3(-0.38, 0.1, 0.0), Vector3.ZERO, ["OFF", "ON"], 0,
		"Activates this cab: control circuits, TMS, ETCS and the direction controller.", 0.02, 70.0, true)
	button("vigilance", "Vigilance acknowledge", desk, Vector3(-0.12, -0.08, 0.0), Vector3.ZERO, Color(1.0, 0.85, 0.15),
		"Press to reset the vigilance timer when the lamp flashes / buzzer sounds.", 0.026, false, false, "VIGILANCE")
	mushroom("estop", "Emergency stop", desk, Vector3(0.3, 0.1, 0.0), Vector3.ZERO,
		"Opens the safety loop: emergency brakes on the whole train. Click again to pull it back out.")
	button("eb_reset", "Emergency brake reset", desk, Vector3(0.5, 0.15, 0.0), Vector3.ZERO, Color(0.2, 0.45, 0.95),
		"After an emergency brake: stop, controller in EB, then press to reset.", 0.015, false, false, "EB RESET")

	# ------------------------------------------------------- right wing
	button("doors_close", "Close doors", desk, Vector3(0.72, 0.17, 0.0), Vector3.ZERO, Color(0.9, 0.9, 0.9),
		"Closes all doors (with chimes). Traction is interlocked until all doors are closed and locked.", 0.017, false, false, "CLOSE")
	button("door_rel_right", "Door release RIGHT", desk, Vector3(1.12, 0.17, 0.0), Vector3.ZERO, Color(1.0, 0.75, 0.1),
		"Releases the doors on the RIGHT side (only at a stand).", 0.017, false, true, "R DOORS")
	button("pan_up", "Pantograph UP", desk, Vector3(0.66, 0.02, 0.0), Vector3.ZERO, Color(0.3, 0.9, 0.4),
		"Raises the pantographs. If the main reservoir is empty, the battery auxiliary compressor charges the pantograph reservoir first.", 0.016, false, true, "PAN UP")
	button("pan_down", "Pantograph DOWN", desk, Vector3(0.79, 0.02, 0.0), Vector3.ZERO, Color(0.85, 0.85, 0.85),
		"Lowers the pantographs (opens the HSCB).", 0.016, false, false, "PAN DN")
	button("hscb_close", "HSCB close", desk, Vector3(0.95, 0.02, 0.0), Vector3.ZERO, Color(0.3, 0.9, 0.4),
		"Closes the high speed circuit breaker: 1500 V to the traction inverters and auxiliary converter.", 0.016, false, true, "HSCB ON")
	button("hscb_open", "HSCB open", desk, Vector3(1.08, 0.02, 0.0), Vector3.ZERO, Color(0.85, 0.85, 0.85),
		"Opens the high speed circuit breaker.", 0.016, false, false, "HSCB OFF")
	button("park_apply", "Parking brake APPLY", desk, Vector3(0.66, -0.12, 0.0), Vector3.ZERO, Color(1.0, 0.2, 0.15),
		"Applies the spring parking brakes.", 0.016, false, true, "PARK ON")
	button("park_release", "Parking brake RELEASE", desk, Vector3(0.79, -0.12, 0.0), Vector3.ZERO, Color(0.3, 0.9, 0.4),
		"Releases the spring parking brakes (needs 500 kPa main reservoir).", 0.016, false, true, "PARK OFF")
	rotary("headlights", "Headlights", desk, Vector3(0.97, -0.13, 0.0), Vector3.ZERO, ["OFF", "MARK", "DIM", "BRT"], 0,
		"Marker lights / dipped / full headlights.", 0.02, 45.0)
	rotary("wipers", "Windscreen wipers", desk, Vector3(1.17, -0.13, 0.0), Vector3.ZERO, ["OFF", "INT", "SLOW", "FAST"], 0, "", 0.02, 45.0)
	button("washer", "Windscreen washer", desk, Vector3(1.25, 0.03, 0.0), Vector3.ZERO, Color(0.3, 0.5, 0.95), "", 0.012, false, false, "WASH")

	# ------------------------------------------------- driver's safety pedal
	var ped := _host(self, Vector3(-0.15, FLOOR + 0.06, 1.1), Vector3.ZERO)
	_register(ped, "dsd", "Driver's safety pedal (deadman)", "Must be held down whenever moving or in power, otherwise the brakes apply after 2.5 s. Key F toggles your foot on/off.")
	ped.kind = CabControl.Kind.TOGGLE
	ped.labels = ["RELEASED", "HELD DOWN"]
	var pp := Node3D.new()
	ped.add_child(pp)
	MU.box(pp, Vector3(0.3, 0.025, 0.24), Vector3(0, 0.02, 0.0), MU.mat(Color(0.12, 0.12, 0.12), 0.8))
	pp.rotation_degrees = Vector3(18, 0, 0)
	ped.rot_axis = Vector3(-14, 0, 0)
	ped.setup_part(pp)
	ped.pick_extent = Vector3(0.16, 0.06, 0.13)

	# ------------------------------------------------------- overhead panel
	var ov := frame(self, Vector3(0.6, 3.82, 1.75), Vector3(40, 0, 0))
	MU.box(ov, Vector3(1.0, 0.22, 0.03), Vector3(0, 0, -0.015), dark)
	toggle("cab_light", "Cab light", ov, Vector3(-0.38, 0.02, 0.0), Vector3.ZERO, ["OFF", "ON"], 0)
	rotary("desk_light", "Desk / instrument lights", ov, Vector3(-0.22, 0.02, 0.0), Vector3.ZERO, ["0", "1", "2", "3"], 1, "", 0.016, 40.0)
	toggle("demister", "Windscreen demister", ov, Vector3(-0.06, 0.02, 0.0), Vector3.ZERO, ["OFF", "ON"], 0)
	toggle("hvac", "Saloon air-conditioning", ov, Vector3(0.08, 0.02, 0.0), Vector3.ZERO, ["OFF", "ON"], 1, "Saloon HVAC (load on the auxiliary converter).")
	toggle("saloon_lights", "Saloon lights", ov, Vector3(0.22, 0.02, 0.0), Vector3.ZERO, ["OFF", "ON"], 1)
	button("pa", "PA chime", ov, Vector3(0.38, 0.02, 0.0), Vector3.ZERO, Color(0.85, 0.85, 0.85), "Passenger announcement chime.", 0.013, false, false, "PA")

	# ----------------------------------------------- rear panel (behind seat)
	var rp := frame(self, Vector3(-0.45, 0, 2.54), Vector3(0, 180, 0))
	MU.box(rp, Vector3(1.4, 1.2, 0.02), Vector3(0, 2.55, -0.01), MU.mat(Color(0.3, 0.32, 0.35), 0.5, 0.2))
	text("BATTERY ISOLATION", rp, Vector3(0.45, 3.06, 0.004), Vector3.ZERO, 0.0004)
	rotary("battery", "Battery isolating switch", rp, Vector3(0.45, 2.88, 0.0), Vector3.ZERO, ["OFF", "ON"], 0,
		"Connects the 110 V battery to the train. The first switch in a cold start.", 0.035, 90.0)
	text("CIRCUIT BREAKERS", rp, Vector3(-0.2, 3.06, 0.004), Vector3.ZERO, 0.0004)
	var mcbs := [["mcb_control", "Cab control"], ["mcb_tms", "TMS"], ["mcb_etcs", "ETCS"], ["mcb_pan", "Pantograph control"],
		["mcb_hscb", "HSCB control"], ["mcb_comp", "Main compressor"], ["mcb_doors", "Door control"], ["mcb_lights", "Head / tail lights"],
		["mcb_wipers", "Wipers"], ["mcb_hvac", "Saloon HVAC"], ["mcb_radio", "Train radio"], ["mcb_cctv", "CCTV"]]
	for i in range(mcbs.size()):
		var col := i % 4
		var row := i / 4
		var m: Array = mcbs[i]
		var t := toggle(m[0], "Circuit breaker: " + m[1], rp, Vector3(-0.5 + col * 0.15, 2.85 - row * 0.2, 0.0), Vector3.ZERO, ["OFF", "ON"], 1,
			"Miniature circuit breaker. If a system won't work, check its breaker.")
		text(m[1], rp, Vector3(-0.5 + col * 0.15, 2.785 - row * 0.2, 0.004), Vector3.ZERO, 0.00036)
		t.name = m[0]

	# ---------------------------------------------------------- seat & lights
	_seat(seat_mat, dark, steel)
	_details(wall, dark, black, rubber, steel, glass)
	cab_light = OmniLight3D.new()
	cab_light.light_color = Color(1.0, 0.97, 0.9)
	cab_light.omni_range = 3.0
	cab_light.light_energy = 0.0
	add_child(cab_light)
	cab_light.position = Vector3(0, 3.8, 1.9)
	desk_light = OmniLight3D.new()
	desk_light.light_color = Color(0.85, 0.9, 1.0)
	desk_light.omni_range = 1.2
	desk_light.light_energy = 0.0
	add_child(desk_light)
	desk_light.position = Vector3(0, 2.45, 1.2)
	add_fill(Vector3(0, 3.5, 0.95), 3.6, 2.2, Color(1.0, 0.97, 0.92))
	add_fill(Vector3(0, 2.0, 1.9), 2.4, 0.9, Color(1.0, 0.96, 0.9))

	# ---------------------------------------------------------------- views
	add_view("Driver (seated)", Vector3(0.0, 2.55, 1.88), 0.0, -9.0)
	add_view("Rear panel (battery & breakers)", Vector3(-0.45, 2.78, 1.45), 180.0, -10.0)
	add_view("Standing", Vector3(0.45, 2.95, 1.7), 8.0, -16.0)
	add_view("Side window (left)", Vector3(-1.05, 2.75, 1.75), 72.0, -8.0)
	add_view("Side window (right)", Vector3(1.05, 2.75, 1.75), -72.0, -8.0)


## Driver's seat: moulded cushion and backrest in moquette, headrest,
## armrests, gas-strut pedestal on a swivel base.
func _seat(fabric: Material, dark: Material, steel: Material) -> void:
	var z0 := 1.95
	var cush := []
	for i in range(6):
		var t := float(i) / 5.0
		var z := z0 - 0.26 + t * 0.52
		var bulge := sin(t * PI) * 0.025
		cush.append(MU.rounded_ring(0.27 + bulge * 0.5, FLOOR + 0.5, FLOOR + 0.6 + bulge, 0.05, z, 3))
	add_child(MU.loft(cush, fabric))
	# backrest tilted back ~10 degrees
	var back := Node3D.new()
	add_child(back)
	back.position = Vector3(0, FLOOR + 0.62, z0 + 0.25)
	back.rotation_degrees = Vector3(10, 0, 0)
	var br := []
	for i in range(5):
		var t := float(i) / 4.0
		var y := t * 0.66
		var hw := 0.26 - 0.03 * t + sin(t * PI) * 0.01
		var r := PackedVector3Array()
		for k in range(16):
			var a := TAU * k / 16.0
			r.append(Vector3(cos(a) * hw, y, 0.035 - sin(a) * (0.06 + 0.012 * sin(t * PI))))
		br.append(r)
	var bm := MU.loft(br, fabric)
	back.add_child(bm)
	MU.box(back, Vector3(0.3, 0.18, 0.1), Vector3(0, 0.8, 0.06), fabric)
	for sx in [-1.0, 1.0]:
		MU.box(back, Vector3(0.025, 0.12, 0.025), Vector3(sx * 0.08, 0.7, 0.06), steel)
		# armrests
		MU.box(self, Vector3(0.07, 0.05, 0.36), Vector3(sx * 0.33, FLOOR + 0.82, z0 + 0.02), dark)
		MU.box(self, Vector3(0.04, 0.24, 0.04), Vector3(sx * 0.33, FLOOR + 0.7, z0 + 0.17), dark)
	MU.box(back, Vector3(0.5, 0.6, 0.02), Vector3(0, 0.32, 0.105), dark)
	# pedestal
	MU.cyl(self, 0.045, 0.32, Vector3(0, FLOOR + 0.33, z0), steel, Vector3.ZERO, 10)
	MU.cyl(self, 0.07, 0.18, Vector3(0, FLOOR + 0.1, z0), dark, Vector3.ZERO, 10)
	MU.box(self, Vector3(0.5, 0.03, 0.42), Vector3(0, FLOOR + 0.475, z0), dark)
	for k in range(5):
		var a := TAU * k / 5.0
		MU.box(self, Vector3(0.05, 0.03, 0.28), Vector3(sin(a) * 0.14, FLOOR + 0.02, z0 + cos(a) * 0.14), dark, Vector3(0, rad_to_deg(a), 0))


## Non-interactive fittings that make the cab read as a real place.
func _details(wall: Material, dark: Material, black: Material, rubber: Material, steel: Material, glass: Material) -> void:
	# padded edge along the driver's side of the desk and a footrest
	MU.cyl(self, 0.028, 2.6, Vector3(0, 1.952, 1.535), black, Vector3(0, 0, 90), 12)
	MU.cyl(self, 0.018, 0.7, Vector3(0, FLOOR + 0.16, 1.2), steel, Vector3(0, 0, 90), 8)    # footrest bar
	MU.box(self, Vector3(0.7, 0.02, 0.18), Vector3(0, FLOOR + 0.13, 1.24), black, Vector3(-20, 0, 0))
	# roller sun blind across the top of the windscreen, pulled down a little
	MU.cyl(self, 0.035, 2.5, Vector3(0, 3.76, 1.56), dark, Vector3(0, 0, 90), 12)
	MU.box(self, Vector3(2.4, 0.16, 0.004), Vector3(0, 3.68, 1.45), MU.glass(Color(0.05, 0.05, 0.06, 0.72)), Vector3(29.7, 0, 0))
	MU.box(self, Vector3(2.4, 0.015, 0.012), Vector3(0, 3.6, 1.405), black, Vector3(29.7, 0, 0))
	# rubber seals round the windscreen and side windows
	for sx in [-1.0, 1.0]:
		var x: float = sx * 1.41
		for zz in [1.25, 2.2]:
			MU.box(self, Vector3(0.025, 0.82, 0.03), Vector3(x, 2.85, zz), rubber)
		for yy in [2.45, 3.25]:
			MU.box(self, Vector3(0.025, 0.03, 0.98), Vector3(x, yy, 1.725), rubber)
		# grab handle by each side window
		MU.cyl(self, 0.012, 0.35, Vector3(sx * 1.38, 2.85, 2.32), steel, Vector3.ZERO, 8)
	# ceiling light panel and air-conditioning diffusers
	ceiling_lamp = MU.lamp(Color(1.0, 0.97, 0.9), 0.0)
	ceiling_lamp.albedo_color = Color(0.85, 0.85, 0.83)
	MU.box(self, Vector3(1.1, 0.02, 0.4), Vector3(0, 3.945, 2.1), ceiling_lamp)
	MU.box(self, Vector3(1.16, 0.015, 0.46), Vector3(0, 3.95, 2.1), dark)
	for sx in [-1.0, 1.0]:
		MU.box(self, Vector3(0.5, 0.012, 0.12), Vector3(sx * 0.95, 3.945, 2.2), dark)
		for k in range(5):
			MU.box(self, Vector3(0.46, 0.006, 0.008), Vector3(sx * 0.95, 3.937, 2.16 + k * 0.02), black)
	# rear wall: saloon door window and handle, fire extinguisher, notice holder
	MU.box(self, Vector3(0.4, 0.5, 0.004), Vector3(0.75, FLOOR + 1.55, 2.528), MU.mat(Color(0.04, 0.045, 0.05), 0.05, 0.0, "nif_door_glass"))
	MU.box(self, Vector3(0.46, 0.56, 0.006), Vector3(0.75, FLOOR + 1.55, 2.531), rubber)
	MU.box(self, Vector3(0.03, 0.22, 0.04), Vector3(0.45, FLOOR + 1.05, 2.52), steel)
	MU.cyl(self, 0.075, 0.48, Vector3(1.22, FLOOR + 0.4, 2.44), MU.mat(Color(0.75, 0.06, 0.04), 0.35, 0.1, "extinguisher"), Vector3.ZERO, 14)
	MU.cyl(self, 0.03, 0.08, Vector3(1.22, FLOOR + 0.68, 2.44), black, Vector3.ZERO, 8)
	MU.box(self, Vector3(0.1, 0.03, 0.08), Vector3(1.22, FLOOR + 0.6, 2.5), steel)
	MU.box(self, Vector3(0.3, 0.42, 0.015), Vector3(1.05, FLOOR + 1.45, 2.54), MU.mat(Color(0.92, 0.92, 0.88), 0.7))
	text("TRAIN NOTICES", self, Vector3(1.05, FLOOR + 1.62, 2.53), Vector3(0, 180, 0), 0.0003, Color(0.1, 0.1, 0.1))
	# radio handset on its cradle (right wing)
	MU.box(self, Vector3(0.12, 0.05, 0.22), Vector3(1.18, FLOOR + 0.75, 1.42), black)
	MU.box(self, Vector3(0.05, 0.045, 0.2), Vector3(1.18, FLOOR + 0.79, 1.42), dark)
	# side walls under the windows: moulded trim with a coat hook
	for sx in [-1.0, 1.0]:
		MU.box(self, Vector3(0.04, 0.06, 1.9), Vector3(sx * 1.4, FLOOR + 1.2, 1.6), dark)
	MU.cyl(self, 0.01, 0.06, Vector3(-1.38, 3.2, 2.45), steel, Vector3(0, 0, 90), 6)


func _cctv(parent: Node3D) -> void:
	cctv_vp = SubViewport.new()
	cctv_vp.size = Vector2i(320, 200)
	cctv_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	cctv_vp.world_3d = null
	parent.add_child(cctv_vp)
	cctv_cam = Camera3D.new()
	cctv_cam.fov = 50.0
	cctv_cam.far = 400.0
	cctv_vp.add_child(cctv_cam)
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.28, 0.175)
	mi.mesh = qm
	var m := StandardMaterial3D.new()
	m.albedo_texture = cctv_vp.get_texture()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	parent.add_child(mi)
	mi.position = Vector3(0.6, 0.03, 0.003)
	text("CCTV  LEFT", parent, Vector3(0.6, 0.13, 0.004), Vector3.ZERO, 0.00028)


func bind(sim: MariyungSim) -> void:
	dmi.sim = sim
	tms.sim = sim


func update_visuals(sim: MariyungSim, delta: float) -> void:
	if dmi.sim == null:
		bind(sim)
	gauges["air"].set_value(0, sim.mr)
	gauges["air"].set_value(1, sim.bc[0])
	gauges["line_v"].set_value(0, sim.line_v)
	gauges["bat_v"].set_value(0, sim.bat_v)
	var pw := sim.bat_v > 80.0
	set_lamp("pan_up", pw and sim.pan_pos > 0.97, 0.0 if sim.pan_pos > 0.97 or not sim.pan_cmd else 0.6)
	set_lamp("hscb_close", pw and sim.hscb)
	set_lamp("park_apply", pw and sim.park_applied)
	set_lamp("park_release", pw and not sim.park_applied)
	set_lamp("door_rel_left", pw and sim.rel_l)
	set_lamp("door_rel_right", pw and sim.rel_r)
	set_lamp("lamp_doors", sim.cab_active and sim.doors_locked)
	set_lamp("lamp_eb", pw and (sim.eb_latched or int(round(val("tbc"))) == -8), 0.0 if not sim.eb_latched else 0.5)
	set_lamp("lamp_vig", sim.vig_stage >= 1, 0.4 if sim.vig_stage == 1 else 0.0)
	set_lamp("lamp_dsd", sim.dsd_t > 0.2, 0.3)
	set_lamp("lamp_brakes", sim.cab_active and sim.bc[0] > 40.0)
	set_lamp("lamp_wsp", sim.wsp or sim.slip, 0.25)
	set_lamp("lamp_comp", sim.comp_on or sim.aux_comp)
	set_lamp("lamp_siv", sim.siv_on)
	set_lamp("lamp_line", pw and sim.line_v > 1000.0)
	set_lamp("lamp_hold", sim.holding)
	var desk_level := int(val("desk_light"))
	for id in lamps:
		var m: StandardMaterial3D = lamps[id]
		if m.emission_energy_multiplier > 0.0 and not flashing.has(id):
			m.emission_energy_multiplier = 1.2 + desk_level * 0.5
	cab_light.light_energy = 1.2 if (val("cab_light") > 0.5 and pw) else 0.0
	ceiling_lamp.emission_energy_multiplier = 2.5 if cab_light.light_energy > 0.0 else 0.0
	desk_light.light_energy = desk_level * 0.15 if sim.cab_active else 0.0
	# wipers sweep across the glass
	for i in range(wipers.size()):
		# parked flat along the bottom of the screen, sweeping up and over when running
		var a := 0.5 - 0.5 * cos(sim.wiper_phase * TAU)
		wipers[i].rotation_degrees = Vector3(0, 0, 86.0 - a * 120.0)
	# CCTV: view back along the left side of the train, a few frames a second
	_cctv_t += delta
	if _cctv_t > 0.15 and sim.cab_active and val("mcb_cctv") > 0.5:
		_cctv_t = 0.0
		var car := sim.train.vehicles[0]
		var t := car.global_transform
		cctv_cam.global_transform = Transform3D(t.basis, t * Vector3(-1.75, 4.0, -8.0)).looking_at(t * Vector3(-1.6, 1.5, 30.0), t.basis.y)
		cctv_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
