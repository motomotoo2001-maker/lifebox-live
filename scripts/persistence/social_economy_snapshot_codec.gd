class_name SocialEconomySnapshotCodec
extends RefCounted

static func encode_relationships(graph: RelationshipGraph) -> Array:
	if graph == null:
		return []

	var encoded: Array = []
	for edge in graph.all_relationships():
		var state: RelationshipState = edge["state"]
		encoded.append({
			"from_id": str(edge["from_id"]),
			"to_id": str(edge["to_id"]),
			"affinity": state.affinity,
			"trust": state.trust,
			"tension": state.tension,
		})
	return encoded

static func validate_relationships(
	data: Array,
	resident_ids: Dictionary
) -> Array[String]:
	var errors: Array[String] = []
	var seen_edges: Dictionary = {}

	for index in range(data.size()):
		var raw_edge = data[index]
		if not raw_edge is Dictionary:
			errors.append("relationship[%d] must be a Dictionary" % index)
			continue
		var edge: Dictionary = raw_edge

		var from_id := _read_non_empty_string(edge, "from_id")
		var to_id := _read_non_empty_string(edge, "to_id")
		if from_id.is_empty():
			errors.append("relationship[%d] from_id must be non-empty" % index)
		if to_id.is_empty():
			errors.append("relationship[%d] to_id must be non-empty" % index)

		if not from_id.is_empty() and not to_id.is_empty():
			if from_id == to_id:
				errors.append("relationship[%d] must not be a self edge" % index)

			if not _resident_exists(resident_ids, from_id):
				errors.append("relationship[%d] from_id is not in resident roster" % index)
			if not _resident_exists(resident_ids, to_id):
				errors.append("relationship[%d] to_id is not in resident roster" % index)

			var edge_key := "%s>%s" % [from_id, to_id]
			if seen_edges.has(edge_key):
				errors.append("duplicate directed relationship edge: %s" % edge_key)
			seen_edges[edge_key] = true

		for value_name in ["affinity", "trust", "tension"]:
			if not edge.has(value_name) or not _is_finite_number(edge[value_name]):
				errors.append(
					"relationship[%d] %s must be finite" % [index, value_name]
				)
				continue
			var value := float(edge[value_name])
			if value < -100.0 or value > 100.0:
				errors.append(
					"relationship[%d] %s must be inside -100..100"
					% [index, value_name]
				)

	return errors

static func restore_relationships(
	data: Array,
	graph: RelationshipGraph
) -> bool:
	if graph == null:
		return false

	var roster: Dictionary = {}
	for raw_edge in data:
		if not raw_edge is Dictionary:
			return false
		if raw_edge.has("from_id") and raw_edge["from_id"] is String:
			roster[raw_edge["from_id"]] = true
		if raw_edge.has("to_id") and raw_edge["to_id"] is String:
			roster[raw_edge["to_id"]] = true

	if not validate_relationships(data, roster).is_empty():
		return false

	for raw_edge in data:
		var edge: Dictionary = raw_edge
		var state := graph.get_or_create(
			StringName(edge["from_id"]),
			StringName(edge["to_id"])
		)
		if state == null:
			return false
		state.affinity = float(edge["affinity"])
		state.trust = float(edge["trust"])
		state.tension = float(edge["tension"])

	return true

static func _read_non_empty_string(data: Dictionary, key: String) -> String:
	if not data.has(key) or not data[key] is String:
		return ""
	return data[key]

static func _resident_exists(resident_ids: Dictionary, resident_id: String) -> bool:
	if resident_ids.has(resident_id):
		return true
	return resident_ids.has(StringName(resident_id))

static func _is_finite_number(value) -> bool:
	if not (value is int or value is float):
		return false
	var number := float(value)
	return not is_nan(number) and not is_inf(number)
