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
		"set_display_name",
		"set_visual_color",
		"set_visual_profile",
		"set_presentation_state",
		"presentation_state",
		"set_selected",
		"is_selected",
		"set_activity_badge",
		"clear_activity_badge",
		"set_movement_target",
		"stop_movement",
	]:
		if not actor.has_method(method_name):
			failures.append("ResidentActor3D must expose %s()" % method_name)

	for signal_name in ["movement_arrived", "movement_failed", "resident_selected"]:
		if not actor.has_signal(signal_name):
			failures.append("ResidentActor3D must expose %s signal" % signal_name)

	if actor.get("movement_speed") == null or float(actor.get("movement_speed")) <= 0.0:
		failures.append("ResidentActor3D movement_speed must be positive")

	for node_path in [
		"ClickArea",
		"ClickArea/CollisionShape3D",
		"Visuals",
		"Visuals/SelectionMarker",
		"Visuals/Shadow",
		"Visuals/LegLeft",
		"Visuals/LegRight",
		"Visuals/Body",
		"Visuals/ArmLeft",
		"Visuals/ArmRight",
		"Visuals/Head",
		"Visuals/Hair",
		"Visuals/Nose",
		"Visuals/EyeLeft",
		"Visuals/EyeRight",
		"Visuals/NameLabel",
		"Visuals/ActivityBadge",
	]:
		if not actor.has_node(node_path):
			failures.append("ResidentActor3D missing visual node %s" % node_path)

	if actor.has_node("Visuals/Body") and not actor.get_node("Visuals/Body") is MeshInstance3D:
		failures.append("ResidentActor3D Body must be MeshInstance3D")
	if actor.has_node("Visuals/Head") and not actor.get_node("Visuals/Head") is MeshInstance3D:
		failures.append("ResidentActor3D Head must be MeshInstance3D")
	if actor.has_node("Visuals/NameLabel") and not actor.get_node("Visuals/NameLabel") is Label3D:
		failures.append("ResidentActor3D NameLabel must be Label3D")

	if actor.has_method("set_selected") and actor.has_method("is_selected"):
		actor.set_selected(true)
		if not actor.is_selected():
			failures.append("set_selected(true) must persist selection state")
		if actor.has_node("Visuals/SelectionMarker"):
			if not actor.get_node("Visuals/SelectionMarker").visible:
				failures.append("selected actor must show SelectionMarker")
		actor.set_selected(false)
		if actor.is_selected():
			failures.append("set_selected(false) must clear selection state")

	if actor.has_method("set_visual_profile"):
		actor.set_visual_profile(3)
		if actor.get("_visual_profile_index") != 3:
			failures.append("set_visual_profile() must store deterministic profile index")

	if actor.has_method("set_presentation_state") and actor.has_method("presentation_state"):
		for state_name in [&"idle", &"walk", &"interact", &"social"]:
			actor.set_presentation_state(state_name)
			if actor.presentation_state() != state_name:
				failures.append("presentation state must accept %s" % state_name)
		actor.set_presentation_state(&"invalid")
		if actor.presentation_state() != &"idle":
			failures.append("invalid presentation state must fall back to idle")

	actor.free()
	return failures
