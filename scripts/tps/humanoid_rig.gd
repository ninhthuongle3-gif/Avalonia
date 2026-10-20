extends Node3D
## A real, inspectable Skeleton3D with layered procedural poses and two-bone IK.
## Feet are stored in world space during stance, not animated by a looping sine.
const Kit = preload("res://scripts/tps/geometry.gd")
signal footstep
var skeleton: Skeleton3D
var bones: Dictionary = {}
var attachments: Dictionary = {}
var weapon: Node3D
var muzzle: Marker3D
var muzzle_flash: MeshInstance3D
var right_grip: Marker3D
var left_grip: Marker3D
var magazine: Marker3D
var infected: bool = false
var gait_phase: float = 0.0
var travelled: float = 0.0
var animation_state: String = "idle"
var aim_blend: float = 0.0
var sprint_blend: float = 0.0
var lean: Vector2 = Vector2.ZERO
var pelvis_height: float = 0.94
var feet: Dictionary = {}
var stance: Dictionary = {}
var swing_start: Dictionary = {}
var last_origin: Vector3
var initialized_feet: bool = false
var debug_markers: Array = []
var debug_visible: bool = false
var clock: float = 0.0
var last_grounded: bool = true
var landing: float = 0.0
var settle: Dictionary = {"left": -1.0, "right": -1.0}
var settle_from: Dictionary = {}

func _ready():
	name = "Humanoid"
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	add_child(skeleton)
	bone("root", "", Vector3.ZERO)
	bone("pelvis", "root", Vector3(0, 0.94, 0))
	bone("spine", "pelvis", Vector3(0, 0.14, 0))
	bone("chest", "spine", Vector3(0, 0.22, 0))
	bone("neck", "chest", Vector3(0, 0.19, 0))
	bone("head", "neck", Vector3(0, 0.13, 0))
	for side in ["left", "right"]:
		var sign_x = -1.0 if side == "left" else 1.0
		bone(side + "_clavicle", "chest", Vector3(sign_x * 0.19, 0.1, 0))
		bone(side + "_upper_arm", side + "_clavicle", Vector3(sign_x * 0.085, 0, 0))
		bone(side + "_forearm", side + "_upper_arm", Vector3(0, -0.3, 0))
		bone(side + "_hand", side + "_forearm", Vector3(0, -0.29, 0))
		bone(side + "_index", side + "_hand", Vector3(0, -0.055, -0.035))
		bone(side + "_thumb", side + "_hand", Vector3(-sign_x * 0.045, -0.02, 0))
		bone(side + "_thigh", "pelvis", Vector3(sign_x * 0.13, -0.035, 0))
		bone(side + "_shin", side + "_thigh", Vector3(0, -0.45, 0))
		bone(side + "_foot", side + "_shin", Vector3(0, -0.43, 0))
		bone(side + "_toe", side + "_foot", Vector3(0, 0, -0.14))
	bone("hair_upper", "head", Vector3(0, 0.08, 0.15))
	bone("hair_lower", "hair_upper", Vector3(0, -0.22, 0.05))
	bone("coat_left", "pelvis", Vector3(-0.15, 0.03, 0.12))
	bone("coat_right", "pelvis", Vector3(0.15, 0.03, 0.12))
	skeleton.reset_bone_poses()
	skeleton.force_update_all_bone_transforms()
	build_meshes()
	if not infected:
		build_weapon()
	last_origin = global_position

func bone(bone_name: String, parent_name: String, offset: Vector3):
	var index = skeleton.get_bone_count()
	skeleton.add_bone(bone_name)
	bones[bone_name] = index
	if parent_name != "":
		skeleton.set_bone_parent(index, bones[parent_name])
	skeleton.set_bone_rest(index, Transform3D(Basis.IDENTITY, offset))
	var attachment = BoneAttachment3D.new()
	attachment.name = bone_name + "_Slot"
	attachment.bone_name = bone_name
	skeleton.add_child(attachment)
	attachments[bone_name] = attachment

func build_meshes():
	var coat = Kit.material(Color("384940") if infected else Color("244f59"))
	var dark = Kit.material(Color("272e29") if infected else Color("172630"))
	var skin = Kit.material(Color("82936c") if infected else Color("e8b89c"))
	var hair = Kit.material(Color("343c32") if infected else Color("c3ccd5"))
	var light = Kit.material(Color("dc6b49") if infected else Color("64cbb9"), 0.35)
	Kit.box(attachments.pelvis, Vector3(0, 0, 0), Vector3(0.38, 0.16, 0.25), dark)
	Kit.box(attachments.spine, Vector3(0, 0.06, 0), Vector3(0.31, 0.24, 0.25), coat)
	Kit.box(attachments.chest, Vector3(0, 0.04, 0), Vector3(0.43, 0.25, 0.28), coat)
	Kit.box(attachments.chest, Vector3(0, 0.01, 0.19), Vector3(0.29, 0.3, 0.12), dark)
	Kit.box(attachments.chest, Vector3(0, 0.08, 0.26), Vector3(0.18, 0.025, 0.015), light)
	Kit.box(attachments.pelvis, Vector3(0, 0.06, 0), Vector3(0.39, 0.05, 0.28), light)
	Kit.sphere(attachments.neck, Vector3.ZERO, 0.075, skin)
	Kit.sphere(attachments.head, Vector3(0, 0.035, 0), 0.19, skin)
	Kit.sphere(attachments.head, Vector3(0, 0.115, 0.025), 0.19, hair)
	Kit.box(attachments.head, Vector3(0, 0.015, 0.15), Vector3(0.31, 0.24, 0.07), hair)
	for x in [-0.07, 0.07]:
		Kit.box(attachments.head, Vector3(x, 0.035, -0.178), Vector3(0.04, 0.018, 0.012), light)
	for side in ["left", "right"]:
		Kit.sphere(attachments[side + "_upper_arm"], Vector3.ZERO, 0.105, coat)
		Kit.box(attachments[side + "_upper_arm"], Vector3(0, -0.15, 0), Vector3(0.135, 0.29, 0.15), coat)
		Kit.sphere(attachments[side + "_forearm"], Vector3.ZERO, 0.075, dark)
		Kit.box(attachments[side + "_forearm"], Vector3(0, -0.145, 0), Vector3(0.11, 0.27, 0.12), coat)
		Kit.box(attachments[side + "_hand"], Vector3(0, -0.035, 0), Vector3(0.1, 0.09, 0.07), skin)
		Kit.box(attachments[side + "_index"], Vector3(0, -0.025, 0), Vector3(0.025, 0.05, 0.025), skin)
		Kit.box(attachments[side + "_thumb"], Vector3(0, -0.018, 0), Vector3(0.025, 0.045, 0.03), skin)
		Kit.box(attachments[side + "_thigh"], Vector3(0, -0.225, 0), Vector3(0.17, 0.43, 0.19), dark)
		Kit.sphere(attachments[side + "_shin"], Vector3.ZERO, 0.088, coat)
		Kit.box(attachments[side + "_shin"], Vector3(0, -0.21, 0), Vector3(0.145, 0.39, 0.16), dark)
		Kit.box(attachments[side + "_foot"], Vector3(0, -0.035, -0.055), Vector3(0.17, 0.14, 0.28), dark)
		Kit.box(attachments[side + "_toe"], Vector3(0, -0.035, -0.035), Vector3(0.17, 0.12, 0.09), dark)
		Kit.box(attachments["coat_" + side], Vector3(0, -0.17, 0), Vector3(0.18, 0.34, 0.055), coat)
	if not infected:
		Kit.box(attachments.hair_upper, Vector3(0, -0.11, 0.02), Vector3(0.13, 0.24, 0.12), hair)
		Kit.box(attachments.hair_lower, Vector3(0, -0.1, 0), Vector3(0.1, 0.22, 0.1), hair)
		for attachment in attachments.values():
			var marker = Kit.sphere(attachment, Vector3.ZERO, 0.028, Kit.material(Color("75ffb8"), 1))
			marker.visible = false
			debug_markers.append(marker)

func build_weapon():
	weapon = Node3D.new()
	weapon.name = "WeaponMount"
	add_child(weapon)
	var metal = Kit.material(Color("19262b"))
	Kit.box(weapon, Vector3(0, 0, -0.25), Vector3(0.1, 0.14, 0.5), metal)
	Kit.box(weapon, Vector3(0, 0, 0.1), Vector3(0.11, 0.13, 0.2), metal)
	Kit.box(weapon, Vector3(0, 0, -0.62), Vector3(0.045, 0.045, 0.3), Kit.material(Color("64777c")))
	Kit.box(weapon, Vector3(0, -0.13, -0.23), Vector3(0.08, 0.22, 0.12), metal)
	Kit.box(weapon, Vector3(0, -0.09, -0.06), Vector3(0.06, 0.14, 0.06), metal)
	Kit.box(weapon, Vector3(0, 0.09, -0.19), Vector3(0.055, 0.065, 0.12), Kit.material(Color("5ebdab")))
	muzzle = Marker3D.new()
	muzzle.name = "Muzzle"
	weapon.add_child(muzzle)
	muzzle.position.z = -0.79
	muzzle_flash = Kit.sphere(muzzle, Vector3(0, 0, -0.04), 0.08, Kit.material(Color("ffe6a0"), 4))
	muzzle_flash.scale = Vector3(0.6, 0.6, 2)
	muzzle_flash.visible = false
	right_grip = Marker3D.new()
	weapon.add_child(right_grip)
	right_grip.position = Vector3(0, -0.06, -0.06)
	left_grip = Marker3D.new()
	weapon.add_child(left_grip)
	left_grip.position = Vector3(-0.02, -0.06, -0.24)
	magazine = Marker3D.new()
	weapon.add_child(magazine)
	magazine.position = Vector3(-0.03, -0.18, -0.23)

func toggle_debug():
	debug_visible = not debug_visible
	for marker in debug_markers:
		marker.visible = debug_visible

func bone_pose(bone_name: String) -> Transform3D:
	skeleton.force_update_all_bone_transforms()
	return skeleton.get_bone_global_pose(bones[bone_name])

func global_pose(bone_name: String, pose: Transform3D):
	var index: int = bones[bone_name]
	var parent = skeleton.get_bone_parent(index)
	var local = pose
	if parent >= 0:
		skeleton.force_update_all_bone_transforms()
		local = skeleton.get_bone_global_pose(parent).affine_inverse() * pose
	skeleton.set_bone_pose_position(index, local.origin)
	skeleton.set_bone_pose_rotation(index, local.basis.get_rotation_quaternion())

func rotate_bone(bone_name: String, angles: Vector3):
	skeleton.set_bone_pose_rotation(bones[bone_name], Quaternion.from_euler(angles))

func solve_limb(upper: String, lower: String, end: String, target: Vector3, pole: Vector3, first: float, second: float):
	var hip: Vector3 = bone_pose(upper).origin
	var offset = target - hip
	var distance = clampf(offset.length(), 0.05, first + second - 0.006)
	var direction = offset.normalized() if offset.length() > 0.001 else Vector3.DOWN
	var across = pole - direction * pole.dot(direction)
	if across.length_squared() < 0.001:
		across = Vector3.FORWARD.cross(direction)
	across = across.normalized()
	var along = (first * first - second * second + distance * distance) / (2 * distance)
	var height = sqrt(maxf(0, first * first - along * along))
	var joint = hip + direction * along + across * height
	var tip = hip + direction * distance
	global_pose(upper, Transform3D(Basis(Quaternion(Vector3.DOWN, (joint - hip).normalized())), hip))
	global_pose(lower, Transform3D(Basis(Quaternion(Vector3.DOWN, (tip - joint).normalized())), joint))
	global_pose(end, Transform3D(Basis.IDENTITY, tip))

func ground_foot(point: Vector3) -> Vector3:
	var query = PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.5, point - Vector3.UP * 1.1, 1)
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		point.y = hit.position.y + 0.105
	return point

func reset_feet():
	gait_phase = 0.25
	for side in ["left", "right"]:
		var x = -0.13 if side == "left" else 0.13
		feet[side] = ground_foot(to_global(Vector3(x, 0.105, 0)))
		swing_start[side] = feet[side]
		stance[side] = true
		settle[side] = -1.0
	last_origin = global_position
	initialized_feet = true

func update_pose(delta: float, data: Dictionary):
	clock += delta
	animation_state = data.get("state", "idle")
	var move: Vector3 = data.get("velocity", Vector3.ZERO)
	var speed = Vector2(move.x, move.z).length()
	var grounded: bool = data.get("grounded", true)
	var step_distance: float = data.get("distance", 0.0)
	var aim: float = data.get("aim", 0.0)
	var sprint: float = data.get("sprint", 0.0)
	aim_blend = move_toward(aim_blend, aim, delta * 5)
	sprint_blend = move_toward(sprint_blend, sprint, delta * 3)
	var acceleration: Vector3 = global_basis.inverse() * data.get("acceleration", Vector3.ZERO)
	var desired_lean = Vector2(clampf(-acceleration.z * 0.012 + speed * sprint_blend * 0.018, -0.16, 0.22), clampf(-acceleration.x * 0.015, -0.16, 0.16))
	lean = lean.lerp(desired_lean, 1.0 - exp(-delta * 7))
	if grounded and not last_grounded:
		landing = 1.0
		initialized_feet = false
	last_grounded = grounded
	landing = move_toward(landing, 0.0, delta * 4)
	if not initialized_feet or global_position.distance_to(last_origin) > 2.5:
		reset_feet()
	last_origin = global_position
	var run_blend = clampf(speed / 4.4, 0, 1)
	var stride = lerpf(lerpf(1.15, 2.4, run_blend), 3.3, sprint_blend)
	if aim_blend > 0.1:
		stride = lerpf(stride, 1.05, aim_blend)
	if grounded:
		gait_phase += step_distance / stride
		travelled += step_distance
	skeleton.reset_bone_poses()
	var bounce = absf(sin(gait_phase * TAU * 2)) * minf(speed / 4, 1.0) * 0.025
	pelvis_height = 0.94 + bounce - landing * 0.09 - run_blend * 0.035 - sprint_blend * 0.03
	skeleton.set_bone_pose_position(bones.pelvis, Vector3(0, pelvis_height, 0))
	rotate_bone("pelvis", Vector3(-lean.x * 0.2, sin(gait_phase * TAU) * 0.035 * minf(speed, 1), lean.y * 0.3))
	rotate_bone("spine", Vector3(-lean.x * 0.65, data.get("aim_yaw", 0.0) * aim_blend * 0.3, lean.y * 0.5))
	rotate_bone("chest", Vector3(-lean.x * 0.35 + data.get("pitch", 0.0) * aim_blend * 0.25, 0, 0))
	rotate_bone("neck", Vector3(data.get("pitch", 0.0) * aim_blend * 0.3, data.get("aim_yaw", 0.0) * 0.25, 0))
	rotate_bone("hair_upper", Vector3(lean.x * 1.2 + sin(clock * 7) * speed * 0.004, 0, -lean.y))
	rotate_bone("hair_lower", Vector3(sin(clock * 8 - 0.5) * speed * 0.009, 0, lean.y * 0.7))
	for side in ["left", "right"]:
		rotate_bone("coat_" + side, Vector3(0.1 + speed * 0.035 + sin(gait_phase * TAU + (PI if side == "left" else 0)) * speed * 0.018, 0, 0))
		animate_foot(side, step_distance, stride, move, grounded, delta)
	if infected:
		animate_infected(data)
	else:
		animate_weapon(data, speed)
	if animation_state == "dead":
		rotate_bone("root", Vector3(-data.get("death", 0.0) * 1.45, 0, 0.12))
	if animation_state == "hurt" or animation_state == "stagger":
		rotate_bone("chest", Vector3(0.18, 0.1, 0.08))
	skeleton.force_update_all_bone_transforms()

func animate_foot(side: String, distance: float, stride: float, move: Vector3, grounded: bool, delta: float):
	var x = -0.13 if side == "left" else 0.13
	var neutral = to_global(Vector3(x, 0.105, 0))
	var cycle = fposmod(gait_phase + (0.5 if side == "right" else 0.0), 1.0)
	var speed = Vector2(move.x, move.z).length()
	var planted_time = lerpf(lerpf(0.62, 0.34, clampf(speed / 4.4, 0, 1)), 0.27, sprint_blend)
	planted_time = lerpf(planted_time, 0.62, aim_blend)
	if not grounded:
		var tuck = Vector3(x, 0.25, 0.12 if side == "left" else -0.12)
		feet[side] = to_global(tuck)
		stance[side] = false
	elif distance < 0.0001 or speed < 0.05:
		var target = ground_foot(neutral)
		if settle[side] < 0 and feet[side].distance_to(target) > 0.08:
			settle[side] = 0.0
			settle_from[side] = feet[side]
		if settle[side] >= 0:
			settle[side] = minf(1.0, settle[side] + delta / 0.22)
			feet[side] = settle_from[side].lerp(target, smoothstep(0, 1, settle[side]))
			feet[side].y += sin(settle[side] * PI) * 0.07
			if settle[side] >= 1:
				settle[side] = -1.0
		stance[side] = settle[side] < 0
	else:
		settle[side] = -1.0
		var direction = Vector3(move.x, 0, move.z).normalized()
		var landing_point = ground_foot(neutral + direction * stride * planted_time * 0.5)
		if cycle < planted_time:
			if not stance[side]:
				feet[side] = landing_point
				footstep.emit()
			stance[side] = true
		else:
			if stance[side]:
				swing_start[side] = feet[side]
			stance[side] = false
			var progress = (cycle - planted_time) / (1.0 - planted_time)
			feet[side] = swing_start[side].lerp(landing_point, smoothstep(0, 1, progress))
			feet[side].y += sin(progress * PI) * lerpf(0.1, 0.23, sprint_blend)
	var endpoint = to_local(feet[side])
	solve_limb(side + "_thigh", side + "_shin", side + "_foot", endpoint, Vector3(0, 0, -1), 0.45, 0.43)
	rotate_bone(side + "_toe", Vector3(-0.12 if not stance[side] else 0.0, 0, 0))

func animate_weapon(data: Dictionary, speed: float):
	var pitch: float = data.get("pitch", 0.0)
	var recoil: float = data.get("recoil", 0.0)
	var reload: float = data.get("reload", -1.0)
	var sway = sin(gait_phase * TAU) * minf(speed, 4) * 0.008 * (1.0 - aim_blend)
	weapon.position = Vector3(lerpf(0.23, 0.15, aim_blend), lerpf(1.03, 1.38, aim_blend) + sway, lerpf(-0.12, -0.14, aim_blend) + recoil * 0.6)
	weapon.rotation = Vector3(lerpf(-0.95 - sprint_blend * 0.22, pitch + recoil * 0.6, aim_blend), data.get("aim_yaw", 0.0) * aim_blend, lerpf(-0.15, 0.0, aim_blend))
	if reload >= 0.0:
		weapon.rotation.z -= sin(reload * PI) * 0.45
		weapon.position.y -= sin(reload * PI) * 0.12
	var right_hand = to_local(right_grip.global_position)
	var left_hand = to_local(left_grip.global_position)
	if reload >= 0.0:
		var reach = sin(clampf(reload / 0.8, 0, 1) * PI)
		left_hand = left_hand.lerp(to_local(magazine.global_position) + Vector3(-0.04, -0.12 * sin(reload * TAU), 0), reach)
	solve_limb("right_upper_arm", "right_forearm", "right_hand", right_hand, Vector3(0.6, -0.7, 0.2), 0.3, 0.29)
	solve_limb("left_upper_arm", "left_forearm", "left_hand", left_hand, Vector3(-0.6, -0.7, 0.15), 0.3, 0.29)
	for side in ["left", "right"]:
		rotate_bone(side + "_index", Vector3(-0.6 if aim_blend > 0.5 else -0.2, 0, 0))
		rotate_bone(side + "_thumb", Vector3(0, 0, 0.4 if side == "left" else -0.4))

func animate_infected(data: Dictionary):
	var attack: float = data.get("attack", 0.0)
	rotate_bone("spine", Vector3(-0.22, 0, sin(clock * 2) * 0.04))
	rotate_bone("head", Vector3(0.15, sin(clock) * 0.1, 0.08))
	for side in ["left", "right"]:
		var sign_x = -1.0 if side == "left" else 1.0
		var hand = Vector3(sign_x * (0.27 + attack * 0.08), 1.03 + attack * 0.35, -0.42 - attack * 0.12)
		hand.y += sin(gait_phase * TAU + sign_x) * 0.035
		solve_limb(side + "_upper_arm", side + "_forearm", side + "_hand", hand, Vector3(sign_x, -0.5, 0.1), 0.3, 0.29)
