extends SceneTree
## Screenshot of the main menu (checks the background picture and layout).
var frames := 0


## usage: -s res://tests/menu_shot.gd [-- <train index>]
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		root.get_node("GameSettings").train = int(a[0])
	root.add_child(load("res://scenes/main_menu.tscn").instantiate())


func _process(_d: float) -> bool:
	frames += 1
	if frames == 8:
		var d := OS.get_environment("SHOT_DIR")
		root.get_viewport().get_texture().get_image().save_png((d if d != "" else OS.get_user_data_dir()) + "/menu.png")
		print("saved menu")
		return true
	return false
