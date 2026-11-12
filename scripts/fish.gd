class_name Fish
extends Node3D
## A fish that carries one Tamil word. It wanders the pond, notices the bobber, bites, and
## is either landed (the right word) or wriggles free.

enum State { WANDER, CHASE, BITING, FLEE, CAUGHT }

const DEPTH := World.WATER_Y - 0.13

var word := ""
var golden := false
var state: int = State.WANDER
var speed := 1.2
var target := Vector3.ZERO
var label: Label3D
var _tail: Node3D
var _t := 0.0
var _rng := RandomNumberGenerator.new()

func setup(p_word: String, color: Color, font: Font, p_golden: bool = false) -> void:
	word = p_word
	golden = p_golden
	_rng.randomize()
	var body_mat := World.mat(color, 0.35)
	if golden:
		body_mat.emission_enabled = true
		body_mat.emission = Color(1.0, 0.75, 0.2)
		body_mat.emission_energy_multiplier = 0.9
	var body := SphereMesh.new()
	body.radius = 0.5
	body.height = 1.0
	body.radial_segments = 10
	body.rings = 6
	var b := World.mesh_node(body, body_mat)
	b.scale = Vector3(0.36, 0.42, 0.95)
	add_child(b)
	# Tail (wags) and a back fin. The fish faces -Z.
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0, 0.42)
	add_child(_tail)
	var tail := CylinderMesh.new()
	tail.top_radius = 0.0
	tail.bottom_radius = 0.24
	tail.height = 0.4
	tail.radial_segments = 4
	var t := World.mesh_node(tail, body_mat, Vector3(0, 0, 0.16))
	t.rotation = Vector3(-PI / 2, 0, 0)
	t.scale = Vector3(0.3, 1, 1)
	_tail.add_child(t)
	var fin := CylinderMesh.new()
	fin.top_radius = 0.0
	fin.bottom_radius = 0.14
	fin.height = 0.2
	fin.radial_segments = 4
	var f := World.mesh_node(fin, body_mat, Vector3(0, 0.22, 0.0))
	f.scale = Vector3(0.25, 1, 1)
	add_child(f)
	for side in [-1.0, 1.0]:
		var eye := SphereMesh.new()
		eye.radius = 0.035
		eye.height = 0.07
		add_child(World.mesh_node(eye, World.mat(Color(0.08, 0.06, 0.05)), Vector3(0.12 * side, 0.06, -0.33)))
	# The word, always facing the camera, readable above the water.
	label = Label3D.new()
	label.text = word
	label.font = font
	label.font_size = 64
	label.pixel_size = 0.0058
	label.outline_size = 30
	label.modulate = Color(1.0, 0.9, 0.55) if golden else Color(1.0, 0.98, 0.92)
	label.outline_modulate = Color(0.16, 0.09, 0.04, 0.95)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 10
	label.outline_render_priority = 9
	label.position = Vector3(0, 0.85, 0)
	add_child(label)
	_pick_target()

func _pick_target() -> void:
	var ang := _rng.randf() * TAU
	var r := _rng.randf_range(0.6, World.pond_radius(ang) - 1.5)
	target = Vector3(cos(ang) * r, DEPTH, sin(ang) * r)

func chase(point: Vector3) -> void:
	if state == State.WANDER:
		state = State.CHASE
		target = Vector3(point.x, DEPTH, point.z)

func lose_interest() -> void:
	if state == State.CHASE or state == State.BITING:
		state = State.WANDER
		_pick_target()

func flee() -> void:
	state = State.FLEE
	_pick_target()
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_callback(func() -> void:
		if state == State.FLEE:
			state = State.WANDER)

func flash(color: Color) -> void:
	var base := label.modulate
	label.modulate = color
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(label, "modulate", base, 0.4)

func _process(delta: float) -> void:
	_t += delta
	if state == State.CAUGHT:
		_tail.rotation.y = sin(_t * 30.0) * 0.7
		return
	var s := speed
	if state == State.CHASE:
		s *= 1.7
	elif state == State.FLEE:
		s *= 3.0
	elif state == State.BITING:
		s = 0.0
	var to := target - position
	to.y = 0
	if to.length() < 0.25:
		if state == State.WANDER or state == State.FLEE:
			_pick_target()
	elif s > 0.0:
		var want := atan2(-to.x, -to.z)
		rotation.y = lerp_angle(rotation.y, want, clampf(delta * 3.5, 0.0, 1.0))
		position += -global_transform.basis.z * s * delta
		position.y = DEPTH + sin(_t * 2.0) * 0.02
	_tail.rotation.y = sin(_t * (6.0 + s * 4.0)) * 0.45
	if state == State.BITING:
		position.y = DEPTH + sin(_t * 26.0) * 0.03
