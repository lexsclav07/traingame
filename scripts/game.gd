extends Node3D
## The driving session: builds the route, the train, its cab and systems, then
## runs the simulation loop (with time acceleration) and routes input.

const TIME_STEPS := [1.0, 2.0, 5.0, 10.0, 30.0, 60.0, 120.0]

var track: Track
var terrain: TerrainBuilder
var scenery: SceneryBuilder
var envb: EnvironmentBuilder
var train: Train
var cab: Cab
var sim: TrainSim
var rig: CameraRig
var hud: Hud
var effects: Effects
var diesel: DieselEffects
var audio: TrainAudio
var crossings: LevelCrossings
var built := false
var paused := false
var time_idx := 0
var clock := 0.0
var _help_on := false


func _ready() -> void:
	hud = Hud.new()
	add_child(hud)
	hud.resume_pressed.connect(func(): _set_pause(false))
	hud.restart_pressed.connect(func(): get_tree().reload_current_scene())
	hud.menu_pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	await get_tree().process_frame
	await get_tree().process_frame
	_build()


func _build() -> void:
	var gs := GameSettings
	var q: int = gs.graphics_quality
	track = Track.new()
	track.build(RouteDefs.get_route(gs.route_id()))
	terrain = TerrainBuilder.new()
	terrain.setup(track, track.route)
	terrain.build(self, q)
	VegetationBuilder.new().build(self, track, terrain, q)
	Animals.new().build(self, track, terrain, q)
	TrackBuilder.new().build(self, track, terrain, q)
	scenery = SceneryBuilder.new()
	scenery.build(self, track, terrain, q)
	crossings = LevelCrossings.new()
	crossings.build(self, track, terrain, q)
	_apply_render_quality(q)
	envb = EnvironmentBuilder.new()
	envb.build(self, track.route, gs.time_of_day, gs.weather, q)
	scenery.set_night_lights(gs.time_of_day != "day")

	train = Train.new()
	train.name = "Train"
	add_child(train)
	var plat: Array = track.route["platforms"][0]
	if gs.train == GameSettings.TrainType.C92:
		# a coal train does not stop at the platform: it waits at the signal
		# before the bridge on the station approach
		train.setup(track, plat[0] - 80.0)
	else:
		train.setup(track, plat[0] + plat[1] - 6.0)
	if gs.train == GameSettings.TrainType.A4:
		_build_a4()
	elif gs.train == GameSettings.TrainType.C92:
		_build_c92()
	else:
		_build_mariyung()
	train.update_visuals()
	crossings.settle(train)
	var daylight: float = {"day": 1.0, "dusk": 0.35, "night": 0.0}.get(gs.time_of_day, 1.0)
	if gs.weather == "rain":
		daylight *= 0.55
	elif gs.weather == "fog":
		daylight *= 0.7
	if q >= 3 and RenderingServer.get_current_rendering_method() == "forward_plus":
		daylight *= 0.6      # SDFGI already bounces some light in
	cab.set_daylight(daylight)
	train.derailed_signal.connect(func(r): hud.fail(r + "\n\nTake curves at or below the line speed shown on the lineside boards."))
	sim.message.connect(_on_message)
	rig = CameraRig.new()
	add_child(rig)
	rig.setup(cab, train)
	rig.hover_changed.connect(func(_c): pass)
	if gs.weather == "rain":
		envb.attach_rain(rig.cam)
	var grass := GrassField.new()
	grass.name = "Grass"
	add_child(grass)
	grass.setup(terrain, rig.cam, q)
	audio = TrainAudio.new()
	add_child(audio)
	audio.setup(sim, ["electric", "steam", "diesel"][gs.train])
	hud.set_help(_help_text())
	hud.loading.visible = false
	clock = {"day": 10.5, "dusk": 18.3, "night": 22.0}.get(gs.time_of_day, 10.5) * 3600.0
	built = true
	var start_names := ["cold and dark", "prepared, awaiting the crew", "ready to drive"]
	var train_names := ["Mariyung", "Mallard", "92 class coal train (%d %s wagons)" % [gs.coal_wagons, "loaded" if gs.coal_loaded else "empty"]]
	_on_message("%s at %s, %s. F1 = controls and help, F2 = start-up checklist." % [
		train_names[gs.train], track.route["name"].split(" (")[0], start_names[gs.start_state]], "good")


func _build_mariyung() -> void:
	var gs := GameSettings
	var sets: Array = {4: [4], 6: [6], 8: [4, 4], 10: [6, 4]}.get(gs.mariyung_cars, [6])
	var codes4 := [["DD", true, false, false, false], ["DN", false, true, true, false], ["DND", false, true, false, false], ["DDA", true, false, false, true]]
	var codes6 := [["DD", true, false, false, false], ["DNL", false, true, true, false], ["DT", false, false, false, false],
		["DN", false, true, true, false], ["DND", false, true, false, false], ["DDA", true, false, false, true]]
	var seats_per_car := 81.0
	for n in sets:
		var codes: Array = codes4 if n == 4 else codes6
		for c in codes:
			var v := VehicleModels.mariyung_car(c[0], c[1], c[2], c[3], c[4])
			v.mass_load = seats_per_car * gs.passenger_load * 1.25 * 80.0
			train.add_vehicle(v)
	train.derail_lat_limit = 2.2
	var mc := MariyungCab.new()
	mc.build(train.vehicles[0].cab_root)
	cab = mc
	var ms := MariyungSim.new()
	add_child(ms)
	ms.weather = gs.weather
	ms.setup(train, mc, gs.start_state)
	sim = ms
	train.sim = ms


func _build_a4() -> void:
	var gs := GameSettings
	var loco := VehicleModels.a4_loco()
	train.add_vehicle(loco)
	train.add_vehicle(VehicleModels.a4_tender())
	var n: int = gs.a4_coaches
	if gs.a4_dynamometer:
		train.add_vehicle(VehicleModels.lner_coach(true, n == 0))
	for i in range(n):
		var co := VehicleModels.lner_coach(false, i == n - 1)
		co.mass_load = 56.0 * gs.passenger_load * 75.0
		train.add_vehicle(co)
	train.derail_lat_limit = 2.6
	var ac := A4Cab.new()
	ac.build(loco.cab_root)
	cab = ac
	var a4 := A4Sim.new()
	add_child(a4)
	a4.weather = gs.weather
	a4.setup(train, ac, gs.start_state)
	sim = a4
	train.sim = a4
	effects = Effects.new()
	add_child(effects)
	effects.setup(loco, train.vehicles[1] if train.vehicles.size() > 1 else null)
	# express headcode oil lamps are lit at dusk and night, and the
	# compartment lights glow warm through the coach windows
	if gs.time_of_day != "day":
		for lm in loco.head_lamps:
			(lm as StandardMaterial3D).emission_energy_multiplier = 2.5
	# (the material is shared and cached, so set it either way)
	var cw := MU.mat(Color(0.05, 0.055, 0.06), 0.04, 0.0, "coach_win")
	cw.emission_enabled = gs.time_of_day != "day"
	cw.emission = Color(1.0, 0.78, 0.48)
	cw.emission_energy_multiplier = 0.8 if gs.time_of_day != "day" else 0.0


func _build_c92() -> void:
	var gs := GameSettings
	var lead := CoalModels.c44aci("9206")
	var trail := CoalModels.c44aci("9211")
	train.add_vehicle(lead)
	train.add_vehicle(trail)
	var n: int = gs.coal_wagons
	for i in range(n):
		train.add_vehicle(CoalModels.coal_wagon(gs.coal_loaded, i + 1, i == n - 1))
	train.derail_lat_limit = 2.0
	var cc := C92Cab.new()
	cc.build_both(lead, trail)
	cab = cc
	var cs := C92Sim.new()
	add_child(cs)
	cs.weather = gs.weather
	cs.setup(train, cc, gs.start_state)
	sim = cs
	train.sim = cs
	diesel = DieselEffects.new()
	add_child(diesel)
	diesel.setup([lead, trail])


func _on_message(t: String, kind: String) -> void:
	hud.message(t, kind)
	if kind == "fail" and sim and sim.failed and sim.fail_reason == t:
		hud.fail(t)


func _process(delta: float) -> void:
	if not built:
		return
	if paused:
		return
	var ts: float = TIME_STEPS[time_idx]
	var sim_dt := minf(delta, 0.1) * ts
	clock += sim_dt
	sim.hold(delta)
	var steps := maxi(1, int(ceil(sim_dt / 0.05)))
	var h := sim_dt / steps
	for i in range(steps):
		sim.step(h)
		train.physics_step(h)
	train.update_visuals()
	if cab.has_method("update_visuals"):
		cab.call("update_visuals", sim, delta)
	if effects:
		effects.update(sim as A4Sim, delta)
	if diesel:
		diesel.update(sim as C92Sim, delta)
	rig.update_camera(delta)
	crossings.update(sim_dt, train, rig.cam.global_position)
	audio.xing_bell = crossings.bell
	if diesel:
		# which locomotive's engine the listener is nearest
		var anchor = cab.view_anchor.get(rig.view_name(), cab) if rig.mode == "cab" else cab
		audio.near_unit = 1 if anchor == (cab as C92Cab).cab2 else 0
	audio.update_audio(delta, ts, rig.mode == "cab")
	# HUD
	if rig.mode == "cab" and rig.hovered and not rig.looking:
		hud.show_tooltip(rig.hovered, _key_for(rig.hovered.id))
	elif rig.dragging:
		hud.show_tooltip(rig.dragging, "")
	else:
		hud.show_tooltip(null, "")
	var lim := minf(track.limit_at(train.front_s), sim.max_speed_kmh())
	var imperial: bool = track.route["units"] == "imperial"
	var lim_txt := ("%d mph" % int(round(lim / 1.609344 / 5.0) * 5.0)) if imperial else ("%d km/h" % int(lim))
	var hh := int(clock / 3600.0) % 24
	var mm := int(clock / 60.0) % 60
	var g := track.grade_at(train.front_s)
	var grade_txt := "level" if absf(g) < 0.0004 else ("1 in %d %s" % [int(1.0 / absf(g)), "up" if g > 0 else "down"])
	hud.set_info("%s   line speed %s   %s   %02d:%02d   %s%s" % [sim.speed_text(), lim_txt, grade_txt, hh, mm,
		("time x%d   " % int(ts)) if ts > 1.0 else "", rig.view_name()])
	var det := sim.hud_lines()
	if hud.show_details:
		det.append("Train %d m, %d t   gradient %.1f per mille   curve R %s   lateral %.2f m/s2   odometer %.2f km" % [
			int(train.total_length()), int(train.total_mass() / 1000.0), g * 1000.0,
			("%d m" % int(1.0 / absf(track.curv_at(train.front_s)))) if absf(track.curv_at(train.front_s)) > 1e-5 else "straight",
			train.lat_accel, train.odometer / 1000.0])
	hud.set_details(det)
	hud.set_checklist(sim.checklist(), "Start-up checklist (F2)")


func _key_for(id: String) -> String:
	if diesel:
		var short := id.substr(2) if id.begins_with("l_") or id.begins_with("t_") else id
		var dmap := {"throttle": "D / A", "dynbrake": "A / D", "reverser": "W / S", "auto_brake": "; / '", "ind_brake": "[ / ]",
			"bail_off": "B (hold)", "horn": "Space", "alerter": "Q", "sand": "X (hold)", "headlights": "L"}
		return dmap.get(short, "")
	var map := {"regulator": "A/D", "reverser": "W/S", "brake": "; / '", "whistle": "Space", "large_ejector": "J",
		"cocks": "C", "sanders": "X", "blower": "B", "firedoor": "R", "inj_live_steam": "I", "inj_exh_steam": "O",
		"tbc": "A/D", "direction": "W/S", "horn": "Space / N", "vigilance": "Q", "estop": "Backspace",
		"pan_up": "P", "pan_down": "P", "hscb_close": "H", "hscb_open": "H", "master_key": "K", "headlights": "L",
		"door_rel_left": "T", "door_rel_right": "Y", "doors_close": "U", "dsd": "F"}
	return map.get(id, "")


func _unhandled_input(event: InputEvent) -> void:
	if not built:
		return
	if event.is_action_pressed("pause_menu"):
		_set_pause(not paused)
		return
	if paused:
		return
	if rig.handle_input(event):
		return
	if not (event is InputEventKey) or not event.pressed or event.is_echo():
		return
	if event.is_action_pressed("cam_driver"):
		if (event as InputEventKey).shift_pressed:
			rig.prev_cab_view()
		else:
			rig.next_cab_view()
	elif _quick_view(event):
		pass
	elif event.is_action_pressed("cam_second"):
		rig.set_view(1)
	elif event.is_action_pressed("cam_external"):
		rig.set_external()
	elif event.is_action_pressed("cam_lineside"):
		rig.set_lineside()
	elif event.is_action_pressed("help"):
		_help_on = not _help_on
		hud.help.visible = _help_on
	elif event.is_action_pressed("checklist"):
		hud.checklist.visible = not hud.checklist.visible
	elif event.is_action_pressed("debug"):
		hud.show_details = not hud.show_details
	elif event.is_action_pressed("time_faster"):
		time_idx = mini(time_idx + 1, TIME_STEPS.size() - 1)
		hud.message("Time x%d" % int(TIME_STEPS[time_idx]), "info")
	elif event.is_action_pressed("time_slower"):
		time_idx = maxi(time_idx - 1, 0)
		hud.message("Time x%d" % int(TIME_STEPS[time_idx]), "info")
	else:
		for action in GameSettings.KEYS:
			if event.is_action_pressed(action):
				sim.handle_action(action)


## Keys 5-9 jump straight to the cab's quick positions (if it has any).
func _quick_view(event: InputEvent) -> bool:
	for k in range(5):
		if event.is_action_pressed("view_%d" % (k + 5)):
			if k < cab.quick_views.size():
				rig.set_view_named(cab.quick_views[k])
			return true
	return false


func _set_pause(on: bool) -> void:
	paused = on
	hud.set_pause(on)
	if on:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _help_text() -> String:
	return sim.help_text() + """

[b]Cameras & general[/b]
1  cycle cab positions (Shift+1 back)    2  second position    3  outside (drag to orbit, scroll to zoom)    4  lineside
Right mouse (hold)  look around    Mouse wheel  adjust the control under the cursor (or zoom)
+ / -  time acceleration (useful while raising steam or charging air)    F2 start-up checklist    F3 details    Esc  pause"""


## Anti-aliasing, shadow resolution and LOD detail for the chosen quality.
func _apply_render_quality(q: int) -> void:
	var vp := get_viewport()
	var compat := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_4X][q]
	if compat:
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if q == 0 else Viewport.SCREEN_SPACE_AA_DISABLED
	else:
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if q < 3 else Viewport.SCREEN_SPACE_AA_SMAA
	vp.mesh_lod_threshold = [2.0, 1.5, 1.0, 0.6][q]
	RenderingServer.directional_shadow_atlas_set_size([2048, 4096, 4096, 8192][q], true)
	RenderingServer.directional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW, RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, RenderingServer.SHADOW_QUALITY_SOFT_HIGH][q])
	RenderingServer.positional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW, RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, RenderingServer.SHADOW_QUALITY_SOFT_HIGH][q])
