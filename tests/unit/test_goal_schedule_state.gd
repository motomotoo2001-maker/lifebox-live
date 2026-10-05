extends RefCounted

const DAILY_GOAL_PATH := "res://scripts/simulation/goals/daily_goal.gd"
const GOAL_STATE_PATH := "res://scripts/simulation/goals/goal_state.gd"
const GOAL_SYSTEM_PATH := "res://scripts/simulation/goals/goal_system.gd"
const SCHEDULE_STATE_PATH := "res://scripts/simulation/schedule/schedule_state.gd"
const CHARACTER_PATH := "res://scripts/simulation/characters/character_state.gd"
const JOB_DEFINITION_PATH := "res://scripts/simulation/economy/job_definition.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	for path in [DAILY_GOAL_PATH, GOAL_STATE_PATH, GOAL_SYSTEM_PATH, SCHEDULE_STATE_PATH]:
		if not FileAccess.file_exists(path):
			failures.append("goal/schedule dependency must exist at %s" % path)
			return failures

	var daily_goal_script := load(DAILY_GOAL_PATH)
	var goal_state_script := load(GOAL_STATE_PATH)
	var goal_system_script := load(GOAL_SYSTEM_PATH)
	var character_script := load(CHARACTER_PATH)
	var job_definition_script := load(JOB_DEFINITION_PATH)
	if (
		daily_goal_script == null
		or goal_state_script == null
		or goal_system_script == null
		or character_script == null
		or job_definition_script == null
	):
		failures.append("goal/schedule dependencies must load")
		return failures

	var bounded = daily_goal_script.new(&"bounded", &"self_care", 2.0, 10.0, 20.0, 3)
	if not is_equal_approx(bounded.priority, 1.0):
		failures.append("DailyGoal priority must clamp to 1")
	if not is_equal_approx(bounded.target_value, 10.0):
		failures.append("DailyGoal must preserve positive target")
	if not is_equal_approx(bounded.progress, 10.0):
		failures.append("DailyGoal progress must clamp to target")
	bounded.set_progress(NAN)
	if is_nan(bounded.progress):
		failures.append("DailyGoal progress must remain finite")

	var state = goal_state_script.new()
	if state.add_goal(null):
		failures.append("GoalState must reject null goal")

	for index in range(3):
		var goal = daily_goal_script.new(
			StringName("goal_%d" % index),
			&"test",
			0.5,
			1.0,
			0.0,
			1
		)
		if not state.add_goal(goal):
			failures.append("GoalState must accept unique goal %d within capacity" % index)

	if state.active_goals().size() != 3:
		failures.append("GoalState must contain exactly three goals at capacity")

	var duplicate = daily_goal_script.new(&"goal_1", &"test", 0.5, 1.0, 0.0, 1)
	if state.add_goal(duplicate):
		failures.append("GoalState must reject duplicate goal id")

	var overflow = daily_goal_script.new(&"goal_4", &"test", 0.5, 1.0, 0.0, 1)
	if state.add_goal(overflow):
		failures.append("GoalState must reject more than three active daily goals")

	var exposed: Array = state.active_goals()
	exposed.clear()
	if state.active_goals().size() != 3:
		failures.append("active_goals() must not expose mutable internal storage")

	var first = _build_character(character_script, job_definition_script)
	var second = _build_character(character_script, job_definition_script)
	var first_rng := RandomNumberGenerator.new()
	var second_rng := RandomNumberGenerator.new()
	first_rng.seed = 777
	second_rng.seed = 777

	var first_system = goal_system_script.new()
	var second_system = goal_system_script.new()
	first_system.refresh_daily(first, 5, first_rng)
	second_system.refresh_daily(second, 5, second_rng)

	var first_signature := _goal_signature(first.goals.active_goals())
	var second_signature := _goal_signature(second.goals.active_goals())
	if first_signature != second_signature:
		failures.append("same seed/personality/day must generate identical daily goals")
	if first.goals.active_goals().size() != 3:
		failures.append("daily refresh must generate exactly three goals")
	if not _has_category(first.goals.active_goals(), &"work"):
		failures.append("assigned job must generate a work daily goal")

	first_system.refresh_schedule(first, 10.0 * 3600.0)
	if first.schedule.planned_mode != &"work":
		failures.append("resident inside job shift must schedule work")

	first_system.refresh_schedule(first, 23.0 * 3600.0)
	if first.schedule.planned_mode != &"sleep":
		failures.append("resident at 23:00 must schedule sleep")

	first.needs.social.value = 10.0
	first.personality.sociability = 1.0
	first_system.refresh_schedule(first, 18.0 * 3600.0)
	if first.schedule.planned_mode != &"social":
		failures.append("socially deprived sociable resident in free time must schedule social")

	first.needs.social.value = 90.0
	first_system.refresh_schedule(first, 18.0 * 3600.0)
	if first.schedule.planned_mode != &"free":
		failures.append("satisfied resident outside work/sleep must schedule free")

	if first.goals == null or first.schedule == null:
		failures.append("CharacterState must own goals and schedule state")

	return failures

func _build_character(character_script, job_definition_script):
	var resident = character_script.new(&"planner", "Planner")
	resident.personality.ambition = 0.8
	resident.personality.sociability = 0.7
	resident.needs.hunger.value = 45.0
	resident.needs.energy.value = 60.0
	resident.needs.hygiene.value = 70.0
	resident.needs.social.value = 35.0

	var job = job_definition_script.new()
	job.id = &"planner_job"
	job.pay_per_sim_hour = 20.0
	job.shift_start_hour = 9.0
	job.shift_duration_hours = 8.0
	resident.job.assign(job)
	return resident

func _goal_signature(goals: Array) -> String:
	var parts: Array[String] = []
	for goal in goals:
		parts.append("%s:%s:%.4f" % [goal.id, goal.category, goal.priority])
	return "|".join(parts)

func _has_category(goals: Array, category: StringName) -> bool:
	for goal in goals:
		if goal.category == category:
			return true
	return false
