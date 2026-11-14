extends CanvasLayer
## HUD. Big type, one number that matters, and nothing else competing with it.

const P1_COL := Color(0.25, 0.95, 1.0)
const P2_COL := Color(1.0, 0.32, 0.75)
const DIM := Color(0.52, 0.62, 0.78)

var _speed: Label
var _bar_bg: ColorRect
var _bar_fill: ColorRect
var _pips := [[], []]
var _buff := []
var _banner: Label
var _rule: ColorRect
var _sub: Label
var _popup: Label
var _mode: Label
var _flash: ColorRect

var _heat := 1.0
var _shown := 1.0
var _banner_tween: Tween = null
var _popup_tween: Tween = null
var _flash_tween: Tween = null


func _ready() -> void:
	_build()


func _build() -> void:
	var root := Control.new()
	root.name = "Root"
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_vignette(root)
	_top_fade(root)

	# --- speed block -------------------------------------------------------
	var cap := _text(root, "SPEED", 490, 20, 300, 30, DIM, 2)
	cap.add_theme_font_size_override("font_size", 18)

	_speed = _text(root, "×1.0", 480, 32, 320, 100, Color.WHITE, 2)
	_speed.add_theme_font_size_override("font_size", 96)
	_speed.add_theme_constant_override("outline_size", 16)



	# --- players -----------------------------------------------------------
	var n1 := _text(root, "P1", 36, 18, 240, 26, P1_COL, 2)
	n1.add_theme_font_size_override("font_size", 22)
	var n2 := _text(root, "P2", 984, 18, 260, 26, P2_COL, 2)
	n2.add_theme_font_size_override("font_size", 22)
	n2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	for i in 2:
		for k in 3:
			var pip := ColorRect.new()
			pip.pivot_offset = Vector2(7, 7)
			pip.rotation = PI * 0.25
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(pip)
			if i == 0:
				_place(pip, 38 + k * 24, 54, 14, 14)
			else:
				_place(pip, 1226 - k * 24, 54, 14, 14)
			_pips[i].append(pip)

	# --- active powerup, under each name -----------------------------------
	for i in 2:
		var b := _text(root, "", 36 if i == 0 else 984, 76, 240 if i == 0 else 260, 20, DIM, 2)
		b.add_theme_font_size_override("font_size", 14)
		if i == 1:
			b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_buff.append(b)

	# --- banners -----------------------------------------------------------
	_banner = _text(root, "", 0, 0, 0, 0, Color.WHITE, 2)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.offset_left = -660
	_banner.offset_right = 660
	_banner.offset_top = -118
	_banner.offset_bottom = 6
	_banner.add_theme_font_size_override("font_size", 82)
	_banner.add_theme_constant_override("outline_size", 18)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.modulate = Color(1, 1, 1, 0)

	_rule = ColorRect.new()
	_rule.color = Color(1, 1, 1, 0.85)
	root.add_child(_rule)
	_rule.set_anchors_preset(Control.PRESET_CENTER)
	_rule.offset_left = -90
	_rule.offset_right = 90
	_rule.offset_top = 4
	_rule.offset_bottom = 7
	_rule.modulate = Color(1, 1, 1, 0)

	_sub = _text(root, "", 0, 0, 0, 0, DIM, 2)
	_sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_sub.offset_left = -660
	_sub.offset_right = 660
	_sub.offset_top = 30
	_sub.offset_bottom = 62
	_sub.add_theme_font_size_override("font_size", 21)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.modulate = Color(1, 1, 1, 0)

	_popup = _text(root, "", 0, 0, 0, 0, Color.WHITE, 2)
	_popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_popup.offset_left = -660
	_popup.offset_right = 660
	_popup.offset_top = 86
	_popup.offset_bottom = 150
	_popup.add_theme_font_size_override("font_size", 46)
	_popup.add_theme_constant_override("outline_size", 14)
	_popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_popup.modulate = Color(1, 1, 1, 0)

	# --- chrome ------------------------------------------------------------
	_mode = _text(root, "", 36, 668, 560, 24, DIM, 0)
	_mode.add_theme_font_size_override("font_size", 15)

	var hint := _text(root, "ESC  MENU", 984, 668, 260, 24, DIM, 0)
	hint.add_theme_font_size_override("font_size", 15)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_flash = ColorRect.new()
	root.add_child(_flash)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _place(c: Control, x: int, y: int, w: int, h: int) -> void:
	c.set_anchors_preset(Control.PRESET_TOP_LEFT)
	c.position = Vector2(x, y)
	c.size = Vector2(w, h)


func _text(parent: Node, text: String, x: int, y: int, w: int, h: int, col: Color, font_kind: int) -> Label:
	var l := Label.new()
	l.text = text
	l.position = Vector2(x, y)
	l.size = Vector2(w, h)
	l.add_theme_font_override("font", Game.font_wide if font_kind == 2 else Game.font_bold)
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	if w == 0:
		l.set_anchors_preset(Control.PRESET_CENTER)
	return l


func _vignette(root: Control) -> void:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.52, 1.0])
	grad.colors = PackedColorArray([
		Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.12), Color(0, 0, 0, 0.86),
	])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 512
	gt.height = 512
	var vig := TextureRect.new()
	vig.texture = gt
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vig)
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _top_fade(root: Control) -> void:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([Color(0, 0, 0, 0.62), Color(0, 0, 0, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	gt.width = 8
	gt.height = 128
	var bar := TextureRect.new()
	bar.texture = gt
	bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bar.stretch_mode = TextureRect.STRETCH_SCALE
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 150


func _process(delta: float) -> void:
	_shown = lerpf(_shown, _heat, 1.0 - exp(-12.0 * delta))
	_speed.text = "×%.1f" % _shown
	var c := _heat_color(_heat)
	_speed.add_theme_color_override("font_color", c)



func _heat_color(h: float) -> Color:
	var k := clampf((h - 1.0) / (Ball.MAX_HEAT - 1.0), 0.0, 1.0)
	var white := Color(0.95, 0.97, 1.0)
	var amber := Color(1.0, 0.55, 0.15)
	var hot := Color(1.0, 0.99, 0.95)
	if k < 0.45:
		return white.lerp(amber, k / 0.45)
	return amber.lerp(hot, (k - 0.45) / 0.55)


func set_speed(h: float) -> void:
	_heat = h


func set_scores(a: int, b: int) -> void:
	for k in 3:
		_pips[0][k].color = _pip_color(P1_COL, k < a)
		_pips[1][k].color = _pip_color(P2_COL, k < b)


func _pip_color(c: Color, on: bool) -> Color:
	return Color(c.r, c.g, c.b, 1.0) if on else Color(c.r, c.g, c.b, 0.14)


func set_mode(text: String) -> void:
	_mode.text = text


func set_buff(i: int, text: String, col: Color) -> void:
	if _buff.size() < 2:
		return
	_buff[i].text = text
	_buff[i].add_theme_color_override("font_color", col.lerp(Color.WHITE, 0.4))


func banner(title: String, subtitle := "", col := Color.WHITE) -> void:
	_banner.text = title
	_banner.add_theme_color_override("font_color", col)
	var rc := Color(col.r, col.g, col.b, 0.9)
	_rule.color = rc
	_sub.text = subtitle
	if _banner_tween != null:
		_banner_tween.kill()
	_banner.modulate = Color(1, 1, 1, 0)
	_sub.modulate = Color(1, 1, 1, 0)
	_rule.modulate = Color(1, 1, 1, 0)
	_banner_tween = create_tween()
	_banner_tween.set_parallel(true)
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.18)
	_banner_tween.tween_property(_rule, "modulate:a", 1.0, 0.3)
	_banner_tween.tween_property(_sub, "modulate:a", 1.0, 0.4)


func clear_banner() -> void:
	if _banner_tween != null:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.set_parallel(true)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.16)
	_banner_tween.tween_property(_rule, "modulate:a", 0.0, 0.16)
	_banner_tween.tween_property(_sub, "modulate:a", 0.0, 0.16)


func popup(text: String, col: Color) -> void:
	_popup.text = text
	_popup.add_theme_color_override("font_color", col.lerp(Color.WHITE, 0.55))
	if _popup_tween != null:
		_popup_tween.kill()
	_popup.modulate = Color(1, 1, 1, 1)
	_popup_tween = create_tween()
	_popup_tween.set_parallel(true)
	_popup_tween.tween_property(_popup, "modulate:a", 0.0, 0.55).set_delay(0.4)
	_popup_tween.tween_property(_popup, "position:y", _popup.position.y - 14.0, 0.9)


func flash(col: Color) -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	_flash.color = Color(col.r, col.g, col.b, 0.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "color:a", 0.18, 0.05)
	_flash_tween.tween_property(_flash, "color:a", 0.0, 0.42)
