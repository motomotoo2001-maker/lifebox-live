extends RefCounted

const MIGRATOR_PATH := "res://scripts/persistence/save_migrator.gd"
const FIXTURE_PATH := "res://tests/fixtures/save_v0.json"

func run() -> Array[String]:
	var failures: Array[String] = []

	if not FileAccess.file_exists(MIGRATOR_PATH):
		failures.append("SaveMigrator must exist at %s" % MIGRATOR_PATH)
		return failures

	var migrator_script := load(MIGRATOR_PATH)
	if migrator_script == null:
		failures.append("SaveMigrator must load")
		return failures

	var file := FileAccess.open(FIXTURE_PATH, FileAccess.READ)
	if file == null:
		failures.append("legacy v0 fixture must open")
		return failures

	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		failures.append("legacy v0 fixture must parse as Dictionary")
		return failures

	var legacy: Dictionary = parsed
	var legacy_before := legacy.duplicate(true)
	var migrated: Dictionary = migrator_script.migrate_to_current(legacy)

	if migrated.is_empty():
		failures.append("valid v0 snapshot must migrate to current schema")
		return failures

	if migrated.get("schema_version", -1) != SaveSchema.CURRENT_VERSION:
		failures.append("migrated snapshot must end at current schema version")
	if migrated.get("project_id", "") != str(AppConstants.PROJECT_ID):
		failures.append("migrated snapshot must preserve project_id")
	if not migrated.has("payload") or not migrated["payload"] is Dictionary:
		failures.append("migrated snapshot must retain payload")
		return failures

	var payload: Dictionary = migrated["payload"]
	if not payload.has("residents"):
		failures.append("v0 characters must migrate to residents")
	if payload.has("characters"):
		failures.append("v0 characters key must be removed after migration")
	if payload.get("marker", "") != "preserve_me":
		failures.append("unrelated payload fields must survive migration")
	if payload.get("nested", {}).get("value", -1) != 42:
		failures.append("nested unrelated payload data must survive migration")

	if legacy != legacy_before:
		failures.append("migration must never mutate input snapshot")

	payload["marker"] = "mutated_copy"
	if legacy["payload"]["marker"] != "preserve_me":
		failures.append("migrated result must not alias original nested payload")

	var current := SaveSchema.create_envelope({
		"residents": [],
		"marker": "current",
	})
	var current_before := current.duplicate(true)
	var current_result: Dictionary = migrator_script.migrate_to_current(current)
	if current_result != current:
		failures.append("current schema snapshot must pass through semantically unchanged")
	current_result["payload"]["marker"] = "changed"
	if current["payload"]["marker"] != "current":
		failures.append("current-schema migration result must be a deep copy")
	if current != current_before:
		failures.append("current-schema migration must not mutate input")

	var negative := legacy_before.duplicate(true)
	negative["schema_version"] = -1
	if not migrator_script.migrate_to_current(negative).is_empty():
		failures.append("negative schema version must be rejected")

	var future := current_before.duplicate(true)
	future["schema_version"] = SaveSchema.CURRENT_VERSION + 1
	if not migrator_script.migrate_to_current(future).is_empty():
		failures.append("unknown future schema version must be rejected")

	var missing_version := current_before.duplicate(true)
	missing_version.erase("schema_version")
	if not migrator_script.migrate_to_current(missing_version).is_empty():
		failures.append("missing schema version must be rejected")

	var non_integer := current_before.duplicate(true)
	non_integer["schema_version"] = 0.5
	if not migrator_script.migrate_to_current(non_integer).is_empty():
		failures.append("non-integer schema version must be rejected")

	var malformed_v0 := legacy_before.duplicate(true)
	malformed_v0["payload"].erase("characters")
	if not migrator_script.migrate_to_current(malformed_v0).is_empty():
		failures.append("v0 snapshot missing characters must be rejected")

	return failures
