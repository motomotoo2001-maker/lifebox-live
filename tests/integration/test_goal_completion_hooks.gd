extends RefCounted

const CHARACTER_PATH := "res://scripts/simulation/characters/character_state.gd"
const GOAL_DEFINITION_PATH := "res://scripts/simulation/goals/goal_definition.gd"
const GOAL_STATE_PATH := "res://scripts/simulation/goals/goal_state.gd"
const INTERACTION_PATH := "res://scripts/simulation/interactions/interaction_definition.gd"
const CANDIDATE_PATH := "res://scripts/simulation/utility_ai/action_candidate.gd"
const EXECUTOR_PATH := "res://scripts/simulation/actions/action_executor.gd"
const ECONOMY_PATH := "res://scripts/simulation/economy/economy_system.gd"
const SMART_OBJECT_PATH := "res://scripts/simulation/interactions/smart_object.gd"
const SOCIAL_SYSTEM_PATH := "res://scripts/simulation/social/social_system.gd"
const SOCIAL_ACTION_PATH := "res://scripts/simulation/social/social_action_definition.gd"
const RELATIONSHIP_GRAPH_PATH := "res://scripts/simulation/relationships/relationship_graph.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	var character_script = load(CHARACTER_PATH)
	var goal_definition_script = load(GOAL_DEFINITION_PATH)
	var goal_state_script = load(GOAL_STATE_PATH)
	var interaction_script = load(INTERACTION_PATH)
	var candidate_script = load(CANDIDATE_PATH)
	var executor_script = load(EXECUTOR_PATH)
	var economy_script = load(ECONOMY_PATH)
	var smart_object_script = load(SMART_OBJECT_PATH)
	var social_system_script = load(SOCIAL_SYSTEM_PATH)
	var social_action_script = load(SOCIAL_ACTION_PATH)
	var relationship_graph_script = load(RELATIONSHIP_GRAPH_PATH)

	for script in [
		character_script,
		goal_definition_script,
		goal_state_script,
		interaction_script,
		candidate_script,
		executor_script,
		economy_script,
		smart_object_script,
		social_system_script,
		social_action_script,
		relationship_graph_script,
	]:
		if script == null or not script.can_instantiate():
			failures.append("goal completion dependencies must load and instantiate")
			return failures

	_test_successful_interaction_completes_matching_goal(
		failures,
		character_script,
		goal_definition_script,
		goal_state_script,
		interaction_script,
		candidate_script,
		executor_script,
		economy_script
	)
	_test_cancel_and_movement_failure_do_not_complete(
		failures,
		character_script,
		goal_definition_script,
		goal_state_script,
		interaction_script,
		candidate_script,
		executor_script,
		economy_script,
		smart_object_script
	)
	_test_social_completion_completes_targeted_goal(
		failures,
		character_script,
		goal_definition_script,
		goal_state_script,
		social_system_script,
		social_action_script,
		relationship_graph_script
	)

	return failures

func _test_successful_interaction_completes_matching_goal(
	failures: Array[String],
	character_script,
	goal_definition_script,
	goal_state_script,
	interaction_script,
	candidate_script,
	executor_script,
	economy_script
) -> void:
	var resident = character_script.new(&"resident_action", "Action Resident")
	resident.goals.begin_day(0)

	var relax_goal = _goal(
		goal_definition_script,
		goal_state_script,
		&"relax_day_0",
		&"wellbeing",
		[&"relax"]
	)
	var work_goal = _goal(
		goal_definition_script,
		goal_state_script,
		&"work_day_0",
		&"work",
		[&"work"]
	)
	resident.goals.add(relax_goal)
	resident.goals.add(work_goal)

	var interaction = interaction_script.new()
	interaction.id = &"relax"
	interaction.duration_sim_seconds = 1.0
	interaction.need_effects = {"comfort": 10.0}
	interaction.action_tags.append(&"relax")

	var candidate = candidate_script.new(
		interaction.id,
		100.0,
		null,
		interaction
	)
	var executor = executor_script.new(economy_script.new())

	if not executor.start(candidate, resident):
		failures.append("goal completion interaction must start")
		return
	if not executor.advance(1.0):
		failures.append("goal completion interaction must finish")
		return

	if relax_goal.status != GoalState.STATUS_COMPLETED:
		failures.append("successful matching interaction must complete goal")
	if not is_equal_approx(relax_goal.progress, 1.0):
		failures.append("completed matching goal must reach full progress")
	if work_goal.status != GoalState.STATUS_ACTIVE:
		failures.append("unrelated goal must remain active")

func _test_cancel_and_movement_failure_do_not_complete(
	failures: Array[String],
	character_script,
	goal_definition_script,
	goal_state_script,
	interaction_script,
	candidate_script,
	executor_script,
	economy_script,
	smart_object_script
) -> void:
	var resident = character_script.new(&"resident_cancel", "Cancel Resident")
	resident.goals.begin_day(0)
	var goal = _goal(
		goal_definition_script,
		goal_state_script,
		&"relax_day_0",
		&"wellbeing",
		[&"relax"]
	)
	resident.goals.add(goal)

	var interaction = interaction_script.new()
	interaction.id = &"relax"
	interaction.duration_sim_seconds = 10.0
	interaction.need_effects = {"comfort": 10.0}
	interaction.action_tags.append(&"relax")

	var executor = executor_script.new(economy_script.new())
	var immediate_candidate = candidate_script.new(
		interaction.id,
		100.0,
		null,
		interaction
	)
	if not executor.start(immediate_candidate, resident):
		failures.append("cancel fixture action must start")
		return
	executor.cancel()
	if goal.status != GoalState.STATUS_ACTIVE:
		failures.append("cancelled interaction must not complete goal")

	var smart_object = smart_object_script.new()
	smart_object.object_id = &"relax_object"
	smart_object.interaction_point = Vector3.ZERO
	smart_object.interactions.append(interaction)

	var moving_candidate = candidate_script.new(
		interaction.id,
		100.0,
		smart_object,
		interaction
	)
	if not executor.start(moving_candidate, resident):
		failures.append("movement failure fixture action must start")
		smart_object.free()
		return
	if not executor.report_movement_failure(smart_object.object_id):
		failures.append("movement failure feedback must apply")
	if goal.status != GoalState.STATUS_ACTIVE:
		failures.append("movement failure must not complete goal")

	smart_object.free()

func _test_social_completion_completes_targeted_goal(
	failures: Array[String],
	character_script,
	goal_definition_script,
	goal_state_script,
	social_system_script,
	social_action_script,
	relationship_graph_script
) -> void:
	var initiator = character_script.new(&"initiator", "Initiator")
	var target = character_script.new(&"target", "Target")
	initiator.needs.social.value = 0.0
	initiator.personality.sociability = 1.0
	target.needs.social.value = 100.0

	initiator.goals.begin_day(0)
	var social_goal = _goal(
		goal_definition_script,
		goal_state_script,
		&"social_target_day_0",
		&"social",
		[&"social"],
		target.id
	)
	initiator.goals.add(social_goal)

	var system = social_system_script.new()
	var chat = social_action_script.new()
	chat.id = &"chat"
	chat.duration_sim_seconds = 2.0
	if not system.register_action(chat):
		failures.append("social completion chat action must register")
		return

	var relationships = relationship_graph_script.new()
	relationships.get_or_create(initiator.id, target.id)

	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	system.advance([initiator, target], relationships, 1.0, rng)
	if system.active_sessions().size() != 1:
		failures.append("social completion fixture must start one session")
		return

	system.advance([initiator, target], relationships, 2.0, rng)
	if social_goal.status != GoalState.STATUS_COMPLETED:
		failures.append("completed social session with goal target must complete social goal")
	if not is_equal_approx(social_goal.progress, 1.0):
		failures.append("completed social goal must reach full progress")

func _goal(
	goal_definition_script,
	goal_state_script,
	id: StringName,
	category: StringName,
	tags: Array[StringName],
	target_resident_id: StringName = &""
):
	var definition = goal_definition_script.new()
	definition.id = id
	definition.category = category
	definition.priority = 1.0
	for tag in tags:
		definition.preferred_action_tags.append(tag)
	definition.target_resident_id = target_resident_id
	return goal_state_script.new(definition)
