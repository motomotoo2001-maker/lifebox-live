extends RefCounted

const SOCIAL_SYSTEM_PATH := "res://scripts/simulation/social/social_system.gd"
const SOCIAL_ACTION_PATH := "res://scripts/simulation/social/social_action_definition.gd"
const CHARACTER_PATH := "res://scripts/simulation/characters/character_state.gd"
const RELATIONSHIP_PATH := "res://scripts/simulation/relationships/relationship_graph.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	var social_script := load(SOCIAL_SYSTEM_PATH)
	var action_script := load(SOCIAL_ACTION_PATH)
	var character_script := load(CHARACTER_PATH)
	var relationship_script := load(RELATIONSHIP_PATH)
	if social_script == null or action_script == null or character_script == null or relationship_script == null:
		failures.append("social snapshot dependencies must load")
		return failures

	var source := _build_social_system(
		social_script,
		action_script,
		character_script
	)
	var source_system = source["system"]
	var source_residents: Array = source["residents"]
	var relationships = relationship_script.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 44

	var completed = source_system.reservation_book.reserve(
		&"resident_a",
		&"resident_b",
		&"chat",
		1.0
	)
	if completed == null:
		failures.append("social snapshot completed-session setup must reserve")
		return failures
	_set_action(source_residents, &"resident_a", &"chat")
	_set_action(source_residents, &"resident_b", &"chat")
	source_system.advance(source_residents, relationships, 1.0, rng)

	_set_action(source_residents, &"resident_a", &"manual_busy")
	_set_action(source_residents, &"resident_b", &"manual_busy")

	var active = source_system.reservation_book.reserve(
		&"resident_c",
		&"resident_d",
		&"compliment",
		20.0
	)
	if active == null:
		failures.append("social snapshot active-session setup must reserve")
		return failures
	_set_action(source_residents, &"resident_c", &"compliment")
	_set_action(source_residents, &"resident_d", &"compliment")
	source_system.advance(source_residents, relationships, 5.0, rng)

	var state: Dictionary = source_system.capture_persistence_state()
	if not _is_json_compatible(state):
		failures.append("social persistence state must be JSON-compatible")

	var target := _build_social_system(
		social_script,
		action_script,
		character_script
	)
	var target_system = target["system"]
	var target_residents: Array = target["residents"]

	if not target_system.restore_persistence_state(state, target_residents):
		failures.append("valid social runtime state must restore")
		return failures

	var active_sessions: Array = target_system.active_sessions()
	if active_sessions.size() != 1:
		failures.append("restore must recreate exactly one active social session")
	else:
		var restored_active = active_sessions[0]
		if restored_active.session_id != &"social_000002":
			failures.append("active social session id must round-trip")
		if restored_active.initiator_id != &"resident_c" or restored_active.target_id != &"resident_d":
			failures.append("active social participants must round-trip")
		if restored_active.action_id != &"compliment":
			failures.append("active social action id must round-trip")
		if not is_equal_approx(restored_active.remaining_sim_seconds, 15.0):
			failures.append("active social remaining time must round-trip")

	if not target_system.reservation_book.is_reserved(&"resident_c"):
		failures.append("restored active initiator must be reserved")
	if not target_system.reservation_book.is_reserved(&"resident_d"):
		failures.append("restored active target must be reserved")
	if _get_resident(target_residents, &"resident_c").current_action_id != &"compliment":
		failures.append("restored active initiator action must be restored")
	if _get_resident(target_residents, &"resident_d").current_action_id != &"compliment":
		failures.append("restored active target action must be restored")

	var round_trip: Dictionary = target_system.capture_persistence_state()
	if not is_equal_approx(
		float(round_trip.get("simulation_seconds", -1.0)),
		6.0
	):
		failures.append("SocialSystem simulation time must round-trip")

	var completed_once: Array = target_system.take_completed_sessions()
	if completed_once.size() != 1:
		failures.append("completed-but-undrained queue must round-trip exactly once")
	else:
		if completed_once[0].session_id != &"social_000001":
			failures.append("completed queue session id must round-trip")
	if not target_system.take_completed_sessions().is_empty():
		failures.append("restored completed queue must drain exactly once")

	var c = _get_resident(target_residents, &"resident_c")
	var d = _get_resident(target_residents, &"resident_d")
	if not target_system.cancel_session(&"social_000002", target_residents):
		failures.append("restored active social session must remain cancellable")
	if c.memory.size() != 0 or d.memory.size() != 0:
		failures.append("cancel after restore must not apply social outcome memory")

	var next = target_system.reservation_book.reserve(
		&"resident_a",
		&"resident_b",
		&"chat",
		10.0
	)
	if next == null or next.session_id != &"social_000003":
		failures.append("restored reservation sequence must continue deterministically")
	if next != null:
		target_system.reservation_book.release(next.session_id)

	_test_invalid_restore_cases(
		failures,
		state,
		social_script,
		action_script,
		character_script
	)

	return failures

func _test_invalid_restore_cases(
	failures: Array[String],
	valid_state: Dictionary,
	social_script,
	action_script,
	character_script
) -> void:
	var cases: Array[Dictionary] = []

	var missing_resident := valid_state.duplicate(true)
	missing_resident["reservation_book"]["sessions"][0]["target_id"] = "resident_missing"
	cases.append(missing_resident)

	var duplicate_resident := valid_state.duplicate(true)
	var duplicated: Dictionary = duplicate_resident["reservation_book"]["sessions"][0].duplicate(true)
	duplicated["session_id"] = "social_000003"
	duplicated["initiator_id"] = "resident_a"
	duplicated["target_id"] = "resident_c"
	duplicate_resident["reservation_book"]["sessions"].append(duplicated)
	duplicate_resident["reservation_book"]["sequence"] = 3
	cases.append(duplicate_resident)

	var self_session := valid_state.duplicate(true)
	self_session["reservation_book"]["sessions"][0]["target_id"] = (
		self_session["reservation_book"]["sessions"][0]["initiator_id"]
	)
	cases.append(self_session)

	var invalid_duration := valid_state.duplicate(true)
	invalid_duration["reservation_book"]["sessions"][0]["remaining_sim_seconds"] = 0.0
	cases.append(invalid_duration)

	var duplicate_session_id := valid_state.duplicate(true)
	var duplicate_id_entry: Dictionary = duplicate_session_id["reservation_book"]["sessions"][0].duplicate(true)
	duplicate_id_entry["initiator_id"] = "resident_a"
	duplicate_id_entry["target_id"] = "resident_b"
	duplicate_session_id["reservation_book"]["sessions"].append(duplicate_id_entry)
	cases.append(duplicate_session_id)

	for invalid_state in cases:
		var target := _build_social_system(
			social_script,
			action_script,
			character_script
		)
		var system = target["system"]
		var residents: Array = target["residents"]
		if system.restore_persistence_state(invalid_state, residents):
			failures.append("invalid social persistence state must be rejected")
		if not system.active_sessions().is_empty():
			failures.append("failed social restore must not leave active sessions")
		for resident in residents:
			if system.reservation_book.is_reserved(resident.id):
				failures.append("failed social restore must not partially lock residents")
			if resident.current_action_id != &"idle":
				failures.append("failed social restore must not mutate resident action state")

func _build_social_system(
	social_script,
	action_script,
	character_script
) -> Dictionary:
	var system = social_script.new()

	var chat = action_script.new()
	chat.id = &"chat"
	chat.duration_sim_seconds = 20.0
	system.register_action(chat)

	var compliment = action_script.new()
	compliment.id = &"compliment"
	compliment.duration_sim_seconds = 20.0
	system.register_action(compliment)

	var residents: Array = []
	for suffix in ["a", "b", "c", "d"]:
		var resident = character_script.new(
			StringName("resident_%s" % suffix),
			"Resident %s" % suffix
		)
		resident.needs.social.value = 100.0
		residents.append(resident)

	return {
		"system": system,
		"residents": residents,
	}

func _set_action(
	residents: Array,
	resident_id: StringName,
	action_id: StringName
) -> void:
	var resident = _get_resident(residents, resident_id)
	if resident != null:
		resident.current_action_id = action_id

func _get_resident(
	residents: Array,
	resident_id: StringName
):
	for resident in residents:
		if resident.id == resident_id:
			return resident
	return null

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
