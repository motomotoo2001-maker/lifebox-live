extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []

	_test_direct_social_override(failures)
	_test_social_replay(failures)

	return failures

func _test_direct_social_override(failures: Array[String]) -> void:
	var world := SimulationWorld.new()
	var a := CharacterState.new(&"resident_a", "Mira")
	var b := CharacterState.new(&"resident_b", "Leo")
	a.needs.social.value = 0.0
	b.needs.social.value = 0.0
	world.add_character(a)
	world.add_character(b)

	var chair_a := _make_object(&"chair_a", Vector3(-1.0, 0.0, 0.0))
	var chair_b := _make_object(&"chair_b", Vector3(1.0, 0.0, 0.0))
	world.register_smart_object(chair_a)
	world.register_smart_object(chair_b)

	if not world.request_smart_object_action(a.id, chair_a.object_id, &"relax"):
		failures.append("social override setup must start initiator SmartObject action")
	if not world.request_smart_object_action(b.id, chair_b.object_id, &"relax"):
		failures.append("social override setup must start target SmartObject action")

	if not world.request_social_action(a.id, b.id, &"compliment"):
		failures.append("valid player social action must start")
	else:
		if not world.social_system.reservation_book.is_reserved(a.id):
			failures.append("player social initiator must be reserved")
		if not world.social_system.reservation_book.is_reserved(b.id):
			failures.append("player social target must be reserved")
		if a.current_action_id != &"compliment":
			failures.append("player social initiator action id must update")
		if b.current_action_id != &"compliment":
			failures.append("player social target action id must update")
		if a.movement.status != MovementState.STATUS_IDLE:
			failures.append("player social override must cancel initiator movement")
		if b.movement.status != MovementState.STATUS_IDLE:
			failures.append("player social override must cancel target movement")
		if not chair_a.is_available_for(&"third"):
			failures.append("player social override must release initiator object")
		if not chair_b.is_available_for(&"third"):
			failures.append("player social override must release target object")

	if world.request_social_action(a.id, a.id, &"chat"):
		failures.append("player social action must reject self-target")
	if world.request_social_action(a.id, b.id, &"missing"):
		failures.append("player social action must reject unknown action")
	if world.request_social_action(a.id, b.id, &"chat"):
		failures.append("player social action must not stack on active session")

	world.social_system.advance(
		world.characters(),
		world.relationship_graph,
		20.0,
		RandomNumberGenerator.new()
	)
	var relationship := world.relationship_graph.get_relationship(a.id, b.id)
	if relationship == null:
		failures.append("completed directed social action must create relationship outcome")
	elif relationship.affinity <= 0.0:
		failures.append("direct compliment must improve affinity")

	chair_a.free()
	chair_b.free()

func _test_social_replay(failures: Array[String]) -> void:
	var control := SimulationWorld.new()
	var a := CharacterState.new(&"resident_a", "Mira")
	var b := CharacterState.new(&"resident_b", "Leo")
	control.add_character(a)
	control.add_character(b)

	var initial_snapshot := WorldSnapshotCodec.encode(control)
	var log := ReplayLog.new()
	if not log.append(
		&"player_social_action",
		{
			"initiator_id": "resident_a",
			"target_id": "resident_b",
			"action_id": "chat",
		}
	):
		failures.append("player social replay event must append")
		return

	if not control.request_social_action(a.id, b.id, &"chat"):
		failures.append("player social replay control action must start")
		return
	var expected := WorldSnapshotCodec.encode(control)

	var replay_world := SimulationWorld.new()
	var errors := ReplayPlayer.replay(
		replay_world,
		initial_snapshot,
		log.events()
	)
	if not errors.is_empty():
		failures.append(
			"player social replay must succeed: %s"
			% " | ".join(errors)
		)
	elif WorldSnapshotCodec.encode(replay_world) != expected:
		failures.append(
			"player social replay snapshot must equal direct-control snapshot"
		)

func _make_object(
	object_id: StringName,
	point: Vector3
) -> SmartObject:
	var interaction := InteractionDefinition.new()
	interaction.id = &"relax"
	interaction.duration_sim_seconds = 10.0
	interaction.need_effects = {"comfort": 20.0}

	var object := SmartObject.new()
	object.object_id = object_id
	object.interaction_point = point
	object.interactions.append(interaction)
	return object
