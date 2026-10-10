class_name EventIdLedger
extends RefCounted

const DEFAULT_CAPACITY := 1024

var capacity: int = DEFAULT_CAPACITY
var _ordered_ids: Array[StringName] = []
var _lookup: Dictionary = {}

func _init(new_capacity: int = DEFAULT_CAPACITY) -> void:
	capacity = maxi(new_capacity, 1)

func has(event_id: StringName) -> bool:
	if event_id == &"":
		return false
	return _lookup.has(event_id)

func record(event_id: StringName) -> bool:
	if event_id == &"" or has(event_id):
		return false

	while _ordered_ids.size() >= capacity:
		var evicted: StringName = _ordered_ids.pop_front()
		_lookup.erase(evicted)

	_ordered_ids.append(event_id)
	_lookup[event_id] = true
	return true

func size() -> int:
	return _ordered_ids.size()

func ids() -> Array[StringName]:
	return _ordered_ids.duplicate()

func clear() -> void:
	_ordered_ids.clear()
	_lookup.clear()

func capture_state() -> Dictionary:
	var encoded_ids: Array = []
	for event_id in _ordered_ids:
		encoded_ids.append(str(event_id))
	return {
		"capacity": capacity,
		"ids": encoded_ids,
	}

func restore_state(data: Dictionary) -> bool:
	if (
		not data.has("capacity")
		or not data["capacity"] is int
		or int(data["capacity"]) < 1
	):
		return false
	if not data.has("ids") or not data["ids"] is Array:
		return false

	var restored_capacity := int(data["capacity"])
	var raw_ids: Array = data["ids"]
	if raw_ids.size() > restored_capacity:
		return false

	var restored_ids: Array[StringName] = []
	var restored_lookup: Dictionary = {}
	for raw_id in raw_ids:
		if not raw_id is String or raw_id.is_empty():
			return false
		var event_id := StringName(raw_id)
		if restored_lookup.has(event_id):
			return false
		restored_ids.append(event_id)
		restored_lookup[event_id] = true

	capacity = restored_capacity
	_ordered_ids = restored_ids
	_lookup = restored_lookup
	return true
