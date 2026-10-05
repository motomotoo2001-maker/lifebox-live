class_name ScheduleState
extends RefCounted

const MODE_SLEEP: StringName = &"sleep"
const MODE_WORK: StringName = &"work"
const MODE_SOCIAL: StringName = &"social"
const MODE_FREE: StringName = &"free"

const VALID_MODES: Array[StringName] = [
	MODE_SLEEP,
	MODE_WORK,
	MODE_SOCIAL,
	MODE_FREE,
]

var day_index: int = -1
var planned_mode: StringName = MODE_FREE
var next_transition_sim_seconds: float = 0.0

func set_plan(
	new_day_index: int,
	new_mode: StringName,
	new_next_transition_sim_seconds: float
) -> bool:
	if new_mode not in VALID_MODES:
		return false
	if (
		is_nan(new_next_transition_sim_seconds)
		or is_inf(new_next_transition_sim_seconds)
		or new_next_transition_sim_seconds < 0.0
	):
		return false

	day_index = maxi(new_day_index, 0)
	planned_mode = new_mode
	next_transition_sim_seconds = new_next_transition_sim_seconds
	return true
