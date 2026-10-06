extends RefCounted

const SHOWCASE_SCENE := "res://scenes/debug/visual_showcase.tscn"
const HUD_SCENE := "res://scenes/ui/visual_hud.tscn"

func run() -> Array[String]:
	var failures: Array[String] = []

	var showcase_scene = load(SHOWCASE_SCENE)
	if showcase_scene == null:
		failures.append("Playable save/load requires visual showcase scene")
		return failures

	var showcase = showcase_scene.instantiate()
	if showcase == null:
		failures.append("Visual showcase must instantiate for save/load contract")
		return failures

	for method_name in [
		"quick_save",
		"quick_load",
		"has_quicksave",
		"_connect_persistence_ui",
		"_refresh_save_availability",
	]:
		if not showcase.has_method(method_name):
			failures.append("Visual showcase must expose %s()" % method_name)

	showcase.free()

	var hud_scene = load(HUD_SCENE)
	if hud_scene == null:
		failures.append("Save/load contract requires VisualHUD scene")
		return failures

	var hud = hud_scene.instantiate()
	if hud == null:
		failures.append("VisualHUD must instantiate for save/load contract")
		return failures

	for signal_name in ["save_requested", "load_requested"]:
		if not hud.has_signal(signal_name):
			failures.append("VisualHUD must expose %s signal" % signal_name)

	for node_path in [
		"EventPanel/SaveButton",
		"EventPanel/LoadButton",
	]:
		if not hud.has_node(node_path):
			failures.append("VisualHUD missing persistence control %s" % node_path)

	if not hud.has_method("set_save_available"):
		failures.append("VisualHUD must expose set_save_available()")

	hud.free()
	return failures
