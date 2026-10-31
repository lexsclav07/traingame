extends Node
## Quick renders of a train and its cabs without building the world (no
## terrain, trees or scenery), for checking models and cab layouts.
## (run through tests/model_shot.gd so the autoloads exist before this compiles)
## usage: -s res://tests/model_shot.gd -- <prefix> <shots>
## shots: comma list of  cab:<view index>[:<yaw>:<pitch>]  |
##        ext:<x>:<y>:<z>:<look x>:<look y>:<look z>  (lead vehicle space) |
##        ext2:... (same, second unit's space) | ctl:<id>:<value> | run:<seconds> | night | day
var shots: Array = []
var idx := 0
var wait := 0
var prefix := "model"
var train: Train
var cab
var sim
var rig: CameraRig
var sun: DirectionalLight3D
var env: Environment
var diesel: DieselEffects


func start(a: PackedStringArray) -> void:
	prefix = a[0]
	shots = Array(a[1].split(","))
	var gs = GameSettings
	gs.train = 2
	gs.start_state = 2
	gs.coal_wagons = 3
	gs.coal_loaded = true
	var world := Node3D.new()
	add_child(world)
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	sky.sky_material = psm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	world.add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -140, 0)
	sun.shadow_enabled = true
	world.add_child(sun)
	var track := Track.new()
	track.build(RouteDefs.get_route("nsw"))
	train = Train.new()
	world.add_child(train)
	train.setup(track, 150.0)
	var lead := CoalModels.c44aci("9206")
	var trail := CoalModels.c44aci("9211")
	train.add_vehicle(lead)
	train.add_vehicle(trail)
	for i in range(3):
		train.add_vehicle(CoalModels.coal_wagon(true, i + 1, i == 2))
	cab = load("res://scripts/cab/c92_cab.gd").new()
	cab.build_both(lead, trail)
	sim = load("res://scripts/sim/c92_sim.gd").new()
	world.add_child(sim)
	sim.setup(train, cab, 2)
	train.sim = sim
	train.update_visuals()
	diesel = DieselEffects.new()
	world.add_child(diesel)
	diesel.setup([lead, trail])
	# ground under the train
	var p0 := track.pos_at(150.0 - 40.0)
	var gm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	gm.mesh = pm
	gm.material_override = MU.mat(Color(0.42, 0.4, 0.33), 0.95)
	world.add_child(gm)
	gm.position = p0 + Vector3(0, -0.25, 0)
	rig = CameraRig.new()
	world.add_child(rig)
	rig.setup(cab, train)
	rig.picking = false
	cab.set_daylight(1.0)


func _out() -> String:
	var d := OS.get_environment("SHOT_DIR")
	return (d if d != "" else OS.get_user_data_dir()) + "/"


func _process(_d: float) -> void:
	if wait == 0:
		if idx >= shots.size():
			get_tree().quit()
			return
		_setup(shots[idx])
	sim.step(0.016)
	cab.update_visuals(sim, 0.016)
	diesel.update(sim, 0.016)
	if rig.mode == "cab":
		rig.update_camera(0.016)
	wait += 1
	if wait >= 4:
		var spec: String = shots[idx]
		if spec.begins_with("cab") or spec.begins_with("ext"):
			get_viewport().get_texture().get_image().save_png(_out() + "%s_%02d.png" % [prefix, idx])
			print("saved %s_%02d (%s)" % [prefix, idx, spec])
		idx += 1
		wait = 0


func _setup(spec: String) -> void:
	var p := spec.split(":")
	match p[0]:
		"cab":
			rig.set_view(int(p[1]))
			rig.yaw = deg_to_rad(float(p[2])) if p.size() > 2 else 0.0
			rig.pitch = deg_to_rad(float(p[3])) if p.size() > 3 else 0.0
		"ext", "ext2":
			rig.mode = "free"
			var v: Vehicle = train.vehicles[0 if p[0] == "ext" else 1]
			var t: Transform3D = v.cab_root.global_transform
			var pos: Vector3 = t * Vector3(float(p[1]), float(p[2]), float(p[3]))
			var look: Vector3 = t * Vector3(float(p[4]), float(p[5]), float(p[6]))
			rig.cam.fov = 55.0
			rig.cam.global_transform = Transform3D(Basis(), pos).looking_at(look, Vector3.UP)
		"ctl":
			cab.c(p[1]).set_value(float(p[2]))
		"run":
			for i in range(int(float(p[1]) / 0.05)):
				sim.step(0.05)
		"dbg":
			var sc = cab.screens[0]
			print("screen: sim %s powered %s computer %s size %s visible %s vp %s mode %s" % [str(sc.sim != null), str(sim._powered(0)), str(sim.computer[0]), str(sc.size), str(sc.is_visible_in_tree()), str(sc.get_viewport().size), str(sc.get_viewport().render_target_update_mode)])
		"night":
			sun.light_energy = 0.0
			env.ambient_light_energy = 0.05
			env.background_energy_multiplier = 0.02
			cab.set_daylight(0.0)
		"day":
			sun.light_energy = 1.0
			env.ambient_light_energy = 1.0
			env.background_energy_multiplier = 1.0
			cab.set_daylight(1.0)
