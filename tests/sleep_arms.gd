extends SceneTree
## Headless test: the arms of a sleeper with the head in the hands (SleepArms), measured on the rigs.
## - Both hands end up in front of the face, under the chin, close together.
## - The two arms are mirror images of each other, the elbows out to the sides and forward of the shoulders.
## Run with: godot --headless -s tests/sleep_arms.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _init() -> void:
	run.call_deferred()


func run() -> void:
	for model in ["Rogue", "Barbarian", "Mage", "Knight"]:
		var holder := Node3D.new()
		get_root().add_child(holder)
		var body: Node3D = load("res://assets/characters/%s.glb" % model).instantiate()
		holder.add_child(body)
		var sk := body.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var anim := body.find_child("AnimationPlayer", true, false) as AnimationPlayer
		anim.play("Sit_Chair_Idle")
		await process_frame
		var arms := SleepArms.attach(sk, anim)
		check(arms != null, "%s: the arms attach" % model)
		if arms == null:
			continue
		arms.active = true
		arms._on = 1.0
		var slots := {}
		for b in ["handslot.l", "handslot.r", "head", "upperarm.l", "upperarm.r", "lowerarm.l", "lowerarm.r"]:
			var s := BoneAttachment3D.new()
			s.bone_name = b
			sk.add_child(s)
			slots[b] = s
		for i in 30:
			await process_frame
		var at := {}
		for b: String in slots:
			at[b] = sk.to_local((slots[b] as Node3D).global_position)
		var l: Vector3 = at["handslot.l"]
		var r: Vector3 = at["handslot.r"]
		var head: Vector3 = at["head"]
		check(l.distance_to(r) < 0.2, "%s: the hands are close together (%.2f)" % [model, l.distance_to(r)])
		for hand: Vector3 in [l, r]:
			check(hand.z > head.z + 0.1, "%s: a hand is in front of the face" % model)
			check(hand.y < head.y and hand.y > head.y - 0.2, "%s: a hand is just under the head" % model)
			check(absf(hand.x) < 0.12, "%s: a hand is under the face, not out to the side" % model)
		var le: Vector3 = at["lowerarm.l"]
		var re: Vector3 = at["lowerarm.r"]
		check(absf(le.x + re.x) < 0.06 and absf(le.y - re.y) < 0.06 and absf(le.z - re.z) < 0.06, "%s: the elbows mirror each other" % model)
		check(le.z > (at["upperarm.l"] as Vector3).z + 0.05 and re.z > (at["upperarm.r"] as Vector3).z + 0.05, "%s: the elbows are forward of the shoulders" % model)
		holder.queue_free()
	if failures == 0:
		print("PASS: sleep_arms")
	else:
		print("FAILED: sleep_arms (%d)" % failures)
	quit(1 if failures > 0 else 0)
