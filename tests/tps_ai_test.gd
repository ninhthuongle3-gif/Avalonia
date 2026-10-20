extends SceneTree
var game
var checks = 0
var failures = 0

func _initialize():
	call_deferred("run")

func check(ok: bool, message: String):
	checks += 1
	if ok:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func frames(count: int):
	for i in range(count):
		await physics_frame
	await process_frame

func key(code: Key):
	var event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = false
	Input.parse_input_event(event)

func fresh_enemy(at: Vector3):
	game.clear_infected()
	await frames(2)
	return game.spawn_zombie(at)

func until_state(zombie, state: String, limit: int):
	for i in range(limit):
		if zombie.state == state:
			return
		await frames(1)

func shoot_at(point: Vector3):
	for i in range(5):
		var direction: Vector3 = (point - game.player.camera.global_position).normalized()
		game.player.yaw = atan2(-direction.x, -direction.z)
		game.player.pitch = asin(direction.y)
		game.player.recoil = 0
		game.player.sync_look()
		await frames(3)
	game.player.fire_timer = 0
	game.player.try_fire(false)

func run():
	game = load("res://scenes/range.tscn").instantiate()
	root.add_child(game)
	game.auto_waves = false
	game.sound.enabled = false
	game.begin_game(false)
	var p = game.player
	p.position = Vector3(3, 0.05, 9)
	await frames(8)
	var wall = game.Kit.box(game, Vector3(3, 1.5, 5), Vector3(4, 3, 1), game.Kit.material(Color.GRAY), true)
	game.rebuild_navigation()
	var z = game.spawn_zombie(Vector3(3, 0.05, 1.5))
	await frames(8)
	check(not z.line_of_sight() and z.state == "patrol", "solid cover blocks perception instead of granting wall vision")
	var route: Array = game.get_route(z.position, p.position)
	check(route.size() > 4, "pathfinder produces a route around cover")
	var route_clear = true
	for point in route:
		if point.x > 0.6 and point.x < 5.4 and point.z > 4.1 and point.z < 5.9:
			route_clear = false
	check(route_clear, "navigation route respects expanded capsule clearance")
	z.hear_shot(p.position)
	check(z.state == "investigate" and z.memory > 0, "nearby gunfire starts investigation of the last heard location")
	var detour = false
	for i in range(360):
		await frames(1)
		if absf(z.position.x - 3) > 2.2:
			detour = true
		if z.position.z > 6.3:
			break
	check(detour and z.position.z > 6.3, "actual zombie capsule follows the detour and reaches the far side of cover")
	check(z.memory > 0 and z.state == "chase", "reacquired line of sight switches investigation to pursuit")
	wall.queue_free()
	await frames(2)
	game.rebuild_navigation()
	p.position = Vector3(3, 0.05, 10)
	p.health = 100
	p.hurt_timer = 0
	z = await fresh_enemy(Vector3(3, 0.05, 9))
	await frames(4)
	check(z.state == "windup" and p.health == 100, "melee enters a visible windup before applying damage")
	await frames(20)
	check(p.health == 100 and z.visual_attack > 0.2, "attack animation progresses without early damage")
	await frames(20)
	check(p.health == 82 and z.attacks == 1 and z.state == "recover", "completed swing damages once and enters recovery")
	check(not p.take_damage(18) and p.health == 82, "damage grace period prevents overlapping instant hits")
	game.set_paused(true)
	var frozen: float = z.attack_timer
	var age: float = z.age
	await frames(12)
	check(z.attack_timer == frozen and z.age == age, "pause freezes enemy attack and perception clocks")
	game.set_paused(false)
	await until_state(z, "windup", 100)
	var before_health: float = p.health
	p.position.x += 4
	await frames(40)
	check(p.health == before_health, "moving out of range during windup avoids the strike")
	p.position = Vector3(3, 0.05, 10)
	z = await fresh_enemy(Vector3(3, 0.05, 9))
	await frames(4)
	wall = game.Kit.box(game, Vector3(3, 1, 9.5), Vector3(2, 2, 0.1), game.Kit.material(Color.GRAY), true)
	before_health = p.health
	await frames(40)
	check(p.health == before_health and z.attacks == 0, "wall introduced during windup blocks the actual strike")
	wall.queue_free()
	await frames(2)
	z = await fresh_enemy(Vector3(3, 0.05, 9))
	await frames(4)
	z.take_hit(z.position + Vector3.UP * 1.1)
	check(z.state == "stagger" and z.health == 66, "body hit interrupts attack with stagger and real damage")
	before_health = p.health
	await frames(20)
	check(p.health == before_health, "stagger cancels the interrupted strike")
	game.clear_infected()
	p.position = Vector3(3, 0.05, 7)
	p.yaw = 0
	p.body_yaw = 0
	p.velocity = Vector3.ZERO
	Input.action_press("tps_aim")
	await frames(30)
	z = game.spawn_zombie(Vector3(3, 0.05, 1.5))
	z.set_physics_process(false)
	await frames(2)
	await shoot_at(z.position + Vector3.UP * 1.1)
	check(p.last_result.target_hit and z.health == 66 and not p.last_result.headshot, "real muzzle ray hits and damages the zombie capsule torso")
	await shoot_at(z.position + Vector3.UP * 1.65)
	check(p.last_result.headshot and z.health == 0 and z.state == "dead", "headshot kills the actual zombie hitbox")
	check(z.collision_layer == 0 and game.infected_kills == 1 and game.drill_targets.is_empty(), "corpse stops colliding and enemy elimination stays separate from training targets")
	var kills: int = game.infected_kills
	z.take_hit(z.position + Vector3.UP * 1.65)
	check(game.infected_kills == kills, "dead enemy cannot award another elimination")
	Input.action_release("tps_aim")
	game.clear_infected()
	p.health = 100
	p.hurt_timer = 0
	p.take_damage(100)
	check(game.dead and game.paused and not p.active, "lethal attack enters defeat and releases gameplay control")
	key(KEY_ESCAPE)
	await frames(2)
	check(game.paused and game.dead, "Escape cannot resume simulation after defeat")
	key(KEY_ENTER)
	await frames(4)
	check(not game.dead and not game.paused and p.health == 100 and p.ammo == 24, "Enter restarts defeat with restored health and ammunition")
	game.auto_waves = true
	game.wave_delay = 0
	await frames(4)
	check(game.wave == 1 and game.alive_infected() == 4, "survival session starts its first four-enemy wave")
	for expected_wave in [2, 3]:
		for enemy in game.zombies:
			if is_instance_valid(enemy) and enemy.health > 0:
				enemy.take_hit(enemy.position + Vector3.UP * 1.65)
		game.wave_delay = 0
		await frames(4)
		check(game.wave == expected_wave and game.alive_infected() == 2 + expected_wave * 2, "clearing enemies advances to wave %d" % expected_wave)
	var runners = 0
	for enemy in game.zombies:
		if is_instance_valid(enemy) and enemy.health > 0 and enemy.kind == "runner":
			runners += 1
	check(runners > 0, "later waves include faster runner AI")
	for enemy in game.zombies:
		if is_instance_valid(enemy) and enemy.health > 0:
			enemy.take_hit(enemy.position + Vector3.UP * 1.65)
	game.wave_delay = 0
	await frames(4)
	check(game.combat_complete and game.paused and game.infected_kills == 18, "three cleared waves finish the survival session")
	key(KEY_F2)
	await frames(4)
	check(not game.combat_mode and game.alive_infected() == 0 and not game.combat_complete, "F2 returns to a clean training range without enemies")
	print("AI RESULT: %d/%d checks passed" % [checks - failures, checks])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
