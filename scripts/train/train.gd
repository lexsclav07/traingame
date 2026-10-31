class_name Train
extends Node3D
## A consist on the track: longitudinal dynamics and placing every vehicle on
## the curves. Traction and brake forces come from the train's systems sim.

signal derailed_signal(reason: String)

var track: Track
var vehicles: Array[Vehicle] = []
var sim: TrainSim
var front_s := 0.0          # distance of the leading coupler face
var speed := 0.0            # m/s along the track (+ = forward)
var accel := 0.0
var odometer := 0.0
var rot_factor := 1.07      # rotating-mass allowance
var derailed := false
var derail_reason := ""
var derail_lat_limit := 2.4 # m/s^2 uncompensated lateral acceleration
var lat_accel := 0.0
var driver_slip_speed := 0.0  # steam: extra driving-wheel surface speed (m/s) when slipping
var crank_angle := 0.0


func setup(t: Track, start_s: float) -> void:
	track = t
	front_s = start_s


func add_vehicle(v: Vehicle) -> void:
	vehicles.append(v)
	add_child(v)


func total_length() -> float:
	var l := 0.0
	for v in vehicles:
		l += v.vlength
	return l


func total_mass() -> float:
	var m := 0.0
	for v in vehicles:
		m += v.total_mass()
	return m


func rear_s() -> float:
	return front_s - total_length()


func vehicle_front_s(i: int) -> float:
	var s := front_s
	for k in range(i):
		s -= vehicles[k].vlength
	return s


## Resistance to motion (N, >= 0) at speed v (m/s): Davis-style per vehicle.
func resistance(v_abs: float) -> float:
	var vk := v_abs * 3.6
	var r := 0.0
	var aero := 0.0
	var first := true
	for veh in vehicles:
		var mt := veh.total_mass() / 1000.0
		match veh.kind:
			"a4", "tender":
				r += mt * (35.0 + 0.15 * vk)
				if veh.kind == "a4":
					aero += 4.0
			"coach":
				r += mt * (10.0 + 0.045 * vk + 0.0012 * vk * vk)
			"c44":
				# heavy diesel: bearings, traction motor gears, flange friction
				r += mt * (6.5 + 0.035 * vk)
				aero += 6.5 if first else 1.6
			"coal":
				# loaded hoppers on roller bearings; empties ride on fewer tonnes but
				# have the same open-top drag
				r += mt * (5.5 + 0.03 * vk) + 120.0
				aero += 1.3
			_:
				r += mt * (8.0 + 0.035 * vk)
				aero += 3.5 if first else 0.9
		first = false
	# breakaway: plain bearings (1930s) stick far more than roller bearings
	var stick := 0.0
	if vk < 5.0:
		for veh in vehicles:
			var extra := 22.0 if veh.kind in ["a4", "tender", "coach"] else 6.0
			stick += veh.total_mass() / 1000.0 * extra * (1.0 - vk / 5.0)
	return r + stick + 0.5 * 1.225 * aero * v_abs * v_abs


func gravity_force() -> float:
	var f := 0.0
	var s := front_s
	for v in vehicles:
		f += v.total_mass() * 9.81 * track.grade_at(s - v.vlength * 0.5)
		s -= v.vlength
	return f


func curve_force() -> float:
	var f := 0.0
	var s := front_s
	for v in vehicles:
		var k := absf(track.curv_at(s - v.vlength * 0.5))
		if k > 1e-5:
			f += v.total_mass() * 9.81 * 0.65 / maxf(1.0 / k - 55.0, 60.0)   # Roeckl
		s -= v.vlength
	return f


func physics_step(dt: float) -> void:
	if derailed:
		speed = move_toward(speed, 0.0, 6.0 * dt)
		front_s += speed * dt
		return
	var m_eff := total_mass() * rot_factor
	var f_drive := sim.traction_force if sim else 0.0
	var f_brake := sim.brake_force if sim else 0.0
	var f_ext := f_drive - gravity_force()
	var f_res := resistance(absf(speed)) + curve_force()
	var hold := f_brake + f_res
	if absf(speed) < 0.005:
		if absf(f_ext) <= hold:
			speed = 0.0
			accel = 0.0
		else:
			accel = (f_ext - signf(f_ext) * hold) / m_eff
			speed += accel * dt
	else:
		accel = (f_ext - signf(speed) * hold) / m_eff
		var ns := speed + accel * dt
		if signf(ns) != signf(speed):
			ns = 0.0       # brakes / resistance can stop the train but never reverse it
		speed = ns
	front_s += speed * dt
	odometer += absf(speed) * dt
	if front_s > track.length * 4.0 or front_s < -track.length * 4.0:
		front_s = track.wrap_s(front_s)
	_check_curving()


func _check_curving() -> void:
	# worst vehicle: uncompensated lateral acceleration = v^2 k - g * cant
	var worst := 0.0
	var s := front_s
	for v in vehicles:
		var mid := s - v.vlength * 0.5
		var a := speed * speed * track.curv_at(mid) - 9.81 * sin(track.cant_at(mid))
		if absf(a) > absf(worst):
			worst = a
		s -= v.vlength
	lat_accel = worst
	if absf(worst) > derail_lat_limit:
		derailed = true
		var k := absf(track.curv_at(front_s))
		derail_reason = "Derailed on a %d m radius curve at %d km/h (line speed %d km/h)." % [int(1.0 / maxf(k, 1e-5)), int(absf(speed) * 3.6), int(track.limit_at(front_s))]
		derailed_signal.emit(derail_reason)


var _last_front := 0.0


## Place every vehicle on the track and spin wheels (called every frame).
func update_visuals() -> void:
	var moved := front_s - _last_front
	if absf(moved) > 1000.0:
		moved = 0.0
	_last_front = front_s
	var s := front_s
	for v in vehicles:
		var sa := s - v.pivot_front
		var sb := s - v.pivot_rear
		var pa := track.pos_at(sa)
		var pb := track.pos_at(sb)
		var fwd := (pa - pb).normalized()
		var right := fwd.cross(Vector3.UP).normalized()
		var up := right.cross(fwd).normalized()
		var c := (track.cant_at(sa) + track.cant_at(sb)) * 0.5
		var rb := Basis(fwd, -c)
		v.global_transform = Transform3D(Basis(rb * right, rb * up, -fwd), (pa + pb) * 0.5)
		v.roll(moved, driver_slip_speed * get_process_delta_time() if not v.driving_wheels.is_empty() else 0.0)
		if not v.rods.is_empty() and not v.driving_wheels.is_empty():
			VehicleModels.update_motion(v, v.driving_wheels[0].rotation.x)
			crank_angle = v.driving_wheels[0].rotation.x
		s -= v.vlength
