extends SceneTree
## Headless test for the woodcutter Bruno: he chops a felled trunk beside
## his spot instead of the air. He stands at the trunk and faces it, the
## lower blade of his axe comes down on the top of the trunk (never through
## it, never short of it), sticks there for a moment while chips fly and the
## chop is heard, and away from his spot he never swings at all.
## Run with: godot --headless --fixed-fps 60 -s tests/woodcutter.gd

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
		print("PASS: woodcutter")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


## Where the cutting edge of the lower blade of the two-handed axe is now.
## The axe's head spans its local x from -0.62 to 0.62 at 0.87 up the
## handle; the chop brings the -x edge down.
func _blade(v: Villager) -> Vector3:
	var axe: MeshInstance3D = v.find_child("2H_Axe", true, false)
	var hold: BoneAttachment3D = axe.get_parent()
	var sk: Skeleton3D = v.find_child("Skeleton3D", true, false)
	var bone := sk.find_bone(hold.bone_name)
	return (sk.global_transform * sk.get_bone_global_pose(bone) * axe.transform) * Vector3(-0.62, 0.87, 0)


## How far a point is from the trunk's axis, measured across the trunk, and
## whether it lies along the trunk (between its two ends).
func _from_axis(spot: Node3D, p: Vector3) -> Vector2:
	var local := spot.to_local(p) - Villager.LOG_CENTRE
	var along := absf(local.x) <= Villager.LOG_LENGTH * 0.5
	return Vector2(Vector2(local.y, local.z).length(), 1.0 if along else 0.0)


func _run() -> void:
	game.load_level(game._outdoor_index(), false)
	for i in 3:
		await physics_frame
	var lvl: Outdoor = game.level
	var bruno: Villager = null
	for v: Villager in lvl.villagers:
		if v.role == "3":
			bruno = v
	check(bruno != null, "Bruno lives in the village")
	if bruno == null:
		_finish()
		return
	var spot: Node3D = lvl.get_node_or_null("ChoppingLog")
	check(spot != null, "a felled trunk lies by the woodcutter's spot")
	check(bruno.chops(), "Bruno chops on it")
	if spot == null or not bruno.chops():
		_finish()
		return
	check(lvl.world_to_cell(spot.global_position) == bruno.home, "the trunk lies on his own tile")
	check(spot.to_global(Villager.LOG_CENTRE).distance_to(bruno._chop_stand) < Level.TILE * 0.5, "within the tile")
	# Facing the stump with the logs just east of him on the village map.
	check(bruno._chop_face.is_equal_approx(Vector3.RIGHT), "he faces the stump with the logs")

	# Keep the hero well away so nobody talks to him, and let him work.
	game.player.global_position = bruno.global_position + Vector3(0, 0, 24)
	bruno.play("Idle", 0.0)
	bruno.global_position = bruno._chop_stand + Vector3(0.6, 0, -0.4)
	bruno._start("work", 1000.0)

	# He steps onto his spot and turns to the trunk before the first blow.
	var deepest := INF
	var bites := 0
	var stuck_frames := 0
	var first_bite := -1
	var at_bite := Vector3.INF
	var chips_flew := false
	var swung_off_spot := false
	for i in 60 * 9:
		await process_frame
		var anim: AnimationPlayer = bruno._anim
		if anim.current_animation == "2H_Melee_Attack_Chop":
			if bruno.global_position.distance_to(bruno._chop_stand) > 0.1:
				swung_off_spot = true
			var a := _from_axis(spot, _blade(bruno))
			if a.y > 0.0:
				deepest = minf(deepest, a.x)
			if anim.speed_scale == 0.0:
				stuck_frames += 1
				if first_bite < 0:
					first_bite = i
					at_bite = _blade(bruno)
					bites += 1
					chips_flew = bruno._chips.emitting
		if first_bite >= 0 and anim.current_animation != "2H_Melee_Attack_Chop" and anim.speed_scale == 1.0 and bites == 1 and stuck_frames > 0:
			bites = 2
	check(not swung_off_spot, "he never swings before he stands at the trunk")
	check(first_bite > 0, "the blade bites into the trunk")
	check(chips_flew, "chips fly when it bites")
	check(stuck_frames >= 12, "the axe sticks in the wood for a moment (%d frames)" % stuck_frames)
	check(bites == 2, "then he pulls it out and stands back")
	var r := Villager.LOG_RADIUS
	check(deepest >= r - 0.12, "the blade never cuts deep into the trunk (%.2f m from its axis, radius %.2f)" % [deepest, r])
	if at_bite != Vector3.INF:
		var hit := _from_axis(spot, at_bite)
		check(hit.y > 0.0, "the blade lands along the trunk, not past its ends")
		check(absf(hit.x - r) < 0.12, "the blade lands on the wood, not in the air (%.2f m from its axis)" % hit.x)
		check(spot.to_local(at_bite).distance_to(Villager.BITE_POINT) < 0.12, "BITE_POINT still matches the animation")
		check(bruno._chips.global_position.distance_to(at_bite) < 0.15, "the chips fly from where the blade bites")
	var facing := Vector3(sin(bruno.rotation.y), 0, cos(bruno.rotation.y))
	check(facing.angle_to(Vector3.RIGHT) < 0.15, "he faces the trunk while he chops")

	# Off his tile (a walk cut short) he does not swing at the air.
	bruno._anim.play("Idle")
	bruno._current_anim = "Idle"
	bruno.global_position = bruno._chop_stand + Vector3(0, 0, Level.TILE * 2)
	bruno._start("work", 1000.0)
	var swung := false
	for i in 60 * 4:
		await process_frame
		if bruno._anim.current_animation == "2H_Melee_Attack_Chop":
			swung = true
	check(not swung, "away from the trunk he never swings")

	# Talking to him pulls the axe out at once.
	bruno.global_position = bruno._chop_stand
	bruno._start("work", 1000.0)
	for i in 60 * 6:
		await process_frame
		if bruno._anim.speed_scale == 0.0:
			break
	bruno.play("Idle")
	check(bruno._anim.speed_scale == 1.0 and bruno._anim.current_animation == "Idle", "anything else frees the stuck axe")
	_finish()
