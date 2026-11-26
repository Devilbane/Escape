extends SceneTree
## Headless test of the safety coffin and its bell (see BellGrave): the grave is inscribed and stands in the
## graveyard, apart from the other special graves; the bell rings only at night, only once a night and only when the
## hero comes near the middle of the graveyard; reaching the grave within WINDOW seconds of the ring brings the scream
## and solves the riddle, coming later brings only a whimper and counts for nothing; the next night it can be tried
## again. The ring is heard from across the graveyard.
## Run with: godot --headless -s tests/bell_grave.gd

var failures := 0
var game: Node
var frames := 0
var told: Array[String] = []
var solved: Array[String] = []


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	_test()
	if Homes.house_of(game.hero_name) > 0:
		Homes.release(Homes.house_of(game.hero_name))
	game.delete_save(game.save_path())
	print("PASS: bell grave" if failures == 0 else "FAILED: " + str(failures))
	quit(1 if failures > 0 else 0)
	return true


## Lets `seconds` pass with the hero at `at` at the given hour.
func _run(bell: BellGrave, at: Vector3, hour: float, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		bell.tick(0.1, at, hour)
		t += 0.1


func _test() -> void:
	game.hero_name = "Bell grave test"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	var lvl: Outdoor = game.level
	game.graveyard_riddles.clear()
	var pair := BellGrave.graves_of(lvl.level_name)
	check(not pair.is_empty(), "the valley has the safety coffin")
	var others := [OwlClock.grave_cell(), RiddleCount.grave_of(lvl.level_name)]
	var spirit := GraveSpirit.graves_of(lvl.level_name)
	others.append_array([spirit.archy, spirit.unknown])
	check(not pair.grave in others, "it is none of the other special graves")
	var stones := lvl.stations.filter(func(s): return s.kind == GraveLore.KIND and s.cell == pair.grave)
	check(stones.size() == 1 and stones[0].name != "" and Lang.EN.has(stones[0].text), "the grave is inscribed (and has its English)")
	var bell: BellGrave = lvl.bell_grave
	check(bell != null and bell.get_child_count() > 8, "the map has the post and the bell")
	if bell == null:
		return
	Events.bus().graveyard_riddle.connect(func(id: String): solved.append(id))
	Events.bus().news_told.connect(func(text: String, _c: Color, _d: float): told.append(text))
	var grave := lvl.cell_to_world(pair.grave)
	var centre := lvl.cell_to_world(pair.centre)
	var far := centre + Vector3(0, 0, 60)
	var at_centre := centre + Vector3(0, 0, 4)
	# By day nothing rings, whoever comes.
	_run(bell, at_centre, 12.0, 2.0)
	check(not bell.rang(), "no ring by day")
	# At night, far from the middle of the graveyard nothing rings either.
	_run(bell, far, 23.0, 2.0)
	check(not bell.rang(), "no ring while the hero is far")
	# Near the middle it rings, once.
	_run(bell, at_centre, 23.0, 0.2)
	check(bell.rang(), "at night near the middle the bell rings")
	var first := bell.since_ring()
	_run(bell, far, 23.0, 1.0)
	_run(bell, at_centre, 23.0, 1.0)
	check(bell.since_ring() > first, "and it keeps counting from that ring, not ringing again")
	# In time: the scream, the riddle.
	_run(bell, grave, 23.0, 0.1)
	check(solved == [GraveyardRiddles.BELL], "reaching the grave in time solves the riddle")
	check(told.has(Lang.t(BellGrave.SCREAM)), "with the scream")
	# Not twice the same night.
	solved.clear()
	_run(bell, grave, 23.0, 3.0)
	check(solved.is_empty(), "once a night")
	# The next night: too late is only a whimper.
	_run(bell, at_centre, 12.0, 1.0)
	check(not bell.rang(), "the bell rests by day")
	told.clear()
	solved.clear()
	_run(bell, at_centre, 22.0, 0.2)
	check(bell.rang(), "it rings again the next night")
	_run(bell, far, 22.0, BellGrave.WINDOW + 1.0)
	_run(bell, grave, 22.0, 0.3)
	check(solved.is_empty() and not told.has(Lang.t(BellGrave.SCREAM)), "too late is no scream and no riddle")
	check(told.has(Lang.t(BellGrave.WHIMPER)), "only a whimper")
	# Just inside the window still counts.
	_run(bell, at_centre, 12.0, 1.0)
	told.clear()
	_run(bell, at_centre, 2.0, 0.2)
	_run(bell, far, 2.0, BellGrave.WINDOW - 1.0)
	_run(bell, grave, 2.0, 0.1)
	check(solved == [GraveyardRiddles.BELL], "just in time still counts (and past midnight is night too)")
	# It can be heard from across the graveyard.
	check(BellGrave.RING_DB > 0.0 and BellGrave.TRIGGER >= 5.0, "the ring is loud")
	for s in ["bell_tiny", "grave_scream", "grave_whimper"]:
		check(ResourceLoader.exists("res://assets/sounds/" + s + ".wav"), s + " exists")
	# It can be reached in time: from the edge of the trigger, walking at the hero's speed.
	var walk := Vector2(centre.x - grave.x, centre.z - grave.z).length() + BellGrave.TRIGGER - BellGrave.REACH
	check(walk / Player.SPEED < BellGrave.WINDOW - 0.8, "the grave can be reached in time from anywhere the bell rings (%.1f s)" % (walk / Player.SPEED))
