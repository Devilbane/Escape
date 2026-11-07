extends SceneTree
## Headless test for the cape wardrobe on the first floor of the hero's house (see CapeWardrobe,
## CapeDesigns): every house has one from the start, on the first floor and out of the way of the
## stairs, the bed, the chest and the other furniture; its window shows the three designs and
## keeps its size when one is picked; the cape's back shows the design picked (the devilbane logo,
## the name "Sbinortz" with a crown, or nothing); the choice is kept in the saved game; and a game
## saved before the wardrobe wears the logo.
## Run with: godot --headless --fixed-fps 60 -s tests/cape_wardrobe.gd

const HERO := "Cape wardrobe test"

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
		print("PASS: cape wardrobe")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _logo(p: Player) -> MeshInstance3D:
	return p.find_child("CapeLogo", true, false) as MeshInstance3D


func _picture(p: Player) -> Texture2D:
	return (_logo(p).mesh.material as StandardMaterial3D).albedo_texture


## The tiles of one storey the hero can walk to from `from`, without crossing furniture or walls.
func _reach(lvl: Level, from: Vector2i, storey: int) -> Dictionary:
	var seen := {from: true}
	var todo := [from]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d in Level.DIRS:
			var n: Vector2i = c + d
			if seen.has(n) or lvl.cell_char(n) == "" or Level.SOLID.contains(lvl.cell_char(n)) or lvl.storey_of(n) != storey:
				continue
			seen[n] = true
			todo.append(n)
	return seen


func _run() -> void:
	var p: Player = game.player
	game.hero_name = HERO
	game.escaped = true
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

	# The wardrobe is there without buying anything, on the first floor.
	check(game.home_upgrades.is_empty(), "no upgrade is built")
	var wardrobes: Array = lvl.stations.filter(func(s): return s.kind == CapeWardrobe.KIND)
	check(wardrobes.size() == 1, "every house has one cape wardrobe from the start")
	if wardrobes.size() == 1:
		var w: Dictionary = wardrobes[0]
		check(lvl.storey_of(w.cell) == 1, "it stands on the first floor (storey %d)" % lvl.storey_of(w.cell))
		check(lvl.get_node_or_null("CapeWardrobe") != null, "it is built")
		# Nothing it should leave free is blocked: the stairs, the bed and the chest of the floor
		# stay reachable from one another.
		var bed: Dictionary = lvl.stations.filter(func(s): return s.kind == "bett")[0]
		var up: Array = lvl.stairs.filter(func(s): return s.storey == 1)
		check(up.size() == 2, "the first floor has its two stairs")
		var open := _reach(lvl, lvl.world_to_cell(lvl.bed_side), 1)
		for s in up:
			check(open.has(s.cell), "the stairs at %s stay reachable from the bed" % s.cell)
		var reachable := false
		for d in Level.DIRS:
			reachable = reachable or open.has(w.cell + d)
		check(reachable, "the wardrobe can be walked up to")
		check(lvl.storey_of(bed.cell) == 1 and bed.cell != w.cell, "it is not on the bed's tile")
		# It stands right beside the bed, along the same wall.
		var gap: Vector2i = w.cell - bed.cell
		check(absi(gap.x) + absi(gap.y) == 1, "it stands directly next to the bed (gap %s)" % gap)
		check(gap.x == 0 and lvl.cell_char(bed.cell + Vector2i(-1, 0)) == "#", "it shares the bed's wall")
		var next_to_stairs := false
		for s in up:
			next_to_stairs = next_to_stairs or s.cell == w.cell
		check(not next_to_stairs, "it is not on a stairs tile")
		for other in lvl.stations:
			check(other.cell != w.cell or other == w, "no other station shares its tile (%s)" % other.kind)

	# The hero starts with the devilbane logo.
	check(p.cape_design == CapeDesigns.DEFAULT and CapeDesigns.DEFAULT == 0, "the first design is the default")
	check(_logo(p).visible and _picture(p) == CapeDesigns.texture(0), "the cape shows the devilbane logo")
	check(CapeDesigns.DESIGNS.size() == 3, "there are three designs")
	check(CapeDesigns.texture(1) != null and CapeDesigns.texture(1) != CapeDesigns.texture(0), "the second design has a picture of its own")
	check(CapeDesigns.texture(2) == null, "the third design is blank")
	check(CapeDesigns.checked(7) == 0 and CapeDesigns.checked(-1) == 0 and CapeDesigns.checked("x") == 0, "a nonsense design falls back to the first")

	# The window: three cards, one size, whatever is worn.
	var menus: Menus = game.menus
	var texts := {}
	for lang in ["de", "en"]:
		Lang.language = lang
		Lang._apply()
		menus.open("umhangschrank")
		await process_frame
		await process_frame
		check(Menus.fixed_size("umhangschrank") != Vector2.ZERO, "the window has a fixed size")
		var before := menus._panel.get_global_rect()
		var cards: Array = menus._box.find_children("*", "PanelContainer", true, false).filter(func(n): return n.custom_minimum_size == Menus.CAPE_CARD)
		check(cards.size() == 3, "%s: the window shows three designs" % lang)
		for design in [1, 2, 0]:
			menus._wear_cape(design)
			await process_frame
			await process_frame
			check(p.cape_design == design, "%s: wearing design %d" % [lang, design])
			check(menus._panel.get_global_rect() == before, "%s: picking design %d does not move or resize the window" % [lang, design])
			var buttons: Array = menus._box.find_children("*", "Button", true, false).filter(func(b): return b.disabled)
			check(buttons.size() == 1, "%s: only the worn design's button is dimmed" % lang)
		menus.close()
	Lang.language = "de"
	Lang._apply()

	# The cape's back follows the choice.
	p.set_cape_design(1)
	check(_logo(p).visible and _picture(p) == CapeDesigns.texture(1), "design 2 shows the name and the crown")
	p.set_cape_design(2)
	check(not _logo(p).visible, "design 3 shows nothing")
	p.set_cape_design(0)
	check(_logo(p).visible and _picture(p) == CapeDesigns.texture(0), "design 1 shows the logo again")

	# Kept in the saved game; older saves wear the logo.
	p.set_cape_design(1)
	check(game.save_game(), "the game saves")
	p.set_cape_design(0)
	game._apply_save(game._read_save())
	check(p.cape_design == 1 and _picture(p) == CapeDesigns.texture(1), "the choice comes back from the saved game")
	var old: Dictionary = game._read_save()
	old.erase("cape")
	p.set_cape_design(2)
	game._apply_save(old)
	check(p.cape_design == 0 and _logo(p).visible, "a game saved before the wardrobe wears the devilbane logo")

	_finish()
