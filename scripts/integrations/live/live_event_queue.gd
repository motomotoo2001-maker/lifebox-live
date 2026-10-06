class_name LiveEventQueue
extends RefCounted

const RESULT_ACCEPTED: StringName = &"accepted"
const RESULT_DUPLICATE: StringName = &"duplicate"
const RESULT_INVALID: StringName = &"invalid"
const RESULT_FULL: StringName = &"full"
const DEFAULT_MAX_PENDING := 256

var max_pending: int = DEFAULT_MAX_PENDING
var _events: Array[LiveEvent] = []
var _pending_ids: Dictionary = {}

func _init(new_max_pending: int = DEFAULT_MAX_PENDING) -> void:
	max_pending = maxi(new_max_pending, 1)

func enqueue(
	event: LiveEvent,
	processed_ledger: EventIdLedger = null
) -> StringName:
	if event == null or not event.validate().is_empty():
		return RESULT_INVALID
	if _pending_ids.has(event.event_id):
		return RESULT_DUPLICATE
	if processed_ledger != null and processed_ledger.has(event.event_id):
		return RESULT_DUPLICATE
	if _events.size() >= max_pending:
		return RESULT_FULL

	_events.append(event)
	_pending_ids[event.event_id] = true
	return RESULT_ACCEPTED

func pop_front() -> LiveEvent:
	if _events.is_empty():
		return null
	var event: LiveEvent = _events.pop_front()
	_pending_ids.erase(event.event_id)
	return event

func peek_front() -> LiveEvent:
	if _events.is_empty():
		return null
	return _events[0]

func size() -> int:
	return _events.size()

func is_empty() -> bool:
	return _events.is_empty()

func clear() -> void:
	_events.clear()
	_pending_ids.clear()
