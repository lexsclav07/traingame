class_name A4Sim
extends TrainSim
## LNER A4 4468 "Mallard": boiler, fire, steam engine, vacuum brake, injectors,
## water scoop, failures, plus an optional AI fireman and AI driver.
##
## Engine model: 3 cylinders 18.5 x 26 in, 6 ft 8 in wheels, 250 psi
##  -> 35,455 lbf starting tractive effort (published figure reproduced exactly).
## Steam path: boiler -> regulator/superheater (orifice) -> steam chest ->
## cylinders (flow ~ revs x cut-off x pressure, with wire-drawing at speed).

const PSI := 0.006894757            # MPa per psi
const ATM := 0.101325                # MPa
const WORK_PSI := 250.0
const TE_K := 0.1076                 # m^2: 1.5 x d^2 s / D
const K0 := 2.2
const REG_A := 9.13
const KB := 0.0012
const WD := 0.008                    # wire-drawing (fitted to the 1938 record-run speeds)
const DRIVER_D := 2.032
const ADHESIVE_KG := 67000.0
const GLASS_BASE_KG := 5300.0        # boiler water at the bottom of the gauge glass
const GLASS_SPAN_KG := 3000.0        # bottom -> top of glass
const SHOVEL_KG := 5.5
const CV := 29000.0                  # kJ/kg, good Yorkshire/Welsh steam coal
const ZONE_NAMES := ["back left", "back right", "front left", "front right"]

# boiler
var water := 0.0                     # kg in boiler
var temp := 15.0                     # degC (saturated water)
var p_abs := ATM
var p_gauge := 0.0                   # psi
var level := 0.6                     # gauge glass reading 0..1 (what the crew sees)
var true_level := 0.6
var safety_open := false
var safety_flow := 0.0
var plug_exposed_time := 0.0
# fire
var zones := [0.0, 0.0, 0.0, 0.0]    # kg of fire on each part of the grate
var zone_t := [15.0, 15.0, 15.0, 15.0]
var green := [0.0, 0.0, 0.0, 0.0]    # freshly fired coal still giving off volatiles
var ash := 0.0
var burn_rate := 0.0                 # kg/s
var heat_kw := 0.0
var smoke_black := 0.0               # 0 clean .. 1 thick black smoke
var lit := false
var firelighters_in := false
# tender
var tender_water := 22730.0
var tender_coal := 8128.0
# engine
var chest_p := ATM
var cyl_flow := 0.0
var te := 0.0
var cutoff := 0.0
var cyl_water := 0.0
var cyl_temp := 15.0
var cyl_damaged := false
var slip_speed := 0.0
var slipping := false
var beat_phase := 0.0
var beat := false
var indicated_hp := 0.0
# brakes
var tp_vac := 0.0
var veh_tp: Array[float] = []
var veh_res: Array[float] = []
var brake_frac := 0.0
# injectors: 0 off, 1 working, 2 wasting at overflow
var inj_live := 0
var inj_exh := 0
var inj_live_feed := 0.0
var inj_exh_feed := 0.0
# misc
var whistle_on := 0.0
var scoop_pickup := 0.0
var scoop_damaged := false
var blowback_warned := false
var shovel_loaded := false
var fire_zone_sel := 0
var fire_cooldown := 0.0
var ai_fireman := true
var ai_driver := false
var ai_target_mph := 60.0
var _ai_cut_bias := 0.0
var _ai_t := 0.0
var _ai_fire_burst := 0
var _warned := {}
var steam_total := 0.0
var _gauge_test_t := 0.0


func setup(t: Train, c: Cab, start_state: int) -> void:
	train = t
	cab = c
	route_units = "imperial"
	veh_tp.resize(t.vehicles.size())
	veh_res.resize(t.vehicles.size())
	match start_state:
		GameSettings.StartState.COLD:
			water = GLASS_BASE_KG + GLASS_SPAN_KG * 0.72
			temp = 14.0
			zones = [0.0, 0.0, 0.0, 0.0]
			lit = false
			_setc("handbrake", 1.0)
			_setc("cocks", 1.0)
			_setc("reverser", 0.0)
		GameSettings.StartState.PREP:
			# banked overnight by the steam raiser: fire in the back corners, ~120 psi
			water = GLASS_BASE_KG + GLASS_SPAN_KG * 0.5
			temp = _t_for_psi(120.0)
			zones = [60.0, 60.0, 8.0, 8.0]
			zone_t = [900.0, 900.0, 650.0, 650.0]
			lit = true
			_setc("handbrake", 1.0)
			_setc("cocks", 1.0)
			_setc("reverser", 0.0)
			_setc("damper_back", 0.3)
		_:
			water = GLASS_BASE_KG + GLASS_SPAN_KG * 0.8
			temp = _t_for_psi(245.0)
			zones = [110.0, 110.0, 85.0, 85.0]
			zone_t = [1150.0, 1150.0, 1100.0, 1100.0]
			lit = true
			tp_vac = 21.0
			for i in range(veh_tp.size()):
				veh_tp[i] = 21.0
				veh_res[i] = 21.0
			cyl_temp = 160.0
			_setc("small_ejector", 1.0)
			_setc("handbrake", 0.0)
			_setc("cocks", 1.0)
			_setc("reverser", 65.0)
			_setc("damper_back", 1.0)
			_setc("damper_front", 0.5)
			_setc("brake", 0.25)
	_update_pressure()
	ai_fireman = GameSettings.ai_fireman
	ai_driver = GameSettings.ai_driver
	for id in ["coal", "firelighters", "gauge_test_l", "gauge_test_r", "fire_zone_0", "fire_zone_1", "fire_zone_2", "fire_zone_3"]:
		var ctl := cab.c(id)
		if ctl:
			ctl.changed.connect(_on_button)


func _on_button(ctl: CabControl) -> void:
	if ctl.value < 0.5:
		return
	match ctl.id:
		"coal":
			if tender_coal < SHOVEL_KG:
				notify("The tender is out of coal!", "warn")
			else:
				shovel_loaded = true
		"firelighters":
			light_fire()
		"gauge_test_l", "gauge_test_r":
			_warned["gauge_tested"] = true
			if true_level < 0.0:
				notify("Gauge glass blown through: NO WATER showing. Danger!", "fail")
			else:
				notify("Gauge glass blown through: water returns to %d%%. It is reading truly." % int(clampf(level, 0.0, 1.0) * 100.0), "info")
		_:
			if ctl.id.begins_with("fire_zone_"):
				var z := int(ctl.id.substr(10))
				if not shovel_loaded:
					notify("Take a shovelful from the coal hole first (or press E).", "info")
				elif fire_shovel(z):
					shovel_loaded = false


func _setc(id: String, v: float) -> void:
	var ctl := cab.c(id)
	if ctl:
		ctl.set_value(v)


func _v(id: String) -> float:
	return cab.val(id)


# ======================================================== thermodynamics
static func psat_mpa(t: float) -> float:
	return exp(16.3872 - 3885.70 / (t + 230.170)) / 1000.0


static func hf(t: float) -> float:
	return 4.2 * t + 0.0004 * t * t


static func t_from_hf(h: float) -> float:
	# inverse of hf (quadratic)
	return (-4.2 + sqrt(4.2 * 4.2 + 4.0 * 0.0004 * h)) / (2.0 * 0.0004)


func _t_for_psi(psi: float) -> float:
	var target := psi * PSI + ATM
	var lo := 20.0
	var hi := 260.0
	for i in range(40):
		var mid := (lo + hi) * 0.5
		if psat_mpa(mid) < target:
			lo = mid
		else:
			hi = mid
	return (lo + hi) * 0.5


func _update_pressure() -> void:
	p_abs = maxf(psat_mpa(temp), ATM)
	p_gauge = (p_abs - ATM) / PSI


# ================================================================== step
func step(dt: float) -> void:
	sim_time += dt
	fire_cooldown = maxf(0.0, fire_cooldown - dt)
	if ai_fireman:
		_ai_fireman(dt)
	if ai_driver:
		_ai_driver(dt)
	var v := train.speed
	var pf := clampf(p_gauge / WORK_PSI, 0.0, 1.2)

	# ---------------------------------------------------------- engine
	cutoff = _v("reverser") / 100.0
	var reg := _v("regulator")
	var wheel_v := absf(v) + slip_speed
	var n := wheel_v / (PI * DRIVER_D)
	_engine(reg, n, v, dt)

	# ---------------------------------------------------- steam users (kg/s)
	var blower := _v("blower") * 0.12 * pf
	var ej_large := _v("large_ejector") * 0.09 * pf
	var ej_small := _v("small_ejector") * 0.025 * pf
	whistle_on = _v("whistle")
	var whistle_flow := whistle_on * 0.09 * pf
	var heat_flow := _v("steam_heat") * 0.06 * pf
	var sand_flow := (0.03 * pf) if _v("sanders") > 0.5 else 0.0
	var cock_flow := (0.3 * reg * pf) if _v("cocks") > 0.5 else 0.0
	# safety valves: lift at 250 psi, reseat ~4 psi lower
	if p_gauge >= WORK_PSI:
		safety_open = true
	elif p_gauge < WORK_PSI - 4.0:
		safety_open = false
	safety_flow = clampf((p_gauge - (WORK_PSI - 5.0)) * 0.35, 0.0, 3.5) if safety_open else 0.0
	var leak := 0.004 * pf

	# ---------------------------------------------------------- injectors
	var inj_steam := 0.0
	var feed := 0.0
	var feed_energy := 0.0
	var res := _injector("live", _v("inj_live_water"), _v("inj_live_steam"), false)
	inj_live = res[0]
	inj_steam += res[1]
	feed += res[2]
	feed_energy += res[2] * hf(res[3])
	inj_live_feed = res[2]
	var res2 := _injector("exh", _v("inj_exh_water"), _v("inj_exh_steam"), true)
	inj_exh = res2[0]
	inj_steam += res2[1]
	feed += res2[2]
	feed_energy += res2[2] * hf(res2[3])
	inj_exh_feed = res2[2]
	if inj_live == 1 or inj_exh == 1:
		_warned["inj_tested"] = true
	tender_water = maxf(0.0, tender_water - (res[4] + res2[4]) * dt)

	steam_total = cyl_flow + blower + ej_large + ej_small + whistle_flow + heat_flow + sand_flow + cock_flow + safety_flow + leak + inj_steam

	# --------------------------------------------------------------- fire
	_fire(dt, blower, ej_large + ej_small)

	# ------------------------------------------------------------- boiler
	var hg := 2790.0
	var e := water * hf(temp)
	var q_loss := 0.6 * (temp - 15.0)
	e += (heat_kw - q_loss) * dt
	e -= steam_total * hg * dt
	e += feed_energy * dt
	water += (feed - steam_total) * dt
	water = maxf(water, 500.0)
	temp = clampf(t_from_hf(e / water), 2.0, 260.0)
	_update_pressure()
	true_level = (water - GLASS_BASE_KG) / GLASS_SPAN_KG
	var g := train.track.grade_at(train.front_s)
	var swell := 0.05 * clampf(steam_total / 3.0, 0.0, 1.0)
	level = true_level + swell + g * 10.0 + clampf(train.accel, -1.0, 1.0) * 0.03
	_failures(dt, reg)

	# -------------------------------------------------------------- brakes
	_vacuum(dt, ej_large, ej_small, pf)

	# ------------------------------------------------------ water troughs
	scoop_pickup = 0.0
	var scoop := _v("scoop")
	if scoop > 0.6 and not scoop_damaged:
		var on_trough := _on_troughs()
		if on_trough:
			var mph := absf(v) / 0.44704
			if mph > 25.0:
				scoop_pickup = clampf((mph - 25.0) * 9.0, 0.0, 450.0) * scoop   # kg/s (~2000 gal per trough at speed)
				var room := 22730.0 - tender_water
				if room <= 0.0:
					_warn_once("overflow", "Tender overflowing! Raise the scoop.", "warn")
				tender_water = minf(22730.0, tender_water + scoop_pickup * dt)
		elif absf(v) > 4.0 and _past_trough_end():
			scoop_damaged = true
			_setc("scoop", 0.0)
			notify("Water scoop struck the end of the troughs and was damaged!", "fail")

	# tender weight
	train.vehicles[1].mass_load = tender_water + tender_coal
	_sounds()
	if level < 0.12 and not _warned.has("lowwater"):
		_warn_once("lowwater", "Water level is low in the glass. Get an injector on!", "warn")
	elif level > 0.25:
		_warned.erase("lowwater")


func _engine(reg: float, n: float, v: float, dt: float) -> void:
	te = 0.0
	cyl_flow = 0.0
	indicated_hp = 0.0
	var c := absf(cutoff)
	if reg > 0.002 and p_abs > ATM + 0.02 and c > 0.01:
		var area := (reg / 0.12 * 0.08) if reg < 0.12 else (0.08 + (reg - 0.12) / 0.88 * 0.92)
		var a := REG_A * area
		# port throttling grows with revs and is worst at short cut-off (small valve openings)
		var wd := 1.0 / (1.0 + WD * n * n / (c + 0.15))
		var k := K0 * maxf(n, 0.05) * (c + 0.02) * wd
		chest_p = (-a * a + sqrt(a * a * a * a + 4.0 * k * k * a * a * p_abs)) / (2.0 * k * k)
		var flow := k * chest_p
		var p_ex := ATM + KB * flow * flow
		var fc := maxf(c, 0.05)
		var mep := 0.88 * chest_p * wd * fc * (1.0 + log(1.0 / fc)) - p_ex
		te = TE_K * mep * 1e6 * signf(cutoff)
		if cyl_damaged:
			te *= 0.66
		cyl_flow = flow if n > 0.06 else flow * 0.15    # standing: only fills the cylinders
		# water in the cylinders robs power and can burst a cover
		if cyl_water > 2.0:
			te *= clampf(1.0 - (cyl_water - 2.0) * 0.08, 0.3, 1.0)
	else:
		chest_p = move_toward(chest_p, ATM, dt * 0.5)
		# drifting: pumping losses unless the reverser is well out
		if n > 0.1:
			te = -1500.0 * clampf(n / 5.0, 0.0, 1.5) * (1.0 - c / 0.75) * signf(v)
	indicated_hp = absf(te * (absf(v) + slip_speed)) / 745.7
	# adhesion and wheelslip
	var mu := adhesion_mu()
	if _v("sanders") > 0.5:
		mu += 0.07 if weather == "rain" else 0.05
	var f_static := mu * ADHESIVE_KG * 9.81
	var f_kin := f_static * 0.7
	if not slipping and absf(te) > f_static and reg > 0.02:
		slipping = true
		notify("Slipping!", "warn")
	if slipping:
		var drive := absf(te) - f_kin
		slip_speed = maxf(0.0, slip_speed + drive / 9000.0 * dt * 4.0 - 2.0 * dt)
		if slip_speed <= 0.01 and absf(te) < f_static * 0.9:
			slipping = false
			slip_speed = 0.0
		slip_speed = minf(slip_speed, 40.0)
		traction_force = f_kin * signf(te)
		# violent slipping tears at the fire
		if slip_speed > 5.0:
			for i in range(4):
				zones[i] = maxf(0.0, zones[i] - zones[i] * 0.02 * dt)
	else:
		slip_speed = 0.0
		traction_force = te
	# exhaust beats: 6 per driving wheel revolution (3 cylinders, double acting)
	beat = false
	if cyl_flow > 0.01:
		beat_phase += n * 6.0 * dt
		if beat_phase >= 1.0:
			beat_phase = fmod(beat_phase, 1.0)
			beat = true
	# cylinder warming and condensate
	if cyl_flow > 0.01:
		cyl_temp = move_toward(cyl_temp, 300.0, cyl_flow * 25.0 * dt)
		cyl_water += cyl_flow * clampf((180.0 - cyl_temp) / 180.0, 0.0, 1.0) * 0.06 * dt
	else:
		cyl_temp = move_toward(cyl_temp, 15.0, 0.01 * dt)
	if _v("cocks") > 0.5:
		cyl_water = maxf(0.0, cyl_water - (0.4 + n * 0.5) * dt)
	elif n > 0.05:
		cyl_water = maxf(0.0, cyl_water - 0.01 * n * dt)


## Returns [state, steam_used, water_delivered, delivery_temp, tender_water_drawn]
func _injector(_nm: String, water_valve: float, steam_valve: float, exhaust: bool) -> Array:
	if steam_valve < 0.15:
		return [0, 0.0, 0.0, 0.0, water_valve * 0.6 if water_valve > 0.1 else 0.0]
	var pf := p_gauge
	var tender_ok := tender_water > 50.0
	var exh_available := exhaust and cyl_flow > 0.4 and _v("regulator") > 0.1
	var min_psi := 40.0 if exh_available else 70.0
	if pf < min_psi:
		# not enough pressure to force water into the boiler: blows out of the overflow
		return [2, 0.15 * steam_valve, 0.0, 0.0, water_valve * 0.8]
	if not tender_ok or water_valve < 0.25 or water_valve > 0.95:
		# wrong water setting: steam blows through or water runs to waste
		return [2, 0.2 * steam_valve, 0.0, 0.0, water_valve * 1.2]
	var deliver := (4.6 if not exhaust else 4.2) * steam_valve * clampf(water_valve * 1.4, 0.5, 1.0)
	var steam_used := 0.0
	var t_del := 70.0
	if exh_available:
		steam_used = 0.06 * steam_valve      # small live-steam supplement
		t_del = 95.0
	else:
		steam_used = 0.33 * steam_valve
		t_del = 72.0 if not exhaust else 80.0
	return [1, steam_used, deliver + steam_used, t_del, deliver]


func _fire(dt: float, blower: float, ejectors: float) -> void:
	var door := _v("firedoor")
	var dampers := clampf(_v("damper_front") * 0.55 + _v("damper_back") * 0.65, 0.0, 1.0)
	var hot := 0.0
	for i in range(4):
		hot = maxf(hot, zone_t[i])
	var natural := 0.05 + 0.1 * clampf((hot - 200.0) / 900.0, 0.0, 1.0)
	# Kylchap double blastpipe: ~1.8 kg of air through the grate per kg of exhaust steam
	var draught := natural + 2.1 * pow(cyl_flow, 0.9) + 9.0 * blower + 1.5 * ejectors
	var air_total := draught * (0.12 + 0.88 * dampers) * (1.0 - 0.25 * door)
	# bed permeability per zone
	var perm := [0.0, 0.0, 0.0, 0.0]
	var psum := 0.0
	for i in range(4):
		var thick: float = zones[i] / 720.0       # m (0.96 m^2 per quarter grate)
		perm[i] = 1.0 / (0.35 + thick / 0.08) / (1.0 + ash / 900.0)
		psum += perm[i]
	var bed := clampf(psum / (4.0 * 1.0 / (0.35 + 0.15 / 0.08)), 0.3, 1.6)
	air_total *= bed
	burn_rate = 0.0
	var q := 0.0
	var smoke := 0.0
	var secondary := 0.35 + 0.65 * clampf(door / 0.2, 0.0, 1.0)      # brick arch + air over the fire
	for i in range(4):
		var air: float = air_total * (perm[i] / maxf(psum, 0.001))
		var burn := 0.0
		if zone_t[i] > 550.0 and zones[i] > 0.05:
			burn = minf(air / 11.5, zones[i] * 0.02)
		zones[i] = maxf(0.0, zones[i] - burn * dt)
		ash += burn * 0.07 * dt
		burn_rate += burn
		var gv: float = green[i]
		var vol := minf(gv, burn * 1.5) if gv > 0.0 else 0.0
		green[i] = maxf(0.0, gv - (vol + gv * 0.03) * dt)
		smoke += vol * (1.0 - clampf(secondary, 0.0, 1.0))
		var comb := 0.88 + 0.1 * clampf(door * 4.0, 0.0, 1.0) - 0.25 * clampf((door - 0.4) / 0.6, 0.0, 1.0)
		q += burn * CV * comb
		# zone temperature
		var target := 120.0
		if burn > 0.0001:
			target = clampf(650.0 + 1700.0 * pow(burn / 0.08, 0.35), 650.0, 1450.0)
		if zones[i] < 2.0:
			target = minf(target, 300.0)       # hole in the fire
		# fire spreads from a burning neighbour across the grate
		if zone_t[i] < 600.0 and zones[i] > 2.0:
			var nb := maxf(zone_t[i ^ 1], zone_t[i ^ 2])
			if nb > 800.0:
				target = maxf(target, 720.0)
		var tau := 25.0 if target > zone_t[i] else 90.0
		zone_t[i] += (target - zone_t[i]) * minf(1.0, dt / tau)
	# a thin or holed fire pulls cold air through, wasting heat
	var holes := 0
	for i in range(4):
		if zones[i] < 6.0 and lit:
			holes += 1
	var eta := clampf(0.84 - 0.18 * clampf(burn_rate / 0.6, 0.0, 1.2) - 0.06 * holes - 0.08 * clampf((door - 0.2) / 0.8, 0.0, 1.0), 0.4, 0.84)
	heat_kw = q * eta
	smoke_black = clampf(smoke * 12.0, 0.0, 1.0)
	var any_hot := false
	for i in range(4):
		if zone_t[i] > 550.0:
			any_hot = true
	if lit and not any_hot:
		lit = false
		notify("The fire has gone out.", "fail")
	if any_hot:
		lit = true


func _vacuum(dt: float, ej_large: float, ej_small: float, pf: float) -> void:
	var nveh := train.vehicles.size()
	var vol := 1.0 + 0.18 * nveh
	var apply := _v("brake")
	var gain := (ej_large / 0.09 * 3.2 + ej_small / 0.025 * 0.45) * clampf(pf * 1.5, 0.0, 1.0) * (26.0 - tp_vac) / 26.0 / vol
	var leak := 0.025 * nveh * (tp_vac / 21.0) / vol
	var admit := 0.0
	if apply > 0.08:
		admit = 7.0 * pow((apply - 0.08) / 0.92, 1.4) * (tp_vac / 21.0 + 0.05) / vol * 3.0
	tp_vac = clampf(tp_vac + (gain - leak - admit) * dt, 0.0, 25.0)
	if tp_vac > 21.0 and _v("large_ejector") < 0.5:
		tp_vac = maxf(21.0, tp_vac - 2.0 * dt)       # relief valve holds 21 in
	# propagate down the train; reservoirs (upper chambers) follow on release only
	var v_kmh := absf(train.speed) * 3.6
	var shoe := (100.0 + v_kmh) / (100.0 + 5.0 * v_kmh)
	var force := 0.0
	brake_frac = 0.0
	for i in range(nveh):
		var tau := 0.3 + 0.4 * i
		veh_tp[i] += (tp_vac - veh_tp[i]) * minf(1.0, dt / tau)
		if veh_tp[i] > veh_res[i]:
			veh_res[i] = veh_tp[i]
		else:
			veh_res[i] = maxf(veh_tp[i], veh_res[i] - 0.002 * dt)
		var frac := clampf((veh_res[i] - veh_tp[i]) / 21.0, 0.0, 1.0)
		var veh := train.vehicles[i]
		force += frac * veh.brake_mass_ratio * veh.total_mass() * 9.81 * 0.125 * shoe
		if i == 0:
			brake_frac = frac
	# tender hand brake
	var hb := _v("handbrake")
	if nveh > 1:
		force += hb * train.vehicles[1].total_mass() * 9.81 * 0.07 * shoe
	brake_force = force


func _on_troughs() -> bool:
	for tr in train.track.route.get("troughs", []):
		var s := train.track.wrap_s(train.front_s - 18.0)
		if s >= tr[0] and s <= tr[0] + tr[1]:
			return true
	return false


func _past_trough_end() -> bool:
	for tr in train.track.route.get("troughs", []):
		var s := train.track.wrap_s(train.front_s - 18.0)
		var end: float = tr[0] + tr[1]
		if s > end and s < end + 30.0:
			return true
	return false


func _failures(dt: float, reg: float) -> void:
	# fusible plug: crown sheet uncovered while the fire is hot
	if true_level < -0.12 and burn_rate > 0.002:
		plug_exposed_time += dt
		if plug_exposed_time > 2.0:
			_warn_once("crown", "WATER BELOW THE GLASS! Crown sheet uncovered!", "fail")
		if plug_exposed_time > 25.0:
			fail("Fusible plug melted: you dropped the plug. Steam has put the fire out. (Never let the water out of the glass.)")
			for i in range(4):
				zones[i] *= 0.1
				zone_t[i] = 200.0
	else:
		plug_exposed_time = maxf(0.0, plug_exposed_time - dt * 2.0)
		_warned.erase("crown")
	# priming: boiler overfull, water carried over to the cylinders
	if true_level > 1.08 and cyl_flow > 0.5:
		cyl_water += (true_level - 1.0) * cyl_flow * 0.8 * dt
		_warn_once("priming", "Priming! Water is going over with the steam. Shut the injector, ease the regulator, open the cocks.", "warn")
	elif true_level < 1.0:
		_warned.erase("priming")
	if cyl_water > 3.0 and _v("cocks") < 0.5 and cyl_flow > 0.2:
		_warn_once("knock", "Water in the cylinders (knocking). Open the cylinder cocks!", "warn")
	if cyl_water > 7.0 and _v("cocks") < 0.5 and reg > 0.2 and absf(train.speed) > 0.5 and not cyl_damaged:
		cyl_damaged = true
		cyl_water = 0.0
		notify("BANG! Hydraulic lock: a cylinder cover has blown out. One cylinder is out of use.", "fail")
	# blowback: regulator shut at speed with no blower and the fire door open
	if reg < 0.03 and absf(train.speed) > 13.0 and _v("blower") < 0.1 and _v("firedoor") > 0.3 and lit:
		if not blowback_warned:
			blowback_warned = true
			notify("BLOWBACK! Flames from the firehole. Always put the blower on before shutting the regulator.", "fail")
	else:
		blowback_warned = false
	if tender_water < 1500.0:
		_warn_once("tender", "Tender water low (%d gal). Pick up water at the troughs." % int(tender_water / 4.546), "warn")


func _warn_once(key: String, t: String, kind: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	notify(t, kind)


func _sounds() -> void:
	sound["beat"] = beat
	sound["exhaust"] = cyl_flow
	sound["chest"] = chest_p
	sound["speed"] = absf(train.speed)
	sound["safety"] = safety_flow
	sound["blower"] = _v("blower") * clampf(p_gauge / WORK_PSI, 0.0, 1.0)
	sound["ejector"] = _v("large_ejector") * clampf(p_gauge / WORK_PSI, 0.0, 1.0) + _v("small_ejector") * 0.25
	sound["whistle"] = whistle_on if p_gauge > 20.0 else 0.0
	sound["injector"] = (1.0 if inj_live == 1 else (0.6 if inj_live == 2 else 0.0)) + (1.0 if inj_exh == 1 else (0.6 if inj_exh == 2 else 0.0))
	sound["cocks"] = (1.0 if _v("cocks") > 0.5 else 0.0) * clampf(_v("regulator") * 3.0, 0.0, 1.0) * clampf(p_gauge / 100.0, 0.0, 1.0)
	sound["fire"] = _v("firedoor") * clampf(burn_rate / 0.2, 0.1, 1.0) if lit else 0.0
	sound["slip"] = slip_speed
	sound["brake"] = brake_frac
	sound["scoop"] = scoop_pickup
	sound["jointed"] = true


# ============================================================ fireman's work
## Throw one shovelful onto a zone (needs the firehole door open).
func fire_shovel(zone: int) -> bool:
	if fire_cooldown > 0.0:
		return false
	if _v("firedoor") < 0.5:
		notify("Open the firehole door first.", "info")
		return false
	if tender_coal < SHOVEL_KG:
		notify("The tender is out of coal!", "warn")
		return false
	tender_coal -= SHOVEL_KG
	var z := clampi(zone, 0, 3)
	var before: float = zones[z]
	zones[z] += SHOVEL_KG
	green[z] += SHOVEL_KG * 0.3
	# fresh coal cools that part of the fire for a while
	zone_t[z] = (zone_t[z] * before + 15.0 * SHOVEL_KG * 2.0) / (before + SHOVEL_KG * 2.0) if before > 0.0 else zone_t[z]
	if not lit and firelighters_in and zone_t[z] > 550.0:
		lit = true
	fire_cooldown = 1.1
	sound["shovel"] = true
	return true


func light_fire() -> void:
	if lit:
		notify("The fire is already alight.", "info")
		return
	var total := 0.0
	for zkg in zones:
		total += zkg
	if total < 40.0:
		notify("Spread some coal over the grate first (about 15-20 shovelfuls), then light it with firelighters.", "info")
		return
	if _v("firedoor") < 0.5:
		notify("Open the firehole door to put the firelighters in.", "info")
		return
	firelighters_in = true
	for i in range(4):
		if zones[i] > 3.0:
			zone_t[i] = 700.0
	lit = true
	notify("Firelighters lit. Open the dampers, keep the door slightly open, and build the fire up gradually.", "info")


func handle_action(action: String) -> void:
	match action:
		"fire_shovel":
			fire_shovel(fire_zone_sel)
		"fire_zone":
			fire_zone_sel = (fire_zone_sel + 1) % 4
			notify("Firing to the %s of the grate." % ZONE_NAMES[fire_zone_sel], "info")
		"firedoor":
			_setc("firedoor", 0.0 if _v("firedoor") > 0.3 else 1.0)
		"cocks":
			_setc("cocks", 0.0 if _v("cocks") > 0.5 else 1.0)
		"sand":
			_setc("sanders", 0.0 if _v("sanders") > 0.5 else 1.0)
		"blower":
			var b := _v("blower")
			_setc("blower", 0.0 if b > 0.6 else (0.5 if b < 0.25 else 1.0))
		"ejector":
			_setc("large_ejector", 0.0 if _v("large_ejector") > 0.5 else 1.0)
		"injector_live":
			if _v("inj_live_steam") > 0.3:
				_setc("inj_live_steam", 0.0)
				_setc("inj_live_water", 0.0)
			else:
				_setc("inj_live_water", 0.6)
				_setc("inj_live_steam", 1.0)
		"injector_exhaust":
			if _v("inj_exh_steam") > 0.3:
				_setc("inj_exh_steam", 0.0)
				_setc("inj_exh_water", 0.0)
			else:
				_setc("inj_exh_water", 0.6)
				_setc("inj_exh_steam", 1.0)
		"emergency":
			_setc("regulator", 0.0)
			_setc("brake", 1.0)
		"ai_fireman":
			ai_fireman = not ai_fireman
			notify("AI fireman " + ("ON: the boiler is being looked after." if ai_fireman else "OFF: you are firing."), "info")
		"ai_driver":
			ai_driver = not ai_driver
			notify("AI driver " + ("ON (target %d mph, PgUp/PgDn to change)." % int(ai_target_mph) if ai_driver else "OFF: you are driving."), "info")
		"ai_speed_up":
			ai_target_mph = minf(ai_target_mph + 5.0, 126.0)
			notify("AI driver target: %d mph" % int(ai_target_mph), "info")
		"ai_speed_down":
			ai_target_mph = maxf(ai_target_mph - 5.0, 0.0)
			notify("AI driver target: %d mph" % int(ai_target_mph), "info")


func hold(dt: float) -> void:
	var reg := cab.c("regulator")
	if Input.is_action_pressed("main_inc"):
		reg.set_value(reg.value + 0.35 * dt, true)
	if Input.is_action_pressed("main_dec"):
		reg.set_value(reg.value - 0.5 * dt, true)
	var rv := cab.c("reverser")
	if Input.is_action_pressed("rev_fwd"):
		rv.set_value(rv.value + 22.0 * dt, true)
	if Input.is_action_pressed("rev_back"):
		rv.set_value(rv.value - 22.0 * dt, true)
	var br := cab.c("brake")
	if Input.is_action_pressed("brake_apply"):
		br.set_value(br.value + 0.6 * dt, true)
	if Input.is_action_pressed("brake_release"):
		br.set_value(br.value - 0.8 * dt, true)
	var wh := cab.c("whistle")
	if Input.is_action_pressed("horn"):
		wh.set_value(1.0, true)
	elif Input.is_action_just_released("horn"):
		wh.set_value(0.0, true)


# =================================================================== AI
func _ai_fireman(dt: float) -> void:
	_ai_t += dt
	if _ai_t < 0.6:
		return
	_ai_t = 0.0
	var reg := _v("regulator")
	var moving := absf(train.speed) > 1.0
	var total := 0.0
	for zkg in zones:
		total += zkg
	# --- not lit: lay and light the fire
	if not lit:
		if total < 60.0:
			_setc("firedoor", 1.0)
			_ai_throw()
			return
		_setc("firedoor", 1.0)
		light_fire()
		_setc("damper_back", 1.0)
		_setc("damper_front", 0.5)
		_setc("firedoor", 0.2)
		return
	# --- target fire depending on steam demand
	var demand := cyl_flow + 0.25
	var desired := 130.0 + demand * 85.0
	if p_gauge < 120.0 and not moving:
		desired = 170.0
	if p_gauge > WORK_PSI - 8.0:
		desired *= 0.8          # don't blow off: hold back a little near full pressure
	if _ai_fire_burst > 0:
		_setc("firedoor", 1.0)
		if fire_cooldown <= 0.0 and _ai_throw():
			_ai_fire_burst -= 1
		if _ai_fire_burst <= 0:
			_setc("firedoor", 0.15 if reg > 0.05 else 0.05)
	elif total < desired and (p_gauge < WORK_PSI - 6.0 or total < desired * 0.7):
		_ai_fire_burst = clampi(int((desired - total) / SHOVEL_KG), 1, 5)
	else:
		_setc("firedoor", 0.15 if reg > 0.05 else 0.05)
	# --- dampers and blower
	if reg > 0.05:
		_setc("damper_back", 1.0)
		_setc("damper_front", 0.5)
	elif p_gauge < WORK_PSI - 10.0:
		_setc("damper_back", 1.0)
		_setc("damper_front", 0.3)
	else:
		_setc("damper_back", 0.3)
		_setc("damper_front", 0.0)
	var want_blower := 0.0
	if p_gauge < 60.0:
		want_blower = 0.3 if p_gauge > 25.0 else 0.0
	elif reg < 0.05 and (moving or p_gauge < WORK_PSI - 15.0):
		want_blower = 0.5
	elif reg > 0.05 and absf(train.speed) < 6.0:
		want_blower = 0.25
	if p_gauge >= WORK_PSI - 2.0 and reg < 0.05:
		want_blower = minf(want_blower, 0.15)
	_setc("blower", want_blower)
	# --- injectors: keep the glass between ~65% and ~85%
	var lv := true_level
	var want_inj := lv < 0.66 or (p_gauge > WORK_PSI - 1.5 and lv < 0.9)
	var stop_inj := lv > 0.86 or p_gauge < 120.0
	var use_exh := reg > 0.1 and cyl_flow > 0.4
	if want_inj and not stop_inj:
		if use_exh:
			_setc("inj_exh_water", 0.6)
			_setc("inj_exh_steam", 1.0)
			_setc("inj_live_steam", 0.0)
			_setc("inj_live_water", 0.0)
		else:
			_setc("inj_live_water", 0.6)
			_setc("inj_live_steam", 1.0)
			_setc("inj_exh_steam", 0.0)
			_setc("inj_exh_water", 0.0)
	elif stop_inj or lv > 0.8:
		_setc("inj_live_steam", 0.0)
		_setc("inj_live_water", 0.0)
		_setc("inj_exh_steam", 0.0)
		_setc("inj_exh_water", 0.0)
	# --- water troughs
	if _on_troughs() and absf(train.speed) / 0.44704 > 30.0 and tender_water < 21000.0:
		_setc("scoop", 1.0)
	elif _v("scoop") > 0.0 and (not _on_troughs() or tender_water > 22000.0):
		_setc("scoop", 0.0)


func _ai_throw() -> bool:
	# thinnest zone first, with a bit more at the back (the A4 grate slopes forward)
	var best := 0
	var bv := INF
	for i in range(4):
		var weight: float = zones[i] * (0.85 if i < 2 else 1.0)
		if weight < bv:
			bv = weight
			best = i
	return fire_shovel(best)


func _ai_driver(dt: float) -> void:
	var mph := absf(train.speed) / 0.44704
	var lim := train.track.min_limit_between(train.front_s, train.front_s + 1500.0) / 1.609344
	var tgt := minf(ai_target_mph, lim)
	var reg := cab.c("regulator")
	var rv := cab.c("reverser")
	var br := cab.c("brake")
	# vacuum first
	if tp_vac < 19.0 and mph < 1.0:
		_setc("large_ejector", 1.0)
		br.set_value(0.0)
		return
	if tp_vac >= 20.5:
		_setc("large_ejector", 0.0)
		_setc("small_ejector", 1.0)
	if _v("handbrake") > 0.1:
		return
	if tgt < 1.0:
		reg.set_value(0.0)
		br.set_value(0.5 if mph > 1.0 else 0.25)
		return
	if mph < 8.0 and _v("cocks") < 0.5 and cyl_temp < 120.0:
		_setc("cocks", 1.0)
	elif mph > 8.0 and _v("cocks") > 0.5:
		_setc("cocks", 0.0)
	# notch up as speed rises, but drop the reverser further down if she's struggling (banks)
	if reg.value > 0.95 and mph < tgt - 8.0 and train.accel < 0.01 and p_gauge > 225.0:
		_ai_cut_bias = minf(_ai_cut_bias + 1.0 * dt, 15.0)
	elif mph > tgt - 1.0 or p_gauge < 215.0:
		_ai_cut_bias = maxf(_ai_cut_bias - 3.0 * dt, 0.0)
	var desired_cut := clampf(65.0 - mph * 0.9 + _ai_cut_bias, 15.0, 65.0)
	rv.set_value(move_toward(rv.value, desired_cut, 20.0 * dt))
	if mph > tgt + 6.0:
		reg.set_value(0.0)
		br.set_value(clampf((mph - tgt - 6.0) * 0.05, 0.15, 0.6))
	elif mph > tgt + 1.0:
		reg.set_value(move_toward(reg.value, 0.0, 0.3 * dt))
		br.set_value(0.0)
	else:
		br.set_value(0.0)
		var want := 0.15 if mph < 3.0 else (0.55 if mph < 15.0 else 1.0)
		if slipping:
			want = 0.05
		reg.set_value(move_toward(reg.value, want, 0.25 * dt))


# ================================================================== HUD
func speed_text() -> String:
	return "%d mph" % int(absf(train.speed) / 0.44704)


func hud_lines() -> PackedStringArray:
	var out := PackedStringArray()
	out.append("Boiler %d psi   Steam chest %d psi   Glass %d%%" % [int(p_gauge), int(maxf(0.0, (chest_p - ATM) / PSI)), int(clampf(level, -0.2, 1.2) * 100.0)])
	out.append("Cut-off %d%% %s   Regulator %d%%   Vacuum %.0f in" % [int(absf(cutoff) * 100.0), "fwd" if cutoff >= 0.0 else "rev", int(_v("regulator") * 100.0), tp_vac])
	out.append("Fire %d kg  burning %d kg/h  %s   Indicated %d hp" % [int(zones[0] + zones[1] + zones[2] + zones[3]), int(burn_rate * 3600.0), "LIT" if lit else "OUT", int(indicated_hp)])
	out.append("Tender: water %d gal  coal %.1f tons   %s" % [int(tender_water / 4.546), tender_coal / 1016.0, "AI fireman ON" if ai_fireman else "You are firing"])
	return out


func checklist() -> Array:
	var tot := 0.0
	for zkg in zones:
		tot += zkg
	return [
		["Water showing in the gauge glass (> 1/2)", level > 0.5],
		["Fire laid over the grate and lit", lit],
		["Dampers open", _v("damper_back") > 0.4],
		["Blower on once pressure > 40 psi (draws the fire)", p_gauge < 40.0 or _v("blower") > 0.1 or _v("regulator") > 0.05],
		["Fire built up (about 300-400 kg, thicker at the back)", tot > 250.0],
		["Pressure near 250 psi (safety valves just simmering)", p_gauge > 220.0],
		["Gauge glass tested (blow through)", _warned.has("gauge_tested")],
		["An injector proved to work", inj_live == 1 or inj_exh == 1 or _warned.has("inj_tested")],
		["Vacuum created: 21 in with the large ejector", tp_vac > 19.0],
		["Small ejector on to hold the vacuum", _v("small_ejector") > 0.5],
		["Tender hand brake released (fireman's side)", _v("handbrake") < 0.05],
		["Cylinder cocks open for starting", _v("cocks") > 0.5 or absf(train.speed) > 3.0],
		["Reverser in full forward gear (65-75%)", cutoff > 0.5 or absf(train.speed) > 3.0],
		["Whistle, then release brake and ease the regulator open", absf(train.speed) > 0.5],
		["Cocks closed once the cylinders are clear", _v("cocks") < 0.5 and absf(train.speed) > 3.0],
		["Notch up the reverser (15-25%) as speed rises", absf(train.speed) > 15.0 and cutoff < 0.3],
	]


func help_text() -> String:
	return """[b]LNER A4 4468 Mallard: driving[/b]
A / D  regulator close / open (hold)          W / S  reverser screw forward / back (hold)
; / '  vacuum brake release / apply (hold)     J  large ejector on/off
Space  chime whistle                          X  steam sanders   C  cylinder cocks
Backspace  shut regulator + full brake

[b]Firing[/b]
R  firehole door    E  fire one shovelful    Z  choose part of the grate
B  blower (off / half / full)    I  live-steam injector    O  exhaust-steam injector
F5  AI fireman on/off    F6  AI driver on/off (PgUp/PgDn sets its speed)
2  go to the fireman's side.  Every valve, lever and wheel in the cab works with the mouse:
left-drag levers and wheels, scroll over anything to adjust it, right-drag to look around.

[b]Rules of the footplate[/b]
- Never let the water drop out of the bottom of the glass (fusible plug!).
- Put the blower on BEFORE shutting the regulator at speed (blowback).
- Open the cylinder cocks when starting from cold; close them once she's warm.
- Fire little and often to the thin spots; black smoke = too much at once or door shut.
- Use the exhaust injector while steaming, the live injector when standing.
- Lower the scoop over the troughs above 30 mph; lift it before they end!"""
