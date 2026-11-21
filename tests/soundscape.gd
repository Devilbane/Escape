extends SceneTree
## Headless test for the ambient soundscapes (scripts/soundscape.gd): every loop
## has its file, every map in levels/ gets a loop or none, the open ground mixes
## by place, hour and rain.
## Run with: godot --headless -s tests/soundscape.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	for sound: String in Soundscape.LOOPS:
		check(ResourceLoader.exists(Sfx.DIR + sound + ".ogg"), "the loop %s has its file" % sound)
	for loop in ["amb_mine_0", "amb_cave_1", "amb_dungeon_2"]:
		check(Soundscape.LOOPS.has(loop), "%s is a listed loop" % loop)
	var named := [
		["kupfer", "rock", false, "", "x", "amb_mine_"],
		["glut", "obsidian", false, "", "x", "amb_fire_glow"],
		["", "", false, "", "die_zelle", "amb_dungeon_"],
		["", "", false, "", "das_spinnenloch", "amb_cave_"],
		["", "bone", false, "", "x", "amb_cave_"],
		["sternhof", "", true, "stern1", "der_ruinenhof", "amb_cave_"],
	]
	for n in named:
		var loop := Soundscape.dungeon_loop(n[0], n[1], n[2], n[3], n[4])
		check(loop.begins_with(n[5]), "%s sounds like %s (got %s)" % [n[4], n[5], loop])
		check(Soundscape.LOOPS.has(loop), "%s is a listed loop" % loop)
	check(Soundscape.dungeon_loop("", "", false, "haus", "x") == "", "a house has no loop of its own")
	check(Soundscape.LOOPS.has("amb_fire_camp") and Soundscape.HOME_FIRE > 0.0 and Soundscape.HOME_FIRE < 1.0, "the home hearth fire is a quiet listed loop")
	var day := Soundscape.outdoor_mix(true, false, {}, 0.0)
	check(day.has("amb_village_day") and not day.has("village_night"), "the village by day")
	var night := Soundscape.outdoor_mix(true, true, {}, 0.0)
	check(night.has("village_night") and not night.has("amb_village_day"), "the village by night")
	var woods := Soundscape.outdoor_mix(false, false, {}, 0.0)
	check(woods.has("amb_forest_day"), "the woods by day")
	var storm := Soundscape.outdoor_mix(false, false, {}, 1.0)
	check(storm.get("rain_heavy", 0.0) > 0.9 and storm.get("rain_light", 1.0) < 0.01, "a storm is heavy rain")
	var drizzle := Soundscape.outdoor_mix(false, false, {}, 0.2)
	check(drizzle.get("rain_light", 0.0) > 0.1, "a drizzle is light rain")
	for key in storm:
		check(Soundscape.LOOPS.has(key), "%s is a listed loop" % key)
	_check_cellars()
	if failures == 0:
		print("PASS: soundscape")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


## A cellar sounds like one: the built house's cellar blends in by depth, the
## outdoors stays only faintly, and the vault under the bank is a cellar too.
func _check_cellars() -> void:
	check(Soundscape.LOOPS.has(Soundscape.CELLAR), "the cellar loop is listed")
	var above := Soundscape.outdoor_mix(true, false, {}, 0.5)
	check(Soundscape.cellar_mix(above, 0.0) == above, "on the ground the outdoors is unchanged")
	var below := Soundscape.cellar_mix(above, 1.0)
	check(is_equal_approx(below[Soundscape.CELLAR], 1.0), "deep in a cellar the cellar loop plays fully")
	for sound in above:
		check(is_equal_approx(below[sound], above[sound] * Soundscape.OUTSIDE), "down there %s is only faint" % sound)
	var half := Soundscape.cellar_mix(above, 0.5)
	check(half[Soundscape.CELLAR] > 0.4 and half[Soundscape.CELLAR] < 0.6, "halfway down the stairs the two blend")

	var house := HouseSketch.new()
	house.plot = Rect2i(10, 10, 4, 4)
	for c in [Vector2i(2, 2), Vector2i(3, 2)]:
		house.pieces[HouseSketch.key_of(c.x, c.y, HouseSketch.CELL_ORIENT, HouseSketch.CELLAR_STOREY)] = {"kind": HouseSketch.DIG, "state": HouseSketch.BUILT}
	var floors := HouseFloors.new([house])
	var deep := house.cell_world(2, 2) - Vector3(0, HouseSketch.DEPTH, 0)
	check(is_equal_approx(Soundscape.cellar_depth(floors, deep), 1.0), "the floor of a dug cellar is deep in the cellar")
	check(Soundscape.cellar_depth(floors, house.cell_world(0, 0)) == 0.0, "the ground beside it is not")
	check(Soundscape.cellar_depth(null, deep) == 0.0, "no houses, no cellar")

	check(Soundscape.cellar_floor("b", false, "cellar"), "the bank's vault is a cellar")
	check(not Soundscape.cellar_floor("b", true, "cellar"), "a lair below a door is no cellar")
	check(not Soundscape.cellar_floor("b", false, "upstairs"), "an upper floor is no cellar")
