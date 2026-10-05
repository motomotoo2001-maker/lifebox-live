extends RefCounted

const FIXTURE_PATH := "res://tests/fixtures/basic_house_fixture.gd"

func run() -> Array[String]:
	var failures: Array[String] = []
	var fixture_script := load(FIXTURE_PATH)
	if fixture_script == null:
		failures.append("basic house fixture must load")
		return failures

	_test_satisfied_resident_stays_idle(failures, fixture_script)
	_test_total_time_is_frame_step_independent(failures, fixture_script)
	return failures

func _test_satisfied_resident_stays_idle(failures: Array[String], fixture_script) -> void:
	var fixture: Dictionary = fixture_script.new().build()
	var resident = fixture["resident"]
	var world = fixture["world"]
	var fridge = fixture["fridge"]
	var bed = fixture["bed"]

	for need_name in ["hunger", "energy", "hygiene", "comfort", "social", "mood"]:
		var need_state = resident.needs.get(need_name)
		need_state.value = 100.0
		need_state.decay_per_sim_hour = 0.0

	world.step(1.0)

	if resident.current_action_id != &"idle":
		failures.append("resident with zero utility interactions must stay Idle")
	if not fridge.is_available_for(&"reservation_probe") or not bed.is_available_for(&"reservation_probe"):
		failures.append("Idle resident must not reserve a SmartObject")

	fridge.free()
	bed.free()

func _test_total_time_is_frame_step_independent(failures: Array[String], fixture_script) -> void:
	var coarse: Dictionary = fixture_script.new().build()
	var fine: Dictionary = fixture_script.new().build()

	coarse["world"].step(120.0)
	for _index in range(120):
		fine["world"].step(1.0)

	var coarse_resident = coarse["resident"]
	var fine_resident = fine["resident"]

	if coarse_resident.current_action_id != fine_resident.current_action_id:
		failures.append("same simulated time must produce the same current action regardless of frame step")

	for need_name in ["hunger", "energy", "hygiene", "comfort", "social", "mood"]:
		var coarse_need = coarse_resident.needs.get(need_name)
		var fine_need = fine_resident.needs.get(need_name)
		if not is_equal_approx(coarse_need.value, fine_need.value):
			failures.append(
				"same simulated time must produce equal %s regardless of frame step" % need_name
			)

	var coarse_fridge_locked: bool = not bool(coarse["fridge"].is_available_for(&"reservation_probe"))
	var fine_fridge_locked: bool = not bool(fine["fridge"].is_available_for(&"reservation_probe"))
	var coarse_bed_locked: bool = not bool(coarse["bed"].is_available_for(&"reservation_probe"))
	var fine_bed_locked: bool = not bool(fine["bed"].is_available_for(&"reservation_probe"))

	if coarse_fridge_locked != fine_fridge_locked or coarse_bed_locked != fine_bed_locked:
		failures.append("same simulated time must produce equal reservation state regardless of frame step")

	coarse["fridge"].free()
	coarse["bed"].free()
	fine["fridge"].free()
	fine["bed"].free()
