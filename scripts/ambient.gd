class_name Ambient
extends Node3D
## Small life around the pond: dragonflies over the water, butterflies over the meadow.
## They only decorate; nothing in the game depends on them.

var _t := 0.0
var _flyers: Array[Dictionary] = []

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 133
	var wing := StandardMaterial3D.new()
	wing.albedo_color = Color(0.9, 0.97, 1.0, 0.4)
	wing.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wing.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wing.cull_mode = BaseMaterial3D.CULL_DISABLED
	var bodies := [Color(0.16, 0.55, 0.78), Color(0.80, 0.26, 0.20), Color(0.20, 0.62, 0.42), Color(0.86, 0.60, 0.16)]
	for i in 4:
		var ang := rng.randf() * TAU
		var r := rng.randf_range(1.5, 4.5)
		_add(_flyer(World.mat(bodies[i], 0.4), wing, Vector3(0.17, 0.008, 0.05), 0.2), {
			"centre": Vector3(cos(ang) * r, World.WATER_Y + 0.55, sin(ang) * r),
			"reach": Vector2(rng.randf_range(1.0, 2.0), rng.randf_range(0.8, 1.6)),
			"speed": rng.randf_range(0.7, 1.2), "phase": rng.randf() * TAU,
			"bob": 0.12, "flap": 0.0,
		})
	var petals := [Color(1.0, 0.82, 0.25), Color(0.98, 0.98, 0.94), Color(0.96, 0.55, 0.30), Color(0.72, 0.60, 0.95)]
	for i in 7:
		var ang := rng.randf() * TAU
		var r := rng.randf_range(8.6, 13.5)
		var m := StandardMaterial3D.new()
		m.albedo_color = petals[i % petals.size()]
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_add(_flyer(World.mat(Color(0.15, 0.12, 0.10)), m, Vector3(0.17, 0.008, 0.2), 0.16), {
			"centre": Vector3(cos(ang) * r, World.GROUND_Y + 0.75, sin(ang) * r),
			"reach": Vector2(rng.randf_range(0.8, 1.7), rng.randf_range(0.8, 1.7)),
			"speed": rng.randf_range(0.35, 0.6), "phase": rng.randf() * TAU,
			"bob": 0.3, "flap": rng.randf_range(11.0, 15.0),
		})

func _add(node: Node3D, info: Dictionary) -> void:
	info["node"] = node
	add_child(node)
	_flyers.append(info)

## A thin body with a wing on each side. The creature faces -Z.
func _flyer(body_mat: Material, wing_mat: Material, wing_size: Vector3, length: float) -> Node3D:
	var n := Node3D.new()
	n.add_child(World.limb(Vector3(0, 0, -length * 0.5), Vector3(0, 0, length * 0.5), 0.018, body_mat))
	for side in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.name = "L" if side < 0.0 else "R"
		var box := BoxMesh.new()
		box.size = wing_size
		var w := World.mesh_node(box, wing_mat, Vector3(side * wing_size.x * 0.5, 0, -length * 0.12))
		w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hinge.add_child(w)
		n.add_child(hinge)
	return n

func _spot(f: Dictionary, t: float) -> Vector3:
	var a: float = t * float(f["speed"]) + float(f["phase"])
	var reach: Vector2 = f["reach"]
	var c: Vector3 = f["centre"]
	return c + Vector3(cos(a) * reach.x + sin(a * 2.3) * 0.3, sin(a * 3.1) * float(f["bob"]), sin(a * 1.4) * reach.y)

func _process(delta: float) -> void:
	_t += delta
	for f in _flyers:
		var n: Node3D = f["node"]
		var here := _spot(f, _t)
		var ahead := _spot(f, _t + 0.08)
		n.position = here
		if here.distance_to(ahead) > 0.001:
			n.look_at(ahead)
		var flap: float = f["flap"]
		var lift := sin(_t * flap + float(f["phase"])) * 0.9 if flap > 0.0 else sin(_t * 60.0) * 0.12
		(n.get_node("L") as Node3D).rotation.z = -lift
		(n.get_node("R") as Node3D).rotation.z = lift
