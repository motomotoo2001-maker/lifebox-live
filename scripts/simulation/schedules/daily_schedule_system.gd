class_name DailyScheduleSystem
extends RefCounted

const DAY_SECONDS := 86400.0
const HOUR_SECONDS := 3600.0

func advance(character: CharacterState, simulation_seconds: float) -> void:
	if character == null or character.schedule == null:
		return
	if is_nan(simulation_seconds) or is_inf(simulation_seconds) or simulation_seconds < 0.0:
		return

	character.schedule.day_index = int(floor(simulation_seconds / DAY_SECONDS))

	if character.schedule.definition == null:
		character.schedule.active_block_id = &""
		return

	if not character.schedule.definition.validate().is_empty():
		character.schedule.active_block_id = &""
		return

	var day_seconds: float = fmod(simulation_seconds, DAY_SECONDS)
	var hour: float = day_seconds / HOUR_SECONDS
	var active_block: ScheduleBlock = character.schedule.definition.active_block_at(hour)
	character.schedule.active_block_id = active_block.id if active_block != null else &""
