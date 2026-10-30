extends SceneTree
## Debug: builds each route, prints stats and writes a top-down PNG map.
func _initialize() -> void:
	for id in ["nsw", "ecml"]:
		var t := Track.new()
		var t0 := Time.get_ticks_msec()
		t.build(RouteDefs.get_route(id))
		var last := Vector3(t.px[t.n - 1], t.py[t.n - 1], t.pz[t.n - 1])
		var gap := (t.pos_at(0.0) - last).length()
		var maxg := 0.0
		for g in t.grade: maxg = maxf(maxg, absf(g))
		print("%s: length %.0f m, samples %d, closure gap %.3f m (should be ~%.1f), height 0..%.1f m, max grade 1 in %.0f, bounds %s, built in %d ms" % [id, t.length, t.n, gap, Track.STEP, t.max_h, 1.0 / maxf(maxg, 1e-6), t.bounds, Time.get_ticks_msec() - t0])
		var img := Image.create(800, 800, false, Image.FORMAT_RGB8)
		img.fill(Color(0.1, 0.1, 0.12))
		var sc := 760.0 / maxf(t.bounds.size.x, t.bounds.size.y)
		for i in range(t.n):
			var x := int((t.px[i] - t.bounds.position.x) * sc) + 20
			var y := int((t.pz[i] - t.bounds.position.y) * sc) + 20
			var h := t.py[i] / maxf(t.max_h, 1.0)
			var col := Color(h, 1.0 - h, 0.3) if t.limit[i] >= 120 else Color(1, 0.2, 1)
			img.set_pixel(clampi(x, 0, 799), clampi(y, 0, 799), col)
		img.set_pixel(20 + int((t.px[0] - t.bounds.position.x) * sc), 20 + int((t.pz[0] - t.bounds.position.y) * sc), Color.WHITE)
		img.save_png(_out() + "map_%s.png" % id)
	quit()


func _out() -> String:
	var d := OS.get_environment("SHOT_DIR")
	return (d if d != "" else OS.get_user_data_dir()) + "/"
