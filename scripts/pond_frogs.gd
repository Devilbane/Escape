class_name PondFrogs
extends Node3D
## Now and then a frog at the water: sitting on the bank among the reeds, hopping along it, or swimming in the
## pond or river (see FrogModel for its look). Only a few live on each body of water and none on many, they
## are not everywhere.
##
## * By day a frog mostly sits and croaks rarely; from dusk through the night it calls often, and its
##   neighbours answer. In autumn it calls less. In winter (and while the water is frozen) the frogs
##   hibernate in the mud: nothing is seen or heard.
## * A frog sitting on the bank hops to another spot or into the water every now and then, swims about
##   near its spot (kicking its legs), and hops out again. If the hero comes close it leaps into the water.
## * The croak is positional (see Sfx.play_3d): it comes from the side the frog is on and fades with the
##   distance from the hero.
##
## It costs next to nothing, like the river fish (see IceFish): only the frogs within ACTIVE_RANGE of the hero
## are shown and moved, the others are hidden and paused. The frogs are moved every frame, not in physics
## ticks, so they stay uninterpolated (see CLAUDE.md, "Smooth motion").

const MAX_FROGS := 12
## A body of water with fewer tiles than BIG_BODY has one frog (at most), a bigger one two, one with more than
## HUGE_BODY three. A small body has a frog with this chance, so not every pond has one.
const BIG_BODY := 60
const HUGE_BODY := 160
const SMALL_CHANCE := 0.75
## The least distance between two frogs' homes (metres).
const SPACING := 11.0
## Frogs farther from the hero than this metres are hidden and paused.
const ACTIVE_RANGE := 40.0
## A frog sits where the ground draws the bank between these distances (see Outdoor.pond_shore_at; minus is
## dry land) and swims where the water is deeper than SWIM_SHORE.
const BANK_NEAR := -0.35
const BANK_FAR := -1.0
const SWIM_SHORE := 0.55
## The frog's length in metres (its model is about a unit long), and how far it varies.
const LENGTH := 0.2
const LENGTH_SPREAD := 0.25
## How far a swimming frog sinks (metres): the ground hides what lies under the water level.
const SINK := 0.05
## The hero this close (metres, half of it when sneaking) sends a sitting frog into the water.
const SHY := 3.2
## How far a frog goes from its home spot while swimming (metres).
const ROAM := 3.5
## Seconds a frog sits and swims between its moves.
const SIT_TIME := Vector2(3.0, 11.0)
const SWIM_TIME := Vector2(8.0, 20.0)
## Seconds between croaks by day, at dusk or dawn and at night (see croak_interval).
const CROAK_DAY := Vector2(28.0, 70.0)
const CROAK_DUSK := Vector2(11.0, 26.0)
const CROAK_NIGHT := Vector2(4.0, 12.0)
## The croak sounds (assets/sounds/frog_N.ogg), their lengths in seconds and how many throat swells each has.
const CROAKS := 7
const CROAK_LENGTH := [1.0, 1.26, 0.59, 1.21, 0.78, 0.76, 0.19]
const CROAK_PULSES := [3, 3, 2, 3, 2, 2, 1]
## The croak's loudness (dB) next to the hero, and how far it carries (metres from the hero).
const CROAK_VOLUME := -9.0
const CROAK_RANGE := 26.0
## The ice from which the frogs have gone under.
const FROZEN_FROM := 0.15
## The hips of the model's hind legs, in its own units (see FrogModel.leg_mesh), and the vocal sac's spot.
const HIP := Vector3(0.27, 0.22, -0.3)
const SAC_AT := Vector3(0, 0.2, 0.4)

var level: Outdoor
var _frogs: Array[Dictionary] = []
## How far from the hero frogs are active (see ACTIVE_RANGE); the test changes it.
var active_range := ACTIVE_RANGE
var _since_check := 0.0
var _rng := RandomNumberGenerator.new()
var _asleep := false
var _ice := 0.0


## Puts frogs on the banks of the water of `ponds` (the pond and river tiles of the map, see
## Outdoor._pond_waters). Needs the level's shore map, so it builds on the first idle frame.
static func grow(lvl: Outdoor, ponds: Array) -> PondFrogs:
	var frogs := PondFrogs.new()
	frogs.name = "PondFrogs"
	frogs.level = lvl
	lvl.add_child(frogs)
	frogs._build.call_deferred(ponds)
	return frogs


## A frog of skin tint `variant` (see FrogModel.VARIANTS), one metre long, sitting at the origin facing +z: a
## node "Rig" with the "Body", the hind legs "LegL" and "LegR" and the vocal "Sac".
static func make_frog(variant: int) -> Node3D:
	var holder := Node3D.new()
	var rig := Node3D.new()
	rig.name = "Rig"
	holder.add_child(rig)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = FrogModel.body_mesh()
	rig.add_child(body)
	for side in [1, -1]:
		var leg := MeshInstance3D.new()
		leg.name = "LegL" if side == 1 else "LegR"
		leg.mesh = FrogModel.leg_mesh(side)
		leg.position = Vector3(HIP.x * side, HIP.y, HIP.z)
		rig.add_child(leg)
	var sac := MeshInstance3D.new()
	sac.name = "Sac"
	sac.mesh = FrogModel.sac_mesh()
	sac.position = SAC_AT
	sac.scale = Vector3.ONE * 0.3
	rig.add_child(sac)
	if variant != 0:
		var skin := FrogModel.skin_material(variant)
		body.set_surface_override_material(0, skin)
		for n in ["LegL", "LegR", "Sac"]:
			(rig.get_node(n) as MeshInstance3D).material_override = skin
	for mi in holder.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return holder


func _build(ponds: Array) -> void:
	if level == null or not is_inside_tree():
		return
	_rng.seed = hash(level.level_name + "froesche")
	# Group the tiles into bodies of water.
	var by_cell := {}
	for w: Dictionary in ponds:
		by_cell[w.cell] = w
	var seen := {}
	var homes: Array[Vector3] = []
	for w: Dictionary in ponds:
		if seen.has(w.cell):
			continue
		var body: Array[Dictionary] = []
		var todo: Array = [w.cell]
		seen[w.cell] = true
		while not todo.is_empty():
			var c: Vector2i = todo.pop_back()
			body.append(by_cell[c])
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if by_cell.has(c + d) and not seen.has(c + d):
					seen[c + d] = true
					todo.append(c + d)
		if _frogs.size() >= MAX_FROGS:
			break
		var want := 3 if body.size() > HUGE_BODY else (2 if body.size() > BIG_BODY else 1)
		if body.size() <= BIG_BODY and _rng.randf() > SMALL_CHANCE:
			continue
		var banks := _banks_of(body)
		if banks.is_empty():
			continue
		_shuffle(banks)
		var placed := 0
		for spot: Vector3 in banks:
			if placed >= want or _frogs.size() >= MAX_FROGS:
				break
			if _too_close(homes, spot):
				continue
			homes.append(spot)
			placed += 1
			_add_frog(spot, banks)
	_wake_near()
	set_process(not _frogs.is_empty())


static func _too_close(homes: Array[Vector3], spot: Vector3) -> bool:
	for h in homes:
		if Vector2(h.x - spot.x, h.z - spot.z).length() < SPACING:
			return true
	return false


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


## Dry spots on the bank of the water tiles `body`: open grass between BANK_FAR and BANK_NEAR from the water.
func _banks_of(body: Array[Dictionary]) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for w: Dictionary in body:
		var centre: Vector3 = w.pos
		for k in 16:
			var a := TAU * float(k) / 16.0
			for r: float in [Level.TILE * 0.5 + 0.5, Level.TILE * 0.5 + 0.9, Level.TILE * 0.5 + 1.3]:
				var p: Vector3 = centre + Vector3(cos(a), 0, sin(a)) * r
				p.y = 0.0
				if _is_bank(p):
					out.append(p)
	return out


func _is_bank(p: Vector3) -> bool:
	var shore := level.pond_shore_at(p)
	if shore > BANK_NEAR or shore < BANK_FAR:
		return false
	var cell := level.world_to_cell(p)
	return level.is_open(cell) and level.cell_char(cell) == "."


func _add_frog(spot: Vector3, banks: Array[Vector3]) -> void:
	var variant := _rng.randi() % FrogModel.VARIANTS.size()
	var holder := make_frog(variant)
	var length := LENGTH * _rng.randf_range(1.0 - LENGTH_SPREAD, 1.0 + LENGTH_SPREAD)
	var rig := holder.get_node("Rig") as Node3D
	rig.scale = Vector3.ONE * length
	add_child(holder)
	var near: Array[Vector3] = []
	for b in banks:
		if Vector2(b.x - spot.x, b.z - spot.z).length() < 6.0:
			near.append(b)
	var f := {"node": holder, "rig": rig, "size": length, "legl": rig.get_node("LegL"), "legr": rig.get_node("LegR"),
			"sac": rig.get_node("Sac"), "banks": near, "pos": spot, "heading": _rng.randf() * TAU, "state": "sit",
			"wait": _rng.randf_range(0.0, SIT_TIME.y), "t": 0.0, "from": spot, "to": spot, "dur": 1.0, "hop_h": 0.2,
			"croak_in": _rng.randf_range(2.0, 20.0), "croak_t": -1.0, "croak_len": 1.0, "pulses": 2,
			"kick": _rng.randf() * 3.0, "pitch": _rng.randf_range(0.82, 1.22), "awake": true, "target": spot,
			"scare": 0.0, "breath": _rng.randf() * TAU, "leaving": false, "into_water": false}
	holder.position = spot
	holder.rotation.y = f.heading
	# About a third start in the water.
	if _rng.randf() < 0.35:
		var water := _water_near(spot)
		if water != Vector3.INF:
			f.state = "swim"
			f.pos = water
			f.target = water
			f.wait = _rng.randf_range(0.0, SWIM_TIME.y)
			holder.position = _lowered(water, f)
	_frogs.append(f)


## A spot of open water (deeper than SWIM_SHORE) within a hop of `from`, or Vector3.INF.
func _water_near(from: Vector3) -> Vector3:
	var start := _rng.randf() * TAU
	for r: float in [0.9, 1.3, 1.8]:
		for k in 12:
			var a := start + TAU * float(k) / 12.0
			var p: Vector3 = from + Vector3(cos(a), 0, sin(a)) * r
			p.y = 0.0
			if level.pond_shore_at(p) >= SWIM_SHORE:
				return p
	return Vector3.INF


## `at` with the frog sunk into the water to its back.
func _lowered(at: Vector3, f: Dictionary) -> Vector3:
	return Vector3(at.x, -SINK * (f.size / LENGTH), at.z)


## How long between croaks now (a Vector2 range): rarely by day, often at dusk and at night, a little less in
## autumn.
func croak_interval() -> Vector2:
	var span := CROAK_DAY
	var h: float = level.hour
	if level.night or h >= 21.0 or (h >= 0.0 and h < 5.0):
		span = CROAK_NIGHT
	elif (h >= 18.0 and h < 21.0) or (h >= 5.0 and h < 7.5):
		span = CROAK_DUSK
	if Weather.is_autumn(level.season_day):
		span *= 1.8
	return span


## Whether it is winter (or the water has frozen): the frogs lie hibernating in the mud.
func hibernating() -> bool:
	return Weather.is_winter(level.season_day) or _ice >= FROZEN_FROM


## How thickly the water is frozen (see Outdoor.set_ice): the frogs go under at the first ice.
func set_ice(value: float) -> void:
	_ice = value


func _process(delta: float) -> void:
	_since_check += delta
	if _since_check >= 0.5:
		_since_check = 0.0
		_wake_near()
	if _asleep:
		return
	var hero := level.player as Node3D
	for f in _frogs:
		if f.awake:
			_step(f, delta, hero)


func _step(f: Dictionary, delta: float, hero: Node3D) -> void:
	var holder: Node3D = f.node
	var rig: Node3D = f.rig
	f.t += delta
	f.breath += delta * 2.6
	var swimming: bool = f.state == "swim"
	var pitch := 0.0
	var kick := 0.0
	var sac_swell := 0.3 + sin(f.breath) * 0.04
	f.scare = maxf(0.0, f.scare - delta)
	match f.state:
		"sit":
			f.wait -= delta
			if f.croak_t < 0.0:
				var d := _hero_distance(f, hero)
				var shy := SHY * (0.5 if hero != null and hero.get("sneaking") == true else 1.0)
				if d < shy and f.scare <= 0.0:
					_flee(f, hero)
				elif f.wait <= 0.0:
					_choose_move(f)
		"swim":
			f.wait -= delta
			var to: Vector3 = f.target
			var here: Vector3 = f.pos
			var flat := Vector3(to.x - here.x, 0, to.z - here.z)
			if f.croak_t < 0.0 and flat.length() > 0.12:
				# Glide and kick: a kick every second or so, the frog coasts between them.
				f.kick += delta
				var phase := fmod(f.kick, 1.15) / 1.15
				kick = sin(clampf(phase * 2.2, 0.0, 1.0) * PI)
				var speed: float = (0.08 + 0.34 * kick) * (f.size / LENGTH)
				var dir := flat.normalized()
				var next: Vector3 = here + dir * speed * delta
				if level.pond_shore_at(next) >= SWIM_SHORE - 0.25 or f.leaving:
					f.pos = next
				else:
					f.target = _roam_target(f)
				f.heading = lerp_angle(f.heading, atan2(dir.x, dir.z), minf(1.0, 4.0 * delta))
			elif f.croak_t < 0.0 and not f.leaving:
				f.target = _roam_target(f)
			if f.croak_t < 0.0 and f.wait <= 0.0:
				if f.leaving and flat.length() < 1.2:
					_hop(f, _nearest_bank(f), false)
				elif not f.leaving:
					f.leaving = true
					f.target = _nearest_bank(f)
			elif f.croak_t < 0.0 and f.leaving and flat.length() < 1.2:
				_hop(f, _nearest_bank(f), false)
		"hop":
			var k := clampf(f.t / f.dur, 0.0, 1.0)
			var from: Vector3 = f.from
			var to: Vector3 = f.to
			var p := from.lerp(to, k)
			p.y = lerpf(from.y, to.y, k) + sin(k * PI) * f.hop_h
			f.pos = Vector3(p.x, 0, p.z)
			holder.position = p
			# Nose up at take-off, down on landing; the legs push off and trail behind.
			pitch = -sin(k * PI * 2.0 + 0.3) * 0.5
			kick = 1.0 - smoothstep(0.0, 0.6, k)
			if k >= 1.0:
				_land(f)
	# The croak: the sac swells with each pulse of the sound.
	if f.croak_t >= 0.0:
		f.croak_t += delta
		var ph: float = f.croak_t / f.croak_len * f.pulses
		var frac: float = ph - floor(ph)
		sac_swell = 0.3 + 0.95 * sin(clampf(frac * 1.1, 0.0, 1.0) * PI)
		if f.croak_t >= f.croak_len:
			f.croak_t = -1.0
			f.croak_in = _rng.randf_range(croak_interval().x, croak_interval().y)
	elif f.state != "hop":
		f.croak_in -= delta
		if f.croak_in <= 0.0:
			_croak(f)
	(f.sac as Node3D).scale = Vector3.ONE * sac_swell
	# Pose: legs folded when sitting, stretched back and kicking when swimming or hopping.
	var stretch: float = kick
	for n in ["legl", "legr"]:
		var leg: Node3D = f[n]
		leg.rotation = Vector3(-stretch * 0.9 + (0.0 if swimming else 0.0), (-0.25 if n == "legl" else 0.25) * stretch, 0)
		leg.scale = Vector3(1, 1, 1.0 + stretch * 0.15)
	rig.rotation.x = pitch
	if f.state != "hop":
		var base: Vector3 = f.pos
		holder.position = _lowered(base, f) if swimming else Vector3(base.x, 0.0, base.z)
		# A swimmer bobs a little on its own ripples.
		if swimming:
			holder.position.y += sin(f.t * 1.7) * 0.004
	holder.rotation.y = f.heading


func _hero_distance(f: Dictionary, hero: Node3D) -> float:
	if hero == null:
		return INF
	var p: Vector3 = f.pos
	return Vector2(p.x - hero.global_position.x, p.z - hero.global_position.z).length()


## A swim target within ROAM of the spot the frog started from.
func _roam_target(f: Dictionary) -> Vector3:
	var home: Vector3 = f.banks[0] if not f.banks.is_empty() else f.pos
	for i in 8:
		var a := _rng.randf() * TAU
		var p: Vector3 = f.pos + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(0.6, 1.6)
		if level.pond_shore_at(p) >= SWIM_SHORE and Vector2(p.x - home.x, p.z - home.z).length() < ROAM:
			return p
	return f.pos


## The bank spot closest to the frog.
func _nearest_bank(f: Dictionary) -> Vector3:
	var best := INF
	var out: Vector3 = f.pos
	for b: Vector3 in f.banks:
		var d := Vector2(b.x - f.pos.x, b.z - f.pos.z).length()
		if d < best:
			best = d
			out = b
	return out


## A sitting frog's next move: hop along the bank, hop into the water, or just turn its head.
func _choose_move(f: Dictionary) -> void:
	var roll := _rng.randf()
	if roll < 0.4:
		var water := _water_near(f.pos)
		if water != Vector3.INF:
			_hop(f, water, true)
			return
	elif roll < 0.75 and f.banks.size() > 1:
		for i in 6:
			var b: Vector3 = f.banks[_rng.randi() % f.banks.size()]
			var d := Vector2(b.x - f.pos.x, b.z - f.pos.z).length()
			if d > 0.5 and d < 2.4:
				_hop(f, b, false)
				return
	f.heading += _rng.randf_range(-0.9, 0.9)
	f.wait = _rng.randf_range(SIT_TIME.x, SIT_TIME.y)


## The hero is too close: into the water if there is any near, else along the bank away from the hero.
func _flee(f: Dictionary, hero: Node3D) -> void:
	f.scare = 4.0
	var water := _water_near(f.pos)
	if water != Vector3.INF:
		_hop(f, water, true)
		return
	_choose_move(f)


func _hop(f: Dictionary, to: Vector3, into_water: bool) -> void:
	f.from = Vector3(f.pos.x, (f.node as Node3D).position.y, f.pos.z)
	f.to = Vector3(to.x, -SINK * (f.size / LENGTH) if into_water else 0.0, to.z)
	f.state = "hop"
	f.t = 0.0
	var d := Vector2(to.x - f.pos.x, to.z - f.pos.z).length()
	f.dur = 0.3 + d * 0.16
	f.hop_h = (0.07 + 0.05 * d) * (f.size / LENGTH)
	f.target = to
	f.into_water = into_water
	f.heading = atan2(to.x - f.pos.x, to.z - f.pos.z)
	f.leaving = false


func _land(f: Dictionary) -> void:
	f.pos = Vector3(f.to.x, 0, f.to.z)
	f.t = 0.0
	if f.into_water:
		f.state = "swim"
		f.wait = _rng.randf_range(SWIM_TIME.x, SWIM_TIME.y)
		f.kick = 0.0
		f.leaving = false
		f.target = _roam_target(f)
		_splash(f)
	else:
		f.state = "sit"
		f.wait = _rng.randf_range(SIT_TIME.x, SIT_TIME.y)
		# The bank spots of the frog now are the ones around its new home.
		f.banks.sort_custom(func(a: Vector3, b: Vector3) -> bool:
			return Vector2(a.x - f.pos.x, a.z - f.pos.z).length() < Vector2(b.x - f.pos.x, b.z - f.pos.z).length())


func _splash(f: Dictionary) -> void:
	var hero := level.player as Node3D
	if hero == null or not _audible(f.pos, hero):
		return
	var d := _hero_distance(f, hero)
	Sfx.play_3d(self, "splash_soft_%d" % (_rng.randi() % 3), -17.0 - maxf(0.0, d - 5.0) * 0.8, f.pos, 1.5)


## Whether a sound at `at` carries to the hero: not from afar, nor into a house or underground.
func _audible(at: Vector3, hero: Node3D) -> bool:
	if hero.global_position.y < Outdoor.UNDERGROUND_Y or level.is_roofed(hero.global_position):
		return false
	return Vector2(at.x - hero.global_position.x, at.z - hero.global_position.z).length() <= CROAK_RANGE


## The frog croaks: one of the sounds, from where it sits, and its sac swells with it. At night a neighbour
## often answers soon after.
func _croak(f: Dictionary, answer := true) -> void:
	var which := _rng.randi() % CROAKS
	f.croak_t = 0.0
	f.croak_len = CROAK_LENGTH[which] / f.pitch
	f.pulses = CROAK_PULSES[which]
	var hero := level.player as Node3D
	if hero != null and _audible(f.pos, hero):
		var d := _hero_distance(f, hero)
		Sfx.play_3d(self, "frog_%d" % which, CROAK_VOLUME - maxf(0.0, d - 5.0) * 0.7, f.pos, f.pitch)
	if answer and (level.night or croak_interval() == CROAK_NIGHT) and _rng.randf() < 0.5:
		var others := _frogs.filter(func(o: Dictionary) -> bool: return o != f and o.awake and o.state != "hop" and o.croak_t < 0.0)
		if not others.is_empty():
			var o: Dictionary = others[_rng.randi() % others.size()]
			o.croak_in = minf(o.croak_in, _rng.randf_range(0.8, 3.0))


## Frogs near the hero live; the others are hidden and paused (see ACTIVE_RANGE), and in winter all are
## hibernating.
func _wake_near() -> void:
	var asleep := hibernating()
	if asleep != _asleep:
		_asleep = asleep
		visible = not asleep
		for f in _frogs:
			# Back from the mud in spring: sitting at the bank, not in the middle of a hop.
			if not asleep and f.state != "sit":
				f.state = "sit"
				f.pos = f.banks[0] if not f.banks.is_empty() else f.pos
				f.wait = _rng.randf_range(0.0, SIT_TIME.y)
			f.croak_t = -1.0
	if _asleep:
		return
	var hero := level.player as Node3D
	for f in _frogs:
		var holder: Node3D = f.node
		var near := hero == null or holder.global_position.distance_to(hero.global_position) <= active_range
		if near != f.awake:
			f.awake = near
			holder.visible = near
			holder.process_mode = Node.PROCESS_MODE_INHERIT if near else Node.PROCESS_MODE_DISABLED
