class_name Vehicle
extends Node3D
## One rail vehicle in a consist. Geometry is built in "vehicle space":
## z = distance back from the front coupler face, y = up from rail top,
## x = right. The model is then offset so the pivot midpoint is the origin.

var kind := ""
var vlength := 20.0
var pivot_front := 3.0          # distance from front to front pivot (bogie centre)
var pivot_rear := 17.0
var mass_tare := 40000.0        # kg
var mass_load := 0.0            # kg (passengers, coal, water)
var axles := 4
var motored_axles := 0
var brake_mass_ratio := 0.9     # max brake force / (m g) for friction brakes
var reversed := false
var model: Node3D

var wheels: Array[Node3D] = []
var wheel_r: Array[float] = []
var driving_wheels: Array[Node3D] = []    # steam: coupled wheels (may slip)
var doors_left: Array = []                # [Node3D, closed_position, open_vector]
var doors_right: Array = []
var pantograph: Node3D
var pan_lower_arm: Node3D
var pan_upper_arm: Node3D
var pan_head: Node3D
var head_lamps: Array = []                # emissive meshes
var head_lights: Array = []               # SpotLight3D / OmniLight3D
var marker_lamps: Array = []
var tail_lamps: Array = []
var cab_root: Node3D                      # attach point for an interactive cab
var rods: Dictionary = {}                 # steam motion parts
var smoke_point: Node3D                   # chimney
var safety_valve_point: Node3D
var cocks_points: Array = []
var whistle_point: Node3D


func total_mass() -> float:
	return mass_tare + mass_load


func make_model_root() -> Node3D:
	model = Node3D.new()
	model.name = "Model"
	add_child(model)
	return model


## Call after geometry is built: shifts the model so the pivot midpoint is at the origin.
func finish_model() -> void:
	var mid := (pivot_front + pivot_rear) * 0.5
	if reversed:
		# turned end for end (e.g. the rear driving car): model z -> -z
		model.rotation.y = PI
		model.position = Vector3(0, 0, mid)
	else:
		model.position = Vector3(0, 0, -mid)


func add_wheel(node: Node3D, r: float, driving := false) -> void:
	wheels.append(node)
	wheel_r.append(r)
	if driving:
		driving_wheels.append(node)


## Rotate all wheels for distance travelled; steam drivers may spin faster (slip).
func roll(distance: float, driver_extra := 0.0) -> void:
	var sgn := -1.0 if reversed else 1.0
	for i in range(wheels.size()):
		var w := wheels[i]
		var extra := driver_extra if driving_wheels.has(w) else 0.0
		w.rotation.x -= sgn * (distance + extra) / wheel_r[i]
