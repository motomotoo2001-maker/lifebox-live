extends RefCounted

const SCRIPT_PATH := "res://scripts/presentation/camera/camera_director.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	if not FileAccess.file_exists(SCRIPT_PATH):
		failures.append("CameraDirector must exist at %s" % SCRIPT_PATH)
		return failures

	var script = load(SCRIPT_PATH)
	if script == null or not script.can_instantiate():
		failures.append("CameraDirector script must load and instantiate")
		return failures

	var director = script.new()
	for method_name in [
		"bind_camera_rig",
		"suggest_focus",
		"tick",
		"force_establishing",
		"current_focus_id",
	]:
		if not director.has_method(method_name):
			failures.append("CameraDirector must expose %s()" % method_name)

	director.min_focus_hold_seconds = 2.0
	director.switch_cooldown_seconds = 1.0
	director.switch_margin = 10.0
	director.min_focus_interest = 10.0
	director.return_to_establishing_after_seconds = 3.0

	director.suggest_focus(&"resident_a", Vector3(1.0, 0.0, 0.0), 30.0)
	director.tick(0.1)
	if director.current_focus_id() != &"resident_a":
		failures.append("first eligible interest target must become focused")

	director.suggest_focus(&"resident_a", Vector3(1.5, 0.0, 0.0), 30.0)
	director.suggest_focus(&"resident_b", Vector3(2.0, 0.0, 0.0), 35.0)
	director.tick(2.1)
	if director.current_focus_id() != &"resident_a":
		failures.append("candidate below switch margin must not steal focus")

	director.suggest_focus(&"resident_a", Vector3(1.5, 0.0, 0.0), 30.0)
	director.suggest_focus(&"resident_b", Vector3(2.0, 0.0, 0.0), 55.0)
	director.tick(1.1)
	if director.current_focus_id() != &"resident_b":
		failures.append("strong candidate after hold/cooldown must switch focus")

	director.suggest_focus(&"resident_c", Vector3(3.0, 0.0, 0.0), 100.0)
	director.tick(0.5)
	if director.current_focus_id() != &"resident_b":
		failures.append("minimum focus hold must prevent immediate camera jitter")

	director.tick(3.1)
	if director.current_focus_id() != &"":
		failures.append("camera must return to establishing after interest timeout")

	director.suggest_focus(&"bad_nan", Vector3.ZERO, NAN)
	director.suggest_focus(&"bad_pos", Vector3(NAN, 0.0, 0.0), 100.0)
	director.tick(0.1)
	if director.current_focus_id() != &"":
		failures.append("invalid focus suggestions must be ignored")

	director.free()
	return failures
