extends SceneTree
## Headless test for the town houses of Weavers' Lane: a row of narrow
## three-storey houses north of the village, one home for every hero (see
## Homes). Each house has its own number and door; a hero without a house
## moves into the first empty one, the others' doors stay shut. Inside, the
## home has three storeys linked by stairs: the chest on the ground floor,
## the bed upstairs, and chalked spots for furniture on every storey. The
## hero walks up and down the stairs and out of the front door, back to the
## door of their own house.
## Run with: godot --headless --fixed-fps 60 -s tests/player_houses.gd

const HERO := "House test A"
const NEIGHBOUR := "House test B"

var failures := 0
var game: Node
var frames := 0
var stage := 0
var stage_frames := 0
## Empty houses picked at the start (other tests may have moved heroes in):
## the hero's, the neighbour's and one more.
var mine := 0
var other := 0
var third := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(5)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _finish() -> void:
	for n in [mine, other]:
		if n > 0 and Homes.owner_of(n) in [HERO, NEIGHBOUR]:
			Homes.release(n)
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: player houses")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _bounds(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	stage_frames += 1
	match stage:
		0:
			_check_lane()
		1:
			# Walked in at the door of the hero's house.
			if stage_frames < 70:
				return false
			_check_inside()
		2:
			# Up the stairs to the upper floor.
			if stage_frames < 90:
				return false
			var lvl: Level = game.level
			var cell: Vector2i = lvl.world_to_cell(game.player.global_position)
			check(lvl.storey_of(cell) == 1, "the stairs up lead to the upper floor (storey %d)" % lvl.storey_of(cell))
			check(not "<>".contains(lvl.cell_char(cell)), "the hero arrives beside the stairs, not on them")
			check(game.state == game.State.PLAYING, "the hero can walk on after the stairs")
			var up: Dictionary = lvl.stairs.filter(func(s): return s.up and s.storey == 1)[0]
			game.player.global_position = lvl.cell_to_world(up.cell)
			_next()
		3:
			if stage_frames < 90:
				return false
			var lvl: Level = game.level
			check(lvl.storey_of(lvl.world_to_cell(game.player.global_position)) == 2, "the upper stairs lead to the attic")
			var down: Dictionary = lvl.stairs.filter(func(s): return not s.up and s.storey == 2)[0]
			game.player.global_position = lvl.cell_to_world(down.cell)
			_next()
		4:
			if stage_frames < 90:
				return false
			var lvl: Level = game.level
			check(lvl.storey_of(lvl.world_to_cell(game.player.global_position)) == 1, "the stairs down lead back to the upper floor")
			# Out of the front door on the ground floor.
			game.player.global_position = lvl.cell_to_world(lvl.exit_cell)
			_next()
		5:
			if stage_frames < 120:
				return false
			check(game.level is Outdoor, "the front door leads out into the village")
			if game.level is Outdoor:
				var door: Vector3 = game.level.doors["^" + str(mine)]
				var p: Vector3 = game.player.global_position
				check(Vector2(p.x - door.x, p.z - door.z).length() < 1.5, "the hero steps out in front of their own house")
			check(game.inside_house == 0, "out in the lane, the hero is in no house")
			_finish()
	return false


func _next() -> void:
	stage += 1
	stage_frames = 0


func _check_lane() -> void:
	Homes.reload()
	for n in range(1, 30):
		if Homes.owner_of(n) in [HERO, NEIGHBOUR]:
			Homes.release(n)
	game.hero_name = HERO
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	var lvl: Outdoor = game.level
	check(game.interiors.has("^"), "the town houses have a building floor (\"building: ^\")")
	var houses: Array[Node3D] = lvl.town_houses
	check(houses.size() >= 12, "Weavers' Lane has room for many heroes (%d houses)" % houses.size())
	var doors := lvl.stations.filter(func(s): return s.kind == "eingang" and s.building == "^")
	check(doors.size() == houses.size(), "every town house has a door to run into")
	var numbers := {}
	for house in houses:
		var number: int = house.get_meta("town_house")
		numbers[number] = true
		check(lvl.doors.has("^" + str(number)), "house %d has a spot in front of its door" % number)
		var box := _bounds(house)
		check(box.size.x < Level.TILE + 0.5, "house %d is narrow (%.1f m wide)" % [number, box.size.x])
		check(box.size.y > 9.0 and box.size.y < 16.0, "house %d has three storeys and a roof (%.1f m high)" % [number, box.size.y])
		var plate: Label3D = house.find_child("Number", true, false)
		check(plate != null and plate.text == str(number), "house %d shows its number over the door" % number)
		check(lvl.astar.is_point_solid(lvl.world_to_cell(house.position)), "house %d is solid" % number)
		var way: Array = lvl.astar.get_id_path(lvl.world_to_cell(lvl.doors["^1"]), lvl.world_to_cell(lvl.doors["^" + str(number)]))
		check(not way.is_empty(), "the lane leads from door to door (house %d)" % number)
	check(numbers.size() == houses.size(), "every town house has its own number")
	var square: Array = lvl.astar.get_id_path(lvl.world_to_cell(lvl.doors["^1"]), lvl.world_to_cell(lvl.doors["s"]))
	check(not square.is_empty(), "a way leads from the lane to the square")

	# Ownership: a neighbour moves into one empty house, the hero into another.
	var free: Array = range(1, houses.size() + 1).filter(func(n): return Homes.owner_of(n) == "")
	check(free.size() >= 3, "most town houses stand empty")
	if free.size() < 3:
		_finish()
		return
	mine = free[0]
	other = free[1]
	third = free[2]
	check(Homes.claim(NEIGHBOUR, other), "a hero can move into an empty house")
	check(not Homes.claim(HERO, other), "a taken house cannot be claimed")
	check(not game._may_enter_house(other), "the neighbour's door stays shut")
	check(game._may_enter_house(mine), "a hero without a house moves into an empty one")
	check(Homes.house_of(HERO) == mine, "the house belongs to the hero now")
	check(not game._may_enter_house(third), "a hero with a house cannot take a second one")
	Homes.reload()
	check(Homes.owner_of(mine) == HERO and Homes.owner_of(other) == NEIGHBOUR, "the deeds are kept on disk")
	Homes.release(other)

	game.player.global_position = lvl.doors["^" + str(mine)]
	game.go_inside("^", mine)
	_next()


func _check_inside() -> void:
	var lvl: Level = game.level
	check(lvl.building == "^" and lvl.is_home, "the door led into the hero's home")
	check(lvl.house_number == mine, "the home knows which house it is")
	check(lvl.safe and lvl.enemies.is_empty(), "a home is a safe place")
	check(lvl.storey_count() == 3, "the home has three storeys (%d)" % lvl.storey_count())
	var beds := lvl.stations.filter(func(s): return s.kind == "bett")
	var chests := lvl.stations.filter(func(s): return s.kind == "lager")
	check(beds.size() == 1 and chests.size() == 1, "a home has a bed and a chest")
	if beds.size() == 1:
		check(lvl.storey_of(beds[0].cell) == 1, "the bed stands upstairs")
	if chests.size() == 1:
		check(lvl.storey_of(chests[0].cell) == 0, "the chest stands on the ground floor")
	check(lvl.bed_side != Vector3.ZERO, "there is a spot beside the bed to wake up on")
	for storey in 3:
		var slots := lvl.furniture_slots.filter(func(s): return s.storey == storey)
		check(slots.size() >= 2, "storey %d keeps room for furniture (%d spots)" % [storey, slots.size()])
		for slot in slots:
			check(not lvl.astar.is_point_solid(slot.cell), "a furniture spot is free floor")
	# Every storey can be reached from the door, by way of the stairs.
	var reach: Dictionary = lvl._reachable()
	for c in lvl._storeys:
		if lvl._walkable(c):
			check(reach.has(c), "tile %s of the home can be reached" % c)
	for s in lvl.stairs:
		var to: Vector2i = lvl.stair_target(s.cell)
		check(to.x >= 0 and lvl.storey_of(to) == s.storey + (1 if s.up else -1), "the stairs on %s lead one storey %s" % [s.cell, "up" if s.up else "down"])
	var p: Vector3 = game.player.global_position
	check(lvl.storey_of(lvl.world_to_cell(p)) == 0, "the hero comes in on the ground floor")
	var up: Dictionary = lvl.stairs.filter(func(s): return s.up and s.storey == 0)[0]
	game.player.global_position = lvl.cell_to_world(up.cell)
	_next()
