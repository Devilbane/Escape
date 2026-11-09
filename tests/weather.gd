extends SceneTree
## Headless test for the weather above ground: rain, fog and thunderstorms
## change the sky, bring their own creatures (slimes at the pond in the
## rain, fog wraiths among the dead trees in fog, bats around the rocks in
## a storm), fog hides a sneaking hero, lightning leaves thunder ore that
## fades when the storm passes, the weather runs on the clock and is kept
## in the saved game, and down in the dungeon there is none of it.
## Run with: godot --headless --fixed-fps 60 -s tests/weather.gd

var failures := 0
var game: Node
var frames := 0
const HERO := "Weather test"


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(5)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _finish() -> void:
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: weather")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	_clear_day()
	_rain()
	_fog()
	_storm()
	_clears_up()
	_rolls()
	_clock_and_saving()
	_dungeon()
	_finish()
	return true


## Lets the open air settle on the weather: the look fades over, the
## level gets its creatures' spots, rain and mist follow.
func _settle() -> void:
	game._tick_clock(60.0)
	game._show_weather()


func _kinds() -> Array:
	var out := []
	for s in game.level._weather_foes:
		if not s.kind in out:
			out.append(s.kind)
	return out


## Brings out every creature of the weather that may come now.
func _call_out() -> void:
	for s in game.level._weather_foes:
		s.timer = 0.0
	game.level._mind_the_weather(0.1)


func _clear_day() -> void:
	game.hero_name = HERO
	game.day_hour = 12.0
	game.set_weather(Weather.CLEAR, 4.0)
	game.load_level(game._outdoor_index(), false)
	_settle()
	check(game.level is Outdoor, "the open air is an outdoor level")
	check(game.level.weather == Weather.CLEAR, "the open air knows the weather")
	check(not game._env.fog_enabled, "no fog on a clear day")
	check(is_equal_approx(game._env.ambient_light_energy, 0.52), "a clear day keeps the daylight")
	check(game.level._weather_foes.is_empty(), "nothing extra comes out on a clear day")
	check(not game._rain.emitting and not game._mist.emitting, "no rain and no mist on a clear day")
	check(not game._clock_text().contains(Lang.t("Regen")), "the HUD names no weather on a clear day")


func _rain() -> void:
	game.set_weather(Weather.RAIN, 4.0)
	_settle()
	check(game.level.weather == Weather.RAIN, "it rains in the open air")
	check(game._env.ambient_light_energy < 0.52 and game._moon.light_energy < 0.88, "rain darkens the day")
	check(game._rain.emitting, "rain falls around the hero")
	check(_kinds() == ["schleim"], "in the rain slimes get their spots")
	for s in game.level._weather_foes:
		var near_pond := false
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				near_pond = near_pond or game.level.cell_char(s.cell + Vector2i(dx, dy)) == "~"
		check(near_pond, "slimes come out right beside the pond")
	_call_out()
	check(game.level.weather_foes_alive() > 0, "slimes crawl out of the pond in the rain")
	check(game._clock_text().contains(Lang.t("Regen")), "the HUD names the rain")


func _fog() -> void:
	var slimes := []
	for s in game.level._weather_foes:
		if s.enemy != null:
			slimes.append(s.enemy)
	game.set_weather(Weather.FOG, 4.0)
	_settle()
	for e in slimes:
		check(is_instance_valid(e) and not e._dawn, "the slimes stay and wander on when the rain stops")
	check(game._env.fog_enabled and game._env.fog_density > 0.003, "a thin haze hangs over the open air")
	check(game._env.fog_density < 0.01, "the haze is thin: the fog is in the clouds, not an even blanket")
	check(game._clouds.visible and game._clouds.strength() > 0.8, "fog clouds drift over the open air")
	check(game._clouds._mat.render_priority < 0, "the clouds draw before every label and particle")
	check(game._mist.emitting and not game._rain.emitting, "mist drifts, and no rain falls in fog")
	check(_kinds() == ["fog_wraith", "schleim"], "in fog the fog wraiths and slimes get their spots")
	_call_out()
	check(game.level.weather_foes_alive() > 0, "fog wraiths drift among the dead trees")
	for s in game.level._weather_foes:
		if s.enemy != null and s.kind == "fog_wraith":
			check(s.enemy._stats.get("roam", false), "a fog wraith roams")
			check(s.enemy.fall_text() == Lang.t("Der Nebelgeist verweht."), "a fog wraith drifts apart when it falls")
	check(not game.level.night, "noon is not night")
	check(not game.level.is_lit(Vector3(-500, 0, -500)), "away from the lanterns the fog hides the hero by day")
	check(game.level.is_lit(game.level._lamps[0].global_position), "a lantern still shows the hero in fog")


func _storm() -> void:
	game.set_weather(Weather.STORM, 4.0)
	_settle()
	check(_kinds() == ["fledermaus", "schleim"], "in a storm bats and slimes get their spots")
	check(game._env.ambient_light_energy < 0.45, "a storm is darker than rain")
	check(game._rain.emitting, "rain pours in a storm")
	var dark: float = game._env.ambient_light_energy
	game._flash = 0.0
	for i in 40:
		game.level.strike()
	check(game._flash > 0.0, "lightning makes the sky flash")
	game._tick_clock(0.0)
	check(game._env.ambient_light_energy > dark, "the flash lights up the world")
	var ore: int = game.level.ore_lying()
	check(ore > 0 and ore <= Outdoor.MAX_ORE, "lightning leaves some thunder ore beside the rocks (%d)" % ore)
	check(Items.ALL.has("donnererz") and Items.ALL.donnererz.get("no_loot", false), "thunder ore is never found as loot")
	check(Forge.can_melt("donnererz") and Forge.melt_yield("donnererz") >= 3, "the smith melts thunder ore into iron bars")
	game.player.bag.append("donnererz")
	check(not game.player.equip("donnererz"), "thunder ore cannot be worn")
	game.player.bag.erase("donnererz")


func _clears_up() -> void:
	game.set_weather(Weather.CLEAR, 4.0)
	_settle()
	check(game.level.ore_lying() == 0, "thunder ore fades once the storm has passed")
	check(game.level._weather_foes.is_empty(), "the weather's creatures go when the sky clears")
	check(game.level.slimes_about() > 0, "the slimes stay and wander on under a clear sky")
	check(game.level.slimes_about() <= Outdoor.SLIMES_AT_MOST, "no more than %d slimes crawl about" % Outdoor.SLIMES_AT_MOST)
	check(not game._env.fog_enabled, "the fog lifts")
	check(not game._clouds.visible, "the clouds are gone with the fog")
	check(DamageNumber.show_at(game, Vector3.ZERO, "1", Color.WHITE).render_priority > game._clouds._mat.render_priority, "combat and news texts draw over the clouds")
	check(absf(game._env.ambient_light_energy - 0.52) < 0.01, "the daylight comes back")


func _rolls() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var seen := {}
	for hour in [2.0, 8.0, 13.0, 19.0]:
		for i in 200:
			var before: String = Weather.KINDS[i % Weather.KINDS.size()]
			var next := Weather.roll(hour, rng, before)
			check(next in Weather.KINDS and next != before, "the next weather is a real change")
			seen[next] = true
	check(seen.size() == Weather.KINDS.size(), "every weather comes now and then")
	# Rain is a third as common as the raw weights would make it.
	var raw := 0
	var kept := 0
	for i in 6000:
		var hr: float = [2.0, 8.0, 13.0, 19.0][i % 4]
		if Weather.roll(hr, rng, Weather.CLEAR) == Weather.RAIN:
			kept += 1
		var chances: Dictionary = Weather.CHANCES[Weather.part_of_day(hr)]
		if Weather._pick(chances, rng, Weather.CLEAR, "") == Weather.RAIN:
			raw += 1
	check(absf(float(kept) / float(raw) - 1.0 / 3.0) < 0.06, "rain comes a third as often (%d of %d)" % [kept, raw])
	for i in 50:
		var h := Weather.spell(rng, Weather.RAIN)
		check(h >= Weather.MIN_HOURS and h <= Weather.MAX_HOURS, "a spell of bad weather lasts a few hours")
		var c := Weather.spell(rng, Weather.CLEAR)
		check(c >= Weather.CLEAR_MIN_HOURS and c <= Weather.CLEAR_MAX_HOURS, "clear skies last longer")
	# Over many days, clear skies hold most of the time.
	var hour := 8.0
	var kind: String = Weather.CLEAR
	var clear := 0.0
	var total := 0.0
	for i in 4000:
		var h := Weather.spell(rng, kind)
		total += h
		if kind == Weather.CLEAR:
			clear += h
		hour = fmod(hour + h, 24.0)
		kind = Weather.roll(hour, rng, kind)
	check(clear / total > 0.55, "clear skies hold most of the time (%.0f%%)" % (100.0 * clear / total))


func _clock_and_saving() -> void:
	# The weather changes when its hours are up, on the clock.
	var before_state = game.state
	game.state = game.State.PLAYING
	game.set_weather(Weather.RAIN, 1.0)
	game._tick_clock(60.0)
	check(game.weather != Weather.RAIN, "the rain stops when its hours are up")
	check(game.weather_hours >= Weather.MIN_HOURS * 0.9, "the next weather lasts a while")
	game.state = before_state

	# The weather goes into the saved game and comes back from it.
	game.set_weather(Weather.FOG, 3.5)
	check(game.save_game(), "the game is saved")
	var data: Dictionary = game._read_save(game.save_path())
	check(data.get("weather", "") == Weather.FOG, "the saved game holds the weather")
	game.set_weather(Weather.CLEAR, 2.0)
	game._apply_save(data)
	check(game.weather == Weather.FOG and is_equal_approx(game.weather_hours, 3.5), "loading brings the weather back")
	data.erase("weather")
	data.erase("weather_hours")
	game._apply_save(data)
	check(game.weather == Weather.CLEAR, "an older saved game wakes up to clear skies")


func _dungeon() -> void:
	game.set_weather(Weather.STORM, 4.0)
	game.load_level(0, false)
	game._tick_clock(1.0)
	game._show_weather()
	check(not game._env.fog_enabled, "no fog down in the dungeon")
	check(not game._clouds.visible, "no clouds down in the dungeon")
	check(not game._rain.emitting and not game._rain.visible, "no rain down in the dungeon")
