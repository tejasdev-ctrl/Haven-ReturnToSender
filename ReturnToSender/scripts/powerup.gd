extends Node3D
class_name Powerup
## A pickup that spawns mid-round. Walk over it and you get a timed buff.
## Built from primitives like everything else: an octahedron (a 4-sided sphere),
## a counter-rotating shell, a floor ring and a faint beacon so it is findable
## from a high camera.

const LIFETIME := 10.0

var kind := 0
var color := Color.WHITE
var power_name := ""
var life := LIFETIME

var _core: MeshInstance3D
var _shell: MeshInstance3D
var _core_mat: StandardMaterial3D
var _shell_mat: StandardMaterial3D
var _ring_mat: StandardMaterial3D
var _beam_mat: StandardMaterial3D
var _t := 0.0


func setup(index: int) -> void:
	kind = index
	var d: Dictionary = Game.POWERUPS[clampi(index, 0, Game.POWERUPS.size() - 1)]
	color = d["color"]
	power_name = d["name"]


func _ready() -> void:
	_build()


func _build() -> void:
	_core_mat = StandardMaterial3D.new()
	_core_mat.albedo_color = color
	_core_mat.emission_enabled = true
	_core_mat.emission = color
	_core_mat.emission_energy_multiplier = 2.2
	_core_mat.roughness = 0.2

	# radial_segments 4 + rings 2 is an octahedron.
	var octa := SphereMesh.new()
	octa.radial_segments = 4
	octa.rings = 2
	octa.radius = 0.34
	octa.height = 0.68

	_core = MeshInstance3D.new()
	_core.mesh = octa
	_core.material_override = _core_mat
	_core.position = Vector3(0, 0.1, 0)
	add_child(_core)

	_shell_mat = StandardMaterial3D.new()
	_shell_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shell_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shell_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_shell_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	_shell_mat.albedo_color = Color(color.r, color.g, color.b, 0.3)

	var octa2 := SphereMesh.new()
	octa2.radial_segments = 4
	octa2.rings = 2
	octa2.radius = 0.46
	octa2.height = 0.92

	_shell = MeshInstance3D.new()
	_shell.mesh = octa2
	_shell.material_override = _shell_mat
	_core.add_child(_shell)

	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring_mat.albedo_color = Color(color.r, color.g, color.b, 0.5)

	var torus := TorusMesh.new()
	torus.inner_radius = 0.52
	torus.outer_radius = 0.6
	torus.rings = 40
	torus.ring_segments = 3
	var ring := MeshInstance3D.new()
	ring.mesh = torus
	ring.material_override = _ring_mat
	ring.position = Vector3(0, -0.96, 0)
	add_child(ring)

	_beam_mat = StandardMaterial3D.new()
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam_mat.albedo_color = Color(color.r, color.g, color.b, 0.07)

	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.05
	beam_mesh.bottom_radius = 0.16
	beam_mesh.height = 3.0
	beam_mesh.radial_segments = 10
	beam_mesh.rings = 0
	var beam := MeshInstance3D.new()
	beam.mesh = beam_mesh
	beam.material_override = _beam_mat
	beam.position = Vector3(0, 0.6, 0)
	add_child(beam)


func _process(delta: float) -> void:
	_t += delta
	life -= delta
	_core.rotation.y += delta * 1.8
	_core.position.y = 0.1 + sin(_t * 2.1) * 0.11
	_core_mat.emission_energy_multiplier = 2.2 + sin(_t * 4.0) * 0.7
	_shell.rotation.y -= delta * 3.2

	# Warn that it is about to vanish.
	if life < 2.6:
		var on := fmod(_t, 0.24) < 0.13
		_core.visible = on
		_shell.visible = on

	if life <= 0.0:
		queue_free()
