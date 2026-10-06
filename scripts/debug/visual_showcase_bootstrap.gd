class_name VisualShowcaseBootstrap
extends Node3D

@onready var shell: VisualSimulationShell = $VisualSimulationShell
@onready var runtime_objects: Node = $RuntimeObjects

var _world := SimulationWorld.new()
var _capture_path: String = ""
var _capture_after_seconds: float = 4.0
var _elapsed_real_seconds: float = 0.0
var _capture_started: bool = false
var _validate_before_capture: bool = false

func _ready() -> void:
	_parse_user_args()
	_build_world()
	shell.bind_world(_world)
	shell.select_resident(&"resident_001")
	shell.hud.set_latest_event("Autonomous household online")

func _process(delta: float) -> void:
	if _capture_path.is_empty() or _capture_started:
		return

	_elapsed_real_seconds += delta
	if _elapsed_real_seconds < _capture_after_seconds:
		return

	_capture_started = true
	_capture_frame()

func _build_world() -> void:
	_world.clock.set_time_scale(20.0)
	_world.household_expense_system.daily_amount = 120.0

	var names := ["Mira", "Leo", "Nika", "Max", "Sara", "Ivan"]
	for index in range(6):
		var resident := CharacterState.new(
			StringName("resident_%03d" % (index + 1)),
			names[index]
		)
		resident.money = 55.0 + float(index * 7)
		resident.needs.hunger.value = 25.0 + float(index * 9)
		resident.needs.energy.value = 45.0 + float((index * 7) % 35)
		resident.needs.hygiene.value = 40.0 + float((index * 11) % 45)
		resident.needs.comfort.value = 35.0 + float((index * 13) % 50)
		resident.needs.social.value = 30.0 + float((index * 17) % 55)
		resident.needs.mood.value = 50.0 + float((index * 5) % 35)

		resident.personality.sociability = clampf(0.35 + float(index) * 0.11, 0.0, 1.0)
		resident.personality.ambition = clampf(0.72 - float(index) * 0.08, 0.0, 1.0)
		resident.personality.impulsiveness = clampf(0.18 + float(index) * 0.13, 0.0, 1.0)
		resident.personality.kindness = clampf(0.82 - float(index) * 0.07, 0.0, 1.0)

		resident.schedule.definition = _make_schedule(index)

		var job := JobDefinition.new()
		job.id = StringName("job_%03d" % (index + 1))
		job.pay_per_sim_hour = 16.0 + float(index)
		job.shift_start_hour = 8.0 + float(index % 3)
		job.shift_duration_hours = 7.0
		resident.job.assign(job)

		_world.add_character(resident)

	for first_index in range(6):
		for second_index in range(6):
			if first_index == second_index:
				continue
			var first_id := StringName("resident_%03d" % (first_index + 1))
			var second_id := StringName("resident_%03d" % (second_index + 1))
			var relationship := _world.relationship_graph.get_or_create(
				first_id,
				second_id
			)
			relationship.apply_delta(
				10.0 + float((first_index + second_index) * 6),
				8.0 + float(second_index * 3),
				0.0
			)

	_register_household_objects()

func _make_schedule(index: int) -> ScheduleDefinition:
	var definition := ScheduleDefinition.new()
	_append_schedule_block(
		definition,
		&"sleep",
		&"sleep",
		22.0 + float(index % 2),
		7.0,
		[&"sleep"]
	)
	_append_schedule_block(
		definition,
		&"breakfast",
		&"meal",
		6.0 + float(index % 2),
		1.0,
		[&"eat"]
	)
	_append_schedule_block(
		definition,
		&"work",
		&"work",
		8.0 + float(index % 3),
		7.0,
		[&"work"]
	)
	_append_schedule_block(
		definition,
		&"free",
		&"free_time",
		16.0,
		5.0,
		[&"relax", &"social"]
	)
	return definition

func _append_schedule_block(
	definition: ScheduleDefinition,
	id: StringName,
	kind: StringName,
	start_hour: float,
	duration_hours: float,
	tags: Array
) -> void:
	var block := ScheduleBlock.new()
	block.id = id
	block.kind = kind
	block.start_hour = start_hour
	block.duration_hours = duration_hours
	for tag in tags:
		block.preferred_action_tags.append(StringName(tag))
	definition.blocks.append(block)

func _register_household_objects() -> void:
	_register_smart_object(
		&"fridge_main",
		&"Fridge",
		&"eat",
		10.0,
		{"hunger": 65.0},
		[&"eat"]
	)
	_register_smart_object(
		&"sofa_main",
		&"Sofa",
		&"relax",
		12.0,
		{"comfort": 45.0, "mood": 18.0},
		[&"relax"]
	)
	_register_smart_object(
		&"shower_main",
		&"Shower",
		&"shower",
		14.0,
		{"hygiene": 72.0, "comfort": 8.0},
		[&"hygiene"]
	)

	for index in range(1, 7):
		_register_smart_object(
			StringName("bed_%02d" % index),
			StringName("Bed%02d" % index),
			StringName("sleep_%02d" % index),
			18.0,
			{"energy": 78.0},
			[&"sleep"]
		)

func _register_smart_object(
	object_id: StringName,
	destination_name: StringName,
	interaction_id: StringName,
	duration_seconds: float,
	need_effects: Dictionary,
	tags: Array
) -> void:
	var marker := shell.household.get_destination(destination_name)
	if marker == null:
		return

	var interaction := InteractionDefinition.new()
	interaction.id = interaction_id
	interaction.duration_sim_seconds = duration_seconds
	interaction.need_effects = need_effects.duplicate(true)
	for tag in tags:
		interaction.action_tags.append(StringName(tag))

	var object := SmartObject.new()
	object.name = str(object_id)
	object.object_id = object_id
	object.interaction_point = marker.global_position
	object.interactions.append(interaction)
	runtime_objects.add_child(object)
	_world.register_smart_object(object)

func _parse_user_args() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			_capture_path = argument.trim_prefix("--capture=")
		elif argument.begins_with("--capture-after="):
			var value := argument.trim_prefix("--capture-after=")
			if value.is_valid_float():
				_capture_after_seconds = maxf(float(value), 0.25)
		elif argument == "--validate-visual-state":
			_validate_before_capture = true

func _capture_frame() -> void:
	await RenderingServer.frame_post_draw

	if _validate_before_capture:
		var visual_errors := shell.validate_visual_state()
		if not visual_errors.is_empty():
			for visual_error in visual_errors:
				push_error("Visual soak validation failed: %s" % visual_error)
			get_tree().quit(4)
			return
		print(
			"VISUAL SOAK OK: %d actors, %d active movement bindings"
			% [shell.actor_count(), shell.active_movement_count()]
		)

	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Visual showcase capture image is empty")
		get_tree().quit(2)
		return

	var absolute_path := _capture_path
	if absolute_path.begins_with("user://") or absolute_path.begins_with("res://"):
		absolute_path = ProjectSettings.globalize_path(absolute_path)

	var directory := absolute_path.get_base_dir()
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)

	var error := image.save_png(absolute_path)
	if error != OK:
		push_error("Failed to save visual showcase PNG: %s" % error)
		get_tree().quit(3)
		return

	print("VISUAL SHOWCASE SAVED: %s" % absolute_path)
	get_tree().quit(0)
