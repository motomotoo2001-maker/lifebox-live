extends RefCounted

const INTENT_PATH := "res://scripts/simulation/movement/movement_intent.gd"
const STATE_PATH := "res://scripts/simulation/movement/movement_state.gd"
const CHARACTER_PATH := "res://scripts/simulation/characters/character_state.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	if not FileAccess.file_exists(INTENT_PATH):
		failures.append("MovementIntent must exist at %s" % INTENT_PATH)
		return failures
	if not FileAccess.file_exists(STATE_PATH):
		failures.append("MovementState must exist at %s" % STATE_PATH)
		return failures

	var intent_script := load(INTENT_PATH)
	var state_script := load(STATE_PATH)
	var character_script := load(CHARACTER_PATH)
	if intent_script == null or state_script == null or character_script == null:
		failures.append("movement state dependencies must load")
		return failures

	var valid_intent = intent_script.new(&"fridge_main", Vector3(1.0, 0.0, 2.0), 0.5)
	if not valid_intent.is_valid():
		failures.append("finite movement intent with target id must be valid")

	var empty_target = intent_script.new(&"", Vector3.ZERO, 0.5)
	if empty_target.is_valid():
		failures.append("movement intent with empty target id must be invalid")

	var nan_target = intent_script.new(&"fridge_main", Vector3(NAN, 0.0, 0.0), 0.5)
	if nan_target.is_valid():
		failures.append("movement intent with NaN position must be invalid")

	var inf_target = intent_script.new(&"fridge_main", Vector3(INF, 0.0, 0.0), 0.5)
	if inf_target.is_valid():
		failures.append("movement intent with infinite position must be invalid")

	var negative_radius = intent_script.new(&"fridge_main", Vector3.ZERO, -5.0)
	if negative_radius.arrival_radius < 0.0:
		failures.append("arrival radius must clamp to non-negative value")

	var state = state_script.new()
	if state.status != &"idle":
		failures.append("MovementState must start idle")
	if state.intent != null:
		failures.append("MovementState must start without intent")
	if not is_equal_approx(state.elapsed_sim_seconds, 0.0):
		failures.append("MovementState elapsed time must start at zero")
	if state.retry_count != 0:
		failures.append("MovementState retry count must start at zero")

	if state.begin(valid_intent) != true:
		failures.append("valid movement intent must start movement")
	if state.status != &"moving" or state.intent != valid_intent:
		failures.append("begin() must enter moving state with the selected intent")

	state.advance_elapsed(5.0)
	if not is_equal_approx(state.elapsed_sim_seconds, 5.0):
		failures.append("moving state must accumulate simulated elapsed time")
	state.advance_elapsed(-10.0)
	state.advance_elapsed(NAN)
	if not is_equal_approx(state.elapsed_sim_seconds, 5.0):
		failures.append("invalid elapsed deltas must be ignored")

	state.increment_retry()
	if state.retry_count != 1:
		failures.append("increment_retry() must increase retry count")

	state.mark_arrived()
	if state.status != &"arrived":
		failures.append("mark_arrived() must enter arrived state")

	state.reset()
	if state.status != &"idle" or state.intent != null:
		failures.append("reset() must return movement state to idle")
	if not is_equal_approx(state.elapsed_sim_seconds, 0.0) or state.retry_count != 0:
		failures.append("reset() must clear elapsed time and retries")

	if state.begin(nan_target) != false:
		failures.append("begin() must reject invalid movement intent")
	if state.status != &"idle":
		failures.append("rejected intent must leave movement state idle")

	if state.begin(valid_intent) != true:
		failures.append("valid movement must restart after reset")
	state.mark_failed()
	if state.status != &"failed":
		failures.append("mark_failed() must enter failed state")

	var character = character_script.new(&"resident_mover", "Mover")
	if character.movement == null:
		failures.append("CharacterState must create MovementState")
	elif character.movement.status != &"idle":
		failures.append("CharacterState movement must start idle")

	return failures
