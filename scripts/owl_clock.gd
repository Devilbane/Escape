class_name OwlClock
extends RefCounted
## The owl clock: a riddle that takes a long while and gives no hand to hold. Its parts are the
## Deathringer (a bell, crafted from a recipe, rung with key 3), the graveyard's gravestones (see
## GraveLore) and the owls (see Owls). What solves it is sealed (see RiddleSeal); no comment, test or
## text of the code says it. Ringing the bell where it should not be rung three times in a row wakes
## Death, stronger at a fuller moon, and rests the bell until the next night; the first CALLS_REWARDED
## times Death pays like any monster, then it gives no loot, no experience and no training, and the
## third time the hero hears that there is more to this bell, and nothing else.
##
## The state is the entry `ID` in the treasure maps' saved state (see TreasureMaps), OPEN once the way
## is open; how many times Death was called and when the bell rests until is saved with the game.

const ID := "eulengruft"
const NAME := "Owlavs Gruft"
## The sealed answers (see RiddleSeal), and the tile of the dead tree whose owl strikes the hours (the
## outdoor map "Apfeltal").
const _PATTERN := "clxXSVg="
const _GRAVE := "d1xf"
const OWL_TREE_CELL := Vector2i(9, 12)
## How high in the dead tree the owl sits (metres).
const OWL_HEIGHT := 3.4

## The seconds between hoots, between groups and before the pattern starts over (it is silent that long).
const HOOT_GAP := 1.3
const GROUP_GAP := 3.6
const ROUND_PAUSE := 11.0
## Seconds from the hero's coming near to the first hoot.
const START_DELAY := 3.0
## The night's hours in which the owl strikes (from the evening, past midnight, until before dawn).
const STRIKE_FROM := 22.0
const STRIKE_UNTIL := 4.0
const SOUND := "owl_clock"
const HOOT_DB := 0.0
const HEAR_RANGE := 45.0
const PUFF := 0.6

const BELL := "totenlaeuter"
const BELL_SOUND := "deathringer"
const BELL_DB := -2.0
## Rings closer together than RING_GAP seconds are too quick for the bell; a pause of SPLIT seconds or
## longer ends a group of rings (and a row of them); END_WAIT seconds without a ring end the attempt at
## the grave.
const RING_GAP := 0.7
const SPLIT := 2.2
const END_WAIT := 5.0
## Rings in a row that wake Death, how often it still pays, and how near to the grave the bell must ring (metres).
const ROW := 3
const CALLS_REWARDED := 3
const GRAVE_RANGE := 4.5
## Death's strength at the full moon (and what each point of the moon's light adds): life, hits and
## the dead who come with it.
const DEATH_LIFE := Vector2i(6, 20)
const ESCORT := 3
const DEATH_KIND := "tod"
const ESCORT_KIND := "wicht"

## What Owlav's crypt holds in its chest.
const REWARD := "eulenamulett"
const REWARD_GOLD := 60

const MORE_TO_IT := "Es muss noch mehr an dieser Glocke sein."
const RESTING := "Die Glocke hallt nur noch dumpf. Sie ruht bis zur nächsten Nacht."
const NOTHING := "Der Klang verhallt in der Nacht. Nichts geschieht."
const OPENED := "Die Steinplatte vor dem Grab schiebt sich zur Seite. Darunter führen Stufen in die Tiefe!"
const DEATH_RISES := "Der Tod steigt aus der Erde!"

var game: Node
## How many times Death was called, and the day until which the bell rests (saved).
var calls := 0
var rest_until := 0
var _last_ring := -INF
var _row := 0
var _groups: Array[int] = []
var _attempt := 0


func _init(owner_game: Node = null) -> void:
	game = owner_game


func clear() -> void:
	calls = 0
	rest_until = 0
	_last_ring = -INF
	_row = 0
	_groups.clear()


# --- The clock --------------------------------------------------------------------------------

## The hoots of the clock, group by group.
static func pattern() -> Array[int]:
	return RiddleSeal.numbers(_PATTERN)


## The tile of the grave the bell is rung at.
static func grave_cell() -> Vector2i:
	var n := RiddleSeal.numbers(_GRAVE)
	return Vector2i(n[0], n[1])


## The number of hoots in one round of the pattern.
static func hoots() -> int:
	var n := 0
	for g: int in pattern():
		n += g
	return n


## Seconds from hoot number `i` (counted over the round) to the next one.
static func gap_after(i: int) -> float:
	var at := 0
	for g: int in pattern():
		at += g
		if i + 1 == at:
			return ROUND_PAUSE if at == hoots() else GROUP_GAP
		if i + 1 < at:
			return HOOT_GAP
	return ROUND_PAUSE


## Whether the hour is one of the clock's (22:00 until 04:00).
static func striking(hour: float) -> bool:
	hour = fposmod(hour, 24.0)
	return hour >= STRIKE_FROM or hour < STRIKE_UNTIL


# --- The grave and the crypt ------------------------------------------------------------------

static func is_open(lvl: Level) -> bool:
	return lvl.treasure.get(ID, "") == TreasureMaps.OPEN


## What the stone number `index` among the graveyard's graves (in map order) says.
static func inscription(index: int, c: Vector2i, town := "") -> Dictionary:
	if c == RiddleCount.grave_of(town):
		return {"name": RiddleCount.NAME, "text": "", "counter": true}
	return GraveLore.OWLAV if c == grave_cell() else GraveLore.other(index)


## Puts a gravestone's reading station on the map (see Outdoor._build_outdoor_cell). Owlav's grave also
## shows its crypt when that is open.
static func place_grave(lvl: Outdoor, c: Vector2i, pos: Vector3, index: int) -> void:
	var entry := inscription(index, c, lvl.level_name)
	lvl.stations.append({"kind": GraveLore.KIND, "cell": c, "pos": pos + Vector3(0, 0, -0.6), "touch": 1.8,
			"used": false, "name": entry.name, "text": entry.text, "owlav": c == grave_cell(),
			"counter": entry.get("counter", false)})
	if c == grave_cell():
		lvl.owlav_pos = pos
		if is_open(lvl):
			build_stairs(lvl, pos, false)


## The open way down in front of the grave: a stone frame round a black stairwell with the old slab
## laid aside, and the way in. `slide`: the slab moves aside now, from where it lay over the stairs.
static func build_stairs(lvl: Outdoor, grave: Vector3, slide: bool) -> void:
	_clear(lvl)
	var at := grave + STAIRS_AT
	var holder := Node3D.new()
	holder.name = "Eulengruft"
	lvl.add_child(holder)
	lvl.owlav_parts = holder
	var stone := _stone()
	var rim := Vector2(SIZE.x * 0.5, SIZE.y * 0.5)
	for side: Vector4 in [Vector4(0, -1, SIZE.x + 0.5, 0.25), Vector4(0, 1, SIZE.x + 0.5, 0.25),
			Vector4(-1, 0, 0.25, SIZE.y), Vector4(1, 0, 0.25, SIZE.y)]:
		var edge := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(side.z, 0.22, side.w)
		edge.mesh = box
		edge.material_override = stone
		edge.position = at + Vector3(side.x * (rim.x + 0.12), 0.08, side.y * (rim.y + 0.12))
		holder.add_child(edge)
	var pit := MeshInstance3D.new()
	var well := BoxMesh.new()
	well.size = Vector3(SIZE.x, 0.02, SIZE.y)
	pit.mesh = well
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color(0.01, 0.01, 0.015)
	pit.material_override = black
	pit.position = at + Vector3(0, 0.04, 0)
	holder.add_child(pit)
	# Three steps seen going down into the dark.
	for i in 3:
		var step := MeshInstance3D.new()
		var tread := BoxMesh.new()
		tread.size = Vector3(SIZE.x - 0.1, 0.05, SIZE.y / 3.0 - 0.06)
		step.mesh = tread
		step.material_override = stone
		step.position = at + Vector3(0, 0.05 - 0.05 * i, SIZE.y * 0.5 - 0.2 - i * SIZE.y / 3.0)
		step.scale = Vector3.ONE * (1.0 - 0.1 * i)
		holder.add_child(step)
	var mist := Effects.make_sparkles(Color(0.5, 0.6, 0.75, 0.5))
	mist.position = at + Vector3(0, 0.4, 0)
	holder.add_child(mist)
	# A cold glow from the stairwell, so the steps can be made out.
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.55, 0.7, 1.0)
	glow.light_energy = 1.4
	glow.omni_range = 4.5
	glow.position = at + Vector3(0, 0.7, 0)
	holder.add_child(glow)
	var slab := MeshInstance3D.new()
	slab.name = "Platte"
	var slab_box := BoxMesh.new()
	slab_box.size = Vector3(SIZE.x + 0.6, 0.18, SIZE.y + 0.5)
	slab.mesh = slab_box
	slab.material_override = stone
	holder.add_child(slab)
	var aside := at + SLAB_ASIDE
	slab.position = at + Vector3(0, 0.1, 0) if slide else aside
	if slide:
		var tween := slab.create_tween()
		tween.tween_property(slab, "position", aside, SLIDE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	lvl._add_solid(at, Vector3(SIZE.x, 1.0, SIZE.y))
	lvl.doors[ID] = grave + EXIT_AT
	_station(lvl, at)


static func _station(lvl: Outdoor, at: Vector3) -> void:
	for s in lvl.stations.duplicate():
		if s.get("building", "") == ID:
			lvl.stations.erase(s)
	if lvl.interiors.has(ID):
		lvl.stations.append({"kind": "eingang", "building": ID, "name": NAME, "cell": lvl.world_to_cell(at),
				"pos": at, "touch": 1.7, "used": false})


static func _clear(lvl: Outdoor) -> void:
	if is_instance_valid(lvl.owlav_parts):
		lvl.owlav_parts.queue_free()
	lvl.owlav_parts = null


## Size of the stairwell, and where it lies from the grave's tile middle, where the slab goes, and where
## the hero stands on coming out.
const SIZE := Vector2(1.5, 1.2)
const STAIRS_AT := Vector3(0, 0, 1.75)
const SLAB_ASIDE := Vector3(2.4, 0.0, 0.3)
const EXIT_AT := Vector3(0, 0, Level.TILE * 0.8)
const SLIDE_TIME := 2.2
static var _stone_material: StandardMaterial3D


static func _stone() -> StandardMaterial3D:
	if _stone_material != null:
		return _stone_material
	var noise := FastNoiseLite.new()
	noise.seed = 31
	noise.frequency = 0.045
	var fine := FastNoiseLite.new()
	fine.seed = 7
	fine.frequency = 0.3
	var img := Image.create(128, 128, true, Image.FORMAT_RGB8)
	for y in 128:
		for x in 128:
			var v := 0.5 + noise.get_noise_2d(x, y) * 0.35 + fine.get_noise_2d(x, y) * 0.12
			var seam := 1.0 if (x % 64 < 2 or y % 32 < 2) else 0.0
			img.set_pixel(x, y, Color(0.58, 0.58, 0.56) * (v * (1.0 - 0.35 * seam)))
	img.generate_mipmaps()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.roughness = 0.95
	mat.uv1_scale = Vector3(2, 2, 2)
	mat.uv1_triplanar = true
	_stone_material = mat
	return mat


# --- The bell ---------------------------------------------------------------------------------

## The hero rings the Deathringer (key 3). `now` in seconds (a test passes its own).
func ring(now := Time.get_ticks_msec() / 1000.0) -> void:
	if game == null or not game.player.bag.has(BELL):
		return
	var gap := now - _last_ring
	if gap < RING_GAP:
		return
	_last_ring = now
	game.player.play_once("Interact", 0.5)
	Sfx.play(game, BELL_SOUND, BELL_DB)
	var continues := gap < SPLIT
	_row = _row + 1 if continues else 1
	if continues and not _groups.is_empty():
		_groups[-1] += 1
	else:
		_groups.append(1)
	var lvl: Level = game.level
	if at_grave(lvl):
		_attempt += 1
		var mine := _attempt
		game.get_tree().create_timer(END_WAIT).timeout.connect(func(): _end_attempt(mine))
		return
	_groups.clear()
	if _row >= ROW:
		_row = 0
		_wake_death(lvl)


## Whether the hero stands at Owlav's grave in the open air.
func at_grave(lvl: Level) -> bool:
	if not lvl is Outdoor or (lvl as Outdoor).owlav_pos == Vector3.INF:
		return false
	var p: Vector3 = (lvl as Outdoor).owlav_pos
	return Vector2(game.player.global_position.x - p.x, game.player.global_position.z - p.z).length() <= GRAVE_RANGE


func _end_attempt(mine: int) -> void:
	if mine != _attempt or game == null or not game.level is Outdoor:
		return
	var rung := _groups.duplicate()
	_groups.clear()
	_row = 0
	if rung == Array(pattern()) and not is_open(game.level):
		open_crypt()
	elif not is_open(game.level):
		Events.tell(Lang.t(NOTHING), Color(0.8, 0.82, 0.9))


## The pattern was right: the slab slides aside, and the way down stays open for good.
func open_crypt() -> void:
	var lvl: Outdoor = game.level
	game.treasure_maps.state[ID] = TreasureMaps.OPEN
	Events.bus().riddle_done.emit(RiddleCount.OWL_CLOCK)
	Sfx.play(game, "rumble")
	Events.tell(Lang.t(OPENED), game.GOLD)
	build_stairs(lvl, lvl.owlav_pos, true)
	game.journal.write("Owlavs Gruft geöffnet", [], game.journal.current_file())


## The strength of the dead at tonight's moon, 0 (new moon) to 1 (full).
func moon_strength() -> float:
	return clampf((Moon.light(game.day) - Moon.DARKEST) / (Moon.BRIGHTEST - Moon.DARKEST), 0.0, 1.0)


## Three rings in a row far from the grave: Death rises beside the hero, with escorts at a fuller moon.
func _wake_death(lvl: Level) -> void:
	if lvl.is_home or (lvl is Outdoor and (lvl as Outdoor).hero_indoors):
		Events.tell(Lang.t(NOTHING), Color(0.8, 0.82, 0.9))
		return
	if game.day < rest_until:
		Events.tell(Lang.t(RESTING), Color(0.8, 0.82, 0.9))
		return
	calls += 1
	rest_until = game.day + 1
	var strength := moon_strength()
	var life := DEATH_LIFE.x + int(round((DEATH_LIFE.y - DEATH_LIFE.x) * strength))
	var damage := 1 + int(strength > 0.35) + int(strength > 0.85)
	var paid := calls <= CALLS_REWARDED
	var spots := _spots(lvl, 1 + int(round(ESCORT * strength)))
	for i in spots.size():
		if i == 0:
			_summon(lvl, DEATH_KIND, spots[i], {"hp": life, "damage": damage}, paid)
		else:
			_summon(lvl, ESCORT_KIND, spots[i], {}, paid)
	Events.tell(Lang.t(DEATH_RISES), Color(0.75, 0.75, 0.95))
	if calls == CALLS_REWARDED:
		game.get_tree().create_timer(3.0).timeout.connect(func():
			Events.tell(Lang.t(MORE_TO_IT), Color(0.75, 0.75, 0.95), 4.0))


## Open spots round the hero, 3 to 6 metres away.
func _spots(lvl: Level, count: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var hero := lvl.world_to_cell(game.player.global_position)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var tries := 0
	while out.size() < count and tries < 80:
		tries += 1
		var c := hero + Vector2i(rng.randi_range(-2, 2), rng.randi_range(-2, 2))
		if c == hero or not lvl.astar.is_in_boundsv(c) or lvl.astar.is_point_solid(c):
			continue
		var w := lvl.cell_to_world(c)
		if w.distance_to(game.player.global_position) < 2.5:
			continue
		out.append(w)
	return out


func _summon(lvl: Level, kind: String, at: Vector3, custom: Dictionary, paid: bool) -> Enemy:
	var e := Enemy.new()
	e.kind = kind
	e.custom = custom
	e.night = true
	e.level = lvl
	e.no_reward = not paid
	lvl.add_child(e)
	e.global_position = at
	var dust := Effects.make_sparkles(Color(0.2, 0.2, 0.3), true)
	dust.position = at + Vector3(0, 0.6, 0)
	lvl.add_child(dust)
	e.died.connect(func():
		if e.no_reward:
			return
		lvl.enemy_killed.emit(e)
		lvl.drop_kill_loot(e, randi_range(6, 10) if kind == DEATH_KIND else 0))
	lvl.enemies = lvl.enemies.filter(func(x): return is_instance_valid(x))
	lvl.enemies.append(e)
	return e


# --- Saved game -------------------------------------------------------------------------------

func for_save() -> Dictionary:
	return {"calls": calls, "rest_until": rest_until}


func load_from(data) -> void:
	clear()
	if data is Dictionary:
		calls = maxi(0, int(data.get("calls", 0)))
		rest_until = maxi(0, int(data.get("rest_until", 0)))
