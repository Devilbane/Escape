class_name GlowwormSwarms
extends Node3D
## Glowworm swarms that roam the open air at night: small clouds of soft
## yellow-green points that drift slowly over the grass and the village lanes,
## fading in and out as they glow. They gather most thickly in the village
## (VILLAGE_SWARMS) and are scarcer elsewhere (WILD_SWARMS).
##
## Purely decorative: no collision, no effect on the game. Each swarm also
## carries one small, soft light so the glow lights the lane around it. Each swarm
## is one small CPUParticles3D made like the other glows (see Effects), and
## only a handful exist, always around the hero: a swarm that falls behind is
## carried to a new spot ahead, out of sight. They keep clear of the hero and
## never drift over walls or buildings. By day, and while the hero is
## indoors, they are put out.
## Tested by tests/glowworm_swarms.gd.

## How many swarms drift near the hero in the village, and elsewhere.
const VILLAGE_SWARMS := 4
const WILD_SWARMS := 3
## Swarms are placed this far from the hero (metres), and carried to a new
## spot once they are farther than LOSE.
const NEAR := 7.0
const FAR := 24.0
const LOSE := 30.0
## How fast a swarm drifts (metres per second) and how long it holds one
## heading (seconds).
const DRIFT := Vector2(0.25, 0.7)
const HOLD := Vector2(4.0, 9.0)
## A swarm hovers this high (metres) above the ground.
const HEIGHT := Vector2(0.5, 1.5)
## A swarm slips away from the hero inside this distance (metres).
const SHY := 3.5
## Where a swarm may drift: on open ground.
const GROUND := ".,Pai:"
## The glow of a glowworm: a yellow-green.
const GLOW := Color(0.72, 1.0, 0.34)
## The soft light a swarm casts: faint and short, so a lane is only touched by
## it. Few swarms exist, so these few omni lights stay cheap.
const LIGHT_ENERGY := 0.45
const LIGHT_RANGE := 4.5

var level: Outdoor
var _swarms: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _init(of_level: Outdoor, seed_text := "") -> void:
	name = "GlowwormSwarms"
	level = of_level
	_rng.seed = hash(seed_text + "gluehwuermchen")


## Whether the glowworms are out at an hour: from dusk until a little after
## dawn, a wider stretch than the night itself so they come and go with the
## fading light.
static func out_at(hour: float) -> bool:
	hour = fposmod(hour, 24.0)
	return hour >= 20.5 or hour < 5.5


## How many swarms should drift around the hero: more in the village.
static func swarms_for(in_village: bool) -> int:
	return VILLAGE_SWARMS if in_village else WILD_SWARMS


## One swarm: a small cloud of points that fade in and out as they drift.
## It starts cold (not emitting).
static func make_swarm() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Swarm"
	p.amount = 10
	p.lifetime = 3.2
	# The cloud's own motion carries the points along with it.
	p.local_coords = true
	p.mesh = Effects._quad(0.16, Color(1, 1, 1))
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 1.2
	p.direction = Vector3.UP
	p.spread = 180.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.25
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	p.lifetime_randomness = 0.5
	var ramp := Gradient.new()
	ramp.set_color(0, Color(GLOW, 0.0))
	ramp.add_point(0.25, Color(GLOW, 0.8))
	ramp.add_point(0.6, Color(GLOW, 0.35))
	ramp.add_point(0.8, Color(GLOW, 0.7))
	ramp.set_color(ramp.get_point_count() - 1, Color(GLOW, 0.0))
	p.color_ramp = ramp
	Effects.start_cold(p)
	var light := OmniLight3D.new()
	light.name = "Glow"
	light.light_color = GLOW
	light.light_energy = LIGHT_ENERGY
	light.omni_range = LIGHT_RANGE
	light.omni_attenuation = 2.0
	light.shadow_enabled = false
	light.light_specular = 0.0
	p.add_child(light)
	return p


## Whether a swarm may hover over a spot: open ground, not a house.
func _free(at: Vector3) -> bool:
	var c := level.world_to_cell(at)
	return GROUND.contains(level.cell_char(c)) and not level._in_house(c)


## A new spot for a swarm around `centre`, on open ground, or INF.
func _spot_near(centre: Vector3) -> Vector3:
	for _try in 12:
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(NEAR, FAR)
		var at := centre + Vector3(cos(a) * d, 0.0, sin(a) * d)
		if not _free(at):
			continue
		# Outside the village a spot is only sometimes taken, so what
		# swarms there are keep to the lanes and the grass beside them.
		if not level._in_village(level.world_to_cell(at)) and _rng.randf() > 0.5:
			continue
		at.y = _rng.randf_range(HEIGHT.x, HEIGHT.y)
		return at
	return Vector3.INF


func _heading(swarm: Dictionary) -> void:
	var a := _rng.randf() * TAU
	var v := _rng.randf_range(DRIFT.x, DRIFT.y)
	swarm.vel = Vector3(cos(a) * v, 0.0, sin(a) * v)
	swarm.hold = _rng.randf_range(HOLD.x, HOLD.y)


func _add_swarm(at: Vector3) -> void:
	var node := make_swarm()
	add_child(node)
	node.position = at
	node.reset_physics_interpolation()
	var swarm := {"node": node}
	_heading(swarm)
	_swarms.append(swarm)


## How many swarms glow now (for the test).
func count() -> int:
	return _swarms.filter(func(w): return not w.get("fading", false)).size()


## Drifts every swarm and keeps the right number of them around the hero.
## `indoors` and the hour decide whether they glow at all.
func tick(delta: float, hero: Vector3, hour: float, indoors: bool) -> void:
	var on := out_at(hour) and not indoors
	var want := 0
	if on:
		want = swarms_for(level._in_village(level.world_to_cell(hero)))
	# Too many: put out the farthest. Too few: add one around the hero.
	var active := _swarms.filter(func(w): return not w.get("fading", false))
	if active.size() > want:
		var far := -1
		for i in _swarms.size():
			if _swarms[i].get("fading", false):
				continue
			if far < 0 or _flat(_swarms[i].node.position, hero) > _flat(_swarms[far].node.position, hero):
				far = i
		_fade_out(far)
	elif active.size() < want:
		var at := _spot_near(hero)
		if at != Vector3.INF:
			_add_swarm(at)
	for i in range(_swarms.size() - 1, -1, -1):
		var swarm: Dictionary = _swarms[i]
		var node: CPUParticles3D = swarm.node
		if not node.emitting and not swarm.get("fading", false):
			node.emitting = true
		if swarm.get("fading", false):
			swarm.life -= delta
			if swarm.life <= 0.0:
				node.queue_free()
				_swarms.remove_at(i)
			continue
		if _flat(node.position, hero) > LOSE:
			var at := _spot_near(hero)
			if at != Vector3.INF:
				node.position = at
				node.restart()
				node.reset_physics_interpolation()
			continue
		swarm.hold -= delta
		if swarm.hold <= 0.0:
			_heading(swarm)
		var vel: Vector3 = swarm.vel
		# Slip away from a hero who comes close.
		var away := node.position - hero
		away.y = 0.0
		if away.length() < SHY and away.length() > 0.01:
			vel = away.normalized() * DRIFT.y + vel * 0.3
		var next: Vector3 = node.position + vel * delta
		if _free(next):
			node.position = next
		else:
			_heading(swarm)


## Lets a swarm stop making points and remove it once the last has faded.
func _fade_out(i: int) -> void:
	var swarm: Dictionary = _swarms[i]
	swarm.fading = true
	swarm.life = (swarm.node as CPUParticles3D).lifetime
	swarm.node.emitting = false
	var glow := (swarm.node as CPUParticles3D).get_node_or_null("Glow") as OmniLight3D
	if glow:
		create_tween().tween_property(glow, "light_energy", 0.0, swarm.life)


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
