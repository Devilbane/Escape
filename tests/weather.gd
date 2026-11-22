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
	# Night dust: 25% of real fog on a clear night, none by day, and
	# never more than real fog.
	var clear := Weather.look(Weather.CLEAR)
	var fog := Weather.look(Weather.FOG)
	check(is_equal_approx(Weather.dusty_mist(clear, 0.0), Weather.NIGHT_DUST * fog.mist), "a clear night has 25% of fog's mist")
	check(Weather.dusty_mist(clear, 12.0) == 0.0, "no dust by day")
	check(is_equal_approx(Weather.dusty_mist(fog, 0.0), Weather.NIGHT_DUST), "the fog weather is not drawn at night, only the dust")
	check(Weather.dusty_mist(fog, 12.0) == fog.mist, "fog by day is as it was")
	# Fog never lights the scenery up: at night its colour is never brighter than the dark air.
	var night_air := Color(0.04, 0.04, 0.05)
	for winter in [false, true]:
		var h := Weather.fog_haze(night_air, 1.0, winter)
		check(maxf(h.r, maxf(h.g, h.b)) <= 0.05 + 0.0001, "night fog is no brighter than the night (winter %s)" % winter)
	var wn := Weather.fog_haze(night_air, 1.0, true)
	check(wn.b > wn.r, "winter fog is tinted cool")
	check(Weather.fog_haze(night_air, 1.0, false) == night_air, "fog keeps the air's colour")
	# The mist particles at night are dark, too.
	var mist := Weather.make_mist()
	Weather.show_particles(Weather.make_rain(), mist, fog, 0.3)
	var mc: Color = ((mist.mesh as QuadMesh).material as ShaderMaterial).get_shader_parameter("albedo")
	check(maxf(mc.r, maxf(mc.g, mc.b)) < 0.2, "night mist is dark")
	# A mist patch that has not drifted in yet has no size and must draw nothing: drawn full-sized,
	# the waiting patches showed as one black dome over the hero when fog rolled in.
	var mist_mat := (mist.mesh as QuadMesh).material as ShaderMaterial
	check(mist_mat.shader == Weather.PARTICLE_SHADER and int(mist_mat.get_shader_parameter("billboard")) == Weather.FACING, "mist patches keep their own size")
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
	_bolt()
	_fog_rolls_in()
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
	game._place_dust(game.player.global_position)
	check(not game.get_node("Dust").visible, "no dust motes drift in the open air (they read as snowflakes)")
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
		for i in 400:
			var before: String = Weather.KINDS[i % Weather.KINDS.size()]
			var season: String = Weather.SEASONS[(i / Weather.KINDS.size()) % Weather.SEASONS.size()]
			var next := Weather.roll(hour, rng, before, season)
			check(next in Weather.KINDS and (next != before or next == Weather.CLEAR), "the next weather is a real change (or clear skies stay)")
			check(season != Weather.WINTER or (next != Weather.RAIN and next != Weather.STORM), "no rain and no storm in winter")
			check(next != Weather.SNOW or season != Weather.SUMMER, "no snow in summer")
			seen[next] = true
	check(seen.size() == Weather.KINDS.size(), "every weather comes now and then")
	# Each season has its own weather: share of the time over many days.
	var shares := {}
	for season in Weather.SEASONS:
		shares[season] = _shares(rng, season)
	var spring: Dictionary = shares[Weather.SPRING]
	var summer: Dictionary = shares[Weather.SUMMER]
	var autumn: Dictionary = shares[Weather.AUTUMN]
	var winter: Dictionary = shares[Weather.WINTER]
	check(spring[Weather.CLEAR] > 0.65 and spring[Weather.RAIN] > spring[Weather.FOG] and spring[Weather.RAIN] < 0.25, "spring: mostly sunny, a bit of rain (%s)" % spring)
	check(spring[Weather.SNOW] > 0.0 and spring[Weather.SNOW] < 0.04 and spring[Weather.FOG] < 0.08, "spring: rarely snow, rarely fog")
	check(summer[Weather.CLEAR] > spring[Weather.CLEAR] and summer[Weather.SNOW] == 0.0, "summer: the sunniest, no snow (%s)" % summer)
	check(summer[Weather.STORM] > summer[Weather.RAIN] and summer[Weather.RAIN] < 0.08 and summer[Weather.FOG] < 0.05, "summer: thunderstorms, rarely rain or fog")
	check(autumn[Weather.RAIN] > spring[Weather.RAIN] and autumn[Weather.FOG] > spring[Weather.FOG] and autumn[Weather.STORM] > 0.05, "autumn: rain, fog and thunderstorms (%s)" % autumn)
	check(autumn[Weather.SNOW] > 0.0 and autumn[Weather.SNOW] < 0.04 and autumn[Weather.CLEAR] > 0.45, "autumn: still sunny spells, rarely snow")
	check(winter[Weather.SNOW] > 0.1 and winter[Weather.RAIN] == 0.0 and winter[Weather.STORM] == 0.0, "winter: snow, no rain (%s)" % winter)
	# The seasons follow each other over the year.
	check(Weather.season(0) == Weather.SPRING and Weather.season(Weather.YEAR_DAYS) == Weather.SPRING, "a year starts in spring")
	var autumn_first := Weather.YEAR_DAYS - Weather.WINTER_DAYS - Weather.AUTUMN_DAYS
	check(Weather.season(autumn_first - 1) == Weather.SUMMER and Weather.season(autumn_first) == Weather.AUTUMN, "summer comes before autumn")
	check(Weather.season(Weather.YEAR_DAYS - 1) == Weather.WINTER, "a year ends in winter")
	for i in 50:
		var h := Weather.spell(rng, Weather.RAIN)
		check(h >= Weather.RAIN_MIN_HOURS and h <= Weather.RAIN_MAX_HOURS, "a spell of rain lasts long")
		var f := Weather.spell(rng, Weather.FOG)
		check(f >= Weather.MIN_HOURS and f <= Weather.MAX_HOURS, "a spell of fog lasts a few hours")
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
		kind = Weather.roll(hour, rng, kind, Weather.AUTUMN)
	check(clear / total > 0.5, "even in autumn clear skies hold most of the time (%.0f%%)" % (100.0 * clear / total))


## The share of the time each weather holds in a season, over many days.
func _shares(rng: RandomNumberGenerator, season: String) -> Dictionary:
	var hour := 8.0
	var kind: String = Weather.CLEAR
	var time := {}
	var total := 0.0
	for k in Weather.KINDS:
		time[k] = 0.0
	for i in 20000:
		var h := Weather.spell(rng, kind)
		total += h
		time[kind] += h
		hour = fmod(hour + h, 24.0)
		kind = Weather.roll(hour, rng, kind, season)
	for k in Weather.KINDS:
		time[k] = snappedf(time[k] / total, 0.001)
	return time


## The lightning bolt zig-zags hard from the sky to the strike, forks a few times, and stays a moment.
func _bolt() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var at := Vector3(5, 0, -3)
	for n in 20:
		var line := LightningBolt.path(at, rng)
		check(line[line.size() - 1].is_equal_approx(at) and line[0].y > 20.0, "the bolt runs from the sky down to the strike")
		var turns := 0
		for i in range(1, line.size() - 1):
			var a: float = line[i].x - line[i - 1].x
			var b: float = line[i + 1].x - line[i].x
			if signf(a) != signf(b):
				turns += 1
		check(turns >= line.size() - 3, "the bolt zig-zags at every kink (%d turns)" % turns)
		var forks := LightningBolt.forks(line, rng)
		check(forks.size() >= LightningBolt.FORKS_MIN and forks.size() <= LightningBolt.FORKS_MAX, "the bolt forks a few times")
		for f in forks:
			check(f[f.size() - 1].y > at.y + 0.5 and f[f.size() - 1].y < f[0].y, "a fork runs down and dies out in the air")
	var bolt := LightningBolt.build(at, rng)
	check(bolt.get_child_count() == 2 and (bolt.get_child(0) as MeshInstance3D).mesh.get_surface_count() == 1, "the bolt is a core and a glow")
	bolt.free()
	check(LightningBolt.lasts() >= 1.2, "the bolt stays a moment (%.2f s)" % LightningBolt.lasts())


## Fog rolls in slowly, thickening evenly over FOG_BUILD seconds, and lifts at the usual pace.
func _fog_rolls_in() -> void:
	var look := Weather.look(Weather.CLEAR)
	var fog := Weather.look(Weather.FOG)
	var seen := []
	for i in 60:
		look = Weather.ease_look(look, fog, Weather.FOG_BUILD / 60.0)
		seen.append(float(look.mist))
	check(seen[5] < 0.15 and seen[29] > 0.4 and seen[29] < 0.6, "the fog thickens slowly (%.2f after a tenth, %.2f halfway)" % [seen[5], seen[29]])
	check(is_equal_approx(seen[59], 1.0) and is_equal_approx(float(look.fog), float(fog.fog)), "the fog reaches its full thickness after FOG_BUILD")
	check(float(look.sun) < 0.6, "the light dims at the usual pace")
	for i in 30:
		look = Weather.ease_look(look, Weather.look(Weather.CLEAR), 1.0)
	check(float(look.mist) < 0.01, "the fog lifts within the usual fade")
	check(Weather.make_mist().preprocess == 0.0, "the mist starts without a burst of particles")


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
