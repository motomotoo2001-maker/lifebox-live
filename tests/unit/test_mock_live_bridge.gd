extends RefCounted

const BRIDGE_PATH := "res://scripts/integrations/live/mock_live_bridge.gd"

func run() -> Array[String]:
	var failures: Array[String] = []
	if not FileAccess.file_exists(BRIDGE_PATH):
		failures.append("MockLiveBridge must exist")
		return failures

	var bridge_script = load(BRIDGE_PATH)
	if bridge_script == null or not bridge_script.can_instantiate():
		failures.append("MockLiveBridge must load")
		return failures

	var bridge = bridge_script.new("mock")
	var gift = bridge.gift(1.0, "viewer_a", "Rose", 5, 2)
	var likes = bridge.like_batch(2.0, "viewer_b", 100)
	var comment = bridge.comment(3.0, "viewer_c", "!A")
	var follow = bridge.follow(4.0, "viewer_d")
	var share = bridge.share(5.0, "viewer_e")
	var events = [gift, likes, comment, follow, share]

	for event in events:
		if event == null or not event.validate().is_empty():
			failures.append("mock helper must emit valid normalized event")
			return failures

	var expected_ids: Array[StringName] = [
		&"mock_gift_000001",
		&"mock_like_batch_000002",
		&"mock_comment_000003",
		&"mock_follow_000004",
		&"mock_share_000005",
	]
	for index in range(events.size()):
		if events[index].event_id != expected_ids[index]:
			failures.append(
				"mock event IDs must be deterministic and sequential"
			)

	if gift.payload["gift_value"] != 5 or gift.payload["repeat_count"] != 2:
		failures.append("gift helper must preserve normalized gift payload")
	if likes.payload["count"] != 100:
		failures.append("like helper must preserve count")
	if comment.payload["text"] != "!A":
		failures.append("comment helper must preserve text")

	var before_invalid: Dictionary = bridge.capture_state()
	if bridge.gift(6.0, "viewer", "", 1, 1) != null:
		failures.append("invalid mock payload must return null")
	if bridge.capture_state() != before_invalid:
		failures.append("invalid mock event must not consume sequence")

	var state: Dictionary = bridge.capture_state()
	var restored = bridge_script.new()
	if not restored.restore_state(state):
		failures.append("valid mock bridge state must restore")
		return failures
	if restored.capture_state() != state:
		failures.append("mock bridge state must round-trip exactly")

	var next = restored.comment(7.0, "viewer_z", "hello")
	if next == null or next.event_id != &"mock_comment_000006":
		failures.append(
			"restored bridge must continue deterministic sequence"
		)

	return failures
