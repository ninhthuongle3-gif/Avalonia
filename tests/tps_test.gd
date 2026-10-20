extends SceneTree
## Live input, real 3D physics, and actual weapon/target logic. No mock raycasts.
var game
var checks = 0
var failures = 0

func _initialize():
	call_deferred("run")

func check(condition: bool, message: String):
	checks += 1
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func frames(count: int):
	for i in range(count):
		await physics_frame
	await process_frame

func key(code: Key, down: bool):
	var event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)

func mouse(button: MouseButton, down: bool):
	var event = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = down
	Input.parse_input_event(event)

func aim_at(point: Vector3):
	for i in range(4):
		var direction: Vector3 = (point - game.player.camera.global_position).normalized()
		game.player.yaw = atan2(-direction.x, -direction.z)
		game.player.pitch = asin(direction.y)
		game.player.recoil = 0.0
		game.player.sync_look()
		await frames(2)

func fire_at(point: Vector3):
	game.player.fire_timer = 0.0
	await aim_at(point)
	game.player.try_fire(false)

func run():
	game = load("res://scenes/range.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	game.sound.enabled = false
	game.capture_mouse = false
	var p = game.player
	check(not game.started and not p.active, "title waits for Enter")
	key(KEY_ENTER, true)
	key(KEY_ENTER, false)
	await frames(4)
	check(game.started and p.active, "Enter starts 3D drill via input")
	for target in game.targets:
		target.moving = false
	var moving_target = game.targets[4]
	moving_target.moving = true
	var old_target_x: float = moving_target.position.x
	await frames(15)
	check(absf(moving_target.position.x - old_target_x) > 0.1, "tracking target moves in live physics")
	moving_target.moving = false
	moving_target.position = moving_target.origin
	await frames(5)
	check(p.is_on_floor(), "player capsule settles on solid range floor")
	var start: Vector3 = p.position
	key(KEY_W, true)
	await frames(12)
	check(p.position.z < start.z - 0.2, "W moves forward through live physics")
	var walk_speed: float = -p.velocity.z
	key(KEY_SHIFT, true)
	await frames(12)
	check(p.sprinting and -p.velocity.z > walk_speed + 1.0, "Shift accelerates forward sprint")
	check(not p.try_fire(), "sprinting prevents firing")
	mouse(MOUSE_BUTTON_RIGHT, true)
	await frames(18)
	check(p.aiming and not p.sprinting and p.camera.fov < 60, "RMB narrows FOV and cancels sprint")
	check(p.arm.spring_length < 2.0, "aiming brings shoulder camera closer")
	key(KEY_W, false)
	key(KEY_SHIFT, false)
	mouse(MOUSE_BUTTON_RIGHT, false)
	await frames(12)
	key(KEY_Q, true)
	key(KEY_Q, false)
	await frames(24)
	check(p.shoulder < 0 and p.arm.position.x < -0.4, "Q switches camera to left shoulder")
	key(KEY_Q, true)
	key(KEY_Q, false)
	await frames(24)
	check(p.shoulder > 0 and p.arm.position.x > 0.4, "Q restores right shoulder")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var motion = InputEventMouseMotion.new()
	motion.relative = Vector2(18, -12)
	var before_yaw: float = p.yaw
	var before_pitch: float = p.pitch
	Input.parse_input_event(motion)
	await frames(2)
	check(p.yaw < before_yaw and p.pitch > before_pitch, "mouse motion changes camera yaw and pitch")
	motion = InputEventMouseMotion.new()
	motion.relative = Vector2(0, -100000)
	Input.parse_input_event(motion)
	await frames(2)
	check(is_equal_approx(p.pitch, 1.05), "mouse look clamps pitch before camera can flip")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	p.yaw = 0
	p.pitch = 0
	p.sync_look()
	key(KEY_SPACE, true)
	key(KEY_SPACE, false)
	await frames(8)
	check(p.position.y > 0.3, "Space jumps using actual capsule physics")
	await frames(60)
	check(p.is_on_floor(), "jump lands back on solid floor")
	p.position = Vector3(0, 0.05, 7)
	p.velocity = Vector3.ZERO
	p.yaw = 0
	p.pitch = 0
	p.sync_look()
	await frames(5)
	# Insert physical geometry between the camera and pivot to test SpringArm collision.
	var wall = game.Kit.box(game, Vector3(0.62, 1.8, 8.4), Vector3(4, 3.6, 0.25), game.Kit.material(Color.GRAY), true)
	await frames(8)
	check(p.arm.get_hit_length() < 1.5, "camera sphere retracts in front of a rear wall")
	wall.queue_free()
	await frames(8)
	check(p.arm.get_hit_length() > 2.8, "camera extends again after obstruction is removed")
	wall = game.Kit.box(game, Vector3(0.8, 1.8, 7), Vector3(0.2, 3.6, 5), game.Kit.material(Color.GRAY), true)
	await frames(8)
	check(p.arm.position.x < 0.55, "sideways camera sweep keeps shoulder root clear of a side wall")
	wall.queue_free()
	await frames(8)
	# Fire through the gap between barriers; from behind the middle barrier the torso
	# is intentionally protected even though the higher camera can see it.
	p.position = Vector3(3, 0.05, 7)
	await frames(5)
	var target = game.targets[1]
	await fire_at(target.global_position + Vector3.UP * 1.2)
	check(p.last_result.target_hit and not p.last_result.headshot, "camera aim and muzzle ray converge on torso")
	check(is_equal_approx(target.health, 66.0) and p.ammo == 23, "body hit applies damage and consumes one round")
	check(not p.try_fire(false), "fire cooldown rejects shots above configured rate")
	check(p.recoil > 0 and p.bloom > 0 and p.muzzle_flash.visible, "shot produces recoil, spread and muzzle flash")
	await fire_at(target.global_position + Vector3.UP * 1.2)
	await fire_at(target.global_position + Vector3.UP * 1.2)
	check(target.health == 0 and target.collision_layer == 0, "three torso hits drop target and disable its hitbox")
	check(game.kills == 1 and game.drill_targets.has(target.number), "drill records the distinct destroyed target")
	await frames(160)
	check(target.health == 100 and target.collision_layer == 2, "target automatically restores its health and hitbox")
	check(p.recoil == 0 and p.bloom == 0, "recoil and spread recover when not firing")
	await fire_at(target.global_position + Vector3.UP * 1.82)
	check(p.last_result.headshot and target.health == 0 and game.headshots == 1, "headshot drops target in a single shot")
	check(game.drill_targets.size() == 1, "repeated takedown does not count as a new distinct target")
	# A cover panel blocks the barrel while the camera still sees the target above it.
	await frames(160)
	await aim_at(target.global_position + Vector3.UP * 1.82)
	var barrel_position: Vector3 = p.muzzle.global_position
	var cover = game.Kit.box(game, barrel_position + Vector3(0, 0, 0.1), Vector3(0.6, 0.22, 0.15), game.Kit.material(Color.GRAY), true)
	await frames(3)
	p.fire_timer = 0.0
	p.try_fire(false)
	check(p.last_result.blocked and not p.last_result.target_hit, "cover intercepts a shot even when crosshair sees target")
	check(target.health == 100, "barrel obstruction prevents damage through cover")
	cover.queue_free()
	await frames(3)
	# World geometry also stops the player's movement.
	p.position = Vector3(0, 0.05, 1.8)
	p.yaw = 0
	p.pitch = 0
	p.velocity = Vector3.ZERO
	p.sync_look()
	key(KEY_W, true)
	await frames(45)
	key(KEY_W, false)
	check(p.position.z > 1.05, "concrete firing barrier blocks the character capsule")
	p.position = Vector3(3, 0.05, 7)
	p.ammo = 10
	p.reserve = 8
	key(KEY_R, true)
	key(KEY_R, false)
	await frames(3)
	check(p.reload_timer > 0 and not p.try_fire(), "R starts reload and prevents firing")
	key(KEY_ESCAPE, true)
	key(KEY_ESCAPE, false)
	await frames(3)
	var frozen_reload: float = p.reload_timer
	var frozen_target: float = game.targets[0].reset_timer
	await frames(15)
	check(game.paused and p.reload_timer == frozen_reload and game.targets[0].reset_timer == frozen_target, "pause freezes weapon and target simulation")
	key(KEY_ENTER, true)
	key(KEY_ENTER, false)
	await frames(110)
	check(not game.paused and p.ammo == 18 and p.reserve == 0, "resume finishes reload with only available reserve rounds")
	p.ammo = 0
	p.fire_timer = 0.0
	check(not p.try_fire() and p.reload_timer == 0, "empty reserve cannot create ammunition")
	key(KEY_T, true)
	key(KEY_T, false)
	await frames(3)
	check(p.ammo == 24 and p.reserve == 144 and p.shots == 0 and game.hits == 0, "T resets drill stats and replenishes ammo")
	mouse(MOUSE_BUTTON_LEFT, true)
	await frames(24)
	mouse(MOUSE_BUTTON_LEFT, false)
	await frames(2)
	check(p.shots >= 3 and p.ammo <= 21, "held left mouse fires automatically through input dispatch")
	game.reset_drill()
	p.position = Vector3(2, 0.05, -2)
	p.velocity = Vector3.ZERO
	await frames(3)
	for t in game.targets:
		await fire_at(t.global_position + Vector3.UP * 1.82)
	check(game.drill_complete and game.drill_targets.size() == 6, "all six distinct targets complete the drill")
	var completed_time: float = game.elapsed
	await frames(6)
	check(game.elapsed == completed_time, "drill completion freezes the result time")
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await frames(2)
	check(game.paused and not p.active and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "losing application focus pauses and releases the cursor")
	key(KEY_ENTER, true)
	key(KEY_ENTER, false)
	await frames(2)
	check(not game.paused and p.active, "Enter resumes after application focus loss")
	print("TPS RESULT: %d/%d checks passed" % [checks - failures, checks])
	game.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
