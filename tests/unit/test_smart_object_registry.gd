extends RefCounted

const REGISTRY_PATH := "res://scripts/simulation/interactions/smart_object_registry.gd"
const SMART_OBJECT_PATH := "res://scripts/simulation/interactions/smart_object.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	if not FileAccess.file_exists(REGISTRY_PATH):
		failures.append("SmartObjectRegistry must exist at %s" % REGISTRY_PATH)
		return failures

	var registry_script := load(REGISTRY_PATH)
	var smart_object_script := load(SMART_OBJECT_PATH)
	if registry_script == null or smart_object_script == null:
		failures.append("SmartObjectRegistry dependencies must load")
		return failures

	var registry = registry_script.new()
	if not registry.has_signal("object_removed"):
		failures.append("SmartObjectRegistry must expose object_removed signal")
		return failures

	var removed_ids: Array[StringName] = []
	registry.object_removed.connect(func(object_id: StringName) -> void:
		removed_ids.append(object_id)
	)

	if registry.register_object(null) != false:
		failures.append("registry must reject null object")

	var invalid = smart_object_script.new()
	if registry.register_object(invalid) != false:
		failures.append("registry must reject object with empty id")
	invalid.free()

	var fridge = smart_object_script.new()
	fridge.object_id = &"fridge_main"
	fridge.interaction_point = Vector3(1.0, 0.0, 2.0)
	if registry.register_object(fridge) != true:
		failures.append("registry must accept first unique object")
	if registry.get_object(&"fridge_main") != fridge:
		failures.append("registry must return registered object by id")

	var duplicate = smart_object_script.new()
	duplicate.object_id = &"fridge_main"
	if registry.register_object(duplicate) != false:
		failures.append("registry must reject duplicate object id")
	duplicate.free()

	if not fridge.reserve(&"resident_a"):
		failures.append("test setup must reserve fridge")
	if registry.unregister_object(&"fridge_main") != true:
		failures.append("registry must unregister existing object")
	if registry.get_object(&"fridge_main") != null:
		failures.append("unregistered object must not be returned")
	if not fridge.is_available_for(&"resident_b"):
		failures.append("unregistering reserved object must clear reservation")
	if removed_ids.size() != 1 or removed_ids[0] != &"fridge_main":
		failures.append("unregister must emit object_removed exactly once")

	if registry.unregister_object(&"fridge_main") != false:
		failures.append("unregistering missing object must return false")

	var sofa = smart_object_script.new()
	sofa.object_id = &"sofa_main"
	if registry.register_object(sofa) != true:
		failures.append("registry must accept second unique object")
	sofa.free()
	if registry.get_object(&"sofa_main") != null:
		failures.append("registry must not return freed stale object")

	fridge.free()
	return failures
