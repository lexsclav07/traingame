extends SceneTree
## Builds the full game scene for a train and runs some frames.
## usage: godot --headless -s res://tests/smoke_game.gd -- a4|mariyung|c92 cold|prep|ready
var game: Node
var frames := 0
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var gs = root.get_node("GameSettings")
	gs.train = {"mariyung": 0, "a4": 1, "c92": 2}.get(args[0] if args.size() > 0 else "mariyung", 0)
	gs.start_state = {"cold": 0, "prep": 1, "ready": 2}.get(args[1] if args.size() > 1 else "ready", 2)
	gs.graphics_quality = 0
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
func _process(_d: float) -> bool:
	frames += 1
	if frames == 5 or frames == 60:
		if game.built:
			var sim = game.sim
			print("frame %d: speed %.2f, front_s %.1f, %s" % [frames, game.train.speed, game.train.front_s, " | ".join(sim.hud_lines())])
	return frames > 61
