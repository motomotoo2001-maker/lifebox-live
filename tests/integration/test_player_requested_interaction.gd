extends RefCounted

const FIXTURE_PATH := "res://tests/fixtures/basic_house_fixture.gd"

func run() -> Array[String]:
	var failures: Array[String] = []
	var fixture_script := load(FIXTURE_PATH)
	if fixture_script == null:
		failures.append("basic house fixture must load")
		return failures

	var fixture: Dictionary = fixture_script.new().build()
	var world: SimulationWorld = fixture["world"]
	var resident: CharacterState = fixture["resident"]
	var fridge: SmartObject = fixture["fridge"]
	var bed: SmartObject = fixture["bed"]

	if not world.has_method("request_interaction"):
		failures.append("SimulationWorld must expose request_interaction()")
		_dispose(fixture)
		return failures

	if not world.request_interaction(
		resident.id,
		bed.object_id,
		&"sleep",
		true
	):
		failures.append("player request must start a valid sleep interaction")
	elif resident.current_action_id != &"sleep":
		failures.append("player-requested sleep must become current action")
	elif resident.movement.intent == null:
		failures.append("player-requested sleep must create movement intent")
	elif resident.movement.intent.target_object_id != bed.object_id:
		failures.append("player-requested sleep must target requested SmartObject")

	if bed.is_available_for(&"reservation_probe"):
		failures.append("player-requested target must be reserved")

	if world.request_interaction(
		resident.id,
		&"missing_object",
		&"eat",
		true
	):
		failures.append("missing player-requested object must be rejected")
	if resident.current_action_id != &"sleep":
		failures.append("rejected player request must preserve active action")

	if world.request_interaction(
		resident.id,
		fridge.object_id,
		&"eat",
		false
	):
		failures.append("non-interrupting player request must reject active action")
	if resident.current_action_id != &"sleep":
		failures.append("non-interrupting rejection must preserve current action")

	if not world.request_interaction(
		resident.id,
		fridge.object_id,
		&"eat",
		true
	):
		failures.append("interrupting player request must replace active action")
	else:
		if resident.current_action_id != &"eat":
			failures.append("interrupting request must install new action")
		if resident.movement.intent == null:
			failures.append("replacement action must create movement intent")
		elif resident.movement.intent.target_object_id != fridge.object_id:
			failures.append("replacement action must target new object")

	if not bed.is_available_for(&"reservation_probe"):
		failures.append("interrupted target reservation must be released")
	if fridge.is_available_for(&"reservation_probe"):
		failures.append("replacement target must be reserved")

	_dispose(fixture)
	return failures

func _dispose(fixture: Dictionary) -> void:
	for key in ["fridge", "bed"]:
		var object = fixture[key]
		if object != null and is_instance_valid(object):
			object.free()
