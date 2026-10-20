extends CharacterBody3D
## Perception + memory + grid pathfinding + a telegraphed, wall-checked melee attack.
const Humanoid = preload("res://scripts/tps/humanoid_rig.gd")
signal killed(zombie, headshot: bool)
var game
var player
var rig
var kind: String = "walker"
var health: float = 100
var state: String = "patrol"
var last_known: Vector3
var home: Vector3
var route: Array = []
var route_timer: float = 0
var memory: float = 0
var attack_timer: float = 0
var stagger_timer: float = 0
var death_timer: float = 0
var patrol_timer: float = 0
var age: float = 0
var number: int = 0
var attacks: int = 0
var visual_attack: float = 0
var rng = RandomNumberGenerator.new()

func _ready():
	add_to_group("tps_infected")
	collision_layer = 2
	collision_mask = 7
	home = position
	last_known = position
	rng.seed = number * 173 + 9
	var shape = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.height = 1.72
	capsule.radius = 0.29
	shape.shape = capsule
	shape.position.y = 0.86
	add_child(shape)
	rig = Humanoid.new()
	rig.infected = true
	add_child(rig)
	if kind == "runner":
		rig.scale = Vector3(0.92, 1, 0.92)
	rig.update_pose(1.0 / 60, {"grounded": true})

func line_of_sight() -> bool:
	if not is_instance_valid(player) or player.health <= 0:
		return false
	var query = PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.5, player.global_position + Vector3.UP * 1.1, 5, [get_rid()])
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == player

func sees_player() -> bool:
	var offset: Vector3 = player.global_position - global_position
	var distance = offset.length()
	if distance > 18 or not line_of_sight():
		return false
	return distance < 3 or (-global_basis.z).dot(offset.normalized()) > 0.35

func hear_shot(at: Vector3):
	if health <= 0 or global_position.distance_to(at) > 30:
		return
	last_known = at
	memory = 8
	route_timer = 0
	if state not in ["windup", "recover", "stagger"]:
		state = "investigate"

func refresh_route():
	route = game.get_route(global_position, last_known)
	route_timer = 0.55 + float(number % 4) * 0.06

func take_hit(point: Vector3) -> Dictionary:
	if health <= 0:
		return {"headshot": false, "destroyed": false}
	var headshot = to_local(point).y > 1.48
	health = maxf(0, health - (100.0 if headshot else 34.0))
	if health <= 0:
		state = "dead"
		collision_layer = 0
		collision_mask = 0
		velocity = Vector3.ZERO
		killed.emit(self, headshot)
	else:
		state = "stagger"
		stagger_timer = 0.28
		memory = 8
		last_known = player.global_position
		attack_timer = 0
	return {"headshot": headshot, "destroyed": health <= 0}

func _physics_process(delta: float):
	age += delta
	if health <= 0:
		death_timer += delta
		rig.update_pose(delta, {"state": "dead", "death": minf(death_timer * 2, 1), "grounded": true})
		if death_timer > 9:
			queue_free()
		return
	if not is_instance_valid(player) or player.health <= 0:
		return
	route_timer -= delta
	memory = maxf(0, memory - delta)
	var visible = sees_player()
	if visible:
		last_known = player.global_position
		memory = 6
		if state in ["patrol", "investigate", "chase"]:
			state = "chase"
	var offset: Vector3 = player.global_position - global_position
	var horizontal_distance = Vector2(offset.x, offset.z).length()
	if state == "stagger":
		stagger_timer -= delta
		if stagger_timer <= 0:
			state = "chase" if visible else "investigate"
	elif state == "windup":
		attack_timer -= delta
		visual_attack = clampf(1.0 - attack_timer / 0.58, 0, 1)
		if attack_timer <= 0:
			# Range, height, and a fresh wall test are required at the actual strike.
			if horizontal_distance <= 1.65 and absf(offset.y) < 1.2 and line_of_sight():
				player.take_damage(18 if kind == "walker" else 14)
				attacks += 1
			state = "recover"
			attack_timer = 0.95
	elif state == "recover":
		attack_timer -= delta
		visual_attack = move_toward(visual_attack, 0, delta * 3)
		if attack_timer <= 0:
			state = "chase" if memory > 0 else "patrol"
	elif horizontal_distance < 1.35 and visible and absf(offset.y) < 1.2:
		state = "windup"
		attack_timer = 0.58
		visual_attack = 0
	elif memory <= 0:
		state = "patrol"
		patrol_timer -= delta
		if patrol_timer <= 0 or global_position.distance_to(last_known) < 0.5:
			last_known = home + Vector3(rng.randf_range(-2, 2), 0, rng.randf_range(-2, 2))
			patrol_timer = rng.randf_range(3, 5)
			route_timer = 0
	var desired = Vector3.ZERO
	if state in ["chase", "investigate", "patrol"]:
		if route_timer <= 0:
			refresh_route()
		while route.size() > 0 and Vector2(route[0].x - position.x, route[0].z - position.z).length() < 0.35:
			route.pop_front()
		if not route.is_empty():
			desired = (route[0] - global_position)
			desired.y = 0
			desired = desired.normalized()
		var separation = Vector3.ZERO
		for other in get_tree().get_nodes_in_group("tps_infected"):
			if other == self or other.health <= 0:
				continue
			var away = global_position - other.global_position
			away.y = 0
			if away.length() > 0.01 and away.length() < 0.8:
				separation += away.normalized() * (0.8 - away.length()) * 1.7
		desired = (desired + separation).limit_length(1)
	var speed = 3.6 if kind == "runner" else 1.65
	if state == "patrol":
		speed *= 0.45
	velocity.x = move_toward(velocity.x, desired.x * speed, delta * 8)
	velocity.z = move_toward(velocity.z, desired.z * speed, delta * 8)
	velocity.y = 0 if is_on_floor() else velocity.y - 20 * delta
	var before = global_position
	move_and_slide()
	var movement = global_position - before
	var face = offset if state in ["windup", "recover"] else desired
	if Vector2(face.x, face.z).length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-face.x, -face.z), 1.0 - exp(-delta * 8))
	rig.update_pose(delta, {"state": state, "velocity": Vector3(movement.x, 0, movement.z) / delta, "distance": Vector2(movement.x, movement.z).length(), "grounded": is_on_floor(), "attack": visual_attack, "sprint": 1.0 if kind == "runner" and state == "chase" else 0.0})
