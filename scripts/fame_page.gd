class_name FamePage
extends RefCounted
## The "Fame" page of the quests window (see Fame): the four ratings as four cards of one size, one under the other.
## A card holds the rating's name and, at the right, its level and title; a bar of the way to the next level; what the
## rating is made of; and a line on how to climb on. Nothing on a card changes the card's size (long texts are
## shortened or wrap inside the room kept for them), so the page keeps its layout whatever the hero has done.

const WIDTH := 740.0
const CARD_HEIGHT := 116.0
const CARD_GAP := 6
const BAR_HEIGHT := 10.0
const GREY := Color(0.75, 0.72, 0.68)
const HINT := Color(0.62, 0.78, 0.95)


static func build(menus: Menus, parent: Control) -> void:
	var game: Node = menus.game
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", CARD_GAP)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(list)
	for rating in Fame.ratings(game):
		list.add_child(_card(game, rating))


static func _card(game: Node, rating: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(WIDTH, CARD_HEIGHT)
	card.add_theme_stylebox_override("panel", UiKit.frame_style(Color(0.05, 0.035, 0.03, 0.6), Color(0.45, 0.3, 0.15, 0.8), 2, 6))
	card.tooltip_text = _tip(rating)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	card.add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	box.add_child(top)
	var name: Label = game._make_label(game.TEXT_FONT, 21, game.GOLD)
	name.text = rating.name
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(name)
	var level: Label = game._make_label(game.TEXT_FONT, 18, Color.WHITE)
	level.text = Lang.t("Stufe %d: %s") % [rating.level, rating.title]
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	level.custom_minimum_size.x = 330
	level.clip_text = true
	level.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(level)
	box.add_child(_bar(game, float(rating.progress)))
	box.add_child(_line(game, rating.detail, GREY, 20.0))
	var hint := _line(game, rating.hint, HINT, 38.0)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	return card


## What the card says when pointed at: the next level and how far off it is.
static func _tip(rating: Dictionary) -> String:
	if rating.next == "":
		return Lang.t("Höchste Stufe erreicht.")
	return Lang.t("Nächste Stufe: %s (%d %%)") % [rating.next, roundi(float(rating.progress) * 100.0)]


## The way to the next level: a bar of one height, full at the top level.
static func _bar(game: Node, share: float) -> Control:
	var holder := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		holder.add_theme_constant_override("margin_" + side, game.BAR_RIM)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = share
	bar.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", game.bar_back())
	bar.add_theme_stylebox_override("fill", game.bar_fill([Color("ffe58a"), Color("e0b33a"), Color("a87a18")]))
	bar.add_child(game.bar_rim())
	holder.add_child(bar)
	return holder


## A line of text in a box of one height: it shortens or wraps within it.
static func _line(game: Node, text: String, colour: Color, height: float) -> Label:
	var l: Label = game._make_label(game.TEXT_FONT, 16, colour)
	l.text = text
	l.custom_minimum_size = Vector2(WIDTH - 24, height)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	return l
