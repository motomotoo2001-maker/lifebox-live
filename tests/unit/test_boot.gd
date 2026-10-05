extends RefCounted

const AppConstants = preload("res://scripts/core/app_constants.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	var version := Engine.get_version_info()

	if int(version.get("major", 0)) != 4:
		failures.append("Godot major version must be 4")

	if AppConstants.PROJECT_ID != &"lifebox_live":
		failures.append("PROJECT_ID must be lifebox_live")

	return failures
