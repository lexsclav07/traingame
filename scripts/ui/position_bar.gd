class_name PositionBar
extends Control
## Where you are and how to get anywhere else. A bar at the bottom of the
## screen shows the current position with ◀ ▶ buttons (or the arrow keys) to
## step to the previous / next one; clicking the name, or V, opens a list of
## every position grouped by where it is (in the cab, outside, the second
## unit, cameras), each with its shortcut key. Click one to go there.

var game: Node
var bar: PanelContainer
var name_btn: Button
var list_panel: PanelContainer
var list_box: VBoxContainer
var _buttons := {}           # position name -> Button in the list
var _last := ""


func setup(g: Node) -> void:
	game = g
	name = "PositionBar"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar = _panel(Color(0.03, 0.04, 0.06, 0.72))
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_top = -52
	bar.offset_bottom = -52
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_END
	add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	bar.add_child(row)
	_btn(row, "◀", func(): _step(-1), "Previous position (Left arrow)")
	name_btn = _btn(row, "", toggle_list, "All positions (V)")
	name_btn.custom_minimum_size = Vector2(300, 34)
	name_btn.add_theme_font_size_override("font_size", 17)
	_btn(row, "▶", func(): _step(1), "Next position (Right arrow)")
	var hint := Label.new()
	hint.text = "  V: all positions"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.65, 0.7, 0.78))
	row.add_child(hint)

	list_panel = _panel(Color(0.03, 0.04, 0.07, 0.94))
	list_panel.anchor_left = 0.5
	list_panel.anchor_right = 0.5
	list_panel.anchor_top = 1.0
	list_panel.anchor_bottom = 1.0
	list_panel.offset_top = -62
	list_panel.offset_bottom = -62
	list_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	list_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(list_panel)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 22)
	list_panel.add_child(cols)
	for grp in _groups():
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 3)
		cols.add_child(vb)
		var h := Label.new()
		h.text = grp[0]
		h.add_theme_font_size_override("font_size", 14)
		h.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
		vb.add_child(h)
		for e in grp[1]:
			var nm: String = e[0]
			var key: String = e[1]
			var b := _btn(vb, ("%s   [%s]" % [e[2], key]) if key != "" else e[2], func(): _go(nm), "")
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.custom_minimum_size = Vector2(250, 30)
			_buttons[nm] = b
	list_panel.visible = false


func _panel(col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", sb)
	return p


func _btn(parent: Control, t: String, f: Callable, tip: String) -> Button:
	var b := Button.new()
	b.text = t
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(40, 34)
	b.pressed.connect(f)
	parent.add_child(b)
	return b


## Shortcut key for a cab position ("" if none).
func _key(i: int, nm: String) -> String:
	var cab: Cab = game.cab
	if i == 0:
		return "1"
	if i == 1 and not cab.view_outside.get(nm, false):
		return "2"
	var q := cab.quick_views.find(nm)
	if q >= 0:
		return str(q + 5)
	return ""


## [group title, [[position, key, label], ...]] for the list.
func _groups() -> Array:
	var cab: Cab = game.cab
	var inside := []
	var outside := []
	var second := []
	var second_out := []
	for i in range(cab.view_order.size()):
		var nm: String = cab.view_order[i]
		var out: bool = cab.view_outside.get(nm, false)
		var label := nm
		var is2 := nm.begins_with("Second unit: ")
		if is2:
			label = nm.substr(13)
			label = label[0].to_upper() + label.substr(1)
		var e := [nm, _key(i, nm), label]
		if is2:
			(second_out if out else second).append(e)
		else:
			(outside if out else inside).append(e)
	var g := [["In the cab", inside]]
	if not outside.is_empty():
		g.append(["Outside on foot", outside])
	if not second.is_empty() or not second_out.is_empty():
		g.append(["Second unit", second + second_out])
	g.append(["Cameras", [["@external", "3", "Outside the train"], ["@lineside", "4", "Lineside camera"]]])
	return g


func toggle_list() -> void:
	list_panel.visible = not list_panel.visible
	if list_panel.visible:
		list_panel.reset_size()


func _go(nm: String) -> void:
	var rig: CameraRig = game.rig
	match nm:
		"@external":
			rig.set_external()
		"@lineside":
			rig.set_lineside()
		_:
			rig.set_view_named(nm)
	list_panel.visible = false


func _step(d: int) -> void:
	var rig: CameraRig = game.rig
	if d > 0:
		rig.next_cab_view()
	else:
		rig.prev_cab_view()


func _process(_delta: float) -> void:
	var rig: CameraRig = game.rig
	if rig == null:
		return
	var cur := rig.view_name()
	if cur == _last:
		return
	_last = cur
	var key := ""
	if rig.mode == "cab":
		key = _key(rig.view_idx, cur)
	else:
		key = "3" if rig.mode == "external" else "4"
		cur = "Outside the train" if rig.mode == "external" else "Lineside camera"
	name_btn.text = ("%s   [%s]" % [cur, key]) if key != "" else cur
	for nm in _buttons:
		var on: bool = rig.mode == "cab" and nm == rig.view_name()
		(_buttons[nm] as Button).modulate = Color(1.0, 0.85, 0.35) if on else Color.WHITE
