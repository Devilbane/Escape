extends SceneTree
## Headless test for going to bed and getting up (see BedRise, BedBlanket): at every moment of both
## sequences, on either side of the bed, no part of the body sinks into the floor or into the mattress;
## the hero ends standing on the floor beside the bed; the weapon is away while in bed and back after; the
## blanket lies over the sleeper and is thrown back flat (no tent).
## Run with: godot --headless --fixed-fps 60 -s tests/bed_rise.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


## The bones of the body itself (not the rig's helpers).
const BODY := ["hips", "spine", "chest", "head", "upperarm.l", "upperarm.r", "lowerarm.l", "lowerarm.r", "hand.l", "hand.r",
		"upperleg.l", "upperleg.r", "lowerleg.l", "lowerleg.r", "foot.l", "foot.r", "toes.l", "toes.r"]


## The lowest body part (metres above the floor of the bed) and the lowest one over the mattress.
func _lowest(sk: Skeleton3D, bed_pos: Vector3, rot: float) -> Dictionary:
	var floor_low := INF
	var over_bed_low := INF
	var inverse := Basis(Vector3.UP, rot).inverse()
	for bone in BODY:
		var i := sk.find_bone(bone)
		var at := sk.global_transform * sk.get_bone_global_pose(i).origin - bed_pos
		floor_low = minf(floor_low, at.y)
		var local := inverse * at
		if local.x > CosyBed.LEFT + 0.15 and local.x < CosyBed.RIGHT - 0.15 and local.z > CosyBed.HEAD + 0.15 and local.z < CosyBed.FOOT - 0.15:
			over_bed_low = minf(over_bed_low, at.y)
	return {"floor": floor_low, "bed": over_bed_low}


func _run() -> void:
	var space := Node3D.new()
	root.add_child(space)
	var bed_pos := Vector3(40, 0, 40)
	var hero: Player = game.player
	hero.frozen = true
	var sk: Skeleton3D = hero._model.find_child("Skeleton3D", true, false)
	for rot: float in [0.0, 1.3]:
		var bed := CosyBed.build(space, bed_pos, rot)
		for side: float in [-1.0, 1.0]:
			for part in ["tuck", "rise"]:
				var keys: Array = BedRise.TUCK_KEYS if part == "tuck" else BedRise.RISE_KEYS
				var t := 0.0
				var worst_floor := INF
				var worst_bed := INF
				while t <= BedRise.length(keys):
					hero.bed_pose(BedRise.at(keys, t, side), bed_pos, rot, side)
					await process_frame
					var low := _lowest(sk, bed_pos, rot)
					worst_floor = minf(worst_floor, low.floor)
					worst_bed = minf(worst_bed, low.bed)
					check(not hero._model.find_child("handslot_r", true, false).visible, "no knife in hand in bed (%s, t %.1f)" % [part, t])
					t += 0.1
				check(worst_floor > -0.06, "%s, side %d, bed turned %.1f: nothing sinks into the floor (%.2f)" % [part, int(side), rot, worst_floor])
				check(worst_bed > 0.74, "%s, side %d, bed turned %.1f: nothing sinks into the mattress (%.2f)" % [part, int(side), rot, worst_bed])
				if part == "rise":
					# The last key: standing on the floor beside the bed.
					var low := _lowest(sk, bed_pos, rot)
					check(low.floor < 0.12 and low.floor > -0.06, "up, the feet are on the floor (%.2f)" % low.floor)
		bed.queue_free()
		await process_frame
	hero.bed_pose_end(bed_pos + Vector3(2, 0, 0), Vector3.BACK)
	check(hero._model.find_child("handslot_r", true, false).visible, "the knife is back in hand when up")
	check(is_zero_approx(hero._model.rotation.x), "the hero stands upright again")
	# The blanket: over the sleeper, then thrown back flat and left there; a new night pulls it up again.
	var bed2 := CosyBed.build(space, bed_pos, 0.0)
	var cloth := BedBlanket.of(space, bed_pos, 0.0)
	check(cloth.get_parent() == bed2, "the blanket belongs to the bed")
	check(not BedBlanket.covers(space, bed_pos, 0.0), "no blanket over anybody at first")
	BedBlanket.tuck(space, bed_pos, 0.0, true)
	check(BedBlanket.covers(space, bed_pos, 0.0), "tucked in, the blanket covers the sleeper")
	BedBlanket.push_off(space, bed_pos, 0.0, true)
	check(not BedBlanket.covers(space, bed_pos, 0.0) and cloth.visible, "pushed off, it lies on the bed")
	check(cloth.scale.y < 0.4, "thrown back, it lies flat, no tent (%.2f)" % cloth.scale.y)
	check(BedRise.TUCK_LENGTH == BedRise.length(BedRise.TUCK_KEYS) and BedRise.RISE_LENGTH == BedRise.length(BedRise.RISE_KEYS),
			"the lengths of the sequences are the ones the villagers use")
	# A game saved in bed starts in bed and the hero gets up: blanket thrown back, up on their feet beside the bed.
	game.hero_name = "Bed rise test"
	game.escaped = true
	if Homes.house_of(game.hero_name) > 0:
		Homes.release(Homes.house_of(game.hero_name))
	var house := 1
	while Homes.owner_of(house) != "":
		house += 1
	check(Homes.claim(game.hero_name, house), "the hero moves into a town house")
	game.inside_house = house
	game.load_level(game.interiors["^"], false)
	await process_frame
	var flags := {"up": false}
	var loaded: bool = game._wake_in_bed({"away": {"hours": 8}}, func(): flags.up = true)
	check(loaded, "a game saved in bed wakes up in it")
	var waited := 0.0
	while not flags.up and waited < 30.0:
		await process_frame
		waited += 1.0 / 60.0
	check(flags.up and not hero.in_bed_pose() and not hero.frozen, "the hero gets up and can move again (%.1f s)" % waited)
	var bed_station: Dictionary = game._nearest_bed()
	check(not bed_station.is_empty() and absf(hero.global_position.y - bed_station.pos.y) < 0.3, "standing on the floor, not sunk into it")
	check(not BedBlanket.covers(game.level, bed_station.pos, float(bed_station.get("rot", 0.0))), "the blanket is thrown back")
	check(hero._model.find_child("handslot_r", true, false).visible, "the knife is back in hand")
	game.delete_save(game.save_path())
	Homes.release(house)
	print("PASS: bed rise" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
