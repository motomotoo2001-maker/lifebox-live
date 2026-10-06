class_name FateDefinition
extends Resource

const TARGET_RANDOM_RESIDENT: StringName = &"random_resident"
const TARGET_LOWEST_NEED_RESIDENT: StringName = &"lowest_need_resident"
const TARGET_HIGHEST_RELATIONSHIP_PAIR: StringName = &"highest_relationship_pair"
const TARGET_HOUSEHOLD: StringName = &"household"

const VALID_NEEDS: Array[StringName] = [
	&"hunger", &"energy", &"hygiene", &"comfort", &"social", &"mood",
]

@export var id: StringName = &""
@export var category: StringName = &""
@export var rarity: StringName = &"common"
@export var minimum_tier: StringName = &"micro"
@export var maximum_tier: StringName = &"legendary"
@export var weight: float = 1.0
@export var cooldown_sim_seconds: float = 0.0
@export var target_mode: StringName = TARGET_RANDOM_RESIDENT
@export var target_need: StringName = &""
@export var preconditions: Dictionary = {}
@export var effects: Array = []

func validate() -> Array[String]:
	var errors: Array[String] = []

	if id == &"":
		errors.append("fate id must not be empty")
	if category == &"":
		errors.append("fate category must not be empty")
	if rarity == &"":
		errors.append("fate rarity must not be empty")

	var minimum_rank := tier_rank(minimum_tier)
	var maximum_rank := tier_rank(maximum_tier)
	if minimum_rank < 0:
		errors.append("minimum_tier is invalid")
	if maximum_rank < 0:
		errors.append("maximum_tier is invalid")
	if minimum_rank >= 0 and maximum_rank >= 0 and minimum_rank > maximum_rank:
		errors.append("minimum_tier must not exceed maximum_tier")

	if is_nan(weight) or is_inf(weight) or weight <= 0.0:
		errors.append("fate weight must be finite and positive")
	if (
		is_nan(cooldown_sim_seconds)
		or is_inf(cooldown_sim_seconds)
		or cooldown_sim_seconds < 0.0
	):
		errors.append("fate cooldown_sim_seconds must be finite and non-negative")

	if target_mode not in [
		TARGET_RANDOM_RESIDENT,
		TARGET_LOWEST_NEED_RESIDENT,
		TARGET_HIGHEST_RELATIONSHIP_PAIR,
		TARGET_HOUSEHOLD,
	]:
		errors.append("fate target_mode is invalid")

	if target_mode == TARGET_LOWEST_NEED_RESIDENT and target_need not in VALID_NEEDS:
		errors.append("lowest_need_resident requires a valid target_need")

	_validate_preconditions(errors)
	_validate_effects(errors)
	return errors

func supports_tier(tier: StringName) -> bool:
	var rank := tier_rank(tier)
	if rank < 0:
		return false
	var minimum_rank := tier_rank(minimum_tier)
	var maximum_rank := tier_rank(maximum_tier)
	return minimum_rank >= 0 and maximum_rank >= 0 and rank >= minimum_rank and rank <= maximum_rank

static func tier_rank(tier: StringName) -> int:
	match tier:
		&"micro":
			return 0
		&"small":
			return 1
		&"medium":
			return 2
		&"large":
			return 3
		&"legendary":
			return 4
		_:
			return -1

func _validate_preconditions(errors: Array[String]) -> void:
	for key in preconditions.keys():
		if key not in ["min_chaos", "max_chaos", "min_residents", "need_below"]:
			errors.append("unknown fate precondition: %s" % str(key))
			continue

		var value = preconditions[key]
		match str(key):
			"min_chaos", "max_chaos":
				if not _is_finite_number(value):
					errors.append("%s must be finite" % str(key))
				elif float(value) < 0.0 or float(value) > 100.0:
					errors.append("%s must be inside 0..100" % str(key))
			"min_residents":
				if not value is int or int(value) < 0:
					errors.append("min_residents must be a non-negative integer")
			"need_below":
				if not value is Dictionary:
					errors.append("need_below must be a Dictionary")
				else:
					var need_data: Dictionary = value
					if (
						not need_data.has("need")
						or StringName(str(need_data["need"])) not in VALID_NEEDS
					):
						errors.append("need_below need is invalid")
					if (
						not need_data.has("value")
						or not _is_finite_number(need_data["value"])
						or float(need_data["value"]) < 0.0
						or float(need_data["value"]) > 100.0
					):
						errors.append("need_below value must be finite inside 0..100")

func _validate_effects(errors: Array[String]) -> void:
	if effects.is_empty():
		errors.append("fate effects must not be empty")
		return

	for index in range(effects.size()):
		var raw_effect = effects[index]
		if not raw_effect is Dictionary:
			errors.append("fate effect[%d] must be a Dictionary" % index)
			continue

		var effect: Dictionary = raw_effect
		if not effect.has("kind") or not effect["kind"] is String:
			errors.append("fate effect[%d] kind must be a string" % index)
			continue

		var kind: String = effect["kind"]
		match kind:
			"need_delta":
				if (
					not effect.has("need")
					or StringName(str(effect["need"])) not in VALID_NEEDS
				):
					errors.append("need_delta effect[%d] need is invalid" % index)
				if not effect.has("delta") or not _is_finite_number(effect["delta"]):
					errors.append("need_delta effect[%d] delta must be finite" % index)
			"money_delta":
				if not effect.has("delta") or not _is_finite_number(effect["delta"]):
					errors.append("money_delta effect[%d] delta must be finite" % index)
			"relationship_delta":
				if target_mode != TARGET_HIGHEST_RELATIONSHIP_PAIR:
					errors.append("relationship_delta requires highest_relationship_pair target")
				var has_component := false
				for field_name in ["affinity", "trust", "tension"]:
					if not effect.has(field_name):
						continue
					has_component = true
					if not _is_finite_number(effect[field_name]):
						errors.append(
							"relationship_delta effect[%d] %s must be finite"
							% [index, field_name]
						)
				if not has_component:
					errors.append("relationship_delta effect[%d] needs at least one component" % index)
			"chaos_delta":
				if not effect.has("delta") or not _is_finite_number(effect["delta"]):
					errors.append("chaos_delta effect[%d] delta must be finite" % index)
			_:
				errors.append("unknown fate effect kind: %s" % kind)

func _is_finite_number(value) -> bool:
	if not (value is int or value is float):
		return false
	var number := float(value)
	return not is_nan(number) and not is_inf(number)
