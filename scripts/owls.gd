class_name Owls
extends Node3D
## The tawny owls of the woods: a few of them to a map, each perched on a branch of a tall tree
## (a bare branch grows out of the trunk to hold it). From dusk until a little after dawn they are
## awake: they turn their heads this way and that (now and then to look at the hero), blink, tilt
## their heads at a curious sound, hoot (with a puff of the chest, and a second owl answers across
## the woods a few seconds later) and, once in a long while, spread their wings and glide without a
## sound to another tree. By day they doze with their eyes shut and their heads sunk. Winter or
## summer, they stay.
##
## Each owl is a handful of small textured meshes (a feather texture drawn once and shared, see
## feather_texture); only owls within AWAKE_RANGE of the hero move at all, the rest keep still, so
## the whole flock costs next to nothing. Hoots are positional (see Sfx.play_3d).
## The calls are synthesised by tools/make_owl_sounds.py (our own work, CC0).
## Tested by tests/owls.gd.

## At most this many owls live on a map, on at most this many perches (trees), and the least
## distance between two perches (tiles).
const MAX_OWLS := 5
const MAX_PERCHES := 16
const PERCH_SPACING := 5
## Only trees at least this tall (metres) hold an owl; it sits this far up the tree (fraction of
## its height) and this far out on a branch (metres) towards the open ground.
const MIN_TREE := 4.5
const PERCH_HEIGHT := 0.7
const BRANCH_OUT := 1.1
## Beyond this distance from the hero (metres) an owl keeps still, and its calls are heard no
## farther than HEAR_RANGE.
const AWAKE_RANGE := 75.0
const HEAR_RANGE := 70.0
## The hours between which the owls are awake: from the evening until dawn.
const ACTIVE_FROM := 18.5
const ACTIVE_UNTIL := 5.5
## Seconds between two hoots of one owl, in the evening and in the deep night.
const HOOT_EVERY := Vector2(9.0, 22.0)
const HOOT_NIGHT := Vector2(6.0, 15.0)
## How far an owl's call carries to another owl that answers it (metres), and the seconds before it does.
const ANSWER_RANGE := 50.0
const ANSWER_AFTER := Vector2(2.5, 4.5)
## Seconds between two turns of the head, and how far it turns at most (radians).
const TURN_EVERY := Vector2(1.6, 5.5)
const TURN_MAX := 2.0
## An owl within this distance (metres) of the hero looks at him now and then.
const LOOK_RANGE := 18.0
const LOOK_CHANCE := 0.45
## Seconds between two blinks.
const BLINK_EVERY := Vector2(2.0, 6.5)
## Seconds between two glides, how far the hero may be for one to begin, the distance of a glide
## (metres) and its speed (metres a second).
const GLIDE_EVERY := Vector2(30.0, 80.0)
const GLIDE_HERO := 50.0
const GLIDE_REACH := Vector2(7.0, 38.0)
const GLIDE_SPEED := 5.5
## How loud a hoot is close by (dB), how fast it fades with distance (dB a metre beyond FADE_FROM)
## and how much quieter it is when the hero is indoors.
const HOOT_DB := -4.0
const FADE_FROM := 12.0
const FADE_RATE := 0.45
const INDOORS_DB := -10.0
const SOUNDS := ["owl_hoot_0", "owl_hoot_1"]
const ANSWER_SOUND := "owl_hoot_2"
## How long each call lasts (seconds), for the puff of the chest.
const SOUND_LENGTH := {"owl_hoot_0": 2.9, "owl_hoot_1": 3.2, "owl_hoot_2": 0.7}
## The size of an owl (a real tawny owl is 38 cm: a little bigger here so it is seen from the camera).
const SIZE := 1.25

## Reported when an owl hoots: its number and the sound it makes (for the tests).
signal hooted(index: int, sound: String)

var owls: Array[Dictionary] = []
## Where the owls may sit: each is {"pos": the perch, "trunk": where the branch leaves the trunk, "taken": bool}.
var perches: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
## The graveyard's clock owl (an index into `owls`, -1 for none) and whether tonight it strikes the hours
## (a full-moon night, see OwlClock). While it strikes, the other owls keep quiet so its hoots can be counted.
var clock_owl := -1
var clock_on := false
var _clock_step := 0
var _clock_t := 0.0
static var _texture: ImageTexture
static var _bark: ImageTexture


## Builds the owls of `level` from the trees it recorded (see WoodsLife: dictionaries with pos,
## height, cell, in_village). `cell_to_world` turns a tile into a spot of the map.
func _init(trees: Array, cell_to_world: Callable, tile: float, seed_text := "") -> void:
	name = "Owls"
	_rng.seed = hash(seed_text + "eulen")
	var spots := trees.filter(func(t: Dictionary): return not t.in_village and float(t.height) >= MIN_TREE)
	for i in range(spots.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var keep = spots[i]
		spots[i] = spots[j]
		spots[j] = keep
	for t: Dictionary in spots:
		if perches.size() >= MAX_PERCHES:
			break
		var trunk := Vector3(t.pos.x, float(t.height) * PERCH_HEIGHT, t.pos.z)
		if _too_close(trunk, tile * PERCH_SPACING):
			continue
		var out := Vector3(0, 0, 1)
		if t.has("cell"):
			var c: Vector3 = cell_to_world.call(t.cell)
			out = Vector3(c.x - t.pos.x, 0.0, c.z - t.pos.z).normalized()
			if out == Vector3.ZERO:
				out = Vector3(0, 0, 1)
		perches.append({"pos": trunk + out * BRANCH_OUT, "trunk": trunk, "taken": false})
	var count := mini(MAX_OWLS, perches.size() / 2)
	if perches.size() >= 6:
		count = maxi(count, 3)
	for i in count:
		_add_owl(i)


## Adds the owl of the graveyard's dead tree: it perches at `trunk` on a branch towards `toward`, never
## glides away and hoots only the pattern of the owl clock (see OwlClock).
func add_clock_owl(trunk: Vector3, toward: Vector3) -> void:
	var out := Vector3(toward.x - trunk.x, 0.0, toward.z - trunk.z).normalized()
	if out == Vector3.ZERO:
		out = Vector3(0, 0, 1)
	perches.append({"pos": trunk + out * BRANCH_OUT, "trunk": trunk, "taken": false})
	_add_owl(perches.size() - 1)
	clock_owl = owls.size() - 1
	var o := owls[clock_owl]
	o.glide_t = INF
	o.hoot_t = INF
	(o.node as Node3D).rotation.y = atan2(out.x, out.z)


## Whether the other owls keep quiet: the clock is striking.
func clock_quiet(hour: float) -> bool:
	return clock_owl >= 0 and clock_on and OwlClock.striking(hour)


## Whether the owls are awake at an hour.
static func awake_at(hour: float) -> bool:
	hour = fposmod(hour, 24.0)
	return hour >= ACTIVE_FROM or hour < ACTIVE_UNTIL


func _too_close(at: Vector3, distance: float) -> bool:
	for p: Dictionary in perches:
		if Vector2(p.pos.x - at.x, p.pos.z - at.z).length() < distance:
			return true
	return false


func _add_owl(index: int) -> void:
	var perch := perches[index]
	perch.taken = true
	var root := Node3D.new()
	root.name = "Owl%d" % index
	add_child(root)
	root.position = perch.pos
	root.rotation.y = _rng.randf() * TAU
	root.scale = Vector3.ONE * SIZE
	# The branch it sits on: a tapered, barked limb from the trunk out to the perch.
	var branch := _branch(perch.trunk, perch.pos)
	add_child(branch)
	var body := MeshInstance3D.new()
	body.mesh = body_mesh()
	body.material_override = _material()
	root.add_child(body)
	var head := Node3D.new()
	head.position = Vector3(0, 0.38, 0.02)
	root.add_child(head)
	var head_mesh := MeshInstance3D.new()
	head_mesh.mesh = head_mesh_of()
	head_mesh.material_override = _material()
	head.add_child(head_mesh)
	var eyes: Array[MeshInstance3D] = []
	for side: float in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		eye.mesh = eye_mesh()
		eye.material_override = _eye_material()
		eye.position = Vector3(side * 0.05, 0.012, 0.112)
		head.add_child(eye)
		eyes.append(eye)
	var wings: Array[Node3D] = []
	for side: float in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * 0.12, 0.31, -0.01)
		root.add_child(pivot)
		var wing := MeshInstance3D.new()
		wing.mesh = wing_mesh(side)
		wing.material_override = _material()
		pivot.add_child(wing)
		wings.append(pivot)
	owls.append({
		"node": root, "head": head, "body": body, "eyes": eyes, "wings": wings, "perch": index,
		"state": "perch", "asleep": false, "head_yaw": 0.0, "head_to": 0.0, "head_roll": 0.0, "roll_to": 0.0,
		"turn_t": _rng.randf_range(0.0, 3.0), "blink_t": _rng.randf_range(1.0, 4.0), "blink": 0.0,
		"hoot_t": _rng.randf_range(2.0, 14.0), "glide_t": _rng.randf_range(GLIDE_EVERY.x, GLIDE_EVERY.y),
		"puff": 0.0, "puff_len": 1.0, "answer": false, "pitch": _rng.randf_range(0.9, 1.12),
		"from": Vector3.ZERO, "to": Vector3.ZERO, "t": 0.0, "dur": 1.0, "flap": 0.0, "wing_open": 0.0,
	})
	_pose(owls[owls.size() - 1], 0.0)


# --- Behaviour ---------------------------------------------------------------------------------

## Moves the owls near the hero for one frame. `hour` is the world's hour; `covered` is true while
## the hero is indoors (the hoots are muffled).
func tick(delta: float, hero: Vector3, hour: float, covered := false) -> void:
	var awake := awake_at(hour)
	for i in owls.size():
		var o := owls[i]
		var node: Node3D = o.node
		var d := Vector2(node.global_position.x - hero.x, node.global_position.z - hero.z).length()
		if d > AWAKE_RANGE:
			if o.state == "glide":
				_land(o)
			continue
		if not awake and o.state != "glide":
			_doze(o, delta)
			continue
		if o.asleep:
			o.asleep = false
		if o.state == "glide":
			_glide(o, delta)
			continue
		_perched(i, o, delta, hero, d, hour, covered)
	_clock_tick(delta, hero, hour, covered)


func _perched(i: int, o: Dictionary, delta: float, hero: Vector3, d: float, hour: float, covered: bool) -> void:
	var node: Node3D = o.node
	# Turning the head: now somewhere, now at the hero when he is near.
	o.turn_t -= delta
	if o.turn_t <= 0.0:
		o.turn_t = _rng.randf_range(TURN_EVERY.x, TURN_EVERY.y)
		if d < LOOK_RANGE and _rng.randf() < LOOK_CHANCE:
			var to_hero := node.global_position.direction_to(hero)
			var yaw := wrapf(atan2(to_hero.x, to_hero.z) - node.rotation.y, -PI, PI)
			o.head_to = clampf(yaw, -TURN_MAX * 1.2, TURN_MAX * 1.2)
		else:
			o.head_to = _rng.randf_range(-TURN_MAX, TURN_MAX)
		o.roll_to = _rng.randf_range(-0.4, 0.4) if _rng.randf() < 0.3 else 0.0
	o.head_yaw = lerpf(o.head_yaw, o.head_to, minf(1.0, delta * 6.0))
	o.head_roll = lerpf(o.head_roll, o.roll_to, minf(1.0, delta * 5.0))
	# Blinking.
	o.blink_t -= delta
	if o.blink_t <= 0.0:
		o.blink_t = _rng.randf_range(BLINK_EVERY.x, BLINK_EVERY.y)
		o.blink = 0.14
	o.blink = maxf(0.0, o.blink - delta)
	# Hooting.
	o.hoot_t -= delta
	if o.hoot_t <= 0.0 and clock_quiet(hour):
		o.hoot_t = _rng.randf_range(3.0, 6.0)
	if o.hoot_t <= 0.0:
		var deep := hour >= 21.0 or hour < 4.0
		var gap := HOOT_NIGHT if deep else HOOT_EVERY
		o.hoot_t = _rng.randf_range(gap.x, gap.y)
		_hoot(i, o, d, covered)
	o.puff = maxf(0.0, o.puff - delta)
	# Gliding to another tree.
	o.glide_t -= delta
	if o.glide_t <= 0.0:
		o.glide_t = _rng.randf_range(GLIDE_EVERY.x, GLIDE_EVERY.y)
		if d < GLIDE_HERO:
			_start_glide(o)
	o.wing_open = lerpf(o.wing_open, 0.0, minf(1.0, delta * 6.0))
	_pose(o, 0.0)


## One owl calls: its sound (the soft short one when it answers another), a puff of its chest, and
## the nearest other owl within ANSWER_RANGE may answer a few seconds later.
func _hoot(i: int, o: Dictionary, d: float, covered: bool) -> void:
	var sound: String = ANSWER_SOUND if o.answer else SOUNDS[_rng.randi() % SOUNDS.size()]
	var answered: bool = o.answer
	o.answer = false
	o.puff_len = float(SOUND_LENGTH[sound])
	o.puff = o.puff_len
	o.head_to = _rng.randf_range(-0.5, 0.5)
	hooted.emit(i, sound)
	if d <= HEAR_RANGE:
		var db := HOOT_DB - FADE_RATE * maxf(0.0, d - FADE_FROM) + (INDOORS_DB if covered else 0.0)
		if db > -34.0 and is_inside_tree():
			Sfx.play_3d(self, sound, db, (o.node as Node3D).global_position + Vector3(0, 0.3, 0), o.pitch)
	if answered:
		return
	# Another owl answers.
	var best := -1
	var best_d := ANSWER_RANGE
	for k in owls.size():
		if k == i or k == clock_owl or owls[k].state != "perch" or owls[k].asleep:
			continue
		var dd: float = (owls[k].node as Node3D).global_position.distance_to((o.node as Node3D).global_position)
		if dd < best_d:
			best_d = dd
			best = k
	if best >= 0:
		owls[best].hoot_t = _rng.randf_range(ANSWER_AFTER.x, ANSWER_AFTER.y) + best_d / 340.0
		owls[best].answer = true


## The clock owl's hoots: one note at a time, following the pattern of OwlClock, while the hero is near on a
## full-moon night.
func _clock_tick(delta: float, hero: Vector3, hour: float, covered: bool) -> void:
	if clock_owl < 0:
		return
	var o := owls[clock_owl]
	var d := Vector2((o.node as Node3D).global_position.x - hero.x, (o.node as Node3D).global_position.z - hero.z).length()
	if not (clock_on and OwlClock.striking(hour)) or d > OwlClock.HEAR_RANGE:
		_clock_step = 0
		_clock_t = OwlClock.START_DELAY
		return
	_clock_t -= delta
	if _clock_t > 0.0:
		return
	_clock_t = OwlClock.gap_after(_clock_step)
	_clock_step = (_clock_step + 1) % OwlClock.hoots()
	o.asleep = false
	o.puff_len = OwlClock.PUFF
	o.puff = o.puff_len
	hooted.emit(clock_owl, OwlClock.SOUND)
	if is_inside_tree():
		var db := OwlClock.HOOT_DB - FADE_RATE * maxf(0.0, d - FADE_FROM) + (INDOORS_DB if covered else 0.0)
		Sfx.play_3d(self, OwlClock.SOUND, db, (o.node as Node3D).global_position + Vector3(0, 0.3, 0))


func _start_glide(o: Dictionary) -> void:
	var node: Node3D = o.node
	var here := node.global_position
	var options: Array[int] = []
	for k in perches.size():
		var p := perches[k]
		if p.taken:
			continue
		var dd := Vector2(p.pos.x - here.x, p.pos.z - here.z).length()
		if dd >= GLIDE_REACH.x and dd <= GLIDE_REACH.y:
			options.append(k)
	if options.is_empty():
		return
	var pick := options[_rng.randi() % options.size()]
	perches[o.perch].taken = false
	perches[pick].taken = true
	o.perch = pick
	o.from = here
	o.to = perches[pick].pos
	o.t = 0.0
	o.dur = Vector2(o.to.x - here.x, o.to.z - here.z).length() / GLIDE_SPEED + 0.8
	o.state = "glide"
	o.head_to = 0.0
	o.head_yaw = 0.0
	o.head_roll = 0.0
	node.rotation.y = atan2(o.to.x - here.x, o.to.z - here.z)


## The glide: silent, wings spread, a shallow dive from the branch and a swoop up to the next one.
func _glide(o: Dictionary, delta: float) -> void:
	o.t += delta / o.dur
	var s := clampf(o.t, 0.0, 1.0)
	var e := s * s * (3.0 - 2.0 * s)
	var flat: Vector3 = (o.from as Vector3).lerp(o.to, e)
	var dip := minf(2.4, Vector2(o.to.x - o.from.x, o.to.z - o.from.z).length() * 0.14)
	flat.y = lerpf(o.from.y, o.to.y, e) - sin(PI * s) * dip
	(o.node as Node3D).global_position = flat
	o.wing_open = minf(1.0, o.wing_open + delta * 7.0)
	# Two slow, soundless beats on setting off.
	o.flap = sin(s * TAU * 2.0) * 0.28 * maxf(0.0, 1.0 - s * 3.0) if s < 0.34 else 0.0
	_pose(o, cos(PI * s) * 0.45)
	if o.t >= 1.0:
		_land(o)


func _land(o: Dictionary) -> void:
	o.state = "perch"
	o.t = 0.0
	o.flap = 0.0
	(o.node as Node3D).global_position = o.to if o.to != Vector3.ZERO else (o.node as Node3D).global_position
	o.head_to = _rng.randf_range(-0.8, 0.8)
	_pose(o, 0.0)


## By day: eyes shut, head sunk, no calls.
func _doze(o: Dictionary, delta: float) -> void:
	o.asleep = true
	o.head_to = 0.0
	o.head_yaw = lerpf(o.head_yaw, 0.0, minf(1.0, delta * 4.0))
	o.head_roll = lerpf(o.head_roll, 0.0, minf(1.0, delta * 4.0))
	o.wing_open = 0.0
	o.puff = 0.0
	_pose(o, 0.0)


## Puts the parts of an owl where they belong this frame (`pitch`: nose down, radians, in flight).
func _pose(o: Dictionary, pitch: float) -> void:
	var node: Node3D = o.node
	node.rotation.x = pitch
	var head: Node3D = o.head
	var sunk: float = 1.0 if o.asleep else 0.0
	head.rotation = Vector3(0.0, o.head_yaw * (1.0 - sunk), o.head_roll * (1.0 - sunk))
	head.position = Vector3(0, 0.38 - 0.045 * sunk, 0.02 + 0.03 * sunk)
	var hooting: float = 0.0
	if o.puff > 0.0:
		# A few pulses of the chest, the head dipping and lifting with each.
		var phase: float = 1.0 - o.puff / o.puff_len
		hooting = clampf(sin(phase * PI) * (0.5 + 0.5 * sin(phase * TAU * 3.5 - 1.2)), 0.0, 1.0)
		head.rotation.x = -0.22 * hooting + 0.1
	(o.body as Node3D).scale = Vector3(1.0 + 0.06 * hooting, 1.0 + 0.04 * hooting, 1.0 + 0.1 * hooting)
	# Eyes: shut asleep or blinking, wide otherwise (a slit, not a hole).
	var open: float = 0.12 if (o.asleep or o.blink > 0.0) else 1.0
	for eye: MeshInstance3D in o.eyes:
		eye.scale = Vector3(1.0, open, 1.0)
	# Wings: folded at the sides, or spread flat in flight (long and wide).
	var spread: float = o.wing_open
	for k in 2:
		var side := -1.0 if k == 0 else 1.0
		var w: Node3D = o.wings[k]
		w.rotation = Vector3(0.0, 0.0, side * (-spread * 1.45 + 0.02 + float(o.flap)))
		w.scale = Vector3(1.0, 1.0 + 1.5 * spread, 1.0 + 0.5 * spread)


# --- Look --------------------------------------------------------------------------------------

## The feather texture, drawn once for every owl: overlapping scallops of tawny brown with dark
## shaft lines and bars, and a pale, streaked underside (the lower half of the texture).
static func feather_texture() -> ImageTexture:
	if _texture != null:
		return _texture
	var size := 256
	var img := Image.create(size, size, true, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = 5
	noise.frequency = 0.09
	var fine := FastNoiseLite.new()
	fine.seed = 9
	fine.frequency = 0.35
	var rows := 14.0
	var cols := 18.0
	for y in size:
		for x in size:
			var u := float(x) / size
			var v := float(y) / size
			var row := floorf(v * rows)
			var uu := u * cols + (0.5 if int(row) % 2 == 1 else 0.0)
			var cell := Vector2(fposmod(uu, 1.0) - 0.5, fposmod(v * rows, 1.0))
			# A scallop: the feather's rounded tip is darker at its edge, its shaft a thin line down the middle.
			var edge := smoothstep(0.55, 0.95, cell.y + absf(cell.x) * 0.5)
			var shaft := 1.0 - smoothstep(0.0, 0.06, absf(cell.x))
			var base := Color(0.47, 0.33, 0.21).lerp(Color(0.62, 0.47, 0.31), noise.get_noise_2d(x, y) * 0.5 + 0.5)
			var dark := Color(0.2, 0.13, 0.09)
			var c := base.lerp(dark, edge * 0.55 + shaft * 0.3)
			# Bars across the feathers: every third row darker.
			if int(row) % 3 == 0:
				c = c.lerp(dark, 0.25)
			c = c * (0.9 + fine.get_noise_2d(x, y) * 0.18)
			# The underside (the bottom of the picture): pale buff with dark streaks down it.
			var belly := smoothstep(0.55, 0.8, v)
			var streak := smoothstep(0.62, 0.9, absf(sin(u * TAU * 11.0 + noise.get_noise_2d(x, y * 0.3) * 3.0)))
			var pale := Color(0.84, 0.74, 0.58).lerp(Color(0.3, 0.2, 0.13), streak * 0.65)
			pale = pale * (0.92 + fine.get_noise_2d(x * 1.7, y) * 0.14)
			img.set_pixel(x, y, c.lerp(pale, belly))
	img.generate_mipmaps()
	_texture = ImageTexture.create_from_image(img)
	return _texture


static func bark_texture() -> ImageTexture:
	if _bark != null:
		return _bark
	var img := Image.create(64, 128, true, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = 3
	noise.frequency = 0.05
	for y in 128:
		for x in 64:
			# Long furrows along the branch.
			var f := noise.get_noise_2d(x * 3.0, y * 0.25) * 0.5 + 0.5
			var c := Color(0.2, 0.15, 0.11).lerp(Color(0.42, 0.33, 0.25), f)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	_bark = ImageTexture.create_from_image(img)
	return _bark


static func _material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = feather_texture()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = Graphics.vertex_colours_srgb()
	m.roughness = 0.95
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func _eye_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = Graphics.vertex_colours_srgb()
	m.roughness = 0.1
	m.metallic_specular = 0.9
	m.emission_enabled = true
	m.emission = Color(0.9, 0.5, 0.1)
	m.emission_energy_multiplier = 0.12
	return m


## An ellipsoid with the feather texture's UVs: `v0` to `v1` is the stretch of the picture it
## covers (the top of the picture is the back, the bottom the pale underside).
static func _ellipsoid(st: SurfaceTool, centre: Vector3, radii: Vector3, tint: Callable, rings := 12, segments := 16, v0 := 0.0, v1 := 1.0) -> void:
	var at := func(r: int, s: int) -> Array:
		var lat := PI * r / rings - PI * 0.5
		var lon := TAU * s / segments
		var d := Vector3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon))
		# The picture runs from the belly (bottom, lat -90) to the back (top).
		return [d, Vector2(float(s) / segments * 2.0, lerpf(v1, v0, float(r) / rings))]
	for r in rings:
		for s in segments:
			var quad := [at.call(r, s), at.call(r + 1, s), at.call(r + 1, s + 1), at.call(r, s + 1)]
			for k: int in [0, 1, 2, 0, 2, 3]:
				var d: Vector3 = quad[k][0]
				st.set_color(tint.call(d))
				st.set_uv(quad[k][1])
				st.add_vertex(centre + d * radii)


## The body: an upright plump ellipsoid, a fan tail below and behind, and the feet.
static func body_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var back := func(d: Vector3) -> Color: return Color(1.0, 1.0, 1.0).lerp(Color(0.8, 0.78, 0.74), clampf(d.z * -0.5, 0.0, 1.0))
	_ellipsoid(st, Vector3(0, 0.21, 0), Vector3(0.135, 0.2, 0.125), back, 14, 18, 0.0, 1.0)
	# The tail: a long, flat fan of feathers hanging behind and below, barred.
	var tail := func(_d: Vector3) -> Color: return Color(0.85, 0.8, 0.74)
	_ellipsoid(st, Vector3(0, 0.07, -0.14), Vector3(0.06, 0.012, 0.15), tail, 5, 10, 0.0, 0.5)
	# Feet: small yellow-grey blobs gripping the branch.
	var foot := func(_d: Vector3) -> Color: return Color(0.55, 0.5, 0.4)
	for side: float in [-1.0, 1.0]:
		_ellipsoid(st, Vector3(side * 0.05, 0.02, 0.025), Vector3(0.028, 0.02, 0.045), foot, 4, 6, 0.2, 0.3)
		for toe: float in [-1.0, 0.0, 1.0]:
			_ellipsoid(st, Vector3(side * 0.05 + toe * 0.016, 0.012, 0.075), Vector3(0.009, 0.009, 0.026), foot, 3, 5, 0.2, 0.3)
	st.generate_normals()
	return st.commit()


## The head (its neck at the origin): a broad, round head with the pale heart-shaped face disc
## ringed in dark, and a short hooked beak.
static func head_mesh_of() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var crown := func(d: Vector3) -> Color: return Color(1.0, 0.97, 0.92)
	_ellipsoid(st, Vector3.ZERO, Vector3(0.125, 0.105, 0.11), crown, 12, 16, 0.0, 0.55)
	# The face disc: two flattened pale ovals, with a dark rim round each (a slightly bigger, darker oval behind).
	var rim := func(_d: Vector3) -> Color: return Color(0.5, 0.4, 0.32)
	var disc := func(_d: Vector3) -> Color: return Color(0.95, 0.88, 0.8)
	for side: float in [-1.0, 1.0]:
		_ellipsoid(st, Vector3(side * 0.05, 0.0, 0.07), Vector3(0.056, 0.07, 0.04), rim, 8, 12, 0.3, 0.45)
		_ellipsoid(st, Vector3(side * 0.05, 0.0, 0.077), Vector3(0.05, 0.063, 0.036), disc, 8, 12, 0.7, 0.85)
	# The beak: a short pale cone, hooked down, between the eyes.
	var beak := func(_d: Vector3) -> Color: return Color(1.2, 1.1, 0.8)
	_ellipsoid(st, Vector3(0, -0.028, 0.112), Vector3(0.016, 0.03, 0.026), beak, 5, 8, 0.75, 0.85)
	st.generate_normals()
	return st.commit()


static func eye_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# An amber iris with a big black pupil in front of it.
	_ellipsoid(st, Vector3.ZERO, Vector3(0.032, 0.034, 0.022), func(_d: Vector3) -> Color: return Color(0.95, 0.6, 0.12), 8, 12, 0.0, 0.1)
	_ellipsoid(st, Vector3(0, 0, 0.012), Vector3(0.022, 0.024, 0.016), func(_d: Vector3) -> Color: return Color(0.02, 0.02, 0.02), 8, 12, 0.0, 0.1)
	st.generate_normals()
	return st.commit()


## A folded wing (hanging from its shoulder at the origin): a long, flat blade of dark, barred feathers.
static func wing_mesh(side: float) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dark := func(d: Vector3) -> Color: return Color(0.78, 0.74, 0.7).lerp(Color(1.0, 0.95, 0.88), clampf(d.y * 0.4 + 0.2, 0.0, 1.0))
	_ellipsoid(st, Vector3(side * 0.02, -0.13, -0.025), Vector3(0.03, 0.17, 0.075), dark, 8, 12, 0.0, 0.5)
	st.generate_normals()
	return st.commit()


## A branch from the trunk at `from` out to `to`: a tapered, furrowed limb.
static func _branch(from: Vector3, to: Vector3) -> MeshInstance3D:
	var length := from.distance_to(to)
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.035
	cyl.bottom_radius = 0.08
	cyl.height = length + 0.3
	cyl.radial_segments = 8
	var m := MeshInstance3D.new()
	m.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = bark_texture()
	mat.roughness = 1.0
	mat.uv1_scale = Vector3(1.0, 2.0, 1.0)
	m.material_override = mat
	m.name = "Branch"
	# The perch is the owl's feet: the branch lies just under them.
	var mid := from.lerp(to, 0.5)
	m.position = mid - Vector3(0, 0.03, 0) - (to - from).normalized() * 0.0
	# The cylinder stands along Y: lay it along the branch's direction, its thick end at the trunk.
	var dir := (from - to).normalized()
	var axis := Vector3.UP.cross(dir)
	if axis.length() > 0.001:
		m.basis = Basis(axis.normalized(), Vector3.UP.angle_to(dir))
	return m
