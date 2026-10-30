extends Node
## Headless physics checks for both trains (run via tests/run_sim_test.gd).

var world: Node3D
var track: Track
var train: Train
var sim: TrainSim
var cab: Cab
var t := 0.0
var S := {}   # mutable state for lambdas (GDScript lambdas capture locals by value)
var failures := 0


func check(ok: bool, what: String) -> void:
	print(("   PASS  " if ok else "   FAIL  ") + what)
	if not ok:
		failures += 1


func run_tests(which: String) -> void:
	world = Node3D.new()
	add_child(world)
	if which == "a4":
		_a4_tests()
	else:
		_emu_tests()


func _make_a4(start: int, s0: float) -> void:
	if train:
		train.queue_free()
		sim.queue_free()
	track = Track.new()
	track.build(RouteDefs.get_route("ecml"))
	train = Train.new()
	world.add_child(train)
	train.setup(track, s0)
	var loco := VehicleModels.a4_loco()
	train.add_vehicle(loco)
	train.add_vehicle(VehicleModels.a4_tender())
	train.add_vehicle(VehicleModels.lner_coach(true, false))
	for i in range(6):
		train.add_vehicle(VehicleModels.lner_coach(false, i == 5))
	cab = A4Cab.new()
	(cab as A4Cab).build(loco.cab_root)
	var a4 := A4Sim.new()
	world.add_child(a4)
	a4.setup(train, cab, start)
	sim = a4
	train.sim = a4
	t = 0.0


func run(secs: float, dt := 0.05, cb := Callable()) -> void:
	var n := int(secs / dt)
	for i in range(n):
		sim.step(dt)
		train.physics_step(dt)
		t += dt
		if cb.is_valid() and cb.call():
			return


func mph() -> float:
	return absf(train.speed) / 0.44704


func _a4_tests() -> void:
	_make_a4(GameSettings.StartState.READY, 200.0)
	var a4 := sim as A4Sim
	print("Train mass: %.0f t (loco+tender+7 cars), length %.0f m" % [train.total_mass() / 1000.0, train.total_length()])
	# 1. starting tractive effort at full gear, full regulator
	cab.c("handbrake").set_value(0.0)
	cab.c("brake").set_value(0.0)
	cab.c("reverser").set_value(75.0)
	cab.c("regulator").set_value(1.0)
	sim.step(0.05)
	print("1. Starting TE: %.0f lbf (published 35,455 lbf at 85%% boiler pressure); boiler %d psi" % [a4.te / 4.44822, int(a4.p_gauge)])
	check(absf(a4.te / 4.44822 * 250.0 / a4.p_gauge - 35455.0) < 1500.0, "starting tractive effort within 1500 lbf of 35,455 (scaled to 250 psi)")
	# 2. acceleration with the AI driver (sensible cut-off) to 75 mph
	cab.c("regulator").set_value(0.0)
	_make_a4(GameSettings.StartState.READY, 200.0)
	a4 = sim as A4Sim
	a4.ai_driver = true
	a4.ai_target_mph = 126.0
	cab.c("handbrake").set_value(0.0)
	var marks := [30.0, 60.0, 75.0, 90.0, 100.0]
	S = {"mi": 0, "peak": 0.0, "pmin": 999.0, "lvl": 9.0, "d0": train.odometer}
	run(1800.0, 0.05, func():
		var mi: int = S["mi"]
		if mi < marks.size() and mph() >= marks[mi]:
			print("2. %3d mph after %5.0f s, %6.2f km  (boiler %d psi, glass %d%%, cut-off %d%%, ihp %d, fire %d kg, slip %s)" % [int(marks[mi]), t, (train.odometer - S["d0"]) / 1000.0, int(a4.p_gauge), int(a4.level * 100), int(a4.cutoff * 100), int(a4.indicated_hp), int(a4.zones[0] + a4.zones[1] + a4.zones[2] + a4.zones[3]), str(a4.slipping)])
			S["mi"] = mi + 1
		S["peak"] = maxf(S["peak"], mph())
		if t > 60.0:
			S["pmin"] = minf(S["pmin"], a4.p_gauge)
			S["lvl"] = minf(S["lvl"], a4.true_level)
		return a4.failed or train.derailed)
	check(not a4.failed and S["pmin"] > 180.0 and S["lvl"] > 0.1, "AI fireman keeps steam (>180 psi) and water in the glass for 30 minutes")
	print("   after 30 min: peak %.1f mph, now %.1f mph at s=%.0f (grade %.4f); min boiler %d psi after warm-up; min true level %.2f; coal used %.0f kg; water used %.0f gal; failed=%s derailed=%s %s" % [S["peak"], mph(), track.wrap_s(train.front_s), track.grade_at(train.front_s), int(S["pmin"]), S["lvl"], 8128.0 - a4.tender_coal, (22730.0 - a4.tender_water) / 4.546, str(a4.failed), str(train.derailed), a4.fail_reason + train.derail_reason])
	# 3. record attempt: down the 1 in 200 bank with full regulator, 40-45% cut-off
	_make_a4(GameSettings.StartState.READY, 3000.0)
	a4 = sim as A4Sim
	cab.c("handbrake").set_value(0.0)
	cab.c("brake").set_value(0.0)
	train.speed = 75.0 * 0.44704
	a4.ai_driver = false
	cab.c("regulator").set_value(1.0)
	cab.c("reverser").set_value(25.0)
	S = {"miles": []}
	S = {"summit": false, "top": 0.0, "miles": [], "d0": 0.0}
	run(1200.0, 0.05, func():
		var g := track.grade_at(train.front_s)
		if g < -0.003 and not S["summit"]:
			S["summit"] = true
			S["d0"] = train.odometer
			cab.c("reverser").set_value(40.0)
			print("3. Over the summit at %.1f mph after %.0f s, boiler %d psi, glass %d%%" % [mph(), t, int(a4.p_gauge), int(a4.level * 100)])
		if S["summit"] and (train.odometer - S["d0"]) / 1609.344 >= (S["miles"] as Array).size() + 1:
			(S["miles"] as Array).append("%.1f" % mph())
		if S["summit"] and g > -0.001:
			return true
		S["top"] = maxf(S["top"], mph())
		return a4.failed or train.derailed)
	print("   Mile by mile down the bank: %s  (1938: 87.5, 96.5, 104, 107, 111.5, 116, 119)" % ", ".join(S["miles"]))
	print("   Max on the descent: %.1f mph (record 126 mph); boiler now %d psi, glass %d%%, indicated %d hp, failed=%s %s" % [S["top"], int(a4.p_gauge), int(a4.level * 100), int(a4.indicated_hp), str(a4.failed), a4.fail_reason])
	# 4. braking: full vacuum application from 75 mph on level track
	_make_a4(GameSettings.StartState.READY, 300.0)
	a4 = sim as A4Sim
	cab.c("handbrake").set_value(0.0)
	cab.c("brake").set_value(0.0)
	train.speed = 75.0 * 0.44704
	cab.c("regulator").set_value(0.0)
	cab.c("blower").set_value(0.5)
	var d0 := train.odometer
	cab.c("brake").set_value(1.0)
	run(300.0, 0.05, func(): return absf(train.speed) < 0.01)
	print("4. Full brake from 75 mph: stopped in %.0f m (%.2f miles) in %.0f s" % [train.odometer - d0, (train.odometer - d0) / 1609.0, t])
	check(train.odometer - d0 > 1100.0 and train.odometer - d0 < 2300.0, "vacuum-braked stop from 75 mph between 0.7 and 1.4 miles")
	# 5. cold start with the AI fireman: time to raise steam
	_make_a4(GameSettings.StartState.COLD, 300.0)
	a4 = sim as A4Sim
	a4.ai_fireman = true
	S = {}
	run(6.0 * 3600.0, 0.5, func():
		for p in [20.0, 50.0, 100.0, 150.0, 200.0, 240.0]:
			if a4.p_gauge >= p and not S.has(p):
				S[p] = true
				print("5. Cold start: %3d psi after %4.1f h (fire %d kg, glass %d%%, coal used %d kg)" % [int(p), t / 3600.0, int(a4.zones[0] + a4.zones[1] + a4.zones[2] + a4.zones[3]), int(a4.level * 100), int(8128 - a4.tender_coal)])
		return a4.p_gauge >= 240.0)
	if a4.p_gauge < 240.0:
		print("5. Cold start: only %d psi after %.1f h, lit=%s" % [int(a4.p_gauge), t / 3600.0, str(a4.lit)])
	check(a4.p_gauge >= 240.0 and t > 2.5 * 3600.0, "steam raised from cold by the AI fireman in a realistic 2.5-6 hours")


# ================================================================ Mariyung
func _make_emu(start: int, cars: int, s0: float) -> void:
	if train:
		train.queue_free()
		sim.queue_free()
	track = Track.new()
	track.build(RouteDefs.get_route("nsw"))
	train = Train.new()
	world.add_child(train)
	train.setup(track, s0)
	var codes4 := [["DD", true, false, false, false], ["DN", false, true, true, false], ["DND", false, true, false, false], ["DDA", true, false, false, true]]
	var codes6 := [["DD", true, false, false, false], ["DNL", false, true, true, false], ["DT", false, false, false, false],
		["DN", false, true, true, false], ["DND", false, true, false, false], ["DDA", true, false, false, true]]
	for c in (codes4 if cars == 4 else codes6):
		train.add_vehicle(VehicleModels.mariyung_car(c[0], c[1], c[2], c[3], c[4]))
	cab = MariyungCab.new()
	(cab as MariyungCab).build(train.vehicles[0].cab_root)
	var ms := MariyungSim.new()
	world.add_child(ms)
	ms.setup(train, cab, start)
	ms.message.connect(func(m, k): print("      [%s] %s" % [k, m]))
	sim = ms
	train.sim = ms
	t = 0.0


func press(id: String) -> void:
	var c := cab.c(id)
	c.press(MOUSE_BUTTON_LEFT)
	c.release()


func _emu_tests() -> void:
	# 1. full cold start
	_make_emu(GameSettings.StartState.COLD, 6, 600.0)
	var ms := sim as MariyungSim
	print("1. Cold start, 6-car (%.0f t):" % (train.total_mass() / 1000.0))
	cab.c("battery").set_value(1)
	run(2.0)
	cab.c("master_key").set_value(1)
	run(20.0)
	press("pan_up")
	run(90.0, 0.05, func(): return ms.pan_pos > 0.99)
	print("   pantograph up after %.0f s (pan reservoir %d kPa)" % [t, int(ms.pan_res)])
	press("hscb_close")
	run(8.0)
	print("   HSCB %s, SIV %s at %.0f s" % [str(ms.hscb), str(ms.siv_on), t])
	var t_mr := t
	run(900.0, 0.1, func(): return ms.mr >= 750.0)
	print("   MR reached 750 kPa after %.0f s of compressor running" % (t - t_mr))
	press("park_release")
	press("dmi_data")
	press("dmi_start")
	cab.c("tbc").set_value(-7)
	press("tms_btest")
	run(25.0)
	cab.c("headlights").set_value(2)
	cab.c("direction").set_value(2)
	cab.c("dsd").set_value(1)
	print("   checklist: %s" % str(ms.checklist().map(func(x): return 1 if x[1] else 0)))
	check(ms.hscb and ms.siv_on and not ms.park_applied and ms.brake_test == 2 and ms.etcs_mode == "SR", "full cold start-up sequence completes")
	# 2. acceleration
	cab.c("tbc").set_value(4)
	var marks := [20.0, 40.0, 60.0, 80.0, 100.0, 115.0]
	S = {"mi": 0, "t0": t, "d0": train.odometer}
	var t0 := t
	var d0 := train.odometer
	run(200.0, 0.05, func():
		var mi: int = S["mi"]
		if mi < marks.size() and absf(train.speed) * 3.6 >= marks[mi]:
			print("2. %3d km/h after %5.1f s, %4.0f m  (grade %.4f, limit %d, ETCS %s perm %d)" % [int(marks[mi]), t - S["t0"], train.odometer - S["d0"], track.grade_at(train.front_s), int(track.limit_at(train.front_s)), ms.etcs_mode, int(ms.etcs_permitted)])
			S["mi"] = mi + 1
		ms.vig_t = 0.0
		return S["mi"] >= marks.size() or ms.eb_latched or train.derailed)
	# 3. service brake B7 from current speed
	var v0 := absf(train.speed) * 3.6
	cab.c("tbc").set_value(-7)
	d0 = train.odometer
	t0 = t
	run(120.0, 0.05, func(): return absf(train.speed) < 0.01)
	print("3. B7 from %d km/h: %.0f m, %.1f s -> mean %.2f m/s2 (spec 1.01)" % [int(v0), train.odometer - d0, t - t0, v0 / 3.6 / maxf(t - t0, 0.01)])
	check(absf(v0 / 3.6 / maxf(t - t0, 0.01) - 1.05) < 0.15, "service brake rate close to 1.01 m/s2")
	# 4. acceleration test on level with a tare 6-car: measure 0-20 km/h
	_make_emu(GameSettings.StartState.READY, 6, 9000.0)
	ms = sim as MariyungSim
	cab.c("tbc").set_value(4)
	t0 = t
	run(60.0, 0.02, func(): return absf(train.speed) * 3.6 >= 30.0)
	print("4. Ready 6-car: 0-30 km/h in %.1f s -> %.2f m/s2 at grade %.4f (spec 0.84)" % [t - t0, 30.0 / 3.6 / (t - t0), track.grade_at(train.front_s)])
	check(absf(30.0 / 3.6 / (t - t0) - 0.8) < 0.12, "loaded acceleration close to the 0.84 m/s2 tare figure")
	# 5. ETCS: try to overspeed a curve
	_make_emu(GameSettings.StartState.READY, 4, 9000.0)
	ms = sim as MariyungSim
	cab.c("tbc").set_value(4)
	S = {"first": "", "maxlat": 0.0, "maxover": -99.0}
	run(400.0, 0.05, func():
		ms.vig_t = 0.0
		S["maxlat"] = maxf(S["maxlat"], absf(train.lat_accel))
		S["maxover"] = maxf(S["maxover"], absf(train.speed) * 3.6 - track.min_limit_between(train.rear_s(), train.front_s))
		if ms.etcs_status >= 2 and S["first"] == "":
			S["first"] = "ETCS intervention status %d at %d km/h, permitted %d" % [ms.etcs_status, int(absf(train.speed) * 3.6), int(ms.etcs_permitted)]
		return train.derailed)
	check(not train.derailed and S["first"] != "", "ETCS intervenes before a curve overspeed derails the train")
	print("5. Holding full power for 400 s: %s; derailed=%s; max lateral %.2f m/s2; max over line speed %.1f km/h; EB latched %s" % [S["first"], str(train.derailed), S["maxlat"], S["maxover"], str(ms.eb_latched)])
