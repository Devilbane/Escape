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
## lights up the whole world for a moment.

const CLEAR := "clear"
const RAIN := "rain"
const FOG := "fog"
const STORM := "storm"
const KINDS := [CLEAR, RAIN, FOG, STORM]

## How many hours of the day one spell of rain, fog or storm lasts, at
## least and at most (one hour is 50 real seconds, see DayNight.DAY_LENGTH).
const MIN_HOURS := 1.5
const MAX_HOURS := 3.5
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

## The look of each weather, laid over the light of the hour: how much of
## the sun (or moon) and of the ambient light is left, the colour
## saturation, how thick the fog is, how hard it rains (0 to 1) and how much
## mist drifts over the ground (0 to 1).
const LOOKS := {
	CLEAR: {"sun": 1.0, "amb": 1.0, "sat": 1.0, "fog": 0.0, "rain": 0.0, "mist": 0.0},
	RAIN: {"sun": 0.5, "amb": 0.85, "sat": 0.8, "fog": 0.006, "rain": 0.55, "mist": 0.0},
	FOG: {"sun": 0.55, "amb": 1.05, "sat": 0.7, "fog": 0.022, "rain": 0.0, "mist": 1.0},
	STORM: {"sun": 0.3, "amb": 0.7, "sat": 0.62, "fog": 0.01, "rain": 1.0, "mist": 0.0},
}
## The colour of fog and haze in full daylight; at night it darkens with
## the ambient light.
const HAZE := Color(0.66, 0.68, 0.72)
## How long the look takes to move most of the way to a new weather
## (real seconds).
const FADE := 5.0

## Rain drops at full strength, and the box around the hero they fall in.
const RAIN_DROPS := 700
const RAIN_BOX := Vector3(22, 0.5, 16)
const RAIN_HEIGHT := 16.0
## Drifting patches of mist at full strength.
const MIST_PATCHES := 28


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
static func roll(hour: float, rng: RandomNumberGenerator, before := "") -> String:
	var chances: Dictionary = CHANCES[part_of_day(hour)]
	var total := 0.0
	for kind in chances:
		if kind != before:
			total += chances[kind]
	var pick := rng.randf() * total
	for kind in chances:
		if kind == before:
			continue
		pick -= chances[kind]
		if pick <= 0.0:
			return kind
	return CLEAR if before != CLEAR else RAIN


## How many hours a new spell of weather lasts: clear skies stay longer
## than rain, fog or a storm.
static func spell(rng: RandomNumberGenerator, kind := RAIN) -> float:
	if kind == CLEAR:
		return rng.randf_range(CLEAR_MIN_HOURS, CLEAR_MAX_HOURS)
	return rng.randf_range(MIN_HOURS, MAX_HOURS)


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
	return p


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
	ramp.add_point(0.35, Color(HAZE, 0.22))
	ramp.add_point(0.7, Color(HAZE, 0.22))
	ramp.set_color(ramp.get_point_count() - 1, Color(HAZE, 0.0))
	p.color_ramp = ramp
	return p


## Shows rain and mist as strong as the look says, darker by night.
static func show_particles(rain: CPUParticles3D, mist: CPUParticles3D, weather_look: Dictionary, light: float) -> void:
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
	mist_mat.albedo_color = Color(shade, shade, shade, m)
