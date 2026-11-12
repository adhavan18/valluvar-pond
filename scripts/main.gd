extends Node3D
## Valluvar's Pond. Thiruvalluvar sits on the bank and fishes for the word missing from a Kural.
## The game itself is scripts/fishing.gd; this script builds the scene around it.
## (The larger version, with a map to walk and two more games, is on the `full-map` branch.)

const POND_CAM := Vector3(0.3, 8.4, 11.9)
const POND_LOOK := Vector3(-0.5, 0.0, -0.2)

var hud: Hud
var camera: Camera3D
var sun: DirectionalLight3D
var env: Environment
var seated: Valluvar
var fishing: Fishing
var bright := 1.0   # scales the storm lighting on the Compatibility renderer
var _shot_path := ""

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
	hud.start_pressed.connect(func() -> void:
		Sfx.play("click")
		fishing._start_game())
	hud.set_mode("fishing")
	hud.hide_leave()
	hud.set_hearts(3)
	fishing.start()

	var shot_delay := 3.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot_path = arg.trim_prefix("--shot=")
		elif arg == "--autoplay":
			fishing._start_game()
		elif arg == "--demo":            # plays itself, for testing
			fishing.demo = true
			fishing._start_game()
			shot_delay = 9.0
	if _shot_path != "":
		get_tree().create_timer(shot_delay).timeout.connect(_save_shot)

func _save_shot() -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_shot_path)
	get_tree().quit()

func _process(_delta: float) -> void:
	hud.set_wisdom(Data.wisdom)
	_fit_camera()

## On narrow or upright screens the camera steps back, so the whole pond and Valluvar stay in view.
func _fit_camera() -> void:
	var size := get_viewport().get_visible_rect().size
	var aspect := size.x / maxf(size.y, 1.0)
	# Upright phones: enlarge the interface so text stays readable, and re-flow it.
	var ui := clampf(1.5 / aspect, 1.0, 2.2)
	if absf(get_window().content_scale_factor - ui) > 0.01:
		get_window().content_scale_factor = ui
	hud.fit(get_viewport().get_visible_rect().size.x)
	var back := clampf(1.98 / aspect, 1.0, 2.7)
	Fish.label_boost = lerpf(1.0, back, 0.75)
	camera.position = POND_LOOK + (POND_CAM - POND_LOOK) * back
	camera.look_at(POND_LOOK)

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
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)

	# Browsers (and older phones) use the simpler Compatibility renderer, which has no filmic
	# tone mapping: the same lights come out much brighter there, so they are turned down.
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		sun.light_energy = 0.62
		env.ambient_light_energy = 0.42
		env.fog_enabled = false
		bright = 0.5

	camera = Camera3D.new()
	camera.fov = 46
	camera.position = POND_CAM
	add_child(camera)
	camera.look_at(POND_LOOK)

	var world_rng := RandomNumberGenerator.new()
	world_rng.seed = 1330
	World.build(self, world_rng)

	seated = Valluvar.new()
	seated.position = World.seat_pos()
	add_child(seated)
	seated.look_at(Vector3(seated.position.x * 2.0, World.GROUND_Y, seated.position.z * 2.0 - 0.6))
	seated.scale = Vector3.ONE * 1.25
