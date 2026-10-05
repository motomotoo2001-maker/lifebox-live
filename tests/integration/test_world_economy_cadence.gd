extends RefCounted

const WORLD_PATH := "res://scripts/simulation/simulation_world.gd"
const CHARACTER_PATH := "res://scripts/simulation/characters/character_state.gd"
const JOB_DEFINITION_PATH := "res://scripts/simulation/economy/job_definition.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	var world_script := load(WORLD_PATH)
	var character_script := load(CHARACTER_PATH)
	var job_definition_script := load(JOB_DEFINITION_PATH)
	if world_script == null or character_script == null or job_definition_script == null:
		failures.append("world economy cadence dependencies must load")
		return failures

	var world = world_script.new()
	var resident = character_script.new(&"economy_cadence_worker", "Economy Cadence Worker")
	_disable_decay(resident)

	var job = job_definition_script.new()
	job.id = &"one_hour_job"
	job.pay_per_sim_hour = 60.0
	job.shift_start_hour = 0.0
	job.shift_duration_hours = 1.0

	if not world.job_system.assign_job(resident, job):
		failures.append("cadence test job must assign")
		return failures
	if not world.add_character(resident):
		failures.append("cadence test resident must enter world")
		return failures

	world.step(3600.0)

	if not is_equal_approx(resident.money, 60.0):
		failures.append("one simulated hour at 60/hour must earn exactly 60")
	if not is_equal_approx(resident.job.total_worked_sim_seconds, 3600.0):
		failures.append("one-hour shift must record exactly 3600 worked seconds")

	var transaction_count: int = world.economy_system.transactions().size()
	if transaction_count != 60:
		failures.append(
			"world economy must batch one-hour wages into 60 one-minute transactions, got %d"
			% transaction_count
		)

	return failures

func _disable_decay(resident) -> void:
	for need_name in ["hunger", "energy", "hygiene", "comfort", "social", "mood"]:
		resident.needs.get(need_name).decay_per_sim_hour = 0.0
