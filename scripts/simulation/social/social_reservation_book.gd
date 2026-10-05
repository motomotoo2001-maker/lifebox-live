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
