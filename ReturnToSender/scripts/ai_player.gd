extends Player
## The opponent. Drives the same body as a human: it only decides where to walk,
## when to press its one button and when to burn a dash.
##
## Difficulty is not "better reactions" alone — it is how wrong its read of the
## bounce is (aim_error), how often it can be bothered to look (reaction), how
## much it trusts its hands (catch_rate) and whether it leads your movement.

var aim_error := 0.5
var reaction := 0.15
var catch_rate := 0.55
var dodge_mode := 1
var leads := false
var power := 0.6
var relentless := false

var _react := 0.0
var _target := Vector3.ZERO
var _aim_off := 0.0
var _catch_decided := false
var _catch_wants := false
var _hold := 0.0
var _throw_wait := 0.4
var _home := 9.0


func setup_tier(t: int) -> void:
	var d: Dictionary = Game.TIERS[clampi(t, 0, Game.TIERS.size() - 1)]
	aim_error = d["aim_error"]
	reaction = d["reaction"]
	catch_rate = d["catch_rate"]
	dodge_mode = d["dodge"]
	leads = d["leads"]
	power = d.get("power", 0.6)
	relentless = d.get("relentless", false)
	# Charge builds while it holds, so "power" is just how long it waits.
	_throw_wait = clampf(power * THROW_MAX_CHARGE - 0.02, 0.05, THROW_MAX_CHARGE - 0.02)


func _gather_input(delta: float) -> void:
	move_input = Vector2.ZERO
	if not alive or ball == null or arena == null:
		return

	_home = -9.0 if index == 0 else 9.0

	if holding_ball:
		_hold += delta
		if not charging:
			begin_charge()
		if _hold >= _throw_wait:
			release_throw()
		return
	_hold = 0.0

	if not ball.live:
		_walk_to(Vector3(_home, 0.0, 0.0))
		return

	var side := signf(global_position.x - ball.global_position.x)
	var approaching := side != 0.0 and side * ball.velocity.x > 0.0
	if not approaching:
		_catch_decided = false
		_walk_to(Vector3(_home, 0.0, 0.0))
		return

	# One read per approach: this is the tier's whole personality in three lines.
	if not _catch_decided:
		_catch_decided = true
		_aim_off = randf_range(-aim_error, aim_error)
		_catch_wants = randf() < catch_rate

	_react -= delta
	if _react <= 0.0:
		_react = maxf(0.02, reaction)
		_target = _predict()

	var dist := ball.distance_to_point(global_position)

	if _catch_wants and catch_cooldown <= 0.0 and catch_timer <= 0.0 and dist < catch_reach() - 0.15:
		open_catch()

	# IMPOSSIBLE does not flinch: too far to catch means dash *into* the ball to
	# close the last metre, instead of hopping sideways like the tiers below it.
	if relentless and dash_cooldown <= 0.0 and dist < 5.0 and dist > catch_reach() - 0.15:
		_walk_to(_target)
		request_dash()
		return

	if not _catch_wants and dash_cooldown <= 0.0 and dist < 3.2:
		if dodge_mode == 2 or (dodge_mode == 1 and dist < 2.4) or (dodge_mode == 0 and randf() < 0.06):
			_side_dash()
			return

	_walk_to(_target)


## Step the ball forward in the same maths the ball itself uses, reflecting off
## the current walls, until it crosses this player's line. No engine physics
## involved, so the prediction is honest even at 108 m/s.
func _predict() -> Vector3:
	var p: Vector3 = ball.global_position
	var v: Vector3 = ball.velocity
	if v.length() < 0.1:
		return Vector3(_home, 0.0, 0.0)
	var hx: float = arena.half_x - Ball.RADIUS
	var hz: float = arena.half_z - Ball.RADIUS
	var step := 0.02
	var side := signf(_home)
	for _i in 300:
		p += v * step
		if p.x > hx:
			p.x = hx
			v.x = -v.x
		elif p.x < -hx:
			p.x = -hx
			v.x = -v.x
		if p.z > hz:
			p.z = hz
			v.z = -v.z
		elif p.z < -hz:
			p.z = -hz
			v.z = -v.z
		if (p.x - global_position.x) * side >= 0.0:
			break
	p.z = clampf(p.z + _aim_off, -hz, hz)
	p.y = 0.0
	return p


func _side_dash() -> void:
	var perp := Vector3(-ball.velocity.z, 0.0, ball.velocity.x)
	if perp.length() < 0.01:
		return
	perp = perp.normalized()
	var a := global_position + perp * 2.5
	var b := global_position - perp * 2.5
	if a.distance_to(ball.global_position) < b.distance_to(ball.global_position):
		perp = -perp
	move_input = Vector2(perp.x, perp.z)
	request_dash()


func _walk_to(target: Vector3) -> void:
	var d := target - global_position
	d.y = 0.0
	if d.length() < 0.22:
		return
	d = d.normalized()
	move_input = Vector2(d.x, d.z)


## Killer leads the human: it throws at where you *will* be, not where you are.
func _throw_direction() -> Vector3:
	var aim: Vector3 = opponent.global_position if opponent != null else global_position + _facing()
	if relentless and opponent != null:
		# Cross-court into the far corner: the human has to sprint the width of
		# the court to have any chance of touching it.
		var fz := 1.0 if opponent.global_position.z < 0.0 else -1.0
		var z_edge := 5.0
		if arena != null:
			z_edge = arena.half_z * 0.88
		aim = Vector3(-signf(global_position.x) * 9.0, 0.0, fz * z_edge)
		if leads:
			var eta := aim.distance_to(global_position) / maxf(ball.speed(), 1.0)
			aim += opponent.velocity * eta
	elif leads and opponent != null:
		var flight := aim.distance_to(global_position) / maxf(ball.speed(), 1.0)
		aim += opponent.velocity * flight
	var d := aim - global_position
	d.y = 0.0
	d.z += randf_range(-aim_error, aim_error) * 0.7
	if d.length() < 0.05:
		return _facing()
	return d.normalized()
