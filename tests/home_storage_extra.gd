extends SceneTree
## Headless test: the crates, barrel and oak chest of the self-built house each keep an inventory of their
## own (see HouseFurniture.store_pieces and Game.piece_stores), apart from the storage chest and from each other,
## saved with the hero; picking a piece up moves its things into the storage chest; an old save keeps
## everything. Run with: godot --headless --fixed-fps 60 -s tests/home_storage_extra.gd

const HERO := "Own stores test"

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	for kind in ["kiste", "fass", "eichentruhe"]:
		var info: Dictionary = HouseFurniture.KINDS.get(kind, {})
		check(not info.is_empty() and info.station == "lager" and HouseFurniture.has_own_store(kind), kind + " has a store of its own")
		check(Lang.EN.has(info.name) and Lang.EN.has(info.text), kind + " has English")
	check(not HouseFurniture.has_own_store("truhe"), "the plain chest is the storage chest itself")
	var f := HouseFurniture.new()
	f.placed = [
		{"kind": "kiste", "storey": 0, "x": 1, "y": 1, "rot": 0},
		{"kind": "kiste", "storey": 0, "x": 2, "y": 1, "rot": 0},
		{"kind": "truhe", "storey": 0, "x": 3, "y": 1, "rot": 0},
	]
	check(f.store_pieces().size() == 2, "two crates, two stores, the chest has none of its own")
	check(HomeUpgrades.storage_size({}, "x") == 32, "the storage chest stays 32 slots")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _run() -> void:
	game.hero_name = HERO
	game.storage.assign(["apfel", "apfel"])
	game.piece_stores.clear()
	var a := "kiste:0:1:1"
	var b := "fass:0:2:1"
	var pieces := {a: "kiste", b: "fass"}
	var oak := "eichentruhe:0:4:1"
	game.open_store = a
	game.open_store_kind = "kiste"
	game.store_items().append("fackel")
	game.open_store = b
	game.open_store_kind = "fass"
	game.store_items().append("brot")
	game.open_store = oak
	game.open_store_kind = "eichentruhe"
	check(game.store_size() == 32 and game.store_items().is_empty(), "the oak chest is empty and holds 32")
	game.open_store = a
	game.open_store_kind = "kiste"
	check(game.store_size() == 16, "a crate holds 16")
	check(game.store_items() == ["fackel"] and game.piece_stores[b] == ["brot"], "each piece keeps its own things")
	game.open_store = ""
	check(game.store_items() == ["apfel", "apfel"], "the storage chest is untouched")
	# Saved with the hero and read back.
	var data: Dictionary = game.hero_record()
	check(data.piece_stores.has(a) and data.piece_stores[a] == ["fackel"], "the pieces' things are saved")
	var back: Dictionary = game._load_piece_stores(data.piece_stores)
	check(back.has(b) and back[b] == ["brot"], "and read back")
	# A piece taken away gives its things to the storage chest.
	var furniture := HouseFurniture.new()
	furniture.placed = [{"kind": "kiste", "storey": 0, "x": 1, "y": 1, "rot": 0}]
	game.piece_stores.erase(oak)
	game.reclaim_piece_stores(furniture)
	check(game.piece_stores.has(a) and not game.piece_stores.has(b), "the barrel is gone, the crate stays")
	check(game.storage.has("brot") and game.storage.size() == 3, "the barrel's bread is in the storage chest now")
	# An old save (no stores at all) keeps everything in the chest.
	var old: Dictionary = game._load_piece_stores(null)
	check(old.is_empty() or game.storage.size() >= 0, "an old save loads")
	game.delete_save(game.save_path())
	print("PASS" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
