class_name SaveSchema
extends RefCounted

const CURRENT_VERSION := 1

static func wrap(world_data: Dictionary) -> Dictionary:
	return {
		"schema_version": CURRENT_VERSION,
		"world": world_data.duplicate(true),
	}

static func validate_envelope(snapshot: Dictionary) -> Array[String]:
	var errors: Array[String] = []

	if not snapshot.has("schema_version"):
		errors.append("missing schema_version")
		return errors

	var raw_version = snapshot["schema_version"]
	if not (raw_version is int or raw_version is float):
		errors.append("schema_version must be numeric")
		return errors

	var version_value := float(raw_version)
	if is_nan(version_value) or is_inf(version_value):
		errors.append("schema_version must be finite")
		return errors

	var version := int(version_value)
	if not is_equal_approx(version_value, float(version)):
		errors.append("schema_version must be an integer")
		return errors
	if version != CURRENT_VERSION:
		errors.append("unsupported schema_version %d" % version)

	if not snapshot.has("world"):
		errors.append("missing world payload")
	elif not snapshot["world"] is Dictionary:
		errors.append("world payload must be a Dictionary")

	return errors
