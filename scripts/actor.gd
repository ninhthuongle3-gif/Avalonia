extends Node2D
## Layered cutout character, with procedural two-bone arms and planted strides.

const CutoutRig = preload("res://scripts/cutout_rig.gd")

var zombie = false
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
var cutout_rig: Skeleton2D

const EDGE = Color("101c22")

func _ready():
	if not zombie:
		cutout_rig = CutoutRig.new()
		cutout_rig.owner_actor = self
		add_child(cutout_rig)

func _process(dt):
	clock += dt
	# During the planted half of a stride the foot moves opposite the body at
	# the same speed. Slow zombies shorten the stride instead of skating.
	var stride_weight = clampf(abs(motion) / 100.0, 0.0, 1.0)
	if stride_weight > 0.01:
		phase += dt * abs(motion) * PI / (60.0 * stride_weight)
	recoil = move_toward(recoil, 0.0, dt * 9.0)
	flash = maxf(0.0, flash - dt)
	hurt = maxf(0.0, hurt - dt * 5.0)
	shield_blend = move_toward(shield_blend, 1.0 if shielding else 0.0, dt * 7.5)
	reload_pose = move_toward(reload_pose, sin(clampf(reload_progress, 0, 1) * PI) if reload_progress >= 0 else 0.0, dt * 8.0)
	queue_redraw()

func poly(points: Array, color: Color, outline = true):
	var p = PackedVector2Array(points)
	draw_colored_polygon(p, color)
	if outline:
		p.append(p[0])
		draw_polyline(p, EDGE, 2.0, true)

func limb(a: Vector2, b: Vector2, width: float, color: Color):
	draw_line(a, b, EDGE, width + 5.0, true)
	draw_circle(a, width * 0.5 + 1, EDGE)
	draw_circle(b, width * 0.5 + 1, EDGE)
	draw_line(a, b, color, width, true)
	draw_circle(a, width * 0.5, color)
	draw_circle(b, width * 0.5, color)
	draw_line(a + Vector2(-2, -2), b + Vector2(-2, -2), color.lightened(0.13), 2, true)

func knee(a: Vector2, foot: Vector2, bend: float) -> Vector2:
	var v = foot - a
	var d = clampf(v.length(), 0.01, 68.0)
	return a + v * 0.5 + Vector2(-v.y, v.x).normalized() * sqrt(maxf(0, 35.0 * 35.0 - d * d * 0.25)) * bend

func _draw():
	if not zombie:
		if hurt > 0:
			draw_circle(Vector2(0, -92), 28, Color(1, 0.5, 0.3, hurt * 0.18))
		return
	var run = clampf(abs(motion) / 100.0, 0.0, 1.0)
	var bob = sin(phase * 2.0) * 2.0 * run + sin(clock * 2.7) * 0.6
	if zombie:
		bob = sin(phase) * 2.5
	var lean = clampf(motion * facing / 170.0, -1.0, 1.0) * 4.0 - recoil * 2.5
	if death > 0:
		draw_set_transform(Vector2(0, -7), facing * -death * 1.45, Vector2(facing, 1))
	else:
		draw_set_transform(Vector2(0, bob), 0, Vector2(facing, 1))
	var hip = Vector2(lean, -65)
	for back in [true, false]:
		var cycle = fposmod(phase + (PI if back else 0.0), TAU)
		var stance = cycle < PI
		var progress = cycle / PI if stance else (cycle - PI) / PI
		var stride = lerpf(30, -30, progress) if stance else lerpf(-30, 30, progress)
		var lift = 0.0 if stance else sin(progress * PI) * 20
		var travel_direction = -1.0 if motion * facing < 0 else 1.0
		var foot = Vector2(stride * run * travel_direction + (-4 if back else 4), -lift * run)
		if airborne:
			foot = Vector2(-20 if back else 20, -17 if back else -27)
		var k = knee(hip + Vector2(-3 if back else 3, 0), foot, -1.0)
		var leg_color = Color("242d31") if not zombie else Color("303b39")
		if back:
			leg_color = leg_color.darkened(0.25)
		limb(hip, k, 18, leg_color)
		limb(k, foot + Vector2(0, -7), 14, leg_color)
		poly([k + Vector2(-9, -7), k + Vector2(7, -8), k + Vector2(9, 7), k + Vector2(-7, 9)], Color("49534a"))
		poly([foot + Vector2(-9, -10), foot + Vector2(6, -9), foot + Vector2(16, -3), foot + Vector2(16, 2), foot + Vector2(-10, 2)], Color("17232a"))
		draw_line(foot + Vector2(-8, 1), foot + Vector2(15, 1), Color("657173"), 2, true)
	draw_zombie(lean)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if hurt > 0:
		draw_circle(Vector2(0, -92), 28, Color(1, 0.5, 0.3, hurt * 0.18))

func draw_zombie(lean):
	var coat = [Color("49584e"), Color("56504a"), Color("384e55")][variant % 3]
	var skin = Color("8a9d7e") if hurt <= 0 else Color("e5c9a0")
	poly([Vector2(-19 + lean, -111), Vector2(11 + lean, -113), Vector2(24 + lean, -82), Vector2(16 + lean, -60), Vector2(5 + lean, -67), Vector2(-5 + lean, -59), Vector2(-24 + lean, -65), Vector2(-24 + lean, -92)], coat)
	draw_line(Vector2(2 + lean, -108), Vector2(8 + lean, -69), coat.lightened(0.16), 2, true)
	poly([Vector2(-6 + lean, -135), Vector2(14 + lean, -139), Vector2(23 + lean, -126), Vector2(19 + lean, -111), Vector2(5 + lean, -108), Vector2(-7 + lean, -119)], skin)
	poly([Vector2(-10 + lean, -132), Vector2(-8 + lean, -143), Vector2(7 + lean, -146), Vector2(20 + lean, -138), Vector2(24 + lean, -128), Vector2(12 + lean, -136), Vector2(-1 + lean, -130)], Color("293a33"))
	draw_line(Vector2(11 + lean, -127), Vector2(19 + lean, -128), Color("d7b978"), 3, true)
	draw_line(Vector2(15 + lean, -116), Vector2(22 + lean, -117), Color("402b2a"), 3, true)
	draw_line(Vector2(-4 + lean, -95), Vector2(8 + lean, -84), Color("633e36"), 6, true)
	for back in [true, false]:
		var shoulder = Vector2(lean + (-8 if back else 9), -102)
		var extension = attack * 24.0
		var elbow = shoulder + Vector2(19, 13 + sin(clock * 3) * 5)
		var hand = shoulder + Vector2(38 + extension, 7 + sin(clock * 3 + (1 if back else 0)) * 8)
		limb(shoulder, elbow, 13, coat.darkened(0.15 if back else 0))
		limb(elbow, hand, 9, skin.darkened(0.2 if back else 0))
		for i in range(3):
			draw_line(hand + Vector2(0, i * 2 - 3), hand + Vector2(9, i * 3 - 3), skin, 2, true)
