extends CharacterBody3D
const Kit = preload("res://scripts/tps/geometry.gd")
const Humanoid = preload("res://scripts/tps/humanoid_rig.gd")
signal fired(result: Dictionary)
signal reloading
signal damaged(amount: float)
signal died
const MAGAZINE = 24
const RELOAD_TIME = 1.65
const FIRE_INTERVAL = 0.115
const WALK_SPEED = 4.4
const SPRINT_SPEED = 7.4
const AIM_SPEED = 2.05
var active: bool = false
var aiming: bool = false
var sprinting: bool = false
var shoulder: float = 1.0
var ammo: int = MAGAZINE
var reserve: int = 144
var health: float = 100.0
var hurt_timer: float = 0.0
var damage_flash: float = 0.0
var reload_timer: float = 0.0
var fire_timer: float = 0.0
var recoil: float = 0.0
var bloom: float = 0.0
var yaw: float = 0.0
var pitch: float = -0.035
var body_yaw: float = 0.0
var shots: int = 0
var real_speed: float = 0.0
var real_velocity: Vector3 = Vector3.ZERO
var locomotion_state: String = "idle"
var aim_weight: float = 0.0
var rig
var pivot: Node3D
var pitch_pivot: Node3D
var arm: SpringArm3D
var camera: Camera3D
var muzzle: Marker3D
var muzzle_flash: MeshInstance3D
var weapon: Node3D
var last_result: Dictionary = {}
var rng = RandomNumberGenerator.new()
var camera_bounds: SphereShape3D

func _ready():
	collision_layer = 4
	collision_mask = 3
	var collision = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.75
	collision.shape = capsule
	collision.position.y = 0.875
	add_child(collision)
	rig = Humanoid.new()
	add_child(rig)
	weapon = rig.weapon
	muzzle = rig.muzzle
	muzzle_flash = rig.muzzle_flash
	pivot = Node3D.new()
	add_child(pivot)
	pivot.position.y = 1.52
	pitch_pivot = Node3D.new()
	pivot.add_child(pitch_pivot)
	arm = SpringArm3D.new()
	pitch_pivot.add_child(arm)
	arm.position.x = 0.62
	arm.spring_length = 3.2
	arm.margin = 0.16
	arm.collision_mask = 1
	camera_bounds = SphereShape3D.new()
	camera_bounds.radius = 0.18
	arm.shape = camera_bounds
	arm.add_excluded_object(get_rid())
	camera = Camera3D.new()
	arm.add_child(camera)
	camera.current = true
	camera.fov = 75
	camera.near = 0.06
	camera.far = 180.0
	rng.seed = 151
	sync_look()
	rig.update_pose(1.0 / 60.0, {"state": "idle", "grounded": true})

func _unhandled_input(event: InputEvent):
	if not active:
		return
	if event is InputEventMouseMotion:
		var sensitivity = 0.0018 if aiming else 0.0027
		yaw -= event.relative.x * sensitivity
		pitch = clampf(pitch - event.relative.y * sensitivity, -1.1, 1.05)
		sync_look()
	if event.is_action_pressed("tps_shoulder"):
		shoulder *= -1.0
	if event.is_action_pressed("tps_reload"):
		begin_reload()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		rig.toggle_debug()

func sync_look():
	pivot.rotation.y = yaw
	pitch_pivot.rotation.x = pitch + recoil

func _physics_process(delta: float):
	if not active:
		return
	advance_weapon(delta)
	hurt_timer = maxf(0.0, hurt_timer - delta)
	damage_flash = maxf(0.0, damage_flash - delta)
	aiming = Input.is_action_pressed("tps_aim")
	aim_weight = move_toward(aim_weight, 1.0 if aiming else 0.0, delta * 5.0)
	var move = Input.get_vector("tps_left", "tps_right", "tps_forward", "tps_back")
	sprinting = Input.is_action_pressed("tps_sprint") and move.length() > 0.1 and not aiming and reload_timer <= 0.0
	var direction = Vector3(move.x, 0, move.y).rotated(Vector3.UP, yaw)
	var speed = SPRINT_SPEED if sprinting else (AIM_SPEED if aiming else WALK_SPEED)
	var horizontal = Vector2(velocity.x, velocity.z)
	var acceleration = 8.0 if sprinting else 12.0
	if move.length() < 0.1:
		acceleration = 9.0
	elif horizontal.dot(Vector2(direction.x, direction.z)) < 0:
		acceleration = 10.0
	if aiming:
		acceleration = 16.0
	if not is_on_floor():
		acceleration = 2.5
	horizontal = horizontal.move_toward(Vector2(direction.x, direction.z) * speed, delta * acceleration)
	velocity.x = horizontal.x
	velocity.z = horizontal.y
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0
		if Input.is_action_just_pressed("tps_jump"):
			velocity.y = 6.0
	var previous = position
	move_and_slide()
	var displacement = position - previous
	var old_real = real_velocity
	real_velocity = Vector3(displacement.x, 0, displacement.z) / delta
	real_speed = real_velocity.length()
	if position.y < -10.0:
		position = Vector3(0, 0.1, 7)
		velocity = Vector3.ZERO
	var desired_yaw = body_yaw
	if aiming:
		desired_yaw = yaw
	elif real_speed > 0.08:
		desired_yaw = atan2(-real_velocity.x, -real_velocity.z)
	body_yaw = lerp_angle(body_yaw, desired_yaw, 1.0 - exp(-delta * (13.0 if aiming else 8.0)))
	rig.rotation.y = body_yaw
	update_camera(delta)
	locomotion_state = choose_state(move)
	var reload_progress = 1.0 - reload_timer / RELOAD_TIME if reload_timer > 0 else -1.0
	rig.update_pose(delta, {"state": locomotion_state, "velocity": real_velocity, "distance": Vector2(displacement.x, displacement.z).length(), "grounded": is_on_floor(), "acceleration": (real_velocity - old_real) / delta, "aim": aim_weight, "sprint": 1.0 if sprinting else 0.0, "pitch": pitch, "aim_yaw": angle_difference(body_yaw, yaw), "recoil": recoil, "reload": reload_progress})
	sync_look()
	if Input.is_action_pressed("tps_fire"):
		try_fire()

func choose_state(move: Vector2) -> String:
	if health <= 0:
		return "dead"
	if damage_flash > 0.15:
		return "hurt"
	if not is_on_floor():
		return "jump" if velocity.y > 0 else "fall"
	if rig.landing > 0.1:
		return "land"
	if reload_timer > 0:
		return "reload"
	if aiming:
		if aim_weight < 0.9:
			return "aim_raise"
		return "aim_walk" if real_speed > 0.1 else "aim_idle"
	if real_speed > 0.1 and move.length() < 0.1:
		return "brake"
	if sprinting:
		return "sprint"
	return "walk" if real_speed > 0.1 else "idle"

func update_camera(delta: float):
	arm.position.x = move_toward(arm.position.x, shoulder * (0.52 if aiming else 0.62), delta * 4.0)
	var sweep = PhysicsShapeQueryParameters3D.new()
	sweep.shape = camera_bounds
	sweep.transform = Transform3D(Basis.IDENTITY, pitch_pivot.global_position)
	sweep.motion = pitch_pivot.global_basis.x * arm.position.x
	sweep.collision_mask = 1
	sweep.exclude = [get_rid()]
	var travel = get_world_3d().direct_space_state.cast_motion(sweep)
	arm.position.x *= travel[0]
	arm.spring_length = move_toward(arm.spring_length, 1.9 if aiming else 3.2, delta * 5.0)
	camera.fov = move_toward(camera.fov, 53.0 if aiming else (82.0 if sprinting else 75.0), delta * 90.0)

func take_damage(amount: float) -> bool:
	if health <= 0 or hurt_timer > 0 or not active:
		return false
	health = maxf(0.0, health - amount)
	hurt_timer = 0.65
	damage_flash = 0.35
	damaged.emit(amount)
	if health <= 0:
		active = false
		died.emit()
	return true

func reset_character():
	health = 100
	hurt_timer = 0
	damage_flash = 0
	position = Vector3(0, 0.05, 7)
	velocity = Vector3.ZERO
	real_velocity = Vector3.ZERO
	real_speed = 0
	body_yaw = 0
	yaw = 0
	pitch = -0.035
	aiming = false
	aim_weight = 0
	rig.aim_blend = 0
	rig.initialized_feet = false
	sync_look()

func advance_weapon(delta: float):
	fire_timer = maxf(0.0, fire_timer - delta)
	recoil = move_toward(recoil, 0.0, delta * 0.16)
	bloom = move_toward(bloom, 0.0, delta * 0.035)
	muzzle_flash.visible = fire_timer > FIRE_INTERVAL - 0.035
	if reload_timer > 0.0:
		reload_timer = maxf(0.0, reload_timer - delta)
		if reload_timer <= 0.0:
			var needed = mini(MAGAZINE - ammo, reserve)
			ammo += needed
			reserve -= needed

func begin_reload() -> bool:
	if reload_timer > 0.0 or ammo == MAGAZINE or reserve <= 0:
		return false
	reload_timer = RELOAD_TIME
	reloading.emit()
	return true

func trace(from: Vector3, to: Vector3, mask: int = 3) -> Dictionary:
	var query = PhysicsRayQueryParameters3D.create(from, to, mask, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query)

func shot_solution(direction: Vector3) -> Dictionary:
	# First find the crosshair point from the camera; then test the actual barrel path.
	# A chest-to-barrel trace also prevents a protruding barrel firing through cover.
	var eye = camera.global_position
	var sight_hit = trace(eye, eye + direction.normalized() * 120.0)
	var aim_point: Vector3 = sight_hit.get("position", eye + direction.normalized() * 120.0)
	var start = muzzle.global_position
	var obstruction = trace(global_position + Vector3.UP * 1.35, start, 1)
	# Continue slightly into the surface: stopping exactly at a raycast's reported
	# face can miss it due to floating-point rounding, especially at long range.
	var ray_end = aim_point + (aim_point - start).normalized() * 0.08
	var impact = obstruction if not obstruction.is_empty() else trace(start, ray_end)
	return {"aim_point": aim_point, "from": start, "point": impact.get("position", aim_point), "impact": impact, "blocked": not obstruction.is_empty() or (not impact.is_empty() and impact.get("collider") != sight_hit.get("collider"))}

func try_fire(spread: bool = true) -> bool:
	if not active or reload_timer > 0.0 or fire_timer > 0.0 or sprinting or not aiming or aim_weight < 0.9 or real_speed > AIM_SPEED + 0.4:
		return false
	if ammo <= 0:
		begin_reload()
		return false
	var direction = -camera.global_basis.z
	if spread:
		var cone = (0.0015 if aiming else 0.009) + bloom
		direction = (direction + camera.global_basis.x * rng.randf_range(-cone, cone) + camera.global_basis.y * rng.randf_range(-cone, cone)).normalized()
	last_result = shot_solution(direction)
	var impact: Dictionary = last_result.impact
	last_result["headshot"] = false
	last_result["target_hit"] = false
	last_result["destroyed"] = false
	if not impact.is_empty() and impact.collider.has_method("take_hit"):
		var damage: Dictionary = impact.collider.take_hit(impact.position)
		last_result.merge(damage, true)
		last_result.target_hit = true
	ammo -= 1
	shots += 1
	fire_timer = FIRE_INTERVAL
	recoil = minf(recoil + 0.013, 0.085)
	bloom = minf(bloom + 0.0025, 0.025)
	muzzle_flash.visible = true
	fired.emit(last_result)
	return true
