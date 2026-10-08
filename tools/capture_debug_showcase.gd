extends SceneTree

const SHOWCASE_SCENE := "res://scenes/debug/showcase.tscn"

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var packed := load(SHOWCASE_SCENE)
	if packed == null:
		push_error("Could not load debug showcase scene")
		quit(1)
		return

	var scene = packed.instantiate()
	root.add_child(scene)

	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Could not capture debug showcase viewport")
		quit(1)
		return

	var output := "user://lifebox_debug_showcase.png"
	var error := image.save_png(output)
	print("SHOWCASE_CAPTURE_PATH=", ProjectSettings.globalize_path(output))
	quit(0 if error == OK else 1)
