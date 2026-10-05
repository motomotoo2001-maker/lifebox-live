class_name MemoryEvent
extends RefCounted

var event_id: StringName
var kind: StringName
var simulation_seconds: float
var related_resident_ids: Array[StringName] = []
var valence: float
var importance: float

func _init(
	new_event_id: StringName = &"",
	new_kind: StringName = &"",
	new_simulation_seconds: float = 0.0,
	new_related_resident_ids: Array = [],
	new_valence: float = 0.0,
	new_importance: float = 0.0
) -> void:
	event_id = new_event_id
	kind = new_kind
	simulation_seconds = _sanitize_time(new_simulation_seconds)
	valence = _sanitize_range(new_valence, -1.0, 1.0)
	importance = _sanitize_range(new_importance, 0.0, 1.0)

	for resident_id in new_related_resident_ids:
		var normalized := StringName(str(resident_id))
		if normalized == &"" or normalized in related_resident_ids:
			continue
		related_resident_ids.append(normalized)

func _sanitize_time(value: float) -> float:
	if is_nan(value) or is_inf(value):
		return 0.0
	return maxf(value, 0.0)

func _sanitize_range(value: float, minimum: float, maximum: float) -> float:
	if is_nan(value) or is_inf(value):
		return 0.0
	return clampf(value, minimum, maximum)
