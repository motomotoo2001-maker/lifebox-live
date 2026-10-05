class_name DailyGoal
extends RefCounted

var id: StringName
var category: StringName
var priority: float = 0.0
var target_value: float = 0.0
var progress: float = 0.0
var expires_day: int = 0

func _init(
	new_id: StringName = &"",
	new_category: StringName = &"",
	new_priority: float = 0.0,
	new_target_value: float = 0.0,
	new_progress: float = 0.0,
	new_expires_day: int = 0
) -> void:
	id = new_id
	category = new_category
	priority = _sanitize_range(new_priority, 0.0, 1.0)
	target_value = _sanitize_non_negative(new_target_value)
	progress = _sanitize_progress(new_progress)
	expires_day = maxi(new_expires_day, 0)

func set_progress(value: float) -> void:
	progress = _sanitize_progress(value)

func add_progress(amount: float) -> void:
	if is_nan(amount) or is_inf(amount):
		return
	set_progress(progress + amount)

func is_complete() -> bool:
	return target_value > 0.0 and progress >= target_value

func _sanitize_progress(value: float) -> float:
	if is_nan(value) or is_inf(value):
		return progress
	if target_value <= 0.0:
		return 0.0
	return clampf(value, 0.0, target_value)

func _sanitize_non_negative(value: float) -> float:
	if is_nan(value) or is_inf(value):
		return 0.0
	return maxf(value, 0.0)

func _sanitize_range(value: float, minimum: float, maximum: float) -> float:
	if is_nan(value) or is_inf(value):
		return minimum
	return clampf(value, minimum, maximum)
