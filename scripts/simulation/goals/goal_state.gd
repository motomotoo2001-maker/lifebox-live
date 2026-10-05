class_name GoalState
extends RefCounted

const STATUS_ACTIVE: StringName = &"active"
const STATUS_COMPLETED: StringName = &"completed"
const STATUS_FAILED: StringName = &"failed"

var definition: GoalDefinition = null
var progress: float = 0.0
var status: StringName = STATUS_ACTIVE

func _init(new_definition: GoalDefinition = null) -> void:
	definition = new_definition

func set_progress(value: float) -> bool:
	if status != STATUS_ACTIVE:
		return false
	if is_nan(value) or is_inf(value):
		return false

	progress = clampf(value, 0.0, 1.0)
	if progress >= 1.0:
		status = STATUS_COMPLETED
	return true

func complete() -> void:
	progress = 1.0
	status = STATUS_COMPLETED

func fail() -> void:
	status = STATUS_FAILED

func is_active() -> bool:
	return status == STATUS_ACTIVE
