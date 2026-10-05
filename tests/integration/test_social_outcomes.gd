extends RefCounted

const SOCIAL_SYSTEM_PATH := "res://scripts/simulation/social/social_system.gd"
const SOCIAL_ACTION_PATH := "res://scripts/simulation/social/social_action_definition.gd"
const RELATIONSHIP_GRAPH_PATH := "res://scripts/simulation/relationships/relationship_graph.gd"
const CHARACTER_PATH := "res://scripts/simulation/characters/character_state.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	var social_system_script := load(SOCIAL_SYSTEM_PATH)
	var action_script := load(SOCIAL_ACTION_PATH)
	var relationship_script := load(RELATIONSHIP_GRAPH_PATH)
	var character_script := load(CHARACTER_PATH)
	if social_system_script == null or action_script == null or relationship_script == null or character_script == null:
		failures.append("social outcome dependencies must load")
		return failures

	_test_completed_outcome(
		failures,
		social_system_script,
		action_script,
		relationship_script,
		character_script,
		&"compliment",
		20.0,
		true
	)
	_test_completed_outcome(
		failures,
		social_system_script,
		action_script,
		relationship_script,
		character_script,
		&"argue",
		20.0,
		false
	)
	_test_cancelled_session_has_no_outcome(
		failures,
		social_system_script,
		action_script,
		relationship_script,
		character_script
	)

	return failures

func _test_completed_outcome(
	failures: Array[String],
	social_system_script,
	action_script,
	relationship_script,
	character_script,
	action_id: StringName,
	duration: float,
	positive: bool
) -> void:
	var system = social_system_script.new()
	var action = action_script.new()
	action.id = action_id
	action.duration_sim_seconds = duration
	if not system.register_action(action):
		failures.append("social outcome action %s must register" % action_id)
		return

	var a = character_script.new(&"a_%s" % action_id, "A")
	var b = character_script.new(&"b_%s" % action_id, "B")
	a.needs.social.value = 0.0
	b.needs.social.value = 0.0
	a.personality.sociability = 1.0
	b.personality.sociability = 1.0
	if action_id == &"argue":
		a.personality.kindness = 0.0
		a.personality.impulsiveness = 1.0
		b.personality.kindness = 0.0
		b.personality.impulsiveness = 1.0
	else:
		a.personality.kindness = 1.0
		b.personality.kindness = 1.0

	var relationships = relationship_script.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99

	var residents: Array = [a, b]
	system.advance(residents, relationships, 1.0, rng)
	var sessions: Array = system.active_sessions()
	if sessions.size() != 1:
		failures.append("%s must start exactly one social session" % action_id)
		return

	system.advance(residents, relationships, duration, rng)

	if not system.active_sessions().is_empty():
		failures.append("%s completion must release social reservation" % action_id)

	var a_to_b = relationships.get_relationship(a.id, b.id)
	var b_to_a = relationships.get_relationship(b.id, a.id)
	if a_to_b == null or b_to_a == null:
		failures.append("%s completion must create both directed relationship edges" % action_id)
		return

	if positive:
		if a_to_b.affinity <= 0.0 or a_to_b.trust <= 0.0:
			failures.append("positive social outcome must increase affinity and trust")
		if a_to_b.tension >= 0.0:
			failures.append("positive social outcome must reduce tension")
	else:
		if a_to_b.affinity >= 0.0 or a_to_b.trust >= 0.0:
			failures.append("argue outcome must reduce affinity and trust")
		if a_to_b.tension <= 0.0:
			failures.append("argue outcome must increase tension")

	if not is_equal_approx(a_to_b.affinity, b_to_a.affinity):
		failures.append("%s outcome must update both directions symmetrically for now" % action_id)

	if a.memory.size() != 1 or b.memory.size() != 1:
		failures.append("%s completion must write one memory to each participant" % action_id)
		return

	var a_memory = a.memory.events()[0]
	var b_memory = b.memory.events()[0]
	if a_memory.kind != action_id or b_memory.kind != action_id:
		failures.append("%s memories must preserve social action kind" % action_id)
	if b.id not in a_memory.related_resident_ids or a.id not in b_memory.related_resident_ids:
		failures.append("%s memories must reference the other participant" % action_id)
	if positive and (a_memory.valence <= 0.0 or b_memory.valence <= 0.0):
		failures.append("positive social memories must have positive valence")
	if not positive and (a_memory.valence >= 0.0 or b_memory.valence >= 0.0):
		failures.append("argue memories must have negative valence")

	var completed: Array = system.take_completed_sessions()
	if completed.size() != 1:
		failures.append("%s completed session must be observable exactly once" % action_id)
	if not system.take_completed_sessions().is_empty():
		failures.append("%s completed session queue must drain exactly once" % action_id)

func _test_cancelled_session_has_no_outcome(
	failures: Array[String],
	social_system_script,
	action_script,
	relationship_script,
	character_script
) -> void:
	var system = social_system_script.new()
	var chat = action_script.new()
	chat.id = &"chat"
	chat.duration_sim_seconds = 30.0
	system.register_action(chat)

	var a = character_script.new(&"cancel_a", "Cancel A")
	var b = character_script.new(&"cancel_b", "Cancel B")
	a.needs.social.value = 0.0
	b.needs.social.value = 0.0
	var relationships = relationship_script.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7

	var residents: Array = [a, b]
	system.advance(residents, relationships, 1.0, rng)
	var sessions: Array = system.active_sessions()
	if sessions.size() != 1:
		failures.append("cancel test must start one session")
		return

	var session = sessions[0]
	if not system.cancel_session(session.session_id, residents):
		failures.append("cancel_session() must cancel active social session")
		return

	if relationships.get_relationship(a.id, b.id) != null:
		failures.append("cancelled social session must not create relationship outcome")
	if a.memory.size() != 0 or b.memory.size() != 0:
		failures.append("cancelled social session must not write memory")
	if a.current_action_id != &"idle" or b.current_action_id != &"idle":
		failures.append("cancelled social session must return both participants to idle")
	if not system.take_completed_sessions().is_empty():
		failures.append("cancelled social session must not enter completed queue")
