extends RefCounted

const ACTION_PATH := "res://scripts/simulation/social/social_action_definition.gd"
const SESSION_PATH := "res://scripts/simulation/social/social_session.gd"
const BOOK_PATH := "res://scripts/simulation/social/social_reservation_book.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	for path in [ACTION_PATH, SESSION_PATH, BOOK_PATH]:
		if not FileAccess.file_exists(path):
			failures.append("social dependency must exist at %s" % path)
			return failures

	var action_script := load(ACTION_PATH)
	var book_script := load(BOOK_PATH)
	if action_script == null or book_script == null:
		failures.append("social reservation dependencies must load")
		return failures

	var chat = action_script.new()
	chat.id = &"chat"
	chat.duration_sim_seconds = 30.0
	var compliment = action_script.new()
	compliment.id = &"compliment"
	compliment.duration_sim_seconds = 20.0
	var argue = action_script.new()
	argue.id = &"argue"
	argue.duration_sim_seconds = 25.0

	if chat.id != &"chat" or compliment.id != &"compliment" or argue.id != &"argue":
		failures.append("social action definitions must preserve configured ids")

	var book = book_script.new()

	if book.reserve(&"", &"b", &"chat", 10.0) != null:
		failures.append("social reservation must reject empty initiator id")
	if book.reserve(&"a", &"", &"chat", 10.0) != null:
		failures.append("social reservation must reject empty target id")
	if book.reserve(&"a", &"a", &"chat", 10.0) != null:
		failures.append("social reservation must reject self session")
	if book.reserve(&"a", &"b", &"chat", NAN) != null:
		failures.append("social reservation must reject non-finite duration")
	if book.reserve(&"a", &"b", &"chat", 0.0) != null:
		failures.append("social reservation must reject non-positive duration")

	var first = book.reserve(&"a", &"b", &"chat", 30.0)
	if first == null:
		failures.append("first valid social pair must reserve atomically")
		return failures

	if first.session_id != &"social_000001":
		failures.append("first successful social session id must be deterministic")
	if first.initiator_id != &"a" or first.target_id != &"b":
		failures.append("SocialSession must preserve both resident ids")
	if first.action_id != &"chat":
		failures.append("SocialSession must preserve action id")
	if not is_equal_approx(first.remaining_sim_seconds, 30.0):
		failures.append("SocialSession must preserve duration")

	if not book.is_reserved(&"a") or not book.is_reserved(&"b"):
		failures.append("successful pair reservation must lock both residents")
	if book.get_session_for(&"a") != first or book.get_session_for(&"b") != first:
		failures.append("both residents must resolve to the same active session")

	if book.reserve(&"a", &"c", &"compliment", 20.0) != null:
		failures.append("reserved initiator must not join second session")
	if book.reserve(&"c", &"b", &"compliment", 20.0) != null:
		failures.append("reserved target must not join second session")

	var second = book.reserve(&"c", &"d", &"argue", 25.0)
	if second == null:
		failures.append("unrelated pair must reserve concurrently")
	elif second.session_id != &"social_000002":
		failures.append("failed reservations must not consume social session ids")

	var sessions: Array = book.active_sessions()
	if sessions.size() != 2:
		failures.append("reservation book must expose two active sessions")
	sessions.clear()
	if book.active_sessions().size() != 2:
		failures.append("active_sessions() must not expose mutable internal storage")

	if book.release(&"missing") != false:
		failures.append("releasing unknown social session must return false")
	if book.release(first.session_id) != true:
		failures.append("releasing active social session must return true")
	if book.is_reserved(&"a") or book.is_reserved(&"b"):
		failures.append("releasing social session must free both residents")
	if book.get_session_for(&"a") != null or book.get_session_for(&"b") != null:
		failures.append("released residents must have no active session")

	if book.release(second.session_id) != true:
		failures.append("second social session must release successfully")

	var third = book.reserve(&"a", &"c", &"compliment", 20.0)
	if third == null:
		failures.append("released residents must be reservable again")
	elif third.session_id != &"social_000003":
		failures.append("next successful social session id must remain deterministic")

	if third != null:
		book.release(third.session_id)
	if not book.active_sessions().is_empty():
		failures.append("all social reservations must be releasable without stale sessions")

	return failures
