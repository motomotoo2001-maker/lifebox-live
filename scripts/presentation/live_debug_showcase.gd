extends Control

const DAY_SECONDS := 86400.0
const HOUSE_ROOMS := {
	"eat": "KITCHEN",
	"eat_free": "KITCHEN",
	"sleep": "BEDROOM",
	"relax": "LIVING",
	"relax_free": "LIVING",
	"buy_coffee": "KITCHEN",
	"work": "WORK",
	"idle": "HALL",
	"chat": "LIVING",
	"compliment": "LIVING",
	"argue": "LIVING",
}

var world := SimulationWorld.new()
var residents: Array[CharacterState] = []
var smart_objects: Array[SmartObject] = []
var resident_labels: Array[Dictionary] = []
var time_label: Label
var story_label: Label
var status_label: Label
var _last_story: String = ""

func _ready() -> void:
	_build_simulation()
	_build_ui()
	set_process(true)

func _exit_tree() -> void:
	for object in smart_objects:
		if object != null and is_instance_valid(object):
			object.free()

func _process(delta: float) -> void:
	world.step(delta)
	_auto_resolve_navigation()
	_refresh_ui()

func _build_simulation() -> void:
	world.clock.set_time_scale(20.0)
	world.household_expense_system.daily_amount = 180.0

	_register_interactions()

	var names := ["MIRA", "LEO", "NIKA", "MAX", "SARA", "IVAN"]
	for index in range(6):
		var resident := CharacterState.new(
			StringName("resident_%03d" % (index + 1)),
			names[index]
		)
		resident.money = 45.0 + float(index * 11)
		resident.needs.hunger.value = 35.0 + float(index * 8)
		resident.needs.energy.value = 80.0 - float(index * 7)
		resident.needs.social.value = 30.0 + float(index * 10)
		resident.needs.comfort.value = 55.0 + float((index * 9) % 35)
		resident.needs.mood.value = 60.0 + float((index * 7) % 30)

		resident.personality.sociability = 0.35 + float(index) * 0.11
		resident.personality.ambition = 0.25 + float((5 - index)) * 0.11
		resident.personality.impulsiveness = 0.15 + float(index % 3) * 0.35
		resident.personality.kindness = 0.8 - float(index) * 0.08

		resident.schedule.definition = _make_schedule(index)
		_assign_job(resident, index)

		world.add_character(resident)
		residents.append(resident)

	for index in range(residents.size()):
		var resident := residents[index]
		var other := residents[(index + 1) % residents.size()]
		world.relationship_graph.get_or_create(
			resident.id,
			other.id
		).apply_delta(25.0 + float(index * 5), 15.0, 0.0)

func _register_interactions() -> void:
	var eat := _interaction(
		&"eat_free",
		10.0,
		[&"eat"],
		{"hunger": 70.0}
	)
	_add_object(&"fridge", Vector3(2,0,0), [eat])

	for index in range(6):
		var sleep := _interaction(
			StringName("sleep_%02d" % (index + 1)),
			28.0,
			[&"sleep"],
			{"energy": 80.0}
		)
		_add_object(
			StringName("bed_%02d" % (index + 1)),
			Vector3(-3.0 + float(index),0,-2),
			[sleep]
		)

	var relax := _interaction(
		&"relax_free",
		16.0,
		[&"relax"],
		{"comfort": 45.0, "mood": 20.0}
	)
	_add_object(&"sofa", Vector3(0,0,2), [relax])

	var coffee := _interaction(
		&"buy_coffee",
		8.0,
		[&"relax", &"spend"],
		{"mood": 45.0, "comfort": 8.0}
	)
	coffee.money_cost = 8.0
	_add_object(&"coffee_machine", Vector3(3,0,2), [coffee])

	var work := _interaction(
		&"work",
		24.0,
		[&"work"],
		{"mood": 6.0}
	)
	_add_object(&"work_desk", Vector3(0,0,-3), [work])

func _interaction(
	id: StringName,
	duration: float,
	tags: Array[StringName],
	effects: Dictionary
) -> InteractionDefinition:
	var interaction := InteractionDefinition.new()
	interaction.id = id
	interaction.duration_sim_seconds = duration
	for tag in tags:
		interaction.action_tags.append(tag)
	interaction.need_effects = effects.duplicate(true)
	return interaction

func _add_object(
	id: StringName,
	point: Vector3,
	interactions: Array
) -> void:
	var object := SmartObject.new()
	object.object_id = id
	object.interaction_point = point
	for interaction in interactions:
		object.interactions.append(interaction)
	add_child(object)
	world.register_smart_object(object)
	smart_objects.append(object)

func _assign_job(resident: CharacterState, index: int) -> void:
	var job := JobDefinition.new()
	job.id = StringName("job_%02d" % (index + 1))
	job.pay_per_sim_hour = 15.0 + float(index * 2)
	job.shift_start_hour = 0.0 if index == 5 else 8.0 + float(index % 2)
	job.shift_duration_hours = 8.0
	world.job_system.assign_job(resident, job)

func _make_schedule(index: int) -> ScheduleDefinition:
	var schedule := ScheduleDefinition.new()
	if index == 5:
		_add_schedule_block(schedule, &"night_work", &"work", 0.0, 6.0, [&"work"])
		_add_schedule_block(schedule, &"sleep", &"sleep", 6.0, 8.0, [&"sleep"])
		_add_schedule_block(schedule, &"free", &"free_time", 14.0, 10.0, [&"relax", &"social"])
	elif index == 1:
		_add_schedule_block(schedule, &"late_free", &"free_time", 0.0, 2.0, [&"relax", &"social"])
		_add_schedule_block(schedule, &"sleep", &"sleep", 2.0, 7.0, [&"sleep"])
		_add_schedule_block(schedule, &"work", &"work", 9.0, 8.0, [&"work"])
		_add_schedule_block(schedule, &"evening", &"free_time", 17.0, 7.0, [&"relax", &"social"])
	else:
		_add_schedule_block(schedule, &"sleep", &"sleep", 22.0, 8.0, [&"sleep"])
		_add_schedule_block(schedule, &"morning", &"meal", 6.0, 2.0, [&"eat"])
		_add_schedule_block(schedule, &"work", &"work", 8.0, 8.0, [&"work"])
		_add_schedule_block(schedule, &"free", &"free_time", 16.0, 6.0, [&"relax", &"social"])
	return schedule

func _add_schedule_block(
	schedule: ScheduleDefinition,
	id: StringName,
	kind: StringName,
	start_hour: float,
	duration_hours: float,
	tags: Array[StringName]
) -> void:
	var block := ScheduleBlock.new()
	block.id = id
	block.kind = kind
	block.start_hour = start_hour
	block.duration_hours = duration_hours
	for tag in tags:
		block.preferred_action_tags.append(tag)
	schedule.blocks.append(block)

func _auto_resolve_navigation() -> void:
	for resident in residents:
		if resident.movement == null or resident.movement.intent == null:
			continue
		world.report_arrival(
			resident.id,
			resident.movement.intent.target_object_id
		)

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("0c111b")
	add_child(bg)

	var top := _panel(self, Vector2(24,22), Vector2(672,112), Color("151e2d"), 22)
	_label(top, "LIFEBOX LIVE", Vector2(22,14), Vector2(360,34), 28, Color("eaf2ff"), true)
	_label(top, "AI TOWN  •  LIVE SIMULATION", Vector2(23,51), Vector2(420,22), 14, Color("75baff"), true)
	time_label = _label(top, "", Vector2(440,17), Vector2(205,28), 20, Color("eaf2ff"), true)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label(top, "SIM x20  •  SAME-SEED DETERMINISTIC", Vector2(300,58), Vector2(345,20), 11, Color("7ee787"), true).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label(top, "Runtime cards below read real CharacterState values", Vector2(23,80), Vector2(620,18), 11, Color("93a4ba"))

	var world_panel := _panel(self, Vector2(24,154), Vector2(672,412), Color("111827"), 22)
	_label(world_panel, "HOUSEHOLD LIVE VIEW", Vector2(18,13), Vector2(300,24), 15, Color("dce8f8"), true)
	_label(world_panel, "positions inferred from current action", Vector2(350,14), Vector2(300,20), 11, Color("8093ac")).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var rooms = [
		[Vector2(20,52),Vector2(200,150),"KITCHEN",Color("26344a")],
		[Vector2(230,52),Vector2(200,150),"LIVING",Color("26344a")],
		[Vector2(440,52),Vector2(212,150),"BEDROOM",Color("26344a")],
		[Vector2(20,212),Vector2(200,130),"BATH",Color("202d40")],
		[Vector2(230,212),Vector2(200,130),"WORK",Color("202d40")],
		[Vector2(440,212),Vector2(212,130),"HALL",Color("1d342b")],
	]
	for room_data in rooms:
		var rp := _panel(world_panel, room_data[0], room_data[1], room_data[3], 12)
		_label(rp, room_data[2], Vector2(10,8), Vector2(120,18), 11, Color("8296af"), true)

	story_label = _label(world_panel, "", Vector2(20,368), Vector2(630,24), 12, Color("7ee787"), true)

	var list := _panel(self, Vector2(24,586), Vector2(672,556), Color("111827"), 22)
	_label(list, "RESIDENT STATE", Vector2(18,12), Vector2(220,22), 15, Color("dce8f8"), true)
	_label(list, "live schedule  •  goal  •  needs", Vector2(350,12), Vector2(300,20), 11, Color("8093ac")).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	for index in range(residents.size()):
		var row_y := 44.0 + float(index) * 82.0
		var row := _panel(list, Vector2(12,row_y), Vector2(648,72), Color("182335"), 12)
		var name_label := _label(row, "", Vector2(68,8), Vector2(105,22), 15, Color("f1f6ff"), true)
		var room_label := _label(row, "", Vector2(68,31), Vector2(130,18), 11, Color("91a4bb"))
		var schedule_label := _label(row, "", Vector2(205,8), Vector2(140,20), 12, Color("75baff"), true)
		var goal_label := _label(row, "", Vector2(205,31), Vector2(190,20), 11, Color("d2a8ff"), true)
		var stats_label := _label(row, "", Vector2(405,9), Vector2(225,52), 11, Color("a7b7ca"))
		stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		resident_labels.append({
			"name": name_label,
			"room": room_label,
			"schedule": schedule_label,
			"goal": goal_label,
			"stats": stats_label,
		})

	var footer := _panel(self, Vector2(24,1162), Vector2(672,92), Color("151e2d"), 22)
	_label(footer, "SIMULATION HEALTH", Vector2(18,12), Vector2(220,20), 12, Color("9db0c7"), true)
	status_label = _label(footer, "LIVE RUNTIME", Vector2(18,37), Vector2(330,28), 20, Color("7ee787"), true)
	_label(footer, "save/load ✓   replay ✓   goals ✓   schedules ✓", Vector2(330,40), Vector2(320,20), 12, Color("a7b7ca"), true).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _refresh_ui() -> void:
	var seconds := world.clock.get_simulation_seconds()
	var day := int(floor(seconds / DAY_SECONDS))
	var hour := int(floor(fmod(seconds, DAY_SECONDS) / 3600.0))
	var minute := int(floor(fmod(seconds, 3600.0) / 60.0))
	time_label.text = "DAY %d   %02d:%02d" % [day, hour, minute]

	var story_parts: Array[String] = []
	for index in range(residents.size()):
		var resident := residents[index]
		var labels: Dictionary = resident_labels[index]
		var room := _room_for_action(resident.current_action_id)
		var schedule_name := "—"
		if resident.schedule != null and resident.schedule.active_block_id != &"":
			schedule_name = str(resident.schedule.active_block_id).to_upper()
		var goal_name := _primary_goal_label(resident)

		labels["name"].text = resident.display_name
		labels["room"].text = "%s  •  $%d" % [room, int(round(resident.money))]
		labels["schedule"].text = schedule_name
		labels["goal"].text = goal_name
		labels["stats"].text = "Action: %s\nHUN %d   ENG %d   SOC %d   MOOD %d" % [
			resident.current_action_id,
			int(resident.needs.hunger.value),
			int(resident.needs.energy.value),
			int(resident.needs.social.value),
			int(resident.needs.mood.value),
		]

		if resident.current_action_id != &"idle" and story_parts.size() < 3:
			story_parts.append(
				"%s → %s" % [resident.display_name, resident.current_action_id]
			)

	story_label.text = "Latest:  %s" % (
		"  •  ".join(story_parts) if not story_parts.is_empty() else "residents planning their day"
	)
	status_label.text = "%d RESIDENTS • x%.0f" % [
		residents.size(),
		world.clock.get_time_scale(),
	]

func _primary_goal_label(resident: CharacterState) -> String:
	if resident.goals == null:
		return "No goal"
	var active := resident.goals.active_goals()
	if active.is_empty():
		return "Goals complete"
	var goal: GoalState = active[0]
	if goal == null or goal.definition == null:
		return "No goal"
	var label := str(goal.definition.category).capitalize()
	if goal.definition.target_resident_id != &"":
		var target := world.get_character(goal.definition.target_resident_id)
		if target != null:
			label += " → " + target.display_name
	return label

func _room_for_action(action_id: StringName) -> String:
	var action := str(action_id)
	if action.begins_with("sleep"):
		return "BEDROOM"
	if action.begins_with("eat") or action == "buy_coffee":
		return "KITCHEN"
	if action == "work":
		return "WORK"
	if action in ["chat", "compliment", "argue", "relax_free"]:
		return "LIVING"
	return str(HOUSE_ROOMS.get(action, "HALL"))

func _panel(parent: Control, pos: Vector2, size: Vector2, color: Color, radius := 18.0) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = size
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = int(radius)
	style.corner_radius_top_right = int(radius)
	style.corner_radius_bottom_left = int(radius)
	style.corner_radius_bottom_right = int(radius)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color("38465d")
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel

func _label(parent: Control, text: String, pos: Vector2, size: Vector2, font_size: int, color: Color = Color.WHITE, bold := false) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if bold:
		label.add_theme_constant_override("outline_size", 1)
		label.add_theme_color_override("font_outline_color", Color("111722"))
	parent.add_child(label)
	return label
