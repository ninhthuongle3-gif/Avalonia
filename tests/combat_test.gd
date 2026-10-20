extends SceneTree
var failures = 0
var checks = 0
var game

func _initialize():
	call_deferred("run")

func check(condition: bool, message: String):
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)

func reset():
	game.start_game()
	game.spawn_left = 0
	game.test_mode = true
	game.sound.enabled = false
	game.input_move = 0
	game.input_fire = false
	game.input_shield = false
	game.input_sprint = false
	game.aim_world = Vector2(1000, 595)
	game.reduced_motion = true

func advance(seconds: float):
	for i in range(ceili(seconds * 60)):
		game.tick(1.0 / 60.0)

func run():
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	reset()
	game.input_move = 1
	advance(0.5)
	check(game.player.position.x > 570 and game.velocity.x == 210, "walk accelerates to configured speed")
	game.input_move = 0
	advance(0.2)
	check(absf(game.velocity.x) < 0.1, "release stops movement without sliding")
	game.input_move = 1
	game.input_sprint = true
	advance(0.5)
	check(game.velocity.x == 315, "sprint is faster than walk")
	game.input_shield = true
	advance(0.3)
	check(game.player.shielding and game.velocity.x == 88, "shield limits sprint and movement speed")
	reset()
	game.jump_buffer = 0.12
	advance(0.2)
	check(game.player.position.y < 650 and game.player.airborne, "buffered jump leaves the ground")
	advance(0.7)
	check(game.player.position.y == 700 and not game.player.airborne, "jump lands without penetrating ground")
	reset()
	game.input_move = -1
	advance(3)
	check(game.player.position.x >= 45, "world boundary prevents walking out of map")
	reset()
	var enemy = game.spawn_enemy(820, 96, 0)
	game.aim_world = Vector2(815, 572)
	check(game.fire(), "loaded rifle fires")
	check(game.ammo == 23 and game.shots_fired == 1, "firing consumes exactly one round")
	check(enemy.hp == 24 and game.head_marker, "head hit deals critical damage")
	check(enemy.stun > 0 and enemy.push > 0, "bullet causes stagger and knockback")
	check(not game.fire() and game.ammo == 23, "fire-rate cooldown prevents duplicate shots")
	game.fire_timer = 0
	game.shot_spread = 0
	game.fire()
	check(enemy.hp <= 0 and game.kills == 1, "second headshot kills and counts elimination once")
	check(game.hits == 2 and game.tracers.size() == 2, "hit feedback records both actual ray hits")
	game.fire_timer = 0
	game.fire()
	check(game.kills == 1, "corpse cannot be killed again")
	reset()
	var near_enemy = game.spawn_enemy(760, 100, 0)
	var far_enemy = game.spawn_enemy(960, 100, 0)
	game.aim_world = Vector2(1200, 600)
	game.fire()
	check(near_enemy.hp == 64 and far_enemy.hp == 100, "nearest body blocks a bullet from hitting an enemy behind it")
	reset()
	game.ammo = 5
	check(game.begin_reload(), "partial magazine starts reload")
	check(not game.fire(), "reload prevents firing")
	advance(1.8)
	check(game.ammo == 24 and game.reload_timer == 0, "reload finishes and refills magazine")
	check(not game.begin_reload(), "full magazine cannot reload")
	game.ammo = 0
	game.fire_timer = 0
	check(not game.fire() and game.reload_timer > 0, "empty magazine triggers automatic reload")
	reset()
	game.input_shield = true
	advance(0.02)
	game.player.facing = 1
	var old_stamina = game.stamina
	check(not game.take_damage(16, game.player.position + Vector2(60, 0)), "shield blocks frontal melee hit")
	check(game.health == 100 and game.stamina < old_stamina and game.blocked_hits == 1, "block spends stamina instead of health")
	check(not game.fire(), "shield prevents shooting")
	game.invulnerability = 0
	check(game.take_damage(16, game.player.position - Vector2(60, 0)), "shield does not block attacks from behind")
	check(game.health == 84 and game.damage_flash > 0, "unblocked damage triggers health loss and feedback")
	check(not game.take_damage(16, game.player.position - Vector2(60, 0)) and game.health == 84, "damage grace period prevents overlapping instant hits")
	reset()
	game.spawn_enemy(game.player.position.x + 60, 100, 0)
	advance(0.55)
	check(game.health == 100, "zombie attack is telegraphed before damage")
	advance(0.4)
	check(game.health == 84, "completed zombie attack damages player")
	reset()
	game.ammo = 5
	game.begin_reload()
	game.paused = true
	var previous_time = game.reload_timer
	advance(0.5)
	check(game.reload_timer == previous_time and game.elapsed == 0, "pause freezes gameplay and reload")
	game.paused = false
	advance(4.2)
	check(game.wave == 2 and game.spawn_left > 0, "cleared wave progresses and schedules next enemies")
	reset()
	game.health = 1
	game.take_damage(16, game.player.position + Vector2(70, 0))
	advance(0.02)
	check(game.game_over and game.health == 0, "lethal hit ends the run")
	game.start_game()
	check(not game.game_over and game.health == 100 and game.enemies.is_empty(), "restart clears corpses, enemies and death state")
	print("RESULT: %d/%d checks passed" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)
