class_name Godmode
extends RefCounted
## The "godmode" command of the chat line (for testing): the hero cannot be
## harmed (no damage, no knockdown, no bleeding, burns or poison, see
## Player.shielded) and runs SPEED_FACTOR times as fast. The factor is applied
## last in Player.refresh_stats, so it stacks on every other speed effect and
## vanishes with the mode. Typing the word again turns it off.
##
## ENABLED is the one switch to gate it, like Teleport.ENABLED.

const ENABLED := true
const COMMAND := "godmode"
## 300 % of the hero's pace.
const SPEED_FACTOR := 3.0
const ON_TEXT := "Gottmodus an: unverwundbar und dreifaches Tempo."
const OFF_TEXT := "Gottmodus aus."


static func is_command(line: String) -> bool:
	return ENABLED and line.strip_edges().to_lower() == COMMAND
