class_name SimulationWorld
extends RefCounted

const FIXED_SIM_STEP_SECONDS := 1.0
const ECONOMY_STEP_SECONDS := 60.0

var clock := SimulationClock.new()
var need_system := NeedSystem.new()
var utility_ai := UtilityAI.new()
var stuck_recovery_policy := StuckRecoveryPolicy.new()
var economy_system := EconomySystem.new()
var spending_decision_system := SpendingDecisionSystem.new()
var job_system := JobSystem.new()
var household_expense_system := HouseholdExpenseSystem.new()
var relationship_graph := RelationshipGraph.new()
var social_system := SocialSystem.new()

var _characters: Array[CharacterState] = []
var _smart_objects: Array[SmartObject] = []
var _executors: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _pending_sim_seconds: float = 0.0
var _processed_sim_seconds: float = 0.0
var _pending_economy_seconds: float = 0.0
var _processed_economy_seconds: float = 0.0

func _init() -> void:
	_rng.seed = 1337
	_register_default_social_actions()

func add_character(character: CharacterState) -> bool:
	if character == null or character.id == &"":
		return false
	if character in _characters or _executors.has(character.id):
		return false

	_characters.append(character)
	_executors[character.id] = ActionExecutor.new(economy_system)
	return true

func register_smart_object(object: SmartObject) -> void:
	if object == null or object in _smart_objects:
		return
	_smart_objects.append(object)

func report_arrival(character_id: StringName, target_object_id: StringName) -> bool:
	var executor: ActionExecutor = _executors.get(character_id)
	if executor == null:
		return false
	return executor.report_arrival(target_object_id)

func report_movement_failure(character_id: StringName, target_object_id: StringName) -> bool:
	var executor: ActionExecutor = _executors.get(character_id)
	if executor == null:
		return false
	return executor.report_movement_failure(target_object_id)

func step(real_delta: float) -> void:
	var sim_delta := clock.advance(real_delta)
	if is_nan(sim_delta) or sim_delta <= 0.0:
		return

	_pending_sim_seconds += sim_delta
	while _pending_sim_seconds >= FIXED_SIM_STEP_SECONDS:
		_step_fixed(FIXED_SIM_STEP_SECONDS)
		_pending_sim_seconds -= FIXED_SIM_STEP_SECONDS

func _step_fixed(sim_delta: float) -> void:
	_processed_sim_seconds += sim_delta
	_pending_economy_seconds += sim_delta

	for character in _characters:
		if character == null:
			continue

		need_system.advance_character(character, sim_delta)

		if social_system.reservation_book.is_reserved(character.id):
			continue

		var executor: ActionExecutor = _executors.get(character.id)
		if executor == null:
			executor = ActionExecutor.new(economy_system)
			_executors[character.id] = executor

		if executor.is_active():
			executor.advance(sim_delta)
			_handle_stuck_movement(character, executor)
			continue

		var candidates := _build_candidates(character)
		var choice := utility_ai.choose(character, candidates, _rng)
		if choice == null:
			character.current_action_id = &"idle"
			continue

		executor.start(choice, character)

	social_system.advance(_characters, relationship_graph, sim_delta, _rng)

	while _pending_economy_seconds >= ECONOMY_STEP_SECONDS:
		_processed_economy_seconds += ECONOMY_STEP_SECONDS
		_advance_economy(ECONOMY_STEP_SECONDS, _processed_economy_seconds)
		_pending_economy_seconds -= ECONOMY_STEP_SECONDS

func _advance_economy(
	sim_delta_seconds: float,
	simulation_seconds: float
) -> void:
	for character in _characters:
		if character == null:
			continue
		job_system.advance_character(
			character,
			sim_delta_seconds,
			simulation_seconds,
			economy_system
		)

	household_expense_system.advance(
		_characters,
		simulation_seconds,
		economy_system
	)

func _handle_stuck_movement(character: CharacterState, executor: ActionExecutor) -> void:
	if not executor.is_active():
		return

	var result := stuck_recovery_policy.evaluate(character.movement)
	if result != StuckRecoveryPolicy.RESULT_FAIL:
		return
	if character.movement.intent == null:
		return

	executor.report_movement_failure(character.movement.intent.target_object_id)

func _build_candidates(character: CharacterState) -> Array[ActionCandidate]:
	var candidates: Array[ActionCandidate] = []

	for object in _smart_objects:
		if object == null or not is_instance_valid(object):
			continue
		for interaction in object.list_interactions(character):
			if interaction == null:
				continue
			if not _is_money_eligible(character, interaction):
				continue
			var score := _score_interaction(character, interaction)
			if score <= 0.0:
				continue
			candidates.append(ActionCandidate.new(interaction.id, score, object, interaction))

	return candidates

func _is_money_eligible(
	character: CharacterState,
	interaction: InteractionDefinition
) -> bool:
	if (
		is_nan(interaction.money_cost)
		or is_inf(interaction.money_cost)
		or is_nan(interaction.money_reward)
		or is_inf(interaction.money_reward)
		or interaction.money_cost < 0.0
		or interaction.money_reward < 0.0
	):
		return false
	if is_nan(character.money) or is_inf(character.money) or character.money < 0.0:
		return false
	return character.money >= interaction.money_cost

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

	return spending_decision_system.adjust_score(character, interaction, score)

func _register_default_social_actions() -> void:
	var chat := SocialActionDefinition.new()
	chat.id = &"chat"
	chat.duration_sim_seconds = 20.0
	social_system.register_action(chat)

	var compliment := SocialActionDefinition.new()
	compliment.id = &"compliment"
	compliment.duration_sim_seconds = 20.0
	social_system.register_action(compliment)

	var argue := SocialActionDefinition.new()
	argue.id = &"argue"
	argue.duration_sim_seconds = 20.0
	social_system.register_action(argue)
