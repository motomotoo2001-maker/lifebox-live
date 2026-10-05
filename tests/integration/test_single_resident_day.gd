extends RefCounted

const ACTION_EXECUTOR_PATH := "res://scripts/simulation/actions/action_executor.gd"
const WORLD_PATH := "res://scripts/simulation/simulation_world.gd"
const FIXTURE_PATH := "res://tests/fixtures/basic_house_fixture.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	if not FileAccess.file_exists(ACTION_EXECUTOR_PATH):
		failures.append("ActionExecutor must exist at %s" % ACTION_EXECUTOR_PATH)
		return failures
	if not FileAccess.file_exists(WORLD_PATH):
		failures.append("SimulationWorld must exist at %s" % WORLD_PATH)
		return failures

	var fixture_script := load(FIXTURE_PATH)
	if fixture_script == null:
		failures.append("basic house fixture must load")
		return failures

	var fixture: Dictionary = fixture_script.new().build()
	var world = fixture["world"]
	var resident = fixture["resident"]
	var fridge = fixture["fridge"]
	var bed = fixture["bed"]

	if not world.has_method("report_arrival"):
		failures.append("SimulationWorld must expose report_arrival")
		_dispose(fixture)
		return failures

	world.step(1.0)
	if resident.current_action_id != &"eat":
		failures.append("hungry resident must choose Eat before Sleep")
	if world.report_arrival(resident.id, fridge.object_id) != true:
		failures.append("Eat target arrival must be accepted")

	var hunger_before: float = resident.needs.hunger.value
	world.step(60.0)
	if resident.needs.hunger.value <= hunger_before:
		failures.append("Eat completion must restore hunger")
	if not fridge.is_available_for(resident.id):
		failures.append("food SmartObject reservation must release after completion")

	resident.needs.energy.value = 5.0
	world.step(1.0)
	if resident.current_action_id != &"sleep":
		failures.append("tired resident must choose Sleep after hunger is satisfied")
	if world.report_arrival(resident.id, bed.object_id) != true:
		failures.append("Sleep target arrival must be accepted")

	var energy_before: float = resident.needs.energy.value
	world.step(60.0)
	if resident.needs.energy.value <= energy_before:
		failures.append("Sleep completion must restore energy")
	if not bed.is_available_for(resident.id):
		failures.append("bed reservation must release after completion")

	_dispose(fixture)
	return failures

func _dispose(fixture: Dictionary) -> void:
	for key in ["fridge", "bed"]:
		var object = fixture[key]
		if is_instance_valid(object):
			object.free()
