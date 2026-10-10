class_name FateEngine
extends RefCounted

var _definitions: Dictionary = {}
var _cooldown_until_by_id: Dictionary = {}

func register_definition(definition: FateDefinition) -> bool:
	if definition == null or definition.id == &"":
		return false
	if _definitions.has(definition.id):
		return false
	if not definition.validate().is_empty():
		return false

	_definitions[definition.id] = definition
	return true

func resolve(
	tier: StringName,
	residents: Array,
	relationships: RelationshipGraph,
	economy: EconomySystem,
	chaos: ChaosMeter,
	simulation_seconds: float,
	rng: RandomNumberGenerator
) -> FateResult:
	if FateDefinition.tier_rank(tier) < 0:
		return FateResult.new(false, &"", [], &"invalid_tier", simulation_seconds)
	if rng == null or relationships == null or economy == null or chaos == null:
		return FateResult.new(false, &"", [], &"missing_dependency", simulation_seconds)
	if is_nan(simulation_seconds) or is_inf(simulation_seconds) or simulation_seconds < 0.0:
		return FateResult.new(false, &"", [], &"invalid_time", simulation_seconds)

	var eligible := _eligible_definitions(
		tier,
		residents,
		chaos,
		simulation_seconds
	)
	if eligible.is_empty():
		return FateResult.new(false, &"", [], &"no_eligible_fate", simulation_seconds)

	var definition := _weighted_pick(eligible, rng)
	if definition == null:
		return FateResult.new(false, &"", [], &"no_eligible_fate", simulation_seconds)

	var target_ids := _resolve_targets(
		definition,
		residents,
		relationships,
		rng
	)
	if target_ids.is_empty():
		return FateResult.new(
			false,
			definition.id,
			[],
			&"no_valid_target",
			simulation_seconds
		)

	var resident_by_id := _resident_lookup(residents)
	if not _can_apply_effects(
		definition,
		target_ids,
		resident_by_id,
		relationships,
		economy,
		chaos
	):
		return FateResult.new(
			false,
			definition.id,
			target_ids,
			&"effect_precondition_failed",
			simulation_seconds
		)

	_apply_effects(
		definition,
		target_ids,
		resident_by_id,
		relationships,
		economy,
		chaos,
		simulation_seconds
	)

	_cooldown_until_by_id[definition.id] = (
		simulation_seconds + definition.cooldown_sim_seconds
	)

	return FateResult.new(
		true,
		definition.id,
		target_ids,
		&"applied",
		simulation_seconds
	)

func capture_cooldown_state() -> Dictionary:
	var cooldowns: Dictionary = {}
	var ids: Array[String] = []
	for raw_id in _cooldown_until_by_id.keys():
		ids.append(str(raw_id))
	ids.sort()

	for id_text in ids:
		cooldowns[id_text] = float(_cooldown_until_by_id[StringName(id_text)])

	return {"cooldowns": cooldowns}

func restore_cooldown_state(data: Dictionary) -> bool:
	if not data.has("cooldowns") or not data["cooldowns"] is Dictionary:
		return false

	var prepared: Dictionary = {}
	var cooldowns: Dictionary = data["cooldowns"]
	for raw_id in cooldowns.keys():
		if not raw_id is String or raw_id.is_empty():
			return false
		var raw_value = cooldowns[raw_id]
		if not _is_finite_number(raw_value) or float(raw_value) < 0.0:
			return false
		prepared[StringName(raw_id)] = float(raw_value)

	_cooldown_until_by_id = prepared
	return true

func _eligible_definitions(
	tier: StringName,
	residents: Array,
	chaos: ChaosMeter,
	simulation_seconds: float
) -> Array[FateDefinition]:
	var ids: Array[String] = []
	for raw_id in _definitions.keys():
		ids.append(str(raw_id))
	ids.sort()

	var eligible: Array[FateDefinition] = []
	for id_text in ids:
		var definition: FateDefinition = _definitions[StringName(id_text)]
		if not definition.supports_tier(tier):
			continue
		if _is_on_cooldown(definition.id, simulation_seconds):
			continue
		if not _preconditions_pass(definition, residents, chaos):
			continue
		eligible.append(definition)

	return eligible

func _is_on_cooldown(
	definition_id: StringName,
	simulation_seconds: float
) -> bool:
	if not _cooldown_until_by_id.has(definition_id):
		return false
	return simulation_seconds < float(_cooldown_until_by_id[definition_id])

func _preconditions_pass(
	definition: FateDefinition,
	residents: Array,
	chaos: ChaosMeter
) -> bool:
	var preconditions := definition.preconditions
	if preconditions.has("min_chaos"):
		if chaos.value < float(preconditions["min_chaos"]):
			return false
	if preconditions.has("max_chaos"):
		if chaos.value > float(preconditions["max_chaos"]):
			return false
	if preconditions.has("min_residents"):
		if _valid_residents(residents).size() < int(preconditions["min_residents"]):
			return false
	if preconditions.has("need_below"):
		var need_data: Dictionary = preconditions["need_below"]
		var need_name := StringName(str(need_data["need"]))
		var threshold := float(need_data["value"])
		var found := false
		for resident in _valid_residents(residents):
			var need_state = resident.needs.get(str(need_name))
			if need_state != null and need_state.value < threshold:
				found = true
				break
		if not found:
			return false

	return true

func _weighted_pick(
	definitions: Array[FateDefinition],
	rng: RandomNumberGenerator
) -> FateDefinition:
	if definitions.is_empty():
		return null

	var total_weight := 0.0
	for definition in definitions:
		total_weight += definition.weight
	if total_weight <= 0.0:
		return null

	var roll := rng.randf() * total_weight
	var cursor := 0.0
	for definition in definitions:
		cursor += definition.weight
		if roll <= cursor:
			return definition

	return definitions[-1]

func _resolve_targets(
	definition: FateDefinition,
	residents: Array,
	relationships: RelationshipGraph,
	rng: RandomNumberGenerator
) -> Array[StringName]:
	var valid := _valid_residents(residents)
	if valid.is_empty():
		return []

	match definition.target_mode:
		FateDefinition.TARGET_RANDOM_RESIDENT:
			var index := rng.randi_range(0, valid.size() - 1)
			return [valid[index].id]
		FateDefinition.TARGET_LOWEST_NEED_RESIDENT:
			return _lowest_need_target(valid, definition.target_need)
		FateDefinition.TARGET_HIGHEST_RELATIONSHIP_PAIR:
			return _highest_relationship_pair(valid, relationships)
		FateDefinition.TARGET_HOUSEHOLD:
			var ids: Array[StringName] = []
			for resident in valid:
				ids.append(resident.id)
			return ids
		_:
			return []

func _lowest_need_target(
	residents: Array[CharacterState],
	need_name: StringName
) -> Array[StringName]:
	var best: CharacterState = null
	var best_value := INF

	for resident in residents:
		var need_state = resident.needs.get(str(need_name))
		if need_state == null:
			continue
		var value := float(need_state.value)
		if value < best_value:
			best = resident
			best_value = value
		elif (
			is_equal_approx(value, best_value)
			and best != null
			and str(resident.id) < str(best.id)
		):
			best = resident

	if best == null:
		return []
	return [best.id]

func _highest_relationship_pair(
	residents: Array[CharacterState],
	relationships: RelationshipGraph
) -> Array[StringName]:
	var resident_ids: Dictionary = {}
	for resident in residents:
		resident_ids[resident.id] = true

	var pair_scores: Dictionary = {}
	for edge in relationships.all_relationships():
		var from_id: StringName = edge["from_id"]
		var to_id: StringName = edge["to_id"]
		if not resident_ids.has(from_id) or not resident_ids.has(to_id):
			continue

		var left := str(from_id)
		var right := str(to_id)
		if right < left:
			var swap := left
			left = right
			right = swap
		var key := "%s|%s" % [left, right]
		var state: RelationshipState = edge["state"]
		var score := (
			state.affinity
			+ state.trust * 0.25
			- maxf(state.tension, 0.0) * 0.10
		)
		if not pair_scores.has(key) or score > float(pair_scores[key]):
			pair_scores[key] = score

	if pair_scores.is_empty():
		return []

	var keys: Array[String] = []
	for raw_key in pair_scores.keys():
		keys.append(str(raw_key))
	keys.sort()

	var best_key := ""
	var best_score := -INF
	for key in keys:
		var score := float(pair_scores[key])
		if score > best_score:
			best_score = score
			best_key = key

	if best_key.is_empty():
		return []

	var parts := best_key.split("|")
	if parts.size() != 2:
		return []
	return [StringName(parts[0]), StringName(parts[1])]

func _can_apply_effects(
	definition: FateDefinition,
	target_ids: Array[StringName],
	resident_by_id: Dictionary,
	relationships: RelationshipGraph,
	economy: EconomySystem,
	chaos: ChaosMeter
) -> bool:
	if relationships == null or economy == null or chaos == null:
		return false

	for target_id in target_ids:
		if not resident_by_id.has(target_id):
			return false

	for raw_effect in definition.effects:
		var effect: Dictionary = raw_effect
		var kind: String = effect["kind"]
		match kind:
			"need_delta":
				var need_name := StringName(str(effect["need"]))
				for target_id in target_ids:
					var resident: CharacterState = resident_by_id[target_id]
					if resident.needs.get(str(need_name)) == null:
						return false
			"money_delta":
				var delta := float(effect["delta"])
				for target_id in target_ids:
					var resident: CharacterState = resident_by_id[target_id]
					if is_nan(resident.money) or is_inf(resident.money) or resident.money < 0.0:
						return false
					if delta < 0.0 and resident.money < -delta:
						return false
					if delta > 0.0:
						var future_balance := resident.money + delta
						if is_nan(future_balance) or is_inf(future_balance):
							return false
			"relationship_delta":
				if target_ids.size() != 2 or target_ids[0] == target_ids[1]:
					return false
			"chaos_delta":
				pass
			_:
				return false

	return true

func _apply_effects(
	definition: FateDefinition,
	target_ids: Array[StringName],
	resident_by_id: Dictionary,
	relationships: RelationshipGraph,
	economy: EconomySystem,
	chaos: ChaosMeter,
	simulation_seconds: float
) -> void:
	for raw_effect in definition.effects:
		var effect: Dictionary = raw_effect
		var kind: String = effect["kind"]
		match kind:
			"need_delta":
				var need_name := StringName(str(effect["need"]))
				var delta := float(effect["delta"])
				for target_id in target_ids:
					var resident: CharacterState = resident_by_id[target_id]
					var need_state = resident.needs.get(str(need_name))
					need_state.apply_delta(delta)
			"money_delta":
				var delta := float(effect["delta"])
				if is_zero_approx(delta):
					continue
				for target_id in target_ids:
					var resident: CharacterState = resident_by_id[target_id]
					if delta > 0.0:
						economy.deposit(resident, delta, simulation_seconds)
					else:
						economy.spend(resident, -delta, simulation_seconds)
			"relationship_delta":
				var affinity := float(effect.get("affinity", 0.0))
				var trust := float(effect.get("trust", 0.0))
				var tension := float(effect.get("tension", 0.0))
				var first := relationships.get_or_create(target_ids[0], target_ids[1])
				var second := relationships.get_or_create(target_ids[1], target_ids[0])
				first.apply_delta(affinity, trust, tension)
				second.apply_delta(affinity, trust, tension)
			"chaos_delta":
				chaos.apply_delta(float(effect["delta"]))

func _valid_residents(residents: Array) -> Array[CharacterState]:
	var valid: Array[CharacterState] = []
	for raw_resident in residents:
		if not raw_resident is CharacterState:
			continue
		var resident: CharacterState = raw_resident
		if resident.id == &"":
			continue
		valid.append(resident)

	valid.sort_custom(func(a: CharacterState, b: CharacterState) -> bool:
		return str(a.id) < str(b.id)
	)
	return valid

func _resident_lookup(residents: Array) -> Dictionary:
	var lookup: Dictionary = {}
	for resident in _valid_residents(residents):
		lookup[resident.id] = resident
	return lookup

func _is_finite_number(value) -> bool:
	if not (value is int or value is float):
		return false
	var number := float(value)
	return not is_nan(number) and not is_inf(number)
