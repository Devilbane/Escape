class_name HomeRun
extends RefCounted
## "Run home": once the hero has a house of their own (see Homes), a button on
## the right edge (or the X key) sends them home by the shortest way. Out in
## the village the hero runs along the path finding to their front door and
## walks in; down in a building (a crypt, a mine floor, the vault cellar, the
## dragon's lair once it is won) they first run to its way out, and from the
## floor above or the village on to the next leg, until they stand in their
## own house.
##
## The hero runs while their breath lasts and walks when it is gone, like a
## held mouse button. Any step, click, blow, throw or jump of the player's own
## calls it off at once, and so does a window. It also stops for danger: a hit,
## or a foe that is after the hero close by, and it does not set out while one
## is. Kept simple on purpose: the hero never fights on the way, the player
## takes over.

## How close (metres) a foe that is after the hero may be before the run stops.
const DANGER_RANGE := 12.0
## How often a leg is planned again when the hero stopped short of its end
## (pushed off the path, a door frame in the way) before the run gives up.
const MAX_RETRIES := 3

var game: Node
## Whether the hero is on the way home right now.
var active := false
## The level the current leg was planned on; a new level starts a new leg.
var _leg_level: Level = null
## Where the current leg ends (a door, a way out, the spot by the bed).
var _goal := Vector3.ZERO
var _retries := 0


func _init(owner_game: Node = null) -> void:
	game = owner_game


## The number of the hero's town house, 0 if they have none.
func house() -> int:
	return Homes.house_of(game.hero_name)


## Whether the hero has a home to run to: a house on Weavers' Lane, or the
## old house the elder gave on a village map without the lane.
func has_home() -> bool:
	return house() > 0 or game.home_claimed


## Whether the button is shown: the hero has a home, plays, is not in it
## already, and a way leads home from where they are.
func can_show() -> bool:
	if game.level == null or game.state != game.State.PLAYING or not has_home():
		return false
	if game.level.is_home:
		return false
	return not _leg().is_empty()


## The next leg from the current level: {"goal": where it ends, "station": the
## door to walk in at, if any}. Empty when no way home leads from here.
func _leg() -> Dictionary:
	var lvl: Level = game.level
	if lvl == null or lvl.is_home:
		return {}
	if lvl is Outdoor:
		var number := house()
		if number > 0:
			for s in lvl.stations:
				if s.kind == "eingang" and s.building == "^" and int(s.get("house", 0)) == number:
					return {"goal": s.pos, "station": s}
		if lvl.home_spot != Vector3.ZERO and game.home_claimed:
			# The old house in the village itself: home is the spot by the bed.
			return {"goal": lvl.home_spot}
		return {}
	if lvl.lair:
		if is_instance_valid(lvl.lair_exit):
			return {"goal": lvl.lair_exit.global_position}
		return {}
	# A building of the village (a crypt, a mine floor, the vaults): its way
	# out leads up a floor or out into the village. The dungeon of the escape
	# has no way home; its doors still want their keys.
	if lvl.building != "" and lvl.exit_cell.x >= 0:
		return {"goal": lvl.cell_to_world(lvl.exit_cell)}
	return {}


## Pressed the button or the key: sets out, or stops when already on the way.
## Returns why not, or "".
func toggle() -> String:
	if active:
		stop()
		return ""
	return start()


## Sets out for home. Returns why not, or "" when the hero is on the way.
func start() -> String:
	if not has_home():
		return Lang.t("Du hast noch kein Zuhause.")
	if game.level == null or game.state != game.State.PLAYING or game.menus.is_open():
		return Lang.t("Nicht jetzt.")
	if game.level.is_home:
		return Lang.t("Du bist schon zu Hause.")
	if _leg().is_empty():
		return Lang.t("Von hier führt kein Weg nach Hause.")
	if danger():
		return Lang.t("Nicht jetzt: Ein Feind ist hinter dir her!")
	if not game.player.can_act():
		return Lang.t("Nicht jetzt.")
	active = true
	_leg_level = null
	game.show_message(Lang.t("Auf dem Heimweg ..."), 1.6)
	_plan()
	game.update_home_button()
	return ""


## Calls the run off. With a reason, says why.
func stop(why := "") -> void:
	if not active:
		return
	active = false
	_leg_level = null
	if game.player:
		game.player.wants_run = false
		game.player.path.clear()
	game._pending_station = {}
	if why != "":
		game.show_message(why, 2.2)
	game.update_home_button()


## Plans the leg on the current level and sets the hero walking.
func _plan() -> void:
	var leg := _leg()
	if leg.is_empty():
		stop(Lang.t("Von hier führt kein Weg nach Hause."))
		return
	_leg_level = game.level
	_goal = leg.goal
	_retries = 0
	_walk(leg)


func _walk(leg: Dictionary) -> void:
	game._pending_search = {}
	game._pending_crate = null
	if leg.has("station"):
		# Walking in at the door is what the click on it does as well.
		game._pending_station = leg.station
		game.player.walk_to(leg.goal, game.WALK_UP_TO)
	else:
		game._pending_station = {}
		game.player.walk_to(leg.goal)


## Whether a foe that is after the hero is close by.
func danger() -> bool:
	var lvl: Level = game.level
	if lvl == null or game.player == null:
		return false
	for e in lvl.enemies:
		if not is_instance_valid(e) or e.dead or e.is_friend() or not e.is_hunting():
			continue
		if game.player.global_position.distance_to(e.global_position) < DANGER_RANGE:
			return true
	return false


## Every frame, after the mouse has had its say about running.
func tick() -> void:
	if not active:
		return
	if game.state == game.State.TRANSITION:
		# Through a door or up the stairs: the next leg starts on arrival.
		return
	if game.state != game.State.PLAYING:
		stop()
		return
	var player: Player = game.player
	if game.level.is_home:
		# Home at last.
		stop()
		return
	if game.menus.is_open():
		stop()
		return
	if player._keyboard_direction() != Vector3.ZERO or player.steer != Vector3.ZERO:
		# The player took the hero by the hand again.
		stop()
		return
	if danger():
		stop(Lang.t("Gefahr! Du bleibst stehen."))
		return
	if game.level != _leg_level:
		_plan()
		return
	if not player.can_act():
		return
	player.wants_run = true
	if player.path.is_empty() and game._pending_station.is_empty():
		var gap := Vector2(player.global_position.x - _goal.x, player.global_position.z - _goal.z).length()
		if gap <= Level.TILE * 0.75:
			# At the spot by the bed in the old village house: home.
			if game.level is Outdoor:
				stop()
			return
		_retries += 1
		if _retries > MAX_RETRIES:
			stop(Lang.t("Von hier führt kein Weg nach Hause."))
			return
		_walk(_leg())


## The hero struck, threw or jumped: the player has taken over.
func on_hero_acted(_action: String) -> void:
	stop()


## A hit stops the hero on the way.
func on_hurt() -> void:
	if active:
		stop(Lang.t("Gefahr! Du bleibst stehen."))
