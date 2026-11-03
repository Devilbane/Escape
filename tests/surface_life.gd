extends SceneTree
## Headless test for the life on the ground above (see SurfaceLife): every
## part of the open-air map gets its own litter, paths stay clear in the
## middle, litter makes way for loot lying on the floor, nothing blocks the
## way, and the little creatures crawl about near the hero.
## Run with: godot --headless --fixed-fps 60 -s tests/surface_life.gd

var failures := 0
var game: Node
var frames := 0
var stage := 0
var wait := 0
var life: SurfaceLife
var coin_spot := Vector3.ZERO
var beetle: Dictionary
var beetle_from := Vector3.ZERO


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(11)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _finish() -> void:
	game.delete_save(game.save_path())
	print("PASS: life on the ground above" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _cell_of(lvl: Level, letter: String) -> Vector2i:
	for y in lvl.height:
		for x in lvl.width:
			if lvl.cell_char(Vector2i(x, y)) == letter:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	if wait > 0:
		wait -= 1
		return false
	match stage:
		0:
			game.hero_name = "Ground test"
			game.escaped = true
			game.load_level(game._outdoor_index(), false)
			game.state = game.State.PLAYING
			wait = 10
			stage = 1
		1:
			_check_litter()
			_check_creatures()
			if failures > 0:
				_finish()
				return true
			# A coin spilt onto a spot full of leaves.
			game.level._lay_coin(coin_spot)
			wait = 30
			stage = 2
		2:
			check(life.litter_near(coin_spot, 1.0) == 0, "no litter covers a coin lying on the floor (%d pieces)" % life.litter_near(coin_spot, 1.0))
			check(life.lifted_count() > 0, "litter around the coin is lifted away")
			# The coin is picked up: the litter comes back.
			var pickups: Array = game.level._pickups
			for p in pickups.duplicate():
				if p.kind == "coin" and (p.node as Node3D).global_position.distance_to(Vector3(coin_spot.x, 0.03, coin_spot.z)) < 0.1:
					p.node.queue_free()
					pickups.erase(p)
			wait = 30
			stage = 3
		3:
			check(life.lifted_count() == 0, "the litter comes back once the coin is gone")
			check(life.litter_near(coin_spot, 1.0) > 0, "the leaves lie there again")
			# The hero walks up to a beetle: it scurries off.
			for cr in life.critters():
				if cr.kind == "beetle":
					beetle = cr
					break
			check(not beetle.is_empty(), "there are beetles")
			if not beetle.is_empty():
				beetle_from = beetle.node.position
				game.player.global_position = beetle_from + Vector3(1.5, 0, 0)
			wait = 60
			stage = 4
		4:
			if not beetle.is_empty():
				check(beetle.node.visible, "a beetle near the hero is drawn")
				check(beetle.node.position.distance_to(beetle_from) > 0.5, "a beetle runs from the hero (moved %.2f)" % beetle.node.position.distance_to(beetle_from))
				var far := true
				for cr in life.critters():
					if cr.node.position.distance_to(game.player.global_position) > SurfaceLife.ACTIVE_RANGE + 2.0 and cr.node.visible:
						far = false
				check(far, "creatures far from the hero rest unseen")
			_finish()
			return true
	return false


func _check_litter() -> void:
	var lvl: Level = game.level
	life = lvl.get_node_or_null("SurfaceLife")
	check(life != null, "the open-air map has life on the ground")
	if life == null:
		return
	check(life.litter_total > 2000 and life.litter_total <= SurfaceLife.LITTER_CAP,
			"plenty of litter, under the cap (%d)" % life.litter_total)
	for biome in [SurfaceLife.VILLAGE, SurfaceLife.FOREST, SurfaceLife.GRAVEYARD, SurfaceLife.HOLLOW, SurfaceLife.PASS, SurfaceLife.MOUNTAIN]:
		check(life.litter_by_biome.get(biome, 0) > 50, "litter lies in the %s (%d)" % [biome, life.litter_by_biome.get(biome, 0)])
	var expect := {":": SurfaceLife.VILLAGE, "g": SurfaceLife.GRAVEYARD, "W": SurfaceLife.HOLLOW,
			"N": SurfaceLife.PASS, "'": SurfaceLife.MOUNTAIN, "&": SurfaceLife.FOREST}
	for letter in expect:
		var c := _cell_of(lvl, letter)
		check(c.x >= 0 and life.biome_of(c) == expect[letter], "'%s' lies in the %s (got %s)" % [letter, expect[letter], life.biome_of(c)])
	check(life.litter_on_path_middles() == 0, "the middle of every path stays clear (%d pieces)" % life.litter_on_path_middles())
	check(life.find_children("*", "CollisionObject3D", true, false).is_empty(), "nothing on the ground blocks the way")
	var batches: Array = life.find_children("*", "MultiMeshInstance3D", true, false)
	check(batches.size() > 20, "litter is drawn in batches (%d)" % batches.size())
	for b: MultiMeshInstance3D in batches:
		if b.name.begins_with("Litter_") and b.visibility_range_end <= 0.0:
			check(false, "litter far away is not drawn")
			break
	# A grass tile in the woods with leaves on it, for the coin.
	var c := _cell_of(lvl, "&")
	for y in lvl.height:
		for x in lvl.width:
			var cell := Vector2i(x, y)
			if lvl.cell_char(cell) == "." and life.biome_of(cell) == SurfaceLife.FOREST and life.litter_near(lvl.cell_to_world(cell), 1.0) >= 3:
				c = cell
				break
		if lvl.cell_char(c) == ".":
			break
	coin_spot = lvl.cell_to_world(c)
	check(life.litter_near(coin_spot, 1.0) > 0, "the coin's spot is covered in litter before")


func _check_creatures() -> void:
	if life == null:
		return
	var kinds := {}
	for cr in life.critters():
		kinds[cr.kind] = true
	check(life.critters().size() > 10 and life.critters().size() <= SurfaceLife.CRITTER_CAP,
			"creatures crawl about, under the cap (%d)" % life.critters().size())
	for kind in ["beetle", "worm", "lizard", "snail"]:
		check(kinds.has(kind), "there are %ss" % kind)
	check(life.trails().size() > 0 and life.trails().size() <= SurfaceLife.TRAIL_CAP, "ants march in lines (%d)" % life.trails().size())
	for cr in life.critters():
		if cr.kind == "lizard":
			check(life.biome_of(game.level.world_to_cell(cr.node.position)) == SurfaceLife.MOUNTAIN, "lizards live on the mountain road")
			break
