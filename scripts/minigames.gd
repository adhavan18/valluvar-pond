class_name Minigames
extends CanvasLayer
## The games played at the school and the scribe's hut, drawn as a panel over the scene.
##   school: "Finish the Kural" — the first line is given; choose its second line.
##   hut:    "Write the leaf"   — tap the Kural's words in order, as a scribe would write them.

signal closed

const INK := Color(0.23, 0.14, 0.05)
const SEPIA := Color(0.42, 0.33, 0.24)
const LEAF := Color(0.93, 0.83, 0.62)
const GOLD := Color(0.95, 0.74, 0.36)
const GOOD := Color(0.55, 0.78, 0.55)
const BAD := Color(0.92, 0.55, 0.45)

var tamil: Font
var latin: Font
var rng := RandomNumberGenerator.new()

var _root: Control
var _title: Label
var _progress: Label
var _verse: RichTextLabel
var _meaning: Label
var _options: VBoxContainer
var _tiles: HFlowContainer
var _status: Label
var _again: Button
var _panel: PanelContainer

var kind := ""
var round_no := 0
var rounds := 5
var right := 0
var earned := 0
var busy := false
var k: Dictionary = {}
var expected: Array[String] = []
var placed := 0
var mistakes := 0

func setup(p_tamil: Font, p_latin: Font) -> void:
	tamil = p_tamil
	latin = p_latin
	rng.randomize()
	layer = 5
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var theme := Theme.new()
	theme.default_font = latin
	theme.default_font_size = 20
	_root.theme = theme
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.05, 0.03, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(LEAF, 28, Color(0.55, 0.38, 0.16, 0.6), 2))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(860, 0)
	_panel = panel
	_root.add_child(panel)
	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 34)
	pad.add_theme_constant_override("margin_top", 20)
	pad.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	pad.add_child(col)

	var head := HBoxContainer.new()
	col.add_child(head)
	_title = _label("", 26, Color(0.64, 0.15, 0.17), HORIZONTAL_ALIGNMENT_LEFT)
	_title.add_theme_font_override("font", tamil)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_progress = _label("", 18, SEPIA, HORIZONTAL_ALIGNMENT_RIGHT)
	head.add_child(_progress)
	var close := _button("Leave", 18)
	close.custom_minimum_size = Vector2(110, 44)
	close.pressed.connect(_close)
	head.add_child(close)

	_verse = RichTextLabel.new()
	_verse.bbcode_enabled = true
	_verse.fit_content = true
	_verse.scroll_active = false
	_verse.custom_minimum_size = Vector2(780, 0)
	_verse.add_theme_font_override("normal_font", tamil)
	_verse.add_theme_font_override("bold_font", tamil)
	_verse.add_theme_font_size_override("normal_font_size", 30)
	_verse.add_theme_font_size_override("bold_font_size", 30)
	_verse.add_theme_color_override("default_color", INK)
	_verse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_verse)
	_meaning = _label("", 17, SEPIA)
	_meaning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_meaning.custom_minimum_size = Vector2(780, 0)
	col.add_child(_meaning)
	_options = VBoxContainer.new()
	_options.add_theme_constant_override("separation", 10)
	col.add_child(_options)
	_tiles = HFlowContainer.new()
	_tiles.alignment = FlowContainer.ALIGNMENT_CENTER
	_tiles.add_theme_constant_override("h_separation", 10)
	_tiles.add_theme_constant_override("v_separation", 10)
	col.add_child(_tiles)
	_status = _label("", 20, INK)
	col.add_child(_status)
	_again = _button("Play again", 20)
	_again.pressed.connect(func() -> void: open(kind))
	col.add_child(_again)
	visible = false

func _label(text: String, size: int, color: Color, align: int = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _box(color: Color, radius: int, border: Color = Color.TRANSPARENT, width: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

func _button(text: String, size: int, use_tamil: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 54)
	b.add_theme_font_size_override("font_size", size)
	if use_tamil:
		b.add_theme_font_override("font", tamil)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(c, INK)
	_paint(b, Color(1.0, 0.97, 0.9))
	return b

func _paint(b: Button, color: Color) -> void:
	b.add_theme_stylebox_override("normal", _box(color, 14, Color(0.55, 0.38, 0.16, 0.45), 2))
	b.add_theme_stylebox_override("hover", _box(color.lightened(0.25), 14, Color(0.64, 0.15, 0.17, 0.7), 2))
	b.add_theme_stylebox_override("pressed", _box(color.darkened(0.08), 14, Color(0.64, 0.15, 0.17, 0.7), 2))
	b.add_theme_stylebox_override("disabled", _box(color, 14, Color(0.55, 0.38, 0.16, 0.3), 2))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

## Fits the panel to the width available (interface units), for upright phones.
func fit(w: float) -> void:
	var pw := minf(860.0, w - 20.0)
	_panel.custom_minimum_size.x = pw
	_verse.custom_minimum_size.x = pw - 80.0
	_meaning.custom_minimum_size.x = pw - 80.0
	var size := 24 if w < 900.0 else 30
	_verse.add_theme_font_size_override("normal_font_size", size)
	_verse.add_theme_font_size_override("bold_font_size", size)

func _clear(box: Node) -> void:
	for c in box.get_children():
		c.queue_free()

func open(p_kind: String) -> void:
	kind = p_kind
	round_no = 0
	right = 0
	earned = 0
	rounds = 5 if kind == "school" else 3
	_title.text = "பள்ளி · Finish the Kural" if kind == "school" else "ஏடகம் · Write the leaf"
	_again.visible = false
	visible = true
	_next()

func _close() -> void:
	Sfx.play("click")
	visible = false
	Data.save()
	closed.emit()

func _next() -> void:
	busy = false
	round_no += 1
	_clear(_options)
	_clear(_tiles)
	_status.text = ""
	if round_no > rounds:
		_finish()
		return
	_progress.text = "%d / %d   " % [round_no, rounds]
	# The best-known chapters first.
	k = Data.kurals[rng.randi() % mini(Data.kurals.size(), 300)]
	_meaning.text = str(k["en"])
	if kind == "school":
		_school_round()
	else:
		_hut_round()

func _finish() -> void:
	_progress.text = ""
	_verse.text = "[center]%s[/center]" % ("நன்று!" if right >= rounds - 1 else "மீண்டும் முயல்க")
	_meaning.text = "%d of %d right.  Wisdom earned: +%d" % [right, rounds, earned]
	_again.visible = true
	Sfx.play("win" if right >= rounds - 1 else "over")
	Data.save()

func _gain(points: int) -> void:
	right += 1
	Data.collect(k)
	# Hear the whole Kural, now complete.
	Sfx.say(", ".join(Data.lines_of(k)))
	earned += points
	Data.wisdom += points

# ---------- school: choose the second line ----------

func _school_round() -> void:
	var lines := Data.lines_of(k)
	_verse.text = "[center]%s\n[color=#a4262c]__________[/color][/center]" % lines[0]
	var choices: Array[String] = [lines[1]]
	while choices.size() < 3:
		var other: Dictionary = Data.kurals[rng.randi() % Data.kurals.size()]
		var second := Data.lines_of(other)[1]
		if not choices.has(second):
			choices.append(second)
	choices.shuffle()
	for c in choices:
		var b := _button(c, 24, true)
		b.pressed.connect(_school_pick.bind(b, c, lines))
		_options.add_child(b)

func _school_pick(b: Button, choice: String, lines: PackedStringArray) -> void:
	if busy:
		return
	busy = true
	var ok := choice == lines[1]
	for other: Button in _options.get_children():
		other.disabled = true
		if other.text == lines[1]:
			_paint(other, GOOD)
	if ok:
		_gain(10)
		Sfx.play("catch")
		_status.text = "+10"
	else:
		_paint(b, BAD)
		Sfx.play("wrong")
	_verse.text = "[center]%s\n[color=#a4262c][b]%s[/b][/color][/center]" % [lines[0], lines[1]]
	get_tree().create_timer(1.5).timeout.connect(_next_if_open.bind(round_no))

func _next_if_open(for_round: int) -> void:
	if visible and for_round == round_no:
		_next()

# ---------- hut: tap the words in order ----------

func _hut_round() -> void:
	expected.clear()
	for line in Data.lines_of(k):
		expected.append_array(Data.words(line))
	placed = 0
	mistakes = 0
	_show_written()
	var order: Array[String] = expected.duplicate()
	order.shuffle()
	for w in order:
		var b := _button(w, 24, true)
		b.pressed.connect(_hut_pick.bind(b, w))
		_tiles.add_child(b)

func _show_written() -> void:
	var first_len := Data.words(Data.lines_of(k)[0]).size()
	var a: Array[String] = []
	var b: Array[String] = []
	for i in expected.size():
		var w := expected[i] if i < placed else "[color=#b9a57e]____[/color]"
		if i < first_len:
			a.append(w)
		else:
			b.append(w)
	_verse.text = "[center]%s\n%s[/center]" % [" ".join(a), " ".join(b)]

func _hut_pick(b: Button, w: String) -> void:
	if busy:
		return
	if w == expected[placed]:
		placed += 1
		b.queue_free()
		Sfx.play("click", 1.0 + placed * 0.06)
		if placed < expected.size():
			Sfx.say(w)   # each word is spoken as it is written
		_show_written()
		if placed == expected.size():
			busy = true
			var points := maxi(5, 15 - mistakes * 2)
			_gain(points)
			Sfx.play("catch")
			_status.text = "+%d" % points
			get_tree().create_timer(1.5).timeout.connect(_next_if_open.bind(round_no))
	else:
		mistakes += 1
		Sfx.play("wrong", 1.2, -10.0)
		_paint(b, BAD)
		get_tree().create_timer(0.35).timeout.connect(func() -> void:
			if is_instance_valid(b):
				_paint(b, Color(1.0, 0.97, 0.9)))
