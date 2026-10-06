extends RefCounted

const WORLD_PATH := "res://scripts/simulation/simulation_world.gd"
const FIXTURE_PATH := "res://tests/fixtures/six_resident_household_fixture.gd"
const INTERACTION_PATH := "res://scripts/simulation/interactions/interaction_definition.gd"
const SMART_OBJECT_PATH := "res://scripts/simulation/interactions/smart_object.gd"
const JOB_DEFINITION_PATH := "res://scripts/simulation/economy/job_definition.gd"
const BLOCK_PATH := "res://scripts/simulation/schedules/schedule_block.gd"
const SCHEDULE_DEFINITION_PATH := "res://scripts/simulation/schedules/schedule_definition.gd"
const SNAPSHOT_PATH := "res://scripts/persistence/world_snapshot_codec.gd"

const TIME_SCALE := 20.0
const REAL_STEP_SECONDS := 1.0
const DAY_SECONDS := 86400.0
const SPLIT_SIM_SECONDS := 1.5 * DAY_SECONDS
const SPLIT_STEPS := int(SPLIT_SIM_SECONDS / (TIME_SCALE * REAL_STEP_SECONDS))
const TOTAL_STEPS := int((3.0 * DAY_SECONDS) / (TIME_SCALE * REAL_STEP_SECONDS)) - 1
const SAMPLE_EVERY_STEPS := 180

func run() -> Array[String]:
	var failures: Array[String] = []

	var world_script = load(WORLD_PATH)
	var fixture_script = load(FIXTURE_PATH)
	var interaction_script = load(INTERACTION_PATH)
	var smart_object_script = load(SMART_OBJECT_PATH)
	var job_definition_script = load(JOB_DEFINITION_PATH)
	var block_script = load(BLOCK_PATH)
	var schedule_definition_script = load(SCHEDULE_DEFINITION_PATH)
	var snapshot_script = load(SNAPSHOT_PATH)

	for script in [
		world_script,
		fixture_script,
		interaction_script,
		smart_object_script,
		job_definition_script,
		block_script,
		schedule_definition_script,
		snapshot_script,
	]:
		if script == null:
			failures.append("daily planning soak dependencies must load")
			return failures

	var control := _build_world(
		failures,
		world_script,
		fixture_script,
		interaction_script,
		smart_object_script,
		job_definition_script,
		block_script,
		schedule_definition_script,
		true
	)
	var save_source := _build_world(
		failures,
		world_script,
		fixture_script,
		interaction_script,
		smart_object_script,
		job_definition_script,
		block_script,
		schedule_definition_script,
		true
	)
	if control.is_empty() or save_source.is_empty():
		_dispose(control)
		_dispose(save_source)
		return failures

	for step_index in range(SPLIT_STEPS):
		_advance_and_drive(control, step_index)
		_advance_and_drive(save_source, step_index)
		if step_index % SAMPLE_EVERY_STEPS == 0:
			_validate_planning(failures, control, "control-pre", step_index)
			_validate_planning(failures, save_source, "save-pre", step_index)

	var control_mid: Dictionary = snapshot_script.encode(control["world"])
	var save_mid: Dictionary = snapshot_script.encode(save_source["world"])
	if control_mid != save_mid:
		failures.append("same-seed worlds must match exactly before Plan 05 save/load split")

	var restored := _build_world(
		failures,
		world_script,
		fixture_script,
		interaction_script,
		smart_object_script,
		job_definition_script,
		block_script,
		schedule_definition_script,
		false
	)
	if restored.is_empty():
		_dispose(control)
		_dispose(save_source)
		return failures

	var restore_errors: Array[String] = snapshot_script.restore(
		restored["world"],
		save_mid
	)
	if not restore_errors.is_empty():
		failures.append(
			"Plan 05 mid-run snapshot must restore: %s"
			% " | ".join(restore_errors)
	)
		_dispose(control)
		_dispose(save_source)
		_dispose(restored)
		return failures

	restored["residents"] = _residents_from_snapshot(
		restored["world"],
		save_mid
	)
	if snapshot_script.encode(restored["world"]) != save_mid:
		failures.append("restored Plan 05 world must exactly re-encode at split")

	_dispose(save_source)

	for local_step in range(TOTAL_STEPS - SPLIT_STEPS):
		var global_step := SPLIT_STEPS + local_step
		_advance_and_drive(control, global_step)
		_advance_and_drive(restored, global_step)
		if global_step % SAMPLE_EVERY_STEPS == 0:
			_validate_planning(failures, control, "control-post", global_step)
			_validate_planning(failures, restored, "restored-post", global_step)

	var control_final: Dictionary = snapshot_script.encode(control["world"])
	var restored_final: Dictionary = snapshot_script.encode(restored["world"])
	if control_final != restored_final:
		failures.append(
			"three-day save/load continuation must end at exact same full snapshot"
		)

	var expected_seconds := float(TOTAL_STEPS) * TIME_SCALE * REAL_STEP_SECONDS
	if not is_equal_approx(
		control["world"].clock.get_simulation_seconds(),
		expected_seconds
	):
		failures.append("control Plan 05 soak must finish at expected simulation time")
	if not is_equal_approx(
		restored["world"].clock.get_simulation_seconds(),
		expected_seconds
	):
		failures.append("restored Plan 05 soak must finish at expected simulation time")

	if int(floor(expected_seconds / DAY_SECONDS)) != 2:
		failures.append("Plan 05 soak must end inside simulated day 2")

	_validate_planning(failures, control, "control-final", TOTAL_STEPS)
	_validate_planning(failures, restored, "restored-final", TOTAL_STEPS)
	_validate_three_days_seen(failures, control)
	_validate_schedule_diversity(failures, control)
	_validate_reservations(failures, control, "control-final")
	_validate_reservations(failures, restored, "restored-final")
	_validate_critical_need_safety(failures, control)

	_dispose(control)
	_dispose(restored)
	return failures

func _build_world(
	failures: Array[String],
	world_script,
	fixture_script,
	interaction_script,
	smart_object_script,
	job_definition_script,
	block_script,
	schedule_definition_script,
	with_residents: bool
) -> Dictionary:
	var world = world_script.new()
	world.clock.set_time_scale(TIME_SCALE)
	world.household_expense_system.daily_amount = 180.0

	var objects: Array = []

	var eat = interaction_script.new()
	eat.id = &"eat_free"
	eat.duration_sim_seconds = 10.0
	eat.need_effects = {"hunger": 65.0}
	eat.action_tags.append(&"eat")

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
		sleep.action_tags.append(&"sleep")

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
	relax.action_tags.append(&"relax")

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
	coffee.action_tags.append(&"relax")
	coffee.action_tags.append(&"spend")

	var cafe = smart_object_script.new()
	cafe.object_id = &"coffee_machine"
	cafe.interaction_point = Vector3(3.0, 0.0, 2.0)
	cafe.interactions.append(coffee)
	world.register_smart_object(cafe)
	objects.append(cafe)

	for index in range(6):
		var work = interaction_script.new()
		work.id = StringName("work_activity_%02d" % (index + 1))
		work.duration_sim_seconds = 20.0
		work.need_effects = {"mood": 4.0}
		work.action_tags.append(&"work")

		var desk = smart_object_script.new()
		desk.object_id = StringName("desk_%02d" % (index + 1))
		desk.interaction_point = Vector3(-3.0 + float(index), 0.0, 4.0)
		desk.interactions.append(work)
		world.register_smart_object(desk)
		objects.append(desk)

	var residents: Array = []
	if with_residents:
		var fixture: Dictionary = fixture_script.new().build()
		if fixture.is_empty():
			failures.append("Plan 05 six-resident fixture must build")
			_dispose({"objects": objects})
			return {}

		residents = fixture["residents"]
		if residents.size() != 6:
			failures.append("Plan 05 soak requires exactly six residents")
			_dispose({"objects": objects})
			return {}

		for index in range(residents.size()):
			var resident = residents[index]
			resident.money = 60.0 + float(index * 5)
			resident.needs.hunger.value = 55.0 + float(index)
			resident.needs.energy.value = 75.0 - float(index * 2)
			resident.needs.hygiene.value = 85.0
			resident.needs.comfort.value = 70.0
			resident.needs.social.value = 45.0
			resident.needs.mood.value = 65.0

			resident.personality.sociability = 0.35
			resident.personality.ambition = 0.35
			resident.personality.impulsiveness = 0.35
			if index == 0:
				resident.personality.sociability = 1.0
			elif index == 1:
				resident.personality.ambition = 1.0
			elif index == 2:
				resident.personality.impulsiveness = 1.0
			else:
				resident.personality.sociability = 0.45 + float(index) * 0.05
				resident.personality.ambition = 0.4 + float(index) * 0.07
				resident.personality.impulsiveness = 0.25 + float(index) * 0.08

			var shift_start := 8.0 + float(index) * 1.5
			var shift_duration := 6.0
			var job = job_definition_script.new()
			job.id = StringName("job_%02d" % (index + 1))
			job.pay_per_sim_hour = 15.0 + float(index)
			job.shift_start_hour = shift_start
			job.shift_duration_hours = shift_duration
			if not world.job_system.assign_job(resident, job):
				failures.append("Plan 05 resident %s must receive job" % resident.id)

			resident.schedule.definition = _build_schedule(
				block_script,
				schedule_definition_script,
				shift_start,
				shift_duration,
				index
			)
			if not resident.schedule.definition.validate().is_empty():
				failures.append("Plan 05 resident schedule must validate: %s" % resident.id)

			if not world.add_character(resident):
				failures.append("Plan 05 resident %s must enter world" % resident.id)

		for index in range(residents.size()):
			var from_resident = residents[index]
			var to_resident = residents[(index + 1) % residents.size()]
			world.relationship_graph.get_or_create(
				from_resident.id,
				to_resident.id
			).apply_delta(
				20.0 + float(index * 5),
				10.0,
				0.0
			)

	return {
		"world": world,
		"residents": residents,
		"objects": objects,
		"goal_signatures": {},
		"days_seen": {},
		"eat_interaction": eat,
		"relax_interaction": relax,
	}

func _build_schedule(
	block_script,
	schedule_definition_script,
	shift_start: float,
	shift_duration: float,
	index: int
):
	var schedule = schedule_definition_script.new()

	var sleep = block_script.new()
	sleep.id = &"sleep"
	sleep.kind = &"sleep"
	sleep.start_hour = 22.0
	sleep.duration_hours = 8.0
	sleep.preferred_action_tags.append(&"sleep")
	schedule.blocks.append(sleep)

	var meal = block_script.new()
	meal.id = &"breakfast"
	meal.kind = &"meal"
	meal.start_hour = 6.0
	meal.duration_hours = 1.0
	meal.preferred_action_tags.append(&"eat")
	schedule.blocks.append(meal)

	var morning = block_script.new()
	morning.id = &"free_morning"
	morning.kind = &"free_time"
	morning.start_hour = 7.0
	morning.duration_hours = shift_start - 7.0
	morning.preferred_action_tags.append(&"relax")
	if index % 2 == 0:
		morning.preferred_action_tags.append(&"social")
	schedule.blocks.append(morning)

	var work = block_script.new()
	work.id = &"work"
	work.kind = &"work"
	work.start_hour = shift_start
	work.duration_hours = shift_duration
	work.preferred_action_tags.append(&"work")
	schedule.blocks.append(work)

	var evening = block_script.new()
	evening.id = &"free_evening"
	evening.kind = &"free_time"
	evening.start_hour = shift_start + shift_duration
	evening.duration_hours = 22.0 - evening.start_hour
	evening.preferred_action_tags.append(&"relax")
	evening.preferred_action_tags.append(&"social")
	schedule.blocks.append(evening)

	return schedule

func _advance_and_drive(state: Dictionary, step_index: int) -> void:
	state["world"].step(REAL_STEP_SECONDS)
	_drive_navigation(state, step_index)

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

func _validate_planning(
	failures: Array[String],
	state: Dictionary,
	label: String,
	step_index: int
) -> void:
	var world = state["world"]
	var residents: Array = state["residents"]
	var sim_seconds: float = world.clock.get_simulation_seconds()
	var day_index := int(floor(sim_seconds / DAY_SECONDS))
	var hour := fmod(sim_seconds, DAY_SECONDS) / 3600.0

	for resident_index in range(residents.size()):
		var resident = residents[resident_index]
		if resident.schedule.day_index != day_index:
			failures.append(
				"%s resident %s schedule day mismatch at step %d"
				% [label, resident.id, step_index]
			)
		if resident.goals.day_index != day_index:
			failures.append(
				"%s resident %s goal day mismatch at step %d"
				% [label, resident.id, step_index]
			)

		var daily_goals: Array = resident.goals.goals()
		var active_goals: Array = resident.goals.active_goals()
		if daily_goals.size() < 1 or daily_goals.size() > 3:
			failures.append(
				"%s resident %s must have 1..3 generated daily goals at step %d"
				% [label, resident.id, step_index]
			)

		var ids: Array[String] = []
		var seen: Dictionary = {}
		for goal in daily_goals:
			var goal_id := str(goal.definition.id)
			ids.append(goal_id)
			if seen.has(goal_id):
				failures.append(
					"%s resident %s duplicate daily goal %s"
					% [label, resident.id, goal_id]
				)
			seen[goal_id] = true
			if not goal_id.ends_with("_day_%d" % day_index):
				failures.append(
					"%s resident %s goal belongs to wrong day: %s"
					% [label, resident.id, goal_id]
				)
			if goal.status == GoalState.STATUS_COMPLETED:
				if not is_equal_approx(goal.progress, 1.0):
					failures.append(
						"%s resident %s completed goal must have full progress: %s"
						% [label, resident.id, goal_id]
					)
			elif goal.status == GoalState.STATUS_ACTIVE:
				if goal.progress < 0.0 or goal.progress >= 1.0:
					failures.append(
						"%s resident %s active goal progress must stay inside 0..<1: %s"
						% [label, resident.id, goal_id]
					)
			elif goal.status != GoalState.STATUS_FAILED:
				failures.append(
					"%s resident %s has invalid goal status: %s"
					% [label, resident.id, goal_id]
				)

		if active_goals.size() > daily_goals.size():
			failures.append(
				"%s resident %s active goal view exceeds daily goal history"
				% [label, resident.id]
			)

		var signature := ",".join(ids)
		var signature_key := "%s:%d" % [resident.id, day_index]
		var signatures: Dictionary = state["goal_signatures"]
		if signatures.has(signature_key):
			if signatures[signature_key] != signature:
				failures.append(
					"%s resident %s regenerated goals inside day %d"
					% [label, resident.id, day_index]
				)
		else:
			signatures[signature_key] = signature

		var days_seen: Dictionary = state["days_seen"]
		days_seen[signature_key] = true

		var expected_block = resident.schedule.definition.active_block_at(hour)
		var expected_id: StringName = expected_block.id if expected_block != null else &""
		if resident.schedule.active_block_id != expected_id:
			failures.append(
				"%s resident %s active schedule block mismatch at hour %.2f"
				% [label, resident.id, hour]
			)

		if resident_index == 0 and not _has_category(daily_goals, &"social"):
			failures.append("dominant social resident must receive social goal each day")
		if resident_index == 1 and not _has_category(daily_goals, &"work"):
			failures.append("dominant ambitious resident must receive work goal each day")
		if resident_index == 2 and not _has_category(daily_goals, &"fun"):
			failures.append("dominant impulsive resident must receive fun goal each day")

func _validate_three_days_seen(
	failures: Array[String],
	state: Dictionary
) -> void:
	var days_seen: Dictionary = state["days_seen"]
	for resident in state["residents"]:
		for day_index in range(3):
			var key := "%s:%d" % [resident.id, day_index]
			if not days_seen.has(key):
				failures.append(
					"control soak must observe resident %s planning on day %d"
					% [resident.id, day_index]
				)

func _validate_schedule_diversity(
	failures: Array[String],
	state: Dictionary
) -> void:
	var starts: Dictionary = {}
	for resident in state["residents"]:
		for block in resident.schedule.definition.blocks:
			if block.kind == &"work":
				starts[str(block.start_hour)] = true
	if starts.size() < 3:
		failures.append("resident job context must produce visibly different work schedules")

func _validate_critical_need_safety(
	failures: Array[String],
	state: Dictionary
) -> void:
	var world = state["world"]
	var resident = state["residents"][0]
	var old_hunger: float = resident.needs.hunger.value
	var old_energy: float = resident.needs.energy.value
	var old_comfort: float = resident.needs.comfort.value
	var old_mood: float = resident.needs.mood.value

	resident.needs.hunger.value = 10.0
	resident.needs.energy.value = 100.0
	resident.needs.comfort.value = 0.0
	resident.needs.mood.value = 0.0

	var interaction_script = load(INTERACTION_PATH)
	var eat_probe = interaction_script.new()
	eat_probe.id = &"critical_eat_probe"
	eat_probe.need_effects = {"hunger": 20.0}
	eat_probe.action_tags.append(&"eat")

	var relax_probe = interaction_script.new()
	relax_probe.id = &"critical_relax_probe"
	relax_probe.need_effects = {"comfort": 100.0, "mood": 100.0}
	relax_probe.action_tags.append(&"relax")

	var eat_base: float = (100.0 - resident.needs.hunger.value) * 20.0
	var relax_base: float = (
		(100.0 - resident.needs.comfort.value) * 100.0
		+ (100.0 - resident.needs.mood.value) * 100.0
	)
	var eat_score: float = world.decision_bias_system.adjust(
		resident,
		eat_probe,
		eat_base,
		world.clock.get_simulation_seconds(),
		world.relationship_graph
	)
	var relax_score: float = world.decision_bias_system.adjust(
		resident,
		relax_probe,
		relax_base,
		world.clock.get_simulation_seconds(),
		world.relationship_graph
	)
	if eat_score <= relax_score:
		failures.append(
			"critical hunger safety must override a much larger preferred relax base score"
		)

	resident.needs.hunger.value = old_hunger
	resident.needs.energy.value = old_energy
	resident.needs.comfort.value = old_comfort
	resident.needs.mood.value = old_mood

func _validate_reservations(
	failures: Array[String],
	state: Dictionary,
	label: String
) -> void:
	var world = state["world"]
	var residents: Array = state["residents"]
	var objects: Array = state["objects"]
	var active_targets: Dictionary = {}
	var social_residents: Dictionary = {}

	for session in world.social_system.active_sessions():
		for resident_id in [session.initiator_id, session.target_id]:
			if social_residents.has(resident_id):
				failures.append(
					"%s duplicate social reservation for %s"
					% [label, resident_id]
				)
			social_residents[resident_id] = true

	for resident in residents:
		if social_residents.has(resident.id):
			if resident.movement.intent != null:
				failures.append(
					"%s social resident %s must not hold movement intent"
					% [label, resident.id]
				)
			continue
		if resident.current_action_id != &"idle" and resident.movement.intent != null:
			var target_id: StringName = resident.movement.intent.target_object_id
			active_targets[target_id] = int(active_targets.get(target_id, 0)) + 1
			if int(active_targets[target_id]) > 1:
				failures.append(
					"%s duplicate SmartObject claim: %s"
					% [label, target_id]
				)

	for object in objects:
		if object == null or not is_instance_valid(object):
			failures.append("%s lost SmartObject during soak" % label)
			continue
		var active_count := int(active_targets.get(object.object_id, 0))
		var locked := not bool(object.is_available_for(&"reservation_probe"))
		if active_count == 0 and locked:
			failures.append(
				"%s stale SmartObject reservation: %s"
				% [label, object.object_id]
			)
		elif active_count == 1 and not locked:
			failures.append(
				"%s active SmartObject must remain reserved: %s"
				% [label, object.object_id]
			)

func _residents_from_snapshot(world, snapshot: Dictionary) -> Array:
	var residents: Array = []
	for resident_data in snapshot.get("residents", []):
		var resident = world.get_character(StringName(resident_data["id"]))
		if resident != null:
			residents.append(resident)
	return residents

func _has_category(goals: Array, category: StringName) -> bool:
	for goal in goals:
		if goal != null and goal.definition != null:
			if goal.definition.category == category:
				return true
	return false

func _dispose(state: Dictionary) -> void:
	if state.is_empty():
		return
	for object in state.get("objects", []):
		if object != null and is_instance_valid(object):
			object.free()
