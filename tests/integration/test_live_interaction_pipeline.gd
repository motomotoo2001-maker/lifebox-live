extends RefCounted

const SYSTEM_PATH := "res://scripts/integrations/live/live_interaction_system.gd"
const WORLD_PATH := "res://scripts/simulation/simulation_world.gd"
const CHARACTER_PATH := "res://scripts/simulation/characters/character_state.gd"
const FATE_DEFINITION_PATH := "res://scripts/simulation/fate/fate_definition.gd"
const MOCK_BRIDGE_PATH := "res://scripts/integrations/live/mock_live_bridge.gd"
const VOTE_SESSION_PATH := "res://scripts/simulation/fate/vote_session.gd"
const LIVE_EVENT_PATH := "res://scripts/integrations/live/live_event.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	if not FileAccess.file_exists(SYSTEM_PATH):
		failures.append("LiveInteractionSystem must exist at %s" % SYSTEM_PATH)
		return failures

	var system_script = load(SYSTEM_PATH)
	var world_script = load(WORLD_PATH)
	var character_script = load(CHARACTER_PATH)
	var fate_definition_script = load(FATE_DEFINITION_PATH)
	var bridge_script = load(MOCK_BRIDGE_PATH)
	var vote_session_script = load(VOTE_SESSION_PATH)
	var live_event_script = load(LIVE_EVENT_PATH)
	for script in [
		system_script,
		world_script,
		character_script,
		fate_definition_script,
		bridge_script,
		vote_session_script,
		live_event_script,
	]:
		if script == null or not script.can_instantiate():
			failures.append("LIVE interaction pipeline dependencies must load and instantiate")
			return failures

	_test_processing_budget_and_dedup(
		failures,
		world_script,
		bridge_script
	)
	_test_gift_to_fate(
		failures,
		world_script,
		character_script,
		fate_definition_script,
		bridge_script
	)
	_test_comment_vote(
		failures,
		world_script,
		bridge_script,
		vote_session_script
	)
	_test_invalid_does_not_block(
		failures,
		world_script,
		bridge_script,
		live_event_script
	)
	_test_live_rng_isolated_from_core_rng(
		failures,
		world_script,
		bridge_script
	)

	return failures

func _test_processing_budget_and_dedup(
	failures: Array[String],
	world_script,
	bridge_script
) -> void:
	var world = world_script.new()
	var bridge = bridge_script.new("budget")
	var first_event = null

	for index in range(10):
		var event = bridge.like_batch(0.0, "viewer_%d" % index, 100)
		if event == null:
			failures.append("budget like event must be created")
			return
		if first_event == null:
			first_event = event
		var result: StringName = world.enqueue_live_event(event)
		if result != LiveEventQueue.RESULT_ACCEPTED:
			failures.append("valid like event must enter LIVE queue")
			return

	world.step(1.0)

	if world.live_interaction_system.pending_count() != 2:
		failures.append("LIVE system must process at most 8 events per fixed step")
	if world.live_interaction_system.processed_ledger.size() != 8:
		failures.append("first LIVE step must record exactly 8 processed event ids")
	if not is_equal_approx(world.live_interaction_system.chaos.value, 8.0):
		failures.append("eight 100-like batches must add exactly 8 chaos")

	world.step(1.0)

	if world.live_interaction_system.pending_count() != 0:
		failures.append("second LIVE step must drain remaining two events")
	if world.live_interaction_system.processed_ledger.size() != 10:
		failures.append("all ten LIVE event ids must be recorded")
	if not is_equal_approx(world.live_interaction_system.chaos.value, 10.0):
		failures.append("ten 100-like batches must add exactly 10 chaos")

	var before_chaos: float = world.live_interaction_system.chaos.value
	var duplicate_result: StringName = world.enqueue_live_event(first_event)
	if duplicate_result != LiveEventQueue.RESULT_DUPLICATE:
		failures.append("already processed event id must be rejected as duplicate")

	world.step(1.0)
	if not is_equal_approx(world.live_interaction_system.chaos.value, before_chaos):
		failures.append("duplicate event must never reapply chaos")

func _test_gift_to_fate(
	failures: Array[String],
	world_script,
	character_script,
	fate_definition_script,
	bridge_script
) -> void:
	var world = world_script.new()
	var resident = character_script.new(&"gift_target", "Gift Target")
	resident.money = 0.0
	if not world.add_character(resident):
		failures.append("gift target resident must enter world")
		return

	var definition = fate_definition_script.new()
	definition.id = &"viewer_cash"
	definition.category = &"gift"
	definition.rarity = &"common"
	definition.minimum_tier = &"micro"
	definition.maximum_tier = &"legendary"
	definition.weight = 1.0
	definition.cooldown_sim_seconds = 0.0
	definition.target_mode = &"random_resident"
	definition.effects = [
		{"kind":"money_delta", "delta":20.0},
		{"kind":"chaos_delta", "delta":2.0},
	]
	if not world.live_interaction_system.fate_engine.register_definition(definition):
		failures.append("gift Fate definition must register")
		return

	var bridge = bridge_script.new("gift")
	var gift = bridge.gift(0.0, "viewer_gift", "Test Gift", 10, 1)
	if gift == null:
		failures.append("valid mock gift must be created")
		return
	if world.enqueue_live_event(gift) != LiveEventQueue.RESULT_ACCEPTED:
		failures.append("valid gift must enter LIVE queue")
		return

	world.step(1.0)

	if not is_equal_approx(resident.money, 20.0):
		failures.append("gift Fate must apply money effect to resident")
	if not is_equal_approx(world.live_interaction_system.chaos.value, 2.0):
		failures.append("gift Fate must apply chaos effect")

	var results: Array = world.live_interaction_system.take_fate_results()
	if results.size() != 1:
		failures.append("gift processing must expose one FateResult")
	else:
		if not results[0].applied:
			failures.append("gift FateResult must be applied")
		if results[0].definition_id != &"viewer_cash":
			failures.append("gift FateResult must expose selected definition id")

	if not world.live_interaction_system.take_fate_results().is_empty():
		failures.append("FateResult buffer must drain exactly once")

func _test_comment_vote(
	failures: Array[String],
	world_script,
	bridge_script,
	vote_session_script
) -> void:
	var world = world_script.new()
	var session = vote_session_script.new(
		&"vote_1",
		&"A",
		"Option A",
		&"B",
		"Option B"
	)
	if not world.live_interaction_system.start_vote_session(session):
		failures.append("valid VoteSession must start")
		return

	var bridge = bridge_script.new("vote")
	var events := [
		bridge.comment(0.0, "viewer_1", "!A"),
		bridge.comment(0.0, "viewer_1", "!B"),
		bridge.comment(0.0, "viewer_2", "  !a  "),
	]
	for event in events:
		if world.enqueue_live_event(event) != LiveEventQueue.RESULT_ACCEPTED:
			failures.append("valid vote comment must enter LIVE queue")
			return

	world.step(1.0)

	var active = world.live_interaction_system.active_vote_session()
	if active == null:
		failures.append("vote session must remain available before close")
		return
	if active.vote_count() != 2:
		failures.append("one viewer changing vote must still count as one effective vote")
	if active.tally(&"A") != 1 or active.tally(&"B") != 1:
		failures.append("comment commands must produce deterministic A/B tally")

	var winner: StringName = world.live_interaction_system.close_vote_session()
	if winner != &"A":
		failures.append("tied A/B vote must use lexical option-id tie-break")
	if active.is_open:
		failures.append("close_vote_session() must close active vote")

func _test_invalid_does_not_block(
	failures: Array[String],
	world_script,
	bridge_script,
	live_event_script
) -> void:
	var world = world_script.new()

	var invalid = live_event_script.new(
		&"bad_comment",
		LiveEvent.KIND_COMMENT,
		0.0,
		"viewer_bad",
		{"text":""}
	)
	if world.enqueue_live_event(invalid) != LiveEventQueue.RESULT_INVALID:
		failures.append("malformed LIVE event must fail closed")

	var bridge = bridge_script.new("valid_after_bad")
	var like = bridge.like_batch(0.0, "viewer_like", 50)
	var follow = bridge.follow(0.0, "viewer_follow")
	var share = bridge.share(0.0, "viewer_share")
	for event in [like, follow, share]:
		if world.enqueue_live_event(event) != LiveEventQueue.RESULT_ACCEPTED:
			failures.append("valid event after malformed input must still enqueue")
			return

	world.step(1.0)

	if not is_equal_approx(world.live_interaction_system.chaos.value, 0.5):
		failures.append("valid like after malformed event must still apply")
	if world.live_interaction_system.processed_ledger.size() != 3:
		failures.append("follow/share no-op hooks must still be acknowledged exactly once")

func _test_live_rng_isolated_from_core_rng(
	failures: Array[String],
	world_script,
	bridge_script
) -> void:
	var control = world_script.new()
	var with_live = world_script.new()
	var bridge = bridge_script.new("rng")

	for event in [
		bridge.like_batch(0.0, "viewer_1", 100),
		bridge.follow(0.0, "viewer_2"),
		bridge.share(0.0, "viewer_3"),
	]:
		if with_live.enqueue_live_event(event) != LiveEventQueue.RESULT_ACCEPTED:
			failures.append("RNG isolation LIVE fixture must enqueue")
			return

	control.step(1.0)
	with_live.step(1.0)

	var control_rng: Dictionary = control.capture_persistence_state()["rng"]
	var live_rng: Dictionary = with_live.capture_persistence_state()["rng"]
	if live_rng != control_rng:
		failures.append("LIVE event processing must not perturb core UtilityAI RNG")
