extends RefCounted

const CHARACTER_STATE_PATH := "res://scripts/simulation/characters/character_state.gd"
const PERSONALITY_STATE_PATH := "res://scripts/simulation/characters/personality_state.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	if not FileAccess.file_exists(CHARACTER_STATE_PATH):
		failures.append("CharacterState must exist at %s" % CHARACTER_STATE_PATH)
		return failures
	if not FileAccess.file_exists(PERSONALITY_STATE_PATH):
		failures.append("PersonalityState must exist at %s" % PERSONALITY_STATE_PATH)
		return failures

	var character_script := load(CHARACTER_STATE_PATH)
	var personality_script := load(PERSONALITY_STATE_PATH)
	if character_script == null or personality_script == null:
		failures.append("CharacterState and PersonalityState scripts must load")
		return failures

	var character = character_script.new(&"resident_001", "Mira")
	if character.id != &"resident_001":
		failures.append("CharacterState id must remain stable")
	if character.display_name != "Mira":
		failures.append("CharacterState display_name must remain stable")
	if character.needs == null:
		failures.append("CharacterState must create NeedProfile")
	if character.personality == null:
		failures.append("CharacterState must create PersonalityState")
	if not is_equal_approx(character.money, 0.0):
		failures.append("CharacterState money must default to 0")
	if character.current_action_id != &"idle":
		failures.append("CharacterState current_action_id must default to idle")

	var personality = personality_script.new()
	var traits := [
		"sociability",
		"neatness",
		"ambition",
		"kindness",
		"impulsiveness",
		"confidence",
		"humor",
		"jealousy",
	]

	for trait_name in traits:
		var initial_value: float = personality.get(trait_name)
		if initial_value < 0.0 or initial_value > 1.0:
			failures.append("%s must default inside 0..1" % trait_name)

		personality.set(trait_name, 2.0)
		if not is_equal_approx(float(personality.get(trait_name)), 1.0):
			failures.append("%s must clamp values above 1" % trait_name)

		personality.set(trait_name, -2.0)
		if not is_equal_approx(float(personality.get(trait_name)), 0.0):
			failures.append("%s must clamp values below 0" % trait_name)

	return failures
