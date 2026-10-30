extends SceneTree
## Builds the game at dusk/night in the rain for a train (exercises the night lighting paths).
## usage: -s res://tests/night_check.gd -- <a4|mariyung> <dusk|night>
var game: Node
var frames := 0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var gs = root.get_node("GameSettings")
	gs.train = 1 if a.size() > 0 and a[0] == "a4" else 0
	gs.time_of_day = a[1] if a.size() > 1 else "night"
	gs.weather = "rain"
	gs.graphics_quality = 1
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)


func _process(_d: float) -> bool:
	if not game.built:
		return false
	frames += 1
	if frames == 30:
		print("night check ok: ", root.get_node("GameSettings").time_of_day)
		return true
	return false
