class_name LocoScreen
extends Control
## Desk displays of a 92 class (GE-style locomotive computer screens), drawn
## into a SubViewport. "main": speed, tractive effort, the controller and the
## air brake. "status": engine, air and alarm pages, picked with the three keys
## under the screen. Both stay dark until the locomotive computer has booted.

const BG := Color(0.0, 0.015, 0.035)
const BAR := Color(0.05, 0.15, 0.34)
const FG := Color(0.88, 0.92, 0.95)
const DIM := Color(0.48, 0.55, 0.62)
const GOOD := Color(0.35, 1.0, 0.45)
const WARN := Color(1.0, 0.75, 0.2)
const BAD := Color(1.0, 0.3, 0.25)
const NUMBERS := ["9206", "9211"]

var kind := "main"
var unit := 0
var sim: C92Sim
var font: Font


static func make(parent: Node3D, k: String, u: int, size_px: Vector2i, size_m: Vector2, pos: Vector3, rot: Vector3) -> LocoScreen:
	var vp := SubViewport.new()
	vp.size = size_px
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	parent.add_child(vp)
	var scr := LocoScreen.new()
	scr.kind = k
	scr.unit = u
	scr.size = Vector2(size_px)
	vp.add_child(scr)
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size_m
	mi.mesh = qm
	var m := StandardMaterial3D.new()
	m.albedo_texture = vp.get_texture()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "Screen_%s_%d" % [k, u]
	parent.add_child(mi)
	mi.position = pos
	mi.rotation_degrees = rot
	return scr


func _ready() -> void:
	font = ThemeDB.fallback_font


func _process(_d: float) -> void:
	queue_redraw()


func _txt(p: Vector2, t: String, sz: int, col := FG, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0) -> void:
	draw_string(font, p, t, align, w, sz, col)


func _draw() -> void:
	var W := size.x
	var H := size.y
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0))
	if sim == null or not sim._powered(unit):
		return
	if not sim.computer[unit]:
		if sim.boot_t[unit] > 0.0:
			draw_rect(Rect2(0, 0, W, H), BG)
			_txt(Vector2(20, H * 0.32), "LOCOMOTIVE COMPUTER", 22, FG)
			_txt(Vector2(20, H * 0.32 + 30), "UNIT %s   SELF TEST" % NUMBERS[unit], 16, DIM)
			var f := clampf(1.0 - sim.boot_t[unit] / 25.0, 0.0, 1.0)
			draw_rect(Rect2(20, H * 0.55, W - 40, 14), Color(0.1, 0.12, 0.16))
			draw_rect(Rect2(20, H * 0.55, (W - 40) * f, 14), Color(0.25, 0.55, 0.95))
			_txt(Vector2(20, H * 0.55 + 40), "%d %%" % int(f * 100.0), 16, DIM)
		return
	draw_rect(Rect2(0, 0, W, H), BG)
	if kind == "main":
		_main(W, H)
	else:
		_status(W, H)


func _role() -> Array:
	if sim.ctrl == unit:
		return ["LEAD - IN CONTROL", GOOD]
	if int(sim._u(unit, "ecs")) != 1:
		return ["ISOLATED", WARN]
	if sim.responds[unit]:
		return ["TRAIL - LOADING", GOOD]
	return ["TRAIL", FG]


func _header(W: float, title: String) -> void:
	draw_rect(Rect2(0, 0, W, 30), BAR)
	_txt(Vector2(8, 21), "%s  %s" % [NUMBERS[unit], title], 16, FG)
	var r: Array = _role()
	_txt(Vector2(W - 228, 21), r[0], 15, r[1], HORIZONTAL_ALIGNMENT_RIGHT, 220)


# ------------------------------------------------------------------ main
func _main(W: float, H: float) -> void:
	_header(W, "MAIN")
	var c := maxi(sim.ctrl, 0)
	# speed
	var spd := absf(sim.train.speed) * 3.6
	draw_rect(Rect2(8, 38, 168, 104), Color(0.03, 0.06, 0.1))
	_txt(Vector2(14, 58), "SPEED  km/h", 13, DIM)
	_txt(Vector2(8, 128), "%d" % int(round(spd)), 62, FG, HORIZONTAL_ALIGNMENT_CENTER, 168)
	var lim := sim.max_speed_kmh()
	draw_rect(Rect2(14, 134, 156, 4), Color(0.15, 0.18, 0.22))
	draw_rect(Rect2(14, 134, 156 * clampf(spd / lim, 0.0, 1.0), 4), WARN if spd > lim else GOOD)
	# controller, reverser
	var thr := sim.throttle_label(c) if sim.ctrl >= 0 else "--"
	_txt(Vector2(190, 66), "CONTROLLER", 13, DIM)
	_txt(Vector2(190, 98), thr, 28, Color(0.95, 0.55, 0.3) if thr.begins_with("DB") else FG)
	var rev := int(sim._u(c, "reverser")) if sim.ctrl >= 0 else 1
	_txt(Vector2(190, 122), "REVERSER", 13, DIM)
	_txt(Vector2(282, 122), ["REVERSE", "CENTRE", "FORWARD"][rev], 15, FG if rev != 1 else DIM)
	_txt(Vector2(190, 140), "SAND", 13, DIM)
	_txt(Vector2(282, 140), "ON" if sim.ctrl >= 0 and sim._uon(c, "sand") else "off", 15, WARN if sim.ctrl >= 0 and sim._uon(c, "sand") else DIM)
	# tractive effort / dynamic brake of the whole locomotive consist
	var te_k := (sim.te[0] + sim.te[1]) / 1000.0
	var db_k := (sim.db[0] + sim.db[1]) / 1000.0
	var y := 158.0
	_txt(Vector2(8, y + 12), "TE / DB (both units)", 13, DIM)
	var x0 := 160.0
	var bw := W - x0 - 12.0
	var mid := x0 + bw * 0.4
	draw_rect(Rect2(x0, y, bw, 18), Color(0.08, 0.1, 0.14))
	if te_k > 0.5:
		draw_rect(Rect2(mid, y + 2, (bw * 0.6) * clampf(te_k / 1100.0, 0.0, 1.0), 14), GOOD)
	if db_k > 0.5:
		var dw := (bw * 0.4) * clampf(db_k / 900.0, 0.0, 1.0)
		draw_rect(Rect2(mid - dw, y + 2, dw, 14), Color(0.95, 0.5, 0.2))
	draw_line(Vector2(mid, y - 2), Vector2(mid, y + 20), FG, 2.0)
	_txt(Vector2(x0, y + 36), "DB %d kN" % int(db_k), 14, Color(0.95, 0.55, 0.3) if db_k > 0.5 else DIM)
	_txt(Vector2(W - 140, y + 36), "TE %d kN" % int(te_k), 14, GOOD if te_k > 0.5 else DIM, HORIZONTAL_ALIGNMENT_RIGHT, 128)
	# air brake (this unit's brake valve and pipe)
	y = 216.0
	draw_line(Vector2(0, y), Vector2(W, y), Color(0.2, 0.25, 0.32), 1.0)
	var cols := [["EQ RES", sim.er[unit]], ["BRAKE PIPE", sim.bp[unit]], ["MAIN RES", sim.mr[unit]],
		["BRAKE CYL", sim.loco_bc[unit]], ["FLOW", sim.flow[unit]]]
	var cw := W / 5.0
	for i in range(5):
		var cd: Array = cols[i]
		_txt(Vector2(i * cw, y + 20), cd[0], 12, DIM, HORIZONTAL_ALIGNMENT_CENTER, cw)
		var v: float = cd[1]
		var col := FG
		if i == 4:
			col = WARN if absf(v) > 900.0 else FG
		elif i == 2 and v < 750.0:
			col = WARN
		_txt(Vector2(i * cw, y + 50), "%d" % int(round(v)), 26, col, HORIZONTAL_ALIGNMENT_CENTER, cw)
	_txt(Vector2(0, y + 66), "kPa", 11, DIM, HORIZONTAL_ALIGNMENT_CENTER, cw * 4.0)
	_txt(Vector2(cw * 4.0, y + 66), "L/min", 11, DIM, HORIZONTAL_ALIGNMENT_CENTER, cw)
	var mode := "LEAD" if sim._u(unit, "brake_mode") < 0.5 else "TRAIL (CUT OUT)"
	_txt(Vector2(8, y + 88), "BRAKE VALVE %s   %s" % [mode, sim.auto_label(unit) if sim._u(unit, "brake_mode") < 0.5 else ""], 13, FG if mode == "LEAD" else DIM)
	# message line: the most important alarm
	var msg := ""
	var mcol := WARN
	if sim.pcs_open:
		msg = "PCS OPEN - " + sim.pcs_reason.to_upper()
		mcol = BAD
	elif sim.alerter_warn:
		msg = "ALERTER - PRESS RESET"
		mcol = BAD if fmod(sim.sim_time, 0.8) < 0.4 else WARN
	elif sim.slip[unit]:
		msg = "WHEEL SLIP"
	elif not sim.alarms.is_empty():
		msg = sim.alarms[0]
	draw_rect(Rect2(0, H - 34, W, 34), Color(0.04, 0.07, 0.12))
	if msg != "":
		_txt(Vector2(8, H - 11), msg, 15, mcol)


# ---------------------------------------------------------------- status
func _status(W: float, H: float) -> void:
	var page: int = sim.screen_page[unit]
	_header(W, ["ENGINE", "AIR", "ALARMS"][page])
	match page:
		0:
			_engine_page(W)
		1:
			_air_page(W)
		_:
			_alarm_page(W)
	var keys := ["ENGINE", "AIR", "ALARMS"]
	for i in range(3):
		var x := W * (0.2 + i * 0.3)
		draw_rect(Rect2(x - 62, H - 30, 124, 26), Color(0.25, 0.4, 0.6) if i == page else Color(0.1, 0.15, 0.22))
		_txt(Vector2(x - 62, H - 11), keys[i], 14, FG, HORIZONTAL_ALIGNMENT_CENTER, 124)


func _row(y: float, label: String, vals: Array, cols: Array) -> void:
	_txt(Vector2(8, y), label, 13, DIM)
	for i in range(vals.size()):
		_txt(Vector2(190 + i * 140, y), vals[i], 14, cols[i])


func _engine_page(W: float) -> void:
	var y := 52.0
	_txt(Vector2(190, y), "UNIT 1  " + NUMBERS[0], 13, FG)
	_txt(Vector2(330, y), "UNIT 2  " + NUMBERS[1], 13, FG)
	draw_line(Vector2(0, y + 6), Vector2(W, y + 6), Color(0.2, 0.25, 0.32), 1.0)
	y += 24.0
	var rows := []
	var e := ["", ""]
	var ec := [FG, FG]
	for u in range(2):
		e[u] = sim.eng[u].to_upper()
		ec[u] = GOOD if sim.eng[u] == "running" else (WARN if sim.eng[u] == "cranking" else DIM)
	rows.append(["ENGINE", e, ec])
	rows.append(["RPM", ["%d" % int(sim.rpm[0]), "%d" % int(sim.rpm[1])], [FG, FG]])
	rows.append(["LOAD", ["%d %%" % int(sim.load[0] * 100.0), "%d %%" % int(sim.load[1] * 100.0)], [FG, FG]])
	var wc := []
	for u in range(2):
		wc.append(BAD if sim.water_t[u] > 98.0 else (WARN if sim.water_t[u] < 40.0 and sim.is_running(u) else FG))
	rows.append(["WATER TEMP", ["%d C" % int(sim.water_t[0]), "%d C" % int(sim.water_t[1])], wc])
	rows.append(["LUBE OIL", ["%d kPa" % int(sim.oil_p[0]), "%d kPa" % int(sim.oil_p[1])], [FG, FG]])
	rows.append(["FUEL PRESSURE", ["%d kPa" % int(sim.fuel_p[0]), "%d kPa" % int(sim.fuel_p[1])], [FG, FG]])
	rows.append(["FUEL", ["%d L" % int(sim.fuel_l[0]), "%d L" % int(sim.fuel_l[1])],
		[WARN if sim.fuel_l[0] < 1500.0 else FG, WARN if sim.fuel_l[1] < 1500.0 else FG]])
	rows.append(["BATTERY", ["%d V" % int(sim.bat_v[0]), "%d V" % int(sim.bat_v[1])], [FG, FG]])
	rows.append(["RADIATOR FANS", ["%d %%" % int(sim.fan[0] * 100.0), "%d %%" % int(sim.fan[1] * 100.0)], [FG, FG]])
	rows.append(["CAB TEMP", ["%d C" % int(sim.cab_temp[0]), "%d C" % int(sim.cab_temp[1])], [FG, FG]])
	var rs := []
	var rc := []
	for u in range(2):
		rs.append("OK" if sim.radio_ok[u] else ("STARTING" if sim._uon(u, "cb_radio") and sim._powered(u) else "OFF"))
		rc.append(GOOD if sim.radio_ok[u] else WARN)
	rows.append(["RADIO", rs, rc])
	for r in rows:
		_row(y, r[0], r[1], r[2])
		y += 20.0
	var why: String = sim.why_not[unit]
	if why != "" and sim.ctrl >= 0:
		_txt(Vector2(8, y + 6), "THIS UNIT NOT LOADING: " + why.to_upper(), 13, WARN)


func _air_page(W: float) -> void:
	var y := 52.0
	_txt(Vector2(190, y), "UNIT 1", 13, FG)
	_txt(Vector2(330, y), "UNIT 2", 13, FG)
	draw_line(Vector2(0, y + 6), Vector2(W, y + 6), Color(0.2, 0.25, 0.32), 1.0)
	y += 24.0
	var modes := []
	for u in range(2):
		modes.append("LEAD" if sim._u(u, "brake_mode") < 0.5 else "TRAIL")
	_row(y, "BRAKE VALVE", modes, [FG, FG]); y += 20.0
	_row(y, "MAIN RESERVOIR", ["%d kPa" % int(sim.mr[0]), "%d kPa" % int(sim.mr[1])],
		[WARN if sim.mr[0] < 750.0 else FG, WARN if sim.mr[1] < 750.0 else FG]); y += 20.0
	_row(y, "COMPRESSOR", ["LOADED" if sim.comp_loaded[0] else "unloaded", "LOADED" if sim.comp_loaded[1] else "unloaded"], [FG, FG]); y += 20.0
	_row(y, "EQ RESERVOIR", ["%d kPa" % int(sim.er[0]), "%d kPa" % int(sim.er[1])], [FG, FG]); y += 20.0
	_row(y, "BRAKE PIPE", ["%d kPa" % int(sim.bp[0]), "%d kPa" % int(sim.bp[1])], [FG, FG]); y += 20.0
	_row(y, "BRAKE CYLINDER", ["%d kPa" % int(sim.loco_bc[0]), "%d kPa" % int(sim.loco_bc[1])], [FG, FG]); y += 20.0
	_row(y, "FLOW", ["%d L/min" % int(sim.flow[0]), "%d L/min" % int(sim.flow[1])], [FG, FG]); y += 26.0
	var n := sim.n
	_txt(Vector2(8, y), "END OF TRAIN", 13, DIM)
	_txt(Vector2(190, y), "BP %d kPa   BC %d kPa   %d wagons" % [int(sim.bp[n - 1]), int(sim.bc[n - 1]), n - 2], 14, FG); y += 20.0
	_txt(Vector2(8, y), "BRAKE TEST", 13, DIM)
	_txt(Vector2(190, y), ["NOT DONE", "APPLIED AT REAR - RELEASE", "PASSED"][sim.brake_test], 14, GOOD if sim.brake_test == 2 else WARN)


func _alarm_page(_W: float) -> void:
	var y := 58.0
	if sim.alarms.is_empty():
		_txt(Vector2(10, y), "NO ACTIVE ALARMS", 16, GOOD)
		return
	for a in sim.alarms:
		var col := BAD if a.begins_with("PCS") or a.contains("HOT") else WARN
		_txt(Vector2(10, y), a, 14, col)
		y += 21.0
		if y > size.y - 44:
			break
