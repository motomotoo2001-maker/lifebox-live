class_name ChaosMeter
extends RefCounted

const MIN_VALUE := 0.0
const MAX_VALUE := 100.0
const CHAOS_PER_LIKE := 0.01

var value: float = 0.0

func add_likes(count: int) -> bool:
	if count < 1:
		return false
	return apply_delta(float(count) * CHAOS_PER_LIKE)

func apply_delta(delta: float) -> bool:
	if is_nan(delta) or is_inf(delta):
		return false
	value = clampf(value + delta, MIN_VALUE, MAX_VALUE)
	return true

func normalized() -> float:
	return value / MAX_VALUE

func capture_state() -> Dictionary:
	return {"value": value}

func restore_state(data: Dictionary) -> bool:
	if not data.has("value"):
		return false
	if not (data["value"] is int or data["value"] is float):
		return false
	var restored := float(data["value"])
	if is_nan(restored) or is_inf(restored):
		return false
	if restored < MIN_VALUE or restored > MAX_VALUE:
		return false
	value = restored
	return true
