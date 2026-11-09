extends SceneTree
## Headless test for the bookshelf in the ground floor of every town house (see Bookshelf and
## HomeStores.BOOKS): it stands in the house from the start, is a station the hero can reach, keeps
## every book the hero puts on it (and nothing else), shows one book per book kept up to its
## capacity with the count on its plaque, is kept in the saved game and comes back on the
## shelf when the house is entered again.
## Run with: godot --headless --fixed-fps 60 -s tests/bookshelf.gd

const HERO := "Bookshelf test"

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
	game.delete_save(game.save_path())
	if Homes.house_of(HERO) > 0:
		Homes.release(Homes.house_of(HERO))
	if failures == 0:
		print("PASS: bookshelf")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


## The books standing on the shelf of the level.
func _standing(lvl: Level) -> int:
	var node := lvl.get_node_or_null(Bookshelf.NODE + "/" + Bookshelf.BOOKS_NODE)
	if node == null:
		return -1
	return node.get_children().filter(func(b): return not b.is_queued_for_deletion()).size()


func _plaque(lvl: Level) -> String:
	var label := lvl.get_node_or_null(Bookshelf.NODE + "/" + Bookshelf.PLAQUE_NODE) as Label3D
	return label.text if label != null else ""


func _run() -> void:
	var p: Player = game.player
	game.hero_name = HERO
	game.escaped = true
	game.home_stores = HomeStores.empty()
	if Homes.house_of(HERO) > 0:
		Homes.release(Homes.house_of(HERO))
	var house := 1
	while Homes.owner_of(house) != "":
		house += 1
	check(Homes.claim(HERO, house), "the hero moves into a town house")
	game.inside_house = house
	game.load_level(game.interiors["^"], false)
	var lvl: Level = game.level
	check(lvl.is_home, "the hero is in their town house")

	# The shelf is in the house from the start, on the ground floor, with floor beside it.
	var shelf: Array = lvl.stations.filter(func(s): return s.kind == Bookshelf.KIND)
	check(shelf.size() == 1, "every house has one bookshelf")
	if shelf.size() == 1:
		var s: Dictionary = shelf[0]
		check(lvl.storey_of(s.cell) == 0, "it stands on the ground floor")
		check(lvl.cell_char(s.cell + Vector2i(0, -1)) == "#", "its back is on the north wall")
		var west: Vector2i = s.cell + Vector2i(-1, 0)
		check(lvl._wall_torches.any(func(t): return t.cell == west), "a torch hangs one tile west of it")
		check(not lvl._wall_torches.any(func(t): return t.cell == s.cell), "none hangs behind it")
		var reachable := false
		for d in Level.DIRS:
			if ".P".contains(lvl.cell_char(s.cell + d)):
				reachable = true
		check(reachable, "it has plain floor beside it to walk up to")
		check(lvl.station_at(s.pos).get("kind", "") == Bookshelf.KIND, "running into it finds it")
		check(lvl.nearest_station(s.pos).get("kind", "") == Bookshelf.KIND, "the hint names it, not a neighbour")
	check(lvl.find_child(Bookshelf.NODE, false, false) != null, "it is built as furniture")
	check(_standing(lvl) == 0 and _plaque(lvl) == Bookshelf.plaque_text(0), "an empty shelf shows no books and reads 0")

	# What goes on it: every book, nothing else.
	var books := []
	for id in Items.ALL:
		if Items.is_book(id):
			books.append(id)
			check(HomeStores.store_of(id) == HomeStores.BOOKS, "the book %s goes on the shelf" % id)
		elif HomeStores.store_of(id) == HomeStores.BOOKS:
			check(false, "%s is no book and must not go on the shelf" % id)
	check(books.size() >= 6, "there are books to store (%d)" % books.size())
	check(HomeStores.STATIONS[HomeStores.BOOKS] == Bookshelf.KIND, "the store has the shelf's station kind")

	# Storing and taking through the window moves books and changes the shelf.
	p.bag.clear()
	for i in 3:
		p.bag.append("fechtbuch")
	p.bag.append("axtbuch")
	p.bag.append("schwert")
	var menus: Menus = game.menus
	menus.open(Bookshelf.KIND)
	check(menus.current == Bookshelf.KIND and Menus.fixed_size(Bookshelf.KIND) != Vector2.ZERO, "the window opens with a fixed size")
	check(HomeStores.shown(game, HomeStores.BOOKS) == ["fechtbuch", "axtbuch"], "the window lists the books the hero carries: %s" % [HomeStores.shown(game, HomeStores.BOOKS)])
	menus._store_move("fechtbuch", 1, true)
	check(_standing(lvl) == 1 and _plaque(lvl) == Bookshelf.plaque_text(1), "one book kept, one on the shelf")
	menus._store_all(HomeStores.BOOKS, true)
	check(p.bag == ["schwert"], "store everything takes all books and only books out of the bag: %s" % [p.bag])
	check(HomeStores.stored(game, "fechtbuch") == 3 and HomeStores.stored(game, "axtbuch") == 1, "all four are kept")
	check(_standing(lvl) == 4 and _plaque(lvl) == Bookshelf.plaque_text(4), "four books stand on the shelf and the plaque reads 4")
	check(game.away_choices().study.has("axtbuch"), "books on the shelf can still be studied while away")
	menus._store_move("fechtbuch", 2, false)
	check(p.bag.count("fechtbuch") == 2 and _standing(lvl) == 2, "taking two back leaves two books on the shelf")
	menus._store_all(HomeStores.BOOKS, false)
	check(_standing(lvl) == 0 and _plaque(lvl) == Bookshelf.plaque_text(0), "an emptied shelf is bare again")
	menus.close()

	# The shelf shows at most its capacity, the plaque counts on.
	check(Bookshelf.shown(0) == 0 and Bookshelf.shown(5) == 5 and Bookshelf.shown(Bookshelf.CAPACITY + 30) == Bookshelf.CAPACITY, "the number of books shown is capped")
	game.home_stores[HomeStores.BOOKS] = {"fechtbuch": Bookshelf.CAPACITY, "axtbuch": 30}
	game.refresh_bookshelf()
	check(_standing(lvl) == Bookshelf.CAPACITY, "a full shelf shows %d books" % Bookshelf.CAPACITY)
	check(_plaque(lvl) == Bookshelf.plaque_text(Bookshelf.CAPACITY + 30), "and its plaque counts them all")

	# Kept in the saved game, and on the shelf when the house is entered again.
	check(game.save_game(), "the game saves")
	game.home_stores = HomeStores.empty()
	game._apply_save(game._read_save())
	check(HomeStores.total(game.home_stores, HomeStores.BOOKS) == Bookshelf.CAPACITY + 30, "the books come back from the save")
	game.home_stores[HomeStores.BOOKS] = {"fechtbuch": 6}
	game.inside_house = house
	game.load_level(game.interiors["^"], false)
	check(_standing(game.level) == 6 and _plaque(game.level) == Bookshelf.plaque_text(6), "entering the house puts the stored books on the shelf")
	var odd := HomeStores.load_from({"buecher": {"fechtbuch": 2, "schwert": 3, "nichts": 1, "axtbuch": -1}})
	check(odd.buecher == {"fechtbuch": 2}, "a saved shelf keeps only books")
	check(HomeStores.load_from(null) == HomeStores.empty() and HomeStores.empty().has(HomeStores.BOOKS), "an old save starts with an empty shelf")

	# Every text has its English.
	for text in [HomeStores.BOOKS_LEARN, "Bücherregal", "Bücher: %d", "Dagegenlaufen, um Bücher ins Regal zu stellen oder zu nehmen",
			"Alle Bücher, die du nicht bei dir trägst. Im Regal stehen: %d. Es fasst beliebig viel.",
			"Noch kein Buch bei dir oder hier. Bücher aus deiner Tasche kommen hier hinein, sobald du welche hast."]:
		check(Lang.EN.has(text), "English for: " + text)
	_finish()
