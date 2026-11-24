extends SceneTree
## Headless test: Hanna's water yoke (WaterYoke, YokeArms, WaterRound).
## - The yoke hangs two buckets from the chest bone; they are empty or full as `full` says.
## - Both hands end up on the beam, mirrored left and right, and the buckets swing with the steps.
## - Her round runs from the fountain to the doors of the shops and the tavern and back, the
##   buckets full on the way out and empty on the way back.
## Run with: godot --headless --fixed-fps 60 -s tests/water_yoke.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	Lang.language = "en"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await _bare_rogue()
	await _village()
	if failures == 0:
		print("PASS: water yoke")
	quit(1 if failures > 0 else 0)


func _bare_rogue() -> void:
	var model: Node3D = load("res://assets/characters/Rogue.glb").instantiate()
	root.add_child(model)
	var anim: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	for a in ["Idle", "Walking_A"]:
		anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	anim.play("Idle")
	await _wait(3)
	var sk: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var yoke := WaterYoke.attach(model, anim)
	check(yoke != null, "the yoke goes on a Rogue")
	check(yoke.get_parent() is BoneAttachment3D and (yoke.get_parent() as BoneAttachment3D).bone_name == "chest", "it hangs from the chest bone")
	var buckets := yoke.find_children("Bucket", "Node3D", true, false)
	check(buckets.size() == 2, "two buckets hang from it (%d)" % buckets.size())
	var waters := yoke.find_children("Water", "MeshInstance3D", true, false)
	check(waters.size() == 2 and not (waters[0] as Node3D).visible and not (waters[1] as Node3D).visible, "the buckets start empty")
	yoke.full = true
	check((waters[0] as Node3D).visible and (waters[1] as Node3D).visible, "full buckets show water")
	check(WaterYoke.beam_y(0.0) > WaterYoke.beam_y(WaterYoke.HALF), "the beam's ends curve down over the shoulders")
	# The hands rest on the beam, one on each side.
	var arms := YokeArms.attach(sk, anim)
	check(arms != null, "the arms attach")
	arms.active = true
	# The hands as a bone attachment sees them: it follows the modified pose.
	var slots := []
	for bone in ["hand.l", "hand.r"]:
		var slot := BoneAttachment3D.new()
		slot.bone_name = bone
		sk.add_child(slot)
		slots.append(slot)
	await _wait(40)
	var left: Vector3 = sk.to_local((slots[0] as Node3D).global_position)
	var right: Vector3 = sk.to_local((slots[1] as Node3D).global_position)
	check(left.x > 0.35 and left.x < 0.65 and absf(left.y - 1.2) < 0.12 and absf(left.z) < 0.15, "the left hand rests on the beam (%s)" % left)
	check(right.x < -0.35 and right.x > -0.65 and absf(right.y - 1.2) < 0.12 and absf(right.z) < 0.15, "the right hand rests on the beam (%s)" % right)
	check(absf(left.x + right.x) < 0.06 and absf(left.y - right.y) < 0.06, "the hands are mirrored")
	# The buckets rock with the steps and settle when she stands.
	anim.play("Walking_A")
	var widest := 0.0
	for i in 90:
		await _wait(1)
		widest = maxf(widest, absf((buckets[0] as Node3D).get_parent().rotation.x))
	check(widest > 0.03 and widest < 0.3, "the buckets swing a little walking (%.3f)" % widest)
	check(absf(WaterYoke.swing_at(0.25, 0.1, 0.0)) <= 0.1001, "a swing never exceeds its width")
	anim.play("Idle")
	await _wait(120)
	check(absf((buckets[0] as Node3D).get_parent().rotation.x) < 0.03, "they hang still when she stands")
	model.queue_free()


func _village() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = "Yoke"
	await _wait(10)
	game.load_level(game._outdoor_index(), false)
	await _wait(30)
	var lvl: Outdoor = game.level
	check(not lvl.spots.fountain.is_empty(), "the village map has a fountain spot for the round")
	var stops := WaterRound.stops(lvl)
	check(stops.size() >= 3, "she calls at several doors (%d)" % stops.size())
	for letter in ["n", "m"]:
		check(lvl.doors.has(letter) and stops.has(lvl.doors[letter]), "the round includes the %s door" % ["tavern" if letter == "n" else "shop"])
	var hanna: Villager = null
	for v: Villager in lvl.villagers:
		if v.role == WaterRound.ROLE:
			hanna = v
	check(hanna != null, "Hanna lives in the village")
	if hanna == null:
		return
	check(hanna._yoke != null and hanna._yoke_arms != null, "she has a yoke and the arms for it")
	# A day's round: filled at the fountain, set off for a door, emptied there, back to the fountain.
	var fill := WaterRound.fill_spot(lvl)
	hanna.global_position = fill
	hanna._task = "work"
	hanna._next_task()
	check(hanna.water_full, "the buckets are full when she leaves the fountain")
	check(hanna._task == "walk", "she sets off")
	var door := stops[0]
	hanna.global_position = door
	hanna._task = "walk"
	hanna._next_task()
	check(not hanna.water_full and hanna._task == "idle", "she empties the buckets at the door")
	hanna._task = "idle"
	hanna._next_task()
	check(not hanna.water_full and hanna._task == "walk", "she walks back for more")
	hanna.global_position = fill
	hanna._task = "walk"
	hanna._next_task()
	check(hanna._task == "work", "she dips the buckets at the fountain")
	# The yoke is on by day and off at night and in bed.
	lvl.set_hour(11.0)
	hanna.night = false
	check(WaterRound.carries(hanna), "she wears the yoke by day")
	hanna.night = true
	check(not WaterRound.carries(hanna), "not at night")
	hanna.night = false
