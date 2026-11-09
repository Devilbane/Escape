class_name Needs
extends RefCounted
## What a craft, forge or building job needs and what is missing, in the one
## form every such window uses: a short line per material, "✓ Iron 3/3" when
## the hero has enough and "✗ Iron 1/3 · 2 missing" when not. Colour and the
## ✓/✗ mark and the word say it twice, so colour is never the only cue.


## One material as a [text, colour] pair (the card lines of TradeWindow).
static func line(material: String, have: int, need: int) -> Array:
	if have >= need:
		return ["✓ %s %d/%d" % [material, need, need], TradeWindow.GREEN]
	return [Lang.t("✗ %s %d/%d · %d fehlen") % [material, have, need, need - have], TradeWindow.RED]


## A label for one material line, for windows that are not a TradeWindow.
static func label(game: Node, material: String, have: int, need: int, size := 16) -> Label:
	var l: Array = line(material, have, need)
	var out: Label = game._make_label(game.TEXT_FONT, size, l[1])
	out.text = l[0]
	# A line is short and never wraps: a wrapping label inside a flow container
	# collapses to a single letter per line (the flow gives it no width to wrap
	# at), so the flow moves a whole line to the next row instead.
	out.autowrap_mode = TextServer.AUTOWRAP_OFF
	return out
