class_name SaveService
extends RefCounted

const TEMP_SUFFIX := ".tmp"
const BACKUP_SUFFIX := ".bak"

static func save_envelope(path: String, snapshot: Dictionary) -> bool:
	if path.is_empty():
		return false

	var normalized := SaveMigrator.migrate_to_current(snapshot)
	if normalized.is_empty():
		return false
	if not SnapshotValidator.validate_envelope(normalized).is_empty():
		return false

	var temp_path := path + TEMP_SUFFIX
	var backup_path := path + BACKUP_SUFFIX
	_cleanup_temp(temp_path)

	if not _ensure_parent_directory(path):
		return false

	var serialized := JSON.stringify(normalized)
	var temp_file := FileAccess.open(temp_path, FileAccess.WRITE)
	if temp_file == null:
		return false

	var stored := temp_file.store_string(serialized)
	temp_file.flush()
	temp_file.close()

	if not stored:
		_cleanup_temp(temp_path)
		return false

	if _load_candidate(temp_path).is_empty():
		_cleanup_temp(temp_path)
		return false

	var absolute_main := ProjectSettings.globalize_path(path)
	var absolute_temp := ProjectSettings.globalize_path(temp_path)
	var absolute_backup := ProjectSettings.globalize_path(backup_path)
	var had_main := FileAccess.file_exists(path)

	if had_main:
		if FileAccess.file_exists(backup_path):
			if DirAccess.remove_absolute(absolute_backup) != OK:
				_cleanup_temp(temp_path)
				return false

		if DirAccess.rename_absolute(absolute_main, absolute_backup) != OK:
			_cleanup_temp(temp_path)
			return false

	if DirAccess.rename_absolute(absolute_temp, absolute_main) != OK:
		if had_main and FileAccess.file_exists(backup_path):
			if not FileAccess.file_exists(path):
				DirAccess.rename_absolute(absolute_backup, absolute_main)
		_cleanup_temp(temp_path)
		return false

	return true

static func load_envelope(path: String) -> Dictionary:
	if path.is_empty():
		return {}

	var main := _load_candidate(path)
	if not main.is_empty():
		return main

	return _load_candidate(path + BACKUP_SUFFIX)

static func _load_candidate(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}

	var raw_text := file.get_as_text()
	file.close()

	var parser := JSON.new()
	if parser.parse(raw_text) != OK:
		return {}

	var parsed = _normalize_json_numbers(parser.data)
	if not parsed is Dictionary:
		return {}

	var migrated := SaveMigrator.migrate_to_current(parsed)
	if migrated.is_empty():
		return {}
	if not SnapshotValidator.validate_envelope(migrated).is_empty():
		return {}

	return migrated

static func _ensure_parent_directory(path: String) -> bool:
	var absolute_path := ProjectSettings.globalize_path(path)
	var base_dir := absolute_path.get_base_dir()
	if base_dir.is_empty():
		return true
	if DirAccess.dir_exists_absolute(base_dir):
		return true
	return DirAccess.make_dir_recursive_absolute(base_dir) == OK

static func _cleanup_temp(temp_path: String) -> void:
	if FileAccess.file_exists(temp_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))


static func _normalize_json_numbers(value):
	if value is float:
		if is_nan(value) or is_inf(value):
			return value
		if (
			value >= -9007199254740991.0
			and value <= 9007199254740991.0
			and value == floor(value)
		):
			return int(value)
		return value

	if value is Array:
		var normalized_array: Array = []
		for item in value:
			normalized_array.append(_normalize_json_numbers(item))
		return normalized_array

	if value is Dictionary:
		var normalized_dictionary: Dictionary = {}
		for key in value.keys():
			normalized_dictionary[key] = _normalize_json_numbers(value[key])
		return normalized_dictionary

	return value
