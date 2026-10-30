extends SceneTree
## Flexible screenshot tool for graphics work.
## usage: -s res://tests/shot.gd -- <a4|mariyung> <cold|prep|ready> <day|dusk|night> <clear|rain> <quality 0-3> <prefix> <shots>
## shots: comma list of  cab:<view>:<yaw>:<pitch>  |  ext:<yaw>:<pitch>:<dist>  |  line  |  move:<seconds>  (drive at speed first)
var game: Node
var shots: Array = []
var idx := 0
var wait := 0
var prefix := "shot"
var settle := 5


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var gs = root.get_node("GameSettings")
	gs.train = 1 if a[0] == "a4" else 0
	gs.start_state = {"cold": 0, "prep": 1, "ready": 2}[a[1]]
	gs.time_of_day = a[2]
	gs.weather = a[3]
	gs.graphics_quality = int(a[4])
	prefix = a[5]
	shots = Array(a[6].split(","))
	gs.show_tooltips = false
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
		if not spec.begins_with("move"):
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
	settle = 5
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
		"move":
			# jump the train along the line and give it speed (no rendering needed)
			var secs := float(p[1])
			game.train.front_s += secs
			game.train.speed = float(p[2]) if p.size() > 2 else 0.0
			game.train.update_visuals()
			settle = 2
