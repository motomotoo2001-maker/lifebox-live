extends RefCounted

const SERVICE_PATH := "res://scripts/persistence/save_service.gd"
const SAVE_PATH := "user://lifebox_save_service_test.json"
const LEGACY_PATH := "user://lifebox_save_service_legacy_test.json"

func run() -> Array[String]:
	var failures: Array[String] = []

	_cleanup()

	if not FileAccess.file_exists(SERVICE_PATH):
		failures.append("SaveService must exist at %s" % SERVICE_PATH)
		return failures

	var service_script := load(SERVICE_PATH)
	if service_script == null:
		failures.append("SaveService must load")
		return failures

	if not service_script.load_envelope(SAVE_PATH).is_empty():
		failures.append("missing main and backup must return empty load result")

	var first := SaveSchema.create_envelope({
		"residents": [],
		"marker": "first",
		"precise_float": 99.8638888888902,
		"large_int": 9007199254740993,
	})
	if not service_script.save_envelope(SAVE_PATH, first):
		failures.append("first valid save must succeed")
		_cleanup()
		return failures

	if not FileAccess.file_exists(SAVE_PATH):
		failures.append("successful save must create main file")
	if FileAccess.file_exists(SAVE_PATH + ".tmp"):
		failures.append("successful save must not leave temp file")

	var loaded_first: Dictionary = service_script.load_envelope(SAVE_PATH)
	if loaded_first.is_empty():
		failures.append("freshly saved main file must load")
	elif loaded_first["payload"].get("marker", "") != "first":
		failures.append("loaded first save must preserve payload")
	else:
		if loaded_first["payload"].get("precise_float") != first["payload"]["precise_float"]:
			failures.append("lossless disk save must preserve exact float value")
		if loaded_first["payload"].get("large_int") != first["payload"]["large_int"]:
			failures.append("lossless disk save must preserve 64-bit integer value")
		if not loaded_first["payload"].get("large_int") is int:
			failures.append("lossless disk save must preserve integer Variant type")

	var second := SaveSchema.create_envelope({
		"residents": [],
		"marker": "second",
	})
	if not service_script.save_envelope(SAVE_PATH, second):
		failures.append("second valid save must succeed")
		_cleanup()
		return failures

	if not FileAccess.file_exists(SAVE_PATH + ".bak"):
		failures.append("second save must preserve previous main as backup")

	var loaded_second: Dictionary = service_script.load_envelope(SAVE_PATH)
	if loaded_second.is_empty():
		failures.append("second main file must load")
	elif loaded_second["payload"].get("marker", "") != "second":
		failures.append("second main payload must be current")

	var backup: Dictionary = _read_raw_envelope(SAVE_PATH + ".bak")
	if backup.is_empty():
		failures.append("backup file must contain valid JSON envelope")
	elif backup["payload"].get("marker", "") != "first":
		failures.append("backup must preserve previous main save")

	var main_file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if main_file == null:
		failures.append("test must be able to corrupt main file")
		_cleanup()
		return failures
	main_file.store_string("{ definitely broken json")
	main_file.close()

	var recovered: Dictionary = service_script.load_envelope(SAVE_PATH)
	if recovered.is_empty():
		failures.append("corrupt main must recover from valid backup")
	elif recovered["payload"].get("marker", "") != "first":
		failures.append("backup recovery must return previous valid save")

	var invalid := second.duplicate(true)
	invalid["project_id"] = "wrong_project"
	if service_script.save_envelope(SAVE_PATH, invalid):
		failures.append("invalid envelope must not be written")

	var recovered_after_invalid: Dictionary = service_script.load_envelope(SAVE_PATH)
	if recovered_after_invalid.is_empty():
		failures.append("failed invalid save must not destroy recoverable backup")
	elif recovered_after_invalid["payload"].get("marker", "") != "first":
		failures.append("failed invalid save must preserve previous recoverable data")

	if FileAccess.file_exists(SAVE_PATH + ".tmp"):
		failures.append("failed or successful operations must not leave temp file")

	var legacy := SaveSchema.create_envelope({
		"residents": [],
		"marker": "legacy_plain_json",
	})
	var legacy_file := FileAccess.open(LEGACY_PATH, FileAccess.WRITE)
	if legacy_file == null:
		failures.append("legacy compatibility test must open legacy save path")
	else:
		legacy_file.store_string(JSON.stringify(legacy))
		legacy_file.close()
		var loaded_legacy: Dictionary = service_script.load_envelope(LEGACY_PATH)
		if loaded_legacy.is_empty():
			failures.append("SaveService must keep loading legacy plain JSON envelopes")
		elif loaded_legacy["payload"].get("marker", "") != "legacy_plain_json":
			failures.append("legacy plain JSON envelope payload must be preserved")

	_cleanup()
	return failures

func _read_raw_envelope(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {}
	var parsed = parser.data
	if not parsed is Dictionary:
		return {}
	if parsed.get("format", "") != SaveService.DISK_FORMAT:
		return {}
	if not parsed.has("data") or not parsed["data"] is String:
		return {}
	var decoded = Marshalls.base64_to_variant(parsed["data"], false)
	if not decoded is Dictionary:
		return {}
	return SaveMigrator.migrate_to_current(decoded)

func _cleanup() -> void:
	for path in [
		SAVE_PATH,
		SAVE_PATH + ".tmp",
		SAVE_PATH + ".bak",
		LEGACY_PATH,
		LEGACY_PATH + ".tmp",
		LEGACY_PATH + ".bak",
	]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
