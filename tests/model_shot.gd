extends SceneTree
## Quick renders of the 92 class and its cabs without building the world.
## usage: -s res://tests/model_shot.gd -- <prefix> <shots>   (see model_shot_node.gd)
func _initialize() -> void:
	var n: Node = load("res://tests/model_shot_node.gd").new()
	root.add_child(n)
	n.call_deferred("start", OS.get_cmdline_user_args())
