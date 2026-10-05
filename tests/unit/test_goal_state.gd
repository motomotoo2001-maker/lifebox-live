extends RefCounted

const DEFINITION_PATH := "res://scripts/simulation/goals/goal_definition.gd"
const STATE_PATH := "res://scripts/simulation/goals/goal_state.gd"
const SET_PATH := "res://scripts/simulation/goals/goal_set.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	for path in [DEFINITION_PATH, STATE_PATH, SET_PATH]:
		if not FileAccess.file_exists(path):
			failures.append("goal dependency must exist at %s" % path)
			return failures

	var definition_script = load(DEFINITION_PATH)
	var state_script = load(STATE_PATH)
	var set_script = load(SET_PATH)
	for script in [definition_script, state_script, set_script]:
		if script == null or not script.can_instantiate():
			failures.append("goal dependencies must load and instantiate")
			return failures

	_test_definition_validation(failures, definition_script)
	_test_progress_and_status(failures, definition_script, state_script)
	_test_goal_set_contract(failures, definition_script, state_script, set_script)
	return failures

func _definition(
	definition_script,
	id: StringName,
	category: StringName,
	priority: float,
	tags: Array[StringName],
	target: StringName = &""
):
	var definition = definition_script.new()
	definition.id = id
	definition.category = category
	definition.priority = priority
	definition.preferred_action_tags = tags.duplicate()
	definition.target_resident_id = target
	return definition

func _test_definition_validation(
	failures: Array[String],
	definition_script
) -> void:
	var valid = _definition(
		definition_script,
		&"relax_today",
		&"wellbeing",
		0.6,
		[&"relax"]
	)
	if not valid.validate().is_empty():
		failures.append("valid goal definition must pass validation")

	var targeted = _definition(
		definition_script,
		&"talk_to_b",
		&"social",
		0.8,
		[&"social"],
		&"resident_b"
	)
	if not targeted.validate().is_empty():
		failures.append("targeted social goal must pass validation")

	var invalid_cases := [
		_definition(definition_script, &"", &"wellbeing", 0.5, [&"relax"]),
		_definition(definition_script, &"bad_category", &"", 0.5, [&"relax"]),
		_definition(definition_script, &"bad_priority_low", &"wellbeing", -0.1, [&"relax"]),
		_definition(definition_script, &"bad_priority_high", &"wellbeing", 1.1, [&"relax"]),
		_definition(definition_script, &"bad_priority_nan", &"wellbeing", NAN, [&"relax"]),
		_definition(definition_script, &"no_tags", &"wellbeing", 0.5, []),
		_definition(
			definition_script,
			&"duplicate_tags",
			&"wellbeing",
			0.5,
			[&"relax", &"relax"]
		),
	]
	for definition in invalid_cases:
		if definition.validate().is_empty():
			failures.append("invalid goal definition must fail: %s" % definition.id)

func _test_progress_and_status(
	failures: Array[String],
	definition_script,
	state_script
) -> void:
	var definition = _definition(
		definition_script,
		&"comfort_goal",
		&"wellbeing",
		0.7,
		[&"relax"]
	)
	var state = state_script.new(definition)

	if state.status != state_script.STATUS_ACTIVE:
		failures.append("new goal state must start active")
	if not is_equal_approx(state.progress, 0.0):
		failures.append("new goal progress must start at zero")

	if not state.set_progress(0.4):
		failures.append("finite goal progress update must succeed")
	if not is_equal_approx(state.progress, 0.4):
		failures.append("goal progress must update")
	if state.status != state_script.STATUS_ACTIVE:
		failures.append("partial progress must remain active")

	if state.set_progress(NAN):
		failures.append("NaN goal progress must be rejected")
	if not is_equal_approx(state.progress, 0.4):
		failures.append("rejected progress must not mutate state")

	if not state.set_progress(2.0):
		failures.append("progress above 1 must clamp and succeed")
	if not is_equal_approx(state.progress, 1.0):
		failures.append("goal progress must clamp to 1")
	if state.status != state_script.STATUS_COMPLETED:
		failures.append("progress reaching 1 must complete goal")

	var failed = state_script.new(definition)
	failed.fail()
	if failed.status != state_script.STATUS_FAILED:
		failures.append("fail() must mark goal failed")
	if not is_equal_approx(failed.progress, 0.0):
		failures.append("fail() must not invent progress")

	var completed = state_script.new(definition)
	completed.complete()
	if (
		completed.status != state_script.STATUS_COMPLETED
		or not is_equal_approx(completed.progress, 1.0)
	):
		failures.append("complete() must set completed status and full progress")

func _test_goal_set_contract(
	failures: Array[String],
	definition_script,
	state_script,
	set_script
) -> void:
	var set = set_script.new()

	for index in range(set_script.MAX_ACTIVE_GOALS):
		var definition = _definition(
			definition_script,
			StringName("goal_%d" % index),
			&"wellbeing",
			0.5,
			[&"relax"]
		)
		if not set.add(state_script.new(definition)):
			failures.append("GoalSet must accept up to MAX_ACTIVE_GOALS active goals")
			return

	if set.active_goals().size() != set_script.MAX_ACTIVE_GOALS:
		failures.append("GoalSet active_goals must report all active goals")

	var overflow_definition = _definition(
		definition_script,
		&"goal_overflow",
		&"wellbeing",
		0.5,
		[&"relax"]
	)
	if set.add(state_script.new(overflow_definition)):
		failures.append("GoalSet must reject active goal beyond MAX_ACTIVE_GOALS")

	var duplicate_definition = _definition(
		definition_script,
		&"goal_0",
		&"social",
		0.8,
		[&"social"]
	)
	if set.add(state_script.new(duplicate_definition)):
		failures.append("GoalSet must reject duplicate goal ids")

	var first = set.get_goal(&"goal_0")
	if first == null:
		failures.append("GoalSet get_goal must find stored goal")
		return

	first.complete()
	if set.active_goals().size() != set_script.MAX_ACTIVE_GOALS - 1:
		failures.append("completed goal must leave active_goals view")

	if not set.add(state_script.new(overflow_definition)):
		failures.append("completed goal must free one active-goal slot")
	if set.goals().size() != set_script.MAX_ACTIVE_GOALS + 1:
		failures.append("GoalSet must retain completed state for current day history")

	var exposed: Array = set.goals()
	exposed.clear()
	if set.goals().is_empty():
		failures.append("GoalSet.goals() must not expose mutable internal storage")
