class_name DailyPlanningSystem
extends RefCounted

const DAY_SECONDS := 86400.0

var schedule_system := DailyScheduleSystem.new()

func advance(
	world,
	simulation_seconds: float,
	rng: RandomNumberGenerator
) -> void:
	if world == null or rng == null:
		return
	if (
		is_nan(simulation_seconds)
		or is_inf(simulation_seconds)
		or simulation_seconds < 0.0
	):
		return

	var day_index := int(floor(simulation_seconds / DAY_SECONDS))
	for character in world.characters():
		if character == null:
			continue

		schedule_system.advance(character, simulation_seconds)
		if character.goals == null:
			continue
		if character.goals.day_index == day_index:
			continue
		if character.goals.day_index > day_index:
			continue
		if not character.goals.begin_day(day_index):
			continue

		var planning_rng := RandomNumberGenerator.new()
		planning_rng.seed = _derive_seed(
			rng.seed,
			character.id,
			day_index
		)
		var generated := DailyGoalPlanner.generate(
			character,
			world.relationship_graph,
			day_index,
			planning_rng
		)
		for goal in generated:
			character.goals.add(goal)

func _derive_seed(
	world_seed: int,
	character_id: StringName,
	day_index: int
) -> int:
	var material := "%d|%s|%d" % [
		world_seed,
		character_id,
		day_index,
	]
	return int(material.hash())
