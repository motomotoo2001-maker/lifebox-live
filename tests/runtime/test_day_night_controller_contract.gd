extends RefCounted

const SCRIPT_PATH := "res://scripts/presentation/world/day_night_controller.gd"
const SCENE_PATH := "res://scenes/debug/visual_showcase.tscn"

func run() -> Array[String]:
	var failures: Array[String] = []

	if not FileAccess.file_exists(SCRIPT_PATH):
		failures.append("DayNightController script must exist")
		return failures

	var script = load(SCRIPT_PATH)
	if script == null or not script.can_instantiate():
		failures.append("DayNightController script must load and instantiate")
		return failures

	var controller = script.new()
	for method_name in [
		"bind_world",
		"phase_for_hour",
		"sample_for_hour",
		"current_phase",
	]:
		if not controller.has_method(method_name):
			failures.append("DayNightController must expose %s()" % method_name)

	var expected := {
		0.0: &"night",
		6.0: &"dawn",
		12.0: &"day",
		19.0: &"dusk",
		23.0: &"night",
	}
	for hour in expected.keys():
		if controller.phase_for_hour(hour) != expected[hour]:
			failures.append("unexpected day phase at hour %.1f" % hour)

	var night: Dictionary = controller.sample_for_hour(0.0)
	var noon: Dictionary = controller.sample_for_hour(12.0)
	if float(noon.get("ambient_energy", 0.0)) <= float(night.get("ambient_energy", 0.0)):
		failures.append("day ambient light must be brighter than night")
	if float(noon.get("key_energy", 0.0)) <= float(night.get("key_energy", 0.0)):
		failures.append("day key light must be brighter than night")
	if float(night.get("indoor_energy", 0.0)) <= float(noon.get("indoor_energy", 0.0)):
		failures.append("indoor lights must be stronger at night")
	if float(night.get("ambient_energy", 0.0)) < 0.30:
		failures.append("night ambient must preserve resident readability")

	controller.free()

	var scene = load(SCENE_PATH)
	if scene == null:
		failures.append("visual showcase must load for day/night contract")
		return failures
	var root = scene.instantiate()
	if not root.has_node("DayNightController"):
		failures.append("visual showcase must contain DayNightController")
	root.free()

	return failures
