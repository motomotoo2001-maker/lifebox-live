extends SceneTree

const TEST_PATHS: Array[String] = [
	"res://tests/unit/test_boot.gd",
	"res://tests/unit/test_simulation_clock.gd",
	"res://tests/unit/test_simulation_clock_safety.gd",
	"res://tests/unit/test_event_bus.gd",
	"res://tests/unit/test_need_state.gd",
	"res://tests/unit/test_character_state.gd",
	"res://tests/unit/test_need_system.gd",
	"res://tests/unit/test_smart_object.gd",
	"res://tests/unit/test_smart_object_registry.gd",
	"res://tests/unit/test_utility_ai.gd",
	"res://tests/unit/test_household_identity.gd",
	"res://tests/unit/test_household_state.gd",
	"res://tests/unit/test_relationship_graph.gd",
	"res://tests/unit/test_memory_store.gd",
	"res://tests/unit/test_economy_system.gd",
	"res://tests/unit/test_job_system.gd",
	"res://tests/unit/test_movement_state.gd",
	"res://tests/integration/test_single_resident_day.gd",
	"res://tests/integration/test_move_before_interact.gd",
	"res://tests/integration/test_household_expenses.gd",
	"res://tests/integration/test_paid_interaction.gd",
	"res://tests/integration/test_six_resident_contention.gd",
	"res://tests/integration/test_stuck_recovery.gd",
	"res://tests/integration/test_simulation_world_invariants.gd",
	"res://tests/runtime/test_resident_actor_contract.gd",
	"res://tests/runtime/test_household_blockout_contract.gd",
	"res://tests/soak/test_foundation_soak.gd",
	"res://tests/soak/test_six_resident_household_soak.gd",
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
