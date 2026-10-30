class_name EnvironmentBuilder
extends RefCounted
## Sky (custom shader with clouds), sun/moon, fog, tonemapping, post effects
## and rain. Quality: 0 Low, 1 Medium, 2 High, 3 Ultra.

var sun: DirectionalLight3D
var env: Environment
var we: WorldEnvironment
var sky_mat: ShaderMaterial
var night := false
var rain: GPUParticles3D
var quality := 2


func build(parent: Node3D, route: Dictionary, time_of_day: String, weather: String, q: int) -> void:
	quality = q
	var forward_plus := RenderingServer.get_current_rendering_method() == "forward_plus"
	we = WorldEnvironment.new()
	we.name = "WorldEnvironment"
	env = Environment.new()
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://assets/shaders/sky.gdshader")
	sky_mat.set_shader_parameter("cloud_tex", TX.t("clouds"))
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128 if q < 3 else Sky.RADIANCE_SIZE_256
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_sky_affect = 0.35
	env.fog_aerial_perspective = 0.55
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.12
	env.glow_enabled = q > 0
	env.glow_intensity = 0.5
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	if forward_plus:
		env.ssao_enabled = q >= 1
		env.ssao_radius = 1.4
		env.ssao_intensity = 1.8
		env.ssao_power = 1.4
		env.ssao_light_affect = 0.15
		env.ssil_enabled = q >= 2
		env.ssil_radius = 4.0
		env.ssil_intensity = 0.8
		env.ssr_enabled = q >= 2
		env.ssr_max_steps = 48
		env.ssr_fade_out = 1.6
		env.sdfgi_enabled = q >= 3
		env.sdfgi_use_occlusion = true
		env.sdfgi_cascades = 4
		env.sdfgi_min_cell_size = 0.4
		env.volumetric_fog_enabled = q >= 2
		env.volumetric_fog_density = 0.0
		env.volumetric_fog_length = 160.0
		env.volumetric_fog_gi_inject = 0.6
		env.volumetric_fog_ambient_inject = 0.4
		env.volumetric_fog_sky_affect = 0.0
	we.environment = env
	# eye adaptation: stepping into a dim cab from bright daylight (Forward+ only)
	if forward_plus and q >= 2:
		var ca := CameraAttributesPractical.new()
		ca.auto_exposure_enabled = true
		ca.auto_exposure_scale = 0.35
		ca.auto_exposure_speed = 0.6
		ca.auto_exposure_min_sensitivity = 60.0
		ca.auto_exposure_max_sensitivity = 400.0
		we.camera_attributes = ca
	parent.add_child(we)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = [90.0, 200.0, 320.0, 450.0][q]
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_blend_splits = q >= 2
	sun.shadow_blur = 1.2
	sun.light_angular_distance = 0.5 if q >= 2 else 0.0
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	parent.add_child(sun)
	var rot: Vector3 = route.get("sun_rot", Vector3(-45, 30, 0))
	var nsw: bool = route["theme"] == "nsw"
	var rainy := weather == "rain"
	var p := {}
	match time_of_day:
		"dusk":
			sun.rotation_degrees = Vector3(-6, rot.y + 40.0, 0)
			sun.light_color = Color(1.0, 0.58, 0.32)
			sun.light_energy = 1.1
			p = {"zenith": Color(0.16, 0.24, 0.45), "horizon": Color(0.98, 0.62, 0.42), "ground": Color(0.24, 0.17, 0.14),
				"glow": Color(1.0, 0.55, 0.3), "lit": Color(1.0, 0.72, 0.55), "shadow": Color(0.38, 0.3, 0.38),
				"cover": 0.42, "energy": 1.0, "amb": 0.55, "fog": Color(0.78, 0.55, 0.45), "fog_d": 0.00032}
		"night":
			night = true
			sun.rotation_degrees = Vector3(-38, rot.y - 60.0, 0)
			sun.light_color = Color(0.6, 0.7, 1.0)
			sun.light_energy = 0.12
			p = {"zenith": Color(0.006, 0.01, 0.03), "horizon": Color(0.03, 0.045, 0.08), "ground": Color(0.01, 0.01, 0.012),
				"glow": Color(0.3, 0.35, 0.5), "lit": Color(0.25, 0.28, 0.35), "shadow": Color(0.04, 0.05, 0.07),
				"cover": 0.35, "energy": 1.0, "amb": 0.35, "fog": Color(0.03, 0.04, 0.06), "fog_d": 0.0004}
			sky_mat.set_shader_parameter("night", 1.0)
			sky_mat.set_shader_parameter("sun_size", 0.99985)
			env.tonemap_exposure = 1.4
		_:
			sun.rotation_degrees = rot
			sun.light_energy = 1.35 if nsw else 1.2
			sun.light_color = Color(1.0, 0.96, 0.88)
			if nsw:
				p = {"zenith": Color(0.13, 0.33, 0.7), "horizon": Color(0.62, 0.74, 0.86), "ground": Color(0.4, 0.37, 0.3),
					"glow": Color(1.0, 0.88, 0.7), "lit": Color(1.0, 0.99, 0.96), "shadow": Color(0.58, 0.63, 0.72),
					"cover": 0.32, "energy": 1.0, "amb": 0.75, "fog": Color(0.68, 0.76, 0.86), "fog_d": 0.00016}
			else:
				p = {"zenith": Color(0.22, 0.38, 0.62), "horizon": Color(0.7, 0.77, 0.84), "ground": Color(0.36, 0.38, 0.32),
					"glow": Color(1.0, 0.9, 0.75), "lit": Color(0.98, 0.98, 0.97), "shadow": Color(0.52, 0.56, 0.64),
					"cover": 0.55, "energy": 1.0, "amb": 0.8, "fog": Color(0.7, 0.75, 0.82), "fog_d": 0.00026}
	if rainy:
		sun.light_energy *= 0.3
		p["zenith"] = (p["zenith"] as Color).lerp(Color(0.32, 0.34, 0.37), 0.85)
		p["horizon"] = (p["horizon"] as Color).lerp(Color(0.48, 0.5, 0.53), 0.85)
		p["lit"] = Color(0.6, 0.62, 0.65) * (0.15 if night else 1.0)
		p["shadow"] = Color(0.32, 0.34, 0.37) * (0.15 if night else 1.0)
		p["cover"] = 0.95
		p["fog"] = (p["fog"] as Color).lerp(Color(0.45, 0.47, 0.5), 0.75)
		p["fog_d"] = 0.0011
		p["amb"] *= 0.9
		sun.shadow_enabled = false
	sky_mat.set_shader_parameter("zenith_color", p["zenith"])
	sky_mat.set_shader_parameter("horizon_color", p["horizon"])
	sky_mat.set_shader_parameter("ground_color", p["ground"])
	sky_mat.set_shader_parameter("sun_glow_color", p["glow"])
	sky_mat.set_shader_parameter("cloud_lit", p["lit"])
	sky_mat.set_shader_parameter("cloud_shadow", p["shadow"])
	sky_mat.set_shader_parameter("cloud_cover", p["cover"])
	sky_mat.set_shader_parameter("sky_energy", p["energy"])
	env.ambient_light_energy = p["amb"]
	# part of the ambient is warm light bounced off the ground, not just blue sky
	env.ambient_light_sky_contribution = 0.7
	env.ambient_light_color = (p["ground"] as Color).lerp(Color(0.6, 0.58, 0.52), 0.5) * (0.15 if night else 1.0)
	env.fog_light_color = p["fog"]
	env.fog_density = p["fog_d"]
	env.fog_sun_scatter = 0.25 if not night else 0.0
	if forward_plus and env.volumetric_fog_enabled:
		# a little ground haze for depth and light shafts; more in rain
		env.volumetric_fog_density = 0.0035 if rainy else (0.0012 if time_of_day == "dusk" else 0.0006)
		env.volumetric_fog_albedo = p["fog"]


## Rain follows the camera so it is always around the player.
func attach_rain(cam: Node3D) -> void:
	rain = GPUParticles3D.new()
	rain.name = "Rain"
	rain.amount = [2500, 5000, 9000, 14000][quality]
	rain.lifetime = 1.0
	rain.local_coords = false
	rain.visibility_aabb = AABB(Vector3(-40, -30, -40), Vector3(80, 50, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(28, 1, 28)
	pm.direction = Vector3(0.08, -1, 0.03)
	pm.spread = 2.0
	pm.gravity = Vector3(0, -9.8, 0)
	pm.initial_velocity_min = 13.0
	pm.initial_velocity_max = 16.0
	rain.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(0.01, 0.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.78, 0.82, 0.88, 0.28)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.billboard_keep_scale = true
	qm.material = mat
	rain.draw_pass_1 = qm
	cam.add_child(rain)
	rain.position = Vector3(0, 14, 0)
