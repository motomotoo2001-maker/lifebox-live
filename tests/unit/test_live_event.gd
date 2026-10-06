extends RefCounted

const LIVE_EVENT_PATH := "res://scripts/integrations/live/live_event.gd"

func run() -> Array[String]:
	var failures: Array[String] = []
	if not FileAccess.file_exists(LIVE_EVENT_PATH):
		failures.append("LiveEvent must exist")
		return failures

	var live_event_script = load(LIVE_EVENT_PATH)
	if live_event_script == null or not live_event_script.can_instantiate():
		failures.append("LiveEvent must load and instantiate")
		return failures

	_test_valid_events(failures, live_event_script)
	_test_invalid_events(failures, live_event_script)
	_test_roundtrip(failures, live_event_script)
	return failures

func _event(
	script,
	event_id: StringName,
	kind: StringName,
	time: float,
	viewer_key: String,
	payload: Dictionary
):
	return script.new(event_id, kind, time, viewer_key, payload)

func _test_valid_events(failures: Array[String], script) -> void:
	var cases = [
		_event(
			script,
			&"gift_1",
			&"gift",
			1.0,
			"viewer_a",
			{"gift_name": "Rose", "gift_value": 5, "repeat_count": 2}
		),
		_event(
			script,
			&"likes_1",
			&"like_batch",
			2.0,
			"viewer_a",
			{"count": 250}
		),
		_event(
			script,
			&"comment_1",
			&"comment",
			3.0,
			"viewer_b",
			{"text": "!A"}
		),
		_event(script, &"follow_1", &"follow", 4.0, "viewer_c", {}),
		_event(script, &"share_1", &"share", 5.0, "viewer_d", {}),
	]
	for event in cases:
		var errors: Array[String] = event.validate()
		if not errors.is_empty():
			failures.append(
				"valid %s event must pass: %s"
				% [event.kind, " | ".join(errors)]
			)

func _test_invalid_events(failures: Array[String], script) -> void:
	var invalid = [
		_event(
			script,
			&"",
			&"gift",
			1.0,
			"viewer",
			{"gift_name": "Rose", "gift_value": 1, "repeat_count": 1}
		),
		_event(script, &"x", &"unknown", 1.0, "viewer", {}),
		_event(
			script,
			&"x",
			&"gift",
			-1.0,
			"viewer",
			{"gift_name": "Rose", "gift_value": 1, "repeat_count": 1}
		),
		_event(
			script,
			&"x",
			&"gift",
			NAN,
			"viewer",
			{"gift_name": "Rose", "gift_value": 1, "repeat_count": 1}
		),
		_event(
			script,
			&"x",
			&"gift",
			1.0,
			"viewer",
			{"gift_name": "", "gift_value": 1, "repeat_count": 1}
		),
		_event(
			script,
			&"x",
			&"gift",
			1.0,
			"viewer",
			{"gift_name": "Rose", "gift_value": -1, "repeat_count": 1}
		),
		_event(
			script,
			&"x",
			&"gift",
			1.0,
			"viewer",
			{"gift_name": "Rose", "gift_value": 1, "repeat_count": 0}
		),
		_event(script, &"x", &"like_batch", 1.0, "viewer", {"count": 0}),
		_event(
			script,
			&"x",
			&"comment",
			1.0,
			"viewer",
			{"text": "   "}
		),
		_event(
			script,
			&"x",
			&"share",
			1.0,
			"viewer",
			{"bad": Vector3.ZERO}
		),
	]
	for event in invalid:
		if event.validate().is_empty():
			failures.append("invalid event must fail: %s" % event.kind)

func _test_roundtrip(failures: Array[String], script) -> void:
	var source = _event(
		script,
		&"gift_roundtrip",
		&"gift",
		12.5,
		"viewer_xyz",
		{
			"gift_name": "Star",
			"gift_value": 75,
			"repeat_count": 3,
			"meta": {"source": "mock"},
		}
	)
	var encoded: Dictionary = source.encode()
	var decoded = script.decode(encoded)
	if decoded == null:
		failures.append("valid encoded event must decode")
		return
	if decoded.encode() != encoded:
		failures.append("LiveEvent encode/decode must round-trip exactly")

	var malformed := encoded.duplicate(true)
	malformed["payload"]["gift_value"] = 1.5
	if script.decode(malformed) != null:
		failures.append("decode must reject malformed kind-specific payload")
