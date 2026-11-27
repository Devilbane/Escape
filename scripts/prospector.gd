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
const RESULT_HEIGHT := 150.0
const HINT_HEIGHT := 60.0
const WINDOW := Vector2(660, 780)
## The mark whose result the window shows (an index into Prospecting.marks, -1 for the newest).
static var view := -1
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
	if p.analysing():
		_line(menus, Lang.t("Brandt untersucht deine Probe: noch %s.") % _left_text(p.analysis_left()), AMBER)
	else:
		_line(menus, Lang.t("Brandt hat gerade keine Probe auf dem Tisch."))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	menus._box.add_child(row)
	var can_buy: bool = not p.has_bucket() and Payment.can_pay(game, Prospecting.PRICE)
	var buy: Button = menus._item_button(Lang.t("Probeneimer kaufen (%d Kupfer)") % Prospecting.PRICE, func(): _buy(menus), can_buy)
	buy.custom_minimum_size = Vector2(300, 54)
	row.add_child(buy)
	var give: Button = menus._item_button(Lang.t("Probe abgeben"), func(): _deliver(menus), p.is_full() and not p.analysing())
	give.custom_minimum_size = Vector2(240, 54)
	row.add_child(give)
	# The marked results, one at a time: what the sample is made of, what he makes of it and the licence.
	var count: int = p.marks.size()
	var i := clampi(view, 0, maxi(count - 1, 0)) if view >= 0 else count - 1
	var last: Dictionary = p.marks[i] if count > 0 else {}
	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 12)
	menus._box.add_child(nav)
	var prev: Button = menus._item_button("<", func(): _show(menus, i - 1), i > 0)
	prev.custom_minimum_size = Vector2(60, 40)
	nav.add_child(prev)
	var which := Label.new()
	which.text = Lang.t("Probe %d von %d") % [i + 1, count] if count > 0 else Lang.t("Keine Proben")
	which.custom_minimum_size = Vector2(240, 40)
	which.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	which.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nav.add_child(which)
	var next: Button = menus._item_button(">", func(): _show(menus, i + 1), i < count - 1)
	next.custom_minimum_size = Vector2(60, 40)
	nav.add_child(next)
	var shown := Lang.t("Noch keine Probe untersucht. Kauf einen Eimer, geh zu einem Fleck, der dich reizt, nimm eine Probe und bring sie her.")
	var colour := Menus.BLUE
	if not last.is_empty():
		var s: Dictionary = last.sample
		shown = "%s\n%s\n\n%s" % [Lang.t("Probe (%s, Tag %d):") % [Prospecting._what(s), int(last.day)],
				Prospecting.composition_text(s), Prospecting.report_text(last.report)]
		colour = ProspectGeology.ORE_COLORS.get(str(last.report.ore), Color.WHITE).lerp(Color.WHITE, 0.45)
	_box(menus, shown, RESULT_HEIGHT, colour)
	# The mining licence for the plot of this mark: now or later (the mark stays, so he sells it whenever the hero comes back).
	var state: String = p.licence_state(last) if not last.is_empty() else "none"
	var offer := ""
	var offer_colour := Menus.BLUE
	match state:
		"offer":
			offer = Lang.t("Für diese Stelle stelle ich dir eine Schürflizenz aus: %d Kupfer, eingetragen als Schürfgrund in deinem Register. Jetzt oder später, die Stelle läuft dir nicht davon.") % p.licence_price(last)
			offer_colour = GREEN
		"owned":
			offer = Lang.t("Du hältst schon die Lizenz für diese Stelle.")
		"barren":
			offer = Lang.t("Auf taubem Gestein stelle ich keine Lizenz aus.")
		_:
			offer = Lang.t("Hier gibt es keine Lizenz zu kaufen.") if not last.is_empty() else ""
	_box(menus, offer, HINT_HEIGHT, offer_colour)
	var lic := HBoxContainer.new()
	lic.alignment = BoxContainer.ALIGNMENT_CENTER
	lic.add_theme_constant_override("separation", 12)
	menus._box.add_child(lic)
	var price: int = p.licence_price(last) if state == "offer" else 0
	var can_lic: bool = state == "offer" and Payment.can_pay(game, price)
	var take: Button = menus._item_button(Lang.t("Lizenz kaufen (%d Kupfer)") % price if state == "offer" else Lang.t("Lizenz kaufen"), func(): _licence(menus, last), can_lic)
	take.custom_minimum_size = Vector2(300, 54)
	lic.add_child(take)
	var later: Button = menus._item_button(Lang.t("Später"), func(): menus.close(), state == "offer")
	later.custom_minimum_size = Vector2(240, 54)
	lic.add_child(later)
	_box(menus, Lang.t("So geht's: Nimm den Eimer in die Hand (Taste 4). Taste 5 schöpft eine Bodenprobe, und wer gegen einen Berg läuft, wird gefragt, ob er dort eine Probe nehmen will. Das Ergebnis steht danach mit dem Ort auf deiner Karte (Taste N)."), HINT_HEIGHT, Menus.BLUE)


static func _show(menus: Menus, index: int) -> void:
	view = index
	menus._rebuild()


static func _licence(menus: Menus, mark: Dictionary) -> void:
	var game: Node = menus.game
	var why: String = game.prospecting.buy_licence(mark)
	menus._note = Lang.t("Lizenz erworben. Der Schürfgrund steht in deinem Register.") if why == "" else why
	if why == "":
		Sfx.play_coins(game, 12)
	menus._rebuild()


## "5 h 20 min" for the seconds left.
static func _left_text(seconds: float) -> String:
	var minutes := ceili(seconds / 60.0)
	return Lang.t("%d Std. %d Min.") % [minutes / 60, minutes % 60]


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
	var started: Dictionary = game.prospecting.deliver()
	if started.is_empty():
		menus._note = Lang.t("Ich untersuche noch deine andere Probe.") if game.prospecting.analysing() else Lang.t("Dein Eimer ist leer.")
	else:
		view = -1
		menus._note = Lang.t("Ich untersuche die Probe. Komm in einem Tag wieder: Dann hast du das Ergebnis, und ich biete dir die Schürflizenz an.")
		Sfx.play(game, "magic", -10.0)
	menus._rebuild()
