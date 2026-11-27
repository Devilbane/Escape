class_name OwnMine
extends RefCounted
## The hero's own mine in the world (rules: MineWork, deeds: MineClaims). On the hero's mining plot (see
## Plots.MINING) stands a claim post, a station: without a mine, running into it opens one over a prospecting
## mark that lies on the plot (one mine per plot); with a mine, it leads down into the instanced mine floor
## (the map "Deine Mine", building ID). At the face of that floor (a station) a window (KIND) holds the work:
## hammer and chisel, fire-setting with timber and a bucket of water in hard rock, timber supports, and hauling
## the broken rock up in a bucket. Every action is stored at once, so the mine is as the hero left it.

const ID := "eigenmine"
## The station on the plot and the one at the face.
const POST := "schuerfpfahl"
const FACE := "stollenort"
const KIND := "stollenort"
const WINDOW := Vector2(660, 600)
const WIDTH := 600.0
const TIMBER := "bauholz"
const WATER := "wassereimer"
## The tile of the face on the mine's map.
const FACE_CELL := Vector2i(16, 3)
const GREEN := Color(0.6, 0.95, 0.6)
const AMBER := Color(1.0, 0.8, 0.4)


static func _rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.randomize()
	return r


## The plot the hero works in now (a Rect2i with size zero when none).
static var plot := Rect2i()


## Puts a claim post on every mining plot of the hero (after the open map is built).
static func attach(game: Node, level: Level) -> void:
	if not level is Outdoor:
		return
	for d: Dictionary in Plots.plots_of(game.hero_name):
		if d.kind != Plots.MINING:
			continue
		var rect: Rect2i = d.rect
		var cell := rect.position + rect.size / 2
		var pos := level.cell_to_world(cell)
		level.stations.append({"kind": POST, "cell": cell, "pos": pos, "reach": 2.6, "used": false, "rect": rect})


## Puts the face of the mine into the mine floor (after it is built).
static func build_face(game: Node, level: Level) -> void:
	if level.building != ID:
		return
	var pos := level.cell_to_world(FACE_CELL)
	level.stations.append({"kind": FACE, "cell": FACE_CELL, "pos": pos, "reach": 2.6, "used": false})


## The hero ran into the claim post.
static func use_post(game: Node, s: Dictionary) -> void:
	var rect: Rect2i = s.rect
	game.player.face(s.pos - game.player.global_position)
	game.player.play("Idle")
	if not MineClaims.has_mine(rect):
		var why := MineClaims.open(game.hero_name, rect, game.prospecting.marks, Time.get_unix_time_from_system())
		match why:
			"":
				Events.tell(Lang.t("Dein Stollen ist angeschlagen. Du darfst jetzt unter dem Schürfgrund graben."), game.GOLD)
			"mark":
				game.show_message(Lang.t("Auf diesem Schürfgrund liegt noch keine Probe. Nimm hier eine Bergprobe und bring sie zum Prospektor."), 4.0)
				return
			"barren":
				game.show_message(Lang.t("Die Probe von hier ist taubes Gestein: Hier lohnt kein Stollen."), 4.0)
				return
			_:
				return
	var mine := MineClaims.on_plot(rect)
	var made := MineClaims.catch_up(rect, Time.get_unix_time_from_system(), _rng())
	if made > 0:
		Events.tell(Lang.t("Dein Schlägel hat in deiner Abwesenheit %d Vortriebe geschafft.") % made, AMBER)
	plot = rect
	# The open map is parked while the hero is down, so the way back out is set now.
	game.level.doors[ID] = s.pos + Vector3(0, 0, Level.TILE)
	game.go_inside(ID)


static func prompt(game: Node, s: Dictionary) -> String:
	if MineClaims.has_mine(s.rect):
		return Lang.t("Dagegenlaufen, um in deine Mine einzufahren")
	return Lang.t("Dagegenlaufen, um hier einen Stollen anzuschlagen")


# --- The window at the face ---------------------------------------------------------------------------

static func _count(game: Node, id: String) -> int:
	return game.player.bag.count(id)


static func _take(game: Node, id: String) -> void:
	var i: int = game.player.bag.find(id)
	if i >= 0:
		game.player.bag.remove_at(i)


static func _line(menus: Menus, text: String, colour := Color.WHITE) -> Label:
	var l: Label = menus._add_label(text, 20, colour)
	l.custom_minimum_size = Vector2(WIDTH, 30.0)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return l


static func _shares_text(shares: Dictionary) -> String:
	var parts := []
	var ores := shares.keys()
	ores.sort_custom(func(a: String, b: String) -> bool: return float(shares[a]) > float(shares[b]))
	for ore: String in ores:
		if float(shares[ore]) >= 0.005:
			parts.append("%s %.1f %%" % [Lang.t(ProspectGeology.ORES[ore]), float(shares[ore]) * 100.0])
	return ", ".join(parts) if not parts.is_empty() else Lang.t("kein Erz")


static func build(menus: Menus) -> void:
	var game: Node = menus.game
	var mine := MineClaims.on_plot(plot)
	menus._add_label(Lang.t("Am Ort"), 38, game.GOLD, game.TITLE_FONT)
	if mine.is_empty():
		_line(menus, Lang.t("Hier ist kein Stollen."))
		return
	var hard := MineWork.is_hard(mine)
	_line(menus, Lang.t("Gestein: %s. %d Vortriebe, %d Stützen") % [ProspectGeology.ROCK_NAMES.get(str(mine.rock), "?"), int(mine.advances), int(mine.supports)])
	var need := MineWork.needs_support(mine)
	_line(menus, Lang.t("Der Stollen braucht eine Stütze.") if need else Lang.t("Der Stollen steht sicher."), AMBER if need else GREEN)
	_line(menus, Lang.t("Am Ort liegen %d kg Haufwerk, auf der Halde %d kg") % [roundi(float(mine.face)), roundi(float(mine.stock_mass))])
	var box: Label = menus._add_label(Lang.t("Erzgehalt am Ort: %s\nHalde: %s") % [_shares_text(mine.shares), _shares_text(MineWork.stock_shares(mine))], 16, Menus.BLUE)
	box.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.custom_minimum_size = Vector2(WIDTH, 110.0)
	box.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var warn := Lang.t("Dieses Gestein ist zu hart für Schlägel und Eisen. Du musst das Feuer selbst setzen: Es braucht Bauholz und einen Wassereimer, und der Fels springt erst, wenn du ihn abschreckst.") if hard else Lang.t("Mit Schlägel und Eisen geht es voran, auch wenn du fort bist: ein Vortrieb je 4 Stunden, höchstens 4 Stunden am Tag.")
	var hint: Label = menus._add_label(warn, 16, AMBER if hard else Menus.BLUE)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(WIDTH, 80.0)
	hint.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	menus._box.add_child(row)
	var hammer: Button = menus._item_button(Lang.t("Schlägel und Eisen"), func(): _work(menus, "hammer"), not hard and not need)
	hammer.custom_minimum_size = Vector2(190, 54)
	row.add_child(hammer)
	var can_fire: bool = hard and not need and _count(game, TIMBER) > 0 and _count(game, WATER) > 0
	var fire: Button = menus._item_button(Lang.t("Feuer setzen"), func(): _work(menus, "fire"), can_fire)
	fire.custom_minimum_size = Vector2(190, 54)
	row.add_child(fire)
	var prop: Button = menus._item_button(Lang.t("Stütze setzen"), func(): _support(menus), need and _count(game, TIMBER) > 0)
	prop.custom_minimum_size = Vector2(190, 54)
	row.add_child(prop)
	var haul: Button = menus._item_button(Lang.t("Eimer hochziehen"), func(): _haul(menus), float(mine.face) > 0.0)
	haul.custom_minimum_size = Vector2(300, 54)
	menus._box.add_child(haul)


static func _work(menus: Menus, how: String) -> void:
	var game: Node = menus.game
	var mine := MineClaims.on_plot(plot)
	if how == "fire":
		if _count(game, TIMBER) <= 0 or _count(game, WATER) <= 0:
			menus._note = Lang.t("Dir fehlt Bauholz oder ein Wassereimer.")
			menus._rebuild()
			return
	var out := MineWork.advance(mine, how, _rng())
	if out.ok:
		if how == "fire":
			_take(game, TIMBER)
			Sfx.play(game, "rumble", -6.0)
			menus._note = Lang.t("Der Fels springt: Du hast %d kg Gestein gelöst.") % roundi(out.rock)
		else:
			Sfx.play(game, "chop")
			menus._note = Lang.t("Du schlägst %d kg Gestein los.") % roundi(out.rock)
		mine["seen"] = Time.get_unix_time_from_system()
		MineClaims.update(plot, mine)
	else:
		menus._note = out.why
	menus._rebuild()


static func _support(menus: Menus) -> void:
	var game: Node = menus.game
	var mine := MineClaims.on_plot(plot)
	if _count(game, TIMBER) <= 0:
		menus._note = Lang.t("Dir fehlt Bauholz.")
	elif MineWork.support(mine):
		_take(game, TIMBER)
		MineClaims.update(plot, mine)
		Sfx.play(game, "chop", -2.0)
		menus._note = Lang.t("Du setzt eine Stütze.")
	menus._rebuild()


static func _haul(menus: Menus) -> void:
	var mine := MineClaims.on_plot(plot)
	var moved := MineWork.haul(mine, MineWork.BUCKET_LOAD)
	if moved > 0.0:
		MineClaims.update(plot, mine)
		menus._note = Lang.t("Ein Eimer Haufwerk liegt auf der Halde.")
	menus._rebuild()
