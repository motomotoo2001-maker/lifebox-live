extends SceneTree

const SHOWCASE_SCENE := "res://scenes/debug/live_showcase.tscn"

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var packed := load(SHOWCASE_SCENE)
	if packed == null:
		push_error("Could not load live debug showcase")
		quit(1)
		return

	var scene = packed.instantiate()
	root.add_child(scene)

	for index in range(180):
		await process_frame

	if not scene.has_meta("showcase_ready"):
		push_error("Live showcase script did not finish building runtime UI")
		quit(1)
		return

	await RenderingServer.frame_post_draw

	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Could not capture live showcase viewport")
		quit(1)
		return

	var output := "res://lifebox_live_showcase.png"
	var error := image.save_png(output)
	print("LIVE_SHOWCASE_CAPTURE_PATH=", ProjectSettings.globalize_path(output))
	quit(0 if error == OK else 1)
