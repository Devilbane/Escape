class_name WritingCard
extends RefCounted
## The card that pops up when the hero notices a writing on a wall (see
## Level.reveal_writing) or reads one again by running into it: a heading,
## the carved word and what it says, in an amber frame like a spotted trap's.
## It does not stop the game and goes by itself.
##
## The card has one fixed size for every writing and language, at the
## bottom centre, above the controls help: the writing itself is on a north
## wall, above the hero on screen, and stays in view; so do the hero and
## the first steps' cards at the top. While it shows, messages go just
## above it (see Game.show_message).

const CARD_WIDTH := 560.0
## Room for this many lines of text, enough for every writing in both
## languages, so a shorter text does not make the card smaller.
const TEXT_LINES := 3
const TEXT_SIZE := 18
const WORD_SIZE := 28
## Distance of the card's lower edge from the bottom of the screen, clear
## of the controls help.
const BOTTOM := 104.0
## Space between the card and a message above it.
const GAP := 12.0
const FADE := 0.25
## A card stays at least this long; longer texts get READ_PER_CHAR more per
## character (UX: about 1 s plus 60 ms per character).
const MIN_SHOW := 6.0
const READ_PER_CHAR := 0.06

var game: Node
var card: PanelContainer
var _word: Label
var _text: Label
var _tween: Tween


func _init(owner_game: Node) -> void:
	game = owner_game


## Builds the card on the HUD; it starts hidden.
func setup(hud: CanvasLayer) -> void:
	card = PanelContainer.new()
	var style := Menus.panel_style(Level.WRITING_COLOR)
	style.set_content_margin_all(14)
	style.content_margin_left = 24
	style.content_margin_right = 24
	card.add_theme_stylebox_override("panel", style)
	card.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	card.offset_left = -CARD_WIDTH / 2.0
	card.offset_right = CARD_WIDTH / 2.0
	card.offset_top = -BOTTOM
	card.offset_bottom = -BOTTOM
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.modulate.a = 0.0
	card.visible = false
	hud.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	var heading: Label = game._make_label(game.TEXT_FONT, 16, Color(1, 1, 1, 0.7))
	heading.text = Lang.t("Inschrift")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)
	_word = game._make_label(game.TEXT_FONT, WORD_SIZE, Level.WRITING_COLOR)
	_word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_word)
	_text = game._make_label(game.TEXT_FONT, TEXT_SIZE)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var line: float = game.TEXT_FONT.get_height(UiKit.sized(TEXT_SIZE)) + _text.get_theme_constant("line_spacing")
	_text.custom_minimum_size = Vector2(CARD_WIDTH - 48, ceilf(line * TEXT_LINES))
	box.add_child(_text)


## The carved word of a wall writing (German), or "" for any other text,
## such as a rune tablet of the dwarves, which keeps the plain message.
static func word_of(text: String) -> String:
	for w in Level.WRITINGS:
		if w[1] == text:
			return w[0]
	return ""


## Shows a wall writing (its German text, one of Level.WRITINGS).
func show_writing(text: String) -> void:
	if card == null:
		return
	var word := word_of(text)
	_word.text = Lang.t(word)
	_text.text = Lang.t(text)
	card.visible = true
	# A message already on screen moves up out of the card's way.
	game.place_message()
	if _tween:
		_tween.kill()
	_tween = card.create_tween()
	_tween.tween_property(card, "modulate:a", 1.0, FADE)
	_tween.tween_interval(maxf(MIN_SHOW, 1.0 + READ_PER_CHAR * _text.text.length()))
	_tween.tween_property(card, "modulate:a", 0.0, FADE)
	_tween.tween_callback(func():
		card.visible = false
		game.place_message())


## How far above the bottom of the screen a message must sit to clear the
## card while it shows (0 when it does not).
func clearance() -> float:
	return BOTTOM + card.get_combined_minimum_size().y + GAP if showing() else 0.0


## Whether the card is on screen.
func showing() -> bool:
	return card != null and card.visible


## Takes the card away at once (a new level was loaded).
func hide_now() -> void:
	if _tween:
		_tween.kill()
	if card:
		card.modulate.a = 0.0
		card.visible = false
		game.place_message()
