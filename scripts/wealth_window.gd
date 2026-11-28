class_name WealthWindow
extends RefCounted
## The wealth window (Menus kind "vermoegen", opened by the "Financial report" button in banker Goldwin's window, the bank): what the hero is worth in
## one sum, in which part of the belongings it lies, and the chart of that sum over the days (see Wealth,
## WealthChart). The window keeps one size: the chart, the range buttons and the cards never change theirs, and a
## range that holds fewer than two days says so inside the chart instead of leaving it out.

const KIND := "vermoegen"
const SIZE := Vector2(800, 640)
const WIDTH := 700.0
const CARD := Vector2(166, 66)
const RANGES := [["7", 7, "7 Tage"], ["30", 30, "30 Tage"], ["all", 0, "Alle Tage"]]
const GREY := Color(0.75, 0.72, 0.68)
const GOOD := Color(0.4, 0.92, 0.4)
const BAD := Color(1.0, 0.38, 0.32)
## The part names, German (translated when shown).
const PART_NAMES := {"purse": "Münzen bei dir", "carried": "Bei dir getragen", "home": "Daheim verwahrt", "bank": "Auf der Bank"}
const PART_TIPS := {
	"purse": "Kupfer-, Silber- und Goldmünzen, die du bei dir trägst.",
	"carried": "Was Händler für deine Tasche und deine Ausrüstung zahlen würden.",
	"home": "Was Händler für die Lagertruhe und die Truhen, Fässer und Regale in deinem Haus zahlen würden, samt der Münzen darin.",
	"bank": "Dein Guthaben und der Inhalt deines Schließfachs.",
}

## The range last chosen stays chosen between visits.
static var range_key := "30"


static func build(menus: Menus) -> void:
	var game: Node = menus.game
	var now := Wealth.compute(game)
	Wealth.record(game.wealth_log, game.day, int(now.total))
	menus._add_label(Lang.t("Vermögen"), 38, game.GOLD, game.TITLE_FONT)
	var total: Label = menus._add_label(Loot.worth_text(int(now.total), 0, 0), 24, game.GOLD)
	total.custom_minimum_size = Vector2(WIDTH, 34)
	total.clip_text = true
	total.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	total.tooltip_text = Lang.t("Münzen und Verkaufswert aller Dinge, die du besitzt, in Kupfer: %s") % Wealth.grouped(int(now.total))
	total.mouse_filter = Control.MOUSE_FILTER_PASS
	_add_cards(menus, now)
	_add_ranges(menus)
	var days := 0
	for r in RANGES:
		if r[0] == range_key:
			days = r[1]
	var readings := Wealth.window(game.wealth_log, days)
	var chart := WealthChart.new()
	chart.setup(readings, game.TEXT_FONT, Lang.t("Das Diagramm füllt sich mit jedem neuen Morgen."))
	chart.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menus._box.add_child(chart)
	_add_stats(menus, readings)


## One card per part of the total: its name and its copper, a tooltip says what it holds.
static func _add_cards(menus: Menus, now: Dictionary) -> void:
	var game: Node = menus.game
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	menus._box.add_child(row)
	for part in Wealth.PARTS:
		var card := PanelContainer.new()
		card.custom_minimum_size = CARD
		card.add_theme_stylebox_override("panel", UiKit.frame_style(Color(0.05, 0.035, 0.03, 0.6), Color(0.45, 0.3, 0.15, 0.8), 2, 6))
		card.tooltip_text = Lang.t(PART_TIPS[part])
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 2)
		card.add_child(box)
		var name: Label = game._make_label(game.TEXT_FONT, 16, GREY)
		name.text = Lang.t(PART_NAMES[part])
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(name)
		var value: Label = game._make_label(game.TEXT_FONT, 18, Color(1.0, 0.8, 0.4))
		value.text = Lang.t("%s Kupfer") % Wealth.grouped(int(now[part]))
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.clip_text = true
		value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		box.add_child(value)
		row.add_child(card)


## The three range buttons: the chosen one is lit, the others calm, all the same size.
static func _add_ranges(menus: Menus) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	menus._box.add_child(row)
	for r in RANGES:
		var b: Button = menus._item_button(Lang.t(r[2]), _choose.bind(menus, r[0]))
		b.custom_minimum_size = Vector2(150, 44)
		b.modulate = Color(1.0, 0.9, 0.6) if range_key == r[0] else Color(0.75, 0.75, 0.8)
		row.add_child(b)


static func _choose(menus: Menus, key: String) -> void:
	range_key = key
	menus._rebuild()


## The numbers under the chart, as text: the change over the range, the peak and the low.
static func _add_stats(menus: Menus, readings: Array) -> void:
	var line := ""
	var color := GREY
	if readings.size() >= 2:
		var first := int(readings[0][1])
		var last := int(readings.back()[1])
		var peak := 0
		var low := last
		for p in readings:
			peak = maxi(peak, int(p[1]))
			low = mini(low, int(p[1]))
		var change := last - first
		var sign := "+" if change > 0 else ("−" if change < 0 else "")
		line = Lang.t("Veränderung: %s Kupfer     Höchststand: %s     Tiefstand: %s") % [
				sign + Wealth.grouped(absi(change)), Wealth.grouped(peak), Wealth.grouped(low)]
		color = GOOD if change > 0 else (BAD if change < 0 else GREY)
	var label: Label = menus._add_label(line, 16, color)
	label.custom_minimum_size = Vector2(WIDTH, 26)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
