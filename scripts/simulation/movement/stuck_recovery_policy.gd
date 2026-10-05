class_name StuckRecoveryPolicy
extends RefCounted

const RESULT_NONE: StringName = &"none"
const RESULT_RETRY: StringName = &"retry"
const RESULT_FAIL: StringName = &"fail"

var movement_timeout_sim_seconds: float = 30.0
var max_retries: int = 2

func evaluate(movement: MovementState) -> StringName:
	if movement == null or movement.status != MovementState.STATUS_MOVING:
		return RESULT_NONE
	if movement.elapsed_sim_seconds < movement_timeout_sim_seconds:
		return RESULT_NONE

	if movement.retry_count < max_retries:
		movement.increment_retry()
		movement.elapsed_sim_seconds = 0.0
		return RESULT_RETRY

	return RESULT_FAIL
