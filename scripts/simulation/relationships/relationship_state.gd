class_name RelationshipState
extends RefCounted

const MIN_VALUE := -100.0
const MAX_VALUE := 100.0

var affinity: float = 0.0
var trust: float = 0.0
var tension: float = 0.0

func apply_delta(
	affinity_delta: float = 0.0,
	trust_delta: float = 0.0,
	tension_delta: float = 0.0
) -> void:
	affinity = _apply_safe_delta(affinity, affinity_delta)
	trust = _apply_safe_delta(trust, trust_delta)
	tension = _apply_safe_delta(tension, tension_delta)

func _apply_safe_delta(current: float, delta: float) -> float:
	if is_nan(delta) or is_inf(delta):
		return current
	return clampf(current + delta, MIN_VALUE, MAX_VALUE)
