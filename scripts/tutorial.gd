class_name Tutorial
extends RefCounted
## The first steps in the cell (the first dungeon level): one short card at a
## time explains walking, running, the dagger, the throwing knives, sneaking
## (and how to stop) and jumping.
##
## Each card stays until the hero has done what it says (but at least
## MIN_SHOW seconds, so it can be read) or MAX_SHOW seconds have passed. Then
## it says "Done!" for a moment when the hero did it, fades out, and after a
## pause of GAP seconds the next card comes.
##
## The cards are explanatory hints like the others (see Game._hint): each
## counts in Game.hints_shown under "tut_<id>". A card the hero acted on is
## learned at once; one that only timed out shows again on a later visit,
## up to Game.HINT_SHOWINGS times. A new game clears the hints, so a new hero
## gets the whole tutorial.
##
## The card has one fixed size for every step and language, at the lower
## left under the event log, out of the way of the HUD, the hero, the prompts
## in the middle and the messages at the bottom.

## The steps in order: id, title and text (German, translated with Lang.t),
## and how the hero shows it is understood.
const STEPS := [
	{"id": "move", "title": "Gehen", "text": "Gehe mit W A S D oder den Pfeiltasten. Oder klicke auf den Boden, dann gehst du dorthin."},
	{"id": "run", "title": "Rennen", "text": "Halte Umschalt oder die linke Maustaste gedrückt, um zu rennen. Rennen kostet Atem: Sieh auf den Balken oben links."},
	{"id": "melee", "title": "Nahkampf", "text": "Drücke F oder J, um mit dem Dolch zuzuschlagen. Oder laufe gegen einen Gegner oder klicke ihn an."},
	{"id": "throw", "title": "Wurfmesser", "text": "Drücke R oder K, oder klicke rechts dorthin, wohin das Messer fliegen soll. Wie viele du hast, steht unter deinem Lebensbalken."},
	{"id": "sneak", "title": "Schleichen", "text": "Drücke C oder doppelklicke, um zu schleichen: langsamer und lautlos. Im Dunkeln sieht dich keiner."},
	{"id": "sneak_off", "title": "Grau und durchsichtig?", "text": "Grau und durchsichtig heißt: Du schleichst. Drücke wieder C oder doppelklicke, um normal zu gehen."},
	{"id": "jump", "title": "Springen", "text": "Drücke die Leertaste, um zu springen. Mit Anlauf springst du weiter; beim Rennen mit der Maus springt ein Rechtsklick."},
]

## Seconds to wait after the level's name has faded before the first card.
const START_DELAY := 1.0
## A card stays at least this long, even when the hero acts at once.
const MIN_SHOW := 2.5
## A card the hero does not act on goes after this many seconds.
const MAX_SHOW := 12.0
## How long "Done!" shows before the card fades.
const DONE_SHOW := 0.9
## The pause between two cards, with no card on screen.
const GAP := 1.5
## Fading in and out (seconds).
const FADE := 0.25
## Metres the hero has to walk to finish the first card.
const MOVE_DISTANCE := 2.5
## Seconds the hero has to run to finish the second card.
const RUN_TIME := 0.6
## The card's fixed width; its text has room for TEXT_LINES lines, enough
## for every step in both languages.
## On the event log's left edge, a little wider than the log so the
## longest step still fits in a few lines.
const CARD_WIDTH := 360.0
const TEXT_LINES := 5
const TEXT_SIZE := 16
## The step's title and the top line ("First steps 3 / 7", "Done!").
const TITLE_SIZE := 18
const TOP_SIZE := 15
## Space between the event log and the card below it.
const CARD_GAP := 8.0
const DONE_COLOR := Color(0.55, 0.95, 0.5)

var game: Node
var card: PanelContainer
var _counter: Label
var _done_label: Label
var _title: Label
var _text: Label

## The step on screen (index into STEPS), or -1 between steps and when idle.
var step := -1
## Seconds the current step has been shown, or the pause has lasted.
var _clock := 0.0
## The hero did what the card says; "Done!" shows.
var _done := false
## Seconds of pause before the next card; -1 while not started.
var _waiting := -1.0
## The last step shown in this visit to the cell, and whether every step
## has had its turn (then nothing more comes until the next visit).
var _last := -1
var _visit_over := false
## How many cards were shown in this visit.
var _shown := 0
## What the hero has done during the current card.
var _walked := 0.0
var _ran := 0.0
var _last_pos := Vector3.INF
var _was_sneaking := false
var _acted := {}


func _init(owner_game: Node) -> void:
	game = owner_game


## Builds the card on the HUD; it starts hidden.
func setup(hud: CanvasLayer) -> void:
	card = PanelContainer.new()
	var style := Menus.panel_style(game.GOLD)
	style.set_content_margin_all(12)
	style.content_margin_left = 16
	style.content_margin_right = 16
	card.add_theme_stylebox_override("panel", style)
	# At the lower left, right under the event log and on its left edge,
	# clear of the messages in the middle and the hero.
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	card.position = Vector2(EventLog.LEFT, EventLog.TOP + EventLog.HEIGHT + CARD_GAP)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.modulate.a = 0.0
	card.visible = false
	hud.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	# Top line: which step of how many, and "Done!" once the hero did it.
	# "Done!" is always there (empty until needed), so nothing moves.
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(top)
	_counter = game._make_label(game.TEXT_FONT, TOP_SIZE, Color(1, 1, 1, 0.7))
	_counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_counter)
	_done_label = game._make_label(game.TEXT_FONT, TOP_SIZE, DONE_COLOR)
	_done_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(_done_label)
	_title = game._make_label(game.TEXT_FONT, TITLE_SIZE, game.GOLD)
	box.add_child(_title)
	_text = game._make_label(game.TEXT_FONT, TEXT_SIZE)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Room for TEXT_LINES lines from the start, so a shorter text does not
	# make the card smaller.
	var line: float = game.TEXT_FONT.get_height(UiKit.sized(TEXT_SIZE)) + _text.get_theme_constant("line_spacing")
	_text.custom_minimum_size = Vector2(CARD_WIDTH - 32, ceilf(line * TEXT_LINES))
	_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	box.add_child(_text)


## Whether the tutorial belongs here: the first dungeon level, while playing
## with no window open.
func _here() -> bool:
	var level = game.level
	if level == null or game.player == null or game.player.dead:
		return false
	if game.level_index != 0 or level.outdoor or level.building != "":
		return false
	return game.state == game.State.PLAYING and not game.menus.is_open() and game._shrine.is_empty()


func _learned(index: int) -> bool:
	return int(game.hints_shown.get("tut_" + STEPS[index].id, 0)) >= game.HINT_SHOWINGS


## The next step not learned yet after `after`, or -1.
func _next(after: int) -> int:
	for i in range(after + 1, STEPS.size()):
		if not _learned(i):
			return i
	return -1


## Whether any step is left to show.
func pending() -> bool:
	return _next(-1) != -1


## Called every frame by the game.
func update(delta: float) -> void:
	if card == null:
		return
	if game.level_index != 0 or game.level == null or game.level.outdoor or game.level.building != "":
		# Left the cell: whatever was on screen goes, and starts afresh on a
		# later visit.
		if step != -1 or _waiting >= 0.0 or _visit_over:
			restart()
		return
	if not _here():
		# A window or a shrine pauses the tutorial; the card hides meanwhile.
		card.visible = false
		return
	card.visible = card.modulate.a > 0.0 or step != -1
	if step == -1:
		_wait(delta)
		return
	_watch(delta)
	_clock += delta
	if _done:
		if _clock >= DONE_SHOW:
			_finish()
		return
	if _clock >= MIN_SHOW and _did_it():
		_done = true
		_clock = 0.0
		game.hints_shown["tut_" + STEPS[step].id] = game.HINT_SHOWINGS
		# No sound of its own: Sfx.play draws from the shared random numbers,
		# and the tutorial must not change how the rest of a run plays out.
		_done_label.text = Lang.t("Geschafft!")
	elif _clock >= MAX_SHOW:
		_finish()


## Between cards: waits for the level's name to fade, then for the pause.
func _wait(delta: float) -> void:
	if _visit_over:
		return
	if _waiting < 0.0:
		if game._message_busy() or not pending():
			return
		_waiting = GAP - START_DELAY
	_waiting += delta
	if _waiting < GAP:
		return
	var next := _next(_last)
	if next != -1:
		_show(next)
		return
	_visit_over = true
	_waiting = -1.0
	if _shown > 0:
		game.show_message(Lang.t("Alle Tasten findest du im Kompendium (H)."), 3.0)


func _show(index: int) -> void:
	step = index
	_shown += 1
	_clock = 0.0
	_done = false
	_walked = 0.0
	_ran = 0.0
	_last_pos = game.player.global_position
	_was_sneaking = game.player.sneaking
	_acted.clear()
	var key: String = "tut_" + STEPS[index].id
	game.hints_shown[key] = int(game.hints_shown.get(key, 0)) + 1
	_counter.text = Lang.t("Erste Schritte %d / %d") % [index + 1, STEPS.size()]
	_done_label.text = ""
	_title.text = Lang.t(STEPS[index].title)
	_text.text = Lang.t(STEPS[index].text)
	card.visible = true
	card.create_tween().tween_property(card, "modulate:a", 1.0, FADE)


## The current card goes; the pause before the next one begins.
func _finish() -> void:
	_last = step
	step = -1
	_waiting = 0.0
	card.create_tween().tween_property(card, "modulate:a", 0.0, FADE)


## Takes the card away at once and forgets this visit: called when a level
## is loaded (a new game, or coming back), and when the hero leaves the cell.
func restart() -> void:
	if card == null:
		return
	step = -1
	_waiting = -1.0
	_last = -1
	_visit_over = false
	_shown = 0
	_acted.clear()
	card.modulate.a = 0.0
	card.visible = false


## Keeps track of what the hero does while a card shows.
func _watch(delta: float) -> void:
	var p: Player = game.player
	var pos := p.global_position
	if _last_pos != Vector3.INF:
		var flat := Vector2(pos.x - _last_pos.x, pos.z - _last_pos.z).length()
		# A jump to another place (stairs, loading) is no walk.
		if flat < 2.0:
			_walked += flat
	_last_pos = pos
	if p.sprinting:
		_ran += delta
	if p.sneaking and not _was_sneaking:
		_acted["sneak_on"] = true
	elif _was_sneaking and not p.sneaking:
		_acted["sneak_off"] = true
	_was_sneaking = p.sneaking


## Whether the hero did what the current card says.
func _did_it() -> bool:
	match STEPS[step].id:
		"move":
			return _walked >= MOVE_DISTANCE
		"run":
			return _ran >= RUN_TIME
		"sneak":
			return _acted.has("sneak_on") or game.player.sneaking
		"sneak_off":
			return _acted.has("sneak_off")
		var action:
			return _acted.has(action)


## The hero struck, threw a knife or jumped (see Events.hero_acted).
func on_hero_acted(action: String) -> void:
	_acted[action] = true
