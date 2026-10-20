extends Node2D
## Layered cutout character, with procedural two-bone arms and planted strides.

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

const EDGE = Color("101c22")
const ARMOR = Color("28343b")
const LIGHT = Color("536369")
const SKIN = Color("c7c0b4")

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
		poly([k + Vector2(-9, -7), k + Vector2(7, -8), k + Vector2(9, 7), k + Vector2(-7, 9)], ARMOR if not zombie else Color("49534a"))
		poly([foot + Vector2(-9, -10), foot + Vector2(6, -9), foot + Vector2(16, -3), foot + Vector2(16, 2), foot + Vector2(-10, 2)], Color("17232a"))
		draw_line(foot + Vector2(-8, 1), foot + Vector2(15, 1), Color("657173"), 2, true)
	if zombie:
		draw_zombie(lean)
	else:
		draw_soldier(lean)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if hurt > 0:
		draw_circle(Vector2(0, -92), 28, Color(1, 0.5, 0.3, hurt * 0.18))

func draw_soldier(lean):
	# Shield, sling and rear arm sit behind the vest.
	if not shielding:
		poly([Vector2(-32, -127), Vector2(-16, -134), Vector2(-7, -120), Vector2(-10, -45), Vector2(-32, -33), Vector2(-43, -47), Vector2(-42, -112)], Color("26343b"))
		draw_polyline(PackedVector2Array([Vector2(-31, -121), Vector2(-23, -123), Vector2(-18, -113), Vector2(-20, -52), Vector2(-30, -45)]), LIGHT, 2, true)
		draw_rect(Rect2(-35, -91, 17, 7), Color("0b151b"))
	poly([Vector2(-17 + lean, -112), Vector2(13 + lean, -111), Vector2(21 + lean, -83), Vector2(15 + lean, -62), Vector2(-18 + lean, -62), Vector2(-24 + lean, -88)], Color("222f36"))
	poly([Vector2(-14 + lean, -110), Vector2(12 + lean, -110), Vector2(15 + lean, -78), Vector2(-13 + lean, -78)], Color("39464a"))
	draw_line(Vector2(-15 + lean, -110), Vector2(12 + lean, -76), Color("778072"), 7, true)
	for i in range(3):
		draw_style_box(panel(Color("253239")), Rect2(-18 + lean + i * 12, -83, 10, 17))
		draw_line(Vector2(-15 + lean + i * 12, -80), Vector2(-10 + lean + i * 12, -80), LIGHT, 1)
	draw_rect(Rect2(-20 + lean, -65, 39, 6), Color("161f24"))
	draw_rect(Rect2(-2 + lean, -65, 9, 6), Color("8b8a73"))
	# Pale hair, helmet rim, headset, transparent visor.
	poly([Vector2(-13 + lean, -139), Vector2(11 + lean, -140), Vector2(17 + lean, -126), Vector2(10 + lean, -114), Vector2(-9 + lean, -116)], SKIN)
	poly([Vector2(-19 + lean, -143), Vector2(7 + lean, -144), Vector2(10 + lean, -135), Vector2(1 + lean, -128), Vector2(3 + lean, -138), Vector2(-4 + lean, -128), Vector2(-7 + lean, -137), Vector2(-14 + lean, -116), Vector2(-20 + lean, -123)], Color("c9d1cf"))
	poly([Vector2(-23 + lean, -141), Vector2(-18 + lean, -155), Vector2(-2 + lean, -160), Vector2(14 + lean, -153), Vector2(19 + lean, -142), Vector2(1 + lean, -139)], Color("33434b"))
	draw_arc(Vector2(-3 + lean, -143), 18, PI + 0.15, TAU - 0.15, 16, Color("748186"), 3, true)
	poly([Vector2(-7 + lean, -149), Vector2(21 + lean, -145), Vector2(20 + lean, -132), Vector2(1 + lean, -134)], Color(0.47, 0.72, 0.77, 0.23))
	draw_line(Vector2(-5 + lean, -147), Vector2(20 + lean, -143), Color("a9c7c9"), 2, true)
	draw_line(Vector2(8 + lean, -129), Vector2(13 + lean, -129), Color("263c45"), 2, true)
	draw_circle(Vector2(-14 + lean, -134), 8, EDGE)
	draw_circle(Vector2(-14 + lean, -134), 5.5, Color("69755f"))
	draw_polyline(PackedVector2Array([Vector2(-12 + lean, -130), Vector2(-6 + lean, -118), Vector2(13 + lean, -118)]), EDGE, 3, true)
	poly([Vector2(-18 + lean, -117), Vector2(14 + lean, -119), Vector2(15 + lean, -107), Vector2(-13 + lean, -104)], Color("1b272d"))
	# Gun and both arms track the cursor. Rear hand follows the forward grip.
	var shoulder = Vector2(lean + 1, -104)
	var gun_angle = aim - recoil * 0.065
	if shielding:
		gun_angle = -0.13
	var direction = Vector2.from_angle(gun_angle)
	var gun_origin = shoulder + direction * (23 - recoil * 5)
	if reload_progress >= 0:
		gun_angle = aim + sin(reload_progress * PI) * 0.65
		direction = Vector2.from_angle(gun_angle)
		gun_origin = shoulder + direction * 18
	var front_grip = gun_origin + direction * 21 + direction.orthogonal() * 5
	if reload_progress >= 0:
		front_grip = gun_origin + direction * 13 + direction.orthogonal() * (13 + sin(reload_progress * PI) * 16)
	var back_grip = gun_origin - direction * 2 + direction.orthogonal() * 9
	var elbow = knee(shoulder + Vector2(-8, 4), front_grip, 1)
	limb(shoulder + Vector2(-8, 4), elbow, 12, Color("202c31"))
	limb(elbow, front_grip, 10, Color("3e4d50"))
	draw_set_transform(gun_origin * Vector2(facing, 1) + Vector2(0, sin(phase * 2) * 2 * clampf(abs(motion) / 100, 0, 1) + sin(clock * 2.7) * 0.6), gun_angle * facing, Vector2(facing, 1))
	poly([Vector2(-25, -5), Vector2(-12, -4), Vector2(-7, -9), Vector2(33, -8), Vector2(35, 3), Vector2(9, 5), Vector2(4, 16), Vector2(-3, 14), Vector2(-2, 3), Vector2(-24, 4)], Color("1b262b"))
	var magazine_offset = sin(clampf(reload_progress / 0.7, 0, 1) * PI) * 21 if reload_progress >= 0 else 0.0
	draw_rect(Rect2(11, 4 + magazine_offset, 10, 15), Color("33434a"))
	draw_line(Vector2(30, -4), Vector2(58, -4), EDGE, 6, true)
	draw_line(Vector2(-6, -9), Vector2(34, -9), LIGHT, 2, true)
	draw_rect(Rect2(3, -14, 12, 5), Color("111d23"))
	for i in range(4):
		draw_line(Vector2(18 + i * 4, -5), Vector2(18 + i * 4, 1), Color("4b5c60"), 1)
	if flash > 0:
		poly([Vector2(58, -4), Vector2(73, -13), Vector2(69, -5), Vector2(92, -4), Vector2(69, 0), Vector2(75, 7)], Color("ffbc65"), false)
		draw_circle(Vector2(62, -4), 6, Color("fff7ca"))
	draw_set_transform(Vector2(0, sin(phase * 2) * 2 * clampf(abs(motion) / 100, 0, 1) + sin(clock * 2.7) * 0.6), 0, Vector2(facing, 1))
	var near_elbow = shoulder + Vector2(-8 - recoil * 5, 27)
	limb(shoulder, near_elbow, 15, Color("34434a"))
	limb(near_elbow, back_grip, 12, Color("3e4d52"))
	draw_circle(shoulder, 10, Color("45565c"))
	draw_line(shoulder + Vector2(-3, -6), shoulder + Vector2(4, -5), Color("cd9b5d"), 3, true)
	draw_circle(back_grip, 6, Color("19292e"))
	if shielding:
		poly([Vector2(27, -135), Vector2(49, -131), Vector2(55, -116), Vector2(55, -48), Vector2(44, -32), Vector2(27, -38), Vector2(23, -54), Vector2(23, -119)], Color("34474d"))
		draw_polyline(PackedVector2Array([Vector2(31, -127), Vector2(45, -124), Vector2(48, -111), Vector2(48, -52), Vector2(40, -42), Vector2(31, -46)]), Color("81918c"), 2, true)
		draw_rect(Rect2(28, -107, 20, 12), Color("0c1c22"))
		draw_line(Vector2(30, -104), Vector2(46, -104), Color("6d8e8c"), 2)
		draw_line(Vector2(35, -65), Vector2(44, -65), Color("d6ad68"), 3)

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

func panel(color: Color) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = EDGE
	box.set_border_width_all(1)
	box.set_corner_radius_all(2)
	return box
