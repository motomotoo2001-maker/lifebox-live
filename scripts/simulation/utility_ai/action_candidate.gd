class_name ActionCandidate
extends RefCounted

var id: StringName
var score: float
var smart_object: SmartObject
var interaction: InteractionDefinition

func _init(
	candidate_id: StringName = &"",
	candidate_score: float = 0.0,
	candidate_smart_object: SmartObject = null,
	candidate_interaction: InteractionDefinition = null
) -> void:
	id = candidate_id
	score = candidate_score
	smart_object = candidate_smart_object
	interaction = candidate_interaction

func is_valid_for(character: CharacterState) -> bool:
	if id == &"":
		return false
	if is_nan(score):
		return false
	if smart_object != null:
		if not is_instance_valid(smart_object):
			return false
		if character == null:
			return false
		if not smart_object.is_available_for(character.id):
			return false
	return true
