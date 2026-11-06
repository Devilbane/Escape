class_name DayNight
extends RefCounted
## The clock of the world. One full day, midnight to midnight, takes
## DAY_LENGTH real seconds wherever the hero is, down in the dungeon too
## (there the light is the dungeon's own, and the hour shows on the HUD).
##
## The light follows the hour: a dark night lit only by the moon (as bright
## as its phase allows, see Moon and Game._moonlight), a pink dawn, the warm daylight (the picture the game always had in the open:
## the values of the toned-down look stay the daytime baseline), and a
## golden-red dusk. Between these keyframes everything blends smoothly.

## Real seconds for one day of 24 hours: 20 minutes.
const DAY_LENGTH := 1200.0
## The hour a new game's world starts at, and the hour the hero wakes up
## after a night in the bed.
const START_HOUR := 8.0
const WAKE_HOUR := 7.0
## Night lasts from NIGHT_FROM until NIGHT_UNTIL: the villagers sleep, the
## dead rise on the graveyard and the bandits grow bold. About 7 of the 20
## real minutes.
const NIGHT_FROM := 21.0
const NIGHT_UNTIL := 5.0

## The sky through the day: hour, background, ambient colour and energy,
## sun (or moon) colour and energy, how high it stands (its pitch in
## degrees, for how much light the ground gets, see sun_strength), colour
## saturation, how strongly lamps and windows glow (0 to 1), and how much
## of the light is the moon's (0 to 1). The night is dark: its only light
## is the moon's cold, deep blue, with the colours left full so its bluish
## sheen covers everything. The night keys are the full moon's, lighting
## the ground about half as brightly as the dusk before it; a smaller moon
## dims that (see Moon.light): a half moon to a third, a crescent to next to
## nothing, and the new moon leaves the night nearly pitch black.
const KEYS := [
	{"hour": 0.0, "bg": Color(0.015, 0.03, 0.09), "amb": Color(0.28, 0.42, 1.0), "amb_e": 0.06,
		"sun": Color(0.4, 0.58, 1.0), "sun_e": 0.25, "pitch": -60.0, "sat": 1.05, "glow": 1.0, "moon": 1.0},
	{"hour": 4.5, "bg": Color(0.015, 0.03, 0.09), "amb": Color(0.28, 0.42, 1.0), "amb_e": 0.06,
		"sun": Color(0.4, 0.58, 1.0), "sun_e": 0.25, "pitch": -60.0, "sat": 1.05, "glow": 1.0, "moon": 1.0},
	{"hour": 6.0, "bg": Color(0.5, 0.36, 0.42), "amb": Color(0.78, 0.62, 0.66), "amb_e": 0.4,
		"sun": Color(1.0, 0.62, 0.42), "sun_e": 0.55, "pitch": -20.0, "sat": 0.92, "glow": 0.5, "moon": 0.0},
	# Daylight: exactly the open-air look the game had before the clock.
	{"hour": 7.5, "bg": Color(0.5, 0.46, 0.57), "amb": Color(0.7, 0.68, 0.78), "amb_e": 0.52,
		"sun": Color(1.0, 0.8, 0.6), "sun_e": 0.88, "pitch": -38.0, "sat": 0.95, "glow": 0.0, "moon": 0.0},
	{"hour": 17.5, "bg": Color(0.5, 0.46, 0.57), "amb": Color(0.7, 0.68, 0.78), "amb_e": 0.52,
		"sun": Color(1.0, 0.8, 0.6), "sun_e": 0.88, "pitch": -38.0, "sat": 0.95, "glow": 0.0, "moon": 0.0},
	{"hour": 19.5, "bg": Color(0.55, 0.32, 0.3), "amb": Color(0.8, 0.58, 0.55), "amb_e": 0.42,
		"sun": Color(1.0, 0.52, 0.3), "sun_e": 0.6, "pitch": -16.0, "sat": 0.95, "glow": 0.55, "moon": 0.0},
	{"hour": 21.0, "bg": Color(0.015, 0.03, 0.09), "amb": Color(0.28, 0.42, 1.0), "amb_e": 0.06,
		"sun": Color(0.4, 0.58, 1.0), "sun_e": 0.25, "pitch": -60.0, "sat": 1.05, "glow": 1.0, "moon": 1.0},
	{"hour": 24.0, "bg": Color(0.015, 0.03, 0.09), "amb": Color(0.28, 0.42, 1.0), "amb_e": 0.06,
		"sun": Color(0.4, 0.58, 1.0), "sun_e": 0.25, "pitch": -60.0, "sat": 1.05, "glow": 1.0, "moon": 1.0},
]


## Where the sun (or the moon) stands through the day: from each hour on,
## its pitch and yaw in degrees. It does not wander with the clock: a light
## turning a little every frame makes every shadow shimmer and crawl, so it
## stays put for a whole part of the day (night, dawn, day, dusk) and only
## then swings to its next place, in SUN_SWING hours (about two seconds).
## Each change falls in a dim hour or a soft light, where the swing is
## barely seen. How brightly the ground is lit does not jump with it: that
## still follows the keys' pitch, see sun_strength.
const SUN_STEPS := [
	{"hour": 5.0, "pitch": -20.0, "yaw": -95.0},
	{"hour": 7.0, "pitch": -38.0, "yaw": -35.0},
	{"hour": 18.5, "pitch": -16.0, "yaw": 25.0},
	{"hour": 21.0, "pitch": -60.0, "yaw": 30.0},
]
const SUN_SWING := 0.04


## The hour after `seconds` of real time have passed.
static func advance(hour: float, seconds: float) -> float:
	return fposmod(hour + seconds * 24.0 / DAY_LENGTH, 24.0)


## Whether it is night: the village sleeps and monsters are about.
static func is_night(hour: float) -> bool:
	return hour >= NIGHT_FROM or hour < NIGHT_UNTIL


## The look of the sky at an hour, blended from the two nearest keyframes.
static func sky_at(hour: float) -> Dictionary:
	hour = fposmod(hour, 24.0)
	for i in KEYS.size() - 1:
		var a: Dictionary = KEYS[i]
		var b: Dictionary = KEYS[i + 1]
		if hour >= a.hour and hour <= b.hour:
			var t: float = 0.0 if b.hour <= a.hour else smoothstep(0.0, 1.0, (hour - a.hour) / (b.hour - a.hour))
			var out := {}
			for key in a:
				out[key] = lerp(a[key], b[key], t)
			return out
	return KEYS[0].duplicate()


## How strongly lamps and windows glow at an hour: 0 by day, 1 at night.
static func glow_at(hour: float) -> float:
	return float(sky_at(hour).glow)


## How much of the light at an hour is the moon's: 0 by day, at dusk and
## at dawn, 1 in the dark of the night.
static func moon_at(hour: float) -> float:
	return float(sky_at(hour).moon)


## The sun's (or moon's) pitch and yaw in degrees at an hour, as a Vector3
## for rotation_degrees: still within a part of the day, see SUN_STEPS.
static func sun_angles_at(hour: float) -> Vector3:
	hour = fposmod(hour, 24.0)
	var n := SUN_STEPS.size()
	# The step in force is the last one begun; before the first, the night's.
	var now := n - 1
	for i in n:
		if hour >= SUN_STEPS[i].hour:
			now = i
	var to: Dictionary = SUN_STEPS[now]
	var from: Dictionary = SUN_STEPS[(now + n - 1) % n]
	var since := fposmod(hour - float(to.hour), 24.0)
	var t := smoothstep(0.0, SUN_SWING, since)
	return Vector3(lerpf(from.pitch, to.pitch, t), lerpf(from.yaw, to.yaw, t), 0.0)


## How strongly the light at an hour shines, its energy, standing where
## sun_angles_at puts it: the keys' energy, made stronger or weaker so the
## ground gets as much light as if it stood at the keys' pitch. A low light
## falls flat across the ground and lights it less than a high one, so
## without this the ground grew brighter at once when the dusk's low sun
## gave way to the high moon at nightfall.
static func sun_strength(hour: float) -> float:
	var sky := sky_at(hour)
	var stands := sin(deg_to_rad(-sun_angles_at(hour).x))
	return float(sky.sun_e) * sin(deg_to_rad(-float(sky.pitch))) / maxf(stands, 0.05)


## Lights the open air for an hour of the day.
static func apply(env: Environment, sun: DirectionalLight3D, hour: float) -> void:
	var sky := sky_at(hour)
	env.background_color = sky.bg
	env.ambient_light_color = sky.amb
	env.ambient_light_energy = sky.amb_e
	env.adjustment_saturation = sky.sat
	sun.light_color = sky.sun
	sun.light_energy = sun_strength(hour)
	var angles := sun_angles_at(hour)
	# Only touched when it changes, so the shadows are not redrawn for nothing.
	if not sun.rotation_degrees.is_equal_approx(angles):
		sun.rotation_degrees = angles


## The time as the HUD shows it, e.g. "21:30", in quarter hours.
static func clock_text(hour: float) -> String:
	var minutes := int(fposmod(hour, 24.0) * 60.0) / 15 * 15
	return "%02d:%02d" % [minutes / 60, minutes % 60]


## The part of the day, as a word (German, translated by Lang).
static func part_of_day(hour: float) -> String:
	if is_night(hour):
		return "Nacht"
	if hour < 7.5:
		return "Morgengrauen"
	if hour < 11.0:
		return "Morgen"
	if hour < 17.5:
		return "Tag"
	return "Abend"
