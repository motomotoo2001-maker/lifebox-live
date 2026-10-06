class_name DailyGoalPlanner
extends RefCounted

const MAX_GOALS := 3
const DOMINANT_TRAIT_THRESHOLD := 0.9

static func generate(
	character: CharacterState,
	relationships: RelationshipGraph,
	day_index: int,
	rng: RandomNumberGenerator
) -> Array[GoalState]:
	var result: Array[GoalState] = []
	if character == null or rng == null or day_index < 0:
		return result

	var candidates: Array[Dictionary] = []
	candidates.append(_candidate(
		_make_definition(
			StringName("wellbeing_day_%d" % day_index),
			&"wellbeing",
			0.45,
			[&"relax"]
		),
		0.65,
		false
	))

	var social_target := _pick_social_target(character, relationships)
	if social_target != &"":
		var sociability := clampf(character.personality.sociability, 0.0, 1.0)
		candidates.append(_candidate(
			_make_definition(
				StringName("social_%s_day_%d" % [social_target, day_index]),
				&"social",
				0.45 + sociability * 0.45,
				[&"social"],
				social_target
			),
			0.25 + sociability * 1.75,
			sociability >= DOMINANT_TRAIT_THRESHOLD
		))

	if character.job != null and character.job.definition != null:
		var ambition := clampf(character.personality.ambition, 0.0, 1.0)
		candidates.append(_candidate(
			_make_definition(
				StringName("work_day_%d" % day_index),
				&"work",
				0.45 + ambition * 0.45,
				[&"work"]
			),
			0.25 + ambition * 1.75,
			ambition >= DOMINANT_TRAIT_THRESHOLD
		))

	var impulsiveness := clampf(character.personality.impulsiveness, 0.0, 1.0)
	candidates.append(_candidate(
		_make_definition(
			StringName("fun_day_%d" % day_index),
			&"fun",
			0.4 + impulsiveness * 0.5,
			[&"relax", &"spend"]
		),
		0.2 + impulsiveness * 1.8,
		impulsiveness >= DOMINANT_TRAIT_THRESHOLD
	))

	var target_count := 1
	if candidates.size() > 1:
		target_count = 1 + rng.randi_range(
			0,
			mini(MAX_GOALS - 1, candidates.size() - 1)
		)

	var remaining := candidates.duplicate(true)
	for candidate in candidates:
		if not bool(candidate["dominant"]):
			continue
		if result.size() >= MAX_GOALS:
			break
		result.append(GoalState.new(candidate["definition"]))
		_remove_candidate_by_id(remaining, candidate["definition"].id)

	target_count = maxi(target_count, result.size())
	target_count = mini(target_count, MAX_GOALS)

	while result.size() < target_count and not remaining.is_empty():
		var picked_index := _weighted_pick_index(remaining, rng)
		var picked: Dictionary = remaining[picked_index]
		result.append(GoalState.new(picked["definition"]))
		remaining.remove_at(picked_index)

	return result

static func _candidate(
	definition: GoalDefinition,
	weight: float,
	dominant: bool
) -> Dictionary:
	return {
		"definition": definition,
		"weight": maxf(weight, 0.0001),
		"dominant": dominant,
	}

static func _make_definition(
	id: StringName,
	category: StringName,
	priority: float,
	tags: Array[StringName],
	target_resident_id: StringName = &""
) -> GoalDefinition:
	var definition := GoalDefinition.new()
	definition.id = id
	definition.category = category
	definition.priority = clampf(priority, 0.0, 1.0)
	definition.preferred_action_tags = tags.duplicate()
	definition.target_resident_id = target_resident_id
	return definition

static func _pick_social_target(
	character: CharacterState,
	relationships: RelationshipGraph
) -> StringName:
	if relationships == null:
		return &""

	var best_id: StringName = &""
	var best_affinity := -INF
	for edge in relationships.all_relationships():
		if not edge is Dictionary:
			continue
		if edge.get("from_id", &"") != character.id:
			continue
		var target_id: StringName = edge.get("to_id", &"")
		if target_id == &"" or target_id == character.id:
			continue
		var state = edge.get("state")
		var affinity := 0.0
		if state != null:
			affinity = float(state.affinity)
		if affinity > best_affinity:
			best_affinity = affinity
			best_id = target_id
		elif (
			is_equal_approx(affinity, best_affinity)
			and str(target_id) < str(best_id)
		):
			best_id = target_id

	return best_id

static func _weighted_pick_index(
	candidates: Array[Dictionary],
	rng: RandomNumberGenerator
) -> int:
	var total := 0.0
	for candidate in candidates:
		total += float(candidate["weight"])

	var roll := rng.randf() * total
	var cursor := 0.0
	for index in range(candidates.size()):
		cursor += float(candidates[index]["weight"])
		if roll <= cursor:
			return index

	return candidates.size() - 1

static func _remove_candidate_by_id(
	candidates: Array[Dictionary],
	goal_id: StringName
) -> void:
	for index in range(candidates.size() - 1, -1, -1):
		var definition: GoalDefinition = candidates[index]["definition"]
		if definition.id == goal_id:
			candidates.remove_at(index)
