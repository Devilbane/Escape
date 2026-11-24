class_name Spooknortz
extends RefCounted
## Spooknortz, the revenant of the village sewers, and the secrets down there.
##
## He lies in a hidden den under the sewers' southern chamber, behind a wall of loose bricks (WALL):
## from the chamber it looks like any other wall, only the bricks are a shade off, there is rubble at
## its foot and a draught moves the dust. The hero runs into it and it gives way. Behind it a short
## passage leads to his den. By day he rests there; at night he is out in the village stealing, so
## the den is empty (and the bundle of stolen goods he keeps there grows). He is not evil, and the
## hero chooses (all in one window, see build): trade with him (his wares are stolen and cheap), listen
## to him (rumours), fetch back the stolen goods for the villagers (a task for Dorfvorsteher Aldo, see
## Quests QUEST), befriend him with a small gift, or fight him.
##
## A second secret: loose bricks in the northern chamber hide a few walled-up coins (NICHE).
##
## What the hero has done is kept as compendium entries in the saved game's lore (the texts below).
## The den is dug with the rest of the sewers (see Sewers.DEN); until the wall gives way a veil of dark
## stone hides it from the cutaway view.

const KIND := "spooknortz"
const WALL := "sewer_wall"
const NICHE := "sewer_niche"
const THIEF := "sewer_thief"
const KINDS := [KIND, WALL, NICHE, THIEF]

const NAME := "Spooknortz"
## The enemy kind his body is (a revenant: a ghoul, raised from a grave).
const BODY := "ghul"
## The wall of loose bricks: the passage's first cell, in the south wall of the chamber over it.
const WALL_CELL := Vector2i(4, 56)
## The loose bricks in the northern chamber's north wall: the cell in front of them and the wall's way.
const NICHE_CELL := Vector2i(7, 17)
const NICHE_FACING := Vector2i(0, -1)
## The passage behind the wall and the den.
const PASSAGE := [Vector2i(4, 56), Vector2i(4, 57)]
const DEN := Rect2i(1, 58, 7, 4)
## Where Spooknortz stands in the den.
const SPOT := Vector2i(4, 60)
## What the walled-up coins come to [least, most].
const NICHE_COINS := [28, 44]
## What his wares cost, in times their worth: a friend pays less.
const MARKUP := 2.0
const FRIEND_MARKUP := 1.5
## What he asks for his friendship, in copper.
const GIFT := 15
## His wares: stolen goods. Item ids.
const WARES := ["amulett_tempo", "amulett_kraft", "schattenamulett"]
## The task of the stolen goods (see Quests.ALL) and its item.
const QUEST := "spook_diebesgut"
const BUNDLE := "diebesgut"

## What the hero learns, word for word (compendium entries; they also stand for what is done).
const DEN_FOUND := "Spooknortz' Versteck: Hinter einer brüchigen Ziegelwand im Kanal liegt die Höhle des Wiedergängers Spooknortz. Tagsüber ruht er dort, nachts schleicht er ins Dorf und stiehlt, was nicht niet- und nagelfest ist."
const MET := "Spooknortz, der Wiedergänger: Ein Toter, der nicht liegen bleibt. Er hehlt, was er nachts im Dorf stiehlt, und ist nicht so böse, wie er aussieht. Man kann mit ihm handeln, ihm zuhören, ihm das Diebesgut für die Dörfler abnehmen, sich mit ihm anfreunden oder ihn bekämpfen."
const FRIEND := "Spooknortz ist dein Freund: Er verkauft dir seine Ware billiger."
const SLAIN := "Spooknortz ist zu Staub zerfallen. Sein Versteck im Kanal ist verwaist."
const NICHE_FOUND := "Münzen im Mauerwerk: Hinter lockeren Ziegeln in der Kammer im Norden der Kanalisation hatte jemand Münzen eingemauert."
## His rumours, one at a time, in this order (each is learned as an entry).
const TALES := [
	"Spooknortz erzählt: „Ich war einmal ein Dörfler wie du. Jetzt klaue ich Äpfel und Kerzen, und keiner merkt, dass ich tot bin.“",
	"Spooknortz erzählt: „In der Kammer ganz im Norden hat ein Maurer einmal Münzen in die Wand gesteckt. Such nach Ziegeln, die nicht ganz passen.“",
	"Spooknortz erzählt: „Das Ungeziefer in den Kammern kommt immer wieder. Lauf nur im Kreis, dann ist es zurück, wenn du das nächste Mal vorbeikommst.“",
]

const WALL_PROMPT := "Dagegenlaufen, um die lockere Wand aufzubrechen"
const TALK_PROMPT := "Dagegenlaufen, um mit Spooknortz zu reden"
const THIEF_PROMPT := "Dagegenlaufen, um den Dieb zu stellen"
const NICHE_PROMPT := "Dagegenlaufen, um die lockeren Ziegel zu lösen"
const WALL_OPENED := "Die lockeren Ziegel kippen zur Seite. Dahinter führt ein niedriger Gang weiter, und von dort riecht es nach Kerzenwachs."
const NICHE_OPENED := "Die Ziegel lösen sich. Dahinter liegen Münzen, so lange vergessen, dass sie grün angelaufen sind."
const AWAY := "Das Lager ist leer, die Decke noch warm. Spooknortz streift nachts durch das Dorf. Komm bei Tag wieder."
const GONE := "Hier liegt nur noch Staub."

const WINDOW := Vector2(660, 690)
const WIDTH := 600.0
const ROW_HEIGHT := 46.0
const SPEECH_HEIGHT := 112.0
const GOLD := Color(1.0, 0.82, 0.4)
const BLUE := Color(0.7, 0.82, 1.0)

## Whether the wall has given way this session (it also does when the lore says so, see sync).
static var opened := false
## Whether the walled-up coins are gone (also when the lore says so).
static var plundered := false
static var _figure: Enemy = null
static var _hostile := false
static var _wall_mesh: Node3D = null
static var _wall_shape: CollisionShape3D = null
static var _veil: Node3D = null
## What he says now in the window (empty: his greeting).
static var _said := ""


## A hint under the hero's feet for the stations here, "" for any other kind.
static func prompt(kind: String) -> String:
	match kind:
		WALL:
			return Lang.t(WALL_PROMPT)
		KIND:
			return Lang.t(TALK_PROMPT)
		NICHE:
			return Lang.t(NICHE_PROMPT)
		THIEF:
			return Lang.t(THIEF_PROMPT)
	return ""


# --- The state ------------------------------------------------------------------

static func slain(game: Node) -> bool:
	return game.lore.has(SLAIN)


## Whether he is out for blood: the hero chose to fight him.
static func hostile() -> bool:
	return _hostile


static func friends(game: Node) -> bool:
	return game.lore.has(FRIEND)


static func _night(game: Node) -> bool:
	return bool(game.level.get("night"))


## The den's state brought in line with the hero's saved lore (once the sewers are drawn).
static func sync(game: Node) -> void:
	if game.lore.has(DEN_FOUND) and not opened:
		opened = true
		_swing_wall(true)
	if game.lore.has(NICHE_FOUND):
		plundered = true


## Down in the sewers (every frame the hero is): Spooknortz rests in his den by day, behind a wall
## the hero has opened, and is out at night.
static func tend(game: Node) -> void:
	sync(game)
	var wanted: bool = opened and not _night(game) and not slain(game)
	var here := _figure != null and is_instance_valid(_figure)
	if here and (_figure.dead or _figure.level != game.level):
		if _figure.dead:
			_figure = null
			return
		_figure = null
		here = false
	if wanted and not here and not _hostile:
		_figure = _spawn(game.level)
	elif not wanted and here and not _hostile:
		_figure.queue_free()
		_figure = null


static func _spawn(level: Level) -> Enemy:
	var e := Enemy.new()
	e.kind = BODY
	e.custom = {"title": NAME}
	e.level = level
	level.add_child(e)
	e.global_position = Sewers.floor_at(SPOT)
	e.reset_physics_interpolation()
	# At rest: he does nothing, and nobody can strike at him (he is not on the level's list of foes).
	e.set_physics_process(false)
	return e


## The hero ran into the wall, Spooknortz or the loose bricks.
static func use(game: Node, s: Dictionary) -> void:
	game.player.face(s.pos - game.player.global_position)
	match s.kind:
		WALL:
			if opened:
				return
			opened = true
			s["used"] = true
			Events.teach(DEN_FOUND)
			Sfx.play(game, "secret", -4.0)
			_swing_wall(false)
			game.show_message(Lang.t(WALL_OPENED), 5.0, GOLD)
		NICHE:
			if plundered:
				return
			plundered = true
			s["used"] = true
			Events.teach(NICHE_FOUND)
			Sfx.play(game, "secret", -4.0)
			game.show_message(Lang.t(NICHE_OPENED), 4.0, GOLD)
			game.level.coins_collected.emit(randi_range(NICHE_COINS[0], NICHE_COINS[1]), CoinPile.MONEY, 0)
		THIEF:
			# Caught in the village at night (see SpookRaid).
			var raid = game.level.get("spook_raid")
			if raid != null:
				raid.caught(game)
		KIND:
			if slain(game):
				game.show_message(Lang.t(GONE), 3.0)
			elif _figure == null or not is_instance_valid(_figure) or _hostile:
				game.show_message(Lang.t(AWAY), 4.0)
			else:
				game.player.play("Idle")
				_said = ""
				game.menus.open(KIND)


## The wall tips aside and the veil over the den lifts (at once when `quick`).
static func _swing_wall(quick: bool) -> void:
	if _wall_shape != null and is_instance_valid(_wall_shape):
		_wall_shape.set_deferred("disabled", true)
	if _veil != null and is_instance_valid(_veil):
		_veil.visible = false
	if _wall_mesh == null or not is_instance_valid(_wall_mesh):
		return
	if quick:
		_wall_mesh.visible = false
		return
	var tween := _wall_mesh.create_tween()
	tween.tween_property(_wall_mesh, "position:y", _wall_mesh.position.y - HouseSketch.DEPTH, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): _wall_mesh.visible = false)


# --- The window -------------------------------------------------------------------

## His window (Menus kind KIND). The layout never changes: the title, the purse, three rows of wares,
## the box of his words and four buttons, whatever is said or bought.
static func build(menus: Menus) -> void:
	var game: Node = menus.game
	menus._add_label(Lang.t("Spooknortz, der Wiedergänger"), 36, game.GOLD, game.TITLE_FONT)
	var purse: Label = menus._add_label(Lang.t("Im Beutel: %d Kupfer") % Payment.worth(game), 20)
	purse.custom_minimum_size = Vector2(WIDTH, 30)
	for id: String in WARES:
		_ware_row(menus, id)
	var said: Label = menus._add_label(_greeting(game) if _said == "" else _said, 17, BLUE)
	said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	said.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	said.custom_minimum_size = Vector2(WIDTH, SPEECH_HEIGHT)
	said.clip_text = true
	var first := HBoxContainer.new()
	first.alignment = BoxContainer.ALIGNMENT_CENTER
	first.add_theme_constant_override("separation", 12)
	menus._box.add_child(first)
	var second := HBoxContainer.new()
	second.alignment = BoxContainer.ALIGNMENT_CENTER
	second.add_theme_constant_override("separation", 12)
	menus._box.add_child(second)
	var quest_state: Dictionary = game.quests.state.get(QUEST, {})
	_button(menus, first, Lang.t("Zuhören"), func(): _listen(menus), true)
	_button(menus, first, Lang.t("Diebesgut zurückholen"), func(): _fetch_goods(menus), quest_state.is_empty())
	_button(menus, second, Lang.t("Freundschaft anbieten (%d Kupfer)") % GIFT, func(): _befriend(menus), not friends(game) and Payment.can_pay(game, GIFT))
	_button(menus, second, Lang.t("Kämpfen"), func(): _fight(menus), true)


static func _button(menus: Menus, row: HBoxContainer, text: String, action: Callable, enabled: bool) -> void:
	var b: Button = menus._item_button(text, action, enabled)
	b.custom_minimum_size = Vector2(WIDTH * 0.5 - 6.0, 54)
	row.add_child(b)


static func _price(game: Node, id: String) -> int:
	var factor := FRIEND_MARKUP if friends(game) else MARKUP
	return maxi(1, roundi(float(Items.ALL[id].price) * factor))


static func _ware_row(menus: Menus, id: String) -> void:
	var game: Node = menus.game
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(WIDTH, ROW_HEIGHT)
	row.add_theme_constant_override("separation", 10)
	menus._box.add_child(row)
	var name_label: Label = game._make_label(game.TEXT_FONT, 18, Rarity.color(id))
	name_label.text = Lang.t(Items.ALL[id].name)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	row.add_child(name_label)
	var price := _price(game, id)
	var price_label: Label = game._make_label(game.TEXT_FONT, 18, Color.WHITE)
	price_label.text = Lang.t("%d Kupfer") % price
	price_label.custom_minimum_size = Vector2(130, 0)
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(price_label)
	var buy: Button = menus._item_button(Lang.t("Kaufen"), func(): _buy(menus, id), Payment.can_pay(game, price), id)
	buy.custom_minimum_size = Vector2(130, ROW_HEIGHT)
	row.add_child(buy)


static func _greeting(game: Node) -> String:
	if not game.lore.has(MET):
		return Lang.t("Ein Besucher! Seit Jahren kommt keiner mehr hier herunter. Ich bin Spooknortz. Was ich nachts im Dorf finde, verkaufe ich hier unten. Wenn du etwas willst, sag es.")
	var state: Dictionary = game.quests.state.get(QUEST, {})
	if state.get("state", "") == "done":
		return Lang.t("Dem Vorsteher hast du alles zurückgebracht? Du bist kein schlechter Kerl für einen Lebenden.")
	if friends(game):
		return Lang.t("Mein Freund! Was darf es heute sein?")
	return Lang.t("Was willst du hier unten, Lebender?")


static func _buy(menus: Menus, id: String) -> void:
	var game: Node = menus.game
	var price := _price(game, id)
	if not Items.fits(game.player.bag, game.player.bag_size(), id):
		menus._note = Lang.t("Deine Tasche ist voll.")
		menus._rebuild()
		return
	if not Payment.can_pay(game, price):
		menus._note = Lang.t("Dafür reicht dein Kupfer nicht.")
		menus._rebuild()
		return
	Payment.pay(game, price)
	game.player.bag.append(id)
	Sfx.play_coins(game, mini(price, 20))
	_meet(game)
	_said = Lang.t("Ein gutes Stück. Frag nicht, wem es einmal gehört hat.")
	menus._note = Lang.t("Gekauft: %s") % Lang.t(Items.ALL[id].name)
	game._update_hud()
	menus._rebuild()


## The next rumour he has not told yet, or a shrug.
static func _listen(menus: Menus) -> void:
	var game: Node = menus.game
	_meet(game)
	for tale: String in TALES:
		if not game.lore.has(tale):
			Events.teach(tale)
			_said = Lang.t(tale)
			menus._rebuild()
			return
	_said = Lang.t("Mehr weiß ich nicht. Komm ein andermal wieder, vielleicht fällt mir etwas ein.")
	menus._rebuild()


static func _fetch_goods(menus: Menus) -> void:
	var game: Node = menus.game
	_meet(game)
	if not game.quests.start_found(QUEST):
		menus._note = Lang.t("Deine Tasche ist voll.")
		menus._rebuild()
		return
	_said = Lang.t("Das Bündel hier habe ich dem Dorf gestohlen. Bring es dem Vorsteher Aldo zurück. Er kann es verteilen, und ich ruhe besser, wenn ich es nicht mehr ansehen muss.")
	game._update_hud()
	menus._rebuild()


static func _befriend(menus: Menus) -> void:
	var game: Node = menus.game
	if not Payment.can_pay(game, GIFT):
		menus._note = Lang.t("Dafür reicht dein Kupfer nicht.")
		menus._rebuild()
		return
	Payment.pay(game, GIFT)
	_meet(game)
	Events.teach(FRIEND)
	Sfx.play_coins(game, mini(GIFT, 20))
	_said = Lang.t("Ein Geschenk? Für mich? Das hat seit meinem Tod keiner getan. Von nun an bist du mein Freund, und Freunde zahlen weniger.")
	game._update_hud()
	menus._rebuild()


static func _fight(menus: Menus) -> void:
	var game: Node = menus.game
	menus.close()
	if _figure == null or not is_instance_valid(_figure):
		return
	_hostile = true
	var e := _figure
	game.level.enemies.append(e)
	e.set_physics_process(true)
	e.died.connect(func():
		_hostile = false
		_figure = null
		Events.teach(SLAIN)
		game.level.enemy_killed.emit(e)
		var purse: Array = Enemy.KINDS[e.kind].get("purse", [0, 0])
		game.level.drop_kill_loot(e, randi_range(purse[0], purse[1]) + 20))
	Events.tell(Lang.t("Spooknortz fletscht die Zähne und greift an."), Color(1.0, 0.6, 0.5))


## The first word with him: the compendium learns of him.
static func _meet(game: Node) -> void:
	if not game.lore.has(MET):
		Events.teach(MET)


# --- The look: the den and its wall ------------------------------------------------

## Builds the den, the false wall, the veil over the den and the loose bricks in the northern chamber,
## under `parent` (see Sewers.build); the stations go onto `level`.
static func build_world(level: Level, parent: Node3D, body: StaticBody3D) -> void:
	opened = false
	plundered = false
	_figure = null
	_hostile = false
	_wall_wall(level, parent, body)
	_veil_over(parent)
	_furnish(level, parent)
	_niche(level, parent)


static func _stone() -> Material:
	return Sewers.brick_material()


## The wall that closes the passage: brick like the rest, but a few bricks stand out, there is rubble at
## its foot and a pale crack of dust. A solid block stops the hero until it gives way.
static func _wall_wall(level: Level, parent: Node3D, body: StaticBody3D) -> void:
	var mid := Sewers.floor_at(WALL_CELL)
	var root := Node3D.new()
	root.name = "FalseWall"
	root.position = mid
	parent.add_child(root)
	_wall_mesh = root
	var high := HouseSketch.DEPTH - 0.05
	var block := Sewers._box(root, Vector3(0, high * 0.5, 0), Vector3(HouseSketch.CELL, high, HouseSketch.CELL), _stone())
	block.name = "Block"
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("lockere_ziegel")
	var b := Sewers.W.Builder.new()
	# Bricks that stand proud and a little crooked, here and there a gap.
	var face := Vector3(0, 0, -HouseSketch.CELL * 0.5)
	for i in 26:
		var x := rng.randf_range(-0.8, 0.8)
		var y := 0.15 + rng.randf() * 1.6
		var tilt := Basis.from_euler(Vector3(0, 0, rng.randf_range(-0.12, 0.12)))
		b.box(face + Vector3(x, y, -0.02), Vector3(0.24, 0.1, 0.1 + rng.randf() * 0.05), Sewers.W.vary(Color(0.5, 0.26, 0.15), rng, 0.12), Sewers.W.STONE, tilt)
	# Dust along the foot, where the draught blows it, and a fan of rubble.
	for i in 18:
		var x := rng.randf_range(-0.9, 0.9)
		var z := -HouseSketch.CELL * 0.5 - rng.randf_range(0.05, 0.5)
		b.box(Vector3(x, 0, z), Vector3(0.08 + rng.randf() * 0.14, 0.05 + rng.randf() * 0.07, 0.08 + rng.randf() * 0.12), Sewers.W.vary(Color(0.55, 0.38, 0.26), rng, 0.15), Sewers.W.STONE, Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)))
	b.finish(root)
	_wall_shape = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(HouseSketch.CELL, high, HouseSketch.CELL)
	_wall_shape.shape = shape
	_wall_shape.position = mid + Vector3(0, high * 0.5, 0)
	body.add_child(_wall_shape)
	level.stations.append({"kind": WALL, "pos": mid + Vector3(0, 0, -0.9), "cell": level.world_to_cell(mid), "used": false, "touch": 1.9})


## Whether a cell of the sewers belongs to the hidden den: its chamber, or the passage behind the false wall.
static func hides(c: Vector2i) -> bool:
	return DEN.has_point(c) or PASSAGE.has(c)


## The group of the meshes that hide the den: the cellar view dresses them in its own earth.
const EARTH_VEIL := "earth_veil"


## A veil of dark stone over the passage and the den, so the cutaway view shows solid ground there until
## the wall gives way.
static func _veil_over(parent: Node3D) -> void:
	_veil = Node3D.new()
	_veil.name = "DenVeil"
	parent.add_child(_veil)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.05, 0.04, 0.035)
	m.roughness = 1.0
	var rects: Array[Rect2i] = [DEN, Rect2i(PASSAGE[0].x, PASSAGE[0].y, 1, PASSAGE.size())]
	for r: Rect2i in rects:
		var low := Sewers.floor_at(r.position) + Vector3(-HouseSketch.CELL * 0.5, 0, -HouseSketch.CELL * 0.5)
		var size := Vector3(r.size.x * HouseSketch.CELL + 0.1, 0.1, r.size.y * HouseSketch.CELL + 0.1)
		var v := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = size
		v.mesh = box
		v.material_override = m
		v.position = low + Vector3(size.x * 0.5 - 0.05, HouseSketch.DEPTH + 0.0 - 0.06, size.z * 0.5 - 0.05)
		v.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# It takes on the earth the cellar view lays round the pit (see CellarView), so that no dark
		# rectangle gives the hidden den away.
		v.add_to_group(EARTH_VEIL)
		_veil.add_child(v)


## The den: a bedroll, a table with candles, a chest, the heap of the stolen goods and a few sacks.
static func _furnish(level: Level, parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("spooknortz_hoehle")
	var b := Sewers.W.Builder.new()
	var base := Sewers.floor_at(SPOT)
	# The bedroll against the west wall, a rolled coat as its pillow.
	var bed := Sewers.floor_at(Vector2i(DEN.position.x, SPOT.y + 1)) + Vector3(0.1, 0, 0)
	b.box(bed + Vector3(0.7, 0.0, 0), Vector3(1.5, 0.12, 0.8), Sewers.W.vary(Color(0.36, 0.3, 0.22), rng, 0.08), Sewers.W.WOOD)
	b.box(bed + Vector3(0.7, 0.12, 0), Vector3(1.4, 0.08, 0.72), Sewers.W.vary(Color(0.45, 0.2, 0.18), rng, 0.08), Sewers.W.WOOD)
	b.cylinder(bed + Vector3(0.05, 0.2, 0), 0.14, 0.14, 0.6, Sewers.W.vary(Color(0.3, 0.32, 0.22), rng, 0.08), Sewers.W.WOOD, 10, Basis.from_euler(Vector3(PI * 0.5, 0, 0)))
	# The table with the candles, on the east side.
	var table := Sewers.floor_at(Vector2i(DEN.end.x - 2, SPOT.y - 1)) + Vector3(0.2, 0, 0)
	b.box(table + Vector3(0, 0.7, 0), Vector3(1.6, 0.1, 1.0), Sewers.W.vary(Color(0.4, 0.28, 0.17), rng, 0.08), Sewers.W.WOOD)
	for sx: float in [-0.7, 0.7]:
		for sz: float in [-0.4, 0.4]:
			b.box(table + Vector3(sx, 0, sz), Vector3(0.1, 0.7, 0.1), Sewers.W.vary(Color(0.3, 0.2, 0.12), rng, 0.08), Sewers.W.WOOD)
	for k in 3:
		var at := table + Vector3(-0.5 + k * 0.45, 0.8, rng.randf_range(-0.2, 0.2))
		b.cylinder(at, 0.05, 0.045, 0.14 + rng.randf() * 0.1, Color(0.9, 0.86, 0.7), Sewers.W.FRESH, 8)
		Sewers._box(parent, at + Vector3(0, 0.26, 0), Vector3(0.04, 0.07, 0.04), Sewers._mat("flame", Color(1.0, 0.78, 0.35), 0.0, 3.0))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.76, 0.45)
	light.light_energy = 2.0
	light.omni_range = 5.0
	light.position = table + Vector3(0, 1.4, 0)
	parent.add_child(light)
	# The stolen goods in the north-east corner: sacks, crates, a candlestick, a cheese, a boot.
	var heap := Sewers.floor_at(Vector2i(DEN.end.x - 1, DEN.position.y)) + Vector3(-0.7, 0, 0.7)
	for k in 5:
		var off := Vector3(rng.randf_range(-0.7, 0.4), 0, rng.randf_range(-0.2, 0.6))
		b.frustum(heap + off, Vector2(0.5, 0.42), Vector2(0.18, 0.16), 0.5 + rng.randf() * 0.25, Sewers.W.vary(Color(0.5, 0.42, 0.28), rng, 0.12), Sewers.W.WOOD, Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)))
	for k in 3:
		Sewers._crate(b, heap + Vector3(-1.2 + k * 0.6, 0, 0.9 + rng.randf() * 0.3), rng)
	b.cylinder(heap + Vector3(0.3, 0.5, 0.1), 0.03, 0.04, 0.4, Color(0.78, 0.66, 0.25), Sewers.W.IRON, 8)
	b.cylinder(heap + Vector3(-0.2, 0.0, 1.5), 0.18, 0.18, 0.09, Color(0.9, 0.75, 0.3), Sewers.W.FRESH, 12)
	# His chest at the foot of the bed.
	var chest := Sewers.floor_at(Vector2i(DEN.position.x + 1, DEN.end.y - 1)) + Vector3(0.2, 0, 0.5)
	b.box(chest, Vector3(1.0, 0.5, 0.6), Sewers.W.vary(Color(0.34, 0.22, 0.13), rng, 0.08), Sewers.W.WOOD)
	b.box(chest + Vector3(0, 0.5, 0), Vector3(1.04, 0.14, 0.64), Sewers.W.vary(Color(0.3, 0.2, 0.12), rng, 0.08), Sewers.W.WOOD)
	for x: float in [-0.35, 0.35]:
		b.box(chest + Vector3(x, 0, 0), Vector3(0.07, 0.64, 0.66), Color(0.25, 0.25, 0.27), Sewers.W.IRON)
	b.finish(parent)
	# He is spoken to where he stands.
	level.stations.append({"kind": KIND, "pos": base, "cell": level.world_to_cell(base), "used": false, "touch": 2.3})


## The loose bricks in the north wall of the northern chamber: a patch of bricks that sits wrong, with a
## glint behind one of them.
static func _niche(level: Level, parent: Node3D) -> void:
	var mid := Sewers.floor_at(NICHE_CELL)
	var wall := Vector3(NICHE_FACING.x, 0, NICHE_FACING.y)
	var side := Vector3(-wall.z, 0, wall.x)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("lockere_ziegel_nische")
	var b := Sewers.W.Builder.new()
	for row in 4:
		for col in 3:
			var at := mid + wall * (HouseSketch.CELL * 0.5 - 0.04) + side * (-0.36 + col * 0.36) + Vector3(0, 0.7 + row * 0.16, 0)
			var out := rng.randf_range(0.0, 0.06)
			b.box(at + wall * (-0.02 - out) - Vector3(0, 0.06, 0), Vector3(0.32, 0.13, 0.08), Sewers.W.vary(Color(0.46, 0.25, 0.15), rng, 0.14), Sewers.W.STONE, Basis.from_euler(Vector3(0, 0, rng.randf_range(-0.06, 0.06))))
	b.finish(parent)
	var glint := mid + wall * (HouseSketch.CELL * 0.5 - 0.12) + Vector3(0, 0.95, 0)
	Sewers._box(parent, glint, Vector3(0.05, 0.05, 0.05), Sewers._mat("niche_glint", Color(1.0, 0.85, 0.4), 0.0, 4.0))
	level.stations.append({"kind": NICHE, "pos": mid + wall * 0.7, "cell": level.world_to_cell(mid), "used": false, "touch": 1.7})
