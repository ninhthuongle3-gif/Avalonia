extends SceneTree
var game
var checks = 0
var failures = 0

func _initialize():
	call_deferred("run")

func check(ok: bool, message: String):
	checks += 1
	if ok:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func frames(count: int):
	for i in range(count):
		await physics_frame
	await process_frame

func press(action: String, down: bool):
	if down:
		Input.action_press(action)
	else:
		Input.action_release(action)

func foot_world(side: String) -> Vector3:
	return game.player.rig.to_global(game.player.rig.bone_pose(side + "_foot").origin)

func run():
	game = load("res://scenes/range.tscn").instantiate()
	root.add_child(game)
	game.combat_mode = false
	game.sound.enabled = false
	game.begin_game(false)
	var p = game.player
	p.position = Vector3(3, 0.05, 12)
	await frames(10)
	var rig = p.rig
	check(rig.skeleton.get_bone_count() >= 30, "real Skeleton3D exposes at least thirty named bones")
	check(rig.skeleton.get_bone_parent(rig.bones.left_hand) == rig.bones.left_forearm and rig.skeleton.get_bone_parent(rig.bones.right_foot) == rig.bones.right_shin, "hands and feet have articulated elbow/knee chains")
	check(rig.attachments.left_hand is BoneAttachment3D and rig.bones.has("right_index"), "mesh slots attach to actual hand and finger bones")
	check(not p.aiming and not game.hud.reticle_visible() and p.weapon.rotation.x < -0.7, "free state lowers weapon and hides the reticle")
	press("tps_fire", true)
	await frames(20)
	press("tps_fire", false)
	check(p.shots == 0 and p.ammo == 24, "left mouse cannot shoot while weapon is lowered")
	var old_body_yaw: float = p.body_yaw
	p.yaw = 0.8
	p.sync_look()
	await frames(8)
	check(absf(p.body_yaw - old_body_yaw) < 0.01, "free-look camera can orbit without rotating an idle character")
	p.yaw = 0
	p.sync_look()
	press("tps_forward", true)
	await frames(6)
	var slow_speed: float = p.real_speed
	check(slow_speed > 0.1 and slow_speed < 1.8, "walking accelerates over time instead of reaching full speed immediately")
	await frames(30)
	check(p.real_speed > slow_speed + 2 and p.locomotion_state == "walk", "held movement builds speed and selects locomotion pose")
	# Inspect the actual solved foot bone in world space, not just its desired target.
	var locked_frames = 0
	var worst_drift = 0.0
	var previous_feet = {"left": foot_world("left"), "right": foot_world("right")}
	var previous_stance = rig.stance.duplicate()
	for i in range(36):
		await frames(1)
		for side in ["left", "right"]:
			var actual = foot_world(side)
			if rig.stance[side] and previous_stance[side]:
				worst_drift = maxf(worst_drift, actual.distance_to(previous_feet[side]))
				locked_frames += 1
			previous_feet[side] = actual
			previous_stance[side] = rig.stance[side]
	print("FOOT LOCK: %d measured stance frames; maximum actual bone drift %.5fm" % [locked_frames, worst_drift])
	check(locked_frames >= 10 and worst_drift < 0.02, "planted foot bones stay within two centimetres between physics frames")
	press("tps_sprint", true)
	await frames(30)
	check(p.real_speed > 6.5 and rig.sprint_blend > 0.8 and rig.lean.x > 0.05, "sprint builds speed and adds forward lean with a distinct stride")
	locked_frames = 0
	worst_drift = 0
	previous_feet = {"left": foot_world("left"), "right": foot_world("right")}
	previous_stance = rig.stance.duplicate()
	for i in range(36):
		await frames(1)
		for side in ["left", "right"]:
			var actual = foot_world(side)
			if rig.stance[side] and previous_stance[side]:
				worst_drift = maxf(worst_drift, actual.distance_to(previous_feet[side]))
				locked_frames += 1
			previous_feet[side] = actual
			previous_stance[side] = rig.stance[side]
	print("SPRINT FOOT LOCK: %d measured stance frames; maximum actual bone drift %.5fm" % [locked_frames, worst_drift])
	check(locked_frames >= 8 and worst_drift < 0.02, "sprint foot placement remains locked during the shorter support phase")
	press("tps_forward", false)
	press("tps_sprint", false)
	await frames(3)
	check(p.real_speed > 5 and p.locomotion_state == "brake", "release starts a visible braking phase while preserving momentum")
	await frames(50)
	check(p.real_speed < 0.05, "braking eventually brings player to a full stop")
	p.position = Vector3(3, 0.05, 9)
	p.velocity = Vector3.ZERO
	press("tps_right", true)
	await frames(24)
	check(p.body_yaw < -1 and not p.aiming, "free movement turns the body toward travel independently of the camera")
	press("tps_right", false)
	await frames(25)
	press("tps_aim", true)
	await frames(3)
	check(p.aim_weight > 0 and p.aim_weight < 0.9 and not p.try_fire(false), "aim-raise transition prevents firing before weapon is ready")
	await frames(30)
	check(game.hud.reticle_visible() and p.weapon.rotation.x > -0.2 and absf(p.body_yaw - p.yaw) < 0.05, "holding aim raises rifle, aligns torso and shows reticle")
	var left_error = foot_world("left")
	left_error = rig.to_global(rig.bone_pose("left_hand").origin) - rig.left_grip.global_position
	var right_error: Vector3 = rig.to_global(rig.bone_pose("right_hand").origin) - rig.right_grip.global_position
	print("GRIP ERROR: left=%.5fm right=%.5fm" % [left_error.length(), right_error.length()])
	check(left_error.length() < 0.04 and right_error.length() < 0.04, "two-bone arm IK places both hands on real weapon grips")
	press("tps_forward", true)
	press("tps_sprint", true)
	await frames(30)
	check(not p.sprinting and p.real_speed <= p.AIM_SPEED + 0.05 and p.locomotion_state == "aim_walk", "aiming replaces sprint with slow, directed movement")
	press("tps_forward", false)
	press("tps_sprint", false)
	await frames(20)
	p.ammo = 10
	p.begin_reload()
	await frames(30)
	check(p.locomotion_state == "reload" and absf(p.weapon.rotation.z) > 0.1, "reload adds a layered weapon pose while retaining the articulated rig")
	press("tps_aim", false)
	await frames(22)
	check(not game.hud.reticle_visible() and p.weapon.rotation.x < -0.7, "releasing aim returns to lowered weapon and hides reticle")
	game.set_paused(true)
	var phase: float = rig.gait_phase
	var reload_time: float = p.reload_timer
	await frames(10)
	check(rig.gait_phase == phase and p.reload_timer == reload_time, "pause freezes animation and weapon simulation")
	for action in ["tps_aim", "tps_fire", "tps_forward", "tps_right", "tps_sprint"]:
		Input.action_release(action)
	print("LOCOMOTION RESULT: %d/%d checks passed" % [checks - failures, checks])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
