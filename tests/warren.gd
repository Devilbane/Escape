extends SceneTree
## Headless test for the rabbit warren (see Warren): a burrow with a huddle of baby rabbits that stay
## near it, dive into it when the hero comes near (and are gone from the world while down there), and
## come out again once the hero has gone.
## Run with: godot --headless --fixed-fps 60 -s tests/warren.gd

var failures := 0
var game: Node
var frames := 0
var stage := 0
var stage_frames := 0
var kits: Array[Animal] = []


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(7)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _finish() -> void:
	game.delete_save(game.save_path())
	print("PASS: warren" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _hidden_count() -> int:
	return kits.filter(func(k): return k.is_hidden()).size()


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	var lvl: Outdoor = game.level if game.level is Outdoor else null
	match stage:
		0:
			game.hero_name = "Warren test"
			game.escaped = true
			game.load_level(game._outdoor_index(), false)
			game.state = game.State.PLAYING
			lvl = game.level
			for a in lvl.animals:
				if a.kind == "kit":
					kits.append(a)
			check(kits.size() == Warren.KITS, "a warren holds %d kits (%d)" % [Warren.KITS, kits.size()])
			for k in kits:
				check(k.has_burrow(), "a kit has a burrow")
				check(k.global_position.distance_to(k._burrow_at) < Warren.START_RADIUS + 0.5, "a kit starts beside the burrow")
			check(kits[0].scale.x <= 1.0 and Animal.KINDS.kit.scale < Animal.KINDS.kaninchen.scale, "kits are smaller than rabbits")
			game.player.global_position = lvl.spots.square[0]
			stage_frames = 0
			stage = 1
		1:
			# The hero is far away: nobody is down in the burrow, nobody wanders off.
			stage_frames += 1
			check(_hidden_count() == 0, "no kit hides from a far hero")
			for k in kits:
				check(k.global_position.distance_to(k._burrow_at) <= (Animal.KINDS.kit.roam + 1.5) * Level.TILE, "kits huddle near their burrow")
			if stage_frames < 300:
				return false
			game.player.global_position = kits[0]._burrow_at + Vector3(4.0, 0, 0)
			stage_frames = 0
			stage = 2
		2:
			# The hero walks up to the warren: every kit dives in and is out of the world.
			stage_frames += 1
			if _hidden_count() < kits.size() and stage_frames < 900:
				return false
			check(_hidden_count() == kits.size(), "every kit dives into the burrow (%d of %d)" % [_hidden_count(), kits.size()])
			for k in kits:
				check(not k.visible, "a kit in the burrow is not seen")
				check(not k.is_in_group(Footprint.GROUP), "a kit in the burrow takes no room")
			stage_frames = 0
			stage = 3
		3:
			# While the hero stays close they stay down.
			stage_frames += 1
			if stage_frames < 900:
				return false
			check(_hidden_count() == kits.size(), "they stay down while the hero is near")
			game.player.global_position = lvl.spots.square[0]
			stage_frames = 0
			stage = 4
		4:
			# The hero is gone: they pop out again.
			stage_frames += 1
			if _hidden_count() > 0 and stage_frames < 1500:
				return false
			check(_hidden_count() == 0, "the kits come out again when the hero has gone")
			for k in kits:
				check(k.visible and k.is_in_group(Footprint.GROUP), "a kit that came out is seen again")
			_finish()
	return false
