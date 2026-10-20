extends Node2D
## Deterministic, original vector set dressing; no downloaded art dependencies.
var camera_x = 0.0
var clock = 0.0
var rng = RandomNumberGenerator.new()
var font = ThemeDB.fallback_font
const GROUND = 700.0

func _process(dt):
	clock += dt
	queue_redraw()

func polygon(points: Array, color: Color):
	draw_colored_polygon(PackedVector2Array(points), color)

func text(at: Vector2, label: String, size: int, color: Color):
	draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw():
	rng.seed = 7407
	draw_set_transform(Vector2(camera_x, 0))
	draw_rect(Rect2(0, 0, 1440, 900), Color("101f28"))
	for i in range(16):
		draw_rect(Rect2(0, 90 + i * 35, 1440, 36), Color("33444b").lerp(Color("172a30"), i / 16.0))
	draw_circle(Vector2(1030, 220), 79, Color("7b8881"))
	draw_circle(Vector2(1030, 220), 75, Color("a4aaa0"))
	draw_circle(Vector2(1050, 199), 68, Color("88968f"))
	for i in range(5):
		draw_rect(Rect2(0, 200 + i * 55, 1440, 12), Color(0.12, 0.2, 0.23, 0.2))
	draw_set_transform(Vector2(camera_x * 0.82, 0))
	for i in range(-6, 30):
		var x = i * 90.0
		var height = rng.randf_range(110, 330)
		draw_rect(Rect2(x, 570 - height, 83, height), Color("1d3037"))
		if i % 3 == 0:
			draw_line(Vector2(x + 40, 570 - height), Vector2(x + 40, 530 - height), Color("203138"), 3)
		for w in range(4):
			for h in range(int(height / 25)):
				if rng.randf() > 0.45:
					draw_rect(Rect2(x + 10 + w * 18, 580 - height + h * 24, 4, 7), Color("617169") if rng.randf() > 0.85 else Color("293d42"))
	draw_set_transform(Vector2(camera_x * 0.55, 0))
	for i in range(-2, 11):
		var x = i * 280
		draw_rect(Rect2(x, 470, 265, 190), Color("20343a"))
		polygon([Vector2(x - 12, 470), Vector2(x + 120, 419), Vector2(x + 273, 470)], Color("293b3e"))
		for k in range(5):
			draw_rect(Rect2(x + 15 + k * 49, 500, 34, 65), Color("12282f"))
			draw_line(Vector2(x + 30 + k * 49, 500), Vector2(x + 30 + k * 49, 565), Color("3a4c4d"), 2)
	draw_set_transform(Vector2.ZERO)
	# Floodlit checkpoint facade.
	draw_rect(Rect2(1160, 360, 700, 340), Color("29383a"))
	draw_rect(Rect2(1160, 360, 700, 17), Color("46514c"))
	draw_rect(Rect2(1190, 390, 270, 44), Color("c6b68e"))
	text(Vector2(1204, 422), "QUARANTINE / 07", 24, Color("273638"))
	draw_rect(Rect2(1230, 468, 265, 232), Color("17282c"))
	for i in range(17):
		draw_line(Vector2(1230, 475 + i * 13), Vector2(1495, 475 + i * 13), Color("3a4847"), 2)
	draw_rect(Rect2(1540, 467, 200, 130), Color("13282e"))
	for i in range(5):
		draw_line(Vector2(1540 + i * 50, 467), Vector2(1540 + i * 50, 597), Color("4b5852"), 4)
	draw_line(Vector2(1540, 530), Vector2(1740, 530), Color("4b5852"), 4)
	draw_rect(Rect2(1552, 482, 36, 36), Color("667260"))
	text(Vector2(1570, 657), "NO ENTRY", 26, Color("b6a274"))
	# Foreground fence, bent uprights and barbed wire.
	for section in range(-2, 8):
		var x = section * 350.0
		if x > 1100 and x < 1800:
			continue
		for j in range(16):
			draw_line(Vector2(x + j * 24, 490), Vector2(x + j * 24 - 120, 690), Color(0.34, 0.45, 0.43, 0.22), 1, true)
			draw_line(Vector2(x + j * 24, 490), Vector2(x + j * 24 + 120, 690), Color(0.34, 0.45, 0.43, 0.22), 1, true)
		draw_line(Vector2(x, 465), Vector2(x, 700), Color("4b5b56"), 5)
		draw_line(Vector2(x, 465), Vector2(x - 15, 445), Color("4b5b56"), 4)
		draw_line(Vector2(x, 489), Vector2(x + 350, 489), Color("3f514f"), 2)
		for j in range(17):
			draw_arc(Vector2(x + j * 21, 459), 15, 0, TAU, 12, Color("53605a"), 1, true)
	for lamp_x in [210, 1120, 2010, 2850]:
		draw_line(Vector2(lamp_x, 700), Vector2(lamp_x, 285), Color("182a30"), 12)
		draw_line(Vector2(lamp_x, 285), Vector2(lamp_x + 70, 285), Color("24383c"), 8)
		draw_rect(Rect2(lamp_x + 53, 280, 38, 10), Color("c8b387"))
		polygon([Vector2(lamp_x + 56, 290), Vector2(lamp_x + 90, 290), Vector2(lamp_x + 240, 704), Vector2(lamp_x - 95, 704)], Color(0.91, 0.77, 0.47, 0.035))
		draw_circle(Vector2(lamp_x + 72, 290), 17, Color(0.95, 0.79, 0.48, 0.05))
	# Overhead power lines.
	for offset in [0, 9]:
		var wire = PackedVector2Array()
		for i in range(65):
			var x = -400 + i * 65
			wire.append(Vector2(x, 230 + offset + sin((x + 400) / 750.0 * PI) * 37))
		draw_polyline(wire, Color("14272d"), 2, true)
	# Abandoned ambulance and wrecked compact car.
	car(620, true)
	car(2240, false)
	for x in [40, 980, 1800, 2660, 3180]:
		barricade(x)
	draw_rect(Rect2(-1500, 700, 7000, 250), Color("19292d"))
	draw_line(Vector2(-1500, 702), Vector2(5500, 702), Color("65716a"), 3)
	for i in range(180):
		var x = rng.randf_range(-1400, 5400)
		var y = rng.randf_range(712, 900)
		draw_line(Vector2(x, y), Vector2(x + rng.randf_range(3, 28), y), Color("2b3c3e"), 1)
	for x in range(-1000, 5000, 290):
		draw_rect(Rect2(x, 756, 110, 4), Color("786e4b"))
		draw_line(Vector2(x + 140, 700), Vector2(x + 185, 725), Color("102227"), 2)
	for x in [400, 1380, 1940, 2870]:
		draw_colored_polygon(PackedVector2Array([Vector2(x, 730), Vector2(x + 180, 729), Vector2(x + 220, 748), Vector2(x + 25, 751)]), Color(0.31, 0.43, 0.43, 0.15))
		for j in range(3):
			draw_line(Vector2(x + 20, 734 + j * 4), Vector2(x + 150, 734 + j * 4), Color(0.5, 0.57, 0.48, 0.07), 1)
	# Rubble and weeds silhouette the road edge.
	for i in range(95):
		var x = rng.randf_range(-1000, 4700)
		var size = rng.randf_range(2, 9)
		polygon([Vector2(x, 699), Vector2(x + size, 690 - size / 2), Vector2(x + size * 2, 699)], Color("34423f"))
		if i % 3 == 0:
			draw_line(Vector2(x, 700), Vector2(x - 4, 683), Color("526055"), 1)
	# Drifting dust/fallout at several depths.
	for i in range(45):
		var x = fposmod(i * 97.3 + clock * (8 + i % 4 * 4), 1800) - 100 + camera_x * 0.2
		var y = fposmod(i * 79.1 + clock * 5, 660)
		draw_circle(Vector2(x, y), 1.1 if i % 3 else 1.8, Color(0.73, 0.78, 0.67, 0.18))

func barricade(x):
	polygon([Vector2(x, 700), Vector2(x + 11, 651), Vector2(x + 92, 651), Vector2(x + 108, 700)], Color("5c6050"))
	draw_rect(Rect2(x + 10, 657, 85, 12), Color("bba770"))
	for i in range(4):
		polygon([Vector2(x + 14 + i * 23, 657), Vector2(x + 25 + i * 23, 657), Vector2(x + 17 + i * 23, 669), Vector2(x + 6 + i * 23, 669)], Color("273333"))
	draw_line(Vector2(x + 17, 678), Vector2(x + 86, 678), Color("777b66"), 2)

func car(x, ambulance):
	var base = Color("6b7163") if ambulance else Color("3f5154")
	polygon([Vector2(x, 683), Vector2(x - 5, 628), Vector2(x + 16, 608), Vector2(x + 136, 608), Vector2(x + 180, 650), Vector2(x + 215, 659), Vector2(x + 221, 684)], base)
	polygon([Vector2(x + 82, 616), Vector2(x + 132, 616), Vector2(x + 164, 649), Vector2(x + 82, 649)], Color("1d3339"))
	draw_rect(Rect2(x + 12, 619, 56, 29), Color("263c3f"))
	draw_line(Vector2(x, 661), Vector2(x + 190, 661), Color("83564a") if ambulance else Color("71807a"), 5)
	for offset in [35, 177]:
		draw_circle(Vector2(x + offset, 683), 18, Color("111e24"))
		draw_circle(Vector2(x + offset, 683), 9, Color("3b4b4c"))
		draw_circle(Vector2(x + offset, 683), 4, Color("6a7267"))
	if ambulance:
		draw_rect(Rect2(x + 29, 653, 22, 7), Color("9eaca0"))
		draw_rect(Rect2(x + 36, 645, 7, 23), Color("9eaca0"))
		draw_rect(Rect2(x + 84, 601, 27, 7), Color("a55e4d"))
	else:
		draw_line(Vector2(x + 112, 622), Vector2(x + 144, 647), Color("a0a89a"), 1)
