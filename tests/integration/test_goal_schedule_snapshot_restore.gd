extends RefCounted

const CODEC_PATH := "res://scripts/persistence/character_snapshot_codec.gd"
const CHARACTER_PATH := "res://scripts/simulation/characters/character_state.gd"
const BLOCK_PATH := "res://scripts/simulation/schedules/schedule_block.gd"
const DEFINITION_PATH := "res://scripts/simulation/schedules/schedule_definition.gd"
const GOAL_DEFINITION_PATH := "res://scripts/simulation/goals/goal_definition.gd"
const GOAL_STATE_PATH := "res://scripts/simulation/goals/goal_state.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	var codec_script = load(CODEC_PATH)
	var character_script = load(CHARACTER_PATH)
	var block_script = load(BLOCK_PATH)
	var schedule_definition_script = load(DEFINITION_PATH)
	var goal_definition_script = load(GOAL_DEFINITION_PATH)
	var goal_state_script = load(GOAL_STATE_PATH)

	for script in [
		codec_script,
		character_script,
		block_script,
		schedule_definition_script,
		goal_definition_script,
		goal_state_script,
	]:
		if script == null or not script.can_instantiate():
			failures.append("goal/schedule persistence dependencies must load")
			return failures

	var source = character_script.new(&"resident_a", "Resident A")
	var schedule = schedule_definition_script.new()

	var sleep = block_script.new()
	sleep.id = &"sleep"
	sleep.kind = &"sleep"
	sleep.start_hour = 22.0
	sleep.duration_hours = 8.0
	sleep.preferred_action_tags.append(&"sleep")
	schedule.blocks.append(sleep)

	var work = block_script.new()
	work.id = &"work"
	work.kind = &"work"
	work.start_hour = 8.0
	work.duration_hours = 8.0
	work.preferred_action_tags.append(&"work")
	schedule.blocks.append(work)

	source.schedule.definition = schedule
	source.schedule.day_index = 2
	source.schedule.active_block_id = &"work"

	if not source.goals.begin_day(2):
		failures.append("goal persistence fixture must begin day 2")
		return failures

	var social_definition = goal_definition_script.new()
	social_definition.id = &"social_resident_b_day_2"
	social_definition.category = &"social"
	social_definition.priority = 0.9
	social_definition.preferred_action_tags.append(&"social")
	social_definition.target_resident_id = &"resident_b"
	var social_goal = goal_state_script.new(social_definition)
	social_goal.set_progress(0.4)
	if not source.goals.add(social_goal):
		failures.append("active social goal must enter fixture")
		return failures

	var completed_definition = goal_definition_script.new()
	completed_definition.id = &"wellbeing_day_2"
	completed_definition.category = &"wellbeing"
	completed_definition.priority = 0.5
	completed_definition.preferred_action_tags.append(&"relax")
	var completed_goal = goal_state_script.new(completed_definition)
	completed_goal.complete()
	if not source.goals.add(completed_goal):
		failures.append("completed goal must enter fixture history")
		return failures

	var encoded: Dictionary = codec_script.encode(source)
	if not encoded.has("schedule"):
		failures.append("resident snapshot must persist schedule state")
		return failures
	if not encoded.has("goals"):
		failures.append("resident snapshot must persist daily goal state")
		return failures
	if not _is_json_compatible(encoded):
		failures.append("goal/schedule resident snapshot must remain JSON-compatible")

	var errors: Array[String] = codec_script.validate(encoded)
	if not errors.is_empty():
		failures.append("valid goal/schedule snapshot must validate: %s" % " | ".join(errors))
		return failures

	var decoded = codec_script.decode_stable_state(encoded)
	if decoded == null:
		failures.append("valid goal/schedule snapshot must decode")
		return failures

	if decoded.schedule.day_index != 2:
		failures.append("schedule day index must round-trip")
	if decoded.schedule.active_block_id != &"work":
		failures.append("active schedule block id must round-trip")
	if decoded.schedule.definition == null:
		failures.append("schedule definition must round-trip")
	else:
		if decoded.schedule.definition.blocks.size() != 2:
			failures.append("schedule block count must round-trip")
		if decoded.schedule.definition.active_block_at(23.0).id != &"sleep":
			failures.append("midnight-crossing schedule must survive snapshot restore")
		if decoded.schedule.definition.active_block_at(12.0).id != &"work":
			failures.append("work schedule block must survive snapshot restore")

	if decoded.goals.day_index != 2:
		failures.append("goal day index must round-trip")
	if decoded.goals.goals().size() != 2:
		failures.append("goal history count must round-trip")
	else:
		var restored_social = decoded.goals.get_goal(&"social_resident_b_day_2")
		var restored_completed = decoded.goals.get_goal(&"wellbeing_day_2")
		if restored_social == null or restored_completed == null:
			failures.append("goal IDs must round-trip")
		else:
			if restored_social.definition.target_resident_id != &"resident_b":
				failures.append("goal target resident must round-trip")
			if not is_equal_approx(restored_social.progress, 0.4):
				failures.append("goal progress must round-trip")
			if restored_social.status != GoalState.STATUS_ACTIVE:
				failures.append("active goal status must round-trip")
			if restored_completed.status != GoalState.STATUS_COMPLETED:
				failures.append("completed goal status must round-trip")
			if not is_equal_approx(restored_completed.progress, 1.0):
				failures.append("completed goal progress must round-trip")

	if codec_script.encode(decoded) != encoded:
		failures.append("goal/schedule snapshot must re-encode exactly after restore")

	var legacy := encoded.duplicate(true)
	legacy.erase("schedule")
	legacy.erase("goals")
	var legacy_errors: Array[String] = codec_script.validate(legacy)
	if not legacy_errors.is_empty():
		failures.append("legacy Plan 04 resident snapshot must remain readable")
	else:
		var legacy_decoded = codec_script.decode_stable_state(legacy)
		if legacy_decoded == null:
			failures.append("legacy resident snapshot must decode")
		else:
			if legacy_decoded.schedule.definition != null:
				failures.append("legacy snapshot must default to no schedule definition")
			if legacy_decoded.schedule.day_index != 0:
				failures.append("legacy snapshot must preserve default schedule day")
			if not legacy_decoded.goals.goals().is_empty():
				failures.append("legacy snapshot must default to no goals")
			if legacy_decoded.goals.day_index != -1:
				failures.append("legacy snapshot must default goal day to -1")

	var resident_ids := {
		"resident_a": true,
		"resident_b": true,
	}
	if not codec_script.validate_goal_targets(encoded, resident_ids).is_empty():
		failures.append("existing social goal target must validate")

	var missing_target_ids := {
		"resident_a": true,
	}
	if codec_script.validate_goal_targets(encoded, missing_target_ids).is_empty():
		failures.append("missing social goal target must fail closed")

	var self_target := encoded.duplicate(true)
	self_target["goals"]["items"][0]["definition"]["target_resident_id"] = "resident_a"
	if codec_script.validate_goal_targets(self_target, resident_ids).is_empty():
		failures.append("goal target must never restore as self")

	var overlap := encoded.duplicate(true)
	overlap["schedule"]["definition"]["blocks"][1]["start_hour"] = 23.0
	if codec_script.validate(overlap).is_empty():
		failures.append("overlapping restored schedule blocks must fail validation")

	var bad_status := encoded.duplicate(true)
	bad_status["goals"]["items"][0]["status"] = "unknown"
	if codec_script.validate(bad_status).is_empty():
		failures.append("unknown restored goal status must fail validation")

	return failures

func _is_json_compatible(value) -> bool:
	if value == null:
		return true
	if value is String or value is bool or value is int or value is float:
		return true
	if value is Array:
		for item in value:
			if not _is_json_compatible(item):
				return false
		return true
	if value is Dictionary:
		for key in value.keys():
			if not key is String:
				return false
			if not _is_json_compatible(value[key]):
				return false
		return true
	return false
