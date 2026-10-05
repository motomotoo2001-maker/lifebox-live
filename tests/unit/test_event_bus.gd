extends RefCounted

const EVENT_BUS_PATH := "res://scripts/core/event_bus.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	if not FileAccess.file_exists(EVENT_BUS_PATH):
		failures.append("EventBus must exist at %s" % EVENT_BUS_PATH)
		return failures

	var bus_script := load(EVENT_BUS_PATH)
	if bus_script == null:
		failures.append("EventBus script must load")
		return failures

	var bus = bus_script.new()
	if not bus.has_signal("simulation_event"):
		failures.append("EventBus must expose simulation_event(topic, payload)")
		return failures

	var received: Array[Dictionary] = []
	bus.simulation_event.connect(func(topic: StringName, payload: Dictionary) -> void:
		received.append({
			"topic": topic,
			"payload": payload.duplicate(true),
		})
	)

	var payload := {
		"value": 42,
		"nested": {"ok": true},
	}
	var expected_payload := payload.duplicate(true)
	bus.publish(&"resident_changed", payload)

	if received.size() != 1:
		failures.append("one publish must emit exactly one event")
		return failures

	if received[0]["topic"] != &"resident_changed":
		failures.append("published topic must be forwarded unchanged")

	if received[0]["payload"] != expected_payload:
		failures.append("published payload must be forwarded unchanged")

	if payload != expected_payload:
		failures.append("publish must not mutate caller payload")

	bus.publish(&"empty")
	if received.size() != 2:
		failures.append("publish with default payload must emit an event")
	elif received[1]["payload"] != {}:
		failures.append("default payload must be an empty Dictionary")

	return failures
