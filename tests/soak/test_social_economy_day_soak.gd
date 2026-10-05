extends RefCounted

const WORLD_PATH := "res://scripts/simulation/simulation_world.gd"
const FIXTURE_PATH := "res://tests/fixtures/six_resident_household_fixture.gd"
const INTERACTION_PATH := "res://scripts/simulation/interactions/interaction_definition.gd"
const SMART_OBJECT_PATH := "res://scripts/simulation/interactions/smart_object.gd"
const JOB_DEFINITION_PATH := "res://scripts/simulation/economy/job_definition.gd"

const TIME_SCALE := 20.0
const REAL_STEP_SECONDS := 1.0
const TOTAL_SIM_SECONDS := 24.0 * 3600.0
const OUTER_STEPS := int(TOTAL_SIM_SECONDS / (TIME_SCALE * REAL_STEP_SECONDS))
const HISTORY_SAMPLE_EVERY_STEPS := 120

func run() -> Array[String]:
	var failures: Array[String] = []

	var first := _build_world(failures, "first")
	var second := _build_world(failures, "second")
	if first.is_empty() or second.is_empty():
		_dispose(first)
		_dispose(second)
		return failures

	var first_history: Array[String] = []
	var second_history: Array[String] = []

	for step_index in range(OUTER_STEPS):
		first["world"].step(REAL_STEP_SECONDS)
		second["world"].step(REAL_STEP_SECONDS)

		_drive_navigation(first, step_index)
		_drive_navigation(second, step_index)

		_validate_state(failures, first, "first", step_index)
		_validate_state(failures, second, "second", step_index)

		if step_index % HISTORY_SAMPLE_EVERY_STEPS == 0:
			first_history.append(_snapshot(first))
			second_history.append(_snapshot(second))

	if first_history != second_history:
		failures.append("same-seed social/economy worlds must produce identical 24-hour histories")

	for state in [first, second]:
		var world = state["world"]
		if not is_equal_approx(world.clock.get_simulation_seconds(), TOTAL_SIM_SECONDS):
			failures.append("24-hour soak world must finish exactly one simulated day")
		if world.household_expense_system.processed_days != 1:
			failures.append("24-hour soak must process exactly one household expense day")
		if is_nan(world.household_expense_system.arrears) or is_inf(world.household_expense_system.arrears):
			failures.append("household arrears must remain finite")
		if world.relationship_graph.all_relationships().is_empty():
			failures.append("24-hour autonomous household must produce social relationship edges")

		var remembered_anything := false
		var worked_anything := false
		for resident in state["residents"]:
			remembered_anything = remembered_anything or resident.memory.size() > 0
			worked_anything = worked_anything or resident.job.total_worked_sim_seconds > 0.0
		if not remembered_anything:
			failures.append("24-hour household must produce resident episodic memories")
		if not worked_anything:
			failures.append("24-hour household must produce simulated job work")

	_dispose(first)
	_dispose(second)
	return failures

func _build_world(failures: Array[String], label: String) -> Dictionary:
	var world_script := load(WORLD_PATH)
	var fixture_script := load(FIXTURE_PATH)
	var interaction_script := load(INTERACTION_PATH)
	var smart_object_script := load(SMART_OBJECT_PATH)
	var job_definition_script := load(JOB_DEFINITION_PATH)
	if (
		world_script == null
		or fixture_script == null
		or interaction_script == null
		or smart_object_script == null
		or job_definition_script == null
	):
		failures.append("%s social/economy soak dependencies must load" % label)
		return {}

	var world = world_script.new()
	var property_names: Array[StringName] = []
	for property in world.get_property_list():
		property_names.append(StringName(property["name"]))
	if &"job_system" not in property_names:
		failures.append("SimulationWorld must expose job_system for autonomous income")
		return {}
	if &"household_expense_system" not in property_names:
		failures.append("SimulationWorld must expose household_expense_system for autonomous bills")
		return {}

	world.clock.set_time_scale(TIME_SCALE)
	world.household_expense_system.daily_amount = 180.0

	var fixture: Dictionary = fixture_script.new().build()
	if fixture.is_empty():
		failures.append("%s six-resident fixture must build" % label)
		return {}

	var residents: Array = fixture["residents"]
	if residents.size() != 6:
		failures.append("%s soak requires exactly six residents" % label)
		return {}

	for index in range(residents.size()):
		var resident = residents[index]
		resident.money = 40.0 + float(index * 5)
		resident.needs.hunger.value = 45.0 + float(index * 2)
		resident.needs.energy.value = 70.0 - float(index * 2)
		resident.needs.hygiene.value = 85.0
		resident.needs.comfort.value = 75.0
		resident.needs.social.value = 35.0 + float(index * 4)
		resident.needs.mood.value = 65.0
		resident.personality.impulsiveness = 0.15 + float(index) * 0.15
		resident.personality.sociability = 0.45 + float(index) * 0.08
		resident.personality.kindness = 0.75 - float(index) * 0.08

		var job = job_definition_script.new()
		job.id = StringName("job_%02d" % (index + 1))
		job.pay_per_sim_hour = 15.0 + float(index)
		job.shift_start_hour = 8.0
		job.shift_duration_hours = 8.0
		if not world.job_system.assign_job(resident, job):
			failures.append("%s resident %s must receive deterministic job" % [label, resident.id])

		if not world.add_character(resident):
			failures.append("%s resident %s must enter SimulationWorld" % [label, resident.id])

	var objects: Array = []

	var eat = interaction_script.new()
	eat.id = &"eat_free"
	eat.duration_sim_seconds = 10.0
	eat.need_effects = {"hunger": 65.0}

	var fridge = smart_object_script.new()
	fridge.object_id = &"fridge_main"
	fridge.interaction_point = Vector3(2.0, 0.0, 0.0)
	fridge.interactions.append(eat)
	world.register_smart_object(fridge)
	objects.append(fridge)

	for index in range(6):
		var sleep = interaction_script.new()
		sleep.id = StringName("sleep_%02d" % (index + 1))
		sleep.duration_sim_seconds = 30.0
		sleep.need_effects = {"energy": 75.0}

		var bed = smart_object_script.new()
		bed.object_id = StringName("bed_%02d" % (index + 1))
		bed.interaction_point = Vector3(-3.0 + float(index), 0.0, -2.0)
		bed.interactions.append(sleep)
		world.register_smart_object(bed)
		objects.append(bed)

	var relax = interaction_script.new()
	relax.id = &"relax_free"
	relax.duration_sim_seconds = 15.0
	relax.need_effects = {"comfort": 45.0, "mood": 15.0}

	var sofa = smart_object_script.new()
	sofa.object_id = &"sofa_main"
	sofa.interaction_point = Vector3(0.0, 0.0, 2.0)
	sofa.interactions.append(relax)
	world.register_smart_object(sofa)
	objects.append(sofa)

	var coffee = interaction_script.new()
	coffee.id = &"buy_coffee"
	coffee.duration_sim_seconds = 8.0
	coffee.need_effects = {"mood": 50.0, "comfort": 10.0}
	coffee.money_cost = 10.0

	var cafe = smart_object_script.new()
	cafe.object_id = &"coffee_machine"
	cafe.interaction_point = Vector3(3.0, 0.0, 2.0)
	cafe.interactions.append(coffee)
	world.register_smart_object(cafe)
	objects.append(cafe)

	return {
		"world": world,
		"residents": residents,
		"objects": objects,
	}

func _drive_navigation(state: Dictionary, step_index: int) -> void:
	var world = state["world"]
	var residents: Array = state["residents"]

	for resident_index in range(residents.size()):
		var resident = residents[resident_index]
		if resident.movement.status != MovementState.STATUS_MOVING:
			continue
		if resident.movement.intent == null:
			continue

		var target_id: StringName = resident.movement.intent.target_object_id
		var should_fail := ((step_index + resident_index * 29) % 211) == 0
		if should_fail:
			world.report_movement_failure(resident.id, target_id)
		else:
			world.report_arrival(resident.id, target_id)

func _validate_state(
	failures: Array[String],
	state: Dictionary,
	label: String,
	step_index: int
) -> void:
	var world = state["world"]
	var residents: Array = state["residents"]
	var objects: Array = state["objects"]
	var active_targets: Dictionary = {}
	var socially_reserved: Dictionary = {}

	for session in world.social_system.active_sessions():
		for resident_id in [session.initiator_id, session.target_id]:
			if socially_reserved.has(resident_id):
				failures.append("%s resident %s appears in multiple social sessions at step %d" % [label, resident_id, step_index])
			socially_reserved[resident_id] = true

	for resident in residents:
		if (
			is_nan(resident.money)
			or is_inf(resident.money)
			or resident.money < 0.0
		):
			failures.append("%s resident %s money invalid at step %d" % [label, resident.id, step_index])

		if resident.memory.size() > resident.memory.capacity:
			failures.append("%s resident %s memory exceeded capacity at step %d" % [label, resident.id, step_index])

		for need_name in ["hunger", "energy", "hygiene", "comfort", "social", "mood"]:
			var need_state = resident.needs.get(need_name)
			if need_state == null:
				failures.append("%s missing need %s at step %d" % [label, need_name, step_index])
				continue
			if is_nan(need_state.value) or is_inf(need_state.value):
				failures.append("%s need %s became non-finite at step %d" % [label, need_name, step_index])
			elif need_state.value < 0.0 or need_state.value > 100.0:
				failures.append("%s need %s left 0..100 at step %d" % [label, need_name, step_index])

		if socially_reserved.has(resident.id):
			if resident.movement.status != MovementState.STATUS_IDLE:
				failures.append("%s social resident %s must not be moving at step %d" % [label, resident.id, step_index])
			if resident.movement.intent != null:
				failures.append("%s social resident %s must not keep SmartObject intent at step %d" % [label, resident.id, step_index])

		if resident.current_action_id != &"idle" and resident.movement.intent != null:
			var target_id: StringName = resident.movement.intent.target_object_id
			active_targets[target_id] = int(active_targets.get(target_id, 0)) + 1
			if int(active_targets[target_id]) > 1:
				failures.append("%s target %s has multiple active residents at step %d" % [label, target_id, step_index])

	for object in objects:
		if object == null or not is_instance_valid(object):
			failures.append("%s lost SmartObject at step %d" % [label, step_index])
			continue
		var active_count := int(active_targets.get(object.object_id, 0))
		var locked: bool = not bool(object.is_available_for(&"reservation_probe"))
		if active_count == 0 and locked:
			failures.append("%s object %s has stale reservation at step %d" % [label, object.object_id, step_index])
		elif active_count == 1 and not locked:
			failures.append("%s active target %s must remain reserved at step %d" % [label, object.object_id, step_index])

	for edge in world.relationship_graph.all_relationships():
		var relationship = edge["state"]
		for value in [relationship.affinity, relationship.trust, relationship.tension]:
			if is_nan(value) or is_inf(value) or value < -100.0 or value > 100.0:
				failures.append("%s relationship left bounds at step %d" % [label, step_index])

func _snapshot(state: Dictionary) -> String:
	var world = state["world"]
	var parts: Array[String] = []

	for resident in state["residents"]:
		var target_id: StringName = &""
		if resident.movement.intent != null:
			target_id = resident.movement.intent.target_object_id
		parts.append(
			"%s:%s:%s:%s:%.2f:%d:%d:%d" % [
				resident.id,
				resident.current_action_id,
				resident.movement.status,
				target_id,
				resident.money,
				int(round(resident.needs.hunger.value)),
				int(round(resident.needs.social.value)),
				resident.memory.size(),
			]
		)

	parts.append("relationships:%d" % world.relationship_graph.all_relationships().size())
	parts.append("social:%d" % world.social_system.active_sessions().size())
	parts.append("tx:%d" % world.economy_system.transactions().size())
	parts.append("arrears:%.2f" % world.household_expense_system.arrears)
	return "|".join(parts)

func _dispose(state: Dictionary) -> void:
	if state.is_empty():
		return
	for object in state.get("objects", []):
		if object != null and is_instance_valid(object):
			object.free()
