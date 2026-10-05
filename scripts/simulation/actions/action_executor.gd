class_name ActionExecutor
extends RefCounted

const PHASE_IDLE: StringName = &"idle"
const PHASE_MOVING: StringName = &"moving"
const PHASE_INTERACTING: StringName = &"interacting"
const DEFAULT_ARRIVAL_RADIUS := 0.5

var _candidate: ActionCandidate
var _character: CharacterState
var _economy_system: EconomySystem
var _remaining_sim_seconds: float = 0.0
var _phase: StringName = PHASE_IDLE

func _init(new_economy_system: EconomySystem = null) -> void:
	_economy_system = new_economy_system

func is_active() -> bool:
	return _candidate != null and _character != null

func start(candidate: ActionCandidate, character: CharacterState) -> bool:
	if candidate == null or character == null or is_active():
		return false

	if candidate.id == &"idle":
		character.current_action_id = &"idle"
		return true

	if not _can_execute_money_terms(candidate.interaction, character):
		return false

	if candidate.smart_object != null:
		if not is_instance_valid(candidate.smart_object):
			return false
		if not candidate.smart_object.reserve(character.id):
			return false

	_candidate = candidate
	_character = character
	_character.current_action_id = candidate.id
	_remaining_sim_seconds = 0.0

	if candidate.smart_object != null:
		var intent := MovementIntent.new(
			candidate.smart_object.object_id,
			candidate.smart_object.interaction_point,
			DEFAULT_ARRIVAL_RADIUS
		)
		if not _character.movement.begin(intent):
			_release_reservation()
			_character.current_action_id = &"idle"
			_clear()
			return false
		_phase = PHASE_MOVING
		return true

	_begin_interaction()
	return true

func advance(sim_delta_seconds: float) -> bool:
	if not is_active():
		return false
	if is_nan(sim_delta_seconds) or is_inf(sim_delta_seconds) or sim_delta_seconds <= 0.0:
		return false

	if _phase == PHASE_MOVING:
		_character.movement.advance_elapsed(sim_delta_seconds)
		return false

	if _phase != PHASE_INTERACTING:
		return false

	_remaining_sim_seconds -= sim_delta_seconds
	if _remaining_sim_seconds > 0.0:
		return false

	_complete()
	return true

func report_arrival(target_object_id: StringName) -> bool:
	if not is_active() or _phase != PHASE_MOVING:
		return false
	if _character.movement.intent == null:
		return false
	if _character.movement.intent.target_object_id != target_object_id:
		return false

	_character.movement.mark_arrived()
	_begin_interaction()
	return true

func report_movement_failure(target_object_id: StringName) -> bool:
	if not is_active() or _phase != PHASE_MOVING:
		return false
	if _character.movement.intent == null:
		return false
	if _character.movement.intent.target_object_id != target_object_id:
		return false

	_character.movement.mark_failed()
	_release_reservation()
	_character.current_action_id = &"idle"
	_clear()
	return true

func cancel() -> void:
	if not is_active():
		return
	_release_reservation()
	_character.current_action_id = &"idle"
	_character.movement.reset()
	_clear()

func _begin_interaction() -> void:
	_phase = PHASE_INTERACTING
	_remaining_sim_seconds = 0.0
	if _candidate != null and _candidate.interaction != null:
		_remaining_sim_seconds = maxf(_candidate.interaction.duration_sim_seconds, 0.0)

	if _remaining_sim_seconds <= 0.0:
		_complete()

func _complete() -> void:
	if _candidate != null and _candidate.interaction != null:
		if _settle_cost(_candidate.interaction):
			_apply_need_effects(_candidate.interaction.need_effects)
			_apply_reward(_candidate.interaction)

	_release_reservation()
	_character.current_action_id = &"idle"
	_character.movement.reset()
	_clear()

func _settle_cost(interaction: InteractionDefinition) -> bool:
	if interaction.money_cost <= 0.0:
		return true
	if _economy_system == null:
		return false
	return _economy_system.spend(_character, interaction.money_cost) != null

func _apply_reward(interaction: InteractionDefinition) -> void:
	if interaction.money_reward <= 0.0:
		return
	if _economy_system == null:
		return
	_economy_system.deposit(_character, interaction.money_reward)

func _can_execute_money_terms(
	interaction: InteractionDefinition,
	character: CharacterState
) -> bool:
	if interaction == null:
		return true
	if (
		is_nan(interaction.money_cost)
		or is_inf(interaction.money_cost)
		or is_nan(interaction.money_reward)
		or is_inf(interaction.money_reward)
		or interaction.money_cost < 0.0
		or interaction.money_reward < 0.0
	):
		return false
	if interaction.money_cost <= 0.0 and interaction.money_reward <= 0.0:
		return true
	if _economy_system == null:
		return false
	if is_nan(character.money) or is_inf(character.money) or character.money < 0.0:
		return false
	return character.money >= interaction.money_cost

func _apply_need_effects(effects: Dictionary) -> void:
	for need_key in effects:
		var need_state = _character.needs.get(str(need_key))
		if need_state == null:
			continue
		var amount = effects[need_key]
		if amount is float or amount is int:
			need_state.apply_delta(float(amount))

func _release_reservation() -> void:
	if _candidate == null or _candidate.smart_object == null or _character == null:
		return
	if is_instance_valid(_candidate.smart_object):
		_candidate.smart_object.release(_character.id)

func _clear() -> void:
	_candidate = null
	_character = null
	_remaining_sim_seconds = 0.0
	_phase = PHASE_IDLE
