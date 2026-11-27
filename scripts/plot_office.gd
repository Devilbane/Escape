class_name PlotOffice
extends RefCounted
## The land registry at the Crown Office (Menus kind "grundbuch"), run by the
## clerk Amtmann Gero. A hero who wants to build marks a plot out on the grass
## (see PlotMarker), then registers it here for a fee that grows with its area
## (see Plots.FEE_PER_TILE), as many plots as Plots.MAX_PER_HERO. The clerk also reads out
## everything the hero owns or rents (see PropertyWindow). The window keeps one layout: the
## three status lines and the hint box have fixed heights, so marking, registering or a refusal
## only changes their text.

const KIND := "grundbuch"
const WIDTH := 560.0
const STATUS_HEIGHT := 30.0
const HINT_HEIGHT := 96.0
const GREEN := Color(0.6, 0.95, 0.6)
const AMBER := Color(1.0, 0.8, 0.4)


static func _line(menus: Menus, text: String, colour := Color.WHITE) -> void:
	var l: Label = menus._add_label(text, 20, colour)
	l.custom_minimum_size = Vector2(WIDTH, STATUS_HEIGHT)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


static func build(menus: Menus) -> void:
	var game: Node = menus.game
	var hero: String = game.hero_name
	var marker: PlotMarker = game.plot_marker
	var owned := Plots.plots_of(hero).size()
	var full := Plots.at_limit(hero)
	var pending: Rect2i = marker.pending if marker != null else Rect2i()
	var has_pending := pending.size != Vector2i.ZERO
	menus._add_label(Lang.t("Amt der Krone: Grundbuch"), 38, game.GOLD, game.TITLE_FONT)
	_line(menus, Lang.t("Im Beutel: %d Kupfer") % Payment.worth(game))
	if owned > 0:
		_line(menus, Lang.t("Grundstücke auf deinen Namen: %d") % owned, GREEN)
	else:
		_line(menus, Lang.t("Du besitzt noch kein Grundstück."))
	if full:
		_line(menus, Lang.t("Mehr als %d Grundstücke vergibt die Krone nicht.") % Plots.MAX_PER_HERO, AMBER)
	elif has_pending:
		_line(menus, Lang.t("Abgesteckt: %d x %d Felder. Gebühr: %d Kupfer.") % [pending.size.x, pending.size.y, Plots.fee(pending)], AMBER)
	else:
		_line(menus, Lang.t("Noch nichts abgesteckt."))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	menus._box.add_child(row)
	var mark: Button = menus._item_button(Lang.t("Land abstecken"), func(): _mark(menus), not full)
	mark.custom_minimum_size = Vector2(240, 54)
	row.add_child(mark)
	var can_pay: bool = has_pending and not full and Payment.can_pay(game, Plots.fee(pending))
	var label := Lang.t("Eintragen lassen") if not has_pending else Lang.t("Eintragen lassen (%d Kupfer)") % Plots.fee(pending)
	var register: Button = menus._item_button(label, func(): _register(menus), can_pay)
	register.custom_minimum_size = Vector2(300, 54)
	row.add_child(register)
	var property: Button = menus._item_button(Lang.t("Besitzverzeichnis"), menus.open.bind(PropertyWindow.KIND))
	property.custom_minimum_size = Vector2(300, 54)
	property.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menus._box.add_child(property)
	var hint: Label = menus._add_label(Lang.t("So geht's: Schnur nehmen, zwei gegenüberliegende Ecken auf blanker Wiese anklicken (%d x %d bis %d x %d Felder), dann hier eintragen lassen. Die Gebühr beträgt %d Kupfer je Feld.") % [Plots.MIN_SIDE, Plots.MIN_SIDE, Plots.MAX_SIDE, Plots.MAX_SIDE, Plots.FEE_PER_TILE], 16, Menus.BLUE)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(WIDTH, HINT_HEIGHT)


static func _mark(menus: Menus) -> void:
	var game: Node = menus.game
	menus.close()
	if game.plot_marker == null:
		return
	game.plot_marker.begin()
	game.show_message(Lang.t("Klicke eine Ecke deines Grundstücks auf der Wiese. Esc bricht ab."), 4.0)


static func _register(menus: Menus) -> void:
	var game: Node = menus.game
	var marker: PlotMarker = game.plot_marker
	var rect := marker.pending
	var fee := Plots.fee(rect)
	if not Payment.can_pay(game, fee):
		menus._note = Lang.t("Dafür reicht dein Kupfer nicht.")
		menus._rebuild()
		return
	var why := Plots.register(game.level, game.hero_name, rect)
	if why != "":
		marker.pending = Rect2i()
		marker.refresh()
		menus._note = PlotMarker.reason(why)
		menus._rebuild()
		return
	Payment.pay(game, fee)
	Events.bus().plot_registered.emit(rect)
	marker.pending = Rect2i()
	marker.refresh()
	Sfx.play_coins(game, mini(fee, 20))
	Events.tell(Lang.t("Das Grundstück ist eingetragen: %d x %d Felder für %d Kupfer.") % [rect.size.x, rect.size.y, fee], AMBER)
	var deed: Dictionary = Plots.plots_of(game.hero_name).back()
	menus._note = Lang.t("Eingetragen als Grundstück %d, %s.") % [deed.n, PropertyRegister.area_name(deed.area)]
	game._update_hud()
	# The purse and the deed must agree, or the fee could be paid twice.
	game.save_game()
	menus._rebuild()
