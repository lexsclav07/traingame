extends SceneTree
## Renders screenshots of the game from several views.
## usage: -s res://tests/render_game.gd -- a4|mariyung cold|prep|ready day|dusk|night outprefix
var game: Node
var frames := 0
var shots := []
var idx := 0
var wait := 0
var prefix := "shot"
var out_dir := OS.get_environment("SHOT_DIR") + "/" if OS.get_environment("SHOT_DIR") != "" else OS.get_user_data_dir() + "/"
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var gs = root.get_node("GameSettings")
	gs.train = 1 if args[0] == "a4" else 0
	gs.start_state = {"cold": 0, "prep": 1, "ready": 2}[args[1]]
	gs.time_of_day = args[2]
	prefix = args[3]
	gs.graphics_quality = 1
	gs.show_tooltips = true
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
func _process(_d: float) -> bool:
	frames += 1
	if not game.built:
		return false
	if shots.is_empty():
		var n: int = game.cab.view_order.size()
		for i in range(n):
			shots.append(["cab", i, 0.0, 0.0])
		shots.append(["cab", 0, 0.0, -0.45])   # look down at the desk / controls
		shots.append(["cab", 0, 0.7, -0.25])
		shots.append(["cab", 0, -0.7, -0.25])
		shots.append(["external", 0, 0.6, -0.18])
		shots.append(["external", 0, 2.4, -0.25])
		shots.append(["lineside", 0, 0.0, 0.0])
		_setup_shot()
	wait += 1
	if wait == 6:
		root.get_viewport().get_texture().get_image().save_png(out_dir + "%s_%02d.png" % [prefix, idx])
		idx += 1
		wait = 0
		if idx >= shots.size():
			return true
		_setup_shot()
	return false
func _setup_shot() -> void:
	var sh: Array = shots[idx]
	var rig = game.rig
	if sh[0] == "cab":
		rig.set_view(sh[1])
		rig.yaw = sh[2]
		rig.pitch = sh[3]
	elif sh[0] == "external":
		rig.set_external()
		rig.ext_yaw = sh[2]
		rig.ext_pitch = sh[3]
		rig.ext_dist = 26.0
	else:
		rig.set_lineside()
