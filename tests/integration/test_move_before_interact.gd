extends RefCounted

const FIXTURE_PATH := "res://tests/fixtures/basic_house_fixture.gd"

func run() -> Array[String]:
	var failures: Array[String] = []
	var fixture_script := load(FIXTURE_PATH)
	if fixture_script == null:
		failures.append("basic house fixture must load")
		return failures

	var fixture: Dictionary = fixture_script.new().build()
	var world = fixture["world"]
	var resident = fixture["resident"]
	var fridge = fixture["fridge"]

	if not world.has_method("report_arrival"):
		failures.append("SimulationWorld must expose report_arrival(character_id, target_object_id)")
		_dispose(fixture)
		return failures
	if not world.has_method("report_movement_failure"):
		failures.append("SimulationWorld must expose report_movement_failure(character_id, target_object_id)")
		_dispose(fixture)
		return failures

	world.step(1.0)
	if resident.current_action_id != &"eat":
		failures.append("hungry resident must select Eat")
	if resident.movement.status != &"moving":
		failures.append("selected SmartObject interaction must enter moving state")
	elif resident.movement.intent == null or resident.movement.intent.target_object_id != &"fridge_main":
		failures.append("movement intent must target selected SmartObject id")
	elif resident.movement.intent.target_position != fridge.interaction_point:
		failures.append("movement intent must target SmartObject interaction point")

	var hunger_before: float = resident.needs.hunger.value
	world.step(10.0)
	if not is_equal_approx(resident.needs.hunger.value, hunger_before):
		failures.append("interaction effect must not apply before arrival")
	if fridge.is_available_for(&"reservation_probe"):
		failures.append("moving resident must keep target reserved")

	if world.report_arrival(resident.id, &"wrong_target") != false:
		failures.append("arrival for wrong target must be rejected")
	if world.report_movement_failure(resident.id, &"fridge_main") != true:
		failures.append("movement failure for active target must be accepted")
	if resident.current_action_id != &"idle":
		failures.append("movement failure must cancel current action")
	if resident.movement.status != &"failed":
		failures.append("movement failure must preserve failed movement status")
	if not fridge.is_available_for(&"reservation_probe"):
		failures.append("movement failure must release SmartObject reservation")
	if not is_equal_approx(resident.needs.hunger.value, hunger_before):
		failures.append("movement failure must not apply interaction effects")

	world.step(1.0)
	if resident.current_action_id != &"eat" or resident.movement.status != &"moving":
		failures.append("resident must be able to retry action after movement failure")
	if world.report_arrival(resident.id, &"fridge_main") != true:
		failures.append("arrival for active target must be accepted")

	var hunger_before_interaction: float = resident.needs.hunger.value
	world.step(60.0)
	if resident.needs.hunger.value <= hunger_before_interaction:
		failures.append("interaction effect must apply after arrival and duration")
	if resident.current_action_id != &"idle":
		failures.append("completed interaction must return resident to idle")
	if resident.movement.status != &"idle":
		failures.append("completed interaction must reset movement state")
	if not fridge.is_available_for(&"reservation_probe"):
		failures.append("completed interaction must release reservation")

	_dispose(fixture)
	return failures

func _dispose(fixture: Dictionary) -> void:
	for key in ["fridge", "bed"]:
		var object = fixture[key]
		if is_instance_valid(object):
			object.free()
