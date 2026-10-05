extends RefCounted

const EVENT_PATH := "res://scripts/simulation/memory/memory_event.gd"
const STORE_PATH := "res://scripts/simulation/memory/memory_store.gd"
const CHARACTER_PATH := "res://scripts/simulation/characters/character_state.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	if not FileAccess.file_exists(EVENT_PATH):
		failures.append("MemoryEvent must exist at %s" % EVENT_PATH)
		return failures
	if not FileAccess.file_exists(STORE_PATH):
		failures.append("MemoryStore must exist at %s" % STORE_PATH)
		return failures

	var event_script := load(EVENT_PATH)
	var store_script := load(STORE_PATH)
	var character_script := load(CHARACTER_PATH)
	if event_script == null or store_script == null or character_script == null:
		failures.append("memory dependencies must load")
		return failures

	var related: Array[StringName] = [&"resident_b"]
	var event = event_script.new(&"memory_001", &"chat", 120.0, related, 2.0, -5.0)
	if event.event_id != &"memory_001":
		failures.append("MemoryEvent must preserve event_id")
	if event.kind != &"chat":
		failures.append("MemoryEvent must preserve kind")
	if not is_equal_approx(event.simulation_seconds, 120.0):
		failures.append("MemoryEvent must preserve finite simulation time")
	if not is_equal_approx(event.valence, 1.0):
		failures.append("MemoryEvent valence must clamp to 1")
	if not is_equal_approx(event.importance, 0.0):
		failures.append("MemoryEvent importance must clamp to 0")
	if event.related_resident_ids != related:
		failures.append("MemoryEvent must preserve related resident ids")

	var non_finite = event_script.new(&"memory_bad", &"unknown", NAN, [], NAN, INF)
	if is_nan(non_finite.simulation_seconds) or is_inf(non_finite.simulation_seconds):
		failures.append("MemoryEvent simulation time must stay finite")
	if is_nan(non_finite.valence) or is_inf(non_finite.valence):
		failures.append("MemoryEvent valence must stay finite")
	if is_nan(non_finite.importance) or is_inf(non_finite.importance):
		failures.append("MemoryEvent importance must stay finite")

	var default_store = store_script.new()
	if default_store.capacity != 64:
		failures.append("MemoryStore default capacity must be 64")

	if default_store.add(null) != false:
		failures.append("MemoryStore must reject null event")
	var empty_id_event = event_script.new(&"", &"chat", 1.0, [], 0.0, 0.5)
	if default_store.add(empty_id_event) != false:
		failures.append("MemoryStore must reject empty event id")

	var duplicate = event_script.new(&"dup", &"chat", 1.0, [], 0.0, 0.5)
	if default_store.add(duplicate) != true:
		failures.append("MemoryStore must accept first unique event")
	if default_store.add(duplicate) != false:
		failures.append("MemoryStore must reject duplicate event id")
	if default_store.get_event(&"dup") != duplicate:
		failures.append("MemoryStore lookup must return stored event")
	if default_store.get_event(&"missing") != null:
		failures.append("MemoryStore lookup must return null for missing event")

	var small_store = store_script.new(3)
	var e1 = event_script.new(&"e1", &"chat", 10.0, [], 0.2, 0.1)
	var e2 = event_script.new(&"e2", &"chat", 5.0, [], 0.2, 0.1)
	var e3 = event_script.new(&"e3", &"chat", 20.0, [], 0.2, 0.9)
	var e4 = event_script.new(&"e4", &"chat", 30.0, [], 0.2, 0.5)

	small_store.add(e1)
	small_store.add(e2)
	small_store.add(e3)
	small_store.add(e4)

	if small_store.size() != 3:
		failures.append("MemoryStore must enforce capacity")
	if small_store.get_event(&"e2") != null:
		failures.append("capacity eviction must remove oldest event among lowest-importance ties")
	if small_store.get_event(&"e1") == null or small_store.get_event(&"e3") == null or small_store.get_event(&"e4") == null:
		failures.append("capacity eviction must preserve higher-priority memories")

	var visible: Array = small_store.events()
	if visible.size() != 3:
		failures.append("events() must expose current bounded memories")
	visible.clear()
	if small_store.size() != 3:
		failures.append("events() must not expose mutable internal storage")

	var character = character_script.new(&"resident_memory", "Memory Resident")
	if character.memory == null:
		failures.append("CharacterState must create MemoryStore")
	elif character.memory.capacity != 64:
		failures.append("CharacterState MemoryStore must use default capacity 64")

	return failures
