extends RefCounted

const BIAS_PATH := "res://scripts/simulation/goals/decision_bias_system.gd"
const CHARACTER_PATH := "res://scripts/simulation/characters/character_state.gd"
const INTERACTION_PATH := "res://scripts/simulation/interactions/interaction_definition.gd"
const BLOCK_PATH := "res://scripts/simulation/schedules/schedule_block.gd"
const DEFINITION_PATH := "res://scripts/simulation/schedules/schedule_definition.gd"
const GOAL_DEFINITION_PATH := "res://scripts/simulation/goals/goal_definition.gd"
const GOAL_STATE_PATH := "res://scripts/simulation/goals/goal_state.gd"
const RELATIONSHIP_GRAPH_PATH := "res://scripts/simulation/relationships/relationship_graph.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	if not FileAccess.file_exists(BIAS_PATH):
		failures.append("DecisionBiasSystem must exist at %s" % BIAS_PATH)
		return failures

	var bias_script = load(BIAS_PATH)
	var character_script = load(CHARACTER_PATH)
	var interaction_script = load(INTERACTION_PATH)
	var block_script = load(BLOCK_PATH)
	var schedule_definition_script = load(DEFINITION_PATH)
	var goal_definition_script = load(GOAL_DEFINITION_PATH)
	var goal_state_script = load(GOAL_STATE_PATH)
	var relationship_graph_script = load(RELATIONSHIP_GRAPH_PATH)

	for script in [
		bias_script,
		character_script,
		interaction_script,
		block_script,
		schedule_definition_script,
		goal_definition_script,
		goal_state_script,
		relationship_graph_script,
	]:
		if script == null or not script.can_instantiate():
			failures.append("schedule/goal bias dependencies must load and instantiate")
			return failures

	var probe_interaction = interaction_script.new()
	if not "action_tags" in probe_interaction:
		failures.append("InteractionDefinition must expose action_tags")
		return failures

	_test_schedule_bias(
		failures,
		bias_script,
		character_script,
		interaction_script,
		block_script,
		schedule_definition_script,
		relationship_graph_script
	)
	_test_goal_bias(
		failures,
		bias_script,
		character_script,
		interaction_script,
		goal_definition_script,
		goal_state_script,
		relationship_graph_script
	)
	_test_critical_need_override(
		failures,
		bias_script,
		character_script,
		interaction_script,
		block_script,
		schedule_definition_script,
		goal_definition_script,
		goal_state_script,
		relationship_graph_script
	)

	return failures

func _test_schedule_bias(
	failures: Array[String],
	bias_script,
	character_script,
	interaction_script,
	block_script,
	schedule_definition_script,
	relationship_graph_script
) -> void:
	var character = character_script.new(&"resident_a", "Resident A")
	var schedule = schedule_definition_script.new()
	var block = block_script.new()
	block.id = &"free"
	block.kind = &"free_time"
	block.start_hour = 0.0
	block.duration_hours = 24.0
	block.preferred_action_tags.append(&"relax")
	schedule.blocks.append(block)
	character.schedule.definition = schedule

	var relax = _interaction(interaction_script, &"relax", [&"relax"], {"comfort": 10.0})
	var work = _interaction(interaction_script, &"work", [&"work"], {"comfort": 10.0})
	var relationships = relationship_graph_script.new()
	var system = bias_script.new()

	var relax_score: float = system.adjust(
		character,
		relax,
		100.0,
		12.0 * 3600.0,
		relationships
	)
	var work_score: float = system.adjust(
		character,
		work,
		100.0,
		12.0 * 3600.0,
		relationships
	)

	if relax_score <= work_score:
		failures.append("matching active schedule tag must increase equal candidate score")
	if work_score != 100.0:
		failures.append("non-matching schedule candidate must keep base score")

func _test_goal_bias(
	failures: Array[String],
	bias_script,
	character_script,
	interaction_script,
	goal_definition_script,
	goal_state_script,
	relationship_graph_script
) -> void:
	var character = character_script.new(&"resident_goal", "Goal Resident")

	var goal_definition = goal_definition_script.new()
	goal_definition.id = &"work_today"
	goal_definition.category = &"work"
	goal_definition.priority = 1.0
	goal_definition.preferred_action_tags.append(&"work")
	if not character.goals.add(goal_state_script.new(goal_definition)):
		failures.append("goal bias fixture goal must be accepted")
		return

	var relax = _interaction(interaction_script, &"relax", [&"relax"], {"comfort": 10.0})
	var work = _interaction(interaction_script, &"work", [&"work"], {"comfort": 10.0})
	var relationships = relationship_graph_script.new()
	var system = bias_script.new()

	var relax_score: float = system.adjust(character, relax, 100.0, 0.0, relationships)
	var work_score: float = system.adjust(character, work, 100.0, 0.0, relationships)

	if work_score <= relax_score:
		failures.append("matching active goal tag must increase equal candidate score")
	if relax_score != 100.0:
		failures.append("non-matching goal candidate must keep base score")

func _test_critical_need_override(
	failures: Array[String],
	bias_script,
	character_script,
	interaction_script,
	block_script,
	schedule_definition_script,
	goal_definition_script,
	goal_state_script,
	relationship_graph_script
) -> void:
	var character = character_script.new(&"critical", "Critical Resident")
	character.needs.hunger.value = 10.0
	character.needs.energy.value = 100.0

	var schedule = schedule_definition_script.new()
	var block = block_script.new()
	block.id = &"fun"
	block.kind = &"free_time"
	block.start_hour = 0.0
	block.duration_hours = 24.0
	block.preferred_action_tags = [&"relax"]
	schedule.blocks.append(block)
	character.schedule.definition = schedule

	var fun_goal = goal_definition_script.new()
	fun_goal.id = &"fun_today"
	fun_goal.category = &"fun"
	fun_goal.priority = 1.0
	fun_goal.preferred_action_tags.append(&"relax")
	character.goals.add(goal_state_script.new(fun_goal))

	var eat = _interaction(interaction_script, &"eat", [&"eat"], {"hunger": 50.0})
	var relax = _interaction(interaction_script, &"relax", [&"relax"], {"comfort": 50.0})
	var relationships = relationship_graph_script.new()
	var system = bias_script.new()

	var eat_score: float = system.adjust(character, eat, 100.0, 0.0, relationships)
	var relax_score: float = system.adjust(character, relax, 100.0, 0.0, relationships)

	if eat_score <= relax_score:
		failures.append("critical hunger action must beat schedule+goal preference")
	if relax_score >= 100.0:
		failures.append("non-critical preferred action must be suppressed during critical need")

	var extreme_relax_score: float = system.adjust(
		character,
		relax,
		1000000000.0,
		0.0,
		relationships
	)
	var tiny_eat_score: float = system.adjust(
		character,
		eat,
		1.0,
		0.0,
		relationships
	)
	if tiny_eat_score <= extreme_relax_score:
		failures.append(
			"critical recovery must strictly outrank any non-critical base score"
		)

	character.needs.hunger.value = 100.0
	character.needs.energy.value = 10.0
	var sleep = _interaction(interaction_script, &"sleep", [&"sleep"], {"energy": 50.0})
	var sleep_score: float = system.adjust(character, sleep, 100.0, 0.0, relationships)
	relax_score = system.adjust(character, relax, 100.0, 0.0, relationships)
	if sleep_score <= relax_score:
		failures.append("critical energy action must beat schedule+goal preference")

func _interaction(
	interaction_script,
	id: StringName,
	tags: Array[StringName],
	need_effects: Dictionary
):
	var interaction = interaction_script.new()
	interaction.id = id
	interaction.action_tags = tags.duplicate()
	interaction.need_effects = need_effects.duplicate(true)
	interaction.duration_sim_seconds = 1.0
	return interaction
