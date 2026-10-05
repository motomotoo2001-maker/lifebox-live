class_name SocialSession
extends RefCounted

var session_id: StringName
var initiator_id: StringName
var target_id: StringName
var action_id: StringName
var remaining_sim_seconds: float

func _init(
	new_session_id: StringName = &"",
	new_initiator_id: StringName = &"",
	new_target_id: StringName = &"",
	new_action_id: StringName = &"",
	duration_sim_seconds: float = 0.0
) -> void:
	session_id = new_session_id
	initiator_id = new_initiator_id
	target_id = new_target_id
	action_id = new_action_id
	if is_nan(duration_sim_seconds) or is_inf(duration_sim_seconds):
		remaining_sim_seconds = 0.0
	else:
		remaining_sim_seconds = maxf(duration_sim_seconds, 0.0)
