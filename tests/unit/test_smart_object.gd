extends RefCounted

const INTERACTION_PATH := "res://scripts/simulation/interactions/interaction_definition.gd"
const SMART_OBJECT_PATH := "res://scripts/simulation/interactions/smart_object.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	if not FileAccess.file_exists(INTERACTION_PATH):
		failures.append("InteractionDefinition must exist at %s" % INTERACTION_PATH)
		return failures
	if not FileAccess.file_exists(SMART_OBJECT_PATH):
		failures.append("SmartObject must exist at %s" % SMART_OBJECT_PATH)
		return failures

	var interaction_script := load(INTERACTION_PATH)
	var smart_object_script := load(SMART_OBJECT_PATH)
	if interaction_script == null or smart_object_script == null:
		failures.append("SmartObject dependencies must load")
		return failures

	var interaction = interaction_script.new()
	interaction.id = &"eat_snack"
	interaction.duration_sim_seconds = 120.0
	interaction.need_effects = {"hunger": 25.0}

	var smart_object = smart_object_script.new()
	smart_object.object_id = &"fridge_main"
	smart_object.interaction_point = Vector3(2.0, 0.0, -1.0)
	smart_object.interactions.append(interaction)

	if smart_object.object_id != &"fridge_main":
		failures.append("SmartObject must expose stable object_id")
	if smart_object.interaction_point != Vector3(2.0, 0.0, -1.0):
		failures.append("SmartObject must expose logical interaction_point")

	var listed: Array = smart_object.list_interactions(null)
	if listed.size() != 1 or listed[0].id != &"eat_snack":
		failures.append("SmartObject must expose configured interactions")

	if not smart_object.reserve(&"resident_a"):
		failures.append("free SmartObject must accept resident A")
	if not smart_object.is_available_for(&"resident_a"):
		failures.append("reservation owner must keep access")
	if smart_object.is_available_for(&"resident_b"):
		failures.append("reserved SmartObject must reject resident B")
	if smart_object.reserve(&"resident_b"):
		failures.append("resident B must not steal an active reservation")

	smart_object.release(&"resident_a")
	if not smart_object.is_available_for(&"resident_b"):
		failures.append("release must make SmartObject available")
	if not smart_object.reserve(&"resident_b"):
		failures.append("resident B must reserve after release")

	smart_object.free()
	if is_instance_valid(smart_object):
		failures.append("freed SmartObject must not preserve observable reservation state")

	return failures
