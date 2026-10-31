class_name Cab
extends Node3D
## Container for a driving cab: controls, gauges, lamps and view points, plus
## builder helpers used by the train-specific cab scripts.
## Local frame = vehicle model frame: -Z forward, +Y up, +X right.

var controls := {}
var gauges := {}
var lamps := {}         # id -> StandardMaterial3D (emissive)
var lamp_colors := {}
var view_points := {}   # name -> Transform3D (local)
var view_order: Array[String] = []
var view_anchor := {}   # name -> Node3D the view is fixed to (default: this cab)
var view_outside := {}  # name -> true for positions outside the cab (torch at night)
var quick_views: Array[String] = []   # views on keys 5..9
## Volumes the mouse cannot reach through (a closed cabinet): each is
## [Node3D frame, centre, half extents, door CabControl]; inactive while its door is open.
var blockers: Array = []
var flashing := {}      # lamp id -> period (s)
var _t := 0.0
## soft daylight bouncing in through the windows (no GI in most render modes)
var fill_lights: Array[Light3D] = []
var fill_energy: Array[float] = []


## Add a shadowless fill light; its energy is scaled by set_daylight().
func add_fill(pos: Vector3, rng: float, energy: float, col := Color(1.0, 0.97, 0.92), parent: Node3D = null) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = col
	l.omni_range = rng
	l.omni_attenuation = 0.8
	l.shadow_enabled = false
	l.light_specular = 0.0
	l.light_energy = 0.0
	(parent if parent else self).add_child(l)
	l.position = pos
	fill_lights.append(l)
	fill_energy.append(energy)
	return l


## 1 = full daylight, 0 = night.
func set_daylight(level: float) -> void:
	for i in range(fill_lights.size()):
		fill_lights[i].light_energy = fill_energy[i] * level


func add_view(nm: String, pos: Vector3, yaw_deg := 0.0, pitch_deg := -8.0, anchor: Node3D = null, outside := false) -> void:
	var b := Basis.from_euler(Vector3(deg_to_rad(pitch_deg), deg_to_rad(yaw_deg), 0))
	view_points[nm] = Transform3D(b, pos)
	view_order.append(nm)
	if anchor:
		view_anchor[nm] = anchor
	if outside:
		view_outside[nm] = true


## Whether the crew would be using a torch at this position at night.
func needs_torch(view_name: String) -> bool:
	return view_outside.get(view_name, false)


func add_blocker(frame_node: Node3D, centre: Vector3, half: Vector3, door_ctl: CabControl) -> void:
	blockers.append([frame_node, centre, half, door_ctl])


## Distance along a ray to the nearest closed cabinet (INF if none is in the way).
func block_distance(origin: Vector3, dir: Vector3) -> float:
	var best := INF
	for bl in blockers:
		var dc: CabControl = bl[3]
		if dc and dc.value > 0.5:
			continue
		var gt: Transform3D = (bl[0] as Node3D).global_transform
		var inv := gt.affine_inverse()
		var o := inv * origin
		var d := inv.basis * dir
		var lo: Vector3 = bl[1] - bl[2]
		var hi: Vector3 = bl[1] + bl[2]
		var tmin := -INF
		var tmax := INF
		var miss := false
		for a in range(3):
			if absf(d[a]) < 1e-9:
				if o[a] < lo[a] or o[a] > hi[a]:
					miss = true
					break
			else:
				var t1 := (lo[a] - o[a]) / d[a]
				var t2 := (hi[a] - o[a]) / d[a]
				tmin = maxf(tmin, minf(t1, t2))
				tmax = minf(tmax, maxf(t1, t2))
		if miss or tmax < maxf(tmin, 0.0):
			continue
		best = minf(best, (gt * (o + d * maxf(tmin, 0.0)) - origin).length())
	return best


func c(id: String) -> CabControl:
	return controls.get(id)


func val(id: String) -> float:
	var cc: CabControl = controls.get(id)
	return cc.value if cc else 0.0


func _register(ctl: CabControl, id: String, title: String, help: String) -> CabControl:
	ctl.id = id
	ctl.title = title
	ctl.help = help
	ctl.name = id
	controls[id] = ctl
	return ctl


func _host(parent: Node3D, pos: Vector3, rot: Vector3) -> CabControl:
	var ctl := CabControl.new()
	(parent if parent else self).add_child(ctl)
	ctl.position = pos
	ctl.rotation_degrees = rot
	return ctl


# ------------------------------------------------------------- builders
## Lever: pivots at the host origin; handle extends along local +Y.
## sweep = rotation (deg) applied from min to max; base = rotation at min.
func lever(id: String, title: String, parent: Node3D, pos: Vector3, rot: Vector3, handle_len: float,
		base: Vector3, sweep: Vector3, mat: Material, knob_mat: Material, help := "", knob_r := 0.025) -> CabControl:
	var ctl := _host(parent, pos, rot)
	_register(ctl, id, title, help)
	ctl.kind = CabControl.Kind.LEVER
	var pivot := Node3D.new()
	ctl.add_child(pivot)
	pivot.rotation_degrees = base
	MU.box(pivot, Vector3(0.018, handle_len, 0.018), Vector3(0, handle_len * 0.5, 0), mat)
	MU.sphere(pivot, knob_r, Vector3(0, handle_len, 0), knob_mat, 10)
	ctl.rot_axis = sweep
	ctl.setup_part(pivot)
	ctl.pick_extent = Vector3(maxf(knob_r * 1.6, 0.03), maxf(handle_len * 0.5, 0.04), maxf(knob_r * 1.6, 0.03))
	ctl.pick_offset = Vector3(0, handle_len * 0.55, 0)
	ctl.set_meta("pick_node", pivot)
	return ctl


## Rotary switch: knob faces +Z, turns about Z. 'step_deg' per position.
func rotary(id: String, title: String, parent: Node3D, pos: Vector3, rot: Vector3, labels: Array, value: int,
		help := "", knob_r := 0.018, step_deg := 45.0, key_style := false) -> CabControl:
	var ctl := _host(parent, pos, rot)
	_register(ctl, id, title, help)
	ctl.kind = CabControl.Kind.ROTARY
	ctl.labels = labels
	ctl.min_v = 0
	ctl.max_v = labels.size() - 1
	ctl.value = value
	var plate := MU.cyl(ctl, knob_r * 1.9, 0.004, Vector3(0, 0, 0.002), MU.mat(Color(0.12, 0.12, 0.13), 0.5, 0.3), Vector3(90, 0, 0), 20)
	plate.name = "Plate"
	var pivot := Node3D.new()
	ctl.add_child(pivot)
	var start := (labels.size() - 1) * step_deg * 0.5
	pivot.rotation_degrees = Vector3(0, 0, start)
	if key_style:
		MU.box(pivot, Vector3(0.012, 0.045, 0.012), Vector3(0, 0, 0.02), MU.mat(Color(0.75, 0.7, 0.4), 0.3, 0.9))
		MU.box(pivot, Vector3(0.03, 0.028, 0.004), Vector3(0, 0, 0.032), MU.mat(Color(0.75, 0.7, 0.4), 0.3, 0.9))
	else:
		MU.cyl(pivot, knob_r, 0.022, Vector3(0, 0, 0.013), MU.mat(Color(0.08, 0.08, 0.08), 0.5), Vector3(90, 0, 0), 14)
		MU.box(pivot, Vector3(0.007, knob_r * 1.9, 0.026), Vector3(0, 0, 0.015), MU.mat(Color(0.85, 0.85, 0.85), 0.5))
	ctl.rot_axis = Vector3(0, 0, -step_deg * (labels.size() - 1))
	ctl.setup_part(pivot)
	ctl.pick_extent = Vector3(knob_r * 1.5, knob_r * 1.5, 0.03)
	ctl.pick_offset = Vector3(0, 0, 0.015)
	# position legends around the knob
	for i in range(labels.size()):
		var a := deg_to_rad(90.0 + start - i * step_deg)
		var lp := Vector3(cos(a), sin(a), 0) * knob_r * 2.6
		MU.label(ctl, labels[i], lp + Vector3(0, 0, 0.005), knob_r * 0.012, Color(0.92, 0.92, 0.9), Vector3.ZERO, 24)
	return ctl


func toggle(id: String, title: String, parent: Node3D, pos: Vector3, rot: Vector3, labels: Array, value: int, help := "") -> CabControl:
	var ctl := _host(parent, pos, rot)
	_register(ctl, id, title, help)
	ctl.kind = CabControl.Kind.TOGGLE
	ctl.labels = labels
	ctl.value = value
	MU.box(ctl, Vector3(0.026, 0.04, 0.008), Vector3(0, 0, 0.004), MU.mat(Color(0.15, 0.15, 0.16), 0.4, 0.6))
	var pivot := Node3D.new()
	ctl.add_child(pivot)
	pivot.position = Vector3(0, 0, 0.008)
	pivot.rotation_degrees = Vector3(30, 0, 0)
	MU.cyl(pivot, 0.004, 0.028, Vector3(0, 0, 0.012), MU.mat(Color(0.8, 0.8, 0.82), 0.25, 0.9), Vector3(90, 0, 0), 8)
	ctl.rot_axis = Vector3(-60, 0, 0)
	ctl.setup_part(pivot)
	ctl.pick_extent = Vector3(0.02, 0.026, 0.025)
	ctl.pick_offset = Vector3(0, 0, 0.012)
	if labels.size() == 2:
		MU.label(ctl, labels[1], Vector3(0, 0.036, 0.003), 0.00034, Color(0.92, 0.92, 0.9), Vector3.ZERO, 24)
		MU.label(ctl, labels[0], Vector3(0, -0.036, 0.003), 0.00034, Color(0.92, 0.92, 0.9), Vector3.ZERO, 24)
	return ctl


## Push button; optionally illuminated (lamp id = button id).
func button(id: String, title: String, parent: Node3D, pos: Vector3, rot: Vector3, col: Color, help := "",
		radius := 0.014, latching := false, lit := false, legend := "") -> CabControl:
	var ctl := _host(parent, pos, rot)
	_register(ctl, id, title, help)
	ctl.kind = CabControl.Kind.BUTTON
	ctl.latching = latching
	MU.cyl(ctl, radius * 1.35, 0.006, Vector3(0, 0, 0.003), MU.mat(Color(0.2, 0.2, 0.2), 0.4, 0.7), Vector3(90, 0, 0), 16)
	var cap := Node3D.new()
	ctl.add_child(cap)
	var m: StandardMaterial3D
	if lit:
		m = MU.lamp(col, 0.0)
		m.albedo_color = col.darkened(0.45)
		lamps[id] = m
		lamp_colors[id] = col
	else:
		m = MU.mat(col, 0.45)
	MU.cyl(cap, radius, 0.014, Vector3(0, 0, 0.012), m, Vector3(90, 0, 0), 16)
	ctl.move_vec = Vector3(0, 0, -0.005)
	ctl.setup_part(cap)
	ctl.pick_extent = Vector3(radius * 1.3, radius * 1.3, 0.02)
	ctl.pick_offset = Vector3(0, 0, 0.012)
	if legend != "":
		MU.label(ctl, legend, Vector3(0, -radius * 2.2, 0.003), 0.00034, Color(0.92, 0.92, 0.9), Vector3.ZERO, 24)
	return ctl


## Mushroom emergency button (latching).
func mushroom(id: String, title: String, parent: Node3D, pos: Vector3, rot: Vector3, help := "") -> CabControl:
	var ctl := _host(parent, pos, rot)
	_register(ctl, id, title, help)
	ctl.kind = CabControl.Kind.BUTTON
	ctl.latching = true
	MU.cyl(ctl, 0.034, 0.012, Vector3(0, 0, 0.006), MU.mat(Color(0.95, 0.8, 0.05), 0.5), Vector3(90, 0, 0), 20)
	var cap := Node3D.new()
	ctl.add_child(cap)
	MU.cyl(cap, 0.009, 0.03, Vector3(0, 0, 0.02), MU.mat(Color(0.3, 0.3, 0.3), 0.5), Vector3(90, 0, 0), 10)
	MU.cyl(cap, 0.026, 0.016, Vector3(0, 0, 0.04), MU.mat(Color(0.8, 0.05, 0.04), 0.4), Vector3(90, 0, 0), 20)
	ctl.move_vec = Vector3(0, 0, -0.012)
	ctl.setup_part(cap)
	ctl.pick_extent = Vector3(0.03, 0.03, 0.03)
	ctl.pick_offset = Vector3(0, 0, 0.03)
	return ctl


## Hand wheel (screw reverser, handbrake, valve wheel). Faces +Z, turns about Z.
func wheel(id: String, title: String, parent: Node3D, pos: Vector3, rot: Vector3, r: float, mn: float, mx: float,
		value: float, turns_total: float, mat: Material, help := "", spokes := 4, handle := true) -> CabControl:
	var ctl := _host(parent, pos, rot)
	_register(ctl, id, title, help)
	ctl.kind = CabControl.Kind.WHEEL
	ctl.min_v = mn
	ctl.max_v = mx
	ctl.value = value
	ctl.scroll_step = (mx - mn) / maxf(turns_total * 8.0, 1.0)
	ctl.key_step = ctl.scroll_step * 0.5
	ctl.drag_scale = (mx - mn) / maxf(turns_total * 220.0, 1.0)
	var pivot := Node3D.new()
	ctl.add_child(pivot)
	MU.torus(pivot, r * 0.85, r, Vector3.ZERO, mat, Vector3(90, 0, 0))
	for k in range(spokes):
		MU.box(pivot, Vector3(0.012, r * 1.8, 0.012), Vector3.ZERO, mat, Vector3(0, 0, 180.0 * k / spokes))
	MU.cyl(pivot, r * 0.18, 0.04, Vector3(0, 0, 0.0), mat, Vector3(90, 0, 0), 10)
	if handle:
		MU.cyl(pivot, 0.011, 0.07, Vector3(r * 0.92, 0, 0.035), MU.mat(Color(0.1, 0.08, 0.06), 0.5), Vector3(90, 0, 0), 8)
	ctl.rot_axis = Vector3(0, 0, -360.0 * turns_total)
	ctl.setup_part(pivot)
	ctl.pick_extent = Vector3(r * 1.05, r * 1.05, 0.04)
	return ctl


## Hinged cabinet door: click to open or close. The panel lies in the host's
## XY plane facing +Z with its hinge on the host's Y axis; it extends along +X
## (hinge on the left) or -X (hinge on the right) and swings out towards +Z.
## Value 1 = open. Controls behind it can only be reached once it is open.
func door(id: String, title: String, parent: Node3D, pos: Vector3, rot: Vector3, size: Vector2, mat: Material,
		help := "", hinge_left := true, open_deg := 105.0, legend := "") -> CabControl:
	var ctl := _host(parent, pos, rot)
	_register(ctl, id, title, help)
	ctl.kind = CabControl.Kind.TOGGLE
	ctl.labels = ["CLOSED", "OPEN"]
	ctl.set_meta("door", true)
	var pivot := Node3D.new()
	ctl.add_child(pivot)
	var sx := 1.0 if hinge_left else -1.0
	MU.box(pivot, Vector3(size.x, size.y, 0.025), Vector3(sx * size.x * 0.5, 0, 0.0125), mat)
	# handle near the free edge, hinges on the other
	var steel := MU.mat(Color(0.7, 0.7, 0.72), 0.3, 0.8, "door_handle")
	MU.box(pivot, Vector3(0.025, 0.12, 0.03), Vector3(sx * (size.x - 0.06), 0, 0.035), steel)
	for hy in [-size.y * 0.35, size.y * 0.35]:
		MU.cyl(pivot, 0.012, 0.08, Vector3(0, hy, 0.01), steel, Vector3.ZERO, 8)
	if legend != "":
		MU.label(pivot, legend, Vector3(sx * size.x * 0.5, size.y * 0.32, 0.027), minf(0.0012, size.x * 0.0014), Color(0.95, 0.95, 0.9), Vector3.ZERO, 32)
	ctl.rot_axis = Vector3(0, -open_deg * sx, 0)
	ctl.setup_part(pivot)
	ctl.pick_extent = Vector3(size.x * 0.5, size.y * 0.5, 0.025)
	ctl.pick_offset = Vector3(sx * size.x * 0.5, 0, 0.02)
	ctl.set_meta("pick_node", pivot)
	return ctl


## Angle cock / isolating cock: handle along the pipe = open, across = closed.
## Faces +Z; the pipe runs along local Y.
func cock(id: String, title: String, parent: Node3D, pos: Vector3, rot: Vector3, open: bool, help := "") -> CabControl:
	var ctl := _host(parent, pos, rot)
	_register(ctl, id, title, help)
	ctl.kind = CabControl.Kind.TOGGLE
	ctl.labels = ["CLOSED", "OPEN"]
	var body := MU.mat(Color(0.25, 0.25, 0.26), 0.5, 0.6, "cock_body")
	MU.cyl(ctl, 0.035, 0.12, Vector3.ZERO, body, Vector3.ZERO, 10)
	var pivot := Node3D.new()
	ctl.add_child(pivot)
	pivot.position = Vector3(0, 0, 0.04)
	MU.box(pivot, Vector3(0.025, 0.16, 0.02), Vector3(0, 0.07, 0.0), MU.mat(Color(0.8, 0.1, 0.06), 0.5, 0.0, "cock_handle"))
	ctl.rot_axis = Vector3(0, 0, 90)
	ctl.value = 1.0 if open else 0.0
	ctl.setup_part(pivot)
	# value 0 rotates the handle across the pipe
	ctl.part_base_rot = Vector3(0, 0, -90)
	ctl._apply()
	ctl.pick_extent = Vector3(0.06, 0.1, 0.05)
	ctl.pick_offset = Vector3(0, 0.05, 0.04)
	ctl.set_meta("pick_node", ctl)
	return ctl


## Battery isolating knife switch: the blade swings down out of its jaws.
func knife(id: String, title: String, parent: Node3D, pos: Vector3, rot: Vector3, help := "") -> CabControl:
	var ctl := _host(parent, pos, rot)
	_register(ctl, id, title, help)
	ctl.kind = CabControl.Kind.TOGGLE
	ctl.labels = ["OFF", "ON"]
	var base := MU.mat(Color(0.12, 0.12, 0.12), 0.7, 0.0, "knife_base")
	var copper := MU.mat(Color(0.72, 0.45, 0.25), 0.35, 0.9, "knife_copper")
	MU.box(ctl, Vector3(0.22, 0.34, 0.03), Vector3(0, 0, 0.015), base)
	for x in [-0.05, 0.05]:
		MU.box(ctl, Vector3(0.02, 0.05, 0.05), Vector3(x, 0.12, 0.05), copper)
		MU.box(ctl, Vector3(0.02, 0.04, 0.04), Vector3(x, -0.13, 0.045), copper)
	var pivot := Node3D.new()
	ctl.add_child(pivot)
	pivot.position = Vector3(0, -0.13, 0.06)
	for x in [-0.05, 0.05]:
		MU.box(pivot, Vector3(0.012, 0.27, 0.035), Vector3(x, 0.13, 0), copper)
	MU.box(pivot, Vector3(0.16, 0.03, 0.03), Vector3(0, 0.22, 0.0), base)
	MU.cyl(pivot, 0.018, 0.14, Vector3(0, 0.22, 0.06), MU.mat(Color(0.75, 0.1, 0.05), 0.5, 0.0, "knife_handle"), Vector3(90, 0, 0), 10)
	# off: blade swung out and down
	ctl.rot_axis = Vector3(-100, 0, 0)
	ctl.part_base_rot = Vector3(100, 0, 0)
	ctl.setup_part(pivot)
	ctl.part_base_rot = Vector3(100, 0, 0)
	ctl._apply()
	ctl.pick_extent = Vector3(0.12, 0.18, 0.08)
	ctl.pick_offset = Vector3(0, 0, 0.06)
	return ctl


func gauge(id: String, parent: Node3D, pos: Vector3, rot: Vector3, r: float, mn: float, mx: float, major: float, minor: float,
		title: String, unit: String, needle_cols: Array = [Color(0.05, 0.05, 0.05)], face := Color(0.93, 0.91, 0.84),
		num_div := 1.0, red_from := INF, sweep := 270.0, bezel := Color(0.15, 0.15, 0.15)) -> CabGauge:
	var g := CabGauge.new()
	(parent if parent else self).add_child(g)
	g.position = pos
	g.rotation_degrees = rot
	g.build(r, mn, mx, major, minor, title, unit, needle_cols, face, num_div, bezel, red_from, sweep)
	g.name = id
	gauges[id] = g
	return g


func lamp(id: String, parent: Node3D, pos: Vector3, rot: Vector3, col: Color, legend := "", size := 0.016, square := false) -> void:
	var host := Node3D.new()
	(parent if parent else self).add_child(host)
	host.position = pos
	host.rotation_degrees = rot
	var m := MU.lamp(col, 0.0)
	m.albedo_color = col.darkened(0.7)
	if square:
		MU.box(host, Vector3(size * 2.2, size * 1.4, 0.006), Vector3(0, 0, 0.003), m)
	else:
		MU.cyl(host, size, 0.008, Vector3(0, 0, 0.004), m, Vector3(90, 0, 0), 14)
	lamps[id] = m
	lamp_colors[id] = col
	if legend != "":
		MU.label(host, legend, Vector3(0, -size * 1.9 if not square else 0.0, 0.008), 0.0003, Color(0.95, 0.95, 0.95) if not square else Color(0.05, 0.05, 0.05), Vector3.ZERO, 24)


func set_lamp(id: String, on: bool, flash_period := 0.0) -> void:
	if not lamps.has(id):
		return
	if flash_period > 0.0 and on:
		flashing[id] = flash_period
		return
	flashing.erase(id)
	(lamps[id] as StandardMaterial3D).emission_energy_multiplier = 2.2 if on else 0.0


func text(t: String, parent: Node3D, pos: Vector3, rot: Vector3 = Vector3.ZERO, px := 0.00028, col := Color(0.92, 0.92, 0.9)) -> Label3D:
	return MU.label(parent if parent else self, t, pos, px, col, rot, 24)


func panel(parent: Node3D, size: Vector3, pos: Vector3, rot: Vector3, mat: Material) -> MeshInstance3D:
	return MU.box(parent if parent else self, size, pos, mat, rot)


func frame(parent: Node3D, pos: Vector3, rot: Vector3) -> Node3D:
	var n := Node3D.new()
	(parent if parent else self).add_child(n)
	n.position = pos
	n.rotation_degrees = rot
	return n


func _process(delta: float) -> void:
	_t += delta
	for id in flashing:
		var per: float = flashing[id]
		var on := fmod(_t, per) < per * 0.5
		(lamps[id] as StandardMaterial3D).emission_energy_multiplier = 2.2 if on else 0.0
