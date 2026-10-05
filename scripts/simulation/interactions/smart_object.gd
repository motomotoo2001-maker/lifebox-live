class_name SmartObject
extends Node

@export var object_id: StringName = &""
@export var interaction_point: Vector3 = Vector3.ZERO
@export var interactions: Array[InteractionDefinition] = []

var _reserved_by: StringName = &""

func list_interactions(_character: CharacterState) -> Array[InteractionDefinition]:
	return interactions.duplicate()

func reserve(character_id: StringName) -> bool:
	if character_id == &"":
		return false
	if _reserved_by == &"" or _reserved_by == character_id:
		_reserved_by = character_id
		return true
	return false

func release(character_id: StringName) -> void:
	if _reserved_by == character_id:
		_reserved_by = &""

func clear_reservation() -> void:
	_reserved_by = &""

func is_available_for(character_id: StringName) -> bool:
	return _reserved_by == &"" or _reserved_by == character_id

func _exit_tree() -> void:
	clear_reservation()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		clear_reservation()
