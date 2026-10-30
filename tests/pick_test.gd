extends SceneTree
## Checks that every cab control can be reached with the mouse from at least
## one cab position (looking around), i.e. nothing is hidden or unclickable.
## usage: -s res://tests/pick_test.gd -- a4|mariyung
var game: Node
var done := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var gs = root.get_node("GameSettings")
	gs.train = 1 if args.size() > 0 and args[0] == "a4" else 0
	gs.graphics_quality = 0
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)


func _process(_d: float) -> bool:
	if not game.built or done:
		return done
	done = true
	var rig = game.rig
	var cab = game.cab
	var cam: Camera3D = rig.cam
	var vp_size := root.get_viewport().get_visible_rect().size
	var reached := {}
	for vi in range(cab.view_order.size()):
		for yaw in [-2.4, -1.8, -1.2, -0.8, -0.4, 0.0, 0.4, 0.8, 1.2, 1.8, 2.4]:
			for pitch in [-1.1, -0.8, -0.5, -0.25, 0.0, 0.3]:
				rig.set_view(vi)
				rig.yaw = yaw
				rig.pitch = pitch
				rig.update_camera(0.016)
				for id in cab.controls:
					if reached.has(id):
						continue
					var ctl: CabControl = cab.controls[id]
					var pn: Node3D = ctl.get_meta("pick_node", ctl)
					var wp: Vector3 = pn.global_transform * ctl.pick_offset
					if cam.is_position_behind(wp):
						continue
					var sp := cam.unproject_position(wp)
					if sp.x < 5 or sp.y < 5 or sp.x > vp_size.x - 5 or sp.y > vp_size.y - 5:
						continue
					var o := cam.project_ray_origin(sp)
					var d := cam.project_ray_normal(sp)
					var best = null
					var bd := 3.0
					for id2 in cab.controls:
						var c2: CabControl = cab.controls[id2]
						if not c2.enabled and c2.id.begins_with("fire_zone"):
							continue
						var h := c2.pick(o, d)
						if h < bd:
							bd = h
							best = c2
					if best == ctl:
						reached[id] = cab.view_order[vi]
	var missing := []
	for id in cab.controls:
		if not reached.has(id) and not id.begins_with("fire_zone"):
			missing.append(id)
	print("controls: %d, reachable: %d, unreachable: %s" % [cab.controls.size(), reached.size(), str(missing)])
	# exercise every control once through its own interface
	var errors := 0
	for id in cab.controls:
		var ctl: CabControl = cab.controls[id]
		var before := ctl.value
		ctl.press(MOUSE_BUTTON_LEFT)
		ctl.drag(Vector2(0, -40))
		ctl.scroll(1)
		ctl.release()
		ctl.scroll(-1)
		ctl.step(1)
		ctl.step(-1)
		if not ctl.state_text() is String:
			errors += 1
	for i in range(30):
		game.sim.step(0.05)
	print("exercised all controls, errors: %d, sim failed: %s" % [errors, str(game.sim.failed)])
	quit(1 if (missing.size() > 0 or errors > 0) else 0)
	return true
