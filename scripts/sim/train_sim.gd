class_name TrainSim
extends Node
## Base class for a train's systems simulation (electrics, air, steam...).
## It reads the cab controls, updates internal state and outputs forces.

signal message(text: String, kind: String)

var train: Train
var cab: Cab
var traction_force := 0.0     # N along the train (+ forward)
var brake_force := 0.0        # N, always resisting motion
var sim_time := 0.0
var failed := false
var fail_reason := ""
var player_role := "driver"   # A4: "driver" or "fireman"
var weather := "clear"
var route_units := "metric"
var sound := {}               # values read by the audio engine


func setup(_t: Train, _c: Cab, _start_state: int) -> void:
	pass


func step(_dt: float) -> void:
	pass


## Keyboard actions. 'held' actions are polled each frame via hold().
func handle_action(_action: String) -> void:
	pass


func hold(_dt: float) -> void:
	pass


func hud_lines() -> PackedStringArray:
	return PackedStringArray()


func checklist() -> Array:
	return []


func help_text() -> String:
	return ""


## Fastest the train itself may run (km/h); the line speed may be lower.
func max_speed_kmh() -> float:
	return INF


func speed_text() -> String:
	return "%d km/h" % int(absf(train.speed) * 3.6)


func notify(t: String, kind := "info") -> void:
	message.emit(t, kind)


func fail(reason: String) -> void:
	if failed:
		return
	failed = true
	fail_reason = reason
	notify(reason, "fail")


func adhesion_mu(braking := false) -> float:
	# a damp rail in fog or dew is often worse than one washed by heavy rain
	if weather == "fog":
		return 0.08 if braking else 0.13
	var wet := weather == "rain"
	if braking:
		return 0.09 if wet else 0.15
	return 0.15 if wet else 0.25
