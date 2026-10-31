extends SceneTree
## Checks that every cab control actually does something. For each control the
## game is built fresh in the same state, the control is operated, the sim runs
## for a few seconds, and everything observable (sim state, sounds, lamps,
## lights, gauges, moving parts, train lamps, effects) is compared with an
## untouched run. Controls that only work in certain situations (e.g. DATA only
## in ETCS standby, EB reset only after an emergency brake) get that situation
## set up first, in both the untouched and the operated run.
## usage: -s res://tests/control_effects.gd -- <a4|mariyung|c92> [start 0-2] [id or prefix* ...]
## Exit code 1 if any control changes nothing.

var train_name := "mariyung"
var start := 2
var only: Array = []
var ids: Array = []
var runs: Array = []          # [kind, id]: kind = "base" | "noise" | "ctx" (setup, untouched) | "op"
var ri := 0
var game: Node
var base_global: Array = []
var base_ctx: Array = []
var noise := {}
var snaps: Array = []
var messages: Array = []
var silent: Array = []
var report: Array = []
const STEPS := 60             # 3 s of sim time after operating


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	train_name = a[0] if a.size() > 0 else "mariyung"
	start = int(a[1]) if a.size() > 1 else 2
	for i in range(2, a.size()):
		only.append(a[i])
	runs = [["base", ""], ["noise", ""]]
	_new_game()


func _new_game() -> void:
	var gs = root.get_node("GameSettings")
	gs.train = {"mariyung": 0, "a4": 1, "c92": 2}[train_name]
	gs.coal_wagons = 6
	gs.coal_loaded = true
	gs.start_state = start
	gs.graphics_quality = 0
	gs.time_of_day = "day"
	gs.weather = "clear"
	gs.ai_fireman = false
	gs.ai_driver = false
	gs.show_tooltips = false
	game = load("res://scenes/game.tscn").instantiate()
	game.set("paused", true)      # the test steps the sim itself, deterministically
	root.add_child(game)
	game.set("paused", true)
	messages = []


func _process(_d: float) -> bool:
	if game == null or not game.built:
		return false
	game.paused = true
	var cab = game.cab
	if ids.is_empty():
		for id in cab.controls:
			if only.is_empty() or only.has(id) or only.any(func(o): return o.ends_with("*") and id.begins_with(o.trim_suffix("*"))):
				ids.append(id)
		ids.sort()
		for id in ids:
			if _has_setup(id):
				runs.append(["ctx", id])
			runs.append(["op", id])
	game.sim.message.connect(func(t, _k = ""): messages.append(t))
	var kind: String = runs[ri][0]
	var id: String = runs[ri][1]
	snaps = []
	if kind == "ctx" or kind == "op":
		_setup(id)
	if kind == "op":
		_operate(cab.controls[id])
	else:
		_run(3)
		snaps.append(_snap())
		_run(7)
		snaps.append(_snap())
	_post(id)
	_run(STEPS)
	snaps.append(_snap())
	match kind:
		"base":
			base_global = snaps
		"noise":
			# anything that differs between two untouched runs is real-time noise (flicker etc.)
			for si in range(snaps.size()):
				for k in snaps[si]:
					if not base_global[si].has(k) or not _same(base_global[si][k], snaps[si][k]):
						noise[k] = true
			if not noise.is_empty():
				print("ignoring real-time noise: ", noise.keys())
		"ctx":
			base_ctx = snaps
		"op":
			var base: Array = base_ctx if _has_setup(id) else base_global
			var changed := []
			for si in range(snaps.size()):
				var snap: Dictionary = snaps[si]
				for k in snap:
					if noise.has(k) or changed.has(k):
						continue
					if not base[si].has(k) or not _same(base[si][k], snap[k]):
						changed.append(k)
			changed.sort()
			var msg := " | msg: " + str(messages.slice(0, 2)) if not messages.is_empty() else ""
			var ctx := " [in context]" if _has_setup(id) else ""
			if changed.is_empty():
				silent.append(id)
				report.append("  NO EFFECT  %-18s%s%s" % [id, ctx, msg])
			else:
				report.append("  ok         %-18s %s%s%s" % [id, ", ".join(changed.slice(0, 6)) + (" ..." if changed.size() > 6 else ""), ctx, msg])
	game.queue_free()
	game = null
	ri += 1
	if ri >= runs.size():
		print("\n%s, start state %d: %d controls" % [train_name, start, ids.size()])
		for line in report:
			print(line)
		print("controls with no effect: %s" % str(silent))
		quit(1 if not silent.is_empty() else 0)
		return true
	_new_game()
	return false


# ------------------------------------------------------------ situations
const SETUPS := {
	"mariyung": ["dmi_data", "dmi_start", "dmi_ack", "doors_close", "dsd", "eb_reset", "mcb_comp", "mcb_doors",
		"mcb_wipers", "pan_up", "park_release", "tms_status", "vigilance"],
	"a4": ["cocks", "fire_zone_0", "fire_zone_1", "fire_zone_2", "fire_zone_3", "firelighters", "scoop"],
	"c92": ["l_bail_off", "l_alerter", "l_reverser", "l_ditch", "l_sw_engine_run", "l_sw_gen_field", "l_scr_engine",
		"l_cb_tcc1", "l_cb_tcc2", "l_cb_comp", "l_cb_alerter", "l_fuel_prime", "l_engine_start", "l_dead_engine",
		"t_auto_brake", "t_ind_brake", "t_bail_off", "t_horn", "t_sand", "t_alerter", "t_throttle", "t_dynbrake", "t_reverser",
		"t_ditch", "t_sw_engine_run", "t_sw_gen_field", "t_scr_engine", "t_cb_tcc1", "t_cb_tcc2", "t_cb_comp", "t_cb_lights",
		"t_cb_alerter", "t_fuel_prime", "t_engine_start", "t_dead_engine"],
}


func _has_setup(id: String) -> bool:
	return (SETUPS[train_name] as Array).has(id)


func _setc(id: String, v: float) -> void:
	game.cab.c(id).set_value(v)


## The second unit's cab takes over: the first unit's cab is shut down and
## set to trail, and the second unit's brake valve, reverser and switches set
## up to drive.
func _cab2_drives() -> void:
	_setc("l_sw_control", 0)
	_setc("l_brake_mode", 1)
	_setc("l_reverser", 1)
	_setc("t_brake_mode", 0)
	_setc("t_reverser", 2)
	_setc("t_auto_brake", 0.0)
	_setc("t_ind_brake", 1.0)
	_setc("t_headlights", 2)
	for sw in ["t_sw_control", "t_sw_engine_run", "t_sw_gen_field"]:
		_setc(sw, 1)
	_run(10)


## Put the train in the situation where 'id' should do something (applied to
## both the untouched and the operated run).
func _setup(id: String) -> void:
	var sim = game.sim
	if train_name == "c92":
		_setup_c92(id)
		return
	match id:
		"dmi_data":
			sim.etcs_mode = "SB"
			sim.etcs_data = false
		"dmi_start":
			sim.etcs_mode = "SB"
			sim.etcs_data = true
		"dmi_ack":
			sim.etcs_status = 3
		"doors_close":
			sim.rel_l = true
			sim.doors_l = 1.0
			sim.doors_locked = false
		"dsd":
			_setc("tbc", 1)                 # in power: the pedal must be held
			_run(10)
		"eb_reset":
			sim.eb_latched = true
			sim.eb_reason = "test"
			_setc("tbc", -8)
		"mcb_comp":
			sim.mr = 700.0                 # below the governor: compressor running
			_run(2)
		"mcb_wipers":
			_setc("wipers", 2)
			_run(4)
		"pan_up":
			sim.pan_cmd = false
			sim.pan_pos = 0.0
			sim.hscb = false
		"park_release":
			sim.park_applied = true
		"tms_status":
			sim.tms_page = 2
		"vigilance":
			game.train.speed = 15.0        # vigilance only times while moving
			sim.vig_t = 58.0
		"cocks":
			_setc("reverser", 70.0)
			_setc("regulator", 0.3)
			_run(10)
		"fire_zone_0", "fire_zone_1", "fire_zone_2", "fire_zone_3":
			_setc("firedoor", 0.9)
			game.cab.controls[id].enabled = true
			sim.shovel_loaded = true
		"firelighters":
			_setc("firedoor", 0.9)
			sim.lit = false
			for i in range(4):
				sim.zone_t[i] = 20.0
		"scoop":
			pass


func _setup_c92(id: String) -> void:
	if not _has_setup(id):
		return
	var sim = game.sim
	var u := 0 if id.begins_with("l_") else 1
	var p := id.substr(0, 2)
	var short := id.substr(2)
	if p == "t_" and short in ["auto_brake", "ind_brake", "bail_off", "horn", "sand", "alerter", "cb_alerter", "throttle", "dynbrake",
			"reverser", "sw_engine_run", "sw_gen_field"]:
		_cab2_drives()
	match short:
		"bail_off":
			# a full service, so the locomotives' own brake cylinders fill from it
			_setc(p + "ind_brake", 0.0)
			_setc(p + "auto_brake", 5.0)
			_run(240)
		"alerter", "cb_alerter":
			_setc(p + "throttle", 1)
			_run(2)
			sim.alerter_t = 58.0
		"reverser":
			_setc(p + "throttle", 1)
			_run(4)
		"sw_engine_run", "sw_gen_field":
			_setc(p + "throttle", 3)
			_run(4)
		"cb_tcc1", "cb_tcc2":
			_setc("l_throttle", 3)
			_run(10)
		"ditch":
			if p == "l_":
				sim.ditch_flash = 15.0
			else:
				_setc("t_headlights", 2)
		"scr_engine":
			sim.screen_page[u] = 2
		"cb_comp":
			sim.mr[u] = 800.0
			_setc("l_mr_cock", 0)           # keep the other unit's reservoir from topping it up
			_run(2)
		"cb_lights":
			_setc(p + "headlights", 2)
			_run(2)
		"fuel_prime":
			sim.eng[u] = "stopped"
			sim.rpm[u] = 0.0
			sim.fuel_p[u] = 0.0
			_setc(p + "ecs", 0)
		"engine_start":
			sim.eng[u] = "stopped"
			sim.rpm[u] = 0.0
			sim.fuel_p[u] = 380.0
			_setc(p + "ecs", 0)
		"dead_engine":
			sim.mr[u] = 300.0
			_setc("l_mr_cock", 0)


## Things to do after operating (or not operating) the control, in both runs.
func _post(id: String) -> void:
	if id == "mcb_doors":
		game.cab.c("door_rel_left").press(MOUSE_BUTTON_LEFT)
		game.cab.c("door_rel_left").release()


## Operates the control and always runs exactly 10 sim steps (so every run,
## including the untouched ones, covers the same amount of time).
func _operate(ctl: CabControl) -> void:
	match ctl.kind:
		CabControl.Kind.BUTTON:
			ctl.press(MOUSE_BUTTON_LEFT)
			_run(3)
			snaps.append(_snap())
			_run(3)
			ctl.release()
			_run(4)
			snaps.append(_snap())
		CabControl.Kind.TOGGLE:
			ctl.press(MOUSE_BUTTON_LEFT)
			ctl.release()
			_run(3)
			snaps.append(_snap())
			_run(7)
			snaps.append(_snap())
		CabControl.Kind.ROTARY:
			if ctl.value < ctl.max_v:
				ctl.step(1)
			else:
				ctl.step(-1)
			_run(3)
			snaps.append(_snap())
			_run(7)
			snaps.append(_snap())
		_:
			var target := ctl.max_v if ctl.value < (ctl.min_v + ctl.max_v) * 0.5 else ctl.min_v
			ctl.set_value(target, true)
			_run(3)             # hold a spring-return control (horn, whistle) for a moment
			snaps.append(_snap())
			_run(7)
			if not is_nan(ctl.spring_to):
				ctl.release()
			snaps.append(_snap())


func _run(n: int) -> void:
	for i in range(n):
		game.sim.step(0.05)
		game.train.physics_step(0.05)
		game.train.update_visuals()
		game.cab.call("update_visuals", game.sim, 0.05)
		if game.effects:
			game.effects.update(game.sim, 0.05)
		if game.diesel:
			game.diesel.update(game.sim, 0.05)


func _same(a, b) -> bool:
	if a is float and b is float:
		return absf(a - b) <= 1e-6 * maxf(1.0, maxf(absf(a), absf(b)))
	return a == b


func _flat(prefix: String, v, out: Dictionary) -> void:
	match typeof(v):
		TYPE_BOOL, TYPE_INT, TYPE_STRING, TYPE_STRING_NAME, TYPE_FLOAT:
			out[prefix] = v
		TYPE_VECTOR3:
			out[prefix] = str((v as Vector3).snapped(Vector3.ONE * 0.0001))
		TYPE_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_INT32_ARRAY:
			for i in range(mini(v.size(), 64)):
				var e = v[i]
				if e is float or e is int or e is bool:
					out["%s[%d]" % [prefix, i]] = float(e)
		TYPE_DICTIONARY:
			for k in v:
				var e = v[k]
				if e is float or e is int or e is bool:
					out["%s.%s" % [prefix, str(k)]] = float(e)


func _snap() -> Dictionary:
	var out := {}
	var sim = game.sim
	for p in sim.get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			_flat("sim." + p.name, sim.get(p.name), out)
	var cab = game.cab
	for id in cab.lamps:
		out["lamp." + id] = (cab.lamps[id] as StandardMaterial3D).emission_energy_multiplier
	for id in cab.gauges:
		var g: CabGauge = cab.gauges[id]
		for i in range(g.targets.size()):
			out["gauge.%s[%d]" % [id, i]] = g.targets[i]
	var li := 0
	# every light on the train: cab, engine room, walkways, head and ditch lights
	for l in game.train.find_children("*", "Light3D", true, false):
		out["light[%d]" % li] = (l as Light3D).light_energy
		li += 1
	# moving parts, materials and shader state held by the cab script
	for p in cab.get_property_list():
		if not (p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var v = cab.get(p.name)
		if v is Node3D:
			out["cab." + p.name] = str((v as Node3D).transform)
			out["cab." + p.name + ".visible"] = (v as Node3D).visible
		elif v is StandardMaterial3D:
			out["cab." + p.name + ".emission"] = (v as StandardMaterial3D).emission_energy_multiplier
		elif v is ShaderMaterial:
			for sp in ["mist", "wipe_phase", "wipe_rate", "wash"]:
				var sv = (v as ShaderMaterial).get_shader_parameter(sp)
				if sv != null:
					out["cab.%s.%s" % [p.name, sp]] = float(sv)
		elif v is Array:
			for i in range(mini(v.size(), 16)):
				var e = v[i]
				if e is Node3D:
					out["cab.%s[%d]" % [p.name, i]] = str((e as Node3D).transform)
					out["cab.%s[%d].visible" % [p.name, i]] = (e as Node3D).visible
				elif e is StandardMaterial3D:
					out["cab.%s[%d].emission" % [p.name, i]] = (e as StandardMaterial3D).emission_energy_multiplier
	for vi in range(game.train.vehicles.size()):
		var veh: Vehicle = game.train.vehicles[vi]
		for arr_name in ["head_lamps", "tail_lamps", "marker_lamps"]:
			var arr: Array = veh.get(arr_name)
			for i in range(arr.size()):
				out["veh%d.%s[%d]" % [vi, arr_name, i]] = (arr[i] as StandardMaterial3D).emission_energy_multiplier
		for i in range(veh.head_lights.size()):
			out["veh%d.head_light[%d]" % [vi, i]] = (veh.head_lights[i] as Light3D).light_energy
		if veh.scoop:
			out["veh%d.scoop" % vi] = str(veh.scoop.transform)
		for k in veh.extra:
			var e = veh.extra[k]
			var items: Array = e if e is Array else [e]
			for i in range(items.size()):
				if items[i] is Light3D:
					continue
				if items[i] is Node3D:
					out["veh%d.%s[%d]" % [vi, k, i]] = str((items[i] as Node3D).transform)
				elif items[i] is StandardMaterial3D:
					out["veh%d.%s[%d]" % [vi, k, i]] = (items[i] as StandardMaterial3D).emission_energy_multiplier
	var win := MU.mat(Color(0.06, 0.08, 0.1), 0.08, 0.5, "nif_win")
	out["saloon_windows"] = win.emission_energy_multiplier
	if game.diesel:
		for i in range(game.diesel.stacks.size()):
			out["dfx[%d]" % i] = (game.diesel.stacks[i] as GPUParticles3D).amount_ratio
	if game.effects:
		var fx = game.effects
		for n in ["chimney", "safety", "whistle", "scoop_spray"]:
			var pe = fx.get(n)
			if pe:
				out["fx." + n] = (pe as GPUParticles3D).amount_ratio
		for n in ["overflow_water", "overflow_steam", "cocks"]:
			var arr: Array = fx.get(n)
			for i in range(arr.size()):
				out["fx.%s[%d]" % [n, i]] = (arr[i] as GPUParticles3D).amount_ratio
	return out
