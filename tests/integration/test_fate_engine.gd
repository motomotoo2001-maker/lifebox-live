extends RefCounted

const DEFINITION_PATH := "res://scripts/simulation/fate/fate_definition.gd"
const RESULT_PATH := "res://scripts/simulation/fate/fate_result.gd"
const ENGINE_PATH := "res://scripts/simulation/fate/fate_engine.gd"
const CHARACTER_PATH := "res://scripts/simulation/characters/character_state.gd"
const RELATIONSHIP_GRAPH_PATH := "res://scripts/simulation/relationships/relationship_graph.gd"
const ECONOMY_PATH := "res://scripts/simulation/economy/economy_system.gd"
const CHAOS_PATH := "res://scripts/simulation/fate/chaos_meter.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	for path in [DEFINITION_PATH, RESULT_PATH, ENGINE_PATH]:
		if not FileAccess.file_exists(path):
			failures.append("Fate Engine dependency must exist at %s" % path)
			return failures

	var definition_script = load(DEFINITION_PATH)
	var result_script = load(RESULT_PATH)
	var engine_script = load(ENGINE_PATH)
	var character_script = load(CHARACTER_PATH)
	var relationship_graph_script = load(RELATIONSHIP_GRAPH_PATH)
	var economy_script = load(ECONOMY_PATH)
	var chaos_script = load(CHAOS_PATH)
	for script in [
		definition_script,
		result_script,
		engine_script,
		character_script,
		relationship_graph_script,
		economy_script,
		chaos_script,
	]:
		if script == null or not script.can_instantiate():
			failures.append("Fate Engine dependencies must load and instantiate")
			return failures

	_test_deterministic_weighted_selection(
		failures,
		definition_script,
		engine_script,
		character_script,
		relationship_graph_script,
		economy_script,
		chaos_script
	)
	_test_target_modes_and_effects(
		failures,
		definition_script,
		engine_script,
		character_script,
		relationship_graph_script,
		economy_script,
		chaos_script
	)
	_test_cooldown_and_no_eligible(
		failures,
		definition_script,
		engine_script,
		character_script,
		relationship_graph_script,
		economy_script,
		chaos_script
	)
	_test_malformed_effect_is_atomic(
		failures,
		definition_script,
		engine_script,
		character_script,
		relationship_graph_script,
		economy_script,
		chaos_script
	)

	return failures

func _test_deterministic_weighted_selection(
	failures: Array[String],
	definition_script,
	engine_script,
	character_script,
	relationship_graph_script,
	economy_script,
	chaos_script
) -> void:
	var residents_a := _residents(character_script)
	var residents_b := _residents(character_script)
	var engine_a = engine_script.new()
	var engine_b = engine_script.new()

	var calm = _definition(
		definition_script,
		&"calm_bonus",
		&"micro",
		&"legendary",
		1.0,
		0.0,
		&"random_resident",
		"",
		[
			{"kind":"need_delta", "need":"mood", "delta":5.0},
		]
	)
	var lucky = _definition(
		definition_script,
		&"lucky_cash",
		&"micro",
		&"legendary",
		3.0,
		0.0,
		&"random_resident",
		"",
		[
			{"kind":"money_delta", "delta":10.0},
		]
	)

	for engine in [engine_a, engine_b]:
		if not engine.register_definition(calm):
			failures.append("valid calm fate must register")
			return
		if not engine.register_definition(lucky):
			failures.append("valid lucky fate must register")
			return

	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 9911
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 9911

	var result_a = engine_a.resolve(
		&"small",
		residents_a,
		relationship_graph_script.new(),
		economy_script.new(),
		chaos_script.new(),
		100.0,
		rng_a
	)
	var result_b = engine_b.resolve(
		&"small",
		residents_b,
		relationship_graph_script.new(),
		economy_script.new(),
		chaos_script.new(),
		100.0,
		rng_b
	)

	if not result_a.applied or not result_b.applied:
		failures.append("eligible weighted Fate resolution must apply")
		return
	if result_a.definition_id != result_b.definition_id:
		failures.append("same seed/state must choose the same Fate definition")
	if result_a.target_resident_ids != result_b.target_resident_ids:
		failures.append("same seed/state must choose the same Fate target")

func _test_target_modes_and_effects(
	failures: Array[String],
	definition_script,
	engine_script,
	character_script,
	relationship_graph_script,
	economy_script,
	chaos_script
) -> void:
	var residents := _residents(character_script)
	residents[0].needs.hunger.value = 70.0
	residents[1].needs.hunger.value = 10.0
	residents[2].needs.hunger.value = 40.0
	for resident in residents:
		resident.money = 50.0

	var relationships = relationship_graph_script.new()
	relationships.get_or_create(&"resident_a", &"resident_b").apply_delta(20.0, 0.0, 0.0)
	relationships.get_or_create(&"resident_b", &"resident_a").apply_delta(20.0, 0.0, 0.0)
	relationships.get_or_create(&"resident_a", &"resident_c").apply_delta(80.0, 0.0, 0.0)
	relationships.get_or_create(&"resident_c", &"resident_a").apply_delta(80.0, 0.0, 0.0)

	var economy = economy_script.new()
	var chaos = chaos_script.new()
	chaos.apply_delta(25.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12

	var lowest_engine = engine_script.new()
	var lowest = _definition(
		definition_script,
		&"feed_hungriest",
		&"small",
		&"legendary",
		1.0,
		0.0,
		&"lowest_need_resident",
		"hunger",
		[
			{"kind":"need_delta", "need":"hunger", "delta":30.0},
			{"kind":"money_delta", "delta":15.0},
			{"kind":"chaos_delta", "delta":5.0},
		]
	)
	lowest_engine.register_definition(lowest)
	var lowest_result = lowest_engine.resolve(
		&"small",
		residents,
		relationships,
		economy,
		chaos,
		0.0,
		rng
	)
	if not lowest_result.applied:
		failures.append("lowest-need fate must apply")
	else:
		if lowest_result.target_resident_ids != [&"resident_b"]:
			failures.append("lowest_need_resident must target resident with lowest named need")
		if not is_equal_approx(residents[1].needs.hunger.value, 40.0):
			failures.append("need_delta must apply to selected resident")
		if not is_equal_approx(residents[1].money, 65.0):
			failures.append("positive money_delta must deposit to selected resident")
		if not is_equal_approx(chaos.value, 30.0):
			failures.append("chaos_delta must apply through ChaosMeter")

	var pair_engine = engine_script.new()
	var pair_fate = _definition(
		definition_script,
		&"bond_pair",
		&"medium",
		&"legendary",
		1.0,
		0.0,
		&"highest_relationship_pair",
		"",
		[
			{
				"kind":"relationship_delta",
				"affinity":5.0,
				"trust":3.0,
				"tension":-2.0,
			},
		]
	)
	pair_engine.register_definition(pair_fate)
	var pair_result = pair_engine.resolve(
		&"medium",
		residents,
		relationships,
		economy,
		chaos,
		10.0,
		rng
	)
	if not pair_result.applied:
		failures.append("highest-relationship pair fate must apply")
	else:
		if pair_result.target_resident_ids != [&"resident_a", &"resident_c"]:
			failures.append("highest_relationship_pair must deterministically choose strongest pair")
		var a_to_c = relationships.get_relationship(&"resident_a", &"resident_c")
		var c_to_a = relationships.get_relationship(&"resident_c", &"resident_a")
		if not is_equal_approx(a_to_c.affinity, 85.0):
			failures.append("relationship_delta must update first direction")
		if not is_equal_approx(c_to_a.affinity, 85.0):
			failures.append("relationship_delta must update reverse direction")

	var household_engine = engine_script.new()
	var household = _definition(
		definition_script,
		&"household_cost",
		&"large",
		&"legendary",
		1.0,
		0.0,
		&"household",
		"",
		[
			{"kind":"money_delta", "delta":-5.0},
			{"kind":"need_delta", "need":"mood", "delta":2.0},
		]
	)
	household_engine.register_definition(household)
	var before_balances: Array[float] = []
	for resident in residents:
		before_balances.append(resident.money)
	var household_result = household_engine.resolve(
		&"large",
		residents,
		relationships,
		economy,
		chaos,
		20.0,
		rng
	)
	if not household_result.applied:
		failures.append("household Fate must apply")
	else:
		if household_result.target_resident_ids.size() != 3:
			failures.append("household target must include every resident")
		for index in range(residents.size()):
			if not is_equal_approx(residents[index].money, before_balances[index] - 5.0):
				failures.append("household money_delta must apply to every resident")

func _test_cooldown_and_no_eligible(
	failures: Array[String],
	definition_script,
	engine_script,
	character_script,
	relationship_graph_script,
	economy_script,
	chaos_script
) -> void:
	var residents := _residents(character_script)
	var engine = engine_script.new()
	var definition = _definition(
		definition_script,
		&"cooldown_fate",
		&"medium",
		&"legendary",
		1.0,
		60.0,
		&"random_resident",
		"",
		[
			{"kind":"need_delta", "need":"mood", "delta":5.0},
		]
	)
	engine.register_definition(definition)

	var rng := RandomNumberGenerator.new()
	rng.seed = 44
	var relationships = relationship_graph_script.new()
	var economy = economy_script.new()
	var chaos = chaos_script.new()

	var first = engine.resolve(
		&"medium", residents, relationships, economy, chaos, 10.0, rng
	)
	if not first.applied:
		failures.append("first cooldown fate must apply")
		return

	var blocked = engine.resolve(
		&"medium", residents, relationships, economy, chaos, 69.0, rng
	)
	if blocked.applied:
		failures.append("Fate must remain blocked before cooldown expiry")

	var resumed = engine.resolve(
		&"medium", residents, relationships, economy, chaos, 70.0, rng
	)
	if not resumed.applied:
		failures.append("Fate must become eligible at cooldown expiry")

	var none = engine.resolve(
		&"micro", residents, relationships, economy, chaos, 1000.0, rng
	)
	if none.applied:
		failures.append("tier with no eligible Fate must return no-op")
	if none.reason != &"no_eligible_fate":
		failures.append("no eligible Fate must expose no_eligible_fate reason")

func _test_malformed_effect_is_atomic(
	failures: Array[String],
	definition_script,
	engine_script,
	character_script,
	relationship_graph_script,
	economy_script,
	chaos_script
) -> void:
	var residents := _residents(character_script)
	residents[0].money = 20.0
	residents[0].needs.mood.value = 50.0
	var relationships = relationship_graph_script.new()
	var economy = economy_script.new()
	var chaos = chaos_script.new()
	chaos.apply_delta(10.0)

	var malformed = _definition(
		definition_script,
		&"atomic_bad",
		&"micro",
		&"legendary",
		1.0,
		0.0,
		&"random_resident",
		"",
		[
			{"kind":"money_delta", "delta":5.0},
			{"kind":"need_delta", "need":"missing_need", "delta":100.0},
		]
	)

	var engine = engine_script.new()
	if engine.register_definition(malformed):
		failures.append("definition with malformed effect must be rejected before runtime")
		return

	var unaffordable = _definition(
		definition_script,
		&"atomic_unaffordable",
		&"micro",
		&"legendary",
		1.0,
		0.0,
		&"random_resident",
		"",
		[
			{"kind":"need_delta", "need":"mood", "delta":10.0},
			{"kind":"money_delta", "delta":-100.0},
			{"kind":"chaos_delta", "delta":20.0},
		]
	)
	if not engine.register_definition(unaffordable):
		failures.append("structurally valid unaffordable Fate must register")
		return

	var before_money: float = residents[0].money
	var before_mood: float = residents[0].needs.mood.value
	var before_chaos: float = chaos.value

	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var result = engine.resolve(
		&"micro",
		[residents[0]],
		relationships,
		economy,
		chaos,
		0.0,
		rng
	)
	if result.applied:
		failures.append("unaffordable atomic Fate must not apply")
	if not is_equal_approx(residents[0].money, before_money):
		failures.append("failed Fate must not partially mutate money")
	if not is_equal_approx(residents[0].needs.mood.value, before_mood):
		failures.append("failed Fate must not partially mutate needs")
	if not is_equal_approx(chaos.value, before_chaos):
		failures.append("failed Fate must not partially mutate chaos")

func _definition(
	definition_script,
	id: StringName,
	minimum_tier: StringName,
	maximum_tier: StringName,
	weight: float,
	cooldown: float,
	target_mode: StringName,
	target_need: String,
	effects: Array
):
	var definition = definition_script.new()
	definition.id = id
	definition.category = &"test"
	definition.rarity = &"common"
	definition.minimum_tier = minimum_tier
	definition.maximum_tier = maximum_tier
	definition.weight = weight
	definition.cooldown_sim_seconds = cooldown
	definition.target_mode = target_mode
	definition.target_need = StringName(target_need)
	definition.effects = effects.duplicate(true)
	return definition

func _residents(character_script) -> Array:
	return [
		character_script.new(&"resident_a", "Resident A"),
		character_script.new(&"resident_b", "Resident B"),
		character_script.new(&"resident_c", "Resident C"),
	]
