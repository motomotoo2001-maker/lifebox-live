class_name ResidentActor3D
extends CharacterBody3D

signal movement_arrived(character_id: StringName)
signal movement_failed(character_id: StringName)

@export var movement_speed: float = 2.5

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D

var _character_id: StringName = &""
var _pending_target: Vector3 = Vector3.ZERO
var _arrival_radius: float = 0.5
var _has_target: bool = false
var _target_applied: bool = false

func _ready() -> void:
	navigation_agent.velocity_computed.connect(_on_velocity_computed)

func bind_character(character_id: StringName) -> void:
	_character_id = character_id

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

func _physics_process(_delta: float) -> void:
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

	var desired_velocity := global_position.direction_to(next_path_position) * movement_speed
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
