extends SceneTree
## Screenshot from an actual Godot rendered scene, not a promotional concept image.
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var scene := load("res://scenes/Main.tscn") as PackedScene
	if scene == null:
		push_error("SCREENSHOT_FAIL: no main scene")
		quit(1)
		return
	var app := scene.instantiate()
	root.add_child(app)
	current_scene = app
	app.start_match(0)
	# Let scene and materials finish initializing and camera settle.
	for i in range(12):
		await process_frame
	var png := root.get_viewport().get_texture().get_image()
	if png == null or png.get_width() < 900:
		push_error("SCREENSHOT_FAIL: invalid render target")
		quit(2)
		return
	var output := OS.get_environment("GITHUB_WORKSPACE") + "/build/arena_capture.png"
	var err := png.save_png(output)
	if err != OK:
		push_error("SCREENSHOT_FAIL: image save returned " + str(err))
		quit(3)
		return
	print("SCREENSHOT_OK ", output, " ", png.get_width(), "x", png.get_height())
	quit(0)
