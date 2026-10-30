extends SceneTree
## Measures how long the world takes to build (headless).
var game: Node
var t0 := 0
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var gs = root.get_node("GameSettings")
	gs.train = 1 if a.size() > 0 and a[0] == "a4" else 0
	gs.graphics_quality = int(a[1]) if a.size() > 1 else 2
	t0 = Time.get_ticks_msec()
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
func _process(_d: float) -> bool:
	if game.built:
		print("built in %d ms (quality %d)" % [Time.get_ticks_msec() - t0, root.get_node("GameSettings").graphics_quality])
		var count := 0
		var mmi := 0
		var inst := 0
		for n in game.find_children("*", "MultiMeshInstance3D", true, false):
			mmi += 1
			inst += (n as MultiMeshInstance3D).multimesh.instance_count
		print("multimesh nodes: %d, instances: %d" % [mmi, inst])
		return true
	return false
