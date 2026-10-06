extends RefCounted

const SCENE_PATH := "res://scenes/camera/vertical_camera_rig.tscn"
const SCRIPT_PATH := "res://scripts/presentation/camera/vertical_camera_rig.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	if not FileAccess.file_exists(SCENE_PATH):
		failures.append("VerticalCameraRig scene must exist at %s" % SCENE_PATH)
		return failures
	if not FileAccess.file_exists(SCRIPT_PATH):
		failures.append("VerticalCameraRig script must exist at %s" % SCRIPT_PATH)
		return failures

	var packed_scene = load(SCENE_PATH)
	if packed_scene == null:
		failures.append("VerticalCameraRig scene must load")
		return failures

	var rig = packed_scene.instantiate()
	if rig == null:
		failures.append("VerticalCameraRig scene must instantiate")
		return failures

	if not rig is Node3D:
		failures.append("VerticalCameraRig root must be Node3D")
	if not rig.has_node("Camera3D"):
		failures.append("VerticalCameraRig must contain Camera3D")
	else:
		var camera = rig.get_node("Camera3D")
		if not camera is Camera3D:
			failures.append("VerticalCameraRig Camera3D child must be Camera3D")
		elif camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
			failures.append("VerticalCameraRig camera must be orthogonal")
		elif camera.size <= 0.0:
			failures.append("VerticalCameraRig orthographic size must be positive")

	for method_name in [
		"set_establishing_view",
		"focus_world_position",
		"get_camera",
	]:
		if not rig.has_method(method_name):
			failures.append("VerticalCameraRig must expose %s()" % method_name)

	rig.free()
	return failures
