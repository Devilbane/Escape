class_name VillageBirds
extends Node3D
## The birds that nest on the village roofs (see AgedStone): by day each one
## flies back and forth between its nest and the village around it, now to
## the ground to peck about for a while, now over to another nest or a loop
## round the roofs, and home again. At night they sit in their nests.
##
## Many of them come down to the market square, often where others are
## already about, and linger there, hopping and pecking for worms (now and
## then one pulls a worm out and gulps it down). Walk up to them and they
## take off together.
##
## Each bird is one of a few colourful kinds (robin, blue tit, goldfinch,
## kingfisher, bullfinch, oriole, green finch): the kind sits in its custom
## data and the shader paints its back, breast, wings, head and beak.
##
## All of them are one MultiMesh, their wings beating in the vertex shader
## (shaders/bird.gdshader), so they cost one draw and a few lines a frame;
## the worms in their beaks are a second, tiny one.
## They only fly while the hero is near enough to see them.
##
## Some nests hold a clutch of eggs (now and then one rocks, as if about to
## hatch), others a brood of chicks. Hungry chicks stretch up, gape and
## cheep; their parents bring them the worms they find (see "carry"), and
## the hero can toss them a handful of grain (SEEDS) from below the nest.

const SHADER := preload("res://shaders/bird.gdshader")
## Birds per nest, flying speed (metres a second), how far they fly from
## the nest at most, and the seconds they sit or peck before flying again.
const PER_NEST := 2
const SPEED := 7.5
const RANGE := 34.0
const SIT := Vector2(2.5, 7.0)
const PECK := Vector2(3.0, 8.0)
## How many kinds of bird there are (their colours are in bird.gdshader).
const KINDS := 7
## How often an outing goes to the market square, how far from the nest it
## may be, how long they linger there, how often one that is done flutters
## over to another spot on the square instead of flying home, and how often
## it lands by the others already there.
const MARKET_CHANCE := 0.6
const MARKET_RANGE := 70.0
const MARKET_STAY := Vector2(8.0, 18.0)
const MARKET_FLUTTER := 0.4
const MARKET_FLOCK := 0.65
## How many spots on the square the birds gather at.
const GATHER := 3
## Pecking: the seconds between two dips of the head, how long a dip lasts,
## how likely a dip brings up a worm and how long the worm is in the beak.
const DIP_EVERY := Vector2(0.35, 1.3)
const DIP_TIME := 0.22
const WORM_CHANCE := 0.15
const WORM_TIME := 1.6
## A bird on the ground takes off when the hero comes this close (metres),
## and the others pecking this near it go too.
const SHY := 3.5
const FLOCK := 6.0
## How far apart birds on the ground keep (metres).
const ROOM := 0.9
## Where the worm hangs from, in the bird's own space (the tip of its beak).
const BEAK := Vector3(0, 0.06, 0.25)
## Beyond this distance from the hero (metres) the birds keep still.
const AWAKE_RANGE := 90.0
const SIZE := 1.9

## How likely a nest holds a brood, how likely a brood is chicks rather than
## eggs, and how many eggs or chicks there are.
const BROOD_CHANCE := 0.6
const CHICK_CHANCE := 0.55
const BROOD_SIZE := Vector2i(2, 3)
const MIN_CHICKS := 2
## Seconds a brood stays full after a parent feeds it, and after the hero does.
const FULL_TIME := Vector2(25.0, 50.0)
const HERO_FULL := 120.0
## Seconds a parent leans down to feed a chick.
const FEED_TIME := 0.9
## The hero feeds a hungry brood from this close (metres, along the ground)
## with a handful of SEEDS from the bag, and hears it cheep from this far.
const SEEDS := "koerner"
const FEED_REACH := 8.0
const CHEEP_RANGE := 18.0
const CHEEP_EVERY := Vector2(1.2, 2.8)
## Seconds between two rocks of an egg, and how long a rock lasts.
const ROCK_EVERY := Vector2(4.0, 11.0)
const ROCK_TIME := 0.7
## For the compendium.
const LEARN := "Küken: In manchen Nestern auf den Dächern des Dorfes liegen Eier, in anderen sitzen junge Vögel. Hungrige Küken recken sich, sperren die Schnäbel auf und piepsen, bis ihre Eltern mit einem Wurm kommen. Trägst du Körner bei dir (bei der Krämerin), stell dich unter so ein Nest: Du wirfst den Küken eine Handvoll hinauf."
## Whether the hero was told how to feed the chicks (once a game).
static var _hinted := false

## Each bird: {"home", "at", "from", "to", "lift", "t", "time", "wait",
## "state" ("sit", "fly", "peck"), "phase", "yaw", "next", "kind",
## "market" (pecking on the market square), "dip" (seconds to the next dip),
## "dipping" (seconds left of this one), "worm" (seconds left with a worm)}.
var birds: Array = []
var nests: Array[Vector3] = []
## Each nest's brood, if it has one: {"nest" (index), "chicks" (or eggs),
## "first" (its first instance in _chick_body or _eggs), "count", "full"
## (seconds left of being full), "beg" (0 to 1, how hard they beg),
## "cheep" (seconds to the next cheep), "slots" ([{"at", "yaw", "phase",
## "rock", "rocking", "pose" (a chick's body, head and lower beak as last
## drawn)}], one per chick or egg)}.
var broods: Array = []
## The brood in each nest, or {} (by nest index).
var _brood_of: Array = []
## Spots on the ground where the birds land to peck.
var ground: Array[Vector3] = []
## The tiles of the market square.
var market: Array[Vector3] = []
var _gather: Array[Vector3] = []
var level: Node3D
var _mm: MultiMesh
var _worms: MultiMesh
var _chick_body: MultiMesh
var _chick_head: MultiMesh
var _chick_jaw: MultiMesh
var _eggs: MultiMesh
var _rng := RandomNumberGenerator.new()
var _clock := 0.0


func _init(level_node: Node3D, nest_spots: Array[Vector3], ground_spots: Array[Vector3], market_spots: Array[Vector3], seed_value: int) -> void:
	name = "VillageBirds"
	level = level_node
	nests = nest_spots
	ground = ground_spots
	market = market_spots
	_rng.seed = seed_value
	for n in nests.size():
		var nest := nests[n]
		for i in PER_NEST:
			var perch := nest + Vector3(0.28 * (i * 2 - 1), 0.24, 0.05)
			birds.append({"home": perch, "at": perch, "from": perch, "to": perch, "lift": 0.0, "t": 0.0,
					"time": 1.0, "wait": _rng.randf_range(0.5, SIT.y), "state": "sit",
					"phase": _rng.randf() * TAU, "yaw": _rng.randf() * TAU, "next": "out",
					"kind": _rng.randi() % KINDS, "market": false, "dip": 0.0, "dipping": 0.0, "worm": 0.0,
					"nest": n, "carry": false, "feed": 0.0})
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_custom_data = true
	# White instance colours: without any, the compatibility renderer gives
	# the shader a vertex COLOR of zero, and the parts and wings are lost.
	_mm.use_colors = true
	_mm.mesh = bird_mesh()
	_mm.instance_count = birds.size()
	for i in birds.size():
		_mm.set_instance_color(i, Color.WHITE)
	var node := MultiMeshInstance3D.new()
	node.multimesh = _mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	node.material_override = mat
	add_child(node)
	_worms = MultiMesh.new()
	_worms.transform_format = MultiMesh.TRANSFORM_3D
	_worms.mesh = worm_mesh()
	_worms.instance_count = birds.size()
	var worms := MultiMeshInstance3D.new()
	worms.name = "Worms"
	worms.multimesh = _worms
	worms.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var worm_mat := StandardMaterial3D.new()
	worm_mat.vertex_color_use_as_albedo = true
	worm_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	worm_mat.roughness = 0.45
	worms.material_override = worm_mat
	add_child(worms)
	for i in birds.size():
		_show(i)
	_make_broods(seed_value)


func _process(delta: float) -> void:
	var hero: Node3D = level.get("player")
	var hero_at := Vector3.INF
	if hero and not birds.is_empty():
		hero_at = to_local(hero.global_position)
		var near := false
		for nest in nests:
			if nest.distance_to(hero_at) < AWAKE_RANGE:
				near = true
				break
		if not near:
			return
	_clock += delta
	var night: bool = level.get("night") == true
	if hero_at != Vector3.INF:
		_shy_away(hero_at)
	for i in birds.size():
		_think(birds[i], delta, night)
		_show(i)
	for brood: Dictionary in broods:
		_tend(brood, delta, night, hero_at)


## Birds on the ground take off when the hero walks up to them, and the
## others pecking near them go with them.
func _shy_away(hero_at: Vector3) -> void:
	for b: Dictionary in birds:
		if b.state != "peck" or _flat_distance(b.at, hero_at) > SHY:
			continue
		var from: Vector3 = b.at
		for other: Dictionary in birds:
			if other.state == "peck" and _flat_distance(other.at, from) < FLOCK:
				_take_off(other)


func _take_off(b: Dictionary) -> void:
	b.worm = 0.0
	b.dipping = 0.0
	b.market = false
	_fly(b, b.home, "home")
	# Startled: they burst up steeply.
	b.lift = float(b.lift) + 3.0


func _think(b: Dictionary, delta: float, night: bool) -> void:
	match b.state:
		"fly":
			b.t += delta / b.time
			if b.t >= 1.0:
				b.at = b.to
				if b.to == b.home:
					b.state = "sit"
					b.market = false
					b.wait = _rng.randf_range(SIT.x, SIT.y)
					if b.carry:
						# Down to the chicks with the worm.
						b.feed = FEED_TIME
						var mid := nests[int(b.nest)] - (b.at as Vector3)
						b.yaw = atan2(mid.x, mid.z)
				elif b.next == "peck":
					b.state = "peck"
					var stay := MARKET_STAY if b.market else PECK
					b.wait = _rng.randf_range(stay.x, stay.y)
					b.dip = _rng.randf_range(DIP_EVERY.x, DIP_EVERY.y)
					_make_room(b)
				else:
					b.state = "sit"
					b.wait = _rng.randf_range(SIT.x, SIT.y) * 0.6
				return
			var t: float = b.t
			var from: Vector3 = b.from
			var to: Vector3 = b.to
			var lift := Vector3.UP * float(b.lift)
			var mid := (from + to) * 0.5 + lift
			var p := from.lerp(mid, t).lerp(mid.lerp(to, t), t)
			var dir := p - (b.at as Vector3)
			if dir.length() > 0.001:
				b.yaw = atan2(dir.x, dir.z)
			b.at = p
		"peck":
			b.wait -= delta
			if night:
				_take_off(b)
				return
			if b.worm > 0.0:
				# Tugging the worm out, then gulping it down, or off home
				# with it to the hungry chicks.
				b.worm -= delta
				if b.carry and b.worm < WORM_TIME * 0.55:
					b.worm = 0.0
					b.market = false
					_fly(b, b.home, "home")
				return
			if b.dipping > 0.0:
				b.dipping -= delta
				if b.dipping <= 0.0 and _rng.randf() < WORM_CHANCE:
					b.worm = WORM_TIME
					b.carry = _wants_worm(b)
				return
			if b.wait <= 0.0:
				if b.market and _rng.randf() < MARKET_FLUTTER:
					# Over to another spot on the square, a few hops away.
					var spot: Vector3 = b.at
					var hop := Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized() * _rng.randf_range(1.5, 3.0)
					if market.any(func(m: Vector3): return _flat_distance(m, spot + hop) < Level.TILE * 0.5):
						_fly(b, spot + hop, "peck")
						return
				_fly(b, b.home, "home")
				return
			b.dip -= delta
			if b.dip <= 0.0:
				b.dipping = DIP_TIME
				b.dip = _rng.randf_range(DIP_EVERY.x, DIP_EVERY.y)
			elif _rng.randf() < delta * 1.2:
				# Little hops about on the ground.
				b.at += Vector3(_rng.randf_range(-0.4, 0.4), 0, _rng.randf_range(-0.4, 0.4))
				b.yaw = _rng.randf() * TAU
				_make_room(b)
		"sit":
			if b.feed > 0.0:
				b.feed -= delta
				if b.feed <= 0.0:
					b.carry = false
					b.feed = 0.0
					var brood: Dictionary = _brood_of[int(b.nest)]
					if not brood.is_empty():
						brood.full = _rng.randf_range(FULL_TIME.x, FULL_TIME.y)
				return
			b.wait -= delta
			if night:
				if b.at != b.home:
					_fly(b, b.home, "home")
				return
			if b.wait > 0.0:
				return
			if b.at != b.home:
				_fly(b, b.home, "home")
				return
			var roll := _rng.randf()
			if roll < MARKET_CHANCE and _to_market(b):
				return
			var near_ground := ground.filter(func(g: Vector3): return g.distance_to(b.home) < RANGE)
			if roll < 0.7 and not near_ground.is_empty():
				var spot: Vector3 = near_ground[_rng.randi() % near_ground.size()]
				_fly(b, spot + Vector3(_rng.randf_range(-1.5, 1.5), 0.05, _rng.randf_range(-1.5, 1.5)), "peck")
			elif roll < 0.88 and nests.size() > 1:
				var other: Vector3 = nests[_rng.randi() % nests.size()]
				if other.distance_to(b.home) < RANGE * 1.5 and other.distance_to(b.home) > 1.0:
					_fly(b, other + Vector3(_rng.randf_range(-0.3, 0.3), 0.3, _rng.randf_range(-0.3, 0.3)), "sit")
				else:
					b.wait = _rng.randf_range(SIT.x, SIT.y)
			else:
				# A loop round the roofs, back to the nest.
				var away := Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized() * _rng.randf_range(8.0, 16.0)
				_fly(b, b.home + away + Vector3.UP * _rng.randf_range(1.0, 4.0), "sit")
				b.wait = 0.0


## A bird on the ground keeps a little room between itself and the others.
func _make_room(b: Dictionary) -> void:
	for o: Dictionary in birds:
		if is_same(o, b) or o.state != "peck":
			continue
		var away := Vector3(b.at.x - o.at.x, 0, b.at.z - o.at.z)
		var d := away.length()
		if d < ROOM:
			if d < 0.01:
				away = Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1))
			b.at += away.normalized() * (ROOM - d)


## Down to the market square: to one of its few gathering spots (where
## the crumbs are, see GATHER), most often beside birds already there.
## False when the square is too far from the nest.
func _to_market(b: Dictionary) -> bool:
	if _gather.is_empty() and not market.is_empty():
		var pick := market.duplicate()
		for i in mini(GATHER, pick.size()):
			_gather.append(pick.pop_at(_rng.randi() % pick.size()))
	var spot := Vector3.INF
	if _rng.randf() < MARKET_FLOCK:
		var there := birds.filter(func(o: Dictionary): return not is_same(o, b) and o.market)
		if not there.is_empty():
			var o: Dictionary = there[_rng.randi() % there.size()]
			spot = o.to if o.state == "fly" else o.at
	if spot == Vector3.INF:
		var near_by := _gather.filter(func(m: Vector3): return m.distance_to(b.home) < MARKET_RANGE)
		if near_by.is_empty():
			return false
		spot = near_by[_rng.randi() % near_by.size()]
	if spot.distance_to(b.home) > MARKET_RANGE:
		return false
	b.market = true
	spot.y = 0.0
	_fly(b, spot + Vector3(_rng.randf_range(-1.0, 1.0), 0.05, _rng.randf_range(-1.0, 1.0)), "peck")
	return true


## Whether a bird that just pulled up a worm takes it home: when its own
## chicks are hungry and their other parent is not already on the way.
func _wants_worm(b: Dictionary) -> bool:
	var brood: Dictionary = _brood_of[int(b.nest)]
	if brood.is_empty() or not brood.chicks or brood.full > 0.0:
		return false
	return not birds.any(func(o: Dictionary): return not is_same(o, b) and o.nest == b.nest and o.carry)


func _fly(b: Dictionary, to: Vector3, next: String) -> void:
	b.from = b.at
	b.to = to
	b.next = next
	b.t = 0.0
	var dist := (b.from as Vector3).distance_to(to)
	b.time = maxf(0.6, dist / SPEED)
	# Short hops stay low, long flights arc up over the roofs.
	b.lift = minf(2.0, dist * 0.4) + dist * 0.25
	b.state = "fly"


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _show(i: int) -> void:
	var b: Dictionary = birds[i]
	var flying: bool = b.state == "fly"
	var kind := (float(b.kind) + 0.5) / KINDS
	var basis := Basis(Vector3.UP, b.yaw).scaled(Vector3.ONE * SIZE)
	var at: Vector3 = b.at
	var worm := 0.0
	if flying:
		# Gliding down the last stretch, beating hard on the way up.
		var climbing: bool = b.t < 0.5
		_mm.set_instance_custom_data(i, Color(b.phase, 0.9 if climbing else 0.45, 0.0, kind))
		basis = basis * Basis(Vector3.RIGHT, -0.25 if climbing else 0.15)
	else:
		_mm.set_instance_custom_data(i, Color(b.phase, 0.0, 1.0, kind))
		if b.feed > 0.0:
			# Leaning down into the nest, the worm going into a gaping beak.
			var done := 1.0 - float(b.feed) / FEED_TIME
			worm = clampf((1.0 - done) * 1.6, 0.0, 1.0)
			basis = basis * Basis(Vector3.RIGHT, sin(PI * done) * 0.7)
		elif b.state == "peck":
			if b.worm > 0.0:
				# Head up, tugging: the worm stretches out, then goes down whole.
				var done := 1.0 - float(b.worm) / WORM_TIME
				worm = clampf(done * 4.0, 0.0, 1.0) * clampf((1.0 - done) * 3.0, 0.0, 1.0)
				basis = basis * Basis(Vector3.RIGHT, 0.35 * (1.0 - done) - 0.3 + sin(_clock * 22.0 + b.phase) * 0.08 * worm)
			elif b.dipping > 0.0:
				# The head goes down into the ground and up again.
				basis = basis * Basis(Vector3.RIGHT, sin(PI * (1.0 - float(b.dipping) / DIP_TIME)) * 0.75)
	if b.carry and b.worm <= 0.0 and b.feed <= 0.0:
		# Flying home with the worm hanging from the beak.
		worm = 1.0
	var xform := Transform3D(basis, at)
	_mm.set_instance_transform(i, xform)
	if worm > 0.0:
		var wiggle := Basis(Vector3.FORWARD, sin(_clock * 18.0 + b.phase) * 0.6).scaled(Vector3(1.0, worm, 1.0))
		_worms.set_instance_transform(i, xform * Transform3D(wiggle, BEAK))
	else:
		_worms.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), at))


## A small bird: a body, a head with a beak, a tail and two wings, flying
## towards +z. COLOR.r says which part a vertex belongs to, for the shader to
## paint in its kind's colours (0 back, 0.25 breast, 0.5 wings and tail,
## 0.75 head, 1 beak); COLOR.a marks the wings (see bird.gdshader).
static func bird_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var back := Color(0.0, 0, 0, 0.5)
	var breast := Color(0.25, 0, 0, 0.5)
	var wing := Color(0.5, 0, 0, 0.5)
	var head := Color(0.75, 0, 0, 0.5)
	var beak := Color(1.0, 0, 0, 0.5)
	# Body: a stretched diamond, the breast underneath.
	var nose := Vector3(0, 0.02, 0.17)
	var tail := Vector3(0, 0.03, -0.14)
	var top := Vector3(0, 0.08, 0.02)
	var bottom := Vector3(0, -0.05, 0.03)
	var left := Vector3(-0.055, 0.02, 0.02)
	var right := Vector3(0.055, 0.02, 0.02)
	for tri: Array in [[nose, top, right], [nose, right, bottom], [nose, bottom, left], [nose, left, top],
			[tail, right, top], [tail, bottom, right], [tail, left, bottom], [tail, top, left]]:
		for p: Vector3 in tri:
			st.set_color(breast if p == bottom or (p == nose and tri.has(bottom)) else back)
			st.add_vertex(p)
	# The head: a smaller diamond up front.
	var h_front := Vector3(0, 0.075, 0.21)
	var h_back := Vector3(0, 0.08, 0.11)
	var h_top := Vector3(0, 0.12, 0.16)
	var h_bottom := Vector3(0, 0.03, 0.16)
	var h_left := Vector3(-0.042, 0.075, 0.16)
	var h_right := Vector3(0.042, 0.075, 0.16)
	for tip: Vector3 in [h_front, h_back]:
		for pair: Array in [[h_top, h_right], [h_right, h_bottom], [h_bottom, h_left], [h_left, h_top]]:
			for p: Vector3 in [tip, pair[0], pair[1]]:
				st.set_color(head)
				st.add_vertex(p)
	# The beak: a little pointed wedge.
	var b_tip := BEAK
	var b_top := Vector3(0, 0.085, 0.2)
	var b_low := Vector3(0, 0.055, 0.2)
	var b_left := Vector3(-0.018, 0.07, 0.2)
	var b_right := Vector3(0.018, 0.07, 0.2)
	for pair: Array in [[b_top, b_right], [b_right, b_low], [b_low, b_left], [b_left, b_top]]:
		for p: Vector3 in [b_tip, pair[0], pair[1]]:
			st.set_color(beak)
			st.add_vertex(p)
	# The tail fan.
	for p: Vector3 in [Vector3(0, 0.04, -0.1), Vector3(-0.06, 0.03, -0.24), Vector3(0.06, 0.03, -0.24)]:
		st.set_color(wing)
		st.add_vertex(p)
	# Wings: a swept triangle on each side, the tip marked by COLOR.a.
	for side: float in [-1.0, 1.0]:
		var tip_a := 0.5 + side * 0.5
		var root_a := 0.5 + side * 0.04
		var pts := [Vector3(side * 0.04, 0.04, 0.08), Vector3(side * 0.04, 0.04, -0.04), Vector3(side * 0.3, 0.05, -0.08)]
		var alphas := [root_a, root_a, tip_a]
		var inner := [Vector3(side * 0.04, 0.04, 0.08), Vector3(side * 0.3, 0.05, -0.08), Vector3(side * 0.18, 0.045, 0.06)]
		var inner_a := [root_a, tip_a, 0.5 + side * 0.3]
		for k in 3:
			st.set_color(Color(wing.r, 0, 0, alphas[k]))
			st.add_vertex(pts[k])
		for k in 3:
			st.set_color(Color(wing.r, 0, 0, inner_a[k]))
			st.add_vertex(inner[k])
	st.generate_normals()
	return st.commit()


## A pink earthworm hanging down from the beak (its top at the origin),
## two crossed strips with a bend in them.
static func worm_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := [Vector3(0, 0, 0), Vector3(0.014, -0.05, 0.012), Vector3(-0.01, -0.1, 0.02), Vector3(0.008, -0.15, 0.014)]
	var pink := Color(0.86, 0.46, 0.5)
	var dark := Color(0.62, 0.3, 0.34)
	for axis: Vector3 in [Vector3(0.011, 0, 0), Vector3(0, 0, 0.011)]:
		for k in pts.size() - 1:
			var w0: Vector3 = axis * (1.0 - k * 0.15)
			var w1: Vector3 = axis * (1.0 - (k + 1) * 0.15)
			var a: Vector3 = pts[k]
			var c: Vector3 = pts[k + 1]
			var col := pink if k % 2 == 0 else dark
			for p: Vector3 in [a - w0, a + w0, c + w1, a - w0, c + w1, c - w1]:
				st.set_color(col)
				st.add_vertex(p)
	st.generate_normals()
	return st.commit()


# --- Eggs and chicks ------------------------------------------------------------

## Decides which nests hold eggs and which chicks (with their own random
## numbers, so the birds fly as before), and builds them: one MultiMesh for
## the eggs, three for the chicks (body, head with the upper beak, and the
## lower beak, which opens and shuts).
func _make_broods(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 1
	_brood_of.resize(nests.size())
	_brood_of.fill({})
	var kinds := []
	for n in nests.size():
		kinds.append("" if rng.randf() >= BROOD_CHANCE else ("chicks" if rng.randf() < CHICK_CHANCE else "eggs"))
	# A village with nests has a few broods of chicks to find (MIN_CHICKS),
	# and with more nests than that a clutch of eggs too.
	for n in nests.size():
		if kinds.count("chicks") >= MIN_CHICKS:
			break
		if kinds[n] != "chicks" and (kinds[n] != "eggs" or kinds.count("eggs") > 1):
			kinds[n] = "chicks"
	if nests.size() > MIN_CHICKS and not kinds.has("eggs"):
		kinds[kinds.rfind("") if kinds.has("") else nests.size() - 1] = "eggs"
	var chicks := 0
	var eggs := 0
	for n in nests.size():
		if kinds[n] == "":
			continue
		var is_chicks: bool = kinds[n] == "chicks"
		var count := rng.randi_range(BROOD_SIZE.x, BROOD_SIZE.y)
		var brood := {"nest": n, "chicks": is_chicks, "first": chicks if is_chicks else eggs, "count": count,
				"full": rng.randf_range(0.0, FULL_TIME.y), "beg": 0.0, "cheep": rng.randf_range(CHEEP_EVERY.x, CHEEP_EVERY.y), "slots": []}
		var turn := rng.randf() * TAU
		for k in count:
			var a := turn + TAU * k / count + rng.randf_range(-0.3, 0.3)
			var r := rng.randf_range(0.1, 0.14) if count > 1 else 0.0
			brood.slots.append({"at": Vector3(cos(a) * r, 0.0, sin(a) * r), "yaw": a + PI + rng.randf_range(-0.5, 0.5),
					"phase": rng.randf() * TAU, "rock": rng.randf_range(ROCK_EVERY.x, ROCK_EVERY.y), "rocking": 0.0, "pose": []})
		if is_chicks:
			chicks += count
		else:
			eggs += count
		broods.append(brood)
		_brood_of[n] = brood
	_chick_body = _brood_multimesh("ChickBodies", chick_body_mesh(), chicks)
	_chick_head = _brood_multimesh("ChickHeads", chick_head_mesh(), chicks)
	_chick_jaw = _brood_multimesh("ChickBeaks", chick_jaw_mesh(), chicks)
	_eggs = _brood_multimesh("Eggs", egg_mesh(), eggs)
	for brood: Dictionary in broods:
		_show_brood(brood)


func _brood_multimesh(node_name: String, mesh: Mesh, count: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	node.material_override = mat
	add_child(node)
	return mm


## A brood over a frame: chicks grow hungry, beg while they are (and while a
## parent sits by them), cheep when the hero is near enough to hear, and
## take a handful of grain from a hero standing below; eggs rock now and then.
func _tend(brood: Dictionary, delta: float, night: bool, hero_at: Vector3) -> void:
	var nest := nests[int(brood.nest)]
	if not brood.chicks:
		for slot: Dictionary in brood.slots:
			if slot.rocking > 0.0:
				slot.rocking -= delta
			else:
				slot.rock -= delta
				if slot.rock <= 0.0:
					slot.rock = _rng.randf_range(ROCK_EVERY.x, ROCK_EVERY.y)
					slot.rocking = ROCK_TIME
		_show_brood(brood)
		return
	brood.full = maxf(0.0, brood.full - delta)
	var hungry := is_hungry(brood) and not night
	var parent_by := birds.any(func(b: Dictionary): return b.nest == brood.nest and b.feed > 0.0)
	var want := 1.0 if hungry or parent_by else 0.0
	brood.beg = move_toward(brood.beg, want, delta * (4.0 if want > 0.0 else 1.5))
	if hero_at != Vector3.INF:
		var away := _flat_distance(nest, hero_at)
		if hungry and away < CHEEP_RANGE:
			brood.cheep -= delta
			if brood.cheep <= 0.0:
				brood.cheep = _rng.randf_range(CHEEP_EVERY.x, CHEEP_EVERY.y)
				Sfx.play(self, "cheep", -8.0 - away * 0.6, to_global(nest), _rng.randf_range(0.92, 1.1))
		if hungry and away < FEED_REACH:
			_hero_below(brood)
	_show_brood(brood)


## Whether a brood of chicks wants feeding.
static func is_hungry(brood: Dictionary) -> bool:
	return brood.chicks and brood.full <= 0.0


## The hero stands below a nest of hungry chicks: with grain in the bag they
## toss a handful up (the chicks are full for a good while); without, they
## are told once a game where to get some.
func _hero_below(brood: Dictionary) -> void:
	var hero: Node = level.get("player")
	if hero == null or hero.get("dead") == true:
		return
	var bag = hero.get("bag")
	if bag is Array and (bag as Array).has(SEEDS):
		(bag as Array).erase(SEEDS)
		brood.full = HERO_FULL
		Sfx.play(self, "cheep", -4.0, to_global(nests[int(brood.nest)]), 1.15)
		Events.tell(Lang.t("Du wirfst den Küken eine Handvoll Körner hinauf. Sie piepsen zufrieden und kuscheln sich ins Nest."), Color(0.95, 0.88, 0.55), 3.5)
		Events.teach(LEARN)
		fed_by_hero += 1
	elif not _hinted:
		_hinted = true
		Events.tell(Lang.t("Über dir piepsen hungrige Küken. Körner für sie gibt es bei der Krämerin."), Color(0.95, 0.88, 0.55), 3.5)
		Events.teach(LEARN)


func _show_brood(brood: Dictionary) -> void:
	var nest := nests[int(brood.nest)]
	if not brood.chicks:
		for k in brood.count:
			var slot: Dictionary = brood.slots[k]
			var tilt := 0.0
			if slot.rocking > 0.0:
				var t := 1.0 - float(slot.rocking) / ROCK_TIME
				tilt = sin(t * TAU * 2.0) * (1.0 - t) * 0.35
			var basis := Basis(Vector3.UP, slot.yaw) * Basis(Vector3.FORWARD, tilt) * Basis(Vector3.RIGHT, 1.2)
			_eggs.set_instance_transform(int(brood.first) + k, Transform3D(basis, nest + slot.at + Vector3(0, 0.12, 0)))
		return
	var beg: float = brood.beg
	# Begging chicks turn to a parent on the rim, or else up to the sky.
	var parent := Vector3.INF
	for b: Dictionary in birds:
		if b.nest == brood.nest and b.state == "sit" and b.at == b.home:
			parent = b.at
			break
	for k in brood.count:
		var slot: Dictionary = brood.slots[k]
		var phase: float = slot.phase
		var body_at := nest + (slot.at as Vector3) + Vector3(0, 0.13 + beg * 0.03, 0)
		var yaw: float = slot.yaw
		if parent != Vector3.INF and beg > 0.0:
			var to := parent - body_at
			yaw = lerp_angle(yaw, atan2(to.x, to.z), beg)
		yaw += sin(_clock * 6.0 + phase) * 0.35 * beg
		var breathe := 1.0 + sin(_clock * 2.5 + phase) * 0.03
		var body := Basis(Vector3.UP, yaw).scaled(Vector3(1.0, breathe, 1.0))
		var i: int = int(brood.first) + k
		_chick_body.set_instance_transform(i, Transform3D(body, body_at))
		# The neck stretches up and the head tips back, beak to the sky,
		# bobbing while it begs.
		var stretch := beg * (0.08 + sin(_clock * 9.0 + phase) * 0.015)
		var head := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -1.25 * beg + 0.15 * (1.0 - beg))
		var head_xf := Transform3D(head, body_at + Vector3(0, 0.07 + stretch, 0) + Basis(Vector3.UP, yaw) * Vector3(0, 0, 0.03))
		_chick_head.set_instance_transform(i, head_xf)
		var gape := beg * (0.55 + 0.45 * sin(_clock * 17.0 + phase * 3.0)) * 0.85
		var jaw_xf := head_xf * Transform3D(Basis(Vector3.RIGHT, gape), CHICK_HINGE)
		_chick_jaw.set_instance_transform(i, jaw_xf)
		slot.pose = [Transform3D(body, body_at), head_xf, jaw_xf]


## Where the lower beak hinges on a chick's head.
const CHICK_HINGE := Vector3(0, 0.035, 0.05)
## How often the hero fed chicks in this village (for the tests).
var fed_by_hero := 0


## A ball of `rings` × `segments` with its radii, coloured by `paint`
## (given the unit direction of each vertex).
static func _ball(st: SurfaceTool, centre: Vector3, radii: Vector3, paint: Callable, rings := 6, segments := 8) -> void:
	var dir := func(r: int, s: int) -> Vector3:
		var lat := PI * r / rings - PI * 0.5
		var lon := TAU * s / segments
		return Vector3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon))
	for r in rings:
		for s in segments:
			var quad := [dir.call(r, s), dir.call(r + 1, s), dir.call(r + 1, s + 1), dir.call(r, s + 1)]
			for k: int in [0, 1, 2, 0, 2, 3]:
				var d: Vector3 = quad[k]
				st.set_color(paint.call(d))
				st.add_vertex(centre + d * radii)


## A nestling's body: a fluffy grey-brown ball, paler underneath.
static func chick_body_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_ball(st, Vector3.ZERO, Vector3(0.1, 0.085, 0.11), func(d: Vector3) -> Color:
		return Color(0.33, 0.29, 0.27).lerp(Color(0.6, 0.53, 0.46), clampf(-d.y * 0.8 + 0.3, 0.0, 1.0)))
	# Two stubby wings.
	for side: float in [-1.0, 1.0]:
		for p: Vector3 in [Vector3(side * 0.09, 0.03, 0.04), Vector3(side * 0.12, 0.0, -0.06), Vector3(side * 0.095, -0.03, 0.0)]:
			st.set_color(Color(0.36, 0.32, 0.29))
			st.add_vertex(p)
	st.generate_normals()
	return st.commit()


## A nestling's head (its neck at the origin): a round head with a fluffy
## tuft, dark eyes, and the upper half of a wide beak, bright yellow at its
## edges and red-orange inside.
static func chick_head_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_ball(st, Vector3(0, 0.03, 0), Vector3(0.065, 0.06, 0.065), func(d: Vector3) -> Color:
		return Color(0.36, 0.32, 0.29).lerp(Color(0.56, 0.5, 0.44), clampf(-d.y, 0.0, 1.0)))
	for side: float in [-1.0, 1.0]:
		_ball(st, Vector3(side * 0.04, 0.05, 0.04), Vector3(0.016, 0.016, 0.016), func(_d: Vector3) -> Color: return Color(0.06, 0.05, 0.05), 3, 5)
	# The tuft of down on top.
	for k in 3:
		var x := (k - 1) * 0.018
		for p: Vector3 in [Vector3(x - 0.01, 0.085, 0.0), Vector3(x + 0.01, 0.085, 0.0), Vector3(x * 1.6, 0.13, -0.015)]:
			st.set_color(Color(0.5, 0.46, 0.41))
			st.add_vertex(p)
	_beak_half(st, 1.0)
	st.generate_normals()
	return st.commit()


## The lower half of a nestling's beak, hinged at CHICK_HINGE.
static func chick_jaw_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_beak_half(st, -1.0, -CHICK_HINGE)
	st.generate_normals()
	return st.commit()


## One half of a gaping beak, pointing towards +z: `up` 1 for the upper half
## (yellow on top, the red mouth below), -1 for the lower one.
static func _beak_half(st: SurfaceTool, up: float, shift := Vector3.ZERO) -> void:
	var yellow := Color(1.0, 0.82, 0.18)
	var mouth := Color(0.95, 0.35, 0.18)
	var hinge := CHICK_HINGE + shift
	var left := hinge + Vector3(-0.05, 0.0, -0.005)
	var right := hinge + Vector3(0.05, 0.0, -0.005)
	var tip := hinge + Vector3(0, 0.0, 0.085)
	var ridge := hinge + Vector3(0, 0.022 * up, 0.02)
	# The outside, then the inside of the mouth.
	for tri: Array in [[left, ridge, tip], [ridge, right, tip], [left, ridge, right]]:
		for p: Vector3 in (tri if up > 0.0 else [tri[0], tri[2], tri[1]]):
			st.set_color(yellow)
			st.add_vertex(p)
	for p: Vector3 in ([left, tip, right] if up > 0.0 else [left, right, tip]):
		st.set_color(mouth)
		st.add_vertex(p)


## A small egg, pale blue with brown speckles, its long axis along y.
static func egg_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_ball(st, Vector3.ZERO, Vector3(0.06, 0.08, 0.06), func(d: Vector3) -> Color:
		var speck := fposmod(sin(d.x * 41.0 + d.y * 17.0) * 43758.5 + d.z * 13.0, 1.0)
		return Color(0.45, 0.33, 0.24) if speck > 0.82 else Color(0.56, 0.78, 0.86), 7, 10)
	st.generate_normals()
	return st.commit()
