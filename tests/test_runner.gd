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
	"res://tests/unit/test_social_reservation_book.gd",
	"res://tests/unit/test_movement_state.gd",
	"res://tests/unit/test_save_schema.gd",
	"res://tests/unit/test_save_migrator.gd",
	"res://tests/unit/test_character_snapshot_codec.gd",
	"res://tests/unit/test_social_economy_snapshot_codec.gd",
	"res://tests/unit/test_schedule_definition.gd",
	"res://tests/unit/test_daily_schedule_state.gd",
	"res://tests/unit/test_goal_state.gd",
	"res://tests/integration/test_daily_goal_planner.gd",
	"res://tests/integration/test_schedule_goal_bias.gd",
	"res://tests/integration/test_social_goal_target_bias.gd",
	"res://tests/integration/test_goal_completion_hooks.gd",
	"res://tests/integration/test_daily_planning_rollover.gd",
	"res://tests/integration/test_goal_schedule_snapshot_restore.gd",
	"res://tests/integration/test_single_resident_day.gd",
	"res://tests/integration/test_move_before_interact.gd",
	"res://tests/integration/test_household_expenses.gd",
	"res://tests/integration/test_paid_interaction.gd",
	"res://tests/integration/test_autonomous_social_actions.gd",
	"res://tests/integration/test_social_outcomes.gd",
	"res://tests/integration/test_autonomous_spending.gd",
	"res://tests/integration/test_world_economy_cadence.gd",
	"res://tests/integration/test_action_snapshot_restore.gd",
	"res://tests/integration/test_social_snapshot_restore.gd",
	"res://tests/integration/test_world_snapshot_roundtrip.gd",
	"res://tests/integration/test_save_service.gd",
	"res://tests/integration/test_replay_log.gd",
	"res://tests/integration/test_six_resident_contention.gd",
	"res://tests/integration/test_stuck_recovery.gd",
	"res://tests/integration/test_simulation_world_invariants.gd",
	"res://tests/runtime/test_resident_actor_contract.gd",
	"res://tests/runtime/test_household_blockout_contract.gd",
	"res://tests/runtime/test_vertical_camera_rig_contract.gd",
	"res://tests/runtime/test_visual_simulation_shell_contract.gd",
	"res://tests/runtime/test_visual_hud_contract.gd",
	"res://tests/runtime/test_visual_showcase_contract.gd",
	"res://tests/soak/test_foundation_soak.gd",
	"res://tests/soak/test_six_resident_household_soak.gd",
	"res://tests/soak/test_social_economy_day_soak.gd",
	"res://tests/soak/test_persistence_replay_soak.gd",
	"res://tests/soak/test_daily_goals_schedules_soak.gd",
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
