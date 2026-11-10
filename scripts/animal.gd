class_name Animal
extends Node3D
## A peaceful animal of the woods between the graveyard and the village:
## does, stags and foxes graze and stroll around the meadow they live on,
## and bolt when the hero comes close. They never fight and cannot be hurt,
## and they take up no room, so they never stand in anyone's way.
##
## A sneaking hero gets much closer before they notice. Once the hero is far
## enough away again they calm down and go back to grazing.
##
## A fox, a doe or a stag can be won over: while the hero carries its
## favourite food (a sausage, an apple, a salt lick; see Companions) it does
## not bolt but comes up, curious, and eats from the hero's hand. After
## Companions.TRUST_NEEDED gifts it becomes the hero's companion (see Pet).
## The hero has at most one of each kind.
##
## Models: "Ultimate Animated Animals" by Quaternius (CC0, see
## assets/animals/LICENSE.txt).

## model: file in assets/animals; scale fits it to the hero's size; walk and
## run: speeds (m/s; the legs keep pace with them, see Stride);
## shy: how close the hero may come before it bolts (metres); roam: how far
## from home it strolls (tiles).
const KINDS := {
	"reh": {"model": "Deer", "scale": 0.45, "walk": 1.3, "run": 7.5, "shy": 11.0, "roam": 4},
	"hirsch": {"model": "Stag", "scale": 0.45, "walk": 1.2, "run": 7.0, "shy": 9.0, "roam": 4},
	"fuchs": {"model": "Fox", "scale": 0.4, "walk": 1.5, "run": 6.5, "shy": 8.0, "roam": 5},
}
## Which map letter places which animal (see Outdoor).
const LETTERS := {"D": "reh", "V": "hirsch", "&": "fuchs"}
## A sneaking hero is noticed only this much closer.
const SNEAK_FACTOR := 0.45
## How far a frightened animal runs from home at most (tiles), and how far
## the hero must be before it settles down again (times its shy distance).
const FLEE_ROAM := 7
const CALM_FACTOR := 1.5
## From how far an animal smells its food on the hero and comes over, and
## how long it chews (how close it comes: Companions.SPECIES "reach").
const CURIOUS_RANGE := 14.0
const EAT_TIME := 2.5

var level: Level
var kind := "reh"
var home := Vector2i.ZERO
## "graze", "idle", "stroll" or "flee"; also "approach" (coming for the
## food the hero carries) and "eat".
var state := "idle"
var _stats: Dictionary
var _model: Node3D
var _anim: AnimationPlayer
var _rng := RandomNumberGenerator.new()
var _path: Array[Vector3] = []
var _speed := 0.0
var _timer := 0.0
var _current_anim := ""
var _repath := 0.0
var _waiting := 0.0


func setup(owner_level: Level, animal_kind: String, cell: Vector2i) -> void:
	level = owner_level
	kind = animal_kind
	home = cell
	_stats = KINDS[kind]
	_rng.seed = hash(kind) + cell.x * 131 + cell.y * 7


func _ready() -> void:
	SmoothMotion.follow_ticks(self)
	_model = load("res://assets/animals/%s.glb" % _stats.model).instantiate()
	_model.scale = Vector3.ONE * float(_stats.scale)
	add_child(_model)
	CreatureSkin.dress(_model, "", String(_stats.model))
	_anim = _model.find_child("AnimationPlayer", true, false)
	for a in ["Idle", "Walk", "Gallop", "Eating"]:
		_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	rotation.y = _rng.randf() * TAU
	_begin(["graze", "idle"][_rng.randi() % 2], _rng.randf_range(1.0, 6.0))


## How close the hero may come right now before this animal bolts.
func shy_distance() -> float:
	var d: float = _stats.shy
	if level and level.player and level.player.get("sneaking"):
		d *= SNEAK_FACTOR
	return d


func is_fleeing() -> bool:
	return state == "flee"


## The key in the level's taken list that marks this animal as the hero's.
func tame_key() -> String:
	return "%s_zahm:%d,%d" % [kind, home.x, home.y]


## The food that wins this animal over, or "" if it cannot be won over.
func food() -> String:
	return Companions.SPECIES[kind].food if Companions.is_species(kind) else ""


## Whether this animal would come for food the hero carries right now: one
## that can be won over, of a kind the hero has no companion of yet.
func is_curious() -> bool:
	var owned = level.get("owned_companions")
	if food() == "" or not owned is Array or owned.has(kind) or level.player.get("dead"):
		return false
	var bag = level.player.get("bag")
	return bag is Array and bag.has(food())


## Plays one of the model's animations (Idle, Walk, Gallop, Eating).
func play(anim_name: String) -> void:
	if _current_anim == anim_name:
		return
	_current_anim = anim_name
	_anim.play(anim_name, 0.25)


func _begin(new_state: String, time: float) -> void:
	state = new_state
	_timer = time
	_anim.speed_scale = 1.0
	match state:
		"graze":
			play("Eating")
		"idle":
			play("Idle")


func _physics_process(delta: float) -> void:
	if level == null or level.player == null:
		return
	var hero: Node3D = level.player
	var away := global_position - hero.global_position
	away.y = 0.0
	if state == "eat":
		_timer -= delta
		if _timer <= 0.0:
			_begin("idle", 1.5)
		return
	var curious := is_curious()
	if curious and away.length() < CURIOUS_RANGE:
		_come_for_food(hero, delta)
		return
	if state == "approach":
		_begin("idle", 1.0)
	var hero_near: bool = away.length() < shy_distance() and not hero.get("dead") and not curious
	if hero_near and state != "flee":
		_flee_from(hero.global_position)
	match state:
		"graze", "idle":
			if not hero_near and away.length() < shy_distance() * CALM_FACTOR:
				# Wary: stops eating and keeps an eye on the hero.
				_turn_to(-away, delta)
				play("Idle")
			_timer -= delta
			if _timer <= 0.0:
				_next()
		"stroll", "flee":
			_walk(delta)
			if _path.is_empty():
				if state == "flee" and away.length() < shy_distance() * CALM_FACTOR:
					# Still too close for comfort: on it runs.
					_flee_from(hero.global_position)
				else:
					_begin("idle", _rng.randf_range(1.0, 3.0))


## An animal comes up to a hero who carries its food and eats it from their
## hand (the game takes it from the bag, see Outdoor.animal_fed).
func _come_for_food(hero: Node3D, delta: float) -> void:
	var to := _flat(hero.global_position - global_position)
	var reach: float = Companions.SPECIES[kind].reach
	if to.length() <= reach:
		_path.clear()
		_turn_to(to, 1.0)
		state = "eat"
		_timer = EAT_TIME
		_anim.speed_scale = 1.0
		play("Eating")
		level.emit_signal("animal_fed", self)
		return
	if state != "approach":
		state = "approach"
		_speed = _stats.walk * 1.4
		_repath = 0.0
	_repath -= delta
	if _repath <= 0.0:
		_repath = 0.5
		_path.clear()
		var cells: Array[Vector2i] = level.grid_path(level.world_to_cell(global_position), level.world_to_cell(hero.global_position))
		for c in cells.slice(1, cells.size() - 1):
			_path.append(level.cell_to_world(c))
	if _path.is_empty():
		# Same tile or the next one: straight to the hero, unless a wall is in the way.
		var next := global_position + to.normalized() * minf(_stride("Walk", _speed) * delta, to.length() - reach * 0.9)
		if WalkRules.can_step(level, global_position, next, true):
			global_position = next
		else:
			play("Idle")
		_turn_to(to, delta)
	else:
		_walk(delta)


## Calm again: graze a while, look around, or stroll to another spot.
func _next() -> void:
	var roll := _rng.randf()
	if roll < 0.4:
		_begin("graze", _rng.randf_range(4.0, 9.0))
	elif roll < 0.6:
		_begin("idle", _rng.randf_range(2.0, 4.0))
	else:
		var target := _nearby(int(_stats.roam))
		if not _set_path(target):
			_begin("idle", 2.0)
			return
		state = "stroll"
		_speed = _stats.walk


## Bolts from something that attacked it (a slime, see SlimeGrowth.bite).
func bolt_from(danger: Vector3) -> void:
	_flee_from(danger)


## Bolts to the spot near home that lies farthest from the hero.
func _flee_from(danger: Vector3) -> void:
	var best := Vector2i(-1, -1)
	var best_score := -INF
	var here := level.world_to_cell(global_position)
	for i in 24:
		var c := home + Vector2i(_rng.randi_range(-FLEE_ROAM, FLEE_ROAM), _rng.randi_range(-FLEE_ROAM, FLEE_ROAM))
		if not _open(c) or c == here:
			continue
		var p := level.cell_to_world(c)
		# Away from the hero, and not past them on the way.
		var score := _flat(p - danger).length() - 0.5 * _flat(p - global_position).length()
		if _flat(p - danger).dot(_flat(global_position - danger)) < 0.0:
			score -= 100.0
		if score > best_score:
			best_score = score
			best = c
	if best == Vector2i(-1, -1) or not _set_path(level.cell_to_world(best)):
		_begin("idle", 1.0)
		return
	if state != "flee":
		Effects.float_text(level, global_position + Vector3(0, 2.2, 0), "!", Color(1.0, 0.95, 0.7, 0.9))
	state = "flee"
	_speed = _stats.run


func _walk(delta: float) -> void:
	if _path.is_empty():
		return
	var to := _flat(_path[0] - global_position)
	var step := _stride("Gallop" if state == "flee" else "Walk", _speed) * delta
	var target := Vector3(_path[0].x, global_position.y, _path[0].z) if to.length() <= step else global_position + to.normalized() * step
	if not WalkRules.can_step(level, global_position, target):
		# A gate was shut (or a wall stands) ahead: stand, then find the way again.
		play("Idle")
		_anim.speed_scale = 1.0
		_waiting += delta
		if _waiting >= WalkRules.MAKE_WAY:
			_waiting = 0.0
			var goal: Vector3 = _path[_path.size() - 1]
			if not _set_path(goal):
				_begin("idle", 1.0)
		return
	_waiting = 0.0
	global_position = target
	if to.length() <= step:
		_path.pop_front()
	_turn_to(to, delta)


## Moves in `anim` at up to `speed`: a walk no faster than its legs step,
## every gait played just as fast as its planted hooves must travel (see
## Stride). Returns the speed really moved.
func _stride(anim: String, speed: float) -> float:
	var rig := Stride.rig_of(str(_stats.model))
	var size := _model.scale.x
	var moved := minf(speed, Stride.top_speed(rig, anim, size)) if anim == "Walk" else speed
	play(anim)
	_anim.speed_scale = Stride.playback(rig, anim, size, moved)
	return moved


func _set_path(target: Vector3) -> bool:
	_path.assign(WalkRules.path(level, global_position, target, _rng))
	return not _path.is_empty()


## A free tile within a few tiles of home.
func _nearby(radius: int) -> Vector3:
	for i in 20:
		var c := home + Vector2i(_rng.randi_range(-radius, radius), _rng.randi_range(-radius, radius))
		if _open(c):
			return level.cell_to_world(c)
	return level.cell_to_world(home)


func _open(c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= level.width or c.y >= level.height:
		return false
	return level.is_open(c) if level.has_method("is_open") else not level.astar.is_point_solid(c)


func _turn_to(direction: Vector3, delta: float) -> void:
	WalkRules.turn(self, direction, delta)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
