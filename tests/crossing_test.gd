extends SceneTree
## Level crossings: the protection must be complete (booms down / gates shut
## across the road) before a train at line speed reaches the road, and must
## clear again once the train has gone.
## usage: godot --headless -s res://tests/crossing_test.gd -- a4|mariyung|c92
var game: Node
var failures := 0
var cars_seen := 0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var gs = root.get_node("GameSettings")
	gs.train = {"mariyung": 0, "a4": 1, "c92": 2}.get(a[0] if a.size() > 0 else "mariyung", 0)
	gs.start_state = 2
	gs.graphics_quality = 0
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)


func _process(_d: float) -> bool:
	if not game.built:
		return false
	game.paused = true
	var lc = game.crossings
	var tr = game.train
	var track = game.track
	print("%d level crossings on %s" % [lc.xings.size(), track.route["id"]])
	if lc.xings.size() < 2:
		_fail("expected at least two crossings")
	for x in lc.xings:
		var c: Dictionary = x["c"]
		var o: Vector3 = c["o"]
		# the road meets the rail top at the crossing and is never below the ground
		var y0: float = lc._road_y(c, 0.0, 0.0)
		print("  s %.0f  road %.0f m / %.0f m, half width %.1f, road at rail top %+.3f m" % [c["s"], c["len"][0], c["len"][1], c["hw"], y0 - o.y])
		if absf(y0 - o.y) > 0.05:
			_fail("road not at rail level at s %.0f" % c["s"])
		for u in [-60.0, -20.0, -9.0, 9.0, 20.0, 60.0]:
			var g: float = lc._ground(c, u, 0.0)
			var y: float = lc._road_y(c, u, 0.0)
			if y < g + 0.04:
				_fail("road below ground at u %.0f" % u)
		# nothing of the scenery may stand in the road
		for k in range(-4, 5):
			var p: Vector3 = o + (c["f"] as Vector3) * (k * 0.5)
			if game.terrain.road_dist(p.x, p.z) > 2.5:
				_fail("road_dist wrong at the crossing")
	for speed in [8.0, 25.0, 40.0, 56.0]:
		for x in lc.xings:
			_run_past(lc, tr, x, speed)
	print("road vehicles were waiting in %d steps while trains passed" % cars_seen)
	print("crossing test done, failures: %d" % failures)
	quit(1 if failures > 0 else 0)
	return true


## Drive the train past one crossing at a steady speed, stepping the crossings.
func _run_past(lc, tr, x: Dictionary, speed: float) -> void:
	var s: float = x["s"]
	tr.speed = speed
	tr.front_s = s - 3000.0
	lc.settle(tr)
	var dt := 0.05
	var arrived := false
	var protected_on_arrival := false
	var cleared_after := false
	var t := 0.0
	while t < 600.0:
		tr.front_s += speed * dt
		lc.update(dt, tr, Vector3.ZERO)
		t += dt
		var ahead: float = game.terrain.sdiff(s, tr.front_s)
		if not arrived and ahead <= 0.0:
			arrived = true
			protected_on_arrival = (float(x["boom"]) <= 0.001) if lc.nsw else (float(x["gate"]) <= 0.001)
		var behind: float = game.terrain.sdiff(tr.front_s - tr.total_length(), s)
		# no road vehicle may be on the crossing while the train is on it
		if ahead < 30.0 and behind < 30.0:
			for car in x["cars"]:
				if (car["n"] as Node3D).visible and absf(float(car["u"])) < lc.PANEL_U + 1.0:
					_fail("car on the crossing with the train at s %.0f" % s)
					return
			if x["cars"].any(func(cc): return (cc["n"] as Node3D).visible):
				cars_seen += 1
		if arrived and behind > 40.0 + speed * 11.0:
			cleared_after = (float(x["boom"]) >= 0.999) if lc.nsw else (float(x["gate"]) >= 0.999)
			break
	var tag := "s %.0f at %.0f m/s" % [s, speed]
	if not protected_on_arrival:
		_fail("%s: road not closed when the train arrived (boom %.2f gate %.2f)" % [tag, x["boom"], x["gate"]])
	elif not cleared_after:
		_fail("%s: road not reopened after the train" % tag)
	else:
		print("  %s: closed in time, reopened after" % tag)


func _fail(msg: String) -> void:
	failures += 1
	print("FAIL: " + msg)
