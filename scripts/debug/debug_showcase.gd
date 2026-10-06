extends Control

const CAPTURE_SIZE := Vector2i(540, 960)
const DISPLAY_TIME_SECONDS := 18.5 * 3600.0

var _world := SimulationWorld.new()
var _residents: Array[CharacterState] = []
var _resident_colors: Array[Color] = [
	Color("ff6b6b"),
	Color("4dabf7"),
	Color("ffd43b"),
	Color("69db7c"),
	Color("da77f2"),
	Color("ffa94d"),
]

func _ready() -> void:
	DisplayServer.window_set_size(CAPTURE_SIZE)
	custom_minimum_size = Vector2(CAPTURE_SIZE)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_debug_world()
	queue_redraw()

	if "--capture-showcase" in OS.get_cmdline_user_args():
		call_deferred("_capture_showcase")

func _build_debug_world() -> void:
	var names: Array[String] = ["Vera", "Max", "Lika", "Oleg", "Nora", "Dan"]
	var sociability: Array[float] = [0.95, 0.45, 0.85, 0.25, 0.65, 0.55]
	var ambition: Array[float] = [0.60, 0.95, 0.30, 0.90, 0.55, 0.40]
	var impulsiveness: Array[float] = [0.25, 0.35, 0.90, 0.30, 0.50, 0.70]

	for index in range(names.size()):
		var resident := CharacterState.new(
			StringName("resident_%02d" % (index + 1)),
			names[index]
		)
		resident.money = 42.0 + float(index * 17)
		resident.needs.hunger.value = 38.0 + float(index * 7)
		resident.needs.energy.value = 78.0 - float(index * 8)
		resident.needs.hygiene.value = 72.0 + float((index % 3) * 8)
		resident.needs.comfort.value = 55.0 + float((index % 2) * 20)
		resident.needs.social.value = 28.0 + float(index * 9)
		resident.needs.mood.value = 62.0 + float((index % 4) * 7)

		resident.personality.sociability = sociability[index]
		resident.personality.ambition = ambition[index]
		resident.personality.impulsiveness = impulsiveness[index]
		resident.personality.kindness = 0.45 + float(index % 3) * 0.20
		resident.personality.neatness = 0.35 + float((index + 1) % 4) * 0.15

		resident.schedule.definition = _make_schedule(index)

		if index != 2 and index != 5:
			var job := JobDefinition.new()
			job.id = StringName("job_%02d" % (index + 1))
			job.pay_per_sim_hour = 16.0 + float(index * 2)
			job.shift_start_hour = 8.0 if index != 3 else 16.0
			job.shift_duration_hours = 8.0
			resident.job.assign(job)

		_world.add_character(resident)
		_residents.append(resident)

	for index in range(_residents.size()):
		var current := _residents[index]
		var next := _residents[(index + 1) % _residents.size()]
		_world.relationship_graph.get_or_create(current.id, next.id).apply_delta(
			30.0 + float(index * 8),
			15.0 + float(index * 4),
			0.0
		)

		var previous := _residents[(index - 1 + _residents.size()) % _residents.size()]
		_world.relationship_graph.get_or_create(current.id, previous.id).apply_delta(
			10.0 + float(index * 3),
			8.0,
			5.0
		)

	var planning_rng := RandomNumberGenerator.new()
	planning_rng.seed = 20261006
	_world.daily_planning_system.advance(
		_world,
		DISPLAY_TIME_SECONDS,
		planning_rng
	)

func _make_schedule(index: int) -> ScheduleDefinition:
	var schedule := ScheduleDefinition.new()

	if index == 3:
		_add_block(schedule, &"sleep", &"sleep", 0.0, 7.0, [&"sleep"])
		_add_block(schedule, &"free", &"free_time", 7.0, 8.0, [&"relax"])
		_add_block(schedule, &"meal", &"meal", 15.0, 1.0, [&"eat"])
		_add_block(schedule, &"work", &"work", 16.0, 8.0, [&"work"])
		return schedule

	if index == 2:
		_add_block(schedule, &"sleep", &"sleep", 23.0, 8.0, [&"sleep"])
		_add_block(schedule, &"morning", &"free_time", 7.0, 5.0, [&"relax"])
		_add_block(schedule, &"meal", &"meal", 12.0, 1.0, [&"eat"])
		_add_block(schedule, &"social", &"social", 13.0, 10.0, [&"social"])
		return schedule

	if index == 5:
		_add_block(schedule, &"sleep", &"sleep", 0.0, 8.0, [&"sleep"])
		_add_block(schedule, &"free", &"free_time", 8.0, 4.0, [&"relax"])
		_add_block(schedule, &"meal", &"meal", 12.0, 1.0, [&"eat"])
		_add_block(schedule, &"social", &"social", 13.0, 5.0, [&"social"])
		_add_block(schedule, &"evening", &"free_time", 18.0, 6.0, [&"relax"])
		return schedule

	_add_block(schedule, &"sleep", &"sleep", 0.0, 7.0, [&"sleep"])
	_add_block(schedule, &"morning", &"meal", 7.0, 1.0, [&"eat"])
	_add_block(schedule, &"work", &"work", 8.0, 8.0, [&"work"])
	_add_block(schedule, &"social", &"social", 16.0, 3.0, [&"social"])
	_add_block(schedule, &"free", &"free_time", 19.0, 5.0, [&"relax"])
	return schedule

func _add_block(
	schedule: ScheduleDefinition,
	block_id: StringName,
	kind: StringName,
	start_hour: float,
	duration_hours: float,
	tags: Array
) -> void:
	var block := ScheduleBlock.new()
	block.id = block_id
	block.kind = kind
	block.start_hour = start_hour
	block.duration_hours = duration_hours
	for tag in tags:
		block.preferred_action_tags.append(StringName(tag))
	schedule.blocks.append(block)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(CAPTURE_SIZE)), Color("0b1018"))
	_draw_header()
	_draw_house()
	_draw_residents_in_house()
	_draw_resident_cards()
	_draw_footer()

func _draw_header() -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(22, 36), "LIFEBOX LIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("f8fafc"))
	draw_string(font, Vector2(22, 59), "AI TOWN  •  DAY 0  •  18:30", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("94a3b8"))
	draw_string(font, Vector2(390, 38), "SIM LIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("4ade80"))
	draw_circle(Vector2(378, 33), 5.0, Color("4ade80"))

func _draw_house() -> void:
	var font := ThemeDB.fallback_font
	var house := Rect2(18, 80, 504, 342)
	draw_rect(house, Color("151c28"))
	draw_rect(house, Color("334155"), false, 2.0)

	var rooms := {
		"kitchen": Rect2(30, 94, 230, 120),
		"living": Rect2(272, 94, 238, 120),
		"bedroom": Rect2(30, 226, 230, 176),
		"office": Rect2(272, 226, 238, 86),
		"yard": Rect2(272, 324, 238, 78),
	}

	for room_name in rooms.keys():
		var rect: Rect2 = rooms[room_name]
		draw_rect(rect, _room_color(str(room_name)))
		draw_rect(rect, Color("475569"), false, 1.0)
		draw_string(font, rect.position + Vector2(10, 20), str(room_name).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("cbd5e1"))

	draw_string(font, Vector2(45, 132), "FRIDGE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("93c5fd"))
	draw_string(font, Vector2(130, 192), "TABLE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("fcd34d"))
	draw_string(font, Vector2(340, 168), "SOFA", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("c4b5fd"))
	draw_string(font, Vector2(82, 330), "BEDS", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("f9a8d4"))
	draw_string(font, Vector2(340, 285), "WORK", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("86efac"))
	draw_string(font, Vector2(350, 375), "STREET / YARD", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("fdba74"))

func _draw_residents_in_house() -> void:
	var centers := {
		"kitchen": Vector2(150, 165),
		"living": Vector2(390, 166),
		"bedroom": Vector2(148, 314),
		"office": Vector2(390, 274),
		"yard": Vector2(390, 363),
	}
	var slot_offsets: Array[Vector2] = [
		Vector2(-28, -16),
		Vector2(28, -16),
		Vector2(-28, 20),
		Vector2(28, 20),
		Vector2(0, 0),
		Vector2(0, 30),
	]
	var room_counts: Dictionary = {}

	for index in range(_residents.size()):
		var resident := _residents[index]
		var room := _room_for_resident(resident)
		var count := int(room_counts.get(room, 0))
		room_counts[room] = count + 1
		var base: Vector2 = centers.get(room, Vector2(390, 363))
		var position := base + slot_offsets[count % slot_offsets.size()]

		draw_circle(position, 14.0, _resident_colors[index])
		draw_circle(position, 14.0, Color("f8fafc"), false, 2.0)
		draw_string(ThemeDB.fallback_font, position + Vector2(-11, 5), resident.display_name.left(2).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("081018"))

func _draw_resident_cards() -> void:
	var font := ThemeDB.fallback_font
	var top := 440.0
	var card_height := 76.0

	for index in range(_residents.size()):
		var resident := _residents[index]
		var y := top + float(index) * card_height
		var rect := Rect2(18, y, 504, 66)
		draw_rect(rect, Color("121a26"))
		draw_rect(rect, Color("263244"), false, 1.0)

		draw_circle(Vector2(38, y + 22), 8.0, _resident_colors[index])
		draw_string(font, Vector2(54, y + 20), resident.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("f8fafc"))
		draw_string(font, Vector2(390, y + 20), "$%.0f" % resident.money, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("86efac"))

		var block_text := str(resident.schedule.active_block_id)
		if block_text.is_empty():
			block_text = "idle"
		draw_string(font, Vector2(54, y + 41), "schedule: %s" % block_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("93c5fd"))

		var need_text := "H %.0f  E %.0f  S %.0f  M %.0f" % [
			resident.needs.hunger.value,
			resident.needs.energy.value,
			resident.needs.social.value,
			resident.needs.mood.value,
		]
		draw_string(font, Vector2(240, y + 41), need_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("94a3b8"))
		draw_string(font, Vector2(54, y + 58), _goal_summary(resident), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("fbbf24"))

func _draw_footer() -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(18, 934), "6 residents  •  schedules + goals  •  social/economy/memory  •  Godot 4.7.2", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("64748b"))
	draw_string(font, Vector2(18, 951), "DEBUG SHOWCASE — current simulation systems, not final art", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("475569"))

func _room_for_resident(resident: CharacterState) -> String:
	match resident.schedule.active_block_id:
		&"sleep":
			return "bedroom"
		&"meal", &"morning":
			return "kitchen"
		&"work":
			return "office"
		&"social":
			return "living"
		_:
			if resident.personality.impulsiveness > 0.65:
				return "yard"
			return "living"

func _room_color(room_name: String) -> Color:
	match room_name:
		"kitchen":
			return Color("1e293b")
		"living":
			return Color("20263a")
		"bedroom":
			return Color("211d34")
		"office":
			return Color("172c2b")
		"yard":
			return Color("292317")
		_:
			return Color("1e293b")

func _goal_summary(resident: CharacterState) -> String:
	if resident.goals == null or resident.goals.goals().is_empty():
		return "goals: —"

	var parts: Array[String] = []
	for goal in resident.goals.goals():
		if goal == null or goal.definition == null:
			continue
		var status_marker := "✓" if goal.status == GoalState.STATUS_COMPLETED else "•"
		var text := "%s %s" % [status_marker, str(goal.definition.category)]
		if goal.definition.target_resident_id != &"":
			var target := _world.get_character(goal.definition.target_resident_id)
			if target != null:
				text += "→" + target.display_name
		parts.append(text)
		if parts.size() >= 3:
			break
	return "goals: " + "  ".join(parts)

func _capture_showcase() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	var output_dir := ProjectSettings.globalize_path("res://debug_output")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var image := get_viewport().get_texture().get_image()
	var path := "res://debug_output/lifebox_debug_showcase.png"
	var error := image.save_png(path)
	if error == OK:
		print("SHOWCASE_CAPTURED:", ProjectSettings.globalize_path(path))
	else:
		push_error("Failed to save showcase screenshot: %s" % error)
	get_tree().quit()
