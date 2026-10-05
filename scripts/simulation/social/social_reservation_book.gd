class_name SocialReservationBook
extends RefCounted

var _sequence: int = 0
var _sessions_by_id: Dictionary = {}
var _session_id_by_resident: Dictionary = {}
var _active_sessions: Array[SocialSession] = []

func reserve(
	initiator_id: StringName,
	target_id: StringName,
	action_id: StringName,
	duration_sim_seconds: float
) -> SocialSession:
	if initiator_id == &"" or target_id == &"" or action_id == &"":
		return null
	if initiator_id == target_id:
		return null
	if (
		is_nan(duration_sim_seconds)
		or is_inf(duration_sim_seconds)
		or duration_sim_seconds <= 0.0
	):
		return null
	if is_reserved(initiator_id) or is_reserved(target_id):
		return null

	_sequence += 1
	var session := SocialSession.new(
		StringName("social_%06d" % _sequence),
		initiator_id,
		target_id,
		action_id,
		duration_sim_seconds
	)

	_sessions_by_id[session.session_id] = session
	_session_id_by_resident[initiator_id] = session.session_id
	_session_id_by_resident[target_id] = session.session_id
	_active_sessions.append(session)
	return session

func is_reserved(resident_id: StringName) -> bool:
	return resident_id != &"" and _session_id_by_resident.has(resident_id)

func get_session_for(resident_id: StringName) -> SocialSession:
	if not is_reserved(resident_id):
		return null

	var session_id: StringName = _session_id_by_resident[resident_id]
	if not _sessions_by_id.has(session_id):
		_session_id_by_resident.erase(resident_id)
		return null

	return _sessions_by_id[session_id] as SocialSession

func active_sessions() -> Array[SocialSession]:
	return _active_sessions.duplicate()

func release(session_id: StringName) -> bool:
	if not _sessions_by_id.has(session_id):
		return false

	var session: SocialSession = _sessions_by_id[session_id]
	_sessions_by_id.erase(session_id)
	_session_id_by_resident.erase(session.initiator_id)
	_session_id_by_resident.erase(session.target_id)
	_active_sessions.erase(session)
	return true

func capture_state() -> Dictionary:
	var sessions: Array = []
	for session in _active_sessions:
		sessions.append(session.capture_persistence_state())
	return {
		"sequence": _sequence,
		"sessions": sessions,
	}

func validate_persistence_state(
	data: Dictionary,
	valid_resident_ids: Dictionary
) -> Array[String]:
	var errors: Array[String] = []

	if not data.has("sequence") or not data["sequence"] is int:
		errors.append("social reservation sequence must be an integer")
		return errors

	var sequence := int(data["sequence"])
	if sequence < 0:
		errors.append("social reservation sequence must be non-negative")

	if not data.has("sessions") or not data["sessions"] is Array:
		errors.append("social reservation sessions must be an Array")
		return errors

	var seen_session_ids: Dictionary = {}
	var seen_residents: Dictionary = {}

	for index in range(data["sessions"].size()):
		var raw_session = data["sessions"][index]
		if not raw_session is Dictionary:
			errors.append("social session[%d] must be a Dictionary" % index)
			continue

		var session_data: Dictionary = raw_session
		for session_error in SocialSession.validate_persistence_state(session_data):
			errors.append("social session[%d]: %s" % [index, session_error])

		if not session_data.has("session_id") or not session_data["session_id"] is String:
			continue
		var session_id: String = session_data["session_id"]
		if seen_session_ids.has(session_id):
			errors.append("duplicate social session id: %s" % session_id)
		seen_session_ids[session_id] = true

		var parsed_sequence := _session_sequence_from_id(session_id)
		if parsed_sequence <= 0 or parsed_sequence > sequence:
			errors.append("social session id exceeds restored sequence: %s" % session_id)

		for id_key in ["initiator_id", "target_id"]:
			if not session_data.has(id_key) or not session_data[id_key] is String:
				continue
			var resident_id: String = session_data[id_key]
			if resident_id.is_empty():
				continue
			if not _resident_exists(valid_resident_ids, resident_id):
				errors.append(
					"social session[%d] %s is not in resident roster"
					% [index, id_key]
				)
			if seen_residents.has(resident_id):
				errors.append(
					"resident appears in multiple active social sessions: %s"
					% resident_id
				)
			seen_residents[resident_id] = true

	return errors

func restore_state(
	data: Dictionary,
	valid_resident_ids: Dictionary
) -> bool:
	if not validate_persistence_state(data, valid_resident_ids).is_empty():
		return false

	var restored_by_id: Dictionary = {}
	var restored_by_resident: Dictionary = {}
	var restored_sessions: Array[SocialSession] = []

	for raw_session in data["sessions"]:
		var session := SocialSession.from_persistence_state(raw_session)
		if session == null:
			return false
		restored_by_id[session.session_id] = session
		restored_by_resident[session.initiator_id] = session.session_id
		restored_by_resident[session.target_id] = session.session_id
		restored_sessions.append(session)

	_sequence = int(data["sequence"])
	_sessions_by_id = restored_by_id
	_session_id_by_resident = restored_by_resident
	_active_sessions = restored_sessions
	return true

func _resident_exists(
	valid_resident_ids: Dictionary,
	resident_id: String
) -> bool:
	if valid_resident_ids.has(resident_id):
		return true
	return valid_resident_ids.has(StringName(resident_id))

func _session_sequence_from_id(session_id: String) -> int:
	if not session_id.begins_with("social_"):
		return -1
	var suffix := session_id.trim_prefix("social_")
	if suffix.is_empty() or not suffix.is_valid_int():
		return -1
	var parsed := int(suffix)
	if session_id != "social_%06d" % parsed:
		return -1
	return parsed
