extends Node2D
## Original procedural pixel art. Simulation is independent of rendering for tests.
const GROUND = 392.0
const COSTS = {"barricade": 35, "turret": 85, "rifle": 55, "medic": 70, "repair": 40}
var scrap = 160
var supplies = 5
var base_hp = 400.0
var wave = 0
var kills = 0
var phase = "build"
var selected = 0
var slots: Array = []
var squad: Array = []
var enemies: Array = []
var shots: Array = []
var spawn_remaining = 0
var spawn_timer = 0.0
var elapsed = 0.0
var message = "指挥官，天黑前布好防线。"
var ui: CanvasLayer
var status: Label
var briefing: Label
var action_buttons: Array[Button] = []
var wave_button: Button
var rng = RandomNumberGenerator.new()
var test_mode = false

func _ready():
	rng.seed = 241108
	reset_game()
	make_ui()

func reset_game():
	scrap = 160
	supplies = 5
	base_hp = 400.0
	wave = 0
	kills = 0
	phase = "build"
	enemies.clear()
	squad.clear()
	shots.clear()
	slots.clear()
	for x in [310, 420, 530, 640]:
		slots.append({"x": float(x), "kind": "", "hp": 0.0, "cooldown": 0.0})
	message = "指挥官，天黑前布好防线。"

func make_ui():
	ui = CanvasLayer.new()
	add_child(ui)
	var title = Label.new()
	title.text = "余晖之后  /  AFTERGLOW"
	title.position = Vector2(28, 16)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("eed7a4"))
	ui.add_child(title)
	status = Label.new()
	status.position = Vector2(29, 53)
	status.add_theme_font_size_override("font_size", 14)
	ui.add_child(status)
	briefing = Label.new()
	briefing.position = Vector2(29, 441)
	briefing.add_theme_font_size_override("font_size", 15)
	ui.add_child(briefing)
	var actions = [["barricade", "路障 · 35"], ["turret", "哨戒塔 · 85"], ["rifle", "招募枪手 · 55"], ["medic", "招募医护 · 70"], ["repair", "维修营地 · 40"]]
	for i in actions.size():
		var button = make_button(actions[i][1], Vector2(28 + i * 143, 482), Vector2(135, 35))
		button.pressed.connect(purchase.bind(actions[i][0]))
		action_buttons.append(button)
	wave_button = make_button("迎战尸潮  [空格]", Vector2(761, 482), Vector2(174, 35))
	wave_button.pressed.connect(start_wave)
	var hint = Label.new()
	hint.text = "点击地面编号选择工位  /  空格迎战  /  P 暂停  /  R 失败后重建"
	hint.position = Vector2(30, 413)
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color("84939a")
	ui.add_child(hint)

func make_button(text: String, pos: Vector2, dimensions: Vector2) -> Button:
	var button = Button.new()
	button.text = text
	button.position = pos
	button.size = dimensions
	button.add_theme_font_size_override("font_size", 13)
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color("243338")
	normal.border_color = Color("596b66")
	normal.set_border_width_all(1)
	button.add_theme_stylebox_override("normal", normal)
	var hover = normal.duplicate()
	hover.bg_color = Color("455b50")
	button.add_theme_stylebox_override("hover", hover)
	ui.add_child(button)
	return button

func purchase(kind: String):
	if phase != "build":
		return
	if not COSTS.has(kind) or scrap < COSTS[kind]:
		message = "废料不足，守住下一波可获得补给。"
		return
	if kind in ["barricade", "turret"]:
		if slots[selected].kind != "":
			message = "这个工位已有设施，请选择空工位。"
			return
		slots[selected].kind = kind
		slots[selected].hp = 240.0 if kind == "barricade" else 140.0
	elif kind in ["rifle", "medic"]:
		if supplies <= 0 or squad.size() >= 8:
			message = "招募需要口粮，队伍最多容纳 8 人。"
			return
		supplies -= 1
		squad.append({"kind": kind, "x": 185.0 + squad.size() * 17, "cooldown": 0.0})
	elif kind == "repair":
		if base_hp >= 400:
			message = "营地完好，无需维修。"
			return
		base_hp = minf(400.0, base_hp + 130)
	scrap -= COSTS[kind]
	message = "部署完成。选择其他工位，或按空格迎战。"

func start_wave():
	if phase != "build":
		return
	wave += 1
	phase = "combat"
	spawn_remaining = 6 + wave * 3
	spawn_timer = 0.3
	message = "第 %d 波来袭！守住营地。" % wave

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos = get_global_mouse_position()
		if pos.y > 310 and pos.y < 412:
			for i in slots.size():
				if absf(pos.x - slots[i].x) < 48:
					selected = i
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			start_wave()
		elif event.keycode == KEY_P:
			if phase == "combat":
				phase = "paused"
			elif phase == "paused":
				phase = "combat"
		elif event.keycode == KEY_R and phase == "defeat":
			reset_game()

func _process(delta):
	if not test_mode:
		advance(minf(delta, 0.05))
	if is_instance_valid(status):
		status.text = "营地 %d / 400     废料 %d     口粮 %d     队伍 %d / 8     波次 %d     击杀 %d" % [ceili(base_hp), scrap, supplies, squad.size(), wave, kills]
		briefing.text = message if phase != "paused" else "战术暂停  /  按 P 继续"
		wave_button.disabled = phase != "build"
		for i in action_buttons.size():
			action_buttons[i].disabled = phase != "build" or scrap < COSTS[["barricade", "turret", "rifle", "medic", "repair"][i]]
	queue_redraw()

func advance(dt: float):
	if phase == "paused" or phase == "defeat":
		return
	elapsed += dt
	for shot in shots:
		shot.life -= dt
	shots = shots.filter(func(s): return s.life > 0)
	if phase != "combat":
		return
	spawn_timer -= dt
	if spawn_remaining > 0 and spawn_timer <= 0:
		var runner = wave >= 2 and spawn_remaining % 3 == 0
		var brute = wave >= 3 and spawn_remaining % 5 == 0
		enemies.append({"x": 985.0, "hp": (110.0 if brute else 38.0) + wave * 5, "speed": 27.0 if brute else (63.0 if runner else 31.0), "damage": 25.0 if brute else 12.0, "kind": "brute" if brute else ("runner" if runner else "walker"), "flash": 0.0})
		spawn_remaining -= 1
		spawn_timer = maxf(0.35, 1.3 - wave * 0.06)
	for member in squad:
		member.cooldown -= dt
		if member.kind == "medic":
			base_hp = minf(400, base_hp + dt * 1.8)
		elif member.cooldown <= 0 and fire_from(member.x, 640.0, 17.0):
			member.cooldown = 0.72
	for slot in slots:
		slot.cooldown -= dt
		if slot.kind == "turret" and slot.cooldown <= 0 and fire_from(slot.x, 370.0, 26.0):
			slot.cooldown = 0.85
	for enemy in enemies:
		if enemy.hp <= 0:
			continue
		enemy.flash = maxf(0, enemy.flash - dt)
		var blocker = null
		for slot in slots:
			if slot.kind != "" and enemy.x >= slot.x - 8 and enemy.x <= slot.x + 25:
				if blocker == null or slot.x > blocker.x:
					blocker = slot
		if blocker != null:
			blocker.hp -= enemy.damage * dt
			if blocker.hp <= 0:
				blocker.kind = ""
		elif enemy.x <= 157:
			base_hp -= enemy.damage * dt
		else:
			enemy.x -= enemy.speed * dt
	var living = []
	for enemy in enemies:
		if enemy.hp <= 0:
			kills += 1
			scrap += 4
		else:
			living.append(enemy)
	enemies = living
	if base_hp <= 0:
		base_hp = 0
		phase = "defeat"
		message = "营地失守。坚持了 %d 波，消灭 %d 名感染者。按 R 重建。" % [wave, kills]
	elif spawn_remaining == 0 and enemies.is_empty():
		phase = "build"
		scrap += 55 + wave * 10
		supplies += 2
		message = "第 %d 波已击退！获得 %d 废料和 2 份口粮，整备防线。" % [wave, 55 + wave * 10]

func fire_from(x: float, reach: float, damage: float) -> bool:
	var target = null
	for enemy in enemies:
		if enemy.hp > 0 and enemy.x > x - 18 and enemy.x - x <= reach:
			if target == null or enemy.x < target.x:
				target = enemy
	if target == null:
		return false
	target.hp -= damage
	target.flash = 0.09
	shots.append({"from": Vector2(x + 8, GROUND - 23), "to": Vector2(target.x, GROUND - 19), "life": 0.09})
	return true

func box(x: float, y: float, w: float, h: float, color: String):
	draw_rect(Rect2(floorf(x), floorf(y), w, h), Color(color))

func _draw():
	box(0, 0, 960, 540, "101923")
	box(0, 150, 960, 245, "342d36")
	box(0, 245, 960, 150, "594045")
	box(0, 337, 960, 58, "8b5949")
	draw_circle(Vector2(754, 195), 43, Color("c38362"))
	box(0, 215, 960, 3, "55404a")
	for i in 22:
		var x = i * 49 - 12
		var h = 40 + (i * 37 % 98)
		box(x, 316 - h, 39, h + 40, "252b35")
		box(x + 4, 310 - h, 5, 9, "252b35")
		for j in 3:
			if (i + j) % 3 == 0:
				box(x + 9, 325 - h + j * 23, 5, 7, "795b50")
	for i in 15:
		box(i * 73, 352, 3, 40, "333b3c")
		for j in 4:
			draw_line(Vector2(i * 73, 354 + j * 10), Vector2(i * 73 + 73, 354 + j * 10), Color("444548"), 1)
	box(0, GROUND, 960, 23, "232c2c")
	box(0, GROUND, 960, 3, "9b9270")
	for i in 90:
		box((i * 137) % 960, 398 + (i * 17) % 13, 3 + i % 5, 2, "46504a")
	box(0, 433, 960, 107, "111b22")
	box(0, 77, 960, 1, "39474b")
	# Camp cabin, warm windows, radio aerial and floodlight.
	box(35, 312, 122, 80, "303c3c")
	box(29, 306, 135, 9, "58615a")
	for y in range(320, 390, 9):
		box(36, y, 120, 2, "222d30")
	box(53, 328, 31, 26, "d1a561")
	box(66, 328, 3, 26, "4d5148")
	box(53, 340, 31, 3, "4d5148")
	box(108, 340, 29, 52, "18272d")
	box(128, 363, 3, 3, "c9ac74")
	box(147, 267, 3, 39, "7b8982")
	box(132, 277, 33, 2, "7b8982")
	box(170, 306, 4, 86, "4f5e5d")
	box(162, 300, 20, 8, "ddc38c")
	draw_colored_polygon(PackedVector2Array([Vector2(174, 307), Vector2(295, 392), Vector2(180, 392)]), Color(0.95, 0.8, 0.46, 0.06))
	box(44, 293, 5, 14, "656f64")
	box(49, 293, 27, 12, "9d604b")
	for i in slots.size():
		var slot = slots[i]
		var x = slot.x
		var tint = Color("dbb97e") if i == selected else Color("4c625e")
		draw_rect(Rect2(x - 35, 396, 70, 12), tint, false, 2)
		draw_string(ThemeDB.fallback_font, Vector2(x - 3, 406), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, tint)
		if slot.kind == "barricade":
			box(x - 25, 365, 50, 26, "65564a")
			box(x - 26, 369, 52, 5, "9b8a68")
			box(x - 26, 383, 52, 5, "9b8a68")
			for off in [-19, 13]:
				box(x + off, 358, 6, 34, "b0a284")
		elif slot.kind == "turret":
			box(x - 14, 348, 5, 44, "69766a")
			box(x + 9, 348, 5, 44, "69766a")
			box(x - 22, 341, 44, 9, "87927b")
			person(x, 341, "gunner")
		if slot.kind != "":
			box(x - 23, 329 if slot.kind == "barricade" else 296, 46, 3, "202a2d")
			box(x - 23, 329 if slot.kind == "barricade" else 296, 46 * maxf(0, slot.hp) / (240 if slot.kind == "barricade" else 140), 3, "95ac79")
	for member in squad:
		person(member.x, GROUND, member.kind)
	for enemy in enemies:
		person(enemy.x, GROUND, enemy.kind, enemy.flash > 0)
	for shot in shots:
		draw_line(shot.from, shot.to, Color("edcb83"), 1)
		box(shot.from.x, shot.from.y - 3, 7, 5, "fff1b1")
	if phase == "defeat":
		draw_rect(Rect2(0, 80, 960, 330), Color(0.12, 0.04, 0.06, 0.75))
		draw_string(ThemeDB.fallback_font, Vector2(357, 257), "CAMP OVERRUN", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color("dda18a"))

func person(x: float, ground: float, kind: String, flash = false):
	var infected = kind in ["walker", "runner", "brute"]
	var skin = "a0ac80" if infected else "c1a387"
	var coat = "4e6251" if infected else "697e79"
	if kind == "runner":
		coat = "856454"
	if kind == "brute":
		coat = "61616b"
	if kind == "medic":
		coat = "c0bda0"
	if flash:
		skin = "fff0bf"
		coat = "fff0bf"
	var wide = 5 if kind == "brute" else 0
	var step = sin(elapsed * (10 if kind == "runner" else 6) + x) * 3 if infected and phase == "combat" else 0.0
	box(x - 6 - wide, ground - 23, 12 + wide * 2, 14, coat)
	box(x - 5, ground - 34, 10, 11, skin)
	box(x - 6, ground - 36, 12, 4, "303f3e")
	box(x - 6, ground - 9, 4, 9 - step, "2c3536")
	box(x + 2, ground - 9, 4, 9 + step, "2c3536")
	if infected:
		box(x - 16, ground - 22, 12, 4, skin)
		box(x - 5, ground - 30, 2, 2, "d59c71")
	elif kind == "medic":
		box(x - 3, ground - 20, 6, 2, "a64d45")
		box(x - 1, ground - 22, 2, 6, "a64d45")
	else:
		box(x + 3, ground - 23, 17, 4, "202e33")
		box(x + 5, ground - 19, 5, 4, skin)
