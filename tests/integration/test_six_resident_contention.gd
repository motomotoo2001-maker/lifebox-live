extends RefCounted

const WORLD_PATH := "res://scripts/simulation/simulation_world.gd"
const CHARACTER_PATH := "res://scripts/simulation/characters/character_state.gd"
const INTERACTION_PATH := "res://scripts/simulation/interactions/interaction_definition.gd"
const SMART_OBJECT_PATH := "res://scripts/simulation/interactions/smart_object.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	var world_script := load(WORLD_PATH)
	var character_script := load(CHARACTER_PATH)
	var interaction_script := load(INTERACTION_PATH)
	var smart_object_script := load(SMART_OBJECT_PATH)
	if world_script == null or character_script == null or interaction_script == null or smart_object_script == null:
		failures.append("contention dependencies must load")
		return failures

	var world = world_script.new()
	var residents: Array = []
	for index in range(1, 7):
		var resident = character_script.new(
			StringName("resident_%03d" % index),
			"Resident %d" % index
		)
		resident.needs.hunger.value = 10.0
		for need_name in ["hunger", "energy", "hygiene", "comfort", "social", "mood"]:
			var need_state = resident.needs.get(need_name)
			need_state.decay_per_sim_hour = 0.0
		if not world.add_character(resident):
			failures.append("all six unique residents must enter the world")
		residents.append(resident)

	var eat = interaction_script.new()
	eat.id = &"eat"
	eat.duration_sim_seconds = 1.0
	eat.need_effects = {"hunger": 100.0}

	var fridge = smart_object_script.new()
	fridge.object_id = &"fridge_main"
	fridge.interaction_point = Vector3(2.0, 0.0, 0.0)
	fridge.interactions.append(eat)
	world.register_smart_object(fridge)

	world.step(1.0)
	var first_owner = _find_single_eater(failures, residents, "first contention step")
	if first_owner != null:
		if first_owner.movement.status != &"moving":
			failures.append("fridge owner must be moving toward the reserved fridge")
		elif first_owner.movement.intent == null or first_owner.movement.intent.target_object_id != fridge.object_id:
			failures.append("fridge owner movement intent must target fridge_main")
		if fridge.is_available_for(&"reservation_probe"):
			failures.append("shared fridge must be reserved while owner is moving")

		for resident in residents:
			if resident == first_owner:
				continue
			if resident.current_action_id != &"idle":
				failures.append("losing residents must remain idle instead of stealing fridge")
			if fridge.is_available_for(resident.id):
				failures.append("losing resident must not share active fridge reservation")

		if not world.report_arrival(first_owner.id, fridge.object_id):
			failures.append("first fridge owner arrival must be accepted")
		world.step(1.0)

		var second_owner = _find_single_eater(failures, residents, "second contention step")
		if second_owner == null:
			failures.append("another hungry resident must retry after fridge is released")
		elif second_owner.id == first_owner.id:
			failures.append("satisfied first owner must not immediately monopolize fridge again")

	fridge.free()
	return failures

func _find_single_eater(failures: Array[String], residents: Array, label: String):
	var eaters: Array = []
	for resident in residents:
		if resident.current_action_id == &"eat":
			eaters.append(resident)

	if eaters.size() != 1:
		failures.append("%s must have exactly one active fridge user, got %d" % [label, eaters.size()])
		return null
	return eaters[0]
