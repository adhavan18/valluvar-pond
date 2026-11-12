class_name Hud
extends CanvasLayer
## Everything drawn over the pond: the Kural with its missing word, the meaning, hearts, score,
## time, prompts, and the start and game-over panels. Built in code.

signal start_pressed
signal action_pressed
signal leave_pressed

const INK := Color(0.23, 0.14, 0.05)
const SEPIA := Color(0.42, 0.33, 0.24)
const GOLD := Color(0.95, 0.74, 0.36)
const KUMKUM := Color(0.64, 0.15, 0.17)
const LEAF := Color(0.93, 0.83, 0.62)

var tamil: FontFile
var latin: FontFile

var _couplet: RichTextLabel
var _meaning: Label
var _source: Label
var _hearts: HBoxContainer
var _score: Label
var _streak: Label
var _time: ProgressBar
var _prompt: Label
var _banner: Label
var _panel: PanelContainer
var _panel_title: Label
var _panel_body: Label
var _panel_button: Button
var _prompt_tween: Tween
var _leaf: PanelContainer
var _stats: VBoxContainer
var _wisdom: Label
var _action: Button
var _leave: Button

func _ready() -> void:
	tamil = load("res://fonts/NotoSerifTamil-normal-400_700-tamil.woff2")
	latin = load("res://fonts/PlusJakartaSans-normal-400_800-latin.woff2")
	tamil.fallbacks = [latin]
	# Latin text falls back to a second copy of the Tamil face (a font cannot fall back in a circle).
	var tamil_plain: FontFile = load("res://fonts/NotoSansTamil-normal-400_700-tamil.woff2")
	latin.fallbacks = [tamil_plain]

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = latin
	theme.default_font_size = 20
	root.theme = theme
	add_child(root)

	# The palm leaf at the top: the couplet, its meaning, where it is from.
	var leaf := PanelContainer.new()
	_leaf = leaf
	leaf.add_theme_stylebox_override("panel", _box(LEAF, 30, Color(0.55, 0.38, 0.16, 0.5), 2))
	leaf.set_anchors_preset(Control.PRESET_CENTER_TOP)
	leaf.grow_horizontal = Control.GROW_DIRECTION_BOTH
	leaf.position.y = 14
	leaf.custom_minimum_size = Vector2(760, 0)
	leaf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(leaf)
	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 34)
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_bottom", 12)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	leaf.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(col)
	_source = _label("", 14, SEPIA)
	col.add_child(_source)
	_couplet = RichTextLabel.new()
	_couplet.bbcode_enabled = true
	_couplet.fit_content = true
	_couplet.scroll_active = false
	_couplet.autowrap_mode = TextServer.AUTOWRAP_OFF
	_couplet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_couplet.add_theme_font_override("normal_font", tamil)
	_couplet.add_theme_font_override("bold_font", tamil)
	_couplet.add_theme_font_size_override("normal_font_size", 30)
	_couplet.add_theme_font_size_override("bold_font_size", 30)
	_couplet.add_theme_color_override("default_color", INK)
	col.add_child(_couplet)
	_meaning = _label("", 17, SEPIA)
	_meaning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_meaning.custom_minimum_size = Vector2(690, 0)
	col.add_child(_meaning)

	# Hearts, score and streak on the left; time along the bottom.
	var stats := VBoxContainer.new()
	_stats = stats
	stats.position = Vector2(20, 18)
	stats.add_theme_constant_override("separation", 6)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(stats)
	_hearts = HBoxContainer.new()
	_hearts.add_theme_constant_override("separation", 6)
	stats.add_child(_hearts)
	_score = _label("0", 34, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	_score.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.04))
	_score.add_theme_constant_override("outline_size", 8)
	stats.add_child(_score)
	_streak = _label("", 18, GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	_streak.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.04))
	_streak.add_theme_constant_override("outline_size", 6)
	stats.add_child(_streak)

	_time = ProgressBar.new()
	_time.show_percentage = false
	_time.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_time.offset_left = 40
	_time.offset_right = -40
	_time.offset_top = -30
	_time.offset_bottom = -16
	_time.add_theme_stylebox_override("background", _box(Color(0.1, 0.07, 0.04, 0.55), 8))
	_time.add_theme_stylebox_override("fill", _box(GOLD, 8))
	_time.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_time)

	_prompt = _label("", 26, Color.WHITE)
	_prompt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt.offset_top = -86
	_prompt.offset_bottom = -44
	_prompt.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.04))
	_prompt.add_theme_constant_override("outline_size", 8)
	root.add_child(_prompt)

	_banner = _label("", 54, GOLD)
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	_banner.add_theme_font_override("font", tamil)
	_banner.add_theme_color_override("font_outline_color", Color(0.25, 0.08, 0.06))
	_banner.add_theme_constant_override("outline_size", 14)
	_banner.modulate.a = 0.0
	root.add_child(_banner)

	# Wisdom earned across every game, top right; under it, the way out of a game.
	_wisdom = _label("", 22, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	_wisdom.add_theme_font_override("font", tamil)
	_wisdom.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.04))
	_wisdom.add_theme_constant_override("outline_size", 8)
	_wisdom.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_wisdom.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_wisdom.offset_right = -20
	_wisdom.offset_top = 16
	root.add_child(_wisdom)
	_leave = _pill("Leave the pond", 18)
	_leave.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_leave.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_leave.offset_right = -20
	_leave.offset_top = 58
	_leave.pressed.connect(func() -> void: leave_pressed.emit())
	root.add_child(_leave)
	# What Valluvar can do where he stands ("Sit and fish").
	_action = _pill("", 24)
	_action.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_action.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_action.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_action.offset_bottom = -92
	_action.custom_minimum_size = Vector2(280, 64)
	_action.pressed.connect(func() -> void: action_pressed.emit())
	_action.visible = false
	root.add_child(_action)

	# Start / game over.
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _box(Color(0.12, 0.08, 0.05, 0.94), 26, Color(0.95, 0.74, 0.36, 0.5), 2))
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.custom_minimum_size = Vector2(560, 0)
	root.add_child(_panel)
	var ppad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		ppad.add_theme_constant_override("margin_" + side, 30)
	_panel.add_child(ppad)
	var pcol := VBoxContainer.new()
	pcol.add_theme_constant_override("separation", 14)
	ppad.add_child(pcol)
	_panel_title = _label("", 44, GOLD)
	_panel_title.add_theme_font_override("font", tamil)
	pcol.add_child(_panel_title)
	_panel_body = _label("", 19, Color(0.95, 0.9, 0.83))
	_panel_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel_body.custom_minimum_size = Vector2(500, 0)
	pcol.add_child(_panel_body)
	_panel_button = Button.new()
	_panel_button.custom_minimum_size = Vector2(0, 58)
	_panel_button.add_theme_font_size_override("font_size", 22)
	_panel_button.add_theme_color_override("font_color", Color(0.16, 0.09, 0.02))
	_panel_button.add_theme_color_override("font_hover_color", Color(0.16, 0.09, 0.02))
	_panel_button.add_theme_color_override("font_pressed_color", Color(0.16, 0.09, 0.02))
	_panel_button.add_theme_stylebox_override("normal", _box(GOLD, 16))
	_panel_button.add_theme_stylebox_override("hover", _box(Color(0.98, 0.82, 0.5), 16))
	_panel_button.add_theme_stylebox_override("pressed", _box(Color(0.86, 0.62, 0.24), 16))
	_panel_button.pressed.connect(func() -> void: start_pressed.emit())
	pcol.add_child(_panel_button)

func _label(text: String, size: int, color: Color, align: int = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _box(color: Color, radius: int, border: Color = Color.TRANSPARENT, width: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(width)
	return sb

## The couplet with one word replaced by a blank (or shown in red-brown once caught).
func show_kural(lines: Array, blank_line: int, blank_index: int, solved: bool, meaning: String, source: String) -> void:
	var out: Array[String] = []
	for li in lines.size():
		var words: Array = lines[li]
		var parts: Array[String] = []
		for wi in words.size():
			var w: String = words[wi]
			if li == blank_line and wi == blank_index:
				parts.append("[color=#a4262c][b]%s[/b][/color]" % w if solved else "[color=#a4262c]______[/color]")
			else:
				parts.append(w)
		out.append(" ".join(parts))
	_couplet.text = "[center]%s[/center]" % "\n".join(out)
	_meaning.text = meaning
	_source.text = source

func set_hearts(n: int, total: int = 3) -> void:
	for c in _hearts.get_children():
		c.queue_free()
	for i in total:
		var p := Panel.new()
		p.custom_minimum_size = Vector2(22, 22)
		p.add_theme_stylebox_override("panel", _box(KUMKUM if i < n else Color(0.1, 0.07, 0.04, 0.45), 11, Color(1, 0.9, 0.75, 0.7), 2))
		_hearts.add_child(p)

func set_score(score: int, streak: int) -> void:
	_score.text = str(score)
	_streak.text = "" if streak < 2 else "streak ×%d" % streak

func set_time(ratio: float) -> void:
	_time.value = clampf(ratio, 0.0, 1.0) * 100.0
	_time.add_theme_stylebox_override("fill", _box(KUMKUM if ratio < 0.2 else GOLD, 8))

func prompt(text: String, urgent: bool = false) -> void:
	_prompt.text = text
	_prompt.add_theme_color_override("font_color", GOLD if urgent else Color.WHITE)
	if _prompt_tween:
		_prompt_tween.kill()
	_prompt.scale = Vector2.ONE
	if urgent:
		_prompt.pivot_offset = _prompt.size / 2.0
		_prompt_tween = create_tween().set_loops()
		_prompt_tween.tween_property(_prompt, "scale", Vector2(1.18, 1.18), 0.16)
		_prompt_tween.tween_property(_prompt, "scale", Vector2.ONE, 0.16)

## A word that swells in the middle of the screen and fades: "+12", "Storm!", the caught word.
func banner(text: String, color: Color = GOLD) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.modulate.a = 1.0
	_banner.pivot_offset = _banner.size / 2.0
	_banner.scale = Vector2(0.6, 0.6)
	var tw := create_tween()
	tw.tween_property(_banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.55)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.35)

func show_panel(title: String, body: String, button: String) -> void:
	_panel_title.text = title
	_panel_body.text = body
	_panel_button.text = button
	_panel.visible = true

func hide_panel() -> void:
	_panel.visible = false

func _pill(text: String, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_size_override("font_size", size)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, Color(0.16, 0.09, 0.02))
	var normal := _box(GOLD, 23)
	var hover := _box(Color(0.98, 0.82, 0.5), 23)
	for sb: StyleBoxFlat in [normal, hover]:
		sb.content_margin_left = 22
		sb.content_margin_right = 22
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", normal)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b

## "explore": only wisdom, the prompt and the action button. "fishing": the whole pond display.
func set_mode(mode: String) -> void:
	var fishing := mode == "fishing"
	_leaf.visible = fishing
	_stats.visible = fishing
	_time.visible = fishing
	_leave.visible = fishing
	if fishing:
		_action.visible = false

func set_wisdom(n: int) -> void:
	_wisdom.text = "ஞானம்  %d" % n

func set_action(text: String) -> void:
	_action.visible = text != ""
	_action.text = text

## The fishing-only build has no "leave" button: there is nowhere else to go.
func hide_leave() -> void:
	_leave.visible = false

var _fit_w := -1.0

## Re-flows the display for the width available (in interface units): on a narrow, upright
## phone the leaf shrinks to fit, the couplet wraps at a smaller size, and the hearts, score
## and wisdom move below the leaf instead of beside it.
func fit(w: float) -> void:
	if is_equal_approx(w, _fit_w):
		return
	_fit_w = w
	var narrow := w < 900.0
	var leaf_w := minf(760.0, w - 24.0)
	_leaf.custom_minimum_size.x = leaf_w
	_meaning.custom_minimum_size.x = leaf_w - 70.0
	_couplet.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if narrow else TextServer.AUTOWRAP_OFF
	_couplet.custom_minimum_size.x = leaf_w - 70.0 if narrow else 0.0
	var size := 24 if narrow else 30
	_couplet.add_theme_font_size_override("normal_font_size", size)
	_couplet.add_theme_font_size_override("bold_font_size", size)
	_panel.custom_minimum_size.x = minf(560.0, w - 30.0)
	_panel_body.custom_minimum_size.x = minf(500.0, w - 90.0)
	_stats.position.y = 250.0 if narrow else 18.0
	_wisdom.offset_top = 250.0 if narrow else 16.0
