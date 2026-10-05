extends RefCounted

const POLICY_PATH := "res://scripts/simulation/movement/stuck_recovery_policy.gd"
const WORLD_PATH := "res://scripts/simulation/simulation_world.gd"
const CHARACTER_PATH := "res://scripts/simulation/characters/character_state.gd"
const INTERACTION_PATH := "res://scripts/simulation/interactions/interaction_definition.gd"
const SMART_OBJECT_PATH := "res://scripts/simulation/interactions/smart_object.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	if not FileAccess.file_exists(POLICY_PATH):
		failures.append("StuckRecoveryPolicy must exist at %s" % POLICY_PATH)
		return failures

	var policy_script := load(POLICY_PATH)
	var world_script := load(WORLD_PATH)
	var character_script := load(CHARACTER_PATH)
	var interaction_script := load(INTERACTION_PATH)
	var smart_object_script := load(SMART_OBJECT_PATH)
	if policy_script == null or world_script == null or character_script == null or interaction_script == null or smart_object_script == null:
		failures.append("stuck recovery dependencies must load")
		return failures

	var policy = policy_script.new()
	if not is_equal_approx(policy.movement_timeout_sim_seconds, 30.0):
		failures.append("default movement timeout must be 30 simulated seconds")
	if policy.max_retries != 2:
		failures.append("default movement max retries must be 2")

	var world = world_script.new()
	if world.get("stuck_recovery_policy") == null:
		failures.append("SimulationWorld must expose stuck_recovery_policy")
		return failures

	var resident = character_script.new(&"resident_stuck", "Stuck Resident")
	resident.needs.hunger.value = 10.0
	resident.needs.energy.value = 100.0
	for need_name in ["hunger", "energy", "hygiene", "comfort", "social", "mood"]:
		resident.needs.get(need_name).decay_per_sim_hour = 0.0
	if not world.add_character(resident):
		failures.append("stuck recovery resident must enter world")

	var eat = interaction_script.new()
	eat.id = &"eat"
	eat.duration_sim_seconds = 1.0
	eat.need_effects = {"hunger": 100.0}

	var fridge = smart_object_script.new()
	fridge.object_id = &"fridge_main"
	fridge.interaction_point = Vector3(2.0, 0.0, 0.0)
	fridge.interactions.append(eat)
	world.register_smart_object(fridge)

	var sleep = interaction_script.new()
	sleep.id = &"sleep"
	sleep.duration_sim_seconds = 1.0
	sleep.need_effects = {"energy": 100.0}

	var bed = smart_object_script.new()
	bed.object_id = &"bed_main"
	bed.interaction_point = Vector3(-2.0, 0.0, 0.0)
	bed.interactions.append(sleep)
	world.register_smart_object(bed)

	world.step(1.0)
	if resident.current_action_id != &"eat" or resident.movement.status != &"moving":
		failures.append("resident must begin moving toward fridge before watchdog test")

	world.step(29.0)
	world.step(1.0)
	if resident.movement.status != &"moving":
		failures.append("first movement timeout must retry instead of fail")
	if resident.movement.retry_count != 1:
		failures.append("first movement timeout must increment retry count to 1")
	if not is_equal_approx(resident.movement.elapsed_sim_seconds, 0.0):
		failures.append("first retry must reset movement elapsed time")
	if fridge.is_available_for(&"reservation_probe"):
		failures.append("retry must keep target reservation")

	world.step(29.0)
	world.step(1.0)
	if resident.movement.status != &"moving":
		failures.append("second movement timeout must retry instead of fail")
	if resident.movement.retry_count != 2:
		failures.append("second movement timeout must increment retry count to 2")
	if not is_equal_approx(resident.movement.elapsed_sim_seconds, 0.0):
		failures.append("second retry must reset movement elapsed time")

	world.step(29.0)
	world.step(1.0)
	if resident.current_action_id != &"idle":
		failures.append("exhausted movement retries must cancel current action")
	if resident.movement.status != &"failed":
		failures.append("exhausted movement retries must mark movement failed")
	if resident.movement.retry_count != 2:
		failures.append("failed movement must preserve exhausted retry count")
	if not fridge.is_available_for(&"reservation_probe"):
		failures.append("failed movement must release reserved target")

	fridge.free()
	resident.needs.energy.value = 5.0
	world.step(1.0)
	if resident.current_action_id != &"sleep":
		failures.append("resident must be able to select another action after stuck recovery")
	if resident.movement.status != &"moving":
		failures.append("new action after stuck recovery must start movement")
	if resident.movement.retry_count != 0:
		failures.append("new movement target must start with a fresh retry count")

	bed.free()
	return failures
