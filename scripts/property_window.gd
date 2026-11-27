class_name PropertyWindow
extends RefCounted
## The property register read out by the Crown clerk (Menus kind "besitz", opened from PlotOffice): every
## plot, house, mining ground and rented house the hero has, in sections (see PropertyRegister). The window
## keeps one size: a title, a status line and a list of fixed height that scrolls, so a longer register only
## lengthens the scrolling. Sections stay put and are never folded; one with nothing in it says so.

const KIND := "besitz"
const SIZE := Vector2(660, 600)
const WIDTH := 600.0
const LIST_HEIGHT := 340.0
const CARD_HEIGHT := 68.0
const TAG_WIDTH := 130.0
const GREY := Color(0.75, 0.72, 0.68)
const AMBER := Color(1.0, 0.8, 0.4)


static func build(menus: Menus) -> void:
	var game: Node = menus.game
	var hero: String = game.hero_name
	PropertyRegister.leave_rental(hero)
	menus._add_label(Lang.t("Besitzverzeichnis"), 38, game.GOLD, game.TITLE_FONT)
	var status: Label = menus._add_label(Lang.t("%d Besitztümer eingetragen") % PropertyRegister.count(hero, game.level), 20, Color.WHITE)
	status.custom_minimum_size = Vector2(WIDTH, 30)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(WIDTH, LIST_HEIGHT)
	menus._box.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var first := true
	for section in PropertyRegister.SECTIONS:
		if not first:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, 8)
			list.add_child(gap)
		first = false
		var head: Label = game._make_label(game.TITLE_FONT, 20, game.GOLD)
		head.text = Lang.t(section.title)
		list.add_child(head)
		list.add_child(UiKit.rule())
		var rows := PropertyRegister.rows(section.key, hero, game.level)
		if rows.is_empty():
			var none: Label = game._make_label(game.TEXT_FONT, 16, GREY)
			none.text = Lang.t(section.empty)
			list.add_child(none)
		for row in rows:
			list.add_child(_card(game, row))
	var back: Button = menus._item_button(Lang.t("Zurück zum Grundbuch"), menus.open.bind(PlotOffice.KIND))
	back.custom_minimum_size = Vector2(300, 54)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menus._box.add_child(back)


## One property: its name and the line that describes it on the left, its kind on the right.
static func _card(game: Node, row: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, CARD_HEIGHT)
	card.add_theme_stylebox_override("panel", UiKit.frame_style(Color(0.05, 0.035, 0.03, 0.6), Color(0.45, 0.3, 0.15, 0.8), 2, 6))
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	card.add_child(margin)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	margin.add_child(line)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 4)
	line.add_child(text)
	var title: Label = game._make_label(game.TEXT_FONT, 18, AMBER)
	title.text = row.title
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(title)
	var detail: Label = game._make_label(game.TEXT_FONT, 16, Color.WHITE)
	detail.text = row.detail
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size = Vector2(WIDTH - TAG_WIDTH - 70, 0)
	text.add_child(detail)
	var tag: Label = game._make_label(game.TEXT_FONT, 16, GREY)
	tag.text = row.tag
	tag.custom_minimum_size = Vector2(TAG_WIDTH, 0)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(tag)
	return card
