class_name CameraRig
extends Node3D
## Cab views (with free look), an orbiting external camera and a lineside
## camera. Also picks the cab control under the mouse.

signal hover_changed(control: CabControl)

var cam: Camera3D
var cab: Cab
var train: Train
var mode := "cab"            # cab / external / lineside
var view_idx := 0
var yaw := 0.0
var pitch := 0.0
var looking := false
var fov_cab := 62.0
var ext_yaw := 0.6
var ext_pitch := -0.18
var ext_dist := 30.0
var line_s := 0.0
var line_side := 1.0
var hovered: CabControl
var picking := true       # hover-highlight controls under the mouse (off for screenshots)
var dragging: CabControl
var drag_button := 0
var highlight: MeshInstance3D
var torch: SpotLight3D      # carried when standing outside at night
var _mouse_moved := false


func setup(c: Cab, t: Train) -> void:
	cab = c
	train = t
	cam = Camera3D.new()
	cam.name = "PlayerCamera"
	cam.near = 0.03
	cam.far = 9000.0
	cam.fov = fov_cab
	add_child(cam)
	cam.current = true
	highlight = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	highlight.mesh = bm
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(1.0, 0.85, 0.2, 0.18)
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.no_depth_test = true
	hm.cull_mode = BaseMaterial3D.CULL_DISABLED
	highlight.material_override = hm
	highlight.visible = false
	add_child(highlight)
	torch = SpotLight3D.new()
	torch.light_color = Color(1.0, 0.96, 0.88)
	torch.spot_range = 14.0
	torch.spot_angle = 24.0
	torch.light_energy = 0.0
	torch.shadow_enabled = false
	cam.add_child(torch)
	torch.position = Vector3(0.15, -0.2, 0)
	set_view(0)


func set_view(i: int) -> void:
	mode = "cab"
	view_idx = clampi(i, 0, cab.view_order.size() - 1)
	yaw = 0.0
	pitch = 0.0
	cam.fov = fov_cab


func set_view_named(nm: String) -> void:
	var i := cab.view_order.find(nm)
	if i >= 0:
		set_view(i)


func prev_cab_view() -> void:
	if mode != "cab":
		set_view(0)
	else:
		set_view((view_idx - 1 + cab.view_order.size()) % cab.view_order.size())


func view_name() -> String:
	match mode:
		"cab":
			return cab.view_order[view_idx]
		"external":
			return "External"
	return "Lineside"


func next_cab_view() -> void:
	if mode != "cab":
		set_view(0)
	else:
		set_view((view_idx + 1) % cab.view_order.size())


func set_external() -> void:
	mode = "external"
	cam.fov = 60.0
	_release_drag()


func set_lineside() -> void:
	mode = "lineside"
	cam.fov = 40.0
	line_s = train.front_s + 160.0 * signf(train.speed if absf(train.speed) > 0.5 else 1.0)
	line_side = -line_side
	_release_drag()


func _release_drag() -> void:
	if dragging:
		dragging.release()
		dragging = null
	hovered = null
	highlight.visible = false


func update_camera(delta: float) -> void:
	match mode:
		"cab":
			var vname: String = cab.view_order[view_idx]
			var vp: Transform3D = cab.view_points[vname]
			var head := Basis.from_euler(Vector3(pitch, yaw, 0))
			var anchor: Node3D = cab.view_anchor.get(vname, cab)
			var t := anchor.global_transform * Transform3D(vp.basis * head, vp.origin)
			# a little ride motion: track irregularities at speed
			var spd := absf(train.speed)
			var tt := Time.get_ticks_msec() * 0.001
			var shake := Vector3(sin(tt * 7.3) * 0.6 + sin(tt * 13.1) * 0.4, sin(tt * 9.7) * 0.5 + sin(tt * 17.3) * 0.5, 0) * 0.0018 * clampf(spd / 30.0, 0.0, 1.5)
			t.origin += t.basis * shake
			cam.global_transform = t
		"external":
			var lead := train.vehicles[0]
			var center := lead.global_position + Vector3(0, 2.5, 0)
			var dir := Vector3(cos(ext_pitch) * sin(ext_yaw), -sin(ext_pitch), cos(ext_pitch) * cos(ext_yaw))
			var heading_basis := Basis(Vector3.UP, atan2(-lead.global_transform.basis.z.x, -lead.global_transform.basis.z.z) + PI)
			var pos := center + heading_basis * dir * ext_dist
			cam.global_transform = Transform3D(Basis(), pos).looking_at(center, Vector3.UP)
		"lineside":
			var ahead := line_s - train.front_s
			if absf(ahead) > 450.0 or (ahead * signf(train.speed) < -250.0):
				line_s = train.front_s + 220.0 * signf(train.speed if absf(train.speed) > 0.5 else 1.0)
				line_side = -line_side
			var f := train.track.flat_frame_at(line_s, 9.0 * line_side)
			var pos := f.origin + Vector3(0, 2.2, 0)
			var target := train.vehicles[0].global_position + Vector3(0, 2.0, 0)
			cam.global_transform = Transform3D(Basis(), pos).looking_at(target, Vector3.UP)
	if mode == "cab" and picking:
		_pick()
	var dark: bool = mode == "cab" and cab.needs_torch(cab.view_order[view_idx])
	torch.light_energy = 2.2 if dark and GameSettings.time_of_day != "day" else 0.0
	if dragging:
		_place_highlight(dragging)


func _pick() -> void:
	if looking or dragging:
		return
	var mp := get_viewport().get_mouse_position()
	var o := cam.project_ray_origin(mp)
	var d := cam.project_ray_normal(mp)
	var best: CabControl = null
	var bd := minf(3.0, cab.block_distance(o, d))
	for id in cab.controls:
		var ctl: CabControl = cab.controls[id]
		if not ctl.enabled and ctl.id.begins_with("fire_zone"):
			continue
		var h := ctl.pick(o, d)
		if h < bd:
			bd = h
			best = ctl
	if best != hovered:
		hovered = best
		hover_changed.emit(best)
	if hovered:
		_place_highlight(hovered)
	else:
		highlight.visible = false


func _place_highlight(ctl: CabControl) -> void:
	var pn: Node3D = ctl.get_meta("pick_node", ctl)
	highlight.global_transform = pn.global_transform * Transform3D(Basis().scaled(ctl.pick_extent * 2.05), ctl.pick_offset)
	highlight.visible = true


func handle_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed and mode == "cab" and hovered and hovered.kind in [CabControl.Kind.ROTARY, CabControl.Kind.TOGGLE]:
				hovered.press(MOUSE_BUTTON_RIGHT)
				return true
			looking = mb.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if looking else Input.MOUSE_MODE_VISIBLE
			if looking:
				highlight.visible = false
			return true
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and hovered and mode == "cab":
				dragging = hovered
				hovered.press(MOUSE_BUTTON_LEFT)
				return true
			if not mb.pressed and dragging:
				dragging.release()
				dragging = null
				return true
			if mb.pressed and mode == "external":
				looking = true
				return true
			if not mb.pressed and mode == "external":
				looking = false
				return true
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var dir := 1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1
			if mode == "cab" and hovered:
				hovered.scroll(dir)
			elif mode == "cab":
				cam.fov = clampf(cam.fov - dir * 4.0, 22.0, 85.0)
			elif mode == "external":
				ext_dist = clampf(ext_dist * (0.9 if dir > 0 else 1.1), 6.0, 250.0)
			else:
				cam.fov = clampf(cam.fov - dir * 3.0, 10.0, 70.0)
			return true
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		var sens := GameSettings.mouse_sensitivity * 0.01
		if dragging:
			dragging.drag(mm.relative)
			return true
		if looking:
			if mode == "cab":
				yaw = clampf(yaw - mm.relative.x * sens, -2.6, 2.6)
				pitch = clampf(pitch - mm.relative.y * sens, -1.2, 1.0)
			elif mode == "external":
				ext_yaw -= mm.relative.x * sens
				ext_pitch = clampf(ext_pitch + mm.relative.y * sens, -1.4, 0.15)
			return true
	return false
