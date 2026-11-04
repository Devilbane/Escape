extends SceneTree
## Headless test for the moon: its phases run on the game's day counter
## (eight nights a round), the night is brighter at full moon than at new
## moon, the HUD clock names the moon at night, and the journal says what
## tonight brings. At full moon a wolf pack hunts together round the
## hollow's pond and moon flowers open there (picked, they go into the
## ingredient pouch, and they close at dawn). At new moon the holes breathe
## and a horror crawls out of the hole nearest the village, closer to it;
## at dawn it all goes back.
## Run with: godot --headless --fixed-fps 60 -s tests/moon.gd

var failures := 0
var game: Node
var frames := 0
const HERO := "Moon test"


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
	if failures == 0:
		print("PASS: moon")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	_phases()
	_texts()
	_full_moon()
	_new_moon()
	_quiet_night()
	_journal()
	_finish()
	return true


## The first night of a game whose moon is `phase`.
func _night_of(phase: int) -> int:
	for n in Moon.CYCLE:
		if Moon.phase(n) == phase:
			return n
	return -1


## Puts the hero in the open air on a night (or a day) and lets the world
## settle on it.
func _go_out(day: int, hour: float) -> void:
	game.hero_name = HERO
	game.day = day
	game.day_hour = hour
	game.set_weather(Weather.CLEAR, 6.0)
	game.load_level(game._outdoor_index(), false)
	game._tick_clock(0.0)


func _phases() -> void:
	var seen := {}
	for n in Moon.CYCLE * 3:
		seen[Moon.phase(n)] = true
		check(Moon.phase(n) == Moon.phase(n + Moon.CYCLE), "the moon comes round every %d nights" % Moon.CYCLE)
		check(Moon.phase(n + 1) == (Moon.phase(n) + 1) % Moon.CYCLE, "the moon moves on one phase a night")
	check(seen.size() == Moon.CYCLE, "every phase comes round")
	check(not Moon.is_full(0) and not Moon.is_new(0), "the first night of a game is a quiet one")
	var full := _night_of(Moon.FULL)
	var dark := _night_of(Moon.NEW)
	check(Moon.light(full) > Moon.light(dark), "the full moon is brighter than the new moon")
	check(Moon.light(dark + 1) < Moon.light(full) * 0.15, "a thin crescent is almost as dark as no moon")
	check(Moon.light(dark + 2) < Moon.light(full) * 0.5, "the half moon is only dimly lit")
	for n in Moon.CYCLE:
		check(Moon.light(n) >= Moon.DARKEST - 0.001 and Moon.light(n) <= Moon.BRIGHTEST + 0.001, "the moonlight stays within its bounds")
	check(Moon.nights_until(full, Moon.FULL) == 0, "tonight counts as zero nights to the full moon")
	check(Moon.nights_until(full + 1, Moon.FULL) == Moon.CYCLE - 1, "after the full moon the next is a round away")


func _texts() -> void:
	for word in Moon.PHASES:
		check(Lang.EN.has(word), "%s has an English name" % word)
	check(Lang.EN.has(Moon.LORE), "the moon's knowledge entry has an English text")
	var saved := Lang.language
	Lang.language = "en"
	Lang._apply()
	for n in Moon.CYCLE:
		var text := Moon.forecast(n)
		check(text != "" and not text.contains("Nacht"), "the forecast for night %d is in English: %s" % [n, text])
	Lang.language = saved
	Lang._apply()


func _full_moon() -> void:
	var full := _night_of(Moon.FULL)
	_go_out(full, 23.0)
	var out: Outdoor = game.level
	check(out.moon_night == full, "the open air knows tonight's moon")
	check(game._clock_text().contains(Lang.t("Vollmond")), "the HUD clock names the full moon at night")
	var bright: float = game._moon.light_energy
	check(out._pack.size() == Outdoor.PACK_SIZE, "a wolf pack gets its spots at full moon")
	for s in out._pack:
		var near := false
		for dy in range(-4, 5):
			for dx in range(-4, 5):
				near = near or out.cell_char(s.cell + Vector2i(dx, dy)) == Outdoor.PACK_NEAR
		check(near, "the pack gathers round the hollow's pond")
	check(out._pack.filter(func(s): return s.leader).size() == 1, "the pack has one leader")
	check(out.flowers_open() == Outdoor.FLOWERS, "the moon flowers open at full moon")
	check(not out.holes_breathe() and out.moon_horror() == null, "the holes are quiet at full moon")

	# The hero is far away: the pack comes out.
	game.player.global_position = out.cell_to_world(out.start_cell)
	for s in out._pack:
		s.timer = 0.0
	out._mind_the_moon(0.1)
	check(out.pack_alive() == Outdoor.PACK_SIZE, "the pack comes out when the hero is far away")
	var leader: Enemy = out._pack.filter(func(s): return s.leader)[0].enemy
	check(leader.elite, "the pack's leader is a strong wolf")

	# The pack hunts together: one is after the hero, and the rest follow.
	var first: Enemy = out._pack[1].enemy
	first.alert(game.player.global_position)
	out._mind_the_moon(0.1)
	for s in out._pack:
		check(s.enemy.is_hunting(), "the whole pack hunts once one of them does")

	# A flower picked goes into the pouch, and does not grow back tonight.
	var had: int = game.crafting.have(Outdoor.FLOWER)
	var flower: Dictionary = out._pickups.filter(func(p): return p.get("moon", false))[0]
	game.player.global_position = flower.node.global_position
	out._check_pickups()
	check(game.crafting.have(Outdoor.FLOWER) == had + 1, "a picked moon flower goes into the ingredient pouch")
	check(out.flowers_open() == Outdoor.FLOWERS - 1, "a picked flower is gone")
	out.set_moon(-1)
	out.set_moon(full)
	check(out.flowers_open() == Outdoor.FLOWERS - 1, "a flower picked tonight does not open again tonight")

	# Dawn: the pack goes back, the flowers close.
	game.day = full + 1
	game.day_hour = 8.0
	game._tick_clock(0.0)
	check(out.moon_night == -1, "the moon's night is over at dawn")
	check(out.flowers_open() == 0, "the moon flowers close at dawn")
	check(out._pack.is_empty(), "the pack is gone by day")
	for s in out.enemies:
		if is_instance_valid(s) and s.kind == "wolf" and s.elite:
			check(s.dead or s._dawn, "the pack's leader goes back at dawn")
	check(not game._clock_text().contains(Lang.t("Vollmond")), "by day the HUD clock names no moon")
	game.day = full
	game.day_hour = 23.0
	game._tick_clock(0.0)
	check(game._moon.light_energy > 0.0 and is_equal_approx(game._moon.light_energy, bright), "the night is lit the same each full moon")
	check(is_equal_approx(game.player._lantern.omni_range, 8.5), "under the full moon the hero's lantern reaches as far as by day")
	var c: Color = game._moon.light_color
	check(c.b > c.r + 0.3 and c.b > c.g, "the moonlight casts a bluish sheen")
	check(game._env.ambient_light_color.b > game._env.ambient_light_color.r + 0.3, "and the night air is bluish too")
	check(game._env.adjustment_saturation > 0.9, "with colour enough left for the blue to show")
	check(game.lore.has(Moon.LORE), "the moon goes into the compendium's knowledge")


func _new_moon() -> void:
	var full := _night_of(Moon.FULL)
	_go_out(full, 23.0)
	var bright: float = game._moon.light_energy
	var dark := _night_of(Moon.NEW)
	_go_out(dark, 23.0)
	var out: Outdoor = game.level
	check(game._moon.light_energy < bright, "the new moon night is darker than the full moon night")
	check(game._moon.light_energy < bright * 0.15, "a new moon night is nearly black: the moon is the night's only light")
	check(game._env.ambient_light_energy < 0.004 and game._moon.light_energy < bright * 0.03, "and the new moon leaves the night nearly pitch black")
	check(game._moon.light_energy > 0.0, "but a trace of moonlight still shows the shapes of things")
	check(game.player._lantern.omni_range < 8.5 * 0.8 and game.player._lantern.light_energy < 1.1 * 0.8, "the hero's lantern shows only a small pool on a moonless night")
	check(game._clock_text().contains(Lang.t("Neumond")), "the HUD clock names the new moon")
	check(out.holes_breathe(), "the holes breathe at new moon")
	check(out._breaths.size() == out.holes.size() and out._breaths.all(func(b): return b.emitting), "a dark breath rises out of every hole")
	check(out._pack.is_empty() and out.flowers_open() == 0, "no pack and no flowers at new moon")
	check(not out._moon_horror.is_empty(), "a horror gets a spot at new moon")
	var middle := out.village_middle()
	var hole: Vector2i = out._moon_horror.hole
	for pos in out.holes:
		check(Vector2(out.world_to_cell(pos)).distance_to(middle) >= Vector2(hole).distance_to(middle), "the horror comes out of the hole nearest the village")
	var spot: Vector2i = out._moon_horror.cell
	check(Vector2(spot).distance_to(middle) < Vector2(hole).distance_to(middle), "the horror lurks closer to the village than its hole")
	check(Vector2(spot).distance_to(Vector2(hole)) >= Outdoor.HORROR_OUT - 1.0, "the horror crawls well out of its hole")
	check(out.cell_char(spot) != ":", "the horror stays off the village square")

	# It never comes out under the hero's nose.
	game.player.global_position = out.cell_to_world(spot)
	out._moon_horror.timer = 0.0
	out._mind_the_moon(0.1)
	check(out.moon_horror() == null, "the horror does not come out right beside the hero")
	game.player.global_position = out.cell_to_world(out.start_cell)
	out._mind_the_moon(0.1)
	var horror := out.moon_horror()
	check(horror != null and horror.is_horror(), "a horror comes out when the hero is far away")

	# Slain, it does not come back before the next new moon.
	horror.hp = 0
	horror._die()
	check(out.taken.has("neumond:%d" % dark), "a slain new-moon horror is remembered")
	out.set_moon(-1)
	out.set_moon(dark)
	check(out._moon_horror.is_empty(), "a slain horror does not come back the same night")
	out.taken.erase("neumond:%d" % dark)

	# Dawn: the holes fall quiet.
	game.day = dark + 1
	game.day_hour = 8.0
	game._tick_clock(0.0)
	check(not out.holes_breathe() and out._breaths.all(func(b): return not b.emitting), "the holes stop breathing at dawn")
	check(out._moon_horror.is_empty(), "the horror is gone by day")


func _quiet_night() -> void:
	var quiet := 0
	_go_out(quiet, 23.0)
	var out: Outdoor = game.level
	check(not Moon.is_full(quiet) and not Moon.is_new(quiet), "night 0 is a quiet moon")
	check(out._pack.is_empty() and out.flowers_open() == 0 and out._moon_horror.is_empty() and not out.holes_breathe(),
			"on a quiet moon nothing extra comes out")
	_go_out(_night_of(Moon.FULL), 12.0)
	check(game.level.moon_night == -1 and game.level._pack.is_empty() and game.level.flowers_open() == 0,
			"the full moon brings nothing by day")


func _journal() -> void:
	var full := _night_of(Moon.FULL)
	_go_out(full, 23.0)
	game.menus.map_page = "tagebuch"
	game.menus.open("karte")
	var found := false
	for l in game.menus._box.find_children("*", "Label", true, false):
		if (l as Label).text.contains(Moon.forecast(full)):
			found = true
	check(found, "the journal shows what tonight's moon brings")
	game.menus.close()
