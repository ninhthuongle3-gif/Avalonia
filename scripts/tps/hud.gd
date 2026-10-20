extends Control
## A resolution-independent instrument overlay, drawn in a 1440 x 900 design space.
var game
var font = preload("res://assets/heading.ttf")
var small_font = ThemeDB.fallback_font
const INK = Color("e6eee5")
const TEAL = Color("70e2ca")
const AMBER = Color("ffc17a")
const MUTED = Color("a4b6b6")

func reticle_visible() -> bool:
	return game.started and not game.paused and game.player.aiming and game.player.aim_weight >= 0.9 and not game.dead

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
	text(Vector2(1080, 43), "QUARANTINE  /  02", 22, AMBER, true)
	text(Vector2(1080, 69), "INFECTED BREACH" if game.combat_mode else "TRAINING RANGE", 13, MUTED)
	if not game.started or game.paused:
		draw_rect(Rect2(0, 0, 1440, 900), Color(0.015, 0.035, 0.05, 0.78))
		panel(Rect2(100, 178, 670, 548))
		text(Vector2(134, 218), "TRAINING PROTOCOL  /  SECTOR 09", 15, TEAL)
		var title = "OPERATOR DOWN" if game.dead else ("SECTOR SECURED" if game.combat_complete else ("HOLD THE LINE" if not game.paused else "SESSION PAUSED"))
		text(Vector2(130, 295), title, 54, INK, true)
		text(Vector2(134, 339), "Survive three waves. Gunfire draws the infected." if game.combat_mode else "Clear all six targets. Watch your barrel and cover.", 20)
		text(Vector2(134, 373), "F2: switch breach / training    F3: show skeleton joints", 16, TEAL)
		var lines = ["W A S D   Move       SHIFT   Sprint       SPACE   Jump", "MOUSE   Free look       HOLD RMB   Raise weapon / aim", "LMB   Fire while aiming       Q   Shoulder       R   Reload", "T   Restart       ESC   Pause       M   Toggle sound"]
		for i in range(lines.size()):
			text(Vector2(134, 430 + i * 40), lines[i], 18, INK)
		draw_rect(Rect2(134, 618, 600, 62), Color("234c50"))
		var action = "RESTART" if game.dead or game.combat_complete else ("BEGIN SESSION" if not game.paused else "RESUME SESSION")
		text(Vector2(156, 658), "ENTER  /  " + action, 25, TEAL, true)
		return
	# Center remains the true camera ray. Recoil rotates the camera, never just a cosmetic reticle.
	var center = Vector2(720, 450)
	var gap = 5.0 + p.bloom * 850.0
	var reticle = TEAL if game.hit_timer > 0.0 else INK
	if reticle_visible():
		for dir in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_line(center + dir * gap, center + dir * (gap + 7), reticle, 2, true)
		draw_circle(center, 1.8, reticle)
		if game.hit_timer > 0.0:
			for dir in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				draw_line(center + dir * 10, center + dir * 18, TEAL, 2, true)
	panel(Rect2(42, 119, 286, 147))
	text(Vector2(60, 146), "OBJECTIVE  /  " + ("SURVIVE THE BREACH" if game.combat_mode else "RANGE CLEARANCE"), 13, TEAL)
	text(Vector2(60, 186), "WAVE %d / 3" % game.wave if game.combat_mode else "%02d / 06 TARGETS" % game.drill_targets.size(), 28, INK, true)
	text(Vector2(60, 214), "%d ACTIVE  /  %d ELIMINATED" % [game.alive_infected(), game.infected_kills] if game.combat_mode else "Orange plates / instant headshot takedown", 12, MUTED)
	text(Vector2(60, 245), "%02d:%02d   /   %s" % [int(game.elapsed) / 60, int(game.elapsed) % 60, "BREACH IN %ds" % ceili(game.wave_delay) if game.combat_mode and game.alive_infected() == 0 else "IN PROGRESS"], 16, AMBER)
	panel(Rect2(42, 733, 326, 119))
	text(Vector2(61, 761), "OPERATOR  /  01", 13, TEAL)
	text(Vector2(61, 791), "HEALTH  %03d" % int(p.health), 24, INK, true)
	draw_rect(Rect2(61, 802, 280, 3), Color("374b4b"))
	draw_rect(Rect2(61, 802, 280 * p.health / 100, 3), TEAL if p.health > 35 else AMBER)
	text(Vector2(61, 832), "%s  /  %s" % ["RIGHT" if p.shoulder > 0 else "LEFT", p.locomotion_state.to_upper()], 14, MUTED)
	panel(Rect2(1090, 704, 308, 148))
	text(Vector2(1110, 736), "AR-07  /  5.56 x 45", 20, TEAL, true)
	text(Vector2(1106, 797), "%02d" % p.ammo, 59, AMBER if p.ammo <= 5 else INK, true)
	text(Vector2(1210, 795), "/  %03d" % p.reserve, 27, MUTED)
	text(Vector2(1110, 828), "RELOADING" if p.reload_timer > 0 else "AUTO   /   R TO RELOAD", 13, AMBER)
	if p.reload_timer > 0:
		draw_rect(Rect2(1110, 841, 268 * (1.0 - p.reload_timer / p.RELOAD_TIME), 3), TEAL)
	var accuracy = 0 if p.shots == 0 else roundi(100.0 * game.hits / p.shots)
	text(Vector2(470, 826), "HITS  %02d     HEADSHOTS  %02d     ACCURACY  %d%%" % [game.hits, game.headshots, accuracy], 17, INK)
	text(Vector2(395, 875), "HOLD RMB  AIM / FIRE     Q  SHOULDER     F2  MODE     T  RESTART     ESC  PAUSE", 14, MUTED)
	if p.damage_flash > 0:
		var flash = Color(0.8, 0.1, 0.06, p.damage_flash * 0.8)
		draw_rect(Rect2(0, 0, 1440, 18), flash)
		draw_rect(Rect2(0, 882, 1440, 18), flash)
		draw_rect(Rect2(0, 0, 18, 900), flash)
		draw_rect(Rect2(1422, 0, 18, 900), flash)
	if game.notice_timer > 0.0:
		var width = small_font.get_string_size(game.notice, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		draw_rect(Rect2(700 - width * 0.5, 113, width + 40, 42), Color(0.02, 0.065, 0.075, 0.93))
		text(Vector2(720 - width * 0.5, 141), game.notice, 17, AMBER)
