extends RefCounted

const CHARACTER_PATH := "res://scripts/simulation/characters/character_state.gd"
const INTERACTION_PATH := "res://scripts/simulation/interactions/interaction_definition.gd"
const SMART_OBJECT_PATH := "res://scripts/simulation/interactions/smart_object.gd"
const WORLD_PATH := "res://scripts/simulation/simulation_world.gd"

func build() -> Dictionary:
	var character_script := load(CHARACTER_PATH)
	var interaction_script := load(INTERACTION_PATH)
	var smart_object_script := load(SMART_OBJECT_PATH)
	var world_script := load(WORLD_PATH)

	var resident = character_script.new(&"resident_001", "Mira")
	resident.needs.hunger.value = 10.0
	resident.needs.energy.value = 95.0
	resident.needs.hunger.decay_per_sim_hour = 0.0
	resident.needs.energy.decay_per_sim_hour = 0.0
	resident.needs.hygiene.decay_per_sim_hour = 0.0
	resident.needs.comfort.decay_per_sim_hour = 0.0
	resident.needs.social.decay_per_sim_hour = 0.0
	resident.needs.mood.decay_per_sim_hour = 0.0

	var eat = interaction_script.new()
	eat.id = &"eat"
	eat.duration_sim_seconds = 60.0
	eat.need_effects = {"hunger": 70.0}

	var sleep = interaction_script.new()
	sleep.id = &"sleep"
	sleep.duration_sim_seconds = 60.0
	sleep.need_effects = {"energy": 70.0}

	var fridge = smart_object_script.new()
	fridge.name = "Fridge"
	fridge.object_id = &"fridge_main"
	fridge.interaction_point = Vector3(2.0, 0.0, 0.0)
	fridge.interactions.append(eat)

	var bed = smart_object_script.new()
	bed.name = "Bed"
	bed.object_id = &"bed_main"
	bed.interaction_point = Vector3(-2.0, 0.0, 0.0)
	bed.interactions.append(sleep)

	var world = world_script.new()
	world.add_character(resident)
	world.register_smart_object(fridge)
	world.register_smart_object(bed)

	return {
		"world": world,
		"resident": resident,
		"fridge": fridge,
		"bed": bed,
	}
