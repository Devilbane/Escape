extends SceneTree
## Headless test: the arm that carries a torch or a lamp (CarryArm, HandLamp).
## - The arm reaches forward and rocks only a few degrees with the steps (twice a walk cycle).
## - A lamp hangs upright whichever way its bearer faces, at the bearer's scale.
## - Villagers are mixed: some carry a lamp and some a torch.
## Run with: godot --headless -s tests/carry_arm.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _init() -> void:
	run.call_deferred()


func run() -> void:
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for i in 101:
		var a := CarryArm.angles(i / 100.0, CarryArm.ROCK_RUN)
		lo = Vector2(minf(lo.x, a.x), minf(lo.y, a.y))
		hi = Vector2(maxf(hi.x, a.x), maxf(hi.y, a.y))
	check(lo.x > CarryArm.REACH - 6.0 and hi.x < CarryArm.REACH + 6.0, "the raise only rocks a few degrees")
	check(lo.y > CarryArm.BEND - 6.0 and hi.y < CarryArm.BEND + 6.0, "the bend only rocks a few degrees")
	pass
	var still := CarryArm.angles(0.37, 0.0)
	check(is_equal_approx(still.x, CarryArm.REACH) and is_equal_approx(still.y, CarryArm.BEND), "no rock when standing")
	var steps := 0
	var prev := CarryArm.angles(0.0, 3.0).x - CarryArm.REACH
	for i in range(1, 201):
		var cur := CarryArm.angles(i / 200.0, 3.0).x - CarryArm.REACH
		if prev < 0.0 and cur >= 0.0:
			steps += 1
		prev = cur
	check(steps == 2, "two rocks in a cycle, one a step (%d)" % steps)
	check(CarryArm.carries_in("Walking_A") and CarryArm.carries_in("Idle") and not CarryArm.carries_in("Cheer"), "it carries in walks and idle only")
	for yaw in [0.0, 1.0, 2.5, -2.0]:
		var b := HandLamp.hanging(yaw, 1.2, 0.7)
		check(absf(b.y.normalized().y) > 0.99, "the lamp hangs upright (yaw %.1f)" % yaw)
		check(is_equal_approx(b.get_scale().x, 1.2), "the lamp keeps the bearer's scale")
	for yaw in [0.0, 1.7, -2.4]:
		var up := HandLamp.held_up(yaw, 1.0)
		check(up.y.normalized().y > 0.98, "a held torch keeps its flame up (yaw %.1f)" % yaw)
	var lamp_root := Node3D.new()
	HandLamp.build(lamp_root)
	var lamp_flames := 0
	for c in lamp_root.get_children():
		if c is CPUParticles3D:
			lamp_flames += 1
			check((c as CPUParticles3D).local_coords, "the lamp's flame stays with the lamp, no blaze trail")
	check(lamp_flames == 1, "the lamp has one flame")
	lamp_root.free()
	var lamps := 0
	var torches := 0
	for role: String in Villager.ROLES:
		var v := Villager.new()
		v.role = role
		if v.carries_lamp():
			lamps += 1
		else:
			torches += 1
		v.free()
	check(lamps > 0 and torches > 0, "some villagers carry lamps, some torches (%d/%d)" % [lamps, torches])
	# Where the hand really ends up, measured on the rigs of the villagers and the hero: far in front
	# of the belly (and clear of it sideways), about shoulder height, standing and walking.
	for model in ["Rogue", "Barbarian", "Mage", "Knight"]:
		var holder := Node3D.new()
		get_root().add_child(holder)
		var body: Node3D = load("res://assets/characters/%s.glb" % model).instantiate()
		holder.add_child(body)
		var sk := body.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var anim := body.find_child("AnimationPlayer", true, false) as AnimationPlayer
		anim.play("Idle")
		await process_frame
		var arm := CarryArm.attach(sk, anim)
		check(arm != null, "%s: the arm attaches" % model)
		if arm == null:
			continue
		arm.active = true
		# The hand as the torch sees it: a bone attachment, which follows the modified pose.
		var slot := BoneAttachment3D.new()
		slot.bone_name = "handslot.l"
		sk.add_child(slot)
		var shoulder_slot := BoneAttachment3D.new()
		shoulder_slot.bone_name = "upperarm.l"
		sk.add_child(shoulder_slot)
		var belly_slot := BoneAttachment3D.new()
		belly_slot.bone_name = "hips"
		sk.add_child(belly_slot)
		for clip in ["Idle", "Walking_A", "Walking_B", "Walking_C", "Running_A", "Running_B"]:
			anim.play(clip)
			for i in 30:
				await process_frame
			var hand := sk.to_local(slot.global_position)
			var shoulder := sk.to_local(shoulder_slot.global_position)
			var belly := sk.to_local(belly_slot.global_position)
			check(hand.z - belly.z > 0.45, "%s %s: the hand is held far in front (%.2f)" % [model, clip, hand.z - belly.z])
			check(absf(hand.y - shoulder.y) < (0.4 if clip.begins_with("Running") else 0.25), "%s %s: the hand is about shoulder height (%.2f)" % [model, clip, hand.y - shoulder.y])
			check(hand.x > (0.15 if clip == "Idle" else -0.1), "%s %s: the hand stays off the middle of the body (%.2f)" % [model, clip, hand.x])
		holder.queue_free()
	print("PASS" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
