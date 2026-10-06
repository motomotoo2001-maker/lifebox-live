class_name CharacterState
extends RefCounted

const NeedProfileScript = preload("res://scripts/simulation/needs/need_profile.gd")
const PersonalityStateScript = preload("res://scripts/simulation/characters/personality_state.gd")
const MovementStateScript = preload("res://scripts/simulation/movement/movement_state.gd")
const MemoryStoreScript = preload("res://scripts/simulation/memory/memory_store.gd")
const JobStateScript = preload("res://scripts/simulation/economy/job_state.gd")
const DailyScheduleStateScript = preload("res://scripts/simulation/schedules/daily_schedule_state.gd")
const GoalSetScript = preload("res://scripts/simulation/goals/goal_set.gd")

var id: StringName
var display_name: String
var needs
var personality
var movement
var memory
var job
var schedule
var goals
var money: float = 0.0
var current_action_id: StringName = &"idle"

func _init(character_id: StringName = &"", character_display_name: String = "") -> void:
	id = character_id
	display_name = character_display_name
	needs = NeedProfileScript.new()
	personality = PersonalityStateScript.new()
	movement = MovementStateScript.new()
	memory = MemoryStoreScript.new()
	job = JobStateScript.new()
	schedule = DailyScheduleStateScript.new()
	goals = GoalSetScript.new()
