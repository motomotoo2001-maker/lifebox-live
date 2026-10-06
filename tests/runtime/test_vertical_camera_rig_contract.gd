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
		"pan_world",
		"adjust_zoom",
		"desired_target",
		"desired_size",
		"get_camera",
	]:
		if not rig.has_method(method_name):
			failures.append("VerticalCameraRig must expose %s()" % method_name)

	var before_target: Vector3 = rig.desired_target()
	rig.pan_world(Vector3(2.0, 0.0, -1.0))
	var after_target: Vector3 = rig.desired_target()
	if after_target.is_equal_approx(before_target):
		failures.append("pan_world() must change desired camera target")

	var before_size: float = rig.desired_size()
	rig.adjust_zoom(-2.0)
	if rig.desired_size() >= before_size:
		failures.append("negative adjust_zoom() must zoom in")

	rig.pan_world(Vector3(999.0, 0.0, 999.0))
	var clamped: Vector3 = rig.desired_target()
	if (
		clamped.x > rig.target_x_bounds.y + 0.001
		or clamped.z > rig.target_z_bounds.y + 0.001
	):
		failures.append("manual pan target must stay inside authored bounds")

	rig.free()
	return failures
