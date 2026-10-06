class_name VerticalCameraRig
extends Node3D

@export var establishing_position: Vector3 = Vector3(15.0, 15.0, 19.0)
@export var establishing_target: Vector3 = Vector3(0.0, 0.6, 0.0)
@export var establishing_ortho_size: float = 30.0
@export var focus_ortho_size: float = 18.0

@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	set_establishing_view()
	camera.current = true

func set_establishing_view() -> void:
	if not is_instance_valid(camera):
		return
	global_position = establishing_position
	camera.size = maxf(establishing_ortho_size, 1.0)
	look_at(establishing_target, Vector3.UP)

func focus_world_position(target: Vector3, requested_size: float = -1.0) -> void:
	if not is_instance_valid(camera):
		return
	if not _is_finite_vector(target):
		return

	var view_size := focus_ortho_size
	if requested_size > 0.0 and not is_nan(requested_size) and not is_inf(requested_size):
		view_size = requested_size
	camera.size = maxf(view_size, 1.0)
	look_at(target, Vector3.UP)

func get_camera() -> Camera3D:
	return camera

func _is_finite_vector(value: Vector3) -> bool:
	return (
		not is_nan(value.x) and not is_inf(value.x)
		and not is_nan(value.y) and not is_inf(value.y)
		and not is_nan(value.z) and not is_inf(value.z)
	)
