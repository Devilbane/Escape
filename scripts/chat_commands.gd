class_name ChatCommands
extends RefCounted
## The summary of every chat command for the compendium's "Befehle" page: what
## to type, what it does and an example or two. Only the commands that are
## switched on (each has an ENABLED const, see Godmode, Teleport, SkyCommand)
## are listed, so the page never promises a command that is spoken aloud
## instead.
##
## A new chat command adds its entry here. Every text is German and has an
## English entry in scripts/lang/chat_commands.gd; tests/chat_commands.gd
## checks that each entry has a translation.

## One entry per command: its name, the syntax, a short description and
## examples (each example a line to type).
static func entries() -> Array:
	var out := []
	if Godmode.ENABLED:
		out.append({
			"name": "Gottmodus",
			"syntax": Godmode.COMMAND,
			"text": "Unverwundbar und dreifaches Tempo. Noch einmal schreiben schaltet ihn wieder aus.",
			"examples": [Godmode.COMMAND],
		})
	if Teleport.ENABLED:
		out.append({
			"name": "Teleport",
			"syntax": "%s  oder  %s <Code>" % [Teleport.COMMAND, Teleport.COMMAND],
			"text": "Ohne Code listet das Ereignisprotokoll alle Orte mit ihrem Fünf-Buchstaben-Code; der Code in der nächsten Zeile bringt den Helden zum Eingang des Ortes.",
			"examples": [Teleport.COMMAND, "%s %s" % [Teleport.COMMAND, Teleport.VILLAGE_CODE]],
		})
	if SkyCommand.ENABLED:
		out.append({
			"name": "Wetter und Zeit",
			"syntax": "weather:<Wetter>-<Zeit>",
			"text": "Erzwingt Wetter (clear, rain, fog, storm, snow), Tageszeit (dawn, morning, noon, afternoon, dusk, evening, night, midnight oder eine Stunde wie 14 oder 14:30) und Jahreszeit (winter, spring). Jeder Teil geht auch allein; time: ist dasselbe wie weather:. Schnee legt sofort eine volle Schneedecke.",
			"examples": ["weather:rain-noon", "weather:snow", "weather:-night", "time:14:30", "weather:winter"],
		})
		out.append({
			"name": "Himmelstour",
			"syntax": "%s%s  /  %s%s" % [SkyCommand.PREFIXES[0], SkyCommand.TOUR_START, SkyCommand.PREFIXES[0], SkyCommand.TOUR_STOP],
			"text": "Zeigt jedes Wetter eine Minute lang, während die Uhr einen ganzen Tag und eine Nacht durchläuft, und fängt dann von vorn an. Stop oder ein anderer Himmelsbefehl beendet sie.",
			"examples": ["weather:showcase", "weather:stop"],
		})
	return out
