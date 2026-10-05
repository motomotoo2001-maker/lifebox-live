extends RefCounted

const CODEC_PATH := "res://scripts/persistence/action_snapshot_codec.gd"
const WORLD_PATH := "res://scripts/simulation/simulation_world.gd"
const CHARACTER_PATH := "res://scripts/simulation/characters/character_state.gd"
const INTERACTION_PATH := "res://scripts/simulation/interactions/interaction_definition.gd"
const SMART_OBJECT_PATH := "res://scripts/simulation/interactions/smart_object.gd"
const CANDIDATE_PATH := "res://scripts/simulation/utility_ai/action_candidate.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	if not FileAccess.file_exists(CODEC_PATH):
		failures.append("ActionSnapshotCodec must exist at %s" % CODEC_PATH)
		return failures

	var codec_script := load(CODEC_PATH)
	var world_script := load(WORLD_PATH)
	var character_script := load(CHARACTER_PATH)
	var interaction_script := load(INTERACTION_PATH)
	var smart_object_script := load(SMART_OBJECT_PATH)
	var candidate_script := load(CANDIDATE_PATH)
	if (
		codec_script == null
		or world_script == null
		or character_script == null
		or interaction_script == null
		or smart_object_script == null
		or candidate_script == null
	):
		failures.append("action snapshot dependencies must load")
		return failures

	_test_moving_restore(
		failures,
		codec_script,
		world_script,
		character_script,
		interaction_script,
		smart_object_script,
		candidate_script
	)
	_test_interacting_restore(
		failures,
		codec_script,
		world_script,
		character_script,
		interaction_script,
		smart_object_script,
		candidate_script
	)
	_test_missing_topology_cancels(
		failures,
		codec_script,
		world_script,
		character_script,
		interaction_script,
		smart_object_script,
		candidate_script
	)
	_test_duplicate_claim_validation(
		failures,
		codec_script,
		world_script,
		character_script,
		interaction_script,
		smart_object_script
	)

	return failures

func _test_moving_restore(
	failures: Array[String],
	codec_script,
	world_script,
	character_script,
	interaction_script,
	smart_object_script,
	candidate_script
) -> void:
	var source := _build_action_world(
		world_script,
		character_script,
		interaction_script,
		smart_object_script,
		&"moving_resident",
		&"moving_fridge",
		&"eat_moving",
		10.0
	)
	var source_world = source["world"]
	var source_character = source["character"]
	var source_object = source["object"]
	var source_interaction = source["interaction"]
	var executor = source_world.get_action_executor(source_character.id)
	if executor == null:
		failures.append("SimulationWorld must expose resident ActionExecutor")
		_dispose_case(source)
		return

	var candidate = candidate_script.new(
		source_interaction.id,
		100.0,
		source_object,
		source_interaction
	)
	if not executor.start(candidate, source_character):
		failures.append("moving snapshot setup action must start")
		_dispose_case(source)
		return

	executor.advance(7.0)
	source_character.movement.increment_retry()
	var snapshot: Dictionary = executor.capture_state()
	if snapshot.get("phase", "") != "moving":
		failures.append("moving ActionExecutor snapshot must record moving phase")

	var target := _build_action_world(
		world_script,
		character_script,
		interaction_script,
		smart_object_script,
		&"moving_resident",
		&"moving_fridge",
		&"eat_moving",
		10.0
	)
	var target_world = target["world"]
	var target_character = target["character"]
	var target_object = target["object"]

	var errors: Array[String] = codec_script.validate(snapshot, target_world)
	if not errors.is_empty():
		failures.append("valid moving snapshot must pass validation: %s" % " | ".join(errors))
	elif not codec_script.restore(snapshot, target_world):
		failures.append("valid moving snapshot must restore")
	else:
		var restored_executor = target_world.get_action_executor(target_character.id)
		if restored_executor == null or not restored_executor.is_active():
			failures.append("restored moving executor must be active")
		if target_character.current_action_id != &"eat_moving":
			failures.append("moving action id must restore")
		if target_character.movement.status != MovementState.STATUS_MOVING:
			failures.append("movement status must restore as moving")
		if not is_equal_approx(target_character.movement.elapsed_sim_seconds, 7.0):
			failures.append("movement elapsed time must restore")
		if target_character.movement.retry_count != 1:
			failures.append("movement retry count must restore")
		if target_character.movement.intent == null:
			failures.append("moving restore must rebuild movement intent")
		elif target_character.movement.intent.target_object_id != &"moving_fridge":
			failures.append("moving restore must preserve target object id")
		if target_object.is_available_for(&"reservation_probe"):
			failures.append("moving restore must re-establish SmartObject reservation")

	_dispose_case(source)
	_dispose_case(target)

func _test_interacting_restore(
	failures: Array[String],
	codec_script,
	world_script,
	character_script,
	interaction_script,
	smart_object_script,
	candidate_script
) -> void:
	var source := _build_action_world(
		world_script,
		character_script,
		interaction_script,
		smart_object_script,
		&"interacting_resident",
		&"interacting_fridge",
		&"eat_interacting",
		10.0
	)
	var source_world = source["world"]
	var source_character = source["character"]
	var source_object = source["object"]
	var source_interaction = source["interaction"]
	source_character.needs.hunger.value = 10.0

	var executor = source_world.get_action_executor(source_character.id)
	var candidate = candidate_script.new(
		source_interaction.id,
		100.0,
		source_object,
		source_interaction
	)
	if executor == null or not executor.start(candidate, source_character):
		failures.append("interacting snapshot setup must start")
		_dispose_case(source)
		return

	executor.report_arrival(source_object.object_id)
	executor.advance(4.0)
	var snapshot: Dictionary = executor.capture_state()
	if snapshot.get("phase", "") != "interacting":
		failures.append("interacting snapshot must record interacting phase")
	if not is_equal_approx(float(snapshot.get("remaining_sim_seconds", -1.0)), 6.0):
		failures.append("interacting snapshot must preserve remaining duration")

	var target := _build_action_world(
		world_script,
		character_script,
		interaction_script,
		smart_object_script,
		&"interacting_resident",
		&"interacting_fridge",
		&"eat_interacting",
		10.0
	)
	var target_world = target["world"]
	var target_character = target["character"]
	var target_object = target["object"]
	target_character.needs.hunger.value = 10.0

	if not codec_script.restore(snapshot, target_world):
		failures.append("valid interacting snapshot must restore")
	else:
		var restored_executor = target_world.get_action_executor(target_character.id)
		var hunger_before: float = target_character.needs.hunger.value
		restored_executor.advance(5.0)
		if not is_equal_approx(target_character.needs.hunger.value, hunger_before):
			failures.append("restored interaction must not apply effects before remaining time expires")
		if target_object.is_available_for(&"reservation_probe"):
			failures.append("restored interaction must keep reservation until completion")

		restored_executor.advance(1.0)
		if target_character.needs.hunger.value <= hunger_before:
			failures.append("restored interaction must apply effects exactly on completion")
		if target_character.current_action_id != &"idle":
			failures.append("completed restored interaction must return resident to idle")
		if not target_object.is_available_for(&"reservation_probe"):
			failures.append("completed restored interaction must release reservation")

	_dispose_case(source)
	_dispose_case(target)

func _test_missing_topology_cancels(
	failures: Array[String],
	codec_script,
	world_script,
	character_script,
	interaction_script,
	smart_object_script,
	candidate_script
) -> void:
	var source := _build_action_world(
		world_script,
		character_script,
		interaction_script,
		smart_object_script,
		&"missing_resident",
		&"missing_target",
		&"missing_interaction",
		10.0
	)
	var source_world = source["world"]
	var source_character = source["character"]
	var source_object = source["object"]
	var source_interaction = source["interaction"]
	var executor = source_world.get_action_executor(source_character.id)
	var candidate = candidate_script.new(
		source_interaction.id,
		100.0,
		source_object,
		source_interaction
	)
	executor.start(candidate, source_character)
	executor.advance(3.0)
	var snapshot: Dictionary = executor.capture_state()

	var target_world = world_script.new()
	var target_character = character_script.new(&"missing_resident", "Missing Resident")
	target_world.add_character(target_character)

	if not codec_script.restore(snapshot, target_world):
		failures.append("missing saved target must be handled as safe cancellation")
	if target_character.current_action_id != &"idle":
		failures.append("missing target restore must leave resident idle")
	if target_character.movement.status != MovementState.STATUS_IDLE:
		failures.append("missing target restore must reset movement")

	var object_without_interaction = smart_object_script.new()
	object_without_interaction.object_id = &"missing_target"
	object_without_interaction.interaction_point = Vector3.ZERO
	target_world.register_smart_object(object_without_interaction)

	if not codec_script.restore(snapshot, target_world):
		failures.append("missing saved interaction must be handled as safe cancellation")
	if not object_without_interaction.is_available_for(&"reservation_probe"):
		failures.append("missing interaction restore must not leave target reserved")

	_dispose_case(source)
	object_without_interaction.free()

func _test_duplicate_claim_validation(
	failures: Array[String],
	codec_script,
	world_script,
	character_script,
	interaction_script,
	smart_object_script
) -> void:
	var world = world_script.new()
	var a = character_script.new(&"claim_a", "Claim A")
	var b = character_script.new(&"claim_b", "Claim B")
	world.add_character(a)
	world.add_character(b)

	var interaction = interaction_script.new()
	interaction.id = &"shared_action"
	interaction.duration_sim_seconds = 10.0
	interaction.need_effects = {"comfort": 10.0}

	var object = smart_object_script.new()
	object.object_id = &"shared_target"
	object.interaction_point = Vector3.ZERO
	object.interactions.append(interaction)
	world.register_smart_object(object)

	var first := _manual_moving_snapshot(&"claim_a", &"shared_target", &"shared_action")
	var second := _manual_moving_snapshot(&"claim_b", &"shared_target", &"shared_action")
	var errors: Array[String] = codec_script.validate_collection([first, second], world)
	if errors.is_empty():
		failures.append("duplicate active claims on single-capacity SmartObject must fail validation")
	if not object.is_available_for(&"reservation_probe"):
		failures.append("action validation must never mutate SmartObject reservations")

	object.free()

func _build_action_world(
	world_script,
	character_script,
	interaction_script,
	smart_object_script,
	character_id: StringName,
	object_id: StringName,
	interaction_id: StringName,
	duration: float
) -> Dictionary:
	var world = world_script.new()
	var character = character_script.new(character_id, str(character_id))
	_disable_decay(character)
	world.add_character(character)

	var interaction = interaction_script.new()
	interaction.id = interaction_id
	interaction.duration_sim_seconds = duration
	interaction.need_effects = {"hunger": 50.0}

	var object = smart_object_script.new()
	object.object_id = object_id
	object.interaction_point = Vector3(2.0, 0.0, -1.0)
	object.interactions.append(interaction)
	world.register_smart_object(object)

	return {
		"world": world,
		"character": character,
		"object": object,
		"interaction": interaction,
	}

func _manual_moving_snapshot(
	character_id: StringName,
	object_id: StringName,
	interaction_id: StringName
) -> Dictionary:
	return {
		"active": true,
		"character_id": str(character_id),
		"action_id": str(interaction_id),
		"phase": "moving",
		"target_object_id": str(object_id),
		"interaction_id": str(interaction_id),
		"remaining_sim_seconds": 0.0,
		"movement": {
			"elapsed_sim_seconds": 0.0,
			"retry_count": 0,
			"arrival_radius": 0.5,
		},
	}

func _disable_decay(character) -> void:
	for need_name in ["hunger", "energy", "hygiene", "comfort", "social", "mood"]:
		character.needs.get(need_name).decay_per_sim_hour = 0.0

func _dispose_case(state: Dictionary) -> void:
	if state.has("object"):
		var object = state["object"]
		if object != null and is_instance_valid(object):
			object.free()
