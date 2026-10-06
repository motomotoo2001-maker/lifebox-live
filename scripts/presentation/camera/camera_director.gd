class_name CameraDirector
extends Node

@export var min_focus_hold_seconds: float = 3.0
@export var switch_cooldown_seconds: float = 1.5
@export var switch_margin: float = 12.0
@export var min_focus_interest: float = 15.0
@export var return_to_establishing_after_seconds: float = 4.0
@export var focus_ortho_size: float = 20.5

var _camera_rig: VerticalCameraRig = null
var _current_focus_id: StringName = &""
var _current_interest: float = 0.0
var _current_position: Vector3 = Vector3.ZERO
var _focus_hold_elapsed: float = 0.0
var _cooldown_remaining: float = 0.0
var _no_interest_elapsed: float = 0.0

var _pending_focus_id: StringName = &""
var _pending_interest: float = -INF
var _pending_position: Vector3 = Vector3.ZERO

func bind_camera_rig(rig: VerticalCameraRig) -> void:
	_camera_rig = rig
	if _camera_rig != null and _current_focus_id == &"":
		_camera_rig.set_establishing_view()

func suggest_focus(
	character_id: StringName,
	world_position: Vector3,
	interest_score: float
) -> void:
	if character_id == &"":
		return
	if not _is_finite_vector(world_position):
		return
	if is_nan(interest_score) or is_inf(interest_score):
		return
	if interest_score < min_focus_interest:
		return

	if (
		_pending_focus_id == &""
		or interest_score > _pending_interest
		or (
			is_equal_approx(interest_score, _pending_interest)
			and str(character_id) < str(_pending_focus_id)
		)
	):
		_pending_focus_id = character_id
		_pending_position = world_position
		_pending_interest = interest_score

func tick(delta: float) -> void:
	if is_nan(delta) or is_inf(delta) or delta < 0.0:
		_clear_pending()
		return

	_focus_hold_elapsed += delta
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)

	if _pending_focus_id == &"":
		_no_interest_elapsed += delta
		if (
			_current_focus_id != &""
			and _focus_hold_elapsed >= min_focus_hold_seconds
			and _cooldown_remaining <= 0.0
			and _no_interest_elapsed >= return_to_establishing_after_seconds
		):
			force_establishing()
	else:
		_no_interest_elapsed = 0.0
		if _current_focus_id == &"":
			_activate_pending()
		elif _pending_focus_id == _current_focus_id:
			_current_position = _pending_position
			_current_interest = _pending_interest
		elif (
			_focus_hold_elapsed >= min_focus_hold_seconds
			and _cooldown_remaining <= 0.0
			and _pending_interest >= _current_interest + switch_margin
		):
			_activate_pending()

	if _camera_rig != null and _current_focus_id != &"":
		_camera_rig.focus_world_position(
			_current_position,
			focus_ortho_size
		)

	_clear_pending()

func force_establishing() -> void:
	_current_focus_id = &""
	_current_interest = 0.0
	_current_position = Vector3.ZERO
	_focus_hold_elapsed = 0.0
	_cooldown_remaining = switch_cooldown_seconds
	_no_interest_elapsed = 0.0
	if _camera_rig != null:
		_camera_rig.set_establishing_view()

func current_focus_id() -> StringName:
	return _current_focus_id

func _activate_pending() -> void:
	_current_focus_id = _pending_focus_id
	_current_interest = _pending_interest
	_current_position = _pending_position
	_focus_hold_elapsed = 0.0
	_cooldown_remaining = switch_cooldown_seconds

func _clear_pending() -> void:
	_pending_focus_id = &""
	_pending_interest = -INF
	_pending_position = Vector3.ZERO

func _is_finite_vector(value: Vector3) -> bool:
	return (
		not is_nan(value.x) and not is_inf(value.x)
		and not is_nan(value.y) and not is_inf(value.y)
		and not is_nan(value.z) and not is_inf(value.z)
	)
