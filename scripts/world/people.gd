class_name People
extends RefCounted
## Simple, varied passengers for the platforms: modern clothes on the NSW
## line, 1930s coats, suits and hats on the ECML. Built into a MeshBatch so a
## whole platform of people costs a handful of draws.

var b: MeshBatch
var era := "modern"
var rng := RandomNumberGenerator.new()
var _cloth := {}


func _init(batch: MeshBatch, theme: String, seed_v: int) -> void:
	b = batch
	era = "modern" if theme == "nsw" else "1930s"
	rng.seed = seed_v


func _fabric(col: Color) -> Material:
	var k := col.to_html()
	if not _cloth.has(k):
		_cloth[k] = TX.pbr("fabric_albedo", "fabric_normal", col, 0.9, 0.0, Vector3.ONE * 6.0, false, 0.6, "cloth_" + k)
	return _cloth[k]


func _pick(arr: Array):
	return arr[rng.randi() % arr.size()]


## One standing person at xf (feet on the ground, facing local +Z).
func person(xf: Transform3D) -> void:
	var h := rng.randf_range(1.58, 1.88)
	var s := h / 1.75
	var skin: Color = _pick([Color(0.94, 0.78, 0.66), Color(0.86, 0.66, 0.5), Color(0.7, 0.5, 0.36), Color(0.48, 0.32, 0.22), Color(0.98, 0.84, 0.74)])
	var hair: Color = _pick([Color(0.08, 0.06, 0.05), Color(0.25, 0.16, 0.09), Color(0.55, 0.4, 0.22), Color(0.75, 0.62, 0.38), Color(0.6, 0.6, 0.6)])
	var top: Color
	var legs: Color
	var dress := rng.randf() < (0.3 if era == "modern" else 0.4)
	if era == "modern":
		top = _pick([Color(0.15, 0.25, 0.5), Color(0.75, 0.1, 0.12), Color(0.9, 0.9, 0.88), Color(0.12, 0.12, 0.13), Color(0.2, 0.45, 0.3), Color(0.85, 0.6, 0.15), Color(0.5, 0.35, 0.55), Color(0.55, 0.6, 0.65)])
		legs = _pick([Color(0.15, 0.2, 0.32), Color(0.1, 0.1, 0.11), Color(0.45, 0.4, 0.32), Color(0.22, 0.28, 0.4)])
	else:
		top = _pick([Color(0.12, 0.12, 0.14), Color(0.22, 0.2, 0.18), Color(0.3, 0.26, 0.2), Color(0.18, 0.2, 0.26), Color(0.35, 0.3, 0.28), Color(0.28, 0.12, 0.1)])
		legs = top.darkened(0.15)
	var skin_m := MU.mat(skin, 0.6, 0.0, "skin_" + skin.to_html())
	var hair_m := MU.mat(hair, 0.75, 0.0, "hair_" + hair.to_html())
	var top_m := _fabric(top)
	var legs_m := _fabric(legs)
	var shoe_m := MU.mat(Color(0.06, 0.05, 0.05) if rng.randf() < 0.7 else Color(0.85, 0.85, 0.85), 0.5, 0.0, "")
	var lean := Basis(Vector3.RIGHT, rng.randf_range(-0.04, 0.04))
	var base := xf * Transform3D(lean.scaled(Vector3(s, s, s)), Vector3.ZERO)
	# shoes and legs (or a dress / long coat)
	for sx in [-1.0, 1.0]:
		b.box("p", shoe_m, Vector3(0.1, 0.07, 0.26), base * Transform3D(Basis(), Vector3(sx * 0.1, 0.035, 0.04)))
	if dress:
		b.cyl("p", top_m if era == "1930s" else legs_m, base * Transform3D(Basis(), Vector3(0, 0.62, 0)), 0.17, 0.27, 0.62, 10)
		for sx in [-1.0, 1.0]:
			b.cyl("p", skin_m if era == "modern" else legs_m, base * Transform3D(Basis(), Vector3(sx * 0.09, 0.2, 0)), 0.045, 0.05, 0.34, 6)
	else:
		for sx in [-1.0, 1.0]:
			b.cyl("p", legs_m, base * Transform3D(Basis(Vector3.BACK, sx * 0.03), Vector3(sx * 0.1, 0.45, 0)), 0.07, 0.065, 0.82, 8)
		b.box("p", legs_m, Vector3(0.36, 0.2, 0.22), base * Transform3D(Basis(), Vector3(0, 0.88, 0)))
	# torso, coat tails for the 1930s
	b.cyl("p", top_m, base * Transform3D(Basis().scaled(Vector3(1.0, 1.0, 0.62)), Vector3(0, 1.2, 0)), 0.2, 0.18, 0.56, 10)
	if era == "1930s" and not dress:
		b.cyl("p", top_m, base * Transform3D(Basis().scaled(Vector3(1.0, 1.0, 0.65)), Vector3(0, 0.8, 0)), 0.2, 0.22, 0.34, 10)
	# arms hanging, one sometimes bent (phone / bag)
	for sx in [-1.0, 1.0]:
		var bent: bool = sx > 0.0 and rng.randf() < 0.35
		if bent:
			b.cyl("p", top_m, base * Transform3D(Basis(Vector3.BACK, sx * 0.12), Vector3(sx * 0.25, 1.28, 0.0)), 0.05, 0.055, 0.3, 6)
			b.cyl("p", top_m, base * Transform3D(Basis(Vector3.RIGHT, 1.3), Vector3(sx * 0.27, 1.12, 0.12)), 0.045, 0.05, 0.28, 6)
			b.mesh("p", skin_m, _sphere(0.045), base * Transform3D(Basis(), Vector3(sx * 0.27, 1.14, 0.27)))
		else:
			b.cyl("p", top_m, base * Transform3D(Basis(Vector3.BACK, sx * 0.08), Vector3(sx * 0.26, 1.13, 0.0)), 0.045, 0.055, 0.58, 6)
			b.mesh("p", skin_m, _sphere(0.045), base * Transform3D(Basis(), Vector3(sx * 0.29, 0.82, 0.0)))
	# neck, head, hair or hat
	b.cyl("p", skin_m, base * Transform3D(Basis(), Vector3(0, 1.52, 0)), 0.05, 0.055, 0.1, 8)
	b.mesh("p", skin_m, _sphere(0.105), base * Transform3D(Basis().scaled(Vector3(0.92, 1.08, 1.0)), Vector3(0, 1.64, 0.0)))
	if era == "1930s" and (not dress or rng.randf() < 0.8):
		var hat_m := MU.mat(_pick([Color(0.08, 0.08, 0.08), Color(0.25, 0.2, 0.15), Color(0.35, 0.33, 0.3)]), 0.7, 0.0, "")
		if dress:
			b.cyl("p", hat_m, base * Transform3D(Basis(), Vector3(0, 1.74, 0)), 0.1, 0.12, 0.08, 12)
			b.cyl("p", hat_m, base * Transform3D(Basis(), Vector3(0, 1.71, 0)), 0.17, 0.17, 0.015, 14)
		else:
			b.cyl("p", hat_m, base * Transform3D(Basis(), Vector3(0, 1.77, 0)), 0.095, 0.11, 0.12, 12)
			b.cyl("p", hat_m, base * Transform3D(Basis(), Vector3(0, 1.715, 0)), 0.16, 0.16, 0.015, 14)
	else:
		b.mesh("p", hair_m, _sphere(0.112), base * Transform3D(Basis().scaled(Vector3(0.95, 0.8, 1.02)), Vector3(0, 1.69, -0.012)))
	# modern: backpacks; 1930s: suitcases
	if era == "modern" and rng.randf() < 0.35:
		b.box("p", _fabric(_pick([Color(0.1, 0.1, 0.1), Color(0.2, 0.3, 0.5), Color(0.5, 0.15, 0.1)])), Vector3(0.3, 0.4, 0.16), base * Transform3D(Basis(), Vector3(0, 1.2, -0.2)))
	elif era == "1930s" and rng.randf() < 0.4:
		var case_m := MU.mat(_pick([Color(0.35, 0.2, 0.1), Color(0.25, 0.15, 0.08), Color(0.5, 0.42, 0.3)]), 0.5, 0.0, "")
		b.box("p", case_m, Vector3(0.55, 0.38, 0.18), xf * Transform3D(Basis(), Vector3(0.45, 0.19, 0.1)))


static var _spheres := {}


static func _sphere(r: float) -> SphereMesh:
	var k := "%.3f" % r
	if not _spheres.has(k):
		var sm := SphereMesh.new()
		sm.radius = r
		sm.height = r * 2.0
		sm.radial_segments = 10
		sm.rings = 6
		_spheres[k] = sm
	return _spheres[k]
