extends RefCounted

const CLOCK_PATH := "res://scripts/core/simulation_clock.gd"

func run() -> Array[String]:
	var failures: Array[String] = []
	var clock_script := load(CLOCK_PATH)
	if clock_script == null:
		failures.append("SimulationClock must load")
		return failures

	var clock = clock_script.new()
	clock.set_time_scale(NAN)
	var nan_delta: float = clock.advance(1.0)
	if is_nan(nan_delta) or is_inf(nan_delta):
		failures.append("NaN time scale must never produce non-finite simulation delta")
	elif not is_equal_approx(nan_delta, 0.0):
		failures.append("NaN time scale must sanitize to safe paused scale 0.0")

	clock.set_time_scale(INF)
	var inf_delta: float = clock.advance(1.0)
	if is_nan(inf_delta) or is_inf(inf_delta):
		failures.append("infinite time scale must never produce non-finite simulation delta")
	elif inf_delta < 0.0 or inf_delta > 20.0:
		failures.append("infinite time scale must remain inside legal 0..20 range")

	return failures
