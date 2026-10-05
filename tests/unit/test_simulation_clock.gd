extends RefCounted

const CLOCK_PATH := "res://scripts/core/simulation_clock.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	if not FileAccess.file_exists(CLOCK_PATH):
		failures.append("SimulationClock must exist at %s" % CLOCK_PATH)
		return failures

	var clock_script := load(CLOCK_PATH)
	if clock_script == null:
		failures.append("SimulationClock script must load")
		return failures

	var clock = clock_script.new()
	if not clock.has_signal("tick"):
		failures.append("SimulationClock must expose tick(sim_delta)")
		return failures

	var emitted_deltas: Array[float] = []
	clock.tick.connect(func(sim_delta: float) -> void:
		emitted_deltas.append(sim_delta)
	)

	_expect_close(failures, clock.advance(2.0), 2.0, "default 1x scale")
	_expect_close(failures, clock.get_simulation_seconds(), 2.0, "accumulated seconds after 1x")

	clock.set_time_scale(5.0)
	_expect_close(failures, clock.advance(2.0), 10.0, "5x scale")
	_expect_close(failures, clock.get_simulation_seconds(), 12.0, "accumulated seconds after 5x")

	clock.set_time_scale(20.0)
	_expect_close(failures, clock.advance(0.5), 10.0, "20x scale")
	_expect_close(failures, clock.get_simulation_seconds(), 22.0, "accumulated seconds after 20x")

	var tick_count_before_zero := emitted_deltas.size()
	_expect_close(failures, clock.advance(0.0), 0.0, "zero delta")
	if emitted_deltas.size() != tick_count_before_zero:
		failures.append("zero delta must not emit tick")

	clock.set_time_scale(-5.0)
	_expect_close(failures, clock.advance(1.0), 0.0, "negative time scale clamps to zero")

	clock.set_time_scale(999.0)
	_expect_close(failures, clock.advance(1.0), 20.0, "time scale clamps to 20x")

	clock.set_time_scale(20.0)
	_expect_close(failures, clock.advance(120.0), 2400.0, "large delta remains numerically valid")

	return failures

func _expect_close(failures: Array[String], actual: float, expected: float, label: String) -> void:
	if not is_equal_approx(actual, expected):
		failures.append("%s: expected %s, got %s" % [label, expected, actual])
