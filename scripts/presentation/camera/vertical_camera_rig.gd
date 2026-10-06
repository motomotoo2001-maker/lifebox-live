class_name VerticalCameraRig
extends Node3D

@export var establishing_position: Vector3 = Vector3(15.0, 15.0, 19.0)
@export var establishing_target: Vector3 = Vector3(0.0, 0.6, 0.0)
@export var establishing_ortho_size: float = 30.0
@export var focus_ortho_size: float = 20.5
@export var transition_speed: float = 4.5
@export var min_ortho_size: float = 11.0
@export var max_ortho_size: float = 34.0
@export var target_x_bounds: Vector2 = Vector2(-8.5, 8.5)
@export var target_z_bounds: Vector2 = Vector2(-5.5, 5.5)

@onready var camera: Camera3D = $Camera3D

var _desired_target: Vector3 = Vector3.ZERO
var _current_target: Vector3 = Vector3.ZERO
var _desired_size: float = 30.0

func _ready() -> void:
	global_position = establishing_position
	_desired_target = establishing_target
	_current_target = establishing_target
	_desired_size = maxf(establishing_ortho_size, 1.0)
	camera.size = _desired_size
	_apply_target()
	camera.current = true

func _process(delta: float) -> void:
	if not is_instance_valid(camera):
		return
	if is_nan(delta) or is_inf(delta) or delta <= 0.0:
		return

	var speed := maxf(transition_speed, 0.01)
	var weight := 1.0 - exp(-speed * delta)
	_current_target = _current_target.lerp(_desired_target, weight)
	camera.size = lerpf(camera.size, _desired_size, weight)
	_apply_target()

func set_establishing_view() -> void:
	global_position = establishing_position
	_desired_target = establishing_target
	_desired_size = maxf(establishing_ortho_size, 1.0)

func pan_world(offset: Vector3) -> void:
	if not _is_finite_vector(offset):
		return
	_desired_target = _clamp_target(
		_desired_target + Vector3(offset.x, 0.0, offset.z)
	)

func adjust_zoom(delta_size: float) -> void:
	if is_nan(delta_size) or is_inf(delta_size):
		return
	_desired_size = clampf(
		_desired_size + delta_size,
		maxf(min_ortho_size, 1.0),
		maxf(max_ortho_size, maxf(min_ortho_size, 1.0))
	)

func desired_target() -> Vector3:
	return _desired_target

func desired_size() -> float:
	return _desired_size

func focus_world_position(target: Vector3, requested_size: float = -1.0) -> void:
	if not is_instance_valid(camera):
		return
	if not _is_finite_vector(target):
		return

	var view_size := focus_ortho_size
	if (
		requested_size > 0.0
		and not is_nan(requested_size)
		and not is_inf(requested_size)
	):
		view_size = requested_size

	_desired_target = _clamp_target(target)
	_desired_size = clampf(
		maxf(view_size, 1.0),
		maxf(min_ortho_size, 1.0),
		maxf(max_ortho_size, maxf(min_ortho_size, 1.0))
	)

func get_camera() -> Camera3D:
	return camera

func _clamp_target(value: Vector3) -> Vector3:
	return Vector3(
		clampf(value.x, target_x_bounds.x, target_x_bounds.y),
		value.y,
		clampf(value.z, target_z_bounds.x, target_z_bounds.y)
	)

func _apply_target() -> void:
	var direction := _current_target - global_position
	if direction.length_squared() <= 0.000001:
		return
	look_at(_current_target, Vector3.UP)

func _is_finite_vector(value: Vector3) -> bool:
	return (
		not is_nan(value.x) and not is_inf(value.x)
		and not is_nan(value.y) and not is_inf(value.y)
		and not is_nan(value.z) and not is_inf(value.z)
	)
