extends RefCounted

const HUD_SCENE := "res://scenes/ui/visual_hud.tscn"

func run() -> Array[String]:
	var failures: Array[String] = []

	var packed = load(HUD_SCENE)
	if packed == null:
		failures.append("resident insights require VisualHUD scene")
		return failures
	var hud = packed.instantiate()
	if hud == null:
		failures.append("VisualHUD must instantiate for resident insights")
		return failures

	var world := SimulationWorld.new()
	world.household_expense_system.daily_amount = 120.0
	world.household_expense_system.arrears = 35.0

	var mira := CharacterState.new(&"resident_001", "Mira")
	var leo := CharacterState.new(&"resident_002", "Leo")
	mira.money = 55.0

	var job := JobDefinition.new()
	job.id = &"job_artist"
	job.pay_per_sim_hour = 18.0
	job.shift_start_hour = 9.0
	job.shift_duration_hours = 7.0
	mira.job.assign(job)

	if not world.add_character(mira) or not world.add_character(leo):
		failures.append("resident insights fixture must add two residents")
		hud.free()
		return failures

	var relation := world.relationship_graph.get_or_create(mira.id, leo.id)
	relation.apply_delta(42.0, 30.0, 5.0)

	var memory := MemoryEvent.new(
		&"memory_001",
		&"compliment",
		120.0,
		[leo.id],
		0.7,
		0.6
	)
	mira.memory.add(memory)

	hud.bind_world(world)

	var job_text: String = hud._job_text(mira)
	if "job artist" not in job_text or "$18/h" not in job_text:
		failures.append("career insight must expose job identity and pay")

	var bills_text: String = hud._household_text()
	if "$120/day" not in bills_text or "$35" not in bills_text:
		failures.append("household insight must expose daily bills and arrears")

	var relation_text: String = hud._relationship_text(mira)
	if "Leo" not in relation_text or "AFF 42" not in relation_text:
		failures.append("relationship insight must expose closest resident and affinity")

	var memory_text: String = hud._memory_text(mira)
	if "compliment" not in memory_text or "Leo" not in memory_text:
		failures.append("memory insight must expose recent social memory")

	hud.free()
	return failures
