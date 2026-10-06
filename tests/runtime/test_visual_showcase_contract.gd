extends RefCounted

const SCENE_PATH := "res://scenes/debug/visual_showcase.tscn"
const SCRIPT_PATH := "res://scripts/debug/visual_showcase_bootstrap.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	if not FileAccess.file_exists(SCENE_PATH):
		failures.append("Visual showcase scene must exist at %s" % SCENE_PATH)
		return failures
	if not FileAccess.file_exists(SCRIPT_PATH):
		failures.append("Visual showcase script must exist at %s" % SCRIPT_PATH)
		return failures

	var packed_scene = load(SCENE_PATH)
	if packed_scene == null:
		failures.append("Visual showcase scene must load")
		return failures

	var showcase = packed_scene.instantiate()
	if showcase == null:
		failures.append("Visual showcase scene must instantiate")
		return failures

	for method_name in [
		"_build_world",
		"_register_household_objects",
		"_register_smart_object",
	]:
		if not showcase.has_method(method_name):
			failures.append("Visual showcase must expose %s()" % method_name)

	if showcase.has_method("_make_schedule"):
		for index in range(6):
			var schedule: ScheduleDefinition = showcase._make_schedule(index)
			if schedule == null:
				failures.append("Showcase schedule %d must exist" % index)
				continue
			var schedule_errors := schedule.validate()
			if not schedule_errors.is_empty():
				failures.append(
					"Showcase schedule %d must validate: %s"
					% [index, " | ".join(schedule_errors)]
				)

	for node_path in [
		"RuntimeObjects",
		"VisualSimulationShell",
		"WorldEnvironment",
		"KeyLight",
		"FillLight",
		"KitchenWarmLight",
		"LivingWarmLight",
		"BedroomWarmLight",
		"BathroomCoolLight",
	]:
		if not showcase.has_node(node_path):
			failures.append("Visual showcase missing node %s" % node_path)

	showcase.free()
	return failures
