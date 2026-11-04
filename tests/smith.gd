extends SceneTree
## Headless test for the smith Gorm: he hammers hot iron on an anvil beside
## his spot instead of the air. He holds a smith's hammer (not an axe), stands
## at the anvil and faces it, the hammer's face comes down on the top of the
## iron (never into the anvil, never short of it), rests there for a beat
## while sparks fly and the anvil rings, then comes up again; away from his
## spot he never swings at all.
## Run with: godot --headless --fixed-fps 60 -s tests/smith.gd

const CHOP := "1H_Melee_Attack_Chop"

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


func _finish() -> void:
	if failures == 0:
		print("PASS: smith")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


## A point of the hammer, given in the hammer's own frame, where it is now.
func _on_hammer(v: Villager, local: Vector3) -> Vector3:
	var hammer: MeshInstance3D = v.find_child("SmithHammer", true, false)
	var hold: BoneAttachment3D = hammer.get_parent()
	var sk: Skeleton3D = v.find_child("Skeleton3D", true, false)
	var bone := sk.find_bone(hold.bone_name)
	return (sk.global_transform * sk.get_bone_global_pose(bone) * hammer.transform) * local


## The corners of the hammer's head (see VillageProps.smith_hammer).
func _head_corners(v: Villager) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for x in [-0.17, 0.01, 0.11]:
		for y in [0.74, 0.86]:
			for z in [-0.06, 0.06]:
				out.append(_on_hammer(v, Vector3(x, y, z)))
	return out


## The lowest corner of the striking face.
func _face_low(v: Villager) -> float:
	var low := INF
	for y in [-0.06, 0.06]:
		for z in [-0.06, 0.06]:
			low = minf(low, _on_hammer(v, Villager.HAMMER_FACE + Vector3(0, y, z)).y)
	return low


## How deep a point lies inside the anvil (0 when outside): the stump, the
## anvil's foot, waist, face, heel and horn, and the hot iron on the face,
## each as a box (the stump as an upright cylinder), as VillageProps builds
## them.
func _sunk(spot: Node3D, p: Vector3) -> float:
	var l := spot.to_local(p) - Villager.ANVIL_AT
	var deep := 0.0
	var stump := VillageProps.SMITH_STUMP
	var top := VillageProps.STUMP_HEIGHT + 0.015
	var off := Vector2(l.x, l.z - stump.x).length()
	if off < stump.y and l.y < top:
		deep = maxf(deep, minf(stump.y - off, top - l.y))
	var iron := VillageProps.HOT_IRON_AT
	for box in [
			[Vector3(0, top, 0), Vector3(0.44, 0.1, 0.34)],
			[Vector3(0, top + 0.1, 0), Vector3(0.2, 0.12, 0.15)],
			[Vector3(0, top + 0.22, 0), Vector3(0.62, 0.14, 0.22)],
			[Vector3(-0.38, top + 0.29, 0), Vector3(0.16, 0.07, 0.16)],
			[Vector3(0.45, top + 0.25, 0), Vector3(0.3, 0.12, 0.12)],
			[Vector3(iron.x, iron.y, iron.z), Vector3(0.3, VillageProps.HOT_IRON_HEIGHT, 0.08)]]:
		var foot: Vector3 = box[0]
		var size: Vector3 = box[1]
		var d := Vector3(size.x * 0.5 - absf(l.x - foot.x), minf(l.y - foot.y, foot.y + size.y - l.y), size.z * 0.5 - absf(l.z - foot.z))
		if d.x > 0.0 and d.y > 0.0 and d.z > 0.0:
			deep = maxf(deep, minf(d.x, minf(d.y, d.z)))
	return deep


func _run() -> void:
	game.load_level(game._outdoor_index(), false)
	for i in 3:
		await physics_frame
	var lvl: Outdoor = game.level
	var gorm: Villager = null
	for v: Villager in lvl.villagers:
		if v.role == "1":
			gorm = v
	check(gorm != null, "Gorm lives in the village")
	if gorm == null:
		_finish()
		return
	var hammer: MeshInstance3D = gorm.find_child("SmithHammer", true, false)
	var axe: MeshInstance3D = gorm.find_child("1H_Axe", true, false)
	check(hammer != null and hammer.visible, "Gorm holds a smith's hammer")
	check(axe == null or not axe.visible, "and no axe")
	var spot: Node3D = lvl.get_node_or_null("SmithAnvil")
	check(spot != null, "an anvil stands by the smith's spot")
	check(gorm.chops() and gorm.smiths(), "Gorm hammers on it")
	if spot == null or hammer == null or not gorm.chops():
		_finish()
		return
	var anvil := spot.to_global(Villager.ANVIL_AT)
	check(lvl.world_to_cell(anvil) == gorm.home, "the anvil stands on his own tile")
	check(lvl.world_to_cell(anvil + Vector3(-0.4, 0, 0)) == gorm.home, "all of it")
	# Facing his forge, on the tile just west of him.
	check(gorm._chop_face.is_equal_approx(Vector3.LEFT), "he faces his forge")

	# Keep the hero well away so nobody talks to him, and let him work.
	game.player.global_position = gorm.global_position + Vector3(0, 0, 24)
	gorm.play("Idle", 0.0)
	gorm.global_position = gorm._chop_stand + Vector3(0.5, 0, 0.4)
	gorm._start("work", 1000.0)

	var deepest := 0.0
	var strikes := 0
	var held_frames := 0
	var at_strike := Vector3.INF
	var low_at_strike := INF
	var sparks_flew := false
	var swung_off_spot := false
	var was_held := false
	var rests := 0
	var was_swinging := false
	for i in 60 * 9:
		await process_frame
		var anim: AnimationPlayer = gorm._anim
		var swinging := anim.current_animation == CHOP
		if swinging and gorm.global_position.distance_to(gorm._chop_stand) > 0.1:
			swung_off_spot = true
		# Every blow, the way up and down again, and the rest between.
		for c in _head_corners(gorm):
			deepest = maxf(deepest, _sunk(spot, c))
		var held := swinging and anim.speed_scale == 0.0
		if held:
			held_frames += 1
			if not was_held:
				strikes += 1
				if strikes == 1:
					at_strike = _on_hammer(gorm, Villager.HAMMER_FACE)
					low_at_strike = _face_low(gorm)
					sparks_flew = gorm._chips.emitting
		was_held = held
		if was_swinging and not swinging:
			rests += 1
		was_swinging = swinging
	check(not swung_off_spot, "he never swings before he stands at the anvil")
	print("%d blows, %d frames on the iron, %d strokes to rest" % [strikes, held_frames, rests])
	check(rests >= 1, "between a few blows he lowers the hammer and rests")
	check(strikes >= 2, "he strikes the iron again and again (%d blows)" % strikes)
	check(sparks_flew, "sparks fly when the hammer strikes")
	check(held_frames >= strikes * 3, "the hammer rests on the iron for a beat")
	check(held_frames <= strikes * 9, "only a beat: a hammer rings off, it does not stick")
	check(deepest < 0.015, "the hammer never sinks into the anvil (%.3f m)" % deepest)
	if at_strike != Vector3.INF:
		var top := VillageProps.ANVIL_TOP + VillageProps.HOT_IRON_HEIGHT
		check(absf(low_at_strike - top) < 0.04, "the hammer lands on the iron, not in the air (lowest corner %.3f, iron top %.3f)" % [low_at_strike, top])
		check(spot.to_local(at_strike).distance_to(Villager.HAMMER_POINT) < 0.06, "HAMMER_POINT still matches the animation (%s)" % spot.to_local(at_strike))
		var on := spot.to_local(at_strike) - Villager.ANVIL_AT - VillageProps.HOT_IRON_AT
		check(absf(on.x) < 0.1 and absf(on.z) < 0.04, "it lands on the hot iron on the anvil's face")
		check(gorm._chips.global_position.distance_to(at_strike) < 0.08, "the sparks fly from where the hammer strikes")
	var facing := Vector3(sin(gorm.rotation.y), 0, cos(gorm.rotation.y))
	check(facing.angle_to(Vector3.LEFT) < 0.15, "he faces the anvil while he works")

	# Off his tile (a walk cut short) he does not swing at the air.
	gorm._anim.play("Idle")
	gorm._current_anim = "Idle"
	gorm.global_position = gorm._chop_stand + Vector3(Level.TILE * 2, 0, 0)
	gorm._start("work", 1000.0)
	var swung := false
	for i in 60 * 4:
		await process_frame
		if gorm._anim.current_animation == CHOP:
			swung = true
	check(not swung, "away from the anvil he never swings")

	# Talking to him lifts the hammer at once.
	gorm.global_position = gorm._chop_stand
	gorm._start("work", 1000.0)
	for i in 60 * 6:
		await process_frame
		if gorm._anim.speed_scale == 0.0:
			break
	gorm.play("Idle")
	check(gorm._anim.speed_scale == 1.0 and gorm._anim.current_animation == "Idle", "anything else frees the hammer")
	_finish()
