extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var world := SimulationWorld.new()

	var first := CharacterState.new(&"resident_a", "A")
	var second := CharacterState.new(&"resident_b", "B")
	for resident in [first, second]:
		resident.needs.social.value = 0.0
		resident.needs.hunger.value = 0.0
		resident.personality.sociability = 1.0
		resident.personality.kindness = 1.0
		if not world.add_character(resident):
			failures.append("social scheduling test must add both residents")
			return failures

	var snack := SmartObject.new()
	snack.object_id = &"snack"
	snack.interaction_point = Vector3(1.0, 0.0, 0.0)
	var eat := InteractionDefinition.new()
	eat.id = &"eat"
	eat.duration_sim_seconds = 10.0
	eat.need_effects = {"hunger": 80.0}
	snack.interactions.append(eat)
	world.register_smart_object(snack)

	world.step(1.0)

	var sessions := world.social_system.active_sessions()
	if sessions.size() != 1:
		failures.append(
			"two highly social idle residents must get a social scheduling window before SmartObject selection"
		)
	else:
		if not world.social_system.reservation_book.is_reserved(first.id):
			failures.append("first resident must be reserved by active social session")
		if not world.social_system.reservation_book.is_reserved(second.id):
			failures.append("second resident must be reserved by active social session")
		if first.movement.status != MovementState.STATUS_IDLE:
			failures.append("social scheduling must not create authoritative movement")
		if second.movement.status != MovementState.STATUS_IDLE:
			failures.append("social scheduling must not create authoritative movement")

	snack.free()
	return failures
