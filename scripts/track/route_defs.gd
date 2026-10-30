class_name RouteDefs
## Route definitions. Each loop is described as HALF a circuit whose net turn is
## exactly +180 degrees; the builder repeats it rotated 180 degrees, so the loop
## always closes perfectly no matter how the segments are edited.
##
## plan entries:   ["S", length_m, limit_kmh]            straight
##                 ["C", radius_m, angle_deg, limit_kmh] curve (+ = left, - = right)
## profile entries: [length_m, grade_per_mille]  (positive = rising). Lengths are
##                 scaled to fit the loop and the last entry is adjusted so the
##                 loop returns to its starting height.


static func get_route(id: String) -> Dictionary:
	match id:
		"ecml":
			return _ecml()
		_:
			return _nsw()


static func _nsw() -> Dictionary:
	return {
		"id": "nsw",
		"name": "Hawkesbury Loop (NSW-style intercity line)",
		"theme": "nsw",
		"electrified": true,
		"units": "metric",
		"transition": 60.0,
		"default_limit": 130.0,
		"plan": [
			["S", 1100, 130],
			["C", 900, 25, 115],
			["S", 700, 115],
			["C", 450, -35, 90],
			["S", 500, 100],
			["C", 300, 60, 70],
			["S", 1500, 130],
			["C", 650, 70, 100],
			["S", 600, 115],
			["C", 420, -20, 85],
			["S", 800, 115],
			["C", 700, 80, 110],
			["S", 400, 130],
		],
		"profile": [
			[1500, 0], [3200, 25], [600, 4], [2400, -20], [1500, 0],
			[1800, 8], [1200, -6], [1600, -18], [800, 0], [2000, -6], [1000, 0],
		],
		"water_level": -14.0,
		"terrain_amp": 55.0,
		"sleeper_spacing": 0.6,
		"troughs": [],
		"platforms": [[400.0, 230.0, -1]],   # [start_s, length, side (-1 left / +1 right)]
		"km_post_start": 52.0,               # km from Central at s = 0
		"sun_rot": Vector3(-48, -140, 0),
	}


static func _ecml() -> Dictionary:
	return {
		"id": "ecml",
		"name": "Stoke Bank Loop (1930s East Coast Main Line-style)",
		"theme": "ecml",
		"electrified": false,
		"units": "imperial",
		"transition": 90.0,
		"default_limit": 145.0,
		"plan": [
			["S", 6200, 145],
			["C", 2200, 20, 145],
			["S", 3400, 145],
			["C", 1800, -15, 145],
			["S", 2600, 145],
			["C", 1250, 90, 120],
			["S", 2300, 145],
			["C", 1500, 85, 130],
			["S", 1400, 145],
		],
		# climb to "Stoke summit" at ~1 in 200 then the long descent the record was set on
		"profile": [
			[2500, 0], [9000, 5], [800, 0], [11000, -5], [3000, 0],
			[6000, 2.5], [3000, -1], [5000, -0.5], [2000, 0],
		],
		"water_level": -30.0,
		"terrain_amp": 18.0,
		"sleeper_spacing": 0.76,
		"troughs": [[1000.0, 500.0]],        # [start_s, length]: water troughs, level track
		"platforms": [[200.0, 200.0, 1]],
		"mile_post_start": 76.0,             # miles from King's Cross at s = 0
		"sun_rot": Vector3(-38, 35, 0),
	}
