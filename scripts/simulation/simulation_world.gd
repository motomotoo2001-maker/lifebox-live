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
var decision_bias_system := DecisionBiasSystem.new()
var daily_planning_system := DailyPlanningSystem.new()
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

func characters() -> Array[CharacterState]:
	return _characters.duplicate()

func get_character(character_id: StringName) -> CharacterState:
	for character in _characters:
		if character != null and character.id == character_id:
			return character
	return null

func get_smart_object(object_id: StringName) -> SmartObject:
	for object in _smart_objects:
		if object == null or not is_instance_valid(object):
			continue
		if object.object_id == object_id:
			return object
	return null

func get_action_executor(character_id: StringName) -> ActionExecutor:
	return _executors.get(character_id)


func capture_persistence_state() -> Dictionary:
	var residents: Array = []
	var actions: Array = []

	for character in _characters:
		if character == null:
			continue
		residents.append(CharacterSnapshotCodec.encode(character))

		var executor: ActionExecutor = _executors.get(character.id)
		if executor != null and executor.is_active():
			actions.append(executor.capture_state())

	return {
		"clock": clock.capture_state(),
		"runtime": {
			"pending_sim_seconds": _pending_sim_seconds,
			"processed_sim_seconds": _processed_sim_seconds,
			"pending_economy_seconds": _pending_economy_seconds,
			"processed_economy_seconds": _processed_economy_seconds,
		},
		"residents": residents,
		"actions": actions,
		"relationships": SocialEconomySnapshotCodec.encode_relationships(
			relationship_graph
		),
		"economy": economy_system.capture_persistence_state(),
		"household_expenses": household_expense_system.capture_persistence_state(),
		"social": social_system.capture_persistence_state(),
		"rng": {
			"seed": str(_rng.seed),
			"state": str(_rng.state),
		},
	}

func validate_persistence_state(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []

	for required_key in [
		"clock",
		"runtime",
		"residents",
		"actions",
		"relationships",
		"economy",
		"household_expenses",
		"social",
		"rng",
	]:
		if not data.has(required_key):
			errors.append("world snapshot missing %s" % required_key)

	if not errors.is_empty():
		return errors

	if not data["clock"] is Dictionary:
		errors.append("world clock must be a Dictionary")
	if not data["runtime"] is Dictionary:
		errors.append("world runtime must be a Dictionary")
	if not data["residents"] is Array:
		errors.append("world residents must be an Array")
	if not data["actions"] is Array:
		errors.append("world actions must be an Array")
	if not data["relationships"] is Array:
		errors.append("world relationships must be an Array")
	if not data["economy"] is Dictionary:
		errors.append("world economy must be a Dictionary")
	if not data["household_expenses"] is Dictionary:
		errors.append("world household_expenses must be a Dictionary")
	if not data["social"] is Dictionary:
		errors.append("world social must be a Dictionary")
	if not data["rng"] is Dictionary:
		errors.append("world rng must be a Dictionary")

	if not errors.is_empty():
		return errors

	var validation_clock := SimulationClock.new()
	if not validation_clock.restore_state(data["clock"]):
		errors.append("world clock state is invalid")

	_validate_runtime_state(
		data["runtime"],
		validation_clock.get_simulation_seconds(),
		errors
	)

	var decoded_residents: Array[CharacterState] = []
	var resident_ids: Dictionary = {}
	for index in range(data["residents"].size()):
		var raw_resident = data["residents"][index]
		if not raw_resident is Dictionary:
			errors.append("resident[%d] must be a Dictionary" % index)
			continue

		var resident_data: Dictionary = raw_resident
		var resident_errors := CharacterSnapshotCodec.validate(resident_data)
		for resident_error in resident_errors:
			errors.append("resident[%d]: %s" % [index, resident_error])
		if not resident_errors.is_empty():
			continue

		var resident_id: String = resident_data["id"]
		if resident_ids.has(resident_id):
			errors.append("duplicate resident id: %s" % resident_id)
			continue
		resident_ids[resident_id] = true

		var decoded := CharacterSnapshotCodec.decode_stable_state(resident_data)
		if decoded == null:
			errors.append("resident[%d] failed stable decode" % index)
			continue
		decoded_residents.append(decoded)

	for index in range(data["residents"].size()):
		var raw_resident = data["residents"][index]
		if not raw_resident is Dictionary:
			continue
		var goal_target_errors := CharacterSnapshotCodec.validate_goal_targets(
			raw_resident,
			resident_ids
		)
		for goal_target_error in goal_target_errors:
			errors.append(
				"resident[%d]: %s"
				% [index, goal_target_error]
			)

	if errors.is_empty():
		_validate_resident_planning_time(
			data["residents"],
			decoded_residents,
			data["runtime"],
			errors
		)

	var relationship_errors := SocialEconomySnapshotCodec.validate_relationships(
		data["relationships"],
		resident_ids
	)
	for relationship_error in relationship_errors:
		errors.append(relationship_error)

	var validation_economy := EconomySystem.new()
	if not validation_economy.restore_persistence_state(data["economy"]):
		errors.append("world economy state is invalid")

	var validation_expenses := HouseholdExpenseSystem.new()
	if not validation_expenses.restore_persistence_state(
		data["household_expenses"]
	):
		errors.append("world household expense state is invalid")

	_validate_rng_state(data["rng"], errors)

	if not errors.is_empty():
		return errors

	var validation_bundle := _build_validation_world(decoded_residents)
	var validation_world: SimulationWorld = validation_bundle["world"]
	var validation_objects: Array = validation_bundle["objects"]

	var action_errors := ActionSnapshotCodec.validate_collection(
		data["actions"],
		validation_world
	)
	for action_error in action_errors:
		errors.append(action_error)

	_validate_action_social_overlap(
		data["actions"],
		data["social"],
		errors
	)

	if not validation_world.social_system.restore_persistence_state(
		data["social"],
		decoded_residents
	):
		errors.append("world social runtime state is invalid")

	for object in validation_objects:
		if object != null and is_instance_valid(object):
			object.free()

	return errors

func restore_persistence_state(data: Dictionary) -> bool:
	if not validate_persistence_state(data).is_empty():
		return false

	var restored_residents: Array[CharacterState] = []
	for raw_resident in data["residents"]:
		var resident := CharacterSnapshotCodec.decode_stable_state(raw_resident)
		if resident == null:
			return false
		restored_residents.append(resident)

	var restored_relationships := RelationshipGraph.new()
	if not SocialEconomySnapshotCodec.restore_relationships(
		data["relationships"],
		restored_relationships
	):
		return false

	var restored_economy := EconomySystem.new()
	if not restored_economy.restore_persistence_state(data["economy"]):
		return false

	var restored_expenses := HouseholdExpenseSystem.new()
	if not restored_expenses.restore_persistence_state(
		data["household_expenses"]
	):
		return false

	var restored_clock := SimulationClock.new()
	if not restored_clock.restore_state(data["clock"]):
		return false

	_clear_runtime_before_restore()

	economy_system = restored_economy
	household_expense_system = restored_expenses
	relationship_graph = restored_relationships
	clock = restored_clock
	social_system = SocialSystem.new()
	_register_default_social_actions()

	_characters.clear()
	_executors.clear()
	for resident in restored_residents:
		if not add_character(resident):
			return false

	for raw_action in data["actions"]:
		if not ActionSnapshotCodec.restore(raw_action, self):
			return false

	if not social_system.restore_persistence_state(data["social"], _characters):
		return false

	var runtime: Dictionary = data["runtime"]
	_pending_sim_seconds = float(runtime["pending_sim_seconds"])
	_processed_sim_seconds = float(runtime["processed_sim_seconds"])
	_pending_economy_seconds = float(runtime["pending_economy_seconds"])
	_processed_economy_seconds = float(runtime["processed_economy_seconds"])

	var rng_data: Dictionary = data["rng"]
	_rng.seed = int(rng_data["seed"])
	_rng.state = int(rng_data["state"])

	return true

func _validate_resident_planning_time(
	resident_data_list: Array,
	decoded_residents: Array[CharacterState],
	runtime: Dictionary,
	errors: Array[String]
) -> void:
	if not runtime.has("processed_sim_seconds"):
		return
	if not _is_finite_non_negative_number(runtime["processed_sim_seconds"]):
		return

	var processed_sim_seconds := float(runtime["processed_sim_seconds"])
	var expected_day := int(floor(
		processed_sim_seconds / DailyPlanningSystem.DAY_SECONDS
	))
	var decoded_by_id: Dictionary = {}
	for resident in decoded_residents:
		if resident != null:
			decoded_by_id[str(resident.id)] = resident

	for index in range(resident_data_list.size()):
		var raw_resident = resident_data_list[index]
		if not raw_resident is Dictionary:
			continue
		var resident_id := str(raw_resident.get("id", ""))
		if not decoded_by_id.has(resident_id):
			continue
		var resident: CharacterState = decoded_by_id[resident_id]

		if raw_resident.has("schedule"):
			if resident.schedule.day_index != expected_day:
				errors.append(
					"resident[%d] schedule day does not match processed simulation day"
					% index
				)

			if processed_sim_seconds >= FIXED_SIM_STEP_SECONDS:
				var expected_block_id: StringName = &""
				if resident.schedule.definition != null:
					var day_seconds := fmod(
						processed_sim_seconds,
						DailyPlanningSystem.DAY_SECONDS
					)
					var hour := day_seconds / 3600.0
					var expected_block: ScheduleBlock = resident.schedule.definition.active_block_at(
						hour
					)
					if expected_block != null:
						expected_block_id = expected_block.id
				if resident.schedule.active_block_id != expected_block_id:
					errors.append(
						"resident[%d] active schedule block does not match processed simulation time"
						% index
					)

		if (
			processed_sim_seconds >= FIXED_SIM_STEP_SECONDS
			and raw_resident.has("goals")
			and resident.goals.day_index != expected_day
		):
			errors.append(
				"resident[%d] goal day does not match processed simulation day"
				% index
			)

func _validate_runtime_state(
	runtime: Dictionary,
	clock_simulation_seconds: float,
	errors: Array[String]
) -> void:
	for key in [
		"pending_sim_seconds",
		"processed_sim_seconds",
		"pending_economy_seconds",
		"processed_economy_seconds",
	]:
		if not runtime.has(key) or not _is_finite_non_negative_number(runtime[key]):
			errors.append("runtime %s must be finite and non-negative" % key)

	if not errors.is_empty():
		return

	var pending_sim := float(runtime["pending_sim_seconds"])
	var processed_sim := float(runtime["processed_sim_seconds"])
	var pending_economy := float(runtime["pending_economy_seconds"])
	var processed_economy := float(runtime["processed_economy_seconds"])

	if pending_sim >= FIXED_SIM_STEP_SECONDS + 0.000001:
		errors.append("runtime pending_sim_seconds exceeds fixed-step remainder")
	if pending_economy >= ECONOMY_STEP_SECONDS + 0.000001:
		errors.append("runtime pending_economy_seconds exceeds economy-step remainder")
	if processed_economy > processed_sim + 0.000001:
		errors.append("runtime processed_economy_seconds exceeds processed simulation")

	if absf((processed_sim + pending_sim) - clock_simulation_seconds) > 0.0001:
		errors.append("runtime simulation counters do not match clock")
	if absf((processed_economy + pending_economy) - processed_sim) > 0.0001:
		errors.append("runtime economy counters do not match processed simulation")

func _validate_rng_state(rng_data: Dictionary, errors: Array[String]) -> void:
	for key in ["seed", "state"]:
		if not rng_data.has(key) or not rng_data[key] is String:
			errors.append("rng %s must be a lossless integer string" % key)
			continue
		var value: String = rng_data[key]
		if value.is_empty() or not value.is_valid_int():
			errors.append("rng %s must be a valid integer string" % key)

func _validate_action_social_overlap(
	actions: Array,
	social_data: Dictionary,
	errors: Array[String]
) -> void:
	var action_residents: Dictionary = {}
	for raw_action in actions:
		if not raw_action is Dictionary:
			continue
		if not raw_action.get("active", false):
			continue
		if raw_action.has("character_id") and raw_action["character_id"] is String:
			action_residents[raw_action["character_id"]] = true

	if (
		not social_data.has("reservation_book")
		or not social_data["reservation_book"] is Dictionary
	):
		return
	var book: Dictionary = social_data["reservation_book"]
	if not book.has("sessions") or not book["sessions"] is Array:
		return

	for raw_session in book["sessions"]:
		if not raw_session is Dictionary:
			continue
		for id_key in ["initiator_id", "target_id"]:
			if raw_session.has(id_key) and raw_session[id_key] is String:
				var resident_id: String = raw_session[id_key]
				if action_residents.has(resident_id):
					errors.append(
						"resident cannot have active SmartObject and social action: %s"
						% resident_id
					)

func _build_validation_world(
	residents: Array[CharacterState]
) -> Dictionary:
	var validation_world := SimulationWorld.new()
	var validation_objects: Array = []

	for source_object in _smart_objects:
		if source_object == null or not is_instance_valid(source_object):
			continue

		var clone := SmartObject.new()
		clone.object_id = source_object.object_id
		clone.interaction_point = source_object.interaction_point
		for interaction in source_object.interactions:
			clone.interactions.append(interaction)
		validation_world.register_smart_object(clone)
		validation_objects.append(clone)

	for resident in residents:
		validation_world.add_character(resident)

	return {
		"world": validation_world,
		"objects": validation_objects,
	}

func _clear_runtime_before_restore() -> void:
	for raw_executor in _executors.values():
		if raw_executor is ActionExecutor:
			var executor: ActionExecutor = raw_executor
			if executor.is_active():
				executor.cancel()

	for object in _smart_objects:
		if object != null and is_instance_valid(object):
			object.clear_reservation()

func _is_finite_non_negative_number(value) -> bool:
	if not (value is int or value is float):
		return false
	var number := float(value)
	return not is_nan(number) and not is_inf(number) and number >= 0.0

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
	daily_planning_system.advance(
		self,
		_processed_sim_seconds,
		_rng
	)

	for character in _characters:
		if character == null:
			continue
		need_system.advance_character(character, sim_delta)

	# Social decisions get a deterministic scheduling window before idle
	# residents commit to SmartObject actions. Existing active sessions are
	# advanced here as well, so their participants remain reserved below.
	social_system.advance(_characters, relationship_graph, sim_delta, _rng)

	for character in _characters:
		if character == null:
			continue

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

	var spending_score := spending_decision_system.adjust_score(
		character,
		interaction,
		score
	)
	return decision_bias_system.adjust(
		character,
		interaction,
		spending_score,
		_processed_sim_seconds,
		relationship_graph
	)

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
