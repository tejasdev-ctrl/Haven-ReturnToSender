extends Camera3D
## Fixed arena camera with trauma-based shake. One camera, whole court, always.

var _trauma := 0.0
var _kick := 0.0
var _base_pos := Vector3.ZERO
var _base_rot := Vector3.ZERO


func _ready() -> void:
	position = Vector3(0.0, 16.5, 12.5)
	fov = 52.0
	look_at(Vector3(0.0, -0.4, 0.0), Vector3.UP)
	_base_pos = position
	_base_rot = rotation


func shake(amount: float) -> void:
	_trauma = minf(1.2, _trauma + amount)


## A short field-of-view punch. Pure sugar, and the cheapest way to make a kill
## feel like an event.
func kick(degrees: float) -> void:
	_kick = maxf(_kick, degrees)


func _process(delta: float) -> void:
	_kick = lerpf(_kick, 0.0, 1.0 - exp(-4.0 * delta))
	fov = 60.0 + _kick
	_trauma = maxf(0.0, _trauma - delta * 1.7)
	var s := _trauma * _trauma
	if s <= 0.0001:
		position = _base_pos
		rotation = _base_rot
		return
	position = _base_pos + Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	) * s * 0.55
	rotation = _base_rot + Vector3(
		randf_range(-1.0, 1.0) * 0.010,
		randf_range(-1.0, 1.0) * 0.010,
		randf_range(-1.0, 1.0) * 0.018
	) * s
