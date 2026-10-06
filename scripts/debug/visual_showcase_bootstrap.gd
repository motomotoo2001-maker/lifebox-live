class_name VisualShowcaseBootstrap
extends Node3D

const QUICKSAVE_PATH := "user://lifebox_quicksave.save"

@onready var shell: VisualSimulationShell = $VisualSimulationShell
@onready var runtime_objects: Node = $RuntimeObjects
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var key_light: DirectionalLight3D = $KeyLight
@onready var fill_light: DirectionalLight3D = $FillLight
@onready var kitchen_light: OmniLight3D = $KitchenWarmLight
@onready var living_light: OmniLight3D = $LivingWarmLight
@onready var bedroom_light: OmniLight3D = $BedroomWarmLight
@onready var bathroom_light: OmniLight3D = $BathroomCoolLight

var _world := SimulationWorld.new()
var _capture_path: String = ""
var _capture_after_seconds: float = 4.0
var _elapsed_real_seconds: float = 0.0
var _capture_started: bool = false
var _validate_before_capture: bool = false
var _validate_save_load_before_capture: bool = false

func _ready() -> void:
	_parse_user_args()
	_build_world()
	shell.bind_world(_world)
	shell.select_resident(&"resident_001")
	if not shell.hud.save_requested.is_connected(save_game):
		shell.hud.save_requested.connect(save_game)
	if not shell.hud.load_requested.is_connected(load_game):
		shell.hud.load_requested.connect(load_game)
	shell.hud.set_latest_event("Autonomous household online")

func save_game() -> bool:
	var snapshot := WorldSnapshotCodec.encode(_world)
	if snapshot.is_empty():
		shell.hud.set_latest_event("Save failed: empty world snapshot")
		return false

	var envelope := SaveSchema.create_envelope({"world": snapshot})
	if not SaveService.save_envelope(QUICKSAVE_PATH, envelope):
		print("QUICKSAVE SAVE FAILED: %s" % QUICKSAVE_PATH)
		shell.hud.set_latest_event("Save failed")
		return false

	shell.hud.set_latest_event("Game saved")
	return true

func load_game() -> bool:
	var envelope := SaveService.load_envelope(QUICKSAVE_PATH)
	if envelope.is_empty():
		shell.hud.set_latest_event("No quicksave found")
		return false
	if not envelope.has("payload") or not envelope["payload"] is Dictionary:
		print("QUICKSAVE LOAD FAILED: envelope payload missing")
		shell.hud.set_latest_event("Load failed: invalid save")
		return false
	var payload: Dictionary = envelope["payload"]
	if not payload.has("world") or not payload["world"] is Dictionary:
		print("QUICKSAVE LOAD FAILED: world payload missing")
		shell.hud.set_latest_event("Load failed: invalid world")
		return false

	var selected_id := shell.selected_resident_id()
	var errors := WorldSnapshotCodec.restore(_world, payload["world"])
	if not errors.is_empty():
		print("QUICKSAVE RESTORE ERRORS: %s" % " | ".join(errors))
		shell.hud.set_latest_event("Load failed: %s" % errors[0])
		return false

	if not shell.bind_world(_world):
		shell.hud.set_latest_event("Load failed: visual rebind")
		return false
	if selected_id != &"" and _world.get_character(selected_id) != null:
		shell.select_resident(selected_id, false)

	shell.hud.set_latest_event("Game loaded")
	return true

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo or not key_event.ctrl_pressed:
		return
	if key_event.keycode == KEY_S:
		save_game()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_L:
		load_game()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	_update_time_of_day_visuals()
	if _capture_path.is_empty() or _capture_started:
		return

	_elapsed_real_seconds += delta
	if _elapsed_real_seconds < _capture_after_seconds:
		return

	_capture_started = true
	_capture_frame()

func _update_time_of_day_visuals() -> void:
	if _world == null:
		return
	if (
		world_environment == null
		or world_environment.environment == null
		or key_light == null
	):
		return

	var seconds := _world.clock.get_simulation_seconds()
	var hour := fmod(seconds, 86400.0) / 3600.0
	var day_factor := 0.0
	if hour >= 6.0 and hour <= 18.0:
		day_factor = sin(((hour - 6.0) / 12.0) * PI)
	day_factor = clampf(day_factor, 0.0, 1.0)

	var environment := world_environment.environment
	environment.background_color = Color("07111f").lerp(
		Color("87b8d6"),
		day_factor
	)
	environment.ambient_light_color = Color("6f89b3").lerp(
		Color("f3f0df"),
		day_factor
	)
	environment.ambient_light_energy = lerpf(0.28, 0.72, day_factor)

	key_light.light_color = Color("8096c9").lerp(
		Color("fff0cf"),
		day_factor
	)
	key_light.light_energy = lerpf(0.20, 1.20, day_factor)
	fill_light.light_energy = lerpf(0.18, 0.38, day_factor)

	var warm_energy := lerpf(1.38, 0.46, day_factor)
	kitchen_light.light_energy = warm_energy
	living_light.light_energy = warm_energy * 0.92
	bedroom_light.light_energy = warm_energy * 0.78
	bathroom_light.light_energy = lerpf(0.96, 0.48, day_factor)

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
	_register_smart_object(
		&"tv_main",
		&"TV",
		&"watch_tv",
		32.0,
		{"mood": 32.0, "comfort": 10.0},
		[&"relax", &"fun"]
	)
	_register_smart_object(
		&"bathroom_sink_main",
		&"BathroomSink",
		&"wash_up",
		12.0,
		{"hygiene": 28.0, "comfort": 4.0},
		[&"hygiene"]
	)
	_register_smart_object(
		&"bookshelf_main",
		&"Bookshelf",
		&"read",
		35.0,
		{"mood": 20.0, "comfort": 10.0},
		[&"relax", &"fun"]
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
		elif argument == "--validate-save-load":
			_validate_save_load_before_capture = true

func _capture_frame() -> void:
	await RenderingServer.frame_post_draw

	if _validate_save_load_before_capture:
		var before_save := WorldSnapshotCodec.encode(_world)
		if before_save.is_empty() or not save_game() or not load_game():
			push_error("Quicksave validation failed")
			get_tree().quit(5)
			return
		var after_load := WorldSnapshotCodec.encode(_world)
		if after_load != before_save:
			push_error("Quicksave restore changed authoritative world state")
			get_tree().quit(6)
			return
		print("QUICKSAVE RESTORE OK")
		await get_tree().process_frame
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
