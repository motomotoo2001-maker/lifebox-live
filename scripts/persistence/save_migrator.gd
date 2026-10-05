class_name SaveMigrator
extends RefCounted

static func migrate_to_current(snapshot: Dictionary) -> Dictionary:
	if not _has_valid_base_envelope(snapshot):
		return {}

	var migrated := snapshot.duplicate(true)
	var version := int(migrated["schema_version"])

	while version < SaveSchema.CURRENT_VERSION:
		match version:
			0:
				if not _migrate_v0_to_v1(migrated):
					return {}
				version = 1
			_:
				return {}

	if version != SaveSchema.CURRENT_VERSION:
		return {}

	if not SnapshotValidator.validate_envelope(migrated).is_empty():
		return {}

	return migrated

static func _migrate_v0_to_v1(snapshot: Dictionary) -> bool:
	if not snapshot.has("payload") or not snapshot["payload"] is Dictionary:
		return false

	var payload: Dictionary = snapshot["payload"]
	if not payload.has("characters") or not payload["characters"] is Array:
		return false
	if payload.has("residents"):
		return false

	payload["residents"] = payload["characters"].duplicate(true)
	payload.erase("characters")
	snapshot["schema_version"] = 1
	return true

static func _has_valid_base_envelope(snapshot: Dictionary) -> bool:
	if not snapshot.has("project_id") or not snapshot["project_id"] is String:
		return false
	if snapshot["project_id"] != str(AppConstants.PROJECT_ID):
		return false

	if not snapshot.has("schema_version") or not snapshot["schema_version"] is int:
		return false
	var version := int(snapshot["schema_version"])
	if version < 0 or version > SaveSchema.CURRENT_VERSION:
		return false

	if not snapshot.has("payload") or not snapshot["payload"] is Dictionary:
		return false

	return true
