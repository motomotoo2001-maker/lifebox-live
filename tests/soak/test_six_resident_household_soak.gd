extends RefCounted

const WORLD_PATH := "res://scripts/simulation/simulation_world.gd"
const HOUSEHOLD_FIXTURE_PATH := "res://tests/fixtures/six_resident_household_fixture.gd"
const INTERACTION_PATH := "res://scripts/simulation/interactions/interaction_definition.gd"
const SMART_OBJECT_PATH := "res://scripts/simulation/interactions/smart_object.gd"

const TIME_SCALE := 20.0
const REAL_STEP_SECONDS := 0.25
const SIM_STEP_SECONDS := TIME_SCALE * REAL_STEP_SECONDS
const SIM_HOURS := 8.0
const TOTAL_SIM_SECONDS := SIM_HOURS * 3600.0
const OUTER_STEPS := int(TOTAL_SIM_SECONDS / SIM_STEP_SECONDS)
const HISTORY_SAMPLE_EVERY_STEPS := 12

func run() -> Array[String]:
	var failures: Array[String] = []

	var first := _build_household_world(failures, "first")
	var second := _build_household_world(failures, "second")
	if first.is_empty() or second.is_empty():
		_dispose_world(first)
		_dispose_world(second)
		return failures

	var first_history: Array[String] = []
	var second_history: Array[String] = []

	for step_index in range(OUTER_STEPS):
		first["world"].step(REAL_STEP_SECONDS)
		second["world"].step(REAL_STEP_SECONDS)

		_drive_runtime_feedback(first, step_index)
		_drive_runtime_feedback(second, step_index)

		_validate_world(failures, first, "first", step_index)
		_validate_world(failures, second, "second", step_index)

		if step_index % HISTORY_SAMPLE_EVERY_STEPS == 0:
			first_history.append(_snapshot(first))
			second_history.append(_snapshot(second))

	if first_history != second_history:
		failures.append("same fixed-seed household must produce identical eight-hour histories")

	var first_seconds: float = first["world"].clock.get_simulation_seconds()
	var second_seconds: float = second["world"].clock.get_simulation_seconds()
	if not is_equal_approx(first_seconds, TOTAL_SIM_SECONDS):
		failures.append("first household must complete exactly 8 simulated hours")
	if not is_equal_approx(second_seconds, TOTAL_SIM_SECONDS):
		failures.append("second household must complete exactly 8 simulated hours")

	_dispose_world(first)
	_dispose_world(second)
	return failures

func _build_household_world(failures: Array[String], label: String) -> Dictionary:
	var world_script := load(WORLD_PATH)
	var fixture_script := load(HOUSEHOLD_FIXTURE_PATH)
	var interaction_script := load(INTERACTION_PATH)
	var smart_object_script := load(SMART_OBJECT_PATH)
	if world_script == null or fixture_script == null or interaction_script == null or smart_object_script == null:
		failures.append("%s household soak dependencies must load" % label)
		return {}

	var fixture: Dictionary = fixture_script.new().build()
	if fixture.is_empty():
		failures.append("%s six-resident fixture must build" % label)
		return {}

	var residents: Array = fixture["residents"]
	if residents.size() != 6:
		failures.append("%s household must contain exactly six residents" % label)
		return {}

	var world = world_script.new()
	world.clock.set_time_scale(TIME_SCALE)

	var seen_ids: Dictionary = {}
	for index in range(residents.size()):
		var resident = residents[index]
		if resident.id == &"" or seen_ids.has(resident.id):
			failures.append("%s household resident ids must be unique and non-empty" % label)
		seen_ids[resident.id] = true

		resident.needs.hunger.value = 35.0 + float(index * 3)
		resident.needs.energy.value = 55.0 + float(index * 2)
		resident.needs.hygiene.value = 80.0
		resident.needs.comfort.value = 80.0
		resident.needs.social.value = 80.0
		resident.needs.mood.value = 80.0

		resident.needs.hunger.decay_per_sim_hour = 12.0
		resident.needs.energy.decay_per_sim_hour = 8.0
		resident.needs.hygiene.decay_per_sim_hour = 4.0
		resident.needs.comfort.decay_per_sim_hour = 3.0
		resident.needs.social.decay_per_sim_hour = 5.0
		resident.needs.mood.decay_per_sim_hour = 2.0

		if not world.add_character(resident):
			failures.append("%s household resident %s must enter SimulationWorld" % [label, resident.id])

	var eat = interaction_script.new()
	eat.id = &"eat"
	eat.duration_sim_seconds = 15.0
	eat.need_effects = {"hunger": 55.0}

	var fridge = smart_object_script.new()
	fridge.object_id = &"fridge_main"
	fridge.interaction_point = Vector3(2.0, 0.0, 0.0)
	fridge.interactions.append(eat)
	world.register_smart_object(fridge)

	var objects: Array = [fridge]
	for index in range(6):
		var sleep = interaction_script.new()
		sleep.id = StringName("sleep_%02d" % (index + 1))
		sleep.duration_sim_seconds = 30.0
		sleep.need_effects = {"energy": 65.0}

		var bed = smart_object_script.new()
		bed.object_id = StringName("bed_%02d" % (index + 1))
		bed.interaction_point = Vector3(-3.0 + float(index), 0.0, -2.0)
		bed.interactions.append(sleep)
		world.register_smart_object(bed)
		objects.append(bed)

	return {
		"world": world,
		"residents": residents,
		"objects": objects,
	}

func _drive_runtime_feedback(state: Dictionary, step_index: int) -> void:
	var world = state["world"]
	var residents: Array = state["residents"]

	for resident_index in range(residents.size()):
		var resident = residents[resident_index]
		if resident.movement.status != MovementState.STATUS_MOVING:
			continue
		if resident.movement.intent == null:
			continue

		var target_id: StringName = resident.movement.intent.target_object_id
		var should_fail := ((step_index + resident_index * 17) % 113) == 0
		if should_fail:
			world.report_movement_failure(resident.id, target_id)
		else:
			world.report_arrival(resident.id, target_id)

func _validate_world(
	failures: Array[String],
	state: Dictionary,
	label: String,
	step_index: int
) -> void:
	var residents: Array = state["residents"]
	var objects: Array = state["objects"]
	var active_targets: Dictionary = {}

	for resident in residents:
		for need_name in ["hunger", "energy", "hygiene", "comfort", "social", "mood"]:
			var need_state = resident.needs.get(need_name)
			if need_state == null:
				failures.append("%s missing need %s at step %d" % [label, need_name, step_index])
				continue
			if is_nan(need_state.value) or is_inf(need_state.value):
				failures.append("%s need %s became non-finite at step %d" % [label, need_name, step_index])
			elif need_state.value < 0.0 or need_state.value > 100.0:
				failures.append("%s need %s left 0..100 at step %d" % [label, need_name, step_index])

		if resident.movement.status == MovementState.STATUS_MOVING:
			if resident.movement.intent == null:
				failures.append("%s moving resident lacks intent at step %d" % [label, step_index])
			elif resident.movement.elapsed_sim_seconds > 30.0:
				failures.append("%s resident remained moving past watchdog timeout at step %d" % [label, step_index])

		if resident.current_action_id != &"idle" and resident.movement.intent != null:
			var target_id: StringName = resident.movement.intent.target_object_id
			var count := int(active_targets.get(target_id, 0)) + 1
			active_targets[target_id] = count
			if count > 1:
				failures.append("%s target %s has multiple active residents at step %d" % [label, target_id, step_index])

	for object in objects:
		if object == null or not is_instance_valid(object):
			failures.append("%s household lost SmartObject at step %d" % [label, step_index])
			continue
		var active_count := int(active_targets.get(object.object_id, 0))
		var locked: bool = not bool(object.is_available_for(&"reservation_probe"))
		if active_count == 0 and locked:
			failures.append("%s object %s has stale reservation at step %d" % [label, object.object_id, step_index])
		elif active_count == 1 and not locked:
			failures.append("%s active target %s must remain reserved at step %d" % [label, object.object_id, step_index])

func _snapshot(state: Dictionary) -> String:
	var parts: Array[String] = []
	var residents: Array = state["residents"]
	var objects: Array = state["objects"]

	for resident in residents:
		var target_id: StringName = &""
		if resident.movement.intent != null:
			target_id = resident.movement.intent.target_object_id
		parts.append(
			"%s:%s:%s:%s:%d:%d" % [
				resident.id,
				resident.current_action_id,
				resident.movement.status,
				target_id,
				int(round(resident.needs.hunger.value)),
				int(round(resident.needs.energy.value)),
			]
		)

	for object in objects:
		var locked: bool = not bool(object.is_available_for(&"reservation_probe"))
		parts.append("%s:%s" % [object.object_id, str(locked)])

	return "|".join(parts)

func _dispose_world(state: Dictionary) -> void:
	if state.is_empty():
		return
	var objects: Array = state.get("objects", [])
	for object in objects:
		if object != null and is_instance_valid(object):
			object.free()
