extends SceneTree
## Exercise input dispatch and the live physics loop, rather than calling fire/reload directly.
var game
var failures = 0
var checks = 0

func _initialize():
	call_deferred("run")

func check(condition: bool, message: String):
	checks += 1
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func key(code: Key, down: bool):
	var event = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)

func mouse(button: MouseButton, down: bool):
	var event = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = down
	event.position = Vector2(900, 530)
	Input.parse_input_event(event)

func frames(count: int):
	for i in range(count):
		await physics_frame
	await process_frame

func run():
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(2)
	game.sound.enabled = false
	check(not game.started, "title screen waits for input")
	key(KEY_ENTER, true)
	key(KEY_ENTER, false)
	await frames(3)
	check(game.started, "Enter input starts game through event handler")
	game.spawn_left = 0
	var start_x = game.player.position.x
	key(KEY_D, true)
	await frames(12)
	check(game.player.position.x > start_x + 10, "held D moves player in live physics loop")
	key(KEY_D, false)
	await frames(12)
	check(absf(game.velocity.x) < 0.1, "D release stops player in live physics loop")
	key(KEY_SPACE, true)
	key(KEY_SPACE, false)
	await frames(10)
	check(game.player.airborne and game.player.position.y < 690, "Space dispatch triggers jump")
	mouse(MOUSE_BUTTON_LEFT, true)
	await frames(15)
	mouse(MOUSE_BUTTON_LEFT, false)
	check(game.ammo < 24 and game.shots_fired >= 2, "held left mouse automatically fires multiple shots")
	mouse(MOUSE_BUTTON_RIGHT, true)
	await frames(3)
	check(game.player.shielding, "right mouse raises shield")
	mouse(MOUSE_BUTTON_RIGHT, false)
	await frames(3)
	key(KEY_R, true)
	key(KEY_R, false)
	await frames(3)
	check(game.reload_timer > 0, "R dispatch starts reload")
	key(KEY_ESCAPE, true)
	key(KEY_ESCAPE, false)
	await frames(3)
	var frozen = game.reload_timer
	await frames(8)
	check(game.paused and game.reload_timer == frozen, "Esc pauses live simulation")
	key(KEY_ESCAPE, true)
	key(KEY_ESCAPE, false)
	await frames(3)
	check(not game.paused and game.reload_timer < frozen, "Esc resumes live simulation")
	key(KEY_F1, true)
	key(KEY_F1, false)
	await frames(3)
	check(game.help_open and game.paused, "F1 opens help and pauses")
	key(KEY_ESCAPE, true)
	key(KEY_ESCAPE, false)
	key(KEY_V, true)
	key(KEY_V, false)
	await frames(3)
	check(game.reduced_motion, "V toggles reduced motion")
	print("INPUT RESULT: %d/%d checks passed" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)
