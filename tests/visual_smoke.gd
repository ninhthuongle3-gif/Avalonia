extends SceneTree
## Render a reproducible combat vignette using the actual running game.
var game
var frames = 0
var captured = false

func _initialize():
	call_deferred("begin")

func begin():
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.test_mode = true
	game.sound.enabled = false
	game.start_game()
	game.spawn_left = 0
	game.spawn_enemy(845, 280, 12)
	game.spawn_enemy(1040, 130, 29)
	game.spawn_enemy(1170, 130, 34)
	game.spawn_enemy(1310, 130, 38)
	game.aim_world = Vector2(845, 573)
	game.input_move = 1
	game.input_fire = true

func _process(_dt):
	if not is_instance_valid(game):
		return false
	frames += 1
	if frames == 24:
		game.input_move = 0
	if frames == 45:
		game.input_fire = false
		game.begin_reload()
	if frames == 85:
		game.input_shield = true
	if frames == 160:
		game.input_shield = false
		game.input_move = -1
	if frames == 190:
		game.jump_buffer = 0.12
	if frames == 210:
		game.input_move = 0
		game.input_fire = true
	if frames == 20 and not captured:
		captured = true
		capture()
	if frames >= 240:
		quit()
	return false

func capture():
	await RenderingServer.frame_post_draw
	var error = root.get_texture().get_image().save_png("res://artifacts/combat.png")
	if error != OK:
		push_error("Could not save rendered combat screenshot")
		quit(1)
