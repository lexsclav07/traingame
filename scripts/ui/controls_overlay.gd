class_name ControlsOverlay
extends Control
## A key guide that stays on screen: every driving key for the train, with
## what the control it works is set to right now, then moving about and the
## general keys. Turned on in the menu ("Show controls on screen"), in the
## pause menu, or with F4.

var game: Node
var panel: PanelContainer
var label: RichTextLabel
var _t := 0.0


func setup(g: Node) -> void:
	game = g
	name = "ControlsOverlay"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.04, 0.06, 0.62)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = 12
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.custom_minimum_size = Vector2(330, 0)
	label.add_theme_font_size_override("normal_font_size", 14)
	label.add_theme_font_size_override("bold_font_size", 14)
	panel.add_child(label)
	visible = GameSettings.show_controls
	_refresh()


func toggle() -> void:
	visible = not visible
	GameSettings.show_controls = visible
	GameSettings.save_settings()
	if visible:
		_refresh()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if _t > 0.2:
		_t = 0.0
		_refresh()


## [keys, what it does, control id or ""] for the train being driven.
func _rows() -> Array:
	match int(GameSettings.train):
		GameSettings.TrainType.C92:
			return [
				["D / A", "Throttle", "throttle"],
				["A (at idle)", "Dynamic brake", "dynbrake"],
				["W / S", "Reverser", "reverser"],
				["' / ;", "Automatic brake", "auto_brake"],
				["[ / ]", "Independent brake", "ind_brake"],
				["B (hold)", "Bail off", ""],
				["X (hold)", "Sand", ""],
				["Space", "Horn", ""],
				["Q", "Alerter reset", ""],
				["L", "Headlights", "headlights"],
				["Backspace", "Emergency brake", ""],
			]
		GameSettings.TrainType.A4:
			return [
				["D / A", "Regulator", "regulator"],
				["W / S", "Reverser (cut-off)", "reverser"],
				["' / ;", "Vacuum brake", "brake"],
				["J", "Large ejector", "large_ejector"],
				["C", "Cylinder cocks", "cocks"],
				["X", "Sanders", "sanders"],
				["Space", "Whistle", ""],
				["R", "Firehole doors", "firedoor"],
				["E / Z", "Fire a shovelful / part of grate", ""],
				["B", "Blower", "blower"],
				["I / O", "Live / exhaust injector", ""],
				["F5 / F6", "AI fireman / AI driver", ""],
				["Backspace", "Shut regulator, full brake", ""],
			]
	return [
		["D / A", "Controller", "tbc"],
		["W / S", "Direction", "direction"],
		["F", "Safety pedal", "dsd"],
		["Q", "Vigilance", ""],
		["Space / N", "Horn high / low", ""],
		["K", "Master key", "master_key"],
		["P", "Pantograph up / down", ""],
		["H", "HSCB close / open", ""],
		["L", "Headlights", "headlights"],
		["T / Y / U", "Doors left / right / close", ""],
		["Backspace", "Emergency brake", ""],
	]


func _refresh() -> void:
	var cab: Cab = game.cab
	var sim = game.sim
	if cab == null or sim == null:
		return
	var p := ""
	if sim is C92Sim:
		p = (sim as C92Sim)._ck()
	var t := "[b][color=#ffd060]CONTROLS[/color][/b]   [color=#8890a0]F4 hides this[/color]\n"
	for r in _rows():
		var st := ""
		if r[2] != "":
			var ctl: CabControl = cab.c(p + r[2])
			if ctl:
				st = "  [color=#ffd860]%s[/color]" % ctl.state_text()
		t += "[color=#ffffff][b]%s[/b][/color]  %s%s\n" % [r[0], r[1], st]
	t += "\n[color=#9ab0d0][b]Mouse[/b][/color]  point = info, click / drag / scroll = use\n"
	t += "[color=#9ab0d0][b]Right mouse (hold)[/b][/color]  look around\n"
	t += "[color=#9ab0d0][b]V[/b][/color]  all positions   [b]← / →[/b]  previous / next\n"
	t += "[color=#9ab0d0][b]1[/b][/color]  driver's seat   [b]3[/b]  outside   [b]4[/b]  lineside\n"
	t += "[color=#9ab0d0][b]+ / -[/b][/color]  time faster / slower\n"
	t += "[color=#9ab0d0][b]F1[/b][/color] help  [b]F2[/b] checklist  [b]F3[/b] details  [b]Esc[/b] pause"
	label.text = t
