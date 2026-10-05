extends RefCounted

const CODEC_PATH := "res://scripts/persistence/social_economy_snapshot_codec.gd"
const RELATIONSHIP_GRAPH_PATH := "res://scripts/simulation/relationships/relationship_graph.gd"
const ECONOMY_PATH := "res://scripts/simulation/economy/economy_system.gd"
const EXPENSE_PATH := "res://scripts/simulation/economy/household_expense_system.gd"
const CHARACTER_PATH := "res://scripts/simulation/characters/character_state.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	if not FileAccess.file_exists(CODEC_PATH):
		failures.append("SocialEconomySnapshotCodec must exist at %s" % CODEC_PATH)
		return failures

	var codec_script := load(CODEC_PATH)
	var graph_script := load(RELATIONSHIP_GRAPH_PATH)
	var economy_script := load(ECONOMY_PATH)
	var expense_script := load(EXPENSE_PATH)
	var character_script := load(CHARACTER_PATH)
	if (
		codec_script == null
		or graph_script == null
		or economy_script == null
		or expense_script == null
		or character_script == null
	):
		failures.append("social economy persistence dependencies must load")
		return failures

	_test_relationships(failures, codec_script, graph_script)
	_test_economy(failures, economy_script, character_script)
	_test_household_expenses(failures, expense_script)

	return failures

func _test_relationships(
	failures: Array[String],
	codec_script,
	graph_script
) -> void:
	var graph = graph_script.new()
	graph.get_or_create(&"resident_a", &"resident_b").apply_delta(25.0, 10.0, -5.0)
	graph.get_or_create(&"resident_b", &"resident_a").apply_delta(-15.0, -20.0, 35.0)

	var encoded: Array = codec_script.encode_relationships(graph)
	if encoded.size() != 2:
		failures.append("relationship codec must encode all directed edges")
		return
	if not _is_json_compatible(encoded):
		failures.append("relationship snapshot must be JSON-compatible")

	var resident_ids := {
		"resident_a": true,
		"resident_b": true,
	}
	var errors: Array[String] = codec_script.validate_relationships(encoded, resident_ids)
	if not errors.is_empty():
		failures.append("valid relationship snapshot must pass: %s" % " | ".join(errors))
		return

	var restored = graph_script.new()
	if not codec_script.restore_relationships(encoded, restored):
		failures.append("valid relationship snapshot must restore")
		return

	var a_to_b = restored.get_relationship(&"resident_a", &"resident_b")
	var b_to_a = restored.get_relationship(&"resident_b", &"resident_a")
	if a_to_b == null or b_to_a == null:
		failures.append("restored directed relationship edges must exist")
	else:
		if not is_equal_approx(a_to_b.affinity, 25.0):
			failures.append("relationship affinity must round-trip")
		if not is_equal_approx(a_to_b.trust, 10.0):
			failures.append("relationship trust must round-trip")
		if not is_equal_approx(a_to_b.tension, -5.0):
			failures.append("relationship tension must round-trip")
		if not is_equal_approx(b_to_a.affinity, -15.0):
			failures.append("reverse relationship must remain distinct")

	var missing_endpoint := encoded.duplicate(true)
	missing_endpoint[0]["to_id"] = "resident_missing"
	if codec_script.validate_relationships(missing_endpoint, resident_ids).is_empty():
		failures.append("relationship endpoint outside resident roster must fail validation")

	var duplicate_edge := encoded.duplicate(true)
	duplicate_edge.append(duplicate_edge[0].duplicate(true))
	if codec_script.validate_relationships(duplicate_edge, resident_ids).is_empty():
		failures.append("duplicate directed relationship edge must fail validation")

	var self_edge := encoded.duplicate(true)
	self_edge[0]["to_id"] = self_edge[0]["from_id"]
	if codec_script.validate_relationships(self_edge, resident_ids).is_empty():
		failures.append("self relationship edge must fail validation")

func _test_economy(
	failures: Array[String],
	economy_script,
	character_script
) -> void:
	var economy = economy_script.new()
	var resident = character_script.new(&"resident_money", "Money Resident")

	for index in range(515):
		var tx = economy.deposit(resident, 1.0, float(index))
		if tx == null:
			failures.append("economy setup deposit must succeed")
			return

	var state: Dictionary = economy.capture_persistence_state()
	if not _is_json_compatible(state):
		failures.append("economy persistence state must be JSON-compatible")
	if state.get("sequence", -1) != 515:
		failures.append("economy persistence must capture transaction sequence")
	if not state.has("transactions") or not state["transactions"] is Array:
		failures.append("economy persistence must capture transaction history")
		return

	var transactions: Array = state["transactions"]
	if transactions.size() != 512:
		failures.append("economy persistence must retain newest 512 transactions")
	else:
		if transactions[0]["transaction_id"] != "txn_000004":
			failures.append("bounded economy history must drop oldest transactions first")
		if transactions[-1]["transaction_id"] != "txn_000515":
			failures.append("bounded economy history must preserve newest transaction")

	var restored = economy_script.new()
	if not restored.restore_persistence_state(state):
		failures.append("valid economy persistence state must restore")
		return
	if restored.transactions().size() != 512:
		failures.append("restored economy must retain captured bounded history")

	var next_resident = character_script.new(&"next_money", "Next Money")
	var next_tx = restored.deposit(next_resident, 2.0, 600.0)
	if next_tx == null or next_tx.transaction_id != &"txn_000516":
		failures.append("restored economy must continue deterministic transaction sequence")

	var before_invalid: Dictionary = restored.capture_persistence_state()
	var invalid := before_invalid.duplicate(true)
	invalid["sequence"] = -1
	if restored.restore_persistence_state(invalid):
		failures.append("invalid economy persistence state must be rejected")
	if restored.capture_persistence_state() != before_invalid:
		failures.append("failed economy restore must not partially mutate current state")

func _test_household_expenses(
	failures: Array[String],
	expense_script
) -> void:
	var expenses = expense_script.new(120.0)
	expenses.arrears = 15.5
	expenses.processed_days = 3

	var state: Dictionary = expenses.capture_persistence_state()
	if not _is_json_compatible(state):
		failures.append("household expense state must be JSON-compatible")

	var restored = expense_script.new()
	if not restored.restore_persistence_state(state):
		failures.append("valid household expense state must restore")
		return

	if not is_equal_approx(restored.daily_amount, 120.0):
		failures.append("daily household amount must round-trip")
	if not is_equal_approx(restored.arrears, 15.5):
		failures.append("household arrears must round-trip")
	if restored.processed_days != 3:
		failures.append("processed household days must round-trip")

	var before_invalid: Dictionary = restored.capture_persistence_state()
	var invalid := before_invalid.duplicate(true)
	invalid["processed_days"] = -1
	if restored.restore_persistence_state(invalid):
		failures.append("negative processed_days must reject expense restore")
	if restored.capture_persistence_state() != before_invalid:
		failures.append("failed expense restore must not mutate current state")

func _is_json_compatible(value) -> bool:
	if value == null:
		return true
	if value is String or value is bool or value is int or value is float:
		return true
	if value is Array:
		for item in value:
			if not _is_json_compatible(item):
				return false
		return true
	if value is Dictionary:
		for key in value.keys():
			if not key is String:
				return false
			if not _is_json_compatible(value[key]):
				return false
		return true
	return false
