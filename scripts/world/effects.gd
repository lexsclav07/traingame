class_name Effects
extends Node3D
## Steam and smoke for the A4: chimney exhaust (puffs on each beat, black when
## the firing is poor), safety valves, cylinder cocks and the whistle.

var chimney: GPUParticles3D
var safety: GPUParticles3D
var cocks: Array[GPUParticles3D] = []
var whistle: GPUParticles3D
var overflow_water: Array[GPUParticles3D] = []
var overflow_steam: Array[GPUParticles3D] = []
var scoop_spray: GPUParticles3D
var tender: Vehicle
var _puff := 0.0
var _ramp_smoke: Gradient


static func _soft_tex() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 64
	gt.height = 64
	return gt


func _emitter(parent: Node3D, amount: int, life: float, size: float, grow: float, col: Color) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.emitting = true
	p.amount_ratio = 0.0
	p.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	p.visibility_aabb = AABB(Vector3(-60, -20, -60), Vector3(120, 80, 120))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var qm := QuadMesh.new()
	qm.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	var puff := TX.t("smoke_puff")
	m.albedo_texture = puff if puff else _soft_tex()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	# lit by the sun and sky (dark at night, glowing edges against the sun)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.backlight_enabled = true
	m.backlight = Color(0.55, 0.55, 0.55)
	m.roughness = 1.0
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	if RenderingServer.get_current_rendering_method() != "gl_compatibility":
		m.proximity_fade_enabled = true
		m.proximity_fade_distance = 0.8
	qm.material = m
	p.draw_pass_1 = qm
	var pm := ParticleProcessMaterial.new()
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.angular_velocity_min = -25.0
	pm.angular_velocity_max = 25.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.2
	pm.turbulence_noise_scale = 6.0
	pm.turbulence_influence_min = 0.05
	pm.turbulence_influence_max = 0.15
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.35))
	curve.add_point(Vector2(1, 1.0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	pm.scale_min = 1.0
	pm.scale_max = grow
	var ramp := Gradient.new()
	ramp.set_color(0, Color(col.r, col.g, col.b, 0.75))
	ramp.set_color(1, Color(col.r, col.g, col.b, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = ramp
	pm.color_ramp = gt
	pm.gravity = Vector3(0, 0.6, 0)
	pm.damping_min = 1.5
	pm.damping_max = 3.0
	p.process_material = pm
	parent.add_child(p)
	return p


## Falling water (injector overflow, scoop spray): small lit droplets with gravity.
func _water(parent: Node3D, amount: int, life: float, size: float, dir: Vector3, spread: float, vmin: float, vmax: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.amount_ratio = 0.0
	p.visibility_aabb = AABB(Vector3(-20, -10, -20), Vector3(40, 30, 40))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var qm := QuadMesh.new()
	qm.size = Vector2(size, size * 1.8)
	var m := StandardMaterial3D.new()
	m.albedo_texture = _soft_tex()
	m.albedo_color = Color(0.82, 0.88, 0.92, 0.7)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.1
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	qm.material = m
	p.draw_pass_1 = qm
	var pm := ParticleProcessMaterial.new()
	pm.direction = dir
	pm.spread = spread
	pm.initial_velocity_min = vmin
	pm.initial_velocity_max = vmax
	pm.gravity = Vector3(0, -9.8, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.6
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.85, 0.9, 0.95, 0.75))
	ramp.set_color(1, Color(0.85, 0.9, 0.95, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = ramp
	pm.color_ramp = gt
	p.process_material = pm
	parent.add_child(p)
	return p


func setup(loco: Vehicle, tender_v: Vehicle = null) -> void:
	tender = tender_v
	for i in range(loco.overflow_points.size()):
		var op: Node3D = loco.overflow_points[i]
		overflow_water.append(_water(op, 120, 0.9, 0.05, Vector3(0, -1, 0), 8.0, 0.3, 1.2))
		var st := _emitter(op, 60, 1.0, 0.35, 3.5, Color(1, 1, 1))
		_cfg(st, Vector3(signf(op.position.x), -0.4, 0), 25.0, 2.0, 4.0)
		overflow_steam.append(st)
	if tender and tender.scoop:
		# water forced out round the scoop over the troughs
		scoop_spray = _water(tender.scoop, 900, 1.2, 0.12, Vector3(0, 1, 0), 55.0, 3.0, 7.0)
	chimney = _emitter(loco.smoke_point, 260, 3.2, 1.3, 4.5, Color(0.92, 0.92, 0.92))
	_cfg(chimney, Vector3(0, 1, 0), 12.0, 5.0, 9.0)
	var cpm := chimney.process_material as ParticleProcessMaterial
	cpm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	cpm.emission_sphere_radius = 0.2
	_ramp_smoke = (cpm.color_ramp as GradientTexture1D).gradient
	safety = _emitter(loco.safety_valve_point, 120, 1.6, 0.6, 5.0, Color(1, 1, 1))
	_cfg(safety, Vector3(0, 1, 0), 8.0, 14.0, 18.0)
	for cp in loco.cocks_points:
		var c := _emitter(cp, 80, 0.9, 0.5, 4.0, Color(1, 1, 1))
		var side := signf(cp.position.x)
		_cfg(c, Vector3(side, -0.3, -0.4), 15.0, 7.0, 10.0)
		cocks.append(c)
	whistle = _emitter(loco.whistle_point, 60, 1.0, 0.4, 3.5, Color(1, 1, 1))
	_cfg(whistle, Vector3(0, 1, 0), 20.0, 5.0, 7.0)


func _cfg(p: GPUParticles3D, dir: Vector3, spread: float, vmin: float, vmax: float) -> void:
	var pm := p.process_material as ParticleProcessMaterial
	pm.direction = dir
	pm.spread = spread
	pm.initial_velocity_min = vmin
	pm.initial_velocity_max = vmax


func update(sim: A4Sim, delta: float) -> void:
	if chimney == null:
		return
	var ex: float = sim.cyl_flow
	var blower: float = sim.sound.get("blower", 0.0)
	if sim.beat:
		_puff = 1.0
	_puff = maxf(0.0, _puff - delta * 6.0)
	var base := clampf(blower * 0.35 + 0.04 * float(sim.lit), 0.0, 0.5)
	chimney.amount_ratio = clampf(base + ex * 0.25 + _puff * clampf(ex, 0.0, 1.0) * 0.6, 0.0, 1.0)
	var cpm := chimney.process_material as ParticleProcessMaterial
	cpm.initial_velocity_min = 3.0 + ex * 4.0 + _puff * 5.0
	cpm.initial_velocity_max = 6.0 + ex * 6.0 + _puff * 7.0
	var grey := clampf(sim.smoke_black, 0.0, 1.0)
	var c := Color(0.93, 0.93, 0.93).lerp(Color(0.12, 0.11, 0.1), grey * 0.85)
	if not sim.lit:
		chimney.amount_ratio = 0.0
	_ramp_smoke.set_color(0, Color(c.r, c.g, c.b, 0.55 + grey * 0.3))
	_ramp_smoke.set_color(1, Color(c.r, c.g, c.b, 0.0))
	safety.amount_ratio = clampf(sim.safety_flow / 2.0, 0.0, 1.0)
	var ck: float = sim.sound.get("cocks", 0.0)
	for e in cocks:
		e.amount_ratio = clampf(ck * (0.4 + _puff), 0.0, 1.0)
	whistle.amount_ratio = clampf(sim.whistle_on, 0.0, 1.0) if sim.p_gauge > 20.0 else 0.0
	for i in range(overflow_water.size()):
		var w: float = sim.overflow[i] if i < sim.overflow.size() else 0.0
		overflow_water[i].amount_ratio = clampf(w * 0.9, 0.0, 1.0)
		overflow_steam[i].amount_ratio = 0.8 if (i < sim.overflow_steam.size() and sim.overflow_steam[i]) else 0.0
	if tender and tender.scoop:
		var down: float = sim.cab.val("scoop")
		tender.scoop.position.y = lerpf(0.62, 0.2, down)
		if scoop_spray:
			scoop_spray.amount_ratio = clampf(sim.scoop_pickup / 300.0, 0.0, 1.0)
