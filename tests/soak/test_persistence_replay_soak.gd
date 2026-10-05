extends RefCounted

const WORLD_PATH := "res://scripts/simulation/simulation_world.gd"
const FIXTURE_PATH := "res://tests/fixtures/six_resident_household_fixture.gd"
const INTERACTION_PATH := "res://scripts/simulation/interactions/interaction_definition.gd"
const SMART_OBJECT_PATH := "res://scripts/simulation/interactions/smart_object.gd"
const JOB_DEFINITION_PATH := "res://scripts/simulation/economy/job_definition.gd"
const SNAPSHOT_PATH := "res://scripts/persistence/world_snapshot_codec.gd"
const SAVE_SERVICE_PATH := "res://scripts/persistence/save_service.gd"
const REPLAY_LOG_PATH := "res://scripts/replay/replay_log.gd"
const REPLAY_PLAYER_PATH := "res://scripts/replay/replay_player.gd"

const TIME_SCALE := 20.0
const REAL_STEP_SECONDS := 1.0
const HALF_SIM_SECONDS := 4.0 * 3600.0
const HALF_STEPS := int(HALF_SIM_SECONDS / (TIME_SCALE * REAL_STEP_SECONDS))
const TOTAL_SIM_SECONDS := 8.0 * 3600.0
const REPLAY_STEPS := 60
const SAVE_PATH := "user://lifebox_persistence_replay_soak.json"

func run() -> Array[String]:
	var failures: Array[String] = []
	_cleanup_save_files()

	var world_script := load(WORLD_PATH)
	var fixture_script := load(FIXTURE_PATH)
	var interaction_script := load(INTERACTION_PATH)
	var smart_object_script := load(SMART_OBJECT_PATH)
	var job_definition_script := load(JOB_DEFINITION_PATH)
	var snapshot_script := load(SNAPSHOT_PATH)
	var save_service_script := load(SAVE_SERVICE_PATH)
	var replay_log_script := load(REPLAY_LOG_PATH)
	var replay_player_script := load(REPLAY_PLAYER_PATH)

	if (
		world_script == null
		or fixture_script == null
		or interaction_script == null
		or smart_object_script == null
		or job_definition_script == null
		or snapshot_script == null
		or save_service_script == null
		or replay_log_script == null
		or replay_player_script == null
	):
		failures.append("persistence replay soak dependencies must load")
		return failures

	var control := _build_world(
		failures,
		world_script,
		fixture_script,
		interaction_script,
		smart_object_script,
		job_definition_script,
		true
	)
	var save_source := _build_world(
		failures,
		world_script,
		fixture_script,
		interaction_script,
		smart_object_script,
		job_definition_script,
		true
	)
	if control.is_empty() or save_source.is_empty():
		_dispose(control)
		_dispose(save_source)
		return failures

	for step_index in range(HALF_STEPS):
		_advance_and_drive(control, step_index)
		_advance_and_drive(save_source, step_index)

	var control_mid: Dictionary = snapshot_script.encode(control["world"])
	var save_mid: Dictionary = snapshot_script.encode(save_source["world"])
	if control_mid != save_mid:
		failures.append("identical worlds must match before save/load split")

	var envelope := SaveSchema.create_envelope({"world": save_mid})
	if not save_service_script.save_envelope(SAVE_PATH, envelope):
		failures.append("first soak disk save must succeed")
	if not save_service_script.save_envelope(SAVE_PATH, envelope):
		failures.append("second soak disk save must succeed and create backup")

	var restored := _build_world(
		failures,
		world_script,
		fixture_script,
		interaction_script,
		smart_object_script,
		job_definition_script,
		false
	)
	if restored.is_empty():
		_dispose(control)
		_dispose(save_source)
		_cleanup_save_files()
		return failures

	var restore_errors: Array[String] = snapshot_script.restore(
		restored["world"],
		save_mid
	)
	if not restore_errors.is_empty():
		failures.append(
			"mid-soak snapshot must restore: %s"
			% " | ".join(restore_errors)
		)
	else:
		restored["residents"] = _residents_from_snapshot(
			restored["world"],
			save_mid
		)
		if snapshot_script.encode(restored["world"]) != save_mid:
			failures.append("freshly restored mid-soak world must exactly match snapshot")

	_dispose(save_source)

	if restore_errors.is_empty():
		for local_step in range(HALF_STEPS):
			var global_step := HALF_STEPS + local_step
			_advance_and_drive(control, global_step)
			_advance_and_drive(restored, global_step)

		var control_final: Dictionary = snapshot_script.encode(control["world"])
		var restored_final: Dictionary = snapshot_script.encode(restored["world"])
		if control_final != restored_final:
			failures.append(
				"save/load continuation must end at exact same full snapshot as control"
			)

		if not is_equal_approx(
			control["world"].clock.get_simulation_seconds(),
			TOTAL_SIM_SECONDS
		):
			failures.append("control continuation must finish exactly eight simulated hours")
		if not is_equal_approx(
			restored["world"].clock.get_simulation_seconds(),
			TOTAL_SIM_SECONDS
		):
			failures.append("restored continuation must finish exactly eight simulated hours")

		_validate_reservations(failures, control, "control-final")
		_validate_reservations(failures, restored, "restored-final")

	_test_disk_backup_recovery(
		failures,
		save_service_script,
		save_mid,
		world_script,
		fixture_script,
		interaction_script,
		smart_object_script,
		job_definition_script,
		snapshot_script
	)
	_test_replay_segment(
		failures,
		world_script,
		fixture_script,
		interaction_script,
		smart_object_script,
		job_definition_script,
		snapshot_script,
		replay_log_script,
		replay_player_script
	)

	_dispose(control)
	_dispose(restored)
	_cleanup_save_files()
	return failures

func _test_disk_backup_recovery(
	failures: Array[String],
	save_service_script,
	expected_world_snapshot: Dictionary,
	world_script,
	fixture_script,
	interaction_script,
	smart_object_script,
	job_definition_script,
	snapshot_script
) -> void:
	if not FileAccess.file_exists(SAVE_PATH + ".bak"):
		failures.append("second disk save must create backup for recovery test")
		return

	var main := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if main == null:
		failures.append("recovery test must be able to corrupt main save")
		return
	main.store_string("{ broken soak save")
	main.close()

	var recovered: Dictionary = save_service_script.load_envelope(SAVE_PATH)
	if recovered.is_empty():
		failures.append("corrupt soak main save must recover from backup")
		return
	if not recovered.has("payload") or not recovered["payload"] is Dictionary:
		failures.append("recovered soak envelope must contain payload")
		return
	var recovered_world = recovered["payload"].get("world", {})
	if recovered_world != expected_world_snapshot:
		failures.append(
			"backup recovery must return exact saved world snapshot; first diff: %s"
			% _first_difference(expected_world_snapshot, recovered_world, "world")
		)

	var restore_target := _build_world(
		failures,
		world_script,
		fixture_script,
		interaction_script,
		smart_object_script,
		job_definition_script,
		false
	)
	if restore_target.is_empty():
		return

	var restore_errors: Array[String] = snapshot_script.restore(
		restore_target["world"],
		recovered_world
	)
	if not restore_errors.is_empty():
		failures.append(
			"disk-recovered world snapshot must restore: %s"
			% " | ".join(restore_errors)
		)
	else:
		restore_target["residents"] = _residents_from_snapshot(
			restore_target["world"],
			recovered_world
		)
		var reencoded: Dictionary = snapshot_script.encode(restore_target["world"])
		if reencoded != expected_world_snapshot:
			failures.append(
				"disk-recovered world must re-encode to exact saved snapshot; first diff: %s"
				% _first_difference(expected_world_snapshot, reencoded, "world")
			)
		_validate_reservations(failures, restore_target, "disk-recovered")

	_dispose(restore_target)

func _test_replay_segment(
	failures: Array[String],
	world_script,
	fixture_script,
	interaction_script,
	smart_object_script,
	job_definition_script,
	snapshot_script,
	replay_log_script,
	replay_player_script
) -> void:
	var replay_control := _build_world(
		failures,
		world_script,
		fixture_script,
		interaction_script,
		smart_object_script,
		job_definition_script,
		true
	)
	if replay_control.is_empty():
		return

	var initial_snapshot: Dictionary = snapshot_script.encode(replay_control["world"])
	var replay_log = replay_log_script.new()

	for step_index in range(REPLAY_STEPS):
		if not replay_log.append(&"advance", {"real_delta": REAL_STEP_SECONDS}):
			failures.append("replay soak advance event must append")
			_dispose(replay_control)
			return

		replay_control["world"].step(REAL_STEP_SECONDS)
		_record_and_apply_navigation(
			failures,
			replay_control,
			step_index,
			replay_log
		)

	var expected_final: Dictionary = snapshot_script.encode(replay_control["world"])

	var replay_target := _build_world(
		failures,
		world_script,
		fixture_script,
		interaction_script,
		smart_object_script,
		job_definition_script,
		false
	)
	if replay_target.is_empty():
		_dispose(replay_control)
		return

	var replay_errors: Array[String] = replay_player_script.replay(
		replay_target["world"],
		initial_snapshot,
		replay_log.events()
	)
	if not replay_errors.is_empty():
		failures.append(
			"bounded soak replay must succeed: %s"
			% " | ".join(replay_errors)
		)
	else:
		replay_target["residents"] = _residents_from_snapshot(
			replay_target["world"],
			expected_final
		)
		var replay_final: Dictionary = snapshot_script.encode(replay_target["world"])
		if replay_final != expected_final:
			failures.append("bounded recorded replay must reach exact control snapshot")
		_validate_reservations(failures, replay_target, "replay-final")

	_dispose(replay_control)
	_dispose(replay_target)

func _record_and_apply_navigation(
	failures: Array[String],
	state: Dictionary,
	step_index: int,
	replay_log
) -> void:
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
		var kind: StringName = &"movement_failed" if should_fail else &"movement_arrived"
		var payload := {
			"character_id": str(resident.id),
			"target_object_id": str(target_id),
		}
		if not replay_log.append(kind, payload):
			failures.append("navigation replay event must append")
			return

		if should_fail:
			if not world.report_movement_failure(resident.id, target_id):
				failures.append("control movement failure feedback must apply")
		else:
			if not world.report_arrival(resident.id, target_id):
				failures.append("control movement arrival feedback must apply")

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

func _build_world(
	failures: Array[String],
	world_script,
	fixture_script,
	interaction_script,
	smart_object_script,
	job_definition_script,
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

	var residents: Array = []
	if with_residents:
		var fixture: Dictionary = fixture_script.new().build()
		if fixture.is_empty():
			failures.append("six-resident persistence fixture must build")
			_dispose({"objects": objects})
			return {}

		residents = fixture["residents"]
		if residents.size() != 6:
			failures.append("persistence soak requires exactly six residents")
			_dispose({"objects": objects})
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
				failures.append("resident %s must receive deterministic soak job" % resident.id)

			if not world.add_character(resident):
				failures.append("resident %s must enter persistence soak world" % resident.id)

	return {
		"world": world,
		"residents": residents,
		"objects": objects,
	}

func _residents_from_snapshot(world, snapshot: Dictionary) -> Array:
	var residents: Array = []
	for resident_data in snapshot.get("residents", []):
		var resident = world.get_character(StringName(resident_data["id"]))
		if resident != null:
			residents.append(resident)
	return residents

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
				failures.append("%s duplicate social reservation for %s" % [label, resident_id])
			social_residents[resident_id] = true

	for resident in residents:
		if social_residents.has(resident.id):
			if resident.movement.intent != null:
				failures.append("%s social resident %s must not hold movement intent" % [label, resident.id])
			continue

		if resident.current_action_id != &"idle" and resident.movement.intent != null:
			var target_id: StringName = resident.movement.intent.target_object_id
			active_targets[target_id] = int(active_targets.get(target_id, 0)) + 1
			if int(active_targets[target_id]) > 1:
				failures.append("%s duplicate SmartObject claim: %s" % [label, target_id])

	for object in objects:
		if object == null or not is_instance_valid(object):
			failures.append("%s lost SmartObject during soak" % label)
			continue

		var active_count := int(active_targets.get(object.object_id, 0))
		var locked := not bool(object.is_available_for(&"reservation_probe"))
		if active_count == 0 and locked:
			failures.append("%s stale SmartObject reservation: %s" % [label, object.object_id])
		elif active_count == 1 and not locked:
			failures.append("%s active SmartObject must remain reserved: %s" % [label, object.object_id])

func _cleanup_save_files() -> void:
	for path in [SAVE_PATH, SAVE_PATH + ".tmp", SAVE_PATH + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _dispose(state: Dictionary) -> void:
	if state.is_empty():
		return
	for object in state.get("objects", []):
		if object != null and is_instance_valid(object):
			object.free()


func _first_difference(expected, actual, path: String) -> String:
	var expected_type := typeof(expected)
	var actual_type := typeof(actual)

	if expected_type != actual_type:
		return "%s type %s != %s (%s vs %s)" % [
			path,
			type_string(expected_type),
			type_string(actual_type),
			str(expected),
			str(actual),
		]

	if expected is Dictionary:
		var expected_keys: Array = expected.keys()
		var actual_keys: Array = actual.keys()
		for key in expected_keys:
			if not actual.has(key):
				return "%s missing key %s" % [path, str(key)]
			var nested := _first_difference(
				expected[key],
				actual[key],
				"%s.%s" % [path, str(key)]
			)
			if not nested.is_empty():
				return nested
		for key in actual_keys:
			if not expected.has(key):
				return "%s unexpected key %s" % [path, str(key)]
		return ""

	if expected is Array:
		if expected.size() != actual.size():
			return "%s array size %d != %d" % [path, expected.size(), actual.size()]
		for index in range(expected.size()):
			var nested := _first_difference(
				expected[index],
				actual[index],
				"%s[%d]" % [path, index]
			)
			if not nested.is_empty():
				return nested
		return ""

	if expected is float:
		if expected != actual:
			return "%s float delta=%s expected=%s actual=%s" % [
				path,
				str(absf(expected - actual)),
				str(expected),
				str(actual),
			]
		return ""

	if expected != actual:
		return "%s %s != %s" % [path, str(expected), str(actual)]

	return ""

