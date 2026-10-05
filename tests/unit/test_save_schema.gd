extends RefCounted

const SCHEMA_PATH := "res://scripts/persistence/save_schema.gd"
const MIGRATOR_PATH := "res://scripts/persistence/save_migrator.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	if not FileAccess.file_exists(SCHEMA_PATH):
		failures.append("SaveSchema must exist at %s" % SCHEMA_PATH)
		return failures
	if not FileAccess.file_exists(MIGRATOR_PATH):
		failures.append("SaveMigrator must exist at %s" % MIGRATOR_PATH)
		return failures

	var schema_script := load(SCHEMA_PATH)
	var migrator_script := load(MIGRATOR_PATH)
	if schema_script == null or migrator_script == null:
		failures.append("save schema dependencies must load")
		return failures

	if schema_script.CURRENT_VERSION != 1:
		failures.append("save schema CURRENT_VERSION must start at 1")

	var world_data := {
		"simulation_seconds": 123.0,
		"residents": [{"id": "resident_001"}],
	}
	var wrapped: Dictionary = schema_script.wrap(world_data)
	if int(wrapped.get("schema_version", -1)) != 1:
		failures.append("wrap() must emit schema_version 1")
	if wrapped.get("world", null) != world_data:
		failures.append("wrap() must preserve world payload")

	var valid_errors: Array[String] = schema_script.validate_envelope(wrapped)
	if not valid_errors.is_empty():
		failures.append("valid v1 envelope must have no validation errors")

	var missing_version_errors: Array[String] = schema_script.validate_envelope({"world": {}})
	if missing_version_errors.is_empty():
		failures.append("missing schema_version must be rejected")

	var missing_world_errors: Array[String] = schema_script.validate_envelope({"schema_version": 1})
	if missing_world_errors.is_empty():
		failures.append("missing world payload must be rejected")

	var future_errors: Array[String] = schema_script.validate_envelope({
		"schema_version": 999,
		"world": {},
	})
	if future_errors.is_empty():
		failures.append("future save version must be rejected")

	var migrator = migrator_script.new()
	var legacy := {
		"version": 0,
		"data": {
			"simulation_seconds": 77.0,
			"residents": [{"id": "legacy_resident"}],
		},
	}
	var legacy_before: Dictionary = legacy.duplicate(true)
	var migrated: Dictionary = migrator.migrate(legacy)

	if legacy != legacy_before:
		failures.append("migration must not mutate caller dictionary")
	if int(migrated.get("schema_version", -1)) != 1:
		failures.append("legacy v0 must migrate to schema v1")
	if migrated.get("world", null) != legacy["data"]:
		failures.append("legacy v0 data must become v1 world payload")
	if not schema_script.validate_envelope(migrated).is_empty():
		failures.append("migrated v0 snapshot must validate as v1")

	var current_before: Dictionary = wrapped.duplicate(true)
	var current_migrated: Dictionary = migrator.migrate(wrapped)
	if wrapped != current_before:
		failures.append("current-version migration must not mutate caller snapshot")
	if current_migrated != wrapped:
		failures.append("current-version migration must preserve equivalent data")
	if current_migrated.is_same_typed(wrapped) and current_migrated.hash() == wrapped.hash():
		pass

	var future_migrated: Dictionary = migrator.migrate({
		"schema_version": 2,
		"world": {},
	})
	if not future_migrated.is_empty():
		failures.append("future version migration must fail with empty snapshot")

	var malformed_legacy: Dictionary = migrator.migrate({
		"version": 0,
		"data": "not_a_dictionary",
	})
	if not malformed_legacy.is_empty():
		failures.append("malformed legacy payload must fail migration")

	return failures
