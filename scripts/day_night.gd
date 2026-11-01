class_name DayNight
extends RefCounted
## The clock of the world above ground. One full day, midnight to midnight,
## takes DAY_LENGTH real seconds while the hero is in the open air or inside
## a village building; down in the dungeon the clock stands still and the
## light is the dungeon's own.
##
## The light follows the hour: a cool blue night with a pale moon, a pink
## dawn, the warm daylight (the picture the game always had in the open:
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
## sun (or moon) colour and energy, its pitch and yaw in degrees, colour
## saturation, and how strongly lamps and windows glow (0 to 1).
const KEYS := [
	{"hour": 0.0, "bg": Color(0.05, 0.06, 0.12), "amb": Color(0.42, 0.5, 0.78), "amb_e": 0.3,
		"sun": Color(0.62, 0.7, 0.95), "sun_e": 0.32, "pitch": -60.0, "yaw": 30.0, "sat": 0.8, "glow": 1.0},
	{"hour": 4.5, "bg": Color(0.05, 0.06, 0.12), "amb": Color(0.42, 0.5, 0.78), "amb_e": 0.3,
		"sun": Color(0.62, 0.7, 0.95), "sun_e": 0.32, "pitch": -60.0, "yaw": 30.0, "sat": 0.8, "glow": 1.0},
	{"hour": 6.0, "bg": Color(0.5, 0.36, 0.42), "amb": Color(0.78, 0.62, 0.66), "amb_e": 0.4,
		"sun": Color(1.0, 0.62, 0.42), "sun_e": 0.55, "pitch": -20.0, "yaw": -95.0, "sat": 0.92, "glow": 0.5},
	# Daylight: exactly the open-air look the game had before the clock.
	{"hour": 7.5, "bg": Color(0.5, 0.46, 0.57), "amb": Color(0.7, 0.68, 0.78), "amb_e": 0.52,
		"sun": Color(1.0, 0.8, 0.6), "sun_e": 0.88, "pitch": -38.0, "yaw": -70.0, "sat": 0.95, "glow": 0.0},
	{"hour": 17.5, "bg": Color(0.5, 0.46, 0.57), "amb": Color(0.7, 0.68, 0.78), "amb_e": 0.52,
		"sun": Color(1.0, 0.8, 0.6), "sun_e": 0.88, "pitch": -38.0, "yaw": 0.0, "sat": 0.95, "glow": 0.0},
	{"hour": 19.5, "bg": Color(0.55, 0.32, 0.3), "amb": Color(0.8, 0.58, 0.55), "amb_e": 0.42,
		"sun": Color(1.0, 0.52, 0.3), "sun_e": 0.6, "pitch": -16.0, "yaw": 25.0, "sat": 0.95, "glow": 0.55},
	{"hour": 21.0, "bg": Color(0.05, 0.06, 0.12), "amb": Color(0.42, 0.5, 0.78), "amb_e": 0.3,
		"sun": Color(0.62, 0.7, 0.95), "sun_e": 0.32, "pitch": -60.0, "yaw": 30.0, "sat": 0.8, "glow": 1.0},
	{"hour": 24.0, "bg": Color(0.05, 0.06, 0.12), "amb": Color(0.42, 0.5, 0.78), "amb_e": 0.3,
		"sun": Color(0.62, 0.7, 0.95), "sun_e": 0.32, "pitch": -60.0, "yaw": 30.0, "sat": 0.8, "glow": 1.0},
]


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


## Lights the open air for an hour of the day.
static func apply(env: Environment, sun: DirectionalLight3D, hour: float) -> void:
	var sky := sky_at(hour)
	env.background_color = sky.bg
	env.ambient_light_color = sky.amb
	env.ambient_light_energy = sky.amb_e
	env.adjustment_saturation = sky.sat
	sun.light_color = sky.sun
	sun.light_energy = sky.sun_e
	sun.rotation_degrees = Vector3(sky.pitch, sky.yaw, 0)


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
