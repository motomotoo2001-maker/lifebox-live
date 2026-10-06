class_name ResidentActor3D
extends CharacterBody3D

signal movement_arrived(character_id: StringName)
signal movement_failed(character_id: StringName)

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

var _character_id: StringName = &""
var _pending_target: Vector3 = Vector3.ZERO
var _arrival_radius: float = 0.5
var _has_target: bool = false
var _target_applied: bool = false
var _display_name: String = "Resident"
var _visual_time: float = 0.0

func _ready() -> void:
	navigation_agent.velocity_computed.connect(_on_velocity_computed)
	_apply_visual_style()
	_refresh_name_label()

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

func _animate_visuals() -> void:
	if not is_instance_valid(visuals):
		return

	var moving: bool = _has_target or velocity.length_squared() > 0.01
	var frequency := 8.0 if moving else 2.0
	var amplitude := 0.035 if moving else 0.012
	visuals.position.y = sin(_visual_time * frequency) * amplitude

	if is_instance_valid(arm_left) and is_instance_valid(arm_right):
		var swing := sin(_visual_time * frequency) * 0.22 if moving else 0.0
		arm_left.rotation.x = swing
		arm_right.rotation.x = -swing

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
		hair_mesh.material_override = _material(Color("2b2630"), 0.86)

	if is_instance_valid(shadow_mesh):
		var shadow_material := _material(Color(0.02, 0.03, 0.05, 0.34), 1.0)
		shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		shadow_mesh.material_override = shadow_material

	if is_instance_valid(name_label):
		name_label.modulate = Color.WHITE

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
