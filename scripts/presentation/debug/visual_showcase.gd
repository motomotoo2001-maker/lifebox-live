class_name VisualShowcase
extends Node3D

const RESIDENT_NAMES: Array[String] = [
	"Ava",
	"Noah",
	"Mia",
	"Leo",
	"Zoe",
	"Max",
]

const RESIDENT_POSITIONS: Array[Vector3] = [
	Vector3(-3.8, 0.2, -3.7),
	Vector3(-1.8, 0.2, -3.0),
	Vector3(2.2, 0.2, -3.8),
	Vector3(4.0, 0.2, -1.8),
	Vector3(-3.4, 0.2, 3.3),
	Vector3(3.3, 0.2, 3.2),
]

const RESIDENT_COLORS: Array[Color] = [
	Color("6ad6ff"),
	Color("ff9a76"),
	Color("b7f07a"),
	Color("d3a4ff"),
	Color("ffd66a"),
	Color("72e0bd"),
]

const ROOM_COLORS: Array[Color] = [
	Color("30364c"),
	Color("313b52"),
	Color("2d4244"),
	Color("40384b"),
]

var _resident_states: Array[CharacterState] = []

func _ready() -> void:
	_build_lighting()
	_build_house()
	_resident_states = _build_demo_residents()
	_build_resident_visuals()
	_build_hud()
	_configure_camera()

	var capture_path := OS.get_environment("LIFEBOX_CAPTURE_PATH")
	if not capture_path.is_empty():
		call_deferred("_capture_when_ready", capture_path)

func _build_lighting() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("111522")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c9d6ff")
	environment.ambient_light_energy = 0.58

	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	key_light.light_energy = 1.4
	key_light.shadow_enabled = true
	add_child(key_light)

	var fill := OmniLight3D.new()
	fill.position = Vector3(0.0, 8.0, 2.0)
	fill.omni_range = 24.0
	fill.light_energy = 3.0
	fill.light_color = Color("9fc8ff")
	add_child(fill)

func _build_house() -> void:
	_make_box(
		"Foundation",
		Vector3(13.4, 0.35, 15.2),
		Vector3(0.0, -0.3, 0.0),
		Color("171b28")
	)

	_make_box(
		"BedroomFloor",
		Vector3(6.1, 0.16, 6.7),
		Vector3(-3.2, -0.08, -3.6),
		ROOM_COLORS[0]
	)
	_make_box(
		"LoungeFloor",
		Vector3(6.1, 0.16, 6.7),
		Vector3(3.2, -0.08, -3.6),
		ROOM_COLORS[1]
	)
	_make_box(
		"KitchenFloor",
		Vector3(6.1, 0.16, 6.7),
		Vector3(-3.2, -0.08, 3.6),
		ROOM_COLORS[2]
	)
	_make_box(
		"BathFloor",
		Vector3(6.1, 0.16, 6.7),
		Vector3(3.2, -0.08, 3.6),
		ROOM_COLORS[3]
	)

	var wall_color := Color("596176")
	_make_box("BackWall", Vector3(13.4, 1.6, 0.22), Vector3(0.0, 0.75, -7.1), wall_color)
	_make_box("LeftWall", Vector3(0.22, 1.6, 14.0), Vector3(-6.6, 0.75, 0.0), wall_color)
	_make_box("RightWall", Vector3(0.22, 1.6, 14.0), Vector3(6.6, 0.75, 0.0), wall_color)
	_make_box("MidWallA", Vector3(0.18, 1.05, 5.0), Vector3(0.0, 0.48, -4.3), wall_color)
	_make_box("MidWallB", Vector3(0.18, 1.05, 4.9), Vector3(0.0, 0.48, 4.4), wall_color)
	_make_box("CrossWallLeft", Vector3(4.7, 1.05, 0.18), Vector3(-4.15, 0.48, 0.0), wall_color)
	_make_box("CrossWallRight", Vector3(4.7, 1.05, 0.18), Vector3(4.15, 0.48, 0.0), wall_color)

	_build_bedroom()
	_build_lounge()
	_build_kitchen()
	_build_bathroom()

func _build_bedroom() -> void:
	var bed_color := Color("7182a8")
	for index in range(3):
		var z_position := -5.4 + float(index) * 1.65
		_make_box(
			"Bed_%02d" % index,
			Vector3(2.1, 0.36, 1.18),
			Vector3(-4.35, 0.18, z_position),
			bed_color
		)
		_make_box(
			"BedBlanket_%02d" % index,
			Vector3(1.15, 0.08, 1.0),
			Vector3(-4.1, 0.4, z_position),
			Color("9eb5e7")
		)

func _build_lounge() -> void:
	_make_box(
		"SofaBase",
		Vector3(3.7, 0.48, 1.15),
		Vector3(3.15, 0.28, -4.7),
		Color("765d85")
	)
	_make_box(
		"SofaBack",
		Vector3(3.7, 1.0, 0.32),
		Vector3(3.15, 0.82, -5.2),
		Color("8a6c9c")
	)
	_make_box(
		"CoffeeTable",
		Vector3(2.0, 0.28, 1.1),
		Vector3(3.15, 0.18, -2.6),
		Color("8b6f54")
	)
	_make_box(
		"TV",
		Vector3(2.8, 1.45, 0.22),
		Vector3(3.15, 1.0, -0.55),
		Color("11141c")
	)

func _build_kitchen() -> void:
	_make_box(
		"KitchenCounter",
		Vector3(4.7, 0.85, 0.72),
		Vector3(-3.55, 0.42, 5.8),
		Color("778a82")
	)
	_make_box(
		"Fridge",
		Vector3(1.2, 2.25, 1.0),
		Vector3(-5.25, 1.12, 2.0),
		Color("c4d0d6")
	)
	_make_box(
		"DiningTable",
		Vector3(2.6, 0.3, 2.1),
		Vector3(-2.7, 0.52, 3.1),
		Color("8d6d4e")
	)
	for offset in [
		Vector3(-1.55, 0.42, 3.1),
		Vector3(-3.85, 0.42, 3.1),
		Vector3(-2.7, 0.42, 1.95),
		Vector3(-2.7, 0.42, 4.25),
	]:
		_make_cylinder("DiningChair", 0.38, 0.7, offset, Color("596b68"))

func _build_bathroom() -> void:
	_make_box(
		"ShowerBase",
		Vector3(2.1, 0.16, 2.1),
		Vector3(4.6, 0.08, 5.1),
		Color("76a8b8")
	)
	_make_box(
		"ShowerWallA",
		Vector3(2.1, 1.9, 0.1),
		Vector3(4.6, 0.95, 6.1),
		Color(0.55, 0.78, 0.86, 0.35)
	)
	_make_box(
		"Sink",
		Vector3(1.35, 0.55, 0.75),
		Vector3(1.7, 0.72, 5.35),
		Color("d8dedf")
	)
	_make_box(
		"Washer",
		Vector3(1.25, 1.25, 1.0),
		Vector3(1.65, 0.62, 2.2),
		Color("9aa9b3")
	)

func _build_demo_residents() -> Array[CharacterState]:
	var residents: Array[CharacterState] = []
	var blocks := [
		&"work",
		&"free_time",
		&"social",
		&"work",
		&"meal",
		&"free_time",
	]
	var money := [84.0, 42.0, 115.0, 67.0, 31.0, 96.0]
	var hunger := [76.0, 58.0, 91.0, 44.0, 68.0, 82.0]
	var energy := [63.0, 74.0, 57.0, 88.0, 69.0, 52.0]
	var social := [47.0, 79.0, 66.0, 35.0, 72.0, 61.0]
	var goal_categories := [
		&"work",
		&"social",
		&"wellbeing",
		&"work",
		&"social",
		&"fun",
	]

	for index in range(6):
		var resident := CharacterState.new(
			StringName("showcase_%02d" % (index + 1)),
			RESIDENT_NAMES[index]
		)
		resident.money = money[index]
		resident.needs.hunger.value = hunger[index]
		resident.needs.energy.value = energy[index]
		resident.needs.social.value = social[index]
		resident.needs.comfort.value = 72.0 - float(index) * 3.0
		resident.needs.mood.value = 64.0 + float(index) * 4.0
		resident.schedule.day_index = 3
		resident.schedule.active_block_id = blocks[index]
		resident.goals.begin_day(3)

		var goal_definition := GoalDefinition.new()
		goal_definition.id = StringName(
			"%s_showcase_day_3" % goal_categories[index]
		)
		goal_definition.category = goal_categories[index]
		goal_definition.priority = 0.65 + float(index) * 0.05
		match goal_categories[index]:
			&"work":
				goal_definition.preferred_action_tags.append(&"work")
			&"social":
				goal_definition.preferred_action_tags.append(&"social")
			&"wellbeing":
				goal_definition.preferred_action_tags.append(&"relax")
			&"fun":
				goal_definition.preferred_action_tags.append(&"relax")
				goal_definition.preferred_action_tags.append(&"spend")

		var goal := GoalState.new(goal_definition)
		goal.set_progress(0.15 + float(index) * 0.1)
		resident.goals.add(goal)
		residents.append(resident)

	return residents

func _build_resident_visuals() -> void:
	for index in range(_resident_states.size()):
		var resident := _resident_states[index]
		var root := Node3D.new()
		root.name = "ResidentVisual_%02d" % (index + 1)
		root.position = RESIDENT_POSITIONS[index]
		add_child(root)

		_make_cylinder(
			"Body",
			0.42,
			1.2,
			Vector3(0.0, 0.78, 0.0),
			RESIDENT_COLORS[index],
			root
		)
		_make_sphere(
			"Head",
			0.38,
			Vector3(0.0, 1.72, 0.0),
			RESIDENT_COLORS[index].lightened(0.14),
			root
		)
		_make_cylinder(
			"ShadowMarker",
			0.62,
			0.06,
			Vector3(0.0, 0.04, 0.0),
			Color(0.08, 0.1, 0.16, 0.75),
			root
		)

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "HUD"
	add_child(canvas)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(root)

	var top_panel := PanelContainer.new()
	top_panel.position = Vector2(22.0, 22.0)
	top_panel.size = Vector2(676.0, 118.0)
	top_panel.add_theme_stylebox_override(
		"panel",
		_panel_style(Color(0.055, 0.07, 0.115, 0.94), 18.0)
	)
	root.add_child(top_panel)

	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_left", 22)
	top_margin.add_theme_constant_override("margin_right", 22)
	top_margin.add_theme_constant_override("margin_top", 15)
	top_margin.add_theme_constant_override("margin_bottom", 15)
	top_panel.add_child(top_margin)

	var top_box := VBoxContainer.new()
	top_box.add_theme_constant_override("separation", 5)
	top_margin.add_child(top_box)

	var title := Label.new()
	title.text = "LIFEBOX LIVE  •  AI TOWN"
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", Color("f2f6ff"))
	top_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "DAY 3  •  14:20  •  6 RESIDENTS  •  AUTONOMOUS SIM"
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color("8ea6c9"))
	top_box.add_child(subtitle)

	var chaos := ProgressBar.new()
	chaos.min_value = 0.0
	chaos.max_value = 100.0
	chaos.value = 37.0
	chaos.custom_minimum_size = Vector2(0.0, 12.0)
	chaos.show_percentage = false
	top_box.add_child(chaos)

	var cards_panel := PanelContainer.new()
	cards_panel.position = Vector2(22.0, 858.0)
	cards_panel.size = Vector2(676.0, 396.0)
	cards_panel.add_theme_stylebox_override(
		"panel",
		_panel_style(Color(0.045, 0.055, 0.09, 0.96), 18.0)
	)
	root.add_child(cards_panel)

	var cards_margin := MarginContainer.new()
	cards_margin.add_theme_constant_override("margin_left", 14)
	cards_margin.add_theme_constant_override("margin_right", 14)
	cards_margin.add_theme_constant_override("margin_top", 14)
	cards_margin.add_theme_constant_override("margin_bottom", 14)
	cards_panel.add_child(cards_margin)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	cards_margin.add_child(grid)

	for index in range(_resident_states.size()):
		grid.add_child(_resident_card(_resident_states[index], index))

	var event_panel := PanelContainer.new()
	event_panel.position = Vector2(22.0, 770.0)
	event_panel.size = Vector2(676.0, 72.0)
	event_panel.add_theme_stylebox_override(
		"panel",
		_panel_style(Color(0.08, 0.11, 0.17, 0.92), 14.0)
	)
	root.add_child(event_panel)

	var event_label := Label.new()
	event_label.text = "STORY  •  Ava started work   |   Noah wants to talk to Mia   |   Chaos 37%"
	event_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	event_label.add_theme_font_size_override("font_size", 14)
	event_label.add_theme_color_override("font_color", Color("d9e7ff"))
	event_panel.add_child(event_label)

func _resident_card(resident: CharacterState, index: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(319.0, 112.0)
	card.add_theme_stylebox_override(
		"panel",
		_panel_style(Color(0.085, 0.1, 0.15, 0.95), 12.0, RESIDENT_COLORS[index])
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 13)
	margin.add_theme_constant_override("margin_right", 13)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	margin.add_child(box)

	var header := Label.new()
	header.text = "%s   •   %s" % [
		resident.display_name.to_upper(),
		str(resident.schedule.active_block_id).to_upper(),
	]
	header.add_theme_font_size_override("font_size", 17)
	header.add_theme_color_override("font_color", RESIDENT_COLORS[index].lightened(0.16))
	box.add_child(header)

	var goal_text := "No active goal"
	var active_goals := resident.goals.active_goals()
	if not active_goals.is_empty():
		var goal: GoalState = active_goals[0]
		goal_text = "%s  %d%%" % [
			str(goal.definition.category).capitalize(),
			int(round(goal.progress * 100.0)),
		]

	var goal_label := Label.new()
	goal_label.text = "Goal: %s" % goal_text
	goal_label.add_theme_font_size_override("font_size", 13)
	goal_label.add_theme_color_override("font_color", Color("dce4f5"))
	box.add_child(goal_label)

	var stats := Label.new()
	stats.text = "$%d   Hunger %d   Energy %d   Social %d" % [
		int(round(resident.money)),
		int(round(resident.needs.hunger.value)),
		int(round(resident.needs.energy.value)),
		int(round(resident.needs.social.value)),
	]
	stats.add_theme_font_size_override("font_size", 12)
	stats.add_theme_color_override("font_color", Color("9eacc6"))
	box.add_child(stats)

	return card

func _configure_camera() -> void:
	var camera := Camera3D.new()
	camera.name = "ShowcaseCamera"
	camera.position = Vector3(11.8, 16.8, 20.5)
	camera.fov = 43.0
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.7, 0.0), Vector3.UP)
	camera.current = true

func _make_box(
	node_name: String,
	size: Vector3,
	position: Vector3,
	color: Color,
	parent: Node = null
) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position
	instance.material_override = _material(color)
	var target_parent: Node = parent if parent != null else self
	target_parent.add_child(instance)
	return instance

func _make_cylinder(
	node_name: String,
	radius: float,
	height: float,
	position: Vector3,
	color: Color,
	parent: Node = null
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position
	instance.material_override = _material(color)
	var target_parent: Node = parent if parent != null else self
	target_parent.add_child(instance)
	return instance

func _make_sphere(
	node_name: String,
	radius: float,
	position: Vector3,
	color: Color,
	parent: Node = null
) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position
	instance.material_override = _material(color)
	var target_parent: Node = parent if parent != null else self
	target_parent.add_child(instance)
	return instance

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	return material

func _panel_style(
	color: Color,
	radius: float,
	border_color: Color = Color.TRANSPARENT
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = int(radius)
	style.corner_radius_top_right = int(radius)
	style.corner_radius_bottom_left = int(radius)
	style.corner_radius_bottom_right = int(radius)
	if border_color.a > 0.0:
		style.border_width_left = 3
		style.border_color = border_color
	return style

func _capture_when_ready(capture_path: String) -> void:
	for _frame in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var directory := capture_path.get_base_dir()
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)

	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(capture_path)
	if error == OK:
		print("SHOWCASE_CAPTURED:%s" % capture_path)
		get_tree().quit(0)
	else:
		push_error("Failed to save showcase screenshot: %s" % error_string(error))
		get_tree().quit(1)
