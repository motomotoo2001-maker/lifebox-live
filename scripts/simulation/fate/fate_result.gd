class_name FateResult
extends RefCounted

var applied: bool = false
var definition_id: StringName = &""
var target_resident_ids: Array[StringName] = []
var reason: StringName = &""
var simulation_seconds: float = 0.0

func _init(
	new_applied: bool = false,
	new_definition_id: StringName = &"",
	new_target_resident_ids: Array[StringName] = [],
	new_reason: StringName = &"",
	new_simulation_seconds: float = 0.0
) -> void:
	applied = new_applied
	definition_id = new_definition_id
	target_resident_ids = new_target_resident_ids.duplicate()
	reason = new_reason
	simulation_seconds = new_simulation_seconds
