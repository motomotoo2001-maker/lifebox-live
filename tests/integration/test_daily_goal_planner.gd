extends RefCounted

const PLANNER_PATH := "res://scripts/simulation/goals/daily_goal_planner.gd"
const CHARACTER_PATH := "res://scripts/simulation/characters/character_state.gd"
const JOB_DEFINITION_PATH := "res://scripts/simulation/economy/job_definition.gd"
const RELATIONSHIP_GRAPH_PATH := "res://scripts/simulation/relationships/relationship_graph.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	if not FileAccess.file_exists(PLANNER_PATH):
		failures.append("DailyGoalPlanner must exist at %s" % PLANNER_PATH)
		return failures

	var planner_script = load(PLANNER_PATH)
	var character_script = load(CHARACTER_PATH)
	var job_definition_script = load(JOB_DEFINITION_PATH)
	var relationship_graph_script = load(RELATIONSHIP_GRAPH_PATH)
	for script in [
		planner_script,
		character_script,
		job_definition_script,
		relationship_graph_script,
	]:
		if script == null or not script.can_instantiate():
			failures.append("daily goal planner dependencies must load and instantiate")
			return failures

	_test_same_seed_same_goals(
		failures,
		planner_script,
		character_script,
		job_definition_script,
		relationship_graph_script
	)
	_test_personality_changes_goal_mix(
		failures,
		planner_script,
		character_script,
		job_definition_script,
		relationship_graph_script
	)
	_test_social_target_validation(
		failures,
		planner_script,
		character_script,
		relationship_graph_script
	)

	return failures

func _test_same_seed_same_goals(
	failures: Array[String],
	planner_script,
	character_script,
	job_definition_script,
	relationship_graph_script
) -> void:
	var first = _build_profile(
		character_script,
		job_definition_script,
		&"resident_a",
		0.8,
		0.7,
		0.5,
		true
	)
	var second = _build_profile(
		character_script,
		job_definition_script,
		&"resident_a",
		0.8,
		0.7,
		0.5,
		true
	)

	var first_graph = _graph_with_target(
		relationship_graph_script,
		first.id,
		&"resident_b",
		30.0
	)
	var second_graph = _graph_with_target(
		relationship_graph_script,
		second.id,
		&"resident_b",
		30.0
	)

	var first_rng := RandomNumberGenerator.new()
	first_rng.seed = 424242
	var second_rng := RandomNumberGenerator.new()
	second_rng.seed = 424242

	var first_goals: Array = planner_script.generate(first, first_graph, 3, first_rng)
	var second_goals: Array = planner_script.generate(second, second_graph, 3, second_rng)

	if first_goals.size() < 1 or first_goals.size() > 3:
		failures.append("planner must generate between 1 and 3 goals when candidates exist")
		return
	if first_goals.size() != second_goals.size():
		failures.append("same seed/profile must generate same goal count")
		return

	var first_ids: Array[String] = []
	var second_ids: Array[String] = []
	for goal in first_goals:
		first_ids.append(str(goal.definition.id))
	for goal in second_goals:
		second_ids.append(str(goal.definition.id))

	if first_ids != second_ids:
		failures.append("same seed/profile/day must generate identical goal IDs")

	var seen: Dictionary = {}
	for goal in first_goals:
		if goal == null or goal.definition == null:
			failures.append("planner must return valid GoalState entries")
			continue
		if not goal.definition.validate().is_empty():
			failures.append("planner must return valid GoalDefinitions")
		if seen.has(goal.definition.id):
			failures.append("planner must not generate duplicate goal IDs")
		seen[goal.definition.id] = true

func _test_personality_changes_goal_mix(
	failures: Array[String],
	planner_script,
	character_script,
	job_definition_script,
	relationship_graph_script
) -> void:
	var social = _build_profile(
		character_script,
		job_definition_script,
		&"social_resident",
		1.0,
		0.0,
		0.0,
		false
	)
	var ambitious = _build_profile(
		character_script,
		job_definition_script,
		&"ambitious_resident",
		0.0,
		1.0,
		0.0,
		true
	)
	var impulsive = _build_profile(
		character_script,
		job_definition_script,
		&"impulsive_resident",
		0.0,
		0.0,
		1.0,
		false
	)

	var social_graph = _graph_with_target(
		relationship_graph_script,
		social.id,
		&"resident_friend",
		70.0
	)
	var ambitious_graph = relationship_graph_script.new()
	var impulsive_graph = relationship_graph_script.new()

	var social_rng := RandomNumberGenerator.new()
	social_rng.seed = 17
	var ambitious_rng := RandomNumberGenerator.new()
	ambitious_rng.seed = 17
	var impulsive_rng := RandomNumberGenerator.new()
	impulsive_rng.seed = 17

	var social_goals: Array = planner_script.generate(social, social_graph, 0, social_rng)
	var ambitious_goals: Array = planner_script.generate(
		ambitious,
		ambitious_graph,
		0,
		ambitious_rng
	)
	var impulsive_goals: Array = planner_script.generate(
		impulsive,
		impulsive_graph,
		0,
		impulsive_rng
	)

	if not _has_category(social_goals, &"social"):
		failures.append("high sociability resident must receive a social goal")
	if not _has_category(ambitious_goals, &"work"):
		failures.append("high ambition employed resident must receive a work goal")
	if not _has_category(impulsive_goals, &"fun"):
		failures.append("high impulsiveness resident must receive a fun goal")

func _test_social_target_validation(
	failures: Array[String],
	planner_script,
	character_script,
	relationship_graph_script
) -> void:
	var resident = character_script.new(&"resident_a", "Resident A")
	resident.personality.sociability = 1.0

	var empty_graph = relationship_graph_script.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var no_target_goals: Array = planner_script.generate(
		resident,
		empty_graph,
		1,
		rng
	)
	if _has_category(no_target_goals, &"social"):
		failures.append("planner must not generate social goal without a valid target")

	var graph = _graph_with_target(
		relationship_graph_script,
		resident.id,
		&"resident_b",
		10.0
	)
	rng.seed = 5
	var goals: Array = planner_script.generate(resident, graph, 1, rng)
	for goal in goals:
		if goal.definition.category == &"social":
			if goal.definition.target_resident_id != &"resident_b":
				failures.append("social goal must reference an existing relationship target")
			if goal.definition.target_resident_id == resident.id:
				failures.append("social goal must never target self")

func _build_profile(
	character_script,
	job_definition_script,
	id: StringName,
	sociability: float,
	ambition: float,
	impulsiveness: float,
	with_job: bool
):
	var resident = character_script.new(id, str(id))
	resident.personality.sociability = sociability
	resident.personality.ambition = ambition
	resident.personality.impulsiveness = impulsiveness
	resident.personality.neatness = 0.5
	resident.personality.kindness = 0.5

	if with_job:
		var job = job_definition_script.new()
		job.id = StringName("job_%s" % id)
		job.pay_per_sim_hour = 20.0
		job.shift_start_hour = 8.0
		job.shift_duration_hours = 8.0
		resident.job.assign(job)

	return resident

func _graph_with_target(
	relationship_graph_script,
	from_id: StringName,
	to_id: StringName,
	affinity: float
):
	var graph = relationship_graph_script.new()
	var relationship = graph.get_or_create(from_id, to_id)
	relationship.apply_delta(affinity, 0.0, 0.0)
	return graph

func _has_category(goals: Array, category: StringName) -> bool:
	for goal in goals:
		if goal != null and goal.definition != null and goal.definition.category == category:
			return true
	return false
