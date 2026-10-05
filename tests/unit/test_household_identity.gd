extends RefCounted

const WORLD_PATH := "res://scripts/simulation/simulation_world.gd"
const CHARACTER_PATH := "res://scripts/simulation/characters/character_state.gd"

func run() -> Array[String]:
	var failures: Array[String] = []
	var world_script := load(WORLD_PATH)
	var character_script := load(CHARACTER_PATH)
	if world_script == null or character_script == null:
		failures.append("SimulationWorld and CharacterState must load")
		return failures

	var world = world_script.new()
	var empty_id = character_script.new(&"", "Invalid")
	if world.add_character(empty_id) != false:
		failures.append("empty resident id must be rejected")

	var first = character_script.new(&"resident_001", "Mira")
	if world.add_character(first) != true:
		failures.append("first valid resident must be accepted")
	if world.add_character(first) != false:
		failures.append("same resident instance must not be added twice")

	var duplicate_id = character_script.new(&"resident_001", "Duplicate Mira")
	if world.add_character(duplicate_id) != false:
		failures.append("different resident with duplicate id must be rejected")

	for index in range(2, 7):
		var id := StringName("resident_%03d" % index)
		var resident = character_script.new(id, "Resident %d" % index)
		if world.add_character(resident) != true:
			failures.append("unique resident %s must be accepted" % id)

	return failures
