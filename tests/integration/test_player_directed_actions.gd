extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var world := SimulationWorld.new()
	var resident := CharacterState.new(&"resident_001", "Mira")
	resident.needs.hunger.value = 0.0
	resident.needs.comfort.value = 0.0
	resident.needs.social.value = 100.0
	if not world.add_character(resident):
		failures.append("player action test must add resident")
		return failures

	var fridge := _make_object(
		&"fridge_main",
		&"eat",
		Vector3(-2.0, 0.0, 0.0),
		{"hunger": 60.0}
	)
	var sofa := _make_object(
		&"sofa_main",
		&"relax",
		Vector3(2.0, 0.0, 0.0),
		{"comfort": 60.0}
	)
	world.register_smart_object(fridge)
	world.register_smart_object(sofa)

	if not world.request_smart_object_action(
		resident.id,
		sofa.object_id,
		&"relax"
	):
		failures.append("valid direct relax request must start")
	elif resident.current_action_id != &"relax":
		failures.append("direct relax request must become current action")
	elif resident.movement.intent == null:
		failures.append("direct relax request must create movement intent")
	elif resident.movement.intent.target_object_id != sofa.object_id:
		failures.append("direct relax request must target sofa")

	if not world.request_smart_object_action(
		resident.id,
		fridge.object_id,
		&"eat"
	):
		failures.append("new direct action must replace active SmartObject action")
	else:
		if resident.current_action_id != &"eat":
			failures.append("replacement direct action must become current action")
		if sofa.is_available_for(&"resident_other") == false:
			failures.append("replaced action must release prior SmartObject reservation")
		if fridge.is_available_for(&"resident_other"):
			failures.append("new direct action must reserve requested SmartObject")

	if world.request_smart_object_action(
		resident.id,
		&"missing_object",
		&"eat"
	):
		failures.append("missing direct-action target must be rejected")
	if world.request_smart_object_action(
		resident.id,
		fridge.object_id,
		&"missing_interaction"
	):
		failures.append("missing direct-action interaction must be rejected")

	var other := CharacterState.new(&"resident_002", "Leo")
	other.needs.social.value = 0.0
	other.personality.sociability = 1.0
	other.personality.kindness = 1.0
	resident.needs.social.value = 0.0
	resident.personality.sociability = 1.0
	resident.personality.kindness = 1.0
	if world.add_character(other):
		var executor := world.get_action_executor(resident.id)
		if executor != null and executor.is_active():
			executor.cancel()
		world.social_system.advance(
			world.characters(),
			world.relationship_graph,
			1.0,
			RandomNumberGenerator.new()
		)
		if world.social_system.reservation_book.is_reserved(resident.id):
			if world.request_smart_object_action(
				resident.id,
				sofa.object_id,
				&"relax"
			):
				failures.append("direct SmartObject action must not steal resident from active social session")

	fridge.free()
	sofa.free()
	return failures

func _make_object(
	object_id: StringName,
	interaction_id: StringName,
	point: Vector3,
	effects: Dictionary
) -> SmartObject:
	var interaction := InteractionDefinition.new()
	interaction.id = interaction_id
	interaction.duration_sim_seconds = 10.0
	interaction.need_effects = effects.duplicate(true)

	var object := SmartObject.new()
	object.object_id = object_id
	object.interaction_point = point
	object.interactions.append(interaction)
	return object
