extends RefCounted

const CANDIDATE_PATH := "res://scripts/simulation/utility_ai/action_candidate.gd"
const UTILITY_AI_PATH := "res://scripts/simulation/utility_ai/utility_ai.gd"
const CHARACTER_STATE_PATH := "res://scripts/simulation/characters/character_state.gd"
const SMART_OBJECT_PATH := "res://scripts/simulation/interactions/smart_object.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	if not FileAccess.file_exists(CANDIDATE_PATH):
		failures.append("ActionCandidate must exist at %s" % CANDIDATE_PATH)
		return failures
	if not FileAccess.file_exists(UTILITY_AI_PATH):
		failures.append("UtilityAI must exist at %s" % UTILITY_AI_PATH)
		return failures

	var candidate_script := load(CANDIDATE_PATH)
	var utility_script := load(UTILITY_AI_PATH)
	var character_script := load(CHARACTER_STATE_PATH)
	var smart_object_script := load(SMART_OBJECT_PATH)
	if candidate_script == null or utility_script == null or character_script == null or smart_object_script == null:
		failures.append("UtilityAI dependencies must load")
		return failures

	var character = character_script.new(&"resident_ai", "AI Test")
	var utility_ai = utility_script.new()

	var low = candidate_script.new(&"low", 10.0)
	var high = candidate_script.new(&"high", 20.0)
	var invalid = candidate_script.new(&"", 999.0)

	var blocked_object = smart_object_script.new()
	blocked_object.reserve(&"resident_other")
	var blocked = candidate_script.new(&"blocked", 100.0, blocked_object)

	var candidates: Array[ActionCandidate] = [low, high, invalid, blocked]
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var choice = utility_ai.choose(character, candidates, rng)
	if choice == null or choice.id != &"high":
		failures.append("UtilityAI must choose the highest valid available candidate")

	var empty_candidates: Array[ActionCandidate] = []
	var empty_rng := RandomNumberGenerator.new()
	empty_rng.seed = 1
	var idle_choice = utility_ai.choose(character, empty_candidates, empty_rng)
	if idle_choice == null or idle_choice.id != &"idle":
		failures.append("UtilityAI must return Idle when no valid candidate exists")

	var tie_a = candidate_script.new(&"tie_a", 50.0)
	var tie_b = candidate_script.new(&"tie_b", 50.0)
	var ties: Array[ActionCandidate] = [tie_a, tie_b]
	var rng_a := RandomNumberGenerator.new()
	var rng_b := RandomNumberGenerator.new()
	rng_a.seed = 987654
	rng_b.seed = 987654
	var tie_choice_a = utility_ai.choose(character, ties, rng_a)
	var tie_choice_b = utility_ai.choose(character, ties, rng_b)

	if tie_choice_a == null or tie_choice_b == null:
		failures.append("UtilityAI tie choice must return a candidate")
	elif tie_choice_a.id != tie_choice_b.id:
		failures.append("equal scores with the same seed must resolve identically")
	elif tie_choice_a.id != &"tie_a" and tie_choice_a.id != &"tie_b":
		failures.append("tie resolution must select one of the tied candidates")

	blocked_object.free()
	return failures
