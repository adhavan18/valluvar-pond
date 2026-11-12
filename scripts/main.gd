extends Node3D
## Valluvar's world. Thiruvalluvar walks a small map (meadow, pond, a school under a banyan
## tree, a scribe's hut) and plays a different Kural game at each place:
##   the pond   — fish for the word missing from a Kural       (scripts/fishing.gd)
##   the school — choose the second line of a Kural            (scripts/minigames.gd)
##   the hut    — write a Kural by tapping its words in order  (scripts/minigames.gd)
## Every game earns wisdom (ஞானம்), which is saved.

enum Mode { EXPLORE, FISHING, MINI }

const CAM_OFFSET := Vector3(0, 10.5, 11.5)
const POND_CAM := Vector3(0.3, 8.4, 11.9)
const POND_LOOK := Vector3(-0.5, 0.0, -0.2)
const ACTIONS := { "pond": "Sit and fish", "school": "Teach at the school", "hut": "Visit the scribe" }

var mode: int = Mode.EXPLORE
var near := ""
var hud: Hud
var camera: Camera3D
var sun: DirectionalLight3D
var env: Environment
var player: Player
var seated: Valluvar
var fishing: Fishing
var mini: Minigames
var markers := {}
var _cam_tween: Tween
var _hint_time := 6.0
var _shot_path := ""
var _t := 0.0
var _back := 1.0   # how far the pond camera steps back on narrow screens
var bright := 1.0   # scales the storm lighting on the Compatibility renderer

func _ready() -> void:
	Data.load_all()
	add_child(Sfx.new())
	hud = Hud.new()
	add_child(hud)
	_build_scene()

	fishing = Fishing.new()
	add_child(fishing)
	fishing.setup(hud, camera, seated, sun, env)
	fishing.light_scale = bright
	mini = Minigames.new()
	add_child(mini)
	mini.setup(hud.tamil, hud.latin)
	DisplayServer.tts_get_voices()   # wakes the voice list early, ready for the first word

	hud.start_pressed.connect(func() -> void:
		Sfx.play("click")
		if mode == Mode.FISHING:
			fishing._start_game())
	hud.action_pressed.connect(func() -> void: _enter(near))
	hud.leave_pressed.connect(_leave)
	mini.closed.connect(_leave)
	hud.hide_panel()
	hud.set_mode("explore")
	hud.set_hearts(3)
	hud.prompt("Tap the ground or use the arrow keys to walk")

	var shot_delay := 3.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot_path = arg.trim_prefix("--shot=")
		elif arg.begins_with("--at="):          # start standing at a place: pond, school, hut
			var where: String = arg.trim_prefix("--at=")
			var e := World.entries()
			if e.has(where):
				player.position = e[where]
		elif arg.begins_with("--enter="):       # ...and go straight into its game
			var id: String = arg.trim_prefix("--enter=")
			player.position = World.entries()[id]
			_enter(id)
			if id == "pond":
				fishing._start_game()
		elif arg == "--demo":
			fishing.demo = true
			shot_delay = 9.0
		elif arg == "--closeup":
			camera.position = player.position + Vector3(2.4, 2.4, 4.2)
			camera.look_at(player.position + Vector3(0, 1.3, 0))
			hud.visible = false
			set_process(false)
	if _shot_path != "":
		get_tree().create_timer(shot_delay).timeout.connect(_save_shot)

func _save_shot() -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_shot_path)
	get_tree().quit()

func _build_scene() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.8, 0.86)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.82, 0.86, 0.8)
	env.ambient_light_energy = 0.75
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.84, 0.86)
	env.fog_density = 0.0035
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_color = Color(1.0, 0.95, 0.84)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)

	# Browsers (and older phones) use the simpler Compatibility renderer, which has no filmic
	# tone mapping: the same lights come out much brighter there, so they are turned down.
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		sun.light_energy = 0.62
		env.ambient_light_energy = 0.42
		env.fog_enabled = false
		bright = 0.5

	var world_rng := RandomNumberGenerator.new()
	world_rng.seed = 1330
	World.build(self, world_rng)
	World.build_places(self, hud.tamil)

	# Valluvar seated at the pond (shown only while fishing).
	seated = Valluvar.new()
	seated.position = World.seat_pos()
	add_child(seated)
	seated.look_at(Vector3(seated.position.x * 2.0, World.GROUND_Y, seated.position.z * 2.0 - 0.6))
	seated.scale = Vector3.ONE * 1.25
	seated.visible = false
	World.obstacles.append(Vector3(seated.position.x, seated.position.z, 1.0))

	player = Player.new()
	player.position = World.SPAWN
	add_child(player)

	camera = Camera3D.new()
	camera.fov = 46
	add_child(camera)
	camera.position = player.position + CAM_OFFSET
	camera.look_at(player.position + Vector3(0, 1.2, 0))

	# A glowing ring on the ground where each place is entered.
	var e := World.entries()
	for id: String in e:
		var ring := TorusMesh.new()
		ring.inner_radius = 1.05
		ring.outer_radius = 1.25
		ring.rings = 32
		ring.ring_segments = 6
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.98, 0.78, 0.3, 0.8)
		var node := World.mesh_node(ring, m, e[id] + Vector3(0, 0.05, 0))
		node.scale = Vector3(1, 0.15, 1)
		add_child(node)
		markers[id] = node

# ---------- moving between the map and the games ----------

func _enter(id: String) -> void:
	if mode != Mode.EXPLORE or not ACTIONS.has(id):
		return
	Sfx.play("enter")
	player.halt()
	player.frozen = true
	hud.set_action("")
	hud.prompt("")
	if id == "pond":
		mode = Mode.FISHING
		player.visible = false
		seated.visible = true
		hud.set_mode("fishing")
		var goal := Transform3D(Basis(), POND_LOOK + (POND_CAM - POND_LOOK) * _back).looking_at(POND_LOOK, Vector3.UP)
		if _cam_tween:
			_cam_tween.kill()
		_cam_tween = create_tween()
		_cam_tween.tween_property(camera, "global_transform", goal, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		fishing.start()
	else:
		mode = Mode.MINI
		mini.open(id)

func _leave() -> void:
	if mode == Mode.FISHING:
		fishing.stop()
		seated.visible = false
		player.visible = true
		hud.set_mode("explore")
	if _cam_tween:
		_cam_tween.kill()
	mode = Mode.EXPLORE
	player.frozen = false
	Sfx.play("click")
	Data.save()

func _unhandled_input(event: InputEvent) -> void:
	if mode != Mode.EXPLORE:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var from := camera.project_ray_origin(event.position)
		var dir := camera.project_ray_normal(event.position)
		if dir.y < -0.001:
			var p := from + dir * ((World.GROUND_Y - from.y) / dir.y)
			player.walk_to(p)
			_tap_mark(p)
	elif event is InputEventKey and event.pressed and not event.echo:
		if near != "" and event.keycode in [KEY_E, KEY_ENTER, KEY_SPACE]:
			_enter(near)

## Upright phones: enlarge the interface so text stays readable, re-flow it, and widen the pond view.
func _fit_screen() -> void:
	var size := get_viewport().get_visible_rect().size
	var aspect := size.x / maxf(size.y, 1.0)
	var ui := clampf(1.5 / aspect, 1.0, 2.2)
	if absf(get_window().content_scale_factor - ui) > 0.01:
		get_window().content_scale_factor = ui
	var w := get_viewport().get_visible_rect().size.x
	hud.fit(w)
	mini.fit(w)
	_back = clampf(1.98 / aspect, 1.0, 2.7)
	Fish.label_boost = lerpf(1.0, _back, 0.75) if mode == Mode.FISHING else 1.0

## A small ring where the ground was tapped.
func _tap_mark(at: Vector3) -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.3
	ring.outer_radius = 0.36
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1, 1, 1, 0.8)
	var node := World.mesh_node(ring, m, Vector3(at.x, World.GROUND_Y + 0.04, at.z))
	node.scale = Vector3(1, 0.1, 1)
	add_child(node)
	var tw := create_tween().set_parallel()
	tw.tween_property(node, "scale", Vector3(0.3, 0.1, 0.3), 0.5)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.5)
	tw.chain().tween_callback(node.queue_free)

func _process(delta: float) -> void:
	_t += delta
	_fit_screen()
	hud.set_wisdom(Data.wisdom)
	for id: String in markers:
		var node: MeshInstance3D = markers[id]
		node.visible = mode == Mode.EXPLORE
		var s := 1.0 + sin(_t * 3.0) * 0.08
		node.scale = Vector3(s, 0.15, s)
	if mode != Mode.EXPLORE:
		return
	# The camera follows from above and behind.
	var want := player.position + CAM_OFFSET
	camera.position = camera.position.lerp(want, clampf(delta * 4.0, 0, 1))
	camera.look_at(camera.position - CAM_OFFSET + Vector3(0, 1.2, 0))
	# What can be done here?
	var found := ""
	var e := World.entries()
	for id: String in e:
		var p: Vector3 = e[id]
		if Vector2(player.position.x - p.x, player.position.z - p.z).length() < 2.4:
			found = id
	if found != near:
		near = found
		hud.set_action(str(ACTIONS.get(near, "")))
		if near != "":
			Sfx.play("click", 1.4, -12.0)
	if _hint_time > 0.0:
		_hint_time -= delta
		if player.moving or _hint_time <= 0.0:
			_hint_time = 0.0
			hud.prompt("")
