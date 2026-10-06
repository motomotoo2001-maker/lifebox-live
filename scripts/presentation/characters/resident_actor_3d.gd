class_name ResidentActor3D
extends CharacterBody3D

signal movement_arrived(character_id: StringName)
signal movement_failed(character_id: StringName)

@export var movement_speed: float = 2.5
@export var walk_bob_height: float = 0.055
@export var walk_bob_speed: float = 10.0

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var visual_root: Node3D = $VisualRoot
@onready var body_mesh: MeshInstance3D = $VisualRoot/Body
@onready var head_mesh: MeshInstance3D = $VisualRoot/Head
@onready var shadow_mesh: MeshInstance3D = $VisualRoot/Shadow
@onready var name_label: Label3D = $VisualRoot/NameLabel

var _character_id: StringName = &""
var _display_name: String = "Resident"
var _pending_target: Vector3 = Vector3.ZERO
var _arrival_radius: float = 0.5
var _has_target: bool = false
var _target_applied: bool = false
var _visual_time: float = 0.0

func _ready() -> void:
	navigation_agent.velocity_computed.connect(_on_velocity_computed)
	_apply_shadow_material()
	_refresh_label(&"idle")

func bind_character(character_id: StringName) -> void:
	_character_id = character_id

func get_character_id() -> StringName:
	return _character_id

func has_movement_target() -> bool:
	return _has_target

func set_visual_profile(display_name: String, color: Color) -> void:
	_display_name = display_name
	body_mesh.material_override = _material(color)
	head_mesh.material_override = _material(color.lightened(0.16))
	name_label.modulate = color.lightened(0.18)
	name_label.outline_modulate = Color(0.02, 0.025, 0.04, 0.95)
	_refresh_label(&"idle")

func set_activity_label(activity_id: StringName) -> void:
	_refresh_label(activity_id)

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
	visual_root.position.y = 0.0
	if is_instance_valid(navigation_agent):
		navigation_agent.velocity = Vector3.ZERO

func _physics_process(delta: float) -> void:
	if not _has_target:
		visual_root.position.y = move_toward(
			visual_root.position.y,
			0.0,
			maxf(delta * 0.5, 0.0)
		)
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

	_face_next_path_position(next_path_position)
	_visual_time += maxf(delta, 0.0)
	visual_root.position.y = sin(_visual_time * walk_bob_speed) * walk_bob_height

	var desired_velocity: Vector3 = (
		global_position.direction_to(next_path_position) * movement_speed
	)
	if navigation_agent.avoidance_enabled:
		navigation_agent.velocity = desired_velocity
	else:
		_on_velocity_computed(desired_velocity)

func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if not _has_target:
		return
	velocity = safe_velocity
	move_and_slide()

func _arrive() -> void:
	stop_movement()
	movement_arrived.emit(_character_id)

func _fail_movement() -> void:
	stop_movement()
	movement_failed.emit(_character_id)

func _face_next_path_position(next_path_position: Vector3) -> void:
	var flat_target := Vector3(
		next_path_position.x,
		global_position.y,
		next_path_position.z
	)
	if global_position.distance_squared_to(flat_target) <= 0.0001:
		return
	look_at(flat_target, Vector3.UP)

func _refresh_label(activity_id: StringName) -> void:
	if not is_instance_valid(name_label):
		return
	var activity_text := str(activity_id).replace("_", " ").to_upper()
	name_label.text = "%s  •  %s" % [
		_display_name.to_upper(),
		activity_text,
	]

func _apply_shadow_material() -> void:
	if not is_instance_valid(shadow_mesh):
		return
	var shadow_material := StandardMaterial3D.new()
	shadow_material.albedo_color = Color(0.05, 0.06, 0.09, 1.0)
	shadow_material.roughness = 1.0
	shadow_mesh.material_override = shadow_material

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	return material

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
