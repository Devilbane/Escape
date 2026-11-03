class_name Fishing
extends RefCounted
## Fishing: stand by the water, cast the line (key G or the "Angeln" button)
## and wait. When the float jerks under and a "!" shows, press again quickly
## to strike, and the catch comes in. Too slow, and the fish is gone.
##
## Three waters hold fish: the fountain on the village square, the village
## pond and the pond in the wolf hollow. Most bites are a perch (or, in the
## fountain, a coin someone threw in for luck); each water also has a rare
## fish that bites only there, some only at certain hours. Every fish goes
## into the ingredient pouch (see Crafting), where recipes call for it.
##
## The line is drawn in again when the hero walks away from the water, is
## hit, or opens a window.

## What bites in each water: [catch, weight, when]. A catch is a fish (an
## ingredient id), "muenze" for an old coin (+1 gold) or "" for weed.
## "when" limits the catch to an hour: "nacht" (see DayNight.is_night) or
## "daemmerung" (dawn and dusk, see is_dusk); "" is any time.
const WATERS := {
	"brunnen": [["", 40, ""], ["muenze", 50, ""], ["goldkarpfen", 10, ""]],
	"teich": [["", 30, ""], ["barsch", 60, ""], ["silberhecht", 12, "daemmerung"]],
	"senke": [["", 25, ""], ["barsch", 60, ""], ["mondforelle", 15, "nacht"]],
}
## How far from the water's edge the hero can stand and still cast (metres).
const RANGE := 2.4
## Seconds until a fish bites: a random time between these two.
const WAIT_MIN := 2.5
const WAIT_MAX := 6.5
## Seconds the hero has to strike once the float jerks under.
const BITE_TIME := 1.2
## Explained once in the compendium, the first time the line is cast.
const HOW_TO := "Angeln (Taste G oder der Knopf „Angeln“): stell dich ans Wasser und wirf die Leine aus. Taucht der Schwimmer unter und erscheint ein !, drück schnell noch einmal. Fische kommen in den Zutatenbeutel. Seltene Fische beißen nur in einem Gewässer, manche nur zu bestimmten Stunden."

enum {IDLE, WAITING, BITE}

var game: Node
var state := IDLE
## The water the line is in (see Level.fishing_waters), and the level it is on.
var water := {}
var _level: Node
## Seconds until the next bite (WAITING) or until the fish lets go (BITE).
var timer := 0.0
var _hp_at_cast := 0
var _float: Node3D
var _float_rest := Vector3.ZERO
var _bob := 0.0
var rng := RandomNumberGenerator.new()


func _init(owner_game: Node = null) -> void:
	game = owner_game
	rng.randomize()


func is_fishing() -> bool:
	return state != IDLE


## The water the hero could cast into right now, or {}.
func water_near() -> Dictionary:
	if game == null or game.level == null or not game.level.has_method("nearest_water"):
		return {}
	return game.level.nearest_water(game.player.global_position, RANGE)


## Key G or the button: casts the line, strikes when a fish bites, or draws
## the line in early. Returns why nothing happened, or "".
func press() -> String:
	match state:
		WAITING:
			stop()
			game.show_message(Lang.t("Du holst die Leine ein. Noch hat nichts angebissen."), 1.8)
			return ""
		BITE:
			land()
			return ""
	if not game.player.can_act():
		return Lang.t("Nicht jetzt.")
	var w := water_near()
	if w.is_empty():
		return Lang.t("Hier gibt es kein Wasser zum Angeln.")
	cast(w)
	return ""


## Casts the line into a water.
func cast(w: Dictionary) -> void:
	stop()
	water = w
	_level = game.level
	state = WAITING
	timer = rng.randf_range(WAIT_MIN, WAIT_MAX)
	_hp_at_cast = game.player.hp
	var p: Vector3 = game.player.global_position
	game.player.path.clear()
	game.player.face(w.pos - p)
	game.player.play_once("Throw", 0.6)
	Sfx.play(game, "swing", -6.0)
	_float_rest = float_spot(w, p)
	_float = _make_float()
	_float.position = _float_rest
	_level.add_child(_float)
	Events.teach(HOW_TO)
	game.show_message(Lang.t("Du wirfst die Leine aus und wartest …"), 2.0)


## Where the float lands: on the water, a little way in from the edge
## closest to the hero.
static func float_spot(w: Dictionary, from: Vector3) -> Vector3:
	var to := Vector3(from.x - w.pos.x, 0, from.z - w.pos.z)
	var spot: Vector3 = w.pos
	if w.round:
		spot += to.normalized() * minf(to.length(), w.reach * 0.6) if to.length() > 0.01 else Vector3.ZERO
	else:
		var inner: float = w.reach - 1.0
		spot += Vector3(clampf(to.x, -inner, inner), 0, clampf(to.z, -inner, inner))
	spot.y = w.surface
	return spot


## A red and white float, a little ball on the water.
func _make_float() -> Node3D:
	var node := Node3D.new()
	for part in [[Color(0.9, 0.15, 0.12), 0.06], [Color(0.95, 0.95, 0.9), -0.06]]:
		var mesh := SphereMesh.new()
		mesh.radius = 0.13
		mesh.height = 0.2
		var mat := StandardMaterial3D.new()
		mat.albedo_color = part[0]
		mat.roughness = 0.5
		var ball := MeshInstance3D.new()
		ball.mesh = mesh
		ball.material_override = mat
		ball.position.y = part[1]
		ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(ball)
	return node


## Called every frame by the game.
func tick(delta: float) -> void:
	if state == IDLE:
		return
	if game.level != _level or not is_instance_valid(_float):
		stop()
		return
	if game.player.dead or game.player.hp < _hp_at_cast:
		stop()
		game.show_message(Lang.t("Der Kampf verscheucht die Fische."), 1.8)
		return
	if game.menus.is_open() or Level.water_distance(water, game.player.global_position) > RANGE + 0.8:
		stop()
		game.show_message(Lang.t("Du holst die Leine ein."), 1.4)
		return
	_hp_at_cast = maxi(_hp_at_cast, game.player.hp)
	_bob += delta
	timer -= delta
	if state == WAITING:
		_float.position = _float_rest + Vector3(0, sin(_bob * 2.2) * 0.03, 0)
		if timer <= 0.0:
			bite()
	else:
		# The float is pulled under and jerks about.
		_float.position = _float_rest + Vector3(sin(_bob * 31.0) * 0.05, -0.12, 0)
		if timer <= 0.0:
			stop()
			game.show_message(Lang.t("Zu langsam! Der Fisch ist weg."), 1.8)


## A fish takes the bait: the hero has BITE_TIME seconds to strike.
func bite() -> void:
	state = BITE
	timer = BITE_TIME
	Sfx.play(game, "drip", 0.0, _float_rest, 0.8)
	Effects.float_text(_level, _float_rest + Vector3(0, 1.2, 0), "!", Color(1.0, 0.85, 0.3), true)
	game.show_message(Lang.t("Es beißt! Schnell: G oder „Angeln“!"), BITE_TIME)


## The hero strikes in time: what was on the hook comes in.
func land() -> void:
	var caught := roll(water.water, game.day_hour, rng)
	var pos: Vector3 = _float_rest
	var on: Node = _level
	stop()
	take(caught, pos, on)


## What was on the hook comes in: weed (""), an old coin ("muenze") or a fish
## for the ingredient pouch. `pos` is where the float was, on level `on`.
func take(caught: String, pos: Vector3, on: Node) -> void:
	game.player.play_flourish("PickUp", 0.6)
	if caught == "":
		Sfx.play(game, "drip", -4.0)
		Events.found(Lang.t("Nur Wasserkraut am Haken."), Color(0.8, 0.8, 0.85))
	elif caught == "muenze":
		game.coins += 1
		Sfx.play(game, "coin")
		Effects.float_text(on, pos + Vector3(0, 1.4, 0), Lang.t("+%d Gold") % 1, game.GOLD, true)
		Events.found(Lang.t("Eine alte Münze, die jemand für sein Glück hineingeworfen hat. +1 Gold"), game.GOLD)
	else:
		game.crafting.add(caught)
		var fish := Crafting.ingredient_name(caught)
		if Crafting.INGREDIENTS[caught].get("rare", false):
			Sfx.play(game, "gift")
			var burst := Effects.make_sparkles(Color(0.6, 0.85, 1.0), true)
			burst.position = pos + Vector3(0, 0.5, 0)
			on.add_child(burst)
			Events.tell(Lang.t("Ein seltener Fang: %s!") % fish + "\n" + Lang.t("Der Fang kommt in deinen Zutatenbeutel."), Color(0.6, 0.85, 1.0))
			Events.found(Lang.t("Ein seltener Fang: %s!") % Rarity.marked(caught), Color(0.6, 0.85, 1.0))
		else:
			Sfx.play(game, "drip")
			Effects.float_text(on, pos + Vector3(0, 1.4, 0), fish, Color(0.75, 0.9, 1.0), true)
			Events.found(Lang.t("Gefangen: %s! Ab in den Zutatenbeutel.") % Rarity.marked(caught))
		for id in game.crafting.caught_fish(caught):
			game.show_message(Lang.t("Jetzt verstehst du eine verwischte Zeile im Rezept „%s“.") % Lang.t(Crafting.RECIPES[id].name), 3.5)
	game._update_hud()


## Draws the line in, without a catch.
func stop() -> void:
	state = IDLE
	water = {}
	_level = null
	if is_instance_valid(_float):
		_float.queue_free()
	_float = null


## Whether it is dawn or dusk, when the silver pike bites.
static func is_dusk(hour: float) -> bool:
	return (hour >= 5.0 and hour < 8.0) or (hour >= 18.0 and hour < 21.0)


## Whether a catch can bite at an hour.
static func bites_at(when: String, hour: float) -> bool:
	match when:
		"nacht":
			return DayNight.is_night(hour)
		"daemmerung":
			return is_dusk(hour)
	return true


## What comes in from a water at an hour, picked by the weights in WATERS.
static func roll(water_id: String, hour: float, random: RandomNumberGenerator) -> String:
	var table := (WATERS.get(water_id, []) as Array).filter(func(row): return bites_at(row[2], hour))
	var total := 0
	for row in table:
		total += int(row[1])
	if total <= 0:
		return ""
	var pick := random.randi_range(1, total)
	for row in table:
		pick -= int(row[1])
		if pick <= 0:
			return row[0]
	return ""
