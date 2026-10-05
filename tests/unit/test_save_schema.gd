extends RefCounted

const SCHEMA_PATH := "res://scripts/persistence/save_schema.gd"
const VALIDATOR_PATH := "res://scripts/persistence/snapshot_validator.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	if not FileAccess.file_exists(SCHEMA_PATH):
		failures.append("SaveSchema must exist at %s" % SCHEMA_PATH)
		return failures
	if not FileAccess.file_exists(VALIDATOR_PATH):
		failures.append("SnapshotValidator must exist at %s" % VALIDATOR_PATH)
		return failures

	var schema_script := load(SCHEMA_PATH)
	var validator_script := load(VALIDATOR_PATH)
	if schema_script == null or validator_script == null:
		failures.append("save schema dependencies must load")
		return failures

	if schema_script.CURRENT_VERSION != 1:
		failures.append("SaveSchema CURRENT_VERSION must start at 1")

	var payload := {
		"residents": [],
		"marker": "stable",
	}
	var envelope: Dictionary = schema_script.create_envelope(payload)

	if envelope.get("project_id", "") != str(AppConstants.PROJECT_ID):
		failures.append("save envelope must include exact project_id")
	if envelope.get("schema_version", -1) != 1:
		failures.append("save envelope must include schema_version 1")
	if not envelope.has("payload") or envelope["payload"] != payload:
		failures.append("save envelope must include payload unchanged")
	if not validator_script.validate_envelope(envelope).is_empty():
		failures.append("valid save envelope must pass validation")

	var mutated_payload: Dictionary = envelope["payload"]
	mutated_payload["marker"] = "changed"
	if payload["marker"] != "stable":
		failures.append("create_envelope() must defensively copy payload")

	var cases: Array[Dictionary] = [
		{
			"snapshot": {
				"project_id": "",
				"schema_version": 1,
				"payload": {},
			},
			"needle": "project_id",
		},
		{
			"snapshot": {
				"schema_version": 1,
				"payload": {},
			},
			"needle": "project_id",
		},
		{
			"snapshot": {
				"project_id": "wrong_project",
				"schema_version": 1,
				"payload": {},
			},
			"needle": "project_id",
		},
		{
			"snapshot": {
				"project_id": str(AppConstants.PROJECT_ID),
				"schema_version": 1.5,
				"payload": {},
			},
			"needle": "schema_version",
		},
		{
			"snapshot": {
				"project_id": str(AppConstants.PROJECT_ID),
				"schema_version": -1,
				"payload": {},
			},
			"needle": "schema_version",
		},
		{
			"snapshot": {
				"project_id": str(AppConstants.PROJECT_ID),
				"schema_version": schema_script.CURRENT_VERSION + 1,
				"payload": {},
			},
			"needle": "future",
		},
		{
			"snapshot": {
				"project_id": str(AppConstants.PROJECT_ID),
				"schema_version": 1,
			},
			"needle": "payload",
		},
		{
			"snapshot": {
				"project_id": str(AppConstants.PROJECT_ID),
				"schema_version": 1,
				"payload": [],
			},
			"needle": "payload",
		},
	]

	for case in cases:
		var snapshot: Dictionary = case["snapshot"]
		var before := snapshot.duplicate(true)
		var errors: Array[String] = validator_script.validate_envelope(snapshot)
		if errors.is_empty():
			failures.append("invalid envelope must produce validation errors")
			continue

		var joined := " | ".join(errors).to_lower()
		if str(case["needle"]).to_lower() not in joined:
			failures.append(
				"validation error must mention %s, got: %s"
				% [case["needle"], joined]
			)
		if snapshot != before:
			failures.append("validate_envelope() must never mutate input")

	return failures
