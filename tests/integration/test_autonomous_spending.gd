extends RefCounted

const SPENDING_PATH := "res://scripts/simulation/economy/spending_decision_system.gd"
const WORLD_PATH := "res://scripts/simulation/simulation_world.gd"
const CHARACTER_PATH := "res://scripts/simulation/characters/character_state.gd"
const INTERACTION_PATH := "res://scripts/simulation/interactions/interaction_definition.gd"
const SMART_OBJECT_PATH := "res://scripts/simulation/interactions/smart_object.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	if not FileAccess.file_exists(SPENDING_PATH):
		failures.append("SpendingDecisionSystem must exist at %s" % SPENDING_PATH)
		return failures

	var spending_script := load(SPENDING_PATH)
	var world_script := load(WORLD_PATH)
	var character_script := load(CHARACTER_PATH)
	var interaction_script := load(INTERACTION_PATH)
	var smart_object_script := load(SMART_OBJECT_PATH)
	if spending_script == null or world_script == null or character_script == null or interaction_script == null or smart_object_script == null:
		failures.append("autonomous spending dependencies must load")
		return failures

	_test_personality_bias(
		failures,
		spending_script,
		character_script,
		interaction_script
	)
	_test_free_vs_paid_choice(
		failures,
		world_script,
		character_script,
		interaction_script,
		smart_object_script
	)
	_test_same_seed_tie_resolution(
		failures,
		world_script,
		character_script,
		interaction_script,
		smart_object_script
	)

	return failures

func _test_personality_bias(
	failures: Array[String],
	spending_script,
	character_script,
	interaction_script
) -> void:
	var system = spending_script.new()
	var paid = interaction_script.new()
	paid.id = &"paid_meal"
	paid.money_cost = 20.0
	paid.need_effects = {"hunger": 50.0}

	var impulsive = character_script.new(&"impulsive", "Impulsive")
	impulsive.money = 100.0
	impulsive.needs.hunger.value = 10.0
	impulsive.personality.impulsiveness = 1.0

	var cautious = character_script.new(&"cautious", "Cautious")
	cautious.money = 100.0
	cautious.needs.hunger.value = 10.0
	cautious.personality.impulsiveness = 0.0

	var base_score := 100.0
	var impulsive_score: float = system.adjust_score(impulsive, paid, base_score)
	var cautious_score: float = system.adjust_score(cautious, paid, base_score)

	if impulsive_score <= cautious_score:
		failures.append("higher impulsiveness must increase willingness to choose affordable paid interaction")
	if impulsive_score <= base_score:
		failures.append("urgent need + high impulsiveness may bias paid interaction above equal free option")
	if cautious_score >= base_score:
		failures.append("cautious resident should prefer equal free option over paid interaction")

	var poor = character_script.new(&"poor", "Poor")
	poor.money = 5.0
	poor.needs.hunger.value = 0.0
	poor.personality.impulsiveness = 1.0
	if system.adjust_score(poor, paid, base_score) > 0.0:
		failures.append("unaffordable paid interaction must receive no eligible score")

	var satisfied = character_script.new(&"satisfied", "Satisfied")
	satisfied.money = 100.0
	satisfied.needs.hunger.value = 100.0
	satisfied.personality.impulsiveness = 1.0
	if not is_equal_approx(system.adjust_score(satisfied, paid, 0.0), 0.0):
		failures.append("zero base utility must remain zero to prevent compulsive repeat purchases")

func _test_free_vs_paid_choice(
	failures: Array[String],
	world_script,
	character_script,
	interaction_script,
	smart_object_script
) -> void:
	var impulsive_world = world_script.new()
	var impulsive = character_script.new(&"buyer_impulsive", "Buyer Impulsive")
	impulsive.money = 100.0
	impulsive.needs.hunger.value = 5.0
	impulsive.personality.impulsiveness = 1.0
	_disable_decay(impulsive)
	impulsive_world.add_character(impulsive)

	var free_meal = interaction_script.new()
	free_meal.id = &"free_meal"
	free_meal.duration_sim_seconds = 1.0
	free_meal.need_effects = {"hunger": 100.0}

	var paid_meal = interaction_script.new()
	paid_meal.id = &"paid_meal"
	paid_meal.duration_sim_seconds = 1.0
	paid_meal.need_effects = {"hunger": 100.0}
	paid_meal.money_cost = 20.0

	var free_table = smart_object_script.new()
	free_table.object_id = &"free_table"
	free_table.interaction_point = Vector3(-1.0, 0.0, 0.0)
	free_table.interactions.append(free_meal)
	impulsive_world.register_smart_object(free_table)

	var paid_table = smart_object_script.new()
	paid_table.object_id = &"paid_table"
	paid_table.interaction_point = Vector3(1.0, 0.0, 0.0)
	paid_table.interactions.append(paid_meal)
	impulsive_world.register_smart_object(paid_table)

	impulsive_world.step(1.0)
	if impulsive.current_action_id != &"paid_meal":
		failures.append("highly impulsive resident with urgent need and enough money should prefer paid option")

	impulsive_world.report_arrival(impulsive.id, paid_table.object_id)
	impulsive_world.step(1.0)
	if not is_equal_approx(impulsive.money, 80.0):
		failures.append("chosen paid option must charge exact cost")

	impulsive_world.step(1.0)
	if impulsive.current_action_id == &"paid_meal":
		failures.append("satisfied resident must not immediately repeat paid purchase")

	free_table.free()
	paid_table.free()

	var cautious_world = world_script.new()
	var cautious = character_script.new(&"buyer_cautious", "Buyer Cautious")
	cautious.money = 100.0
	cautious.needs.hunger.value = 5.0
	cautious.personality.impulsiveness = 0.0
	_disable_decay(cautious)
	cautious_world.add_character(cautious)

	var free_table_2 = smart_object_script.new()
	free_table_2.object_id = &"free_table_2"
	free_table_2.interaction_point = Vector3(-1.0, 0.0, 0.0)
	free_table_2.interactions.append(free_meal)
	cautious_world.register_smart_object(free_table_2)

	var paid_table_2 = smart_object_script.new()
	paid_table_2.object_id = &"paid_table_2"
	paid_table_2.interaction_point = Vector3(1.0, 0.0, 0.0)
	paid_table_2.interactions.append(paid_meal)
	cautious_world.register_smart_object(paid_table_2)

	cautious_world.step(1.0)
	if cautious.current_action_id != &"free_meal":
		failures.append("cautious resident should prefer equally useful free alternative")

	free_table_2.free()
	paid_table_2.free()

func _test_same_seed_tie_resolution(
	failures: Array[String],
	world_script,
	character_script,
	interaction_script,
	smart_object_script
) -> void:
	var first = _build_tie_world(world_script, character_script, interaction_script, smart_object_script)
	var second = _build_tie_world(world_script, character_script, interaction_script, smart_object_script)

	first["world"].step(1.0)
	second["world"].step(1.0)

	if first["resident"].current_action_id != second["resident"].current_action_id:
		failures.append("same fixed seed must resolve equal paid-option ties identically")

	for object in first["objects"]:
		object.free()
	for object in second["objects"]:
		object.free()

func _build_tie_world(
	world_script,
	character_script,
	interaction_script,
	smart_object_script
) -> Dictionary:
	var world = world_script.new()
	var resident = character_script.new(&"tie_resident", "Tie Resident")
	resident.money = 100.0
	resident.needs.hunger.value = 0.0
	resident.personality.impulsiveness = 1.0
	_disable_decay(resident)
	world.add_character(resident)

	var objects: Array = []
	for suffix in ["a", "b"]:
		var interaction = interaction_script.new()
		interaction.id = StringName("paid_%s" % suffix)
		interaction.duration_sim_seconds = 1.0
		interaction.need_effects = {"hunger": 100.0}
		interaction.money_cost = 10.0

		var object = smart_object_script.new()
		object.object_id = StringName("vendor_%s" % suffix)
		object.interaction_point = Vector3.ZERO
		object.interactions.append(interaction)
		world.register_smart_object(object)
		objects.append(object)

	return {
		"world": world,
		"resident": resident,
		"objects": objects,
	}

func _disable_decay(resident) -> void:
	for need_name in ["hunger", "energy", "hygiene", "comfort", "social", "mood"]:
		resident.needs.get(need_name).decay_per_sim_hour = 0.0
