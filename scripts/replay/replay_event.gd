class_name ReplayEvent
extends RefCounted

var sequence: int
var kind: StringName
var payload: Dictionary

func _init(
	new_sequence: int = 0,
	new_kind: StringName = &"",
	new_payload: Dictionary = {}
) -> void:
	sequence = new_sequence
	kind = new_kind
	payload = new_payload.duplicate(true)
