extends SceneTree
## Headless test for the eerie dungeon sounds (DungeonSounds): every take of
## every kind is part of the game and short; in a dungeon floor a sound comes
## now and then, from a spot of its own a few tiles from the hero, quietly,
## through the Effects bus, and never the same kind twice in a row. Nothing
## plays in the safe room, under the open sky or while a skeleton hunts the
## hero, and the sounds fall silent with the floor they were heard on.
## Run with: godot --headless --fixed-fps 60 -s tests/dungeon_sounds.gd

var failures := 0
var game: Node
var frames := 0
var stage := 0
var stage_frames := 0


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
	if failures == 0:
		print("PASS: dungeon sounds")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _next() -> void:
	stage += 1
	stage_frames = 0


func _players(lvl: Node) -> Array:
	return lvl.find_children("*", "AudioStreamPlayer3D", false, false) \
			.filter(func(p): return str(p.stream.resource_path).contains("dungeon_"))


func _level_index(name_part: String) -> int:
	for i in game.level_files.size():
		if game.level_files[i].contains(name_part):
			return i
	return -1


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	if game.player:
		game.player.hp = game.player.max_hp
	stage_frames += 1
	var ds: DungeonSounds = game.dungeon_sounds
	match stage:
		0:
			check(ds != null, "the game listens for sounds in the dark")
			for kind in DungeonSounds.KINDS:
				for n in int(DungeonSounds.KINDS[kind].count):
					var take := "dungeon_%s_%d" % [kind, n]
					var path := Sfx.DIR + take + ".ogg"
					check(ResourceLoader.exists(path), "the sound %s is part of the game" % take)
					if ResourceLoader.exists(path):
						var s: AudioStream = load(path)
						check(s.get_length() > 0.3 and s.get_length() < 8.0, "%s is short (%.1f s)" % [take, s.get_length()])
						check(not s.loop, "%s plays once" % take)
				check(float(DungeonSounds.KINDS[kind].db) <= -10.0, "%s is quiet" % kind)
			game.hero_name = "Sound test"
			game.load_level(_level_index("03_das_labyrinth"), false)
			game.state = game.State.PLAYING
			_next()
		1:
			if stage_frames < 10:
				return false
			var lvl: Level = game.level
			check(not lvl.safe and not lvl.outdoor, "the labyrinth is a dungeon floor")
			# A skeleton on the hero's heels: no sounds.
			var hunter: Enemy = null
			for e in lvl.enemies:
				if is_instance_valid(e) and not e.dead:
					hunter = e
					break
			check(hunter != null, "the labyrinth has a skeleton")
			if hunter:
				hunter._wake(game.player.global_position)
				check(hunter.is_hunting() and not ds.can_play(), "no sounds while a skeleton hunts the hero")
			# Then keep the skeletons out of it.
			for e in lvl.enemies:
				if is_instance_valid(e):
					e.queue_free()
			lvl.enemies.clear()
			_next()
		2:
			var lvl: Level = game.level
			check(ds.can_play(), "sounds may come in the dungeon")
			# A sound of every kind: from where, how loud, through which bus.
			var hero: Vector3 = game.player.global_position
			for kind in DungeonSounds.KINDS:
				var p: AudioStreamPlayer3D = ds.play(kind)
				check(p != null and p.get_parent() == lvl, "a %s plays in the level" % kind)
				if p == null:
					continue
				check(p.bus == Sfx.BUS, "a %s goes through the Effects bus" % kind)
				check(p.volume_db <= -10.0, "a %s is quiet (%.1f dB)" % [kind, p.volume_db])
				var flat := Vector2(p.global_position.x - hero.x, p.global_position.z - hero.z).length()
				var info: Dictionary = DungeonSounds.KINDS[kind]
				check(flat <= (float(info.far) + 1.0) * Level.TILE, "a %s comes from nearby (%.1f m)" % [kind, flat])
				check(p.global_position.distance_to(hero) > 1.0 or kind == "skitter", "a %s comes from a spot of its own" % kind)
			# Picked by chance, never twice the same in a row.
			var last := ""
			var seen := {}
			for i in 200:
				var k := ds.pick_kind()
				check(k != last, "never the same kind twice in a row")
				ds._last_kind = k
				last = k
				seen[k] = true
			check(seen.size() == DungeonSounds.KINDS.size(), "every kind comes up (%d)" % seen.size())
			for p in _players(lvl):
				p.queue_free()
			# On their own: the timer runs out and a sound comes.
			ds._timer = 0.05
			_next()
		3:
			if stage_frames < 10:
				return false
			check(_players(game.level).size() == 1, "a sound comes on its own when the timer runs out")
			check(ds._timer >= DungeonSounds.GAP_MIN, "and the next waits a while (%.1f s)" % ds._timer)
			_next()
		4:
			# The safe room: no sounds.
			for p in _players(game.level):
				p.queue_free()
			game.load_level(_level_index("05_die_zuflucht"), false)
			game.state = game.State.PLAYING
			_next()
		5:
			if stage_frames < 10:
				return false
			check(game.level.safe, "the refuge is a safe room")
			check(not ds.can_play(), "no sounds in the safe room")
			ds._timer = 0.0
			_next()
		6:
			if stage_frames < 30:
				return false
			check(_players(game.level).is_empty(), "nothing plays in the safe room")
			# Under the open sky: no sounds either.
			game.escaped = true
			game.load_level(game._outdoor_index(), false)
			game.state = game.State.PLAYING
			_next()
		7:
			if stage_frames < 30:
				return false
			check(game.level.outdoor, "out in the open")
			check(not ds.can_play(), "no dungeon sounds under the open sky")
			check(_players(game.level).is_empty(), "nothing plays under the open sky")
			_finish()
			return true
	return false
