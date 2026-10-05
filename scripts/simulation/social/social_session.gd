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

func capture_persistence_state() -> Dictionary:
	return {
		"session_id": str(session_id),
		"initiator_id": str(initiator_id),
		"target_id": str(target_id),
		"action_id": str(action_id),
		"remaining_sim_seconds": remaining_sim_seconds,
	}

static func from_persistence_state(data: Dictionary) -> SocialSession:
	if not _has_basic_fields(data):
		return null
	return SocialSession.new(
		StringName(data["session_id"]),
		StringName(data["initiator_id"]),
		StringName(data["target_id"]),
		StringName(data["action_id"]),
		float(data["remaining_sim_seconds"])
	)

static func validate_persistence_state(
	data: Dictionary,
	allow_zero_remaining: bool = false
) -> Array[String]:
	var errors: Array[String] = []

	for key in ["session_id", "initiator_id", "target_id", "action_id"]:
		if not data.has(key) or not data[key] is String or data[key].is_empty():
			errors.append("%s must be a non-empty string" % key)

	if (
		data.has("initiator_id")
		and data.has("target_id")
		and data["initiator_id"] is String
		and data["target_id"] is String
		and not data["initiator_id"].is_empty()
		and data["initiator_id"] == data["target_id"]
	):
		errors.append("social session must not target itself")

	if (
		not data.has("remaining_sim_seconds")
		or not _is_finite_number(data["remaining_sim_seconds"])
	):
		errors.append("remaining_sim_seconds must be finite")
	else:
		var remaining := float(data["remaining_sim_seconds"])
		if allow_zero_remaining:
			if remaining < 0.0:
				errors.append("remaining_sim_seconds must be non-negative")
		elif remaining <= 0.0:
			errors.append("remaining_sim_seconds must be positive")

	return errors

static func _has_basic_fields(data: Dictionary) -> bool:
	return validate_persistence_state(data, true).is_empty()

static func _is_finite_number(value) -> bool:
	if not (value is int or value is float):
		return false
	var number := float(value)
	return not is_nan(number) and not is_inf(number)
