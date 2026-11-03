class_name TutorialSteps
## The tutorial's steps for each train. A step is a Dictionary:
##   title, text (BBCode), ids (controls to ring; "g:<id>" for a gauge),
##   done (Callable -> bool, or null for a step you read and press Next on),
##   do (the short instruction shown until it is done), view (optional
##   position "Show me" should use).


static func for_game(g: Node) -> Array:
	match int(GameSettings.train):
		GameSettings.TrainType.C92:
			return c92(g)
		GameSettings.TrainType.A4:
			return a4(g)
	return mariyung(g)


static func _st(title: String, text: String, ids: Array = [], done = null, todo := "", view := "") -> Dictionary:
	return {"title": title, "text": text, "ids": ids, "done": done, "do": todo, "view": view}


## The first steps are the same for every train: how to look, point and click.
static func _basics(g: Node, seat: String) -> Array:
	var rig: CameraRig = g.rig
	return [
		_st("Welcome", ("You're in the %s. This tutorial takes you through a start-up from cold, one control at a time, and then drives away.\n\n" % seat) +
			"[b]How it works:[/b] the controls you need are [color=#ffd060]ringed in yellow[/color]. If one is out of sight an arrow points to it, and [b]Show me (Tab)[/b] takes you straight there. Each step ticks itself off when you've done it.\n\n" +
			"You can hide this panel, and come back to any step with Back."),
		_st("Looking around", "Hold the [b]right mouse button[/b] and move the mouse to look around the cab. Let go to get the pointer back.\n\nThe [b]1[/b] key steps through the positions you can stand in (Shift+1 goes back); [b]3[/b] is the outside view, [b]4[/b] the lineside camera, and 1 brings you back in.",
			[], func() -> bool: return absf(rig.yaw) > 0.5 or absf(rig.pitch) > 0.35, "Hold the right mouse button and look around."),
		_st("Using the controls", "Point at anything in the cab and a label tells you what it is, how it's set, and what it does.\n\n" +
			"[b]Buttons and switches:[/b] click. [b]Rotary switches:[/b] left click turns them one way, right click the other.\n[b]Levers and wheels:[/b] drag them with the left button, or point at them and use the [b]scroll wheel[/b].\n[b]Doors and cabinets:[/b] click to open or close.\n\n" +
			"Most driving controls have keys too (shown in the label). [b]F1[/b] lists them all, [b]F2[/b] shows the start-up checklist, [b]+ / -[/b] speed time up and down, [b]Esc[/b] pauses."),
	]


# ================================================================ 92 class
static func c92(g: Node) -> Array:
	var cab: Cab = g.cab
	var sim: C92Sim = g.sim
	var rig: CameraRig = g.rig
	var two: bool = sim.nu == 2
	var on := func(id: String) -> bool: return cab.val(id) > 0.5
	var all_cb := func(p: String) -> bool:
		for b in C92Sim.BREAKERS:
			if cab.val(p + b) < 0.5:
				return false
		return true
	var cbs := func(p: String) -> Array:
		var out := []
		for b in C92Sim.BREAKERS:
			out.append(p + b)
		return out
	var s := _basics(g, "driver's seat of Pacific National 9206" + (" (with 9211 coupled behind)" if two else ""))
	s.append_array([
		_st("The driving controls", "On the desk in front of you:\n" +
			"[b]Automatic brake[/b] (left, tall handle): the train brakes. Forward is RELEASE, pull back for more braking. Keys [b];[/b] and [b]'[/b].\n" +
			"[b]Independent brake[/b]: the locomotive's own brakes. Keys [b][[/b] and [b]][/b].\n" +
			"[b]Throttle[/b] (black knob, right): IDLE then notches 1 to 8. Keys [b]D[/b] / [b]A[/b].\n" +
			"[b]Dynamic brake[/b] (red knob): the motors act as generators to slow you. With the throttle at IDLE, [b]A[/b] sets it up and adds more.\n" +
			"[b]Reverser[/b] (silver knob): FORWARD, CENTRE, REVERSE. Keys [b]W[/b] / [b]S[/b].",
			["l_auto_brake", "l_ind_brake", "l_throttle", "l_dynbrake", "l_reverser"]),
		_st("Gauges and displays", "The two air gauges show the [b]main reservoir[/b] (red needle) and equalising reservoir, then the [b]brake pipe[/b] and brake cylinder (red). The displays come alive once the computer has booted; the keys under the right one change its page. The row of lamps under the left display are warnings: PCS open, wheel slip, handbrake on and so on.\n\nRight now everything is dead: the battery is isolated.",
			["g:l_air1", "g:l_air2", "g:l_loadmeter", "g:l_speedo"], null, "", "Driver"),
		# ------------------------------------------------- front unit
		_st("Out to the battery box", "The battery isolating switch is outside, in a box on the left walkway just behind the cab. Press [b]7[/b] to go there (or Show me).",
			["l_bat_door"], func() -> bool: return rig.mode == "cab" and rig.view_name() == "Battery box (left walkway)", "Press 7 to go out to the battery box.", "Battery box (left walkway)"),
		_st("Open the battery box", "Click both doors of the battery box to open them.",
			["l_bat_door", "l_bat2_door"], func() -> bool: return on.call("l_bat_door") and on.call("l_bat2_door"), "Click both battery box doors open."),
		_st("Battery on", "Click the [b]battery isolating switch[/b]. That puts the 74 V battery on the locomotive's circuits: the first switch in any start-up, and the last one off.",
			["l_bat_switch"], func() -> bool: return on.call("l_bat_switch"), "Click the battery switch ON."),
		_st("The engine control panel", "Back inside: the engine control panel is behind the door on the wall behind the driver's seat. Press [b]6[/b] to face it.",
			["l_ecp_door"], func() -> bool: return rig.mode == "cab" and rig.view_name() == "Engine control panel", "Press 6 to face the engine control panel.", "Engine control panel"),
		_st("Open the panel", "Click the door to open it.",
			["l_ecp_door"], func() -> bool: return on.call("l_ecp_door"), "Click the panel door open.", "Engine control panel"),
		_st("Circuit breakers", "Switch on all twelve circuit breakers (click each one: handle up is ON). Control, local control, fuel pump, computer, excitation, both traction converters and the compressor are needed to run; the rest are lights, air-conditioning, radio and the alerter.\n\nPoint at a breaker to see what it feeds.",
			cbs.call("l_"), func() -> bool: return all_cb.call("l_"), "Switch all 12 breakers ON."),
		_st("Wait for the computer", "The locomotive computer takes about 25 seconds to boot; the battery voltmeter on the panel shows the battery working. Press [b]+[/b] to speed time up if you like ([b]-[/b] slows it again).",
			["g:l_batv"], func() -> bool: return sim.computer[0], "Wait for \"computer and displays ready\".", "Engine control panel"),
		_st("Prime the fuel", "The [b]engine control switch[/b] must be in ISOLATE to start (it is). Now press and [b]hold FUEL PRIME[/b] until the fuel pressure passes 200 kPa: the fuel pump fills the injectors. Holding a button: keep the left mouse button down on it.",
			["l_ecs", "l_fuel_prime"], func() -> bool: return sim.fuel_p[0] > 200.0 or sim.is_running(0), "Hold FUEL PRIME for a few seconds."),
		_st("Start the engine", "Now press and [b]hold ENGINE START[/b]. The main alternator turns the 16-cylinder engine over on the battery; keep holding until it fires (about 5 seconds), then let go.",
			["l_engine_start"], func() -> bool: return sim.is_running(0), "Hold ENGINE START until the engine fires.", "Engine control panel"),
	])
	if two:
		s.append_array([
			_st("Now the second unit", "9211 has to be started too. Press [b]9[/b] for its cab, then [b]1[/b] a few times to step through its positions to its battery box (or just press Show me).",
				["t_bat_door"], func() -> bool: return rig.mode == "cab" and rig.view_name() == "Second unit: battery box", "Get to the second unit's battery box.", "Second unit: battery box"),
			_st("Second unit: battery", "Same as before: open both doors and switch the battery on.",
				["t_bat_door", "t_bat2_door", "t_bat_switch"], func() -> bool: return on.call("t_bat_switch"), "Open the box, battery switch ON."),
			_st("Second unit: engine control panel", "Go to the second unit's engine control panel (Show me), open its door and switch on all twelve breakers.",
				["t_ecp_door"] + cbs.call("t_"), func() -> bool: return all_cb.call("t_"), "Open the panel, all 12 breakers ON.", "Second unit: engine control panel"),
			_st("Second unit: start the engine", "When its computer is ready: hold [b]FUEL PRIME[/b] until the fuel pressure passes 200 kPa, then hold [b]ENGINE START[/b] until it fires.",
				["t_fuel_prime", "t_engine_start"], func() -> bool: return sim.is_running(1), "Prime and start the second engine."),
			_st("Second unit: engine control switch to RUN", "Turn the second unit's [b]engine control switch[/b] to RUN, so it will take power when the front cab asks for it.",
				["t_ecs"], func() -> bool: return int(cab.val("t_ecs")) == 1, "ECS to RUN."),
			_st("Second unit: brake valve to TRAIL", "Only one brake valve may control the train. Open the second unit's [b]air brake cabinet[/b] (the door on the right of the back wall) and turn its brake valve to [b]TRAIL[/b] (cut out).",
				["t_brake_door", "t_brake_mode"], func() -> bool: return cab.val("t_brake_mode") > 0.5, "Open the brake cabinet, brake valve to TRAIL.", "Second unit: air brake cabinet"),
			_st("Second unit: reverser and CONTROL", "A trailing unit must have its [b]reverser centred[/b] and its [b]CONTROL switch off[/b], so it follows the front cab instead of trying to drive. They already are in a cold start, but this is what to check.",
				["t_reverser", "t_sw_control"], func() -> bool: return int(cab.val("t_reverser")) == 1 and cab.val("t_sw_control") < 0.5, "Reverser CENTRE, CONTROL off.", "Second unit: driver"),
			_st("Connect the units", "Between the two locomotives: open the four [b]angle cocks[/b] (brake pipe and main reservoir, on both units) and plug in the [b]MU jumper[/b] cable that carries the throttle and the other controls. Press [b]8[/b] to go there.",
				["l_bp_cock", "t_bp_cock", "l_mr_cock", "t_mr_cock", "mu_jumper"],
				func() -> bool: return on.call("l_bp_cock") and on.call("t_bp_cock") and on.call("l_mr_cock") and on.call("t_mr_cock") and on.call("mu_jumper"),
				"Open all four cocks, connect the MU jumper.", "Coupling between the units"),
		])
	s.append_array([
		_st("Engine control switch to RUN", "Back in the front cab (press [b]6[/b]): turn the front unit's [b]engine control switch[/b] to RUN.",
			["l_ecs"], func() -> bool: return int(cab.val("l_ecs")) == 1, "ECS to RUN.", "Engine control panel"),
		_st("Brake valve in LEAD", "The front unit's brake valve controls the train, so it stays in [b]LEAD[/b] (cut in). Open the [b]air brake cabinet[/b] beside the engine control panel and check it.",
			["l_brake_door", "l_brake_mode"], func() -> bool: return cab.val("l_brake_door") > 0.5 and cab.val("l_brake_mode") < 0.5, "Open the brake cabinet; brake valve LEAD.", "Air brake cabinet"),
		_st("Release the automatic brake", "Back to the driver's seat ([b]5[/b]). The automatic brake handle is in FULL SERVICE. Push it fully forward to [b]RELEASE[/b] (drag it, scroll on it, or hold [b];[/b]) so the brake pipe can charge. The independent brake stays on and holds the locomotive.",
			["l_auto_brake"], func() -> bool: return cab.val("l_auto_brake") < 0.5, "Automatic brake to RELEASE.", "Driver"),
		_st("Pump up the air", "The compressor%s now fill%s the main reservoir%s and the brake pipe. Watch the gauges: main reservoir up to about 1000 kPa, brake pipe 500 kPa. This takes several minutes, so press [b]+[/b] a few times to speed things up." % [("s" if two else ""), ("" if two else "s"), ("s" if two else "")],
			["g:l_air1", "g:l_air2"], func() -> bool: return sim.mr[0] > 850.0 and (not two or sim.mr[1] > 850.0) and sim.bp[sim.n - 1] > 470.0, "Wait for the air (press + to speed up).", "Driver"),
		_st("Release the handbrake", "The handbrake wheel is outside at the back (No. 2) end of the locomotive. Go there (Show me) and turn the wheel anticlockwise: drag it, or scroll on it, until it says RELEASED.",
			["l_handbrake"], func() -> bool: return cab.val("l_handbrake") < 0.05, "Release the handbrake.", "Handbrake (No. 2 end)"),
	])
	if two:
		s.append(_st("Second unit's handbrake", "And the same on the second unit.",
			["t_handbrake"], func() -> bool: return cab.val("t_handbrake") < 0.05, "Release the second unit's handbrake.", "Second unit: handbrake"))
	s.append_array([
		_st("Desk switches", "Back in the driver's seat ([b]5[/b]). Switch on [b]CONTROL[/b] (makes this the controlling cab), [b]ENGINE RUN[/b] (lets the throttle speed the engine up) and [b]GEN FIELD[/b] (lets the alternator load).",
			["l_sw_control", "l_sw_engine_run", "l_sw_gen_field"], func() -> bool: return on.call("l_sw_control") and on.call("l_sw_engine_run") and on.call("l_sw_gen_field"), "Switch on CONTROL, ENGINE RUN and GEN FIELD.", "Driver"),
		_st("Brake test", "Before moving, prove the brakes work. Apply the automatic brake a little: pull it back to [b]MINIMUM[/b] or a bit more (press [b]'[/b]). Watch the brake pipe gauge drop%s." % (" and the application reach the last wagon" if sim.n > sim.nu else ""),
			["l_auto_brake", "g:l_air2"], func() -> bool: return sim.brake_test >= 1, "Make a brake application ('), and wait."),
		_st("Release the brakes", "Good. Now push the automatic brake back to [b]RELEASE[/b] ([b];[/b]) and let the brakes come off.",
			["l_auto_brake"], func() -> bool: return sim.brake_test >= 2, "Automatic brake to RELEASE."),
		_st("Lights", "Turn the [b]headlights[/b] on (the HEAD knob on the overhead console, or [b]L[/b]) and the [b]marker lights[/b].",
			["l_headlights", "l_markers"], func() -> bool: return int(cab.val("l_headlights")) >= 1 and on.call("l_markers"), "Headlights and markers on.", "Driver"),
		_st("Reverser forward", "Put the [b]reverser[/b] to FORWARD ([b]W[/b]).",
			["l_reverser"], func() -> bool: return int(cab.val("l_reverser")) == 2, "Reverser FORWARD (W)."),
		_st("Release the independent brake", "Release the locomotive's own brake: push the [b]independent brake[/b] forward to RELEASE (or press [b]][/b] a few times).",
			["l_ind_brake"], func() -> bool: return cab.val("l_ind_brake") < 0.05, "Independent brake to RELEASE (])."),
		_st("Away you go", "Open the [b]throttle[/b] a notch at a time ([b]D[/b]). Each notch raises the engine speed and the power; the load meter shows the tractive effort. %s" % ("With wagons on, go gently: snatching the power makes the slack run out with a bang." if sim.n > sim.nu else "On its own a 92 class gets going very quickly!"),
			["l_throttle", "g:l_loadmeter", "g:l_speedo"], func() -> bool: return absf(sim.train.speed) > 2.0, "Notch up the throttle (D)."),
		_st("Slowing down", "To slow down: throttle back to IDLE ([b]A[/b]), then keep pressing [b]A[/b] to set up and apply the [b]dynamic brake[/b]. For a stop, use the automatic brake ([b]'[/b]) too. [b]Backspace[/b] is an emergency stop.\n\nEvery minute or so the [b]alerter[/b] will ask if you're awake: press [b]Q[/b].",
			["l_dynbrake", "l_auto_brake", "l_alerter"]),
		_st("That's it", "You've started a 92 class from cold and driven it away.\n\n[b]F2[/b] shows the start-up checklist any time, [b]F1[/b] lists every key, and pointing at any control explains it. Esc pauses (and gets you back to the menu)."),
	])
	return s


# ================================================================ Mariyung
static func mariyung(g: Node) -> Array:
	var cab: Cab = g.cab
	var sim = g.sim
	var rig: CameraRig = g.rig
	var on := func(id: String) -> bool: return cab.val(id) > 0.5
	var s := _basics(g, "driving cab of a NSW D set \"Mariyung\"")
	s.append_array([
		_st("The driving controls", "In front of you:\n" +
			"[b]Traction / brake controller[/b] (left): push forward for power (P1 to P4), pull back to brake (B1 to B7), fully back is EB, the emergency brake. Keys [b]D[/b] / [b]A[/b].\n" +
			"[b]Direction controller[/b]: forward, neutral, reverse. Keys [b]W[/b] / [b]S[/b].\n" +
			"[b]Driver's safety pedal[/b]: must be held down while you drive ([b]F[/b] toggles it).\n" +
			"[b]Vigilance[/b] button: press it ([b]Q[/b]) when the lamp flashes.",
			["tbc", "direction", "dsd", "vigilance"]),
		_st("Battery on", "Everything is off. The battery switch is on the panel behind you: press [b]2[/b] to turn round to it, and click the [b]battery isolating switch[/b] ON.",
			["battery"], func() -> bool: return on.call("battery"), "Battery switch ON.", "Rear panel (battery & breakers)"),
		_st("Circuit breakers", "The circuit breakers next to it feed the train's systems. They're all on already; point at one to see what it does. If something won't work later, check its breaker here.",
			["mcb_control", "mcb_pan", "mcb_hscb", "mcb_comp"], null, "", "Rear panel (battery & breakers)"),
		_st("Master key", "Face forward again ([b]1[/b]) and turn the [b]master key[/b] ON ([b]K[/b]). That activates this cab: the TMS screen and the ETCS display start up.",
			["master_key"], func() -> bool: return sim.cab_active, "Master key ON (K).", "Driver (seated)"),
		_st("Wait for the screens", "The TMS (train management) screen and the ETCS driver display take a little while to boot. Press [b]+[/b] to speed time up if you like.",
			["tms_status", "dmi_data"], func() -> bool: return sim.tms_on and sim.etcs_mode != "NP", "Wait for TMS and the DMI."),
		_st("Raise the pantograph", "Press [b]PAN UP[/b] ([b]P[/b]). With the main reservoir empty, a small battery compressor first pumps up enough air to lift it, so it takes a moment. The line voltmeter then reads about 1500 V.",
			["pan_up", "g:line_v"], func() -> bool: return sim.pan_pos > 0.97, "Pantograph UP (P)."),
		_st("Close the HSCB", "Close the [b]high-speed circuit breaker[/b] ([b]H[/b]): it connects the overhead supply to the train. The auxiliary converter then starts and the main compressor runs.",
			["hscb_close"], func() -> bool: return sim.hscb, "HSCB CLOSE (H)."),
		_st("Pump up the air", "Wait for the main reservoir to pass 750 kPa (the air gauge). Press [b]+[/b] to speed up time.",
			["g:air"], func() -> bool: return sim.mr > 750.0, "Wait for 750 kPa.", "Driver (seated)"),
		_st("Release the parking brake", "Press [b]PARKING BRAKE RELEASE[/b]. The spring parking brakes need air to hold them off.",
			["park_release"], func() -> bool: return not sim.park_applied, "Parking brake RELEASE."),
		_st("ETCS: train data and start", "On the ETCS display (the DMI): press [b]DATA[/b] to confirm the train data, then [b]START[/b] for Start of Mission.",
			["dmi_data", "dmi_start"], func() -> bool: return sim.etcs_mode in ["SR", "FS", "IS"], "DATA, then START."),
		_st("Brake test", "With the controller in [b]B7[/b] or EB (it's in EB), press [b]BRK TEST[/b] under the TMS screen and wait for it to pass.",
			["tms_btest", "tbc"], func() -> bool: return sim.brake_test == 2, "Press BRK TEST and wait."),
		_st("Headlights", "Turn the [b]headlights[/b] to full ([b]L[/b]).",
			["headlights"], func() -> bool: return int(cab.val("headlights")) >= 2, "Headlights on (L)."),
		_st("Doors", "The doors must be closed and locked before the train will take power (they are). [b]T[/b] / [b]Y[/b] release the left / right doors at a platform and [b]U[/b] closes them.",
			["door_rel_left", "door_rel_right", "doors_close"], func() -> bool: return sim.doors_locked, "Doors closed and locked.", "Driver (seated)"),
		_st("Direction forward", "Direction controller to [b]FORWARD[/b] ([b]W[/b]).",
			["direction"], func() -> bool: return int(cab.val("direction")) == 2, "Direction FORWARD (W).", "Driver (seated)"),
		_st("Safety pedal", "Put your foot on the [b]driver's safety pedal[/b] ([b]F[/b]). Without it, the brakes go on after a couple of seconds whenever you're moving or in power.",
			["dsd"], func() -> bool: return on.call("dsd"), "Safety pedal down (F)."),
		_st("Away you go", "Move the controller from EB through the brake steps to COAST and on into power ([b]D[/b]). Keep an eye on the ETCS speed limit on the DMI.",
			["tbc"], func() -> bool: return absf(sim.train.speed) > 2.0, "Controller into power (D)."),
		_st("That's it", "To stop, bring the controller back into the brake steps ([b]A[/b]). Press [b]Q[/b] whenever the vigilance lamp flashes.\n\n[b]F2[/b] shows the start-up checklist any time, [b]F1[/b] lists every key, and pointing at any control explains it.",
			["tbc", "vigilance"]),
	])
	# everything except the rear panel is done from the driver's seat
	for st in s:
		var ids: Array = st["ids"]
		if st["view"] == "" and not ids.is_empty() and not (ids[0] as String).begins_with("mcb") and ids[0] != "battery":
			st["view"] = "Driver (seated)"
	return s


# ================================================================ Mallard
static func a4(g: Node) -> Array:
	var cab: Cab = g.cab
	var sim = g.sim
	var v := func(id: String) -> float: return cab.val(id)
	var fire_ok := func() -> bool:
		var tot := 0.0
		for z in sim.zones:
			tot += z
		return tot > 250.0
	var s := _basics(g, "cab of LNER A4 4468 \"Mallard\". She was banked overnight: the fire is alive in the back of the grate and there's about 120 psi, so you won't have to wait hours to raise steam")
	s.append_array([
		_st("The driver's controls", "On the driver's (left) side:\n" +
			"[b]Regulator[/b]: lets steam to the cylinders: your throttle. Keys [b]A[/b] / [b]D[/b].\n" +
			"[b]Reversing screw[/b]: sets direction and cut-off (how long steam is admitted each stroke). Keys [b]W[/b] / [b]S[/b].\n" +
			"[b]Vacuum brake valve[/b]: the train brake. Keys [b];[/b] / [b]'[/b].\n" +
			"[b]Ejectors[/b]: make the vacuum that holds the brakes off.\n" +
			"[b]Cylinder cocks[/b] ([b]C[/b]), [b]sanders[/b] ([b]X[/b]), [b]whistle[/b] (Space).",
			["regulator", "reverser", "brake", "large_ejector", "cocks", "whistle"]),
		_st("The fireman's side", "Press [b]2[/b] for the fireman's position. The [b]firehole doors[/b] ([b]R[/b]) open onto the grate; click the [b]coal[/b] (or press [b]E[/b]) to fire a shovelful where you've aimed it ([b]Z[/b] picks the part of the grate). The [b]blower[/b] ([b]B[/b]) draws the fire when the engine isn't working, and the two [b]injectors[/b] ([b]I[/b], [b]O[/b]) put water in the boiler.\n\nIf you'd rather just drive, [b]F5[/b] turns the AI fireman on.",
			["firedoor", "coal", "blower", "inj_live_steam"], null, "", "Fireman"),
		_st("Water in the glass", "First thing on any footplate: check there's water showing in the [b]gauge glass[/b]. Never let it drop out of the bottom: the fusible plug melts and the fire's out.",
			["gauge_test_l"], func() -> bool: return sim.level > 0.5, "Check the gauge glass (over half)."),
		_st("Open the dampers", "Open the [b]back damper[/b] (and the front a little) so air can get up through the fire.",
			["damper_back", "damper_front"], func() -> bool: return v.call("damper_back") > 0.4, "Back damper open.", "Fireman"),
		_st("Build up the fire", "Open the firehole doors ([b]R[/b]) and fire round the grate, a shovelful at a time, thicker at the back ([b]E[/b], or click the coal). Shut the doors between rounds. Aim for 300-400 kg on the grate. Press [b]+[/b] to speed time up while the fire burns through.",
			["firedoor", "coal"], fire_ok, "Fire round the box (E), doors shut between.", "Fireman"),
		_st("Blower on", "Above 40 psi, put the [b]blower[/b] on ([b]B[/b]): a jet of steam up the chimney that draws the fire hard and raises steam much faster.",
			["blower"], func() -> bool: return sim.p_gauge < 40.0 or v.call("blower") > 0.1, "Blower on (B).", "Fireman"),
		_st("Raise steam", "Keep the fire bright and the water up until the boiler gauge is near [b]250 psi[/b], when the safety valves just start to simmer. Use time acceleration ([b]+[/b]).",
			["g:boiler"], func() -> bool: return sim.p_gauge > 220.0, "Wait for about 250 psi (use +)."),
		_st("Prove an injector", "Put some water in: open the [b]live steam injector[/b] water valve then its steam valve ([b]I[/b]), and listen for it to pick up. Watch the level rise in the glass.",
			["inj_live_water", "inj_live_steam"], func() -> bool: return sim.inj_live == 1 or sim.inj_exh == 1 or sim._warned.has("inj_tested"), "Get an injector working (I)."),
		_st("Create the vacuum", "Back on the driver's side ([b]1[/b]). Open the [b]large ejector[/b] ([b]J[/b]) until the vacuum gauge reads 21 inches, then open the [b]small ejector[/b] to hold it, and close the large one.",
			["large_ejector", "small_ejector", "g:vacuum"], func() -> bool: return sim.tp_vac > 19.0 and v.call("small_ejector") > 0.5, "Large ejector to 21 in, then the small ejector.", "Driver (seated)"),
		_st("Tender hand brake off", "Wind off the [b]tender hand brake[/b] on the fireman's side (drag or scroll the handle).",
			["handbrake"], func() -> bool: return v.call("handbrake") < 0.05, "Hand brake off."),
		_st("Cocks open, full forward gear", "The cylinders are cold and full of water: keep the [b]cylinder cocks[/b] open ([b]C[/b]). Wind the [b]reversing screw[/b] into full forward gear, 65 to 75% ([b]W[/b]).",
			["cocks", "reverser"], func() -> bool: return v.call("cocks") > 0.5 and sim.cutoff > 0.5, "Cocks open, reverser full forward (W)."),
		_st("Away you go", "Sound the [b]whistle[/b] (Space), make sure the brake is off, and ease the [b]regulator[/b] open ([b]D[/b]). Gently: too much and she'll slip.",
			["whistle", "brake", "regulator"], func() -> bool: return absf(sim.train.speed) > 0.5, "Whistle, then ease the regulator open (D)."),
		_st("Close the cocks", "Once she's moving and the cylinders are clear of water, close the [b]cylinder cocks[/b] ([b]C[/b]).",
			["cocks"], func() -> bool: return v.call("cocks") < 0.5, "Close the cocks (C)."),
		_st("Notch up", "As speed rises, wind the reverser back towards 15-25% cut-off ([b]S[/b]): she'll use far less steam for the same speed.",
			["reverser"], func() -> bool: return absf(sim.train.speed) > 15.0 and sim.cutoff < 0.3, "Notch up (S) as you gather speed."),
		_st("That's it", "You've raised steam and got the Mallard under way. Fire little and often, keep the water in the glass, and put the blower on before you shut the regulator at speed.\n\n[b]F2[/b] shows the checklist, [b]F1[/b] lists every key."),
	])
	return s
