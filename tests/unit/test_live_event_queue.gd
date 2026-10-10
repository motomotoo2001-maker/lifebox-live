extends RefCounted

const EVENT_PATH := "res://scripts/integrations/live/live_event.gd"
const LEDGER_PATH := "res://scripts/integrations/live/event_id_ledger.gd"
const QUEUE_PATH := "res://scripts/integrations/live/live_event_queue.gd"

func run() -> Array[String]:
	var failures: Array[String] = []
	for path in [EVENT_PATH, LEDGER_PATH, QUEUE_PATH]:
		if not FileAccess.file_exists(path):
			failures.append("missing live queue dependency: %s" % path)
			return failures

	var event_script = load(EVENT_PATH)
	var ledger_script = load(LEDGER_PATH)
	var queue_script = load(QUEUE_PATH)
	for script in [event_script, ledger_script, queue_script]:
		if script == null or not script.can_instantiate():
			failures.append("live queue dependencies must load")
			return failures

	_test_ledger(failures, ledger_script)
	_test_queue(failures, event_script, ledger_script, queue_script)
	return failures

func _test_ledger(failures: Array[String], ledger_script) -> void:
	var ledger = ledger_script.new(3)
	if (
		not ledger.record(&"a")
		or not ledger.record(&"b")
		or not ledger.record(&"c")
	):
		failures.append("ledger must accept unique IDs until capacity")
	if ledger.record(&"b"):
		failures.append("ledger must reject duplicate ID")
	if not ledger.record(&"d"):
		failures.append("ledger must accept new ID after eviction")
	if ledger.has(&"a"):
		failures.append("ledger must evict oldest ID first")
	for id in [&"b", &"c", &"d"]:
		if not ledger.has(id):
			failures.append("ledger must retain newest IDs")
	if ledger.size() != 3:
		failures.append("ledger size must stay bounded")

	var state: Dictionary = ledger.capture_state()
	var restored = ledger_script.new()
	if not restored.restore_state(state):
		failures.append("valid ledger state must restore")
	elif restored.capture_state() != state:
		failures.append("ledger state must round-trip exactly")

func _test_queue(
	failures: Array[String],
	event_script,
	ledger_script,
	queue_script
) -> void:
	var ledger = ledger_script.new(4)
	var queue = queue_script.new(2)
	var first = _comment(event_script, &"e1", "one")
	var second = _comment(event_script, &"e2", "two")
	var third = _comment(event_script, &"e3", "three")

	if queue.enqueue(first, ledger) != queue_script.RESULT_ACCEPTED:
		failures.append("first valid event must enqueue")
	if queue.enqueue(first, ledger) != queue_script.RESULT_DUPLICATE:
		failures.append("pending duplicate must be rejected")
	if queue.enqueue(second, ledger) != queue_script.RESULT_ACCEPTED:
		failures.append("second valid event must enqueue")
	if queue.enqueue(third, ledger) != queue_script.RESULT_FULL:
		failures.append("queue must reject event above max_pending")
	if queue.size() != 2:
		failures.append("queue size must stay bounded")

	var popped = queue.pop_front()
	if popped == null or popped.event_id != &"e1":
		failures.append("queue must pop FIFO")
	if not ledger.record(popped.event_id):
		failures.append("processed event ID must enter ledger")
	if queue.enqueue(first, ledger) != queue_script.RESULT_DUPLICATE:
		failures.append("processed duplicate must be rejected")

	var invalid = event_script.new(
		&"bad",
		&"comment",
		0.0,
		"viewer",
		{"text": ""}
	)
	if queue.enqueue(invalid, ledger) != queue_script.RESULT_INVALID:
		failures.append("invalid event must not enter queue")

	var remaining = queue.pop_front()
	if remaining == null or remaining.event_id != &"e2":
		failures.append("second FIFO item must remain intact")
	if queue.pop_front() != null:
		failures.append("empty queue must pop null")

func _comment(event_script, id: StringName, text: String):
	return event_script.new(
		id,
		&"comment",
		0.0,
		"viewer",
		{"text": text}
	)
