extends Control
## Title screen. Two decisions: who is playing, and which ruleset.

const CYAN := Color(0.25, 0.95, 1.0)
const PINK := Color(1.0, 0.32, 0.75)
const DANGER := Color(1.0, 0.3, 0.32)

var _buttons: Array = []
var _rules_btn: Button
var _tag: Label


func _ready() -> void:
	_build()


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.010, 0.012, 0.022)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_glow(Vector2(150.0, -40.0), Vector2(980.0, 420.0), CYAN, 0.16)
	_glow(Vector2(150.0, 420.0), Vector2(980.0, 380.0), PINK, 0.10)

	var line := ColorRect.new()
	line.color = Color(CYAN.r, CYAN.g, CYAN.b, 0.5)
	add_child(line)
	_place(line, 160, 96, 960, 1)

	var line2 := ColorRect.new()
	line2.color = Color(PINK.r, PINK.g, PINK.b, 0.35)
	add_child(line2)
	_place(line2, 160, 700, 960, 1)

	# Neon title: a coloured copy behind a white one.
	var glow := _label("RETURN TO SENDER", 72, Color(CYAN.r, CYAN.g, CYAN.b, 0.35), 2)
	glow.position = Vector2(3, 87)
	var title := _label("RETURN TO SENDER", 72, Color(1, 1, 1), 2)
	title.position = Vector2(0, 84)
	title.add_theme_constant_override("outline_size", 0)

	_tag = _label("", 20, CYAN, 2)
	_tag.position = Vector2(0, 184)
	_tag.size = Vector2(1280, 26)
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var blurb := _label("Every touch makes the ball faster. Survive, or get flattened.", 17, Color(0.55, 0.65, 0.8), 0)
	blurb.position = Vector2(0, 212)
	blurb.size = Vector2(1280, 24)
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var box := VBoxContainer.new()
	add_child(box)
	box.position = Vector2(390, 240)
	box.size = Vector2(500, 252)
	box.add_theme_constant_override("separation", 5)

	_rules_btn = Button.new()
	_rules_btn.text = ""
	_rules_btn.custom_minimum_size = Vector2(0, 36)
	_rules_btn.add_theme_font_override("font", Game.font_wide)
	_rules_btn.add_theme_font_size_override("font_size", 17)
	_skin(_rules_btn, 0.45)
	_rules_btn.pressed.connect(_cycle_rules)
	box.add_child(_rules_btn)
	_buttons.append(_rules_btn)

	var modes := [
		["2 PLAYERS", Game.MODE_PVP, 0, CYAN],
		["VS AI — ROOKIE", Game.MODE_AI, 0, CYAN],
		["VS AI — REGULAR", Game.MODE_AI, 1, CYAN],
		["VS AI — KILLER", Game.MODE_AI, 2, CYAN],
		["VS AI — IMPOSSIBLE", Game.MODE_AI, 3, DANGER],
	]
	for m in modes:
		_add_button(box, m[0], m[1], m[2], m[3])

	var controls := _label(
		"P1   W A S D   ·   SHIFT  dash   ·   SPACE  hand\n" +
		"P2   ARROWS   ·   .  dash   ·   /  hand\n" +
		"tap to catch   ·   hold to charge a throw",
		15, Color(0.5, 0.6, 0.76), 0)
	controls.position = Vector2(0, 594)
	controls.size = Vector2(1280, 70)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	_powerup_legend()
	_refresh_rules_text()
	if not _buttons.is_empty():
		_buttons[0].grab_focus()


func _glow(pos: Vector2, size: Vector2, col: Color, alpha: float) -> void:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([Color(col.r, col.g, col.b, alpha), Color(col.r, col.g, col.b, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 256
	gt.height = 256
	var t := TextureRect.new()
	t.texture = gt
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(t)
	t.position = pos
	t.size = size


## The four pickups, spelled out on the title screen so nobody has to learn
## them by being hit with them.
func _powerup_legend() -> void:
	var head := _label("POWERUPS   ·   WALK OVER THEM   ·   7 SECONDS", 11, Color(0.42, 0.52, 0.68), 2)
	head.position = Vector2(0, 500)
	head.size = Vector2(1280, 16)

	var descs := [
		"+45% run speed",
		"hitbox 0.40 to 0.26 m",
		"catch reach 2.2 to 3.45 m",
		"dash cooldown 1.2 to 0.42 s",
	]

	var row := HBoxContainer.new()
	add_child(row)
	row.position = Vector2(140, 522)
	row.size = Vector2(1000, 44)
	row.add_theme_constant_override("separation", 12)

	for i in 4:
		var d: Dictionary = Game.POWERUPS[i]
		var col: Color = d["color"]

		var card := VBoxContainer.new()
		card.custom_minimum_size = Vector2(232, 0)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_constant_override("separation", 3)
		row.add_child(card)

		var line := HBoxContainer.new()
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		line.add_theme_constant_override("separation", 7)
		card.add_child(line)

		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(9, 9)
		dot.pivot_offset = Vector2(4.5, 4.5)
		dot.rotation = PI * 0.25
		dot.color = col
		line.add_child(dot)

		var nm := Label.new()
		nm.text = str(d["name"])
		nm.add_theme_font_override("font", Game.font_wide)
		nm.add_theme_font_size_override("font_size", 13)
		nm.add_theme_color_override("font_color", col)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.add_child(nm)

		var ds := Label.new()
		ds.text = descs[i]
		ds.add_theme_font_override("font", Game.font_regular)
		ds.add_theme_font_size_override("font_size", 13)
		ds.add_theme_color_override("font_color", Color(0.5, 0.6, 0.76))
		ds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(ds)


func _add_button(parent: Node, text: String, mode: int, tier: int, accent: Color = CYAN) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 36)
	b.add_theme_font_override("font", Game.font_wide)
	b.add_theme_font_size_override("font_size", 19)
	_skin(b, 0.35, accent)
	b.pressed.connect(_start.bind(mode, tier))
	parent.add_child(b)
	_buttons.append(b)


func _skin(b: Button, border_alpha: float, tint: Color = CYAN) -> void:
	var base := tint
	var accent := Color(base.r, base.g, base.b, border_alpha)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.03, 0.04, 0.07, 0.92)
	normal.border_color = accent
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8

	var hover := normal.duplicate()
	hover.bg_color = Color(0.06, 0.11, 0.18, 0.96)
	hover.border_color = Color(base.r, base.g, base.b, 0.95)
	hover.set_border_width_all(2)

	var pressed := normal.duplicate()
	pressed.bg_color = Color(base.r, base.g, base.b, 0.22)
	pressed.border_color = Color(1, 1, 1, 0.9)

	var focus := hover.duplicate()
	focus.border_color = Color(1, 1, 1, 0.75)

	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", focus)
	b.add_theme_color_override("font_color", Color(0.78, 0.88, 1.0).lerp(base, 0.45))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	b.add_theme_color_override("font_focus_color", Color(1, 1, 1))


func _cycle_rules() -> void:
	Game.ruleset = Game.RULES_REBOUND if Game.ruleset == Game.RULES_CLASSIC else Game.RULES_CLASSIC
	Game.sfx.play("ui")
	_refresh_rules_text()


func _refresh_rules_text() -> void:
	if Game.ruleset == Game.RULES_REBOUND:
		_rules_btn.text = "RULES  ·  REBOUND        click to switch"
		_tag.text = "BLOCK WITH YOUR FRONT   ·   GET HIT IN THE BACK AND YOU'RE DONE"
		_tag.add_theme_color_override("font_color", Color(1.0, 0.58, 0.3))
	else:
		_rules_btn.text = "RULES  ·  CLASSIC        click to switch"
		_tag.text = "BOUNCE BACK   ·   BEST OF FIVE   ·   NOBODY SCORES"
		_tag.add_theme_color_override("font_color", CYAN)


func _start(mode: int, tier: int) -> void:
	Game.mode = mode
	Game.tier = tier
	Game.sfx.play("ui")
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _label(text: String, size_px: int, col: Color, font_kind: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Game.font_wide if font_kind == 2 else Game.font_regular)
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 10)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	l.position = Vector2(0, 120)
	l.size = Vector2(1280, size_px + 18)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _place(c: Control, x: int, y: int, w: int, h: int) -> void:
	c.position = Vector2(x, y)
	c.size = Vector2(w, h)
