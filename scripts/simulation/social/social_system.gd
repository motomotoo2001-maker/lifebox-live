class_name SocialSystem
extends RefCounted

const MIN_START_SCORE := 20.0

var reservation_book := SocialReservationBook.new()

var _actions_by_id: Dictionary = {}
var _completed_sessions: Array[SocialSession] = []

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
	var completed := _completed_sessions.duplicate()
	_completed_sessions.clear()
	return completed

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

	var completed_any := _advance_active_sessions(residents, sim_delta_seconds)
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

		_completed_sessions.append(session)
		_reset_participant_action(resident_by_id, session.initiator_id, session.action_id)
		_reset_participant_action(resident_by_id, session.target_id, session.action_id)
		reservation_book.release(session.session_id)
		completed_any = true

	return completed_any

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
	var best_score := -INF

	for initiator in eligible:
		for target in eligible:
			if initiator == target:
				continue

			for action_id_text in action_ids:
				var action_id := StringName(action_id_text)
				var action: SocialActionDefinition = _actions_by_id[action_id]
				var score := _score_action(
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

	match action.id:
		&"compliment":
			return (
				base * 0.85
				+ kindness * 30.0
				+ affinity * 0.10
				+ trust * 0.04
				- maxf(tension, 0.0) * 0.05
			)
		&"argue":
			return (
				base * 0.35
				+ impulsiveness * 25.0
				+ maxf(tension, 0.0) * 0.20
				- kindness * 15.0
				- affinity * 0.05
			)
		_:
			return (
				base
				+ affinity * 0.05
				+ trust * 0.03
				- maxf(tension, 0.0) * 0.03
			)

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
