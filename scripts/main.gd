extends Node2D
## Fixed-timestep combat simulation. Visual hit stop never changes Engine.time_scale.
const Actor = preload("res://scripts/actor.gd")
const Scenery = preload("res://scripts/environment.gd")
const Sound = preload("res://scripts/sound.gd")
const HUD = preload("res://scripts/hud.gd")
const GROUND = 700.0
const MAGAZINE = 24
const RELOAD_TIME = 1.65
const WORLD_LEFT = 0.0
const WORLD_RIGHT = 3300.0

var stage: Node2D
var player: Node2D
var scenery: Node2D
var sound: Node
var hud: Control
var enemies: Array = []
var particles: Array = []
var tracers: Array = []
var impacts: Array = []
var velocity = Vector2.ZERO
var camera_x = 0.0
var aim_world = Vector2(1000, 590)
var health = 100.0
var stamina = 100.0
var ammo = MAGAZINE
var reload_timer = 0.0
var fire_timer = 0.0
var invulnerability = 0.0
var shot_spread = 0.0
var shake = 0.0
var hit_stop = 0.0
var hit_marker = 0.0
var head_marker = false
var damage_flash = 0.0
var kills = 0
var shots_fired = 0
var hits = 0
var blocked_hits = 0
var wave = 1
var spawn_left = 0
var spawn_timer = 0.0
var wave_wait = 0.0
var wave_banner = 0.0
var elapsed = 0.0
var foot_timer = 0.0
var coyote = 0.0
var jump_buffer = 0.0
var started = false
var paused = false
var game_over = false
var help_open = false
var reduced_motion = false
var test_mode = false
var input_move = 0.0
var input_fire = false
var input_shield = false
var input_sprint = false
var rng = RandomNumberGenerator.new()
var screenshot_path = ""

func _ready():
	rng.seed = 7216
	stage = Node2D.new()
	stage.show_behind_parent = true
	add_child(stage)
	scenery = Scenery.new()
	stage.add_child(scenery)
	player = Actor.new()
	player.position = Vector2(920, GROUND)
	player.scale = Vector2(1.6, 1.6)
	stage.add_child(player)
	sound = Sound.new()
	add_child(sound)
	var canvas = CanvasLayer.new()
	add_child(canvas)
	hud = HUD.new()
	hud.game = self
	canvas.add_child(hud)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			screenshot_path = arg.trim_prefix("--screenshot=")
		if arg == "--demo":
			start_game()
	if not screenshot_path.is_empty():
		capture_later()

func capture_later():
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(screenshot_path)
	get_tree().quit()

func start_game():
	started = true
	paused = false
	game_over = false
	help_open = false
	health = 100
	stamina = 100
	ammo = MAGAZINE
	reload_timer = 0
	fire_timer = 0
	invulnerability = 0
	velocity = Vector2.ZERO
	player.position = Vector2(490, GROUND)
	player.scale = Vector2.ONE
	player.airborne = false
	player.death = 0
	player.shielding = false
	player.reload_progress = -1
	player.motion = 0
	camera_x = 0
	kills = 0
	shots_fired = 0
	hits = 0
	blocked_hits = 0
	elapsed = 0
	shot_spread = 0
	coyote = 0
	jump_buffer = 0
	foot_timer = 0
	damage_flash = 0
	shake = 0
	hit_stop = 0
	for enemy in enemies:
		enemy.actor.queue_free()
	enemies.clear()
	particles.clear()
	tracers.clear()
	impacts.clear()
	wave = 1
	begin_wave()

func begin_wave():
	spawn_left = 4 + wave * 2
	spawn_timer = 0.7
	wave_wait = 0.0
	wave_banner = 3.0

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ENTER:
				if not started or game_over:
					start_game()
			KEY_ESCAPE:
				if started and not game_over:
					paused = not paused
					help_open = false
			KEY_F1:
				if started and not game_over:
					help_open = not help_open
					paused = help_open
			KEY_R:
				if started and not paused and not game_over:
					begin_reload()
			KEY_SPACE:
				if started and not paused and not game_over:
					jump_buffer = 0.12
			KEY_M:
				sound.enabled = not sound.enabled
			KEY_V:
				reduced_motion = not reduced_motion
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not started or game_over:
			if Rect2(88, 625, 290, 54).has_point(get_global_mouse_position()) or game_over:
				start_game()
		elif paused and not help_open:
			paused = false

func _physics_process(dt):
	if not test_mode:
		input_move = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
		input_fire = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		input_shield = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		input_sprint = Input.is_physical_key_pressed(KEY_SHIFT)
		aim_world = get_global_mouse_position() + Vector2(camera_x, 0)
	tick(dt)

func tick(dt: float):
	hit_marker = maxf(0, hit_marker - dt)
	damage_flash = maxf(0, damage_flash - dt * 1.7)
	shake = move_toward(shake, 0, dt * 24)
	update_effects(dt)
	if not started or paused or game_over:
		player.set_process(not paused)
		for enemy in enemies:
			enemy.actor.set_process(not paused)
		if started:
			update_camera(dt)
		else:
			camera_x = 0
			stage.position = Vector2.ZERO
			scenery.camera_x = 0
		queue_redraw()
		return
	player.set_process(true)
	for enemy in enemies:
		enemy.actor.set_process(true)
	if hit_stop > 0 and not reduced_motion:
		hit_stop -= dt
		update_camera(dt)
		queue_redraw()
		return
	elapsed += dt
	wave_banner = maxf(0, wave_banner - dt)
	fire_timer = maxf(0, fire_timer - dt)
	invulnerability = maxf(0, invulnerability - dt)
	shot_spread = move_toward(shot_spread, 0, dt * 0.12)
	# Shield changes locomotion and prevents firing; stamina discourages holding forever.
	player.shielding = input_shield and stamina > 2 and reload_timer <= 0
	if player.shielding:
		stamina = maxf(0, stamina - dt * 7)
	else:
		stamina = minf(100, stamina + dt * 19)
	var speed = 88.0 if player.shielding else (315.0 if input_sprint and not input_fire and reload_timer <= 0 else 210.0)
	var acceleration = 1750.0 if player.position.y >= GROUND else 850.0
	velocity.x = move_toward(velocity.x, input_move * speed, acceleration * dt)
	if player.position.y >= GROUND:
		coyote = 0.1
	else:
		coyote = maxf(0, coyote - dt)
	jump_buffer = maxf(0, jump_buffer - dt)
	if jump_buffer > 0 and coyote > 0:
		velocity.y = -480
		jump_buffer = 0
		coyote = 0
		player.airborne = true
	velocity.y += 1450 * dt
	player.position += velocity * dt
	player.position.x = clampf(player.position.x, WORLD_LEFT + 45, WORLD_RIGHT - 45)
	if player.position.y >= GROUND:
		if player.airborne:
			burst(player.position, 8, Color("8a9482"), 0.5, Vector2(0, -40))
			sound.play("step", -3, 0.7)
		player.position.y = GROUND
		velocity.y = 0
		player.airborne = false
	player.motion = velocity.x
	player.facing = 1.0 if aim_world.x >= player.position.x else -1.0
	update_aim()
	if absf(velocity.x) > 40 and not player.airborne:
		foot_timer -= dt
		if foot_timer <= 0:
			foot_timer = 0.27 if speed > 250 else 0.36
			sound.play("step", -8, rng.randf_range(0.85, 1.15))
			burst(player.position + Vector2(0, -2), 2, Color("7d8a7c"), 0.3, Vector2(-velocity.x * 0.15, -20))
	if reload_timer > 0:
		var old_timer = reload_timer
		reload_timer = maxf(0, reload_timer - dt)
		player.reload_progress = 1.0 - reload_timer / RELOAD_TIME
		if old_timer > 0.4 and reload_timer <= 0.4:
			sound.play("rack")
		if reload_timer <= 0:
			ammo = MAGAZINE
			player.reload_progress = -1
	if input_fire and fire_timer <= 0 and not player.shielding:
		fire()
	update_enemies(dt)
	if health <= 0:
		game_over = true
		player.death = 1
		player.motion = 0
		player.shielding = false
		player.reload_progress = -1
	update_waves(dt)
	update_camera(dt)
	queue_redraw()

func update_camera(dt):
	var look = clampf((aim_world.x - player.position.x) * 0.16, -95, 145)
	var target = clampf(player.position.x - 500 + look, 0, WORLD_RIGHT - 1440)
	camera_x = lerpf(camera_x, target, 1 - exp(-dt * 5.5))
	var offset = Vector2.ZERO if reduced_motion else Vector2(rng.randf_range(-shake, shake), rng.randf_range(-shake, shake) * 0.55)
	stage.position = Vector2(-camera_x, 0) + offset
	scenery.camera_x = camera_x
	# Keep corpses behind the living and player, preserving the shield silhouette.
	player.z_index = 4

func begin_reload() -> bool:
	if reload_timer > 0 or ammo == MAGAZINE or game_over or player.shielding:
		return false
	reload_timer = RELOAD_TIME
	player.reload_progress = 0
	sound.play("reload")
	return true

func muzzle_position() -> Vector2:
	return player.position + Vector2(0, -104) + Vector2(cos(player.aim) * player.facing, sin(player.aim)) * 81

func update_aim():
	var to_aim = aim_world - (player.position + Vector2(0, -104))
	player.facing = 1.0 if to_aim.x >= 0 else -1.0
	player.aim = clampf(atan2(to_aim.y, absf(to_aim.x)), -1.2, 1.15)

func fire() -> bool:
	if reload_timer > 0 or player.shielding or game_over or fire_timer > 0:
		return false
	if ammo <= 0:
		begin_reload()
		return false
	update_aim()
	ammo -= 1
	shots_fired += 1
	fire_timer = 0.112
	player.recoil = 1
	player.flash = 0.045
	shot_spread = minf(shot_spread + 0.007, 0.045)
	shake = maxf(shake, 2.8)
	sound.play("shot", 0, rng.randf_range(0.94, 1.06))
	var origin = muzzle_position()
	# Rays originate at the muzzle; close targets cannot be hit through the player's body.
	var direction = Vector2(cos(player.aim) * player.facing, sin(player.aim)).rotated(rng.randf_range(-shot_spread, shot_spread))
	var endpoint = origin + direction * 1400
	var best = 1400.0
	var target = null
	var headshot = false
	for enemy in enemies:
		if enemy.hp <= 0:
			continue
		for zone in ["body", "head"]:
			var center = enemy.actor.position + Vector2(5 * enemy.actor.facing, -88 if zone == "body" else -128)
			var radius = 28.0 if zone == "body" else 17.0
			var along = (center - origin).dot(direction)
			var perpendicular_sq = (center - origin).length_squared() - along * along
			if perpendicular_sq <= radius * radius:
				var entry = along - sqrt(maxf(0, radius * radius - perpendicular_sq))
				if entry >= 0 and entry < best:
					best = entry
					target = enemy
					headshot = zone == "head"
	if target != null:
		endpoint = origin + direction * best
		damage_enemy(target, 72 if headshot else 36, headshot, direction)
		hits += 1
		hit_marker = 0.16
		head_marker = headshot
		burst(endpoint, 12 if headshot else 7, Color("9a5545"), 0.65, direction * 130 + Vector2(0, -55))
		impacts.append({"pos": endpoint, "life": 0.35, "text": "CRITICAL" if headshot else "", "head": headshot})
	else:
		burst(endpoint, 4, Color("c0b28c"), 0.3, -direction * 35)
	tracers.append({"from": origin, "to": endpoint, "life": 0.065})
	# Brass exits the receiver, has gravity, bounces once, and fades.
	particles.append({"pos": origin - direction * 54, "vel": Vector2(-player.facing * rng.randf_range(50, 110), -rng.randf_range(130, 220)), "life": 1.6, "max": 1.6, "color": Color("d1ad61"), "size": 3.0, "brass": true})
	return true

func spawn_enemy(x: float, hp = 100.0, speed = 42.0):
	var actor = Actor.new()
	actor.zombie = true
	actor.variant = rng.randi_range(0, 2)
	actor.position = Vector2(x, GROUND)
	actor.phase = rng.randf_range(0, TAU)
	actor.z_index = 3
	stage.add_child(actor)
	var enemy = {"actor": actor, "hp": hp, "speed": speed, "stun": 0.0, "push": 0.0, "cooldown": 0.4, "windup": -1.0, "corpse": 0.0}
	enemies.append(enemy)
	return enemy

func damage_enemy(enemy: Dictionary, damage: float, headshot: bool, direction: Vector2):
	enemy.hp -= damage
	enemy.stun = 0.27 if headshot else 0.17
	enemy.push = direction.x * (180 if headshot else 100)
	enemy.actor.hurt = 1
	enemy.windup = -1
	hit_stop = 0.045 if headshot else 0.018
	shake = maxf(shake, 5 if headshot else 3)
	if enemy.hp <= 0:
		kills += 1
		enemy.actor.z_index = 1
		enemy.actor.motion = 0
		enemy.corpse = 6.0
		sound.play("kill", -2, rng.randf_range(0.8, 1.1))
	else:
		sound.play("hit", -2, rng.randf_range(0.9, 1.2))

func update_enemies(dt):
	for i in range(enemies.size() - 1, -1, -1):
		var e = enemies[i]
		var actor = e.actor
		if e.hp <= 0:
			e.corpse -= dt
			actor.death = minf(1, actor.death + dt * 4)
			actor.position.x += e.push * dt
			e.push = move_toward(e.push, 0, dt * 420)
			actor.modulate.a = clampf(e.corpse, 0, 1)
			if e.corpse <= 0:
				actor.queue_free()
				enemies.remove_at(i)
			continue
		actor.facing = 1 if player.position.x > actor.position.x else -1
		e.cooldown = maxf(0, e.cooldown - dt)
		e.stun = maxf(0, e.stun - dt)
		actor.position.x += e.push * dt
		e.push = move_toward(e.push, 0, dt * 600)
		var distance = absf(player.position.x - actor.position.x)
		actor.motion = 0
		actor.attack = 0
		if e.stun > 0:
			continue
		if e.windup >= 0:
			e.windup += dt
			actor.attack = sin(clampf(e.windup / 0.48, 0, 1) * PI)
			if e.windup >= 0.48:
				if distance < 83 and player.position.y > GROUND - 90:
					take_damage(16, actor.position)
				e.windup = -1
				e.cooldown = 1.0
		elif distance < 68 and e.cooldown <= 0:
			e.windup = 0
		elif distance > 54:
			var move = actor.facing * e.speed
			actor.position.x += move * dt
			actor.motion = move
		# Mild separation keeps multiple enemies readable without allowing corpses to block.
		for other in enemies:
			if other == e or other.hp <= 0:
				continue
			var dx = actor.position.x - other.actor.position.x
			if absf(dx) < 24 and absf(dx) > 0.01:
				actor.position.x += signf(dx) * dt * 12

func take_damage(amount: float, source: Vector2) -> bool:
	if invulnerability > 0 or game_over:
		return false
	var from_front = (source.x - player.position.x) * player.facing > 0
	if player.shielding and from_front and stamina >= 14:
		stamina -= 14
		blocked_hits += 1
		shake = maxf(shake, 4)
		invulnerability = 0.3
		sound.play("shield")
		burst(player.position + Vector2(player.facing * 40, -95), 14, Color("c7d8c1"), 0.45, Vector2(player.facing * 140, -100))
		return false
	health = maxf(0, health - amount)
	invulnerability = 0.65
	player.hurt = 1
	damage_flash = 0.65
	shake = 9
	velocity.x = signf(player.position.x - source.x) * 150
	sound.play("hurt")
	burst(player.position + Vector2(0, -100), 9, Color("ad6555"), 0.6, Vector2(0, -90))
	return true

func update_waves(dt):
	if spawn_left > 0:
		spawn_timer -= dt
		if spawn_timer <= 0:
			var right = rng.randf() > 0.18 or wave == 1
			var x = camera_x + 1530 if right else camera_x - 90
			x = clampf(x, -100, WORLD_RIGHT + 100)
			spawn_enemy(x, 90 + wave * 6, rng.randf_range(36, 51) + wave * 3)
			spawn_left -= 1
			spawn_timer = maxf(0.6, 2.0 - wave * 0.1) + rng.randf_range(0, 0.6)
	elif living_enemies() == 0:
		wave_wait += dt
		if wave_wait >= 4:
			wave += 1
			health = minf(100, health + 15)
			begin_wave()

func living_enemies() -> int:
	var count = 0
	for e in enemies:
		if e.hp > 0:
			count += 1
	return count

func burst(pos: Vector2, count: int, color: Color, lifetime: float, impulse: Vector2):
	for i in range(count):
		var life = lifetime * rng.randf_range(0.5, 1.2)
		particles.append({"pos": pos, "vel": impulse + Vector2(rng.randf_range(-95, 95), rng.randf_range(-100, 30)), "life": life, "max": life, "color": color, "size": rng.randf_range(1.3, 3.2), "brass": false})

func update_effects(dt):
	for i in range(particles.size() - 1, -1, -1):
		var p = particles[i]
		p.life -= dt
		p.vel.y += dt * (800 if p.brass else 370)
		p.pos += p.vel * dt
		if p.pos.y > GROUND:
			p.pos.y = GROUND
			p.vel.y = -absf(p.vel.y) * 0.25
			p.vel.x *= 0.65
		if p.life <= 0:
			particles.remove_at(i)
	for i in range(tracers.size() - 1, -1, -1):
		tracers[i].life -= dt
		if tracers[i].life <= 0:
			tracers.remove_at(i)
	for i in range(impacts.size() - 1, -1, -1):
		impacts[i].life -= dt
		if impacts[i].life <= 0:
			impacts.remove_at(i)

func _draw():
	draw_set_transform(stage.position)
	for e in enemies:
		if e.hp > 0:
			draw_ellipse_shadow(e.actor.position, 25, Color(0.02, 0.05, 0.06, 0.4))
	draw_ellipse_shadow(Vector2(player.position.x, GROUND), 28, Color(0.01, 0.03, 0.04, 0.6))
	for trace in tracers:
		draw_line(trace.from, trace.to, Color(1, 0.86, 0.59, trace.life / 0.065), 1.7, true)
		draw_line(trace.from, trace.from.lerp(trace.to, 0.18), Color(1, 0.96, 0.8, trace.life / 0.065), 3, true)
	for p in particles:
		var color = p.color
		color.a = clampf(p.life / p.max * 2, 0, 1)
		if p.brass:
			draw_line(p.pos, p.pos + Vector2(3, 1).rotated(p.life * 17), color, 2, true)
		else:
			draw_circle(p.pos, p.size, color)
	draw_set_transform(Vector2.ZERO)

func draw_ellipse_shadow(pos: Vector2, radius: float, color: Color):
	draw_set_transform(stage.position + pos, 0, Vector2(1, 0.2))
	draw_circle(Vector2.ZERO, radius, color)
	draw_set_transform(stage.position)
