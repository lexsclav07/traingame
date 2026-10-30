extends Control
## Main menu: pick the train, its length, how it starts, and the conditions.

var gs := GameSettings
var ui := {}
var desc: RichTextLabel


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.08, 0.11)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var stripe := ColorRect.new()
	stripe.color = Color(0.1, 0.19, 0.42)
	stripe.position = Vector2(0, 0)
	stripe.size = Vector2(4000, 120)
	add_child(stripe)
	var title := Label.new()
	title.text = "TRAINGAME"
	title.add_theme_font_size_override("font_size", 54)
	title.position = Vector2(48, 18)
	add_child(title)
	var sub := Label.new()
	sub.text = "Start up and drive real trains, every switch and lever working.   by Lex Sclavos"
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
	sub.position = Vector2(52, 84)
	add_child(sub)

	var hb := HBoxContainer.new()
	hb.position = Vector2(48, 150)
	hb.add_theme_constant_override("separation", 40)
	add_child(hb)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 10)
	hb.add_child(grid)

	_option(grid, "train", "Train", gs.TRAIN_NAMES, gs.train)
	_option(grid, "mcars", "Mariyung length", ["4 cars", "6 cars", "8 cars (4+4)", "10 cars (6+4)"], [4, 6, 8, 10].find(gs.mariyung_cars))
	ui["coaches"] = _spin(grid, "Mallard: coaches", 0, 14, gs.a4_coaches)
	ui["dyn"] = _check(grid, "Mallard: dynamometer car", gs.a4_dynamometer)
	_option(grid, "start", "Start", gs.START_NAMES, gs.start_state)
	_option(grid, "route", "Route", ["Train's own route", "Hawkesbury Loop (NSW, electrified)", "Stoke Bank Loop (ECML 1930s)"], ["auto", "nsw", "ecml"].find(gs.route))
	_option(grid, "tod", "Time of day", ["Day", "Dusk", "Night"], ["day", "dusk", "night"].find(gs.time_of_day))
	_option(grid, "weather", "Weather", ["Clear", "Rain (poor adhesion)"], ["clear", "rain"].find(gs.weather))
	ui["load"] = _slider(grid, "Passenger load", 0.0, 1.0, gs.passenger_load)
	ui["aif"] = _check(grid, "Mallard: AI fireman", gs.ai_fireman)
	ui["aid"] = _check(grid, "Mallard: AI driver (you fire)", gs.ai_driver)
	_option(grid, "gfx", "Graphics", ["Low", "Medium", "High"], gs.graphics_quality)
	ui["sens"] = _slider(grid, "Mouse sensitivity", 0.05, 0.6, gs.mouse_sensitivity)
	ui["vol"] = _slider(grid, "Volume", 0.0, 1.0, gs.master_volume)
	ui["tips"] = _check(grid, "Control tooltips", gs.show_tooltips)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 14)
	hb.add_child(right)
	desc = RichTextLabel.new()
	desc.bbcode_enabled = true
	desc.custom_minimum_size = Vector2(620, 470)
	right.add_child(desc)
	var go := Button.new()
	go.text = "Drive"
	go.custom_minimum_size = Vector2(240, 56)
	go.add_theme_font_size_override("font_size", 24)
	go.pressed.connect(_start)
	right.add_child(go)
	var quit := Button.new()
	quit.text = "Quit"
	quit.custom_minimum_size = Vector2(240, 38)
	quit.pressed.connect(func(): get_tree().quit())
	right.add_child(quit)
	(ui["train"] as OptionButton).item_selected.connect(func(_i): _describe())
	(ui["start"] as OptionButton).item_selected.connect(func(_i): _describe())
	_describe()


func _label(grid: GridContainer, t: String) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_color_override("font_color", Color(0.78, 0.82, 0.9))
	grid.add_child(l)


func _option(grid: GridContainer, key: String, t: String, items: Array, sel: int) -> void:
	_label(grid, t)
	var o := OptionButton.new()
	for it in items:
		o.add_item(it)
	o.selected = maxi(sel, 0)
	o.custom_minimum_size = Vector2(330, 0)
	grid.add_child(o)
	ui[key] = o


func _spin(grid: GridContainer, t: String, mn: int, mx: int, v: int) -> SpinBox:
	_label(grid, t)
	var s := SpinBox.new()
	s.min_value = mn
	s.max_value = mx
	s.value = v
	grid.add_child(s)
	return s


func _check(grid: GridContainer, t: String, v: bool) -> CheckBox:
	_label(grid, t)
	var c := CheckBox.new()
	c.button_pressed = v
	grid.add_child(c)
	return c


func _slider(grid: GridContainer, t: String, mn: float, mx: float, v: float) -> HSlider:
	_label(grid, t)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = 0.01
	s.value = v
	s.custom_minimum_size = Vector2(330, 24)
	grid.add_child(s)
	return s


func _describe() -> void:
	var t: int = (ui["train"] as OptionButton).selected
	var st: int = (ui["start"] as OptionButton).selected
	var txt := ""
	if t == 0:
		txt = """[font_size=24][b]NSW D set "Mariyung"[/b][/font_size]
Double-deck intercity electric multiple unit built by Hyundai Rotem with Mitsubishi IGBT-VVVF traction, running on 1500 V DC overhead. In service on the Central Coast & Newcastle, Blue Mountains and South Coast lines.

[b]As simulated:[/b] 20.4 m cars, 3.03 m wide, 4.40 m tall; 4-car 200 t, 6-car 298 t; 160 km/h design, 130 km/h service; 0.84 m/s² acceleration; 1.01 m/s² service and 1.10 m/s² emergency braking; blended regenerative + EP brakes; spring parking brakes; plug doors with traction interlock; vigilance, driver's safety pedal and ETCS supervision.

Route: the Hawkesbury Loop, a fictional 17.7 km NSW-style electrified line with sandstone cuttings, a 1 in 40 bank and curves down to 300 m radius."""
	else:
		txt = """[font_size=24][b]LNER A4 4468 "Mallard"[/b][/font_size]
Sir Nigel Gresley's streamlined 4-6-2, holder of the world speed record for steam: 126 mph down Stoke Bank on 3 July 1938 with six coaches and the dynamometer car (240 tons).

[b]As simulated:[/b] three 18½ × 26 in cylinders, 6 ft 8 in drivers, 250 psi boiler -> 35,455 lbf tractive effort; Kylchap double chimney; steam flow through the regulator, superheater and valve events; a full fire and boiler model (dampers, firehole door, blower, two injectors, water gauge glasses, fusible plug), vacuum brakes with large and small ejectors, sanders, cylinder cocks, water scoop, and the tender hand brake.

Route: the Stoke Bank Loop, a fictional 43 km 1930s East Coast Main Line-style circuit with 11 km of 1 in 200 descent and water troughs."""
	var starts := [
		"\n\n[b]Cold & dark:[/b] everything is off and cold. A full start-up (F2 shows the checklist). For the A4, raising steam from cold takes hours: use time acceleration (+).",
		"\n\n[b]Prepared:[/b] the train has been stabled with power available / a banked fire. You do the crew preparation, tests and departure.",
		"\n\n[b]Ready to drive:[/b] prepared, tested and ready to depart."]
	desc.text = txt + starts[st]


func _start() -> void:
	gs.train = (ui["train"] as OptionButton).selected
	gs.mariyung_cars = [4, 6, 8, 10][(ui["mcars"] as OptionButton).selected]
	gs.a4_coaches = int((ui["coaches"] as SpinBox).value)
	gs.a4_dynamometer = (ui["dyn"] as CheckBox).button_pressed
	gs.start_state = (ui["start"] as OptionButton).selected
	gs.route = ["auto", "nsw", "ecml"][(ui["route"] as OptionButton).selected]
	gs.time_of_day = ["day", "dusk", "night"][(ui["tod"] as OptionButton).selected]
	gs.weather = ["clear", "rain"][(ui["weather"] as OptionButton).selected]
	gs.passenger_load = (ui["load"] as HSlider).value
	gs.ai_fireman = (ui["aif"] as CheckBox).button_pressed
	gs.ai_driver = (ui["aid"] as CheckBox).button_pressed
	gs.graphics_quality = (ui["gfx"] as OptionButton).selected
	gs.mouse_sensitivity = (ui["sens"] as HSlider).value
	gs.master_volume = (ui["vol"] as HSlider).value
	gs.show_tooltips = (ui["tips"] as CheckBox).button_pressed
	gs.save_settings()
	get_tree().change_scene_to_file("res://scenes/game.tscn")
