class_name VerticalCameraRig
extends Node3D

@export var establishing_position: Vector3 = Vector3(15.0, 15.0, 19.0)
@export var establishing_target: Vector3 = Vector3(0.0, 0.6, 0.0)
@export var establishing_ortho_size: float = 30.0
@export var focus_ortho_size: float = 20.5
@export var transition_speed: float = 4.5

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

	_desired_target = target
	_desired_size = maxf(view_size, 1.0)

func get_camera() -> Camera3D:
	return camera

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
