extends RefCounted

const FIXTURE_PATH := "res://tests/fixtures/basic_house_fixture.gd"
const STEP_REAL_SECONDS := 30.0
const STEP_COUNT := 96
const FIXED_SCALE := 20.0

func run() -> Array[String]:
	var failures: Array[String] = []
	var fixture_script := load(FIXTURE_PATH)
	if fixture_script == null:
		failures.append("basic house fixture must load for soak test")
		return failures

	var first: Dictionary = fixture_script.new().build()
	var second: Dictionary = fixture_script.new().build()
	_configure_soak_world(first)
	_configure_soak_world(second)

	var first_history: Array[StringName] = []
	var second_history: Array[StringName] = []

	for step_index in range(STEP_COUNT):
		first["world"].step(STEP_REAL_SECONDS)
		second["world"].step(STEP_REAL_SECONDS)

		first_history.append(first["resident"].current_action_id)
		second_history.append(second["resident"].current_action_id)

		_check_need_bounds(failures, first["resident"], "first", step_index)
		_check_need_bounds(failures, second["resident"], "second", step_index)
		_check_action_and_reservation(failures, first, "first", step_index)
		_check_action_and_reservation(failures, second, "second", step_index)

	if first_history != second_history:
		failures.append("fixed-seed worlds must produce identical action histories")

	_dispose_fixture(first)
	_dispose_fixture(second)
	return failures

func _configure_soak_world(fixture: Dictionary) -> void:
	var world = fixture["world"]
	var resident = fixture["resident"]

	world.clock.set_time_scale(FIXED_SCALE)
	resident.needs.hunger.decay_per_sim_hour = 12.0
	resident.needs.energy.decay_per_sim_hour = 8.0
	resident.needs.hygiene.decay_per_sim_hour = 4.0
	resident.needs.comfort.decay_per_sim_hour = 3.0
	resident.needs.social.decay_per_sim_hour = 5.0
	resident.needs.mood.decay_per_sim_hour = 2.0

func _check_need_bounds(
	failures: Array[String],
	resident,
	label: String,
	step_index: int
) -> void:
	for need_name in ["hunger", "energy", "hygiene", "comfort", "social", "mood"]:
		var need_state = resident.needs.get(need_name)
		if need_state == null:
			failures.append("%s world missing need %s" % [label, need_name])
			continue
		if is_nan(need_state.value) or need_state.value < 0.0 or need_state.value > 100.0:
			failures.append(
				"%s world need %s left 0..100 at step %d" %
				[label, need_name, step_index]
			)

func _check_action_and_reservation(
	failures: Array[String],
	fixture: Dictionary,
	label: String,
	step_index: int
) -> void:
	var resident = fixture["resident"]
	var fridge = fixture["fridge"]
	var bed = fixture["bed"]
	var action: StringName = resident.current_action_id

	if action != &"idle" and action != &"eat" and action != &"sleep":
		failures.append("%s world has invalid action %s at step %d" % [label, action, step_index])

	var fridge_locked: bool = not bool(fridge.is_available_for(&"reservation_probe"))
	var bed_locked: bool = not bool(bed.is_available_for(&"reservation_probe"))

	if fridge_locked and bed_locked:
		failures.append("%s world holds two SmartObject reservations at step %d" % [label, step_index])

	if action == &"eat" and not fridge_locked:
		failures.append("%s Eat action must own fridge reservation at step %d" % [label, step_index])
	elif action == &"sleep" and not bed_locked:
		failures.append("%s Sleep action must own bed reservation at step %d" % [label, step_index])
	elif action == &"idle" and (fridge_locked or bed_locked):
		failures.append("%s Idle action must not leave a stale reservation at step %d" % [label, step_index])

func _dispose_fixture(fixture: Dictionary) -> void:
	var fridge = fixture["fridge"]
	var bed = fixture["bed"]
	if is_instance_valid(fridge):
		fridge.free()
	if is_instance_valid(bed):
		bed.free()
