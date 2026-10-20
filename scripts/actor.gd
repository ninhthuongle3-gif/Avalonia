extends Node2D
## Shared actor state. The player uses a replaceable Skeleton2D rig; zombies use
## procedural silhouettes with type-specific locomotion and attack poses.

const SkeletalRig = preload("res://scripts/skeletal_rig.gd")

var zombie = false
var zombie_kind = "slow"
var facing = 1.0
var aim = 0.0
var motion = 0.0
var phase = 0.0
var clock = 0.0
var recoil = 0.0
var flash = 0.0
var hurt = 0.0
var shielding = false
var reload_progress = -1.0
var airborne = false
var death = 0.0
var attack = 0.0
var variant = 0
var floor_y = 700.0
var body_lean = 0.0
var weapon_ready = 0.0
var shield_blend = 0.0
var reload_pose = 0.0
var weapon_kind = "rifle"
var weapon_alpha = 1.0
var skeletal_rig: Skeleton2D

const EDGE = Color("101c22")

func _ready():
	if not zombie:
		skeletal_rig = SkeletalRig.new()
		skeletal_rig.owner_actor = self
		add_child(skeletal_rig)

func _process(dt):
	clock += dt
	var gait_rate = {"slow": 0.72, "fast": 1.15, "runner": 1.72, "crawler": 1.35}.get(zombie_kind, 1.0)
	var stride_weight = clampf(abs(motion) / (130.0 if zombie_kind == "runner" else 85.0), 0.0, 1.0)
	if stride_weight > 0.01:
		phase += dt * (3.4 + absf(motion) * 0.032) * gait_rate
	recoil = move_toward(recoil, 0.0, dt * 9.0)
	flash = maxf(0.0, flash - dt)
	hurt = maxf(0.0, hurt - dt * 5.0)
	shield_blend = move_toward(shield_blend, 1.0 if shielding else 0.0, dt * 7.5)
	reload_pose = move_toward(reload_pose, sin(clampf(reload_progress, 0, 1) * PI) if reload_progress >= 0 else 0.0, dt * 8.0)
	queue_redraw()

func sync_rig():
	if is_instance_valid(skeletal_rig):
		skeletal_rig.update_pose(0.0, true)

func weapon_socket_world(socket_name: String) -> Vector2:
	sync_rig()
	if not is_instance_valid(skeletal_rig):
		return position + Vector2(facing * 70, -105)
	var marker = skeletal_rig.get_socket(socket_name)
	if marker == null or get_parent() == null:
		return position + Vector2(facing * 70, -105)
	return get_parent().to_local(marker.global_position)

func poly(points: Array, color: Color, outline = true):
	var packed = PackedVector2Array(points)
	draw_colored_polygon(packed, color)
	if outline:
		packed.append(packed[0])
		draw_polyline(packed, EDGE, 2.0, true)

func limb(a: Vector2, b: Vector2, width: float, color: Color):
	draw_line(a, b, EDGE, width + 4.5, true)
	draw_circle(a, width * 0.5 + 1, EDGE)
	draw_circle(b, width * 0.5 + 1, EDGE)
	draw_line(a, b, color, width, true)
	draw_circle(a, width * 0.5, color)
	draw_circle(b, width * 0.5, color)

func knee(a: Vector2, foot: Vector2, bend: float, limb_length = 35.0) -> Vector2:
	var delta = foot - a
	var distance = clampf(delta.length(), 0.01, limb_length * 2.0 - 1.0)
	return a + delta * 0.5 + Vector2(-delta.y, delta.x).normalized() * sqrt(maxf(0, limb_length * limb_length - distance * distance * 0.25)) * bend

func hit_profile() -> Dictionary:
	if zombie_kind == "crawler":
		return {"body_offset": Vector2(-4, -38), "body_radius": 25.0, "head_offset": Vector2(31 * facing, -46), "head_radius": 14.0}
	var head_y = -120.0 if zombie_kind == "runner" else -128.0
	return {"body_offset": Vector2(5 * facing, -84), "body_radius": 28.0, "head_offset": Vector2(6 * facing, head_y), "head_radius": 17.0}

func _draw():
	if not zombie:
		if hurt > 0:
			draw_circle(Vector2(0, -94), 30, Color(1, 0.44, 0.26, hurt * 0.2))
		return
	draw_set_transform(Vector2.ZERO, 0, Vector2(facing, 1))
	if zombie_kind == "crawler":
		draw_crawler()
	else:
		draw_upright_zombie()
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if hurt > 0:
		var profile = hit_profile()
		draw_circle(profile.body_offset, profile.body_radius, Color(1, 0.46, 0.26, hurt * 0.18))

func zombie_palette() -> Array:
	var coats = {
		"slow": [Color("49584e"), Color("56504a"), Color("445155")],
		"fast": [Color("5c5748"), Color("4d5b51"), Color("56444a")],
		"runner": [Color("443f3b"), Color("4d3737"), Color("3f4a45")],
		"crawler": [Color("3d4841"), Color("4c433c"), Color("35464a")]
	}
	return coats.get(zombie_kind, coats.slow)

func draw_upright_zombie():
	var coat: Color = zombie_palette()[variant % 3]
	var skin = Color("8a9d7e") if hurt <= 0 else Color("e5c9a0")
	var speed_ratio = clampf(absf(motion) / 125.0, 0, 1)
	var type_stride = {"slow": 18.0, "fast": 27.0, "runner": 38.0}.get(zombie_kind, 22.0)
	var lift_scale = {"slow": 7.0, "fast": 15.0, "runner": 22.0}.get(zombie_kind, 12.0)
	var forward_lean = {"slow": 0.10, "fast": 0.20, "runner": 0.38}.get(zombie_kind, 0.1)
	var irregular = sin(clock * (1.9 + variant * 0.37) + variant) * (0.08 if zombie_kind == "slow" else 0.035)
	var body_rotation = forward_lean * speed_ratio + irregular - attack * 0.18
	var bob = absf(sin(phase)) * -4.0 * speed_ratio + sin(clock * 2.1 + variant) * (2.2 if zombie_kind == "slow" else 0.8)
	if death > 0:
		draw_set_transform(Vector2(0, -5), -death * 1.45, Vector2.ONE)
	else:
		draw_set_transform(Vector2(0, bob), body_rotation, Vector2.ONE)
	var hip = Vector2(0, -63)
	for back in [true, false]:
		var local_phase = phase + (PI if back else 0.0)
		var stride = sin(local_phase) * type_stride * speed_ratio
		var lift = maxf(0, cos(local_phase)) * lift_scale * speed_ratio
		if zombie_kind == "slow" and back:
			lift *= 0.35
		var foot = Vector2(stride + (-5 if back else 5), -lift)
		var joint = knee(hip + Vector2(-4 if back else 4, 0), foot + Vector2(0, -7), -1.0 if not back else 1.0)
		var leg_color = coat.darkened(0.28 if back else 0.12)
		limb(hip, joint, 17, leg_color)
		limb(joint, foot + Vector2(0, -7), 13, leg_color.darkened(0.08))
		poly([foot + Vector2(-9, -9), foot + Vector2(8, -8), foot + Vector2(17, -2), foot + Vector2(16, 3), foot + Vector2(-10, 3)], Color("17232a"))

	var lurch = sin(phase * 0.5 + variant) * (5.0 if zombie_kind == "slow" else 2.0)
	poly([Vector2(-22 + lurch, -113), Vector2(14 + lurch, -112), Vector2(25 + lurch, -82), Vector2(15 + lurch, -59), Vector2(-22 + lurch, -63), Vector2(-27 + lurch, -93)], coat)
	poly([Vector2(-7 + lurch, -137), Vector2(15 + lurch, -139), Vector2(24 + lurch, -125), Vector2(18 + lurch, -108), Vector2(2 + lurch, -107), Vector2(-10 + lurch, -120)], skin)
	poly([Vector2(-11 + lurch, -132), Vector2(-7 + lurch, -145), Vector2(9 + lurch, -147), Vector2(23 + lurch, -136), Vector2(25 + lurch, -127), Vector2(9 + lurch, -135), Vector2(-2 + lurch, -130)], Color("293a33"))
	draw_line(Vector2(12 + lurch, -126), Vector2(20 + lurch, -127), Color("e2be72"), 3, true)
	var arm_swing = sin(phase + PI * 0.5) * (18.0 if zombie_kind == "runner" else 7.0) * speed_ratio
	for back in [true, false]:
		var shoulder = Vector2(lurch + (-9 if back else 10), -102)
		var side = -1.0 if back else 1.0
		var extension = attack * (32.0 if zombie_kind == "runner" else 25.0)
		var elbow: Vector2
		var hand: Vector2
		if zombie_kind == "runner" and attack < 0.05:
			elbow = shoulder + Vector2(-arm_swing * side * 0.55, 22)
			hand = elbow + Vector2(arm_swing * side, 16)
		else:
			elbow = shoulder + Vector2(19 + extension * 0.35, 13 + side * arm_swing * 0.18)
			hand = shoulder + Vector2(39 + extension, 8 + side * arm_swing * 0.2)
		limb(shoulder, elbow, 13, coat.darkened(0.16 if back else 0.02))
		limb(elbow, hand, 9, skin.darkened(0.2 if back else 0.0))

func draw_crawler():
	var coat: Color = zombie_palette()[variant % 3]
	var skin = Color("819570") if hurt <= 0 else Color("dfb88f")
	var crawl = clampf(absf(motion) / 80.0, 0, 1)
	var bob = sin(phase * 2.0) * 2.0 * crawl
	var lunge = attack * 23.0
	if death > 0:
		draw_set_transform(Vector2(0, 3), death * -0.22, Vector2(1, 1.0 - death * 0.25))
	else:
		draw_set_transform(Vector2(lunge, bob), sin(phase) * 0.035 * crawl, Vector2.ONE)
	poly([Vector2(-40, -52), Vector2(7, -57), Vector2(28, -43), Vector2(13, -25), Vector2(-38, -28), Vector2(-52, -39)], coat)
	poly([Vector2(21, -61), Vector2(42, -57), Vector2(51, -43), Vector2(43, -29), Vector2(25, -32), Vector2(15, -45)], skin)
	poly([Vector2(18, -59), Vector2(29, -69), Vector2(45, -63), Vector2(54, -51), Vector2(43, -56), Vector2(29, -51)], Color("26362f"))
	draw_line(Vector2(39, -48), Vector2(49, -47), Color("d8b66d"), 3, true)
	for back in [true, false]:
		var phase_offset = PI if back else 0.0
		var shoulder = Vector2(-2 if back else 9, -43)
		var elbow = shoulder + Vector2(17 + sin(phase + phase_offset) * 12 * crawl, 22)
		var hand = Vector2(31 + cos(phase + phase_offset) * 25 * crawl + lunge, -4)
		limb(shoulder, elbow, 11, coat.darkened(0.18 if back else 0.02))
		limb(elbow, hand, 8, skin.darkened(0.12))
	var rear_hip = Vector2(-34, -31)
	var rear_knee = Vector2(-54 + sin(phase) * 9 * crawl, -12)
	var rear_foot = Vector2(-42 + sin(phase) * 16 * crawl, -2)
	limb(rear_hip, rear_knee, 14, coat.darkened(0.24))
	limb(rear_knee, rear_foot, 11, coat.darkened(0.32))
