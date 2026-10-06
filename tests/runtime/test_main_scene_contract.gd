extends RefCounted

const MAIN_SCENE_PATH := "res://scenes/main/lifebox_live.tscn"

func run() -> Array[String]:
	var failures: Array[String] = []

	var configured := str(
		ProjectSettings.get_setting("application/run/main_scene", "")
	)
	if configured != MAIN_SCENE_PATH:
		failures.append(
			"application/run/main_scene must point to %s" % MAIN_SCENE_PATH
		)

	if not FileAccess.file_exists(MAIN_SCENE_PATH):
		failures.append("Main scene must exist at %s" % MAIN_SCENE_PATH)
		return failures

	var packed_scene = load(MAIN_SCENE_PATH)
	if packed_scene == null:
		failures.append("Main scene must load")
		return failures

	var root = packed_scene.instantiate()
	if root == null:
		failures.append("Main scene must instantiate")
		return failures

	if not root is Node3D:
		failures.append("Main scene root must be Node3D")
	if not root.has_node("HouseholdSimulation"):
		failures.append("Main scene must contain HouseholdSimulation")

	root.free()
	return failures
