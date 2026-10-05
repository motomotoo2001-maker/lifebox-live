class_name DecisionBiasSystem
extends RefCounted

const DAY_SECONDS := 86400.0
const HOUR_SECONDS := 3600.0
const CRITICAL_NEED_THRESHOLD := 20.0
const CRITICAL_MATCH_FLOOR := 1000000000.0
const CRITICAL_MISMATCH_CAP := 999999999.0
const CRITICAL_MISMATCH_MULTIPLIER := 0.25
const SCHEDULE_BONUS_MULTIPLIER := 0.35
const GOAL_BONUS_BASE := 0.25
const GOAL_PRIORITY_MULTIPLIER := 0.5

func adjust(
	character: CharacterState,
	interaction: InteractionDefinition,
	base_score: float,
	simulation_seconds: float,
	_relationships: RelationshipGraph
) -> float:
	if character == null or interaction == null:
		return 0.0
	if is_nan(base_score) or is_inf(base_score) or base_score < 0.0:
		return 0.0

	var critical_needs := _critical_needs(character)
	if not critical_needs.is_empty():
		if _helps_any_need(interaction, critical_needs):
			return CRITICAL_MATCH_FLOOR + minf(
				base_score,
				CRITICAL_MATCH_FLOOR
			)
		return minf(
			base_score * CRITICAL_MISMATCH_MULTIPLIER,
			CRITICAL_MISMATCH_CAP
		)

	var score := base_score
	var active_block := _active_schedule_block(character, simulation_seconds)
	if (
		active_block != null
		and _tags_overlap(
			interaction.action_tags,
			active_block.preferred_action_tags
		)
	):
		score += base_score * SCHEDULE_BONUS_MULTIPLIER

	if character.goals != null:
		for goal in character.goals.active_goals():
			if goal == null or goal.definition == null:
				continue
			if not _tags_overlap(
				interaction.action_tags,
				goal.definition.preferred_action_tags
			):
				continue
			var priority := clampf(goal.definition.priority, 0.0, 1.0)
			score += base_score * (
				GOAL_BONUS_BASE
				+ priority * GOAL_PRIORITY_MULTIPLIER
			)

	return score

func _critical_needs(character: CharacterState) -> Array[StringName]:
	var needs: Array[StringName] = []
	if character.needs.hunger.value <= CRITICAL_NEED_THRESHOLD:
		needs.append(&"hunger")
	if character.needs.energy.value <= CRITICAL_NEED_THRESHOLD:
		needs.append(&"energy")
	return needs

func _helps_any_need(
	interaction: InteractionDefinition,
	need_names: Array[StringName]
) -> bool:
	for need_name in need_names:
		if not interaction.need_effects.has(need_name):
			continue
		var raw_effect = interaction.need_effects[need_name]
		if (
			(raw_effect is int or raw_effect is float)
			and float(raw_effect) > 0.0
		):
			return true
	return false

func _active_schedule_block(
	character: CharacterState,
	simulation_seconds: float
) -> ScheduleBlock:
	if character.schedule == null or character.schedule.definition == null:
		return null
	if (
		is_nan(simulation_seconds)
		or is_inf(simulation_seconds)
		or simulation_seconds < 0.0
	):
		return null
	if not character.schedule.definition.validate().is_empty():
		return null

	var day_seconds := fmod(simulation_seconds, DAY_SECONDS)
	var hour := day_seconds / HOUR_SECONDS
	return character.schedule.definition.active_block_at(hour)

func _tags_overlap(
	interaction_tags: Array[StringName],
	preferred_tags: Array[StringName]
) -> bool:
	if interaction_tags.is_empty() or preferred_tags.is_empty():
		return false
	for tag in interaction_tags:
		if tag in preferred_tags:
			return true
	return false
