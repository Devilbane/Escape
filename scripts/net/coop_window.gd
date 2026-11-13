class_name CoopWindow
extends RefCounted
## The "Play together" window (Menus kind "mitspielen"): host a game on this
## computer or join a friend's, see who is there, and leave again.
##
## Every part has a fixed size, so connecting, a long error or a full list of
## players never reshapes the window: the status line is one line (a longer
## text ends in "…"), the player list is a scroll region of its own, and the
## three buttons are always there, the ones that do not apply now dimmed.

const KIND := "mitspielen"
const WIDTH := 680.0
const STATUS_HEIGHT := 30.0
const LIST_HEIGHT := 128.0
const HINT_HEIGHT := 48.0
const GREEN := Color(0.6, 0.95, 0.6)
const RED := Color(1.0, 0.6, 0.5)


## What the status line says, and in which colour (the words carry the
## meaning; the colour only backs them up).
static func status(session: CoopSession) -> Array:
	match session.mode:
		CoopSession.Mode.HOSTING:
			return [Lang.t("Du bist Gastgeber auf Port %d. Mitspieler: %d") % [session.port, session.others.size()], GREEN]
		CoopSession.Mode.JOINING:
			return [Lang.t("Verbinde mit %s …") % session.address, Menus.BLUE]
		CoopSession.Mode.JOINED:
			return [Lang.t("Verbunden mit %s. Mitspieler: %d") % [session.address, session.others.size()], GREEN]
	match session.problem:
		"port":
			return [Lang.t("Port %d ist belegt oder gesperrt.") % session.port, RED]
		"address":
			return [Lang.t("Diese Adresse geht nicht."), RED]
		"lost":
			return [Lang.t("Die Verbindung ist abgerissen."), RED]
		"version":
			return [Lang.t("Abgewiesen: Ihr habt verschiedene Spielversionen."), RED]
		"name taken":
			return [Lang.t("Abgewiesen: Dort spielt schon ein Held mit deinem Namen."), RED]
		"":
			return [Lang.t("Nicht verbunden."), Menus.ABOUT_COLOR]
	return [Lang.t("Abgewiesen."), RED]


static func build(menus: Menus) -> void:
	var game: Node = menus.game
	var session: CoopSession = game.coop
	var on := session.is_on()
	menus._add_label(Lang.t("Gemeinsam spielen"), 38, game.GOLD, game.TITLE_FONT)
	var said := status(session)
	var line := menus._add_label(said[0], 20, said[1])
	line.custom_minimum_size = Vector2(WIDTH, STATUS_HEIGHT)
	line.clip_text = true
	line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	# Where to: the friend's address (unused when hosting) and the port.
	var fields := HBoxContainer.new()
	fields.alignment = BoxContainer.ALIGNMENT_CENTER
	fields.add_theme_constant_override("separation", 10)
	menus._box.add_child(fields)
	fields.add_child(_caption(game, Lang.t("Adresse")))
	var address := _field(menus, session.address, 300, "127.0.0.1")
	address.editable = not on
	address.text_changed.connect(func(t: String) -> void: session.address = t)
	fields.add_child(address)
	fields.add_child(_caption(game, Lang.t("Port")))
	var port := _field(menus, str(session.port), 110, str(NetProtocol.DEFAULT_PORT))
	port.max_length = 5
	port.editable = not on
	port.text_changed.connect(func(t: String) -> void: session.port = clampi(int(t), 1024, 65535) if t.is_valid_int() else NetProtocol.DEFAULT_PORT)
	fields.add_child(port)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	menus._box.add_child(buttons)
	for b in [[Lang.t("Gastgeber sein"), func() -> void: session.host(session.port), not on],
			[Lang.t("Beitreten"), func() -> void: session.join(session.address, session.port), not on],
			[Lang.t("Verlassen"), session.leave, on]]:
		var button := menus._item_button(b[0], b[1], b[2])
		button.custom_minimum_size = Vector2(210, 60)
		buttons.add_child(button)

	# Who is here: a heading between bronze rules, then a list of fixed height.
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 10)
	heading.custom_minimum_size = Vector2(WIDTH, 32)
	menus._box.add_child(heading)
	for i in 3:
		if i == 1:
			var title: Label = game._make_label(game.TEXT_FONT, 16, game.GOLD)
			title.text = Lang.t("Mitspieler")
			title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			heading.add_child(title)
		else:
			var rule := UiKit.rule()
			rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
			heading.add_child(rule)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(WIDTH, LIST_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menus._box.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var names := []
	if on:
		names.append(Lang.t("%s (du)") % session._hero_name())
		for id in session.others:
			names.append(str(session.others[id]))
	else:
		names.append(Lang.t("Noch niemand. Wer beitritt, steht hier."))
	for n in names:
		var row: Label = game._make_label(game.TEXT_FONT, 18, Menus.BLUE if on else Menus.ABOUT_COLOR)
		row.text = n
		row.clip_text = true
		row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(row)

	var hint := menus._add_label(Lang.t("Im selben Netz gibst du die Adresse des Gastgeber-PCs ein. Von außerhalb muss der Gastgeber den Port (UDP) im Router freigeben. Jeder behält seinen eigenen Spielstand."), 16, Menus.ABOUT_COLOR)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(WIDTH, HINT_HEIGHT)


static func _caption(game: Node, text: String) -> Label:
	var l: Label = game._make_label(game.TEXT_FONT, 18, game.GOLD)
	l.text = text
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


static func _field(menus: Menus, text: String, width: float, placeholder: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.text = text
	edit.placeholder_text = placeholder
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.custom_minimum_size = Vector2(width, 52)
	edit.add_theme_font_override("font", menus.game.TEXT_FONT)
	edit.add_theme_font_size_override("font_size", UiKit.sized(20))
	edit.add_theme_stylebox_override("normal", Menus.panel_style(Color(0.85, 0.66, 0.32, 0.8)))
	edit.add_theme_stylebox_override("focus", Menus.panel_style(menus.game.GOLD))
	edit.add_theme_stylebox_override("read_only", Menus.panel_style(Color(0.5, 0.42, 0.3, 0.6)))
	for style in ["normal", "focus", "read_only"]:
		edit.get_theme_stylebox(style).set_content_margin_all(8)
	return edit
