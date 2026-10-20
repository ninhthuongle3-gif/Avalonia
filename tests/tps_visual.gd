extends SceneTree
## Run with an actual OpenGL display; verifies that screenshots contain rendered pixels.
var game

func _initialize():
	call_deferred("run")

func frames(count: int):
	for i in range(count):
		await physics_frame
	await process_frame

func capture(path: String):
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	if image.is_empty() or image.get_pixel(image.get_width() / 2, image.get_height() / 2).a == 0:
		push_error("Missing rendered frame")
		quit(1)
		return
	var result = image.save_png(path)
	if result != OK:
		push_error("Failed to save " + path)
		quit(1)
	print("RENDERED: " + path)

func run():
	game = load("res://scenes/range.tscn").instantiate()
	root.add_child(game)
	game.sound.enabled = false
	await frames(8)
	await capture("res://artifacts/tps-title.png")
	game.begin_game(false)
	await frames(30)
	await capture("res://artifacts/tps-range.png")
	Input.action_press("tps_aim")
	await frames(30)
	await capture("res://artifacts/tps-aim.png")
	game.player.shoulder = -1
	await frames(30)
	await capture("res://artifacts/tps-left.png")
	Input.action_release("tps_aim")
	print("VISUAL RESULT: four rendered views saved")
	quit()
