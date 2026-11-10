class_name VillageWall
extends RefCounted
## The low stone wall round the village and its gates (see WallBrick, the
## letters "_" for a stretch of wall and "\" for a gate on the map).
##
## Forest closes the village on most sides; the wall closes the ways in.
## The villagers shut the gates when a slime comes near (a slime within
## WATCH_RANGE of a gate, or the village up in arms, see VillageAlarm) and
## open them again OPEN_AFTER seconds after the last slime has left or
## fallen. A gate is never shut while somebody stands in it.
##
## Every slime outside the wall with nothing else to hunt makes for the nearest
## brick (see siege_brick); one that cannot get at what it hunts because the wall is in the way
## attacks the wall (see Enemy._plan_route). Each brick has 1000 HP and a
## slime's blow does ACID times its damage to stone, less WALL_RESIST of it. Afterwards the village's
## stonemason (Villager "S") walks to the hurt bricks, one by one, and
## builds them up again, MEND_PER_SECOND HP a second, as long as no slime
## is about. There is no limit to his work: he mends as long as a brick is hurt.

const CHECK_EVERY := 1.0
## How near to a gate a slime sets the villagers shutting it (metres).
const WATCH_RANGE := 36.0
const OPEN_AFTER := 8.0
## A slime's blow does this many times its damage to the wall.
const ACID := 24
## The share of that which the stone shrugs off: slimes and blobs do only
## 1 - WALL_RESIST (20%) of it to the wall.
const WALL_RESIST := 0.8
## The stonemason's work: HP built up per second, and how near a slime
## may be (metres) before he leaves the wall alone.
const MEND_PER_SECOND := 4.0
const MEND_SAFE := 24.0
## Nobody stands within this distance of a gate that is about to shut (metres).
const GATE_ROOM := 2.0
## A slime this close to a brick (metres, to its body) goes for it when blocked.
const SIEGE_REACH := 6.0
## A slime outside the wall that has nothing else to hunt makes for the nearest
## brick within this distance (metres) and eats into it (see Enemy._scout_wall).
const SIEGE_SIGHT := 30.0
## How long the gates wait for villagers still outside to come in (seconds).
const GRACE := 7.0
## The most villagers that take up a post at the wall at a time: everyone who can fight.
const MOST_DEFENDERS := 12
const MUSTER_CALL := "Alle hinter die Mauer! Wir verteidigen das Dorf!"
const SHUT_CALL := "Tor zu! Ein Schleim kommt!"
const OPEN_CALL := "Das Tor ist wieder offen. Die Gefahr ist vorbei."
const SHUT_NEWS := "Die Dörfler schließen das Tor: Ein Schleim ist in der Nähe!"
const OPEN_NEWS := "Die Dörfler öffnen das Tor wieder."
const GNAWED := "Ein Schleim frisst sich in die Dorfmauer!"
const BROKEN := "Ein Schleim hat ein Stück der Dorfmauer eingerissen!"
const MENDED := "Der Steinmetz hat die Dorfmauer wieder instand gesetzt."
const COLOR := Color(1.0, 0.75, 0.3)
## Wall tiles on the map, and gate tiles.
const WALL_LETTER := "_"
const GATE_LETTER := "\\"

## Every brick by its tile.
var bricks: Dictionary = {}
var gates: Array[WallBrick] = []
## The villagers want the gates shut now.
var shut_wanted := false
## The tiles within the wall, with every gate shut (empty when there is no wall).
var inside: Dictionary = {}
var _grace := 0.0
var _check := 0.0
var _calm := 0.0
var _gnawed_news := 0.0
var _hurt_since_mended := false


## Puts up the brick of a wall or gate tile (called while the map is built).
func add(o: Outdoor, c: Vector2i, is_gate: bool) -> void:
	var brick := WallBrick.new()
	brick.setup(o, c, is_gate, runs_along_x(o, c))
	o.add_child(brick)
	bricks[c] = brick
	if is_gate:
		gates.append(brick)


## Whether the wall at a tile runs west to east (else north to south): it does
## when its neighbours to the west or east are wall, and north and south are not.
static func runs_along_x(o: Outdoor, c: Vector2i) -> bool:
	var sides := func(a: Vector2i, b: Vector2i) -> bool:
		return (WALL_LETTER + GATE_LETTER).contains(o.cell_char(c + a)) or (WALL_LETTER + GATE_LETTER).contains(o.cell_char(c + b))
	return sides.call(Vector2i(-1, 0), Vector2i(1, 0)) and not sides.call(Vector2i(0, -1), Vector2i(0, 1))


## Tells the path finding which bricks block (called after the astar is set up).
func sync(o: Outdoor) -> void:
	for c in bricks:
		o.astar.set_point_solid(c, bricks[c].blocks())
	_find_inside(o)


## The tiles reached from the village square without passing a brick or a gate.
func _find_inside(o: Outdoor) -> void:
	inside.clear()
	if bricks.is_empty() or o.spots.square.is_empty():
		return
	var first := o.world_to_cell(o.spots.square[0])
	var queue: Array[Vector2i] = [first]
	inside[first] = true
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d in Level.DIRS:
			var n: Vector2i = c + d
			if not inside.has(n) and not bricks.has(n) and Outdoor.WALK.contains(o.cell_char(n)):
				inside[n] = true
				queue.append(n)


## Whether a tile is within the wall (everything is, where there is no wall).
func is_inside(c: Vector2i) -> bool:
	return inside.is_empty() or inside.has(c)


## A brick fell, was built up again, or a gate was shut or opened.
func changed(brick: WallBrick) -> void:
	var o := brick.level
	var open_ground := not brick.blocks()
	if not brick.gate:
		o._set_cell(brick.cell, "." if brick.hp <= 0 else WALL_LETTER)
	if o.astar != null and o.astar.is_in_boundsv(brick.cell):
		o.astar.set_point_solid(brick.cell, not open_ground)
	if brick.hp <= 0:
		_hurt_since_mended = true


func brick_at(c: Vector2i) -> WallBrick:
	return bricks.get(c)


func damaged() -> Array:
	return bricks.values().filter(func(b: WallBrick): return b.is_damaged())


# --- The gates --------------------------------------------------------------------

func tick(o: Outdoor, delta: float) -> void:
	_gnawed_news = maxf(0.0, _gnawed_news - delta)
	_check -= delta
	if _check > 0.0 or gates.is_empty():
		return
	_check = CHECK_EVERY
	var threat := o.village_alarm.raised or slime_near_a_gate(o) or slime_at_the_wall(o)
	if threat:
		_calm = 0.0
		if not shut_wanted:
			shut_wanted = true
			Events.alarm("wall" if slime_at_the_wall(o) else "gate")
			_grace = GRACE
			_call(o, SHUT_CALL, SHUT_NEWS)
		_grace -= CHECK_EVERY
		_muster(o)
	elif shut_wanted:
		_calm += CHECK_EVERY
		if _calm >= OPEN_AFTER:
			shut_wanted = false
			_call(o, OPEN_CALL, OPEN_NEWS)
	for g in gates:
		if g.shut == shut_wanted:
			continue
		# Never shut a gate on somebody standing in it.
		if shut_wanted and (g.hp <= 0 or someone_in(o, g) or (_grace > 0.0 and stragglers(o) > 0)):
			continue
		g.close(shut_wanted)
	_send_mason(o)
	if not shut_wanted and _hurt_since_mended and damaged().is_empty():
		_hurt_since_mended = false
		Events.tell(Lang.t(MENDED), COLOR)


## The villagers outside the wall come in, and everyone who can fight takes
## a post on the inside, at the stretch of wall the nearest slime is at. They
## hold it whatever the slime's level (see Villager.defend): only a slime that
## has broken through (VillageAlarm.intruders) sends them after it into the
## village, or indoors if it is too big (VillageAlarm.too_big). Defenders whose
## slime has moved along the wall follow it to a new post.
func _muster(o: Outdoor) -> void:
	var anchor := threatened_brick(o)
	if anchor == null:
		return
	var way_in := stand_of(o, anchor)
	var posts := 0
	for v in o.villagers:
		if v.eaten or v.at_home or not v.visible:
			continue
		if not is_inside(o.world_to_cell(v.global_position)):
			v.go_inside(way_in)
		elif v.brave and posts < MOST_DEFENDERS and v.can_defend():
			v.defend(post_of(o, anchor, posts))
			posts += 1
		elif v.brave and v.defends():
			v.repost(post_of(o, anchor, posts))
			posts += 1


## The villagers out and about who are still outside the wall.
func stragglers(o: Outdoor) -> int:
	var n := 0
	for v in o.villagers:
		if not v.eaten and not v.at_home and v.visible and not is_inside(o.world_to_cell(v.global_position)) \
				and v.global_position.distance_to(gates[0].global_position) < 100.0:
			n += 1
	return n


## The piece of standing wall (or gate) closest to the slime nearest to the
## wall: where the defenders gather. Null when no slime is about.
func threatened_brick(o: Outdoor) -> WallBrick:
	var best: WallBrick = null
	var best_d := INF
	for e in o.enemies:
		if not (is_instance_valid(e) and not e.dead and e.is_inside_tree() and SlimeGrowth.grows(e.kind)):
			continue
		for b: WallBrick in bricks.values():
			if b.hp <= 0:
				continue
			var d := b.distance_from(e.global_position)
			if d < best_d:
				best = b
				best_d = d
	return best


## The `k`th post inside the wall by a brick: close to the wall, spread along it.
func post_of(o: Outdoor, brick: WallBrick, k: int) -> Vector3:
	var inward := (stand_of(o, brick) - brick.global_position).normalized()
	var along := Vector3(1, 0, 0) if brick.along_x else Vector3(0, 0, 1)
	var offset := (((k + 1) / 2) * (1.0 if k % 2 == 0 else -1.0)) * 1.4
	return brick.global_position + inward * 2.0 + along * offset


## Whether a living slime is within WATCH_RANGE of any stretch of the wall.
func slime_at_the_wall(o: Outdoor) -> bool:
	for e in o.enemies:
		if is_instance_valid(e) and not e.dead and e.is_inside_tree() and SlimeGrowth.grows(e.kind):
			for b: WallBrick in bricks.values():
				if b.hp > 0 and b.distance_from(e.global_position) < WATCH_RANGE:
					return true
	return false


## The living slime nearest to a point within `within` metres, or null.
static func nearest_slime(o: Outdoor, at: Vector3, within: float) -> Enemy:
	var best: Enemy = null
	var best_d := within
	for e in o.enemies:
		if is_instance_valid(e) and not e.dead and e.is_inside_tree() and SlimeGrowth.grows(e.kind):
			var d := Vector2(e.global_position.x - at.x, e.global_position.z - at.z).length()
			if d < best_d:
				best = e
				best_d = d
	return best


## A villager out and about calls it out, nearest to the first gate.
func _call(o: Outdoor, text: String, news: String) -> void:
	var gate: WallBrick = gates[0]
	var best: Villager = null
	var best_d := INF
	for v in o.villagers:
		if v.eaten or v.at_home or not v.visible:
			continue
		var d: float = v.global_position.distance_to(gate.global_position)
		if d < best_d:
			best = v
			best_d = d
	if best == null:
		best = VillageAlarm.caller(o)
	if best != null:
		best.say(Lang.t(text))
	Events.tell(Lang.t(news), COLOR)


## Whether a living slime crawls within WATCH_RANGE of a gate.
func slime_near_a_gate(o: Outdoor) -> bool:
	for g in gates:
		if slime_near(o, g.global_position, WATCH_RANGE):
			return true
	return false


static func slime_near(o: Outdoor, at: Vector3, within: float) -> bool:
	for e in o.enemies:
		if is_instance_valid(e) and not e.dead and e.is_inside_tree() and SlimeGrowth.grows(e.kind) \
				and Vector2(e.global_position.x - at.x, e.global_position.z - at.z).length() < within:
			return true
	return false


## Whether the hero, a villager or a monster stands in the way of a gate's leaves.
static func someone_in(o: Outdoor, gate: WallBrick) -> bool:
	var at := gate.global_position
	var bodies: Array = [o.player]
	bodies.append_array(o.enemies)
	bodies.append_array(o.villagers)
	for b in bodies:
		if is_instance_valid(b) and b is Node3D and b.visible and Vector2(b.global_position.x - at.x, b.global_position.z - at.z).length() < GATE_ROOM:
			return true
	return false


# --- A slime at the wall -------------------------------------------------------------

## The brick a slime blocked by the wall goes for: the one close to it that stops
## the way, nearest to what the slime wants (`goal`). Null when none is near.
func target_for(slime: Node3D, goal: Vector3) -> WallBrick:
	var best: WallBrick = null
	var best_d := INF
	for b: WallBrick in bricks.values():
		if not b.blocks() or b.distance_from(slime.global_position) > SIEGE_REACH:
			continue
		var d := b.nearest_point(goal).distance_to(goal)
		if d < best_d:
			best = b
			best_d = d
	return best


## The standing brick a slime outside the wall besieges: the nearest within
## SIEGE_SIGHT. Null when it is inside the wall, or none is near.
func siege_brick(slime: Node3D) -> WallBrick:
	if bricks.is_empty() or is_inside(slime.level.world_to_cell(slime.global_position)):
		return null
	var best: WallBrick = null
	var best_d := SIEGE_SIGHT
	for b: WallBrick in bricks.values():
		var d := b.distance_from(slime.global_position)
		if b.blocks() and d < best_d:
			best = b
			best_d = d
	return best


## What a slime's blow of `slime_damage` does to the stone (at least 1).
static func wall_damage(slime_damage: int) -> int:
	return maxi(1, roundi(maxi(1, slime_damage) * ACID * (1.0 - WALL_RESIST)))


## A slime's blow on a brick. Returns whether the brick is gone.
func gnaw(o: Outdoor, brick: WallBrick, slime_damage: int) -> bool:
	var damage := wall_damage(slime_damage)
	var at := brick.global_position + Vector3(0, WallBrick.COURSES * WallBrick.COURSE, 0)
	Effects.float_text(o, at, "-%d" % damage, Color(0.6, 0.9, 0.4))
	Sfx.play(o, "hit", -8.0, brick.global_position, 0.6)
	var gone := brick.hurt(damage)
	if gone:
		Events.tell(Lang.t(BROKEN), COLOR)
	elif _gnawed_news <= 0.0:
		_gnawed_news = 60.0
		Events.tell(Lang.t(GNAWED), COLOR)
	_hurt_since_mended = true
	return gone


# --- The stonemason ------------------------------------------------------------------

## Sends the stonemason to the worst hurt brick, when he is free and it is safe.
func _send_mason(o: Outdoor) -> void:
	var work := job(o)
	if work == null:
		return
	for v in o.villagers:
		if v.role == "S":
			if v.can_mend():
				v.mend(work)
			return


## The brick the mason mends next: the worst hurt one that is safe to work on.
## Null when there is none, or while the gates are shut (a slime is near).
func job(o: Outdoor) -> WallBrick:
	if shut_wanted or o.village_alarm.raised:
		return null
	var best: WallBrick = null
	for b: WallBrick in bricks.values():
		if not b.is_damaged() or slime_near(o, b.global_position, MEND_SAFE):
			continue
		if best == null or b.hp < best.hp:
			best = b
	return best


## Where the mason stands to work on a brick: the open tile beside it that is
## closest to the village, so he works on the inner side of the wall.
func stand_of(o: Outdoor, brick: WallBrick) -> Vector3:
	var centre := Vector3.ZERO
	if not o.spots.square.is_empty():
		centre = o.spots.square[0]
	var best := brick.global_position
	var best_d := INF
	for d in Level.DIRS:
		var n: Vector2i = brick.cell + d
		if not o.is_open(n) or bricks.has(n):
			continue
		var p := o.cell_to_world(n)
		var dist := p.distance_to(centre)
		if dist < best_d:
			best = p
			best_d = dist
	return best
