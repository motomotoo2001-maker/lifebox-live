class_name ReplayPlayer
extends RefCounted

static func replay(
	world: SimulationWorld,
	initial_snapshot: Dictionary,
	events: Array
) -> Array[String]:
	var errors := _validate_events(events)
	if world == null:
		errors.append("replay destination world is required")
	if initial_snapshot.is_empty():
		errors.append("replay initial snapshot is required")

	if not errors.is_empty():
		return errors

	var restore_errors := WorldSnapshotCodec.restore(world, initial_snapshot)
	if not restore_errors.is_empty():
		for restore_error in restore_errors:
			errors.append("initial snapshot: %s" % restore_error)
		return errors

	for raw_event in events:
		var event: ReplayEvent = raw_event
		match event.kind:
			&"advance":
				world.step(float(event.payload["real_delta"]))
			&"movement_arrived":
				if not world.report_arrival(
					StringName(event.payload["character_id"]),
					StringName(event.payload["target_object_id"])
				):
					errors.append(
						"replay movement_arrived rejected at sequence %d"
						% event.sequence
					)
					return errors
			&"movement_failed":
				if not world.report_movement_failure(
					StringName(event.payload["character_id"]),
					StringName(event.payload["target_object_id"])
				):
					errors.append(
						"replay movement_failed rejected at sequence %d"
						% event.sequence
					)
					return errors
			&"player_action":
				if not world.request_smart_object_action(
					StringName(event.payload["character_id"]),
					StringName(event.payload["target_object_id"]),
					StringName(event.payload["interaction_id"])
				):
					errors.append(
						"replay player_action rejected at sequence %d"
						% event.sequence
					)
					return errors

	return errors

static func _validate_events(events: Array) -> Array[String]:
	var errors: Array[String] = []

	if events.size() > ReplayLog.MAX_EVENTS:
		errors.append(
			"replay event count exceeds MAX_EVENTS (%d)"
			% ReplayLog.MAX_EVENTS
		)
		return errors

	for index in range(events.size()):
		var raw_event = events[index]
		if not raw_event is ReplayEvent:
			errors.append("replay event[%d] must be ReplayEvent" % index)
			continue

		var event: ReplayEvent = raw_event
		var expected_sequence := index + 1
		if event.sequence != expected_sequence:
			errors.append(
				"replay event[%d] sequence must be %d"
				% [index, expected_sequence]
			)

		var input_errors := ReplayLog.validate_input(event.kind, event.payload)
		for input_error in input_errors:
			errors.append(
				"replay event[%d]: %s"
				% [index, input_error]
			)

	return errors
