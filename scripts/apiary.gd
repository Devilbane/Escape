class_name Apiary
extends Node3D
## The apiary of the farming valley: the bee hives (map letter HIVE, two to a tile: a straw skep and a painted
## box hive, see HiveModels), the wild flowers of the bees' meadow round them, and the bees.
##
## The bees are ambient life, not enemies. In spring and summer, on a day that is not wet, from the morning to the
## evening they come out of the hives, circle in front of them, fly to a flower of the meadow, sit on it for a while,
## and carry on home, where they slip in at the entrance for a moment (see _step). Each hive hums while it is
## awake, a soft buzz heard from the hive's own side (see buzz_stream). At night, in autumn and winter, in rain
## and snow the bees stay in their hives and the meadow is bare or in bloom with them (see set_season).
##
## A hero who stands right at a hive for a moment (VEXED_AFTER seconds within VEXED_RANGE) disturbs it: the
## bees of the hive and its neighbours swarm round the hero for ANGRY_TIME seconds, and if the hero does
## not step away, one bee stings once (STING). The hive then lets the hero be for CALM_TIME seconds. Nothing more:
## no fight, no chase. The beekeeper (see Beekeeper) works among the hives all day and is never stung.
##
## Everything is cheap: the bees only exist as nodes while the hero is near (ACTIVE_RANGE), and they are hidden
## when they do not fly. Tested by tests/bees.gd and tests/beekeeper.gd.

## The map letter of a hive tile: a skep and a box hive side by side.
const HIVE := "ħ"
## The bees of each hive, and how far from the hero the apiary wakes up (metres).
const BEES_PER_HIVE := 9
const ACTIVE_RANGE := 46.0
## When the bees fly: from this hour to that, in these seasons, unless the weather is one of WET.
const FLY_FROM := 7.0
const FLY_TO := 19.5
const SEASONS := ["spring", "summer"]
const WET := ["rain", "storm", "snow"]
## How fast a bee flies, how long it sits on a flower and how long it stays inside (seconds, from and to).
const SPEED := 2.4
const FEED_TIME := Vector2(3.0, 7.0)
const INSIDE_TIME := Vector2(2.0, 5.0)
const CIRCLE_TIME := Vector2(2.5, 6.0)
## How near the hero stands to vex a hive, for how long, and what follows.
const VEXED_RANGE := 2.0
const VEXED_AFTER := 1.2
const ANGRY_TIME := 7.0
const STING_AFTER := 2.2
const CALM_TIME := 35.0
## The hero is only stung with this much life left, and stays at least this far from a hive when it is over.
const STING_MIN_HP := 4
const STING := 1
## The hum: how far it carries (metres), how loud it is at a hive and how much louder it is when the bees are vexed.
const HEARD := 30.0
const HUM_DB := -19.0
const ANGRY_DB := 4.0
## Where the hive's bees fly in and out, in front of it (metres).
const FRONT := 0.4
const LEARN := "Bienen: Im Frühling und Sommer fliegen sie von Blüte zu Blüte und summen vor ihren Stöcken. Wer sich an einen Stock stellt, ärgert sie: Sie schwärmen um den Kopf und stechen einmal. Ein Schritt zurück, und sie lassen dich in Ruhe. Honig bekommst du vom Imker im Tal."
const VEXED := "Die Bienen sind aufgebracht! Geh einen Schritt zurück."
const STUNG := "Au! Ein Bienenstich."

var level: Outdoor
var hives: Array[Dictionary] = []
## The head of every flower, where a bee lands (world positions, in the bloom of summer).
var flowers: Array[Vector3] = []
var _cells: Array[Vector2i] = []
var _beds: Array[Dictionary] = []
var _season := ""
var _bees: Array[Dictionary] = []
var _bees_root: Node3D
var _rng := RandomNumberGenerator.new()
var _clock := 0.0
var _awake := false
var _near_hum: AudioStreamPlayer3D
static var _buzz: AudioStreamWAV


func _init(of_level: Outdoor = null, hive_cells: Array[Vector2i] = [], seed_text := "") -> void:
	name = "Apiary"
	level = of_level
	_cells = hive_cells
	_rng.seed = hash(seed_text + "bienen")


func _ready() -> void:
	for c in _cells:
		_place_hives(c)
	_sow_meadow()
	_bees_root = Node3D.new()
	_bees_root.name = "Bees"
	add_child(_bees_root)
	for i in hives.size():
		for _k in BEES_PER_HIVE:
			_add_bee(i)
	_bees_root.visible = false


# --- The hives -----------------------------------------------------------------------------

## A skep and a box hive on the tile `c`, with the tile blocked where they stand.
func _place_hives(c: Vector2i) -> void:
	var mid := level.cell_to_world(c)
	var skep_first := (c.x + c.y) % 2 == 0
	# The hives sit at the tile's south edge, so their entrances look out over the next tile, where one can stand.
	var spots := [Vector3(-0.95, 0, 1.12), Vector3(0.95, 0, 1.05)]
	var number := absi(hash(c))
	for i in 2:
		var is_skep := (i == 0) == skep_first
		var model := HiveModels.skep() if is_skep else HiveModels.box_hive(number + i)
		model.name = "Hive%d_%d_%d" % [c.x, c.y, i]
		model.position = mid + spots[i]
		model.rotation.y = _rng.randf_range(-0.2, 0.2)
		add_child(model)
		var front := Vector3(0, 0, 1).rotated(Vector3.UP, model.rotation.y)
		hives.append({"pos": model.position, "front": front, "node": model, "skep": is_skep, "cell": c,
				"gate": model.position + front * FRONT + Vector3(0, 0.46 if is_skep else 0.36, 0),
				"near": 0.0, "calm": 0.0, "angry": 0.0, "stung": false, "hum": null})
	level._add_solid(mid + Vector3(0, 0, 1.1), Vector3(3.0, 1.3, 1.1))


## The number of hives (two to a tile).
func hive_count() -> int:
	return hives.size()


## The nearest hive's distance to a spot, on the ground (INF without hives).
func distance_to(at: Vector3) -> float:
	var best := INF
	for h in hives:
		best = minf(best, Vector2(h.pos.x - at.x, h.pos.z - at.z).length())
	return best


# --- The meadow ----------------------------------------------------------------------------

## The wild flowers round the hives: patches on the open grass within three tiles, in five colours and lavender.
func _sow_meadow() -> void:
	var seen := {}
	var kinds := {}
	for c in _cells:
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var near := c + Vector2i(dx, dy)
				if seen.has(near):
					continue
				seen[near] = true
				if level.cell_char(near) != "." or not level.is_open(near) or level._in_village(near):
					continue
				if _rng.randf() > 0.72:
					continue
				var mid := level.cell_to_world(near)
				# A patch is mostly one colour, with a few of another.
				var main := _rng.randi() % (HiveModels.FLOWER_COLOURS.size() + 1)
				for _f in 20:
					var pick := main if _rng.randf() < 0.8 else _rng.randi() % (HiveModels.FLOWER_COLOURS.size() + 1)
					var at := mid + Vector3(_rng.randf_range(-1.7, 1.7), 0, _rng.randf_range(-1.7, 1.7))
					# Not on a path or against a hive.
					if level.cell_char(level.world_to_cell(at)) != "." or distance_to(at) < 0.9:
						continue
					if not kinds.has(pick):
						kinds[pick] = []
					kinds[pick].append([at, _rng.randf() * TAU, _rng.randf_range(1.2, 1.7)])
	for pick: int in kinds:
		var spike := pick >= HiveModels.FLOWER_COLOURS.size()
		var petal: Color = HiveModels.LAVENDER if spike else HiveModels.FLOWER_COLOURS[pick]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = HiveModels.flower_mesh(petal, spike)
		mm.instance_count = kinds[pick].size()
		var inst := MultiMeshInstance3D.new()
		inst.name = "Flowers%d" % pick
		inst.multimesh = mm
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(inst)
		_beds.append({"mm": mm, "node": inst, "spots": kinds[pick], "spike": spike})
		for s: Array in kinds[pick]:
			flowers.append(s[0] + Vector3(0, HiveModels.flower_head(spike) * s[2], 0))


## How many flowers bloom in the meadow.
func flower_count() -> int:
	return flowers.size()


## Dresses the meadow for season day `day` (see Weather.season): half grown in spring, in full bloom in summer,
## gone in autumn and winter.
func set_season(day: int) -> void:
	var season := Weather.season(day)
	if season == _season:
		return
	_season = season
	var grown := 0.75 if season == "spring" else 1.0
	for bed in _beds:
		bed.node.visible = season in SEASONS
		var spots: Array = bed.spots
		for i in spots.size():
			var s: Array = spots[i]
			var basis := Basis(Vector3.UP, s[1]).scaled(Vector3.ONE * float(s[2]) * grown)
			(bed.mm as MultiMesh).set_instance_transform(i, Transform3D(basis, s[0]))


## The season the meadow is dressed for ("" before the first set_season).
func season() -> String:
	return _season


# --- The bees ------------------------------------------------------------------------------

## Whether bees fly at an hour, in a season, in a weather.
static func flying_now(hour: float, season_name: String, weather: String) -> bool:
	return season_name in SEASONS and hour >= FLY_FROM and hour < FLY_TO and not weather in WET


func _add_bee(hive: int) -> void:
	var node := HiveModels.bee()
	_bees_root.add_child(node)
	var gate: Vector3 = hives[hive].gate
	node.position = gate
	_bees.append({"node": node, "hive": hive, "state": "inside", "t": _rng.randf_range(0.2, 4.0), "angle": _rng.randf() * TAU,
			"radius": _rng.randf_range(0.45, 1.1), "dir": 1.0 if _rng.randf() < 0.5 else -1.0, "phase": _rng.randf() * TAU,
			"target": gate, "pos": gate})
	node.visible = false


## How many bees there are, and how many are out in the open.
func bee_count() -> int:
	return _bees.size()


func bees_out() -> int:
	return _bees.filter(func(b: Dictionary) -> bool: return b.state != "inside").size()


## How many of the bees are in the state (for the test): "inside", "orbit", "go", "feed", "back" or "swarm".
func bees_in(state: String) -> int:
	return _bees.filter(func(b: Dictionary) -> bool: return b.state == state).size()


## The bees now: hidden, or out. Moves each bee and keeps the hum going. `indoors` is the hero inside a house.
func tick(delta: float, hero: Vector3, hour: float, indoors: bool, season_day: int, weather: String) -> void:
	set_season(season_day)
	_clock += delta
	var near := distance_to(hero) < ACTIVE_RANGE and not indoors
	var flying := flying_now(hour, _season, weather)
	_awake = near and flying
	if _bees_root != null:
		_bees_root.visible = _awake
	if not _awake:
		for h in hives:
			_hum(h, hero, false)
		return
	for h in hives:
		_vex(h, hero, delta)
	for b in _bees:
		_step(b, delta, hero)
	for i in hives.size():
		_hum(hives[i], hero, true)
	_near_buzz(hero)


func _step(b: Dictionary, delta: float, hero: Vector3) -> void:
	var node: Node3D = b.node
	var hive: Dictionary = hives[b.hive]
	var gate: Vector3 = hive.gate
	var before := node.position
	b.t -= delta
	match b.state:
		"inside":
			node.visible = false
			if b.t <= 0.0:
				node.position = gate
				node.visible = true
				_circle(b)
		"orbit":
			b.angle += b.dir * delta * 2.4
			var want: Vector3 = gate + Vector3(cos(b.angle), 0.1 + 0.18 * sin(b.angle * 2.0), sin(b.angle)) * b.radius
			node.position = node.position.lerp(want, minf(1.0, 5.0 * delta))
			if b.t <= 0.0:
				if not flowers.is_empty() and _rng.randf() < 0.85:
					b.target = flowers[_rng.randi() % flowers.size()] + Vector3(0, 0.05, 0)
					b.state = "go"
				else:
					b.state = "back"
		"go":
			if _fly(b, node, b.target, delta):
				b.state = "feed"
				b.t = _rng.randf_range(FEED_TIME.x, FEED_TIME.y)
		"feed":
			var t: float = _clock * 3.0 + b.phase
			var want: Vector3 = b.target + Vector3(cos(t) * 0.035, 0.05 + sin(t * 1.7) * 0.02, sin(t) * 0.035)
			node.position = node.position.lerp(want, minf(1.0, 6.0 * delta))
			if b.t <= 0.0:
				b.state = "back"
		"back":
			if _fly(b, node, gate, delta):
				if _rng.randf() < 0.6:
					b.state = "inside"
					b.t = _rng.randf_range(INSIDE_TIME.x, INSIDE_TIME.y)
				else:
					_circle(b)
		"swarm":
			b.angle += b.dir * delta * 5.5
			var want: Vector3 = hero + Vector3(cos(b.angle), 1.15 + 0.4 * sin(b.angle * 1.7 + b.phase), sin(b.angle)) * (b.radius + 0.5)
			node.position = node.position.lerp(want, minf(1.0, 7.0 * delta))
			if b.t <= 0.0:
				b.state = "back"
	# Turn the way the bee goes, and beat the wings.
	var moved: Vector3 = node.position - before
	if moved.length() > 0.2 * delta and delta > 0.0:
		var to := Transform3D().looking_at(moved.normalized(), Vector3.UP).basis
		node.basis = node.basis.slerp(to, minf(1.0, 12.0 * delta)).orthonormalized()
	var beat := sin((_clock + b.phase) * TAU * 26.0) * 0.8
	(node.get_node("WingL") as Node3D).rotation.z = -beat - 0.3
	(node.get_node("WingR") as Node3D).rotation.z = beat + 0.3


func _circle(b: Dictionary) -> void:
	b.state = "orbit"
	b.t = _rng.randf_range(CIRCLE_TIME.x, CIRCLE_TIME.y)
	b.radius = _rng.randf_range(0.45, 1.1)


## Flies a bee towards a spot, with a little wobble; true once it is there.
func _fly(b: Dictionary, node: Node3D, to: Vector3, delta: float) -> bool:
	var away := to - node.position
	if away.length() < 0.12:
		return true
	var wobble := Vector3(sin(_clock * 7.0 + b.phase), sin(_clock * 9.0 + b.phase * 2.0) * 0.6, cos(_clock * 6.0 + b.phase)) * 0.25
	node.position += (away.normalized() + wobble * 0.5).normalized() * SPEED * delta
	return false


# --- The hum and the vexed hive -------------------------------------------------------------

## A looping buzz: a wing beat of 230 Hz with a wavering pitch and a flutter, softened.
static func buzz_stream() -> AudioStreamWAV:
	if _buzz != null:
		return _buzz
	var rate := 22050
	var n := rate
	var f0 := 120.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t := float(i) / rate
		var phase := TAU * (f0 * t - (0.05 * f0 / (TAU * 3.0)) * cos(TAU * 3.0 * t))
		var v := 0.0
		for k in range(1, 4):
			v += sin(phase * k + k * 0.7) / pow(k, 1.6)
		v *= 0.8 + 0.2 * sin(TAU * 11.0 * t)
		v += rng.randf_range(-0.12, 0.12)
		samples[i] = v
	# Two passes of a gentle low pass, the second one kept, so the loop closes without a click.
	var out := PackedByteArray()
	out.resize(n * 2)
	var state := 0.0
	var peak := 0.0
	var smooth := PackedFloat32Array()
	smooth.resize(n)
	for pass_no in 2:
		for i in n:
			state += (samples[i] - state) * 0.16
			smooth[i] = state
	for i in n:
		peak = maxf(peak, absf(smooth[i]))
	for i in n:
		out.encode_s16(i * 2, int(clampf(smooth[i] / peak * 0.55, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	wav.data = out
	_buzz = wav
	return wav


## The hum of a hive: heard from its own side while the bees fly, softer with every metre, silent beyond HEARD.
func _hum(h: Dictionary, hero: Vector3, on: bool) -> void:
	var player: AudioStreamPlayer3D = h.hum
	var d := Vector2(h.pos.x - hero.x, h.pos.z - hero.z).length()
	if not on or d > HEARD or not is_inside_tree():
		if player != null and player.playing:
			player.stop()
		return
	if player == null:
		player = AudioStreamPlayer3D.new()
		player.stream = buzz_stream()
		player.bus = Sfx.BUS
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		player.panning_strength = 1.5
		player.name = "Hum"
		add_child(player)
		h.hum = player
	player.global_position = h.gate
	var angry: bool = h.angry > 0.0
	player.volume_db = HUM_DB - 24.0 * clampf((d - 2.0) / (HEARD - 2.0), 0.0, 1.0) + (ANGRY_DB if angry else 0.0)
	player.pitch_scale = 1.1 if angry else 1.0
	if not player.playing:
		player.play(_rng.randf() * 0.9)


## The bee nearest the hero buzzes on its own, so one passing by is heard going past: its hum follows it and
## swells as it comes close.
func _near_buzz(hero: Vector3) -> void:
	var best: Node3D = null
	var best_d := 9.0
	for b in _bees:
		var node: Node3D = b.node
		if not node.visible:
			continue
		var d := node.position.distance_to(hero + Vector3(0, 1.0, 0))
		if d < best_d:
			best_d = d
			best = node
	if best == null:
		if _near_hum != null and _near_hum.playing:
			_near_hum.stop()
		return
	if _near_hum == null:
		_near_hum = AudioStreamPlayer3D.new()
		_near_hum.stream = buzz_stream()
		_near_hum.bus = Sfx.BUS
		_near_hum.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		_near_hum.panning_strength = 1.5
		_near_hum.name = "NearHum"
		add_child(_near_hum)
	_near_hum.global_position = best.position
	_near_hum.volume_db = -14.0 - 18.0 * best_d / 9.0
	_near_hum.pitch_scale = 1.0
	if not _near_hum.playing:
		_near_hum.play(_rng.randf() * 0.9)


## A hero who stands at a hive disturbs it (see the top): the bees swarm round, and one may sting.
func _vex(h: Dictionary, hero: Vector3, delta: float) -> void:
	h.calm = maxf(0.0, h.calm - delta)
	if h.angry > 0.0:
		h.angry -= delta
		if not h.stung and h.angry < ANGRY_TIME - STING_AFTER and distance_to(hero) < 4.0:
			h.stung = true
			_sting(h)
		return
	var d := Vector2(h.pos.x - hero.x, h.pos.z - hero.z).length()
	if d < VEXED_RANGE and h.calm <= 0.0:
		h.near += delta
		if h.near >= VEXED_AFTER:
			_vexed(h)
	else:
		h.near = maxf(0.0, h.near - delta)


## Sets the bees of a hive and the hives within five metres of it on the hero.
func vex(hive: int) -> void:
	_vexed(hives[hive])


func _vexed(h: Dictionary) -> void:
	h.near = 0.0
	h.calm = CALM_TIME
	h.angry = ANGRY_TIME
	h.stung = false
	for b in _bees:
		var other: Dictionary = hives[b.hive]
		if other == h or Vector2(other.pos.x - h.pos.x, other.pos.z - h.pos.z).length() < 5.0:
			b.state = "swarm"
			b.t = ANGRY_TIME
			b.node.visible = true
			b.node.position = other.gate
	Events.teach(LEARN)
	Events.tell(Lang.t(VEXED), Color(1.0, 0.85, 0.3))


## Whether any hive is vexed now.
func vexed() -> bool:
	return hives.any(func(h: Dictionary) -> bool: return h.angry > 0.0)


func _sting(h: Dictionary) -> void:
	if level == null or level.player == null:
		return
	var hero: Player = level.player
	if hero.dead or hero.hp < STING_MIN_HP:
		return
	hero.take_damage(STING, h.pos, null, false)
	Events.tell(Lang.t(STUNG), Color(1.0, 0.7, 0.3))
