extends SceneTree
## Renders a few cab gauges on their own (quick check of the baked dial faces).
var frames := 0
var root3d: Node3D


func _initialize() -> void:
	root3d = Node3D.new()
	root.add_child(root3d)
	var cam := Camera3D.new()
	root3d.add_child(cam)
	cam.position = Vector3(0, 0, 0.5)
	cam.fov = 40
	var l := DirectionalLight3D.new()
	root3d.add_child(l)
	l.rotation_degrees = Vector3(-30, 20, 0)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.2, 0.22, 0.25)
	e.ambient_light_color = Color(0.6, 0.6, 0.6)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment = e
	root3d.add_child(env)
	var specs := [
		[Vector3(-0.17, 0.05, 0), 0.075, 0, 300, 50, 10, "BOILER", "lb/sq in", Color(0.95, 0.93, 0.86), 250.0, 270.0],
		[Vector3(0.0, 0.05, 0), 0.07, 0, 1000, 200, 50, "MR / BC", "kPa", Color(0.94, 0.94, 0.92), INF, 270.0],
		[Vector3(0.17, 0.05, 0), 0.075, 0, 120, 20, 5, "SPEED", "m.p.h.", Color(0.06, 0.06, 0.07), INF, 300.0],
		[Vector3(-0.08, -0.11, 0), 0.06, 0, 30, 5, 1, "VACUUM", "ins", Color(0.95, 0.93, 0.86), INF, 270.0],
		[Vector3(0.08, -0.11, 0), 0.06, 0, 5000, 1000, 250, "TENDER", "gallons", Color(0.95, 0.93, 0.86), INF, 270.0],
	]
	for sp in specs:
		var g := CabGauge.new()
		root3d.add_child(g)
		g.position = sp[0]
		var div := 1000.0 if sp[3] == 5000 else 1.0
		g.build(sp[1], sp[2], sp[3], sp[4], sp[5], sp[6], sp[7], [Color(0.05, 0.05, 0.05)], sp[8], div, Color(0.7, 0.55, 0.25), sp[9], sp[10])
		g.set_value(0, sp[3] * 0.62)


func _process(_d: float) -> bool:
	frames += 1
	if frames == 40:
		var d := OS.get_environment("SHOT_DIR")
		root.get_viewport().get_texture().get_image().save_png((d if d != "" else OS.get_user_data_dir()) + "/gauges.png")
		print("saved gauges")
		return true
	return false
