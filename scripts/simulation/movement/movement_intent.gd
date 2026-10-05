class_name MovementIntent
extends RefCounted

var target_object_id: StringName
var target_position: Vector3
var arrival_radius: float

func _init(
	new_target_object_id: StringName = &"",
	new_target_position: Vector3 = Vector3.ZERO,
	new_arrival_radius: float = 0.5
) -> void:
	target_object_id = new_target_object_id
	target_position = new_target_position
	arrival_radius = _sanitize_radius(new_arrival_radius)

func is_valid() -> bool:
	return (
		target_object_id != &""
		and _is_finite_vector(target_position)
		and _is_finite_float(arrival_radius)
		and arrival_radius >= 0.0
	)

func _sanitize_radius(value: float) -> float:
	if not _is_finite_float(value):
		return 0.0
	return maxf(value, 0.0)

func _is_finite_vector(value: Vector3) -> bool:
	return (
		_is_finite_float(value.x)
		and _is_finite_float(value.y)
		and _is_finite_float(value.z)
	)

func _is_finite_float(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)
