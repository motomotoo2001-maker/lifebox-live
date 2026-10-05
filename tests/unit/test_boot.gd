extends RefCounted

const APP_CONSTANTS_PATH := "res://scripts/core/app_constants.gd"

func run() -> Array[String]:
	var failures: Array[String] = []
	var version := Engine.get_version_info()

	if int(version.get("major", 0)) != 4:
		failures.append("Godot major version must be 4")

	if not FileAccess.file_exists(APP_CONSTANTS_PATH):
		failures.append("AppConstants must exist at %s" % APP_CONSTANTS_PATH)
		return failures

	var app_constants_script := load(APP_CONSTANTS_PATH)
	if app_constants_script == null:
		failures.append("AppConstants script must load")
		return failures

	if app_constants_script.PROJECT_ID != &"lifebox_live":
		failures.append("PROJECT_ID must be lifebox_live")

	return failures
