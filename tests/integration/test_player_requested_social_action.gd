extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var world := SimulationWorld.new()

	var a := CharacterState.new(&"resident_a", "A")
	var b := CharacterState.new(&"resident_b", "B")
	for resident in [a, b]:
		for need_name in ["hunger", "energy", "hygiene", "comfort", "social", "mood"]:
			resident.needs.get(need_name).decay_per_sim_hour = 0.0
		if not world.add_character(resident):
			failures.append("social command resident must enter world")

	if not world.has_method("request_social_interaction"):
		failures.append("SimulationWorld must expose request_social_interaction()")
		return failures

	if world.request_social_interaction(
		a.id,
		a.id,
		&"chat",
		true
	):
		failures.append("social command must reject self target")
	if world.request_social_interaction(
		a.id,
		b.id,
		&"missing",
		true
	):
		failures.append("social command must reject unknown action")

	if not world.request_social_interaction(
		a.id,
		b.id,
		&"compliment",
		true
	):
		failures.append("valid compliment command must start")
		return failures

	if not world.social_system.reservation_book.is_reserved(a.id):
		failures.append("social command must reserve initiator")
	if not world.social_system.reservation_book.is_reserved(b.id):
		failures.append("social command must reserve target")
	if a.current_action_id != &"compliment" or b.current_action_id != &"compliment":
		failures.append("social command must set both participant actions")

	if world.request_social_interaction(
		a.id,
		b.id,
		&"argue",
		false
	):
		failures.append("non-interrupting social command must reject busy pair")
	if a.current_action_id != &"compliment":
		failures.append("rejected social command must preserve active session")

	if not world.request_social_interaction(
		a.id,
		b.id,
		&"argue",
		true
	):
		failures.append("interrupting social command must replace active session")
	if a.current_action_id != &"argue" or b.current_action_id != &"argue":
		failures.append("replacement social command must set argue action")

	var before_affinity := 0.0
	var relationship := world.relationship_graph.get_relationship(a.id, b.id)
	if relationship != null:
		before_affinity = relationship.affinity

	world.step(1.1)

	var after := world.relationship_graph.get_relationship(a.id, b.id)
	if after == null:
		failures.append("completed direct social action must create relationship")
	elif after.affinity >= before_affinity:
		failures.append("direct argue command must reduce affinity")

	if a.memory.size() != 1 or b.memory.size() != 1:
		failures.append("completed direct social action must write memories")
	if world.social_system.reservation_book.is_reserved(a.id):
		failures.append("completed direct social action must release initiator")
	if world.social_system.reservation_book.is_reserved(b.id):
		failures.append("completed direct social action must release target")

	return failures
