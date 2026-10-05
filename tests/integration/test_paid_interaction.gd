extends RefCounted

const WORLD_PATH := "res://scripts/simulation/simulation_world.gd"
const CHARACTER_PATH := "res://scripts/simulation/characters/character_state.gd"
const INTERACTION_PATH := "res://scripts/simulation/interactions/interaction_definition.gd"
const SMART_OBJECT_PATH := "res://scripts/simulation/interactions/smart_object.gd"
const ACTION_EXECUTOR_PATH := "res://scripts/simulation/actions/action_executor.gd"
const ACTION_CANDIDATE_PATH := "res://scripts/simulation/utility_ai/action_candidate.gd"
const ECONOMY_PATH := "res://scripts/simulation/economy/economy_system.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	var world_script := load(WORLD_PATH)
	var character_script := load(CHARACTER_PATH)
	var interaction_script := load(INTERACTION_PATH)
	var smart_object_script := load(SMART_OBJECT_PATH)
	var executor_script := load(ACTION_EXECUTOR_PATH)
	var candidate_script := load(ACTION_CANDIDATE_PATH)
	var economy_script := load(ECONOMY_PATH)
	if (
		world_script == null
		or character_script == null
		or interaction_script == null
		or smart_object_script == null
		or executor_script == null
		or candidate_script == null
		or economy_script == null
	):
		failures.append("paid interaction dependencies must load")
		return failures

	var probe = interaction_script.new()
	var property_names: Array[StringName] = []
	for property in probe.get_property_list():
		property_names.append(StringName(property["name"]))
	if &"money_cost" not in property_names:
		failures.append("InteractionDefinition must expose money_cost")
		return failures
	if &"money_reward" not in property_names:
		failures.append("InteractionDefinition must expose money_reward")
		return failures

	_test_unaffordable_action(
		failures,
		world_script,
		character_script,
		interaction_script,
		smart_object_script
	)
	_test_successful_paid_action(
		failures,
		world_script,
		character_script,
		interaction_script,
		smart_object_script
	)
	_test_failed_and_cancelled_action(
		failures,
		character_script,
		interaction_script,
		smart_object_script,
		executor_script,
		candidate_script,
		economy_script
	)
	_test_reward_action(
		failures,
		world_script,
		character_script,
		interaction_script,
		smart_object_script
	)

	return failures

func _test_unaffordable_action(
	failures: Array[String],
	world_script,
	character_script,
	interaction_script,
	smart_object_script
) -> void:
	var world = world_script.new()
	var resident = character_script.new(&"poor_resident", "Poor Resident")
	resident.money = 5.0
	resident.needs.hunger.value = 10.0
	_disable_decay(resident)
	world.add_character(resident)

	var paid_meal = interaction_script.new()
	paid_meal.id = &"buy_meal"
	paid_meal.duration_sim_seconds = 1.0
	paid_meal.need_effects = {"hunger": 50.0}
	paid_meal.money_cost = 10.0

	var cafe = smart_object_script.new()
	cafe.object_id = &"cafe"
	cafe.interaction_point = Vector3(1.0, 0.0, 0.0)
	cafe.interactions.append(paid_meal)
	world.register_smart_object(cafe)

	world.step(1.0)
	if resident.current_action_id != &"idle":
		failures.append("unaffordable paid interaction must not become an action candidate")
	if not cafe.is_available_for(&"reservation_probe"):
		failures.append("unaffordable interaction must not reserve SmartObject")
	if not is_equal_approx(resident.money, 5.0):
		failures.append("unaffordable candidate rejection must not change money")

	cafe.free()

func _test_successful_paid_action(
	failures: Array[String],
	world_script,
	character_script,
	interaction_script,
	smart_object_script
) -> void:
	var world = world_script.new()
	var resident = character_script.new(&"buyer", "Buyer")
	resident.money = 20.0
	resident.needs.hunger.value = 10.0
	_disable_decay(resident)
	world.add_character(resident)

	var paid_meal = interaction_script.new()
	paid_meal.id = &"buy_meal"
	paid_meal.duration_sim_seconds = 1.0
	paid_meal.need_effects = {"hunger": 50.0}
	paid_meal.money_cost = 10.0

	var cafe = smart_object_script.new()
	cafe.object_id = &"cafe_paid"
	cafe.interaction_point = Vector3(1.0, 0.0, 0.0)
	cafe.interactions.append(paid_meal)
	world.register_smart_object(cafe)

	world.step(1.0)
	if resident.current_action_id != &"buy_meal":
		failures.append("affordable paid interaction must be selectable")
	if not is_equal_approx(resident.money, 20.0):
		failures.append("money must not be charged while resident is only moving")

	var hunger_before: float = resident.needs.hunger.value
	world.report_arrival(resident.id, cafe.object_id)
	if not is_equal_approx(resident.money, 20.0):
		failures.append("arrival alone must not charge paid interaction")
	world.step(1.0)

	if not is_equal_approx(resident.money, 10.0):
		failures.append("successful paid interaction must charge exact cost on completion")
	if resident.needs.hunger.value <= hunger_before:
		failures.append("successful paid interaction must apply need effects")
	if not cafe.is_available_for(&"reservation_probe"):
		failures.append("successful paid interaction must release SmartObject")

	cafe.free()

func _test_failed_and_cancelled_action(
	failures: Array[String],
	character_script,
	interaction_script,
	smart_object_script,
	executor_script,
	candidate_script,
	economy_script
) -> void:
	var resident = character_script.new(&"cancel_buyer", "Cancel Buyer")
	resident.money = 20.0
	resident.needs.hunger.value = 10.0
	_disable_decay(resident)

	var paid_meal = interaction_script.new()
	paid_meal.id = &"buy_cancelled"
	paid_meal.duration_sim_seconds = 5.0
	paid_meal.need_effects = {"hunger": 50.0}
	paid_meal.money_cost = 10.0
	paid_meal.money_reward = 3.0

	var cafe = smart_object_script.new()
	cafe.object_id = &"cancel_cafe"
	cafe.interaction_point = Vector3(1.0, 0.0, 0.0)
	cafe.interactions.append(paid_meal)

	var candidate = candidate_script.new(&"buy_cancelled", 100.0, cafe, paid_meal)
	var economy = economy_script.new()
	var executor = executor_script.new(economy)

	var money_before: float = resident.money
	var hunger_before: float = resident.needs.hunger.value
	if not executor.start(candidate, resident):
		failures.append("paid ActionExecutor setup must start")
	else:
		executor.cancel()

	if not is_equal_approx(resident.money, money_before):
		failures.append("cancelled paid interaction must not charge or reward")
	if not is_equal_approx(resident.needs.hunger.value, hunger_before):
		failures.append("cancelled paid interaction must not apply need effects")
	if economy.transactions().size() != 0:
		failures.append("cancelled paid interaction must create no economy transaction")

	if not executor.start(candidate, resident):
		failures.append("paid action must restart for movement failure test")
	else:
		executor.report_movement_failure(cafe.object_id)

	if not is_equal_approx(resident.money, money_before):
		failures.append("movement-failed paid interaction must not charge or reward")
	if economy.transactions().size() != 0:
		failures.append("movement-failed paid interaction must create no economy transaction")

	cafe.free()

func _test_reward_action(
	failures: Array[String],
	world_script,
	character_script,
	interaction_script,
	smart_object_script
) -> void:
	var world = world_script.new()
	var resident = character_script.new(&"worker_action", "Worker Action")
	resident.money = 0.0
	resident.needs.comfort.value = 10.0
	_disable_decay(resident)
	world.add_character(resident)

	var work = interaction_script.new()
	work.id = &"quick_job"
	work.duration_sim_seconds = 1.0
	work.need_effects = {"comfort": 10.0}
	work.money_reward = 30.0

	var desk = smart_object_script.new()
	desk.object_id = &"work_desk"
	desk.interaction_point = Vector3(-1.0, 0.0, 0.0)
	desk.interactions.append(work)
	world.register_smart_object(desk)

	world.step(1.0)
	if resident.current_action_id != &"quick_job":
		failures.append("reward interaction must be selectable when it has utility")
	if not is_equal_approx(resident.money, 0.0):
		failures.append("reward must not be credited before completion")

	world.report_arrival(resident.id, desk.object_id)
	world.step(1.0)
	if not is_equal_approx(resident.money, 30.0):
		failures.append("successful reward interaction must credit exact reward on completion")

	desk.free()

func _disable_decay(resident) -> void:
	for need_name in ["hunger", "energy", "hygiene", "comfort", "social", "mood"]:
		resident.needs.get(need_name).decay_per_sim_hour = 0.0
