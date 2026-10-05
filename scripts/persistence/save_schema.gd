class_name SaveSchema
extends RefCounted

const CURRENT_VERSION: int = 1

static func create_envelope(payload: Dictionary) -> Dictionary:
	return {
		"project_id": str(AppConstants.PROJECT_ID),
		"schema_version": CURRENT_VERSION,
		"payload": payload.duplicate(true),
	}
