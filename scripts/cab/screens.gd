class_name CabScreen
extends Control
## In-cab display drawn into a SubViewport: ETCS DMI or the Train
## Management System (TMS). 'kind' picks which one.

var kind := "dmi"
var sim: MariyungSim
var font: Font


static func make(parent: Node3D, k: String, s: MariyungSim, size_px: Vector2i, size_m: Vector2, pos: Vector3, rot: Vector3) -> CabScreen:
	var vp := SubViewport.new()
	vp.size = size_px
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	parent.add_child(vp)
	var scr := CabScreen.new()
	scr.kind = k
	scr.sim = s
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
	parent.add_child(mi)
	mi.position = pos
	mi.rotation_degrees = rot
	return scr


func _ready() -> void:
	font = ThemeDB.fallback_font


func _process(_d: float) -> void:
	queue_redraw()


func _txt(p: Vector2, t: String, sz: int, col := Color.WHITE, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0) -> void:
	draw_string(font, p, t, align, w, sz, col)


func _draw() -> void:
	if kind == "dmi":
		_draw_dmi()
	else:
		_draw_tms()


# ------------------------------------------------------------------ DMI
func _draw_dmi() -> void:
	var W := size.x
	var H := size.y
	draw_rect(Rect2(0, 0, W, H), Color(0.01, 0.07, 0.13))
	if sim == null:
		return
	if sim.etcs_mode == "NP":
		if sim.dmi_boot > 0.0:
			_txt(Vector2(20, H * 0.5), "ETCS: self test %d%%" % int((1.0 - sim.dmi_boot / 14.0) * 100.0), 26, Color(0.75, 0.8, 0.85))
		else:
			draw_rect(Rect2(0, 0, W, H), Color(0.0, 0.0, 0.0))
		return
	if sim.etcs_mode == "IS":
		draw_rect(Rect2(0, 0, W, H), Color(0.0, 0.0, 0.0))
		_txt(Vector2(20, 60), "ETCS ISOLATED", 34, Color(1.0, 0.75, 0.1))
		return
	var c := Vector2(W * 0.5, H * 0.46)
	var r := H * 0.36
	var vmax := 180.0
	var a0 := deg_to_rad(-234.0)      # 0 km/h (from +x, clockwise in screen space)
	var a1 := deg_to_rad(54.0)
	var spd := absf(sim.train.speed) * 3.6
	var perm := sim.etcs_permitted
	# permitted-speed hook (grey arc up to permitted)
	if sim.etcs_mode == "FS" or sim.etcs_mode == "SR":
		draw_arc(c, r * 1.06, a0, lerpf(a0, a1, clampf(perm / vmax, 0.0, 1.0)), 48, Color(0.75, 0.75, 0.75), 8.0)
		if sim.etcs_target >= 0.0:
			var at := lerpf(a0, a1, clampf(sim.etcs_target / vmax, 0.0, 1.0))
			draw_line(c + Vector2(cos(at), sin(at)) * r * 1.0, c + Vector2(cos(at), sin(at)) * r * 1.12, Color(1.0, 0.85, 0.0), 4.0)
	# ticks
	var v := 0.0
	while v <= vmax + 0.1:
		var a := lerpf(a0, a1, v / vmax)
		var dir := Vector2(cos(a), sin(a))
		var major := int(v) % 20 == 0
		draw_line(c + dir * r * (0.86 if major else 0.92), c + dir * r, Color(0.85, 0.85, 0.85), 2.0 if major else 1.0)
		if major:
			_txt(c + dir * r * 0.72 - Vector2(14, -6), "%d" % int(v), 15, Color(0.85, 0.85, 0.85), HORIZONTAL_ALIGNMENT_CENTER, 28)
		v += 10.0
	# needle colour by supervision status
	var ncol := Color(0.75, 0.75, 0.75)
	match sim.etcs_status:
		1:
			ncol = Color(1.0, 0.6, 0.0)
		2, 3:
			ncol = Color(1.0, 0.15, 0.1)
	var an := lerpf(a0, a1, clampf(spd / vmax, 0.0, 1.0))
	draw_line(c, c + Vector2(cos(an), sin(an)) * r * 0.9, ncol, 6.0)
	draw_circle(c, r * 0.2, ncol)
	_txt(c + Vector2(-40, 9), "%d" % int(spd), 26, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, 80)
	# left: target distance bar, target speed
	if sim.etcs_mode == "FS" and sim.etcs_target >= 0.0:
		var dfrac := clampf(sim.etcs_target_d / 1000.0, 0.0, 1.0)
		draw_rect(Rect2(14, H * 0.18 + (1.0 - dfrac) * H * 0.5, 16, dfrac * H * 0.5), Color(0.75, 0.75, 0.75))
		_txt(Vector2(8, H * 0.14), "%d m" % int(sim.etcs_target_d), 14, Color(0.85, 0.85, 0.85))
		_txt(Vector2(8, H * 0.74), "%d" % int(sim.etcs_target), 20, Color(1.0, 0.85, 0.0))
	# right: mode and level
	draw_rect(Rect2(W - 78, 14, 64, 40), Color(0.1, 0.2, 0.3))
	_txt(Vector2(W - 72, 44), sim.etcs_mode, 26, Color(0.9, 0.9, 0.9))
	_txt(Vector2(W - 70, 76), "L1", 20, Color(0.8, 0.8, 0.8))
	# messages
	var msg := ""
	var mcol := Color(0.9, 0.9, 0.9)
	match sim.etcs_mode:
		"SB":
			msg = "Stand By: DATA, then START" if not sim.etcs_data else "Train data valid: press START"
		"SR":
			msg = "Staff Responsible: max %d km/h" % int(MariyungSim.SR_SPEED)
	if sim.etcs_status == 1:
		msg = "Overspeed"
		mcol = Color(1.0, 0.6, 0.0)
	elif sim.etcs_status == 2:
		msg = "Brake intervention"
		mcol = Color(1.0, 0.25, 0.2)
	elif sim.etcs_status == 3:
		msg = "TRIP: stop, then ACK"
		mcol = Color(1.0, 0.25, 0.2)
	draw_rect(Rect2(0, H - 72, W, 28), Color(0.02, 0.1, 0.18))
	_txt(Vector2(10, H - 51), msg, 18, mcol)
	# soft key captions
	var keys := ["DATA", "START", "ACK"]
	for i in range(3):
		var x := W * (0.17 + i * 0.33)
		draw_rect(Rect2(x - 42, H - 36, 84, 30), Color(0.08, 0.16, 0.25))
		_txt(Vector2(x - 42, H - 14), keys[i], 16, Color(0.85, 0.85, 0.85), HORIZONTAL_ALIGNMENT_CENTER, 84)


# ------------------------------------------------------------------ TMS
func _draw_tms() -> void:
	var W := size.x
	var H := size.y
	draw_rect(Rect2(0, 0, W, H), Color(0.0, 0.0, 0.0))
	if sim == null:
		return
	if not sim.tms_on:
		if sim.tms_boot > 0.0:
			draw_rect(Rect2(0, 0, W, H), Color(0.05, 0.06, 0.08))
			_txt(Vector2(20, H * 0.45), "TMS booting...", 24, Color(0.7, 0.75, 0.8))
			draw_rect(Rect2(20, H * 0.55, (W - 40) * (1.0 - sim.tms_boot / 18.0), 10), Color(0.3, 0.6, 0.9))
		return
	draw_rect(Rect2(0, 0, W, H), Color(0.08, 0.09, 0.11))
	var pages := ["STATUS", "BRAKES", "DOORS", "FAULTS"]
	draw_rect(Rect2(0, 0, W, 30), Color(0.12, 0.22, 0.38))
	_txt(Vector2(8, 22), "TMS  %s" % pages[sim.tms_page], 18, Color.WHITE)
	_txt(Vector2(W - 190, 22), "Ctrl %s   %s" % [sim.tbc_label(), ["REV", "NEU", "FWD"][int(sim.cab.val("direction"))]], 16, Color(0.9, 0.9, 0.9))
	var cars := sim.train.vehicles.size()
	var cw := (W - 20.0) / cars
	match sim.tms_page:
		0:
			for i in range(cars):
				var veh := sim.train.vehicles[i]
				var x := 10.0 + i * cw
				var col := Color(0.25, 0.3, 0.38)
				draw_rect(Rect2(x + 2, 64, cw - 4, 34), col)
				_txt(Vector2(x + 4, 86), veh.name, 13, Color.WHITE)
				if veh.pantograph:
					var pc := Color(0.3, 0.9, 0.4) if sim.pan_pos > 0.97 else (Color(1.0, 0.8, 0.2) if sim.pan_pos > 0.02 else Color(0.5, 0.5, 0.5))
					draw_line(Vector2(x + cw * 0.5, 64), Vector2(x + cw * 0.5 - 8, 50), pc, 2.0)
					draw_line(Vector2(x + cw * 0.5 - 14, 48), Vector2(x + cw * 0.5 + 6, 48), pc, 3.0)
				var bcp: float = sim.bc[i]
				draw_rect(Rect2(x + 4, 104, (cw - 8) * clampf(bcp / 420.0, 0.0, 1.0), 6), Color(0.95, 0.6, 0.15))
			var y := 136.0
			var lines := [
				["Line voltage", "%d V" % int(sim.line_v), sim.line_v > 1000.0],
				["Line current", "%d A" % int(sim.line_i), true],
				["HSCB", "CLOSED" if sim.hscb else "OPEN", sim.hscb],
				["Aux converter", "ON" if sim.siv_on else "OFF", sim.siv_on],
				["Battery", "%d V" % int(sim.bat_v), sim.bat_v > 100.0],
				["Main reservoir", "%d kPa%s" % [int(sim.mr), "  (compressor)" if sim.comp_on else ""], sim.mr > 750.0],
				["Pan reservoir", "%d kPa%s" % [int(sim.pan_res), "  (aux comp)" if sim.aux_comp else ""], sim.pan_res > 450.0],
				["Parking brake", "APPLIED" if sim.park_applied else "RELEASED", not sim.park_applied],
				["Brake test", ["NOT DONE", "RUNNING", "PASSED"][sim.brake_test], sim.brake_test == 2],
				["Doors", "CLOSED & LOCKED" if sim.doors_locked else "OPEN", sim.doors_locked],
			]
			for ln in lines:
				_txt(Vector2(14, y), ln[0], 15, Color(0.8, 0.82, 0.86))
				_txt(Vector2(W * 0.48, y), ln[1], 15, Color(0.4, 1.0, 0.5) if ln[2] else Color(1.0, 0.75, 0.25))
				y += 21.0
			if sim.traction_inhibit != "" and sim.cab_active:
				_txt(Vector2(14, H - 46), "Traction inhibit: " + sim.traction_inhibit, 14, Color(1.0, 0.6, 0.3))
		1:
			for i in range(cars):
				var x := 10.0 + i * cw
				var bcp: float = sim.bc[i]
				var hgt := (H - 150.0) * clampf(bcp / 450.0, 0.0, 1.0)
				draw_rect(Rect2(x + 6, H - 70 - hgt, cw - 12, hgt), Color(0.95, 0.6, 0.15))
				draw_rect(Rect2(x + 6, 50, cw - 12, H - 120), Color(0.4, 0.4, 0.45), false, 1.0)
				_txt(Vector2(x + 4, H - 52), "%d" % int(bcp), 14, Color.WHITE)
			_txt(Vector2(14, 46), "Brake cylinder pressure (kPa)  MR %d kPa  %s" % [int(sim.mr), "WSP ACTIVE" if sim.wsp else ""], 15, Color(0.85, 0.85, 0.9))
		2:
			_txt(Vector2(14, 50), "Left side", 15, Color(0.85, 0.85, 0.9))
			_txt(Vector2(14, 130), "Right side", 15, Color(0.85, 0.85, 0.9))
			for i in range(cars):
				var x := 10.0 + i * cw
				for side in range(2):
					var f: float = sim.doors_l if side == 0 else sim.doors_r
					var col := Color(0.3, 0.85, 0.4) if f <= 0.0 and sim.doors_locked else (Color(1.0, 0.75, 0.2) if f < 1.0 else Color(1.0, 0.3, 0.25))
					draw_rect(Rect2(x + 6, 60 + side * 80, cw - 12, 40), col)
			_txt(Vector2(14, 230), "Release: L %s  R %s" % ["YES" if sim.rel_l else "no", "YES" if sim.rel_r else "no"], 15, Color(0.85, 0.85, 0.9))
		3:
			var y2 := 56.0
			var any := false
			if sim.eb_latched:
				_txt(Vector2(14, y2), "EMERGENCY BRAKE: " + sim.eb_reason, 15, Color(1.0, 0.35, 0.3))
				y2 += 22.0
				any = true
			for id in ["mcb_control", "mcb_tms", "mcb_etcs", "mcb_pan", "mcb_hscb", "mcb_comp", "mcb_doors", "mcb_lights", "mcb_wipers", "mcb_hvac"]:
				if sim.cab.val(id) < 0.5:
					_txt(Vector2(14, y2), "Circuit breaker tripped / off: " + sim.cab.c(id).title, 15, Color(1.0, 0.75, 0.25))
					y2 += 22.0
					any = true
			if sim.slip:
				_txt(Vector2(14, y2), "Wheel slip (traction)", 15, Color(1.0, 0.75, 0.25))
				y2 += 22.0
				any = true
			if not any:
				_txt(Vector2(14, y2), "No active faults", 15, Color(0.4, 1.0, 0.5))
	var keys := ["STATUS", "BRAKES", "DOORS", "FAULTS", "BRK TEST"]
	for i in range(5):
		var x := W * (0.1 + i * 0.2)
		draw_rect(Rect2(x - 44, H - 30, 88, 26), Color(0.15, 0.2, 0.28) if i != sim.tms_page else Color(0.25, 0.4, 0.6))
		_txt(Vector2(x - 44, H - 11), keys[i], 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 88)
