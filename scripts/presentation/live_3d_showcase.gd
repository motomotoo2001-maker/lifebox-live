extends Node3D

const RESIDENT_ACTOR_SCENE = preload("res://scenes/characters/resident_actor_3d.tscn")
const DAY_SECONDS := 86400.0

@onready var house: Node3D = $HouseholdBlockout
@onready var actors_root: Node3D = $Actors
@onready var decor_root: Node3D = $Decor
@onready var camera: Camera3D = $Camera3D
@onready var hud_layer: CanvasLayer = $HUD

var world := SimulationWorld.new()
var residents: Array[CharacterState] = []
var actors: Dictionary = {}
var actor_targets: Dictionary = {}
var smart_objects: Array[SmartObject] = []

var time_label: Label
var story_label: Label
var resident_hud_labels: Array[Label] = []

func _ready() -> void:
	_configure_camera()
	_build_visual_house()
	_build_simulation()
	_spawn_actors()
	_build_hud()
	set_meta("showcase_ready", true)
	set_meta("showcase_ready", true)

func _exit_tree() -> void:
	for object in smart_objects:
		if object != null and is_instance_valid(object):
			object.free()

func _physics_process(delta: float) -> void:
	world.step(delta)
	_sync_actor_targets()
	_refresh_actor_labels()
	_refresh_hud()

func _configure_camera() -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 29.0
	camera.position = Vector3(0.0, 18.0, 18.0)
	camera.look_at(Vector3(0.0, 0.0, 0.4), Vector3.UP)

func _build_visual_house() -> void:
	var room_colors := [
		Color("30435b"),
		Color("39435d"),
		Color("45405e"),
		Color("31505a"),
		Color("3a4657"),
		Color("314d3f"),
	]
	var centers := [
		Vector3(-5.35, 0.03, 2.5),
		Vector3(0.0, 0.03, 2.5),
		Vector3(5.35, 0.03, 2.5),
		Vector3(-5.35, 0.03, -2.5),
		Vector3(0.0, 0.03, -2.5),
		Vector3(5.35, 0.03, -2.5),
	]
	for index in range(centers.size()):
		_add_box(
			decor_root,
			centers[index],
			Vector3(5.1, 0.06, 4.6),
			room_colors[index]
		)

	var wall_color := Color("8194ba")
	_add_box(decor_root, Vector3(-8.0, 0.7, 0), Vector3(0.16, 1.4, 10.0), wall_color)
	_add_box(decor_root, Vector3(8.0, 0.7, 0), Vector3(0.16, 1.4, 10.0), wall_color)
	_add_box(decor_root, Vector3(0, 0.7, 5.0), Vector3(16.0, 1.4, 0.16), wall_color)
	_add_box(decor_root, Vector3(0, 0.45, -5.0), Vector3(16.0, 0.9, 0.16), wall_color)
	_add_box(decor_root, Vector3(-2.67, 0.6, 0), Vector3(0.12, 1.2, 10.0), wall_color)
	_add_box(decor_root, Vector3(2.67, 0.6, 0), Vector3(0.12, 1.2, 10.0), wall_color)
	_add_box(decor_root, Vector3(0, 0.6, 0), Vector3(16.0, 1.2, 0.12), wall_color)

	# Simple editable-looking furniture blockout.
	_add_box(decor_root, Vector3(-6.2, 0.55, 3.4), Vector3(1.2, 1.1, 0.8), Color("7da8bd"))
	_add_box(decor_root, Vector3(-4.8, 0.38, 2.0), Vector3(2.0, 0.75, 1.1), Color("b88b67"))
	_add_box(decor_root, Vector3(0.0, 0.38, 3.3), Vector3(2.8, 0.75, 1.0), Color("765d9c"))
	_add_box(decor_root, Vector3(0.0, 0.42, -3.5), Vector3(2.2, 0.84, 1.0), Color("8b6f4f"))
	_add_box(decor_root, Vector3(6.3, 0.55, 3.5), Vector3(1.0, 1.1, 1.0), Color("6aa2a6"))

	for index in range(6):
		_add_box(
			decor_root,
			Vector3(-6.0 + float(index) * 2.25, 0.23, 1.0),
			Vector3(1.35, 0.46, 1.7),
			Color("d7d9e6")
		)

func _add_box(
	parent: Node3D,
	position_value: Vector3,
	size_value: Vector3,
	color: Color
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	mesh_instance.mesh = mesh
	mesh_instance.position = position_value
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mesh_instance)
	return mesh_instance

func _build_simulation() -> void:
	world.clock.set_time_scale(4.0)
	world.household_expense_system.daily_amount = 180.0

	_register_house_objects()

	var names := ["MIRA", "LEO", "NIKA", "MAX", "SARA", "IVAN"]
	for index in range(6):
		var resident := CharacterState.new(
			StringName("resident_%03d" % (index + 1)),
			names[index]
		)
		resident.money = 45.0 + float(index * 11)
		resident.needs.hunger.value = 28.0 + float(index * 9)
		resident.needs.energy.value = 82.0 - float(index * 8)
		resident.needs.hygiene.value = 45.0 + float(index * 7)
		resident.needs.social.value = 25.0 + float(index * 11)
		resident.needs.comfort.value = 50.0 + float((index * 8) % 35)
		resident.needs.mood.value = 55.0 + float((index * 7) % 30)

		resident.personality.sociability = 0.35 + float(index) * 0.11
		resident.personality.ambition = 0.25 + float(5 - index) * 0.11
		resident.personality.impulsiveness = 0.15 + float(index % 3) * 0.35
		resident.personality.kindness = 0.8 - float(index) * 0.08

		resident.schedule.definition = _make_schedule(index)
		_assign_job(resident, index)

		world.add_character(resident)
		residents.append(resident)

	for index in range(residents.size()):
		var resident: CharacterState = residents[index]
		var other: CharacterState = residents[(index + 1) % residents.size()]
		world.relationship_graph.get_or_create(
			resident.id,
			other.id
		).apply_delta(25.0 + float(index * 5), 15.0, 0.0)

func _register_house_objects() -> void:
	var eat := _interaction(&"eat_free", 12.0, [&"eat"], {"hunger": 70.0})
	_add_smart_object(&"fridge", "Fridge", [eat])

	for index in range(6):
		var sleep := _interaction(
			StringName("sleep_%02d" % (index + 1)),
			32.0,
			[&"sleep"],
			{"energy": 80.0}
		)
		_add_smart_object(
			StringName("bed_%02d" % (index + 1)),
			"Bed%02d" % (index + 1),
			[sleep]
		)

	var shower := _interaction(
		&"shower",
		18.0,
		[&"hygiene"],
		{"hygiene": 75.0, "mood": 5.0}
	)
	_add_smart_object(&"shower", "Shower", [shower])

	var relax := _interaction(
		&"relax_free",
		20.0,
		[&"relax"],
		{"comfort": 48.0, "mood": 18.0}
	)
	_add_smart_object(&"sofa", "Sofa", [relax])

	var coffee := _interaction(
		&"buy_coffee",
		10.0,
		[&"relax", &"spend"],
		{"mood": 42.0, "comfort": 8.0}
	)
	coffee.money_cost = 8.0
	_add_smart_object(&"coffee_machine", "CoffeeMachine", [coffee])

	var work := _interaction(
		&"work",
		26.0,
		[&"work"],
		{"mood": 6.0}
	)
	_add_smart_object(&"work_desk", "WorkDesk", [work])

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

func _add_smart_object(
	id: StringName,
	marker_name: String,
	interactions: Array
) -> void:
	var marker: Marker3D = house.get_node("Destinations/%s" % marker_name)
	var object := SmartObject.new()
	object.object_id = id
	object.interaction_point = marker.global_position
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

func _spawn_actors() -> void:
	var colors := [
		Color("58a6ff"),
		Color("a371f7"),
		Color("f78166"),
		Color("3fb950"),
		Color("d29922"),
		Color("db61a2"),
	]

	for index in range(residents.size()):
		var resident: CharacterState = residents[index]
		var actor: ResidentActor3D = (
			RESIDENT_ACTOR_SCENE.instantiate() as ResidentActor3D
		)
		actors_root.add_child(actor)

		var spawn: Marker3D = house.get_node(
			"Spawns/ResidentSpawn%02d" % (index + 1)
		)
		actor.global_position = spawn.global_position
		actor.movement_speed = 3.4
		actor.bind_character(resident.id)
		actor.movement_arrived.connect(_on_actor_arrived)
		actor.movement_failed.connect(_on_actor_failed)
		_apply_actor_style(actor, colors[index], resident.display_name)
		actors[resident.id] = actor

func _apply_actor_style(
	actor: ResidentActor3D,
	color: Color,
	resident_name: String
) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.55
	var body: MeshInstance3D = actor.get_node("VisualRoot/Body")
	var head: MeshInstance3D = actor.get_node("VisualRoot/Head")
	var label: Label3D = actor.get_node("VisualRoot/NameLabel")
	body.material_override = material
	head.material_override = material
	label.text = resident_name

func _sync_actor_targets() -> void:
	for resident in residents:
		var actor: ResidentActor3D = actors.get(resident.id)
		if actor == null:
			continue

		if (
			resident.movement.status == MovementState.STATUS_MOVING
			and resident.movement.intent != null
		):
			var target_id: StringName = resident.movement.intent.target_object_id
			if actor_targets.get(resident.id, &"") != target_id:
				actor_targets[resident.id] = target_id
				actor.set_movement_target(
					resident.movement.intent.target_position,
					resident.movement.intent.arrival_radius
				)
		elif actor_targets.has(resident.id):
			actor.stop_movement()
			actor_targets.erase(resident.id)

func _on_actor_arrived(character_id: StringName) -> void:
	var resident: CharacterState = world.get_character(character_id)
	if resident == null or resident.movement.intent == null:
		return
	var target_id: StringName = resident.movement.intent.target_object_id
	world.report_arrival(character_id, target_id)
	actor_targets.erase(character_id)

func _on_actor_failed(character_id: StringName) -> void:
	var resident: CharacterState = world.get_character(character_id)
	if resident == null or resident.movement.intent == null:
		return
	var target_id: StringName = resident.movement.intent.target_object_id
	world.report_movement_failure(character_id, target_id)
	actor_targets.erase(character_id)

func _refresh_actor_labels() -> void:
	for resident in residents:
		var actor: ResidentActor3D = actors.get(resident.id)
		if actor == null:
			continue
		var label: Label3D = actor.get_node("VisualRoot/NameLabel")
		label.text = "%s\n%s" % [
			resident.display_name,
			resident.current_action_id,
		]

func _build_hud() -> void:
	var root := Control.new()
	root.size = Vector2(720, 1280)
	hud_layer.add_child(root)

	var top := _panel(
		root,
		Vector2(22, 20),
		Vector2(676, 106),
		Color(0.06, 0.09, 0.14, 0.92)
	)
	_label(top, "LIFEBOX LIVE", Vector2(22, 14), Vector2(300, 34), 28, Color("eef5ff"))
	_label(top, "3D AI TOWN • LIVE DOLLHOUSE", Vector2(23, 51), Vector2(360, 22), 14, Color("75baff"))
	time_label = _label(top, "", Vector2(430, 16), Vector2(220, 30), 20, Color.WHITE)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	story_label = _label(top, "", Vector2(23, 78), Vector2(620, 18), 11, Color("7ee787"))

	var bottom := _panel(
		root,
		Vector2(22, 936),
		Vector2(676, 320),
		Color(0.06, 0.09, 0.14, 0.94)
	)
	_label(bottom, "LIVE RESIDENTS", Vector2(18, 12), Vector2(220, 22), 15, Color("dce8f8"))

	for index in range(residents.size()):
		var resident: CharacterState = residents[index]
		var column := index % 2
		var row := index / 2
		var label := _label(
			bottom,
			"",
			Vector2(18 + column * 330, 44 + row * 86),
			Vector2(315, 78),
			12,
			Color("cbd8e8")
		)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		resident_hud_labels.append(label)

func _refresh_hud() -> void:
	if time_label == null:
		return

	var seconds := world.clock.get_simulation_seconds()
	var day := int(floor(seconds / DAY_SECONDS))
	var hour := int(floor(fmod(seconds, DAY_SECONDS) / 3600.0))
	var minute := int(floor(fmod(seconds, 3600.0) / 60.0))
	time_label.text = "DAY %d  %02d:%02d  x%.0f" % [
		day,
		hour,
		minute,
		world.clock.get_time_scale(),
	]

	var story_parts: Array[String] = []
	for resident in residents:
		if resident.current_action_id != &"idle" and story_parts.size() < 3:
			story_parts.append(
				"%s → %s" % [
					resident.display_name,
					resident.current_action_id,
				]
			)
	story_label.text = (
		" • ".join(story_parts)
		if not story_parts.is_empty()
		else "Residents planning their next move"
	)

	for index in range(mini(residents.size(), resident_hud_labels.size())):
		var resident: CharacterState = residents[index]
		var schedule_text := "—"
		if resident.schedule != null and resident.schedule.active_block_id != &"":
			schedule_text = str(resident.schedule.active_block_id)

		var goal_text := "complete"
		if resident.goals != null:
			var active: Array[GoalState] = resident.goals.active_goals()
			if not active.is_empty() and active[0].definition != null:
				goal_text = str(active[0].definition.category)

		resident_hud_labels[index].text = "%s  •  $%d\n%s  |  %s\nH %d  E %d  S %d  M %d" % [
			resident.display_name,
			int(round(resident.money)),
			resident.current_action_id,
			schedule_text + " / " + goal_text,
			int(resident.needs.hunger.value),
			int(resident.needs.energy.value),
			int(resident.needs.social.value),
			int(resident.needs.mood.value),
		]

func _panel(
	parent: Control,
	position_value: Vector2,
	size_value: Vector2,
	color: Color
) -> Panel:
	var panel := Panel.new()
	panel.position = position_value
	panel.size = size_value
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color("40516c")
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel

func _label(
	parent: Control,
	text: String,
	position_value: Vector2,
	size_value: Vector2,
	font_size: int,
	color: Color
) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position_value
	label.size = size_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label
