class_name NeedState
extends RefCounted

const MIN_VALUE := 0.0
const MAX_VALUE := 100.0

var value: float
var decay_per_sim_hour: float

func _init(initial_value: float = MAX_VALUE, decay_rate: float = 0.0) -> void:
	value = _sanitize_value(initial_value)
	decay_per_sim_hour = _sanitize_decay(decay_rate)

func apply_delta(amount: float) -> void:
	if is_nan(amount):
		return
	value = clampf(value + amount, MIN_VALUE, MAX_VALUE)

func normalized() -> float:
	if is_nan(value):
		return 0.0
	return clampf(value, MIN_VALUE, MAX_VALUE) / MAX_VALUE

func _sanitize_value(raw_value: float) -> float:
	if is_nan(raw_value):
		return MIN_VALUE
	return clampf(raw_value, MIN_VALUE, MAX_VALUE)

func _sanitize_decay(raw_decay: float) -> float:
	if is_nan(raw_decay):
		return 0.0
	return maxf(raw_decay, 0.0)
