class_name MemoryStore
extends RefCounted

var capacity: int

var _events_by_id: Dictionary = {}
var _events: Array[MemoryEvent] = []

func _init(max_capacity: int = 64) -> void:
	capacity = maxi(max_capacity, 1)

func add(event: MemoryEvent) -> bool:
	if event == null or event.event_id == &"":
		return false
	if _events_by_id.has(event.event_id):
		return false

	_events_by_id[event.event_id] = event
	_events.append(event)

	while _events.size() > capacity:
		_evict_one()

	return true

func get_event(event_id: StringName) -> MemoryEvent:
	if not _events_by_id.has(event_id):
		return null
	return _events_by_id[event_id] as MemoryEvent

func size() -> int:
	return _events.size()

func events() -> Array[MemoryEvent]:
	return _events.duplicate()

func _evict_one() -> void:
	if _events.is_empty():
		return

	var candidate_index := 0
	for index in range(1, _events.size()):
		var current: MemoryEvent = _events[index]
		var candidate: MemoryEvent = _events[candidate_index]

		if current.importance < candidate.importance:
			candidate_index = index
		elif is_equal_approx(current.importance, candidate.importance):
			if current.simulation_seconds < candidate.simulation_seconds:
				candidate_index = index

	var removed: MemoryEvent = _events[candidate_index]
	_events.remove_at(candidate_index)
	_events_by_id.erase(removed.event_id)
