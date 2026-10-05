extends RefCounted

const PLANNING_PATH := "res://scripts/simulation/goals/daily_planning_system.gd"
const WORLD_PATH := "res://scripts/simulation/simulation_world.gd"
const CHARACTER_PATH := "res://scripts/simulation/characters/character_state.gd"
const JOB_DEFINITION_PATH := "res://scripts/simulation/economy/job_definition.gd"
const BLOCK_PATH := "res://scripts/simulation/schedules/schedule_block.gd"
const DEFINITION_PATH := "res://scripts/simulation/schedules/schedule_definition.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	if not FileAccess.file_exists(PLANNING_PATH):
		failures.append("DailyPlanningSystem must exist at %s" % PLANNING_PATH)
		return failures

	var planning_script = load(PLANNING_PATH)
	var world_script = load(WORLD_PATH)
	var character_script = load(CHARACTER_PATH)
	var job_definition_script = load(JOB_DEFINITION_PATH)
	var block_script = load(BLOCK_PATH)
	var definition_script = load(DEFINITION_PATH)

	for script in [
		planning_script,
		world_script,
		character_script,
		job_definition_script,
		block_script,
		definition_script,
	]:
		if script == null or not script.can_instantiate():
			failures.append("daily planning dependencies must load and instantiate")
			return failures

	_test_rollover_and_idempotence(
		failures,
		planning_script,
		world_script,
		character_script,
		job_definition_script,
		block_script,
		definition_script
	)
	_test_same_seed_same_daily_plan(
		failures,
		planning_script,
		world_script,
		character_script,
		job_definition_script
	)

	return failures

func _test_rollover_and_idempotence(
	failures: Array[String],
	planning_script,
	world_script,
	character_script,
	job_definition_script,
	block_script,
	definition_script
) -> void:
	var world = world_script.new()
	var resident = character_script.new(&"planner_a", "Planner A")
	resident.personality.ambition = 1.0
	resident.personality.sociability = 1.0
	resident.money = 55.0

	var job = job_definition_script.new()
	job.id = &"job_planner"
	job.pay_per_sim_hour = 20.0
	job.shift_start_hour = 8.0
	job.shift_duration_hours = 8.0
	resident.job.assign(job)
	resident.job.total_worked_sim_seconds = 123.0

	var schedule = definition_script.new()
	var work_block = block_script.new()
	work_block.id = &"work"
	work_block.kind = &"work"
	work_block.start_hour = 8.0
	work_block.duration_hours = 8.0
	work_block.preferred_action_tags.append(&"work")
	schedule.blocks.append(work_block)
	resident.schedule.definition = schedule

	if not world.add_character(resident):
		failures.append("daily planning resident must enter world")
		return

	var friend = character_script.new(&"planner_b", "Planner B")
	if not world.add_character(friend):
		failures.append("daily planning friend must enter world")
		return
	world.relationship_graph.get_or_create(
		resident.id,
		friend.id
	).apply_delta(50.0, 20.0, 0.0)

	var rng := RandomNumberGenerator.new()
	rng.seed = 8080
	var system = planning_script.new()

	system.advance(world, 9.0 * 3600.0, rng)

	if resident.schedule.day_index != 0:
		failures.append("day-zero planning must set schedule day index 0")
	if resident.schedule.active_block_id != &"work":
		failures.append("09:00 must activate work schedule block")
	if resident.goals.day_index != 0:
		failures.append("first planning pass must generate day-zero goals")
	if resident.goals.active_goals().is_empty():
		failures.append("first planning pass must generate active goals")
	if resident.goals.active_goals().size() > 3:
		failures.append("daily planner must keep at most three active goals")
	if not _has_category(resident.goals.active_goals(), &"work"):
		failures.append("ambitious employed resident must have work goal")
	if not _has_category(resident.goals.active_goals(), &"social"):
		failures.append("social resident with relationship target must have social goal")

	var first_ids := _goal_ids(resident.goals.active_goals())
	var first_refs: Array = resident.goals.active_goals()
	var rng_state_before := rng.state
	var money_before := resident.money
	var worked_before := resident.job.total_worked_sim_seconds

	system.advance(world, 9.0 * 3600.0, rng)

	if _goal_ids(resident.goals.active_goals()) != first_ids:
		failures.append("repeated same-day planning must not regenerate goals")
	if rng.state != rng_state_before:
		failures.append("daily planning must not consume caller RNG state")
	if resident.money != money_before:
		failures.append("daily planning must not pay or spend money")
	if resident.job.total_worked_sim_seconds != worked_before:
		failures.append("daily planning must not advance job wages/work time")

	system.advance(world, 24.0 * 3600.0 + 9.0 * 3600.0, rng)

	if resident.schedule.day_index != 1:
		failures.append("next-day planning must roll schedule to day 1")
	if resident.goals.day_index != 1:
		failures.append("next-day planning must generate day-one goals")
	var second_ids := _goal_ids(resident.goals.active_goals())
	if second_ids == first_ids:
		failures.append("day-one goal IDs must differ from day-zero IDs")
	for old_goal in first_refs:
		if old_goal.status == GoalState.STATUS_ACTIVE:
			failures.append("previous-day active goals must be retired before new day")

	var day_one_ids := second_ids.duplicate()
	system.advance(world, 24.0 * 3600.0 + 9.0 * 3600.0, rng)
	if _goal_ids(resident.goals.active_goals()) != day_one_ids:
		failures.append("repeated day-one timestamp must remain idempotent")

	var before_day := resident.goals.day_index
	system.advance(world, -1.0, rng)
	system.advance(world, NAN, rng)
	if resident.goals.day_index != before_day:
		failures.append("invalid planning timestamps must not mutate goal day")

func _test_same_seed_same_daily_plan(
	failures: Array[String],
	planning_script,
	world_script,
	character_script,
	job_definition_script
) -> void:
	var first_world = world_script.new()
	var second_world = world_script.new()
	var first = _resident_with_job(
		character_script,
		job_definition_script,
		&"same_seed"
	)
	var second = _resident_with_job(
		character_script,
		job_definition_script,
		&"same_seed"
	)
	first_world.add_character(first)
	second_world.add_character(second)

	var first_rng := RandomNumberGenerator.new()
	first_rng.seed = 999
	var second_rng := RandomNumberGenerator.new()
	second_rng.seed = 999
	var first_system = planning_script.new()
	var second_system = planning_script.new()

	first_system.advance(first_world, 12.0 * 3600.0, first_rng)
	second_system.advance(second_world, 12.0 * 3600.0, second_rng)

	if _goal_ids(first.goals.active_goals()) != _goal_ids(second.goals.active_goals()):
		failures.append("same world seed/resident/day must generate same daily goals")

func _resident_with_job(
	character_script,
	job_definition_script,
	id: StringName
):
	var resident = character_script.new(id, str(id))
	resident.personality.ambition = 0.7
	resident.personality.impulsiveness = 0.4
	var job = job_definition_script.new()
	job.id = StringName("job_%s" % id)
	job.pay_per_sim_hour = 15.0
	job.shift_start_hour = 8.0
	job.shift_duration_hours = 8.0
	resident.job.assign(job)
	return resident

func _goal_ids(goals: Array) -> Array[String]:
	var ids: Array[String] = []
	for goal in goals:
		ids.append(str(goal.definition.id))
	return ids

func _has_category(goals: Array, category: StringName) -> bool:
	for goal in goals:
		if goal.definition.category == category:
			return true
	return false
