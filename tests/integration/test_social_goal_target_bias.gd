extends RefCounted

const SOCIAL_SYSTEM_PATH := "res://scripts/simulation/social/social_system.gd"
const SOCIAL_ACTION_PATH := "res://scripts/simulation/social/social_action_definition.gd"
const CHARACTER_PATH := "res://scripts/simulation/characters/character_state.gd"
const RELATIONSHIP_GRAPH_PATH := "res://scripts/simulation/relationships/relationship_graph.gd"
const GOAL_DEFINITION_PATH := "res://scripts/simulation/goals/goal_definition.gd"
const GOAL_STATE_PATH := "res://scripts/simulation/goals/goal_state.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	var social_system_script = load(SOCIAL_SYSTEM_PATH)
	var social_action_script = load(SOCIAL_ACTION_PATH)
	var character_script = load(CHARACTER_PATH)
	var relationship_graph_script = load(RELATIONSHIP_GRAPH_PATH)
	var goal_definition_script = load(GOAL_DEFINITION_PATH)
	var goal_state_script = load(GOAL_STATE_PATH)

	for script in [
		social_system_script,
		social_action_script,
		character_script,
		relationship_graph_script,
		goal_definition_script,
		goal_state_script,
	]:
		if script == null or not script.can_instantiate():
			failures.append("social goal target bias dependencies must load")
			return failures

	var initiator = character_script.new(&"initiator", "Initiator")
	var preferred = character_script.new(&"preferred", "Preferred")
	var other = character_script.new(&"other", "Other")

	initiator.needs.social.value = 0.0
	initiator.personality.sociability = 1.0
	preferred.needs.social.value = 100.0
	other.needs.social.value = 100.0

	var definition = goal_definition_script.new()
	definition.id = &"social_preferred_day_0"
	definition.category = &"social"
	definition.priority = 1.0
	definition.preferred_action_tags.append(&"social")
	definition.target_resident_id = preferred.id
	if not initiator.goals.begin_day(0):
		failures.append("social goal fixture must begin day zero")
		return failures
	if not initiator.goals.add(goal_state_script.new(definition)):
		failures.append("social target goal must enter initiator goal set")
		return failures

	var social_system = social_system_script.new()
	var chat = social_action_script.new()
	chat.id = &"chat"
	chat.duration_sim_seconds = 20.0
	if not social_system.register_action(chat):
		failures.append("chat action must register")
		return failures

	var relationships = relationship_graph_script.new()
	relationships.get_or_create(initiator.id, preferred.id)
	relationships.get_or_create(
		initiator.id,
		other.id
	).apply_delta(80.0, 0.0, 0.0)

	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	social_system.advance(
		[initiator, preferred, other],
		relationships,
		1.0,
		rng
	)

	var sessions: Array = social_system.active_sessions()
	if sessions.size() != 1:
		failures.append("social target bias fixture must start exactly one session")
		return failures

	var session = sessions[0]
	if session.initiator_id != initiator.id:
		failures.append("high-urgency goal owner must initiate the social session")
	if session.target_id != preferred.id:
		failures.append("active social goal must bias session toward its target resident")

	return failures
