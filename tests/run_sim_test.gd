extends SceneTree
## usage: godot --headless --path . -s res://tests/run_sim_test.gd -- a4|mariyung
## (the checks live in sim_checks.gd so autoloads are registered before it compiles)
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var checks: Node = load("res://tests/sim_checks.gd").new()
	root.add_child(checks)
	checks.run_tests(args[0] if args.size() > 0 else "a4")
	print("checks failed: %d" % checks.failures)
	quit(1 if checks.failures > 0 else 0)
