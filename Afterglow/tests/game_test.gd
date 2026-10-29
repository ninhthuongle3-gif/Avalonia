extends SceneTree
var checks = 0
var failures = 0

func check(condition: bool, description: String):
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)

func _initialize():
	call_deferred("run_tests")

func run_tests():
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.test_mode = true
	check(game.slots.size() == 4 and game.scrap == 160, "new camp has four slots and starting resources")
	game.purchase("turret")
	check(game.slots[0].kind == "turret" and game.scrap == 75, "tower occupies selected slot and charges cost")
	game.purchase("barricade")
	check(game.scrap == 75, "occupied slot cannot consume resources")
	game.selected = 1
	game.purchase("barricade")
	check(game.slots[1].hp == 240 and game.scrap == 40, "barricade built at second position")
	game.purchase("rifle")
	check(game.squad.is_empty(), "insufficient funds reject recruitment")
	game.scrap = 200
	game.purchase("rifle")
	game.purchase("medic")
	check(game.squad.size() == 2 and game.supplies == 3 and game.scrap == 75, "recruitment spends scrap and food")
	game.base_hp = 300
	game.start_wave()
	game.purchase("repair")
	check(game.base_hp == 300 and game.scrap == 75, "building locked during wave")
	game.phase = "paused"
	game.advance(5)
	check(game.enemies.is_empty() and game.base_hp == 300, "pause freezes spawning and healing")
	game.phase = "combat"
	for i in 6000:
		game.advance(0.05)
		if game.phase != "combat":
			break
	check(game.phase == "build" and game.kills == 9, "real defenders defeat first wave and return to building")
	check(game.scrap == 176 and game.supplies == 5, "kill income and wave rewards paid once")
	check(game.base_hp > 300, "medic restores camp during combat")
	game.reset_game()
	game.start_wave()
	for i in 10000:
		game.advance(0.05)
		if game.phase == "defeat":
			break
	check(game.phase == "defeat" and game.base_hp == 0, "undefended camp loses to real zombie attacks")
	game.reset_game()
	check(game.phase == "build" and game.enemies.is_empty() and game.wave == 0 and game.base_hp == 400, "restart clears previous battle state")
	game.scrap = 1000
	game.supplies = 0
	game.purchase("rifle")
	check(game.squad.is_empty() and game.scrap == 1000, "missing food rejects recruitment without charge")
	game.wave = 2
	game.start_wave()
	for i in 160:
		game.advance(0.05)
	check(game.enemies.any(func(e): return e.kind == "runner") and game.enemies.any(func(e): return e.kind == "brute"), "later waves introduce runners and brutes")
	print("RESULT: %d/%d checks passed" % [checks - failures, checks])
	quit(1 if failures else 0)
