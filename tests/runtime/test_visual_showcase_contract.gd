extends RefCounted

const SHOWCASE_SCENE_PATH := "res://scenes/debug/visual_showcase.tscn"
const SHOWCASE_SCRIPT_PATH := "res://scripts/presentation/debug/visual_showcase.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	if not FileAccess.file_exists(SHOWCASE_SCENE_PATH):
		failures.append("visual showcase scene must exist")
		return failures
	if not FileAccess.file_exists(SHOWCASE_SCRIPT_PATH):
		failures.append("visual showcase script must exist")
		return failures

	var script = load(SHOWCASE_SCRIPT_PATH)
	if script == null or not script.can_instantiate():
		failures.append("visual showcase script must load and instantiate")
		return failures

	var packed_scene = load(SHOWCASE_SCENE_PATH)
	if packed_scene == null or not packed_scene is PackedScene:
		failures.append("visual showcase must load as PackedScene")
		return failures

	var instance = packed_scene.instantiate()
	if instance == null:
		failures.append("visual showcase must instantiate")
		return failures

	if not instance is Node3D:
		failures.append("visual showcase root must be Node3D")
	if instance.name != "VisualShowcase":
		failures.append("visual showcase root name must remain stable")

	instance.free()
	return failures
