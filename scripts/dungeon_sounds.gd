class_name DungeonSounds
extends Node
## The dungeon is never quite silent: now and then, somewhere in the dark
## around the hero, water drips, wood creaks, a chain rattles, cockroaches
## scurry over the stones, wind howls through a crack, a voice whispers or
## something moans. Each sound comes from a spot of its own in the world (to
## the left, to the right, near or far), plays quietly through the Effects
## bus (so the effects volume slider and M turn it down or off), and never
## in a safe room or under the open sky. Nothing plays while a monster is on
## the hero's heels: the fight is loud enough.
## The sounds are made by tools/make_dungeon_sounds.py.

## Each kind of sound: how many takes it has, how often it comes up compared
## to the others, how loud it is right next to the hero, and how far away
## it sounds from (in tiles).
const KINDS := {
	"drip": {"count": 3, "weight": 3.0, "db": -12.0, "near": 2.0, "far": 6.0},
	"creak": {"count": 2, "weight": 2.0, "db": -14.0, "near": 3.0, "far": 7.0},
	"skitter": {"count": 2, "weight": 2.0, "db": -12.0, "near": 1.5, "far": 3.5},
	"chains": {"count": 2, "weight": 1.5, "db": -14.0, "near": 4.0, "far": 8.0},
	"wind": {"count": 2, "weight": 1.5, "db": -16.0, "near": 6.0, "far": 10.0},
	"whisper": {"count": 3, "weight": 1.0, "db": -15.0, "near": 2.0, "far": 4.0},
	"moan": {"count": 2, "weight": 1.0, "db": -16.0, "near": 6.0, "far": 10.0},
}
## Seconds between two sounds.
const GAP_MIN := 9.0
const GAP_MAX := 22.0
## The first sound after entering a floor comes a little sooner.
const FIRST_GAP := 6.0
## How much quieter a sound is per metre away from the hero.
const DB_PER_METRE := 0.3
## Each sound plays at a slightly different pitch every time.
const PITCH_SPREAD := 0.07
## Cockroaches run this far (metres) while they are heard.
const SKITTER_RUN := 6.0

var game: Node
var _timer := FIRST_GAP
var _last_kind := ""
var _level: Node = null


func _init(owner_game: Node) -> void:
	game = owner_game


func _process(delta: float) -> void:
	if game.level != _level:
		_level = game.level
		_timer = FIRST_GAP
	if not can_play():
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = randf_range(GAP_MIN, GAP_MAX)
	play(pick_kind())


## Whether the dark is quiet enough for a sound now: in the dungeon (or a
## cave or lair below ground), while playing, and with no monster hunting.
func can_play() -> bool:
	var level = game.level
	if game.state != game.State.PLAYING or level == null or game.player == null:
		return false
	if level.safe or level.outdoor:
		return false
	return not level.enemies.any(func(e): return is_instance_valid(e) and e.is_hunting())


## A kind of sound, by weight, never the same one twice in a row.
func pick_kind() -> String:
	var total := 0.0
	for kind in KINDS:
		if kind != _last_kind:
			total += KINDS[kind].weight
	var roll := randf() * total
	for kind in KINDS:
		if kind == _last_kind:
			continue
		roll -= KINDS[kind].weight
		if roll <= 0.0:
			return kind
	return KINDS.keys()[0]


## A spot somewhere around the hero for a sound of this kind, a few tiles
## away in any direction. Cockroaches run over open floor; the rest may
## also come from behind a wall.
func pick_spot(kind: String) -> Vector3:
	var info: Dictionary = KINDS[kind]
	var level = game.level
	var hero: Vector3 = game.player.global_position
	var spot := hero
	for attempt in 8:
		var angle := randf() * TAU
		var tiles := randf_range(info.near, info.far)
		spot = hero + Vector3(cos(angle), 0.0, sin(angle)) * tiles * Level.TILE
		var cell: Vector2i = level.world_to_cell(spot)
		cell.x = clampi(cell.x, 0, maxi(0, level.width - 1))
		cell.y = clampi(cell.y, 0, maxi(0, level.height - 1))
		spot = level.cell_to_world(cell)
		if kind != "skitter" or not Level.SOLID.contains(level.cell_char(cell)):
			break
	spot.y = 0.5
	return spot


## How loud a sound of this kind is from this spot.
func volume_at(kind: String, spot: Vector3) -> float:
	var dist := spot.distance_to(game.player.global_position)
	return KINDS[kind].db - dist * DB_PER_METRE


## Plays one sound of this kind somewhere around the hero.
func play(kind: String) -> AudioStreamPlayer3D:
	_last_kind = kind
	var spot := pick_spot(kind)
	var take := "dungeon_%s_%d" % [kind, randi() % int(KINDS[kind].count)]
	var p := Sfx.play_3d(game.level, take, volume_at(kind, spot), spot,
			1.0 + randf_range(-PITCH_SPREAD, PITCH_SPREAD))
	if p and kind == "skitter":
		# The swarm scurries past instead of sitting in one spot.
		var angle := randf() * TAU
		var to := spot + Vector3(cos(angle), 0.0, sin(angle)) * SKITTER_RUN
		p.create_tween().tween_property(p, "global_position", to, p.stream.get_length())
	return p
