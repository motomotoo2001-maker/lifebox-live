class_name ScheduleDefinition
extends Resource

@export var blocks: Array[ScheduleBlock] = []

func validate() -> Array[String]:
	var errors: Array[String] = []
	var seen_ids: Dictionary = {}

	for index in range(blocks.size()):
		var block: ScheduleBlock = blocks[index]
		if block == null:
			errors.append("schedule block[%d] must not be null" % index)
			continue

		if block.id == &"":
			errors.append("schedule block[%d] id must not be empty" % index)
		elif seen_ids.has(block.id):
			errors.append("duplicate schedule block id: %s" % block.id)
		else:
			seen_ids[block.id] = true

		if block.kind == &"":
			errors.append("schedule block %s kind must not be empty" % block.id)

		if not _is_finite(block.start_hour):
			errors.append("schedule block %s start_hour must be finite" % block.id)
		elif block.start_hour < 0.0 or block.start_hour >= 24.0:
			errors.append("schedule block %s start_hour must be inside 0..<24" % block.id)

		if not _is_finite(block.duration_hours):
			errors.append("schedule block %s duration_hours must be finite" % block.id)
		elif block.duration_hours <= 0.0 or block.duration_hours > 24.0:
			errors.append("schedule block %s duration_hours must be inside 0<..24" % block.id)

	for first_index in range(blocks.size()):
		var first: ScheduleBlock = blocks[first_index]
		if not _has_valid_time(first):
			continue
		for second_index in range(first_index + 1, blocks.size()):
			var second: ScheduleBlock = blocks[second_index]
			if not _has_valid_time(second):
				continue
			if _blocks_overlap(first, second):
				errors.append(
					"schedule blocks overlap: %s / %s"
					% [first.id, second.id]
				)

	return errors

func active_block_at(hour: float) -> ScheduleBlock:
	if not _is_finite(hour) or hour < 0.0 or hour >= 24.0:
		return null

	for block in blocks:
		if not _has_valid_time(block):
			continue
		if _contains_hour(block, hour):
			return block

	return null

func _blocks_overlap(first: ScheduleBlock, second: ScheduleBlock) -> bool:
	var first_segments: Array[Vector2] = _segments(first)
	var second_segments: Array[Vector2] = _segments(second)

	for first_segment in first_segments:
		for second_segment in second_segments:
			var start: float = maxf(first_segment.x, second_segment.x)
			var end: float = minf(first_segment.y, second_segment.y)
			if start < end:
				return true

	return false

func _segments(block: ScheduleBlock) -> Array[Vector2]:
	if block.duration_hours >= 24.0:
		return [Vector2(0.0, 24.0)]

	var end_hour: float = block.start_hour + block.duration_hours
	if end_hour <= 24.0:
		return [Vector2(block.start_hour, end_hour)]

	return [
		Vector2(block.start_hour, 24.0),
		Vector2(0.0, end_hour - 24.0),
	]

func _contains_hour(block: ScheduleBlock, hour: float) -> bool:
	if block.duration_hours >= 24.0:
		return true

	var end_hour: float = block.start_hour + block.duration_hours
	if end_hour <= 24.0:
		return hour >= block.start_hour and hour < end_hour

	return hour >= block.start_hour or hour < (end_hour - 24.0)

func _has_valid_time(block: ScheduleBlock) -> bool:
	if block == null:
		return false
	if not _is_finite(block.start_hour) or not _is_finite(block.duration_hours):
		return false
	if block.start_hour < 0.0 or block.start_hour >= 24.0:
		return false
	return block.duration_hours > 0.0 and block.duration_hours <= 24.0

func _is_finite(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)
