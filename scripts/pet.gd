class_name Pet
extends Node3D
## The hero's fox: a wild fox of the meadows that the hero has won over with
## sausages (see Animal, "curious"). From then on it trots along at the hero's
## heels everywhere, in the open air, in the village and down in the dungeon.
##
## Its nose is what makes it useful: every level hides a few ingredients in
## the ground (see Level.hidden_finds) that the hero cannot see. When one lies
## within the fox's nose range it runs over, sniffs, digs it up and leaves it
## lying there for the hero to pick up.
##
## The fox never fights, cannot be hurt and takes up no room, like the wild
## animals. If it falls too far behind it catches up at once.

## The food that wins a fox over, and how many it must eat to trust the hero.
const FOOD := "wurst"
const TRUST_NEEDED := 3
## Where the foxes live, for the hint on buying a sausage and the
## compendium. tests/fox.gd checks that the map still agrees: the fox
## meadow lies west of the village square, next to the woodland pond.
const WHERE := "Füchse leben auf der Wiese am Waldteich westlich vom Dorf, am Weg, der vom Friedhof herunterkommt. Trag eine Wurst bei dir, dann kommt ein Fuchs zu dir."
## Gap (metres) the fox keeps to the hero, and from how far it runs instead
## of walking.
const FOLLOW_GAP := 2.6
const RUN_FROM := 7.0
## Beyond this the fox catches up at once (it knows a short cut).
const CATCH_UP := 24.0
const WALK_SPEED := 2.2
const RUN_SPEED := 7.5
## How far its nose reaches (metres from the fox), how long it digs, and how
## long it rests its nose after a find (seconds).
const NOSE_RANGE := 14.0
const DIG_TIME := 2.0
const SNIFF_REST := 12.0
## A spot it cannot reach in this time is given up for now.
const GIVE_UP := 10.0
const SCALE := 0.4
const RUN_ANIM := 5.0

signal dug_up(id: String, pos: Vector3)

var level: Level
## "follow", "seek" (on the way to a find), "dig".
var state := "follow"
var _model: Node3D
var _anim: AnimationPlayer
var _path: Array[Vector3] = []
var _repath := 0.0
var _rest := SNIFF_REST * 0.5
var _timer := 0.0
var _target: Dictionary = {}
var _current_anim := ""
var _placed := false


func setup(owner_level: Level) -> void:
	level = owner_level


func _ready() -> void:
	_model = load("res://assets/animals/Fox.glb").instantiate()
	_model.scale = Vector3.ONE * SCALE
	add_child(_model)
	_anim = _model.find_child("AnimationPlayer", true, false)
	for a in ["Idle", "Walk", "Gallop", "Eating"]:
		_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	play("Idle")


func play(anim_name: String) -> void:
	if _current_anim == anim_name:
		return
	_current_anim = anim_name
	_anim.play(anim_name, 0.25)


func _hero() -> Node3D:
	return level.player if level else null


func _physics_process(delta: float) -> void:
	var hero := _hero()
	if hero == null:
		return
	var gap := _flat(hero.global_position - global_position).length()
	if not _placed or gap > CATCH_UP:
		_beside_hero(hero)
		_placed = true
		return
	_rest -= delta
	match state:
		"follow":
			if _rest <= 0.0 and _sniff():
				return
			if gap > FOLLOW_GAP:
				_repath -= delta
				if _repath <= 0.0 or _path.is_empty():
					_repath = 0.4
					_set_path(hero.global_position)
				_walk(delta, RUN_SPEED if gap > RUN_FROM else WALK_SPEED, hero)
			else:
				_path.clear()
				_anim.speed_scale = 1.0
				play("Idle")
				_turn_to(hero.global_position - global_position, delta)
		"seek":
			_timer -= delta
			if not level.hidden_finds.has(_target) or _timer <= 0.0:
				_back_to_hero()
				return
			_walk(delta, RUN_SPEED, null)
			if _path.is_empty():
				state = "dig"
				_timer = DIG_TIME
				_anim.speed_scale = 1.4
				play("Eating")
		"dig":
			_timer -= delta
			if _timer <= 0.0:
				_dig_up()


## Puts the fox down on open ground right next to the hero.
func _beside_hero(hero: Node3D) -> void:
	var here := level.world_to_cell(hero.global_position)
	var spot := hero.global_position - hero.global_transform.basis.z * 1.2
	for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1)]:
		if _open(here + d):
			spot = level.cell_to_world(here + d)
			break
	global_position = Vector3(spot.x, 0.0, spot.z)
	_path.clear()
	state = "follow"


## Looks for a hidden ingredient in nose range. True when it found one and
## is on its way.
func _sniff() -> bool:
	var best: Dictionary = {}
	var best_d := NOSE_RANGE
	for f in level.hidden_finds:
		var d := _flat(level.cell_to_world(f.cell) - global_position).length()
		if d < best_d:
			best_d = d
			best = f
	if best.is_empty():
		_rest = 1.0
		return false
	if not _set_path(level.cell_to_world(best.cell)):
		# Out of reach (behind a wall or a gate): ignore it for a while.
		_rest = SNIFF_REST
		return false
	_target = best
	state = "seek"
	_timer = GIVE_UP
	Effects.float_text(level, global_position + Vector3(0, 1.6, 0), "?", Color(1.0, 0.75, 0.35, 0.95))
	return true


func _dig_up() -> void:
	_anim.speed_scale = 1.0
	var pos := level.cell_to_world(_target.cell)
	if level.hidden_finds.has(_target):
		level.hidden_finds.erase(_target)
		var dirt := Effects.make_sparkles(Color(0.45, 0.32, 0.18), true)
		dirt.position = pos + Vector3(0, 0.3, 0)
		level.add_child(dirt)
		dug_up.emit(_target.id, pos)
	_back_to_hero()


func _back_to_hero() -> void:
	_target = {}
	_path.clear()
	_rest = SNIFF_REST
	state = "follow"


func is_digging() -> bool:
	return state == "dig"


func _walk(delta: float, speed: float, hero: Node3D) -> void:
	if _path.is_empty():
		return
	if hero:
		# Keeps up with a running hero.
		var hero_speed: float = Vector2(hero.velocity.x, hero.velocity.z).length() if hero is CharacterBody3D else 0.0
		speed = maxf(speed, hero_speed * 1.1)
	var to := _flat(_path[0] - global_position)
	var step := speed * delta
	if to.length() <= step:
		global_position = Vector3(_path[0].x, global_position.y, _path[0].z)
		_path.pop_front()
	else:
		global_position += to.normalized() * step
	_turn_to(to, delta)
	if speed > WALK_SPEED * 1.5:
		play("Gallop")
		_anim.speed_scale = clampf(speed / RUN_ANIM, 0.6, 2.0)
	else:
		play("Walk")
		_anim.speed_scale = 1.0


func _set_path(target: Vector3) -> bool:
	_path.clear()
	var from := level.world_to_cell(global_position)
	var to := level.world_to_cell(target)
	if from == to:
		_path.append(Vector3(target.x, global_position.y, target.z))
		return true
	var cells: Array[Vector2i] = level.grid_path(from, to)
	for c in cells.slice(1, cells.size() - 1):
		_path.append(level.cell_to_world(c))
	if not cells.is_empty():
		_path.append(Vector3(target.x, global_position.y, target.z))
	return not _path.is_empty()


func _open(c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= level.width or c.y >= level.height:
		return false
	return level.is_open(c) if level.has_method("is_open") else level._walkable(c) and not level.astar.is_point_solid(c)


func _turn_to(direction: Vector3, delta: float) -> void:
	direction.y = 0.0
	if direction.length() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), minf(1.0, delta * 7.0))


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
