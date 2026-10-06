class_name ResidentActor3D
extends CharacterBody3D

signal movement_arrived(character_id: StringName)
signal movement_failed(character_id: StringName)
signal resident_selected(character_id: StringName)

@export var movement_speed: float = 2.5
@export var resident_color: Color = Color("58a6ff")

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var visuals: Node3D = $Visuals
@onready var body_mesh: MeshInstance3D = $Visuals/Body
@onready var head_mesh: MeshInstance3D = $Visuals/Head
@onready var shadow_mesh: MeshInstance3D = $Visuals/Shadow
@onready var name_label: Label3D = $Visuals/NameLabel
@onready var leg_left: MeshInstance3D = $Visuals/LegLeft
@onready var leg_right: MeshInstance3D = $Visuals/LegRight
@onready var arm_left: MeshInstance3D = $Visuals/ArmLeft
@onready var arm_right: MeshInstance3D = $Visuals/ArmRight
@onready var hair_mesh: MeshInstance3D = $Visuals/Hair
@onready var nose_mesh: MeshInstance3D = $Visuals/Nose
@onready var eye_left: MeshInstance3D = $Visuals/EyeLeft
@onready var eye_right: MeshInstance3D = $Visuals/EyeRight
@onready var activity_badge: Label3D = $Visuals/ActivityBadge
@onready var selection_marker: MeshInstance3D = $Visuals/SelectionMarker
@onready var click_area: Area3D = $ClickArea

var _character_id: StringName = &""
var _pending_target: Vector3 = Vector3.ZERO
var _arrival_radius: float = 0.5
var _has_target: bool = false
var _target_applied: bool = false
const STATE_IDLE: StringName = &"idle"
const STATE_WALK: StringName = &"walk"
const STATE_INTERACT: StringName = &"interact"
const STATE_SOCIAL: StringName = &"social"

var _display_name: String = "Resident"
var _visual_time: float = 0.0
var _visual_profile_index: int = 0
var _presentation_state: StringName = STATE_IDLE
var _badge_time_remaining: float = 0.0
var _selected: bool = false

func _ready() -> void:
	navigation_agent.velocity_computed.connect(_on_velocity_computed)
	if is_instance_valid(click_area) and not click_area.input_event.is_connected(
		_on_click_area_input_event
	):
		click_area.input_event.connect(_on_click_area_input_event)
	_apply_visual_style()
	_refresh_name_label()
	set_selected(_selected)

func bind_character(character_id: StringName) -> void:
	_character_id = character_id
	if _display_name == "Resident" and character_id != &"":
		_display_name = str(character_id)
	_refresh_name_label()

func set_display_name(value: String) -> void:
	_display_name = value.strip_edges()
	if _display_name.is_empty():
		_display_name = str(_character_id) if _character_id != &"" else "Resident"
	_refresh_name_label()

func set_visual_color(value: Color) -> void:
	resident_color = value
	_apply_visual_style()

func set_visual_profile(profile_index: int) -> void:
	_visual_profile_index = maxi(profile_index, 0)
	_apply_visual_style()
	_apply_visual_profile()

func set_presentation_state(state: StringName) -> void:
	match state:
		STATE_IDLE, STATE_WALK, STATE_INTERACT, STATE_SOCIAL:
			_presentation_state = state
		_:
			_presentation_state = STATE_IDLE

func presentation_state() -> StringName:
	return _presentation_state

func set_selected(value: bool) -> void:
	_selected = value

	var marker: MeshInstance3D = selection_marker
	if not is_instance_valid(marker) and has_node("Visuals/SelectionMarker"):
		marker = get_node("Visuals/SelectionMarker") as MeshInstance3D
	if is_instance_valid(marker):
		marker.visible = value

	var label: Label3D = name_label
	if not is_instance_valid(label) and has_node("Visuals/NameLabel"):
		label = get_node("Visuals/NameLabel") as Label3D
	if is_instance_valid(label):
		label.modulate = Color("fff3a6") if value else Color.WHITE

func is_selected() -> bool:
	return _selected

func set_activity_badge(text: String, duration: float = 0.0) -> void:
	if not is_instance_valid(activity_badge):
		return
	activity_badge.text = text.strip_edges()
	activity_badge.visible = not activity_badge.text.is_empty()
	activity_badge.modulate = _activity_badge_color(activity_badge.text)
	if is_nan(duration) or is_inf(duration) or duration < 0.0:
		_badge_time_remaining = 0.0
	else:
		_badge_time_remaining = duration

func _activity_badge_color(text: String) -> Color:
	match text.to_upper():
		"SOCIAL":
			return Color("c9a7ff")
		"MEAL":
			return Color("ffb36b")
		"WORK":
			return Color("77baff")
		"FUN":
			return Color("7fe0a1")
		_:
			return Color("ffe070")

func clear_activity_badge() -> void:
	_badge_time_remaining = 0.0
	if is_instance_valid(activity_badge):
		activity_badge.text = ""
		activity_badge.visible = false

func set_movement_target(target: Vector3, arrival_radius: float) -> void:
	if not _is_finite_vector(target):
		_fail_movement()
		return
	_pending_target = target
	_arrival_radius = _sanitize_radius(arrival_radius)
	_has_target = true
	_target_applied = false

func stop_movement() -> void:
	_has_target = false
	_target_applied = false
	velocity = Vector3.ZERO
	if is_instance_valid(navigation_agent):
		navigation_agent.velocity = Vector3.ZERO

func _physics_process(delta: float) -> void:
	_visual_time += delta
	_update_activity_badge(delta)
	_animate_visuals()

	if not _has_target:
		return
	if not is_instance_valid(navigation_agent):
		_fail_movement()
		return

	var navigation_map: RID = navigation_agent.get_navigation_map()
	if NavigationServer3D.map_get_iteration_id(navigation_map) == 0:
		return

	if not _target_applied:
		navigation_agent.target_desired_distance = _arrival_radius
		navigation_agent.target_position = _pending_target
		_target_applied = true

	if navigation_agent.is_navigation_finished():
		_arrive()
		return

	var next_path_position: Vector3 = navigation_agent.get_next_path_position()
	if not navigation_agent.is_target_reachable():
		_fail_movement()
		return

	var desired_velocity: Vector3 = (
		global_position.direction_to(next_path_position) * movement_speed
	)
	if navigation_agent.avoidance_enabled:
		navigation_agent.velocity = desired_velocity
	else:
		_on_velocity_computed(desired_velocity)

func _update_activity_badge(delta: float) -> void:
	if _badge_time_remaining <= 0.0:
		return
	_badge_time_remaining = maxf(_badge_time_remaining - maxf(delta, 0.0), 0.0)
	if _badge_time_remaining <= 0.0:
		clear_activity_badge()

func _animate_visuals() -> void:
	if not is_instance_valid(visuals):
		return

	var state := _presentation_state
	if _has_target or velocity.length_squared() > 0.01:
		state = STATE_WALK

	visuals.position.y = 0.0
	visuals.rotation.x = 0.0
	visuals.rotation.z = 0.0

	if is_instance_valid(head_mesh):
		head_mesh.rotation.x = 0.0
		head_mesh.rotation.z = 0.0
	if is_instance_valid(arm_left):
		arm_left.rotation.x = 0.0
	if is_instance_valid(arm_right):
		arm_right.rotation.x = 0.0
	if is_instance_valid(leg_left):
		leg_left.rotation.x = 0.0
	if is_instance_valid(leg_right):
		leg_right.rotation.x = 0.0

	match state:
		STATE_WALK:
			_animate_walk_state()
		STATE_INTERACT:
			_animate_interact_state()
		STATE_SOCIAL:
			_animate_social_state()
		_:
			_animate_idle_state()

func _animate_idle_state() -> void:
	var phase := sin(_visual_time * 2.0)
	visuals.position.y = phase * 0.012
	visuals.rotation.z = phase * 0.008
	if is_instance_valid(head_mesh):
		head_mesh.rotation.z = -phase * 0.025

func _animate_walk_state() -> void:
	var phase := sin(_visual_time * 8.0)
	visuals.position.y = abs(phase) * 0.035
	if is_instance_valid(arm_left):
		arm_left.rotation.x = phase * 0.34
	if is_instance_valid(arm_right):
		arm_right.rotation.x = -phase * 0.34
	if is_instance_valid(leg_left):
		leg_left.rotation.x = -phase * 0.24
	if is_instance_valid(leg_right):
		leg_right.rotation.x = phase * 0.24
	if is_instance_valid(head_mesh):
		head_mesh.rotation.z = phase * 0.018

func _animate_interact_state() -> void:
	var phase := sin(_visual_time * 4.2)
	visuals.position.y = phase * 0.014
	visuals.rotation.x = -0.035 + phase * 0.012
	if is_instance_valid(arm_left):
		arm_left.rotation.x = -0.42 + phase * 0.08
	if is_instance_valid(arm_right):
		arm_right.rotation.x = -0.42 - phase * 0.08
	if is_instance_valid(head_mesh):
		head_mesh.rotation.x = 0.035 + phase * 0.015

func _animate_social_state() -> void:
	var phase := sin(_visual_time * 3.0)
	visuals.position.y = abs(phase) * 0.01
	visuals.rotation.z = phase * 0.035
	if is_instance_valid(arm_left):
		arm_left.rotation.x = -0.12 + phase * 0.2
	if is_instance_valid(arm_right):
		arm_right.rotation.x = -0.12 - phase * 0.12
	if is_instance_valid(head_mesh):
		head_mesh.rotation.z = -phase * 0.055

func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if not _has_target:
		return
	_face_velocity(safe_velocity)
	velocity = safe_velocity
	move_and_slide()

func _face_velocity(value: Vector3) -> void:
	if not is_instance_valid(visuals):
		return
	var planar := Vector3(value.x, 0.0, value.z)
	if planar.length_squared() <= 0.0001:
		return
	visuals.rotation.y = atan2(-planar.x, -planar.z)

func _material(
	color: Color,
	roughness: float = 0.82
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _apply_visual_style() -> void:
	if not is_instance_valid(body_mesh):
		return

	body_mesh.material_override = _material(resident_color, 0.78)
	var lower := resident_color.darkened(0.2)

	for mesh in [leg_left, leg_right]:
		if is_instance_valid(mesh):
			mesh.material_override = _material(lower, 0.88)

	for mesh in [arm_left, arm_right]:
		if is_instance_valid(mesh):
			mesh.material_override = _material(
				resident_color.lightened(0.03),
				0.82
			)

	if is_instance_valid(head_mesh):
		head_mesh.material_override = _material(Color("efc19c"), 0.72)
	if is_instance_valid(nose_mesh):
		nose_mesh.material_override = _material(Color("dfa982"), 0.78)
	if is_instance_valid(hair_mesh):
		var hair_colors: Array[Color] = [
			Color("2b2630"),
			Color("4b3328"),
			Color("1d2430"),
			Color("6b4a32"),
			Color("342b3a"),
			Color("302a24"),
		]
		hair_mesh.material_override = _material(
			hair_colors[_visual_profile_index % hair_colors.size()],
			0.86
		)

	var trouser_colors: Array[Color] = [
		Color("24364a"),
		Color("403954"),
		Color("4a332f"),
		Color("233f35"),
		Color("51411e"),
		Color("462f46"),
	]
	var trouser_color: Color = trouser_colors[
		_visual_profile_index % trouser_colors.size()
	]
	for mesh in [leg_left, leg_right]:
		if is_instance_valid(mesh):
			mesh.material_override = _material(trouser_color, 0.9)

	var eye_material := _material(Color("151922"), 0.45)
	for eye in [eye_left, eye_right]:
		if is_instance_valid(eye):
			eye.material_override = eye_material

	if is_instance_valid(shadow_mesh):
		var shadow_material := _material(Color(0.02, 0.03, 0.05, 0.34), 1.0)
		shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		shadow_mesh.material_override = shadow_material

	if is_instance_valid(name_label):
		name_label.modulate = Color("fff3a6") if _selected else Color.WHITE

	if is_instance_valid(selection_marker):
		var selection_material := _material(
			Color("ffd65a"),
			0.7
		)
		selection_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		selection_material.albedo_color.a = 0.46
		selection_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		selection_marker.material_override = selection_material
		selection_marker.visible = _selected

func _apply_visual_profile() -> void:
	if not is_instance_valid(visuals):
		return

	var variant := _visual_profile_index % 6
	var body_scales: Array[Vector3] = [
		Vector3(1.0, 1.0, 1.0),
		Vector3(0.94, 1.04, 0.94),
		Vector3(1.05, 0.97, 1.05),
		Vector3(0.98, 1.06, 0.98),
		Vector3(1.03, 1.0, 0.97),
		Vector3(0.96, 0.99, 1.04),
	]
	var hair_scales: Array[Vector3] = [
		Vector3(1.02, 0.55, 1.02),
		Vector3(1.08, 0.42, 1.02),
		Vector3(0.94, 0.68, 1.0),
		Vector3(1.12, 0.5, 0.92),
		Vector3(0.9, 0.72, 1.05),
		Vector3(1.06, 0.6, 1.08),
	]
	var hair_heights: Array[float] = [1.68, 1.65, 1.72, 1.67, 1.74, 1.7]

	if is_instance_valid(body_mesh):
		body_mesh.scale = body_scales[variant]
	if is_instance_valid(hair_mesh):
		hair_mesh.scale = hair_scales[variant]
		hair_mesh.position.y = hair_heights[variant]

	var stance_offsets: Array[float] = [0.15, 0.14, 0.16, 0.145, 0.155, 0.14]
	if is_instance_valid(leg_left):
		leg_left.position.x = -stance_offsets[variant]
	if is_instance_valid(leg_right):
		leg_right.position.x = stance_offsets[variant]

func _on_click_area_input_event(
	_camera: Node,
	event: InputEvent,
	_event_position: Vector3,
	_normal: Vector3,
	_shape_idx: int
) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if _character_id == &"":
		return
	resident_selected.emit(_character_id)
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()

func _refresh_name_label() -> void:
	if is_instance_valid(name_label):
		name_label.text = _display_name

func _arrive() -> void:
	stop_movement()
	movement_arrived.emit(_character_id)

func _fail_movement() -> void:
	stop_movement()
	movement_failed.emit(_character_id)

func _sanitize_radius(value: float) -> float:
	if is_nan(value) or is_inf(value):
		return 0.5
	return maxf(value, 0.05)

func _is_finite_vector(value: Vector3) -> bool:
	return (
		not is_nan(value.x) and not is_inf(value.x)
		and not is_nan(value.y) and not is_inf(value.y)
		and not is_nan(value.z) and not is_inf(value.z)
	)
