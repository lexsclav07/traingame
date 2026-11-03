class_name Tutorial
extends Control
## Step-by-step tutorial. A panel explains each step; the controls it needs are
## ringed on screen (an arrow at the edge points to any that are out of view);
## "Show me" (Tab) moves you to the right position and looks at the control;
## and each step ticks itself off when you have done it. Steps come from
## TutorialSteps for the train being driven.

var game: Node
var steps: Array = []
var i := 0
var _t := 0.0
var _done_t := -1.0
var _done_on_entry := false
var panel: PanelContainer
var head: Label
var title: Label
var body: RichTextLabel
var status: RichTextLabel
var b_back: Button
var b_show: Button
var b_next: Button
var minimised := false


func setup(g: Node) -> void:
	game = g
	name = "Tutorial"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	steps = TutorialSteps.for_game(g)
	panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.09, 0.9)
	sb.border_color = Color(1.0, 0.82, 0.25, 0.85)
	sb.border_width_left = 3
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -16
	panel.offset_right = -16
	panel.offset_top = -62
	panel.offset_bottom = -62
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.custom_minimum_size = Vector2(540, 0)
	panel.add_child(vb)
	head = Label.new()
	head.add_theme_font_size_override("font_size", 13)
	head.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
	vb.add_child(head)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 22)
	vb.add_child(title)
	body = RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_font_size_override("normal_font_size", 16)
	body.add_theme_font_size_override("bold_font_size", 16)
	vb.add_child(body)
	status = RichTextLabel.new()
	status.bbcode_enabled = true
	status.fit_content = true
	status.scroll_active = false
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.add_theme_font_size_override("normal_font_size", 16)
	status.add_theme_font_size_override("bold_font_size", 16)
	vb.add_child(status)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vb.add_child(row)
	b_back = _button(row, "Back", back)
	b_show = _button(row, "Show me  (Tab)", show_target)
	b_next = _button(row, "Next  (Enter)", next)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	_button(row, "Hide", toggle_minimised)
	_enter(0)


func _button(row: HBoxContainer, t: String, f: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 32)
	b.pressed.connect(f)
	row.add_child(b)
	return b


func toggle_minimised() -> void:
	minimised = not minimised
	body.visible = not minimised
	status.visible = not minimised
	b_back.visible = not minimised
	b_show.visible = not minimised
	b_next.visible = not minimised


func _enter(k: int) -> void:
	i = clampi(k, 0, steps.size() - 1)
	var st: Dictionary = steps[i]
	_done_t = -1.0
	_done_on_entry = _is_done(st)
	head.text = "TUTORIAL   step %d of %d" % [i + 1, steps.size()]
	title.text = st["title"]
	body.text = st["text"]
	b_back.disabled = i == 0
	b_show.visible = not minimised and not (st.get("ids", []) as Array).is_empty()
	b_next.text = "Finish" if i == steps.size() - 1 else "Next  (Enter)"
	if minimised:
		toggle_minimised()
	_update_status()


func next() -> void:
	if i >= steps.size() - 1:
		visible = false
		game.hud.message("Tutorial finished. F2 shows the start-up checklist any time, F1 the controls.", "good")
		return
	_enter(i + 1)


func back() -> void:
	_enter(i - 1)


func _is_done(st: Dictionary) -> bool:
	var d = st.get("done")
	if d == null:
		return false
	return bool((d as Callable).call())


func _update_status() -> void:
	var st: Dictionary = steps[i]
	if st.get("done") == null:
		status.text = "[color=#9aa4b4]Press Next when you're ready.[/color]"
	elif _is_done(st):
		status.text = "[color=#70e070][b]✔ %s[/b][/color]" % ("Already done: press Next." if _done_on_entry else "Done!")
	else:
		status.text = "[color=#ffd860][b]➜ %s[/b][/color]" % st.get("do", "Do it now.")


func _process(delta: float) -> void:
	if not visible or steps.is_empty():
		return
	_t += delta
	var st: Dictionary = steps[i]
	if st.get("done") != null and not _done_on_entry:
		if _is_done(st):
			if _done_t < 0.0:
				_done_t = _t
			elif _t - _done_t > 1.3 and i < steps.size() - 1:
				_enter(i + 1)
				return
		else:
			_done_t = -1.0
	_update_status()
	queue_redraw()


# ------------------------------------------------------------- targets
## World position of a control (its pick point) or of a gauge ("g:<id>").
func _target_point(id: String) -> Variant:
	var cab: Cab = game.cab
	if id.begins_with("g:"):
		var g = cab.gauges.get(id.substr(2))
		return (g as Node3D).global_position if g else null
	var ctl: CabControl = cab.c(id)
	if ctl == null:
		return null
	var pn: Node3D = ctl.get_meta("pick_node", ctl)
	return pn.global_transform * ctl.pick_offset


func _target_name(id: String) -> String:
	if id.begins_with("g:"):
		return "gauge"
	var ctl: CabControl = game.cab.c(id)
	return ctl.title if ctl else id


## The step's targets; a control shut away behind a closed door is replaced by
## the door, which has to be opened first.
func _targets() -> Array:
	var out := []
	var seen := {}
	for id0 in steps[i].get("ids", []):
		var id: String = id0
		var ctl: CabControl = null if id.begins_with("g:") else game.cab.c(id)
		if ctl and ctl.has_meta("behind") and game.cab.val(ctl.get_meta("behind")) < 0.5:
			id = ctl.get_meta("behind")
		if seen.has(id):
			continue
		seen[id] = true
		var p = _target_point(id)
		if p != null:
			out.append([id, p])
	return out


## Goes to the cab position nearest the step's first control that can see it,
## and turns to look straight at it.
func show_target() -> void:
	var tg := _targets()
	if tg.is_empty():
		return
	var cab: Cab = game.cab
	var rig: CameraRig = game.rig
	var wp: Vector3 = tg[0][1]
	var want: String = steps[i].get("view", "")
	var best := -1
	var bd := INF
	for vi in range(cab.view_order.size()):
		var vn: String = cab.view_order[vi]
		var vt := _view_transform(vn)
		var d := vt.origin.distance_to(wp)
		var blocked := cab.block_distance(vt.origin, (wp - vt.origin).normalized()) < d - 0.05
		# prefer sitting in the driver's seat, then the working positions, over
		# leaning out of windows
		var lv := vt.affine_inverse() * wp
		var turn := absf(atan2(-lv.x, -lv.z))
		var score := d + (6.0 if blocked else 0.0) + (0.0 if vi == 0 else 0.1) + turn * 0.12 + (3.0 if turn > 2.4 else 0.0)
		for w in ["Look out", "Leaning", "Side window", "Standing"]:
			if vn.begins_with(w):
				score += 0.6
		if vn == want:
			score = -1.0
		if score < bd:
			bd = score
			best = vi
	rig.set_view(best)
	var local := _view_transform(cab.view_order[best]).affine_inverse() * wp
	rig.yaw = clampf(atan2(-local.x, -local.z), -2.6, 2.6)
	rig.pitch = clampf(asin(clampf(local.y / maxf(local.length(), 1e-4), -1.0, 1.0)), -1.2, 1.0)


func _view_transform(vn: String) -> Transform3D:
	var cab: Cab = game.cab
	var anchor: Node3D = cab.view_anchor.get(vn, cab)
	return anchor.global_transform * (cab.view_points[vn] as Transform3D)


# --------------------------------------------------------------- drawing
func _draw() -> void:
	var rig: CameraRig = game.rig
	if rig == null or minimised:
		return
	var font := ThemeDB.fallback_font
	var vs := get_viewport_rect().size
	if rig.mode != "cab":
		if not (steps[i].get("ids", []) as Array).is_empty():
			_hint(font, Vector2(vs.x * 0.5, vs.y * 0.5), "Press 1 (or Tab) to go back to the cab")
		return
	var cam := rig.cam
	var pulse := 0.5 + 0.5 * sin(_t * 5.0)
	var col := Color(1.0, 0.82, 0.25)
	var tg := _targets()
	# each control ringed; any out of sight gets an arrow at the screen edge
	var shown_arrow := false
	for e in tg:
		var id: String = e[0]
		var wp: Vector3 = e[1]
		var on_screen := not cam.is_position_behind(wp)
		var sp := Vector2.ZERO
		if on_screen:
			sp = cam.unproject_position(wp)
			on_screen = sp.x > 20 and sp.y > 20 and sp.x < vs.x - 20 and sp.y < vs.y - 20
		if on_screen:
			var d := cam.global_position.distance_to(wp)
			var r := clampf(0.045 / maxf(d, 0.2) * vs.y / (2.0 * tan(deg_to_rad(cam.fov) * 0.5)), 14.0, 70.0)
			draw_arc(sp, r + pulse * 6.0, 0.0, TAU, 40, Color(col, 0.95), 3.0, true)
			draw_arc(sp, r + 10.0 + pulse * 10.0, 0.0, TAU, 40, Color(col, 0.35 * (1.0 - pulse)), 2.0, true)
			if tg.size() <= 6:
				var label := _target_name(id)
				var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
				var lp := sp + Vector2(-w * 0.5, r + 26.0)
				draw_rect(Rect2(lp + Vector2(-6, -16), Vector2(w + 12, 22)), Color(0.02, 0.03, 0.05, 0.8))
				draw_string(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 0.92, 0.7))
		elif not shown_arrow:
			shown_arrow = true
			var local := cam.global_transform.affine_inverse() * wp
			var dir := Vector2(local.x, -local.y)
			if dir.length() < 1e-4:
				dir = Vector2(1, 0)
			dir = dir.normalized()
			var c := vs * 0.5
			var rad := minf(vs.x, vs.y) * 0.5 - 70.0
			var tip := c + dir * rad
			var n := Vector2(-dir.y, dir.x)
			var pts := PackedVector2Array([tip + dir * 26.0, tip + n * 18.0, tip - n * 18.0])
			draw_colored_polygon(pts, Color(col, 0.6 + 0.4 * pulse))
			_hint(font, tip - dir * 40.0, "%s is this way: look round, or press Tab" % _target_name(id))


func _hint(font: Font, at: Vector2, t: String) -> void:
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var lp := at + Vector2(-w * 0.5, 6)
	draw_rect(Rect2(lp + Vector2(-8, -18), Vector2(w + 16, 26)), Color(0.02, 0.03, 0.05, 0.85))
	draw_string(font, lp, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.9, 0.6))
