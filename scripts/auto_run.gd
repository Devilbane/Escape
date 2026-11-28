class_name AutoRun
extends RefCounted
## "Run there": a click on an explored spot of the map, or on a place in the list beside it,
## closes the map and sends the hero running there along the path finding (see Menus._map_run_to).
## A dotted route and a ring on the ground show where they are heading (see AutoRunMarker).
##
## It works like the way home (see HomeRun) and is as simple: the hero runs on the level they are
## on and stops on arrival or when the way is blocked. Any step, click, blow, throw or jump of the
## player's own calls it off at once, and so does a window. It also stops for danger: a hit, or a foe
## that is after the hero close by, and it does not set out while one is.

## How close (metres) a foe that is after the hero may be before the run stops.
const DANGER_RANGE := 12.0
## How often the way is planned again when the hero stopped short of the goal (pushed off the path,
## a door frame in the way) before the run gives up.
const MAX_RETRIES := 3
## How far (tiles) from a clicked tile the nearest spot the hero can reach is looked for: the click
## may land on a wall, a bush or the middle of a house.
const SEARCH_RADIUS := 3

var game: Node
## Whether the hero is on the way right now.
var active := false
var _level: Level = null
var _goal := Vector3.ZERO
var _retries := 0
var _marker: AutoRunMarker = null


func _init(owner_game: Node = null) -> void:
	game = owner_game


## The spot (world) the hero can run to for a click on map tile `cell`: the tile itself, or the
## nearest tile within SEARCH_RADIUS that a way leads to. Vector3.INF when there is none.
static func destination(level: Level, hero: Vector3, cell: Vector2i) -> Vector3:
	var walk_in = level.get("walk_in")
	var from := level.set_out_cell(hero)
	for ring in range(0, SEARCH_RADIUS + 1):
		var best := Vector3.INF
		var best_gap := INF
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				var c := cell + Vector2i(dx, dy)
				if not level.astar.is_in_boundsv(c) or level.astar.is_point_solid(c) or not level._walkable(c):
					continue
				var world := level.cell_to_world(c)
				var reachable := c == from or not level.grid_path(from, c).is_empty()
				if not reachable and walk_in != null:
					reachable = not walk_in.route(hero, world).is_empty()
				var gap := Vector2(dx, dy).length()
				if reachable and gap < best_gap:
					best = world
					best_gap = gap
		if best != Vector3.INF:
			return best
	return Vector3.INF


## Sets out for `goal` (world). Returns why not, or "" when the hero is on the way.
func start(goal: Vector3) -> String:
	stop()
	if game.level == null or game.state != game.State.PLAYING or game.menus.is_open():
		return Lang.t("Nicht jetzt.")
	if danger():
		return Lang.t("Nicht jetzt: Ein Feind ist hinter dir her!")
	if not game.player.can_act():
		return Lang.t("Nicht jetzt.")
	game.home_run.stop()
	var player: Player = game.player
	if Vector2(player.global_position.x - goal.x, player.global_position.z - goal.z).length() <= Level.TILE * 0.75:
		return Lang.t("Du bist schon da.")
	_level = game.level
	_goal = goal
	_retries = 0
	_walk()
	if player.path.is_empty():
		return Lang.t(ClickRefusal.TEXT_UNREACHABLE)
	active = true
	_marker = AutoRunMarker.make(_level, player, goal)
	game.show_message(Lang.t("Du läufst los ..."), 1.4)
	return ""


## Calls the run off. With a reason, says why.
func stop(why := "") -> void:
	if not active:
		return
	active = false
	_level = null
	if is_instance_valid(_marker):
		_marker.finish()
	_marker = null
	if game.player:
		game.player.wants_run = false
		game.player.path.clear()
	if why != "":
		game.show_message(why, 2.2)


func _walk() -> void:
	game._pending_search = {}
	game._pending_station = {}
	game._pending_crate = null
	game.player.walk_to(_goal)


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


## Every frame.
func tick() -> void:
	if not active:
		return
	if game.state == game.State.TRANSITION:
		return
	var player: Player = game.player
	if game.state != game.State.PLAYING or game.level != _level or game.menus.is_open():
		stop()
		return
	if player._keyboard_direction() != Vector3.ZERO or player.steer != Vector3.ZERO:
		stop()
		return
	if danger():
		stop(Lang.t("Gefahr! Du bleibst stehen."))
		return
	if not player.can_act():
		return
	player.wants_run = true
	if player.path.is_empty():
		var gap := Vector2(player.global_position.x - _goal.x, player.global_position.z - _goal.z).length()
		if gap <= Level.TILE * 0.75:
			stop()
			return
		_retries += 1
		if _retries > MAX_RETRIES:
			stop(Lang.t(ClickRefusal.TEXT_PARTIAL))
			return
		_walk()


## The hero struck, threw or jumped: the player has taken over.
func on_hero_acted(_action: String) -> void:
	stop()


## A hit stops the hero on the way.
func on_hurt() -> void:
	if active:
		stop(Lang.t("Gefahr! Du bleibst stehen."))
