extends Node
## Autoload "Game". Match settings, the input map, slow motion, and the synth.
##
## Deliberately uses plain int constants instead of enums so other scripts can
## read them off the autoload instance without dictionary lookups.

const MODE_PVP := 0
const MODE_AI := 1

## Rulesets. CLASSIC is the original game. REBOUND adds a facing guard:
## a ball that arrives against your front is knocked back, one that arrives
## from behind ends your round.
const RULES_CLASSIC := 0
const RULES_REBOUND := 1

const TIER_NAMES := ["ROOKIE", "REGULAR", "KILLER", "IMPOSSIBLE"]

## Powerups: dropped into the court mid-round, collected by walking over them.
## Every one of them is a temporary lie about the rules you just learned.
const POWERUPS := [
	{"id": "overclock", "name": "OVERCLOCK", "color": Color(1.0, 0.86, 0.25), "dur": 7.0},
	{"id": "slip", "name": "SLIP", "color": Color(0.45, 1.0, 0.62), "dur": 7.0},
	{"id": "magnet", "name": "MAGNET", "color": Color(0.55, 0.72, 1.0), "dur": 7.0},
	{"id": "surge", "name": "SURGE", "color": Color(1.0, 0.45, 0.88), "dur": 7.0},
]

## Spec section 7. aim_error in metres, reaction in seconds, catch_rate 0..1,
## dodge: 0 = random, 1 = when the ball is close, 2 = always. power 0..1 is how
## long it waits before letting go (it charges the throw while it holds).
## relentless is the IMPOSSIBLE tell: it never flinches away from the ball, and
## it returns the ball cross-court to the corner you are furthest from.
const TIERS := [
	{"aim_error": 1.6, "reaction": 0.35, "catch_rate": 0.20, "dodge": 0, "leads": false, "power": 0.45, "relentless": false},
	{"aim_error": 0.5, "reaction": 0.15, "catch_rate": 0.55, "dodge": 1, "leads": false, "power": 0.60, "relentless": false},
	{"aim_error": 0.1, "reaction": 0.05, "catch_rate": 0.85, "dodge": 2, "leads": true, "power": 0.80, "relentless": false},
	{"aim_error": 0.0, "reaction": 0.02, "catch_rate": 1.00, "dodge": 2, "leads": true, "power": 1.00, "relentless": true},
]

const FONT_PATH := "res://assets/fonts/Oxanium.ttf"

var mode := MODE_PVP
var tier := 1
var ruleset := RULES_CLASSIC
var sfx: Node = null

## Typography. Set as ThemeDB's fallback so every Label, Button and Label3D in
## the project picks it up without touching a single scene file.
var font_regular: Font = null
var font_bold: Font = null
var font_wide: Font = null

var _slow_token := 0


func _enter_tree() -> void:
	_setup_input()


func _ready() -> void:
	Engine.time_scale = 1.0
	_load_fonts()
	sfx = load("res://scripts/sfx.gd").new()
	sfx.name = "Sfx"
	add_child(sfx)


func _load_fonts() -> void:
	var base: Font = null
	if ResourceLoader.exists(FONT_PATH):
		base = load(FONT_PATH)
	if base == null:
		# Web/CI fallback: no shipped font, use whatever the OS has.
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(["Avenir Next", "Helvetica Neue", "Arial", "sans-serif"])
		base = sf
	font_regular = base
	font_bold = _font_variation(base, 700, 0)
	font_wide = _font_variation(base, 700, 7)
	ThemeDB.fallback_font = base


func _font_variation(base: Font, weight: int, spacing: int) -> FontVariation:
	var fv := FontVariation.new()
	fv.base_font = base
	fv.variation_opentype = {"wght": weight}
	fv.spacing_glyph = spacing
	return fv


func font(size_kind := 0) -> Font:
	match size_kind:
		1:
			return font_bold
		2:
			return font_wide
		_:
			return font_regular


func tier_data() -> Dictionary:
	return TIERS[clampi(tier, 0, TIERS.size() - 1)]


func mode_label() -> String:
	var base := "2 PLAYERS · SAME KEYBOARD"
	if mode != MODE_PVP:
		base = "VS AI · " + TIER_NAMES[clampi(tier, 0, TIER_NAMES.size() - 1)]
	if ruleset == RULES_REBOUND:
		base += "  ·  REBOUND"
	return base


## Slow the world down for a fixed number of *real* seconds. A later call
## cancels an earlier one so kills never stack into permanent slow motion.
func slowmo(scale: float, real_seconds: float) -> void:
	_slow_token += 1
	var token := _slow_token
	Engine.time_scale = scale
	await get_tree().create_timer(real_seconds, true, false, true).timeout
	if token == _slow_token:
		Engine.time_scale = 1.0


# --- input -----------------------------------------------------------------

## Registered in code rather than in project.godot so the controls are readable
## in one place. Physical keycodes = layout independent (AZERTY still works).
func _setup_input() -> void:
	_bind("p1_left", [KEY_A])
	_bind("p1_right", [KEY_D])
	_bind("p1_forward", [KEY_W])
	_bind("p1_back", [KEY_S])
	_bind("p1_dash", [KEY_SHIFT])
	_bind("p1_hand", [KEY_SPACE])

	_bind("p2_left", [KEY_LEFT])
	_bind("p2_right", [KEY_RIGHT])
	_bind("p2_forward", [KEY_UP])
	_bind("p2_back", [KEY_DOWN])
	_bind("p2_dash", [KEY_PERIOD])
	_bind("p2_hand", [KEY_SLASH])


func _bind(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
