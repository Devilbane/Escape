class_name AshSpire
extends RefCounted
## The Ashen Spire: the ruined tower of the mage Ashkaran on the high ridge
## in the east, and the cellars he dug under it. A hero of level 18 to 20
## climbs in at the spire's gate (the "<" block of the open-air map), goes
## down through five floors (headers "building: spire1" .. "spire5", chained
## by "down:" and "up:" like the mines) and steals the mage's grimoire from
## the sanctum at the very bottom. The way there asks for everything the
## game has to offer: secret walls and hidden levers, the block puzzle, timed
## jumps over blade sweepers (AshBlades) while archers shoot, crates and
## stone blocks to climb (AshLedge), fights, and sneaking up on guardians.
##
## The floors, from the top:
##   spire1  the Aschenzinne, the open courtyard (the way down is behind a
##           gate that opens when the blocks lie on the plates)
##   spire2  the cistern: dark halls full of sleeping guardians, sneak past
##           them; a hidden bed in a secret room (an "inn" floor)
##   spire3  the clockwork: blade sweepers and crossfire, ledges to climb,
##           the healing cache and the dwarven anvil; the first sub boss
##   spire4  the archive: undead scholars, a second hidden bed, the prisoner
##           in his cell and the second sub boss
##   spire5  the sanctum: the grimoire on its lectern (the goal), an optional
##           boss in the vault beyond, and a hidden hatch up to the courtyard
##
## The grimoire teaches "Arkane Energie" (Training.CRAFTS "magie"): the key Z
## shoots an arcane bolt (see cast and AshBolt). Monsters on these floors come
## back after RESPAWN_HOURS (header "respawn:", see Level).

const FLOORS := ["spire1", "spire2", "spire3", "spire4", "spire5"]
## The station kinds the floors add (see Game._use_station).
const BOOK := "ash_buch"
const CACHE := "ash_vorrat"
const ANVIL := "ash_amboss"
const HATCH := "ash_luke"
const PRISONER := "ash_gefangener"

const SPELL := "magie"
## Training for one level of Arkane Energie (Training.SKILL_FIRST).
const BOOK_XP := 8.5
## What the supply cache holds, and how many hours until it is full again.
const CACHE_POTIONS := 2
const REFILL_HOURS := 10.0
## How much wear the anvil takes off, and how many hours until it cools.
const MEND_POINTS := 10
const MEND_HOURS := 8.0

const WOOD := Color(0.34, 0.23, 0.14)
const IRON := Color(0.22, 0.2, 0.2)
const STONE := Color(0.42, 0.4, 0.42)
const ARCANE := Color(0.62, 0.4, 1.0)
const EMBER := Color(1.0, 0.5, 0.2)
const MEDIC := Color(0.9, 0.25, 0.3)

const LEARN_BOOK := "Das Grimoire der Stillen Flamme: Der Magier Ashkaran schrieb darin nieder, wie man die Kraft in sich selbst zu einer Kugel aus Licht sammelt. Wer es liest, beherrscht die Arkane Energie. Mit der Taste Z schleuderst du einen Zauberblitz auf den nächsten Feind in Sicht. Er durchschlägt jede Rüstung (nur der Wächter in Rüstung lacht darüber), braucht ein paar Sekunden zum Sammeln und wird mit jeder Stufe stärker."
const LEARN_SPIRE := "Die Aschenzinne: Hoch im Osten, über den Minen, steht der Turm des Magiers Ashkaran in Trümmern. Unter dem Hof liegt ein Keller, der tiefer reicht, als der Turm je hoch war. Man sagt, in seinem Allerheiligsten liege ein Buch, das jedem, der es liest, die Macht über die Magie gibt. Nur wer im Kampf bestehen kann, wer Geheimnisse und Schalter aufspürt, sich lautlos bewegt und im richtigen Augenblick springt, kommt hinunter und wieder herauf."

static func is_floor(level: Level) -> bool:
	return level != null and level.building in FLOORS


## Hints under the hero's feet for the stations of the spire (see
## Game._prompt), "" for any other kind.
static func prompt(kind: String) -> String:
	match kind:
		BOOK:
			return Lang.t("Dagegenlaufen, um das Grimoire an dich zu nehmen")
		CACHE:
			return Lang.t("Dagegenlaufen, um dich am Vorrat zu bedienen")
		ANVIL:
			return Lang.t("Dagegenlaufen, um deine Ausrüstung am Amboss auszubessern")
		HATCH:
			return Lang.t("Dagegenlaufen, um die Leiter nach oben zu steigen")
		PRISONER:
			return Lang.t("Dagegenlaufen, um mit dem Gefangenen zu reden")
	return ""


# --- The spell --------------------------------------------------------------

## Whether the hero has read the grimoire.
static func knows_spell(player: Player) -> bool:
	return Training.skill_level(player.xp.get(SPELL, 0.0), SPELL) >= 1


static func spell_power(player: Player) -> int:
	return 4 + 2 * Training.skill_level(player.xp.get(SPELL, 0.0), SPELL) + (player.attribute("intelligenz") - 10) / 2


## Seconds between two bolts.
static func cooldown(player: Player) -> float:
	return maxf(1.5, 4.0 - 0.25 * Training.skill_level(player.xp.get(SPELL, 0.0), SPELL))


## The key Z: a bolt at the closest monster in sight (or straight ahead).
static func cast(player: Player) -> void:
	if not player.can_act():
		return
	if not knows_spell(player):
		Effects.float_text(player.level, player.global_position + Vector3(0, 3.2, 0), Lang.t("Du kennst keinen Zauber"), Color(1, 1, 1, 0.8))
		return
	var now := Time.get_ticks_msec() / 1000.0
	var ready: float = float(player.get_meta("arcane_ready", 0.0))
	if now < ready:
		Effects.float_text(player.level, player.global_position + Vector3(0, 3.2, 0), Lang.t("Die Kraft sammelt sich noch (%d s)") % ceili(ready - now), Color(0.8, 0.7, 1.0, 0.9))
		return
	player.set_meta("arcane_ready", now + cooldown(player))
	player.path.clear()
	var dir := player.facing()
	var target := player._nearest_enemy(26.0, true)
	if target:
		dir = target.global_position - player.global_position
	dir.y = 0.0
	if dir.length() < 0.01:
		dir = player.facing()
	player.face(dir)
	player.play_once("Throw", 0.45)
	player.train(SPELL, 1.0)
	Sfx.play(player, "magic", -2.0, player.global_position, 1.1)
	AshBolt.spawn(player.level, player.global_position + Vector3(0, 1.5, 0) + dir.normalized() * 0.6, dir, spell_power(player))


# --- The tiles ---------------------------------------------------------------

## Builds the spire's own tiles (see Tiles.DUNGEON). True if `ch` was one.
static func build_cell(level: Level, c: Vector2i, ch: String) -> bool:
	var pos := level.cell_to_world(c)
	match ch:
		"I":
			_build_lectern(level, c, pos)
		"*":
			_build_cache(level, c, pos)
		"!":
			_build_anvil(level, c, pos)
		";":
			_build_hatch(level, c, pos)
		_:
			return false
	return true


static func _build_lectern(level: Level, c: Vector2i, pos: Vector3) -> void:
	var stone := Mines._material(STONE)
	Mines._box(level, pos + Vector3(0, 0.45, 0), Vector3(1.4, 0.9, 1.4), stone)
	Mines._box(level, pos + Vector3(0, 1.0, 0), Vector3(1.8, 0.25, 1.2), stone)
	var book := Mines._box(level, pos + Vector3(0, 1.22, 0), Vector3(1.1, 0.2, 0.8), Mines._material(ARCANE, 1.6), 0.2)
	var light := Mines._light(level, pos + Vector3(0, 2.0, 0), ARCANE, 2.2, 8.0)
	level._add_solid(pos, Vector3(1.8, 1.4, 1.8))
	level.stations.append({"kind": BOOK, "cell": c, "pos": pos, "used": false, "book": book, "light": light})


static func _build_cache(level: Level, c: Vector2i, pos: Vector3) -> void:
	var wood := Mines._material(WOOD)
	Mines._box(level, pos + Vector3(0, 0.55, 0), Vector3(2.2, 1.1, 1.3), wood)
	Mines._box(level, pos + Vector3(0, 1.12, 0), Vector3(2.4, 0.12, 1.5), Mines._material(IRON))
	var cross := Mines._material(MEDIC, 1.0)
	Mines._box(level, pos + Vector3(0, 0.6, 0.67), Vector3(0.7, 0.2, 0.04), cross)
	Mines._box(level, pos + Vector3(0, 0.6, 0.67), Vector3(0.2, 0.7, 0.04), cross)
	Mines._light(level, pos + Vector3(0, 1.8, 1.0), Color(1.0, 0.55, 0.5), 1.0, 5.0)
	level._add_solid(pos, Vector3(2.4, 1.2, 1.5))
	level.stations.append({"kind": CACHE, "cell": c, "pos": pos, "used": false})


static func _build_anvil(level: Level, c: Vector2i, pos: Vector3) -> void:
	var iron := Mines._material(IRON)
	Mines._box(level, pos + Vector3(0, 0.4, 0), Vector3(0.9, 0.8, 0.9), Mines._material(WOOD))
	Mines._box(level, pos + Vector3(0, 0.95, 0), Vector3(1.6, 0.35, 0.7), iron)
	Mines._box(level, pos + Vector3(0.95, 0.95, 0), Vector3(0.5, 0.2, 0.4), iron)
	Mines._box(level, pos + Vector3(0, 1.15, 0), Vector3(1.0, 0.05, 0.4), Mines._material(EMBER, 1.2))
	Mines._light(level, pos + Vector3(0, 1.6, 0), EMBER, 1.6, 7.0)
	level._add_solid(pos, Vector3(2.0, 1.2, 1.2))
	level.stations.append({"kind": ANVIL, "cell": c, "pos": pos, "used": false})


## The hatch in the floor: a trapdoor and a ladder. On a floor with the header
## "hatch:" it leads up (the hidden shortcut), on the floor it comes out on it
## stands open.
static func _build_hatch(level: Level, c: Vector2i, pos: Vector3) -> void:
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color(0.02, 0.015, 0.015)
	Mines._box(level, pos + Vector3(0, 0.03, 0), Vector3(2.0, 0.04, 2.0), black)
	var wood := Mines._material(WOOD)
	for side in [-1.0, 1.0]:
		Mines._box(level, pos + Vector3(side * 1.1, 0.12, 0), Vector3(0.25, 0.24, 2.4), wood)
		Mines._box(level, pos + Vector3(0, 0.12, side * 1.1), Vector3(2.4, 0.24, 0.25), wood)
	Mines._box(level, pos + Vector3(-0.6, 0.35, -0.6), Vector3(0.1, 0.1, 1.4), wood, 0.0)
	level._add_solid(pos, Vector3(2.2, 0.8, 2.2))
	level.hatch_side = level.cell_to_world(level._open_side(c))
	if level.hatch_to != "":
		level.stations.append({"kind": HATCH, "cell": c, "pos": pos, "used": false, "building": level.hatch_to})
	else:
		Mines._light(level, pos + Vector3(0, 0.6, 0), Color(1.0, 0.9, 0.7), 1.2, 6.0)


# --- Using them --------------------------------------------------------------

## Running into one of the spire's stations (see Game._use_station).
static func use(game: Node, s: Dictionary) -> void:
	var player: Player = game.player
	player.face(s.pos - player.global_position)
	player.play("Idle")
	match s.kind:
		BOOK:
			_take_book(game, s)
		CACHE:
			_use_cache(game, s)
		ANVIL:
			_use_anvil(game, s)
		HATCH:
			game.use_hatch(s)
		PRISONER:
			_talk_prisoner(game, s)


static func _take_book(game: Node, s: Dictionary) -> void:
	var player: Player = game.player
	if s.used:
		return
	s.used = true
	if not knows_spell(player):
		player.xp[SPELL] = maxf(float(player.xp.get(SPELL, 0.0)), BOOK_XP)
		player.trained.emit(SPELL, 1)
		Training.save_hero(game.hero_name, player.xp, player.level_data())
	var mat: StandardMaterial3D = (s.book as MeshInstance3D).material_override
	mat.emission_energy_multiplier = 0.0
	mat.albedo_color = Color(0.2, 0.18, 0.25)
	(s.light as OmniLight3D).light_energy = 0.0
	game.level.taken["ash:book"] = true
	Sfx.play(game, "magic", -2.0)
	Events.teach(LEARN_BOOK)
	Events.found(Lang.t("Das Grimoire der Stillen Flamme! Du beherrschst die Arkane Energie (Taste Z)."), ARCANE)
	game.show_message(Lang.t("Du hast das Grimoire gestohlen! Mit Z schleuderst du Zauberblitze."), 4.0)
	# The theft wakes everything on the floor.
	for e in game.level.enemies:
		if is_instance_valid(e) and not e.dead:
			e.alert(player.global_position)


## The hours the world has run, as the stations' memory keys.
static func _ready_again(level: Level, key: String, hours: float) -> bool:
	var last = level.taken.get(key)
	return not (last is float) or level.world_hours - last >= hours


static func _use_cache(game: Node, s: Dictionary) -> void:
	var player: Player = game.player
	var level: Level = game.level
	var key := "ash:cache:%d:%d" % [s.cell.x, s.cell.y]
	if not _ready_again(level, key, REFILL_HOURS):
		game.show_message(Lang.t("Der Vorrat ist leer. Gib ihm Zeit, bis er sich wieder gefüllt hat."), 3.0)
		return
	var given := 0
	for i in CACHE_POTIONS:
		if player.bag_fits("heiltrank"):
			player.bag.append("heiltrank")
			given += 1
	if given == 0:
		game.show_message(Lang.t("Dein Rucksack ist voll."), 2.5)
		return
	level.taken[key] = level.world_hours
	Sfx.play(game, "drink", -4.0)
	player.hp = mini(player.max_hp, player.hp + 1)
	Events.found(Lang.t("+%d Heiltrank") % given, Color(1.0, 0.5, 0.55))
	game.show_message(Lang.t("Ein vergessener Vorrat der Wachen: Heiltränke und Verbandszeug."), 3.0)


static func _use_anvil(game: Node, s: Dictionary) -> void:
	var player: Player = game.player
	var level: Level = game.level
	var key := "ash:anvil:%d:%d" % [s.cell.x, s.cell.y]
	if not _ready_again(level, key, MEND_HOURS):
		game.show_message(Lang.t("Der Amboss ist noch heiß. Komm später wieder."), 3.0)
		return
	var done: int = game._repair_gear(MEND_POINTS)
	if done == 0:
		game.show_message(Lang.t("Deine Ausrüstung ist heil. Hier ist nichts zu tun."), 2.5)
		return
	level.taken[key] = level.world_hours
	Sfx.play(game, "gear_metal_%d" % (randi() % 3), -2.0)
	Events.found(Lang.t("%d Punkte Haltbarkeit ausgebessert") % done, Color(1.0, 0.8, 0.5))
	game.show_message(Lang.t("Ein altes Zwergenwerkzeug liegt am Amboss. Du flickst, so gut es geht."), 3.0)


## The prisoner's tale and his task: a healing potion for him.
const PRISONER_LINES := [
	"Ihr seid nicht von den Wachen. Gut. Ich bin Bruder Orlan, Ashkarans Schreiber. Er sperrte mich ein, weil ich sein Buch kenne.",
	"Das Grimoire liegt ganz unten, im Allerheiligsten. Der Weg dorthin ist verflucht mit Fallen, die man nur im Sprung überlebt.",
	"Ich bin wund. Ein Heiltrank, und ich verrate Euch ein Geheimnis dieser Zelle.",
]
const PRISONER_THANKS := "Dank sei Euch! Hört: In der langen Halle des Archivs, in der Südwand, ist hinter einem Mauerstück ein Bett versteckt. Und ganz unten, hinter dem Allerheiligsten, führt eine Leiter ungesehen zurück in den Hof."


static func _talk_prisoner(game: Node, s: Dictionary) -> void:
	var player: Player = game.player
	var level: Level = game.level
	if level.taken.has("ash:prisoner"):
		game.show_message(Lang.t(PRISONER_THANKS), 7.0)
		return
	if player.bag.has("heiltrank") or player.bag.has("heiltrank_schwach") or player.bag.has("heiltrank_stark"):
		for id in ["heiltrank_schwach", "heiltrank", "heiltrank_stark"]:
			if player.bag.has(id):
				player.bag.erase(id)
				break
		level.taken["ash:prisoner"] = true
		Sfx.play(game, "drink")
		player.train("weisheit", 6.0)
		Events.found(Lang.t("Bruder Orlan trinkt den Trank und erzählt dir von zwei verborgenen Orten."), Color(0.8, 0.9, 1.0))
		game.show_message(Lang.t(PRISONER_THANKS), 8.0)
		return
	var line := int(s.get("line", 0))
	s.line = (line + 1) % PRISONER_LINES.size()
	game.show_message(Lang.t(PRISONER_LINES[line]), 6.0)
