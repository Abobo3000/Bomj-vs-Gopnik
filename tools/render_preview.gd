extends SceneTree
## Capture three frames from a real Godot render. No AI-generated images.
func _initialize() -> void:
	call_deferred("_capture")

func _settle(frames: int = 12) -> void:
	for i in range(frames):
		await process_frame

func _save(name: String) -> void:
	var texture := root.get_viewport().get_texture()
	if texture == null:
		push_error("SCREENSHOT_FAIL: null viewport")
		quit(2)
		return
	var png := texture.get_image()
	var output := OS.get_environment("GITHUB_WORKSPACE") + "/build/" + name
	if png == null or png.get_width() < 900:
		push_error("SCREENSHOT_FAIL: viewport too small")
		quit(2)
		return
	var err := png.save_png(output)
	if err != OK:
		push_error("SCREENSHOT_FAIL: PNG write failed " + str(err))
		quit(3)
		return
	print("SCREENSHOT_OK ", output, " ", png.get_width(), "x", png.get_height())

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
	await _settle(14)
	_save("fight_bomj.png")
	app.start_match(1)
	await _settle(14)
	_save("fight_gopnik.png")
	app.start_match(0)
	app.player.position.x = -2.6
	app.cpu.position.x = 0.7
	app.player.energy = 100.0
	app.player.try_action("special1")
	app.player.action_time = 0.48
	app.player._pose()
	app._on_strike(app.player, "special1")
	await _settle(3)
	_save("fire_special.png")
	quit(0)
