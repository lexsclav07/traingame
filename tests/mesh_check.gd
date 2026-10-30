extends SceneTree
## Checks merged vehicle meshes: every vertex should be referenced by the index array.
func _initialize() -> void:
	for v in [VehicleModels.mariyung_car("DD", true, false, false, false), VehicleModels.a4_loco(), VehicleModels.lner_coach(false, true)]:
		var body := v.model.get_node("Body") as MeshInstance3D
		var am := body.mesh as ArrayMesh
		var bad := 0
		for i in range(am.get_surface_count()):
			var arr := am.surface_get_arrays(i)
			var nv: int = (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			var idx = arr[Mesh.ARRAY_INDEX]
			if idx != null and not (idx as PackedInt32Array).is_empty():
				var used := {}
				for k in (idx as PackedInt32Array):
					used[k] = true
				if used.size() < nv:
					bad += 1
					print("  surface %d: %d of %d vertices unreferenced" % [i, nv - used.size(), nv])
		print("%s: %d surfaces, %d with dropped geometry" % [v.name, am.get_surface_count(), bad])
		v.free()
	quit()
