class_name SimulationWorld
extends RefCounted

const FIXED_SIM_STEP_SECONDS := 1.0

var clock := SimulationClock.new()
var need_system := NeedSystem.new()
var utility_ai := UtilityAI.new()

var _characters: Array[CharacterState] = []
var _smart_objects: Array[SmartObject] = []
var _executors: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _pending_sim_seconds: float = 0.0

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
	if is_nan(sim_delta) or sim_delta <= 0.0:
		return

	_pending_sim_seconds += sim_delta
	while _pending_sim_seconds >= FIXED_SIM_STEP_SECONDS:
		_step_fixed(FIXED_SIM_STEP_SECONDS)
		_pending_sim_seconds -= FIXED_SIM_STEP_SECONDS

func _step_fixed(sim_delta: float) -> void:
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
			if score <= 0.0:
				continue
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
