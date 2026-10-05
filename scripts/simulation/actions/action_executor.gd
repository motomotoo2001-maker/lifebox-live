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

func capture_state() -> Dictionary:
	if not is_active():
		return {"active": false}

	var target_object_id := ""
	var interaction_id := ""
	var arrival_radius := DEFAULT_ARRIVAL_RADIUS

	if _candidate.smart_object != null and is_instance_valid(_candidate.smart_object):
		target_object_id = str(_candidate.smart_object.object_id)
	if _candidate.interaction != null:
		interaction_id = str(_candidate.interaction.id)
	if _character.movement.intent != null:
		arrival_radius = _character.movement.intent.arrival_radius

	return {
		"active": true,
		"character_id": str(_character.id),
		"action_id": str(_candidate.id),
		"phase": str(_phase),
		"target_object_id": target_object_id,
		"interaction_id": interaction_id,
		"remaining_sim_seconds": _remaining_sim_seconds,
		"movement": {
			"elapsed_sim_seconds": _character.movement.elapsed_sim_seconds,
			"retry_count": _character.movement.retry_count,
			"arrival_radius": arrival_radius,
		},
	}

func restore_state(
	data: Dictionary,
	character: CharacterState,
	smart_object: SmartObject,
	interaction: InteractionDefinition
) -> bool:
	if not _validate_restore_state(data, character, smart_object, interaction):
		return false

	if is_active():
		cancel()

	if not smart_object.reserve(character.id):
		return false

	var movement_data: Dictionary = data["movement"]
	var arrival_radius := float(movement_data["arrival_radius"])
	var intent := MovementIntent.new(
		smart_object.object_id,
		smart_object.interaction_point,
		arrival_radius
	)
	if not intent.is_valid():
		smart_object.release(character.id)
		return false

	_candidate = ActionCandidate.new(
		StringName(data["action_id"]),
		0.0,
		smart_object,
		interaction
	)
	_character = character
	_character.current_action_id = StringName(data["action_id"])
	_phase = StringName(data["phase"])
	_remaining_sim_seconds = float(data["remaining_sim_seconds"])

	_character.movement.intent = intent
	_character.movement.elapsed_sim_seconds = float(
		movement_data["elapsed_sim_seconds"]
	)
	_character.movement.retry_count = int(movement_data["retry_count"])

	if _phase == PHASE_MOVING:
		_character.movement.status = MovementState.STATUS_MOVING
	else:
		_character.movement.status = MovementState.STATUS_ARRIVED

	return true

func _validate_restore_state(
	data: Dictionary,
	character: CharacterState,
	smart_object: SmartObject,
	interaction: InteractionDefinition
) -> bool:
	if character == null or smart_object == null or interaction == null:
		return false
	if not is_instance_valid(smart_object):
		return false
	if not data.get("active", false):
		return false

	for key in [
		"character_id",
		"action_id",
		"phase",
		"target_object_id",
		"interaction_id",
		"remaining_sim_seconds",
		"movement",
	]:
		if not data.has(key):
			return false

	if not data["character_id"] is String or data["character_id"].is_empty():
		return false
	if StringName(data["character_id"]) != character.id:
		return false
	if not data["action_id"] is String or data["action_id"].is_empty():
		return false
	if not data["phase"] is String:
		return false
	var phase := StringName(data["phase"])
	if phase != PHASE_MOVING and phase != PHASE_INTERACTING:
		return false

	if not data["target_object_id"] is String:
		return false
	if StringName(data["target_object_id"]) != smart_object.object_id:
		return false

	if not data["interaction_id"] is String:
		return false
	if StringName(data["interaction_id"]) != interaction.id:
		return false

	if not _is_finite_number(data["remaining_sim_seconds"]):
		return false
	var remaining := float(data["remaining_sim_seconds"])
	if phase == PHASE_MOVING:
		if remaining < 0.0:
			return false
	else:
		if remaining <= 0.0:
			return false

	if not data["movement"] is Dictionary:
		return false
	var movement_data: Dictionary = data["movement"]

	if (
		not movement_data.has("elapsed_sim_seconds")
		or not _is_finite_number(movement_data["elapsed_sim_seconds"])
		or float(movement_data["elapsed_sim_seconds"]) < 0.0
	):
		return false
	if (
		not movement_data.has("retry_count")
		or not movement_data["retry_count"] is int
		or int(movement_data["retry_count"]) < 0
	):
		return false
	if (
		not movement_data.has("arrival_radius")
		or not _is_finite_number(movement_data["arrival_radius"])
		or float(movement_data["arrival_radius"]) < 0.0
	):
		return false

	return true

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

func _is_finite_number(value) -> bool:
	if not (value is int or value is float):
		return false
	var number := float(value)
	return not is_nan(number) and not is_inf(number)
