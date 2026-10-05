extends RefCounted

const BLOCK_PATH := "res://scripts/simulation/schedules/schedule_block.gd"
const DEFINITION_PATH := "res://scripts/simulation/schedules/schedule_definition.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	if not FileAccess.file_exists(BLOCK_PATH):
		failures.append("ScheduleBlock must exist at %s" % BLOCK_PATH)
		return failures
	if not FileAccess.file_exists(DEFINITION_PATH):
		failures.append("ScheduleDefinition must exist at %s" % DEFINITION_PATH)
		return failures

	var block_script = load(BLOCK_PATH)
	var definition_script = load(DEFINITION_PATH)
	if block_script == null or definition_script == null:
		failures.append("schedule definition dependencies must load")
		return failures
	if not block_script.can_instantiate() or not definition_script.can_instantiate():
		failures.append("schedule definition dependencies must be instantiable")
		return failures

	_test_valid_schedule(failures, block_script, definition_script)
	_test_overlap_rejected(failures, block_script, definition_script)
	_test_midnight_crossing(failures, block_script, definition_script)
	_test_invalid_values(failures, block_script, definition_script)
	return failures

func _block(block_script, id: StringName, kind: StringName, start: float, duration: float, tags: Array[StringName] = []):
	var block = block_script.new()
	block.id = id
	block.kind = kind
	block.start_hour = start
	block.duration_hours = duration
	block.preferred_action_tags = tags.duplicate()
	return block

func _append_all(definition, values: Array) -> void:
	for value in values:
		definition.blocks.append(value)

func _test_valid_schedule(failures: Array[String], block_script, definition_script) -> void:
	var definition = definition_script.new()
	_append_all(definition, [
		_block(block_script, &"sleep", &"sleep", 0.0, 7.0, [&"sleep"]),
		_block(block_script, &"breakfast", &"meal", 7.0, 1.0, [&"eat"]),
		_block(block_script, &"work", &"work", 8.0, 8.0, [&"work"]),
		_block(block_script, &"free", &"free_time", 16.0, 8.0, [&"relax", &"social"]),
	])
	var errors: Array[String] = definition.validate()
	if not errors.is_empty():
		failures.append("valid non-overlapping schedule must pass: %s" % " | ".join(errors))
		return
	if definition.active_block_at(6.5).id != &"sleep":
		failures.append("06:30 must resolve to sleep")
	if definition.active_block_at(7.0).id != &"breakfast":
		failures.append("exact block boundary must resolve to block starting at boundary")
	if definition.active_block_at(12.0).id != &"work":
		failures.append("12:00 must resolve to work")
	if definition.active_block_at(20.0).id != &"free":
		failures.append("20:00 must resolve to free time")

func _test_overlap_rejected(failures: Array[String], block_script, definition_script) -> void:
	var definition = definition_script.new()
	_append_all(definition, [
		_block(block_script, &"a", &"free_time", 8.0, 4.0),
		_block(block_script, &"b", &"social", 11.5, 2.0),
	])
	var errors: Array[String] = definition.validate()
	if errors.is_empty():
		failures.append("overlapping schedule blocks must fail validation")
	elif "overlap" not in " | ".join(errors).to_lower():
		failures.append("overlap validation error must mention overlap")

func _test_midnight_crossing(failures: Array[String], block_script, definition_script) -> void:
	var definition = definition_script.new()
	_append_all(definition, [
		_block(block_script, &"night_sleep", &"sleep", 22.0, 8.0, [&"sleep"]),
		_block(block_script, &"morning", &"free_time", 6.0, 4.0, [&"relax"]),
	])
	var errors: Array[String] = definition.validate()
	if not errors.is_empty():
		failures.append("midnight-crossing block with touching morning boundary must be valid: %s" % " | ".join(errors))
		return
	if definition.active_block_at(23.0).id != &"night_sleep":
		failures.append("23:00 must resolve inside crossing sleep block")
	if definition.active_block_at(5.5).id != &"night_sleep":
		failures.append("05:30 must resolve inside crossing sleep block")
	if definition.active_block_at(6.0).id != &"morning":
		failures.append("06:00 must resolve to morning after crossing sleep ends")
	if definition.active_block_at(12.0) != null:
		failures.append("hour outside every block must return null")

func _test_invalid_values(failures: Array[String], block_script, definition_script) -> void:
	var cases := [
		_block(block_script, &"bad_start_low", &"sleep", -1.0, 1.0),
		_block(block_script, &"bad_start_high", &"sleep", 24.0, 1.0),
		_block(block_script, &"bad_duration_zero", &"sleep", 1.0, 0.0),
		_block(block_script, &"bad_duration_high", &"sleep", 1.0, 24.1),
		_block(block_script, &"bad_nan", &"sleep", NAN, 1.0),
	]
	for block in cases:
		var definition = definition_script.new()
		definition.blocks.append(block)
		if definition.validate().is_empty():
			failures.append("invalid schedule block %s must fail validation" % block.id)

	var duplicate = definition_script.new()
	_append_all(duplicate, [
		_block(block_script, &"same", &"sleep", 0.0, 1.0),
		_block(block_script, &"same", &"meal", 2.0, 1.0),
	])
	if duplicate.validate().is_empty():
		failures.append("duplicate schedule block ids must fail validation")
