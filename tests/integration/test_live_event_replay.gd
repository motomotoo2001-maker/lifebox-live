extends RefCounted

const WORLD_PATH := "res://scripts/simulation/simulation_world.gd"
const CHARACTER_PATH := "res://scripts/simulation/characters/character_state.gd"
const FATE_DEFINITION_PATH := "res://scripts/simulation/fate/fate_definition.gd"
const MOCK_BRIDGE_PATH := "res://scripts/integrations/live/mock_live_bridge.gd"
const VOTE_SESSION_PATH := "res://scripts/simulation/fate/vote_session.gd"
const SNAPSHOT_PATH := "res://scripts/persistence/world_snapshot_codec.gd"
const REPLAY_LOG_PATH := "res://scripts/replay/replay_log.gd"
const REPLAY_PLAYER_PATH := "res://scripts/replay/replay_player.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	var world_script = load(WORLD_PATH)
	var character_script = load(CHARACTER_PATH)
	var fate_definition_script = load(FATE_DEFINITION_PATH)
	var bridge_script = load(MOCK_BRIDGE_PATH)
	var vote_session_script = load(VOTE_SESSION_PATH)
	var snapshot_script = load(SNAPSHOT_PATH)
	var replay_log_script = load(REPLAY_LOG_PATH)
	var replay_player_script = load(REPLAY_PLAYER_PATH)

	for script in [
		world_script,
		character_script,
		fate_definition_script,
		bridge_script,
		vote_session_script,
		snapshot_script,
		replay_log_script,
		replay_player_script,
	]:
		if script == null or not script.can_instantiate():
			failures.append("LIVE replay dependencies must load and instantiate")
			return failures

	var control = _build_world(
		world_script,
		character_script,
		fate_definition_script,
		vote_session_script
	)
	var initial_snapshot: Dictionary = snapshot_script.encode(control)
	var log = replay_log_script.new()
	var bridge = bridge_script.new("replay_live")

	var gift = bridge.gift(0.0, "viewer_gift", "Replay Gift", 50, 1)
	var comment = bridge.comment(0.0, "viewer_vote", "!B")
	var like = bridge.like_batch(0.0, "viewer_like", 100)

	for event in [gift, comment, like]:
		if not log.append(&"live_event", {"event":event.encode()}):
			failures.append("ReplayLog must accept normalized live_event input")
			return failures
		if control.enqueue_live_event(event) != LiveEventQueue.RESULT_ACCEPTED:
			failures.append("control LIVE replay event must enqueue")
			return failures

	if not log.append(&"advance", {"real_delta":1.0}):
		failures.append("LIVE replay advance event must append")
		return failures
	control.step(1.0)

	if not log.append(&"live_event", {"event":gift.encode()}):
		failures.append("ReplayLog must permit duplicate normalized event input")
		return failures
	var duplicate_result: StringName = control.enqueue_live_event(gift)
	if duplicate_result != LiveEventQueue.RESULT_DUPLICATE:
		failures.append("control duplicate gift must be acknowledged as duplicate")

	var follow = bridge.follow(1.0, "viewer_follow")
	if not log.append(&"live_event", {"event":follow.encode()}):
		failures.append("ReplayLog must accept follow live_event")
		return failures
	if control.enqueue_live_event(follow) != LiveEventQueue.RESULT_ACCEPTED:
		failures.append("control follow event must enqueue")
		return failures

	if not log.append(&"advance", {"real_delta":1.0}):
		failures.append("second LIVE replay advance must append")
		return failures
	control.step(1.0)

	var expected_final: Dictionary = snapshot_script.encode(control)

	var target = _build_world(
		world_script,
		character_script,
		fate_definition_script,
		vote_session_script,
		false
	)
	var replay_errors: Array[String] = replay_player_script.replay(
		target,
		initial_snapshot,
		log.events()
	)
	if not replay_errors.is_empty():
		failures.append("normalized LIVE replay must succeed: %s" % " | ".join(replay_errors))
		return failures

	var replay_final: Dictionary = snapshot_script.encode(target)
	if replay_final != expected_final:
		failures.append("normalized LIVE replay must reach exact control snapshot")

	var target_vote = target.live_interaction_system.active_vote_session()
	if target_vote == null or target_vote.tally(&"B") != 1:
		failures.append("LIVE replay must reproduce comment vote state")

	return failures

func _build_world(
	world_script,
	character_script,
	fate_definition_script,
	vote_session_script,
	with_resident: bool = true
):
	var world = world_script.new()
	_register_fate(world, fate_definition_script)

	if with_resident:
		var resident = character_script.new(&"resident_replay", "Resident Replay")
		resident.money = 20.0
		world.add_character(resident)

	var session = vote_session_script.new(
		&"replay_vote",
		&"A",
		"Option A",
		&"B",
		"Option B"
	)
	world.live_interaction_system.start_vote_session(session)
	return world

func _register_fate(world, fate_definition_script) -> void:
	var definition = fate_definition_script.new()
	definition.id = &"replay_cash"
	definition.category = &"gift"
	definition.rarity = &"common"
	definition.minimum_tier = &"micro"
	definition.maximum_tier = &"legendary"
	definition.weight = 1.0
	definition.cooldown_sim_seconds = 30.0
	definition.target_mode = &"random_resident"
	definition.effects = [
		{"kind":"money_delta", "delta":7.0},
	]
	world.live_interaction_system.fate_engine.register_definition(definition)
