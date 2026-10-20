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
	game.auto_waves = false
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
	game.player.shoulder = 1
	game.player.position = Vector3(3, 0.05, 10)
	Input.action_press("tps_forward")
	await frames(30)
	await capture("res://artifacts/tps-walk-v2.png")
	Input.action_press("tps_sprint")
	await frames(34)
	await capture("res://artifacts/tps-sprint-v2.png")
	Input.action_release("tps_forward")
	Input.action_release("tps_sprint")
	await frames(4)
	await capture("res://artifacts/tps-brake-v2.png")
	await frames(55)
	game.player.reset_character()
	game.player.position = Vector3(3, 0.05, 7)
	for at in [Vector3(1.5, 0.05, 2.5), Vector3(4.5, 0.05, 1), Vector3(8, 0.05, -1)]:
		game.spawn_zombie(at)
	Input.action_press("tps_aim")
	await frames(30)
	await capture("res://artifacts/tps-infected-v2.png")
	game.player.ammo = 12
	game.player.begin_reload()
	await frames(28)
	await capture("res://artifacts/tps-reload-v2.png")
	Input.action_release("tps_aim")
	print("VISUAL RESULT: nine rendered views saved")
	quit()
