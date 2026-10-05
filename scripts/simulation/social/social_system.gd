class_name SocialSystem
extends RefCounted

const MIN_START_SCORE := 20.0

var reservation_book := SocialReservationBook.new()

var _actions_by_id: Dictionary = {}
var _completed_sessions: Array[SocialSession] = []
var _simulation_seconds: float = 0.0

func register_action(action: SocialActionDefinition) -> bool:
	if action == null or action.id == &"":
		return false
	if (
		is_nan(action.duration_sim_seconds)
		or is_inf(action.duration_sim_seconds)
		or action.duration_sim_seconds <= 0.0
	):
		return false
	if _actions_by_id.has(action.id):
		return false

	_actions_by_id[action.id] = action
	return true

func active_sessions() -> Array[SocialSession]:
	return reservation_book.active_sessions()

func take_completed_sessions() -> Array[SocialSession]:
	var completed: Array[SocialSession] = _completed_sessions.duplicate()
	_completed_sessions.clear()
	return completed

func capture_persistence_state() -> Dictionary:
	var completed: Array = []
	for session in _completed_sessions:
		completed.append(session.capture_persistence_state())

	return {
		"simulation_seconds": _simulation_seconds,
		"reservation_book": reservation_book.capture_state(),
		"completed_sessions": completed,
	}

func restore_persistence_state(
	data: Dictionary,
	residents: Array
) -> bool:
	var validation := _validate_persistence_state(data, residents)
	if not validation.is_empty():
		return false

	var resident_ids: Dictionary = {}
	var resident_by_id := _build_resident_lookup(residents)
	for resident_id in resident_by_id.keys():
		resident_ids[resident_id] = true

	if not reservation_book.restore_state(data["reservation_book"], resident_ids):
		return false

	var restored_completed: Array[SocialSession] = []
	for raw_session in data["completed_sessions"]:
		var session := SocialSession.from_persistence_state(raw_session)
		if session == null:
			return false
		restored_completed.append(session)

	for resident in residents:
		if not resident is CharacterState:
			continue
		if _actions_by_id.has(resident.current_action_id):
			resident.current_action_id = &"idle"

	for session in reservation_book.active_sessions():
		var initiator: CharacterState = resident_by_id[session.initiator_id]
		var target: CharacterState = resident_by_id[session.target_id]
		initiator.current_action_id = session.action_id
		target.current_action_id = session.action_id

	_simulation_seconds = float(data["simulation_seconds"])
	_completed_sessions = restored_completed
	return true

func _validate_persistence_state(
	data: Dictionary,
	residents: Array
) -> Array[String]:
	var errors: Array[String] = []

	if (
		not data.has("simulation_seconds")
		or not _is_finite_number(data["simulation_seconds"])
		or float(data["simulation_seconds"]) < 0.0
	):
		errors.append("social simulation_seconds must be finite and non-negative")

	if not data.has("reservation_book") or not data["reservation_book"] is Dictionary:
		errors.append("social reservation_book must be a Dictionary")
		return errors

	if not data.has("completed_sessions") or not data["completed_sessions"] is Array:
		errors.append("social completed_sessions must be an Array")
		return errors

	var resident_ids: Dictionary = {}
	for raw_resident in residents:
		if not raw_resident is CharacterState:
			errors.append("social restore resident must be CharacterState")
			continue
		var resident: CharacterState = raw_resident
		if resident.id == &"":
			errors.append("social restore resident id must be non-empty")
			continue
		if resident_ids.has(resident.id):
			errors.append("duplicate resident id in social restore roster: %s" % resident.id)
		resident_ids[resident.id] = true

	var book_errors := reservation_book.validate_persistence_state(
		data["reservation_book"],
		resident_ids
	)
	for book_error in book_errors:
		errors.append(book_error)

	var sequence := -1
	if data["reservation_book"].has("sequence") and data["reservation_book"]["sequence"] is int:
		sequence = int(data["reservation_book"]["sequence"])

	var seen_session_ids: Dictionary = {}
	if data["reservation_book"].has("sessions") and data["reservation_book"]["sessions"] is Array:
		for raw_active in data["reservation_book"]["sessions"]:
			if not raw_active is Dictionary:
				continue
			if raw_active.has("session_id") and raw_active["session_id"] is String:
				seen_session_ids[raw_active["session_id"]] = true
			if raw_active.has("action_id") and raw_active["action_id"] is String:
				if not _actions_by_id.has(StringName(raw_active["action_id"])):
					errors.append(
						"active social action is not registered: %s"
						% raw_active["action_id"]
					)

	for index in range(data["completed_sessions"].size()):
		var raw_completed = data["completed_sessions"][index]
		if not raw_completed is Dictionary:
			errors.append("completed social session[%d] must be a Dictionary" % index)
			continue
		var completed: Dictionary = raw_completed
		for session_error in SocialSession.validate_persistence_state(completed, true):
			errors.append(
				"completed social session[%d]: %s" % [index, session_error]
			)

		if (
			completed.has("remaining_sim_seconds")
			and _is_finite_number(completed["remaining_sim_seconds"])
			and not is_equal_approx(float(completed["remaining_sim_seconds"]), 0.0)
		):
			errors.append(
				"completed social session[%d] remaining time must be zero" % index
			)

		for id_key in ["initiator_id", "target_id"]:
			if completed.has(id_key) and completed[id_key] is String:
				var resident_id := StringName(completed[id_key])
				if not resident_ids.has(resident_id):
					errors.append(
						"completed social session[%d] %s is not in resident roster"
						% [index, id_key]
					)

		if completed.has("action_id") and completed["action_id"] is String:
			if not _actions_by_id.has(StringName(completed["action_id"])):
				errors.append(
					"completed social action is not registered: %s"
					% completed["action_id"]
				)

		if completed.has("session_id") and completed["session_id"] is String:
			var session_id: String = completed["session_id"]
			if seen_session_ids.has(session_id):
				errors.append("duplicate social session id across runtime state: %s" % session_id)
			seen_session_ids[session_id] = true
			var parsed := _session_sequence_from_id(session_id)
			if parsed <= 0 or (sequence >= 0 and parsed > sequence):
				errors.append("completed social session id exceeds restored sequence: %s" % session_id)

	return errors

func cancel_session(session_id: StringName, residents: Array) -> bool:
	var session := _find_session(session_id)
	if session == null:
		return false

	var resident_by_id := _build_resident_lookup(residents)
	_reset_participant_action(resident_by_id, session.initiator_id, session.action_id)
	_reset_participant_action(resident_by_id, session.target_id, session.action_id)
	return reservation_book.release(session.session_id)

func advance(
	residents: Array,
	relationships: RelationshipGraph,
	sim_delta_seconds: float,
	rng: RandomNumberGenerator
) -> void:
	if relationships == null or rng == null:
		return
	if (
		is_nan(sim_delta_seconds)
		or is_inf(sim_delta_seconds)
		or sim_delta_seconds <= 0.0
	):
		return

	_simulation_seconds += sim_delta_seconds

	var completed_any := _advance_active_sessions(
		residents,
		relationships,
		sim_delta_seconds
	)
	if completed_any:
		return

	var candidate := _choose_candidate(residents, relationships, rng)
	if candidate.is_empty():
		return

	var action: SocialActionDefinition = candidate["action"]
	var initiator: CharacterState = candidate["initiator"]
	var target: CharacterState = candidate["target"]

	var session := reservation_book.reserve(
		initiator.id,
		target.id,
		action.id,
		action.duration_sim_seconds
	)
	if session == null:
		return

	initiator.current_action_id = action.id
	target.current_action_id = action.id

func _advance_active_sessions(
	residents: Array,
	relationships: RelationshipGraph,
	sim_delta_seconds: float
) -> bool:
	var completed_any := false
	var resident_by_id := _build_resident_lookup(residents)

	for session in reservation_book.active_sessions():
		session.remaining_sim_seconds = maxf(
			session.remaining_sim_seconds - sim_delta_seconds,
			0.0
		)
		if session.remaining_sim_seconds > 0.0:
			continue

		_apply_outcome(session, resident_by_id, relationships)
		_completed_sessions.append(session)
		_reset_participant_action(resident_by_id, session.initiator_id, session.action_id)
		_reset_participant_action(resident_by_id, session.target_id, session.action_id)
		reservation_book.release(session.session_id)
		completed_any = true

	return completed_any

func _apply_outcome(
	session: SocialSession,
	resident_by_id: Dictionary,
	relationships: RelationshipGraph
) -> void:
	if (
		not resident_by_id.has(session.initiator_id)
		or not resident_by_id.has(session.target_id)
	):
		return

	var initiator: CharacterState = resident_by_id[session.initiator_id]
	var target: CharacterState = resident_by_id[session.target_id]

	var affinity_delta := 5.0
	var trust_delta := 3.0
	var tension_delta := -2.0
	var valence := 0.3
	var importance := 0.3

	match session.action_id:
		&"compliment":
			affinity_delta = 10.0
			trust_delta = 6.0
			tension_delta = -4.0
			valence = 0.7
			importance = 0.6
		&"argue":
			affinity_delta = -10.0
			trust_delta = -6.0
			tension_delta = 15.0
			valence = -0.8
			importance = 0.7

	var forward := relationships.get_or_create(initiator.id, target.id)
	var reverse := relationships.get_or_create(target.id, initiator.id)
	if forward != null:
		forward.apply_delta(affinity_delta, trust_delta, tension_delta)
	if reverse != null:
		reverse.apply_delta(affinity_delta, trust_delta, tension_delta)

	_write_memory(initiator, target.id, session, valence, importance)
	_write_memory(target, initiator.id, session, valence, importance)

func _write_memory(
	character: CharacterState,
	other_resident_id: StringName,
	session: SocialSession,
	valence: float,
	importance: float
) -> void:
	if character == null or character.memory == null:
		return

	var event_id := StringName(
		"%s_%s" % [session.session_id, character.id]
	)
	var related_ids: Array[StringName] = [other_resident_id]
	var memory := MemoryEvent.new(
		event_id,
		session.action_id,
		_simulation_seconds,
		related_ids,
		valence,
		importance
	)
	character.memory.add(memory)

func _choose_candidate(
	residents: Array,
	relationships: RelationshipGraph,
	rng: RandomNumberGenerator
) -> Dictionary:
	var eligible: Array[CharacterState] = []
	for raw_resident in residents:
		if not raw_resident is CharacterState:
			continue
		var resident: CharacterState = raw_resident
		if not _is_eligible_resident(resident):
			continue
		eligible.append(resident)

	if eligible.size() < 2 or _actions_by_id.is_empty():
		return {}

	var action_ids: Array[String] = []
	for raw_action_id in _actions_by_id.keys():
		action_ids.append(str(raw_action_id))
	action_ids.sort()

	var candidates: Array[Dictionary] = []
	var best_score: float = -INF

	for initiator in eligible:
		for target in eligible:
			if initiator == target:
				continue

			for action_id_text in action_ids:
				var action_id := StringName(action_id_text)
				var action: SocialActionDefinition = _actions_by_id[action_id]
				var score: float = _score_action(
					initiator,
					target,
					action,
					relationships
				)
				if score < MIN_START_SCORE:
					continue

				if score > best_score + 0.0001:
					best_score = score
					candidates = [{
						"initiator": initiator,
						"target": target,
						"action": action,
						"score": score,
					}]
				elif is_equal_approx(score, best_score):
					candidates.append({
						"initiator": initiator,
						"target": target,
						"action": action,
						"score": score,
					})

	if candidates.is_empty():
		return {}
	if candidates.size() == 1:
		return candidates[0]

	return candidates[rng.randi_range(0, candidates.size() - 1)]

func _score_action(
	initiator: CharacterState,
	target: CharacterState,
	action: SocialActionDefinition,
	relationships: RelationshipGraph
) -> float:
	var social_urgency := 100.0 - clampf(initiator.needs.social.value, 0.0, 100.0)
	var sociability := clampf(initiator.personality.sociability, 0.0, 1.0)
	var kindness := clampf(initiator.personality.kindness, 0.0, 1.0)
	var impulsiveness := clampf(initiator.personality.impulsiveness, 0.0, 1.0)
	var base := social_urgency * (0.5 + 0.5 * sociability)

	var affinity := 0.0
	var trust := 0.0
	var tension := 0.0
	var relationship := relationships.get_relationship(initiator.id, target.id)
	if relationship != null:
		affinity = relationship.affinity
		trust = relationship.trust
		tension = relationship.tension

	var goal_target_bonus := _social_goal_target_bonus(initiator, target)

	match action.id:
		&"compliment":
			return (
				base * 0.85
				+ goal_target_bonus
				+ kindness * 30.0
				+ affinity * 0.10
				+ trust * 0.04
				- maxf(tension, 0.0) * 0.05
			)
		&"argue":
			return (
				base * 0.35
				+ goal_target_bonus
				+ impulsiveness * 25.0
				+ maxf(tension, 0.0) * 0.20
				- kindness * 15.0
				- affinity * 0.05
			)
		_:
			return (
				base
				+ goal_target_bonus
				+ affinity * 0.05
				+ trust * 0.03
				- maxf(tension, 0.0) * 0.03
			)

func _social_goal_target_bonus(
	initiator: CharacterState,
	target: CharacterState
) -> float:
	if initiator == null or target == null or initiator.goals == null:
		return 0.0

	var best_priority := -1.0
	for goal in initiator.goals.active_goals():
		if goal == null or goal.definition == null:
			continue
		if goal.definition.category != &"social":
			continue
		if goal.definition.target_resident_id != target.id:
			continue
		best_priority = maxf(
			best_priority,
			clampf(goal.definition.priority, 0.0, 1.0)
		)

	if best_priority < 0.0:
		return 0.0
	return 15.0 + best_priority * 35.0

func _is_eligible_resident(resident: CharacterState) -> bool:
	if resident == null or resident.id == &"":
		return false
	if resident.current_action_id != &"idle":
		return false
	if resident.movement == null or resident.movement.status != MovementState.STATUS_IDLE:
		return false
	if reservation_book.is_reserved(resident.id):
		return false
	return true

func _build_resident_lookup(residents: Array) -> Dictionary:
	var lookup: Dictionary = {}
	for raw_resident in residents:
		if not raw_resident is CharacterState:
			continue
		var resident: CharacterState = raw_resident
		if resident.id == &"":
			continue
		lookup[resident.id] = resident
	return lookup

func _reset_participant_action(
	resident_by_id: Dictionary,
	resident_id: StringName,
	action_id: StringName
) -> void:
	if not resident_by_id.has(resident_id):
		return
	var resident: CharacterState = resident_by_id[resident_id]
	if resident.current_action_id == action_id:
		resident.current_action_id = &"idle"

func _session_sequence_from_id(session_id: String) -> int:
	if not session_id.begins_with("social_"):
		return -1
	var suffix := session_id.trim_prefix("social_")
	if suffix.is_empty() or not suffix.is_valid_int():
		return -1
	var parsed := int(suffix)
	if session_id != "social_%06d" % parsed:
		return -1
	return parsed

func _is_finite_number(value) -> bool:
	if not (value is int or value is float):
		return false
	var number := float(value)
	return not is_nan(number) and not is_inf(number)

func _find_session(session_id: StringName) -> SocialSession:
	for session in reservation_book.active_sessions():
		if session.session_id == session_id:
			return session
	return null
