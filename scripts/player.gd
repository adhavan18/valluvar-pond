class_name Player
extends Node3D
## Thiruvalluvar on foot. Walks with the arrow keys / WASD, or to wherever the ground is
## tapped. He is solid: trees, rocks, buildings, signposts and the pond all stop him, and he
## slides along them rather than passing through.

const SPEED := 5.4
const RADIUS := 0.5
const MAP_RADIUS := 47.0

var target: Variant = null   # Vector3 to walk to, or null
var frozen := false
var moving := false
var _model: Node3D
var _t := 0.0
var _step := 0.0
var _stuck := 0.0

func _ready() -> void:
	_model = Node3D.new()
	add_child(_model)
	if ResourceLoader.exists("res://models/valluvar_walk.glb"):
		var scene: PackedScene = load("res://models/valluvar_walk.glb")
		_model.add_child(scene.instantiate())
	else:
		# Stand-in until the Blender model exists.
		var body := CapsuleMesh.new()
		body.radius = 0.32
		body.height = 1.5
		_model.add_child(World.mesh_node(body, World.mat(Color(0.94, 0.9, 0.8)), Vector3(0, 0.75, 0)))
		var head := SphereMesh.new()
		head.radius = 0.25
		head.height = 0.5
		_model.add_child(World.mesh_node(head, World.mat(Color(0.4, 0.22, 0.12)), Vector3(0, 1.7, 0)))
	_model.scale = Vector3.ONE * 1.15
	# A soft shadow blob keeps him grounded even where the sun's shadow is faint.
	var blob := CylinderMesh.new()
	blob.top_radius = 0.55
	blob.bottom_radius = 0.55
	blob.height = 0.01
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.albedo_color = Color(0, 0, 0, 0.22)
	add_child(World.mesh_node(blob, bm, Vector3(0, 0.02, 0)))

func walk_to(point: Vector3) -> void:
	target = Vector3(point.x, World.GROUND_Y, point.z)
	_stuck = 0.0

func halt() -> void:
	target = null
	moving = false

func _key_vector() -> Vector3:
	var x := Input.get_axis("ui_left", "ui_right")
	var z := Input.get_axis("ui_up", "ui_down")
	if Input.is_physical_key_pressed(KEY_A): x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): x += 1.0
	if Input.is_physical_key_pressed(KEY_W): z -= 1.0
	if Input.is_physical_key_pressed(KEY_S): z += 1.0
	return Vector3(clampf(x, -1, 1), 0, clampf(z, -1, 1))

func _process(delta: float) -> void:
	var dir := Vector3.ZERO
	if not frozen:
		var keys := _key_vector()
		if keys.length() > 0.1:
			target = null
			dir = keys.normalized()
		elif target != null:
			var to: Vector3 = target - position
			to.y = 0
			if to.length() < 0.3:
				target = null
			else:
				dir = to.normalized()
	moving = dir != Vector3.ZERO
	if moving:
		var before := position
		position = _resolve(position + dir * SPEED * delta)
		# Blocked on the way to a tapped point: give up rather than push forever.
		if target != null and position.distance_to(before) < SPEED * delta * 0.25:
			_stuck += delta
			if _stuck > 0.5:
				target = null
		else:
			_stuck = 0.0
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), clampf(delta * 10.0, 0, 1))
		_step += delta
		if _step > 0.34:
			_step = 0.0
			Sfx.play("step", randf_range(0.85, 1.15), -15.0)
	_t += delta * (10.0 if moving else 1.6)
	_model.position.y = absf(sin(_t)) * 0.08 if moving else 0.0
	_model.rotation.z = sin(_t) * 0.05 if moving else 0.0
	_model.scale.y = 1.15 * (1.0 + (0.0 if moving else sin(_t) * 0.01))

## Pushes a wanted position out of everything solid.
func _resolve(p: Vector3) -> Vector3:
	var flat := Vector2(p.x, p.z)
	if flat.length() > MAP_RADIUS:
		flat = flat.normalized() * MAP_RADIUS
	# The pond: he walks its bank, not its water.
	var bank := World.pond_radius(atan2(flat.y, flat.x)) + 0.8
	if flat.length() < bank and flat.length() > 0.001:
		flat = flat.normalized() * bank
	for o in World.obstacles:
		var c := Vector2(o.x, o.y)
		var d := flat - c
		var min_d := o.z + RADIUS
		if d.length() < min_d and d.length() > 0.001:
			flat = c + d.normalized() * min_d
	return Vector3(flat.x, World.GROUND_Y, flat.y)
