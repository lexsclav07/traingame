class_name CabControl
extends Node3D
## One interactive cab control: lever, rotary switch, toggle, push button or
## hand wheel. The player operates it with the mouse (click / drag / scroll)
## or with keyboard bindings routed through the train's sim.

signal changed(control: CabControl)

enum Kind { LEVER, ROTARY, TOGGLE, BUTTON, WHEEL }

var id := ""
var title := ""
var help := ""
var kind := Kind.LEVER
var value := 0.0
var min_v := 0.0
var max_v := 1.0
var notches: Array = []          # LEVER detents: [[value, "label"], ...]
var notch_only := false          # LEVER that can only sit in a notch
var labels: Array = []           # ROTARY position names
var spring_to := NAN             # spring-return value when released
var drag_scale := 0.004          # value per pixel of vertical mouse drag
var scroll_step := 0.05
var key_step := 0.05
var latching := false            # BUTTON that stays down until pressed again
var pressed := false
var enabled := true              # e.g. reverser locked without the key
var lock_reason := ""
var pick_extent := Vector3(0.04, 0.04, 0.04)
var pick_offset := Vector3.ZERO
var part: Node3D                 # moving part
var part_base_pos := Vector3.ZERO
var part_base_rot := Vector3.ZERO
var rot_axis := Vector3.ZERO     # degrees at max (relative), applied linearly over min..max
var move_vec := Vector3.ZERO     # metres at max
var custom_state: Callable       # returns the tooltip state text
var unit := ""
var last_touch := 0.0            # Time in msec of last player use (vigilance resets etc.)


func setup_part(p: Node3D) -> void:
	part = p
	part_base_pos = p.position
	part_base_rot = p.rotation_degrees
	_apply()


func norm() -> float:
	if max_v == min_v:
		return 0.0
	return (value - min_v) / (max_v - min_v)


func set_value(v: float, by_player := false) -> void:
	if not enabled and by_player:
		return
	var nv := clampf(v, min_v, max_v)
	if kind == Kind.ROTARY:
		nv = roundf(nv)
	elif kind == Kind.TOGGLE:
		nv = 1.0 if nv >= 0.5 else 0.0
	if nv != value:
		value = nv
		_apply()
		changed.emit(self)
	if by_player:
		last_touch = Time.get_ticks_msec()


func _apply() -> void:
	if part == null:
		return
	var t := norm()
	if kind == Kind.BUTTON:
		t = 1.0 if (pressed or value > 0.5) else 0.0
	if rot_axis != Vector3.ZERO:
		part.rotation_degrees = part_base_rot + rot_axis * t
	if move_vec != Vector3.ZERO:
		part.position = part_base_pos + move_vec * t


# ------------------------------------------------------------- interaction
func press(button: int) -> void:
	if not enabled:
		return
	last_touch = Time.get_ticks_msec()
	match kind:
		Kind.BUTTON:
			if latching:
				set_value(0.0 if value > 0.5 else 1.0, true)
			else:
				pressed = true
				set_value(1.0, true)
				_apply()
		Kind.TOGGLE:
			set_value(1.0 - value, true)
		Kind.ROTARY:
			step(1 if button == MOUSE_BUTTON_LEFT else -1)


func release() -> void:
	if kind == Kind.BUTTON and not latching:
		pressed = false
		set_value(0.0, true)
		_apply()
	if not is_nan(spring_to):
		set_value(spring_to, true)
	if kind == Kind.LEVER and not notches.is_empty():
		_snap()


func drag(rel: Vector2) -> void:
	if not enabled:
		return
	if kind == Kind.LEVER or kind == Kind.WHEEL:
		set_value(value - rel.y * drag_scale * (max_v - min_v if kind == Kind.LEVER else 1.0), true)
		if notch_only:
			_snap()


func scroll(dir: int) -> void:
	if not enabled:
		return
	match kind:
		Kind.ROTARY:
			step(dir)
		Kind.LEVER:
			if not notches.is_empty() and (notch_only or scroll_step <= 0.0):
				_notch_step(dir)
			else:
				set_value(value + dir * scroll_step * (max_v - min_v), true)
		Kind.WHEEL:
			set_value(value + dir * scroll_step, true)
		Kind.TOGGLE:
			set_value(1.0 if dir > 0 else 0.0, true)


## Keyboard / AI stepping.
func step(dir: int) -> void:
	if not enabled:
		return
	match kind:
		Kind.ROTARY:
			set_value(value + dir, true)
		Kind.LEVER:
			if not notches.is_empty() and notch_only:
				_notch_step(dir)
			else:
				set_value(value + dir * key_step * (max_v - min_v), true)
		Kind.WHEEL:
			set_value(value + dir * key_step, true)
		Kind.TOGGLE:
			set_value(1.0 if dir > 0 else 0.0, true)


func _snap() -> void:
	var best: float = value
	var bd := INF
	for nt in notches:
		var d := absf(float(nt[0]) - value)
		if d < bd:
			bd = d
			best = nt[0]
	if notch_only or bd < (max_v - min_v) * 0.04:
		set_value(best, true)


func _notch_step(dir: int) -> void:
	var vals := []
	for nt in notches:
		vals.append(float(nt[0]))
	vals.sort()
	var idx := 0
	var bd := INF
	for i in range(vals.size()):
		var d := absf(vals[i] - value)
		if d < bd:
			bd = d
			idx = i
	idx = clampi(idx + dir, 0, vals.size() - 1)
	set_value(vals[idx], true)


func notch_label() -> String:
	for nt in notches:
		if absf(float(nt[0]) - value) < 0.001:
			return nt[1]
	return ""


func state_text() -> String:
	if custom_state.is_valid():
		return custom_state.call()
	match kind:
		Kind.ROTARY:
			var i := int(value)
			return labels[i] if i >= 0 and i < labels.size() else str(i)
		Kind.TOGGLE:
			if labels.size() == 2:
				return labels[int(value)]
			return "ON" if value > 0.5 else "OFF"
		Kind.BUTTON:
			if latching:
				return "PRESSED IN" if value > 0.5 else "OUT"
			return "press" if not pressed else "held"
		Kind.LEVER:
			var nl := notch_label()
			if nl != "":
				return nl
			return "%d%%" % int(round(norm() * 100.0))
		Kind.WHEEL:
			return "%.1f %s" % [value, unit]
	return ""


## Ray / box test in local space. Returns hit distance or INF.
func pick(origin: Vector3, dir: Vector3) -> float:
	if not is_visible_in_tree():
		return INF
	var pn: Node3D = get_meta("pick_node", self)
	var gt := pn.global_transform
	var inv := gt.affine_inverse()
	var o := inv * origin
	var d := inv.basis * dir
	var lo := pick_offset - pick_extent
	var hi := pick_offset + pick_extent
	var tmin := -INF
	var tmax := INF
	for a in range(3):
		if absf(d[a]) < 1e-9:
			if o[a] < lo[a] or o[a] > hi[a]:
				return INF
		else:
			var t1 := (lo[a] - o[a]) / d[a]
			var t2 := (hi[a] - o[a]) / d[a]
			tmin = maxf(tmin, minf(t1, t2))
			tmax = minf(tmax, maxf(t1, t2))
	if tmax < maxf(tmin, 0.0):
		return INF
	var hit_local := o + d * maxf(tmin, 0.0)
	return (gt * hit_local - origin).length()
