extends StaticBody3D
const Kit = preload("res://scripts/tps/geometry.gd")
signal hit(headshot: bool, destroyed: bool)
var health: float = 100.0
var reset_timer: float = 0.0
var moving: bool = false
var phase: float = 0.0
var origin: Vector3
var visual: Node3D
var plate_material: StandardMaterial3D
var flash: float = 0.0
var number: int = 1

func _ready():
	origin = position
	collision_layer = 2
	collision_mask = 0
	visual = Node3D.new()
	add_child(visual)
	plate_material = Kit.material(Color("dc714c"))
	Kit.box(visual, Vector3(0, 1.16, 0), Vector3(0.64, 0.86, 0.16), plate_material)
	Kit.sphere(visual, Vector3(0, 1.82, 0), 0.22, plate_material)
	Kit.box(visual, Vector3(0, 0.38, 0), Vector3(0.08, 0.76, 0.1), Kit.material(Color("42575b")))
	Kit.box(visual, Vector3(0, 0.08, 0), Vector3(1.1, 0.16, 0.5), Kit.material(Color("273b40")))
	Kit.box(visual, Vector3(0, 1.2, 0.09), Vector3(0.38, 0.025, 0.01), Kit.material(Color("ffe8b0"), 1))
	Kit.box(visual, Vector3(0, 1.2, 0.09), Vector3(0.025, 0.38, 0.01), Kit.material(Color("ffe8b0"), 1))
	Kit.label(visual, Vector3(0, 2.32, 0), "%02d" % number, 40, Color("f5be7c"))
	var body_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(0.64, 0.86, 0.18)
	body_shape.shape = box_shape
	body_shape.position.y = 1.16
	add_child(body_shape)
	var head_shape = CollisionShape3D.new()
	var head_sphere = SphereShape3D.new()
	head_sphere.radius = 0.22
	head_shape.shape = head_sphere
	head_shape.position.y = 1.82
	add_child(head_shape)

func take_hit(point: Vector3) -> Dictionary:
	if health <= 0.0:
		return {"headshot": false, "destroyed": false}
	var headshot = to_local(point).y > 1.58
	health = maxf(0.0, health - (100.0 if headshot else 34.0))
	flash = 0.12
	if health <= 0.0:
		reset_timer = 2.5
		collision_layer = 0
	hit.emit(headshot, health <= 0.0)
	return {"headshot": headshot, "destroyed": health <= 0.0}

func reset_target():
	health = 100.0
	reset_timer = 0.0
	collision_layer = 2
	visual.rotation.x = 0.0

func _physics_process(delta: float):
	flash = maxf(0.0, flash - delta)
	plate_material.albedo_color = Color("fff4c8") if flash > 0.0 else Color("dc714c")
	if health <= 0.0:
		visual.rotation.x = lerp_angle(visual.rotation.x, -PI * 0.48, 10.0 * delta)
		reset_timer -= delta
		if reset_timer <= 0.0:
			reset_target()
	else:
		visual.rotation.x = lerp_angle(visual.rotation.x, 0.0, 10.0 * delta)
	if moving:
		phase += delta
		position.x = origin.x + sin(phase * 0.8) * 2.2
