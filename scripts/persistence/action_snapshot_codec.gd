class_name ActionSnapshotCodec
extends RefCounted

static func validate(
	data: Dictionary,
	world: SimulationWorld
) -> Array[String]:
	var errors: Array[String] = []

	if world == null:
		errors.append("action snapshot requires destination world")
		return errors

	if not data.has("active") or not data["active"] is bool:
		errors.append("action active must be a bool")
		return errors
	if not data["active"]:
		return errors

	var character_id := _read_non_empty_string(data, "character_id")
	var action_id := _read_non_empty_string(data, "action_id")
	var phase := _read_non_empty_string(data, "phase")
	var target_object_id := _read_non_empty_string(data, "target_object_id")
	var interaction_id := _read_non_empty_string(data, "interaction_id")

	if character_id.is_empty():
		errors.append("action character_id must be non-empty")
	elif world.get_character(StringName(character_id)) == null:
		errors.append("action character_id does not exist in destination world")

	if action_id.is_empty():
		errors.append("action action_id must be non-empty")
	if phase not in ["moving", "interacting"]:
		errors.append("action phase must be moving or interacting")
	if target_object_id.is_empty():
		errors.append("action target_object_id must be non-empty")
	if interaction_id.is_empty():
		errors.append("action interaction_id must be non-empty")

	if (
		not data.has("remaining_sim_seconds")
		or not _is_finite_number(data["remaining_sim_seconds"])
	):
		errors.append("action remaining_sim_seconds must be finite")
	else:
		var remaining := float(data["remaining_sim_seconds"])
		if phase == "moving" and remaining < 0.0:
			errors.append("moving action remaining_sim_seconds must be non-negative")
		elif phase == "interacting" and remaining <= 0.0:
			errors.append("interacting action remaining_sim_seconds must be positive")

	if not data.has("movement") or not data["movement"] is Dictionary:
		errors.append("action movement must be a Dictionary")
	else:
		_validate_movement(data["movement"], errors)

	if (
		not character_id.is_empty()
		and not target_object_id.is_empty()
		and world.get_character(StringName(character_id)) != null
	):
		var object := world.get_smart_object(StringName(target_object_id))
		if object != null and not object.is_available_for(StringName(character_id)):
			errors.append("action target SmartObject is already reserved by another resident")

	return errors

static func validate_collection(
	actions: Array,
	world: SimulationWorld
) -> Array[String]:
	var errors: Array[String] = []
	var claimed_targets: Dictionary = {}
	var claimed_characters: Dictionary = {}

	for index in range(actions.size()):
		var raw_action = actions[index]
		if not raw_action is Dictionary:
			errors.append("action[%d] must be a Dictionary" % index)
			continue

		var action: Dictionary = raw_action
		var action_errors := validate(action, world)
		for action_error in action_errors:
			errors.append("action[%d]: %s" % [index, action_error])

		if not action.get("active", false):
			continue

		var character_id := _read_non_empty_string(action, "character_id")
		if not character_id.is_empty():
			if claimed_characters.has(character_id):
				errors.append("resident has multiple active action snapshots: %s" % character_id)
			claimed_characters[character_id] = true

		var target_object_id := _read_non_empty_string(action, "target_object_id")
		if not target_object_id.is_empty():
			if claimed_targets.has(target_object_id):
				errors.append(
					"multiple active actions claim SmartObject: %s"
					% target_object_id
				)
			claimed_targets[target_object_id] = true

	return errors

static func restore(
	data: Dictionary,
	world: SimulationWorld
) -> bool:
	if world == null:
		return false
	if not validate(data, world).is_empty():
		return false
	if not data.get("active", false):
		return true

	var character_id := StringName(data["character_id"])
	var character := world.get_character(character_id)
	if character == null:
		return false

	var executor := world.get_action_executor(character_id)
	if executor == null:
		return false

	var object := world.get_smart_object(StringName(data["target_object_id"]))
	if object == null:
		_safe_cancel(character, executor, null)
		return true

	var interaction := _find_interaction(
		object,
		character,
		StringName(data["interaction_id"])
	)
	if interaction == null:
		_safe_cancel(character, executor, object)
		return true

	return executor.restore_state(data, character, object, interaction)

static func _find_interaction(
	object: SmartObject,
	character: CharacterState,
	interaction_id: StringName
) -> InteractionDefinition:
	if object == null or not is_instance_valid(object):
		return null
	for interaction in object.list_interactions(character):
		if interaction != null and interaction.id == interaction_id:
			return interaction
	return null

static func _safe_cancel(
	character: CharacterState,
	executor: ActionExecutor,
	object: SmartObject
) -> void:
	if executor != null and executor.is_active():
		executor.cancel()
	else:
		character.current_action_id = &"idle"
		character.movement.reset()

	if object != null and is_instance_valid(object):
		object.release(character.id)

static func _validate_movement(
	movement: Dictionary,
	errors: Array[String]
) -> void:
	if (
		not movement.has("elapsed_sim_seconds")
		or not _is_finite_number(movement["elapsed_sim_seconds"])
		or float(movement["elapsed_sim_seconds"]) < 0.0
	):
		errors.append("movement elapsed_sim_seconds must be finite and non-negative")

	if (
		not movement.has("retry_count")
		or not movement["retry_count"] is int
		or int(movement["retry_count"]) < 0
	):
		errors.append("movement retry_count must be a non-negative integer")

	if (
		not movement.has("arrival_radius")
		or not _is_finite_number(movement["arrival_radius"])
		or float(movement["arrival_radius"]) < 0.0
	):
		errors.append("movement arrival_radius must be finite and non-negative")

static func _read_non_empty_string(data: Dictionary, key: String) -> String:
	if not data.has(key) or not data[key] is String:
		return ""
	return data[key]

static func _is_finite_number(value) -> bool:
	if not (value is int or value is float):
		return false
	var number := float(value)
	return not is_nan(number) and not is_inf(number)
