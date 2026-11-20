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
## Rain lasts long when it comes (it is rare, see RAIN_KEEP): twice as long as fog or a storm.
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

## How likely each weather is to come next, by part of the day. The
## weather never repeats (see roll), so after clear skies these weights only
## pick which bad weather comes; after bad weather, clear skies win most
## rolls.
const CHANCES := {
	"night": {CLEAR: 8.0, RAIN: 1.0, FOG: 2.0, STORM: 1.0},
	"morning": {CLEAR: 8.0, RAIN: 0.75, FOG: 2.5, STORM: 0.25},
	"day": {CLEAR: 14.0, RAIN: 1.5, FOG: 0.5, STORM: 0.5},
	"evening": {CLEAR: 8.0, RAIN: 1.25, FOG: 0.5, STORM: 1.5},
}

## The year: WINTER_DAYS of winter at the end of every YEAR_DAYS days (a new game starts on day
## 0, so the first winter comes on day 24). Snow falls only in winter, and there is no rain and no
## thunderstorm then: snow comes in their place, often, and the snow on the ground stays until spring.
const YEAR_DAYS := 32
const WINTER_DAYS := 8
const WINTER_CHANCES := {
	"night": {CLEAR: 6.0, FOG: 2.0, SNOW: 5.0},
	"morning": {CLEAR: 6.0, FOG: 2.5, SNOW: 4.0},
	"day": {CLEAR: 8.0, FOG: 0.5, SNOW: 5.0},
	"evening": {CLEAR: 6.0, FOG: 0.5, SNOW: 5.0},
}
## In winter the snow on the ground does not melt in dry weather at all: it lies until spring.

## Rain is only a thirtieth as common as the weights above would make it: a roll
## that lands on rain keeps it with this chance, and otherwise goes on to
## another weather (fog, a storm, or clear skies after bad weather).
const RAIN_KEEP := 1.0 / 30.0

## The look of each weather, laid over the light of the hour: how much of
## the sun (or moon) and of the ambient light is left, the colour
## saturation, how thick the fog is, how hard it rains (0 to 1) and how much
## mist drifts over the ground (0 to 1). The fog is only a thin haze all
## over; the thick part of it hangs in drifting clouds (see FogClouds), which
## `mist` sets the thickness of.
const LOOKS := {
	CLEAR: {"sun": 1.0, "amb": 1.0, "sat": 1.0, "fog": 0.0, "rain": 0.0, "mist": 0.0, "snow": 0.0},
	RAIN: {"sun": 0.5, "amb": 0.85, "sat": 0.8, "fog": 0.006, "rain": 0.55, "mist": 0.0, "snow": 0.0},
	FOG: {"sun": 0.55, "amb": 1.05, "sat": 0.7, "fog": 0.007, "rain": 0.0, "mist": 1.0, "snow": 0.0},
	STORM: {"sun": 0.3, "amb": 0.7, "sat": 0.62, "fog": 0.01, "rain": 1.0, "mist": 0.0, "snow": 0.0},
	SNOW: {"sun": 0.6, "amb": 1.0, "sat": 0.75, "fog": 0.005, "rain": 0.0, "mist": 0.0, "snow": 1.0},
}
## The colour of fog and haze in full daylight; at night it darkens with
## the ambient light.
const HAZE := Color(0.66, 0.68, 0.72)
## How long the look takes to move most of the way to a new weather
## (real seconds).
const FADE := 5.0

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


## Picks the next weather for an hour of the day. It is never the same as
## the weather before, so every change can be seen.
static func roll(hour: float, rng: RandomNumberGenerator, before := "", winter := false) -> String:
	var chances: Dictionary = (WINTER_CHANCES if winter else CHANCES)[part_of_day(hour)]
	var pick := _pick(chances, rng, before, "")
	if pick == RAIN and rng.randf() >= RAIN_KEEP:
		pick = _pick(chances, rng, before, RAIN)
	return pick


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


## Whether `day` (the game's count of days) is in winter (see YEAR_DAYS).
static func is_winter(day: int) -> bool:
	return posmod(day, YEAR_DAYS) >= YEAR_DAYS - WINTER_DAYS


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
	env.fog_density = weather_look.fog
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
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.billboard_keep_scale = true
	mat.albedo_color = Color(0.75, 0.82, 0.95, 0.0)
	streak.material = mat
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
	leaves.material.albedo_color = Color(tone, tone, tone, 0.9 * strength)


## Soft grey patches of mist that drift slowly over the ground.
static func make_mist() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = MIST_PATCHES
	p.lifetime = 12.0
	p.preprocess = 12.0
	p.local_coords = false
	p.emitting = false
	var patch := QuadMesh.new()
	patch.size = Vector2(9.0, 9.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = Effects._soft_dot()
	mat.albedo_color = Color(1, 1, 1, 0.0)
	mat.no_depth_test = false
	patch.material = mat
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
	var rain_mat: StandardMaterial3D = (rain.mesh as QuadMesh).material
	rain_mat.albedo_color = Color(0.75 * shade, 0.82 * shade, 0.95 * shade, 0.45 * r)
	var m: float = weather_look.mist
	mist.emitting = m > 0.02
	mist.visible = mist.emitting
	var mist_mat: StandardMaterial3D = (mist.mesh as QuadMesh).material
	# Mist by day is pale. At night it is no brighter than the dark around it (it never lights the
	# scenery up, it only hides it): its brightness follows the light of the hour, which is low.
	var pale := clampf(light * light * 1.6, 0.03, 1.0)
	mist_mat.albedo_color = Color(pale * 0.95, pale * 0.97, pale, m)
