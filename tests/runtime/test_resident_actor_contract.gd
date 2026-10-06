extends RefCounted

const SCENE_PATH := "res://scenes/characters/resident_actor_3d.tscn"
const SCRIPT_PATH := "res://scripts/presentation/characters/resident_actor_3d.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	if not FileAccess.file_exists(SCENE_PATH):
		failures.append("ResidentActor3D scene must exist at %s" % SCENE_PATH)
		return failures
	if not FileAccess.file_exists(SCRIPT_PATH):
		failures.append("ResidentActor3D script must exist at %s" % SCRIPT_PATH)
		return failures

	var packed_scene = load(SCENE_PATH)
	if packed_scene == null:
		failures.append("ResidentActor3D scene must load")
		return failures

	var actor = packed_scene.instantiate()
	if actor == null:
		failures.append("ResidentActor3D scene must instantiate")
		return failures

	if not actor is CharacterBody3D:
		failures.append("ResidentActor3D root must be CharacterBody3D")

	if not actor.has_node("NavigationAgent3D"):
		failures.append("ResidentActor3D must contain NavigationAgent3D child")
	else:
		var navigation_agent = actor.get_node("NavigationAgent3D")
		if not navigation_agent is NavigationAgent3D:
			failures.append("NavigationAgent3D child must have NavigationAgent3D type")

	for method_name in [
		"bind_character",
		"get_character_id",
		"has_movement_target",
		"set_visual_profile",
		"set_activity_label",
		"set_movement_target",
		"stop_movement",
	]:
		if not actor.has_method(method_name):
			failures.append("ResidentActor3D must expose %s()" % method_name)

	for signal_name in ["movement_arrived", "movement_failed"]:
		if not actor.has_signal(signal_name):
			failures.append("ResidentActor3D must expose %s signal" % signal_name)

	for required_node in [
		"VisualRoot",
		"VisualRoot/Body",
		"VisualRoot/Head",
		"VisualRoot/Shadow",
		"VisualRoot/NameLabel",
		"CollisionShape3D",
	]:
		if not actor.has_node(required_node):
			failures.append("ResidentActor3D missing visual node %s" % required_node)

	if actor.get("movement_speed") == null or float(actor.get("movement_speed")) <= 0.0:
		failures.append("ResidentActor3D movement_speed must be positive")

	actor.free()
	return failures
