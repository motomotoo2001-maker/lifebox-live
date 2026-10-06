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
		"social_presentation_count",
		"select_resident",
		"selected_resident_id",
		"set_simulation_paused",
		"is_simulation_paused",
		"_on_hud_resident_requested",
		"presentation_state_for",
		"_social_target_for",
		"validate_visual_state",
	]:
		if not shell.has_method(method_name):
			failures.append("VisualSimulationShell must expose %s()" % method_name)

	if shell.has_method("set_simulation_paused") and shell.has_method("is_simulation_paused"):
		shell.set_simulation_paused(true)
		if not shell.is_simulation_paused():
			failures.append("set_simulation_paused(true) must pause visual advance")
		shell.set_simulation_paused(false)
		if shell.is_simulation_paused():
			failures.append("set_simulation_paused(false) must resume visual advance")

	if shell.has_method("_presentation_target_for"):
		var fridge_intent := MovementIntent.new(
			&"fridge_main",
			Vector3(1.0, 0.0, 1.0),
			0.5
		)
		var fridge_target: Vector3 = shell._presentation_target_for(
			&"resident_001",
			fridge_intent
		)
		if fridge_target.is_equal_approx(fridge_intent.target_position):
			failures.append("fridge presentation anchor must offset visual target")

		var bed_intent := MovementIntent.new(
			&"bed_01",
			Vector3(2.0, 0.0, -3.0),
			0.5
		)
		var bed_target: Vector3 = shell._presentation_target_for(
			&"resident_001",
			bed_intent
		)
		if bed_target.is_equal_approx(bed_intent.target_position):
			failures.append("bed presentation anchor must offset visual target")

	shell.free()
	return failures
