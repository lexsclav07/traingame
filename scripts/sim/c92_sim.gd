class_name C92Sim
extends TrainSim
## Two Pacific National 92 class (UGL C44aci, GE 7FDL-16, AC traction) working
## in multiple on a Hunter Valley coal train.
##
## Published figures used: 3,184 kW traction power, 535 kN tractive effort,
## 139 t, 115 km/h (the coal train itself is limited to 80 km/h), 13,500 L
## coal-service fuel tank; wagons 23 t tare / 120 t gross.
## Each unit has its own battery, breakers, engine, compressor, brake valve
## and handbrake. Either cab can control the train: the one with its CONTROL
## switch on drives, and the other unit follows through the MU jumper if its
## engine control switch is in RUN, its reverser is off and its brake valve is
## cut out (TRAIL). Start-up and set-up follow general GE / Australian
## practice; the exact (unpublished) 92 class procedures may differ in detail.
##
## Air brake: one brake-pipe cell per vehicle, solved implicitly so the
## application and release travel down the train; every wagon has a triple
## valve with auxiliary and emergency reservoirs and an empty/load device.

const PFX := ["l_", "t_"]
const TE_MAX := 535000.0             # N per unit, starting
const P_RAIL := 3184000.0            # W per unit at notch 8 (traction)
const NOTCH_P := [0.0, 0.05, 0.12, 0.21, 0.32, 0.46, 0.61, 0.79, 1.0]
const NOTCH_RPM := [440.0, 440.0, 535.0, 620.0, 710.0, 790.0, 880.0, 960.0, 1050.0]
const IDLE_RPM := 440.0
const DB_F_MAX := 450000.0           # N per unit
const DB_P_MAX := 4000000.0          # W per unit (grid capacity)
const LOCO_BC_MAX := 450.0           # kPa
const LOCO_BRAKE_F := 232000.0       # N per unit at 450 kPa (about 17 % of its weight)
const BP_FULL := 500.0               # kPa
const MR_CUT_IN := 860.0
const MR_CUT_OUT := 1000.0
const FUEL_FULL := 13500.0           # L
const TRAIN_MAX := 80.0              # km/h, loaded coal trains
const P_ATM := 101.3
# air volumes (litres) and flows (free-air litres per second)
const V_MR := 1000.0
const V_BP_LOCO := 30.0
const V_BP_WAGON := 20.0
const V_AR := 41.0
const V_ER_W := 57.0
const V_BC := 16.0
const G_LINK := 24.0                 # brake pipe conductance between vehicles
const G_RELAY := 3.0
const Q_RELAY_MAX := 60.0
const G_EXHAUST := 4.0
const G_EMERG := 30.0
const G_LEAK := 0.0004
const K_SRV := 2.0
const COMP_FLOW := 70.0              # compressor at full engine speed
const AUTO_LABELS := {0.0: "RELEASE", 1.0: "MINIMUM", 5.0: "FULL SERVICE", 6.0: "SUPPRESSION", 7.0: "HANDLE OFF", 8.0: "EMERGENCY"}
const BREAKERS := ["cb_control", "cb_local", "cb_fuel", "cb_computer", "cb_excite", "cb_tcc1", "cb_tcc2",
	"cb_comp", "cb_lights", "cb_cabair", "cb_radio", "cb_alerter"]
enum VM { RELEASE, SERVICE, LAP, EMERG }

var n := 0                           # vehicles
var loaded := true
# --- per unit (index 0 = lead / front unit, 1 = second unit) -------------
var soc: Array[float] = [0.85, 0.85]              # battery state of charge
var bat_v: Array[float] = [0.0, 0.0]
var computer: Array[bool] = [false, false]
var boot_t: Array[float] = [-1.0, -1.0]           # computer boot countdown (s)
var fuel_p: Array[float] = [0.0, 0.0]             # fuel pressure (kPa)
var eng: Array[String] = ["stopped", "stopped"]    # stopped / cranking / running / stopping
var rpm: Array[float] = [0.0, 0.0]
var crank_t: Array[float] = [0.0, 0.0]
var water_t: Array[float] = [20.0, 20.0]
var oil_p: Array[float] = [0.0, 0.0]
var turbo: Array[float] = [0.0, 0.0]
var load: Array[float] = [0.0, 0.0]               # engine load 0..1 (sound, smoke)
var black_smoke: Array[float] = [0.0, 0.0]
var te: Array[float] = [0.0, 0.0]                 # N, + = in the direction of travel set by the reverser
var db: Array[float] = [0.0, 0.0]                 # N dynamic braking
var db_blower: Array[float] = [0.0, 0.0]
var mr: Array[float] = [0.0, 0.0]                 # main reservoir kPa
var comp_loaded: Array[bool] = [false, false]
var er: Array[float] = [0.0, 0.0]                 # equalising reservoir of each brake valve
var flow: Array[float] = [0.0, 0.0]               # brake pipe flow at each brake valve (L/min)
var loco_bc: Array[float] = [0.0, 0.0]
var fuel_l: Array[float] = [9600.0, 9400.0]
var slip: Array[bool] = [false, false]
var fan: Array[float] = [0.0, 0.0]
var responds: Array[bool] = [false, false]       # unit takes power / dynamic brake from the controlling cab
var why_not: Array[String] = ["", ""]              # why a unit is not loading
var cabinet := {}                    # door id -> 1 open / 0 closed
var start_attempts: Array[int] = [0, 0]
var cab_temp: Array[float] = [25.0, 25.0]         # cab air temperature (C)
var radio_ok: Array[bool] = [false, false]
var _radio_t: Array[float] = [0.0, 0.0]
# --- train ----------------------------------------------------------------
var ctrl := -1                       # controlling cab (unit index) or -1
var mu_link := true
var bp: PackedFloat32Array           # brake pipe per vehicle (kPa)
var ar: PackedFloat32Array           # auxiliary reservoir
var erw: PackedFloat32Array          # emergency reservoir
var bc: PackedFloat32Array           # brake cylinder (wagons; locos' valve output)
var vmode: PackedInt32Array
var bp_prev: PackedFloat32Array
var cap: PackedFloat32Array          # free-air litres per kPa of each brake pipe cell
var f_ref: PackedFloat32Array        # wagon brake force at 360 kPa
var emerg_vent: PackedFloat32Array   # wagon emergency valves venting the pipe
var pcs_open := false
var pcs_reason := ""
var _pcs_t := 0.0
var penalty := false
var alerter_t := 0.0
var alerter_warn := false
var brake_test := 0                  # 0 not done, 1 reduction seen at the rear, 2 released again
var _bt_rear_ref := 0.0
var horn := 0.0
var ditch_flash := 0.0
var wiper_phase: Array[float] = [0.0, 0.0]
var screen_page: Array[int] = [0, 0]            # status display: 0 engine, 1 air, 2 alarms
var alarms: Array[String] = []
var _said := {}
var _warned_hb := false


func max_speed_kmh() -> float:
	return TRAIN_MAX


# ================================================================== set-up
func setup(t: Train, c: Cab, start_state: int) -> void:
	train = t
	cab = c
	route_units = "metric"
	n = t.vehicles.size()
	loaded = GameSettings.coal_loaded
	bp.resize(n)
	ar.resize(n)
	erw.resize(n)
	bc.resize(n)
	vmode.resize(n)
	bp_prev.resize(n)
	cap.resize(n)
	f_ref.resize(n)
	emerg_vent.resize(n)
	for i in range(n):
		var veh := t.vehicles[i]
		cap[i] = (V_BP_LOCO if i < 2 else V_BP_WAGON) / P_ATM
		var gross := veh.total_mass()
		# retarding force at 360 kPa: about 4 % of a loaded wagon's weight; the
		# empty/load valve cuts the cylinder pressure on an empty wagon
		f_ref[i] = 0.042 * 120000.0 * 9.81 * (1.0 if veh.mass_load > 1000.0 else 0.3) if i >= 2 else 0.0
		if i >= 2 and gross < 1.0:
			f_ref[i] = 0.0
	for id in cab.controls:
		(cab.controls[id] as CabControl).changed.connect(_on_control)
	var amb := _ambient()
	water_t = [amb, amb]
	cab_temp = [amb + 3.0, amb + 3.0]
	match start_state:
		GameSettings.StartState.COLD:
			_cold()
		GameSettings.StartState.PREP:
			_warm(false)
		_:
			_warm(true)
	for i in range(n):
		bp_prev[i] = bp[i]


func _ambient() -> float:
	var tod: String = GameSettings.time_of_day
	return {"day": 25.0, "dusk": 19.0, "night": 14.0}.get(tod, 22.0) - {"rain": 4.0, "fog": 6.0}.get(weather, 0.0)


func _cold() -> void:
	for u in range(2):
		var p: String = PFX[u]
		_setc(p + "bat_switch", 0)
		for b in BREAKERS:
			_setc(p + b, 0)
		_setc(p + "ecs", 0)
		_setc(p + "handbrake", 1.0)
		_setc(p + "reverser", 1)
		_setc(p + "throttle", 0)
		_setc(p + "dynbrake", 0)
		_setc(p + "brake_mode", 0)          # both brake valves left cut in (LEAD)
		for s in ["sw_control", "sw_engine_run", "sw_gen_field", "markers", "cab_light", "gauge_light", "walkway_lights"]:
			_setc(p + s, 0)
		_setc(p + "headlights", 0)
		_setc(p + "ditch", 0)
		_setc(p + "wipers", 0)
	# the units have been coupled but not yet connected up: the hoses' cocks
	# closed and the MU jumper still in its stowage socket
	for ck in ["l_bp_cock", "t_bp_cock", "l_mr_cock", "t_mr_cock", "mu_jumper"]:
		_setc(ck, 0)
	_setc("l_auto_brake", 5.0)
	_setc("l_ind_brake", 1.0)
	_setc("t_auto_brake", 7.0)
	_setc("t_ind_brake", 0.0)
	soc = [0.82, 0.8]
	for i in range(n):
		bp[i] = 0.0
		ar[i] = 0.0
		erw[i] = 0.0
		bc[i] = 0.0
		vmode[i] = VM.RELEASE


## Prepared (engines running, air up, handbrakes still on) or ready to drive.
func _warm(ready: bool) -> void:
	for u in range(2):
		var p: String = PFX[u]
		_setc(p + "bat_switch", 1)
		for b in BREAKERS:
			_setc(p + b, 1)
		_setc(p + "ecs", 1)
		_setc(p + "handbrake", 0.0 if ready else 1.0)
		_setc(p + "throttle", 0)
		_setc(p + "dynbrake", 0)
		eng[u] = "running"
		rpm[u] = IDLE_RPM
		fuel_p[u] = 380.0
		oil_p[u] = 260.0
		water_t[u] = 74.0
		computer[u] = true
		boot_t[u] = 0.0
		bat_v[u] = 76.0
		mr[u] = 950.0
		soc[u] = 0.95
		cab_temp[u] = 22.0
		radio_ok[u] = true
		_radio_t[u] = 10.0
	# lead set up to drive, second unit trailing
	_setc("l_brake_mode", 0)
	_setc("t_brake_mode", 1)
	_setc("t_reverser", 1)
	_setc("t_auto_brake", 7.0)
	_setc("t_ind_brake", 0.0)
	_setc("l_reverser", 2 if ready else 1)
	_setc("l_auto_brake", 0.0 if ready else 5.0)
	_setc("l_ind_brake", 1.0)
	for s in ["sw_control", "sw_engine_run", "sw_gen_field"]:
		_setc("l_" + s, 1 if ready else 0)
	_setc("l_headlights", 2 if ready else 0)
	_setc("l_ditch", 1 if ready else 0)
	_setc("l_markers", 1 if ready else 0)
	_setc("l_gauge_light", 1)
	var red := 0.0 if ready else 150.0
	er = [BP_FULL - red, BP_FULL - red]
	for i in range(n):
		bp[i] = BP_FULL - red
		ar[i] = bp[i]
		erw[i] = BP_FULL
		vmode[i] = VM.RELEASE if ready else VM.LAP
		bc[i] = 0.0 if ready else 355.0
	loco_bc = [LOCO_BC_MAX, LOCO_BC_MAX]
	brake_test = 2 if ready else 0


# ================================================================ helpers
func _setc(id: String, v: float) -> void:
	var ctl := cab.c(id)
	if ctl:
		ctl.set_value(v)


func _v(id: String) -> float:
	return cab.val(id)


func _on(id: String) -> bool:
	return cab.val(id) > 0.5


func _u(u: int, id: String) -> float:
	return cab.val(PFX[u] + id)


func _uon(u: int, id: String) -> bool:
	return cab.val(PFX[u] + id) > 0.5


func _say(key: String, t: String, kind := "info") -> void:
	if _said.has(key):
		return
	_said[key] = true
	notify(t, kind)


func _unsay(key: String) -> void:
	_said.erase(key)


func unit_name(u: int) -> String:
	return ["front unit", "second unit"][u]


func is_running(u: int) -> bool:
	return eng[u] == "running"


## Power available on a unit's control circuits.
func _powered(u: int) -> bool:
	return bat_v[u] > 40.0


func _on_control(ctl: CabControl) -> void:
	var id := ctl.id
	if id.ends_with("_door"):
		cabinet[id] = ctl.value
	# any use of the controlling cab's desk resets the alerter
	if ctrl >= 0 and id.begins_with(PFX[ctrl]) and not id.begins_with(PFX[ctrl] + "cb_") and not id.ends_with("_door"):
		alerter_t = 0.0
		if alerter_warn and not penalty:
			alerter_warn = false
	var u := 0 if id.begins_with("l_") else (1 if id.begins_with("t_") else -1)
	var short := id.substr(2) if u >= 0 else id
	var pressed := ctl.value > 0.5
	match short:
		"engine_stop":
			if pressed and eng[u] in ["running", "cranking"]:
				eng[u] = "stopping"
				notify("%s: engine stopping." % unit_name(u).capitalize())
		"efco":
			if pressed:
				for k in range(2):
					if eng[k] in ["running", "cranking"]:
						eng[k] = "stopping"
				notify("Emergency fuel cut-off: both engines shut down. Pull the button out to reset it.", "warn")
		"scr_engine", "scr_air", "scr_alarms":
			if pressed:
				screen_page[u] = ["scr_engine", "scr_air", "scr_alarms"].find(short)
		"alerter":
			if pressed:
				alerter_t = 0.0
				alerter_warn = false
		"dynbrake":
			if ctl.value > 0.5 and _u(u, "throttle") > 0.5:
				ctl.set_value(0.0)
				notify("Dynamic brake interlock: close the throttle to IDLE first.")
		"throttle":
			if ctl.value > 0.5 and _u(u, "dynbrake") > 0.5:
				ctl.set_value(0.0)
				notify("Throttle interlock: dynamic brake handle must be OFF.")
		"reverser":
			if absf(train.speed) > 0.3 and ctl.value != 1.0 and ((ctl.value == 0.0 and train.speed > 0.0) or (ctl.value == 2.0 and train.speed < 0.0)):
				notify("Reversing while moving: the unit will not load until stopped.", "warn")
		"brake_mode":
			notify("%s brake valve: %s." % [unit_name(u).capitalize(), "cut in (LEAD)" if ctl.value < 0.5 else "cut out (TRAIL)"])
		"mu_jumper":
			notify("MU jumper %s." % ("connected" if pressed else "stowed: the second unit no longer follows the controlling cab"))
		"bp_cock", "mr_cock":
			if not pressed and absf(train.speed) > 1.0 and short == "bp_cock":
				notify("Angle cock closed with the train moving: brake pipe split!", "warn")


# ================================================================== step
func step(dt: float) -> void:
	sim_time += dt
	_control_stations()
	for u in range(2):
		_electrics(u, dt)
		_engine(u, dt)
	_air(dt)
	_safety(dt)
	_traction(dt)
	_lights(dt)
	_misc(dt)
	_sounds()


## Which cab controls the train, and which units answer it.
func _control_stations() -> void:
	mu_link = _on("mu_jumper")
	var live := []
	for u in range(2):
		live.append(_powered(u) and _uon(u, "cb_control") and _uon(u, "sw_control"))
	ctrl = -1
	if live[0] and live[1]:
		ctrl = 0
		_say("two_ctrl", "Both cabs have CONTROL on: the second unit cannot follow. Switch CONTROL off in the cab you are not driving from.", "warn")
	elif live[0]:
		ctrl = 0
		_unsay("two_ctrl")
	elif live[1]:
		ctrl = 1
		_unsay("two_ctrl")
	for u in range(2):
		var ok := true
		var why := ""
		if ctrl < 0:
			ok = false
			why = "no controlling cab"
		elif u != ctrl:
			if not mu_link:
				ok = false
				why = "MU jumper stowed"
			elif live[u]:
				ok = false
				why = "its own CONTROL switch is on"
			elif int(_u(u, "reverser")) != 1:
				ok = false
				why = "its reverser is not OFF"
		if ok and not is_running(u):
			ok = false
			why = "engine not running"
		if ok and int(_u(u, "ecs")) != 1:
			ok = false
			why = "engine control switch in ISOLATE"
		if ok and not (_uon(u, "cb_excite") and (_uon(u, "cb_tcc1") or _uon(u, "cb_tcc2"))):
			ok = false
			why = "excitation / traction control breaker off"
		if ok and not computer[u]:
			ok = false
			why = "computer not ready"
		responds[u] = ok
		why_not[u] = why


func _electrics(u: int, dt: float) -> void:
	var on := _uon(u, "bat_switch")
	var charging := is_running(u) and _uon(u, "cb_local")
	var drain := 0.0
	if on:
		drain = 0.0008 if computer[u] else 0.0003
		if _uon(u, "cb_lights"):
			drain += 0.0004
		if eng[u] == "cranking":
			drain += 0.0025
	if charging:
		soc[u] = minf(1.0, soc[u] + dt * 0.0006)
	else:
		soc[u] = maxf(0.0, soc[u] - drain * dt * 0.05)
	var rest := 62.0 + soc[u] * 10.0
	var target := 0.0
	if on:
		target = 76.0 if charging else rest
		if eng[u] == "cranking":
			target = rest - 14.0
	bat_v[u] = move_toward(bat_v[u], target, dt * 60.0)
	# computer (locomotive control computer and displays)
	var comp_on := on and _uon(u, "cb_computer") and _uon(u, "cb_control") and bat_v[u] > 50.0
	if comp_on and not computer[u]:
		if boot_t[u] < 0.0:
			boot_t[u] = 25.0
		boot_t[u] -= dt
		if boot_t[u] <= 0.0:
			boot_t[u] = 0.0
			computer[u] = true
			notify("%s: computer and displays ready." % unit_name(u).capitalize())
	elif not comp_on:
		if computer[u] and is_running(u):
			eng[u] = "stopping"
			notify("%s: computer lost power: engine shutting down." % unit_name(u).capitalize(), "warn")
		computer[u] = false
		boot_t[u] = -1.0


func _engine(u: int, dt: float) -> void:
	var p: String = PFX[u]
	var fuel_ok := _powered(u) and _uon(u, "cb_fuel") and _uon(u, "cb_control") and fuel_l[u] > 1.0 and not _on("l_efco") and not _on("t_efco")
	var priming := _uon(u, "fuel_prime") and fuel_ok
	var pump := fuel_ok and (priming or eng[u] in ["running", "cranking"])
	fuel_p[u] = move_toward(fuel_p[u], 380.0 if pump else 0.0, dt * (90.0 if pump else (6.0 if eng[u] == "stopped" else 60.0)))
	match eng[u]:
		"stopped":
			rpm[u] = move_toward(rpm[u], 0.0, dt * 80.0)
			if _uon(u, "engine_start"):
				var why := ""
				if not _powered(u):
					why = "no battery"
				elif not computer[u]:
					why = "computer not ready (control and computer breakers, wait for it to boot)"
				elif int(_u(u, "ecs")) != 0:
					why = "engine control switch must be in ISOLATE to start"
				elif fuel_p[u] < 200.0:
					why = "no fuel pressure: hold FUEL PRIME first"
				elif soc[u] < 0.25:
					why = "battery too flat to crank"
				if why != "":
					_say("start_inhibit%d" % u, "%s: engine start inhibited - %s." % [unit_name(u).capitalize(), why], "warn")
				else:
					_unsay("start_inhibit%d" % u)
					eng[u] = "cranking"
					crank_t[u] = 0.0
					start_attempts[u] += 1
		"cranking":
			# the main alternator motors the engine round on the battery
			crank_t[u] += dt
			rpm[u] = move_toward(rpm[u], 110.0, dt * 70.0)
			if not _uon(u, "engine_start"):
				eng[u] = "stopped"
				notify("%s: start button released before the engine fired." % unit_name(u).capitalize())
			elif crank_t[u] > 4.5 and fuel_p[u] > 200.0:
				eng[u] = "running"
				notify("%s: engine fired, running up to idle." % unit_name(u).capitalize(), "good")
			elif crank_t[u] > 15.0:
				eng[u] = "stopped"
				notify("%s: engine did not start (cranked 15 s). Check fuel pressure." % unit_name(u).capitalize(), "warn")
		"running":
			var target := IDLE_RPM
			if responds[u] and ctrl >= 0:
				var notch := int(round(_u(ctrl, "throttle")))
				if _uon(ctrl, "sw_engine_run") and not pcs_open:
					target = NOTCH_RPM[clampi(notch, 0, 8)]
				# dynamic braking runs the engine up a little for the grid blowers' excitation
				if _u(ctrl, "dynbrake") > 1.5:
					target = maxf(target, 620.0)
			rpm[u] = move_toward(rpm[u], target, dt * (60.0 if target > rpm[u] else 45.0))
			if fuel_p[u] < 120.0 or not fuel_ok:
				eng[u] = "stopping"
				notify("%s: fuel pressure lost - engine shutting down (fuel pump breaker / EFCO / empty tank)." % unit_name(u).capitalize(), "warn")
			if water_t[u] > 104.0:
				eng[u] = "stopping"
				notify("%s: engine shut down on high water temperature." % unit_name(u).capitalize(), "fail")
		"stopping":
			rpm[u] = move_toward(rpm[u], 0.0, dt * 70.0)
			if rpm[u] < 1.0:
				eng[u] = "stopped"
	oil_p[u] = move_toward(oil_p[u], (rpm[u] / 1050.0) * 420.0 if eng[u] != "stopped" else 0.0, dt * 80.0)
	# turbo: lags the load (black smoke while it catches up)
	var want := load[u]
	turbo[u] = move_toward(turbo[u], want, dt * (0.22 if want > turbo[u] else 0.4))
	black_smoke[u] = clampf((want - turbo[u]) * 2.5, 0.0, 1.0)
	if eng[u] == "cranking" and crank_t[u] > 3.5:
		black_smoke[u] = 0.8
	# cooling water: warms with running and load, fans and shutters above 82 C
	var amb := _ambient()
	var heat := 0.0
	if is_running(u):
		heat = 0.04 + load[u] * 0.45
	var cool := (water_t[u] - amb) * (0.0016 + fan[u] * 0.012)
	water_t[u] += (heat - cool) * dt
	fan[u] = move_toward(fan[u], clampf((water_t[u] - 82.0) / 10.0, 0.0, 1.0) if is_running(u) else 0.0, dt * 0.3)
	# fuel burn: about 0.21 kg/kWh at full power, 25 L/h at idle
	if is_running(u):
		var kw := 60.0 + load[u] * 3300.0 + db_blower[u] * 300.0
		fuel_l[u] = maxf(0.0, fuel_l[u] - kw * 0.25 / 3600.0 * dt)


# ================================================================== air
func _air(dt: float) -> void:
	# compressors (engine driven, unloaded by the governor), MR equalising pipe
	for u in range(2):
		var running := is_running(u) and _uon(u, "cb_comp")
		if mr[u] < MR_CUT_IN:
			comp_loaded[u] = running
		elif mr[u] > MR_CUT_OUT:
			comp_loaded[u] = false
		if not running:
			comp_loaded[u] = false
		if comp_loaded[u]:
			mr[u] += COMP_FLOW * (rpm[u] / 1050.0) / (V_MR / P_ATM) * dt
		if _uon(u, "dead_engine") and bp[u] > mr[u] + 5.0:
			# dead engine cock: the main reservoir fills from the brake pipe
			var q := 0.4 * (bp[u] - mr[u])
			mr[u] += q / (V_MR / P_ATM) * dt
			bp[u] -= q / cap[u] * dt
		mr[u] = maxf(0.0, mr[u] - 0.004 * mr[u] * dt / 60.0)
	var mr_link := _on("l_mr_cock") and _on("t_mr_cock")
	if mr_link:
		var q := 1.5 * (mr[0] - mr[1])
		var c := V_MR / P_ATM
		mr[0] -= q / c * dt
		mr[1] += q / c * dt
	# brake valves: equalising reservoir follows the automatic brake handle
	var sources := []          # [cell, G, p_target, unit]
	var emergency_any := false
	for u in range(2):
		flow[u] = 0.0
		var active := _u(u, "brake_mode") < 0.5 and computer[u]
		if not active:
			continue
		var h := _u(u, "auto_brake")
		var target := BP_FULL
		if penalty and u == maxi(ctrl, 0):
			target = BP_FULL - 150.0
		if h >= 7.5:
			emergency_any = true
			target = 0.0
		elif h >= 4.99:
			target = BP_FULL - 150.0          # full service, suppression, handle off
		elif h >= 0.5:
			target = BP_FULL - (50.0 + (h - 1.0) / 4.0 * 100.0)
		er[u] = move_toward(er[u], minf(target, mr[u]), dt * (40.0 if target > er[u] else 22.0))
		if emergency_any and h >= 7.5:
			sources.append([u, G_EMERG, 0.0, -1])
		elif er[u] > bp[u] + 0.3 and mr[u] > bp[u]:
			var g := G_RELAY
			var est: float = g * (er[u] - bp[u])
			if est > Q_RELAY_MAX:
				g *= Q_RELAY_MAX / est
			sources.append([u, g, minf(er[u], mr[u]), u])
		elif bp[u] > er[u] + 0.3:
			sources.append([u, G_EXHAUST, er[u], -2 - u])
	for u in range(2):
		if _u(u, "emerg_valve") > 0.5:
			sources.append([u, G_EMERG, 0.0, -1])
			emergency_any = true
	# implicit brake pipe solve (tridiagonal)
	var links := PackedFloat32Array()
	links.resize(maxi(n - 1, 0))
	for i in range(n - 1):
		links[i] = G_LINK
	if not (_on("l_bp_cock") and _on("t_bp_cock")):
		links[0] = 0.0
	var a := PackedFloat32Array()
	var bdiag := PackedFloat32Array()
	var cc := PackedFloat32Array()
	var d := PackedFloat32Array()
	a.resize(n)
	bdiag.resize(n)
	cc.resize(n)
	d.resize(n)
	for i in range(n):
		var ci: float = cap[i] / dt
		bdiag[i] = ci + G_LEAK + emerg_vent[i]
		d[i] = ci * bp[i]
		if i > 0:
			a[i] = -links[i - 1]
			bdiag[i] += links[i - 1]
		if i < n - 1:
			cc[i] = -links[i]
			bdiag[i] += links[i]
	for s in sources:
		var cell: int = s[0]
		bdiag[cell] += float(s[1])
		d[cell] += float(s[1]) * float(s[2])
	for i in range(1, n):
		var w: float = a[i] / bdiag[i - 1]
		bdiag[i] -= w * cc[i - 1]
		d[i] -= w * d[i - 1]
	var pnew := PackedFloat32Array()
	pnew.resize(n)
	pnew[n - 1] = d[n - 1] / bdiag[n - 1]
	for i in range(n - 2, -1, -1):
		pnew[i] = (d[i] - cc[i] * pnew[i + 1]) / bdiag[i]
	# air drawn from the main reservoirs by the relay valves, and the flow indicators
	for s in sources:
		var cell2: int = s[0]
		var q: float = float(s[1]) * (float(s[2]) - pnew[cell2])
		var who: int = s[3]
		if who >= 0:
			mr[who] = maxf(0.0, mr[who] - q / (V_MR / P_ATM) * dt)
			flow[who] = q * 60.0
		elif who <= -2:
			flow[-2 - who] = q * 60.0
	for i in range(n):
		bp_prev[i] = bp[i]
		bp[i] = maxf(0.0, pnew[i])
	_valves(dt)
	_loco_brakes(dt)
	if emergency_any or bp[mini(maxi(ctrl, 0), n - 1)] < 150.0 and bp_prev[0] > 300.0:
		_open_pcs("emergency brake application")


## Triple valves on every vehicle (locos' control valves included).
func _valves(dt: float) -> void:
	var c_ar := V_AR / P_ATM
	var c_er := V_ER_W / P_ATM
	var c_bc := V_BC / P_ATM
	for i in range(n):
		var p := bp[i]
		var rate := (bp_prev[i] - p) / maxf(dt, 1e-4)
		emerg_vent[i] = 0.0
		if vmode[i] == VM.EMERG:
			# emergency: reservoirs dumped into the cylinder, pipe vented locally
			emerg_vent[i] = G_EMERG * 0.5 if p > 5.0 else 0.0
			var q := K_SRV * maxf(0.0, ar[i] - bc[i])
			ar[i] -= q / c_ar * dt
			bc[i] += q / c_bc * dt
			var q2 := K_SRV * maxf(0.0, erw[i] - bc[i])
			erw[i] -= q2 / c_er * dt
			bc[i] += q2 / c_bc * dt
			if p > 200.0 and p > ar[i] + 10.0:
				vmode[i] = VM.RELEASE
			continue
		if (rate > 60.0 and p < ar[i] - 30.0) or (p < 100.0 and ar[i] > 280.0):
			vmode[i] = VM.EMERG
			continue
		if p < ar[i] - 12.0 or ((vmode[i] == VM.SERVICE or vmode[i] == VM.LAP) and p < ar[i] - 4.0):
			vmode[i] = VM.SERVICE
			var q3 := K_SRV * minf(ar[i] - p - 3.0, ar[i] - bc[i])
			if q3 > 0.0:
				ar[i] -= q3 / c_ar * dt
				bc[i] += q3 / c_bc * dt
			else:
				vmode[i] = VM.LAP
		elif p > ar[i] + 9.0 and vmode[i] != VM.RELEASE:
			vmode[i] = VM.RELEASE
		elif vmode[i] == VM.SERVICE:
			vmode[i] = VM.LAP
		if vmode[i] == VM.RELEASE:
			bc[i] = maxf(0.0, bc[i] - bc[i] * dt / 7.0 - dt * 2.0)
			# recharge the reservoirs from the brake pipe through the charging choke
			if p > ar[i]:
				var qc := c_ar / 60.0 * (p - ar[i])
				ar[i] += qc / c_ar * dt
				bp[i] -= qc / cap[i] * dt
			if p > erw[i]:
				var qe := c_er / 90.0 * (p - erw[i])
				erw[i] += qe / c_er * dt
				bp[i] -= qe / cap[i] * dt


func _loco_brakes(dt: float) -> void:
	# independent brake: the controlling brake valve's handle, sent to a
	# trailing unit down the independent application & release pipe
	var link := _on("l_mr_cock") and _on("t_mr_cock")
	var bail := false
	for u in range(2):
		if _u(u, "brake_mode") < 0.5 and computer[u] and _uon(u, "bail_off"):
			bail = true
	for u in range(2):
		var own := _u(u, "brake_mode") < 0.5 and computer[u]
		var cmd := 0.0
		if own:
			cmd = _u(u, "ind_brake") * LOCO_BC_MAX
		elif link:
			for k in range(2):
				if k != u and _u(k, "brake_mode") < 0.5 and computer[k]:
					cmd = maxf(cmd, _u(k, "ind_brake") * LOCO_BC_MAX)
		var auto := 0.0 if bail else minf(LOCO_BC_MAX, bc[u] * 1.25)
		var target := minf(maxf(cmd, auto), mr[u])
		loco_bc[u] = move_toward(loco_bc[u], target, dt * (110.0 if target > loco_bc[u] else 70.0))


func _open_pcs(reason: String) -> void:
	if not pcs_open:
		pcs_open = true
		pcs_reason = reason
		notify("PCS open (%s): power cut. To reset: throttle IDLE, automatic brake handle in SUPPRESSION for 10 s%s." % [reason, " and the train stopped" if reason.begins_with("emergency") else ""], "warn")


# ================================================================ safety
func _safety(dt: float) -> void:
	var vk := absf(train.speed) * 3.6
	var c := maxi(ctrl, 0)
	var armed := ctrl >= 0 and _uon(c, "cb_alerter") and computer[c] and (vk > 1.0 or _u(c, "throttle") > 0.5)
	if armed and not penalty:
		alerter_t += dt
		if alerter_t > 60.0 and not alerter_warn:
			alerter_warn = true
			notify("Vigilance: press the ALERTER button (Q).", "warn")
		if alerter_t > 70.0:
			penalty = true
			_open_pcs("vigilance penalty")
	elif not armed:
		alerter_t = 0.0
		alerter_warn = false
	# PCS reset: throttle idle and the handle in suppression (handle off and full
	# service count as well) for 10 s; after an emergency the train must stop
	if pcs_open:
		var h := _u(c, "auto_brake")
		var ok := _u(c, "throttle") < 0.5 and h >= 4.99 and h < 7.5
		if pcs_reason.begins_with("emergency") and absf(train.speed) > 0.1:
			ok = false
		_pcs_t = _pcs_t + dt if ok else 0.0
		if _pcs_t > 10.0:
			pcs_open = false
			penalty = false
			alerter_t = 0.0
			alerter_warn = false
			_pcs_t = 0.0
			notify("PCS reset: power available. Release the brakes.", "good")


# ============================================================== traction
func _traction(dt: float) -> void:
	var v := train.speed
	var vk := absf(v) * 3.6
	var total_te := 0.0
	var total_db := 0.0
	var c := maxi(ctrl, 0)
	var rev := int(_u(c, "reverser")) if ctrl >= 0 else 1
	var dir := 0.0 if rev == 1 else (1.0 if rev == 2 else -1.0)
	var notch := int(round(_u(c, "throttle"))) if ctrl >= 0 else 0
	var dbh := _u(c, "dynbrake") if ctrl >= 0 else 0.0
	var mu := adhesion_mu()
	for u in range(2):
		var veh := train.vehicles[u]
		var weight := veh.total_mass() * 9.81
		var sand := _uon(c, "sand") and ctrl >= 0 and _powered(u)
		var mu_u := mu + (0.05 if sand else 0.0)
		var power_ok := responds[u] and _uon(c, "sw_gen_field") and _uon(c, "sw_engine_run") and dir != 0.0 and notch >= 1 and dbh < 0.5 and not pcs_open
		if power_ok and ((dir > 0.0 and v < -0.3) or (dir < 0.0 and v > 0.3)):
			power_ok = false
			why_not[u] = "reverser against the direction of travel"
		var target := 0.0
		if power_ok:
			var tcc := (0.5 if _uon(u, "cb_tcc1") else 0.0) + (0.5 if _uon(u, "cb_tcc2") else 0.0)
			var cold := 0.5 if water_t[u] < 40.0 else 1.0
			if cold < 1.0:
				_say("cold%d" % u, "%s: engine cold (%d C): load limited until the water reaches 40 C." % [unit_name(u).capitalize(), int(water_t[u])])
			var p_avail: float = P_RAIL * NOTCH_P[notch] * clampf((rpm[u] - 300.0) / (NOTCH_RPM[notch] - 300.0), 0.0, 1.0) * (0.45 + 0.55 * turbo[u]) * cold * tcc
			var f_lim := TE_MAX * minf(1.0, 0.12 + notch * 0.16) * tcc
			target = minf(f_lim, p_avail / maxf(absf(v), 0.6))
		# AC creep control holds the wheels just short of slipping
		var adh := mu_u * weight
		slip[u] = target > adh * 0.98
		if slip[u]:
			target = adh * 0.96
		te[u] = move_toward(te[u], target, dt * 90000.0)
		load[u] = clampf(te[u] * maxf(absf(v), 0.6) / P_RAIL, 0.0, 1.0) if target > 0.0 else 0.0
		if power_ok:
			load[u] = maxf(load[u], NOTCH_P[notch] * 0.35)
		total_te += te[u] * dir
		# dynamic brake
		var db_ok := responds[u] and dbh > 0.5 and notch == 0 and dir != 0.0 and not pcs_open
		db_blower[u] = move_toward(db_blower[u], (0.35 + 0.65 * clampf((dbh - 1.0) / 8.0, 0.0, 1.0)) if db_ok else 0.0, dt * 0.8)
		var db_target := 0.0
		if db_ok and dbh > 1.05:
			var frac := clampf((dbh - 1.0) / 8.0, 0.0, 1.0)
			db_target = minf(DB_F_MAX * frac, DB_P_MAX * frac / maxf(absf(v), 1.0))
			if vk < 3.0:
				db_target *= vk / 3.0
			db_target = minf(db_target, adh * 0.9)
		db[u] = move_toward(db[u], db_target, dt * 70000.0)
		total_db += db[u]
	traction_force = total_te
	# brakes: wagons, locos (with the handbrake), dynamic brake
	var f := total_db
	for u in range(2):
		var veh2 := train.vehicles[u]
		f += LOCO_BRAKE_F * loco_bc[u] / LOCO_BC_MAX
		f += _u(u, "handbrake") * 0.1 * veh2.total_mass() * 9.81
	var mu_b := adhesion_mu(true) + 0.1
	for i in range(2, n):
		var fw: float = f_ref[i] * clampf(bc[i] / 360.0, 0.0, 1.3)
		var cap_f := mu_b * train.vehicles[i].total_mass() * 9.81
		f += minf(fw, cap_f)
	brake_force = f
	# a moving train with a handbrake on: smoking brake blocks
	var hb := _u(0, "handbrake") > 0.3 or _u(1, "handbrake") > 0.3
	if hb and vk > 3.0 and not _warned_hb:
		_warned_hb = true
		notify("A locomotive handbrake is still on - the wheels are dragging! Release it at the No. 2 end.", "warn")
	elif not hb:
		_warned_hb = false


func adhesion_mu(braking := false) -> float:
	if braking:
		return super.adhesion_mu(true)
	# AC traction with creep control holds far more than an EMU's figure
	match weather:
		"rain":
			return 0.24
		"fog":
			return 0.2
	return 0.33


# ================================================================ lights
func _lights(dt: float) -> void:
	horn = _u(maxi(ctrl, 0), "horn") if ctrl >= 0 else 0.0
	if horn > 0.3:
		ditch_flash = 15.0
	ditch_flash = maxf(0.0, ditch_flash - dt)
	for u in range(2):
		var veh := train.vehicles[u]
		var lights_ok := _powered(u) and _uon(u, "cb_lights")
		var hl := int(_u(u, "headlights")) if lights_ok else 0
		for m in veh.head_lamps:
			(m as StandardMaterial3D).emission_energy_multiplier = [0.0, 1.5, 4.0][hl]
		for l in veh.head_lights:
			(l as SpotLight3D).light_energy = [0.0, 1.2, 4.5][hl]
		var dmode := int(_u(u, "ditch")) if lights_ok and hl > 0 else 0
		var d_on := dmode == 1 or (dmode == 2)
		var flash := dmode == 2 and ditch_flash > 0.0
		var phase := fmod(sim_time, 1.0) < 0.5
		var dl: Array = veh.extra.get("ditch_lamps", [])
		var dls: Array = veh.extra.get("ditch_lights", [])
		for k in range(dls.size()):
			var lit := d_on and (not flash or (phase == (k == 0)))
			(dls[k] as SpotLight3D).light_energy = 2.0 if lit else 0.0
		for m in dl:
			(m as StandardMaterial3D).emission_energy_multiplier = 3.0 if d_on and (not flash or phase) else 0.0
		var mk := lights_ok and _uon(u, "markers")
		for m in veh.marker_lamps:
			(m as StandardMaterial3D).emission_energy_multiplier = 2.5 if mk else 0.0
		for m in veh.tail_lamps:
			(m as StandardMaterial3D).emission_energy_multiplier = 0.0
		var erl: OmniLight3D = veh.extra.get("engine_room_light")
		if erl:
			erl.light_energy = 0.8 if lights_ok and cabinet.get(PFX[u] + "eng1_door", 0.0) + cabinet.get(PFX[u] + "eng2_door", 0.0) > 0.5 else 0.0
		# radiator fans, and the dynamic brake grid blower
		for fnode in veh.extra.get("fans", []):
			(fnode as Node3D).rotation.y += fan[u] * 18.0 * dt
		var dbf: Node3D = veh.extra.get("db_fan")
		if dbf:
			dbf.rotation.y += db_blower[u] * 40.0 * dt
	# end-of-train marker flashes once a second
	var last := train.vehicles[n - 1]
	for m in last.tail_lamps:
		(m as StandardMaterial3D).emission_energy_multiplier = 3.0 if fmod(sim_time, 1.2) < 0.25 else 0.0


# ================================================================== misc
func _misc(dt: float) -> void:
	for u in range(2):
		var w := int(_u(u, "wipers"))
		if _powered(u) and w > 0:
			wiper_phase[u] += dt * (0.6 if w == 1 else 1.0)
		else:
			var f := wiper_phase[u] - floorf(wiper_phase[u])
			if f > 0.001:
				wiper_phase[u] = minf(ceilf(wiper_phase[u]), wiper_phase[u] + dt * 0.6)
	# brake test: with the pipe charged, a reduction must be seen at the rear
	# (the end-of-train device) and the last wagon's brakes apply; then release
	var rear := bp[n - 1]
	var handle := _u(maxi(ctrl, 0), "auto_brake")
	if brake_test == 0 and handle < 0.5:
		_bt_rear_ref = rear if rear > 440.0 else 0.0
	if brake_test == 0 and _bt_rear_ref > 440.0 and rear < _bt_rear_ref - 35.0 and bc[n - 1] > 40.0:
		brake_test = 1
		notify("Brake test: the application reached the last wagon (brake cylinder %d kPa). Now release." % int(bc[n - 1]), "good")
	elif brake_test == 1 and rear > _bt_rear_ref - 12.0 and bc[n - 1] < 10.0:
		brake_test = 2
		notify("Brake test complete: the train brakes applied and released.", "good")
	# cab air-conditioning and the train radio
	var amb := _ambient()
	for u in range(2):
		var ac := _powered(u) and _uon(u, "cb_cabair")
		var warm := amb + (5.0 if GameSettings.time_of_day == "day" and weather == "clear" else 1.0)
		var target := 22.0 if ac else warm
		cab_temp[u] = move_toward(cab_temp[u], target, dt * (0.03 if ac else 0.006) * maxf(absf(cab_temp[u] - target), 0.5))
		if _powered(u) and _uon(u, "cb_radio"):
			_radio_t[u] += dt
			radio_ok[u] = _radio_t[u] > 6.0
		else:
			_radio_t[u] = 0.0
			radio_ok[u] = false
	# alarms for the displays
	alarms.clear()
	for u in range(2):
		var nm: String = ["UNIT 1", "UNIT 2"][u]
		if _powered(u) and not is_running(u):
			alarms.append("%s ENGINE NOT RUNNING" % nm)
		if is_running(u) and water_t[u] > 98.0:
			alarms.append("%s HOT ENGINE" % nm)
		if is_running(u) and water_t[u] < 40.0:
			alarms.append("%s COLD ENGINE - LOAD LIMITED" % nm)
		if slip[u]:
			alarms.append("%s WHEEL SLIP" % nm)
		if _u(u, "handbrake") > 0.3:
			alarms.append("%s HANDBRAKE APPLIED" % nm)
		if fuel_l[u] < 1500.0:
			alarms.append("%s LOW FUEL" % nm)
		if _powered(u) and not radio_ok[u]:
			alarms.append("%s RADIO %s" % [nm, "STARTING" if _uon(u, "cb_radio") else "OFF"])
		if _powered(u) and not responds[u] and is_running(u) and ctrl >= 0:
			alarms.append("%s NOT LOADING: %s" % [nm, why_not[u].to_upper()])
	if pcs_open:
		alarms.append("PCS OPEN - " + pcs_reason.to_upper())
	if alerter_warn:
		alarms.append("ALERTER")
	if not mu_link:
		alarms.append("MU JUMPER NOT CONNECTED")
	if not (_on("l_bp_cock") and _on("t_bp_cock")):
		alarms.append("BRAKE PIPE CLOSED BETWEEN UNITS")


func _sounds() -> void:
	for u in range(2):
		sound["rpm%d" % u] = rpm[u]
		sound["load%d" % u] = load[u]
		sound["turbo%d" % u] = turbo[u]
		sound["crank%d" % u] = 1.0 if eng[u] == "cranking" else 0.0
		sound["comp%d" % u] = 1.0 if comp_loaded[u] else 0.0
		sound["db%d" % u] = db_blower[u]
		sound["fan%d" % u] = fan[u]
		sound["cabac%d" % u] = 1.0 if _powered(u) and _uon(u, "cb_cabair") else 0.0
	sound["horn"] = horn
	sound["sand"] = 1.0 if ctrl >= 0 and _uon(ctrl, "sand") and mr[ctrl] > 300.0 else 0.0
	sound["alerter"] = 1.0 if alerter_warn else 0.0
	sound["speed"] = absf(train.speed)
	sound["inverter"] = clampf((absf(te[0]) + absf(te[1]) + db[0] + db[1]) / (2.0 * TE_MAX), 0.0, 1.0)
	sound["release"] = clampf(maxf(0.0, -flow[maxi(ctrl, 0)]) / 4000.0, 0.0, 1.0)
	sound["bc"] = loco_bc[0]
	sound["jointed"] = false


# ============================================================== keyboard
func _ck() -> String:
	return PFX[maxi(ctrl, 0)]


func handle_action(action: String) -> void:
	var p := _ck()
	match action:
		"main_inc":
			var dbc := cab.c(p + "dynbrake")
			if dbc.value > 0.5:
				dbc.set_value(dbc.value - 1.0 if dbc.value > 1.5 else 0.0, true)
			else:
				cab.c(p + "throttle").step(1)
		"main_dec":
			var th := cab.c(p + "throttle")
			if th.value > 0.5:
				th.step(-1)
			else:
				var dbc2 := cab.c(p + "dynbrake")
				dbc2.set_value(minf(9.0, dbc2.value + 1.0), true)
		"rev_fwd":
			cab.c(p + "reverser").step(1)
		"rev_back":
			cab.c(p + "reverser").step(-1)
		"brake_apply":
			var ab := cab.c(p + "auto_brake")
			ab.set_value(minf(5.0, (ab.value + 0.5) if ab.value >= 1.0 else 1.0), true)
		"brake_release":
			var ab2 := cab.c(p + "auto_brake")
			ab2.set_value(0.0 if ab2.value <= 1.0 else maxf(1.0, ab2.value - 0.5), true)
		"ind_apply":
			var ib := cab.c(p + "ind_brake")
			ib.set_value(ib.value + 0.25, true)
		"ind_release":
			var ib2 := cab.c(p + "ind_brake")
			ib2.set_value(ib2.value - 0.25, true)
		"emergency":
			_setc(p + "auto_brake", 8.0)
		"acknowledge":
			var al := cab.c(p + "alerter")
			al.press(MOUSE_BUTTON_LEFT)
			al.release()
		"headlights":
			var h := cab.c(p + "headlights")
			h.set_value(int(h.value + 1) % 3, true)


func hold(_dt: float) -> void:
	var p := _ck()
	var hc := cab.c(p + "horn")
	if Input.is_action_pressed("horn"):
		hc.set_value(1.0, true)
	elif Input.is_action_just_released("horn"):
		hc.set_value(0.0, true)
	var sc := cab.c(p + "sand")
	if Input.is_action_pressed("sand"):
		if sc.value < 0.5:
			sc.press(MOUSE_BUTTON_LEFT)
	elif Input.is_action_just_released("sand"):
		sc.release()
	var bo := cab.c(p + "bail_off")
	if Input.is_action_pressed("bail_off"):
		if bo.value < 0.5:
			bo.press(MOUSE_BUTTON_LEFT)
	elif Input.is_action_just_released("bail_off"):
		bo.release()


# =================================================================== HUD
func auto_label(u: int) -> String:
	var h := _u(u, "auto_brake")
	for k in AUTO_LABELS:
		if absf(float(k) - h) < 0.01:
			return AUTO_LABELS[k]
	return "SERVICE %d kPa" % int(50.0 + (h - 1.0) / 4.0 * 100.0)


func throttle_label(u: int) -> String:
	var dbh := _u(u, "dynbrake")
	if dbh > 0.5:
		return "DB SETUP" if dbh < 1.05 else "DB %.1f" % (dbh - 1.0)
	var t := int(round(_u(u, "throttle")))
	return "IDLE" if t == 0 else "NOTCH %d" % t


func hud_lines() -> PackedStringArray:
	var out := PackedStringArray()
	var c := maxi(ctrl, 0)
	out.append("%s   Reverser %s   Auto brake %s   Independent %d%%   %s   TE %d kN   DB %d kN" % [
		throttle_label(c), ["REVERSE", "OFF", "FORWARD"][int(_u(c, "reverser"))], auto_label(c), int(_u(c, "ind_brake") * 100.0),
		"Cab %d controlling" % (ctrl + 1) if ctrl >= 0 else "No cab controlling", int((te[0] + te[1]) / 1000.0), int((db[0] + db[1]) / 1000.0)])
	out.append("BP %d kPa (rear %d)   ER %d   MR %d / %d   Loco BC %d   Wagon BC %d (rear %d)   Flow %d L/min" % [
		int(bp[c]), int(bp[n - 1]), int(er[c]), int(mr[0]), int(mr[1]), int(loco_bc[0]), int(bc[2] if n > 2 else 0.0), int(bc[n - 1]), int(flow[c])])
	for u in range(2):
		out.append("Unit %d: %s %d rpm  water %d C  fuel %d L  battery %d V%s" % [u + 1, eng[u].to_upper(), int(rpm[u]), int(water_t[u]), int(fuel_l[u]), int(bat_v[u]),
			("   NOT LOADING: " + why_not[u]) if why_not[u] != "" and ctrl >= 0 and is_running(u) else ""])
	if pcs_open:
		out.append("PCS OPEN: " + pcs_reason)
	return out


func checklist() -> Array:
	var both_bat := _uon(0, "bat_switch") and _uon(1, "bat_switch")
	var cbs := true
	for u in range(2):
		for b in ["cb_control", "cb_local", "cb_fuel", "cb_computer", "cb_excite", "cb_tcc1", "cb_tcc2", "cb_comp"]:
			cbs = cbs and _uon(u, b)
	return [
		["Front unit: open the battery box on the left walkway, battery switch ON", _uon(0, "bat_switch")],
		["Second unit: battery switch ON", _uon(1, "bat_switch")],
		["Both cabs: engine control panel breakers ON (control, local, fuel pump, computer, excitation, TCC 1 & 2, compressor)", cbs and both_bat],
		["Computers booted on both units", computer[0] and computer[1]],
		["Both engines started: ECS in ISOLATE, hold FUEL PRIME, then hold ENGINE START", is_running(0) and is_running(1)],
		["Second unit set up to trail: brake valve TRAIL, reverser OFF, CONTROL off, ECS RUN", _u(1, "brake_mode") > 0.5 and int(_u(1, "reverser")) == 1 and not _uon(1, "sw_control") and int(_u(1, "ecs")) == 1],
		["MU jumper connected, brake pipe and MR cocks open between the units", mu_link and _on("l_bp_cock") and _on("t_bp_cock") and _on("l_mr_cock") and _on("t_mr_cock")],
		["Front unit: brake valve LEAD, ECS RUN", _u(0, "brake_mode") < 0.5 and int(_u(0, "ecs")) == 1],
		["Main reservoirs above 850 kPa (use + to speed up time)", mr[0] > 850.0 and mr[1] > 850.0],
		["Brake pipe charged to the last wagon (rear above 470 kPa)", bp[n - 1] > 470.0],
		["Handbrakes released on both locomotives (wheel at each No. 2 end)", _u(0, "handbrake") < 0.05 and _u(1, "handbrake") < 0.05],
		["Desk: CONTROL, ENGINE RUN and GEN FIELD on", _uon(0, "sw_control") and _uon(0, "sw_engine_run") and _uon(0, "sw_gen_field")],
		["Brake test: with the train fully charged, make a reduction (MINIMUM or more), watch it reach the rear, then release", brake_test == 2],
		["Headlights on (L), markers on", int(_u(0, "headlights")) >= 1 and _uon(0, "markers")],
		["Reverser FORWARD (W), release the brakes, notch up (D)", absf(train.speed) > 0.5],
	]


func help_text() -> String:
	return """[b]Pacific National 92 class pair on a coal train[/b]
D / A  throttle up / down (with the throttle at IDLE, A sets up and increases the dynamic brake; D backs it off)
W / S  reverser forward / reverse    ' / ;  automatic brake apply / release    [ / ]  independent brake apply / release
B (hold)  bail off the automatic brake on the locomotives    X (hold)  sand    Space  horn    Q  alerter reset
L  headlights    Backspace  emergency brake
1  next position (Shift+1 back)   5 driver   6 engine control panel   7 battery box   8 coupling   9 second unit's cab
Each locomotive has its own battery box (left walkway), engine control panel and brake cabinet (behind the seats),
engine room doors and a handbrake wheel at the No. 2 end. Click a cabinet door to open it.

[b]Driving a heavy train[/b]
The brake pipe takes seconds to carry an application to the last wagon and minutes to recharge after a release:
plan ahead, use the dynamic brake to hold the train on falling grades, and keep the automatic brake for stopping.
Loaded, the train is limited to 80 km/h. Over about 30 loaded wagons, two units may stall on the 1 in 40 bank."""
