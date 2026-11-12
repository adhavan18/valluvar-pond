class_name Valluvar
extends Node3D
## Thiruvalluvar, seated cross-legged on the bank with a bamboo rod: an original low-poly figure
## built from primitives (white beard, topknot, cream dhoti, a palm leaf on his lap).
## If res://models/valluvar.glb exists (made in Blender), it replaces the body.

var rod_tip: Marker3D
var _rod: Node3D
var _body: Node3D
var _t := 0.0

func _ready() -> void:
	var skin := World.mat(Color(0.71, 0.49, 0.32))
	var cloth := World.mat(Color(0.96, 0.93, 0.84))
	var hair := World.mat(Color(0.94, 0.94, 0.91))
	var dark := World.mat(Color(0.12, 0.09, 0.07))
	var mat_red := World.mat(Color(0.62, 0.17, 0.14))
	var leaf := World.mat(Color(0.85, 0.72, 0.45))
	var bamboo := World.mat(Color(0.66, 0.52, 0.26))
	var thread := World.mat(Color(0.98, 0.96, 0.9))

	# A woven mat to sit on.
	var seat := CylinderMesh.new()
	seat.top_radius = 0.85
	seat.bottom_radius = 0.85
	seat.height = 0.05
	add_child(World.mesh_node(seat, mat_red, Vector3(0, 0.03, 0)))

	_body = Node3D.new()
	add_child(_body)
	if ResourceLoader.exists("res://models/valluvar.glb"):
		var scene: PackedScene = load("res://models/valluvar.glb")
		_body.add_child(scene.instantiate())
	else:
		_build_body(skin, cloth, hair, dark, leaf, thread)

	# The rod, held in the right hand, reaching out over the water (local +Z is forward).
	_rod = Node3D.new()
	_rod.position = Vector3(0.42, 0.86, 0.5)
	add_child(_rod)
	var tip_local := Vector3(0.25, 1.5, 2.5)
	_rod.add_child(World.limb(Vector3(0, -0.15, -0.25), tip_local, 0.03, bamboo, 0.012))
	rod_tip = Marker3D.new()
	rod_tip.position = tip_local
	_rod.add_child(rod_tip)

func _build_body(skin: Material, cloth: Material, hair: Material, dark: Material, leaf: Material, thread: Material) -> void:
	# Crossed legs under the dhoti.
	var lap := SphereMesh.new()
	lap.radius = 0.5
	lap.height = 1.0
	var lap_n := World.mesh_node(lap, cloth, Vector3(0, 0.22, 0.12))
	lap_n.scale = Vector3(1.25, 0.42, 1.0)
	_body.add_child(lap_n)
	for side in [-1.0, 1.0]:
		_body.add_child(World.limb(Vector3(0.5 * side, 0.2, 0.15), Vector3(-0.1 * side, 0.2, 0.55), 0.11, cloth))
		var foot := SphereMesh.new()
		foot.radius = 0.1
		foot.height = 0.2
		_body.add_child(World.mesh_node(foot, skin, Vector3(-0.2 * side, 0.2, 0.6)))
	# Torso, bare-chested, with the cloth over the left shoulder and the sacred thread.
	var torso := CapsuleMesh.new()
	torso.radius = 0.3
	torso.height = 0.95
	_body.add_child(World.mesh_node(torso, skin, Vector3(0, 0.78, 0)))
	_body.add_child(World.limb(Vector3(-0.3, 1.16, 0.02), Vector3(0.22, 0.42, 0.2), 0.085, cloth))
	_body.add_child(World.limb(Vector3(-0.24, 1.18, 0.2), Vector3(0.2, 0.5, 0.27), 0.012, thread))
	# Head, beard, hair and topknot.
	var head := SphereMesh.new()
	head.radius = 0.25
	head.height = 0.52
	_body.add_child(World.mesh_node(head, skin, Vector3(0, 1.45, 0.02)))
	var beard := SphereMesh.new()
	beard.radius = 0.2
	beard.height = 0.4
	var beard_n := World.mesh_node(beard, hair, Vector3(0, 1.27, 0.15))
	beard_n.scale = Vector3(0.95, 1.35, 0.7)
	_body.add_child(beard_n)
	var cap := SphereMesh.new()
	cap.radius = 0.265
	cap.height = 0.53
	var cap_n := World.mesh_node(cap, hair, Vector3(0, 1.5, -0.05))
	cap_n.scale = Vector3(1.0, 0.9, 1.0)
	_body.add_child(cap_n)
	var bun := SphereMesh.new()
	bun.radius = 0.12
	bun.height = 0.24
	_body.add_child(World.mesh_node(bun, hair, Vector3(0, 1.78, -0.04)))
	for side in [-1.0, 1.0]:
		var eye := SphereMesh.new()
		eye.radius = 0.025
		eye.height = 0.05
		_body.add_child(World.mesh_node(eye, dark, Vector3(0.09 * side, 1.47, 0.245)))
		# Three lines of sacred ash become one pale band on the forehead.
	_body.add_child(World.limb(Vector3(-0.12, 1.56, 0.215), Vector3(0.12, 1.56, 0.215), 0.014, hair))
	# Arms: the right holds the rod, the left rests on a palm leaf in the lap.
	_body.add_child(World.limb(Vector3(0.33, 1.1, 0), Vector3(0.46, 0.8, 0.22), 0.075, skin))
	_body.add_child(World.limb(Vector3(0.46, 0.8, 0.22), Vector3(0.42, 0.86, 0.5), 0.065, skin))
	_body.add_child(World.limb(Vector3(-0.33, 1.1, 0), Vector3(-0.45, 0.72, 0.2), 0.075, skin))
	_body.add_child(World.limb(Vector3(-0.45, 0.72, 0.2), Vector3(-0.2, 0.5, 0.45), 0.065, skin))
	var olai := BoxMesh.new()
	olai.size = Vector3(0.62, 0.02, 0.15)
	var olai_n := World.mesh_node(olai, leaf, Vector3(-0.05, 0.46, 0.5))
	olai_n.rotation = Vector3(0.1, 0.25, 0)
	_body.add_child(olai_n)

func _process(delta: float) -> void:
	_t += delta
	# Breathing, and the rod riding gently.
	_body.scale.y = 1.0 + sin(_t * 1.6) * 0.012
	if not _busy:
		_rod.rotation.x = sin(_t * 1.1) * 0.02

var _busy := false

## Whip the rod back and forward for a cast.
func cast_swing() -> void:
	_swing(-0.55, 0.12, 0.35)

## Heave the rod up for a catch.
func strike() -> void:
	_swing(-0.75, 0.0, 0.5)

func _swing(back: float, forward: float, time: float) -> void:
	_busy = true
	var tw := create_tween()
	tw.tween_property(_rod, "rotation:x", back, time * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_rod, "rotation:x", forward, time * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_rod, "rotation:x", 0.0, time * 0.25)
	tw.tween_callback(func() -> void: _busy = false)
