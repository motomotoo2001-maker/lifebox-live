extends RefCounted

const SCENE_PATH := "res://scenes/ui/visual_hud.tscn"
const SCRIPT_PATH := "res://scripts/presentation/ui/visual_hud.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	if not FileAccess.file_exists(SCENE_PATH):
		failures.append("VisualHUD scene must exist at %s" % SCENE_PATH)
		return failures
	if not FileAccess.file_exists(SCRIPT_PATH):
		failures.append("VisualHUD script must exist at %s" % SCRIPT_PATH)
		return failures

	var packed_scene = load(SCENE_PATH)
	if packed_scene == null:
		failures.append("VisualHUD scene must load")
		return failures

	var hud = packed_scene.instantiate()
	if hud == null:
		failures.append("VisualHUD scene must instantiate")
		return failures

	if not hud is Control:
		failures.append("VisualHUD root must be Control")

	for node_path in [
		"TopPanel",
		"TopPanel/DayTimeLabel",
		"TopPanel/StatusLabel",
		"TopPanel/ControlHintLabel",
		"TopPanel/ResidentStrip",
		"TopPanel/ResidentStrip/ResidentButton1",
		"TopPanel/ResidentStrip/ResidentButton2",
		"TopPanel/ResidentStrip/ResidentButton3",
		"TopPanel/ResidentStrip/ResidentButton4",
		"TopPanel/ResidentStrip/ResidentButton5",
		"TopPanel/ResidentStrip/ResidentButton6",
		"SocialPanel",
		"SocialPanel/SocialTargetLabel",
		"SocialPanel/SocialStrip",
		"SocialPanel/SocialStrip/ChatButton",
		"SocialPanel/SocialStrip/ComplimentButton",
		"SocialPanel/SocialStrip/ArgueButton",
		"CommandPanel",
		"CommandPanel/CommandLabel",
		"CommandPanel/CommandStrip",
		"CommandPanel/CommandStrip/EatButton",
		"CommandPanel/CommandStrip/SleepButton",
		"CommandPanel/CommandStrip/ShowerButton",
		"CommandPanel/CommandStrip/RelaxButton",
		"CommandPanel/CommandStrip/TVButton",
		"CommandPanel/CommandStrip/ReadButton",
		"EventPanel",
		"EventPanel/EventLabel",
		"EventPanel/SaveButton",
		"EventPanel/LoadButton",
		"ResidentPanel",
		"ResidentPanel/NameLabel",
		"ResidentPanel/ScheduleLabel",
		"ResidentPanel/GoalLabel",
		"ResidentPanel/ActionLabel",
		"ResidentPanel/SocialSummaryLabel",
		"ResidentPanel/JobMemoryLabel",
		"ResidentPanel/MoneyLabel",
		"ResidentPanel/HungerLabel",
		"ResidentPanel/EnergyLabel",
		"ResidentPanel/HygieneLabel",
		"ResidentPanel/ComfortLabel",
		"ResidentPanel/SocialLabel",
		"ResidentPanel/MoodLabel",
		"ResidentPanel/HungerBar",
		"ResidentPanel/EnergyBar",
		"ResidentPanel/HygieneBar",
		"ResidentPanel/ComfortBar",
		"ResidentPanel/SocialBar",
		"ResidentPanel/MoodBar",
	]:
		if not hud.has_node(node_path):
			failures.append("VisualHUD missing node %s" % node_path)

	if not hud.has_signal("resident_requested"):
		failures.append("VisualHUD must expose resident_requested signal")
	if not hud.has_signal("save_requested"):
		failures.append("VisualHUD must expose save_requested signal")
	if not hud.has_signal("load_requested"):
		failures.append("VisualHUD must expose load_requested signal")
	if not hud.has_signal("activity_requested"):
		failures.append("VisualHUD must expose activity_requested signal")
	if not hud.has_signal("social_requested"):
		failures.append("VisualHUD must expose social_requested signal")

	for method_name in [
		"bind_world",
		"set_selected_resident",
		"set_simulation_running",
		"set_camera_mode_text",
		"set_latest_event",
		"refresh",
	]:
		if not hud.has_method(method_name):
			failures.append("VisualHUD must expose %s()" % method_name)

	hud.free()
	return failures
