extends SceneTree
## Headless test for the hero's cosy bed at home (see CosyBed): it stands where the plain cot
## stood (same footprint, so the same solid), its pillows lie round the spot a click uses and its
## mattress is where the hero lies; the town house has it, and its posts are turned.
## Run with: godot --headless --fixed-fps 60 -s tests/cosy_bed.gd

const HERO := "Cosy bed test"

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


func _near(a: float, b: float, by: float) -> bool:
	return absf(a - b) <= by


func _run() -> void:
	# The same footprint as the cot, from its origin.
	var space := Node3D.new()
	root.add_child(space)
	var cot: Node3D = load("res://assets/dungeon/bed_decorated.glb").instantiate()
	space.add_child(cot)
	var bed := CosyBed.build(space, Vector3.ZERO, 0.0)
	var old := Level.footprint(cot, space)
	var new := Level.footprint(bed, space)
	for axis in [0, 2]:
		check(_near(new.position[axis], old.position[axis], 0.08) and _near(new.end[axis], old.end[axis], 0.08),
				"the bed covers the cot's footprint along axis %d: %s against %s" % [axis, new, old])
	# The pillows round the spot a click uses, the mattress where the hero lies.
	var pillows := 0
	for mi: MeshInstance3D in bed.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh is SphereMesh and mi.scale.x > 0.5 and Vector2(mi.position.x - Level.PILLOW.x, mi.position.z - Level.PILLOW.z).length() < 0.5:
			pillows += 1
			check(_near(mi.position.y, Level.PILLOW.y, 0.15), "a pillow lies at the spot's height")
	check(pillows == 2, "two pillows lie round the spot a click uses (%d)" % pillows)
	check(_near(CosyBed.MATTRESS_TOP, game.BED_MATTRESS_HEIGHT, 0.05), "the hero lies on top of the mattress")
	check(bed.get_node_or_null("Bedding") != null and bed.get_node_or_null("FurThrow") != null, "it is made: bedding and a fur throw")
	space.queue_free()

	# The town house has the cosy bed, a station where it was.
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
	var beds: Array = lvl.stations.filter(func(s): return s.kind == "bett")
	check(beds.size() == 1, "the house has one bed")
	check(lvl.find_child(CosyBed.NODE, false, false) != null, "it is the cosy bed")
	if beds.size() == 1:
		check(lvl.station_at(beds[0].pos).get("kind", "") == "bett", "running into it finds it")
	game.delete_save(game.save_path())
	Homes.release(house)
	print("PASS: cosy bed" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
