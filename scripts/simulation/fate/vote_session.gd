class_name VoteSession
extends RefCounted

var session_id: StringName = &""
var option_a_id: StringName = &"A"
var option_a_label: String = ""
var option_b_id: StringName = &"B"
var option_b_label: String = ""
var is_open: bool = true
var winner_id: StringName = &""
var _votes: Dictionary = {}

func _init(
	new_session_id: StringName = &"",
	new_option_a_id: StringName = &"A",
	new_option_a_label: String = "",
	new_option_b_id: StringName = &"B",
	new_option_b_label: String = ""
) -> void:
	session_id = new_session_id
	option_a_id = new_option_a_id
	option_a_label = new_option_a_label
	option_b_id = new_option_b_id
	option_b_label = new_option_b_label

func is_valid() -> bool:
	return (
		session_id != &""
		and option_a_id != &""
		and option_b_id != &""
		and option_a_id != option_b_id
	)

func cast_vote(viewer_key: String, option_id: StringName) -> bool:
	if not is_open or not is_valid():
		return false
	if viewer_key.strip_edges().is_empty():
		return false
	if option_id != option_a_id and option_id != option_b_id:
		return false

	_votes[viewer_key] = option_id
	return true

func vote_count() -> int:
	return _votes.size()

func tally(option_id: StringName) -> int:
	if option_id != option_a_id and option_id != option_b_id:
		return 0
	var count := 0
	for selected in _votes.values():
		if selected == option_id:
			count += 1
	return count

func close() -> StringName:
	if not is_valid():
		return &""
	if not is_open:
		return winner_id

	winner_id = _compute_winner()
	is_open = false
	return winner_id

func capture_state() -> Dictionary:
	var viewer_keys: Array[String] = []
	for raw_key in _votes.keys():
		viewer_keys.append(str(raw_key))
	viewer_keys.sort()

	var votes: Array = []
	for viewer_key in viewer_keys:
		votes.append({
			"viewer_key": viewer_key,
			"option_id": str(_votes[viewer_key]),
		})

	return {
		"session_id": str(session_id),
		"option_a_id": str(option_a_id),
		"option_a_label": option_a_label,
		"option_b_id": str(option_b_id),
		"option_b_label": option_b_label,
		"is_open": is_open,
		"winner_id": str(winner_id),
		"votes": votes,
	}

func restore_state(data: Dictionary) -> bool:
	for key in [
		"session_id",
		"option_a_id",
		"option_a_label",
		"option_b_id",
		"option_b_label",
		"is_open",
		"winner_id",
		"votes",
	]:
		if not data.has(key):
			return false

	if not data["session_id"] is String or data["session_id"].is_empty():
		return false
	if not data["option_a_id"] is String or data["option_a_id"].is_empty():
		return false
	if not data["option_b_id"] is String or data["option_b_id"].is_empty():
		return false
	if data["option_a_id"] == data["option_b_id"]:
		return false
	if (
		not data["option_a_label"] is String
		or not data["option_b_label"] is String
	):
		return false
	if not data["is_open"] is bool:
		return false
	if not data["winner_id"] is String:
		return false
	if not data["votes"] is Array:
		return false

	var restored_votes: Dictionary = {}
	for raw_vote in data["votes"]:
		if not raw_vote is Dictionary:
			return false
		if (
			not raw_vote.has("viewer_key")
			or not raw_vote["viewer_key"] is String
			or raw_vote["viewer_key"].strip_edges().is_empty()
		):
			return false
		if (
			not raw_vote.has("option_id")
			or not raw_vote["option_id"] is String
		):
			return false

		var selected := StringName(raw_vote["option_id"])
		if (
			selected != StringName(data["option_a_id"])
			and selected != StringName(data["option_b_id"])
		):
			return false

		var viewer_key: String = raw_vote["viewer_key"]
		if restored_votes.has(viewer_key):
			return false
		restored_votes[viewer_key] = selected

	var restored_winner := StringName(data["winner_id"])
	if data["is_open"]:
		if restored_winner != &"":
			return false
	elif (
		restored_winner != StringName(data["option_a_id"])
		and restored_winner != StringName(data["option_b_id"])
	):
		return false

	session_id = StringName(data["session_id"])
	option_a_id = StringName(data["option_a_id"])
	option_a_label = data["option_a_label"]
	option_b_id = StringName(data["option_b_id"])
	option_b_label = data["option_b_label"]
	is_open = data["is_open"]
	winner_id = restored_winner
	_votes = restored_votes

	if not is_open:
		var expected_winner := _compute_winner()
		if winner_id != expected_winner:
			return false
	return true

func _compute_winner() -> StringName:
	var a_count := tally(option_a_id)
	var b_count := tally(option_b_id)
	if a_count > b_count:
		return option_a_id
	if b_count > a_count:
		return option_b_id
	return (
		option_a_id
		if str(option_a_id) < str(option_b_id)
		else option_b_id
	)
