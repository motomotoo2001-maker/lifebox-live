class_name CharacterState
extends RefCounted

const NeedProfileScript = preload("res://scripts/simulation/needs/need_profile.gd")
const PersonalityStateScript = preload("res://scripts/simulation/characters/personality_state.gd")

var id: StringName
var display_name: String
var needs
var personality
var money: float = 0.0
var current_action_id: StringName = &"idle"

func _init(character_id: StringName = &"", character_display_name: String = "") -> void:
	id = character_id
	display_name = character_display_name
	needs = NeedProfileScript.new()
	personality = PersonalityStateScript.new()
