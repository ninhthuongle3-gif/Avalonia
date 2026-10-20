extends Control
## A resolution-independent instrument overlay, drawn in a 1440 x 900 design space.
var game
var font = preload("res://assets/heading.ttf")
var small_font = ThemeDB.fallback_font
const INK = Color("e6eee5")
const TEAL = Color("70e2ca")
const AMBER = Color("ffc17a")
const MUTED = Color("a4b6b6")

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func text(at: Vector2, value: String, size: int = 18, color: Color = INK, heading: bool = false):
	draw_string(font if heading else small_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func panel(rect: Rect2):
	draw_rect(rect, Color(0.025, 0.07, 0.085, 0.88))
	draw_line(rect.position, rect.position + Vector2(0, rect.size.y), TEAL, 2)

func _draw():
	if not is_instance_valid(game) or not is_instance_valid(game.player):
		return
	var viewport = get_viewport_rect().size
	draw_set_transform(Vector2.ZERO, 0, viewport / Vector2(1440, 900))
	var p = game.player
	text(Vector2(42, 48), "LAST LIGHT", 30, INK, true)
	text(Vector2(43, 72), "Q U A R A N T I N E   D I V I S I O N", 12, TEAL)
	draw_line(Vector2(43, 91), Vector2(368, 91), Color(0.4, 0.7, 0.67, 0.6))
	text(Vector2(1125, 43), "FIELD TEST  /  01", 22, AMBER, true)
	text(Vector2(1125, 69), "THIRD PERSON  /  LIVE FIRE", 13, MUTED)
	if not game.started or game.paused:
		draw_rect(Rect2(0, 0, 1440, 900), Color(0.015, 0.035, 0.05, 0.78))
		panel(Rect2(100, 178, 670, 548))
		text(Vector2(134, 218), "TRAINING PROTOCOL  /  SECTOR 09", 15, TEAL)
		text(Vector2(130, 295), "HOLD THE LINE" if not game.paused else "SESSION PAUSED", 58, INK, true)
		text(Vector2(134, 339), "Clear all six targets. Stay aware of your barrel and cover.", 20)
		text(Vector2(134, 373), "Adult survivor placeholder / third-person handling prototype", 16, MUTED)
		var lines = ["W A S D   Move       SHIFT   Sprint       SPACE   Jump", "MOUSE   Look       RMB   Aim       LMB   Fire", "Q   Switch shoulder       R   Reload       T   Reset drill", "ESC   Pause / release cursor       M   Toggle sound"]
		for i in range(lines.size()):
			text(Vector2(134, 430 + i * 40), lines[i], 18, INK)
		draw_rect(Rect2(134, 618, 600, 62), Color("234c50"))
		text(Vector2(156, 658), "ENTER  /  " + ("BEGIN FIELD TEST" if not game.paused else "RESUME SESSION"), 25, TEAL, true)
		return
	# Center remains the true camera ray. Recoil rotates the camera, never just a cosmetic reticle.
	var center = Vector2(720, 450)
	var gap = 5.0 + p.bloom * 850.0 + (0.0 if p.aiming else 6.0)
	var reticle = TEAL if game.hit_timer > 0.0 else INK
	for dir in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_line(center + dir * gap, center + dir * (gap + 7), reticle, 2, true)
	draw_circle(center, 1.8, reticle)
	if game.hit_timer > 0.0:
		for dir in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			draw_line(center + dir * 10, center + dir * 18, TEAL, 2, true)
	panel(Rect2(42, 119, 286, 147))
	text(Vector2(60, 146), "OBJECTIVE  /  RANGE CLEARANCE", 13, TEAL)
	text(Vector2(60, 186), "%02d / 06 TARGETS" % game.drill_targets.size(), 28, INK, true)
	text(Vector2(60, 214), "Orange plates / instant headshot takedown", 12, MUTED)
	text(Vector2(60, 245), "%02d:%02d   /   %s" % [int(game.elapsed) / 60, int(game.elapsed) % 60, "COMPLETE" if game.drill_complete else "IN PROGRESS"], 16, AMBER)
	panel(Rect2(42, 733, 326, 119))
	text(Vector2(61, 761), "OPERATOR  /  01", 13, TEAL)
	text(Vector2(61, 791), "SURVIVOR", 24, INK, true)
	text(Vector2(61, 825), "%s SHOULDER   /   %s" % ["RIGHT" if p.shoulder > 0 else "LEFT", "AIMING" if p.aiming else ("SPRINTING" if p.sprinting else "READY")], 14, MUTED)
	panel(Rect2(1090, 704, 308, 148))
	text(Vector2(1110, 736), "AR-07  /  5.56 x 45", 20, TEAL, true)
	text(Vector2(1106, 797), "%02d" % p.ammo, 59, AMBER if p.ammo <= 5 else INK, true)
	text(Vector2(1210, 795), "/  %03d" % p.reserve, 27, MUTED)
	text(Vector2(1110, 828), "RELOADING" if p.reload_timer > 0 else "AUTO   /   R TO RELOAD", 13, AMBER)
	if p.reload_timer > 0:
		draw_rect(Rect2(1110, 841, 268 * (1.0 - p.reload_timer / p.RELOAD_TIME), 3), TEAL)
	var accuracy = 0 if p.shots == 0 else roundi(100.0 * game.hits / p.shots)
	text(Vector2(470, 826), "HITS  %02d     HEADSHOTS  %02d     ACCURACY  %d%%" % [game.hits, game.headshots, accuracy], 17, INK)
	text(Vector2(432, 875), "Q  SHOULDER     RMB  AIM     R  RELOAD     T  RESET     ESC  PAUSE", 14, MUTED)
	if game.notice_timer > 0.0:
		var width = small_font.get_string_size(game.notice, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		draw_rect(Rect2(700 - width * 0.5, 113, width + 40, 42), Color(0.02, 0.065, 0.075, 0.93))
		text(Vector2(720 - width * 0.5, 141), game.notice, 17, AMBER)
