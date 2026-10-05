extends RefCounted

const HOUSEHOLD_PATH := "res://scripts/simulation/household/household_state.gd"
const CHARACTER_PATH := "res://scripts/simulation/characters/character_state.gd"

func build() -> Dictionary:
	var household_script := load(HOUSEHOLD_PATH)
	var character_script := load(CHARACTER_PATH)
	if household_script == null or character_script == null:
		return {}

	var household = household_script.new()
	var residents: Array = []

	for index in range(1, 7):
		var resident_id := StringName("resident_%03d" % index)
		var resident = character_script.new(resident_id, "Resident %d" % index)
		if household.add_resident(resident):
			residents.append(resident)

	return {
		"household": household,
		"residents": residents,
	}
