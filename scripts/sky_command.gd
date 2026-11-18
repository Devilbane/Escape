class_name SkyCommand
extends RefCounted
## The weather and time commands of the chat line (for testing): they force
## the weather, the hour, or the season at once, so the look of rain, fog, a
## storm, snow, winter and every time of day can be checked without waiting.
##
##   weather:rain-noon    rain at noon
##   weather:snow         snow now (and a full layer of snow on the ground)
##   weather:-night       the night, the weather stays
##   time:14              14:00 (also "14:30"), the weather stays
##   weather:winter-snow  the winter (day 24 of the year) with snow
##   weather:spring       out of winter (the first day of the next spring)
##
## "weather:" and "time:" are the same command: after the colon come words
## joined by "-", in any order, each one a weather, a season or an hour. Any
## part may be left out. A line that does not parse lists the options.
##
## ENABLED is the one switch to gate it, like Godmode.ENABLED and
## Teleport.ENABLED: off, the line is an ordinary spoken line again.
##
## Every text is German and has an English entry in scripts/lang/sky_command.gd.

const ENABLED := true
const PREFIXES := ["weather:", "time:", "wetter:", "zeit:"]
## The words of each weather (English, as typed; the German names work too).
const WEATHERS := {
	"clear": Weather.CLEAR, "klar": Weather.CLEAR,
	"rain": Weather.RAIN, "regen": Weather.RAIN,
	"fog": Weather.FOG, "nebel": Weather.FOG,
	"storm": Weather.STORM, "gewitter": Weather.STORM,
	"snow": Weather.SNOW, "schnee": Weather.SNOW,
}
## The seasons: winter on, winter off.
const SEASONS := {"winter": true, "spring": false, "summer": false, "frühling": false}
## Named times of day, as an hour.
const TIMES := {
	"dawn": 6.0, "morning": 8.0, "noon": 12.0, "afternoon": 15.0,
	"dusk": 19.5, "evening": 20.0, "night": 23.0, "midnight": 0.0,
}
## How long a forced weather lasts, in hours of the day (5 real minutes).
const HOLD_HOURS := 6.0
## The showcase tour: every weather in turn, each for this many real seconds,
## while the clock sweeps through a whole day and night (midnight to midnight).
const TOUR_START := "showcase"
const TOUR_STOP := "stop"
const TOUR_SECONDS := 60.0
const TOUR_WEATHERS := [Weather.CLEAR, Weather.RAIN, Weather.FOG, Weather.STORM, Weather.SNOW]


## The weather and the hour the tour shows `seconds` after its start.
static func tour_at(seconds: float) -> Dictionary:
	var spell := int(seconds / TOUR_SECONDS)
	return {
		"weather": TOUR_WEATHERS[spell % TOUR_WEATHERS.size()],
		"hour": fposmod(seconds, TOUR_SECONDS) / TOUR_SECONDS * 24.0,
	}
## The first day of winter within a year, and the year (see Weather).
const WINTER_FROM := Weather.YEAR_DAYS - Weather.WINTER_DAYS


## What the line asks for as {"weather": kind or "", "hour": hour or -1.0,
## "winter": -1 (unchanged), 0 or 1}, or {"error": text} when a word is not
## understood, or null when the line is no sky command.
static func parse(line: String) -> Variant:
	if not ENABLED:
		return null
	var lower := line.strip_edges().to_lower()
	var rest := ""
	var found := false
	for prefix in PREFIXES:
		if lower.begins_with(prefix):
			rest = lower.substr(prefix.length())
			found = true
			break
	if not found:
		return null
	var out := {"weather": "", "hour": -1.0, "winter": -1, "tour": ""}
	for word in rest.split("-", false):
		word = word.strip_edges()
		if word == "":
			continue
		if word == TOUR_START or word == TOUR_STOP:
			out.tour = word
		elif WEATHERS.has(word):
			out.weather = WEATHERS[word]
		elif SEASONS.has(word):
			out.winter = 1 if SEASONS[word] else 0
		elif TIMES.has(word):
			out.hour = TIMES[word]
		elif hour_of(word) >= 0.0:
			out.hour = hour_of(word)
		else:
			return {"error": word}
	if out.weather == "" and out.hour < 0.0 and out.winter < 0 and out.tour == "":
		return {"error": ""}
	return out


## "14", "14.5" or "14:30" as an hour from 0 to 24, or -1.0 when it is none.
static func hour_of(word: String) -> float:
	var parts := word.split(":")
	if parts.size() > 2 or not parts[0].is_valid_int():
		return -1.0
	var hour := float(int(parts[0]))
	if parts.size() == 2:
		if not parts[1].is_valid_int() or int(parts[1]) < 0 or int(parts[1]) > 59:
			return -1.0
		hour += int(parts[1]) / 60.0
	elif word.contains("."):
		return -1.0
	if hour < 0.0 or hour >= 24.0:
		return -1.0
	return hour


## The day that starts the wanted season, counting on from `day`: the first
## day of the winter of this year, or the first day of the next year.
static func day_for(day: int, winter: bool) -> int:
	var year_start := day - posmod(day, Weather.YEAR_DAYS)
	if winter:
		return year_start + WINTER_FROM
	return year_start + Weather.YEAR_DAYS


## The options, one line each (German, translated by Lang), for the chat log.
const HELP := [
	"weather:<Wetter>-<Zeit>, z. B. weather:rain-noon. Wetter: clear, rain, fog, storm, snow.",
	"Zeit: dawn, morning, noon, afternoon, dusk, evening, night, midnight oder eine Stunde wie 14 oder 14:30.",
	"Tour: weather:showcase zeigt jedes Wetter eine Minute lang durch einen ganzen Tag und Nacht, weather:stop beendet sie.",
	"Jahreszeit: winter, spring. Jeder Teil geht auch allein: weather:snow, weather:-night, time:noon.",
]
