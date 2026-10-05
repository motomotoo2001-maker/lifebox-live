extends RefCounted

const JOB_DEFINITION_PATH := "res://scripts/simulation/economy/job_definition.gd"
const JOB_STATE_PATH := "res://scripts/simulation/economy/job_state.gd"
const JOB_SYSTEM_PATH := "res://scripts/simulation/economy/job_system.gd"
const ECONOMY_PATH := "res://scripts/simulation/economy/economy_system.gd"
const CHARACTER_PATH := "res://scripts/simulation/characters/character_state.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	for path in [JOB_DEFINITION_PATH, JOB_STATE_PATH, JOB_SYSTEM_PATH]:
		if not FileAccess.file_exists(path):
			failures.append("job dependency must exist at %s" % path)
			return failures

	var definition_script := load(JOB_DEFINITION_PATH)
	var job_system_script := load(JOB_SYSTEM_PATH)
	var economy_script := load(ECONOMY_PATH)
	var character_script := load(CHARACTER_PATH)
	if definition_script == null or job_system_script == null or economy_script == null or character_script == null:
		failures.append("job system dependencies must load")
		return failures

	var worker = character_script.new(&"worker", "Worker")
	if worker.job == null:
		failures.append("CharacterState must create JobState")
		return failures

	var definition = definition_script.new()
	definition.id = &"shop_clerk"
	definition.pay_per_sim_hour = 18.0
	definition.shift_start_hour = 9.0
	definition.shift_duration_hours = 8.0

	var jobs = job_system_script.new()
	var economy = economy_script.new()

	if not jobs.assign_job(worker, definition):
		failures.append("valid job definition must be assignable")
	if worker.job.definition != definition:
		failures.append("assigned JobState must retain definition")

	var earned_half_hour: float = jobs.advance_character(
		worker,
		3600.0,
		9.5 * 3600.0,
		economy
	)
	if not is_equal_approx(earned_half_hour, 9.0):
		failures.append("08:30-09:30 interval must earn exactly half an hour of shift pay")
	if not is_equal_approx(worker.money, 9.0):
		failures.append("job earnings must deposit into resident balance")
	if not is_equal_approx(worker.job.total_worked_sim_seconds, 1800.0):
		failures.append("JobState must track simulated seconds actually worked")

	var earned_two_hours: float = jobs.advance_character(
		worker,
		7200.0,
		11.5 * 3600.0,
		economy
	)
	if not is_equal_approx(earned_two_hours, 36.0):
		failures.append("two hours fully inside shift must earn two hours of pay")
	if not is_equal_approx(worker.money, 45.0):
		failures.append("job earnings must accumulate deterministically")

	var before_outside: float = worker.money
	var earned_outside: float = jobs.advance_character(
		worker,
		3600.0,
		19.0 * 3600.0,
		economy
	)
	if not is_equal_approx(earned_outside, 0.0):
		failures.append("time outside shift must not earn money")
	if not is_equal_approx(worker.money, before_outside):
		failures.append("outside-shift advance must not change balance")

	var invalid_earned: float = jobs.advance_character(worker, NAN, 20.0 * 3600.0, economy)
	if not is_equal_approx(invalid_earned, 0.0):
		failures.append("non-finite job delta must not earn money")

	var night_worker = character_script.new(&"night_worker", "Night Worker")
	var night_definition = definition_script.new()
	night_definition.id = &"night_shift"
	night_definition.pay_per_sim_hour = 20.0
	night_definition.shift_start_hour = 22.0
	night_definition.shift_duration_hours = 4.0

	if not jobs.assign_job(night_worker, night_definition):
		failures.append("cross-midnight job must be assignable")
	var night_economy = economy_script.new()
	var night_earned: float = jobs.advance_character(
		night_worker,
		3600.0,
		24.5 * 3600.0,
		night_economy
	)
	if not is_equal_approx(night_earned, 20.0):
		failures.append("23:30-00:30 interval must count one full hour of cross-midnight shift")
	if not is_equal_approx(night_worker.money, 20.0):
		failures.append("cross-midnight work must deposit correct pay")

	var invalid_definition = definition_script.new()
	invalid_definition.id = &"bad_job"
	invalid_definition.pay_per_sim_hour = -10.0
	invalid_definition.shift_start_hour = 9.0
	invalid_definition.shift_duration_hours = 8.0
	var invalid_worker = character_script.new(&"invalid_worker", "Invalid")
	if jobs.assign_job(invalid_worker, invalid_definition):
		failures.append("negative-pay job must be rejected")

	return failures
