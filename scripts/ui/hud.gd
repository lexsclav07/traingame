class_name Hud
extends CanvasLayer
## On-screen information: control tooltips, messages, help (F1), start-up
## checklist (F2), details (F3), time acceleration and the pause menu.

signal resume_pressed
signal restart_pressed
signal menu_pressed

var tooltip: PanelContainer
var tooltip_label: RichTextLabel
var msg_box: VBoxContainer
var info: Label
var details: Label
var help: PanelContainer
var help_label: RichTextLabel
var checklist: PanelContainer
var check_label: RichTextLabel
var pause_panel: PanelContainer
var fail_panel: PanelContainer
var fail_label: Label
var loading: Label
var show_details := false


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	tooltip = _panel(root, Color(0.05, 0.06, 0.08, 0.86))
	tooltip_label = RichTextLabel.new()
	tooltip_label.bbcode_enabled = true
	tooltip_label.fit_content = true
	tooltip_label.custom_minimum_size = Vector2(340, 0)
	tooltip_label.scroll_active = false
	tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.add_child(tooltip_label)
	tooltip.visible = false

	msg_box = VBoxContainer.new()
	msg_box.position = Vector2(20, 20)
	msg_box.custom_minimum_size = Vector2(620, 0)
	msg_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(msg_box)

	info = Label.new()
	info.anchor_top = 1.0
	info.anchor_bottom = 1.0
	info.offset_top = -40
	info.offset_left = 16
	info.offset_top = -46
	info.offset_left = 12
	info.add_theme_font_size_override("font_size", 17)
	info.add_theme_color_override("font_color", Color(0.93, 0.95, 0.98))
	info.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	info.add_theme_constant_override("shadow_offset_x", 1)
	info.add_theme_constant_override("shadow_offset_y", 1)
	var isb := StyleBoxFlat.new()
	isb.bg_color = Color(0.03, 0.04, 0.06, 0.55)
	isb.set_corner_radius_all(6)
	isb.content_margin_left = 12
	isb.content_margin_right = 12
	isb.content_margin_top = 5
	isb.content_margin_bottom = 5
	info.add_theme_stylebox_override("normal", isb)
	root.add_child(info)

	details = Label.new()
	details.anchor_top = 1.0
	details.anchor_bottom = 1.0
	details.offset_top = -170
	details.offset_left = 16
	details.add_theme_font_size_override("font_size", 15)
	details.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	details.add_theme_constant_override("shadow_offset_x", 1)
	details.add_theme_constant_override("shadow_offset_y", 1)
	details.visible = false
	root.add_child(details)

	help = _panel(root, Color(0.04, 0.05, 0.07, 0.92))
	help.set_anchors_preset(Control.PRESET_CENTER)
	help.position = Vector2(140, 90)
	help_label = RichTextLabel.new()
	help_label.bbcode_enabled = true
	help_label.custom_minimum_size = Vector2(900, 560)
	help.add_child(help_label)
	help.visible = false

	checklist = _panel(root, Color(0.04, 0.05, 0.07, 0.85))
	checklist.anchor_left = 1.0
	checklist.anchor_right = 1.0
	checklist.offset_left = -470
	checklist.offset_top = 20
	check_label = RichTextLabel.new()
	check_label.bbcode_enabled = true
	check_label.fit_content = true
	check_label.custom_minimum_size = Vector2(440, 0)
	check_label.scroll_active = false
	checklist.add_child(check_label)
	checklist.visible = false

	pause_panel = _panel(root, Color(0.04, 0.05, 0.07, 0.94))
	pause_panel.position = Vector2(620, 300)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	pause_panel.add_child(vb)
	var t := Label.new()
	t.text = "Paused"
	t.add_theme_font_size_override("font_size", 28)
	vb.add_child(t)
	for pair in [["Resume", resume_pressed], ["Restart", restart_pressed], ["Main menu", menu_pressed]]:
		var b := Button.new()
		b.text = pair[0]
		b.custom_minimum_size = Vector2(260, 42)
		var sig: Signal = pair[1]
		b.pressed.connect(func(): sig.emit())
		vb.add_child(b)
	var q := Button.new()
	q.text = "Quit to desktop"
	q.custom_minimum_size = Vector2(260, 42)
	q.pressed.connect(func(): get_tree().quit())
	vb.add_child(q)
	pause_panel.visible = false

	fail_panel = _panel(root, Color(0.25, 0.03, 0.03, 0.92))
	fail_panel.position = Vector2(420, 330)
	var fv := VBoxContainer.new()
	fail_panel.add_child(fv)
	fail_label = Label.new()
	fail_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	fail_label.custom_minimum_size = Vector2(740, 0)
	fail_label.add_theme_font_size_override("font_size", 20)
	fv.add_child(fail_label)
	var fb := Button.new()
	fb.text = "Restart"
	fb.pressed.connect(func(): restart_pressed.emit())
	fv.add_child(fb)
	var fc := Button.new()
	fc.text = "Carry on anyway"
	fc.pressed.connect(func(): fail_panel.visible = false)
	fv.add_child(fc)
	fail_panel.visible = false

	loading = Label.new()
	loading.text = "Building the line..."
	loading.add_theme_font_size_override("font_size", 30)
	loading.position = Vector2(60, 60)
	root.add_child(loading)


func _panel(parent: Control, col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p


func show_tooltip(ctl: CabControl, key_hint: String) -> void:
	if ctl == null or not GameSettings.show_tooltips:
		tooltip.visible = false
		return
	var t := "[b]%s[/b]   [color=#ffd860]%s[/color]" % [ctl.title, ctl.state_text()]
	if not ctl.enabled and ctl.lock_reason != "":
		t += "\n[color=#ff8060]%s[/color]" % ctl.lock_reason
	if ctl.help != "":
		t += "\n[color=#c8ccd4][font_size=14]%s[/font_size][/color]" % ctl.help
	var how := ""
	match ctl.kind:
		CabControl.Kind.LEVER:
			how = "drag up/down or scroll"
		CabControl.Kind.WHEEL:
			how = "drag or scroll to turn"
		CabControl.Kind.ROTARY:
			how = "left/right click or scroll"
		CabControl.Kind.TOGGLE:
			how = "click to switch"
		CabControl.Kind.BUTTON:
			how = "click" if ctl.latching else "click / hold"
	t += "\n[color=#8890a0][font_size=13]%s%s[/font_size][/color]" % [how, ("   key: " + key_hint) if key_hint != "" else ""]
	tooltip_label.text = t
	tooltip.visible = true
	var mp := get_viewport().get_mouse_position()
	var vs := get_viewport().get_visible_rect().size
	tooltip.reset_size()
	var pos := mp + Vector2(22, 18)
	if pos.x + tooltip.size.x > vs.x - 10:
		pos.x = mp.x - tooltip.size.x - 22
	if pos.y + tooltip.size.y > vs.y - 10:
		pos.y = mp.y - tooltip.size.y - 18
	tooltip.position = pos


func message(text: String, kind := "info") -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(620, 0)
	l.add_theme_font_size_override("font_size", 18)
	var col := Color(0.92, 0.94, 0.98)
	match kind:
		"warn":
			col = Color(1.0, 0.8, 0.3)
		"fail":
			col = Color(1.0, 0.4, 0.35)
		"good":
			col = Color(0.5, 1.0, 0.6)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.set_meta("born", Time.get_ticks_msec())
	l.set_meta("life", 9000 if kind != "fail" else 16000)
	msg_box.add_child(l)
	while msg_box.get_child_count() > 6:
		msg_box.get_child(0).queue_free()
		msg_box.remove_child(msg_box.get_child(0))


func fail(text: String) -> void:
	fail_label.text = text
	fail_panel.visible = true
	fail_panel.mouse_filter = Control.MOUSE_FILTER_STOP


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	for l in msg_box.get_children():
		var age: int = now - int(l.get_meta("born"))
		var life: int = l.get_meta("life")
		(l as Label).modulate.a = clampf(1.0 - float(age - life + 1500) / 1500.0, 0.0, 1.0)
		if age > life:
			l.queue_free()


func set_info(t: String) -> void:
	info.text = t


func set_details(lines: PackedStringArray) -> void:
	details.visible = show_details
	details.offset_top = -50 - lines.size() * 21
	details.text = "\n".join(lines)


func set_checklist(items: Array, title: String) -> void:
	if not checklist.visible:
		return
	var t := "[b]%s[/b]\n" % title
	var next_shown := false
	for it in items:
		if it[1]:
			t += "[color=#70e070]✔ %s[/color]\n" % it[0]
		elif not next_shown:
			t += "[color=#ffd860]➜ %s[/color]\n" % it[0]
			next_shown = true
		else:
			t += "[color=#9aa0aa]☐ %s[/color]\n" % it[0]
	check_label.text = t


func set_help(t: String) -> void:
	help_label.text = t


func set_pause(on: bool) -> void:
	pause_panel.visible = on
	pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
