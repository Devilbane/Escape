extends SceneTree
## Headless test: a cow's and a bull's snow tracks are one print per hoof, pressed where and when that hoof lands.
## - SnowTrail.HOOVES (touchdown time and spot of each hoof) is measured again from the bones of the Walk and Gallop.
## - Playing a walk cycle through SnowTrail.hoofbeats presses exactly four prints, life-sized (smaller than 20 cm).
## Run with: godot --headless -s tests/hoof_prints.gd

var failures := 0


class FakeLevel extends Node:
	var snow := {"amount": 1.0}
	var player: Node3D
	var pressed: Array = []

	func snow_print(at: Vector3, heading: float, size := 1.0, kind := "boot") -> void:
		pressed.append([at, heading, size, kind])


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	var bones := ["FF_L", "FF_R", "FFB_L", "FFB_R"]
	for model_name in ["Cow", "Bull"]:
		var model: Node3D = load("res://assets/animals/%s.glb" % model_name).instantiate()
		root.add_child(model)
		await process_frame
		var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
		var skel: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
		for anim: String in SnowTrail.HOOVES:
			var length := player.get_animation(anim).length
			var n := 120
			var poses := {}
			for b in bones:
				poses[b] = []
			for i in n:
				player.play(anim)
				player.seek(length * float(i) / n, true, true)
				var to_model := model.global_transform.affine_inverse() * skel.global_transform
				for b in bones:
					poses[b].append(to_model * skel.get_bone_global_pose(skel.find_bone(b)).origin)
			var listed: Array = SnowTrail.HOOVES[anim]
			check(listed.size() == 4, "%s %s lists four hooves" % [model_name, anim])
			for b in bones:
				var low := INF
				var high := -INF
				for p: Vector3 in poses[b]:
					low = minf(low, p.y)
					high = maxf(high, p.y)
				var limit := low + (high - low) * 0.2
				var td := -1
				for i in n:
					if poses[b][(i - 1 + n) % n].y > limit and poses[b][i].y <= limit:
						td = i
				check(td >= 0, "%s %s: %s lands" % [model_name, anim, b])
				if td < 0:
					continue
				var spot: Vector3 = poses[b][td]
				var found := false
				for hoof: Array in listed:
					if absf(fposmod(float(td) / n - float(hoof[0]) + 0.5, 1.0) - 0.5) < 0.02 \
							and absf(float(hoof[1]) - spot.x) < 0.05 and absf(float(hoof[2]) - spot.z) < 0.1:
						found = true
				check(found, "%s %s: %s lands at %.3f, %.2f, %.2f in the list" % [model_name, anim, b, float(td) / n, spot.x, spot.z])
		model.queue_free()
	# One walk cycle presses four small prints.
	var level := FakeLevel.new()
	root.add_child(level)
	var hero := Node3D.new()
	level.add_child(hero)
	level.player = hero
	var rig := Node3D.new()
	level.add_child(rig)
	rig.scale = Vector3.ONE * 0.3
	var model: Node3D = load("res://assets/animals/Cow.glb").instantiate()
	rig.add_child(model)
	await process_frame
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	var trail := SnowTrail.new("cow")
	player.play("Walk")
	var length := player.get_animation("Walk").length
	for i in 61:
		player.seek(length * float(i) / 60.0, true, true)
		trail.hoofbeats(level, rig, player)
	check(level.pressed.size() == 4, "one walk cycle presses four prints, got %d" % level.pressed.size())
	for rec: Array in level.pressed:
		var size: Vector2 = SnowPrints.KINDS[rec[3]] * float(rec[2])
		check(size.x < 0.2 and size.y < 0.22, "a cow's hoof print is small (%.2f x %.2f m)" % [size.x, size.y])
	print("PASS: hoof_prints" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
