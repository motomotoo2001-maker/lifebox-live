extends RefCounted

const SOCIAL_SYSTEM_PATH := "res://scripts/simulation/social/social_system.gd"
const SOCIAL_ACTION_PATH := "res://scripts/simulation/social/social_action_definition.gd"
const RELATIONSHIP_GRAPH_PATH := "res://scripts/simulation/relationships/relationship_graph.gd"
const CHARACTER_PATH := "res://scripts/simulation/characters/character_state.gd"
const WORLD_PATH := "res://scripts/simulation/simulation_world.gd"
const INTERACTION_PATH := "res://scripts/simulation/interactions/interaction_definition.gd"
const SMART_OBJECT_PATH := "res://scripts/simulation/interactions/smart_object.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	if not FileAccess.file_exists(SOCIAL_SYSTEM_PATH):
		failures.append("SocialSystem must exist at %s" % SOCIAL_SYSTEM_PATH)
		return failures

	var social_system_script := load(SOCIAL_SYSTEM_PATH)
	var action_script := load(SOCIAL_ACTION_PATH)
	var relationship_script := load(RELATIONSHIP_GRAPH_PATH)
	var character_script := load(CHARACTER_PATH)
	var world_script := load(WORLD_PATH)
	var interaction_script := load(INTERACTION_PATH)
	var smart_object_script := load(SMART_OBJECT_PATH)
	if (
		social_system_script == null
		or action_script == null
		or relationship_script == null
		or character_script == null
		or world_script == null
		or interaction_script == null
		or smart_object_script == null
	):
		failures.append("autonomous social dependencies must load")
		return failures

	_test_deterministic_pair_choice(
		failures,
		social_system_script,
		action_script,
		relationship_script,
		character_script
	)
	_test_world_does_not_interrupt_object_action(
		failures,
		world_script,
		character_script,
		interaction_script,
		smart_object_script
	)

	return failures

func _test_deterministic_pair_choice(
	failures: Array[String],
	social_system_script,
	action_script,
	relationship_script,
	character_script
) -> void:
	var first := _build_social_case(
		social_system_script,
		action_script,
		relationship_script,
		character_script
	)
	var second := _build_social_case(
		social_system_script,
		action_script,
		relationship_script,
		character_script
	)

	first["system"].advance(first["residents"], first["relationships"], 1.0, first["rng"])
	second["system"].advance(second["residents"], second["relationships"], 1.0, second["rng"])

	var first_sessions: Array = first["system"].active_sessions()
	var second_sessions: Array = second["system"].active_sessions()
	if first_sessions.size() != 1 or second_sessions.size() != 1:
		failures.append("same-seed social systems must start exactly one session")
		return

	var a = first_sessions[0]
	var b = second_sessions[0]
	if (
		a.initiator_id != b.initiator_id
		or a.target_id != b.target_id
		or a.action_id != b.action_id
	):
		failures.append("same seed and same state must choose identical social pair/action")

	if a.initiator_id != &"resident_a" or a.target_id != &"resident_b":
		failures.append("highest-scoring eligible relationship must choose resident_a -> resident_b")
	if a.action_id != &"compliment":
		failures.append("positive relationship + kind initiator must prefer compliment")

	var first_residents: Array = first["residents"]
	for resident in first_residents:
		if resident.id == &"resident_busy":
			if first["system"].reservation_book.is_reserved(resident.id):
				failures.append("busy resident must never be socially reserved")
			if resident.current_action_id != &"eat":
				failures.append("social system must not change pre-existing busy action")

	if not first["system"].reservation_book.is_reserved(&"resident_a"):
		failures.append("social initiator must be reserved during active session")
	if not first["system"].reservation_book.is_reserved(&"resident_b"):
		failures.append("social target must be reserved during active session")

	first["system"].advance(first_residents, first["relationships"], 30.0, first["rng"])
	if not first["system"].active_sessions().is_empty():
		failures.append("completed social session must release itself")
	if first["system"].reservation_book.is_reserved(&"resident_a"):
		failures.append("completed social session must release initiator")
	if first["system"].reservation_book.is_reserved(&"resident_b"):
		failures.append("completed social session must release target")

	for resident in first_residents:
		if resident.id == &"resident_a" or resident.id == &"resident_b":
			if resident.current_action_id != &"idle":
				failures.append("completed social participants must return to idle")

func _build_social_case(
	social_system_script,
	action_script,
	relationship_script,
	character_script
) -> Dictionary:
	var system = social_system_script.new()
	var chat = action_script.new()
	chat.id = &"chat"
	chat.duration_sim_seconds = 20.0
	var compliment = action_script.new()
	compliment.id = &"compliment"
	compliment.duration_sim_seconds = 20.0
	var argue = action_script.new()
	argue.id = &"argue"
	argue.duration_sim_seconds = 20.0
	system.register_action(chat)
	system.register_action(compliment)
	system.register_action(argue)

	var resident_a = character_script.new(&"resident_a", "A")
	resident_a.needs.social.value = 5.0
	resident_a.personality.sociability = 1.0
	resident_a.personality.kindness = 1.0
	resident_a.personality.impulsiveness = 0.0

	var resident_b = character_script.new(&"resident_b", "B")
	resident_b.needs.social.value = 5.0
	resident_b.personality.sociability = 0.8
	resident_b.personality.kindness = 0.8

	var resident_c = character_script.new(&"resident_c", "C")
	resident_c.needs.social.value = 95.0
	resident_c.personality.sociability = 0.2

	var busy = character_script.new(&"resident_busy", "Busy")
	busy.needs.social.value = 0.0
	busy.current_action_id = &"eat"

	var relationships = relationship_script.new()
	relationships.get_or_create(&"resident_a", &"resident_b").apply_delta(80.0, 70.0, -20.0)
	relationships.get_or_create(&"resident_b", &"resident_a").apply_delta(40.0, 40.0, 0.0)

	var rng := RandomNumberGenerator.new()
	rng.seed = 4242

	return {
		"system": system,
		"relationships": relationships,
		"residents": [resident_a, resident_b, resident_c, busy],
		"rng": rng,
	}

func _test_world_does_not_interrupt_object_action(
	failures: Array[String],
	world_script,
	character_script,
	interaction_script,
	smart_object_script
) -> void:
	var world = world_script.new()

	var hungry = character_script.new(&"hungry", "Hungry")
	hungry.needs.hunger.value = 1.0
	hungry.needs.social.value = 0.0
	_disable_decay(hungry)

	var friend = character_script.new(&"friend", "Friend")
	friend.needs.social.value = 0.0
	_disable_decay(friend)

	world.add_character(hungry)
	world.add_character(friend)

	var eat = interaction_script.new()
	eat.id = &"eat"
	eat.duration_sim_seconds = 5.0
	eat.need_effects = {"hunger": 100.0}

	var fridge = smart_object_script.new()
	fridge.object_id = &"fridge_social_priority"
	fridge.interaction_point = Vector3(2.0, 0.0, 0.0)
	fridge.interactions.append(eat)
	world.register_smart_object(fridge)

	world.step(1.0)

	if hungry.current_action_id != &"eat":
		failures.append("high-utility SmartObject action must keep priority over social action")
	if world.social_system.reservation_book.is_reserved(hungry.id):
		failures.append("resident with active SmartObject action must not enter social session")

	fridge.free()

func _disable_decay(resident) -> void:
	for need_name in ["hunger", "energy", "hygiene", "comfort", "social", "mood"]:
		resident.needs.get(need_name).decay_per_sim_hour = 0.0
