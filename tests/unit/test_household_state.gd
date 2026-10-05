extends RefCounted

const HOUSEHOLD_PATH := "res://scripts/simulation/household/household_state.gd"
const CHARACTER_PATH := "res://scripts/simulation/characters/character_state.gd"
const FIXTURE_PATH := "res://tests/fixtures/six_resident_household_fixture.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	if not FileAccess.file_exists(HOUSEHOLD_PATH):
		failures.append("HouseholdState must exist at %s" % HOUSEHOLD_PATH)
		return failures

	var household_script := load(HOUSEHOLD_PATH)
	var character_script := load(CHARACTER_PATH)
	var fixture_script := load(FIXTURE_PATH)
	if household_script == null or character_script == null or fixture_script == null:
		failures.append("HouseholdState dependencies must load")
		return failures

	var household = household_script.new()
	var mira = character_script.new(&"resident_mira", "Mira")
	var teo = character_script.new(&"resident_teo", "Teo")

	if household.add_resident(null) != false:
		failures.append("HouseholdState must reject null resident")

	var empty_id = character_script.new(&"", "Invalid")
	if household.add_resident(empty_id) != false:
		failures.append("HouseholdState must reject empty resident id")

	if household.add_resident(mira) != true:
		failures.append("HouseholdState must accept first valid resident")
	if household.add_resident(mira) != false:
		failures.append("HouseholdState must reject same resident twice")

	var duplicate_mira = character_script.new(&"resident_mira", "Duplicate")
	if household.add_resident(duplicate_mira) != false:
		failures.append("HouseholdState must reject duplicate resident id")

	if household.add_resident(teo) != true:
		failures.append("HouseholdState must accept second unique resident")

	if household.get_resident(&"resident_mira") != mira:
		failures.append("HouseholdState lookup must return resident by stable id")
	if household.get_resident(&"missing") != null:
		failures.append("HouseholdState lookup must return null for missing id")

	var ordered: Array = household.residents()
	if ordered.size() != 2 or ordered[0] != mira or ordered[1] != teo:
		failures.append("HouseholdState must preserve deterministic insertion order")

	ordered.clear()
	if household.residents().size() != 2:
		failures.append("residents() must not expose mutable internal roster storage")

	if household.remove_resident(&"missing") != false:
		failures.append("removing missing resident must return false")
	if household.remove_resident(&"resident_mira") != true:
		failures.append("removing existing resident must return true")
	if household.get_resident(&"resident_mira") != null:
		failures.append("removed resident must no longer be found")
	var remaining: Array = household.residents()
	if remaining.size() != 1 or remaining[0] != teo:
		failures.append("removal must preserve remaining insertion order")

	var fixture: Dictionary = fixture_script.new().build()
	if fixture.is_empty():
		failures.append("six resident fixture must build")
		return failures

	var fixture_residents: Array = fixture["residents"]
	if fixture_residents.size() != 6:
		failures.append("six resident fixture must contain exactly 6 residents")

	var seen_ids: Dictionary = {}
	for index in range(fixture_residents.size()):
		var resident = fixture_residents[index]
		if resident.id == &"":
			failures.append("fixture resident ids must be non-empty")
		if seen_ids.has(resident.id):
			failures.append("fixture resident ids must be unique")
		seen_ids[resident.id] = true
		var expected_id := StringName("resident_%03d" % (index + 1))
		if resident.id != expected_id:
			failures.append("fixture residents must preserve deterministic id order")

	return failures
