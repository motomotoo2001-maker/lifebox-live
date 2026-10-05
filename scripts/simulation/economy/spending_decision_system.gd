class_name SpendingDecisionSystem
extends RefCounted

func adjust_score(
	character: CharacterState,
	interaction: InteractionDefinition,
	base_score: float
) -> float:
	if character == null or interaction == null:
		return 0.0
	if is_nan(base_score) or is_inf(base_score) or base_score <= 0.0:
		return 0.0

	if interaction.money_cost <= 0.0:
		return base_score

	if (
		is_nan(interaction.money_cost)
		or is_inf(interaction.money_cost)
		or interaction.money_cost < 0.0
		or is_nan(character.money)
		or is_inf(character.money)
		or character.money < interaction.money_cost
	):
		return 0.0

	var urgency := _need_urgency(character, interaction)
	var impulsiveness := clampf(
		character.personality.impulsiveness,
		0.0,
		1.0
	)
	var cost_ratio := clampf(
		interaction.money_cost / maxf(character.money, 0.0001),
		0.0,
		1.0
	)

	var multiplier := (
		0.65
		+ urgency * 0.35
		+ impulsiveness * 0.35
		- cost_ratio * 0.25
	)

	return maxf(base_score * multiplier, 0.0)

func _need_urgency(
	character: CharacterState,
	interaction: InteractionDefinition
) -> float:
	var highest_urgency := 0.0

	for need_key in interaction.need_effects:
		var raw_effect = interaction.need_effects[need_key]
		if not (raw_effect is float or raw_effect is int):
			continue
		if float(raw_effect) <= 0.0:
			continue

		var need_state = character.needs.get(str(need_key))
		if need_state == null:
			continue

		var urgency := (
			100.0 - clampf(need_state.value, 0.0, 100.0)
		) / 100.0
		highest_urgency = maxf(highest_urgency, urgency)

	return highest_urgency
