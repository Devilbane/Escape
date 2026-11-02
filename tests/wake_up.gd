extends SceneTree
## Headless test for waking up after a night in bed: a game saved in the
## refuge's bed starts with the hero lying asleep on the mattress and the fox
## curled up in its basket. The hero then opens their eyes, the fox wakes
## and hops out of its basket, the hero gets up and hops down beside the
## bed, and only then can they move and does the welcome-back window open.
## A game saved any other way starts on the feet at once.
## Run with: godot --headless --fixed-fps 60 -s tests/wake_up.gd

var failures := 0
var game: Node
var frames := 0
var stage := 0
var clock := 0.0
var bed: Dictionary = {}
var basket := Vector3.ZERO
var fox_woke := false
var eyes_opened := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(3)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _finish() -> void:
	game.delete_save(game.save_path(game.hero_name))
	if failures == 0:
		print("PASS: wake up")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _asleep() -> bool:
	var lids = game.player._eyelids
	return lids != null and lids.visible


func _process(delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	clock += delta
	match stage:
		0:
			game.hero_name = "Wake test"
			game.escaped = false
			game.companions = [Companions.make("fuchs", "Rufus")]
			game.following = 0
			game.trust = {"fuchs": Pet.TRUST_NEEDED}
			var refuge := -1
			for i in game.level_files.size():
				if "zuflucht" in game.level_files[i]:
					refuge = i
			game.load_level(refuge, false)
			game.state = game.State.PLAYING
			# A night in bed, then the game is loaded again.
			check(Lang.EN.has("Gähn!"), "the yawn has an English text")
			check(game.save_game(true), "the game is saved in bed")
			var data: Dictionary = game._read_save()
			check(game.saved_in_bed(data), "the save knows it was made in bed")
			game._apply_save(data)
			game._after_load(data)
			game._start_playing()
			bed = game._nearest_bed()
			basket = game.level.fox_bed_near(bed.pos)
			check(game._waking and game.state == game.State.TRANSITION, "the hero is still in bed after loading")
			check(game.player.frozen, "the hero cannot walk off while in bed")
			check(game.player.global_position.y > 0.5 and _flat(game.player.global_position, bed.pos) < 2.0, "the hero lies on the mattress")
			check(_asleep(), "the hero's eyes are closed")
			check(game.pet != null and game.pet.is_asleep(), "the fox is asleep")
			check(game.pet != null and _flat(game.pet.global_position, basket) < 0.3, "the fox sleeps in its basket")
			check(game.menus.current != "rueckkehr", "the welcome-back window waits until the hero is up")
			clock = 0.0
			stage = 1
		1:
			if clock < 1.0:
				return false
			check(_asleep() and game.player.global_position.y > 0.5, "the hero sleeps on while the night fades")
			check(game.pet.is_asleep(), "the fox sleeps on while the night fades")
			stage = 2
		2:
			eyes_opened = eyes_opened or not _asleep()
			fox_woke = fox_woke or game.pet.state == "wake"
			if game._waking and clock < 12.0:
				return false
			check(not game._waking, "the hero gets out of bed")
			check(eyes_opened, "the hero opens their eyes")
			check(fox_woke, "the fox wakes up")
			var p: Vector3 = game.player.global_position
			check(p.y < 0.2, "the hero stands on the floor (%.2f m)" % p.y)
			var cell: Vector2i = game.level.world_to_cell(p)
			check(game.level._walkable(cell) and not game.level.astar.is_point_solid(cell), "the hero stands on open floor beside the bed")
			check(game.state == game.State.PLAYING, "the game goes on once the hero is up")
			check(game.menus.current == "rueckkehr", "the welcome-back window opens once the hero is up")
			clock = 0.0
			stage = 3
		3:
			if clock < 1.0:
				return false
			check(game.pet.state != "bed" and game.pet.state != "wake", "the fox follows the hero again")
			check(game.pet.global_position.y < 0.05, "the fox hopped out of its basket (%.2f m)" % game.pet.global_position.y)
			check(_flat(game.pet.global_position, basket) > Pet.BASKET_RADIUS, "the fox is out of its basket")
			game.menus.close()
			check(not game.player.frozen, "the hero can move again once the window is closed")
			# A game saved without going to bed starts on the feet at once.
			check(game.save_game(), "the game is saved without the bed")
			var data: Dictionary = game._read_save()
			check(not game.saved_in_bed(data), "an ordinary save was not made in bed")
			game._apply_save(data)
			game._after_load(data)
			game._start_playing()
			check(not game._waking and not game.player.frozen and game.state == game.State.PLAYING, "an ordinary load starts on the feet")
			check(game.player.global_position.y < 0.2 and not _asleep(), "an ordinary load does not lie in bed")
			_finish()
			return true
	return false
