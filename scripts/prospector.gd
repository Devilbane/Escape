class_name Prospector
extends RefCounted
## Kronprospektor Brandt (map letter ROLE), the Crown's prospector, who stands beside the Crown Office in the
## village. He sells the probe bucket (see Prospecting.BUCKET), takes the filled bucket and tells the hero
## what lies under the spot: the window shows the sample, what it is made of and what the prospector makes
## of it, and every result lands on the hero's map as a mark (see MapView).
## One window (Menus kind KIND) with fixed boxes, so buying, handing over or a refusal only change text.

const ROLE := "ρ"
const KIND := "prospektor"
const WIDTH := 600.0
const STATUS_HEIGHT := 30.0
const RESULT_HEIGHT := 170.0
const HINT_HEIGHT := 80.0
const WINDOW := Vector2(660, 640)
const GREEN := Color(0.6, 0.95, 0.6)
const AMBER := Color(1.0, 0.8, 0.4)


static func _line(menus: Menus, text: String, colour := Color.WHITE) -> Label:
	var l: Label = menus._add_label(text, 20, colour)
	l.custom_minimum_size = Vector2(WIDTH, STATUS_HEIGHT)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return l


static func _box(menus: Menus, text: String, height: float, colour: Color) -> Label:
	var l: Label = menus._add_label(text, 16, colour)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(WIDTH, height)
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return l


static func build(menus: Menus) -> void:
	var game: Node = menus.game
	var p: Prospecting = game.prospecting
	menus._add_label(Lang.t("Amt der Krone: Prospektor"), 38, game.GOLD, game.TITLE_FONT)
	_line(menus, Lang.t("Im Beutel: %d Kupfer") % Payment.worth(game))
	match p.bucket_id():
		Prospecting.FULL:
			_line(menus, Lang.t("Dein Eimer ist voll: %s.") % Prospecting._what(p.sample), GREEN)
		Prospecting.BUCKET:
			_line(menus, Lang.t("Dein Probeneimer ist leer."), AMBER)
		_:
			_line(menus, Lang.t("Du hast keinen Probeneimer."))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	menus._box.add_child(row)
	var can_buy: bool = not p.has_bucket() and Payment.can_pay(game, Prospecting.PRICE)
	var buy: Button = menus._item_button(Lang.t("Probeneimer kaufen (%d Kupfer)") % Prospecting.PRICE, func(): _buy(menus), can_buy)
	buy.custom_minimum_size = Vector2(300, 54)
	row.add_child(buy)
	var give: Button = menus._item_button(Lang.t("Probe abgeben"), func(): _deliver(menus), p.is_full())
	give.custom_minimum_size = Vector2(240, 54)
	row.add_child(give)
	# The result of the last hand-over: what the sample is made of and what he makes of it.
	var last: Dictionary = p.marks.back() if not p.marks.is_empty() else {}
	var shown := Lang.t("Noch keine Probe untersucht. Kauf einen Eimer, geh zu einem Fleck, der dich reizt, nimm eine Probe und bring sie her.")
	var colour := Menus.BLUE
	if not last.is_empty():
		var s: Dictionary = last.sample
		shown = "%s\n%s\n\n%s" % [Lang.t("Letzte Probe (%s, Tag %d):") % [Prospecting._what(s), int(last.day)],
				Prospecting.composition_text(s), Prospecting.report_text(last.report)]
		colour = ProspectGeology.ORE_COLORS.get(str(last.report.ore), Color.WHITE).lerp(Color.WHITE, 0.45)
	_box(menus, shown, RESULT_HEIGHT, colour)
	_box(menus, Lang.t("So geht's: Nimm den Eimer in die Hand (Taste 4). Taste 5 schöpft eine Bodenprobe, und wer gegen einen Berg läuft, wird gefragt, ob er dort eine Probe nehmen will. Das Ergebnis steht danach mit dem Ort auf deiner Karte (Taste N)."), HINT_HEIGHT, Menus.BLUE)


static func _buy(menus: Menus) -> void:
	var game: Node = menus.game
	var why: String = game.prospecting.buy()
	menus._note = Lang.t("Gekauft: %s") % Items.item_name(Prospecting.BUCKET) if why == "" else why
	if why == "":
		Sfx.play_coins(game, 8)
		game._update_hud()
	menus._rebuild()


static func _deliver(menus: Menus) -> void:
	var game: Node = menus.game
	var mark: Dictionary = game.prospecting.deliver()
	if mark.is_empty():
		menus._note = Lang.t("Dein Eimer ist leer.")
	else:
		menus._note = Lang.t("Untersucht. Die Stelle steht auf deiner Karte.")
		Sfx.play(game, "magic", -10.0)
	menus._rebuild()
