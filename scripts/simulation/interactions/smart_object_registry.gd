class_name SmartObjectRegistry
extends RefCounted

signal object_removed(object_id: StringName)

var _objects: Dictionary = {}

func register_object(object: SmartObject) -> bool:
	if object == null or not is_instance_valid(object):
		return false
	if object.object_id == &"" or _objects.has(object.object_id):
		return false

	_objects[object.object_id] = object
	return true

func unregister_object(object_id: StringName) -> bool:
	if not _objects.has(object_id):
		return false

	var object: SmartObject = _objects[object_id]
	_objects.erase(object_id)

	if object != null and is_instance_valid(object):
		object.clear_reservation()

	object_removed.emit(object_id)
	return true

func get_object(object_id: StringName) -> SmartObject:
	if not _objects.has(object_id):
		return null

	var object: SmartObject = _objects[object_id]
	if object == null or not is_instance_valid(object):
		_objects.erase(object_id)
		return null

	return object
