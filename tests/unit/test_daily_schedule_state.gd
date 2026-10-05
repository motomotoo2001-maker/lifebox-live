extends RefCounted

const STATE_PATH := "res://scripts/simulation/schedules/daily_schedule_state.gd"
const SYSTEM_PATH := "res://scripts/simulation/schedules/daily_schedule_system.gd"
const BLOCK_PATH := "res://scripts/simulation/schedules/schedule_block.gd"
const DEFINITION_PATH := "res://scripts/simulation/schedules/schedule_definition.gd"
const CHARACTER_PATH := "res://scripts/simulation/characters/character_state.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	for path in [STATE_PATH, SYSTEM_PATH]:
		if not FileAccess.file_exists(path):
			failures.append("daily schedule dependency must exist at %s" % path)
			return failures

	var state_script = load(STATE_PATH)
	var system_script = load(SYSTEM_PATH)
	var block_script = load(BLOCK_PATH)
	var definition_script = load(DEFINITION_PATH)
	var character_script = load(CHARACTER_PATH)
	for script in [state_script, system_script, block_script, definition_script, character_script]:
		if script == null or not script.can_instantiate():
			failures.append("daily schedule dependencies must load and instantiate")
			return failures

	var definition = definition_script.new()
	definition.blocks.append(_block(block_script, &"sleep", &"sleep", 22.0, 8.0))
	definition.blocks.append(_block(block_script, &"morning", &"free_time", 6.0, 2.0))
	definition.blocks.append(_block(block_script, &"work", &"work", 8.0, 8.0))
	if not definition.validate().is_empty():
		failures.append("daily schedule fixture must be valid")
		return failures

	var character = character_script.new(&"resident_schedule", "Schedule Resident")
	character.schedule.definition = definition
	var system = system_script.new()

	system.advance(character, 0.0)
	if character.schedule.day_index != 0:
		failures.append("time zero must be day 0")
	if character.schedule.active_block_id != &"sleep":
		failures.append("00:00 must resolve crossing sleep block")

	system.advance(character, 6.0 * 3600.0)
	if character.schedule.day_index != 0:
		failures.append("06:00 must remain day 0")
	if character.schedule.active_block_id != &"morning":
		failures.append("06:00 must switch to morning block")

	var same_day: int = character.schedule.day_index
	var same_block: StringName = character.schedule.active_block_id
	system.advance(character, 6.0 * 3600.0)
	if character.schedule.day_index != same_day or character.schedule.active_block_id != same_block:
		failures.append("repeating the same timestamp must be idempotent")

	system.advance(character, 24.0 * 3600.0)
	if character.schedule.day_index != 1:
		failures.append("24:00 must roll to day 1")
	if character.schedule.active_block_id != &"sleep":
		failures.append("day rollover at 00:00 must resolve sleep block")

	system.advance(character, 24.0 * 3600.0 + 12.0 * 3600.0)
	if character.schedule.day_index != 1:
		failures.append("day 1 midday must keep day index 1")
	if character.schedule.active_block_id != &"work":
		failures.append("day 1 12:00 must resolve work block")

	system.advance(character, 24.0 * 3600.0 + 20.0 * 3600.0)
	if character.schedule.active_block_id != &"":
		failures.append("hour outside every block must clear active block id")

	var before_day: int = character.schedule.day_index
	var before_block: StringName = character.schedule.active_block_id
	system.advance(character, -1.0)
	system.advance(character, NAN)
	system.advance(character, INF)
	if character.schedule.day_index != before_day or character.schedule.active_block_id != before_block:
		failures.append("invalid simulation timestamps must not mutate schedule state")

	var no_definition = character_script.new(&"no_schedule", "No Schedule")
	system.advance(no_definition, 3600.0)
	if no_definition.schedule.day_index != 0:
		failures.append("resident without definition must still track day index")
	if no_definition.schedule.active_block_id != &"":
		failures.append("resident without definition must have no active block")

	return failures

func _block(
	block_script,
	id: StringName,
	kind: StringName,
	start: float,
	duration: float
):
	var block = block_script.new()
	block.id = id
	block.kind = kind
	block.start_hour = start
	block.duration_hours = duration
	return block
