extends CharacterBody3D
const Kit = preload("res://scripts/tps/geometry.gd")
signal fired(result: Dictionary)
signal reloading
const MAGAZINE = 24
const RELOAD_TIME = 1.65
const FIRE_INTERVAL = 0.115
var active: bool = false
var aiming: bool = false
var sprinting: bool = false
var shoulder: float = 1.0
var ammo: int = MAGAZINE
var reserve: int = 144
var reload_timer: float = 0.0
var fire_timer: float = 0.0
var recoil: float = 0.0
var bloom: float = 0.0
var yaw: float = 0.0
var pitch: float = -0.035
var shots: int = 0
var walk_phase: float = 0.0
var rig: Node3D
var pivot: Node3D
var pitch_pivot: Node3D
var arm: SpringArm3D
var camera: Camera3D
var muzzle: Marker3D
var muzzle_flash: MeshInstance3D
var left_leg: Node3D
var right_leg: Node3D
var weapon: Node3D
var gun_rest: Vector3
var last_result: Dictionary = {}
var rng = RandomNumberGenerator.new()
var camera_bounds: SphereShape3D

func _ready():
	collision_layer = 4
	collision_mask = 1
	var collision = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.75
	collision.shape = capsule
	collision.position.y = 0.875
	add_child(collision)
	build_character()
	pivot = Node3D.new()
	add_child(pivot)
	pivot.position.y = 1.52
	pitch_pivot = Node3D.new()
	pivot.add_child(pitch_pivot)
	arm = SpringArm3D.new()
	pitch_pivot.add_child(arm)
	arm.position.x = 0.62
	arm.spring_length = 3.0
	arm.margin = 0.16
	arm.collision_mask = 1
	camera_bounds = SphereShape3D.new()
	camera_bounds.radius = 0.18
	arm.shape = camera_bounds
	arm.add_excluded_object(get_rid())
	camera = Camera3D.new()
	arm.add_child(camera)
	camera.current = true
	camera.fov = 73
	camera.near = 0.06
	camera.far = 180.0
	rng.seed = 151
	sync_look()

func build_character():
	rig = Node3D.new()
	add_child(rig)
	var coat = Kit.material(Color("244f59"))
	var dark = Kit.material(Color("172630"))
	var skin = Kit.material(Color("e8b89c"))
	var hair = Kit.material(Color("d9d9dc"))
	var light = Kit.material(Color("64e4cf"), 0.7)
	Kit.box(rig, Vector3(0, 1.19, 0), Vector3(0.48, 0.52, 0.29), coat)
	Kit.box(rig, Vector3(0, 0.87, 0), Vector3(0.43, 0.18, 0.27), dark)
	Kit.box(rig, Vector3(0, 0.96, 0.17), Vector3(0.37, 0.05, 0.06), light)
	Kit.sphere(rig, Vector3(0, 1.64, 0), 0.205, skin)
	Kit.sphere(rig, Vector3(0, 1.72, 0.025), 0.218, hair)
	Kit.box(rig, Vector3(0, 1.58, 0.17), Vector3(0.36, 0.31, 0.12), hair)
	Kit.box(rig, Vector3(0, 1.34, 0.2), Vector3(0.32, 0.36, 0.14), dark)
	Kit.box(rig, Vector3(0, 1.4, 0.28), Vector3(0.18, 0.025, 0.01), light)
	for side in [-1.0, 1.0]:
		var leg = Node3D.new()
		rig.add_child(leg)
		leg.position = Vector3(side * 0.13, 0.85, 0)
		Kit.box(leg, Vector3(0, -0.3, 0), Vector3(0.18, 0.58, 0.2), dark)
		Kit.box(leg, Vector3(0, -0.67, -0.04), Vector3(0.19, 0.25, 0.32), dark)
		Kit.box(leg, Vector3(0, -0.29, -0.11), Vector3(0.19, 0.15, 0.04), coat)
		if side < 0:
			left_leg = leg
		else:
			right_leg = leg
	weapon = Node3D.new()
	rig.add_child(weapon)
	weapon.position = Vector3(0.27, 1.35, -0.25)
	gun_rest = weapon.position
	Kit.box(weapon, Vector3(0, 0, -0.3), Vector3(0.11, 0.15, 0.62), dark)
	Kit.box(weapon, Vector3(0, 0, -0.7), Vector3(0.055, 0.055, 0.3), Kit.material(Color("60777d")))
	Kit.box(weapon, Vector3(0, -0.15, -0.27), Vector3(0.09, 0.25, 0.13), dark)
	Kit.box(weapon, Vector3(0, 0.1, -0.25), Vector3(0.07, 0.065, 0.13), light)
	# Hands and forearms are placeholders attached to the weapon for reliable grip alignment.
	Kit.box(weapon, Vector3(0.05, -0.08, 0.09), Vector3(0.14, 0.18, 0.43), coat)
	Kit.sphere(weapon, Vector3(0.02, -0.05, -0.13), 0.075, skin)
	Kit.box(weapon, Vector3(-0.25, -0.08, -0.19), Vector3(0.42, 0.13, 0.13), coat)
	Kit.sphere(weapon, Vector3(-0.04, -0.06, -0.35), 0.07, skin)
	muzzle = Marker3D.new()
	weapon.add_child(muzzle)
	muzzle.position.z = -0.87
	muzzle_flash = Kit.sphere(muzzle, Vector3(0, 0, -0.04), 0.1, Kit.material(Color("ffe6a0"), 4.0))
	muzzle_flash.scale = Vector3(0.6, 0.6, 1.9)
	muzzle_flash.visible = false

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

func sync_look():
	pivot.rotation.y = yaw
	pitch_pivot.rotation.x = pitch + recoil
	rig.rotation.y = yaw
	weapon.rotation.x = pitch + recoil * 0.6

func _physics_process(delta: float):
	if not active:
		return
	advance_weapon(delta)
	aiming = Input.is_action_pressed("tps_aim")
	var move = Input.get_vector("tps_left", "tps_right", "tps_forward", "tps_back")
	sprinting = Input.is_action_pressed("tps_sprint") and move.y < -0.1 and not aiming and reload_timer <= 0.0
	var direction = Vector3(move.x, 0, move.y).rotated(Vector3.UP, yaw)
	var speed = 7.0 if sprinting else (2.4 if aiming else 4.2)
	velocity.x = move_toward(velocity.x, direction.x * speed, delta * 23.0)
	velocity.z = move_toward(velocity.z, direction.z * speed, delta * 23.0)
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0
		if Input.is_action_just_pressed("tps_jump"):
			velocity.y = 6.0
	move_and_slide()
	if position.y < -10.0:
		position = Vector3(0, 0.1, 7)
		velocity = Vector3.ZERO
	arm.position.x = move_toward(arm.position.x, shoulder * (0.5 if aiming else 0.62), delta * 4.0)
	# Sweep sideways too: the spring arm itself only protects the rearward path.
	# Without this, changing shoulders next to a wall could place its root inside it.
	var sweep = PhysicsShapeQueryParameters3D.new()
	sweep.shape = camera_bounds
	sweep.transform = Transform3D(Basis.IDENTITY, pitch_pivot.global_position)
	sweep.motion = pitch_pivot.global_basis.x * arm.position.x
	sweep.collision_mask = 1
	sweep.exclude = [get_rid()]
	var travel = get_world_3d().direct_space_state.cast_motion(sweep)
	arm.position.x *= travel[0]
	arm.spring_length = move_toward(arm.spring_length, 1.65 if aiming else 3.0, delta * 5.0)
	camera.fov = move_toward(camera.fov, 53.0 if aiming else (80.0 if sprinting else 73.0), delta * 90.0)
	walk_phase += Vector2(velocity.x, velocity.z).length() * delta * 2.3
	var stride = minf(Vector2(velocity.x, velocity.z).length() / 7.0, 1.0) * 0.65
	left_leg.rotation.x = sin(walk_phase) * stride
	right_leg.rotation.x = -sin(walk_phase) * stride
	weapon.position = gun_rest + Vector3(0, -0.16 if reload_timer > 0.0 else 0.0, recoil * 0.65)
	weapon.rotation.z = -0.5 if reload_timer > 0.0 else 0.0
	sync_look()
	if Input.is_action_pressed("tps_fire"):
		try_fire()

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
	if not active or reload_timer > 0.0 or fire_timer > 0.0 or sprinting:
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
