extends RefCounted

const CODEC_PATH := "res://scripts/persistence/world_snapshot_codec.gd"
const WORLD_PATH := "res://scripts/simulation/simulation_world.gd"
const CHARACTER_PATH := "res://scripts/simulation/characters/character_state.gd"
const INTERACTION_PATH := "res://scripts/simulation/interactions/interaction_definition.gd"
const SMART_OBJECT_PATH := "res://scripts/simulation/interactions/smart_object.gd"
const MEMORY_EVENT_PATH := "res://scripts/simulation/memory/memory_event.gd"
const JOB_DEFINITION_PATH := "res://scripts/simulation/economy/job_definition.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	if not FileAccess.file_exists(CODEC_PATH):
		failures.append("WorldSnapshotCodec must exist at %s" % CODEC_PATH)
		return failures

	var codec_script := load(CODEC_PATH)
	var world_script := load(WORLD_PATH)
	var character_script := load(CHARACTER_PATH)
	var interaction_script := load(INTERACTION_PATH)
	var smart_object_script := load(SMART_OBJECT_PATH)
	var memory_event_script := load(MEMORY_EVENT_PATH)
	var job_definition_script := load(JOB_DEFINITION_PATH)
	if (
		codec_script == null
		or world_script == null
		or character_script == null
		or interaction_script == null
		or smart_object_script == null
		or memory_event_script == null
		or job_definition_script == null
	):
		failures.append("world snapshot dependencies must load")
		return failures

	var source := _build_world(
		world_script,
		character_script,
		interaction_script,
		smart_object_script,
		true
	)
	var source_world = source["world"]
	var source_a = source["resident_a"]
	var source_b = source["resident_b"]

	source_a.money = 25.0
	source_a.memory.add(memory_event_script.new(
		&"snapshot_memory",
		&"chat",
		12.0,
		[&"resident_b"],
		0.4,
		0.5
	))

	var job = job_definition_script.new()
	job.id = &"snapshot_job"
	job.pay_per_sim_hour = 20.0
	job.shift_start_hour = 8.0
	job.shift_duration_hours = 4.0
	source_world.job_system.assign_job(source_a, job)
	source_a.job.total_worked_sim_seconds = 123.0

	source_world.relationship_graph.get_or_create(
		source_a.id,
		source_b.id
	).apply_delta(12.0, 8.0, -3.0)

	source_world.economy_system.deposit(source_a, 5.0, 10.0)
	source_world.household_expense_system.daily_amount = 90.0
	source_world.household_expense_system.arrears = 7.0
	source_world.household_expense_system.processed_days = 2

	source_world.clock.set_time_scale(2.0)
	source_world.step(0.75)

	if source_a.current_action_id != &"relax":
		failures.append("source world must start equal-score relax action before snapshot")
		_dispose_world(source)
		return failures
	if source_a.movement.intent == null:
		failures.append("source moving action must have movement intent")
		_dispose_world(source)
		return failures

	var first_target: StringName = source_a.movement.intent.target_object_id
	var snapshot: Dictionary = codec_script.encode(source_world)
	if not _is_json_compatible(snapshot):
		failures.append("world snapshot must be JSON-compatible")
	if not snapshot["rng"]["seed"] is String or not snapshot["rng"]["state"] is String:
		failures.append("world RNG seed/state must use lossless integer strings")

	var target := _build_world(
		world_script,
		character_script,
		interaction_script,
		smart_object_script,
		false
	)
	var target_world = target["world"]

	var restore_errors: Array[String] = codec_script.restore(target_world, snapshot)
	if not restore_errors.is_empty():
		failures.append("valid world snapshot must restore: %s" % " | ".join(restore_errors))
		_dispose_world(source)
		_dispose_world(target)
		return failures

	var restored_snapshot: Dictionary = codec_script.encode(target_world)
	if restored_snapshot != snapshot:
		failures.append("restored world snapshot must exactly equal captured snapshot")

	var restored_a = target_world.get_character(&"resident_a")
	var restored_b = target_world.get_character(&"resident_b")
	if restored_a == null or restored_b == null:
		failures.append("resident roster must restore in stable order")
	else:
		if restored_a.display_name != "Resident A":
			failures.append("resident display name must restore")
		if restored_a.memory.get_event(&"snapshot_memory") == null:
			failures.append("resident memory must restore through world snapshot")
		if restored_a.job.definition == null or restored_a.job.definition.id != &"snapshot_job":
			failures.append("resident job must restore through world snapshot")

	var restored_relationship = target_world.relationship_graph.get_relationship(
		&"resident_a",
		&"resident_b"
	)
	if restored_relationship == null:
		failures.append("relationship graph must restore through world snapshot")
	elif not is_equal_approx(restored_relationship.affinity, 12.0):
		failures.append("relationship values must restore through world snapshot")

	if target_world.economy_system.transactions().size() != 1:
		failures.append("economy history must restore through world snapshot")
	if target_world.household_expense_system.processed_days != 2:
		failures.append("household expense runtime must restore through world snapshot")

	if restored_a != null:
		if restored_a.movement.intent == null:
			failures.append("active action movement intent must restore through world snapshot")
		elif restored_a.movement.intent.target_object_id != first_target:
			failures.append("active action target must restore through world snapshot")

	_test_rng_continuity(failures, source_world, target_world)
	_test_invalid_snapshot_does_not_mutate(
		failures,
		codec_script,
		snapshot,
		world_script,
		character_script,
		interaction_script,
		smart_object_script
	)

	_dispose_world(source)
	_dispose_world(target)
	return failures

func _test_rng_continuity(
	failures: Array[String],
	control_world,
	restored_world
) -> void:
	var control_a = control_world.get_character(&"resident_a")
	var restored_a = restored_world.get_character(&"resident_a")
	if control_a == null or restored_a == null:
		failures.append("RNG continuity residents must exist")
		return
	if control_a.movement.intent == null or restored_a.movement.intent == null:
		failures.append("RNG continuity requires restored active action")
		return

	var control_target: StringName = control_a.movement.intent.target_object_id
	var restored_target: StringName = restored_a.movement.intent.target_object_id
	if control_target != restored_target:
		failures.append("control and restored active target must match before RNG continuation")
		return

	control_world.report_movement_failure(control_a.id, control_target)
	restored_world.report_movement_failure(restored_a.id, restored_target)

	control_world.step(0.25)
	restored_world.step(0.25)

	if control_a.movement.intent == null or restored_a.movement.intent == null:
		failures.append("both worlds must make another equal-score choice after restore")
		return

	if control_a.movement.intent.target_object_id != restored_a.movement.intent.target_object_id:
		failures.append("first RNG-driven choice after restore must match control world")

func _test_invalid_snapshot_does_not_mutate(
	failures: Array[String],
	codec_script,
	valid_snapshot: Dictionary,
	world_script,
	character_script,
	interaction_script,
	smart_object_script
) -> void:
	var target := _build_world(
		world_script,
		character_script,
		interaction_script,
		smart_object_script,
		false
	)
	var world = target["world"]
	var before: Dictionary = codec_script.encode(world)

	var duplicate_resident := valid_snapshot.duplicate(true)
	duplicate_resident["residents"].append(
		duplicate_resident["residents"][0].duplicate(true)
	)
	var errors: Array[String] = codec_script.restore(world, duplicate_resident)
	if errors.is_empty():
		failures.append("duplicate resident IDs must reject world restore")
	if codec_script.encode(world) != before:
		failures.append("failed world restore must not mutate destination world")

	var invalid_runtime := valid_snapshot.duplicate(true)
	invalid_runtime["runtime"]["pending_sim_seconds"] = NAN
	errors = codec_script.restore(world, invalid_runtime)
	if errors.is_empty():
		failures.append("non-finite runtime accumulator must reject world restore")
	if codec_script.encode(world) != before:
		failures.append("invalid runtime restore must not mutate destination world")

	var invalid_schedule_day := valid_snapshot.duplicate(true)
	invalid_schedule_day["residents"][0]["schedule"]["day_index"] = (
		int(invalid_schedule_day["residents"][0]["schedule"]["day_index"]) + 1
	)
	errors = codec_script.restore(world, invalid_schedule_day)
	if errors.is_empty():
		failures.append("restored schedule day must match processed simulation day")
	if codec_script.encode(world) != before:
		failures.append("invalid schedule-day restore must not mutate destination world")

	_dispose_world(target)

func _build_world(
	world_script,
	character_script,
	interaction_script,
	smart_object_script,
	with_residents: bool
) -> Dictionary:
	var world = world_script.new()

	var relax = interaction_script.new()
	relax.id = &"relax"
	relax.duration_sim_seconds = 10.0
	relax.need_effects = {"comfort": 50.0}

	var object_a = smart_object_script.new()
	object_a.object_id = &"relax_a"
	object_a.interaction_point = Vector3(-1.0, 0.0, 0.0)
	object_a.interactions.append(relax)
	world.register_smart_object(object_a)

	var object_b = smart_object_script.new()
	object_b.object_id = &"relax_b"
	object_b.interaction_point = Vector3(1.0, 0.0, 0.0)
	object_b.interactions.append(relax)
	world.register_smart_object(object_b)

	var resident_a = null
	var resident_b = null
	if with_residents:
		resident_a = character_script.new(&"resident_a", "Resident A")
		resident_b = character_script.new(&"resident_b", "Resident B")

		_disable_decay(resident_a)
		_disable_decay(resident_b)

		resident_a.needs.comfort.value = 0.0
		resident_a.needs.social.value = 100.0
		resident_b.needs.comfort.value = 100.0
		resident_b.needs.social.value = 100.0

		world.add_character(resident_a)
		world.add_character(resident_b)

	return {
		"world": world,
		"resident_a": resident_a,
		"resident_b": resident_b,
		"objects": [object_a, object_b],
	}

func _disable_decay(character) -> void:
	for need_name in ["hunger", "energy", "hygiene", "comfort", "social", "mood"]:
		character.needs.get(need_name).decay_per_sim_hour = 0.0

func _dispose_world(state: Dictionary) -> void:
	for object in state.get("objects", []):
		if object != null and is_instance_valid(object):
			object.free()

func _is_json_compatible(value) -> bool:
	if value == null:
		return true
	if value is String or value is bool or value is int or value is float:
		return true
	if value is Array:
		for item in value:
			if not _is_json_compatible(item):
				return false
		return true
	if value is Dictionary:
		for key in value.keys():
			if not key is String:
				return false
			if not _is_json_compatible(value[key]):
				return false
		return true
	return false
