class_name SimulationClock
extends RefCounted

signal tick(sim_delta: float)

const MIN_TIME_SCALE := 0.0
const MAX_TIME_SCALE := 20.0

var _time_scale: float = 1.0
var _simulation_seconds: float = 0.0

func set_time_scale(value: float) -> void:
	if is_nan(value) or is_inf(value):
		_time_scale = MIN_TIME_SCALE
		return
	_time_scale = clampf(value, MIN_TIME_SCALE, MAX_TIME_SCALE)

func advance(real_delta: float) -> float:
	var safe_real_delta := maxf(real_delta, 0.0)
	var sim_delta := safe_real_delta * _time_scale

	if sim_delta > 0.0:
		_simulation_seconds += sim_delta
		tick.emit(sim_delta)

	return sim_delta

func get_simulation_seconds() -> float:
	return _simulation_seconds

func get_time_scale() -> float:
	return _time_scale

func capture_state() -> Dictionary:
	return {
		"time_scale": _time_scale,
		"simulation_seconds": _simulation_seconds,
	}

func restore_state(data: Dictionary) -> bool:
	if not data.has("time_scale") or not _is_finite_number(data["time_scale"]):
		return false
	if not data.has("simulation_seconds") or not _is_finite_number(data["simulation_seconds"]):
		return false

	var restored_scale := float(data["time_scale"])
	var restored_seconds := float(data["simulation_seconds"])

	if restored_scale < MIN_TIME_SCALE or restored_scale > MAX_TIME_SCALE:
		return false
	if restored_seconds < 0.0:
		return false

	_time_scale = restored_scale
	_simulation_seconds = restored_seconds
	return true

func _is_finite_number(value) -> bool:
	if not (value is int or value is float):
		return false
	var number := float(value)
	return not is_nan(number) and not is_inf(number)
