extends RefCounted

const EVENT_PATH := "res://scripts/replay/replay_event.gd"
const LOG_PATH := "res://scripts/replay/replay_log.gd"
const PLAYER_PATH := "res://scripts/replay/replay_player.gd"
const WORLD_PATH := "res://scripts/simulation/simulation_world.gd"
const CHARACTER_PATH := "res://scripts/simulation/characters/character_state.gd"
const INTERACTION_PATH := "res://scripts/simulation/interactions/interaction_definition.gd"
const SMART_OBJECT_PATH := "res://scripts/simulation/interactions/smart_object.gd"
const SNAPSHOT_PATH := "res://scripts/persistence/world_snapshot_codec.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	for path in [EVENT_PATH, LOG_PATH, PLAYER_PATH]:
		if not FileAccess.file_exists(path):
			failures.append("replay dependency must exist at %s" % path)
			return failures

	var event_script := load(EVENT_PATH)
	var log_script := load(LOG_PATH)
	var player_script := load(PLAYER_PATH)
	var world_script := load(WORLD_PATH)
	var character_script := load(CHARACTER_PATH)
	var interaction_script := load(INTERACTION_PATH)
	var smart_object_script := load(SMART_OBJECT_PATH)
	var snapshot_script := load(SNAPSHOT_PATH)
	if (
		event_script == null
		or log_script == null
		or player_script == null
		or world_script == null
		or character_script == null
		or interaction_script == null
		or smart_object_script == null
		or snapshot_script == null
	):
		failures.append("replay dependencies must load")
		return failures

	_test_log_contract(failures, event_script, log_script)
	_test_replay_matches_control(
		failures,
		log_script,
		player_script,
		world_script,
		character_script,
		interaction_script,
		smart_object_script,
		snapshot_script
	)
	_test_invalid_replay_does_not_mutate(
		failures,
		event_script,
		player_script,
		world_script,
		character_script,
		interaction_script,
		smart_object_script,
		snapshot_script
	)

	return failures

func _test_log_contract(
	failures: Array[String],
	event_script,
	log_script
) -> void:
	var log = log_script.new()

	if not log.append(&"advance", {"real_delta": 1.0}):
		failures.append("first valid replay event must append")
	if not log.append(
		&"movement_arrived",
		{"character_id": "resident_a", "target_object_id": "chair_a"}
	):
		failures.append("second valid replay event must append")

	var events: Array = log.events()
	if events.size() != 2:
		failures.append("ReplayLog must expose two appended events")
		return

	if events[0].sequence != 1 or events[1].sequence != 2:
		failures.append("ReplayLog sequence numbers must be deterministic and monotonic")
	if events[0].kind != &"advance":
		failures.append("ReplayEvent kind must be preserved")
	if not is_equal_approx(float(events[0].payload["real_delta"]), 1.0):
		failures.append("ReplayEvent payload must be preserved")

	events.clear()
	if log.events().size() != 2:
		failures.append("ReplayLog.events() must not expose mutable internal storage")

	var original_payload := {"real_delta": 2.0}
	if not log.append(&"advance", original_payload):
		failures.append("third valid replay event must append")
	original_payload["real_delta"] = 999.0
	if not is_equal_approx(float(log.events()[2].payload["real_delta"]), 2.0):
		failures.append("ReplayLog must deep-copy appended payload")

	if log.append(&"unknown", {}):
		failures.append("ReplayLog must reject unknown event kind")
	if log.append(&"advance", {"real_delta": NAN}):
		failures.append("ReplayLog must reject non-finite advance delta")
	if log.events().size() != 3:
		failures.append("failed appends must not consume sequence or mutate event list")

	var maxed = log_script.new()
	for index in range(log_script.MAX_EVENTS):
		if not maxed.append(&"advance", {"real_delta": 0.0}):
			failures.append("ReplayLog must accept exactly MAX_EVENTS valid events")
			return
	if maxed.append(&"advance", {"real_delta": 0.0}):
		failures.append("ReplayLog must reject overflow beyond MAX_EVENTS")

	var manual = event_script.new(10, &"advance", {"real_delta": 1.0})
	if manual.sequence != 10 or manual.kind != &"advance":
		failures.append("ReplayEvent constructor must preserve sequence/kind")

func _test_replay_matches_control(
	failures: Array[String],
	log_script,
	player_script,
	world_script,
	character_script,
	interaction_script,
	smart_object_script,
	snapshot_script
) -> void:
	var control := _build_world(
		world_script,
		character_script,
		interaction_script,
		smart_object_script,
		true
	)
	var control_world = control["world"]
	var resident = control["resident"]

	var initial_snapshot: Dictionary = snapshot_script.encode(control_world)
	var log = log_script.new()

	if not log.append(&"advance", {"real_delta": 1.0}):
		failures.append("replay setup first advance must append")
		_dispose_world(control)
		return
	control_world.step(1.0)

	if resident.movement.intent == null:
		failures.append("control first advance must choose a SmartObject target")
		_dispose_world(control)
		return
	var target_object_id: StringName = resident.movement.intent.target_object_id

	if not log.append(&"movement_arrived", {
		"character_id": str(resident.id),
		"target_object_id": str(target_object_id),
	}):
		failures.append("replay setup arrival must append")
	if not control_world.report_arrival(resident.id, target_object_id):
		failures.append("control arrival feedback must apply")

	if not log.append(&"advance", {"real_delta": 2.0}):
		failures.append("replay setup completion advance must append")
	control_world.step(2.0)

	if not log.append(&"advance", {"real_delta": 1.0}):
		failures.append("replay setup followup advance must append")
	control_world.step(1.0)

	var expected_final: Dictionary = snapshot_script.encode(control_world)

	var replay_target := _build_world(
		world_script,
		character_script,
		interaction_script,
		smart_object_script,
		false
	)
	var replay_world = replay_target["world"]

	var replay_errors: Array[String] = player_script.replay(
		replay_world,
		initial_snapshot,
		log.events()
	)
	if not replay_errors.is_empty():
		failures.append("valid replay must succeed: %s" % " | ".join(replay_errors))
	else:
		var replay_final: Dictionary = snapshot_script.encode(replay_world)
		if replay_final != expected_final:
			failures.append("replayed final snapshot must exactly equal control final snapshot")

	_dispose_world(control)
	_dispose_world(replay_target)

func _test_invalid_replay_does_not_mutate(
	failures: Array[String],
	event_script,
	player_script,
	world_script,
	character_script,
	interaction_script,
	smart_object_script,
	snapshot_script
) -> void:
	var source := _build_world(
		world_script,
		character_script,
		interaction_script,
		smart_object_script,
		true
	)
	var initial_snapshot: Dictionary = snapshot_script.encode(source["world"])

	var cases: Array = [
		[
			event_script.new(1, &"unknown", {}),
		],
		[
			event_script.new(1, &"advance", {"real_delta": NAN}),
		],
		[
			event_script.new(1, &"movement_arrived", {
				"character_id": "",
				"target_object_id": "chair_a",
			}),
		],
		[
			event_script.new(2, &"advance", {"real_delta": 1.0}),
		],
	]

	for events in cases:
		var target := _build_world(
			world_script,
			character_script,
			interaction_script,
			smart_object_script,
			false
		)
		var world = target["world"]
		var before: Dictionary = snapshot_script.encode(world)
		var errors: Array[String] = player_script.replay(world, initial_snapshot, events)
		if errors.is_empty():
			failures.append("invalid replay event list must fail")
		if snapshot_script.encode(world) != before:
			failures.append("invalid replay must not partially restore or advance destination world")
		_dispose_world(target)

	var too_many: Array = []
	for index in range(4097):
		too_many.append(event_script.new(index + 1, &"advance", {"real_delta": 0.0}))

	var overflow_target := _build_world(
		world_script,
		character_script,
		interaction_script,
		smart_object_script,
		false
	)
	var overflow_world = overflow_target["world"]
	var overflow_before: Dictionary = snapshot_script.encode(overflow_world)
	var overflow_errors: Array[String] = player_script.replay(
		overflow_world,
		initial_snapshot,
		too_many
	)
	if overflow_errors.is_empty():
		failures.append("replay input longer than 4096 events must fail")
	if snapshot_script.encode(overflow_world) != overflow_before:
		failures.append("overflow replay must not mutate destination world")

	_dispose_world(overflow_target)
	_dispose_world(source)

func _build_world(
	world_script,
	character_script,
	interaction_script,
	smart_object_script,
	with_resident: bool
) -> Dictionary:
	var world = world_script.new()

	var interaction = interaction_script.new()
	interaction.id = &"relax"
	interaction.duration_sim_seconds = 2.0
	interaction.need_effects = {"comfort": 60.0}

	var chair_a = smart_object_script.new()
	chair_a.object_id = &"chair_a"
	chair_a.interaction_point = Vector3(-1.0, 0.0, 0.0)
	chair_a.interactions.append(interaction)
	world.register_smart_object(chair_a)

	var chair_b = smart_object_script.new()
	chair_b.object_id = &"chair_b"
	chair_b.interaction_point = Vector3(1.0, 0.0, 0.0)
	chair_b.interactions.append(interaction)
	world.register_smart_object(chair_b)

	var resident = null
	if with_resident:
		resident = character_script.new(&"resident_a", "Resident A")
		_disable_decay(resident)
		resident.needs.comfort.value = 0.0
		resident.needs.social.value = 100.0
		world.add_character(resident)

	return {
		"world": world,
		"resident": resident,
		"objects": [chair_a, chair_b],
	}

func _disable_decay(character) -> void:
	for need_name in ["hunger", "energy", "hygiene", "comfort", "social", "mood"]:
		character.needs.get(need_name).decay_per_sim_hour = 0.0

func _dispose_world(state: Dictionary) -> void:
	for object in state.get("objects", []):
		if object != null and is_instance_valid(object):
			object.free()
