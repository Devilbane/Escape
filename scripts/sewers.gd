class_name Sewers
extends RefCounted
## The village's sewers, under the open-air map and not a level of their own: like the forgotten mine
## (see LostMine) and the bank's vault (see BankVault) they are a house sketch drawn on the map by
## HouseSketcher, every piece already built. Everything lies under whole ground (a buried ceiling,
## HouseSketch.BURIED); the grass, the streets and the houses stay as they are on top, and down
## there the surface hides as in any cellar (see CellarView).
##
## The water comes from the valley's river: a little stream runs up the pass beside the road to the
## village gate and dives under it through an iron grating (SewerSurface.MOUTH). Down here it runs as
## the channel of the main drain, slowly, with the village's leaves and rubbish on it, under the
## village to the north-west corner and out through the outfall into a river in the forest
## (SewerSurface.OUTFALL). A brick walkway runs beside the channel, behind a low kerb.
##
## Ways down from the surface: two manhole hatches in the village (SewerSurface.HATCH; the hero heaves
## the lid open and climbs down a ladder, see use) and the street drains (SewerSurface.GRILLE), which
## only let light and the sound of the street through. Cells are 2 m wide, one letter each:
##   "c"  the channel: water, behind a kerb, nobody walks in it
##   "w"  the walkway beside it, and the passages to the shafts
##   "s"  a shaft under a hatch: open to the sky, a ladder up to the street
##   "r"  a chamber of the labyrinth (and Spooknortz' hidden den, see Spooknortz): a bigger vault with pillars to run round (see ROOMS)
## Beside the walkway lies the labyrinth (see PASSAGES, ROOMS): two circuits, each leaving the walkway
## by a narrow passage, running through a chamber and coming back to the walkway further on, so the
## hero can go round and round without ever turning back. The vermin of the chambers (see MOBS)
## come back RESPAWN_AFTER seconds after they fell, about a lap later, out of sight.
## The drain's route is ROUTE, one corner after the other (cells of the plot).

## The plot the sewers are drawn on (map tiles): the village's west side, from the grating at the
## gate up to the outfall in the north-west corner.
const PLOT := Rect2i(37, 17, 13, 31)
## The channel's middle line, corner to corner in the direction of the flow (cells of the plot).
const ROUTE := [Vector2i(15, 57), Vector2i(15, 6), Vector2i(2, 6), Vector2i(2, 4)]
## The manhole hatches: the map tile of each, the cell of its shaft, the way its ladder leans up (the
## street cell next to the shaft that the hero climbs off at), and the cells of the passage to the walkway.
const HATCHES := [
	{"tile": Vector2i(42, 40), "cell": Vector2i(10, 46), "dir": "e", "passage": [Vector2i(11, 46), Vector2i(12, 46), Vector2i(13, 46)]},
	{"tile": Vector2i(40, 21), "cell": Vector2i(6, 8), "dir": "s", "passage": []},
]
## The street drains' tiles (their light shafts down here, see build).
const GRILLES := [Vector2i(44, 41), Vector2i(44, 38), Vector2i(44, 34), Vector2i(42, 20)]
## The narrow arched passages of the labyrinth, one cell wide: [first cell, last cell] in a straight line.
## Each runs from the walkway (x 14) to a chamber, or from chamber to chamber.
const PASSAGES := [
	[Vector2i(8, 52), Vector2i(13, 52)], [Vector2i(4, 38), Vector2i(4, 48)], [Vector2i(8, 34), Vector2i(13, 34)],
	[Vector2i(9, 20), Vector2i(13, 20)], [Vector2i(4, 12), Vector2i(4, 16)], [Vector2i(5, 12), Vector2i(13, 12)],
]
## The chambers, 7 x 7 cells (14 m) or so: Rect2i of cells. (A cell of stone stays between the middle chamber
## and the cellar of the village hall to its north-east, or the two would join into one pit.)
const ROOMS := [Rect2i(1, 49, 7, 7), Rect2i(1, 31, 7, 7), Rect2i(2, 17, 7, 7)]
## The pillars in the chambers, left standing in the dug stone: something to run round or hide behind.
const PILLARS := [Vector2i(4, 52), Vector2i(6, 54), Vector2i(4, 34), Vector2i(2, 36), Vector2i(5, 20), Vector2i(3, 18)]
## The vermin of the labyrinth: [kind of Enemy.KINDS (wildlife), cell].
const MOBS := [
	["schleim", Vector2i(3, 53)], ["schleim", Vector2i(5, 50)], ["spinne", Vector2i(2, 54)],
	["fledermaus", Vector2i(4, 43)], ["fledermaus", Vector2i(10, 52)],
	["spinne", Vector2i(2, 32)], ["spinne", Vector2i(6, 37)], ["schleim", Vector2i(6, 32)],
	["schleim", Vector2i(4, 22)], ["schleim", Vector2i(7, 19)], ["spinne", Vector2i(2, 22)],
	["fledermaus", Vector2i(9, 12)],
]
## Seconds until a fallen one is back at its post: a lap of the bigger circuit (about 115 m at the
## hero's pace, Player.SPEED) with the fights on the way, so the chambers fill up just as the next
## lap begins. It only returns while the hero is farther than RESPAWN_AWAY metres from its post.
const RESPAWN_AFTER := 75.0
const RESPAWN_AWAY := 16.0
## The lamps on the walls: every this many cells of the walkway.
const LAMP_EVERY := 8

const BRICK_COLOUR := Color(0.62, 0.3, 0.17)
const IRON := Color(0.2, 0.2, 0.22)
const LAMP_COLOUR := Color(1.0, 0.72, 0.42)
const DAYLIGHT := Color(0.78, 0.9, 1.0)
## How high the kerb beside the channel is (the water lies below it).
const KERB_HIGH := 0.55
const WATER_RISE := 0.3
const W := preload("res://scripts/weathered_props.gd")

const KIND_LID := SewerSurface.LID
const LEARN := "Die Kanalisation: Unter dem Dorf läuft der Bach aus dem Tal durch einen gemauerten Gang, vom Gitter am Dorftor bis zum Auslauf im Nordwesten. Das Wasser trägt den Unrat des Dorfes mit sich fort. Hinab geht es durch die Kanalluken und über Leitern."
const ENTERED := "Du steigst in die Kanalisation hinab. Es riecht nach Moder, und irgendwo rauscht Wasser."
const LID_OPENED := "Du stemmst den schweren Deckel auf. Eine Leiter führt hinab in die Dunkelheit."
const LID_PROMPT := "Anklicken oder dagegenlaufen, um die Kanalluke zu öffnen und hinabzusteigen"
const LID_DOWN_PROMPT := "Anklicken, um die Leiter hinabzusteigen"
## Seconds a lid stays open before it falls shut.
static var open_for := 60.0
## Seconds the lid takes to swing open (see SewerSurface.swing_open).
const LID_SWING := 0.9

## The luke lids the hero has opened this session (tile -> true).
static var opened := {}

static var _sketch: HouseSketch = null
static var _cells := {}
static var _channel := {}
static var _mats := {}
static var _told := false


## Every dug cell of the sewers: Vector2i (plot cells) -> its letter (see the class notes).
static func cells() -> Dictionary:
	if _cells.is_empty():
		_lay()
	return _cells


## The channel's cells, each with the way the water flows through it (a unit step).
static func channel() -> Dictionary:
	if _cells.is_empty():
		_lay()
	return _channel


static func _lay() -> void:
	var flow := {}
	for i in ROUTE.size() - 1:
		var a: Vector2i = ROUTE[i]
		var b: Vector2i = ROUTE[i + 1]
		var step := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
		var at := a
		while true:
			flow[at] = step
			if at == b:
				break
			at += step
	# The last cell flows on as the leg before it ended: out through the outfall.
	for c: Vector2i in flow:
		_channel[c] = flow[c]
		_cells[c] = "c"
	# The walkway on the left of the flow (looking along it); the corners take the inside one.
	for c: Vector2i in flow:
		var step: Vector2i = flow[c]
		var left := Vector2i(step.y, -step.x)
		var w := c + left
		if not flow.has(w) and not _cells.has(w):
			_cells[w] = "w"
	# The corner cells next to a turn, so the walkway runs round it unbroken.
	var corners: Array[Vector2i] = []
	for i in range(1, ROUTE.size() - 1):
		corners.append(ROUTE[i])
	for corner in corners:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			var w: Vector2i = corner + d
			var near_walk := false
			for e: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if _cells.get(w + e, "") == "w":
					near_walk = true
			if near_walk and not flow.has(w) and not _cells.has(w) and _touches_channel(w, flow):
				_cells[w] = "w"
	for hatch: Dictionary in HATCHES:
		_cells[hatch.cell] = "s"
		for c: Vector2i in hatch.passage:
			_cells[c] = "w"
	for room: Rect2i in ROOMS:
		for y in range(room.position.y, room.end.y):
			for x in range(room.position.x, room.end.x):
				_cells[Vector2i(x, y)] = "r"
	for pass_: Array in PASSAGES:
		var a: Vector2i = pass_[0]
		var b: Vector2i = pass_[1]
		var step := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
		var at := a
		while true:
			if not _cells.has(at):
				_cells[at] = "w"
			if at == b:
				break
			at += step
	# The hidden den behind the false wall (see Spooknortz): a passage and a chamber.
	for c: Vector2i in Spooknortz.PASSAGE:
		_cells[c] = "w"
	for y in range(Spooknortz.DEN.position.y, Spooknortz.DEN.end.y):
		for x in range(Spooknortz.DEN.position.x, Spooknortz.DEN.end.x):
			_cells[Vector2i(x, y)] = "r"
	for c: Vector2i in PILLARS:
		_cells.erase(c)


static func _touches_channel(c: Vector2i, flow: Dictionary) -> bool:
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		if flow.has(c + d):
			return true
	return false


## The sewers as a house sketch, every piece built: dug cells with brick floors and walls, the buried
## ceiling over all of them but the shafts, and a ladder in every shaft.
static func sketch() -> HouseSketch:
	if _sketch != null:
		return _sketch
	var s := HouseSketch.new()
	s.plot = PLOT
	s.flush_ladders = true
	var built := HouseSketch.BUILT
	for c: Vector2i in cells():
		s.pieces[HouseSketch.key_of(c.x, c.y, HouseSketch.CELL_ORIENT, HouseSketch.CELLAR_STOREY)] = {"kind": HouseSketch.DIG, "state": built, "floor": "brick:%d" % variant_at(c), "wall": "brick:%d" % variant_at(c + Vector2i(5, 9))}
		if cells()[c] != "s":
			s.pieces[HouseSketch.key_of(c.x, c.y, HouseSketch.COVER_ORIENT, HouseSketch.CELLAR_STOREY)] = {"kind": HouseSketch.COVER, "state": built, "surface": HouseSketch.BURIED}
	for hatch: Dictionary in HATCHES:
		var c: Vector2i = hatch.cell
		s.pieces[HouseSketch.key_of(c.x, c.y, HouseSketch.LADDER_ORIENTS[hatch.dir], HouseSketch.CELLAR_STOREY)] = {"kind": HouseSketch.LADDER, "state": built}
	_sketch = s
	return s


## The hatch spec standing on map tile `c`, or {}.
static func hatch_at(c: Vector2i) -> Dictionary:
	for hatch: Dictionary in HATCHES:
		if hatch.tile == c:
			return hatch
	return {}


## Whether map tile `c` lies over the sewers: no plot may be marked out there (see Plots.problem).
static func covers_tile(c: Vector2i) -> bool:
	if not PLOT.has_point(c):
		return false
	var first := (c - PLOT.position) * HouseSketch.CELLS_PER_TILE
	for dy in HouseSketch.CELLS_PER_TILE:
		for dx in HouseSketch.CELLS_PER_TILE:
			if cells().has(first + Vector2i(dx, dy)):
				return true
	return false


## The sewers' cell under a world point (plot cells), whether or not it is dug.
static func cell_at(pos: Vector3) -> Vector2i:
	var origin := sketch().node_world(0, 0)
	return Vector2i(floori((pos.x - origin.x) / HouseSketch.CELL), floori((pos.z - origin.z) / HouseSketch.CELL))


## Whether a world point lies down in the sewers (below the ground, within its cells).
static func holds(pos: Vector3) -> bool:
	return pos.y < -1.0 and cells().has(cell_at(pos))


## The size of the cell grid of the plot (for the map's record of what the hero has seen).
static func grid_size() -> Vector2i:
	return PLOT.size * HouseSketch.CELLS_PER_TILE


## The cells the hero sees from `pos` down here: the cells within `radius` steps along the tunnels.
## The hidden den and its passage do not count until the false wall has given way.
static func seen_from(pos: Vector3, radius: int, den_open := false) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not holds(pos):
		return out
	var start := cell_at(pos)
	var dist := {start: 0}
	var todo: Array[Vector2i] = [start]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_front()
		out.append(c)
		if dist[c] >= radius:
			continue
		for d: Vector2i in HouseSketch.DOWN.values():
			var n: Vector2i = c + d
			if dist.has(n) or not cells().has(n) or (not den_open and Spooknortz.hides(n)):
				continue
			dist[n] = dist[c] + 1
			todo.append(n)
	return out


## The middle of a cell's floor.
static func floor_at(c: Vector2i) -> Vector3:
	return sketch().cell_world(c.x, c.y) + Vector3(0, -HouseSketch.DEPTH, 0)


## Whether `a` and `b` are on two sides of the ground: one down in the sewers, the other not.
static func apart(a: Vector3, b: Vector3) -> bool:
	return holds(a) != holds(b)


## The map tile above a plot cell.
static func tile_of(c: Vector2i) -> Vector2i:
	return PLOT.position + Vector2i(floori(c.x / 2.0), floori(c.y / 2.0))


# --- Hints, the lids and the first descent --------------------------------------

static func prompt(kind: String, station := {}) -> String:
	if kind == KIND_LID:
		return Lang.t(LID_DOWN_PROMPT if opened.has(station.get("key", Vector2i(-1, -1))) else LID_PROMPT)
	return Spooknortz.prompt(kind)


## The hero ran into a hatch's lid or clicked the hatch: a shut lid is heaved open (it stays open), then
## the hero walks up to the head of the ladder, if not there yet, and climbs down.
static func use(game: Node, s: Dictionary) -> void:
	if s.kind != KIND_LID:
		return
	if not opened.has(s.key):
		opened[s.key] = true
		SewerSurface.swing_open(s)
		Sfx.play(game, "secret", -4.0)
		game.show_message(Lang.t(LID_OPENED), 4.0)
		_close_later(game, s)
		await game.get_tree().create_timer(LID_SWING).timeout
	var stand: Vector3 = s.stand
	var here: Vector3 = game.player.global_position
	if Vector2(here.x - stand.x, here.z - stand.z).length() > 1.3:
		game.player.walk_to(stand, 0.3)
		game._pending_station = s
		return
	game.player.path.clear()
	game.player.climb_down_at(stand)


## An open lid falls shut again after `open_for` seconds, but not while the hero is down in the sewers,
## on a ladder or standing by the hatch (it is tried again every few seconds).
static func _close_later(game: Node, s: Dictionary) -> void:
	await game.get_tree().create_timer(open_for).timeout
	while opened.has(s.key) and is_instance_valid(s.get("hinge")) and game.is_inside_tree():
		var at: Vector3 = game.player.global_position
		var stand: Vector3 = s.stand
		if holds(at) or game.player.on_ladder() or Vector2(at.x - stand.x, at.z - stand.z).length() < 3.0:
			await game.get_tree().create_timer(5.0).timeout
			continue
		opened.erase(s.key)
		SewerSurface.swing_shut(s)
		return


## Down in the sewers (every frame the hero is): the first time the compendium learns of them.
static func entered(game: Node) -> void:
	_rouse_vermin(game)
	Spooknortz.tend(game)
	if _told or game.lore.has(LEARN):
		_told = true
		return
	_told = true
	Events.teach(LEARN)
	Events.tell(Lang.t(ENTERED), Color(0.7, 0.85, 0.6))


# --- The vermin of the labyrinth ----------------------------------------------------

## The meta every one of the vermin carries: they never fight each other.
const PEACE := "sewer_vermin"
## The vermin of the chambers (see MOBS), one entry each: {"kind", "cell", "enemy", "fell"}; `fell` is
## the time it fell, in seconds (-1 while it lives).
static var _vermin: Array = []
## A fixed time of the clock, in seconds (for the tests; -1 lets it run).
static var clock_stopped := -1.0


static func now() -> float:
	return clock_stopped if clock_stopped >= 0.0 else Time.get_ticks_msec() / 1000.0


## The vermin of the labyrinth.
static func vermin() -> Array:
	if _vermin.size() != MOBS.size():
		_vermin.clear()
		for m: Array in MOBS:
			_vermin.append({"kind": m[0], "cell": m[1], "enemy": null, "fell": -1.0})
	return _vermin


## Down in the sewers (every frame the hero is): each one not standing yet is set at its post, once
## RESPAWN_AFTER seconds have passed since it fell and the hero is not near its post.
static func _rouse_vermin(game: Node) -> void:
	var level: Level = game.level
	var hero: Vector3 = game.player.global_position
	for g: Dictionary in vermin():
		var e = g.enemy
		var alive: bool = e != null and is_instance_valid(e) and not e.dead
		if alive and e.level == level:
			continue
		if e != null and is_instance_valid(e) and e.dead and float(g.fell) < 0.0:
			continue
		if float(g.fell) >= 0.0:
			if now() - float(g.fell) < RESPAWN_AFTER:
				continue
			var post := floor_at(g.cell)
			if Vector2(hero.x - post.x, hero.z - post.z).length() < RESPAWN_AWAY:
				continue
			g.fell = -1.0
		g.enemy = _raise(level, g)


static func _raise(level: Level, g: Dictionary) -> Enemy:
	var e := Enemy.new()
	e.kind = g.kind
	e.level = level
	# The vermin of the chambers leave one another alone (rivals among them would thin each other
	# out while the hero is away, see Enemy._pick_rival).
	e.set_meta(PEACE, true)
	level.add_child(e)
	e.global_position = floor_at(g.cell)
	e.reset_physics_interpolation()
	e.died.connect(func():
		level.enemy_killed.emit(e)
		g.fell = now()
		var purse: Array = Enemy.KINDS[e.kind].get("purse", [0, 0])
		level.drop_kill_loot(e, randi_range(purse[0], purse[1])))
	level.enemies = level.enemies.filter(func(x): return is_instance_valid(x))
	level.enemies.append(e)
	return e


## The vermin standing now (for the tests).
static func standing() -> Array:
	var out: Array = []
	for g: Dictionary in vermin():
		if g.enemy != null and is_instance_valid(g.enemy) and not g.enemy.dead:
			out.append(g.enemy)
	return out


# --- The look: brick -------------------------------------------------------------

## How many grimy variants of brick there are: a wall, a floor cell, picks one by its place (see variant_at).
const VARIANTS := 4

## The wall brick: orange-red courses with grimy mortar, laid in world space (triplanar). `variant` is how
## the grime lies: 0 damp and mossy, 1 dripping slime and algae, 2 water marks of old floods, 3 all of it.
static func brick_material(variant := 0) -> StandardMaterial3D:
	variant = posmod(variant, VARIANTS)
	var key := "brick_%d" % variant
	if not _mats.has(key):
		_mats[key] = _brick_stuff(1.0, 0.62, variant, false)
	return _mats[key]


## The floor: darker, wetter brick underfoot, with muck and puddles.
static func floor_material(variant := 0) -> StandardMaterial3D:
	variant = posmod(variant, VARIANTS)
	var key := "floor_%d" % variant
	if not _mats.has(key):
		_mats[key] = _brick_stuff(0.55, 0.5, variant, true)
	return _mats[key]


## The grime variant of a cell of the plot: the same cell always looks the same, neighbours differ.
static func variant_at(c: Vector2i) -> int:
	return posmod(hash(Vector3i(c.x * 7 + 3, c.y * 13 + 5, 17)), VARIANTS)


## The grime variant a surface name carries: "brick" is 0, "brick:2" is 2.
static func variant_of(surface: String) -> int:
	return int(surface.substr(6)) if surface.length() > 6 else 0


## A smooth, wrapping field of noise, `n` x `n` values in 0..1 with a feature every `n / freq` values.
static func _field(n: int, freq: int, seed_: int) -> PackedFloat32Array:
	var lattice := PackedFloat32Array()
	lattice.resize(freq * freq)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	for i in lattice.size():
		lattice[i] = rng.randf()
	var out := PackedFloat32Array()
	out.resize(n * n)
	for y in n:
		var fy := float(y) / n * freq
		var iy := int(fy)
		var ty := fy - iy
		ty = ty * ty * (3.0 - 2.0 * ty)
		for x in n:
			var fx := float(x) / n * freq
			var ix := int(fx)
			var tx := fx - ix
			tx = tx * tx * (3.0 - 2.0 * tx)
			var a := lattice[iy * freq + ix]
			var b := lattice[iy * freq + (ix + 1) % freq]
			var c := lattice[((iy + 1) % freq) * freq + ix]
			var d := lattice[((iy + 1) % freq) * freq + (ix + 1) % freq]
			out[y * n + x] = lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)
	return out


## The value of a wrapping field (see _field) at pixel (x, y) of a picture `size` wide.
static func _at(field: PackedFloat32Array, n: int, x: int, y: int, size: int) -> float:
	var fx := float(x) / size * n
	var fy := float(y) / size * n
	var ix := int(fx)
	var iy := int(fy)
	var tx := fx - ix
	var ty := fy - iy
	var a := field[iy * n + ix]
	var b := field[iy * n + (ix + 1) % n]
	var c := field[((iy + 1) % n) * n + ix]
	var d := field[((iy + 1) % n) * n + (ix + 1) % n]
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)


## Lays the grime of `variant` over the brick picture `img` (and returns how rough every pixel is, for a wet
## look: slime and puddles shine). Slime drips down in dark green streaks from the top of the picture, moss
## and algae grow in the damp low down and in the mortar, a tide line of old floods stains the wall, and on the
## floor muck and puddles lie in patches.
static func _grime(img: Image, height: PackedFloat32Array, size: int, variant: int, floorish: bool, base_rough: float) -> Image:
	var data := img.get_data()
	var roughs := PackedByteArray()
	roughs.resize(size * size * 3)
	var n := 64
	var seed_ := hash("kanalschmutz%d%s" % [variant, floorish])
	var damp := _field(n, 4, seed_ + 1)
	var moss := _field(n, 8, seed_ + 2)
	var fine := _field(n, 16, seed_ + 3)
	var muck := _field(n, 4, seed_ + 4)
	var puddle := _field(n, 3, seed_ + 5)
	var drips := _field(n, 16, seed_ + 6)
	var reach := _field(n, 4, seed_ + 7)
	var slimy := variant == 1 or variant == 3
	var marked := variant == 2 or variant == 3
	var tide := 0.26 + 0.1 * float(variant % 2)
	# What depends on the column only: where a drip runs, how far, and how the tide line wobbles.
	var col_drip := PackedFloat32Array()
	var col_run := PackedFloat32Array()
	var col_wobble := PackedFloat32Array()
	for x in size:
		col_drip.append(smoothstep(0.62, 0.78, _at(drips, n, x, 0, size)))
		var along := _at(reach, n, x, 0, size)
		col_run.append(0.25 + 0.7 * along)
		col_wobble.append((along - 0.5) * 0.04)
	for y in size:
		var v := float(y) / size
		for x in size:
			var at := (y * size + x) * 3
			var col := Color(data[at] / 255.0, data[at + 1] / 255.0, data[at + 2] / 255.0)
			var rough := base_rough
			var mortar := height[y * size + x] < 0.05
			var wetness := clampf((v - 0.35) * 1.8, 0.0, 1.0) * (0.35 + 0.65 * _at(damp, n, x, y, size))
			col = col.lerp(col * 0.62, wetness * 0.6)
			# Moss and algae: patches in the damp, thick in the mortar.
			var small := _at(fine, n, x, y, size)
			var m := _at(moss, n, x, y, size) * 0.7 + small * 0.3
			var mossy := smoothstep(0.58, 0.8, m + wetness * 0.16 + (0.08 if mortar else 0.0))
			if mossy > 0.0:
				var green := Color(0.17, 0.3, 0.09).lerp(Color(0.3, 0.38, 0.12), small)
				col = col.lerp(green, mossy * (0.75 if mortar else 0.45))
			if slimy:
				# A drip starts at the top and runs down, thinning out.
				var slime: float = col_drip[x] * (1.0 - smoothstep(0.0, col_run[x], v))
				if slime > 0.0:
					col = col.lerp(Color(0.1, 0.2, 0.07), slime * 0.7)
					rough = lerpf(rough, 0.12, slime)
			if marked and not floorish:
				# The tide lines of old floods: a dark edge, brown stain below it, a pale salt line above.
				var wobble: float = col_wobble[x]
				for line: float in [tide, fposmod(tide + 0.5, 1.0)]:
					var dv := v - (line + wobble)
					if dv > 0.0:
						col = col.lerp(col * Color(0.62, 0.55, 0.4), 0.35 * (1.0 - smoothstep(0.0, 0.2, dv)))
					if absf(dv) < 0.012:
						col = col.lerp(Color(0.16, 0.12, 0.07), 0.7)
					elif dv < 0.0 and dv > -0.03:
						col = col.lerp(Color(0.72, 0.68, 0.58), 0.22 * (1.0 + dv / 0.03))
			if floorish:
				var mk := smoothstep(0.5, 0.78, _at(muck, n, x, y, size) * 0.8 + small * 0.2)
				if mk > 0.0:
					col = col.lerp(col * Color(0.5, 0.45, 0.38), mk * 0.65)
					rough = lerpf(rough, 0.3, mk)
				var pd := smoothstep(0.6, 0.8, _at(puddle, n, x, y, size))
				if pd > 0.0:
					col = col.lerp(col * Color(0.45, 0.55, 0.5), pd * 0.6)
					rough = lerpf(rough, 0.06, pd)
			data[at] = int(clampf(col.r, 0.0, 1.0) * 255.0)
			data[at + 1] = int(clampf(col.g, 0.0, 1.0) * 255.0)
			data[at + 2] = int(clampf(col.b, 0.0, 1.0) * 255.0)
			var r8 := int(clampf(rough, 0.0, 1.0) * 255.0)
			roughs[at] = r8
			roughs[at + 1] = r8
			roughs[at + 2] = r8
	img.set_data(size, size, false, Image.FORMAT_RGB8, data)
	return Image.create_from_data(size, size, false, Image.FORMAT_RGB8, roughs)


## The bare brick picture of a shade (`darker`): its pixels, heights and normal map, made once and shared
## by the grime variants.
static var _bases := {}

static func _brick_base(darker: float) -> Dictionary:
	if _bases.has(darker):
		return _bases[darker]
	var size := 256
	var rows := 16
	var wide := 46
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var height := PackedFloat32Array()
	height.resize(size * size)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("kanalziegel")
	var mortar := Color(0.36, 0.33, 0.28)
	for row in rows:
		var shift := (row % 2) * wide / 2
		var tint := BRICK_COLOUR.lerp(Color(0.5, 0.36, 0.2), rng.randf() * 0.45)
		for y in range(row * size / rows, (row + 1) * size / rows):
			var local_y := y - row * size / rows
			for x in size:
				var bx := (x + shift) % wide
				var cell := int(((x + shift) / wide) + row * 7)
				var shade := 0.82 + 0.3 * fposmod(sin(float(cell) * 12.9898) * 43758.5453, 1.0)
				var col := tint * shade
				var h := 1.0
				if bx < 2 or local_y < 2:
					col = mortar
					h = 0.0
				else:
					# A brick's edge is rounded and its face pitted.
					var edge := minf(minf(float(bx - 2), float(wide - bx)), minf(float(local_y - 2), float(size / rows - local_y)))
					h = clampf(0.55 + edge * 0.18, 0.0, 1.0) - rng.randf() * 0.12
					col = col.lerp(Color(0.2, 0.15, 0.1), rng.randf() * 0.18)
				height[y * size + x] = h
				img.set_pixel(x, y, Color(col.r * darker, col.g * darker, col.b * darker))
	var base := {"data": img.get_data(), "height": height, "normal": ImageTexture.create_from_image(_normals_of(height, size, 2.4))}
	_bases[darker] = base
	return base


static func _brick_stuff(darker: float, rough: float, variant := 0, floorish := false) -> StandardMaterial3D:
	var size := 256
	var base := _brick_base(darker)
	var img := Image.create_from_data(size, size, false, Image.FORMAT_RGB8, base.data)
	var wet := _grime(img, base.height, size, variant, floorish, rough)
	var mat := StandardMaterial3D.new()
	# Mipmaps, or the fine courses of brick shimmer as the view moves.
	img.generate_mipmaps()
	wet.generate_mipmaps()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.roughness_texture = ImageTexture.create_from_image(wet)
	mat.normal_enabled = true
	mat.normal_texture = base.normal
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE * 0.8
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.roughness = 1.0
	return mat


## The kerb and block stone: dressed blocks in courses with a rough face and worn edges.
static func stone_material() -> StandardMaterial3D:
	if _mats.has("stone_blocks"):
		return _mats["stone_blocks"]
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var height := PackedFloat32Array()
	height.resize(size * size)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("kanalstein")
	var course := 64
	for row in size / course:
		var wide := 104 if row % 2 == 0 else 152
		var shift := (row * 37) % wide
		var tint := Color(0.46, 0.45, 0.4).lerp(Color(0.38, 0.4, 0.36), rng.randf())
		for y in range(row * course, (row + 1) * course):
			for x in size:
				var bx := (x + shift) % wide
				var local_y := y - row * course
				var grain := rng.randf()
				var col := tint * (0.86 + 0.24 * grain)
				var h := 0.8 - grain * 0.25
				if bx < 3 or local_y < 3:
					col = Color(0.2, 0.2, 0.18)
					h = 0.0
				else:
					var edge := minf(minf(float(bx - 3), float(wide - bx)), minf(float(local_y - 3), float(course - local_y)))
					h = clampf(h * (0.5 + edge * 0.1), 0.0, 1.0)
					# Green damp creeping up from the foot of the course.
					col = col.lerp(Color(0.22, 0.3, 0.16), clampf(0.5 - float(local_y) / course, 0.0, 0.5) * 0.4 * rng.randf())
				height[y * size + x] = h
				img.set_pixel(x, y, Color(col.r, col.g, col.b))
	var mat := StandardMaterial3D.new()
	# Mipmaps, or the fine courses of brick shimmer as the view moves.
	img.generate_mipmaps()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.normal_enabled = true
	mat.normal_texture = ImageTexture.create_from_image(_normals_of(height, size, 3.0))
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE * 0.7
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.roughness = 0.78
	_mats["stone_blocks"] = mat
	return mat


## A normal map from a height field (size x size, wrapping), `strength` times as steep.
static func _normals_of(height: PackedFloat32Array, size: int, strength: float) -> Image:
	var img := Image.create(size, size, true, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var dx := height[y * size + (x + 1) % size] - height[y * size + (x + size - 1) % size]
			var dy := height[((y + 1) % size) * size + x] - height[((y + size - 1) % size) * size + x]
			var n := Vector3(-dx * strength, -dy * strength, 1.0).normalized()
			img.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))
	img.generate_mipmaps(true)
	return img


# --- What stands down there --------------------------------------------------------

## Builds everything down here that is no part of the sketch, under `parent` (shown only while the
## hero is down in a cellar): the kerb and the water of the channel with the rubbish it carries, the
## sluice where the stream comes in, the outfall's bars, the lamps, the slime patches on the floor (see
## SewerSlime) and the light shafts under the
## street drains. The kerb stops the hero (nobody wades the channel); so do the bars.
static func build(level: Level, parent: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "SewerSolids"
	parent.add_child(body)
	_channel_water(parent, body)
	_sluice(parent, body)
	_outfall_bars(parent, body)
	_lamps(parent)
	_ribs(parent)
	_litter(parent)
	_pipes(parent)
	SewerSlime.build(parent)
	for tile: Vector2i in GRILLES:
		_light_shaft(parent, tile)
	for hatch: Dictionary in HATCHES:
		_hatch_light(parent, hatch)
	Spooknortz.build_world(level, parent, body)


## The channel: one water sheet and kerb per cell, a block of solid over it, and the leaves and
## rubbish drifting along each straight stretch.
static func _channel_water(parent: Node3D, body: StaticBody3D) -> void:
	var stone: Material = stone_material()
	var kerb_w := 0.3
	for c: Vector2i in channel():
		var mid := floor_at(c)
		_solid(body, mid + Vector3(0, 0.7, 0), Vector3(HouseSketch.CELL - 0.04, 1.4, HouseSketch.CELL - 0.04))
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if cells().get(c + d, "") != "w":
				continue
			# A kerb on the walkway's side of the cell.
			var at := mid + Vector3(d.x, 0, d.y) * (HouseSketch.CELL * 0.5 - kerb_w * 0.5)
			var size := Vector3(kerb_w, KERB_HIGH, HouseSketch.CELL) if d.x != 0 else Vector3(HouseSketch.CELL, KERB_HIGH, kerb_w)
			_box(parent, at + Vector3(0, (KERB_HIGH - 0.08) * 0.5, 0), size - Vector3(0, 0.08, 0) if d.x != 0 else size - Vector3(0, 0.08, 0), stone)
			# The capstone overhangs the kerb a little on both sides, its edge worn.
			var cap := Vector3(kerb_w + 0.1, 0.1, HouseSketch.CELL) if d.x != 0 else Vector3(HouseSketch.CELL, 0.1, kerb_w + 0.1)
			_box(parent, at + Vector3(0, KERB_HIGH - 0.04, 0), cap, stone)
		var sheet := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(HouseSketch.CELL, HouseSketch.CELL)
		sheet.mesh = plane
		sheet.material_override = _water(_channel[c])
		sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sheet.position = mid + Vector3(0, WATER_RISE, 0)
		parent.add_child(sheet)
	# Rubbish on every straight stretch.
	for i in ROUTE.size() - 1:
		var a: Vector2i = ROUTE[i]
		var b: Vector2i = ROUTE[i + 1]
		var from := floor_at(a)
		var to := floor_at(b)
		var flow := StreamFlow.new()
		flow.from = from + Vector3(0, WATER_RISE + 0.03, 0)
		flow.to = to + Vector3(0, WATER_RISE + 0.03, 0)
		flow.width = HouseSketch.CELL - 0.5
		flow.speed = 0.4
		flow.count = clampi(int(from.distance_to(to) * 1.4), 12, 60)
		flow.rubbish = true
		flow.palette = StreamFlow.RUBBISH
		parent.add_child(flow)


static func _water(step: Vector2i) -> ShaderMaterial:
	var key := "water_%d_%d" % [step.x, step.y]
	if not _mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/sewer_water.gdshader")
		m.set_shader_parameter("flow", Vector2(step.x, step.y))
		_mats[key] = m
	return _mats[key]


## Where the stream comes in: the south wall of the channel's first cell has an iron grille in it,
## daylight and foam behind it.
static func _sluice(parent: Node3D, body: StaticBody3D) -> void:
	var c: Vector2i = ROUTE[0]
	var wall := floor_at(c) + Vector3(0, 0, HouseSketch.CELL * 0.5 - 0.1)
	var iron := _mat("iron", IRON, 0.6)
	var high := 1.7
	for i in 7:
		_box(parent, wall + Vector3(-0.75 + i * 0.25, 0.3 + high * 0.5, -0.04), Vector3(0.06, high, 0.06), iron)
	for y: float in [0.5, 1.2, 1.9]:
		_box(parent, wall + Vector3(0, y, -0.02), Vector3(1.7, 0.08, 0.06), iron)
	_box(parent, wall + Vector3(0, 0.3 + high * 0.5, 0.03), Vector3(1.8, high, 0.04), _mat("day", DAYLIGHT.darkened(0.2), 0.0, 1.6))
	var light := OmniLight3D.new()
	light.light_color = DAYLIGHT
	light.light_energy = 2.2
	light.omni_range = 7.0
	light.position = wall + Vector3(0, 1.4, -0.7)
	parent.add_child(light)
	_solid(body, wall + Vector3(0, 1.2, 0), Vector3(2.0, 2.4, 0.3))


## The outfall's bars across the tunnel's end (both cells: the channel and the walkway), and the green
## daylight of the forest behind them.
static func _outfall_bars(parent: Node3D, body: StaticBody3D) -> void:
	var c: Vector2i = ROUTE[ROUTE.size() - 1]
	var mid := floor_at(c) + Vector3(-HouseSketch.CELL * 0.5, 0, -HouseSketch.CELL * 0.5)
	var iron := _mat("iron", IRON, 0.6)
	var wide := HouseSketch.CELL * 2.0 - 0.3
	var high := HouseSketch.DEPTH - 0.4
	var n := 14
	for i in n + 1:
		_box(parent, mid + Vector3(-wide * 0.5 + i * wide / n, high * 0.5, 0.05), Vector3(0.05, high, 0.05), iron)
	for y: float in [0.3, high * 0.5, high - 0.2]:
		_box(parent, mid + Vector3(0, y, 0.05), Vector3(wide, 0.07, 0.07), iron)
	_box(parent, mid + Vector3(0, high * 0.5, -0.1), Vector3(wide, high, 0.04), _mat("forest_light", Color(0.7, 0.9, 0.7), 0.0, 1.2))
	_solid(body, mid + Vector3(0, high * 0.5, 0.05), Vector3(wide, high, 0.3))
	var light := OmniLight3D.new()
	light.light_color = Color(0.8, 1.0, 0.8)
	light.light_energy = 1.6
	light.omni_range = 7.0
	light.position = mid + Vector3(0, 1.5, 1.2)
	parent.add_child(light)


## A lamp on the wall every LAMP_EVERY cells of the walkway, away from the channel.
static func _lamps(parent: Node3D) -> void:
	var n := 0
	var m := 0
	for c: Vector2i in cells():
		if cells()[c] == "r":
			m += 1
			if m % 12 != 5:
				continue
		elif cells()[c] != "w":
			continue
		else:
			n += 1
			if n % LAMP_EVERY != 0:
				continue
		# The wall: the open side facing away from the channel.
		var out := Vector2i.ZERO
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not cells().has(c + d):
				out = d
		if out == Vector2i.ZERO:
			continue
		var wall := floor_at(c) + Vector3(out.x, 0, out.y) * (HouseSketch.CELL * 0.5 - 0.05)
		var at := wall - Vector3(out.x, 0, out.y) * 0.25 + Vector3(0, 1.6, 0)
		var iron := _mat("iron", IRON, 0.6)
		_box(parent, wall - Vector3(out.x, 0, out.y) * 0.05 + Vector3(0, 1.6, 0), Vector3(0.16, 0.36, 0.16), iron)
		_box(parent, at, Vector3(0.2, 0.26, 0.2), _mat("lamp_glass", LAMP_COLOUR, 0.0, 2.5))
		var light := OmniLight3D.new()
		light.light_color = LAMP_COLOUR
		light.light_energy = 1.7
		light.omni_range = 6.5
		light.position = at - Vector3(out.x, 0, out.y) * 0.3
		parent.add_child(light)


## Daylight down from a street drain: no beam to see, only real, soft light that spreads wide: a broad
## spot that falls off gently towards its edge and a weak glow round it, neither casting shadows.
static func _light_shaft(parent: Node3D, tile: Vector2i) -> void:
	var top := Vector3(tile.x * Level.TILE, 0.0, tile.y * Level.TILE)
	var light := SpotLight3D.new()
	light.light_color = DAYLIGHT
	light.light_energy = 1.1
	light.spot_range = HouseSketch.DEPTH + 5.0
	light.spot_angle = 62.0
	light.spot_angle_attenuation = 2.2
	light.shadow_enabled = false
	light.position = top + Vector3(0, -0.1, 0)
	light.rotation_degrees = Vector3(-90, 0, 0)
	parent.add_child(light)
	var glow := OmniLight3D.new()
	glow.light_color = DAYLIGHT
	glow.light_energy = 0.35
	glow.omni_range = 8.0
	glow.omni_attenuation = 1.4
	glow.shadow_enabled = false
	glow.position = top + Vector3(0, -HouseSketch.DEPTH * 0.7, 0)
	parent.add_child(glow)


## A little daylight down a manhole's shaft, so it is seen from the walkway.
static func _hatch_light(parent: Node3D, hatch: Dictionary) -> void:
	var at := sketch().cell_world(hatch.cell.x, hatch.cell.y)
	var light := OmniLight3D.new()
	light.light_color = DAYLIGHT
	light.light_energy = 1.4
	light.omni_range = 5.0
	light.position = at + Vector3(0, -0.8, 0)
	parent.add_child(light)


static func _mat(key: String, colour: Color, metal := 0.0, glow := 0.0) -> StandardMaterial3D:
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = colour
		m.roughness = 0.9 if metal == 0.0 else 0.45
		m.metallic = metal
		if glow > 0.0:
			m.emission_enabled = true
			m.emission = colour
			m.emission_energy_multiplier = glow
		_mats[key] = m
	return _mats[key]


static func _box(parent: Node3D, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	m.mesh = box
	m.material_override = mat
	m.position = at
	parent.add_child(m)
	return m


static func _solid(body: StaticBody3D, at: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	body.add_child(shape)


# --- The vault: brick ribs, litter and pipes ----------------------------------------

## Brick arch ribs across the tunnel every RIB_EVERY cells of a straight stretch: the barrel vault's
## ribs spring from the walls and meet over the walkway and the channel. The ceiling itself is the ground
## the view is cut through, so the ribs are what shows of the vault from above.
const RIB_EVERY := 3
const RIB_SPRING := 1.55

static func _ribs(parent: Node3D) -> void:
	var brick: Material = brick_material()
	for i in ROUTE.size() - 1:
		var a: Vector2i = ROUTE[i]
		var b: Vector2i = ROUTE[i + 1]
		var step := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
		var left := Vector2i(step.y, -step.x)
		var count := maxi(absi(b.x - a.x), absi(b.y - a.y))
		for k in range(2, count - 1, RIB_EVERY):
			var c := a + step * k
			# Not over a passage or a shaft: the tunnel is wider there.
			if cells().get(c + left * 2, "") != "" or cells().get(c - left, "") != "":
				continue
			var at := floor_at(c) + Vector3(left.x, 0, left.y) * (HouseSketch.CELL * 0.5)
			_arch(parent, at, Vector3(left.x, 0, left.y), Vector3(step.x, 0, step.y), HouseSketch.CELL * 2.0, brick)


## One arch rib: a half ellipse across the tunnel `width` wide, from the springing up under the ground,
## 0.34 m of brick deep and 0.4 m thick along the tunnel.
static func _arch(parent: Node3D, at: Vector3, across: Vector3, along: Vector3, width: float, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rx := width * 0.5
	var ry := HouseSketch.DEPTH - RIB_SPRING - 0.12
	var thick := 0.4
	var depth := 0.34
	var n := 16
	for i in n:
		var a0 := PI * float(i) / n
		var a1 := PI * float(i + 1) / n
		var in0 := across * (cos(a0) * (rx - depth)) + Vector3(0, RIB_SPRING + sin(a0) * (ry - depth), 0)
		var in1 := across * (cos(a1) * (rx - depth)) + Vector3(0, RIB_SPRING + sin(a1) * (ry - depth), 0)
		var out0 := across * (cos(a0) * rx) + Vector3(0, RIB_SPRING + sin(a0) * ry, 0)
		var out1 := across * (cos(a1) * rx) + Vector3(0, RIB_SPRING + sin(a1) * ry, 0)
		var h := along * (thick * 0.5)
		var toward := (in0 + in1) * 0.5
		var soffit_n := Vector3(-toward.x, RIB_SPRING - toward.y, -toward.z).normalized()
		# The soffit (underside), the two faces and the top.
		_quad(st, in0 - h, in1 - h, in1 + h, in0 + h, soffit_n)
		_quad(st, in0 - h, out0 - h, out1 - h, in1 - h, -along)
		_quad(st, in1 + h, out1 + h, out0 + h, in0 + h, along)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	var flip := (b - a).cross(c - a).dot(normal) > 0.0
	var order := [a, c, b, a, d, c] if flip else [a, b, c, a, c, d]
	for v: Vector3 in order:
		st.set_normal(normal)
		st.add_vertex(v)


## Rubbish washed up along the walkway and stacked against the wall: sodden crates, sacks, a barrel,
## heaps of straw and bones, here and there, never in the way of the channel's walk (always on the
## wall side of the walkway).
static func _litter(parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("kanalunrat")
	var b := W.Builder.new()
	var n := 0
	for c: Vector2i in cells():
		if not "wr".contains(cells()[c]):
			continue
		n += 1
		if n % 5 != 2:
			continue
		var out := Vector2i.ZERO
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not cells().has(c + d):
				out = d
		if out == Vector2i.ZERO:
			continue
		var wall := Vector3(out.x, 0, out.y)
		var side := Vector3(-out.y, 0, out.x)
		var base := floor_at(c) + wall * (HouseSketch.CELL * 0.5 - 0.45) + side * rng.randf_range(-0.5, 0.5)
		match rng.randi() % 4:
			0:
				_crate(b, base, rng)
				_crate(b, base + side * 0.7 + wall * 0.05, rng)
			1:
				b.cylinder(base, 0.34, 0.3, 0.8, W.vary(Color(0.42, 0.3, 0.18), rng, 0.1), W.WOOD, 12)
				for y: float in [0.15, 0.6]:
					b.cylinder(base + Vector3(0, y, 0), 0.355, 0.355, 0.05, W.vary(Color(0.25, 0.25, 0.27), rng, 0.05), W.IRON, 12)
			2:
				for k in 5:
					var off := side * rng.randf_range(-0.5, 0.5) + wall * rng.randf_range(-0.2, 0.2)
					b.frustum(base + off, Vector2(0.4, 0.34), Vector2(0.14, 0.12), 0.3 + rng.randf() * 0.2, W.vary(Color(0.5, 0.42, 0.28), rng, 0.12), W.WOOD,
							Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)))
			_:
				for k in 9:
					var off := side * rng.randf_range(-0.55, 0.55) + wall * rng.randf_range(-0.3, 0.3)
					b.bar(base + off + Vector3(0, 0.04, 0), base + off + Vector3(rng.randf_range(-0.3, 0.3), 0.05, rng.randf_range(-0.3, 0.3)), 0.03 + rng.randf() * 0.02,
							Color(0.78, 0.74, 0.62).lerp(Color(0.5, 0.45, 0.35), rng.randf()), W.FRESH, 5)
	b.finish(parent)


static func _crate(b: W.Builder, at: Vector3, rng: RandomNumberGenerator) -> void:
	var turn := Basis.from_euler(Vector3(0, rng.randf_range(-0.5, 0.5), 0))
	var wood := W.vary(Color(0.4, 0.28, 0.17), rng, 0.1)
	b.box(at, Vector3(0.62, 0.5, 0.62), wood, W.WOOD, turn)
	for y: float in [0.06, 0.4]:
		b.box(at + Vector3(0, y, 0), Vector3(0.66, 0.06, 0.66), W.vary(Color(0.3, 0.2, 0.12), rng, 0.1), W.WOOD, turn)
	b.box(at + Vector3(0, 0.5, 0), Vector3(0.6, 0.04, 0.6), W.vary(Color(0.33, 0.24, 0.15), rng, 0.1), W.WOOD, turn)


## Iron pipes along the wall at the height of a man, with brackets, one of them rusted through.
static func _pipes(parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("kanalrohre")
	var b := W.Builder.new()
	var n := 0
	for c: Vector2i in cells():
		if cells()[c] != "w":
			continue
		n += 1
		if n % 9 != 4:
			continue
		var out := Vector2i.ZERO
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not cells().has(c + d):
				out = d
		if out == Vector2i.ZERO:
			continue
		var wall := Vector3(out.x, 0, out.y)
		var side := Vector3(-out.y, 0, out.x)
		var base := floor_at(c) + wall * (HouseSketch.CELL * 0.5 - 0.16) + Vector3(0, 1.3, 0)
		var iron := W.vary(Color(0.3, 0.27, 0.25), rng, 0.08)
		b.bar(base - side * 1.0, base + side * 1.0, 0.09, iron, W.IRON, 10)
		for k: float in [-0.9, 0.0, 0.9]:
			b.box(base + side * k - Vector3(0, 0.12, 0) - wall * 0.06, Vector3(0.12, 0.24, 0.1) if side.x == 0.0 else Vector3(0.1, 0.24, 0.12), Color(0.22, 0.2, 0.2), W.IRON)
		# A coupling in the middle.
		b.bar(base - side * 0.08, base + side * 0.08, 0.12, W.vary(Color(0.36, 0.2, 0.1), rng, 0.1), W.IRON, 10)
		# The rust-through: a green-black streak down the wall under it.
		b.box(base - Vector3(0, 1.2, 0) + wall * 0.07 + side * 0.4, Vector3(0.1, 1.2, 0.01) if side.x == 0.0 else Vector3(0.01, 1.2, 0.1), Color(0.1, 0.14, 0.08), W.FRESH)
	b.finish(parent)
