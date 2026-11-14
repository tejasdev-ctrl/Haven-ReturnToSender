extends Node3D
class_name Ball
## The whole game.
##
## This is hand-integrated rather than a RigidBody3D on purpose. The spec says
## "re-normalise instead of trusting the bounce"; a manual integrator is the
## honest version of that: exact reflections, zero tunnelling at 108 m/s, and —
## the reason that matters — the AI can simulate the identical path, so its
## prediction is not fighting engine friction.

signal wall_hit(pos: Vector3)
signal player_hit(player: Node3D)
signal blocked(player: Node3D)
signal caught(player: Node3D)
signal thrown(player: Node3D)

const BASE_SPEED := 9.0
const MAX_HEAT := 12.0
const RADIUS := 0.35
const PLANE_Y := 1.0
const WALL_HEAT := 1.08
const PLAYER_HEAT := 1.12
const CATCH_HEAT := 1.10
const BLOCK_HEAT := 1.10

var heat := 1.0
var live := false
var held_by: Node3D = null
var velocity := Vector3.ZERO
var arena: Node3D = null
var players: Array = []

var curve_rate := 0.0
var curve_left := 0.0

var _thrower: Node3D = null
var _grace := 0.0
var _prev := Vector3.ZERO
var _trail: Array = []

var _core: MeshInstance3D
var _core_mat: StandardMaterial3D
var _halo: MeshInstance3D
var _halo_mat: StandardMaterial3D
var _gyro: Array = []
var _gyro_mat: StandardMaterial3D
var _gyro_t := 0.0
var _lamp: OmniLight3D
var _trail_mesh: ImmediateMesh
var _trail_node: MeshInstance3D


func _ready() -> void:
	_build()
	reset_center()


func _build() -> void:
	_core_mat = StandardMaterial3D.new()
	_core_mat.albedo_color = Color(0.95, 0.97, 1.0)
	_core_mat.roughness = 0.2
	_core_mat.emission_enabled = true
	_core_mat.emission = Color(1, 1, 1)
	_core_mat.emission_energy_multiplier = 2.4

	var sphere := SphereMesh.new()
	sphere.radius = RADIUS
	sphere.height = RADIUS * 2.0
	sphere.radial_segments = 24
	sphere.rings = 12

	_core = MeshInstance3D.new()
	_core.name = "Core"
	_core.mesh = sphere
	_core.material_override = _core_mat
	add_child(_core)

	# Additive shell around the ball. It grows and brightens with heat, so the
	# ball reads as a light source rather than a white dot at distance.
	_halo_mat = StandardMaterial3D.new()
	_halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_halo_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_halo_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_halo_mat.albedo_color = Color(1, 1, 1, 0.16)

	var halo_sphere := SphereMesh.new()
	halo_sphere.radius = 0.62
	halo_sphere.height = 1.24
	halo_sphere.radial_segments = 20
	halo_sphere.rings = 10
	_halo = MeshInstance3D.new()
	_halo.name = "Halo"
	_halo.mesh = halo_sphere
	_halo.material_override = _halo_mat
	add_child(_halo)

	# Two counter-rotating rings. The ball is the hero of the game, so it gets
	# some structure instead of being a white dot with a trail.
	_gyro_mat = StandardMaterial3D.new()
	_gyro_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_gyro_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_gyro_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_gyro_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_gyro_mat.albedo_color = Color(1, 1, 1, 0.5)

	var gyro_mesh := TorusMesh.new()
	gyro_mesh.inner_radius = 0.74
	gyro_mesh.outer_radius = 0.79
	gyro_mesh.rings = 36
	gyro_mesh.ring_segments = 3
	for _i in 2:
		var g := MeshInstance3D.new()
		g.mesh = gyro_mesh
		g.material_override = _gyro_mat
		add_child(g)
		_gyro.append(g)

	_lamp = OmniLight3D.new()
	_lamp.name = "Glow"
	_lamp.light_color = Color(1, 0.92, 0.82)
	_lamp.light_energy = 1.6
	_lamp.omni_range = 7.0
	_lamp.shadow_enabled = false
	add_child(_lamp)

	var tmat := StandardMaterial3D.new()
	tmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tmat.vertex_color_use_as_albedo = true
	tmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	tmat.cull_mode = BaseMaterial3D.CULL_DISABLED

	_trail_mesh = ImmediateMesh.new()
	_trail_node = MeshInstance3D.new()
	_trail_node.name = "Trail"
	_trail_node.mesh = _trail_mesh
	_trail_node.material_override = tmat
	_trail_node.top_level = true
	add_child(_trail_node)
	_trail_node.global_transform = Transform3D.IDENTITY


func speed() -> float:
	return BASE_SPEED * heat


func _physics_process(delta: float) -> void:
	_prev = global_position

	if held_by != null:
		if held_by.has_method("hand_position"):
			global_position = held_by.hand_position()
		_record_trail(delta)
		return

	if not live:
		_record_trail(delta)
		return

	if _grace > 0.0:
		_grace -= delta

	if curve_left > 0.0:
		velocity = velocity.rotated(Vector3.UP, curve_rate * delta)
		curve_left -= delta

	velocity = velocity.normalized() * speed()

	# Sub-step so a 108 m/s ball moves in chunks smaller than its own radius.
	var travel := velocity.length() * delta
	var steps := clampi(int(ceil(travel / 0.12)), 1, 24)
	var sdt := delta / float(steps)
	for _i in steps:
		if not live:
			break
		_substep(sdt)

	_record_trail(delta)


func _substep(dt: float) -> void:
	var from := global_position
	var to := from + velocity * dt

	var hx: float = arena.half_x - RADIUS
	var hz: float = arena.half_z - RADIUS
	var normal := Vector3.ZERO
	var bounced := false

	if to.x > hx:
		to.x = hx
		normal.x = -1.0
		bounced = true
	elif to.x < -hx:
		to.x = -hx
		normal.x = 1.0
		bounced = true
	if to.z > hz:
		to.z = hz
		normal.z = -1.0
		bounced = true
	elif to.z < -hz:
		to.z = -hz
		normal.z = 1.0
		bounced = true
	to.y = PLANE_Y

	for p in players:
		if not p.alive:
			continue
		if p == _thrower and _grace > 0.0:
			continue
		var near := segment_distance(global_position, to, p.global_position)
		# REBOUND: a ball arriving against the guard is knocked back, and pays
		# for the privilege by getting hotter. The guard is wider than the body,
		# so it is tested first — a ball that would have clipped your shoulder
		# now bounces off your chest instead.
		if near < RADIUS + p.block_radius() and p.guards_front(velocity):
			p.blocks_from_front(velocity)
			var n: Vector3 = p.facing
			velocity = velocity.bounce(n)
			velocity.y = 0.0
			if velocity.length() < 0.5:
				velocity = -n
			global_position = p.global_position + n * (RADIUS + p.block_radius() + 0.06)
			_prev = global_position
			heat = minf(heat * BLOCK_HEAT, MAX_HEAT)
			_thrower = p
			_grace = 0.18
			blocked.emit(p)
			return
		if near < RADIUS + p.hit_radius():
			global_position = to
			velocity = Vector3.ZERO
			live = false
			heat = minf(heat * PLAYER_HEAT, MAX_HEAT)
			player_hit.emit(p)
			return

	global_position = to

	if bounced:
		velocity = velocity.bounce(normal.normalized())
		velocity.y = 0.0
		heat = minf(heat * WALL_HEAT, MAX_HEAT)
		wall_hit.emit(to)


# --- state changes ---------------------------------------------------------

func serve(dir: Vector3) -> void:
	global_position = Vector3(0.0, PLANE_Y, 0.0)
	_prev = global_position
	velocity = dir.normalized() * speed()
	velocity.y = 0.0
	held_by = null
	_thrower = null
	_grace = 0.0
	curve_left = 0.0
	live = true
	_trail.clear()


func reset_center() -> void:
	live = false
	held_by = null
	velocity = Vector3.ZERO
	curve_left = 0.0
	_grace = 0.0
	_thrower = null
	global_position = Vector3(0.0, PLANE_Y, 0.0)
	_prev = global_position
	_trail.clear()


func catch_by(player: Node3D) -> void:
	held_by = player
	live = false
	velocity = Vector3.ZERO
	curve_left = 0.0
	_trail.clear()
	caught.emit(player)


func throw_back(player: Node3D, dir: Vector3, curve: float, power: float) -> void:
	# Catching and sending it back is the one touch that pays you for being brave.
	heat = minf(heat * CATCH_HEAT, MAX_HEAT)
	held_by = null
	_thrower = player
	_grace = 0.22
	var flat := Vector3(dir.x, 0.0, dir.z).normalized()
	global_position = Vector3(player.global_position.x, PLANE_Y, player.global_position.z) + flat * (player.hit_radius() + RADIUS + 0.2)
	_prev = global_position
	velocity = flat * speed()
	curve_rate = curve
	curve_left = 0.35 * clampf(power, 0.0, 1.0)
	live = true
	_trail.clear()
	thrown.emit(player)


# --- queries used by players, AI and HUD -----------------------------------

## Distance from a point (ignoring Y) to the path the ball travelled this tick.
func distance_to_point(p: Vector3) -> float:
	return segment_distance(_prev, global_position, p)


func segment_distance(a: Vector3, b: Vector3, p: Vector3) -> float:
	var pa := Vector2(a.x, a.z)
	var pb := Vector2(b.x, b.z)
	var pp := Vector2(p.x, p.z)
	var ab := pb - pa
	var l2 := ab.length_squared()
	if l2 < 0.000001:
		return pp.distance_to(pa)
	var t := clampf((pp - pa).dot(ab) / l2, 0.0, 1.0)
	return pp.distance_to(pa + ab * t)


func heat_color() -> Color:
	var k := clampf((heat - 1.0) / (MAX_HEAT - 1.0), 0.0, 1.0)
	var white := Color(0.95, 0.97, 1.0)
	var amber := Color(1.0, 0.55, 0.15)
	var hot := Color(1.0, 0.99, 0.95)
	if k < 0.45:
		return white.lerp(amber, k / 0.45)
	return amber.lerp(hot, (k - 0.45) / 0.55)


# --- visuals ---------------------------------------------------------------

func _process(delta: float) -> void:
	var k := clampf((heat - 1.0) / (MAX_HEAT - 1.0), 0.0, 1.0)
	var c := heat_color()
	if _core_mat != null:
		_core_mat.emission = c
		_core_mat.albedo_color = c
		_core_mat.emission_energy_multiplier = 2.4 + k * 7.0
	if _lamp != null:
		_lamp.light_color = c
		_lamp.light_energy = 1.0 + k * 4.0
	if _halo != null:
		_halo.scale = Vector3.ONE * (1.0 + k * 0.45)
		_halo_mat.albedo_color = Color(c.r, c.g, c.b, 0.14 + k * 0.18)
	if _gyro.size() == 2:
		_gyro_t += delta
		_gyro[0].rotation = Vector3(_gyro_t * 4.2, _gyro_t * 2.6, 0.0)
		_gyro[1].rotation = Vector3(0.0, -_gyro_t * 3.4, PI * 0.5)
		_gyro_mat.albedo_color = Color(c.r, c.g, c.b, 0.3 + k * 0.35)
	if _core != null and not live and held_by == null:
		_core.visible = false
	elif _core != null:
		_core.visible = true
	_draw_trail(delta)


func _record_trail(delta: float) -> void:
	if not live or held_by != null:
		_trail.clear()
		return
	for i in range(_trail.size() - 1, -1, -1):
		_trail[i]["t"] += delta
		if float(_trail[i]["t"]) > 0.11:
			_trail.remove_at(i)
	_trail.append({"p": global_position, "t": 0.0})
	# Cap by distance as well as time. At heat 12 the ball covers 12 m in the
	# trail's lifetime, which reads as a plank rather than a streak.
	while _trail.size() > 2:
		var head: Vector3 = _trail[_trail.size() - 1]["p"]
		var tail: Vector3 = _trail[0]["p"]
		if head.distance_to(tail) > 5.0:
			_trail.remove_at(0)
		else:
			break
	if _trail.size() > 40:
		_trail.remove_at(0)


func _draw_trail(_delta: float) -> void:
	if _trail_mesh == null:
		return
	_trail_mesh.clear_surfaces()
	if _trail.size() < 3:
		return

	var c := heat_color()
	var n := _trail.size()
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in n:
		var p: Vector3 = _trail[i]["p"]
		var j: int = mini(i + 1, n - 1)
		var q: Vector3 = _trail[j]["p"]
		var dir := q - p
		if dir.length() < 0.0005:
			dir = Vector3.RIGHT
		var side := dir.normalized().cross(Vector3.UP).normalized()
		var f := float(i) / float(n - 1)          # 0 at the tail, 1 at the ball
		var w := 0.02 + 0.24 * f
		var col := c * (0.02 + 0.52 * f * f)
		_trail_mesh.surface_set_color(col)
		_trail_mesh.surface_add_vertex(p - side * w)
		_trail_mesh.surface_set_color(col)
		_trail_mesh.surface_add_vertex(p + side * w)
	_trail_mesh.surface_end()
