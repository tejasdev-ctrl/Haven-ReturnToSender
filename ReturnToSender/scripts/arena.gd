extends Node3D
## The court: floor, neon grid, neon cage, lights and the sudden-death walls.
##
## Everything is generated from primitives at runtime — no meshes, textures or
## materials are imported. The ball and the players never touch Godot physics:
## this script owns the numbers they collide against (half_x / half_z), which is
## what makes the AI's prediction exact.

const HALF_X := 12.0
const HALF_Z := 7.0
const WALL_H := 5.0

var half_x := HALF_X
var half_z := HALF_Z

var _trim: StandardMaterial3D
var _grid: StandardMaterial3D
var _cage: StandardMaterial3D
var _closer_mat: StandardMaterial3D
var _closers: Array = []
var _rings: Array = []
var _ring_i := 0
var _pulse := 0.0
var _heat := 1.0


func _ready() -> void:
	_build()


func _build() -> void:
	_build_environment()
	_build_floor()
	_build_grid()
	_build_zones()
	_build_borders()
	_build_cage()
	_build_gates()
	_build_lights()
	_build_rings()
	_build_closers()


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.014, 0.026)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.16, 0.22, 0.36)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.15
	env.glow_hdr_threshold = 0.75
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	# A little grade on the whole frame: more contrast, more colour, which is
	# most of what separates "neon" from "flat quads on black".
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 1.20
	env.adjustment_brightness = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _build_floor() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.028, 0.032, 0.048)
	mat.metallic = 0.35
	mat.roughness = 0.5
	var mi := _box(Vector3(HALF_X * 2.0, 0.4, HALF_Z * 2.0), Vector3(0, -0.2, 0), mat)
	mi.name = "Floor"


func _build_grid() -> void:
	# One MultiMesh draws the whole floor grid: cheap, and it can be pushed
	# brighter as the ball heats up.
	_grid = StandardMaterial3D.new()
	_grid.albedo_color = Color(0.01, 0.03, 0.04)
	_grid.emission_enabled = true
	_grid.emission = Color(0.12, 0.85, 1.0)
	_grid.emission_energy_multiplier = 0.5
	_grid.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var unit := BoxMesh.new()
	unit.size = Vector3.ONE

	var xforms: Array = []
	var x := -HALF_X + 2.0
	while x < HALF_X - 0.01:
		xforms.append(Transform3D(Basis.from_scale(Vector3(0.045, 0.02, HALF_Z * 2.0)), Vector3(x, 0.01, 0)))
		x += 2.0
	var z := -HALF_Z + 2.0
	while z < HALF_Z - 0.01:
		xforms.append(Transform3D(Basis.from_scale(Vector3(HALF_X * 2.0, 0.02, 0.045)), Vector3(0, 0.01, z)))
		z += 2.0

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = unit
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Grid"
	mmi.multimesh = mm
	mmi.material_override = _grid
	add_child(mmi)


func _build_borders() -> void:
	_trim = StandardMaterial3D.new()
	_trim.albedo_color = Color(0.7, 1.0, 1.0)
	_trim.emission_enabled = true
	_trim.emission = Color(0.3, 1.0, 1.0)
	_trim.emission_energy_multiplier = 2.4
	_trim.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var t := 0.16
	var y := 0.035
	_box(Vector3(HALF_X * 2.0, 0.03, t), Vector3(0, y, -HALF_Z), _trim).name = "BorderFar"
	_box(Vector3(HALF_X * 2.0, 0.03, t), Vector3(0, y, HALF_Z), _trim).name = "BorderNear"
	_box(Vector3(t, 0.03, HALF_Z * 2.0), Vector3(-HALF_X, y, 0), _trim).name = "BorderLeft"
	_box(Vector3(t, 0.03, HALF_Z * 2.0), Vector3(HALF_X, y, 0), _trim).name = "BorderRight"

	# The halfway line: the only line on the court, because this game is not
	# about territory, it is about the ball coming back.
	_box(Vector3(0.07, 0.03, HALF_Z * 2.0), Vector3(0, y, 0), _trim).name = "Halfway"

	var torus := TorusMesh.new()
	torus.inner_radius = 1.55
	torus.outer_radius = 1.7
	torus.rings = 64
	torus.ring_segments = 4
	var circle := MeshInstance3D.new()
	circle.name = "CentreCircle"
	circle.mesh = torus
	circle.material_override = _trim
	circle.position = Vector3(0, 0.03, 0)
	add_child(circle)


func _build_cage() -> void:
	_cage = StandardMaterial3D.new()
	_cage.albedo_color = Color(0.3, 0.75, 1.0)
	_cage.emission_enabled = true
	_cage.emission = Color(0.18, 0.55, 1.0)
	_cage.emission_energy_multiplier = 1.3
	_cage.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var unit := BoxMesh.new()
	unit.size = Vector3.ONE

	var xforms: Array = []
	var post := 0.1
	# Corner posts.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			xforms.append(Transform3D(Basis.from_scale(Vector3(post, WALL_H, post)), Vector3(sx * HALF_X, WALL_H * 0.5, sz * HALF_Z)))
	# Uprights on the far wall only. The near wall is left open: we look in
	# from that side, and its rails would draw straight across the play area.
	var x := -HALF_X + 4.0
	while x < HALF_X - 0.1:
		xforms.append(Transform3D(Basis.from_scale(Vector3(0.06, WALL_H, 0.06)), Vector3(x, WALL_H * 0.5, -HALF_Z)))
		x += 4.0
	# Uprights along the short walls.
	var z := -HALF_Z + 3.5
	while z < HALF_Z - 0.1:
		for sx in [-1.0, 1.0]:
			xforms.append(Transform3D(Basis.from_scale(Vector3(0.06, WALL_H, 0.06)), Vector3(sx * HALF_X, WALL_H * 0.5, z)))
		z += 3.5
	# Top rails: far wall plus both sides, never the near one.
	xforms.append(Transform3D(Basis.from_scale(Vector3(HALF_X * 2.0, 0.09, 0.09)), Vector3(0, WALL_H, -HALF_Z)))
	for sx in [-1.0, 1.0]:
		xforms.append(Transform3D(Basis.from_scale(Vector3(0.09, 0.09, HALF_Z * 2.0)), Vector3(sx * HALF_X, WALL_H, 0)))

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = unit
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Cage"
	mmi.multimesh = mm
	mmi.material_override = _cage
	add_child(mmi)


## Each half of the floor is tinted with its player's colour. It costs two
## quads and it makes the court read as two territories instead of one slab.
func _build_zones() -> void:
	for i in 2:
		var col: Color = Color(0.25, 0.95, 1.0) if i == 0 else Color(1.0, 0.32, 0.75)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(col.r, col.g, col.b, 0.055)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		var cx: float = -HALF_X * 0.5 if i == 0 else HALF_X * 0.5
		_box(Vector3(HALF_X - 0.3, 0.01, HALF_Z * 2.0 - 0.3), Vector3(cx, 0.014, 0), m).name = "Zone%d" % i


## Two tall coloured panes at the ends, so each player owns a colour in the
## room and the arena reads as a box rather than a floating grid.
func _build_gates() -> void:
	for i in 2:
		var col: Color = Color(0.25, 0.95, 1.0) if i == 0 else Color(1.0, 0.32, 0.75)
		var x := -HALF_X if i == 0 else HALF_X

		var pane := StandardMaterial3D.new()
		pane.albedo_color = Color(col.r, col.g, col.b, 0.06)
		pane.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pane.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		pane.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pane.cull_mode = BaseMaterial3D.CULL_DISABLED
		_box(Vector3(0.04, WALL_H * 0.94, HALF_Z * 2.0), Vector3(x, WALL_H * 0.47, 0), pane).name = "Gate%d" % i

		var seam := StandardMaterial3D.new()
		seam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		seam.albedo_color = col
		seam.emission_enabled = true
		seam.emission = col
		seam.emission_energy_multiplier = 3.2
		_box(Vector3(0.08, WALL_H, 0.09), Vector3(x, WALL_H * 0.5, 0), seam).name = "Seam%d" % i


## Pool of expanding floor rings, one per wall bounce. Cheap, and it turns a
## bounce into an event you can see out of the corner of your eye.
func _build_rings() -> void:
	# Very thin tube: a torus scales its tube with the mesh, so a fat one turns
	# into a grey donut the moment the ripple expands.
	var torus := TorusMesh.new()
	torus.inner_radius = 0.965
	torus.outer_radius = 1.0
	torus.rings = 48
	torus.ring_segments = 4
	for i in 12:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = Color(1, 1, 1, 0)
		var mi := MeshInstance3D.new()
		mi.name = "Ring%d" % i
		mi.mesh = torus
		mi.material_override = m
		mi.visible = false
		add_child(mi)
		_rings.append({"node": mi, "mat": m, "t": 0.0, "s": 1.0})


func impact(pos: Vector3, col: Color, strength := 1.0) -> void:
	if _rings.is_empty():
		return
	var r: Dictionary = _rings[_ring_i % _rings.size()]
	_ring_i += 1
	var mi: MeshInstance3D = r["node"]
	mi.position = Vector3(pos.x, 0.05, pos.z)
	mi.scale = Vector3(0.3 * strength, 1.0, 0.3 * strength)
	mi.visible = true
	r["t"] = 0.0
	r["s"] = strength
	var m: StandardMaterial3D = r["mat"]
	m.albedo_color = Color(col.r, col.g, col.b, 1.0)


func _build_lights() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-58, -28, 0)
	sun.light_color = Color(0.75, 0.85, 1.0)
	sun.light_energy = 0.45
	add_child(sun)

	for i in 2:
		var lamp := OmniLight3D.new()
		lamp.name = "Lamp%d" % i
		lamp.position = Vector3(-7.0 if i == 0 else 7.0, 6.5, 0.0)
		lamp.light_color = Color(0.2, 0.9, 1.0) if i == 0 else Color(1.0, 0.3, 0.75)
		lamp.light_energy = 2.2
		lamp.omni_range = 20.0
		lamp.shadow_enabled = false
		add_child(lamp)


func _build_closers() -> void:
	_closer_mat = StandardMaterial3D.new()
	_closer_mat.albedo_color = Color(1.0, 0.18, 0.2, 0.16)
	_closer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_closer_mat.emission_enabled = true
	_closer_mat.emission = Color(1.0, 0.15, 0.2)
	_closer_mat.emission_energy_multiplier = 2.2
	_closer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_closer_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var unit := BoxMesh.new()
	unit.size = Vector3.ONE
	for i in 4:
		var mi := MeshInstance3D.new()
		mi.name = "Closer%d" % i
		mi.mesh = unit
		mi.material_override = _closer_mat
		mi.visible = false
		add_child(mi)
		_closers.append(mi)
	reset_walls()


## Sudden death: four glass walls slide in from the rails.
func set_half_extents(hx: float, hz: float) -> void:
	half_x = hx
	half_z = hz
	if _closers.size() != 4:
		return
	for mi in _closers:
		mi.visible = hx < HALF_X - 0.01 or hz < HALF_Z - 0.01
	_closers[0].position = Vector3(-hx, WALL_H * 0.5, 0)
	_closers[0].scale = Vector3(0.08, WALL_H, hz * 2.0)
	_closers[1].position = Vector3(hx, WALL_H * 0.5, 0)
	_closers[1].scale = Vector3(0.08, WALL_H, hz * 2.0)
	_closers[2].position = Vector3(0, WALL_H * 0.5, -hz)
	_closers[2].scale = Vector3(hx * 2.0, WALL_H, 0.08)
	_closers[3].position = Vector3(0, WALL_H * 0.5, hz)
	_closers[3].scale = Vector3(hx * 2.0, WALL_H, 0.08)


func reset_walls() -> void:
	half_x = HALF_X
	half_z = HALF_Z
	for mi in _closers:
		mi.visible = false


func pulse(strength: float) -> void:
	_pulse = maxf(_pulse, strength)


func set_heat(h: float) -> void:
	_heat = h
	if _grid != null:
		_grid.emission_energy_multiplier = 0.45 + clampf(h - 1.0, 0.0, 11.0) * 0.16


func _process(delta: float) -> void:
	_pulse = maxf(0.0, _pulse - delta * 4.5)
	if _trim != null:
		_trim.emission_energy_multiplier = 2.1 + _pulse * 4.5 + clampf(_heat - 1.0, 0.0, 11.0) * 0.1

	for r in _rings:
		var mi: MeshInstance3D = r["node"]
		if not mi.visible:
			continue
		r["t"] = float(r["t"]) + delta
		var k: float = float(r["t"]) / 0.26
		if k >= 1.0:
			mi.visible = false
			continue
		var s: float = r["s"]
		mi.scale = Vector3((0.35 + k * 1.9) * s, 1.0, (0.35 + k * 1.9) * s)
		var m: StandardMaterial3D = r["mat"]
		var c := m.albedo_color
		c.a = 0.55 * (1.0 - k) * (1.0 - k)
		m.albedo_color = c


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi
