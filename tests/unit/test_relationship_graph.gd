extends RefCounted

const STATE_PATH := "res://scripts/simulation/relationships/relationship_state.gd"
const GRAPH_PATH := "res://scripts/simulation/relationships/relationship_graph.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	if not FileAccess.file_exists(STATE_PATH):
		failures.append("RelationshipState must exist at %s" % STATE_PATH)
		return failures
	if not FileAccess.file_exists(GRAPH_PATH):
		failures.append("RelationshipGraph must exist at %s" % GRAPH_PATH)
		return failures

	var state_script := load(STATE_PATH)
	var graph_script := load(GRAPH_PATH)
	if state_script == null or graph_script == null:
		failures.append("relationship dependencies must load")
		return failures

	var state = state_script.new()
	if not is_equal_approx(state.affinity, 0.0):
		failures.append("affinity must default to neutral 0")
	if not is_equal_approx(state.trust, 0.0):
		failures.append("trust must default to neutral 0")
	if not is_equal_approx(state.tension, 0.0):
		failures.append("tension must default to neutral 0")

	state.apply_delta(150.0, -150.0, 250.0)
	if not is_equal_approx(state.affinity, 100.0):
		failures.append("affinity must clamp to 100")
	if not is_equal_approx(state.trust, -100.0):
		failures.append("trust must clamp to -100")
	if not is_equal_approx(state.tension, 100.0):
		failures.append("tension must clamp to 100")

	var affinity_before: float = state.affinity
	var trust_before: float = state.trust
	var tension_before: float = state.tension
	state.apply_delta(NAN, NAN, NAN)
	if is_nan(state.affinity) or is_nan(state.trust) or is_nan(state.tension):
		failures.append("relationship values must never become NaN")
	if not is_equal_approx(state.affinity, affinity_before):
		failures.append("NaN affinity delta must be ignored")
	if not is_equal_approx(state.trust, trust_before):
		failures.append("NaN trust delta must be ignored")
	if not is_equal_approx(state.tension, tension_before):
		failures.append("NaN tension delta must be ignored")

	var graph = graph_script.new()
	if graph.get_or_create(&"", &"resident_b") != null:
		failures.append("relationship graph must reject empty source id")
	if graph.get_or_create(&"resident_a", &"") != null:
		failures.append("relationship graph must reject empty target id")
	if graph.get_or_create(&"resident_a", &"resident_a") != null:
		failures.append("relationship graph must reject self relationship")

	var a_to_b = graph.get_or_create(&"resident_a", &"resident_b")
	if a_to_b == null:
		failures.append("valid directed relationship must be created")
		return failures

	if graph.get_or_create(&"resident_a", &"resident_b") != a_to_b:
		failures.append("duplicate edge creation must return existing state")

	a_to_b.apply_delta(20.0, 10.0, -5.0)
	if graph.get_relationship(&"resident_a", &"resident_b") != a_to_b:
		failures.append("stable directed lookup must return existing state")
	if graph.get_relationship(&"resident_b", &"resident_a") != null:
		failures.append("reverse relationship must not exist until created")

	var b_to_a = graph.get_or_create(&"resident_b", &"resident_a")
	if b_to_a == null or b_to_a == a_to_b:
		failures.append("reverse relationship must be a distinct directed state")
	elif not is_equal_approx(b_to_a.affinity, 0.0):
		failures.append("reverse relationship must not inherit forward affinity")

	graph.get_or_create(&"resident_c", &"resident_a")
	graph.get_or_create(&"resident_a", &"resident_c")

	var edges: Array = graph.all_relationships()
	if edges.size() != 4:
		failures.append("relationship graph must expose four created directed edges")
	else:
		var keys: Array[String] = []
		for edge in edges:
			keys.append("%s>%s" % [edge["from_id"], edge["to_id"]])
		var expected: Array[String] = [
			"resident_a>resident_b",
			"resident_a>resident_c",
			"resident_b>resident_a",
			"resident_c>resident_a",
		]
		if keys != expected:
			failures.append("relationship graph traversal must be deterministic and sorted")

	return failures
