class_name SnapshotValidator
extends RefCounted

static func validate_envelope(snapshot: Dictionary) -> Array[String]:
	var errors: Array[String] = []

	if not snapshot.has("project_id"):
		errors.append("project_id is required")
	else:
		var project_id = snapshot["project_id"]
		if not project_id is String:
			errors.append("project_id must be a string")
		elif project_id.is_empty():
			errors.append("project_id must not be empty")
		elif project_id != str(AppConstants.PROJECT_ID):
			errors.append("project_id does not match this project")

	if not snapshot.has("schema_version"):
		errors.append("schema_version is required")
	else:
		var version = snapshot["schema_version"]
		if not version is int:
			errors.append("schema_version must be an integer")
		elif version < 0:
			errors.append("schema_version must not be negative")
		elif version > SaveSchema.CURRENT_VERSION:
			errors.append("future schema_version is not supported")

	if not snapshot.has("payload"):
		errors.append("payload is required")
	elif not snapshot["payload"] is Dictionary:
		errors.append("payload must be a Dictionary")

	return errors
