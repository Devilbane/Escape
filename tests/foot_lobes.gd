extends SceneTree
## Headless test: the mountain's foot spreads out over the meadow (see MountainFoot): lobes and mounds of rock the hero
## walks up onto, low enough to step over (a mound is at most half a character high), never on the approach of a
## climbing spot, which stays as clean as before, and nothing grows in them.
## Run with: godot --headless --fixed-fps 60 -s tests/foot_lobes.gd

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


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


## Walks the hero from `from` towards `to` (metres, x and z) for `seconds` and reports how high he got and where he ended.
func _walk(hero: Player, from: Vector3, to: Vector3, seconds: float) -> Dictionary:
	hero.global_position = from + Vector3(0, 0.6, 0)
	hero.velocity = Vector3.ZERO
	hero.reset_physics_interpolation()
	await _wait(10)
	var top := 0.0
	var dir := Vector3(to.x - from.x, 0, to.z - from.z).normalized()
	for i in int(seconds * 60.0):
		hero.steer = dir
		await physics_frame
		hero.hp = hero.max_hp
		top = maxf(top, hero.global_position.y)
	hero.steer = Vector3.ZERO
	await _wait(10)
	print("walk from z %.1f to %.1f: ended at (%.2f, %.2f, %.2f) top %.2f speed %.1f" % [from.z, to.z, hero.global_position.x, hero.global_position.y, hero.global_position.z, top, hero.speed])
	return {"top": top, "end": hero.global_position}


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game.hero_name = "Foot test"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	await _wait(30)
	game.state = game.State.PLAYING
	var lvl: Outdoor = game.level
	var hero: Player = game.player
	for e in lvl.enemies:
		if is_instance_valid(e):
			e.queue_free()
	lvl.enemies.clear()
	game.day_hour = 12.0
	lvl.set_hour(12.0)
	game.weather = Weather.CLEAR
	game.weather_hours = 9999.0
	var tile := Level.TILE

	# The parts are there.
	var foot := lvl.get_node_or_null("MountainFoot")
	check(foot != null and foot.get_child_count() > 20, "the foot is dressed with lobes, mounds and small things")
	var made := MountainFoot.mounds(lvl)
	check(made.size() >= 10, "there are mounds in the grass (%d)" % made.size())
	for m: Dictionary in made:
		var top := 0.0
		for k in 40:
			var a := TAU * k / 40.0
			for rr in [0.0, 0.3, 0.6]:
				top = maxf(top, MountainFoot.mound_height(m, m.at.x + cos(a) * m.r * rr, m.at.y + sin(a) * m.r * rr))
		check(top <= 0.8, "a mound is at most half a character high (%.2f m)" % top)
		check(Mountains.near_rock(lvl, m.at.x, m.at.y, 0.5), "nothing is planted in a mound")

	# The approach of every climbing spot is clean: no lobe, no mound, within the clean rectangle.
	for s: Dictionary in ClimbSpots.spots(lvl):
		var c: Vector2i = s.cell
		var biggest := 0.0
		for dx in range(-1, 2):
			for dy in range(0, 4):
				var at := lvl.cell_to_world(c + Vector2i(dx, dy))
				var rects := MountainFoot._rects_near(lvl, at.x, at.z, 3)
				for ox in [-1.5, 0.0, 1.5]:
					for oz in [-1.5, 0.0, 1.5]:
						biggest = maxf(biggest, MountainFoot.lobe_height(lvl, rects, at.x + ox, at.z + oz))
		check(biggest < 0.01, "the approach of the spot at %s has no lobe (%.2f m)" % [c, biggest])
		for m: Dictionary in made:
			check((m.at as Vector2).distance_to(Vector2(lvl.cell_to_world(c).x, lvl.cell_to_world(c).z + 2 * tile)) > 3.0 + float(m.r), "no mound stands in front of the spot at %s" % c)
	# The small things lie round the lobes and mounds, never inside them.
	var root := lvl.get_node("MountainFoot")
	var buried := 0
	var seen := 0
	for node in root.get_children():
		if node is MultiMeshInstance3D and not String(node.name).begins_with("Lobes"):
			var mm := (node as MultiMeshInstance3D).multimesh
			for i in mm.instance_count:
				var o := mm.get_instance_transform(i).origin
				seen += 1
				var rects := MountainFoot._rects_near(lvl, o.x, o.z, 3)
				var near: Array = made.filter(func(m: Dictionary) -> bool: return (m.at as Vector2).distance_to(Vector2(o.x, o.z)) < float(m.r) * 1.5 + 1.0)
				if MountainFoot.ground_height(lvl, rects, near, o.x, o.z) > 0.03:
					buried += 1
	for node in root.get_children():
		if node is MultiMeshInstance3D:
			check((node as MultiMeshInstance3D).visibility_range_end == 0.0, "%s has no visibility range (it spans the map, so it would vanish with the hero's distance from its middle)" % node.name)
	check(seen > 100 and buried == 0, "no small thing lies inside a lobe or a mound (%d of %d)" % [buried, seen])
	# The scree of the passes gets a foot too (the open "'" ground), and leaves lie on top of a lobe.
	var scree_lobe := false
	var lifted := 0.0
	for y in lvl.height:
		for x in lvl.width:
			var c := Vector2i(x, y)
			if lvl.cell_char(c) != "'" or scree_lobe:
				continue
			var mid := lvl.cell_to_world(c)
			var rects := MountainFoot._rects_near(lvl, mid.x, mid.z, 3)
			for ox in [-1.5, 0.0, 1.5]:
				for oz in [-1.5, 0.0, 1.5]:
					var h := MountainFoot.lobe_height(lvl, rects, mid.x + ox, mid.z + oz)
					if h > 0.2:
						scree_lobe = true
						lifted = maxf(lifted, MountainFoot.surface_at(lvl, mid.x + ox, mid.z + oz))
	check(scree_lobe, "the scree of a pass has lobes too")
	check(lifted > 0.2, "the leaves and litter are lifted onto a lobe (%.2f m)" % lifted)
	# The hero still reaches a spot's foot and walks up to its rock.
	var spot := ClimbSpots.at(lvl, Vector2i(84, 54))
	var front := lvl.cell_to_world(spot.cell + Vector2i(0, 3))
	var walked := await _walk(hero, front, lvl.cell_to_world(spot.cell + Vector2i(0, 1)), 8.0)
	check(float(walked.top) < 0.2 and float((walked.end as Vector3).z) < lvl.cell_to_world(spot.cell).z + tile * 0.5 + 1.4, "he walks right up to the foot of a climbing spot on flat ground (top %.2f)" % float(walked.top))

	# A lobe: the hero walks from the open meadow straight at the rock, and goes up onto the lobe.
	var best := Vector3.INF
	var best_h := 0.0
	for x in range(40, 120):
		var c := Vector2i(x, 55)
		if lvl.cell_char(c) != ".":
			continue
		var at := lvl.cell_to_world(c)
		var rects := MountainFoot._rects_near(lvl, at.x, at.z, 3)
		var h := MountainFoot.lobe_height(lvl, rects, at.x, at.z - 1.0)
		if h > best_h:
			best_h = h
			best = at
	check(best_h > 0.25, "a lobe of the foot stands in the row in front of the rock (%.2f m)" % best_h)
	if best_h > 0.25:
		var out := await _walk(hero, best + Vector3(0, 0, 8.0), best + Vector3(0, 0, -2.0), 9.0)
		check(float(out.top) > 0.15, "the hero walks up onto a lobe (top %.2f m)" % float(out.top))
		var end: Vector3 = out.end
		check(end.z < best.z + 0.2, "and on up to the rock, not held back by it (z %.2f, lobe at %.2f)" % [end.z, best.z])
		var rects := MountainFoot._rects_near(lvl, end.x, end.z, 3)
		check(absf(end.y - MountainFoot.lobe_height(lvl, rects, end.x, end.z)) < 0.35, "his feet follow the lobe (y %.2f, lobe %.2f)" % [end.y, MountainFoot.lobe_height(lvl, rects, end.x, end.z)])

	# A mound: through the middle of it and out on the other side.
	# (A tree, a boulder or a building may stand beside one: a few mounds are tried.)
	var crossed := false
	var tried := 0
	for i in made.size():
		var m: Dictionary = made[i]
		if tried >= 8 or crossed:
			break
		if MountainFoot.rock_distance(lvl, m.at.x, m.at.y) < float(m.r) + 6.0 or not MountainFoot._plain(lvl, m.at.x, m.at.y - 6.0) or not MountainFoot._plain(lvl, m.at.x, m.at.y + 6.0):
			continue
		tried += 1
		var mid := Vector3(m.at.x, 0, m.at.y)
		var cross := await _walk(hero, mid + Vector3(0, 0, 5.0), mid + Vector3(0, 0, -5.0), 8.0)
		crossed = float(cross.top) > float(m.h) * 0.5 and (cross.end as Vector3).z < mid.z - 1.0 and (cross.end as Vector3).y < 0.3 and float(cross.top) < 1.2
	check(crossed, "the hero walks over a mound and out on the other side (%d tried)" % tried)

	game.delete_save(game.save_path())
	print("PASS: foot lobes" if failures == 0 else "FAILED: %d" % failures)
	quit(failures)
