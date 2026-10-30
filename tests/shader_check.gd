extends SceneTree
## Compiles every custom shader by drawing a small mesh with each (prints shader errors if any).
var frames := 0


func _initialize() -> void:
	var r := Node3D.new()
	root.add_child(r)
	var cam := Camera3D.new()
	r.add_child(cam)
	cam.position = Vector3(0, 0, 4)
	var i := 0
	for path in ["res://assets/shaders/foliage.gdshader", "res://assets/shaders/terrain.gdshader", "res://assets/shaders/water.gdshader"]:
		var mi := MeshInstance3D.new()
		mi.mesh = QuadMesh.new()
		var m := ShaderMaterial.new()
		m.shader = load(path)
		if path.ends_with("foliage.gdshader"):
			m.set_shader_parameter("ground_blend", 0.5)
			m.set_shader_parameter("up_normal", 0.5)
		mi.material_override = m
		r.add_child(mi)
		mi.position = Vector3(i * 1.2 - 1.2, 0, 0)
		i += 1
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://assets/shaders/sky.gdshader")
	e.sky.sky_material = sm
	env.environment = e
	r.add_child(env)
	r.add_child(DirectionalLight3D.new())


func _process(_d: float) -> bool:
	frames += 1
	if frames == 5:
		print("shaders drawn")
		return true
	return false
