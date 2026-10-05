class_name HouseholdState
extends RefCounted

var _residents_by_id: Dictionary = {}
var _resident_order: Array[CharacterState] = []

func add_resident(character: CharacterState) -> bool:
	if character == null or character.id == &"":
		return false
	if _residents_by_id.has(character.id):
		return false

	_residents_by_id[character.id] = character
	_resident_order.append(character)
	return true

func remove_resident(character_id: StringName) -> bool:
	if not _residents_by_id.has(character_id):
		return false

	var resident: CharacterState = _residents_by_id[character_id]
	_residents_by_id.erase(character_id)
	_resident_order.erase(resident)
	return true

func get_resident(character_id: StringName) -> CharacterState:
	return _residents_by_id.get(character_id)

func residents() -> Array[CharacterState]:
	return _resident_order.duplicate()
