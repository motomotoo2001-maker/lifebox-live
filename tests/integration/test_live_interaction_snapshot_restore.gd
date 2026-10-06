extends RefCounted

const WORLD_PATH := "res://scripts/simulation/simulation_world.gd"
const CHARACTER_PATH := "res://scripts/simulation/characters/character_state.gd"
const FATE_DEFINITION_PATH := "res://scripts/simulation/fate/fate_definition.gd"
const MOCK_BRIDGE_PATH := "res://scripts/integrations/live/mock_live_bridge.gd"
const VOTE_SESSION_PATH := "res://scripts/simulation/fate/vote_session.gd"
const SNAPSHOT_PATH := "res://scripts/persistence/world_snapshot_codec.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	var world_script = load(WORLD_PATH)
	var character_script = load(CHARACTER_PATH)
	var fate_definition_script = load(FATE_DEFINITION_PATH)
	var bridge_script = load(MOCK_BRIDGE_PATH)
	var vote_session_script = load(VOTE_SESSION_PATH)
	var snapshot_script = load(SNAPSHOT_PATH)
	for script in [
		world_script,
		character_script,
		fate_definition_script,
		bridge_script,
		vote_session_script,
		snapshot_script,
	]:
		if script == null or not script.can_instantiate():
			failures.append("LIVE snapshot dependencies must load and instantiate")
			return failures

	var source = _build_world(
		world_script,
		character_script,
		fate_definition_script,
		true
	)
	if source == null:
		failures.append("source LIVE snapshot world must build")
		return failures

	var source_world = source
	var session = vote_session_script.new(
		&"snapshot_vote",
		&"A",
		"Option A",
		&"B",
		"Option B"
	)
	if not source_world.live_interaction_system.start_vote_session(session):
		failures.append("snapshot vote session must start")
		return failures

	var bridge = bridge_script.new("snapshot")
	var events: Array = [
		bridge.gift(0.0, "gift_viewer", "Small Gift", 10, 1),
		bridge.comment(0.0, "vote_viewer", "!A"),
	]
	for index in range(8):
		events.append(
			bridge.like_batch(0.0, "like_%d" % index, 25)
		)

	for event in events:
		if source_world.enqueue_live_event(event) != LiveEventQueue.RESULT_ACCEPTED:
			failures.append("snapshot LIVE fixture event must enqueue")
			return failures

	source_world.step(1.0)

	if source_world.live_interaction_system.pending_count() != 2:
		failures.append("snapshot fixture must retain two queued LIVE events")
	if source_world.live_interaction_system.processed_ledger.size() != 8:
		failures.append("snapshot fixture must contain eight processed ids")
	if source_world.live_interaction_system.active_vote_session().tally(&"A") != 1:
		failures.append("snapshot vote state must contain processed comment")

	var snapshot: Dictionary = snapshot_script.encode(source_world)
	if not snapshot.has("live_interaction"):
		failures.append("world snapshot must include optional live_interaction state")
		return failures

	var target = _build_world(
		world_script,
		character_script,
		fate_definition_script,
		false
	)
	var restore_errors: Array[String] = snapshot_script.restore(target, snapshot)
	if not restore_errors.is_empty():
		failures.append("valid LIVE snapshot must restore: %s" % " | ".join(restore_errors))
		return failures

	if snapshot_script.encode(target) != snapshot:
		failures.append("restored LIVE world must exactly re-encode captured snapshot")

	source_world.step(1.0)
	target.step(1.0)

	var source_final: Dictionary = snapshot_script.encode(source_world)
	var target_final: Dictionary = snapshot_script.encode(target)
	if target_final != source_final:
		failures.append("restored LIVE world must continue exactly like source")

	if target.live_interaction_system.pending_count() != 0:
		failures.append("restored LIVE queue must drain remaining events")
	if target.live_interaction_system.processed_ledger.size() != 10:
		failures.append("restored dedup ledger must continue from captured state")

	var legacy := snapshot.duplicate(true)
	legacy.erase("live_interaction")
	var legacy_target = _build_world(
		world_script,
		character_script,
		fate_definition_script,
		false
	)
	var legacy_errors: Array[String] = snapshot_script.restore(
		legacy_target,
		legacy
	)
	if not legacy_errors.is_empty():
		failures.append("Plan 05 snapshot without LIVE state must remain readable")
	else:
		if legacy_target.live_interaction_system.pending_count() != 0:
			failures.append("legacy snapshot must restore empty LIVE queue")
		if legacy_target.live_interaction_system.processed_ledger.size() != 0:
			failures.append("legacy snapshot must restore empty LIVE ledger")
		if not is_equal_approx(legacy_target.live_interaction_system.chaos.value, 0.0):
			failures.append("legacy snapshot must restore zero Chaos")
		if legacy_target.live_interaction_system.active_vote_session() != null:
			failures.append("legacy snapshot must restore no active vote")

	return failures

func _build_world(
	world_script,
	character_script,
	fate_definition_script,
	with_resident: bool
):
	var world = world_script.new()
	_register_fate(world, fate_definition_script)

	if with_resident:
		var resident = character_script.new(&"resident_live", "Resident Live")
		resident.money = 10.0
		if not world.add_character(resident):
			return null

	return world

func _register_fate(world, fate_definition_script) -> void:
	var definition = fate_definition_script.new()
	definition.id = &"persist_cash"
	definition.category = &"gift"
	definition.rarity = &"common"
	definition.minimum_tier = &"micro"
	definition.maximum_tier = &"legendary"
	definition.weight = 1.0
	definition.cooldown_sim_seconds = 120.0
	definition.target_mode = &"random_resident"
	definition.effects = [
		{"kind":"money_delta", "delta":5.0},
		{"kind":"chaos_delta", "delta":1.0},
	]
	world.live_interaction_system.fate_engine.register_definition(definition)
