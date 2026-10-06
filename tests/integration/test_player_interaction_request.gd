extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var world := SimulationWorld.new()

	var resident := CharacterState.new(&"resident_a", "Resident A")
	for need_name in ["hunger", "energy", "hygiene", "comfort", "social", "mood"]:
		resident.needs.get(need_name).decay_per_sim_hour = 0.0
	resident.needs.hunger.value = 0.0
	if not world.add_character(resident):
		failures.append("player command test must add resident")
		return failures

	var fridge := SmartObject.new()
	fridge.object_id = &"fridge_main"
	fridge.interaction_point = Vector3(2.0, 0.0, 0.0)

	var eat := InteractionDefinition.new()
	eat.id = &"eat"
	eat.duration_sim_seconds = 2.0
	eat.need_effects = {"hunger": 60.0}
	fridge.interactions.append(eat)
	world.register_smart_object(fridge)

	if world.request_interaction(&"missing", &"fridge_main", &"eat"):
		failures.append("manual interaction must reject missing resident")
	if world.request_interaction(&"resident_a", &"missing", &"eat"):
		failures.append("manual interaction must reject missing SmartObject")
	if world.request_interaction(&"resident_a", &"fridge_main", &"missing"):
		failures.append("manual interaction must reject missing interaction")

	if not world.request_interaction(&"resident_a", &"fridge_main", &"eat"):
		failures.append("idle resident must accept valid player interaction")
	else:
		if resident.current_action_id != &"eat":
			failures.append("manual interaction must set authoritative action")
		if resident.movement.status != MovementState.STATUS_MOVING:
			failures.append("manual interaction must enter authoritative movement")
		if world.request_interaction(&"resident_a", &"fridge_main", &"eat"):
			failures.append("busy resident must reject another manual interaction")

	if not world.report_arrival(&"resident_a", &"fridge_main"):
		failures.append("manual interaction arrival must be accepted")
	world.step(2.0)
	if resident.current_action_id != &"idle":
		failures.append("manual interaction must complete normally")
	if resident.needs.hunger.value < 59.0:
		failures.append("manual interaction must apply normal need effects")

	var log := ReplayLog.new()
	if not log.append(&"interaction_request", {
		"character_id": "resident_a",
		"object_id": "fridge_main",
		"interaction_id": "eat",
	}):
		failures.append("ReplayLog must accept interaction_request input")
	if log.append(&"interaction_request", {
		"character_id": "",
		"object_id": "fridge_main",
		"interaction_id": "eat",
	}):
		failures.append("ReplayLog must reject malformed interaction_request")

	fridge.free()
	return failures
