class_name EconomyTransaction
extends RefCounted

var transaction_id: StringName
var kind: StringName
var from_resident_id: StringName
var to_resident_id: StringName
var amount: float
var simulation_seconds: float

func _init(
	new_transaction_id: StringName = &"",
	new_kind: StringName = &"",
	new_from_resident_id: StringName = &"",
	new_to_resident_id: StringName = &"",
	new_amount: float = 0.0,
	new_simulation_seconds: float = 0.0
) -> void:
	transaction_id = new_transaction_id
	kind = new_kind
	from_resident_id = new_from_resident_id
	to_resident_id = new_to_resident_id
	amount = _sanitize_non_negative(new_amount)
	simulation_seconds = _sanitize_non_negative(new_simulation_seconds)

func _sanitize_non_negative(value: float) -> float:
	if is_nan(value) or is_inf(value):
		return 0.0
	return maxf(value, 0.0)
