class_name ReplayLog
extends RefCounted

const MAX_EVENTS := 4096

var _events: Array[ReplayEvent] = []

func append(kind: StringName, payload: Dictionary) -> bool:
	if _events.size() >= MAX_EVENTS:
		return false
	if not validate_input(kind, payload).is_empty():
		return false

	var next_sequence := _events.size() + 1
	_events.append(ReplayEvent.new(next_sequence, kind, payload))
	return true

func events() -> Array[ReplayEvent]:
	return _events.duplicate()

static func validate_input(
	kind: StringName,
	payload: Dictionary
) -> Array[String]:
	var errors: Array[String] = []

	match kind:
		&"advance":
			if not payload.has("real_delta"):
				errors.append("advance real_delta is required")
			elif not _is_finite_number(payload["real_delta"]):
				errors.append("advance real_delta must be finite")
			elif float(payload["real_delta"]) < 0.0:
				errors.append("advance real_delta must be non-negative")
		&"movement_arrived", &"movement_failed":
			for key in ["character_id", "target_object_id"]:
				if not payload.has(key):
					errors.append("%s %s is required" % [kind, key])
				elif not payload[key] is String:
					errors.append("%s %s must be a string" % [kind, key])
				elif payload[key].is_empty():
					errors.append("%s %s must be non-empty" % [kind, key])
		_:
			errors.append("unknown replay event kind: %s" % kind)

	return errors

static func _is_finite_number(value) -> bool:
	if not (value is int or value is float):
		return false
	var number := float(value)
	return not is_nan(number) and not is_inf(number)
