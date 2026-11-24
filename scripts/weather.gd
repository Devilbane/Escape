class_name Weather
extends RefCounted
## The weather of the world above ground: clear skies, rain, fog or a
## thunderstorm. It runs on the clock of day and night (see DayNight): a
## spell of weather lasts a few hours of the day, and which weather comes
## next depends on the hour. Most of the time the sky is clear: a clear
## spell lasts longer than a bad one, and when bad weather passes, the sky
## nearly always clears. Fog gathers at night and in the early morning, and
## storms brew in the evening and at night. Like the clock, the weather stands still down in the dungeon.
##
## The weather changes what is about (see Outdoor.set_weather):
##   rain   slimes crawl out of the pond in the woods;
##   fog    fog wraiths drift among the dead trees, and away from the
##          lanterns a sneaking hero stays unseen even by day;
##   storm  bats swarm around the rocks, and where lightning strikes a rock
##          it leaves a lump of thunder ore (see Items, "donnererz") that
##          only lies there while the storm lasts.
## Night still counts on top: fog wraiths out at night roam further.
##
## Over the light of the hour, the weather lays its own look: rain and
## storm darken and grey the sky, fog washes it out and hides the distance.
## Rain falls around the hero, mist drifts over the ground, and lightning
## lights up the whole world for a moment. Rain leaves puddles that stay a
## while after it (see Puddles and puddle_water).

const CLEAR := "clear"
const RAIN := "rain"
const FOG := "fog"
const STORM := "storm"
const SNOW := "snow"
const KINDS := [CLEAR, RAIN, FOG, STORM, SNOW]

## How many hours of the day one spell of rain, fog or storm lasts, at
## least and at most (one hour is 50 real seconds, see DayNight.DAY_LENGTH).
const MIN_HOURS := 1.5
const MAX_HOURS := 3.5
## Rain lasts long when it comes: twice as long as fog or a storm.
const RAIN_MIN_HOURS := 3.0
const RAIN_MAX_HOURS := 7.0
## Snow falls only briefly: a flurry lasts this many hours of the day.
const SNOW_MIN_HOURS := 1.0
const SNOW_MAX_HOURS := 2.0
## Clear skies last longer, so they make up about two thirds of the time.
const CLEAR_MIN_HOURS := 4.0
const CLEAR_MAX_HOURS := 8.0
## A new game, or a saved game from before there was weather, starts with
## clear skies for this many hours.
const FIRST_HOURS := 4.0

## The year: four seasons of SEASON_DAYS real days each, spring, summer, autumn and winter, counted
## in season days (see Seasons: the real calendar, one real week a season). Snow falls only in winter,
## and there is no rain and no thunderstorm then: snow comes in their place, often, and the snow on
## the ground stays until spring.
const SEASON_DAYS := 7
const YEAR_DAYS := 4 * SEASON_DAYS
const SPRING_DAYS := SEASON_DAYS
const WINTER_DAYS := SEASON_DAYS
## Autumn comes just before winter: the leaves of the trees and the vines on the houses turn red,
## brown and gold (see IvySeasons, tree.gdshader).
const AUTUMN_DAYS := SEASON_DAYS
## The season day of the year on which autumn starts.
const AUTUMN_FROM := YEAR_DAYS - WINTER_DAYS - AUTUMN_DAYS

const SPRING := "spring"
const SUMMER := "summer"
const AUTUMN := "autumn"
const WINTER := "winter"
const SEASONS := [SPRING, SUMMER, AUTUMN, WINTER]

## How likely each weather is to come next, by season and part of the day. The
## weather never turns into itself, except that clear skies may stay clear (see
## STAY_CLEAR); otherwise these weights pick which bad weather follows clear skies,
## and after bad weather, clear skies win most rolls. Fog still gathers at night and
## in the morning, and storms still brew in the evening.
##   spring  mostly sunny, now and then rain, rarely fog, no snow;
##   summer  the sunniest: thunderstorms (most on warm evenings), rarely rain or fog, no snow;
##   autumn  changeable: sunny spells, rain, thunderstorms and fog, no snow;
##   winter  snow instead of rain and storms, fog in the morning.
const CHANCES := {
	SPRING: {
		"night": {CLEAR: 8.0, RAIN: 0.9, FOG: 0.6, STORM: 0.15},
		"morning": {CLEAR: 8.0, RAIN: 0.7, FOG: 0.8, STORM: 0.05},
		"day": {CLEAR: 14.0, RAIN: 1.1, FOG: 0.2, STORM: 0.2},
		"evening": {CLEAR: 8.0, RAIN: 0.9, FOG: 0.3, STORM: 0.3},
	},
	SUMMER: {
		"night": {CLEAR: 10.0, RAIN: 0.3, FOG: 0.3, STORM: 1.5},
		"morning": {CLEAR: 10.0, RAIN: 0.2, FOG: 0.5, STORM: 0.3},
		"day": {CLEAR: 16.0, RAIN: 0.3, FOG: 0.1, STORM: 1.0},
		"evening": {CLEAR: 10.0, RAIN: 0.3, FOG: 0.1, STORM: 2.5},
	},
	AUTUMN: {
		"night": {CLEAR: 6.0, RAIN: 2.5, FOG: 3.0, STORM: 1.5},
		"morning": {CLEAR: 6.0, RAIN: 2.0, FOG: 4.0, STORM: 0.5},
		"day": {CLEAR: 10.0, RAIN: 3.0, FOG: 1.0, STORM: 1.2},
		"evening": {CLEAR: 6.0, RAIN: 2.5, FOG: 1.5, STORM: 2.0},
	},
	WINTER: {
		"night": {CLEAR: 6.0, FOG: 2.0, SNOW: 5.0},
		"morning": {CLEAR: 6.0, FOG: 2.5, SNOW: 4.0},
		"day": {CLEAR: 8.0, FOG: 0.5, SNOW: 5.0},
		"evening": {CLEAR: 6.0, FOG: 0.5, SNOW: 5.0},
	},
}
## In winter the snow on the ground does not melt in dry weather at all: it lies until spring.

## When a clear spell ends, the chance that the sky simply stays clear for another
## spell: this is what makes spring and summer sunnier than autumn and winter.
const STAY_CLEAR := {SPRING: 0.5, SUMMER: 0.65, AUTUMN: 0.15, WINTER: 0.0}

## The look of each weather, laid over the light of the hour: how much of
## the sun (or moon) and of the ambient light is left, the colour
## saturation, how thick the fog is, how hard it rains (0 to 1) and how much
## mist drifts over the ground (0 to 1). The fog is only a thin haze all
## over; the thick part of it hangs in drifting clouds (see FogClouds), which
## `mist` sets the thickness of.
const LOOKS := {
	CLEAR: {"sun": 1.0, "amb": 1.0, "sat": 1.0, "fog": 0.0, "rain": 0.0, "mist": 0.0, "snow": 0.0},
	RAIN: {"sun": 0.5, "amb": 0.85, "sat": 0.8, "fog": 0.006, "rain": 0.55, "mist": 0.0, "snow": 0.0},
	FOG: {"sun": 0.55, "amb": 1.05, "sat": 0.7, "fog": 0.0035, "rain": 0.0, "mist": 1.0, "snow": 0.0},
	STORM: {"sun": 0.3, "amb": 0.7, "sat": 0.62, "fog": 0.01, "rain": 1.0, "mist": 0.0, "snow": 0.0},
	SNOW: {"sun": 0.6, "amb": 1.0, "sat": 0.75, "fog": 0.005, "rain": 0.0, "mist": 0.0, "snow": 1.0},
}
## The colour of fog and haze in full daylight; at night it darkens with
## the ambient light.
const HAZE := Color(0.66, 0.68, 0.72)
## How long the look takes to move most of the way to a new weather
## (real seconds).
const FADE := 5.0
## Fog rolls in slowly: the mist and the haze thicken evenly from nothing to their full
## strength over this many real seconds (see ease_look), instead of within FADE. Clearing up
## still takes FADE.
const FOG_BUILD := 60.0

## Every night is a little dusty: the mist at its thinnest, this share of
## the thickness of real fog, fading in at dusk and out at dawn.
const NIGHT_DUST := 0.25

## Rain drops at full strength, and the box around the hero they fall in.
const RAIN_DROPS := 700
const RAIN_BOX := Vector3(22, 0.5, 16)
const RAIN_HEIGHT := 16.0
## Drifting patches of mist at full strength.
const MIST_PATCHES := 28
## Rain puddles (see Puddles): how many hours of rain fill them up (a
## storm pours twice as fast), and how many hours of dry weather after it
## they take to dry up again.
const PUDDLE_FILL_HOURS := 0.8
const PUDDLE_DRY_HOURS := 3.0

## Snow (see SnowCover): flakes at full strength, and the box around the hero
## they fall in. The layer of snow on the roofs and the ground builds up in
## this many hours of snowfall and melts away again in this many hours of
## dry weather (rain washes it off in a third of that).
const SNOW_FLAKES := 650
## In winter a few small flakes fall in any weather (clear, fog): this many, at this strength
## (the share of a full snowfall's look). A real snowfall brings all SNOW_FLAKES.
const WINTER_FLAKES := 450
const WINTER_FLURRY := 0.85
const SNOW_BUILD_HOURS := 0.5
const SNOW_MELT_HOURS := 5.0
const SNOW_RAIN_MELT := 3.0
## Below this much snow on the ground the air is not cold enough to see
## breath, and the footprints of a hero are not clear in the snow.
const COLD_FROM := 0.15
const PRINT_FROM := 0.3
## True while it is cold above ground (set by Game): breath shows (see Breath).
static var cold := false


## The mist of a look as it is drawn: real fog by day, only the night's dust (see NIGHT_DUST) at night.
static func dusty_mist(weather_look: Dictionary, hour: float) -> float:
	# The fog weather itself is never drawn at night (it only made the dark look blotchy): by night
	# its mist fades out and only the thin dust is left.
	var night := DayNight.glow_at(hour)
	return maxf(float(weather_look.mist) * (1.0 - night), NIGHT_DUST * night)


## The cool white of winter fog: only its tint, the brightness is the haze's own.
const WINTER_HAZE := Color(0.7, 0.77, 0.88)


## The colour fog is drawn in (clouds and mist). Fog never adds light: the haze is the colour of the
## air around it (`air`, the environment's fog colour, which is as dark as the ambient light, so
## next to black at night) and so only hides things in the dark, it never lights the scenery up.
## In winter it is tinted cool white over the snow, with the same brightness. No channel is ever
## brighter than the air's brightest one.
static func fog_haze(air: Color, fog: float, winter: bool) -> Color:
	if not winter:
		return air
	var lum := maxf(air.r, maxf(air.g, air.b))
	var cool := Color(WINTER_HAZE.r, WINTER_HAZE.g, WINTER_HAZE.b, air.a) * (lum / WINTER_HAZE.b)
	cool.a = air.a
	return air.lerp(cool, clampf(fog, 0.0, 1.0))


## The part of the day the chances go by.
static func part_of_day(hour: float) -> String:
	if DayNight.is_night(hour):
		return "night"
	if hour < 10.0:
		return "morning"
	if hour >= 17.5:
		return "evening"
	return "day"


## Picks the next weather for an hour of the day in a season (see season). It is
## never the same as the weather before, so every change can be seen, except that
## clear skies may stay clear (see STAY_CLEAR).
static func roll(hour: float, rng: RandomNumberGenerator, before := "", in_season := SPRING) -> String:
	var table: Dictionary = CHANCES.get(in_season, CHANCES[SPRING])
	if before == CLEAR and rng.randf() < float(STAY_CLEAR.get(in_season, 0.0)):
		return CLEAR
	return _pick(table[part_of_day(hour)], rng, before, "")


## One weighted pick among the weathers that are not `before` or `skip`.
static func _pick(chances: Dictionary, rng: RandomNumberGenerator, before: String, skip: String) -> String:
	var total := 0.0
	for kind in chances:
		if kind != before and kind != skip:
			total += chances[kind]
	var pick := rng.randf() * total
	for kind in chances:
		if kind == before or kind == skip:
			continue
		pick -= chances[kind]
		if pick <= 0.0:
			return kind
	return CLEAR if before != CLEAR else FOG


## How many hours a new spell of weather lasts: clear skies stay longer
## than rain, fog or a storm.
static func spell(rng: RandomNumberGenerator, kind := RAIN) -> float:
	if kind == CLEAR:
		return rng.randf_range(CLEAR_MIN_HOURS, CLEAR_MAX_HOURS)
	if kind == SNOW:
		return rng.randf_range(SNOW_MIN_HOURS, SNOW_MAX_HOURS)
	if kind == RAIN:
		return rng.randf_range(RAIN_MIN_HOURS, RAIN_MAX_HOURS)
	return rng.randf_range(MIN_HOURS, MAX_HOURS)


## Whether season day `day` (see Seasons) is in spring, the SPRING_DAYS that open the year.
static func is_spring(day: int) -> bool:
	return posmod(day, YEAR_DAYS) < SPRING_DAYS


## The season of season day `day` (see Seasons): SPRING, SUMMER, AUTUMN or WINTER.
static func season(day: int) -> String:
	if is_winter(day):
		return WINTER
	if is_autumn(day):
		return AUTUMN
	if is_spring(day):
		return SPRING
	return SUMMER


## Whether season day `day` (see Seasons) is in winter (see YEAR_DAYS).
static func is_winter(day: int) -> bool:
	return posmod(day, YEAR_DAYS) >= YEAR_DAYS - WINTER_DAYS


## Whether `day` is in autumn, the AUTUMN_DAYS just before winter.
static func is_autumn(day: int) -> bool:
	var d := posmod(day, YEAR_DAYS)
	return d >= YEAR_DAYS - WINTER_DAYS - AUTUMN_DAYS and d < YEAR_DAYS - WINTER_DAYS


## How many days of autumn have passed on `day` (0 on its first day), or -1 outside autumn.
static func autumn_day(day: int) -> int:
	if not is_autumn(day):
		return -1
	return posmod(day, YEAR_DAYS) - (YEAR_DAYS - WINTER_DAYS - AUTUMN_DAYS)


## The weather a winter allows: snow where rain or a storm would be.
static func for_season(kind: String, winter: bool) -> String:
	if winter and (kind == RAIN or kind == STORM):
		return SNOW
	return kind


## How much water lies in the puddles (0 dry to 1 full) after `delta` real
## seconds more of `kind` weather: rain fills them, a storm faster, and any
## other weather dries them, slowly, so they stay a while after the rain.
static func puddle_water(water: float, kind: String, delta: float) -> float:
	var hours := delta * 24.0 / DayNight.DAY_LENGTH
	if kind == RAIN or kind == STORM:
		water += hours / PUDDLE_FILL_HOURS * (2.0 if kind == STORM else 1.0)
	else:
		water -= hours / PUDDLE_DRY_HOURS
	return clampf(water, 0.0, 1.0)


## How thick the snow lies (0 bare to 1 deep) after `delta` real seconds more
## of `kind` weather: snowfall builds it up, other weather melts it, rain
## quickest. The snow lies on the ground and the roofs for a while after the
## flurry, so there is time to walk in it.
static func snow_cover(cover: float, kind: String, delta: float, winter := false) -> float:
	var hours := delta * 24.0 / DayNight.DAY_LENGTH
	if kind == SNOW:
		cover += hours / SNOW_BUILD_HOURS
	elif not winter:
		cover -= hours / SNOW_MELT_HOURS * (SNOW_RAIN_MELT if kind == RAIN or kind == STORM else 1.0)
	return clampf(cover, 0.0, 1.0)


## Hours of cold snow on the ground it takes the ponds to freeze over, and hours of milder
## weather to thaw again (rain thaws it ICE_RAIN_THAW times as fast).
const ICE_FREEZE_HOURS := 3.0
const ICE_THAW_HOURS := 12.0
const ICE_RAIN_THAW := 2.0


## How thickly the ponds are frozen (0 open water to 1 solid, see IceCover) after `delta` real
## seconds more: they freeze while snow lies (cold enough, see COLD_FROM) and thaw slowly after.
static func ice(frozen: float, cover: float, kind: String, delta: float) -> float:
	var hours := delta * 24.0 / DayNight.DAY_LENGTH
	if cover >= COLD_FROM:
		frozen += hours / ICE_FREEZE_HOURS
	else:
		frozen -= hours / ICE_THAW_HOURS * (ICE_RAIN_THAW if kind == RAIN or kind == STORM else 1.0)
	return clampf(frozen, 0.0, 1.0)


## The look of a weather (see LOOKS).
static func look(kind: String) -> Dictionary:
	return (LOOKS.get(kind, LOOKS[CLEAR]) as Dictionary).duplicate()


## A look partway (t from 0 to 1) from one to another.
## The look `delta` real seconds further on its way from `from` to the look of the weather
## `to`: most of the way within FADE, but the mist and the haze only thicken at the pace of
## FOG_BUILD, so fog rolls in slowly.
static func ease_look(from: Dictionary, to: Dictionary, delta: float) -> Dictionary:
	var out := blend(from, to, 1.0 - exp(-delta / FADE))
	var full: Dictionary = LOOKS[FOG]
	for key in ["mist", "fog"]:
		var was := float(from.get(key, 0.0))
		if float(to[key]) > was:
			out[key] = move_toward(was, float(to[key]), float(full[key]) * delta / FOG_BUILD)
	return out


static func blend(from: Dictionary, to: Dictionary, t: float) -> Dictionary:
	var out := {}
	for key in to:
		out[key] = lerpf(float(from.get(key, to[key])), float(to[key]), t)
	return out


## Lays the weather over the light of the hour. Call it right after
## DayNight.apply. `flash` (0 to 1) is a stroke of lightning.
static func apply(env: Environment, sun: DirectionalLight3D, weather_look: Dictionary, flash := 0.0) -> void:
	var dim: float = weather_look.sun
	sun.light_energy *= dim
	env.ambient_light_energy *= weather_look.amb
	env.adjustment_saturation *= weather_look.sat
	# A grey sky: the background drifts towards the haze, darker by night
	# (as dark as the moon leaves it: fog never glows in a moonless night).
	var haze := HAZE * clampf(env.ambient_light_energy / 0.52, 0.02, 1.0)
	haze.a = 1.0
	env.background_color = env.background_color.lerp(haze, clampf((1.0 - dim) * 0.8, 0.0, 1.0))
	env.fog_enabled = weather_look.fog > 0.0005
	env.fog_density = Graphics.fog(weather_look.fog)
	env.fog_light_color = haze
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.0
	if flash > 0.0:
		var white := Color(0.86, 0.9, 1.0)
		env.ambient_light_energy += flash * 1.4
		env.background_color = env.background_color.lerp(white, flash * 0.6)
		sun.light_energy += flash * 2.4
		sun.light_color = sun.light_color.lerp(white, flash)


## Nothing of the weather down in the dungeon.
static func clear_air(env: Environment) -> void:
	env.fog_enabled = false


## The weather as a word for the HUD (German, translated by Lang).
static func word(kind: String) -> String:
	if kind == RAIN:
		return "Regen"
	if kind == FOG:
		return "Nebel"
	if kind == STORM:
		return "Gewitter"
	if kind == SNOW:
		return "Schnee"
	return "klar"


const PARTICLE_SHADER := preload("res://shaders/weather_particle.gdshader")
## How weather_particle.gdshader turns a quad: as placed, facing the camera, or upright facing it.
const AS_PLACED := 0
const FACING := 1
const UPRIGHT := 2


## The unlit, see-through look of the rain, the mist and the leaves, which leaves out the inside of
## the houses (see weather_particle.gdshader and IndoorMask).
static func particle_material(tex: Texture2D, billboard: int, tinted: bool, colour: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = PARTICLE_SHADER
	if tex != null:
		mat.set_shader_parameter("texture_albedo", tex)
	mat.set_shader_parameter("billboard", billboard)
	mat.set_shader_parameter("use_vertex_color", tinted)
	mat.set_shader_parameter("albedo", colour)
	return mat


## From how hard it rains (the look's rain, 0 to 1) the drops turn smaller and greyer; at the full
## storm they are HEAVY_SIZE as big and HEAVY_GREYING of the way to HEAVY_GREY. Ordinary rain (0.55) is untouched.
const HEAVY_FROM := 0.6
const HEAVY_SIZE := 0.7
const HEAVY_GREYING := 0.6
const HEAVY_GREY := Color(0.62, 0.65, 0.7)


## Rain that falls around the hero (keep it over the hero, see Game).
static func make_rain() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = RAIN_DROPS
	p.lifetime = 0.8
	p.preprocess = 0.8
	p.local_coords = false
	p.emitting = false
	var streak := QuadMesh.new()
	streak.size = Vector2(0.035, 0.85)
	streak.material = particle_material(null, UPRIGHT, false, Color(0.75, 0.82, 0.95, 0.0))
	p.mesh = streak
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = RAIN_BOX
	p.direction = Vector3.DOWN
	p.spread = 3.0
	p.gravity = Vector3(0, -9.8, 0)
	p.initial_velocity_min = 18.0
	p.initial_velocity_max = 22.0
	Effects.start_cold(p)
	return p


const SNOWFLAKE_SHADER := preload("res://shaders/snowflake.gdshader")


## Snowflakes that drift down around the hero (keep them over the hero, see
## Game): big soft flakes, slow, with a little wind.
static func make_snow() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = SNOW_FLAKES
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.local_coords = false
	p.emitting = false
	var flake := QuadMesh.new()
	flake.size = Vector2(0.11, 0.11)
	# Lit by the light that reaches each flake, and invisible where none does (see snowflake.gdshader).
	var mat := ShaderMaterial.new()
	mat.shader = SNOWFLAKE_SHADER
	mat.set_shader_parameter("dot_tex", Effects._soft_dot())
	mat.set_shader_parameter("albedo", Color(1, 1, 1, 0.0))
	flake.material = mat
	p.mesh = flake
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = RAIN_BOX
	p.direction = Vector3(0.35, -1.0, 0.12)
	p.spread = 22.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 1.4
	p.initial_velocity_max = 2.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.5
	Effects.start_cold(p)
	return p


## Autumn leaves that drift gently down around the hero by day (see LeafFall).
static func make_leaves() -> LeafFall:
	return LeafFall.new()


static var _leaf: Texture2D


## A small pointed leaf, white so the particle's tint colours it.
static func _leaf_texture() -> Texture2D:
	if _leaf == null:
		var n := 32
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var u := (x + 0.5) / n * 2.0 - 1.0
				var v := (y + 0.5) / n * 2.0 - 1.0
				# A lens shape along the diagonal, with a slightly darker midrib.
				var along := (u + v) * 0.7071
				var across := (u - v) * 0.7071
				var half := 0.38 * (1.0 - absf(along) * absf(along)) if absf(along) < 1.0 else 0.0
				var a := clampf((half - absf(across)) * 16.0, 0.0, 1.0)
				var rib := 1.0 - 0.25 * clampf(1.0 - absf(across) * 14.0, 0.0, 1.0)
				img.set_pixel(x, y, Color(rib, rib, rib, a))
		_leaf = ImageTexture.create_from_image(img)
	return _leaf


## How many leaves are about (0 to 1): by day only, never in rain, fog or snow.
## The weather look fades between weathers, so the leaves fade with it.
static func leaf_strength(weather_look: Dictionary, hour: float) -> float:
	var calm := 1.0 - clampf(maxf(float(weather_look.rain), maxf(float(weather_look.mist), float(weather_look.snow))) * 2.0, 0.0, 1.0)
	return (1.0 - DayNight.glow_at(hour)) * calm


## Shows the leaves as strong as `strength` says (see leaf_strength), darker in
## dim light.
static func show_leaves(leaves: LeafFall, strength: float, light: float) -> void:
	leaves.visible = strength > 0.05
	var tone := clampf(0.4 + light, 0.4, 1.0)
	leaves.material.set_shader_parameter("albedo", Color(tone, tone, tone, 0.9 * strength))


## Soft grey patches of mist that drift slowly over the ground.
static func make_mist() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = MIST_PATCHES
	p.lifetime = 12.0
	# No preprocess: fog rolls in slowly (see FOG_BUILD), so the patches can drift in as it
	# thickens, and starting them costs no burst of twelve seconds of particles in one frame.
	p.local_coords = false
	p.emitting = false
	var patch := QuadMesh.new()
	patch.size = Vector2(9.0, 9.0)
	# Facing the camera with each patch's own size: a patch that has not drifted in yet has no
	# size and draws nothing. (Drawn full-sized, every waiting patch showed as one black dome over
	# the hero for the first seconds of fog.)
	patch.material = particle_material(Effects._soft_dot(), FACING, true, Color(1, 1, 1, 0.0))
	p.mesh = patch
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(22, 0.6, 16)
	p.direction = Vector3(1, 0, 0.3)
	p.spread = 25.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.8
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.4
	var ramp := Gradient.new()
	ramp.set_color(0, Color(HAZE, 0.0))
	ramp.add_point(0.35, Color(HAZE, 0.1))
	ramp.add_point(0.7, Color(HAZE, 0.1))
	ramp.set_color(ramp.get_point_count() - 1, Color(HAZE, 0.0))
	p.color_ramp = ramp
	Effects.start_cold(p)
	return p


## Shows rain and mist as strong as the look says, darker by night.
static func show_particles(rain: CPUParticles3D, mist: CPUParticles3D, weather_look: Dictionary, light: float, snow: CPUParticles3D = null, winter := false) -> void:
	if snow != null:
		var f: float = weather_look.snow
		# A thin flurry in winter whatever the weather; the heavy fall keeps its own look. The
		# particles' own count only changes between the two (it restarts them), never every frame.
		if winter:
			var want := SNOW_FLAKES if f > WINTER_FLURRY else WINTER_FLAKES
			if snow.amount != want:
				snow.amount = want
				# A new count means a new buffer: blank it, or it shows stray coloured balls.
				Effects.start_cold(snow)
			f = maxf(f, WINTER_FLURRY)
		elif snow.amount != SNOW_FLAKES:
			snow.amount = SNOW_FLAKES
			Effects.start_cold(snow)
		snow.emitting = f > 0.02
		snow.visible = snow.emitting
		# How bright a flake is comes from the light that reaches it (the sun, the moon of tonight's
		# phase, the lamps and the hero's lantern), not from the hour: only the amount falling is set here.
		var snow_mat: ShaderMaterial = (snow.mesh as QuadMesh).material
		snow_mat.set_shader_parameter("albedo", Color(0.92, 0.94, 1.0, 0.9 * f))
	var r: float = weather_look.rain
	rain.emitting = r > 0.02
	rain.visible = rain.emitting
	var shade := clampf(0.12 + light, 0.12, 1.0)
	var rain_mat: ShaderMaterial = (rain.mesh as QuadMesh).material
	# Heavy rain (the storm) falls in smaller, greyer drops; as it fades back to ordinary rain they
	# return to their usual look (see HEAVY_FROM).
	var heavy := smoothstep(HEAVY_FROM, 1.0, r)
	var drop := Color(0.75, 0.82, 0.95).lerp(HEAVY_GREY, heavy * HEAVY_GREYING)
	rain_mat.set_shader_parameter("albedo", Color(drop.r * shade, drop.g * shade, drop.b * shade, 0.45 * r))
	var size := lerpf(1.0, HEAVY_SIZE, heavy)
	rain.scale_amount_min = size
	rain.scale_amount_max = size
	var m: float = weather_look.mist
	mist.emitting = m > 0.02
	mist.visible = mist.emitting
	var mist_mat: ShaderMaterial = (mist.mesh as QuadMesh).material
	# Mist by day is pale. At night it is no brighter than the dark around it (it never lights the
	# scenery up, it only hides it): its brightness follows the light of the hour, which is low.
	var pale := clampf(light * light * 1.6, 0.03, 1.0)
	mist_mat.set_shader_parameter("albedo", Color(pale * 0.95, pale * 0.97, pale, m))
