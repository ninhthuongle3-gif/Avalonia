extends Skeleton2D
## Texture-free player rig. Every visible placeholder belongs to a named bone.
## `apply_skin_piece()` can replace any placeholder with a texture later while
## preserving animation, weapon sockets, hit timing, and gameplay code.

var owner_actor: Node2D
var bones := {}
var skin_slots := {}
var skin_sprites := {}
var sockets := {}
var weapon_shapes := {}
var locomotion_blend := 0.0
var displayed_lean := 0.0
var displayed_aim := 0.0

const EDGE = Color("101a20")
const ARMOR = Color("334149")
const ARMOR_DARK = Color("202c32")
const CLOTH = Color("182329")
const JOINT = Color("59666a")
const VISOR = Color("9bb8b8")
const SKIN = Color("c2b7aa")
const HAIR = Color("c9d0ce")
const RIFLE_LENGTH = 79.0
const PISTOL_LENGTH = 48.0

func _ready():
	build_rig()

func make_bone(name: String, parent: Node, position: Vector2, length = 30.0) -> Bone2D:
	var result := Bone2D.new()
	result.name = name
	result.position = position
	result.auto_calculate_length_and_angle = false
	result.length = length
	result.rest = Transform2D(0.0, position)
	parent.add_child(result)
	bones[name] = result
	return result

func polygon_slot(slot_name: String, parent: Node, points: PackedVector2Array, color: Color, z: int) -> Polygon2D:
	var shape := Polygon2D.new()
	shape.name = slot_name.to_pascal_case() + "Placeholder"
	shape.polygon = points
	shape.color = color
	shape.z_index = z
	parent.add_child(shape)
	skin_slots[slot_name] = shape
	return shape

func limb_slot(slot_name: String, parent: Node, width: float, length: float, color: Color, z: int) -> Polygon2D:
	return polygon_slot(slot_name, parent, PackedVector2Array([
		Vector2(-width * 0.42, -3), Vector2(width * 0.42, -3),
		Vector2(width * 0.55, length * 0.78), Vector2(width * 0.34, length + 4),
		Vector2(-width * 0.34, length + 4), Vector2(-width * 0.55, length * 0.78)
	]), color, z)

func add_joint(parent: Node, radius: float, z: int):
	var joint := Polygon2D.new()
	var points := PackedVector2Array()
	for i in range(10):
		points.append(Vector2.from_angle(i * TAU / 10.0) * radius)
	joint.polygon = points
	joint.color = JOINT
	joint.z_index = z
	parent.add_child(joint)

func build_rig():
	var body = make_bone("Body", self, Vector2(0, -108), 39)
	var pelvis = make_bone("Pelvis", body, Vector2(0, 34), 16)
	polygon_slot("torso", body, PackedVector2Array([
		Vector2(-18, -35), Vector2(17, -34), Vector2(24, 3),
		Vector2(15, 31), Vector2(-16, 31), Vector2(-24, 2)
	]), ARMOR, 1)
	polygon_slot("vest", body, PackedVector2Array([
		Vector2(-16, -17), Vector2(17, -17), Vector2(19, 23), Vector2(-17, 23)
	]), ARMOR_DARK, 3)
	polygon_slot("pelvis", pelvis, PackedVector2Array([
		Vector2(-18, -7), Vector2(18, -7), Vector2(15, 15), Vector2(-14, 15)
	]), CLOTH, 1)

	var rear_thigh = make_bone("RearThigh", pelvis, Vector2(-7, 8), 36)
	var rear_shin = make_bone("RearShin", rear_thigh, Vector2(0, 36), 37)
	var rear_foot = make_bone("RearFoot", rear_shin, Vector2(0, 37), 24)
	limb_slot("rear_thigh", rear_thigh, 17, 36, ARMOR_DARK.darkened(0.18), -6)
	limb_slot("rear_shin", rear_shin, 14, 37, CLOTH.darkened(0.12), -6)
	polygon_slot("rear_boot", rear_foot, PackedVector2Array([
		Vector2(-8, -7), Vector2(8, -7), Vector2(23, -1), Vector2(24, 7), Vector2(-9, 7)
	]), EDGE, -6)

	var front_thigh = make_bone("FrontThigh", pelvis, Vector2(7, 8), 36)
	var front_shin = make_bone("FrontShin", front_thigh, Vector2(0, 36), 37)
	var front_foot = make_bone("FrontFoot", front_shin, Vector2(0, 37), 24)
	limb_slot("front_thigh", front_thigh, 18, 36, ARMOR, 2)
	limb_slot("front_shin", front_shin, 15, 37, CLOTH, 2)
	polygon_slot("front_boot", front_foot, PackedVector2Array([
		Vector2(-8, -7), Vector2(8, -7), Vector2(23, -1), Vector2(24, 7), Vector2(-9, 7)
	]), EDGE, 2)
	for joint_name in ["RearThigh", "RearShin", "FrontThigh", "FrontShin"]:
		add_joint(bones[joint_name], 6.5, bones[joint_name].get_child(0).z_index + 1)

	var neck = make_bone("Neck", body, Vector2(0, -39), 14)
	var head = make_bone("Head", neck, Vector2(0, -13), 20)
	polygon_slot("neck", neck, PackedVector2Array([Vector2(-6, -3), Vector2(6, -3), Vector2(7, 13), Vector2(-7, 13)]), SKIN, 1)
	polygon_slot("head", head, PackedVector2Array([
		Vector2(-13, -18), Vector2(10, -20), Vector2(17, -8), Vector2(14, 13),
		Vector2(3, 21), Vector2(-11, 15), Vector2(-17, 0)
	]), SKIN, 3)
	polygon_slot("helmet", head, PackedVector2Array([
		Vector2(-17, -8), Vector2(-12, -23), Vector2(4, -29), Vector2(18, -18), Vector2(18, -7)
	]), ARMOR_DARK, 5)
	polygon_slot("hair", head, PackedVector2Array([
		Vector2(-16, -4), Vector2(-22, 11), Vector2(-18, 28), Vector2(-9, 18), Vector2(-5, 32), Vector2(3, 16)
	]), HAIR, 1)
	polygon_slot("visor", head, PackedVector2Array([Vector2(-5, -18), Vector2(20, -13), Vector2(18, -5), Vector2(-2, -8)]), VISOR, 7)

	var rear_upper = make_bone("RearUpperArm", body, Vector2(-9, -26), 30)
	var rear_fore = make_bone("RearForearm", rear_upper, Vector2(0, 30), 29)
	var front_upper = make_bone("FrontUpperArm", body, Vector2(10, -25), 30)
	var front_fore = make_bone("FrontForearm", front_upper, Vector2(0, 30), 29)
	limb_slot("rear_upper_arm", rear_upper, 14, 30, ARMOR_DARK.darkened(0.15), -3)
	limb_slot("rear_forearm", rear_fore, 12, 29, CLOTH.darkened(0.12), -3)
	limb_slot("front_upper_arm", front_upper, 15, 30, ARMOR, 7)
	limb_slot("front_forearm", front_fore, 13, 29, CLOTH, 7)
	for joint_name in ["RearUpperArm", "RearForearm", "FrontUpperArm", "FrontForearm"]:
		add_joint(bones[joint_name], 5.5, bones[joint_name].get_child(0).z_index + 1)

	var weapon = make_bone("Weapon", body, Vector2(8, -18), RIFLE_LENGTH)
	var rifle = polygon_slot("rifle", weapon, PackedVector2Array([
		Vector2(-17, -7), Vector2(3, -7), Vector2(9, -12), Vector2(55, -10),
		Vector2(61, -5), Vector2(79, -4), Vector2(79, 2), Vector2(40, 3),
		Vector2(33, 15), Vector2(24, 14), Vector2(25, 3), Vector2(-17, 4)
	]), Color("202a30"), 6)
	var pistol = polygon_slot("pistol", weapon, PackedVector2Array([
		Vector2(-5, -7), Vector2(47, -6), Vector2(48, 1), Vector2(17, 4),
		Vector2(14, 21), Vector2(4, 20), Vector2(3, 3), Vector2(-5, 2)
	]), Color("242f35"), 6)
	weapon_shapes.rifle = rifle
	weapon_shapes.pistol = pistol
	var muzzle = Marker2D.new()
	muzzle.name = "Muzzle"
	weapon.add_child(muzzle)
	sockets.Muzzle = muzzle
	var eject = Marker2D.new()
	eject.name = "EjectPort"
	eject.position = Vector2(11, -10)
	weapon.add_child(eject)
	sockets.EjectPort = eject

	var shield = make_bone("Shield", body, Vector2(-27, -8), 75)
	polygon_slot("shield", shield, PackedVector2Array([
		Vector2(-20, -43), Vector2(18, -43), Vector2(27, -32), Vector2(27, 37),
		Vector2(13, 50), Vector2(-18, 44), Vector2(-28, 29), Vector2(-28, -31)
	]), Color("26343b"), -10)

func apply_skin_piece(slot_name: String, texture: Texture2D, offset = Vector2.ZERO, scale_value = Vector2.ONE) -> bool:
	if not skin_slots.has(slot_name):
		return false
	var placeholder: Polygon2D = skin_slots[slot_name]
	placeholder.visible = texture == null
	if skin_sprites.has(slot_name) and is_instance_valid(skin_sprites[slot_name]):
		skin_sprites[slot_name].queue_free()
		skin_sprites.erase(slot_name)
	if texture != null:
		var sprite := Sprite2D.new()
		sprite.name = slot_name.to_pascal_case() + "Skin"
		sprite.texture = texture
		sprite.position = offset
		sprite.scale = scale_value
		sprite.z_index = placeholder.z_index
		placeholder.get_parent().add_child(sprite)
		skin_sprites[slot_name] = sprite
	return true

func get_socket(name: String) -> Marker2D:
	return sockets.get(name)

func solve_chain(upper: Bone2D, lower: Bone2D, target: Vector2, upper_length: float, lower_length: float, bend: float):
	var shoulder = upper.position
	var relative = target - shoulder
	var distance = clampf(relative.length(), 4.0, upper_length + lower_length - 0.5)
	var alpha = relative.angle()
	var joint = bend * acos(clampf((distance * distance - upper_length * upper_length - lower_length * lower_length) / (2.0 * upper_length * lower_length), -1.0, 1.0))
	upper.rotation = alpha - atan2(lower_length * sin(joint), upper_length + lower_length * cos(joint)) - PI * 0.5
	lower.rotation = joint

func update_pose(dt: float, immediate = false):
	if not is_instance_valid(owner_actor) or bones.is_empty():
		return
	var speed_ratio = clampf(absf(owner_actor.motion) / 315.0, 0, 1)
	if immediate:
		locomotion_blend = speed_ratio
		displayed_lean = owner_actor.body_lean
		displayed_aim = owner_actor.aim
	else:
		locomotion_blend = move_toward(locomotion_blend, speed_ratio, dt * (5.4 if speed_ratio > locomotion_blend else 3.4))
		displayed_lean = lerp_angle(displayed_lean, owner_actor.body_lean, 1.0 - exp(-dt * 10.0))
		displayed_aim = lerp_angle(displayed_aim, owner_actor.aim, 1.0 - exp(-dt * 17.0))
	scale = Vector2(owner_actor.facing, 1)
	var phase = owner_actor.phase
	var gait_energy = locomotion_blend * (1.25 if absf(owner_actor.motion) > 245 else 0.8)
	var bob = sin(phase * 2.0) * 2.6 * gait_energy + sin(owner_actor.clock * 2.6) * (0.65 if speed_ratio < 0.08 else 0.2)
	if owner_actor.airborne:
		bob = -3
	bones.Body.position = Vector2(0, -108 + bob)
	bones.Body.rotation = displayed_lean - owner_actor.recoil * 0.035
	bones.Pelvis.rotation = -bones.Body.rotation * 0.28 + sin(phase * 2.0) * 0.045 * locomotion_blend
	bones.Neck.rotation = -bones.Body.rotation * 0.32
	bones.Head.rotation = clampf(displayed_aim * 0.1, -0.08, 0.08) - bones.Body.rotation * 0.22

	var stride_distance = lerpf(7.0, 31.0, locomotion_blend) * (1.17 if absf(owner_actor.motion) > 245 else 1.0)
	var hip_height = 78.0 - absf(sin(phase)) * 3.0 * locomotion_blend
	var front_target = Vector2(sin(phase) * stride_distance + 6, hip_height - maxf(0, cos(phase)) * 18.0 * locomotion_blend)
	var rear_target = Vector2(sin(phase + PI) * stride_distance - 6, hip_height - maxf(0, cos(phase + PI)) * 18.0 * locomotion_blend)
	if owner_actor.motion * owner_actor.facing < 0:
		front_target.x *= -1
		rear_target.x *= -1
	if owner_actor.airborne:
		front_target = Vector2(20, 55)
		rear_target = Vector2(-18, 62)
	solve_chain(bones.FrontThigh, bones.FrontShin, front_target, 36, 37, -1)
	solve_chain(bones.RearThigh, bones.RearShin, rear_target, 36, 37, 1)
	bones.FrontFoot.rotation = -bones.FrontThigh.rotation - bones.FrontShin.rotation - bones.Pelvis.rotation - bones.Body.rotation
	bones.RearFoot.rotation = -bones.RearThigh.rotation - bones.RearShin.rotation - bones.Pelvis.rotation - bones.Body.rotation

	var ready_angle = lerpf(0.34, displayed_aim, owner_actor.weapon_ready)
	var weapon_angle = ready_angle - bones.Body.rotation - owner_actor.recoil * 0.085
	bones.Weapon.rotation = weapon_angle
	bones.Weapon.position = Vector2(8 - owner_actor.recoil * 5, -18 + owner_actor.reload_pose * 5)
	var front_grip = bones.Weapon.position + Vector2(37, 3).rotated(weapon_angle)
	var rear_grip = bones.Weapon.position + Vector2(4, 4).rotated(weapon_angle)
	if owner_actor.weapon_kind == "pistol":
		front_grip = bones.Weapon.position + Vector2(8, 4).rotated(weapon_angle)
	if owner_actor.reload_pose > 0.01:
		front_grip += Vector2(-12, 25) * owner_actor.reload_pose
	solve_chain(bones.FrontUpperArm, bones.FrontForearm, front_grip, 30, 29, -1)
	solve_chain(bones.RearUpperArm, bones.RearForearm, rear_grip, 30, 29, 1)

	var shield_up = owner_actor.shield_blend
	bones.Shield.position = Vector2(lerpf(-27, 38, shield_up), lerpf(-8, -26, shield_up))
	bones.Shield.rotation = lerpf(-0.22, 0.02, shield_up) - bones.Body.rotation
	skin_slots.shield.z_index = 12 if shield_up > 0.55 else -10
	weapon_shapes.rifle.visible = owner_actor.weapon_kind == "rifle"
	weapon_shapes.pistol.visible = owner_actor.weapon_kind == "pistol"
	weapon_shapes.rifle.modulate.a = owner_actor.weapon_alpha
	weapon_shapes.pistol.modulate.a = owner_actor.weapon_alpha
	sockets.Muzzle.position = Vector2(RIFLE_LENGTH, -2) if owner_actor.weapon_kind == "rifle" else Vector2(PISTOL_LENGTH, -2)
	sockets.EjectPort.position = Vector2(12, -10) if owner_actor.weapon_kind == "rifle" else Vector2(7, -8)

func _process(dt):
	update_pose(dt)
