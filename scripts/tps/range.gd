extends Node3D
const Kit = preload("res://scripts/tps/geometry.gd")
const Player = preload("res://scripts/tps/player.gd")
const Target = preload("res://scripts/tps/target.gd")
const Overlay = preload("res://scripts/tps/hud.gd")
const Sound = preload("res://scripts/sound.gd")
const Zombie = preload("res://scripts/tps/zombie.gd")
var player
var targets: Array = []
var hud
var sound
var started: bool = false
var paused: bool = false
var capture_mouse: bool = true
var hits: int = 0
var kills: int = 0
var headshots: int = 0
var hit_timer: float = 0.0
var notice_timer: float = 0.0
var notice: String = ""
var effects: Array = []
var elapsed: float = 0.0
var drill_complete: bool = false
var drill_targets: Dictionary = {}
var combat_mode: bool = true
var auto_waves: bool = true
var zombies: Array = []
var wave: int = 0
var wave_delay: float = 3.0
var infected_kills: int = 0
var dead: bool = false
var combat_complete: bool = false
var navigation_grid: AStarGrid2D
var zombie_serial: int = 0

func _ready():
	setup_inputs()
	build_range()
	rebuild_navigation()
	player = Player.new()
	add_child(player)
	player.position = Vector3(0, 0.05, 7)
	player.fired.connect(on_shot)
	sound = Sound.new()
	add_child(sound)
	player.reloading.connect(func(): sound.play("reload", -6))
	player.rig.footstep.connect(func(): sound.play("step", -10, 1.12 if player.sprinting else 0.95))
	player.damaged.connect(func(_amount): sound.play("hurt", -5))
	player.died.connect(on_player_died)
	var canvas = CanvasLayer.new()
	add_child(canvas)
	hud = Overlay.new()
	hud.game = self
	canvas.add_child(hud)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func setup_inputs():
	var keys = {"tps_forward": KEY_W, "tps_back": KEY_S, "tps_left": KEY_A, "tps_right": KEY_D, "tps_sprint": KEY_SHIFT, "tps_jump": KEY_SPACE, "tps_reload": KEY_R, "tps_shoulder": KEY_Q, "tps_reset": KEY_T}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event = InputEventKey.new()
			event.physical_keycode = keys[action]
			InputMap.action_add_event(action, event)
	for action in ["tps_fire", "tps_aim"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event = InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT if action == "tps_fire" else MOUSE_BUTTON_RIGHT
			InputMap.action_add_event(action, event)

func begin_game(capture: bool = true):
	capture_mouse = capture
	started = true
	set_paused(false)

func set_paused(value: bool):
	paused = value or dead or combat_complete
	player.active = started and not paused and not dead and not combat_complete
	for target in targets:
		target.set_physics_process(not paused and started)
	for zombie in zombies:
		if is_instance_valid(zombie):
			zombie.set_physics_process(not paused and started and not dead and not combat_complete)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if player.active and capture_mouse else Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER:
			if dead or combat_complete:
				reset_drill()
				set_paused(false)
			elif not started:
				begin_game(capture_mouse)
			elif paused:
				set_paused(false)
		if event.keycode == KEY_ESCAPE and started:
			set_paused(not paused)
		if event.keycode == KEY_M:
			sound.enabled = not sound.enabled
		if event.keycode == KEY_F2:
			combat_mode = not combat_mode
			reset_drill()
			if started:
				set_paused(false)
		if event.is_action_pressed("tps_reset") and started and not paused:
			reset_drill()

func _notification(what: int):
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and started and not paused:
		set_paused(true)

func reset_drill():
	clear_infected()
	wave = 0
	wave_delay = 3.0
	infected_kills = 0
	dead = false
	combat_complete = false
	hits = 0
	kills = 0
	headshots = 0
	elapsed = 0.0
	drill_complete = false
	drill_targets.clear()
	player.shots = 0
	player.ammo = player.MAGAZINE
	player.reserve = 144
	player.reload_timer = 0.0
	player.fire_timer = 0.0
	player.recoil = 0.0
	player.bloom = 0.0
	player.reset_character()
	player.active = started and not paused
	for target in targets:
		target.reset_target()
	notify("BREACH RESET  /  THREE WAVES INCOMING" if combat_mode else "RANGE RESET  /  AMMUNITION RESTOCKED")

func on_player_died():
	dead = true
	set_paused(true)
	notify("OPERATOR DOWN")

func clear_infected():
	for zombie in zombies:
		if is_instance_valid(zombie):
			zombie.remove_from_group("tps_infected")
			zombie.queue_free()
	zombies.clear()

func alive_infected() -> int:
	var count = 0
	for zombie in zombies:
		if is_instance_valid(zombie) and zombie.health > 0:
			count += 1
	return count

func spawn_zombie(at: Vector3, kind: String = "walker"):
	var zombie = Zombie.new()
	zombie.game = self
	zombie.player = player
	zombie.kind = kind
	zombie_serial += 1
	zombie.number = zombie_serial
	zombie.position = at
	zombie.rotation.y = PI
	add_child(zombie)
	zombie.killed.connect(func(_z, _head): infected_kills += 1)
	zombie.set_physics_process(started and not paused and not dead)
	zombies.append(zombie)
	return zombie

func spawn_wave():
	wave += 1
	var positions = [Vector3(-3, 0.1, -4), Vector3(3, 0.1, -6), Vector3(-8, 0.1, -9), Vector3(8, 0.1, -12), Vector3(-3, 0.1, -18), Vector3(3, 0.1, -22), Vector3(-9, 0.1, -25), Vector3(9, 0.1, -25)]
	for i in range(2 + wave * 2):
		var zombie = spawn_zombie(positions[i], "runner" if wave > 1 and i % 3 == 1 else "walker")
		zombie.hear_shot(player.global_position)
	player.reserve = mini(240, player.reserve + 48)
	notify("BREACH  /  WAVE %d OF 3  /  %d INFECTED" % [wave, alive_infected()])

func rebuild_navigation():
	navigation_grid = AStarGrid2D.new()
	navigation_grid.region = Rect2i(-31, -65, 63, 101)
	navigation_grid.cell_size = Vector2(0.5, 0.5)
	navigation_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation_grid.update()
	for child in get_children():
		if not child is StaticBody3D or child.collision_layer != 1:
			continue
		for shape in child.get_children():
			if not shape is CollisionShape3D or not shape.shape is BoxShape3D:
				continue
			var center: Vector3 = shape.global_position
			var extent: Vector3 = shape.shape.size * 0.5
			if center.y + extent.y < 0.1:
				continue
			# Expand by capsule radius, so a valid path also fits the actual body.
			var low = Vector2i(floori((center.x - extent.x - 0.4) * 2), floori((center.z - extent.z - 0.4) * 2))
			var high = Vector2i(ceili((center.x + extent.x + 0.4) * 2), ceili((center.z + extent.z + 0.4) * 2))
			for x in range(low.x, high.x + 1):
				for z in range(low.y, high.y + 1):
					var cell = Vector2i(x, z)
					if navigation_grid.region.has_point(cell):
						navigation_grid.set_point_solid(cell)

func walkable_cell(at: Vector3) -> Vector2i:
	var cell = Vector2i(roundi(at.x * 2), roundi(at.z * 2))
	cell.x = clampi(cell.x, -31, 31)
	cell.y = clampi(cell.y, -65, 35)
	if not navigation_grid.is_point_solid(cell):
		return cell
	for radius in range(1, 6):
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				var test = cell + Vector2i(x, z)
				if navigation_grid.region.has_point(test) and not navigation_grid.is_point_solid(test):
					return test
	return cell

func get_route(from: Vector3, to: Vector3) -> Array:
	var result: Array = []
	for cell in navigation_grid.get_id_path(walkable_cell(from), walkable_cell(to)):
		result.append(Vector3(cell.x * 0.5, 0, cell.y * 0.5))
	return result

func notify(text: String):
	notice = text
	notice_timer = 3.0

func build_range():
	var environment = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("283f49")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("91b8c4")
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("344f59")
	env.fog_density = 0.005
	environment.environment = env
	add_child(environment)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32, -34, 0)
	sun.light_color = Color("ffd3a0")
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	add_child(sun)
	var concrete = Kit.material(Color("465655"))
	var floor_mat = Kit.material(Color("263c41"))
	var dark = Kit.material(Color("172c34"))
	var teal = Kit.material(Color("5bd9c5"), 0.7)
	var orange = Kit.material(Color("e59755"), 0.4)
	Kit.box(self, Vector3(0, -0.25, -8), Vector3(32, 0.5, 52), floor_mat, true)
	Kit.box(self, Vector3(0, 2, -33), Vector3(32, 4, 0.8), concrete, true)
	Kit.box(self, Vector3(-16, 1.8, -8), Vector3(0.6, 3.6, 51), concrete, true)
	Kit.box(self, Vector3(16, 1.8, -8), Vector3(0.6, 3.6, 51), concrete, true)
	Kit.box(self, Vector3(0, 1.8, 18), Vector3(32, 3.6, 0.6), concrete, true)
	Kit.label(self, Vector3(0, 3.1, -32.5), "LAST LIGHT  /  QUARANTINE DIVISION", 74, Color("c3d8ce"))
	Kit.label(self, Vector3(0, 2.38, -32.45), "AUTHORIZED PERSONNEL ONLY     /     SECTOR 09", 35, Color("f5ba75"))
	for x in [-10.0, -4.0, 4.0, 10.0]:
		Kit.box(self, Vector3(x, 0.008, -9), Vector3(0.04, 0.015, 44), Kit.material(Color("638181")))
	for z in [3.0, -4.0, -12.0, -22.0]:
		Kit.box(self, Vector3(0, 0.012, z), Vector3(25, 0.02, 0.06), orange)
	for x in [-6.0, 0.0, 6.0]:
		Kit.box(self, Vector3(x, 0.65, 0.4), Vector3(2.4, 1.3, 0.75), concrete, true)
		Kit.box(self, Vector3(x, 1.31, 0.4), Vector3(2.4, 0.04, 0.8), orange)
		for stripe in range(5):
			var mark = Kit.box(self, Vector3(x - 0.95 + stripe * 0.47, 0.8, 0.79), Vector3(0.18, 0.6, 0.025), dark)
			mark.rotation.z = -0.45
	# Full-height containers exercise camera collision and the muzzle obstruction rule.
	for x in [-11.5, 11.5]:
		Kit.box(self, Vector3(x, 1.4, 5), Vector3(4, 2.8, 5), Kit.material(Color("355a60")), true)
		for z in range(10):
			Kit.box(self, Vector3(x, 1.4, 2.7 + z * 0.5), Vector3(4.05, 2.65, 0.06), dark)
		Kit.label(self, Vector3(x, 1.6, 7.55), "Q / 09", 60, Color("80b5b2"))
	var positions = [Vector3(-6, 0, -7), Vector3(0, 0, -10), Vector3(6, 0, -7), Vector3(-6, 0, -19), Vector3(0, 0, -25), Vector3(6, 0, -19)]
	for i in range(positions.size()):
		var target = Target.new()
		target.position = positions[i]
		target.number = i + 1
		target.moving = i == 4
		add_child(target)
		target.set_physics_process(false)
		targets.append(target)
	for i in range(3):
		var x = (i - 1) * 6.0
		Kit.label(self, Vector3(x, 3.5, -13.0), ["01 / PRECISION", "02 / TRACKING", "03 / TRANSITION"][i], 36, Color("8ec9c2"))
		Kit.box(self, Vector3(x, 3.95, -13.0), Vector3(3.4, 0.06, 0.12), teal)
	for x in [-14.0, 14.0]:
		for z in [-26.0, -12.0, 2.0, 14.0]:
			Kit.box(self, Vector3(x, 2.7, z), Vector3(0.12, 5.4, 0.12), dark)
			Kit.box(self, Vector3(x, 5.45, z), Vector3(0.6, 0.12, 0.6), teal)
			var lamp = OmniLight3D.new()
			add_child(lamp)
			lamp.position = Vector3(x, 4.8, z)
			lamp.light_color = Color("80dbd2")
			lamp.light_energy = 1.2
			lamp.omni_range = 9
	# Reproducible distant skyline, with no downloaded assets.
	var random = RandomNumberGenerator.new()
	random.seed = 92
	for i in range(25):
		var x = -65.0 + i * 5.5
		var height = random.randf_range(7, 24)
		Kit.box(self, Vector3(x, height * 0.5, -random.randf_range(42, 68)), Vector3(random.randf_range(3, 6), height, 6), Kit.material(Color("253b45")))

func on_shot(result: Dictionary):
	sound.play("shot", -6, randf_range(0.96, 1.04))
	for zombie in zombies:
		if is_instance_valid(zombie):
			zombie.hear_shot(player.global_position)
	var color = Color("ffc47b")
	if result.target_hit:
		hits += 1
		headshots += 1 if result.headshot else 0
		hit_timer = 0.18
		color = Color("78f6d5")
		sound.play("impact_metal", -9)
		if result.destroyed:
			kills += 1
			var target = result.impact.collider
			if target.is_in_group("tps_infected"):
				notify("%s  /  INFECTED DOWN" % ("HEADSHOT" if result.headshot else "CONFIRMED"))
			else:
				drill_targets[target.number] = true
				if drill_targets.size() == targets.size() and not drill_complete:
					drill_complete = true
					notify("DRILL COMPLETE  /  ALL SIX TARGETS NEUTRALIZED  /  T TO RETRY")
				else:
					notify("%s  /  TARGET %02d DOWN" % ["HEADSHOT" if result.headshot else "CONFIRMED", target.number])
	elif result.blocked:
		notify("BARREL OBSTRUCTED  /  CLEAR YOUR COVER")
	var from: Vector3 = result.from
	var to: Vector3 = result.point
	if from.distance_to(to) > 0.02:
		var tracer = Kit.box(self, (from + to) * 0.5, Vector3(0.012, 0.012, from.distance_to(to)), Kit.material(color, 2.0))
		tracer.look_at(to, Vector3.UP)
		effects.append({"node": tracer, "life": 0.055})
	if not result.impact.is_empty():
		var spark = Kit.sphere(self, to, 0.075, Kit.material(color, 2.0))
		effects.append({"node": spark, "life": 0.16})

func _process(delta: float):
	if started and not paused:
		if not (combat_complete if combat_mode else drill_complete):
			elapsed += delta
		if combat_mode and auto_waves and not combat_complete and not dead:
			if alive_infected() == 0:
				wave_delay -= delta
				if wave_delay <= 0:
					if wave >= 3:
						combat_complete = true
						set_paused(true)
					else:
						spawn_wave()
			else:
				wave_delay = 4
		hit_timer = maxf(0.0, hit_timer - delta)
		notice_timer = maxf(0.0, notice_timer - delta)
		for i in range(effects.size() - 1, -1, -1):
			effects[i].life -= delta
			if effects[i].life <= 0:
				effects[i].node.queue_free()
				effects.remove_at(i)
	hud.queue_redraw()
