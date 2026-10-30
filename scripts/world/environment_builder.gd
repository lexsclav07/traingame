class_name EnvironmentBuilder
extends RefCounted
## Sky, sun, fog, time of day and rain.

var sun: DirectionalLight3D
var env: Environment
var night := false
var rain: CPUParticles3D


func build(parent: Node3D, route: Dictionary, time_of_day: String, weather: String, quality: int) -> void:
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	env = Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.66, 0.72)
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	env.fog_enabled = true
	env.fog_sky_affect = 0.6
	env.glow_enabled = quality > 0
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.ssao_enabled = quality > 1
	we.environment = env
	parent.add_child(we)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = [80.0, 180.0, 300.0][quality]
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	parent.add_child(sun)
	var rot: Vector3 = route.get("sun_rot", Vector3(-45, 30, 0))
	var nsw: bool = route["theme"] == "nsw"
	var rainy := weather == "rain"

	match time_of_day:
		"dusk":
			sun.rotation_degrees = Vector3(-7, rot.y + 40.0, 0)
			sun.light_color = Color(1.0, 0.62, 0.38)
			sun.light_energy = 0.9
			sm.sky_top_color = Color(0.22, 0.3, 0.52)
			sm.sky_horizon_color = Color(0.95, 0.6, 0.4)
			sm.ground_horizon_color = Color(0.5, 0.36, 0.3)
			sm.ground_bottom_color = Color(0.12, 0.1, 0.1)
			env.ambient_light_energy = 0.3
			env.ambient_light_color = Color(0.7, 0.55, 0.5)
			env.fog_light_color = Color(0.75, 0.5, 0.42)
			env.fog_density = 0.0004
		"night":
			night = true
			sun.rotation_degrees = Vector3(-35, rot.y - 60.0, 0)
			sun.light_color = Color(0.55, 0.65, 0.95)
			sun.light_energy = 0.07
			sm.sky_top_color = Color(0.01, 0.015, 0.04)
			sm.sky_horizon_color = Color(0.03, 0.04, 0.08)
			sm.ground_horizon_color = Color(0.02, 0.02, 0.03)
			sm.ground_bottom_color = Color(0.0, 0.0, 0.0)
			sm.sun_angle_max = 2.0
			env.ambient_light_energy = 0.08
			env.ambient_light_color = Color(0.3, 0.35, 0.5)
			env.fog_light_color = Color(0.02, 0.025, 0.04)
			env.fog_density = 0.0005
			env.tonemap_exposure = 1.25
		_:
			sun.rotation_degrees = rot
			sun.light_energy = 1.25 if nsw else 1.0
			sun.light_color = Color(1.0, 0.97, 0.9)
			sm.sky_top_color = Color(0.22, 0.45, 0.8) if nsw else Color(0.35, 0.5, 0.72)
			sm.sky_horizon_color = Color(0.7, 0.78, 0.86) if nsw else Color(0.75, 0.8, 0.84)
			sm.ground_horizon_color = Color(0.55, 0.55, 0.5)
			sm.ground_bottom_color = Color(0.25, 0.23, 0.2)
			env.ambient_light_energy = 0.45
			env.fog_light_color = Color(0.72, 0.78, 0.86)
			env.fog_density = 0.00022 if nsw else 0.00035
	if rainy:
		sun.light_energy *= 0.35
		env.ambient_light_energy *= 0.8
		sm.sky_top_color = sm.sky_top_color.lerp(Color(0.38, 0.4, 0.43), 0.8)
		sm.sky_horizon_color = sm.sky_horizon_color.lerp(Color(0.5, 0.52, 0.55), 0.8)
		env.fog_density = maxf(env.fog_density, 0.0014)
		env.fog_light_color = env.fog_light_color.lerp(Color(0.45, 0.47, 0.5), 0.7)
		sun.shadow_enabled = false


## Rain follows the camera so it is always around the player.
func attach_rain(cam: Node3D) -> void:
	rain = CPUParticles3D.new()
	rain.name = "Rain"
	rain.amount = 3000
	rain.lifetime = 1.1
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(25, 1, 25)
	rain.direction = Vector3(0.05, -1, 0)
	rain.spread = 3.0
	rain.gravity = Vector3(0, -9.8, 0)
	rain.initial_velocity_min = 12.0
	rain.initial_velocity_max = 15.0
	rain.local_coords = false
	var qm := QuadMesh.new()
	qm.size = Vector2(0.012, 0.45)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.8, 0.88, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	qm.material = mat
	rain.mesh = qm
	cam.add_child(rain)
	rain.position = Vector3(0, 14, 0)
