extends SceneTree
## Renders a second of the synthesised diesel sound in a few situations and
## prints its level and how long it took to compute (must be well under 1 s).
## usage: godot --headless --path . -s res://tests/audio_check.gd
func _initialize() -> void:
	var a = load("res://scripts/audio/train_audio.gd").new()
	a._dp.resize(64)
	a._dl.resize(64)
	a.diesel = true
	var cases := [
		["idle, both units", {"rpm": 440.0, "load": 0.0, "turbo": 0.0}, 0.0, 0.0],
		["notch 8, loading", {"rpm": 1050.0, "load": 1.0, "turbo": 0.9}, 0.0, 30.0],
		["cranking", {"rpm": 110.0, "load": 0.0, "turbo": 0.0, "crank": 1.0}, 0.0, 0.0],
		["idle + horn", {"rpm": 440.0, "load": 0.0, "turbo": 0.0}, 1.0, 0.0],
	]
	for c in cases:
		var pr: Dictionary = c[1]
		for u in range(2):
			a._rpm[u] = pr.get("rpm", 0.0)
			a._load[u] = pr.get("load", 0.0)
			a._turbo[u] = pr.get("turbo", 0.0)
			a._crank[u] = pr.get("crank", 0.0)
			a._gain[u] = 0.8 if u == 0 else 0.3
		a.p["horn"] = c[2]
		var vk: float = c[3]
		var t0 := Time.get_ticks_usec()
		var peak := 0.0
		var sum := 0.0
		for i in range(22050):
			var x: float = a._diesel_sample(a._noise(), vk) * a.vol * 0.45
			peak = maxf(peak, absf(x))
			sum += x * x
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		print("%-18s rms %.3f  peak %.3f  %4.0f ms per second of sound" % [c[0], sqrt(sum / 22050.0), peak, ms])
	a.free()
	quit()
