class_name Fishing
extends Node3D
## The pond game. Thiruvalluvar fishes for the word missing from a Kural.
## Tap the water to cast; when a fish bites, tap to hook it. The right word lands the fish
## and completes the couplet; the wrong one costs a heart. Streaks speed the pond up, every
## fifth Kural is a storm round, and a golden fish brings a heart and time.

signal left

enum State { MENU, IDLE, CASTING, WAITING, BITE, LANDING, OVER }

const START_TIME := 75.0
const MAX_TIME := 90.0
const FISH_COUNT := 5
const FISH_COLORS := [Color(0.95, 0.52, 0.2), Color(0.96, 0.93, 0.88), Color(0.86, 0.26, 0.2), Color(0.98, 0.72, 0.3), Color(0.9, 0.6, 0.5)]


var rng := RandomNumberGenerator.new()

var state: int = State.MENU
var score := 0
var best := 0
var streak := 0
var hearts := 3
var caught := 0
var round_no := 0
var time_left := START_TIME
var storm := false

var q_kural: Dictionary = {}
var q_lines: Array = []
var q_line := 0
var q_index := 0
var answer := ""

var fishes: Array[Fish] = []
var golden: Fish = null
var golden_timer := 14.0
var biter: Fish = null
var bite_timer := 0.0

var hud: Hud
var camera: Camera3D
var valluvar: Valluvar
var bobber: MeshInstance3D
var line_mesh: ImmediateMesh
var line_mat: StandardMaterial3D
var sun: DirectionalLight3D
var rain: CPUParticles3D
var env: Environment
var bobber_rest := true

var active := false
var light_scale := 1.0   # 0.5 on the Compatibility renderer (browsers), set by main
var demo := false   # plays itself (casts at the right fish, hooks on the bite), for testing

func setup(p_hud: Hud, p_camera: Camera3D, p_valluvar: Valluvar, p_sun: DirectionalLight3D, p_env: Environment) -> void:
	hud = p_hud
	camera = p_camera
	valluvar = p_valluvar
	sun = p_sun
	env = p_env
	rng.randomize()
	best = Data.best_fishing
	_build_scene()
	bobber.visible = false

func start() -> void:
	active = true
	bobber.visible = true
	_menu()

func stop() -> void:
	active = false
	state = State.MENU
	_set_storm(false)
	for f in fishes:
		f.queue_free()
	fishes.clear()
	if golden:
		golden.queue_free()
		golden = null
	bobber.visible = false
	line_mesh.clear_surfaces()
	hud.hide_panel()
	hud.prompt("")

func _save_best() -> void:
	Data.best_fishing = best
	Data.save()

# ---------- scene ----------

func _build_scene() -> void:
	var bob := SphereMesh.new()
	bob.radius = 0.13
	bob.height = 0.26
	var bob_mat := World.mat(Color(0.86, 0.2, 0.16), 0.3)
	bobber = World.mesh_node(bob, bob_mat)
	var cap := SphereMesh.new()
	cap.radius = 0.09
	cap.height = 0.18
	bobber.add_child(World.mesh_node(cap, World.mat(Color(1, 1, 0.96), 0.3), Vector3(0, 0.08, 0)))
	add_child(bobber)

	line_mesh = ImmediateMesh.new()
	line_mat = StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.albedo_color = Color(0.98, 0.96, 0.9)
	var line_node := MeshInstance3D.new()
	line_node.mesh = line_mesh
	line_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(line_node)

	rain = CPUParticles3D.new()
	rain.emitting = false
	rain.amount = 420
	rain.lifetime = 0.9
	rain.position = Vector3(0, 11, 0)
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(13, 0.2, 11)
	rain.direction = Vector3(0.15, -1, 0)
	rain.spread = 2.0
	rain.gravity = Vector3(0, -30, 0)
	rain.initial_velocity_min = 12.0
	rain.initial_velocity_max = 16.0
	var drop := BoxMesh.new()
	drop.size = Vector3(0.015, 0.34, 0.015)
	rain.mesh = drop
	var drop_mat := StandardMaterial3D.new()
	drop_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop_mat.albedo_color = Color(0.85, 0.92, 1.0, 0.7)
	drop_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rain.material_override = drop_mat
	add_child(rain)

# ---------- flow ----------

func _menu() -> void:
	state = State.MENU
	hud.show_kural([["வள்ளுவர்", "குளம்"]], -1, -1, false, "Valluvar’s Pond", "")
	hud.show_panel("வள்ளுவர் குளம்",
		"Each Kural is missing a word, and the fish are carrying words.\n\nTap the water to cast near the right fish. When it bites, tap again to hook it. A wrong fish costs a heart; tap while waiting to reel back in.\n\nBest score: %d" % best,
		"Start fishing")
	hud.prompt("")

func _start_game() -> void:
	score = 0
	streak = 0
	hearts = 3
	caught = 0
	round_no = 0
	time_left = START_TIME
	golden_timer = 14.0
	hud.hide_panel()
	hud.set_hearts(hearts)
	hud.set_score(score, streak)
	_next_round()

func _next_round() -> void:
	round_no += 1
	storm = round_no % 5 == 0
	_set_storm(storm)
	_make_question()
	_spawn_fish()
	_rest_bobber()
	state = State.IDLE
	hud.show_kural(q_lines, q_line, q_index, false, str(q_kural["en"]), "Kural %d · %s" % [int(q_kural["id"]), str(q_kural["chTa"])])
	hud.prompt("Tap the water to cast")
	if storm:
		hud.banner("புயல்!  ×2", Color(0.75, 0.9, 1.0))
		Sfx.play("thunder", 1.0, -2.0)

func _make_question() -> void:
	# Early rounds draw from the first, best-known chapters; then the whole book opens up.
	var limit: int = mini(Data.kurals.size(), 100 + round_no * 60)
	q_kural = Data.kurals[rng.randi() % limit]
	q_lines = []
	var spots: Array = []
	var raw_lines := str(q_kural["ta"]).split("\n")
	for li in raw_lines.size():
		var words := Data.words(raw_lines[li])
		q_lines.append(words)
		for wi in words.size():
			if words[wi].length() >= 3:
				spots.append([li, wi])
	var spot: Array = spots[rng.randi() % spots.size()]
	q_line = spot[0]
	q_index = spot[1]
	answer = q_lines[q_line][q_index]

func _spawn_fish() -> void:
	for f in fishes:
		f.queue_free()
	fishes.clear()
	var in_verse := {}
	for l: Array in q_lines:
		for w: String in l:
			in_verse[w] = true
	var words: Array[String] = [answer]
	while words.size() < FISH_COUNT:
		var w: String = Data.word_pool[rng.randi() % Data.word_pool.size()]
		if not in_verse.has(w) and not words.has(w) and absi(w.length() - answer.length()) <= 4:
			words.append(w)
	words.shuffle()
	for i in words.size():
		var f := Fish.new()
		add_child(f)
		f.setup(words[i], FISH_COLORS[i % FISH_COLORS.size()], hud.tamil)
		var ang := TAU * i / words.size() + rng.randf() * 0.6
		var r := rng.randf_range(2.6, 4.8)
		f.position = Vector3(cos(ang) * r, Fish.DEPTH, sin(ang) * r)
		f.rotation.y = rng.randf() * TAU
		f.speed = _fish_speed()
		fishes.append(f)

func _fish_speed() -> float:
	return (0.85 + minf(streak, 12) * 0.09) * (1.5 if storm else 1.0)

func _set_storm(on: bool) -> void:
	rain.emitting = on
	var tw := create_tween().set_parallel()
	tw.tween_property(sun, "light_energy", (0.5 if on else 1.25) * light_scale, 0.8)
	tw.tween_property(env, "background_color", Color(0.36, 0.44, 0.5) if on else Color(0.62, 0.8, 0.86), 0.8)
	tw.tween_property(env, "ambient_light_energy", (0.5 if on else 0.75) * (0.56 if light_scale < 1.0 else 1.0), 0.8)

func _game_over(reason: String) -> void:
	state = State.OVER
	Sfx.play("over")
	Data.save()
	_set_storm(false)
	_rest_bobber()
	if score > best:
		best = score
		_save_best()
	hud.prompt("")
	hud.show_panel(reason, "Kurals completed: %d\nScore: %d\nBest: %d" % [caught, score, best], "Fish again")

# ---------- input ----------

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	match state:
		State.IDLE:
			var hit: Variant = _water_point(event.position)
			if hit != null:
				_cast(hit)
		State.WAITING:
			_reel_back()
		State.BITE:
			_hook()

## Where a screen point meets the water, if that is inside the pond.
func _water_point(screen: Vector2) -> Variant:
	var from := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	if absf(dir.y) < 0.001:
		return null
	var t := (World.WATER_Y - from.y) / dir.y
	if t < 0.0:
		return null
	var p := from + dir * t
	return p if World.in_pond(p, 0.6) else null

# ---------- fishing ----------

func _rest_bobber() -> void:
	bobber_rest = true
	for f in fishes:
		f.lose_interest()

func _cast(point: Vector3) -> void:
	state = State.CASTING
	bobber_rest = false
	valluvar.cast_swing()
	Sfx.play("cast")
	hud.prompt("")
	var start := valluvar.rod_tip.global_position
	var target := Vector3(point.x, World.WATER_Y + 0.05, point.z)
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		var p := start.lerp(target, t)
		p.y += sin(t * PI) * 2.6
		bobber.global_position = p, 0.0, 1.0, 0.55).set_delay(0.18)
	tw.tween_callback(func() -> void:
		if state == State.CASTING:
			state = State.WAITING
			Sfx.play("plop")
			_ripple(target)
			hud.prompt("Wait for a bite…  (tap to reel in)"))

func _reel_back() -> void:
	state = State.IDLE
	_rest_bobber()
	hud.prompt("Tap the water to cast")

func _hook() -> void:
	var f := biter
	biter = null
	if f != golden:
		Sfx.say(f.word)   # hear the word that was hooked, right or wrong
	valluvar.strike()
	if f == golden:
		_land(f, true)
	elif f.word == answer:
		_land(f, false)
	else:
		hearts -= 1
		Sfx.play("wrong")
		streak = 0
		hud.set_hearts(hearts)
		hud.set_score(score, streak)
		hud.banner(f.word, Color(1.0, 0.5, 0.4))
		f.flash(Color(1.0, 0.4, 0.3))
		f.flee()
		_ripple(f.position)
		for other in fishes:
			other.speed = _fish_speed()
		if hearts <= 0:
			_game_over("வலை காலி")
		else:
			_reel_back()

func _land(f: Fish, is_golden: bool) -> void:
	state = State.LANDING
	Sfx.play("catch")
	bobber_rest = true
	f.state = Fish.State.CAUGHT
	_ripple(f.position)
	hud.prompt("")
	var start := f.global_position
	var hand := valluvar.global_position + Vector3(0.6, 1.5, 0.3)
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		var p := start.lerp(hand, t)
		p.y += sin(t * PI) * 3.2
		f.global_position = p
		f.rotation.z = t * TAU * 2.0, 0.0, 1.0, 0.7)
	if is_golden:
		hearts = mini(3, hearts + 1)
		time_left = minf(MAX_TIME, time_left + 10.0)
		score += 15
		hud.set_hearts(hearts)
		hud.set_score(score, streak)
		hud.banner("பொன் மீன்!  +10s")
		tw.tween_callback(func() -> void:
			f.queue_free()
			golden = null
			golden_timer = rng.randf_range(16.0, 26.0)
			if state == State.LANDING:
				state = State.IDLE
				hud.prompt("Tap the water to cast"))
		return
	streak += 1
	caught += 1
	# Then the whole Kural, now complete.
	Sfx.say(", ".join(Data.lines_of(q_kural)), false)
	var gain := (10 + 2 * mini(streak, 10)) * (2 if storm else 1)
	score += gain
	Data.wisdom += gain
	time_left = minf(MAX_TIME, time_left + 8.0)
	hud.set_score(score, streak)
	hud.show_kural(q_lines, q_line, q_index, true, str(q_kural["en"]), "Kural %d · %s" % [int(q_kural["id"]), str(q_kural["chTa"])])
	hud.banner("%s  +%d" % [answer, gain])
	tw.tween_interval(1.1)
	tw.tween_callback(func() -> void:
		if state == State.LANDING:
			_next_round())

func _ripple(at: Vector3) -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.26
	ring.outer_radius = 0.3
	ring.rings = 24
	ring.ring_segments = 4
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1, 1, 1, 0.8)
	var node := World.mesh_node(ring, m, Vector3(at.x, World.WATER_Y + 0.02, at.z))
	node.scale = Vector3(1, 0.1, 1)
	add_child(node)
	var tw := create_tween().set_parallel()
	tw.tween_property(node, "scale", Vector3(5, 0.1, 5), 0.8)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.8)
	tw.chain().tween_callback(node.queue_free)

# ---------- every frame ----------

func _process(delta: float) -> void:
	if not active:
		return
	_update_bobber(delta)
	_draw_line()
	_separate(delta)
	_declutter()
	if state == State.MENU or state == State.OVER:
		return
	if state != State.LANDING:
		time_left -= delta
		hud.set_time(time_left / START_TIME)
		if time_left <= 0.0:
			_game_over("நேரம் முடிந்தது")
			return
	_update_golden(delta)
	if demo:
		if state == State.IDLE:
			for f in fishes:
				if f.word == answer:
					_cast(f.position)
		elif state == State.BITE:
			_hook()
	if state == State.WAITING:
		_attract()
	elif state == State.BITE:
		bite_timer -= delta
		if bite_timer <= 0.0:
			# Too slow: the fish takes the bait and goes.
			if biter:
				biter.flee()
			biter = null
			hud.banner("…", Color(1, 1, 1, 0.8))
			_reel_back()

## Fish keep a little apart, so their words do not pile up.
func _separate(delta: float) -> void:
	for i in fishes.size():
		for j in range(i + 1, fishes.size()):
			var a := fishes[i]
			var b := fishes[j]
			var d := a.position - b.position
			d.y = 0
			var dist := d.length()
			if dist < 2.3 and dist > 0.01:
				var push := d / dist * (2.3 - dist) * delta * 1.4
				if a.state == Fish.State.WANDER and World.in_pond(a.position + push, 1.0):
					a.position += push
				if b.state == Fish.State.WANDER and World.in_pond(b.position - push, 1.0):
					b.position -= push

## Words that would overlap on screen are stacked: the later fish lifts its word above the other.
func _declutter() -> void:
	var right := camera.global_transform.basis.x
	var up := camera.global_transform.basis.y
	var boost := Fish.label_boost
	var row := 0.42 * boost
	var boxes: Array[Vector3] = []   # x along the screen, y up the screen, z = half width
	for f in fishes:
		var half := f.label_w * boost * 0.5 + 0.22 * boost
		var x := f.position.dot(right)
		var lift := 0.8
		for step in 5:
			var y := (f.position + Vector3(0, lift, 0)).dot(up)
			var clash := false
			for b in boxes:
				if absf(x - b.x) < half + b.z and absf(y - b.y) < row * 1.05:
					clash = true
					break
			if not clash:
				break
			lift += row * 1.1 / maxf(up.y, 0.4)
		f.lift = lift
		boxes.append(Vector3(x, (f.position + Vector3(0, lift, 0)).dot(up), half))

func _update_bobber(delta: float) -> void:
	if bobber_rest:
		var home := valluvar.rod_tip.global_position + Vector3(0, -0.9, 0)
		bobber.global_position = bobber.global_position.lerp(home, clampf(delta * 8.0, 0.0, 1.0))
	elif state == State.WAITING:
		bobber.position.y = World.WATER_Y + 0.05 + sin(Time.get_ticks_msec() / 260.0) * 0.025
	elif state == State.BITE:
		bobber.position.y = World.WATER_Y - 0.06 + sin(Time.get_ticks_msec() / 40.0) * 0.05

func _draw_line() -> void:
	line_mesh.clear_surfaces()
	var a := valluvar.rod_tip.global_position
	var b := bobber.global_position
	line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, line_mat)
	for i in 13:
		var t := i / 12.0
		var p := a.lerp(b, t)
		# A little slack, tight when a fish is on.
		p.y -= sin(t * PI) * (0.08 if state == State.BITE else 0.45) * minf(1.0, a.distance_to(b) / 4.0)
		line_mesh.surface_add_vertex(p)
	line_mesh.surface_end()

func _attract() -> void:
	var all: Array[Fish] = fishes.duplicate()
	if golden:
		all.append(golden)
	for f in all:
		if f.state == Fish.State.WANDER and f.position.distance_to(bobber.position) < 2.9:
			f.chase(bobber.position)
		if f.state == Fish.State.CHASE and Vector2(f.position.x - bobber.position.x, f.position.z - bobber.position.z).length() < 0.42:
			_bite(f, all)
			return

func _bite(f: Fish, all: Array[Fish]) -> void:
	state = State.BITE
	biter = f
	f.state = Fish.State.BITING
	for other in all:
		if other != f:
			other.lose_interest()
	bite_timer = maxf(0.8, 1.7 - streak * 0.06) * (0.85 if storm else 1.0)
	_ripple(bobber.position)
	hud.prompt("TAP TO HOOK!", true)
	Sfx.play("bite")

func _update_golden(delta: float) -> void:
	if golden:
		return
	golden_timer -= delta
	if golden_timer > 0.0:
		return
	golden = Fish.new()
	add_child(golden)
	golden.setup("பொன்", Color(1.0, 0.78, 0.25), hud.tamil, true)
	var ang := rng.randf() * TAU
	golden.position = Vector3(cos(ang) * 4.5, Fish.DEPTH, sin(ang) * 4.5)
	golden.speed = 2.3
	# It does not stay long.
	var g := golden
	get_tree().create_timer(9.0).timeout.connect(func() -> void:
		if is_instance_valid(g) and golden == g and g.state != Fish.State.CAUGHT and g != biter:
			g.queue_free()
			golden = null
			golden_timer = rng.randf_range(16.0, 26.0))
