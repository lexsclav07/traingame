extends SceneTree
## Flexible screenshot tool for graphics work.
## usage: -s res://tests/shot.gd -- <a4|mariyung|c92> <cold|prep|ready> <day|dusk|night> <clear|rain> <quality 0-3> <prefix> <shots>
## shots: comma list of  cab:<view>:<yaw>:<pitch>  |  ext:<yaw>:<pitch>:<dist>  |  line  |
##        free:<s>:<lateral>:<height>:<yaw deg>:<pitch deg>  |  freeg:(same, height above the ground)  |
##        move:<metres>:<speed>  |
##        ctl:<id>:<value>  |  sim:<variable>:<value>  |  wait:<frames>  |  run:<seconds>  |
##        xing:<crossing>:<metres short of it>:<speed>
var game: Node
var shots: Array = []
var idx := 0
var wait := 0
var prefix := "shot"
var settle := 5


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var gs = root.get_node("GameSettings")
	gs.train = {"mariyung": 0, "a4": 1, "c92": 2}[a[0]]
	gs.start_state = {"cold": 0, "prep": 1, "ready": 2}[a[1]]
	gs.time_of_day = a[2]
	gs.weather = a[3]
	gs.graphics_quality = int(a[4])
	prefix = a[5]
	shots = Array(a[6].split(","))
	gs.show_tooltips = false
	# extra settings: SHOT_OPTS="units=1,wagons=0,route=flat,drag=1,tutorial=1"
	for kv in OS.get_environment("SHOT_OPTS").split(",", false):
		var p := kv.split("=")
		match p[0]:
			"units":
				gs.c92_units = int(p[1])
			"wagons":
				gs.coal_wagons = int(p[1])
			"route":
				gs.route = p[1]
			"drag":
				gs.drag_timer = p[1] == "1"
			"tutorial":
				gs.tutorial = p[1] == "1"
			"keys":
				gs.show_controls = p[1] == "1"
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)


func _out() -> String:
	var d := OS.get_environment("SHOT_DIR")
	return (d if d != "" else OS.get_user_data_dir()) + "/"


func _process(_d: float) -> bool:
	if not game.built:
		return false
	if wait == 0:
		if idx >= shots.size():
			return true
		_setup(shots[idx])
	wait += 1
	if wait >= settle:
		var spec: String = shots[idx]
		if not (spec.begins_with("move") or spec.begins_with("ctl") or spec.begins_with("sim") or spec.begins_with("wait") or spec.begins_with("run") or spec.begins_with("xing") or spec.begins_with("tut")):
			root.get_viewport().get_texture().get_image().save_png(_out() + "%s_%02d.png" % [prefix, idx])
			print("saved %s_%02d (%s)" % [prefix, idx, spec])
		idx += 1
		wait = 0
	return false


func _setup(spec: String) -> void:
	var p := spec.split(":")
	var rig = game.rig
	rig.picking = false
	rig.highlight.visible = false
	settle = int(OS.get_environment("SETTLE")) if OS.get_environment("SETTLE") != "" else 5
	match p[0]:
		"cab":
			rig.set_view(int(p[1]))
			rig.yaw = float(p[2]) if p.size() > 2 else 0.0
			rig.pitch = float(p[3]) if p.size() > 3 else 0.0
		"ext":
			rig.set_external()
			rig.ext_yaw = float(p[1])
			rig.ext_pitch = float(p[2])
			rig.ext_dist = float(p[3]) if p.size() > 3 else 26.0
		"line":
			rig.set_lineside()
		"free":
			# free:<s>:<lateral>:<height>:<yaw deg>:<pitch deg> relative to the track
			rig.mode = "free"
			var f: Transform3D = game.track.flat_frame_at(float(p[1]), float(p[2]))
			var b: Basis = f.basis * Basis.from_euler(Vector3(deg_to_rad(float(p[5])), deg_to_rad(float(p[4])), 0))
			rig.cam.fov = 62.0
			rig.cam.global_transform = Transform3D(b, f.origin + Vector3.UP * float(p[3]))
		"freeg":
			# freeg:<s>:<lateral>:<height above the ground>:<yaw deg>:<pitch deg>
			rig.mode = "free"
			var fg: Transform3D = game.track.flat_frame_at(float(p[1]), float(p[2]))
			var bg: Basis = fg.basis * Basis.from_euler(Vector3(deg_to_rad(float(p[5])), deg_to_rad(float(p[4])), 0))
			var gy: float = game.terrain.mesh_height(fg.origin.x, fg.origin.z)
			rig.cam.fov = 62.0
			rig.cam.global_transform = Transform3D(bg, Vector3(fg.origin.x, gy + float(p[3]), fg.origin.z))
		"ctl":
			# ctl:<control id>:<value>
			game.cab.c(p[1]).set_value(float(p[2]))
			settle = 2
		"sim":
			# sim:<variable>:<value>
			game.sim.set(p[1], float(p[2]))
			settle = 2
		"wait":
			# wait:<frames> (let the game run, e.g. wipers sweeping)
			settle = int(p[1])
		"tut":
			# tut:<step number>[:show]  tutorial step, optionally "Show me"
			game.tutorial._enter(int(p[1]) - 1)
			if p.size() > 2:
				game.tutorial.show_target()
			settle = 6
		"poslist":
			# the position list open
			game.positions.toggle_list()
			settle = 6
		"run":
			# run:<seconds> of simulation without rendering it
			for i in range(int(float(p[1]) / 0.05)):
				game.sim.step(0.05)
				game.train.physics_step(0.05)
			game.train.update_visuals()
			game.cab.call("update_visuals", game.sim, 0.05)
			game.crossings.settle(game.train)
			settle = 2
		"xing":
			# xing:<index>:<metres short of it>:<speed> puts the train's front there
			var xs: Array = game.crossings.xings
			var xi: Dictionary = xs[int(p[1]) % xs.size()]
			game.train.front_s = float(xi["s"]) - float(p[2])
			game.train.speed = float(p[3]) if p.size() > 3 else 0.0
			game.train.update_visuals()
			game.crossings.settle(game.train)
			settle = 2
		"move":
			# jump the train along the line and give it speed (no rendering needed)
			var secs := float(p[1])
			game.train.front_s += secs
			game.train.speed = float(p[2]) if p.size() > 2 else 0.0
			game.train.update_visuals()
			game.crossings.settle(game.train)
			settle = 2
