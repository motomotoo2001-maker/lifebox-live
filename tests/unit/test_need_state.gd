extends RefCounted

const NEED_STATE_PATH := "res://scripts/simulation/needs/need_state.gd"
const NEED_PROFILE_PATH := "res://scripts/simulation/needs/need_profile.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	if not FileAccess.file_exists(NEED_STATE_PATH):
		failures.append("NeedState must exist at %s" % NEED_STATE_PATH)
		return failures

	if not FileAccess.file_exists(NEED_PROFILE_PATH):
		failures.append("NeedProfile must exist at %s" % NEED_PROFILE_PATH)
		return failures

	var state_script := load(NEED_STATE_PATH)
	var profile_script := load(NEED_PROFILE_PATH)
	if state_script == null or profile_script == null:
		failures.append("NeedState and NeedProfile scripts must load")
		return failures

	var need = state_script.new(75.0, 12.0)
	_expect_close(failures, need.value, 75.0, "initial value")
	_expect_close(failures, need.decay_per_sim_hour, 12.0, "decay rate")
	_expect_close(failures, need.normalized(), 0.75, "normalized value")

	need.apply_delta(10000.0)
	_expect_close(failures, need.value, 100.0, "positive clamp")

	need.apply_delta(-10000.0)
	_expect_close(failures, need.value, 0.0, "negative clamp")

	need.apply_delta(35.0)
	var before_nan: float = need.value
	need.apply_delta(NAN)
	if is_nan(need.value):
		failures.append("NeedState value must never become NaN")
	_expect_close(failures, need.value, before_nan, "NaN delta must be ignored")

	var profile = profile_script.new()
	var required_keys := ["hunger", "energy", "hygiene", "comfort", "social", "mood"]
	for key in required_keys:
		var state = profile.get(key)
		if state == null:
			failures.append("NeedProfile must expose %s" % key)
			continue
		if state.value < 0.0 or state.value > 100.0:
			failures.append("%s must start inside 0..100" % key)

	return failures

func _expect_close(failures: Array[String], actual: float, expected: float, label: String) -> void:
	if not is_equal_approx(actual, expected):
		failures.append("%s: expected %s, got %s" % [label, expected, actual])
