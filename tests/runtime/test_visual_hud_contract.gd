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
		"CommandPanel",
		"CommandPanel/CommandStrip",
		"CommandPanel/CommandStrip/EatButton",
		"CommandPanel/CommandStrip/RelaxButton",
		"CommandPanel/CommandStrip/ShowerButton",
		"CommandPanel/CommandStrip/TVButton",
		"CommandPanel/CommandStrip/ReadButton",
		"CommandPanel/CommandStrip/SleepButton",
		"InsightPanel",
		"InsightPanel/TitleLabel",
		"InsightPanel/CareerLabel",
		"InsightPanel/HouseholdLabel",
		"InsightPanel/RelationshipLabel",
		"InsightPanel/MemoryLabel",
		"EventPanel",
		"EventPanel/EventLabel",
		"ResidentPanel",
		"ResidentPanel/NameLabel",
		"ResidentPanel/ScheduleLabel",
		"ResidentPanel/GoalLabel",
		"ResidentPanel/ActionLabel",
		"ResidentPanel/MoneyLabel",
		"ResidentPanel/HungerLabel",
		"ResidentPanel/EnergyLabel",
		"ResidentPanel/SocialLabel",
		"ResidentPanel/MoodLabel",
		"ResidentPanel/HungerBar",
		"ResidentPanel/EnergyBar",
		"ResidentPanel/SocialBar",
		"ResidentPanel/MoodBar",
	]:
		if not hud.has_node(node_path):
			failures.append("VisualHUD missing node %s" % node_path)

	if not hud.has_signal("resident_requested"):
		failures.append("VisualHUD must expose resident_requested signal")
	if not hud.has_signal("command_requested"):
		failures.append("VisualHUD must expose command_requested signal")

	for method_name in [
		"bind_world",
		"_day_phase_text",
		"_connect_command_buttons",
		"_on_command_button_pressed",
		"_job_text",
		"_household_text",
		"_relationship_text",
		"_memory_text",
		"set_selected_resident",
		"set_simulation_running",
		"set_latest_event",
		"refresh",
	]:
		if not hud.has_method(method_name):
			failures.append("VisualHUD must expose %s()" % method_name)

	hud.free()
	return failures
