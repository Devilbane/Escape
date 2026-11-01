extends SceneTree
## Headless test for the peaceful animals in the woods between the graveyard
## and the village: does, stags and foxes are there with every animation
## they need, graze and stroll near home while the hero is far, bolt when the
## hero comes close (later when the hero sneaks), and never stand in the way.
## Run with: godot --headless --fixed-fps 60 -s tests/animals.gd

var failures := 0
var game: Node
var frames := 0
var stage := 0
var stage_frames := 0
var deer: Animal
var start_gap := 0.0
var max_from_home := 0.0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(5)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _finish() -> void:
	game.delete_save(game.save_path(game.hero_name))
	if failures == 0:
		print("PASS: animals")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


## Puts the hero somewhere `gap` metres from the animal, on open ground.
func _hero_near(lvl: Outdoor, animal: Animal, gap: float) -> void:
	var player: Player = game.player
	for i in 16:
		var dir := Vector3(sin(i * TAU / 16.0), 0, cos(i * TAU / 16.0))
		var p := animal.global_position + dir * gap
		if lvl.is_open(lvl.world_to_cell(p)):
			player.global_position = p
			player.velocity = Vector3.ZERO
			return
	player.global_position = animal.global_position + Vector3(gap, 0, 0)


func _far_away() -> void:
	var lvl: Outdoor = game.level
	var player: Player = game.player
	player.global_position = lvl.spots.square[0]
	player.velocity = Vector3.ZERO


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	var lvl: Outdoor = game.level if game.level is Outdoor else null
	match stage:
		0:
			game.hero_name = "Animal test"
			game.escaped = true
			game.load_level(game._outdoor_index(), false)
			game.state = game.State.PLAYING
			lvl = game.level
			var kinds := {}
			for a in lvl.animals:
				kinds[a.kind] = kinds.get(a.kind, 0) + 1
				for anim in ["Idle", "Walk", "Gallop", "Eating"]:
					check(a._anim.has_animation(anim), "%s has the animation %s" % [a.kind, anim])
				check(lvl.is_open(a.home), "%s lives on open ground" % a.kind)
				check(not lvl.enemies.has(a), "%s is not an enemy" % a.kind)
				check(a.find_children("*", "CollisionObject3D", true, false).is_empty(), "%s takes up no room" % a.kind)
				# They live in the woods, well away from the village square.
				check(lvl._flat_distance(a.global_position, lvl.spots.square[0]) > 30.0, "%s lives away from the village" % a.kind)
			print("animals in the woods: ", kinds)
			check(kinds.get("reh", 0) >= 3, "does graze in the woods")
			check(kinds.has("hirsch") and kinds.has("fuchs"), "stags and foxes live in the woods")
			deer = lvl.animals.filter(func(a): return a.kind == "reh")[0]
			_far_away()
			stage_frames = 0
			stage = 1
		1:
			# With the hero far away the doe stays calm and close to home.
			stage_frames += 1
			max_from_home = maxf(max_from_home, deer.global_position.distance_to(lvl.cell_to_world(deer.home)))
			check(not deer.is_fleeing(), "the doe stays calm while the hero is far away")
			if stage_frames < 900:
				return false
			check(max_from_home <= (Animal.KINDS.reh.roam + 1.5) * Level.TILE, "the doe strolls only near home (%.1f m)" % max_from_home)
			_hero_near(lvl, deer, 5.0)
			start_gap = 5.0
			max_from_home = 0.0
			stage_frames = 0
			stage = 2
		2:
			# The hero walks up: the doe bolts.
			stage_frames += 1
			var player: Player = game.player
			max_from_home = maxf(max_from_home, deer.global_position.distance_to(lvl.cell_to_world(deer.home)))
			check(lvl.is_open(lvl.world_to_cell(deer.global_position)), "the doe runs over open ground")
			if stage_frames == 10:
				check(deer.is_fleeing(), "the doe bolts when the hero comes close")
			if stage_frames == 60:
				check(deer._current_anim == "Gallop", "the doe gallops away")
			if stage_frames < 180:
				return false
			var gap := lvl._flat_distance(deer.global_position, player.global_position)
			check(gap > start_gap + 4.0, "the doe got away from the hero (%.1f m)" % gap)
			check(max_from_home <= (Animal.FLEE_ROAM + 1.5) * Level.TILE, "the doe does not run off for good (%.1f m)" % max_from_home)
			# Calm again once the hero is gone.
			_far_away()
			stage_frames = 0
			stage = 3
		3:
			stage_frames += 1
			if deer.is_fleeing() and stage_frames < 600:
				return false
			check(not deer.is_fleeing(), "the doe calms down once the hero is gone")
			# A sneaking hero gets much closer.
			var player: Player = game.player
			player.sneaking = true
			var gap: float = Animal.KINDS.reh.shy * 0.7
			check(gap > deer.shy_distance(), "sneaking makes the doe less shy")
			_hero_near(lvl, deer, gap)
			stage_frames = 0
			stage = 4
		4:
			stage_frames += 1
			if stage_frames == 20:
				check(not deer.is_fleeing(), "the doe does not notice a sneaking hero at %.1f m" % (Animal.KINDS.reh.shy * 0.7))
				_hero_near(lvl, deer, 2.5)
			if stage_frames == 40:
				check(deer.is_fleeing(), "the doe bolts when a sneaking hero comes very close")
				game.player.sneaking = false
				_finish()
				return true
	return false
