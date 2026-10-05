class_name RelationshipGraph
extends RefCounted

var _edges: Dictionary = {}

func get_or_create(from_id: StringName, to_id: StringName) -> RelationshipState:
	if not _is_valid_pair(from_id, to_id):
		return null

	var key := _edge_key(from_id, to_id)
	if _edges.has(key):
		return _edges[key]["state"] as RelationshipState

	var state := RelationshipState.new()
	_edges[key] = {
		"from_id": from_id,
		"to_id": to_id,
		"state": state,
	}
	return state

func get_relationship(from_id: StringName, to_id: StringName) -> RelationshipState:
	if not _is_valid_pair(from_id, to_id):
		return null

	var key := _edge_key(from_id, to_id)
	if not _edges.has(key):
		return null

	return _edges[key]["state"] as RelationshipState

func all_relationships() -> Array:
	var keys: Array[String] = []
	for key in _edges.keys():
		keys.append(str(key))
	keys.sort()

	var result: Array = []
	for key in keys:
		var edge: Dictionary = _edges[key]
		result.append({
			"from_id": edge["from_id"],
			"to_id": edge["to_id"],
			"state": edge["state"],
		})
	return result

func _is_valid_pair(from_id: StringName, to_id: StringName) -> bool:
	return from_id != &"" and to_id != &"" and from_id != to_id

func _edge_key(from_id: StringName, to_id: StringName) -> String:
	return "%s>%s" % [from_id, to_id]
