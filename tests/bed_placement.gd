extends SceneTree
## Headless test for where the hero lies in a bed (see BedRise, Game._climb_into_bed): in every bed model
## (the cosy bed and the plain cot of inns and dungeons), turned every way, from either side, for a small
## and a big body, the sleeper lies inside the mattress and in the middle of it.
## Then the whole way through Game.sleep in the hero's house: the hero goes to the bed that was run into,
## whichever way they come from, and ends lying on it.
## Run with: godot --headless --fixed-fps 60 -s tests/bed_placement.gd

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


const BODY := ["hips", "spine", "chest", "head", "upperarm.l", "upperarm.r", "hand.l", "hand.r",
		"upperleg.l", "upperleg.r", "foot.l", "foot.r", "toes.l", "toes.r"]
## How far in from the mattress's edges every body part has to lie, metres.
const MARGIN := 0.05


## Whether every body part lies over the mattress of the bed at `bed_pos` turned by `rot`; and where the
## hips and the head are, in the bed's own space.
func _lies_on(sk: Skeleton3D, bed_pos: Vector3, rot: float, what: String) -> void:
	var inverse := Basis(Vector3.UP, rot).inverse()
	for bone in BODY:
		var at: Vector3 = inverse * (sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone)).origin - bed_pos)
		check(at.x > CosyBed.LEFT + MARGIN and at.x < CosyBed.RIGHT - MARGIN and at.z > CosyBed.HEAD + MARGIN and at.z < CosyBed.FOOT - MARGIN,
				"%s: %s lies on the mattress (%.2f, %.2f)" % [what, bone, at.x, at.z])
	var hips: Vector3 = inverse * (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("hips")).origin - bed_pos)
	check(absf(hips.x - (CosyBed.LEFT + CosyBed.RIGHT) * 0.5) < 0.03, "%s: the hips are in the middle across the bed (%.2f)" % [what, hips.x])
	var head: Vector3 = inverse * (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("head")).origin - bed_pos)
	check(absf(head.x - (CosyBed.LEFT + CosyBed.RIGHT) * 0.5) < 0.03, "%s: the head is in the middle across the bed (%.2f)" % [what, head.x])


func _run() -> void:
	var space := Node3D.new()
	root.add_child(space)
	var bed_pos := Vector3(40, 0, 40)
	var hero: Player = game.player
	hero.frozen = true
	var sk: Skeleton3D = hero._model.find_child("Skeleton3D", true, false)
	for model in ["cosy", "cot"]:
		for scale in [0.9, 1.0, 1.15]:
			hero._model.scale = Vector3.ONE * scale
			for quarter in 4:
				for rot: float in [quarter * PI * 0.5, quarter * PI * 0.5 + 0.4]:
					var bed: Node3D = CosyBed.build(space, bed_pos, rot) if model == "cosy" else game.level._place("bed_decorated", bed_pos, rot, space)
					for side: float in [-1.0, 1.0]:
						hero.bed_pose(BedRise.at(BedRise.TUCK_KEYS, BedRise.TUCK_LENGTH, side), bed_pos, rot, side)
						await process_frame
						_lies_on(sk, bed_pos, rot, "%s bed, body %.2f, turned %.2f, side %d" % [model, scale, rot, int(side)])
					bed.queue_free()
	hero._model.scale = Vector3.ONE
	hero.bed_pose_end(bed_pos + Vector3(2, 0, 0), Vector3.BACK)
	# The whole way through Game.sleep, coming to the bed from each of its four sides.
	game.hero_name = "Bed placement test"
	game.escaped = true
	game.quit_on_log_out = false
	var house := 1
	while Homes.owner_of(house) != "":
		house += 1
	check(Homes.claim(game.hero_name, house), "the hero moves into a town house")
	game.inside_house = house
	game.load_level(game.interiors["^"], false)
	await process_frame
	await process_frame
	var bed: Dictionary = game._nearest_bed()
	check(not bed.is_empty(), "the house has a bed")
	var rot: float = bed.get("rot", 0.0)
	for from in [Vector3(0, 0, 2.4), Vector3(0, 0, -2.4), Vector3(2.2, 0, 0), Vector3(-2.2, 0, 0)]:
		hero.frozen = false
		hero.global_position = bed.pos + from
		game._use_station(bed)
		game.sleep()
		var t := 0.0
		while t < 5.0:
			await process_frame
			t += 1.0 / 60.0
		check(hero.in_bed_pose(), "the hero lies in bed (from %s)" % from)
		_lies_on(sk, bed.pos, rot, "slept in the house, from %s" % from)
		# Out again, for the next try.
		hero.bed_pose_end(bed.pos + Vector3(0, 0, 2), Vector3.BACK)
		game.state = game.State.PLAYING
	game.delete_save(game.save_path())
	Homes.release(house)
	print("PASS: bed placement" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
