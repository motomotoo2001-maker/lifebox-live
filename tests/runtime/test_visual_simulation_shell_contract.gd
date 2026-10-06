extends RefCounted

const SCENE_PATH := "res://scenes/presentation/visual_simulation_shell.tscn"
const SCRIPT_PATH := "res://scripts/presentation/visual_simulation_shell.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	if not FileAccess.file_exists(SCENE_PATH):
		failures.append("VisualSimulationShell scene must exist at %s" % SCENE_PATH)
		return failures
	if not FileAccess.file_exists(SCRIPT_PATH):
		failures.append("VisualSimulationShell script must exist at %s" % SCRIPT_PATH)
		return failures

	var packed_scene = load(SCENE_PATH)
	if packed_scene == null:
		failures.append("VisualSimulationShell scene must load")
		return failures

	var shell = packed_scene.instantiate()
	if shell == null:
		failures.append("VisualSimulationShell scene must instantiate")
		return failures

	if not shell is Node3D:
		failures.append("VisualSimulationShell root must be Node3D")

	for node_path in [
		"HouseholdBlockout",
		"ResidentActors",
		"VerticalCameraRig",
		"CameraDirector",
		"HUDLayer",
		"HUDLayer/VisualHUD",
	]:
		if not shell.has_node(node_path):
			failures.append("VisualSimulationShell missing node %s" % node_path)

	for method_name in [
		"bind_world",
		"sync_visuals",
		"actor_for",
		"actor_count",
		"active_movement_count",
		"validate_visual_state",
	]:
		if not shell.has_method(method_name):
			failures.append("VisualSimulationShell must expose %s()" % method_name)

	shell.free()
	return failures
