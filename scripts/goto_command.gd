class_name GotoCommand
extends RefCounted
## The goto command of the chat line (for testing): it takes the hero to an exact tile of a
## place, in an exact season and at an exact time of day, so a change can be looked at under
## the very conditions it was made for. The build review page puts such a line on each entry.
##
##   goto <code> <x> <y> [season] [time]
##   goto dorfx 149 127 autumn 14:30
##   goto            (alone) writes the line for where the hero stands now into the event log
##                   and copies it to the clipboard, to paste into a report
##
## <code> is a place's five-letter teleport code (see Teleport), <x> and <y> the tile column and
## row that F2 shows (see HeroCoords). The season is spring, summer, autumn or winter (see
## SkyCommand), the time an hour like 14 or 14:30 or a named time such as noon. Season and time
## may be left out (they then stay as they are) and come in either order.
##
## ENABLED is the one switch to gate it, like Teleport.ENABLED: off, the line is spoken aloud.
##
## Every text is German and has an English entry in scripts/lang/goto_command.gd.

const ENABLED := true
const COMMAND := "goto"


## What the line asks for: null when it is no goto command, {} for the bare word, {"error": text}
## when a word is not understood, else {"code": text, "cell": Vector2i, "season": name or "",
## "hour": hour or -1.0}.
static func parse(line: String) -> Variant:
	if not ENABLED:
		return null
	var words := line.strip_edges().to_lower().split(" ", false)
	if words.is_empty() or words[0] != COMMAND:
		return null
	if words.size() == 1:
		return {}
	if words.size() < 4 or not words[2].is_valid_int() or not words[3].is_valid_int():
		return {"error": ""}
	var out := {"code": words[1], "cell": Vector2i(int(words[2]), int(words[3])), "season": "", "hour": -1.0}
	for i in range(4, words.size()):
		var word: String = words[i]
		if SkyCommand.SEASON_WORDS.has(word):
			out.season = SkyCommand.SEASON_WORDS[word]
		elif SkyCommand.TIMES.has(word):
			out.hour = SkyCommand.TIMES[word]
		elif SkyCommand.hour_of(word) >= 0.0:
			out.hour = SkyCommand.hour_of(word)
		else:
			return {"error": word}
	return out


## The line that brings a hero to `cell` of the place with `code`, in `season` at `hour`.
static func line(code: String, cell: Vector2i, season: String, hour: float) -> String:
	return "%s %s %d %d %s %s" % [COMMAND, code, cell.x, cell.y, season, DayNight.clock_text(hour)]
