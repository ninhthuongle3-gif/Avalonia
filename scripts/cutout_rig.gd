extends Skeleton2D
## Runtime cutout rig built from the generated transparent parts sheet.
## Every visible part is attached to a Bone2D so art can be replaced without
## rewriting movement or combat code.

var owner_actor: Node2D
var bones := {}
var sprites := {}
var locomotion_blend := 0.0
var displayed_lean := 0.0
var displayed_aim := 0.0

const PARTS := "res://assets/character/parts/"

func _ready():
	build_rig()

func bone(name: String, parent: Node, position: Vector2) -> Bone2D:
	var result := Bone2D.new()
	result.name = name
	result.position = position
	result.auto_calculate_length_and_angle = false
	result.length = 30.0
	result.rest = Transform2D(0.0, position)
	parent.add_child(result)
	bones[name] = result
	return result

func attach(part_name: String, parent: Node, scale_value: float, offset: Vector2, z: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = part_name.to_pascal_case()
	sprite.texture = load(PARTS + part_name + ".png")
	sprite.scale = Vector2.ONE * scale_value
	sprite.offset = offset
	sprite.z_index = z
	parent.add_child(sprite)
	sprites[part_name] = sprite
	return sprite

func attach_limb(part_name: String, parent: Node, length_scale: float, z: int) -> Sprite2D:
	var texture: Texture2D = load(PARTS + part_name + ".png")
	var scale_value = length_scale / maxf(1.0, texture.get_height())
	var sprite = attach(part_name, parent, scale_value, Vector2(0, texture.get_height() * 0.48), z)
	sprite.scale.x *= 1.16
	return sprite

func build_rig():
	var body = bone("Body", self, Vector2(0, -114))
	var pelvis = bone("Pelvis", body, Vector2(0, 20))
	attach("pelvis", pelvis, 0.185, Vector2(0, 3), 0)
	attach("torso", body, 0.19, Vector2(0, -25), 1)

	var rear_thigh = bone("RearThigh", pelvis, Vector2(-7, 6))
	var rear_shin = bone("RearShin", rear_thigh, Vector2(0, 29))
	var rear_boot = bone("RearBoot", rear_shin, Vector2(0, 27))
	attach_limb("thigh_rear", rear_thigh, 36, -7)
	attach_limb("shin_rear", rear_shin, 33, -7)
	attach_limb("boot_rear", rear_boot, 30, -7)

	var front_thigh = bone("FrontThigh", pelvis, Vector2(7, 6))
	var front_shin = bone("FrontShin", front_thigh, Vector2(0, 29))
	var front_boot = bone("FrontBoot", front_shin, Vector2(0, 27))
	attach_limb("thigh_front", front_thigh, 36, 2)
	attach_limb("shin_front", front_shin, 33, 2)
	attach_limb("boot_front", front_boot, 30, 2)

	var head = bone("Head", body, Vector2(8, -67))
	attach("hair", head, 0.165, Vector2(-11, 3), -2)
	attach("head", head, 0.17, Vector2(8, -2), 4)

	var rear_upper = bone("RearUpperArm", body, Vector2(-8, -42))
	var rear_fore = bone("RearForearm", rear_upper, Vector2(0, 28))
	attach_limb("upper_arm_rear", rear_upper, 29, -3)
	attach_limb("forearm_rear", rear_fore, 27, -3)
	var front_upper = bone("FrontUpperArm", body, Vector2(11, -43))
	var front_fore = bone("FrontForearm", front_upper, Vector2(0, 29))
	attach_limb("upper_arm_front", front_upper, 29, 7)
	attach_limb("forearm_front", front_fore, 27, 7)

	var weapon = bone("Weapon", body, Vector2(9, -43))
	attach("rifle", weapon, 0.155, Vector2(145, 0), 6)
	attach("pistol", weapon, 0.19, Vector2(105, 3), 6)

	var shield = bone("Shield", body, Vector2(-25, -22))
	attach("shield", shield, 0.155, Vector2(0, 0), -10)

func _process(dt):
	if not is_instance_valid(owner_actor) or bones.is_empty():
		return
	var speed_ratio = clampf(absf(owner_actor.motion) / 315.0, 0, 1)
	locomotion_blend = move_toward(locomotion_blend, speed_ratio, dt * (4.8 if speed_ratio > locomotion_blend else 3.1))
	var desired_lean = owner_actor.body_lean
	displayed_lean = lerp_angle(displayed_lean, desired_lean, 1.0 - exp(-dt * 9.0))
	displayed_aim = lerp_angle(displayed_aim, owner_actor.aim, 1.0 - exp(-dt * (15.0 if owner_actor.weapon_ready > 0.5 else 7.0)))
	scale = Vector2(owner_actor.facing, 1)
	var phase = owner_actor.phase
	var bob = sin(phase * 2.0) * 2.0 * locomotion_blend + sin(owner_actor.clock * 2.7) * 0.55
	if owner_actor.airborne:
		bob -= 2
	bones.Body.position = Vector2(0, -114 + bob)
	bones.Body.rotation = displayed_lean - owner_actor.recoil * 0.035
	bones.Head.rotation = clampf(displayed_aim * 0.12, -0.09, 0.09) - bones.Body.rotation * 0.35

	var stride = sin(phase) * 0.53 * locomotion_blend
	var lift_front = maxf(0, -cos(phase)) * locomotion_blend
	var lift_rear = maxf(0, cos(phase)) * locomotion_blend
	if owner_actor.airborne:
		stride = -0.32
		lift_front = 0.45
		lift_rear = 0.1
	bones.FrontThigh.rotation = stride
	bones.RearThigh.rotation = -stride
	bones.FrontShin.rotation = -maxf(0, stride) * 0.78 - lift_front * 0.34
	bones.RearShin.rotation = -maxf(0, -stride) * 0.78 - lift_rear * 0.34
	bones.FrontBoot.rotation = -bones.FrontThigh.rotation - bones.FrontShin.rotation - displayed_lean
	bones.RearBoot.rotation = -bones.RearThigh.rotation - bones.RearShin.rotation - displayed_lean

	# weapon_ready supplies anticipation and follow-through: the arms rise from a
	# low-ready pose before the first round and settle only after recovery.
	var ready_angle = lerpf(0.34, displayed_aim, owner_actor.weapon_ready)
	var weapon_angle = ready_angle - bones.Body.rotation - owner_actor.recoil * 0.075
	bones.Weapon.rotation = weapon_angle
	bones.Weapon.position.x = 9 - owner_actor.recoil * 5
	var arm_angle = weapon_angle - PI * 0.5
	bones.FrontUpperArm.rotation = arm_angle + 0.20
	bones.FrontForearm.rotation = -0.40 + owner_actor.reload_pose * 1.05
	bones.RearUpperArm.rotation = arm_angle - 0.08
	bones.RearForearm.rotation = 0.22 - owner_actor.reload_pose * 0.7

	var shield_up = owner_actor.shield_blend
	bones.Shield.position = Vector2(lerpf(-27, 36, shield_up), lerpf(-20, -34, shield_up))
	bones.Shield.rotation = lerpf(-0.18, 0.03, shield_up) - bones.Body.rotation
	sprites.shield.z_index = 12 if shield_up > 0.55 else -10
	sprites.rifle.visible = owner_actor.weapon_kind == "rifle"
	sprites.pistol.visible = owner_actor.weapon_kind == "pistol"
	sprites.rifle.modulate.a = owner_actor.weapon_alpha
	sprites.pistol.modulate.a = owner_actor.weapon_alpha
	queue_redraw()
