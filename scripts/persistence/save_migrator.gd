class_name SaveMigrator
extends RefCounted

func migrate(snapshot: Dictionary) -> Dictionary:
	var source: Dictionary = snapshot.duplicate(true)

	if source.has("schema_version"):
		var raw_version = source["schema_version"]
		if not (raw_version is int or raw_version is float):
			return {}
		var version_value := float(raw_version)
		if is_nan(version_value) or is_inf(version_value):
			return {}
		if not is_equal_approx(version_value, float(int(version_value))):
			return {}
		if int(version_value) != SaveSchema.CURRENT_VERSION:
			return {}
		if not SaveSchema.validate_envelope(source).is_empty():
			return {}
		return source

	if not source.has("version"):
		return {}

	var raw_legacy_version = source["version"]
	if not (raw_legacy_version is int or raw_legacy_version is float):
		return {}
	var legacy_version := float(raw_legacy_version)
	if is_nan(legacy_version) or is_inf(legacy_version):
		return {}
	if not is_equal_approx(legacy_version, 0.0):
		return {}
	if not source.has("data") or not source["data"] is Dictionary:
		return {}

	return SaveSchema.wrap(source["data"])
