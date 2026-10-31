class_name DieselEffects
extends Node3D
## Exhaust for the 92 class units: a faint haze at idle, a grey-brown plume
## under load, and black smoke while the turbocharger catches up with the fuel
## (notching up quickly, or the first seconds after an engine fires).

var stacks: Array[GPUParticles3D] = []
var ramps: Array[Gradient] = []


func setup(locos: Array) -> void:
	for v in locos:
		var ex: Node3D = (v as Vehicle).extra.get("exhaust")
		if ex == null:
			continue
		stacks.append(_emitter(ex))


func _emitter(parent: Node3D) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 140
	p.lifetime = 3.5
	p.local_coords = false
	p.amount_ratio = 0.0
	p.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	p.visibility_aabb = AABB(Vector3(-60, -20, -60), Vector3(120, 80, 120))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var qm := QuadMesh.new()
	qm.size = Vector2(0.8, 0.8)
	var m := StandardMaterial3D.new()
	var puff := TX.t("smoke_puff")
	m.albedo_texture = puff if puff else Effects._soft_tex()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.backlight_enabled = true
	m.backlight = Color(0.4, 0.4, 0.4)
	m.roughness = 1.0
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	if RenderingServer.get_current_rendering_method() != "gl_compatibility":
		m.proximity_fade_enabled = true
		m.proximity_fade_distance = 0.6
	qm.material = m
	p.draw_pass_1 = qm
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.2, 0.02, 0.1)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 10.0
	pm.initial_velocity_min = 3.0
	pm.initial_velocity_max = 5.0
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.angular_velocity_min = -30.0
	pm.angular_velocity_max = 30.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.4
	pm.turbulence_noise_scale = 5.0
	pm.turbulence_influence_min = 0.05
	pm.turbulence_influence_max = 0.18
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.3))
	curve.add_point(Vector2(1, 1.0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	pm.scale_min = 1.0
	pm.scale_max = 5.5
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.5, 0.5, 0.52, 0.3))
	ramp.set_color(1, Color(0.5, 0.5, 0.52, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = ramp
	pm.color_ramp = gt
	ramps.append(ramp)
	pm.gravity = Vector3(0, 0.4, 0)
	pm.damping_min = 1.2
	pm.damping_max = 2.5
	p.process_material = pm
	parent.add_child(p)
	return p


func update(sim: C92Sim, _delta: float) -> void:
	for u in range(stacks.size()):
		var p := stacks[u]
		var firing: bool = sim.eng[u] == "running" or (sim.eng[u] == "cranking" and sim.crank_t[u] > 3.0) or (sim.eng[u] == "stopping" and sim.rpm[u] > 150.0)
		var ld: float = sim.load[u]
		var blk: float = sim.black_smoke[u]
		p.amount_ratio = clampf(0.1 + ld * 0.55 + blk * 0.6, 0.0, 1.0) if firing else 0.0
		var pm := p.process_material as ParticleProcessMaterial
		var spd: float = sim.rpm[u] / 1050.0
		pm.initial_velocity_min = 2.0 + spd * 5.0 + ld * 4.0
		pm.initial_velocity_max = 3.5 + spd * 7.0 + ld * 5.0
		# idle: faint blue-grey haze; load: grey-brown; turbo lag: black
		var col := Color(0.55, 0.57, 0.6).lerp(Color(0.32, 0.3, 0.28), clampf(ld * 1.4, 0.0, 1.0)).lerp(Color(0.06, 0.06, 0.06), blk)
		var alpha := clampf(0.12 + ld * 0.25 + blk * 0.6, 0.0, 0.85)
		ramps[u].set_color(0, Color(col.r, col.g, col.b, alpha))
		ramps[u].set_color(1, Color(col.r, col.g, col.b, 0.0))
