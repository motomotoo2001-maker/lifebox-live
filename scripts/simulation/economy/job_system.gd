class_name JobSystem
extends RefCounted

const DAY_SECONDS := 86400.0

func assign_job(character: CharacterState, definition: JobDefinition) -> bool:
	if character == null or character.job == null:
		return false
	if not _is_valid_definition(definition):
		return false

	character.job.assign(definition)
	return true

func advance_character(
	character: CharacterState,
	sim_delta_seconds: float,
	simulation_seconds: float,
	economy: EconomySystem
) -> float:
	if character == null or character.job == null or economy == null:
		return 0.0
	if character.job.definition == null:
		return 0.0
	if not _is_valid_definition(character.job.definition):
		return 0.0
	if not _is_finite_positive(sim_delta_seconds):
		return 0.0
	if is_nan(simulation_seconds) or is_inf(simulation_seconds) or simulation_seconds < 0.0:
		return 0.0

	var interval_end := simulation_seconds
	var interval_start := maxf(interval_end - sim_delta_seconds, 0.0)
	if interval_end <= interval_start:
		return 0.0

	var worked_seconds := _calculate_overlap(
		interval_start,
		interval_end,
		character.job.definition
	)
	if worked_seconds <= 0.0:
		return 0.0

	var earned := (
		worked_seconds / 3600.0
		* character.job.definition.pay_per_sim_hour
	)
	if earned <= 0.0 or is_nan(earned) or is_inf(earned):
		return 0.0

	var transaction := economy.deposit(character, earned, simulation_seconds)
	if transaction == null:
		return 0.0

	character.job.total_worked_sim_seconds += worked_seconds
	return earned

func _calculate_overlap(
	interval_start: float,
	interval_end: float,
	definition: JobDefinition
) -> float:
	var shift_start_seconds := definition.shift_start_hour * 3600.0
	var shift_duration_seconds := definition.shift_duration_hours * 3600.0
	var start_day := int(floor(interval_start / DAY_SECONDS)) - 1
	var end_day := int(floor(interval_end / DAY_SECONDS)) + 1
	var total_overlap := 0.0

	for day_index in range(start_day, end_day + 1):
		var shift_start := float(day_index) * DAY_SECONDS + shift_start_seconds
		var shift_end := shift_start + shift_duration_seconds
		var overlap_start := maxf(interval_start, shift_start)
		var overlap_end := minf(interval_end, shift_end)
		if overlap_end > overlap_start:
			total_overlap += overlap_end - overlap_start

	return total_overlap

func _is_valid_definition(definition: JobDefinition) -> bool:
	if definition == null or definition.id == &"":
		return false
	if not _is_finite_positive(definition.pay_per_sim_hour):
		return false
	if (
		is_nan(definition.shift_start_hour)
		or is_inf(definition.shift_start_hour)
		or definition.shift_start_hour < 0.0
		or definition.shift_start_hour >= 24.0
	):
		return false
	if (
		is_nan(definition.shift_duration_hours)
		or is_inf(definition.shift_duration_hours)
		or definition.shift_duration_hours <= 0.0
		or definition.shift_duration_hours > 24.0
	):
		return false
	return true

func _is_finite_positive(value: float) -> bool:
	return not is_nan(value) and not is_inf(value) and value > 0.0
