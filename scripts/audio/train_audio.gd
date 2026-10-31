class_name TrainAudio
extends Node
## Real-time synthesised sound (no audio files needed). Reads sim.sound values.

const RATE := 22050.0
const HORN_K5 := [311.1, 370.0, 415.3, 493.9, 622.3]

var player: AudioStreamPlayer
var pb: AudioStreamGeneratorPlayback
var sim: TrainSim
var steam := false
var diesel := false
var near_unit := 0             # diesel: the locomotive the listener is in or next to
var _dp := PackedFloat64Array()   # diesel oscillator phases
var _dl := PackedFloat64Array()   # diesel filter states
var _rpm := PackedFloat64Array([0.0, 0.0])
var _load := PackedFloat64Array([0.0, 0.0])
var _turbo := PackedFloat64Array([0.0, 0.0])
var _crank := PackedFloat64Array([0.0, 0.0])
var _comp := PackedFloat64Array([0.0, 0.0])
var _dbb := PackedFloat64Array([0.0, 0.0])
var _fan := PackedFloat64Array([0.0, 0.0])
var _ac := PackedFloat64Array([0.0, 0.0])
var _gain := PackedFloat64Array([1.0, 0.4])
var vol := 0.8
var _ph := {}                 # oscillator phases
var _lp := {}                 # filter states
var _env := {}                # envelopes
var _beat_phase := 0.0
var _joint_dist := 0.0
var _clicks: Array[float] = []   # pending click times (s)
var _t := 0.0
var _seed := 12345
var p := {}                   # smoothed parameters
var in_cab := true
var xing_bell := 0.0          # level crossing bells (set by the game from the camera's distance)


## mode: "electric", "steam" or "diesel"
func setup(s: TrainSim, mode: String) -> void:
	sim = s
	steam = mode == "steam"
	diesel = mode == "diesel"
	_dp.resize(64)
	_dl.resize(64)
	vol = GameSettings.master_volume
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.12
	player = AudioStreamPlayer.new()
	player.stream = gen
	player.volume_db = -4.0
	add_child(player)
	player.play()
	pb = player.get_stream_playback()


func _noise() -> float:
	_seed ^= (_seed << 13) & 0xFFFFFFFF
	_seed ^= (_seed >> 17)
	_seed ^= (_seed << 5) & 0xFFFFFFFF
	return float(_seed & 0xFFFF) / 32768.0 - 1.0


func _lowpass(key: String, x: float, a: float) -> float:
	var y: float = _lp.get(key, 0.0)
	y += a * (x - y)
	_lp[key] = y
	return y


func _osc(key: String, f: float) -> float:
	var ph: float = _ph.get(key, 0.0) + f / RATE
	ph -= floorf(ph)
	_ph[key] = ph
	return sin(ph * TAU)


func _sq(key: String, f: float) -> float:
	var ph: float = _ph.get(key, 0.0) + f / RATE
	ph -= floorf(ph)
	_ph[key] = ph
	return 1.0 if ph < 0.5 else -1.0


func _smooth(key: String, target: float, rate: float, dt: float) -> float:
	var v: float = p.get(key, 0.0)
	v += (target - v) * minf(1.0, rate * dt)
	p[key] = v
	return v


func update_audio(delta: float, _time_scale: float, cab_view: bool) -> void:
	if pb == null or sim == null:
		return
	in_cab = cab_view
	var s := sim.sound
	var spd: float = s.get("speed", 0.0)
	_smooth("speed", spd, 4.0, delta)
	if steam:
		_smooth("exhaust", clampf(float(s.get("exhaust", 0.0)) / 3.0, 0.0, 1.3), 10.0, delta)
		_smooth("safety", clampf(float(s.get("safety", 0.0)) / 1.5, 0.0, 1.0), 6.0, delta)
		_smooth("blower", float(s.get("blower", 0.0)), 5.0, delta)
		_smooth("ejector", clampf(float(s.get("ejector", 0.0)), 0.0, 1.2), 5.0, delta)
		_smooth("whistle", float(s.get("whistle", 0.0)), 18.0, delta)
		_smooth("injector", clampf(float(s.get("injector", 0.0)), 0.0, 1.5), 4.0, delta)
		_smooth("cocks", float(s.get("cocks", 0.0)), 8.0, delta)
		_smooth("fire", float(s.get("fire", 0.0)), 4.0, delta)
		_smooth("slip", clampf(float(s.get("slip", 0.0)) / 10.0, 0.0, 1.0), 5.0, delta)
		_smooth("scoop", clampf(float(s.get("scoop", 0.0)) / 300.0, 0.0, 1.0), 3.0, delta)
		_smooth("gauge_blow", float(s.get("gauge_blow", 0.0)), 20.0, delta)
		_smooth("overflow", float(s.get("overflow", 0.0)), 4.0, delta)
	elif diesel:
		for u in range(2):
			_rpm[u] = _smooth("rpm%d" % u, float(s.get("rpm%d" % u, 0.0)), 4.0, delta)
			_load[u] = _smooth("load%d" % u, float(s.get("load%d" % u, 0.0)), 2.5, delta)
			_turbo[u] = _smooth("turbo%d" % u, float(s.get("turbo%d" % u, 0.0)), 3.0, delta)
			_crank[u] = _smooth("crank%d" % u, float(s.get("crank%d" % u, 0.0)), 12.0, delta)
			_comp[u] = _smooth("comp%d" % u, float(s.get("comp%d" % u, 0.0)), 3.0, delta)
			_dbb[u] = _smooth("db%d" % u, float(s.get("db%d" % u, 0.0)), 1.5, delta)
			_fan[u] = _smooth("fan%d" % u, float(s.get("fan%d" % u, 0.0)), 1.0, delta)
			_ac[u] = _smooth("cabac%d" % u, float(s.get("cabac%d" % u, 0.0)), 1.0, delta)
			# the engine you are next to is loud, the other one 22 m away
			var near := u == near_unit
			_gain[u] = (0.8 if near else 0.3) if cab_view else (1.0 if near else 0.55)
		_smooth("horn", float(s.get("horn", 0.0)), 25.0, delta)
		_smooth("alerter", float(s.get("alerter", 0.0)), 30.0, delta)
		_smooth("inverter", float(s.get("inverter", 0.0)), 4.0, delta)
		_smooth("release", float(s.get("release", 0.0)), 6.0, delta)
		_smooth("sand", float(s.get("sand", 0.0)), 8.0, delta)
		_smooth("bc", float(s.get("bc", 0.0)), 3.0, delta)
	else:
		_smooth("traction", float(s.get("traction", 0.0)), 6.0, delta)
		_smooth("regen", float(s.get("regen", 0.0)), 6.0, delta)
		_smooth("comp", float(s.get("compressor", 0.0)), 2.0, delta)
		_smooth("aux", float(s.get("aux_comp", 0.0)), 3.0, delta)
		_smooth("siv", float(s.get("siv", 0.0)), 1.0, delta)
		_smooth("horn_hi", float(s.get("horn_hi", 0.0)), 25.0, delta)
		_smooth("horn_lo", float(s.get("horn_lo", 0.0)), 25.0, delta)
		_smooth("chime", float(s.get("chime", 0.0)), 30.0, delta)
		_smooth("vig", float(s.get("vigilance", 0.0)), 30.0, delta)
		_smooth("dsd", float(s.get("dsd", 0.0)), 30.0, delta)
		_smooth("etcs", float(s.get("etcs", 0.0)), 30.0, delta)
		_smooth("bc", float(s.get("bc", 0.0)), 3.0, delta)
		_smooth("hvac", float(s.get("hvac", 0.0)), 0.6, delta)
		_smooth("demister", float(s.get("demister", 0.0)), 1.2, delta)
		_smooth("washer", float(s.get("washer", 0.0)), 20.0, delta)
		_smooth("wiper", float(s.get("wiper", 0.0)), 8.0, delta)
	_smooth("bell", xing_bell, 6.0, delta)
	var frames := pb.get_frames_available()
	if frames <= 0:
		return
	var buf := PackedVector2Array()
	buf.resize(frames)
	var dt := 1.0 / RATE
	var v: float = p.get("speed", 0.0)
	var vk := v * 3.6
	# rail joints (1930s 60 ft rails): clicks for each axle of the cab vehicle
	if s.get("jointed", false) and v > 0.3:
		var axles := [0.0, 2.2, 4.4, 6.6, 9.0]
		var before := _joint_dist
		_joint_dist += v * delta
		for ax in axles:
			var a0 := fmod(before + 18.288 - ax, 18.288)
			var a1 := a0 + v * delta
			if a1 >= 18.288:
				_clicks.append(_t + (18.288 - a0) / maxf(v, 0.01))
	for i in range(frames):
		_t += dt
		var out := 0.0
		var n := _noise()
		# rolling + wind (common)
		var roll := _lowpass("roll", n, 0.02 + v * 0.0008) * clampf(v / 30.0, 0.0, 1.0) * 0.55
		var wind := (n - _lowpass("wind_lp", n, 0.25)) * clampf((v - 10.0) / 50.0, 0.0, 1.0) * 0.18
		out += roll + wind
		if not _clicks.is_empty() and _t >= _clicks[0]:
			_clicks.remove_at(0)
			_env["click"] = 1.0
		var ce: float = _env.get("click", 0.0)
		if ce > 0.001:
			out += (_osc("click_o", 95.0) * 0.6 + n * 0.5) * ce * 0.9
			_env["click"] = ce * 0.9985
		if steam:
			out += _steam_sample(n, v, dt)
		elif diesel:
			out += _diesel_sample(n, vk)
		else:
			out += _electric_sample(n, v, vk)
		# level crossing bell: struck twice a second, inharmonic partials
		var bl: float = p.get("bell", 0.0)
		if bl > 0.002:
			var be := exp(-fmod(_t, 0.5) * 8.0)
			out += (_osc("bell1", 1210.0) * 0.5 + _osc("bell2", 2740.0) * 0.28 + _osc("bell3", 4030.0) * 0.12) * be * bl * (0.22 if in_cab else 0.4)
		out = clampf(out * vol * 0.45, -1.0, 1.0)
		buf[i] = Vector2(out, out)
	pb.push_buffer(buf)


func _steam_sample(n: float, v: float, dt: float) -> float:
	var out := 0.0
	var ex: float = p.get("exhaust", 0.0)
	var slip: float = p.get("slip", 0.0)
	# exhaust beats: 6 per revolution of the 6 ft 8 in drivers
	var revs := (v + slip * 10.0) / (PI * 2.032)
	var beat_rate := revs * 6.0
	if ex > 0.02:
		_beat_phase += beat_rate * dt
		if _beat_phase >= 1.0:
			_beat_phase -= floorf(_beat_phase)
			_env["chuff"] = 1.0
		elif beat_rate < 0.05 and _env.get("chuff", 0.0) < 0.01:
			pass
	var ch: float = _env.get("chuff", 0.0)
	var decay := clampf(0.9993 - beat_rate * 0.00004, 0.995, 0.9995)
	_env["chuff"] = ch * decay
	var body := _lowpass("chuff1", n, 0.09) - _lowpass("chuff2", n, 0.012)
	out += body * (ch * 2.4 + 0.25 * clampf(beat_rate / 25.0, 0.0, 1.0)) * ex * 1.6
	# cylinder cocks: sharp hiss with each beat
	var ck: float = p.get("cocks", 0.0)
	if ck > 0.01:
		out += (n - _lowpass("cock_hp", n, 0.4)) * ck * (0.35 + ch * 0.9)
	# safety valves: roaring high hiss
	var sv: float = p.get("safety", 0.0)
	if sv > 0.01:
		out += (n - _lowpass("sv_hp", n, 0.15)) * sv * 1.4
	var bl: float = p.get("blower", 0.0)
	if bl > 0.01:
		out += (_lowpass("bl_lp", n, 0.3) - _lowpass("bl_hp", n, 0.05)) * bl * 0.5
	var ej: float = p.get("ejector", 0.0)
	if ej > 0.01:
		out += ((n - _lowpass("ej_hp", n, 0.3)) * 0.4 + _osc("ej_tone", 1250.0) * 0.03) * ej * 0.5
	var inj: float = p.get("injector", 0.0)
	if inj > 0.01:
		out += ((n - _lowpass("inj_hp", n, 0.55)) * 0.25 + _osc("inj_tone", 2400.0 + _osc("inj_w", 3.0) * 40.0) * 0.06) * inj
	var fire: float = p.get("fire", 0.0)
	if fire > 0.01:
		out += _lowpass("fire_lp", n, 0.03) * fire * 1.2
	# blowing through the gauge glass: a sharp roar of steam and water at the drain
	var gb: float = p.get("gauge_blow", 0.0)
	if gb > 0.01:
		out += (n - _lowpass("gb_hp", n, 0.35)) * gb * 0.9
	# water running out of an injector overflow onto the ballast
	var ov: float = p.get("overflow", 0.0)
	if ov > 0.01:
		out += (_lowpass("ov_lp", n, 0.08) - _lowpass("ov_lp2", n, 0.01)) * ov * 0.5
	var sc: float = p.get("scoop", 0.0)
	if sc > 0.01:
		out += (_lowpass("sc_lp", n, 0.2) - _lowpass("sc_hp", n, 0.02)) * sc * 1.2
	# chime whistle: three pipes, slightly breathy
	var wh: float = p.get("whistle", 0.0)
	if wh > 0.01:
		var w := _osc("w1", 293.0) * 0.5 + _osc("w2", 349.0) * 0.45 + _osc("w3", 440.0) * 0.4
		w += _osc("w1h", 586.0) * 0.12 + _osc("w2h", 698.0) * 0.1
		w += _lowpass("w_n", n, 0.3) * 0.25
		out += w * wh * 0.55
	return out


## Advance a diesel oscillator; returns its phase 0..1.
func _dph(i: int, f: float) -> float:
	var ph := _dp[i] + f / RATE
	ph -= floorf(ph)
	_dp[i] = ph
	return ph


func _dlp(i: int, x: float, a: float) -> float:
	var y := _dl[i] + a * (x - _dl[i])
	_dl[i] = y
	return y


## One GE 7FDL-16: firing pulses at 8 per revolution, uneven from cylinder to
## cylinder (the four-stroke "lope"), muffled at idle and harsh under load,
## with the turbocharger's whine on top; plus the engine-driven compressor,
## dynamic brake grid blowers and radiator fans of that unit.
func _engine_unit(u: int, n: float) -> float:
	var r := _rpm[u]
	var b := u * 20
	var out := 0.0
	if r > 15.0:
		var f := r / 60.0 * 8.0
		var phf := _dph(b, f)
		var phc := _dph(b + 1, r / 120.0)
		var ld := _load[u]
		var uneven := 1.0 + 0.22 * sin(phc * TAU) + 0.12 * sin(phc * TAU * 3.0 + 1.3)
		var pulse := exp(-phf * (5.0 + ld * 3.0)) * uneven
		var body := sin(phf * TAU) * 0.5 + sin(_dph(b + 2, f * 0.5) * TAU) * 0.35
		var grit := _dlp(b + 3, n, 0.08 + ld * 0.12)
		var x := pulse * (0.55 + grit * 0.9) + body * 0.4
		x = _dlp(b + 4, x, 0.1 + ld * 0.25 + r / 1050.0 * 0.12)
		out += x * clampf(r / 440.0, 0.0, 1.0) * (0.4 + ld * 0.6) * 1.3
		var tb := _turbo[u]
		out += sin(_dph(b + 5, 1600.0 + tb * 4200.0 + r * 0.8) * TAU) * (0.004 + tb * 0.03)
		out += (n - _dlp(b + 6, n, 0.35)) * tb * 0.1
	var cr := _crank[u]
	if cr > 0.01:
		# cranking: the main alternator, run as a motor, whines as it turns the engine over
		out += sin(_dph(b + 7, 300.0 + r * 1.6) * TAU) * 0.06 * cr + sin(_dph(b + 8, 900.0 + r * 4.8) * TAU) * 0.015 * cr
	var cm := _comp[u]
	if cm > 0.01:
		var pc := _dph(b + 9, r / 60.0 * 3.0)
		out += exp(-pc * 7.0) * _dlp(b + 10, n, 0.12) * cm * 0.9
	var db := _dbb[u]
	if db > 0.01:
		out += (_dlp(b + 11, n, 0.3) - _dlp(b + 12, n, 0.03)) * db * 0.45 + sin(_dph(b + 13, 140.0 + db * 160.0) * TAU) * db * 0.02
	var fn := _fan[u]
	if fn > 0.01:
		out += _dlp(b + 14, n, 0.05) * fn * 0.5
	if _ac[u] > 0.01 and u == near_unit and in_cab:
		out += (_dlp(b + 15, n, 0.1) - _dlp(b + 16, n, 0.02)) * _ac[u] * 0.12
	return out * _gain[u]


func _diesel_sample(n: float, vk: float) -> float:
	var out := _engine_unit(0, n) + _engine_unit(1, n)
	# AC traction: inverters and motors whine with speed while loading or braking
	var inv: float = p.get("inverter", 0.0)
	if inv > 0.01:
		out += (sin(_dph(45, 220.0 + vk * 21.0) * TAU) * 0.035 + sin(_dph(46, 1150.0 + vk * 2.0) * TAU) * 0.01) * inv
	# Nathan K5LA five-chime horn (a B6 chord, rich and reedy)
	var hn: float = p.get("horn", 0.0)
	if hn > 0.01:
		var hsum := 0.0
		for k in range(5):
			hsum += 1.0 if _dph(40 + k, HORN_K5[k]) < 0.5 else -1.0
		out += _dlp(47, hsum, 0.35) * hn * 0.075
	if p.get("alerter", 0.0) > 0.01:
		out += sin(_dph(48, 1950.0) * TAU) * 0.07 * (1.0 if fmod(_t, 0.6) < 0.3 else 0.0)
	var rl: float = p.get("release", 0.0)
	if rl > 0.01:
		out += (n - _dlp(49, n, 0.4)) * rl * 0.35
	var sd: float = p.get("sand", 0.0)
	if sd > 0.01:
		out += (n - _dlp(50, n, 0.2)) * sd * 0.06
	var bcp: float = p.get("bc", 0.0)
	if bcp > 80.0 and vk > 0.5 and vk < 12.0:
		out += sin(_dph(51, 2300.0 + sin(_t * 31.0) * 70.0) * TAU) * 0.025 * clampf((12.0 - vk) / 8.0, 0.0, 1.0)
	return out


func _electric_sample(n: float, v: float, vk: float) -> float:
	var out := 0.0
	var tr: float = p.get("traction", 0.0)
	var rg: float = p.get("regen", 0.0)
	var drive := maxf(tr, rg * 0.8)
	if drive > 0.01 and vk > 0.2:
		# IGBT-VVVF: carrier tone shifts through its pulse modes as speed rises
		var carrier := 700.0
		if vk < 12.0:
			carrier = 500.0 + vk * 60.0
		elif vk < 40.0:
			carrier = 1100.0 + (vk - 12.0) * 6.0
		else:
			carrier = 900.0
		var motor_f := vk * 9.5 + 20.0
		out += (_osc("vvvf", carrier) * 0.12 + _osc("mot", motor_f) * 0.22 + _osc("mot2", motor_f * 2.0) * 0.08) * drive
	var siv: float = p.get("siv", 0.0)
	if siv > 0.01:
		out += (_osc("siv1", 100.0) * 0.04 + _osc("siv2", 1500.0) * 0.012) * siv
	var comp: float = p.get("comp", 0.0)
	if comp > 0.01:
		var pulse := 0.5 + 0.5 * _osc("comp_r", 14.0)
		out += (_lowpass("comp_lp", n, 0.05) * 1.2 + _osc("comp_o", 55.0) * 0.2) * pulse * comp * 0.6
	var aux: float = p.get("aux", 0.0)
	if aux > 0.01:
		out += (_sq("aux_o", 120.0) * 0.05 + _lowpass("aux_n", n, 0.2) * 0.2) * aux
	# saloon air-conditioning and cab demister fans (heard faintly in the cab)
	var hv: float = p.get("hvac", 0.0)
	if hv > 0.01:
		out += (_lowpass("hvac_n", n, 0.03) * 0.5 + _osc("hvac_o", 48.0) * 0.015) * hv
	var dm: float = p.get("demister", 0.0)
	if dm > 0.01:
		out += (_lowpass("dm_n", n, 0.12) - _lowpass("dm_n2", n, 0.02)) * 0.35 * dm
	# washer pump and spray, wiper motor
	var ws: float = p.get("washer", 0.0)
	if ws > 0.01:
		out += (_osc("ws_o", 760.0) * 0.03 + (n - _lowpass("ws_n", n, 0.4)) * 0.12) * ws
	var wp: float = p.get("wiper", 0.0)
	if wp > 0.01:
		out += (_sq("wp_o", 62.0) * 0.012 + _lowpass("wp_n", n, 0.08) * 0.05) * wp
	# two-tone horn
	var hh: float = p.get("horn_hi", 0.0)
	if hh > 0.01:
		out += (_sq("hh1", 659.0) * 0.18 + _osc("hh2", 1318.0) * 0.08) * hh
	var hl: float = p.get("horn_lo", 0.0)
	if hl > 0.01:
		out += (_sq("hl1", 415.0) * 0.18 + _osc("hl2", 830.0) * 0.08) * hl
	var chime: float = p.get("chime", 0.0)
	if chime > 0.01:
		var step := int(_t * 2.6) % 3
		var f: float = [880.0, 698.0, 587.0][step]
		out += _osc("chime_o", f) * 0.15 * chime
	if p.get("vig", 0.0) > 0.01:
		out += _sq("vig_o", 880.0) * 0.08 * (1.0 if fmod(_t, 0.5) < 0.3 else 0.0)
	if p.get("dsd", 0.0) > 0.01:
		out += _sq("dsd_o", 620.0) * 0.08
	if p.get("etcs", 0.0) > 0.01:
		out += _osc("etcs_o", 1000.0) * 0.1 * (1.0 if fmod(_t, 0.8) < 0.15 else 0.0)
	# brake squeal near a stand
	var bcp: float = p.get("bc", 0.0)
	if bcp > 80.0 and vk > 0.5 and vk < 15.0:
		out += _osc("sq", 2600.0 + _osc("sq_w", 5.0) * 60.0) * 0.03 * clampf((15.0 - vk) / 10.0, 0.0, 1.0)
	return out
