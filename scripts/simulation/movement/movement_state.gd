class_name MovementState
extends RefCounted

const STATUS_IDLE: StringName = &"idle"
const STATUS_MOVING: StringName = &"moving"
const STATUS_ARRIVED: StringName = &"arrived"
const STATUS_FAILED: StringName = &"failed"

var status: StringName = STATUS_IDLE
var intent: MovementIntent = null
var elapsed_sim_seconds: float = 0.0
var retry_count: int = 0

func begin(new_intent: MovementIntent) -> bool:
	if new_intent == null or not new_intent.is_valid():
		return false

	intent = new_intent
	status = STATUS_MOVING
	elapsed_sim_seconds = 0.0
	retry_count = 0
	return true

func advance_elapsed(sim_delta_seconds: float) -> void:
	if status != STATUS_MOVING:
		return
	if is_nan(sim_delta_seconds) or is_inf(sim_delta_seconds) or sim_delta_seconds <= 0.0:
		return
	elapsed_sim_seconds += sim_delta_seconds

func increment_retry() -> void:
	retry_count += 1

func mark_arrived() -> void:
	if status == STATUS_MOVING:
		status = STATUS_ARRIVED

func mark_failed() -> void:
	if status == STATUS_MOVING:
		status = STATUS_FAILED

func reset() -> void:
	status = STATUS_IDLE
	intent = null
	elapsed_sim_seconds = 0.0
	retry_count = 0
