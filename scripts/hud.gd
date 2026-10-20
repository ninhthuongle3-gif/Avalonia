extends Control
var game: Node2D
var font = ThemeDB.fallback_font
var title_font: Font
const IVORY = Color("e7e5d5")
const MUTED = Color("8d9e99")
const AMBER = Color("d3ad71")
const RED = Color("d77461")
const PANEL = Color(0.035, 0.075, 0.09, 0.86)

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_font = load("res://assets/heading.ttf") if ResourceLoader.exists("res://assets/heading.ttf") else font

func _process(_dt):
	queue_redraw()

func label_at(pos: Vector2, label: String, size = 16, color = IVORY, heading = false):
	draw_string(title_font if heading else font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func line(a: Vector2, b: Vector2, color = MUTED, width = 1.0):
	draw_line(a, b, color, width, true)

func panel(rect: Rect2, color = PANEL):
	draw_rect(rect, color)
	draw_rect(rect, Color(0.57, 0.65, 0.6, 0.18), false, 1)

func _draw():
	if not is_instance_valid(game):
		return
	# Letterbox edge and fine printed registration marks.
	draw_rect(Rect2(0, 0, 1440, 6), Color("0b171d"))
	draw_rect(Rect2(0, 894, 1440, 6), Color("0b171d"))
	for x in [28, 1412]:
		line(Vector2(x, 28), Vector2(x, 45), AMBER)
		line(Vector2(x, 28), Vector2(x + (17 if x < 100 else -17), 28), AMBER)
		line(Vector2(x, 872), Vector2(x, 855), AMBER)
		line(Vector2(x, 872), Vector2(x + (17 if x < 100 else -17), 872), AMBER)
	if not game.started:
		draw_menu()
		return
	draw_ingame()
	if game.damage_flash > 0:
		var alpha = game.damage_flash
		for i in range(9):
			var c = Color(0.65, 0.13, 0.09, alpha * (1 - i / 9.0) * 0.14)
			draw_rect(Rect2(i * 5, i * 5, 1440 - i * 10, 900 - i * 10), c, false, 6)
	if game.game_over:
		draw_end()
	elif game.paused:
		draw_pause()

func draw_menu():
	for i in range(30):
		draw_rect(Rect2(i * 34, 0, 34, 900), Color(0.025, 0.06, 0.075, 0.88 * (1 - i / 30.0)))
	label_at(Vector2(88, 98), "AN INDEPENDENT SURVIVAL PROTOTYPE", 13, MUTED)
	line(Vector2(88, 127), Vector2(155, 127), AMBER, 3)
	label_at(Vector2(88, 204), "N O   O N E   I S   C O M I N G .", 15, AMBER)
	label_at(Vector2(80, 320), "LAST", 112, IVORY, true)
	label_at(Vector2(80, 424), "LIGHT", 112, IVORY, true)
	label_at(Vector2(90, 472), "Q U A R A N T I N E    /    0 7", 19, AMBER)
	label_at(Vector2(90, 529), "The perimeter has fallen. Your shift hasn't ended.", 17, IVORY)
	label_at(Vector2(90, 557), "Hold the line. Make every round count.", 17, MUTED)
	var hover = Rect2(88, 625, 290, 54).has_point(get_global_mouse_position())
	draw_rect(Rect2(88, 625, 290, 54), IVORY if hover else AMBER)
	label_at(Vector2(112, 659), "ENTER THE QUARANTINE", 16, Color("14252a"), true)
	label_at(Vector2(397, 660), "[ ENTER ]", 14, MUTED)
	line(Vector2(88, 722), Vector2(568, 722), Color("435451"))
	label_at(Vector2(88, 756), "A / D  MOVE       MOUSE  AIM       LMB  FIRE", 13, MUTED)
	label_at(Vector2(88, 783), "RMB  SHIELD       1 / 2  WEAPON       R  RELOAD", 13, MUTED)
	label_at(Vector2(88, 842), "01 / FIELD TEST", 12, AMBER)
	label_at(Vector2(1082, 842), "GODOT 4  /  MODULAR BONE RIG", 12, MUTED)
	# Right-side diegetic field annotation.
	line(Vector2(1054, 543), Vector2(1098, 510), AMBER)
	line(Vector2(1098, 510), Vector2(1310, 510), AMBER)
	label_at(Vector2(1110, 493), "OPERATOR / WHITE ASH", 13, IVORY)
	label_at(Vector2(1110, 535), "RIFLE / SIDEARM / SHIELD", 11, MUTED)
	label_at(Vector2(1142, 90), "SECTOR 07", 17, IVORY, true)
	label_at(Vector2(1142, 115), "02:17  /  SIGNAL LOST", 12, AMBER)

func draw_ingame():
	panel(Rect2(45, 40, 267, 73))
	draw_rect(Rect2(45, 40, 3, 73), AMBER)
	label_at(Vector2(65, 68), "LAST LIGHT", 22, IVORY, true)
	label_at(Vector2(66, 94), "QUARANTINE  /  SECTOR 07", 12, MUTED)
	panel(Rect2(546, 40, 348, 66))
	label_at(Vector2(570, 66), "HOLD THE PERIMETER", 13, AMBER)
	var remaining = game.spawn_left + game.living_enemies()
	var status = "%02d HOSTILES REMAINING" % remaining
	if remaining == 0:
		status = "SECTOR CLEAR  /  +15 HP NEXT WAVE"
	label_at(Vector2(570, 91), status, 14, IVORY)
	panel(Rect2(1150, 40, 244, 73))
	label_at(Vector2(1170, 66), "WAVE %02d" % game.wave, 20, IVORY, true)
	label_at(Vector2(1171, 94), "%02d:%02d    /    %02d ELIMINATED" % [int(game.elapsed) / 60, int(game.elapsed) % 60, game.kills], 12, MUTED)
	# Bottom-left status module.
	panel(Rect2(45, 781, 345, 79))
	label_at(Vector2(65, 809), "+", 23, AMBER)
	label_at(Vector2(93, 808), "WHITE ASH", 14, IVORY, true)
	label_at(Vector2(318, 808), "%03d" % ceili(game.health), 18, IVORY, true)
	draw_rect(Rect2(65, 820, 302, 6), Color("263c40"))
	draw_rect(Rect2(65, 820, 302 * game.health / 100, 6), RED if game.health < 30 else Color("abb9a3"))
	draw_rect(Rect2(65, 838, 302, 3), Color("263c40"))
	draw_rect(Rect2(65, 838, 302 * game.stamina / 100, 3), AMBER)
	# Weapon module. Both weapons keep independent magazines.
	var config = game.weapon_config()
	panel(Rect2(1100, 766, 294, 94))
	label_at(Vector2(1120, 792), "%s  /  %s" % [config.name, config.caliber], 13, MUTED)
	label_at(Vector2(1120, 837), "%02d" % game.ammo, 39, AMBER if game.ammo < 6 else IVORY, true)
	label_at(Vector2(1187, 835), "/  %02d" % config.magazine, 18, MUTED)
	label_at(Vector2(1272, 820), config.mode, 14, AMBER)
	label_at(Vector2(1272, 838), "SKILL  %d / 5" % game.weapon_skill_level(), 10, IVORY)
	label_at(Vector2(1272, 852), "RESERVE  INF", 9, MUTED)
	label_at(Vector2(465, 846), "1 RIFLE   /   2 PISTOL   /   Q SWITCH   /   R RELOAD   /   F1 CONTROLS", 12, MUTED)
	label_at(Vector2(1110, 747), "1  AR-07", 10, AMBER if game.weapon_kind == "rifle" else MUTED)
	label_at(Vector2(1182, 747), "2  P-9", 10, AMBER if game.weapon_kind == "pistol" else MUTED)
	# Front/back threat arrows are visible before an enemy enters the view.
	for e in game.enemies:
		if e.hp <= 0:
			continue
		var x = e.actor.position.x - game.camera_x
		if x < 10 or x > 1430:
			var side = 28 if x < 10 else 1412
			var direction = -1 if x < 10 else 1
			draw_colored_polygon(PackedVector2Array([Vector2(side, 570), Vector2(side - direction * 10, 562), Vector2(side - direction * 10, 578)]), RED)
	# Reload is shown near the actor, leaving the crosshair unobstructed.
	if game.reload_timer > 0:
		var px = game.player.position.x - game.camera_x
		var py = game.player.position.y - 185
		label_at(Vector2(px - 40, py - 12), "RELOADING", 11, AMBER)
		draw_rect(Rect2(px - 40, py, 80, 3), Color("263c40"))
		draw_rect(Rect2(px - 40, py, 80 * (1 - game.reload_timer / game.current_reload_time()), 3), AMBER)
	if game.player.shielding:
		label_at(Vector2(game.player.position.x - game.camera_x - 39, game.player.position.y - 185), "GUARDING", 11, AMBER)
	if game.wave_banner > 0:
		var opacity = minf(1, game.wave_banner)
		label_at(Vector2(606, 185), "WAVE %02d" % game.wave, 32, Color(0.91, 0.89, 0.82, opacity), true)
		label_at(Vector2(585, 212), "KEEP THEM OUT OF THE SECTOR", 12, Color(0.83, 0.68, 0.44, opacity))
	for impact in game.impacts:
		if impact.head:
			label_at(impact.pos - Vector2(game.camera_x + 26, 30 + (0.35 - impact.life) * 50), impact.text, 11, Color(0.87, 0.72, 0.45, impact.life / 0.35))
	if not game.paused and not game.game_over:
		draw_reticle()
	if game.reduced_motion:
		label_at(Vector2(45, 751), "REDUCED MOTION", 10, AMBER)
	if not game.sound.enabled:
		label_at(Vector2(45, 733), "AUDIO MUTED", 10, MUTED)

func draw_reticle():
	var requested = game.aim_world - Vector2(game.camera_x, 0)
	var pos = game.actual_aim_world() - Vector2(game.camera_x, 0)
	var gap = 6 + game.shot_spread * 430
	var color = AMBER if game.player.shielding else IVORY
	if game.reload_timer > 0:
		color = MUTED
	for axis in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		line(pos + axis * gap, pos + axis * (gap + 7), Color("101d22"), 4)
		line(pos + axis * gap, pos + axis * (gap + 7), color, 1.3)
	draw_circle(pos, 1.3, color)
	if game.recoil_pitch > 0.012:
		draw_circle(requested, 3.0, Color(0.55, 0.62, 0.59, 0.35), false, 1)
		line(requested, pos, Color(0.83, 0.68, 0.44, 0.25), 1)
	if game.hit_marker > 0:
		var hit_color = AMBER if game.head_marker else IVORY
		for i in range(4):
			var angle = PI / 4 + i * PI / 2
			var direction = Vector2.from_angle(angle)
			line(pos + direction * 6, pos + direction * 13, hit_color, 2)

func draw_pause():
	draw_rect(Rect2(0, 0, 1440, 900), Color(0.02, 0.05, 0.065, 0.85))
	label_at(Vector2(470, 225), "FIELD MANUAL" if game.help_open else "TAKE A BREATH.", 42, IVORY, true)
	line(Vector2(470, 250), Vector2(970, 250), AMBER)
	var rows = [["A / D  or  ARROWS", "Move with acceleration and braking inertia"], ["MOUSE / LEFT CLICK", "Aim / fire (rifle auto, pistol semi)"], ["1 / 2  or  Q", "Rifle / pistol / switch weapon"], ["RIGHT CLICK", "Hold ballistic shield (front only)"], ["R / SPACE / SHIFT", "Reload / jump / sprint"], ["M / V / ESC", "Mute / reduced motion / pause"]]
	for i in range(rows.size()):
		label_at(Vector2(470, 302 + i * 43), rows[i][0], 14, AMBER)
		label_at(Vector2(695, 302 + i * 43), rows[i][1], 14, IVORY)
	label_at(Vector2(470, 622), "Low skill + automatic fire = climb and wide groups.", 16, MUTED)
	label_at(Vector2(470, 652), "Semi-auto settles faster. Hits improve weapon skill.", 16, MUTED)
	label_at(Vector2(470, 707), "[ ESC ]  RETURN TO THE PERIMETER", 14, AMBER)

func draw_end():
	draw_rect(Rect2(0, 0, 1440, 900), Color(0.025, 0.05, 0.06, 0.88))
	label_at(Vector2(475, 280), "SIGNAL LOST", 58, IVORY, true)
	label_at(Vector2(477, 331), "THE PERIMETER WILL REMEMBER YOU.", 14, AMBER)
	line(Vector2(475, 362), Vector2(970, 362), Color("56645a"))
	label_at(Vector2(477, 413), "WAVES REACHED     %02d" % game.wave, 20, IVORY)
	label_at(Vector2(477, 455), "ELIMINATED            %02d" % game.kills, 20, IVORY)
	label_at(Vector2(477, 497), "ACCURACY               %d%%" % (100.0 * game.hits / maxf(1, game.shots_fired)), 20, IVORY)
	label_at(Vector2(477, 539), "SHIELD BLOCKS       %02d" % game.blocked_hits, 20, IVORY)
	label_at(Vector2(477, 638), "[ ENTER / CLICK ]  ONE MORE SHIFT", 17, AMBER)
