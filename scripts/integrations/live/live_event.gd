class_name LiveEvent
extends RefCounted

const KIND_GIFT: StringName = &"gift"
const KIND_LIKE_BATCH: StringName = &"like_batch"
const KIND_COMMENT: StringName = &"comment"
const KIND_FOLLOW: StringName = &"follow"
const KIND_SHARE: StringName = &"share"
const SUPPORTED_KINDS: Array[StringName] = [
	KIND_GIFT,
	KIND_LIKE_BATCH,
	KIND_COMMENT,
	KIND_FOLLOW,
	KIND_SHARE,
]

var event_id: StringName = &""
var kind: StringName = &""
var occurred_at_sim_seconds: float = 0.0
var viewer_key: String = ""
var payload: Dictionary = {}

func _init(
	new_event_id: StringName = &"",
	new_kind: StringName = &"",
	new_occurred_at_sim_seconds: float = 0.0,
	new_viewer_key: String = "",
	new_payload: Dictionary = {}
) -> void:
	event_id = new_event_id
	kind = new_kind
	occurred_at_sim_seconds = new_occurred_at_sim_seconds
	viewer_key = new_viewer_key
	payload = new_payload.duplicate(true)

func validate() -> Array[String]:
	var errors: Array[String] = []

	if event_id == &"":
		errors.append("event_id must be non-empty")
	if kind not in SUPPORTED_KINDS:
		errors.append("kind is unsupported: %s" % kind)
	if (
		is_nan(occurred_at_sim_seconds)
		or is_inf(occurred_at_sim_seconds)
		or occurred_at_sim_seconds < 0.0
	):
		errors.append("occurred_at_sim_seconds must be finite and non-negative")
	if not _is_persistence_safe(payload):
		errors.append("payload must be persistence-safe")
		return errors

	match kind:
		KIND_GIFT:
			_validate_gift(errors)
		KIND_LIKE_BATCH:
			_validate_like_batch(errors)
		KIND_COMMENT:
			_validate_comment(errors)

	return errors

func encode() -> Dictionary:
	return {
		"event_id": str(event_id),
		"kind": str(kind),
		"occurred_at_sim_seconds": occurred_at_sim_seconds,
		"viewer_key": viewer_key,
		"payload": payload.duplicate(true),
	}

static func decode(data: Dictionary) -> LiveEvent:
	for key in [
		"event_id",
		"kind",
		"occurred_at_sim_seconds",
		"viewer_key",
		"payload",
	]:
		if not data.has(key):
			return null

	if not data["event_id"] is String:
		return null
	if not data["kind"] is String:
		return null
	if not (
		data["occurred_at_sim_seconds"] is int
		or data["occurred_at_sim_seconds"] is float
	):
		return null
	if not data["viewer_key"] is String:
		return null
	if not data["payload"] is Dictionary:
		return null

	var event := LiveEvent.new(
		StringName(data["event_id"]),
		StringName(data["kind"]),
		float(data["occurred_at_sim_seconds"]),
		data["viewer_key"],
		data["payload"]
	)
	if not event.validate().is_empty():
		return null
	return event

func _validate_gift(errors: Array[String]) -> void:
	if (
		not payload.has("gift_name")
		or not payload["gift_name"] is String
		or payload["gift_name"].strip_edges().is_empty()
	):
		errors.append("gift_name must be a non-empty string")

	if (
		not payload.has("gift_value")
		or not payload["gift_value"] is int
		or int(payload["gift_value"]) < 0
	):
		errors.append("gift_value must be an integer >= 0")

	if (
		not payload.has("repeat_count")
		or not payload["repeat_count"] is int
		or int(payload["repeat_count"]) < 1
	):
		errors.append("repeat_count must be an integer >= 1")

func _validate_like_batch(errors: Array[String]) -> void:
	if (
		not payload.has("count")
		or not payload["count"] is int
		or int(payload["count"]) < 1
	):
		errors.append("like_batch count must be an integer >= 1")

func _validate_comment(errors: Array[String]) -> void:
	if (
		not payload.has("text")
		or not payload["text"] is String
		or payload["text"].strip_edges().is_empty()
	):
		errors.append("comment text must be a non-empty string")

static func _is_persistence_safe(value) -> bool:
	if value == null or value is bool or value is int or value is String:
		return true
	if value is float:
		return not is_nan(value) and not is_inf(value)
	if value is Array:
		for item in value:
			if not _is_persistence_safe(item):
				return false
		return true
	if value is Dictionary:
		for key in value.keys():
			if not key is String:
				return false
			if not _is_persistence_safe(value[key]):
				return false
		return true
	return false
