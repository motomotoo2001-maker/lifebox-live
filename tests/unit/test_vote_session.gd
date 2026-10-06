extends RefCounted

const VOTE_PATH := "res://scripts/simulation/fate/vote_session.gd"

func run() -> Array[String]:
	var failures: Array[String] = []
	if not FileAccess.file_exists(VOTE_PATH):
		failures.append("VoteSession must exist")
		return failures

	var vote_script = load(VOTE_PATH)
	if vote_script == null or not vote_script.can_instantiate():
		failures.append("VoteSession must load")
		return failures

	_test_vote_replacement_and_close(failures, vote_script)
	_test_tie_break(failures, vote_script)
	_test_persistence(failures, vote_script)
	return failures

func _test_vote_replacement_and_close(
	failures: Array[String],
	vote_script
) -> void:
	var vote = vote_script.new(
		&"vote_1",
		&"A",
		"Build",
		&"B",
		"Destroy"
	)
	if not vote.is_valid():
		failures.append("valid vote session must validate")
		return

	if not vote.cast_vote("viewer_1", &"A"):
		failures.append("first vote must be accepted")
	if not vote.cast_vote("viewer_2", &"B"):
		failures.append("second viewer vote must be accepted")
	if not vote.cast_vote("viewer_1", &"B"):
		failures.append("same viewer must be able to replace vote")

	if vote.vote_count() != 2:
		failures.append(
			"vote replacement must not increase unique viewer count"
		)
	if vote.tally(&"A") != 0 or vote.tally(&"B") != 2:
		failures.append("vote replacement must update tallies")
	if vote.cast_vote("", &"A"):
		failures.append("empty viewer key must be rejected")
	if vote.cast_vote("viewer_3", &"C"):
		failures.append("unknown option must be rejected")

	var winner: StringName = vote.close()
	if winner != &"B":
		failures.append("larger tally must win")
	if vote.is_open:
		failures.append("close must freeze vote session")
	if vote.cast_vote("viewer_3", &"A"):
		failures.append("closed session must ignore later votes")
	if vote.close() != &"B":
		failures.append("repeated close must keep same winner")

func _test_tie_break(failures: Array[String], vote_script) -> void:
	var vote = vote_script.new(
		&"vote_tie",
		&"left",
		"Left",
		&"right",
		"Right"
	)
	vote.cast_vote("viewer_1", &"left")
	vote.cast_vote("viewer_2", &"right")
	if vote.close() != &"left":
		failures.append("tie must use lexical option-id winner")

	var empty = vote_script.new(
		&"vote_empty",
		&"B",
		"B",
		&"A",
		"A"
	)
	if empty.close() != &"A":
		failures.append(
			"zero-vote tie must also use lexical option-id winner"
		)

func _test_persistence(failures: Array[String], vote_script) -> void:
	var source = vote_script.new(
		&"persist",
		&"A",
		"Alpha",
		&"B",
		"Beta"
	)
	source.cast_vote("viewer_z", &"B")
	source.cast_vote("viewer_a", &"A")

	var state: Dictionary = source.capture_state()
	var restored = vote_script.new()
	if not restored.restore_state(state):
		failures.append("valid open vote state must restore")
		return
	if restored.capture_state() != state:
		failures.append("open vote state must round-trip exactly")

	source.close()
	state = source.capture_state()
	restored = vote_script.new()
	if not restored.restore_state(state):
		failures.append("valid closed vote state must restore")
		return
	if restored.capture_state() != state:
		failures.append("closed vote state must round-trip exactly")
	if restored.cast_vote("viewer_new", &"A"):
		failures.append("restored closed vote must remain closed")
