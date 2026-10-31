class_name MariyungSim
extends TrainSim
## NSW D set "Mariyung" (Hyundai Rotem / Mitsubishi IGBT-VVVF, 1500 V DC).
## Published figures used: 160 km/h design / 130 km/h service speed,
## 0.84 m/s^2 acceleration, 1.01 m/s^2 service and 1.10 m/s^2 emergency braking.
## Cab layout and start-up procedure follow general Sydney/NSW EMU practice.

const F_MAX_MC := 89000.0       # N per motor car (gives 0.84 m/s^2 on a tare set)
const P_MAX_MC := 1.0e6         # W per motor car at the wheel
const REGEN_F_MC := 90000.0
const REGEN_P_MC := 1.25e6
const BC_EB := 420.0            # kPa brake cylinder, emergency
const EB_DECEL := 1.10
const SB_DECEL := 1.01
const SERVICE_MAX := 130.0      # km/h
const SR_SPEED := 40.0
const TBC_LABELS := {-8: "EB", -7: "B7", -6: "B6", -5: "B5", -4: "B4", -3: "B3", -2: "B2", -1: "B1", 0: "COAST", 1: "P1", 2: "P2", 3: "P3", 4: "P4"}

var bat_v := 0.0
var cab_active := false
var tms_boot := -1.0
var dmi_boot := -1.0
var tms_on := false
var pan_res := 0.0
var aux_comp := false
var pan_cmd := false
var pan_pos := 0.0
var line_v := 0.0
var hscb := false
var _hscb_t := 0.0
var siv_on := false
var _siv_t := 0.0
var mr := 0.0
var comp_on := false
var park_applied := true
var bc: Array[float] = []
var holding := false
var eb_latched := false
var eb_reason := ""
var power_ramp := 0.0
var brake_ramp := 0.0
var doors_l := 0.0              # 0 closed .. 1 open
var doors_r := 0.0
var rel_l := false
var rel_r := false
var closing := false
var _close_t := 0.0
var doors_locked := true
var vig_t := 0.0
var vig_stage := 0
var dsd_t := 0.0
var etcs_mode := "NP"
var etcs_data := false
var etcs_permitted := 0.0
var etcs_target := -1.0
var etcs_target_d := 0.0
var etcs_status := 0            # 0 normal, 1 warning, 2 service intervention, 3 emergency
var _last_balise := -1
var _sb_roll := 0.0
var brake_test := 0             # 0 not done, 1 running, 2 passed
var _bt_t := 0.0
var wsp := false
var slip := false
var line_i := 0.0
var traction_inhibit := ""
var _inhibit_said := ""
var tms_page := 0
var faults: Array[String] = []
var n_motor := 0
var _prev_touch := 0
var wiper_phase := 0.0
var horn_hi := 0.0
var horn_lo := 0.0
var door_chime := 0.0
var etcs_beep := 0.0
var _said := {}
# comfort & cab equipment
var aux_kw := 0.0               # load on the auxiliary converter
var ambient_t := 24.0           # outside air temperature (deg C)
var saloon_t := 22.5
var hvac_on := false
var demist_on := false
var mist := 0.0                 # condensation on the windscreen 0..1
var radio_ok := false
var _radio_boot := -1.0
var washer_t := 0.0             # wash-wipe cycle running (s left)
var wash_age := 1e4             # seconds since the washer last sprayed
var wipe_idle := 1e4            # seconds since the wipers last moved
var wipe_rate := 0.0            # wiper cycles per second right now


func setup(t: Train, c: Cab, start_state: int) -> void:
	train = t
	cab = c
	route_units = "metric"
	for v in t.vehicles:
		bc.append(0.0)
		if v.motored_axles > 0:
			n_motor += 1
	for id in cab.controls:
		(cab.controls[id] as CabControl).changed.connect(_on_control)
	var tod: String = GameSettings.time_of_day
	ambient_t = {"day": 26.0, "dusk": 20.0, "night": 16.0}.get(tod, 24.0) - {"rain": 4.0, "fog": 6.0}.get(weather, 0.0)
	saloon_t = ambient_t if start_state == GameSettings.StartState.COLD else 22.5
	mist = (0.75 if weather != "clear" else (0.4 if tod != "day" else 0.0)) if start_state == GameSettings.StartState.COLD else 0.0
	match start_state:
		GameSettings.StartState.COLD:
			_setc("battery", 0)
			_setc("master_key", 0)
			_setc("tbc", -8)
			_setc("direction", 1)
			_setc("headlights", 0)
		GameSettings.StartState.PREP:
			_setc("battery", 1)
			_setc("master_key", 0)
			_setc("tbc", -8)
			_setc("direction", 1)
			bat_v = 116.0
			pan_cmd = true
			pan_pos = 1.0
			pan_res = 700.0
			line_v = 1500.0
			hscb = true
			siv_on = true
			_siv_t = 10.0
			mr = 880.0
			for i in range(bc.size()):
				bc[i] = 0.0
		_:
			_setc("battery", 1)
			_setc("master_key", 1)
			_setc("tbc", -7)
			_setc("direction", 2)
			_setc("headlights", 2)
			_setc("dsd", 1)
			bat_v = 118.0
			cab_active = true
			tms_on = true
			pan_cmd = true
			pan_pos = 1.0
			pan_res = 750.0
			line_v = 1500.0
			hscb = true
			siv_on = true
			_siv_t = 10.0
			mr = 890.0
			park_applied = false
			etcs_mode = "FS"
			etcs_data = true
			brake_test = 2
			radio_ok = true
			for i in range(bc.size()):
				bc[i] = 230.0
	_update_pan_visuals()


func _setc(id: String, v: float) -> void:
	var ctl := cab.c(id)
	if ctl:
		ctl.set_value(v)


func _v(id: String) -> float:
	return cab.val(id)


func _on(id: String) -> bool:
	return cab.val(id) > 0.5


func _say(key: String, t: String, kind := "info") -> void:
	if _said.has(key):
		return
	_said[key] = true
	notify(t, kind)


func _on_control(ctl: CabControl) -> void:
	vig_t = 0.0
	if vig_stage > 0 and vig_stage < 3:
		vig_stage = 0
	var pressed := ctl.value > 0.5
	match ctl.id:
		"pan_up":
			if pressed:
				if not cab_active:
					_say("pan_key", "Cab not active: switch the master key ON first.")
				elif not _on("mcb_pan"):
					notify("Pantograph control circuit breaker is OFF (rear panel).", "warn")
				else:
					pan_cmd = true
					if mr < 450.0 and pan_res < 450.0:
						notify("Main reservoir empty: the auxiliary (battery) compressor is charging the pantograph reservoir...")
		"pan_down":
			if pressed:
				pan_cmd = false
		"hscb_close":
			if pressed:
				if not cab_active:
					_say("hscb_key", "Cab not active.")
				elif line_v < 1000.0:
					notify("No line voltage: raise the pantograph first.", "warn")
				elif not _on("mcb_hscb"):
					notify("HSCB control circuit breaker is OFF (rear panel).", "warn")
				else:
					_hscb_t = 0.6
		"hscb_open":
			if pressed and hscb:
				hscb = false
				notify("HSCB opened.")
		"park_apply":
			if pressed and bat_v > 80.0:
				park_applied = true
		"park_release":
			if pressed and cab_active:
				if mr < 500.0:
					notify("Not enough main reservoir air to release the spring parking brake (need 500 kPa).", "warn")
				else:
					park_applied = false
		"door_rel_left", "door_rel_right":
			if pressed:
				_release_doors(ctl.id == "door_rel_left")
		"doors_close":
			if pressed and (doors_l > 0.0 or doors_r > 0.0 or rel_l or rel_r):
				closing = true
				_close_t = 0.0
				door_chime = 1.0
		"eb_reset":
			if pressed:
				_try_eb_reset()
		"vigilance":
			if pressed:
				vig_t = 0.0
				vig_stage = 0
		"dmi_data":
			if pressed and etcs_mode == "SB":
				etcs_data = true
				notify("ETCS train data validated: %d m, max %d km/h, braking: EP + regen." % [int(train.total_length()), int(SERVICE_MAX)])
		"dmi_start":
			if pressed and etcs_mode == "SB":
				if not etcs_data:
					notify("ETCS: enter / validate train data first (DATA).", "warn")
				else:
					etcs_mode = "SR"
					notify("ETCS Start of Mission: Staff Responsible mode, max %d km/h until the next balise." % int(SR_SPEED))
		"dmi_ack":
			if pressed and etcs_status == 3 and absf(train.speed) < 0.1:
				etcs_status = 0
				notify("ETCS trip acknowledged.")
		"tms_status", "tms_brakes", "tms_doors", "tms_faults":
			if pressed:
				tms_page = ["tms_status", "tms_brakes", "tms_doors", "tms_faults"].find(ctl.id)
		"tms_btest":
			if pressed:
				_start_brake_test()
		"pa":
			if pressed:
				door_chime = 0.6
		"washer":
			if pressed:
				if bat_v < 80.0 or not _on("mcb_wipers"):
					notify("Washer: no supply (battery off or wiper circuit breaker off).", "warn")
				else:
					washer_t = 4.5
					wash_age = 0.0
					sound["washer"] = 1.0
		"direction":
			if absf(train.speed) > 0.3:
				notify("Direction controller interlocked while moving!", "warn")


func _release_doors(left: bool) -> void:
	if not cab_active or not _on("mcb_doors"):
		notify("Door control not available (cab inactive or door MCB off).", "warn")
		return
	if absf(train.speed) > 0.14:
		notify("Doors cannot be released while moving.", "warn")
		return
	var side := -1 if left else 1
	var on_platform := false
	for pl in train.track.route.get("platforms", []):
		var s := train.track.wrap_s(train.front_s)
		if s > pl[0] - 5.0 and train.track.wrap_s(train.rear_s()) < pl[0] + pl[1] + 5.0 and int(pl[2]) == side:
			on_platform = true
	if not on_platform:
		notify("Doors released on the %s side with no platform there! (safety incident)" % ("LEFT" if left else "RIGHT"), "fail")
	if left:
		rel_l = true
	else:
		rel_r = true
	closing = false
	doors_locked = false


func _try_eb_reset() -> void:
	if absf(train.speed) > 0.05:
		notify("Emergency brake reset only possible at a stand.", "warn")
		return
	if int(round(_v("tbc"))) != -8:
		notify("Move the traction/brake controller to EB, then reset.", "warn")
		return
	if _on("estop"):
		notify("Emergency stop button is still pressed in (click it to pull it out).", "warn")
		return
	if etcs_status == 3:
		notify("ETCS trip: acknowledge on the DMI (ACK) first.", "warn")
		return
	eb_latched = false
	eb_reason = ""
	vig_stage = 0
	vig_t = 0.0
	dsd_t = 0.0
	notify("Emergency brake reset.", "good")


func _start_brake_test() -> void:
	if not tms_on:
		return
	if absf(train.speed) > 0.05:
		notify("Brake test only at a stand.", "warn")
		return
	if mr < 700.0:
		notify("Brake test: main reservoir pressure too low (%d kPa)." % int(mr), "warn")
		return
	if int(round(_v("tbc"))) > -7:
		notify("Brake test: put the controller in B7 or EB first.", "warn")
		return
	brake_test = 1
	_bt_t = 0.0
	notify("Automatic brake test started (service, emergency, release, regen check)...")


func _eb(reason: String) -> void:
	if not eb_latched:
		eb_latched = true
		eb_reason = reason
		notify("EMERGENCY BRAKE: " + reason, "fail")


# ================================================================== step
func step(dt: float) -> void:
	sim_time += dt
	var v := train.speed
	var vk := absf(v) * 3.6
	_electrics(dt)
	_air(dt)
	_doors(dt)
	_safety(dt, vk)
	_etcs(dt, vk)
	_forces(dt, v, vk)
	_brake_test(dt)
	_lights()
	_comfort(dt)
	_sounds(dt, vk)
	# wipers: a wash-wipe cycle runs them even when switched off, and when
	# switched off mid-stroke they finish the stroke and park
	var wiper_power := 1.0 if bat_v > 80.0 and _on("mcb_wipers") else 0.0
	var sel: float = [0.0, 0.35, 0.9, 1.5][int(_v("wipers"))]
	var spd := sel
	if washer_t > 0.0:
		washer_t -= dt
		spd = maxf(spd, 0.9)
	if spd == 0.0 and fmod(wiper_phase, 1.0) > 0.0005:
		spd = 0.9
	wipe_rate = spd * wiper_power
	var before := wiper_phase
	wiper_phase += dt * wipe_rate
	if sel == 0.0 and washer_t <= 0.0 and int(before) != int(wiper_phase):
		wiper_phase = floor(wiper_phase)      # back at the park position
	wipe_idle = 0.0 if wipe_rate > 0.0 else wipe_idle + dt
	wash_age += dt
	sound["washer"] = maxf(0.0, float(sound.get("washer", 0.0)) - dt * 1.5)


func _electrics(dt: float) -> void:
	var bat_on := _on("battery")
	var target := 0.0
	if bat_on:
		target = 118.0 if siv_on else 108.0
	bat_v = move_toward(bat_v, target, 30.0 * dt if target > bat_v else 3.0 * dt)
	var was := cab_active
	cab_active = bat_on and bat_v > 80.0 and _on("master_key") and _on("mcb_control")
	if cab_active and not was:
		tms_boot = 18.0 if _on("mcb_tms") else -1.0
		dmi_boot = 14.0 if _on("mcb_etcs") else -1.0
		if etcs_mode == "NP":
			pass
	if not cab_active:
		tms_on = false
		tms_boot = -1.0
		if etcs_mode != "IS":
			etcs_mode = "NP"
		dmi_boot = -1.0
	else:
		if tms_boot > 0.0:
			tms_boot -= dt
			if tms_boot <= 0.0:
				tms_on = true
		if not _on("mcb_tms"):
			tms_on = false
		if dmi_boot > 0.0:
			dmi_boot -= dt
			if dmi_boot <= 0.0 and etcs_mode == "NP":
				etcs_mode = "SB"
		if not _on("mcb_etcs"):
			if etcs_mode != "IS":
				_say("etcs_iso", "ETCS ISOLATED (MCB off). No train protection: you must operate under authority.", "warn")
			etcs_mode = "IS"
		elif etcs_mode == "IS":
			_said.erase("etcs_iso")
			etcs_mode = "NP"
			dmi_boot = 14.0
	# pantograph & aux compressor (the pan valve is held up by the control supply)
	if not (bat_on and bat_v > 80.0) or not _on("mcb_pan"):
		if pan_cmd:
			pan_cmd = false
			if bat_on and not _on("mcb_pan"):
				notify("Pantograph control circuit breaker off: the pantograph is lowering.", "warn")
	aux_comp = pan_cmd and pan_res < 650.0 and mr < 450.0 and bat_v > 80.0
	if aux_comp:
		pan_res += 7.0 * dt
	if mr > pan_res:
		pan_res = minf(mr, 900.0)
	var can_up := pan_cmd and pan_res >= 450.0 and bat_v > 80.0
	pan_pos = move_toward(pan_pos, 1.0 if can_up else 0.0, (0.2 if can_up else 0.45) * dt)
	pan_res = maxf(0.0, pan_res - 0.05 * dt)
	var electrified: bool = train.track.route.get("electrified", false)
	line_v = 1500.0 + sin(sim_time * 0.37) * 40.0 - line_i * 0.02 if (pan_pos > 0.97 and electrified) else 0.0
	_update_pan_visuals()
	# HSCB & aux converter
	if _hscb_t > 0.0:
		_hscb_t -= dt
		if _hscb_t <= 0.0 and line_v > 1000.0:
			hscb = true
			notify("HSCB closed.")
	if line_v < 1000.0 or not _on("mcb_hscb") or not bat_on:
		if hscb:
			hscb = false
			if bat_on:
				notify("HSCB opened (loss of line voltage).", "warn")
	if hscb:
		_siv_t += dt
	else:
		_siv_t = 0.0
	var was_siv := siv_on
	siv_on = hscb and _siv_t > 4.5
	if siv_on and not was_siv:
		notify("Auxiliary converter (SIV) running: 415 V AC available.")


func _update_pan_visuals() -> void:
	for veh in train.vehicles:
		if veh.pantograph:
			VehicleModels.update_pantograph(veh, pan_pos, SceneryBuilder.CONTACT_H - 4.42 - 0.05)


func _air(dt: float) -> void:
	var can_comp := siv_on and _on("mcb_comp")
	if can_comp:
		if mr < 750.0:
			comp_on = true
		elif mr >= 900.0:
			comp_on = false
	else:
		comp_on = false
	if comp_on:
		mr += 2.6 * dt
	mr = maxf(0.0, mr - 0.04 * dt)
	if mr < 400.0 and not park_applied:
		park_applied = true
		notify("Spring parking brake applied itself (main reservoir below 400 kPa).", "warn")


func _doors(dt: float) -> void:
	var avail := cab_active and _on("mcb_doors")
	if rel_l and not closing:
		doors_l = move_toward(doors_l, 1.0, dt / 3.0)
	if rel_r and not closing:
		doors_r = move_toward(doors_r, 1.0, dt / 3.0)
	if closing:
		_close_t += dt
		if _close_t > 2.0:
			doors_l = move_toward(doors_l, 0.0, dt / 3.5)
			doors_r = move_toward(doors_r, 0.0, dt / 3.5)
		if doors_l <= 0.0 and doors_r <= 0.0 and _close_t > 2.5:
			closing = false
			rel_l = false
			rel_r = false
			doors_locked = true
			mr -= 4.0
	if not avail and (rel_l or rel_r):
		pass
	for veh in train.vehicles:
		_place_doors(veh.doors_left if not veh.reversed else veh.doors_right, doors_l)
		_place_doors(veh.doors_right if not veh.reversed else veh.doors_left, doors_r)


func _place_doors(list: Array, f: float) -> void:
	for d in list:
		var node: Node3D = d[0]
		var closed: Vector3 = d[1]
		var ov: Vector3 = d[2]
		var plug := clampf(f * 4.0, 0.0, 1.0)
		var slide := clampf((f - 0.15) / 0.85, 0.0, 1.0)
		node.position = closed + Vector3(ov.x * plug, 0, ov.z * slide)


func _safety(dt: float, vk: float) -> void:
	if _on("estop"):
		_eb("Emergency stop button pressed.")
	# vigilance (task-linked): 60 s without activity -> light, buzzer, penalty
	if cab_active and vk > 1.0:
		vig_t += dt
	else:
		vig_t = 0.0
		if vig_stage < 3:
			vig_stage = 0
	if vig_stage < 3:
		if vig_t > 68.0:
			vig_stage = 3
			_eb("Vigilance penalty (no acknowledgement).")
		elif vig_t > 65.0:
			vig_stage = 2
		elif vig_t > 60.0:
			vig_stage = 1
	# driver's safety device (foot pedal)
	var need_dsd := cab_active and (vk > 0.5 or _v("tbc") > 0.5)
	if need_dsd and not _on("dsd"):
		dsd_t += dt
		if dsd_t > 2.5:
			_eb("Driver's safety pedal released.")
			dsd_t = 0.0
	else:
		dsd_t = 0.0
	if not doors_locked and vk > 3.0:
		_eb("Door open while moving.")


func _etcs(dt: float, vk: float) -> void:
	etcs_permitted = 0.0
	etcs_target = -1.0
	if etcs_mode == "NP" or etcs_mode == "IS":
		etcs_status = 0
		return
	var tr := train.track
	# balise groups every 1000 m
	var bidx := int(floor(tr.wrap_s(train.front_s) / 1000.0))
	if bidx != _last_balise:
		if _last_balise >= 0 and etcs_mode == "SR":
			etcs_mode = "FS"
			notify("ETCS: balise read, now in Full Supervision.", "good")
		_last_balise = bidx
	match etcs_mode:
		"SB":
			# standstill supervision
			if vk > 1.0:
				_sb_roll += absf(train.speed) * dt
				if _sb_roll > 3.0:
					etcs_status = 3
					_eb("ETCS standstill supervision: train moved in Stand By.")
			else:
				_sb_roll = 0.0
			etcs_permitted = 0.0
			return
		"SR":
			etcs_permitted = SR_SPEED
		"FS":
			var ceiling := minf(tr.min_limit_between(train.rear_s(), train.front_s), SERVICE_MAX)
			var perm := ceiling
			var a := 0.55
			var d := 50.0
			var best_d := -1.0
			while d < 4000.0:
				var lim := tr.limit_at(train.front_s + d)
				if lim < ceiling:
					var vt := lim / 3.6
					var allowed := sqrt(vt * vt + 2.0 * a * maxf(0.0, d - 60.0)) * 3.6
					if allowed < perm:
						perm = allowed
					if best_d < 0.0 or lim < etcs_target:
						if best_d < 0.0:
							best_d = d
							etcs_target = lim
				d += 25.0
			etcs_target_d = best_d
			etcs_permitted = perm
	# supervision
	if etcs_status == 3:
		return
	var over := vk - etcs_permitted
	if over > 10.0:
		etcs_status = 3
		_eb("ETCS emergency intervention (overspeed).")
	elif over > 5.0:
		etcs_status = 2
	elif over > 2.0 and etcs_status != 2:
		etcs_status = 1
	elif over <= 0.0:
		etcs_status = 0


func _forces(dt: float, v: float, vk: float) -> void:
	var tbc := int(round(_v("tbc")))
	var dirn := int(round(_v("direction"))) - 1        # -1 R, 0 N, +1 F
	var m_total := train.total_mass()
	var m_eff := m_total * 1.06
	# traction interlocks
	traction_inhibit = ""
	if not cab_active:
		traction_inhibit = "cab not active"
	elif not hscb:
		traction_inhibit = "HSCB open / no line voltage"
	elif dirn == 0:
		traction_inhibit = "direction controller in NEUTRAL"
	elif not doors_locked:
		traction_inhibit = "doors not closed and locked"
	elif park_applied:
		traction_inhibit = "parking brake applied"
	elif eb_latched or tbc == -8:
		traction_inhibit = "emergency brake"
	elif etcs_mode == "SB" or etcs_mode == "NP":
		traction_inhibit = "ETCS not in a running mode (Start of Mission)"
	elif brake_test == 1:
		traction_inhibit = "brake test running"
	if tbc > 0 and traction_inhibit != "" and _inhibit_said != traction_inhibit:
		_inhibit_said = traction_inhibit
		notify("Traction inhibited: " + traction_inhibit + ".", "warn")
	if tbc <= 0:
		_inhibit_said = ""
	var eb := eb_latched or tbc == -8 or etcs_status == 3 or bat_v < 80.0
	var demand_power := 0.0
	var demand_brake := 0.0
	if eb:
		demand_brake = EB_DECEL
	elif tbc < 0:
		demand_brake = float(-tbc) / 7.0 * SB_DECEL
	elif tbc > 0 and traction_inhibit == "":
		demand_power = float(tbc) / 4.0
	if etcs_status == 2:
		demand_power = 0.0
		demand_brake = maxf(demand_brake, SB_DECEL)
	if vk > SERVICE_MAX + 2.0:
		demand_power = 0.0
	power_ramp = move_toward(power_ramp, demand_power, 0.8 * dt)
	brake_ramp = move_toward(brake_ramp, demand_brake, (3.0 if eb else 1.2) * dt)
	# --- traction (VVVF, constant effort to ~40 km/h then constant power)
	var spd := maxf(absf(v), 0.1)
	var f_avail := n_motor * minf(F_MAX_MC, P_MAX_MC / spd)
	if vk > SERVICE_MAX:
		f_avail *= clampf(1.0 - (vk - SERVICE_MAX) / 5.0, 0.0, 1.0)
	var f_tr := power_ramp * f_avail
	var m_motor := 0.0
	for veh in train.vehicles:
		if veh.motored_axles > 0:
			m_motor += veh.total_mass()
	var f_adh := adhesion_mu() * m_motor * 9.81
	slip = false
	if f_tr > f_adh:
		f_tr = f_adh * 0.93
		slip = true
	traction_force = f_tr * dirn
	line_i = absf(f_tr * v) / 0.9 / 1500.0 + (aux_kw * 1000.0 / 1500.0 if hscb else 0.0)
	# --- braking: regen first, EP friction makes up the rest
	var f_req := brake_ramp * m_eff
	var regen := 0.0
	if hscb and not eb and vk > 3.0:
		regen = minf(f_req, n_motor * minf(REGEN_F_MC, REGEN_P_MC / spd) * clampf((vk - 3.0) / 7.0, 0.0, 1.0))
		line_i -= regen * absf(v) * 0.9 / 1500.0
	var fric_req := f_req - regen
	holding = vk < 0.4 and power_ramp < 0.25 and cab_active and not eb
	var fric := 0.0
	for i in range(train.vehicles.size()):
		var veh := train.vehicles[i]
		var m := veh.total_mass()
		var target := 0.0
		if eb:
			target = BC_EB
		else:
			target = clampf(fric_req * (m / m_total) / (m * EB_DECEL * 1.06) * BC_EB, 0.0, BC_EB)
		if holding:
			target = maxf(target, 160.0)
		if brake_test == 1:
			target = _bt_bc()
		if mr < target + 30.0:
			target = minf(target, maxf(mr - 30.0, 0.0))
		var prev := bc[i]
		bc[i] = move_toward(bc[i], target, (350.0 if target > bc[i] else 220.0) * dt)
		if bc[i] > prev:
			mr -= (bc[i] - prev) * 0.012
		fric += bc[i] / BC_EB * m * EB_DECEL * 1.06
	var park := (0.07 * m_total * 9.81) if park_applied else 0.0
	var limit := adhesion_mu(true) * m_total * 9.81 * (1.6 if not eb else 1.8)
	wsp = fric + regen > limit and vk > 2.0
	brake_force = minf(fric + regen, limit) + park


func _bt_bc() -> float:
	if _bt_t < 6.0:
		return 300.0
	if _bt_t < 10.0:
		return 0.0
	if _bt_t < 16.0:
		return BC_EB
	return 0.0


func _brake_test(dt: float) -> void:
	if brake_test != 1:
		return
	_bt_t += dt
	if absf(train.speed) > 0.1:
		brake_test = 0
		notify("Brake test aborted (train moved).", "warn")
		return
	if _bt_t > 22.0:
		brake_test = 2
		notify("Brake test PASSED: all cars respond, EB loop healthy, regen available.", "good")


func _lights() -> void:
	var mode := int(_v("headlights")) if (bat_v > 80.0 and _on("mcb_lights")) else 0
	var lead := train.vehicles[0]
	for lamp_m in lead.head_lamps:
		(lamp_m as StandardMaterial3D).emission_energy_multiplier = [0.0, 0.0, 3.0, 9.0][mode] if cab_active else 0.0
	for lamp_m in lead.marker_lamps:
		(lamp_m as StandardMaterial3D).emission_energy_multiplier = 2.5 if (mode >= 1 and cab_active) else 0.0
	for l in lead.head_lights:
		(l as SpotLight3D).light_energy = [0.0, 0.0, 2.5, 8.0][mode] if cab_active else 0.0
	var last := train.vehicles[train.vehicles.size() - 1]
	for lamp_m in last.tail_lamps:
		(lamp_m as StandardMaterial3D).emission_energy_multiplier = 3.0 if bat_v > 80.0 else 0.0
	# saloon lighting glows through the windows (faintly by day, warmly after dark)
	var wm := MU.mat(Color(0.06, 0.08, 0.1), 0.08, 0.5, "nif_win")
	var lit := siv_on and _on("saloon_lights")
	if not wm.emission_enabled:
		wm.emission_enabled = true
	wm.emission = Color(1.0, 0.92, 0.78)
	wm.emission_energy_multiplier = (0.3 if GameSettings.time_of_day != "day" else 0.1) if lit else 0.0


## Saloon air-conditioning, cab demister, windscreen misting, train radio and
## the resulting load on the auxiliary converter.
func _comfort(dt: float) -> void:
	var cars := train.vehicles.size()
	hvac_on = siv_on and _on("hvac") and _on("mcb_hvac")
	var sun_load := 2.5 if GameSettings.time_of_day == "day" and weather == "clear" else 0.0
	var target := 22.5 if hvac_on else ambient_t + sun_load
	saloon_t = move_toward(saloon_t, target, dt * (0.02 if hvac_on else 0.006))
	# demister: heated screen and warm air (heat from the aux converter, fan from the battery)
	demist_on = siv_on and bat_v > 80.0 and _on("demister")
	var humid: float = {"rain": 0.75, "fog": 0.8}.get(weather, 0.4 if GameSettings.time_of_day != "day" else 0.0)
	var m_target := 0.0 if demist_on else humid
	mist = move_toward(mist, m_target, dt * (0.07 if demist_on else 0.004))
	# train radio boots once the cab is active and its breaker is in
	if cab_active and _on("mcb_radio"):
		if not radio_ok:
			if _radio_boot < 0.0:
				_radio_boot = 6.0
			_radio_boot -= dt
			if _radio_boot <= 0.0:
				radio_ok = true
	else:
		if radio_ok and cab_active:
			notify("Train radio lost (radio circuit breaker off).", "warn")
		radio_ok = false
		_radio_boot = -1.0
	# auxiliary converter load (kW)
	aux_kw = 0.0
	if siv_on:
		aux_kw = 14.0 + cars * 3.0                                  # control, battery charging, ventilation
		if comp_on:
			aux_kw += 22.0
		if hvac_on:
			aux_kw += cars * (18.0 + clampf(absf(saloon_t - 22.5) * 6.0, 0.0, 14.0) + absf(ambient_t - 22.0) * 0.8)
		if _on("saloon_lights"):
			aux_kw += cars * 2.4
		if demist_on:
			aux_kw += 4.5
		if int(_v("headlights")) >= 2:
			aux_kw += 0.4
	sound["hvac"] = 1.0 if hvac_on else 0.0
	sound["demister"] = 1.0 if demist_on else 0.0
	sound["wiper"] = 1.0 if wipe_rate > 0.0 else 0.0


func _sounds(dt: float, vk: float) -> void:
	horn_hi = 1.0 if _v("horn") > 0.5 else 0.0
	horn_lo = 1.0 if _v("horn") < -0.5 else 0.0
	door_chime = maxf(0.0, door_chime - dt * 0.35)
	sound["speed"] = absf(train.speed)
	sound["traction"] = absf(traction_force) / maxf(n_motor * F_MAX_MC, 1.0)
	sound["regen"] = 0.0 if brake_ramp <= 0.0 else clampf(brake_ramp, 0.0, 1.0) * (1.0 if hscb and vk > 3.0 else 0.0)
	sound["compressor"] = 1.0 if comp_on else 0.0
	sound["aux_comp"] = 1.0 if aux_comp else 0.0
	sound["siv"] = 1.0 if siv_on else 0.0
	sound["horn_hi"] = horn_hi
	sound["horn_lo"] = horn_lo
	sound["chime"] = door_chime
	sound["vigilance"] = 1.0 if vig_stage == 2 else 0.0
	sound["dsd"] = 1.0 if dsd_t > 0.3 else 0.0
	sound["etcs"] = 1.0 if etcs_status >= 1 and etcs_status < 3 else 0.0
	sound["bc"] = bc[0] if bc.size() > 0 else 0.0
	sound["jointed"] = false


# ============================================================ keyboard
func handle_action(action: String) -> void:
	match action:
		"main_inc":
			cab.c("tbc").step(1)
		"main_dec":
			cab.c("tbc").step(-1)
		"rev_fwd":
			cab.c("direction").step(1)
		"rev_back":
			cab.c("direction").step(-1)
		"emergency":
			_setc("tbc", -8)
		"acknowledge":
			cab.c("vigilance").press(MOUSE_BUTTON_LEFT)
			cab.c("vigilance").release()
			if etcs_status == 3:
				cab.c("dmi_ack").press(MOUSE_BUTTON_LEFT)
				cab.c("dmi_ack").release()
		"deadman":
			cab.c("dsd").set_value(1.0 - _v("dsd"), true)
		"headlights":
			var h := cab.c("headlights")
			h.set_value(int(h.value + 1) % 4, true)
		"pantograph":
			var b := cab.c("pan_down" if pan_cmd else "pan_up")
			b.press(MOUSE_BUTTON_LEFT)
			b.release()
		"hscb":
			var b2 := cab.c("hscb_open" if hscb else "hscb_close")
			b2.press(MOUSE_BUTTON_LEFT)
			b2.release()
		"master_key":
			var k := cab.c("master_key")
			k.set_value(1.0 - k.value, true)
		"doors_left", "doors_right", "doors_close":
			var id: String = {"doors_left": "door_rel_left", "doors_right": "door_rel_right", "doors_close": "doors_close"}[action]
			cab.c(id).press(MOUSE_BUTTON_LEFT)
			cab.c(id).release()


func hold(_dt: float) -> void:
	var hc := cab.c("horn")
	if Input.is_action_pressed("horn"):
		hc.set_value(1.0, true)
	elif Input.is_action_pressed("horn_low"):
		hc.set_value(-1.0, true)
	elif Input.is_action_just_released("horn") or Input.is_action_just_released("horn_low"):
		hc.set_value(0.0, true)


# ================================================================ HUD
func tbc_label() -> String:
	return TBC_LABELS.get(int(round(_v("tbc"))), "?")


func hud_lines() -> PackedStringArray:
	var out := PackedStringArray()
	out.append("Controller %s   Direction %s   ETCS %s (permitted %d km/h)" % [tbc_label(), ["REVERSE", "NEUTRAL", "FORWARD"][int(_v("direction"))], etcs_mode, int(etcs_permitted)])
	out.append("Line %d V  %d A   Battery %d V   MR %d kPa   BC %d kPa   Pan %s  HSCB %s" % [int(line_v), int(line_i), int(bat_v), int(mr), int(bc[0]), "UP" if pan_pos > 0.97 else "DOWN", "CLOSED" if hscb else "OPEN"])
	if traction_inhibit != "" and _v("tbc") > 0.5:
		out.append("Traction inhibited: " + traction_inhibit)
	return out


func checklist() -> Array:
	return [
		["Battery isolating switch ON (rear panel, key 2 to look behind)", _on("battery")],
		["Master key ON: cab activated (K)", cab_active],
		["TMS and ETCS DMI booted", tms_on and etcs_mode != "NP"],
		["Pantograph raised (PAN UP / P)", pan_pos > 0.97],
		["HSCB closed (H)", hscb],
		["Auxiliary converter running", siv_on],
		["Main reservoir charged above 750 kPa (use + to speed up time)", mr > 750.0],
		["Parking brake released", not park_applied],
		["ETCS: validate train DATA, then START (Start of Mission)", etcs_mode in ["SR", "FS", "IS"]],
		["Automatic brake test passed (TMS: BRAKE TEST, controller in B7/EB)", brake_test == 2],
		["Headlights on (L)", int(_v("headlights")) >= 2],
		["Doors closed and locked", doors_locked],
		["Direction controller FORWARD (W)", int(_v("direction")) == 2],
		["Foot on the driver's safety pedal (F)", _on("dsd")],
		["Controller to power (D) and depart!", absf(train.speed) > 0.5],
	]


func help_text() -> String:
	return """[b]NSW D set "Mariyung": driving[/b]
A / D  traction/brake controller one notch towards brake / power (EB, B7..B1, COAST, P1..P4)
W / S  direction controller forward / reverse    F  driver's safety pedal (hold it down = ON)
Q  acknowledge vigilance / ETCS    Space  horn (high)   N  horn (low)    Backspace  controller to EB
K  master key    P  pantograph up/down    H  HSCB close/open    L  headlights
T / Y  release left / right doors    U  close doors
2  look at the rear panel (battery switch and circuit breakers)

Every switch, button, breaker and lever in the cab works with the mouse. Hover for a description.
[b]Safety systems[/b]
- Vigilance: if you don't touch a control for 60 s the lamp flashes, then the buzzer, then the brakes go on. Press Q.
- Driver's safety pedal: must be held (F) whenever moving or in power, or the brakes apply after 2.5 s.
- ETCS: supervises line speed and braking curves. Warning at +2 km/h, service brake at +5, emergency at +10.
- After any emergency brake: stop, controller to EB, then press EB RESET."""
