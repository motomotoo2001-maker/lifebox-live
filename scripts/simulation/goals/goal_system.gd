class_name GoalSystem
extends RefCounted

const DAY_SECONDS := 86400.0

func refresh_daily(
	character: CharacterState,
	day_index: int,
	rng: RandomNumberGenerator
) -> void:
	if character == null or character.goals == null or rng == null:
		return

	var safe_day := maxi(day_index, 0)
	character.goals.clear_for_day(safe_day)

	if character.job != null and character.job.definition != null:
		var work_priority := _clamp_priority(
			0.55
			+ clampf(character.personality.ambition, 0.0, 1.0) * 0.35
			+ _jitter(rng)
		)
		character.goals.add_goal(DailyGoal.new(
			StringName("work_day_%d" % safe_day),
			&"work",
			work_priority,
			1.0,
			0.0,
			safe_day + 1
		))

	var social_urgency := (
		100.0 - clampf(character.needs.social.value, 0.0, 100.0)
	) / 100.0
	var social_priority := _clamp_priority(
		0.25
		+ social_urgency * 0.45
		+ clampf(character.personality.sociability, 0.0, 1.0) * 0.25
		+ _jitter(rng)
	)
	character.goals.add_goal(DailyGoal.new(
		StringName("social_day_%d" % safe_day),
		&"social",
		social_priority,
		1.0,
		0.0,
		safe_day + 1
	))

	var self_care_urgency := _self_care_urgency(character)
	var self_care_priority := _clamp_priority(
		0.30
		+ self_care_urgency * 0.50
		+ clampf(character.personality.neatness, 0.0, 1.0) * 0.15
		+ _jitter(rng)
	)
	character.goals.add_goal(DailyGoal.new(
		StringName("self_care_day_%d" % safe_day),
		&"self_care",
		self_care_priority,
		1.0,
		0.0,
		safe_day + 1
	))

	if character.goals.active_goals().size() < GoalState.MAX_ACTIVE_GOALS:
		var free_priority := _clamp_priority(0.2 + _jitter(rng))
		character.goals.add_goal(DailyGoal.new(
			StringName("wellbeing_day_%d" % safe_day),
			&"wellbeing",
			free_priority,
			1.0,
			0.0,
			safe_day + 1
		))

func refresh_schedule(
	character: CharacterState,
	simulation_seconds: float
) -> void:
	if character == null or character.schedule == null:
		return
	if is_nan(simulation_seconds) or is_inf(simulation_seconds) or simulation_seconds < 0.0:
		return

	var day_index := int(floor(simulation_seconds / DAY_SECONDS))
	var day_seconds := fmod(simulation_seconds, DAY_SECONDS)
	var hour := day_seconds / 3600.0

	if _is_inside_job_shift(character, hour):
		character.schedule.set_plan(
			day_index,
			ScheduleState.MODE_WORK,
			simulation_seconds + 3600.0
		)
		return

	if hour >= 22.0 or hour < 6.0:
		character.schedule.set_plan(
			day_index,
			ScheduleState.MODE_SLEEP,
			_next_six_am(simulation_seconds, day_index, hour)
		)
		return

	if (
		character.needs.social.value < 30.0
		and character.personality.sociability >= 0.5
	):
		character.schedule.set_plan(
			day_index,
			ScheduleState.MODE_SOCIAL,
			simulation_seconds + 3600.0
		)
		return

	character.schedule.set_plan(
		day_index,
		ScheduleState.MODE_FREE,
		simulation_seconds + 3600.0
	)

func _is_inside_job_shift(character: CharacterState, hour: float) -> bool:
	if character.job == null or character.job.definition == null:
		return false

	var definition = character.job.definition
	var start: float = float(definition.shift_start_hour)
	var duration: float = float(definition.shift_duration_hours)
	if (
		is_nan(start)
		or is_inf(start)
		or is_nan(duration)
		or is_inf(duration)
		or start < 0.0
		or start >= 24.0
		or duration <= 0.0
		or duration > 24.0
	):
		return false

	var end := fmod(start + duration, 24.0)
	if duration >= 24.0:
		return true
	if start + duration <= 24.0:
		return hour >= start and hour < start + duration
	return hour >= start or hour < end

func _next_six_am(
	simulation_seconds: float,
	day_index: int,
	hour: float
) -> float:
	if hour < 6.0:
		return float(day_index) * DAY_SECONDS + 6.0 * 3600.0
	return float(day_index + 1) * DAY_SECONDS + 6.0 * 3600.0

func _self_care_urgency(character: CharacterState) -> float:
	var highest := 0.0
	for need_name in ["hunger", "energy", "hygiene", "comfort"]:
		var need_state = character.needs.get(need_name)
		if need_state == null:
			continue
		var urgency := (
			100.0 - clampf(need_state.value, 0.0, 100.0)
		) / 100.0
		highest = maxf(highest, urgency)
	return highest

func _jitter(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(-0.03, 0.03)

func _clamp_priority(value: float) -> float:
	if is_nan(value) or is_inf(value):
		return 0.0
	return clampf(value, 0.0, 1.0)
