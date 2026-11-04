extends Node
## Autoload "GameSettings": everything chosen in the main menu, plus the
## keyboard map. The game scene reads these when it builds the world.

enum TrainType { MARIYUNG, A4, C92 }
enum StartState { COLD, PREP, READY }

const TRAIN_NAMES := ["NSW D set \"Mariyung\" (EMU)", "LNER A4 4468 \"Mallard\" (steam)", "Pacific National 92 class pair, coal train (diesel)"]
const START_NAMES := ["Cold & dark (full start-up)", "Prepared (crew prep needed)", "Ready to drive"]

var train: int = TrainType.MARIYUNG
var mariyung_cars: int = 6          # 4, 6, 8 (4+4) or 10 (6+4)
var a4_coaches: int = 6             # passenger coaches behind the tender
var a4_dynamometer: bool = true     # add the LNER dynamometer car (as on 3 July 1938)
var coal_wagons: int = 20           # coal hoppers behind the 92 class (0 = light engine)
var coal_loaded: bool = true        # loaded (120 t each) or empty (23 t)
var c92_units: int = 2              # one 92 class, or two in multiple
var start_state: int = StartState.READY
var route: String = "auto"          # auto / nsw / ecml / flat
var time_of_day: String = "day"     # day / dusk / night
var weather: String = "clear"       # clear / rain / fog
var passenger_load: float = 0.3     # 0..1 of seated capacity
var ai_fireman: bool = true         # A4: AI handles the fireman's side
var ai_driver: bool = false         # A4: AI drives while you fire
var show_tooltips: bool = true
var show_controls: bool = false     # key guide always on screen
var graphics_quality: int = 2       # 0 low, 1 medium, 2 high, 3 ultra
var mouse_sensitivity: float = 0.2
var master_volume: float = 0.8
var drag_timer: bool = false        # 0-100 km/h and 400 m timer
var tutorial: bool = false          # this session runs the step-by-step tutorial (not saved)

## Key map: action -> list of keys. Mouse: LMB operate/drag, RMB hold to look, wheel adjust.
const KEYS := {
	"cam_driver": [KEY_1],
	"cam_second": [KEY_2],
	"cam_external": [KEY_3],
	"cam_lineside": [KEY_4],
	"help": [KEY_F1],
	"checklist": [KEY_F2],
	"debug": [KEY_F3],
	"show_controls": [KEY_F4],
	"time_faster": [KEY_EQUAL, KEY_KP_ADD],
	"time_slower": [KEY_MINUS, KEY_KP_SUBTRACT],
	"pause_menu": [KEY_ESCAPE],
	"main_inc": [KEY_D],          # power / regulator open
	"main_dec": [KEY_A],          # brake / regulator close
	"rev_fwd": [KEY_W],           # direction controller fwd / reverser screw forward
	"rev_back": [KEY_S],
	"brake_apply": [KEY_APOSTROPHE],
	"brake_release": [KEY_SEMICOLON],
	"ind_apply": [KEY_BRACKETLEFT],      # diesel: independent (locomotive) brake
	"ind_release": [KEY_BRACKETRIGHT],
	"bail_off": [KEY_B],                 # diesel: hold to bail off the locomotive brakes
	"view_5": [KEY_5],                   # quick cab positions
	"view_6": [KEY_6],
	"view_7": [KEY_7],
	"view_8": [KEY_8],
	"view_9": [KEY_9],
	"emergency": [KEY_BACKSPACE],
	"horn": [KEY_SPACE],
	"horn_low": [KEY_N],
	"acknowledge": [KEY_Q],
	"deadman": [KEY_F],
	"fire_shovel": [KEY_E],
	"fire_zone": [KEY_Z],
	"firedoor": [KEY_R],
	"sand": [KEY_X],
	"cocks": [KEY_C],
	"blower": [KEY_B],
	"injector_live": [KEY_I],
	"injector_exhaust": [KEY_O],
	"ejector": [KEY_J],
	"headlights": [KEY_L],
	"pantograph": [KEY_P],
	"hscb": [KEY_H],
	"master_key": [KEY_K],
	"doors_left": [KEY_T],
	"doors_right": [KEY_Y],
	"doors_close": [KEY_U],
	"ai_fireman": [KEY_F5],
	"ai_driver": [KEY_F6],
	"ai_speed_up": [KEY_PAGEUP],
	"ai_speed_down": [KEY_PAGEDOWN],
	"tut_next": [KEY_ENTER, KEY_KP_ENTER],   # tutorial: next step
	"tut_show": [KEY_TAB],                    # tutorial: take me to the control
	"pos_list": [KEY_V],                      # list of every position
	"pos_prev": [KEY_LEFT],
	"pos_next": [KEY_RIGHT],
}


func _ready() -> void:
	_register_inputs()
	_load_settings()


func _register_inputs() -> void:
	for action in KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)


func key_name(action: String) -> String:
	if not KEYS.has(action):
		return "?"
	return OS.get_keycode_string(KEYS[action][0])


func route_id() -> String:
	if route != "auto":
		return route
	return "ecml" if train == TrainType.A4 else "nsw"


# ---------------------------------------------------------------- persistence
const SAVE_PATH := "user://settings.cfg"
const SAVED_KEYS := ["train", "mariyung_cars", "a4_coaches", "a4_dynamometer", "coal_wagons", "coal_loaded", "c92_units", "drag_timer", "start_state",
	"route", "time_of_day", "weather", "passenger_load", "ai_fireman", "show_tooltips", "show_controls",
	"graphics_quality", "mouse_sensitivity", "master_volume"]


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in SAVED_KEYS:
		cfg.set_value("settings", k, get(k))
	cfg.save(SAVE_PATH)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for k in SAVED_KEYS:
		if cfg.has_section_key("settings", k):
			set(k, cfg.get_value("settings", k))
