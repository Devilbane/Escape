extends SceneTree
## Headless test: a hero felled in the open air is carried off by the eagle,
## but the pack (backpack, bag, pouch) stays where they fell, can be fetched
## again after the rescue, and is marked on the map of that place.
## Run with: godot --headless --fixed-fps 60 -s tests/rescue_eagle.gd

const HERO := "Eagle rescue test"

var failures := 0
var game: Node
var frames := 0
var stage := 0
var clock := 0.0
var outdoor_file := ""
var fell_at := Vector3.ZERO


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
	print("PASS: rescue_eagle" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _put_hero(p: Vector3) -> void:
	var player: Player = game.player
	player.global_position = Vector3(p.x, 0.0, p.z)
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()


func _bundles(list: Array) -> Array:
	return list.filter(func(e): return Rescue.is_bundle(e))


func _process(delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	clock += delta
	var player: Player = game.player
	match stage:
		0:
			game.hero_name = HERO
			game.escaped = false
			game.delete_save(game.save_path())
			game.load_level(0, false)
			game.state = game.State.PLAYING
			check(game.save_game(true), "the game is saved in bed")
			game.escaped = true
			game.load_level(game._outdoor_index(), false)
			game.state = game.State.PLAYING
			outdoor_file = game.level_files[game.level_index].get_file()
			player.bag.assign(["knochenhelm", "lederkappe"])
			player.equipped["rucksack"] = "leinenrucksack"
			game.coins = 5
			fell_at = player.global_position
			player.hp = 0
			player.dead = true
			player.defeated.emit()
			var rescue: Rescue = game.level.get_node_or_null("Rescue")
			check(rescue != null and rescue.by_eagle, "on the surface an eagle comes")
			check(_bundles(game.floors.get(outdoor_file, [])).size() == 1, "the pack lies on the floor list of the open air")
			clock = 0.0
			stage = 1
		1:
			if game.state != game.State.PLAYING and clock < Rescue.duration(true) + 15.0:
				return false
			check(game.state == game.State.PLAYING, "the hero gets up again")
			check(_bundles(game.floors.get(outdoor_file, [])).size() == 1, "the pack still lies there after the rescue (%s)" % [game.floors.get(outdoor_file, [])])
			var saved: Dictionary = game._read_save()
			check(_bundles(saved.get("floors", {}).get(outdoor_file, [])).size() == 1, "the saved game keeps the pack")
			# The map of the open air marks the pack, also seen from elsewhere.
			var view := MapView.new()
			view.setup(game.journal, outdoor_file, game.TEXT_FONT)
			var marks: Array[Vector2] = view.lost_packs()
			check(marks.size() == 1, "the pack is marked on the map (%d)" % marks.size())
			check(marks.size() == 1 and marks[0].distance_to(Vector2(fell_at.x, fell_at.z) / Level.TILE) < 0.05, "the mark sits where the hero fell")
			view.free()
			game.escaped = true
			game.load_level(game._outdoor_index(), false)
			game.state = game.State.PLAYING
			check(game.level.find_children("Bundle", "", true, false).size() == 1, "the pack is laid out again in the open air")
			_put_hero(fell_at + Vector3(6, 0, 0))
			clock = 0.0
			stage = 2
		2:
			if clock < 0.3:
				return false
			_put_hero(fell_at + Vector3(0.45, 0, 0.25))
			clock = 0.0
			stage = 3
		3:
			if clock < 0.6:
				return false
			check(player.bag.has("knochenhelm") and player.bag.has("lederkappe"), "the gear comes back (%s)" % [player.bag])
			check(player.equipped.get("rucksack", "") == "leinenrucksack", "the backpack is worn again")
			check(_bundles(game.level.floor_items).is_empty(), "the empty pack is gone")
			_finish()
			return true
	return false
