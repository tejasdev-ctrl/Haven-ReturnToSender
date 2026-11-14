extends CharacterBody3D
class_name Player
## One player. One key does everything: hold the ball to charge a throw, tap to
## open the catch window. Dashing is the only other verb.
##
## Input lives in _gather_input() so the AI subclass can drive the exact same
## body without duplicating a line of movement, catch or throw logic.

signal caught_ball(player)
signal threw_ball(player, dir, power)
signal dashed(player)

const RADIUS := 0.4
const HEIGHT := 1.8
const RUN_SPEED := 6.0
const DASH_SPEED := 18.0
const DASH_TIME := 0.15
const DASH_COOLDOWN := 1.2
const CATCH_WINDOW := 0.22
const CATCH_RADIUS := 2.2
const CATCH_MISS_COOLDOWN := 0.6
const THROW_MAX_CHARGE := 0.8
const CURVE_RATE := 1.5
## A block leaves the guard down, so standing still and eating the rally on
## your chest stops working as the ball gets faster.
const BLOCK_COOLDOWN := 0.9

## The guard covers more than the body does. It reaches BLOCK_REACH metres past
## the hitbox and out to BLOCK_ARC on the dot product (negative means it wraps
## past a right angle). Widened because eating everything on the front felt
## unfair — nudge these down again for a harsher REBOUND.
const BLOCK_REACH := 0.16
const BLOCK_ARC := -0.18

# Powerup effects.
const BUFF_SPEED := 1.45     # run speed multiplier
const BUFF_HIT := 0.26       # capsule radius while slipping
const BUFF_CATCH := 1.25     # extra metres of catch reach
const BUFF_DASH := 0.35      # dash cooldown multiplier

var index := 0
var color := Color.CYAN
var display_name := "P1"
var controls: Dictionary = {}
var arena: Node3D = null
var ball: Ball = null
var opponent: Player = null

var move_input := Vector2.ZERO
var facing := Vector3.RIGHT
var alive := true
var holding_ball := false
var charging := false
var charge := 0.0
var catch_timer := 0.0
var catch_cooldown := 0.0
var block_cd := 0.0
var dash_timer := 0.0
var dash_cooldown := 0.0
var dash_dir := Vector3.ZERO

var buff_id := ""
var buff_name := ""
var buff_color := Color.WHITE
var buff_time := 0.0

var _body: MeshInstance3D
var _mat: StandardMaterial3D
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _catch_ring: MeshInstance3D
var _catch_mat: StandardMaterial3D
var _tag: Label3D
var _yaw: Node3D
var _nose: MeshInstance3D
var _nose_mat: StandardMaterial3D


func _ready() -> void:
	_build()


func _build() -> void:
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = color * 0.22
	_mat.roughness = 0.35
	_mat.emission_enabled = true
	_mat.emission = color
	_mat.emission_energy_multiplier = 1.4

	var capsule := CapsuleMesh.new()
	capsule.radius = RADIUS
	capsule.height = HEIGHT
	capsule.radial_segments = 16
	capsule.rings = 8

	_body = MeshInstance3D.new()
	_body.name = "Body"
	_body.mesh = capsule
	_body.material_override = _mat
	_body.position = Vector3(0, HEIGHT * 0.5, 0)
	add_child(_body)

	# Back-face-only additive shell: a cheap neon rim around the silhouette.
	var shell_mat := StandardMaterial3D.new()
	shell_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shell_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shell_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	shell_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	shell_mat.albedo_color = Color(color.r, color.g, color.b, 0.16)

	var shell_mesh := CapsuleMesh.new()
	shell_mesh.radius = RADIUS * 1.1
	shell_mesh.height = HEIGHT * 1.05
	shell_mesh.radial_segments = 16
	shell_mesh.rings = 8
	var shell := MeshInstance3D.new()
	shell.name = "Rim"
	shell.mesh = shell_mesh
	shell.material_override = shell_mat
	_body.add_child(shell)

	_ring_mat = StandardMaterial3D.new()
	_ring_mat.albedo_color = color
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.emission_enabled = true
	_ring_mat.emission = color
	_ring_mat.emission_energy_multiplier = 2.0

	var foot := TorusMesh.new()
	foot.inner_radius = 0.58
	foot.outer_radius = 0.74
	foot.rings = 40
	foot.ring_segments = 4
	_ring = MeshInstance3D.new()
	_ring.name = "FootRing"
	_ring.mesh = foot
	_ring.material_override = _ring_mat
	_ring.position = Vector3(0, 0.04, 0)
	add_child(_ring)

	_catch_mat = StandardMaterial3D.new()
	_catch_mat.albedo_color = Color(1, 1, 1, 0.5)
	_catch_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_catch_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_catch_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_catch_mat.emission_enabled = true
	_catch_mat.emission = color
	_catch_mat.emission_energy_multiplier = 2.0
	_catch_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Exactly the 2.2 m catch reach, so the mechanic is legible instead of magic.
	var reach := TorusMesh.new()
	reach.inner_radius = CATCH_RADIUS - 0.09
	reach.outer_radius = CATCH_RADIUS
	reach.rings = 64
	reach.ring_segments = 4
	_catch_ring = MeshInstance3D.new()
	_catch_ring.name = "CatchRing"
	_catch_ring.mesh = reach
	_catch_ring.material_override = _catch_mat
	_catch_ring.position = Vector3(0, 0.06, 0)
	_catch_ring.visible = false
	add_child(_catch_ring)

	# The guard: a glowing wedge on the chest that shows which way you are
	# pointing in REBOUND. Hidden in CLASSIC, where it would only repeat the
	# fact that you always face your opponent.
	_yaw = Node3D.new()
	_yaw.name = "Yaw"
	add_child(_yaw)

	_nose_mat = StandardMaterial3D.new()
	_nose_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_nose_mat.albedo_color = color
	_nose_mat.emission_enabled = true
	_nose_mat.emission = color
	_nose_mat.emission_energy_multiplier = 3.0

	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.16
	cone.height = 0.44
	cone.radial_segments = 14
	cone.rings = 0
	_nose = MeshInstance3D.new()
	_nose.name = "Guard"
	_nose.mesh = cone
	_nose.material_override = _nose_mat
	_nose.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	_nose.position = Vector3(0.0, 1.18, 0.5)
	_yaw.add_child(_nose)

	# A thin beacon so both players stay readable from a high camera.
	var beam_mat := StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam_mat.albedo_color = Color(color.r, color.g, color.b, 0.11)

	var beam := CylinderMesh.new()
	beam.top_radius = 0.02
	beam.bottom_radius = 0.12
	beam.height = 2.8
	beam.radial_segments = 12
	beam.rings = 0
	var beam_node := MeshInstance3D.new()
	beam_node.name = "Beacon"
	beam_node.mesh = beam
	beam_node.material_override = beam_mat
	beam_node.position = Vector3(0.0, 3.3, 0.0)
	add_child(beam_node)

	_tag = Label3D.new()
	_tag.name = "Tag"
	_tag.text = display_name
	_tag.position = Vector3(0, 2.5, 0)
	_tag.font_size = 64
	_tag.pixel_size = 0.005
	_tag.modulate = color
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.outline_size = 18
	_tag.outline_modulate = Color(0, 0, 0, 0.85)
	add_child(_tag)
	_tag.text = display_name


func _physics_process(delta: float) -> void:
	if not alive:
		return
	_gather_input(delta)
	_tick_timers(delta)
	_update_facing()
	_move(delta)
	_update_catch_window(delta)
	_update_charge(delta)


func _process(delta: float) -> void:
	_update_visuals(delta)


# --- input (overridden by the AI) ------------------------------------------

func _gather_input(_delta: float) -> void:
	move_input = Vector2.ZERO
	if controls.is_empty():
		return
	move_input = Input.get_vector(controls["left"], controls["right"], controls["forward"], controls["back"])
	if Input.is_action_just_pressed(controls["dash"]):
		request_dash()
	if Input.is_action_just_pressed(controls["hand"]):
		hand_pressed()
	if Input.is_action_just_released(controls["hand"]):
		hand_released()


func hand_pressed() -> void:
	if holding_ball:
		if not charging:
			begin_charge()
	else:
		open_catch()


func hand_released() -> void:
	if charging:
		release_throw()


func open_catch() -> void:
	if catch_cooldown > 0.0 or catch_timer > 0.0:
		return
	catch_timer = CATCH_WINDOW


func begin_charge() -> void:
	if not holding_ball:
		return
	charging = true
	charge = 0.0


func request_dash() -> void:
	if dash_cooldown > 0.0 or not alive:
		return
	var d := Vector3(move_input.x, 0.0, move_input.y)
	if d.length() < 0.1:
		d = _facing()
	dash_dir = d.normalized()
	dash_timer = DASH_TIME
	var mult := BUFF_DASH if _has_buff("surge") else 1.0
	dash_cooldown = DASH_COOLDOWN * mult
	dashed.emit(self)


# --- per-tick --------------------------------------------------------------

func _tick_timers(delta: float) -> void:
	if buff_time > 0.0:
		buff_time = maxf(0.0, buff_time - delta)
		if buff_time == 0.0:
			buff_id = ""
	dash_timer = maxf(0.0, dash_timer - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	catch_cooldown = maxf(0.0, catch_cooldown - delta)
	block_cd = maxf(0.0, block_cd - delta)


func _move(delta: float) -> void:
	var vel := Vector3.ZERO
	if dash_timer > 0.0:
		vel = dash_dir * DASH_SPEED
	else:
		var spd := RUN_SPEED * (BUFF_SPEED if _has_buff("overclock") else 1.0)
		vel = Vector3(move_input.x, 0.0, move_input.y) * spd
	velocity = vel

	if arena == null:
		global_position += vel * delta
		return
	var pos := global_position + vel * delta
	var lim_x: float = arena.half_x - (RADIUS + 0.04)
	var lim_z: float = arena.half_z - (RADIUS + 0.04)
	pos.x = clampf(pos.x, -lim_x, lim_x)
	pos.z = clampf(pos.z, -lim_z, lim_z)
	pos.y = 0.0
	global_position = pos


func _update_catch_window(delta: float) -> void:
	if catch_timer <= 0.0:
		return
	catch_timer -= delta
	if ball != null and ball.live and ball.distance_to_point(global_position) <= catch_reach():
		_do_catch()
		return
	if catch_timer <= 0.0:
		catch_timer = 0.0
		if not holding_ball:
			catch_cooldown = CATCH_MISS_COOLDOWN


func _update_charge(delta: float) -> void:
	if not charging:
		return
	charge = minf(charge + delta, THROW_MAX_CHARGE)
	# Fully charged means released: the ball is not yours to sit on.
	if charge >= THROW_MAX_CHARGE:
		release_throw()


func _do_catch() -> void:
	if ball == null:
		return
	holding_ball = true
	catch_timer = 0.0
	catch_cooldown = 0.0
	charging = false
	charge = 0.0
	ball.catch_by(self)
	caught_ball.emit(self)


func release_throw() -> void:
	if not charging or not holding_ball or ball == null:
		return
	var power := clampf(charge / THROW_MAX_CHARGE, 0.0, 1.0)
	var dir := _throw_direction()
	var curve := _curve_amount(dir) * power
	ball.throw_back(self, dir, curve, power)
	holding_ball = false
	charging = false
	charge = 0.0
	threw_ball.emit(self, dir, power)


# --- aiming ---------------------------------------------------------------

func _has_buff(id: String) -> bool:
	return buff_id == id and buff_time > 0.0


func apply_powerup(kind: int) -> void:
	var d: Dictionary = Game.POWERUPS[clampi(kind, 0, Game.POWERUPS.size() - 1)]
	buff_id = d["id"]
	buff_name = d["name"]
	buff_color = d["color"]
	buff_time = d["dur"]


func buff_text() -> String:
	if buff_id == "" or buff_time <= 0.0:
		return ""
	return "%s  %.1fs" % [buff_name, buff_time]


## Radius the ball can actually hit. SLIP makes you a smaller target.
func hit_radius() -> float:
	return BUFF_HIT if _has_buff("slip") else RADIUS


## How far the hand reaches. MAGNET stretches it.
func catch_reach() -> float:
	return CATCH_RADIUS + (BUFF_CATCH if _has_buff("magnet") else 0.0)


func hand_position() -> Vector3:
	return global_position + Vector3(0, Ball.PLANE_Y + 0.05, 0) + _facing() * 0.55


func _update_facing() -> void:
	if Game.ruleset == Game.RULES_REBOUND:
		# Your guard points where you last walked. Standing still keeps it,
		# so every sidestep is also a decision about what you are covering.
		if move_input.length() > 0.2:
			facing = Vector3(move_input.x, 0.0, move_input.y).normalized()
	else:
		var d := _toward_opponent()
		if d.length() > 0.05:
			facing = d.normalized()


func _toward_opponent() -> Vector3:
	if opponent == null:
		return Vector3(1, 0, 0)
	var d := opponent.global_position - global_position
	d.y = 0.0
	return d


func _facing() -> Vector3:
	return facing


## How far the guard sticks out in front of the body.
func block_radius() -> float:
	return hit_radius() + BLOCK_REACH


## True when the ball is arriving into the player's front. Pure: safe to ask as
## often as you like, it does not spend the guard.
func guards_front(incoming: Vector3) -> bool:
	if Game.ruleset != Game.RULES_REBOUND or not alive or block_cd > 0.0:
		return false
	if incoming.length() < 0.001:
		return false
	var from := -incoming.normalized()
	return from.dot(facing) > BLOCK_ARC


## Commits to the block and puts the guard on cooldown. Only call this once you
## already know the ball is inside block_radius().
func blocks_from_front(incoming: Vector3) -> bool:
	if not guards_front(incoming):
		return false
	block_cd = BLOCK_COOLDOWN
	return true


func _throw_direction() -> Vector3:
	if opponent == null:
		return _facing()
	var d := opponent.global_position - global_position
	d.y = 0.0
	if d.length() < 0.05:
		return _facing()
	return d.normalized()


## Hold a direction while charging and the throw bends that way. Straight input
## throws straight, so the simple shot is always available.
func _curve_amount(dir: Vector3) -> float:
	var lateral := Vector3(move_input.x, 0.0, move_input.y)
	if lateral.length() < 0.35:
		return 0.0
	var s := dir.cross(lateral.normalized()).y
	if absf(s) < 0.05:
		return 0.0
	return signf(s) * CURVE_RATE


# --- round bookkeeping -----------------------------------------------------

func reset_for_round(pos: Vector3) -> void:
	alive = true
	holding_ball = false
	charging = false
	charge = 0.0
	catch_timer = 0.0
	catch_cooldown = 0.0
	block_cd = 0.0
	dash_timer = 0.0
	dash_cooldown = 0.0
	buff_id = ""
	buff_time = 0.0
	move_input = Vector2.ZERO
	global_position = pos
	velocity = Vector3.ZERO
	if _body != null:
		_body.scale = Vector3.ONE
		_body.position = Vector3(0, HEIGHT * 0.5, 0)
		_body.visible = true


func _update_visuals(delta: float) -> void:
	if _mat == null:
		return
	var w := 1.0 - exp(-14.0 * delta)

	var target := 1.4
	if not alive:
		target = 0.15
	elif dash_timer > 0.0:
		target = 4.6
	if charging:
		target += 2.2 * (charge / THROW_MAX_CHARGE)
	_mat.emission_energy_multiplier = lerpf(_mat.emission_energy_multiplier, target, w)

	var squash := Vector3.ONE
	if not alive:
		squash = Vector3(1.5, 0.1, 1.5)
	_body.scale = _body.scale.lerp(squash, 1.0 - exp(-10.0 * delta))
	_body.position.y = HEIGHT * 0.5 * _body.scale.y

	_yaw.rotation.y = atan2(facing.x, facing.z)
	_nose.visible = Game.ruleset == Game.RULES_REBOUND and alive
	if _nose.visible:
		if block_cd > 0.0:
			_nose_mat.emission_energy_multiplier = 0.35
		else:
			_nose_mat.emission_energy_multiplier = 2.4 + 1.6 * clampf(charge / THROW_MAX_CHARGE, 0.0, 1.0)

	_catch_ring.visible = alive and catch_timer > 0.0
	if _catch_ring.visible:
		var k := clampf(catch_timer / CATCH_WINDOW, 0.0, 1.0)
		var reach_scale := catch_reach() / CATCH_RADIUS
		_catch_ring.scale = Vector3.ONE * lerpf(0.9, 1.0, 1.0 - k) * reach_scale
		_catch_mat.emission_energy_multiplier = 2.0 + 3.0 * k

	var rs := 1.0
	if charging:
		rs = 1.0 + 0.35 * (charge / THROW_MAX_CHARGE)
	if buff_id != "":
		rs += 0.25
		_ring_mat.albedo_color = buff_color
		_ring_mat.emission = buff_color
	else:
		_ring_mat.albedo_color = color
		_ring_mat.emission = color
	_ring.scale = Vector3.ONE * rs
	_ring.visible = alive
	if _tag != null:
		_tag.visible = true
