extends SceneTree

const TEST_PATHS: Array[String] = [
	"res://tests/unit/test_boot.gd",
	"res://tests/unit/test_simulation_clock.gd",
	"res://tests/unit/test_event_bus.gd",
	"res://tests/unit/test_need_state.gd",
	"res://tests/unit/test_character_state.gd",
	"res://tests/unit/test_need_system.gd",
	"res://tests/unit/test_smart_object.gd",
	"res://tests/unit/test_utility_ai.gd",
]

func _init() -> void:
	var failures: Array[String] = []

	for test_path in TEST_PATHS:
		var script := load(test_path)
		if script == null:
			failures.append("Unable to load test: %s" % test_path)
			continue

		if not script.can_instantiate():
			failures.append("Unable to instantiate test: %s" % test_path)
			continue

		var test_case = script.new()
		if not test_case.has_method("run"):
			failures.append("Test does not expose run(): %s" % test_path)
			continue

		var case_failures: Array = test_case.run()
		for failure in case_failures:
			failures.append("%s: %s" % [test_path, str(failure)])

	if failures.is_empty():
		print("TESTS PASS: %d suite(s)" % TEST_PATHS.size())
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	print("TESTS FAIL: %d failure(s)" % failures.size())
	quit(1)
