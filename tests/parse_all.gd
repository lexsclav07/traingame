extends SceneTree
## Loads every script so parse errors show up in one run.
func _initialize() -> void:
	var dirs := ["res://scripts"]
	var bad := 0
	while not dirs.is_empty():
		var d: String = dirs.pop_back()
		for sub in DirAccess.get_directories_at(d):
			dirs.append(d + "/" + sub)
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".gd"):
				var s = load(d + "/" + f)
				if s == null or not (s as GDScript).can_instantiate():
					print("FAILED: ", d + "/" + f)
					bad += 1
	print("parse check done, failures: ", bad)
	quit(1 if bad > 0 else 0)
