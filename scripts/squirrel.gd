class_name Squirrel
extends Node3D
## A red squirrel of the woods (see WoodsLife). It lives at the foot of one
## tree at the forest's edge: it bounds about on the ground nearby, now and
## then sitting up to nibble, and when the hero comes too close it dashes to
## its tree and runs up the trunk, in among the leaves. Up there it waits,
## out of sight, until the hero has gone, then comes down again. At night
## it sleeps in its tree and comes down at dawn.
##
## It never fights, cannot be hurt and takes up no room, like the other
## animals of the woods (see Animal). A sneaking hero gets closer before it
## bolts.
##
## The model is built in code (see mesh and tail_mesh), two meshes: the body
## and the bushy tail, which swings and flicks. Every gait is a pose laid over
## them: bounding hops, sitting up, clinging to the trunk.

## How close (metres) the hero may come before it bolts; a sneaking hero is
## noticed only this much closer.
const SHY := 7.0
const SNEAK_FACTOR := 0.45
## Ground speeds (m/s): bounding about, and running for the tree. Up and down
## the trunk.
const WALK := 2.6
const RUN := 8.0
const CLIMB := 4.5
## How far from its tree it ranges (tiles).
const ROAM := 3
## The squirrel's size, against the real thing (the world is big and the
## trees tall, like the birds, see VillageBirds.SIZE).
const SIZE := 2.0
## The trunk's radius (metres), and how far up (fraction of the tree's
## height) it climbs: to where the leaves start, and in among them, out of
## sight, until the hero has gone.
const TRUNK := 0.5
const CLIMB_TO := Vector2(0.15, 0.18)
## How far the hero must be before it comes down again (times SHY).
const CALM_FACTOR := 1.6
## Length of one bound (metres) and its height, walking and running.
const HOP := Vector2(0.9, 1.7)
const HOP_HEIGHT := Vector2(0.12, 0.15)

## "sit", "hop", "flee", "climb", "perch" (up in the leaves, hidden),
## "descend" or "den" (asleep in the tree, hidden).
var state := "sit"
## The tree it lives in: pos (the trunk's foot), height, cell (the open tile
## beside it).
var tree: Dictionary
var level: Level
var _rng := RandomNumberGenerator.new()
var _body: Node3D
var _tail: MeshInstance3D
## Its two hands and two hind feet (left, right), which bound and climb (see _limbs).
var _hands: Array[MeshInstance3D] = []
var _feet: Array[MeshInstance3D] = []
var _path: Array[Vector3] = []
var _waiting := 0.0
var _timer := 0.0
var _phase := 0.0
var _clock := 0.0
## Where on the trunk it clings: angle round it, height, and how far up it
## goes this time.
var _angle := 0.0
var _height := 0.0
var _stop := 0.0
var _sit_up := 0.0
var _flick := 0.0


func setup(owner_level: Level, home_tree: Dictionary) -> void:
	level = owner_level
	tree = home_tree
	_rng.seed = hash(Vector2(tree.pos.x, tree.pos.z))


func _ready() -> void:
	SmoothMotion.follow_ticks(self)
	_build()
	global_position = tree.pos
	_scatter()
	rotation.y = _rng.randf() * TAU
	_begin("sit", _rng.randf_range(0.5, 4.0))


## The model: the body and tail, and the hands and hind feet that move on their own.
func _build() -> void:
	_body = Node3D.new()
	_body.scale = Vector3.ONE * SIZE
	add_child(_body)
	var fur := StandardMaterial3D.new()
	fur.vertex_color_use_as_albedo = true
	fur.roughness = 0.95
	fur.cull_mode = BaseMaterial3D.CULL_DISABLED
	var body := MeshInstance3D.new()
	body.mesh = mesh()
	body.material_override = fur
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(body)
	# The tail swings from its root, at the back.
	_tail = MeshInstance3D.new()
	_tail.mesh = tail_mesh()
	_tail.material_override = fur
	_tail.position = Vector3(0, 0.13, -0.14)
	_tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(_tail)
	for side: float in [-1.0, 1.0]:
		_hands.append(_limb(hand_mesh(), fur, Vector3(side * 0.04, 0.035, 0.1)))
		_feet.append(_limb(foot_mesh(), fur, Vector3(side * 0.055, 0.035, -0.07)))


func _limb(shape: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var limb := MeshInstance3D.new()
	limb.mesh = shape
	limb.material_override = material
	limb.position = at
	limb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(limb)
	return limb


## Where the squirrel stands on the ground (it starts somewhere about its tree).
func _scatter() -> void:
	var spot := _nearby(ROAM)
	global_position = Vector3(spot.x, 0.0, spot.z)


func _begin(new_state: String, time: float) -> void:
	state = new_state
	_timer = time
	_flick = _rng.randf_range(0.5, 2.0)


## Whether it sits up on its hind legs right now (the pose, 0 to 1).
func sitting_up() -> float:
	return _sit_up


func is_up_a_tree() -> bool:
	return state in ["climb", "perch", "descend", "den"]


func shy_distance() -> float:
	var d := SHY
	if level and level.player and level.player.get("sneaking"):
		d *= SNEAK_FACTOR
	return d


func _physics_process(delta: float) -> void:
	if level == null or level.player == null:
		return
	var hero: Node3D = level.player
	var away := _flat(global_position - hero.global_position)
	# Far from the hero it keeps still (nobody sees it).
	if away.length() > 90.0:
		return
	_clock += delta
	var night: bool = level.get("night") == true
	var near: bool = away.length() < shy_distance() and not hero.get("dead")
	match state:
		"sit":
			_timer -= delta
			if near or night:
				_to_tree()
			elif _timer <= 0.0:
				_next()
		"hop":
			_walk(delta, WALK, HOP.x, HOP_HEIGHT.x)
			if near or night:
				_to_tree()
			elif _path.is_empty():
				_begin("sit", _rng.randf_range(1.5, 4.5))
		"flee":
			_walk(delta, RUN, HOP.y, HOP_HEIGHT.y)
			if _path.is_empty():
				_begin("climb", 0.0)
				_start_climb()
		"climb":
			_height = minf(_stop, _height + CLIMB * delta)
			_cling(delta, 1.0)
			if _height >= _stop:
				if night:
					_begin("den", 0.0)
				else:
					_begin("perch", _rng.randf_range(5.0, 11.0))
				# In among the leaves.
				visible = false
		"perch":
			_cling(delta, 1.0)
			_timer -= delta
			if night:
				_begin("den", 0.0)
			elif _timer <= 0.0:
				if away.length() > shy_distance() * CALM_FACTOR:
					visible = true
					_begin("descend", 0.0)
				else:
					# The hero is still about: wait a little longer.
					_timer = 2.0
		"descend":
			_height = maxf(0.0, _height - CLIMB * delta)
			_cling(delta, -1.0)
			if _height <= 0.0:
				_land()
		"den":
			if not night:
				visible = true
				_begin("descend", 0.0)
	_pose(delta)


## Calm again: sit and nibble a while, or bound off to another spot.
func _next() -> void:
	if _rng.randf() < 0.35:
		_begin("sit", _rng.randf_range(1.5, 4.5))
		return
	if _set_path(_nearby(ROAM), false):
		_begin("hop", 0.0)
	else:
		_begin("sit", 2.0)


## Bolts for its tree: along the ground to its foot.
func _to_tree() -> void:
	if state == "flee":
		return
	_set_path(level.cell_to_world(tree.cell), true)
	# The last bound is straight to the foot of the trunk.
	_path.append(Vector3(tree.pos.x, 0.0, tree.pos.z))
	_begin("flee", 0.0)
	Effects.float_text(level, global_position + Vector3(0, 1.4, 0), "!", Color(1.0, 0.95, 0.7, 0.9))


## At the foot of the trunk: up it goes, a little way round, head up.
func _start_climb() -> void:
	var out := _flat(global_position - tree.pos)
	_angle = atan2(out.z, out.x) if out.length() > 0.01 else _rng.randf() * TAU
	_height = 0.0
	_stop = float(tree.height) * _rng.randf_range(CLIMB_TO.x, CLIMB_TO.y)
	if level.get("night") == true:
		_stop = float(tree.height) * CLIMB_TO.y


## Down at the foot again: back to the ground, a few steps out from the trunk.
func _land() -> void:
	var out := Vector3(cos(_angle), 0.0, sin(_angle))
	var spot: Vector3 = tree.pos + out * (TRUNK + 0.6)
	global_position = Vector3(spot.x, 0.0, spot.z)
	reset_physics_interpolation()
	rotation.y = atan2(out.x, out.z)
	_begin("sit", _rng.randf_range(0.8, 2.0))


## Clinging to the trunk, `dir` 1 climbing (head up), -1 coming down.
func _cling(delta: float, dir: float) -> void:
	var out := Vector3(cos(_angle), 0.0, sin(_angle))
	# Spiralling a little as it goes.
	if state in ["climb", "descend"]:
		_angle += delta * 0.7 * dir
	var at: Vector3 = tree.pos + out * (TRUNK) + Vector3.UP * _height
	global_position = at
	# Belly to the trunk: facing it, head up (climbing) or down.
	if state == "perch" or dir > 0.0:
		rotation.y = atan2(-out.x, -out.z)
	else:
		rotation.y = atan2(out.x, out.z)


## Bounds along its path at `speed`, a hop every `hop` metres.
func _walk(delta: float, speed: float, hop: float, height: float) -> void:
	if _path.is_empty():
		return
	var to := _flat(_path[0] - global_position)
	var step := speed * delta
	var target := Vector3(_path[0].x, 0.0, _path[0].z) if to.length() <= step else global_position + to.normalized() * step
	if not WalkRules.can_step(level, global_position, target):
		# A gate was shut (or a wall stands) ahead: sit still, then find the way again.
		_hop_height = 0.0
		_waiting += delta
		if _waiting >= WalkRules.MAKE_WAY:
			_waiting = 0.0
			var goal: Vector3 = _path[_path.size() - 1]
			if not _set_path(goal, state == "flee"):
				_path.clear()
		return
	_waiting = 0.0
	global_position = target
	if to.length() <= step:
		_path.pop_front()
	else:
		_phase += step / hop * PI
	_turn_to(to, delta)
	_hop_height = height


var _hop_height := 0.1


## The pose of the body from the state: the bounding arc, sitting up, or
## clinging to the trunk; and the tail's sway.
func _pose(delta: float) -> void:
	var k := minf(1.0, delta * 10.0)
	var up_target := 1.0 if state == "sit" else 0.0
	_sit_up = lerpf(_sit_up, up_target, minf(1.0, delta * 6.0))
	var pitch := 0.0
	var lift := 0.0
	var tail_up := 0.0
	match state:
		"hop", "flee":
			var arc := absf(sin(_phase))
			lift = arc * _hop_height
			# Nose up at take-off, down on landing.
			pitch = -cos(_phase) * (0.12 if state == "flee" else 0.25)
			tail_up = 0.25 if state == "hop" else -0.45
		"sit":
			pitch = -0.95 * _sit_up
			lift = 0.1 * _sit_up
			tail_up = 0.7 * _sit_up
			# A nibble: the head and hands bob.
			pitch += sin(_clock * 11.0) * 0.04 * _sit_up
		"climb", "perch", "descend":
			var head_up := state != "descend"
			pitch = -PI * 0.5 if head_up else PI * 0.5
			tail_up = 0.0
	_body.rotation.x = lerp_angle(_body.rotation.x, pitch, k)
	_body.position.y = lerpf(_body.position.y, lift, k)
	_limbs(k)
	_flick -= delta
	var flick := 0.0
	if _flick < 0.0:
		flick = sin(_flick * 30.0) * 0.5
		if _flick < -0.6:
			_flick = _rng.randf_range(1.0, 3.0)
	var sway := sin(_clock * 3.0) * 0.1 + flick
	_tail.rotation = Vector3(lerpf(_tail.rotation.x, tail_up, k), 0.0, sway)


## A hand and foot are on the ground only for this share of a bound (the rest of it they swing
## forward through the air): the hands land at the start of it, the hind feet just before the
## end, so both are down about when the body is.
const HAND_DOWN := 0.18
const FOOT_DOWN := 0.18
const FOOT_LANDS := 0.9
const HAND_REST := Vector3(0.04, 0.035, 0.1)
const FOOT_REST := Vector3(0.055, 0.035, -0.07)
var _gait := 0.0
var _stretch := 1.0


## Where along a limb's cycle `t` (0 to 1, the bound) it is on the ground, `down` its share
## of the bound: the limb reaches ahead, lands, and trails back as the body passes over it
## (so it stays put on the ground), then swings forward again. Returns Vector2(forward, up)
## relative to `rest`, with `travel` the body's way over the ground during the contact.
static func _stride_of(t: float, down: float, travel: float, reach: float) -> Vector2:
	if t < down:
		return Vector2(travel * (0.6 - t / down), 0.0)
	var u := (t - down) / (1.0 - down)
	var swing := smoothstep(0.0, 1.0, u)
	# `reach`: how far the limb is thrown out (hands ahead, hind feet behind) in the middle of
	# the swing, as in a squirrel's long, flat leaps.
	return Vector2(lerpf(-0.4 * travel, 0.6 * travel, swing) + reach * sin(u * PI), 0.055 * sin(u * PI))


## The hands and hind feet: bounding on the ground (hands land together, the hind feet swing
## forward past them and land ahead), pulling up and reaching on a trunk, rest otherwise.
func _limbs(k: float) -> void:
	var bounding := state in ["hop", "flee"]
	var climbing := state in ["climb", "descend"]
	_gait = lerpf(_gait, 1.0 if bounding else 0.0, minf(1.0, k * 1.5))
	var long := (HOP.y if state == "flee" else HOP.x) / SIZE
	var t := fposmod(_phase, PI) / PI
	# The body stretches in the air and gathers up on landing.
	var arc := absf(sin(_phase))
	_stretch = lerpf(_stretch, (0.9 + 0.32 * arc) if bounding else 1.0, k)
	_body.scale = Vector3(SIZE, SIZE, SIZE * _stretch)
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var hand: Vector3 = HAND_REST * Vector3(side, 1.0, 1.0)
		var foot: Vector3 = FOOT_REST * Vector3(side, 1.0, 1.0)
		var sway := 0.03 * side
		if _gait > 0.01:
			var h := _stride_of(fposmod(t + sway, 1.0), HAND_DOWN, long * HAND_DOWN, 0.14)
			var f := _stride_of(fposmod(t - FOOT_LANDS + 0.04 * side, 1.0), FOOT_DOWN, long * FOOT_DOWN, -0.26)
			var hand_to := hand + Vector3(0.0, h.y, h.x)
			var foot_to := foot + Vector3(0.0, f.y, f.x + 0.1)
			# Down on the ground while the body is up in the arc: reach for it.
			if t < HAND_DOWN or t > 1.0 - 0.02:
				hand_to.y -= _body.position.y / SIZE
			if fposmod(t - FOOT_LANDS, 1.0) < FOOT_DOWN:
				foot_to.y -= _body.position.y / SIZE
			hand = hand.lerp(hand_to, _gait)
			foot = foot.lerp(foot_to, _gait)
		elif climbing:
			# Up the trunk (the body stands on its tail end): paws pull and reach in turns.
			var c := _height * 9.0 + (PI if i == 0 else 0.0)
			hand += Vector3(0.0, 0.0, 0.05 * sin(c))
			foot += Vector3(0.0, 0.0, 0.05 * sin(c + PI))
		# On the move they follow the gait exactly; otherwise they ease to where they rest.
		var follow := 1.0 if (bounding or climbing) else minf(1.0, k * 2.0)
		_hands[i].position = _hands[i].position.lerp(hand, follow)
		_feet[i].position = _feet[i].position.lerp(foot, follow)


## Fills the path from the tile it stands on to `target`; `exact` keeps to the
## tile centres (running for the tree).
func _set_path(target: Vector3, exact: bool) -> bool:
	# Wandering about: not along the tile centres.
	_path.assign(WalkRules.path(level, global_position, target, _rng, exact))
	return not _path.is_empty()


## A free tile within a few tiles of its tree (the open tile beside it).
func _nearby(radius: int) -> Vector3:
	var home: Vector2i = tree.cell
	for i in 20:
		var c := home + Vector2i(_rng.randi_range(-radius, radius), _rng.randi_range(-radius, radius))
		if _open(c):
			return level.cell_to_world(c) + Vector3(_rng.randf_range(-1.0, 1.0), 0, _rng.randf_range(-1.0, 1.0))
	return level.cell_to_world(home)


func _open(c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= level.width or c.y >= level.height:
		return false
	return level.is_open(c) if level.has_method("is_open") else not level.astar.is_point_solid(c)


func _turn_to(direction: Vector3, delta: float) -> void:
	WalkRules.turn(self, direction, delta, WalkRules.TURN_RATE * 1.5)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


# --- The model ---------------------------------------------------------------

const FUR := Color(0.6, 0.28, 0.1)
const FUR_DARK := Color(0.42, 0.18, 0.07)
const BELLY := Color(0.93, 0.85, 0.7)


## The body of a red squirrel (before SIZE), nose towards +Z, standing on its
## feet at the origin: a plump body with haunches, a round head with a short
## snout, tufted ears and dark eyes, small hands and big hind feet.
static func mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fur := func(d: Vector3) -> Color:
		return FUR.lerp(BELLY, clampf(-d.y * 1.6 - 0.2, 0.0, 1.0))
	var black := func(_d: Vector3) -> Color: return Color(0.05, 0.04, 0.04)
	var pale := func(_d: Vector3) -> Color: return BELLY
	# Body, haunch and shoulders.
	VillageBirds._ball(st, Vector3(0, 0.13, 0.0), Vector3(0.075, 0.075, 0.13), fur)
	VillageBirds._ball(st, Vector3(0, 0.12, -0.085), Vector3(0.085, 0.085, 0.085), fur)
	# Head with snout, nose, ears and eyes.
	VillageBirds._ball(st, Vector3(0, 0.2, 0.135), Vector3(0.06, 0.058, 0.062), fur)
	VillageBirds._ball(st, Vector3(0, 0.185, 0.19), Vector3(0.028, 0.025, 0.03), pale, 4, 6)
	VillageBirds._ball(st, Vector3(0, 0.19, 0.218), Vector3(0.012, 0.011, 0.011), black, 3, 5)
	for side: float in [-1.0, 1.0]:
		VillageBirds._ball(st, Vector3(side * 0.03, 0.222, 0.19), Vector3(0.0105, 0.0105, 0.0105), black, 3, 5)
		# A pointed ear with a tuft.
		for p: Vector3 in [Vector3(side * 0.025, 0.245, 0.12), Vector3(side * 0.055, 0.25, 0.115), Vector3(side * 0.05, 0.31, 0.105)]:
			st.set_color(FUR_DARK)
			st.add_vertex(p)
	st.generate_normals()
	return st.commit()


## A hand (small, dark) and a hind foot (big), each a mesh of its own at the origin so the
## gait can move them (see _limbs).
static func hand_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	VillageBirds._ball(st, Vector3.ZERO, Vector3(0.022, 0.04, 0.024), func(_d: Vector3) -> Color: return FUR_DARK, 3, 5)
	st.generate_normals()
	return st.commit()


static func foot_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	VillageBirds._ball(st, Vector3.ZERO, Vector3(0.03, 0.04, 0.07), func(_d: Vector3) -> Color: return FUR, 3, 6)
	st.generate_normals()
	return st.commit()


## The bushy tail (its root at the origin, curving up and forward over the
## back): a chain of balls, widest near the top, paler at the tip.
static func tail_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const STEPS := 12
	for i in STEPS:
		var t := float(i) / (STEPS - 1)
		# Up the back, curling over at the top.
		var centre := Vector3(0.0, 0.03 + 0.38 * sin(t * PI * 0.5), -0.06 - 0.06 * sin(t * PI) + 0.1 * t * t)
		var r := 0.03 + 0.04 * sin(minf(t * 1.25, 1.0) * PI * 0.5) - 0.012 * maxf(0.0, t - 0.8) * 5.0
		var colour := FUR_DARK.lerp(FUR, minf(1.0, t * 2.0)).lerp(Color(0.86, 0.62, 0.38), maxf(0.0, t - 0.6) * 2.0)
		VillageBirds._ball(st, centre, Vector3(r, r * 1.25, r), func(_d: Vector3) -> Color: return colour, 5, 7)
	st.generate_normals()
	return st.commit()
