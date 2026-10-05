extends RefCounted

const NEED_SYSTEM_PATH := "res://scripts/simulation/needs/need_system.gd"
const CHARACTER_STATE_PATH := "res://scripts/simulation/characters/character_state.gd"
const CLOCK_PATH := "res://scripts/core/simulation_clock.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	if not FileAccess.file_exists(NEED_SYSTEM_PATH):
		failures.append("NeedSystem must exist at %s" % NEED_SYSTEM_PATH)
		return failures

	var need_system_script := load(NEED_SYSTEM_PATH)
	var character_script := load(CHARACTER_STATE_PATH)
	var clock_script := load(CLOCK_PATH)
	if need_system_script == null or character_script == null or clock_script == null:
		failures.append("NeedSystem dependencies must load")
		return failures

	var need_system = need_system_script.new()
	var character = character_script.new(&"resident_decay", "Decay Test")
	need_system.advance_character(character, 3600.0)

	_expect_close(failures, character.needs.hunger.value, 88.0, "hunger after one hour")
	_expect_close(failures, character.needs.energy.value, 92.0, "energy after one hour")
	_expect_close(failures, character.needs.hygiene.value, 96.0, "hygiene after one hour")
	_expect_close(failures, character.needs.comfort.value, 97.0, "comfort after one hour")
	_expect_close(failures, character.needs.social.value, 95.0, "social after one hour")
	_expect_close(failures, character.needs.mood.value, 98.0, "mood after one hour")

	var fast_character = character_script.new(&"resident_fast", "Fast Test")
	var clock = clock_script.new()
	clock.set_time_scale(20.0)
	var sim_delta: float = clock.advance(120.0)
	_expect_close(failures, sim_delta, 2400.0, "120 seconds at 20x")

	need_system.advance_character(fast_character, sim_delta)
	_expect_close(failures, fast_character.needs.hunger.value, 92.0, "accelerated hunger decay")

	var need_names := ["hunger", "energy", "hygiene", "comfort", "social", "mood"]
	for need_name in need_names:
		var value: float = fast_character.needs.get(need_name).value
		if value < 0.0 or value > 100.0 or is_nan(value):
			failures.append("%s must remain inside 0..100 after accelerated decay" % need_name)

	return failures

func _expect_close(failures: Array[String], actual: float, expected: float, label: String) -> void:
	if not is_equal_approx(actual, expected):
		failures.append("%s: expected %s, got %s" % [label, expected, actual])
