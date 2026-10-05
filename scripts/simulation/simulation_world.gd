class_name SimulationWorld
extends RefCounted

var clock := SimulationClock.new()
var need_system := NeedSystem.new()
var utility_ai := UtilityAI.new()

var _characters: Array[CharacterState] = []
var _smart_objects: Array[SmartObject] = []
var _executors: Dictionary = {}
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	_rng.seed = 1337

func add_character(character: CharacterState) -> void:
	if character == null or character in _characters:
		return
	_characters.append(character)
	_executors[character.id] = ActionExecutor.new()

func register_smart_object(object: SmartObject) -> void:
	if object == null or object in _smart_objects:
		return
	_smart_objects.append(object)

func step(real_delta: float) -> void:
	var sim_delta := clock.advance(real_delta)
	if sim_delta <= 0.0:
		return

	for character in _characters:
		if character == null:
			continue

		need_system.advance_character(character, sim_delta)

		var executor: ActionExecutor = _executors.get(character.id)
		if executor == null:
			executor = ActionExecutor.new()
			_executors[character.id] = executor

		if executor.is_active():
			executor.advance(sim_delta)
			continue

		var candidates := _build_candidates(character)
		var choice := utility_ai.choose(character, candidates, _rng)
		if choice == null:
			character.current_action_id = &"idle"
			continue

		executor.start(choice, character)

func _build_candidates(character: CharacterState) -> Array[ActionCandidate]:
	var candidates: Array[ActionCandidate] = []

	for object in _smart_objects:
		if object == null or not is_instance_valid(object):
			continue
		for interaction in object.list_interactions(character):
			if interaction == null:
				continue
			var score := _score_interaction(character, interaction)
			candidates.append(ActionCandidate.new(interaction.id, score, object, interaction))

	return candidates

func _score_interaction(character: CharacterState, interaction: InteractionDefinition) -> float:
	var score := 0.0

	for need_key in interaction.need_effects:
		var need_state = character.needs.get(str(need_key))
		if need_state == null:
			continue

		var raw_effect = interaction.need_effects[need_key]
		if not (raw_effect is float or raw_effect is int):
			continue

		var effect := float(raw_effect)
		if effect <= 0.0:
			continue

		var deficit := 100.0 - clampf(need_state.value, 0.0, 100.0)
		score += deficit * effect

	return score
