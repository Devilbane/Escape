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
	]
	for n in named:
		var loop := Soundscape.dungeon_loop(n[0], n[1], n[2], n[3], n[4])
		check(loop.begins_with(n[5]), "%s sounds like %s (got %s)" % [n[4], n[5], loop])
		check(Soundscape.LOOPS.has(loop), "%s is a listed loop" % loop)
	check(Soundscape.dungeon_loop("", "", false, "haus", "x") == "", "a house has no loop of its own")
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
	if failures == 0:
		print("PASS: soundscape")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
