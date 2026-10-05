class_name SimulationClock
extends RefCounted

signal tick(sim_delta: float)

const MIN_TIME_SCALE := 0.0
const MAX_TIME_SCALE := 20.0

var _time_scale: float = 1.0
var _simulation_seconds: float = 0.0

func set_time_scale(value: float) -> void:
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
