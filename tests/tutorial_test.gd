extends SceneTree
## Checks the tutorial for a train: every control a step points at exists,
## every step's condition can be evaluated, and "Show me" leaves you looking at
## the step's first control from a position where the mouse can reach it.
## usage: -s res://tests/tutorial_test.gd -- mariyung|a4|c92 [units]
var game: Node
var done := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var gs = root.get_node("GameSettings")
	gs.train = {"mariyung": 0, "a4": 1, "c92": 2}.get(args[0] if args.size() > 0 else "c92", 2)
	gs.c92_units = int(args[1]) if args.size() > 1 else 2
	gs.coal_wagons = 5
	gs.start_state = 1 if gs.train == 1 else 0
	gs.tutorial = true
	gs.graphics_quality = 0
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)


func _process(_d: float) -> bool:
	if not game.built or done:
		return done
	done = true
	var tut = game.tutorial
	var cab = game.cab
	var rig = game.rig
	var cam: Camera3D = rig.cam
	var vs := root.get_viewport().get_visible_rect().size
	var fails := 0
	# cabinets open, so the controls inside can be reached
	for id in cab.controls:
		if cab.controls[id].has_meta("door"):
			cab.controls[id].set_value(1.0)
	print("%d steps" % tut.steps.size())
	for k in range(tut.steps.size()):
		var st: Dictionary = tut.steps[k]
		tut._enter(k)
		var ids: Array = st.get("ids", [])
		for id in ids:
			if tut._target_point(id) == null:
				print("FAIL step %d (%s): no control or gauge '%s'" % [k + 1, st["title"], id])
				fails += 1
		if st.get("done") != null:
			tut._is_done(st)
		if ids.is_empty():
			continue
		var first: String = ids[0]
		tut.show_target()
		rig.update_camera(0.016)
		var wp: Vector3 = tut._target_point(first)
		var ok := false
		var why := ""
		if cam.is_position_behind(wp):
			why = "behind the camera"
		else:
			var sp := cam.unproject_position(wp)
			if sp.x < 5 or sp.y < 5 or sp.x > vs.x - 5 or sp.y > vs.y - 5:
				why = "off screen at %s" % str(sp)
			elif first.begins_with("g:"):
				ok = true
			else:
				var o := cam.project_ray_origin(sp)
				var d := cam.project_ray_normal(sp)
				var best = null
				var bd := minf(3.0, cab.block_distance(o, d))
				for id2 in cab.controls:
					var h: float = cab.controls[id2].pick(o, d)
					if h < bd:
						bd = h
						best = cab.controls[id2]
				ok = best != null and best.id == first
				if not ok:
					why = "the mouse picks %s" % (best.id if best else "nothing (too far or blocked)")
		print("%s step %2d %-40s show me -> %-36s %s" % ["ok  " if ok else "FAIL", k + 1, st["title"], rig.view_name(), why])
		if not ok:
			fails += 1
	print("tutorial failures: %d" % fails)
	quit(1 if fails > 0 else 0)
	return true
