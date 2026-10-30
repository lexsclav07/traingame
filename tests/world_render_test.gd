extends SceneTree
## Debug: build a route and screenshot it from a few positions.
var frames := 0
var cam: Camera3D
var track: Track
var shots := []
var route_id := "nsw"
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: route_id = args[0]
	var world := Node3D.new()
	root.add_child(world)
	var t0 := Time.get_ticks_msec()
	track = Track.new()
	track.build(RouteDefs.get_route(route_id))
	var ter := TerrainBuilder.new()
	ter.setup(track, track.route)
	var t1 := Time.get_ticks_msec()
	ter.build(world, 1)
	var t2 := Time.get_ticks_msec()
	ter.scatter_trees(world, 1)
	TrackBuilder.new().build(world, track, ter, 1)
	var t3 := Time.get_ticks_msec()
	SceneryBuilder.new().build(world, track, ter, 1)
	var t4 := Time.get_ticks_msec()
	EnvironmentBuilder.new().build(world, track.route, "day", "clear", 1)
	print("setup %d ms, terrain mesh %d ms, trees+track %d ms, scenery %d ms" % [t1 - t0, t2 - t1, t3 - t2, t4 - t3])
	cam = Camera3D.new()
	cam.far = 8000.0
	world.add_child(cam)
	shots = [[300.0, 0.0, 2.6], [2200.0, 4.0, 3.5], [6000.0, -1.0, 12.0]] if route_id == "nsw" else [[1100.0, 0.0, 2.6], [8000.0, 4.0, 3.5], [20000.0, -6.0, 6.0]]
func _process(_d: float) -> bool:
	frames += 1
	var shot := (frames - 1) / 4
	if shot >= shots.size():
		return true
	var sh: Array = shots[shot]
	var f := track.frame_at(sh[0], sh[1])
	cam.global_transform = f.translated_local(Vector3(0, sh[2], 0))
	cam.rotate_object_local(Vector3.RIGHT, deg_to_rad(-4))
	if frames % 4 == 0:
		root.get_viewport().get_texture().get_image().save_png(_out() + "world_%s_%d.png" % [route_id, shot])
	return false


func _out() -> String:
	var d := OS.get_environment("SHOT_DIR")
	return (d if d != "" else OS.get_user_data_dir()) + "/"
