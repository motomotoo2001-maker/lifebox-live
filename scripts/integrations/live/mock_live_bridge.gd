class_name MockLiveBridge
extends RefCounted

const DEFAULT_PREFIX := "mock"

var prefix: String = DEFAULT_PREFIX
var sequence: int = 0

func _init(new_prefix: String = DEFAULT_PREFIX) -> void:
	var normalized := new_prefix.strip_edges()
	prefix = normalized if not normalized.is_empty() else DEFAULT_PREFIX

func gift(
	simulation_seconds: float,
	viewer_key: String,
	gift_name: String,
	gift_value: int,
	repeat_count: int = 1
) -> LiveEvent:
	return _build(
		LiveEvent.KIND_GIFT,
		simulation_seconds,
		viewer_key,
		{
			"gift_name": gift_name,
			"gift_value": gift_value,
			"repeat_count": repeat_count,
		}
	)

func like_batch(
	simulation_seconds: float,
	viewer_key: String,
	count: int
) -> LiveEvent:
	return _build(
		LiveEvent.KIND_LIKE_BATCH,
		simulation_seconds,
		viewer_key,
		{"count": count}
	)

func comment(
	simulation_seconds: float,
	viewer_key: String,
	text: String
) -> LiveEvent:
	return _build(
		LiveEvent.KIND_COMMENT,
		simulation_seconds,
		viewer_key,
		{"text": text}
	)

func follow(
	simulation_seconds: float,
	viewer_key: String
) -> LiveEvent:
	return _build(
		LiveEvent.KIND_FOLLOW,
		simulation_seconds,
		viewer_key,
		{}
	)

func share(
	simulation_seconds: float,
	viewer_key: String
) -> LiveEvent:
	return _build(
		LiveEvent.KIND_SHARE,
		simulation_seconds,
		viewer_key,
		{}
	)

func capture_state() -> Dictionary:
	return {
		"prefix": prefix,
		"sequence": sequence,
	}

func restore_state(data: Dictionary) -> bool:
	if (
		not data.has("prefix")
		or not data["prefix"] is String
		or data["prefix"].strip_edges().is_empty()
	):
		return false
	if (
		not data.has("sequence")
		or not data["sequence"] is int
		or int(data["sequence"]) < 0
	):
		return false

	prefix = data["prefix"].strip_edges()
	sequence = int(data["sequence"])
	return true

func _build(
	kind: StringName,
	simulation_seconds: float,
	viewer_key: String,
	payload: Dictionary
) -> LiveEvent:
	var next_sequence := sequence + 1
	var event_id := StringName(
		"%s_%s_%06d" % [prefix, kind, next_sequence]
	)
	var event := LiveEvent.new(
		event_id,
		kind,
		simulation_seconds,
		viewer_key,
		payload
	)
	if not event.validate().is_empty():
		return null

	sequence = next_sequence
	return event
