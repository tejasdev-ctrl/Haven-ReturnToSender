extends Node3D
## Match flow: best of five, first to three rounds. The heat carries between
## rounds at 75%, so a match escalates and each round is still survivable.

const ST_INTRO := 0
const ST_LIVE := 1
const ST_POINT := 2
const ST_OVER := 3

const ROUNDS_TO_WIN := 3
const CARRYOVER := 0.75
const INTRO_TIME := 1.2
const POINT_TIME := 1.6
const SUDDEN_DEATH_AFTER := 25.0
const WALL_CLOSE_SPEED := 0.5
const MIN_HALF_X := 3.2
const MIN_HALF_Z := 2.2

const P1_COLOR := Color(0.25, 0.95, 1.0)
const P2_COLOR := Color(1.0, 0.32, 0.75)

const POWERUP_SCENE: PackedScene = preload("res://scenes/powerup.tscn")
const POWERUP_MAX := 2

@onready var arena: Node3D = $Arena
@onready var ball: Ball = $Ball
@onready var hud: CanvasLayer = $HUD
@onready var cam: Camera3D = $Camera

var players: Array = []
var scores := [0, 0]
var round_num := 0
var state := ST_INTRO

var _t := 0.0
var _rally := 0.0
var _closing := false
var _near_cd := [0.0, 0.0]
var _over_lock := 0.0
var _wall_cd := 0.0
var _powerups: Array = []
var _spawn_t := 4.0


func _ready() -> void:
	randomize()
	ball.arena = arena
	_spawn_players()
	ball.players = players
	ball.player_hit.connect(_on_player_hit)
	ball.wall_hit.connect(_on_wall_hit)
	ball.blocked.connect(_on_blocked)
	for p in players:
		p.caught_ball.connect(_on_caught)
		p.threw_ball.connect(_on_threw)
		p.dashed.connect(_on_dashed)
	hud.set_mode(Game.mode_label())
	_start_match()


func _spawn_players() -> void:
	var scene: PackedScene = load("res://scenes/player.tscn")
	for i in 2:
		var p = scene.instantiate()
		if i == 1 and Game.mode == Game.MODE_AI:
			p.set_script(load("res://scripts/ai_player.gd"))
		p.index = i
		p.display_name = "P%d" % (i + 1)
		p.color = P1_COLOR if i == 0 else P2_COLOR
		p.controls = {
			"left": "p%d_left" % (i + 1),
			"right": "p%d_right" % (i + 1),
			"forward": "p%d_forward" % (i + 1),
			"back": "p%d_back" % (i + 1),
			"dash": "p%d_dash" % (i + 1),
			"hand": "p%d_hand" % (i + 1),
		}
		p.arena = arena
		p.ball = ball
		add_child(p)
		if i == 1 and Game.mode == Game.MODE_AI:
			p.setup_tier(Game.tier)
		players.append(p)

	players[0].opponent = players[1]
	players[1].opponent = players[0]


func _process(delta: float) -> void:
	var rd := delta / maxf(Engine.time_scale, 0.01)
	_t += rd
	_wall_cd = maxf(0.0, _wall_cd - rd)
	for i in 2:
		_near_cd[i] = maxf(0.0, _near_cd[i] - rd)

	match state:
		ST_INTRO:
			if _t >= INTRO_TIME:
				_serve()
		ST_LIVE:
			_rally += delta
			_near_misses()
			_tick_powerups(delta)
			if _rally >= SUDDEN_DEATH_AFTER:
				_close_walls(delta)
		ST_POINT:
			if _t >= POINT_TIME:
				_advance()
		ST_OVER:
			_over_lock = maxf(0.0, _over_lock - rd)

	hud.set_speed(ball.heat)
	arena.set_heat(ball.heat)
	if players.size() == 2:
		hud.set_buff(0, players[0].buff_text(), players[0].buff_color)
		hud.set_buff(1, players[1].buff_text(), players[1].buff_color)


# --- flow -----------------------------------------------------------------

func _start_match() -> void:
	scores = [0, 0]
	round_num = 0
	ball.heat = 1.0
	hud.set_scores(0, 0)
	hud.clear_banner()
	_start_round()


func _start_round() -> void:
	round_num += 1
	state = ST_INTRO
	_t = 0.0
	_rally = 0.0
	_closing = false
	_near_cd = [0.0, 0.0]

	arena.reset_walls()
	ball.reset_center()
	ball.heat = maxf(1.0, ball.heat * CARRYOVER)
	_clear_powerups()
	_spawn_t = randf_range(2.5, 4.0)

	for i in players.size():
		players[i].reset_for_round(Vector3(-9.0 if i == 0 else 9.0, 0.0, 0.0))

	hud.set_mode(Game.mode_label())
	var sub := "×%.1f SPEED" % ball.heat
	if Game.ruleset == Game.RULES_REBOUND:
		sub = "REBOUND  ·  " + sub
	hud.banner("ROUND %d" % round_num, sub)
	Game.sfx.play("ui")


func _serve() -> void:
	state = ST_LIVE
	_t = 0.0
	_rally = 0.0
	var side := randi() % 2
	var aim := Vector3(-9.0 if side == 0 else 9.0, 0.0, randf_range(-4.0, 4.0))
	ball.serve(aim.normalized())
	hud.clear_banner()
	Game.sfx.play("serve")


func _advance() -> void:
	if scores[0] >= ROUNDS_TO_WIN or scores[1] >= ROUNDS_TO_WIN:
		_end_match()
	else:
		_start_round()


func _end_match() -> void:
	state = ST_OVER
	_t = 0.0
	_over_lock = 1.0
	var w := 0 if scores[0] > scores[1] else 1
	hud.banner("%s TAKES THE MATCH" % players[w].display_name, "ENTER — REMATCH     ·     ESC — MENU", players[w].color)
	hud.set_scores(scores[0], scores[1])
	cam.shake(0.6)
	Game.sfx.play("win")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_clear_powerups()
		Engine.time_scale = 1.0
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
	elif event.is_action_pressed("ui_accept") and state == ST_OVER and _over_lock <= 0.0:
		Engine.time_scale = 1.0
		Game.sfx.play("ui")
		_start_match()


# --- events ---------------------------------------------------------------

func _on_player_hit(p) -> void:
	if state != ST_LIVE:
		return
	state = ST_POINT
	_t = 0.0
	ball.live = false
	ball.velocity = Vector3.ZERO
	p.alive = false
	p.holding_ball = false
	p.charging = false

	var winner: int = 1 - p.index
	scores[winner] += 1
	hud.set_scores(scores[0], scores[1])

	cam.shake(1.0)
	cam.kick(7.0)
	Game.slowmo(0.25, 0.5)
	Game.sfx.play("kill")
	hud.banner("%s FLATTENED" % p.display_name, "ROUND %d" % round_num, p.color)
	hud.flash(p.color)
	arena.impact(p.global_position, p.color, 1.6)


func _on_wall_hit(pos: Vector3) -> void:
	if _wall_cd > 0.0:
		return
	_wall_cd = 0.045
	cam.shake(0.16)
	arena.pulse(0.55)
	arena.impact(pos, ball.heat_color())
	Game.sfx.play("wall", clampf(ball.heat / 4.0, 0.6, 2.2))


func _on_blocked(p) -> void:
	cam.shake(0.4)
	cam.kick(2.5)
	arena.impact(p.global_position, p.color, 1.2)
	Game.sfx.play("catch", 0.8)
	hud.popup("REBOUND", p.color)


func _on_caught(_p) -> void:
	_rally = 0.0
	cam.shake(0.18)
	Game.sfx.play("catch")


func _on_threw(_p, _dir: Vector3, power: float) -> void:
	cam.shake(0.12)
	Game.sfx.play("throw", 1.0 + power * 0.5)


func _on_dashed(_p) -> void:
	Game.sfx.play("dash")


# --- drama ----------------------------------------------------------------

func _near_misses() -> void:
	if ball.velocity.length() < 24.0:
		return
	for i in 2:
		if _near_cd[i] > 0.0:
			continue
		var p = players[i]
		if not p.alive or p.holding_ball:
			continue
		var d: float = ball.distance_to_point(p.global_position)
		if d > 0.95 and d < 1.9:
			_near_cd[i] = 2.5
			Game.slowmo(0.3, 0.16)
			cam.shake(0.25)
			Game.sfx.play("near")
			hud.popup("NEAR MISS", p.color)


# --- powerups -------------------------------------------------------------

func _tick_powerups(delta: float) -> void:
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		if _powerups.size() < POWERUP_MAX:
			_spawn_powerup()
		_spawn_t = randf_range(7.0, 11.0)

	for i in range(_powerups.size() - 1, -1, -1):
		var pu = _powerups[i]
		if not is_instance_valid(pu):
			_powerups.remove_at(i)
			continue
		for pl in players:
			if not pl.alive:
				continue
			var dx: float = pl.global_position.x - pu.global_position.x
			var dz: float = pl.global_position.z - pu.global_position.z
			if sqrt(dx * dx + dz * dz) < 1.0:
				pl.apply_powerup(pu.kind)
				arena.impact(pu.global_position, pu.color, 0.8)
				cam.shake(0.12)
				Game.sfx.play("catch", 1.5)
				hud.popup("%s  %s" % [pl.display_name, pu.power_name], pu.color)
				pu.queue_free()
				_powerups.remove_at(i)
				break


## Drop a pickup somewhere worth walking to: never on top of a player, never
## on top of another pickup, and never against a wall.
func _spawn_powerup() -> void:
	var pos := Vector3.ZERO
	var ok := false
	for _try in 16:
		pos = Vector3(randf_range(-8.5, 8.5), 1.0, randf_range(-5.2, 5.2))
		ok = true
		for pl in players:
			if pl.global_position.distance_to(pos) < 3.5:
				ok = false
		for pu in _powerups:
			if is_instance_valid(pu) and pu.global_position.distance_to(pos) < 2.6:
				ok = false
		if ok:
			break
	if not ok:
		return
	var pu = POWERUP_SCENE.instantiate()
	pu.setup(randi() % Game.POWERUPS.size())
	pu.position = pos
	add_child(pu)
	_powerups.append(pu)


func _clear_powerups() -> void:
	for pu in _powerups:
		if is_instance_valid(pu):
			pu.queue_free()
	_powerups.clear()


func _close_walls(delta: float) -> void:
	if not _closing:
		_closing = true
		hud.popup("SUDDEN DEATH", Color(1.0, 0.25, 0.2))
		Game.sfx.play("kill", 1.7)
	var hx: float = maxf(MIN_HALF_X, arena.half_x - WALL_CLOSE_SPEED * delta)
	var hz: float = maxf(MIN_HALF_Z, arena.half_z - WALL_CLOSE_SPEED * delta)
	arena.set_half_extents(hx, hz)
