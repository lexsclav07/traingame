extends SceneTree
## Screenshot of the main menu (checks the background picture and layout).
var frames := 0


func _initialize() -> void:
	root.add_child(load("res://scenes/main_menu.tscn").instantiate())


func _process(_d: float) -> bool:
	frames += 1
	if frames == 8:
		var d := OS.get_environment("SHOT_DIR")
		root.get_viewport().get_texture().get_image().save_png((d if d != "" else OS.get_user_data_dir()) + "/menu.png")
		print("saved menu")
		return true
	return false
