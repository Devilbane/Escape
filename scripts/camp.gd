class_name Camp
extends Node3D
## A camp for the night away from any bed: the hero rolls out a bedroll
## ("schlafrolle", bought from the merchant) and lights a small campfire
## beside it. At the camp the game can be saved, either by sleeping there
## and logging out (like the bed: the day plan runs while the player is
## away) or by staying awake. A game saved at a camp wakes up there again.
##
## The rules are kept few and plain:
## - the hero needs a bedroll in the bag (it is not used up);
## - not inside a building (there is a bed there anyway);
## - not in a fight, and no monster close by (SAFE_RANGE), nor the start
##   spot of one still alive, so the camp is still quiet after a reload;
## - walking away (LEAVE_RANGE) packs the camp up again.
##
## Down in the dungeon the hero can also rest by the fire for a while
## (see Game.rest_at_camp): it heals them fully and saves the game, so the
## camp becomes the place they wake up at after blacking out. But the deep
## is never quite safe: a rest may be cut short by an ambush (AMBUSH_CHANCE),
## a few of the floor's own monsters creeping up to the fire. A companion at
## the hero's side keeps watch (GUARDS): the fox and the doe hear them
## coming, so an ambush is much rarer, and no monster dares near a stag.
##
## The camp is drawn from plain shapes, so it fits the dungeon and the open
## air alike: a rolled-out mat with its head end rolled up as a pillow, and
## a ring of stones with crossed logs, a flame and a flickering light.

const ITEM := "schlafrolle"
## No monster this close (metres) when the camp is pitched; any that turns
## up this close after a reload keeps away from the fire (see clear_around).
const SAFE_RANGE := 12.0
## A monster on the hunt this close (metres) still counts as a fight.
const HUNT_RANGE := 30.0
## Walking this far from the camp (metres) packs it up.
const LEAVE_RANGE := 10.0
## Within this distance (metres) the camp key opens the camp's window
## instead of pitching a new camp.
const NEAR := 4.0
## The chance that a rest by the fire on a dungeon floor is cut short by
## an ambush, with nobody keeping watch.
const AMBUSH_CHANCE := 0.3
## The chance of an ambush while a companion keeps watch, by its kind: the
## fox's nose and the doe's ears hear them coming, nobody dares near a stag.
const GUARDS := {"fuchs": 0.1, "reh": 0.15, "hirsch": 0.0}
## How many monsters creep up in an ambush, and how far from the fire
## (metres) they turn up: out of the dark, with time to stand up.
const AMBUSHERS := 2
const AMBUSH_NEAR := 7.0
const AMBUSH_FAR := 11.0
## The bedroll: how far in front of the hero it is rolled out, and its size.
const ROLL_AHEAD := 1.3
const ROLL_SIZE := Vector3(0.85, 0.07, 2.0)
## How far from the bedroll's middle towards its foot the hero stands before
## lying down. Lying down falls backwards, so this puts the body on the mat.
const LIE_OFFSET := 0.65
## The fire burns beside the bedroll, this far to its side (metres).
const FIRE_SIDE := 1.7
const FIRE_COLOR := Color(1.0, 0.58, 0.26)
const FIRE_ENERGY := 2.6
const FIRE_RANGE := 9.0

## The way from the bedroll's head to its foot, as an angle about the
## vertical (see foot).
var rot := 0.0
var _light: OmniLight3D
var _time := 0.0


## Rolls out a camp in `parent` (the level) with its bedroll's middle at
## `at`, the foot of the bedroll pointing along `rot`.
static func pitch(parent: Node, at: Vector3, angle: float) -> Camp:
	var camp := Camp.new()
	camp.name = "Camp"
	camp.rot = angle
	parent.add_child(camp)
	camp.global_position = Vector3(at.x, at.y, at.z)
	camp._build()
	return camp


## The angle of a camp rolled out in front of a hero standing at `from`
## and looking along `ahead`: its foot points back at the hero.
static func angle_facing(ahead: Vector3) -> float:
	var flat := Vector3(ahead.x, 0.0, ahead.z)
	if flat.length() < 0.01:
		flat = Vector3.FORWARD
	flat = -flat.normalized()
	return atan2(flat.x, flat.z)


## Where to roll out a camp for a hero standing at `from` and looking along
## `ahead`: {"pos": the bedroll's middle, "rot": its angle}, on open floor
## with room for the fire. The way the hero looks is tried first, then the
## other ways round. {} when there is no room anywhere.
static func find_spot(level: Level, from: Vector3, ahead: Vector3) -> Dictionary:
	var base := atan2(ahead.x, ahead.z) if Vector2(ahead.x, ahead.z).length() > 0.01 else PI
	for i in 8:
		var turn := base + (1 if i % 2 == 1 else -1) * ceili(i / 2.0) * TAU / 8.0
		var look := Vector3(sin(turn), 0.0, cos(turn))
		var angle := angle_facing(look)
		var middle := from + look * ROLL_AHEAD
		var foot_dir := Vector3(sin(angle), 0.0, cos(angle))
		var side := foot_dir.cross(Vector3.UP).normalized()
		var points := [middle, middle - foot_dir * (ROLL_SIZE.z / 2.0 + 0.2), middle + side * FIRE_SIDE, middle + side * (FIRE_SIDE + 0.6)]
		if points.all(func(p): return _open(level, p)):
			return {"pos": Vector3(middle.x, from.y, middle.z), "rot": angle}
	return {}


## Whether a spot is open floor anyone can walk on, without a grate or a
## trap (nobody sleeps on spikes).
static func _open(level: Level, p: Vector3) -> bool:
	var c := level.world_to_cell(p)
	if not level.astar.is_in_boundsv(c) or level.astar.is_point_solid(c) or not level._walkable(c):
		return false
	if level.grates.has(c) or level.cell_char(c) == "S":
		return false
	return level.traps == null or level.traps.trap_at(c).is_empty()


## The way from the head of the bedroll to its foot.
func foot() -> Vector3:
	return Vector3(sin(rot), 0.0, cos(rot))


## Where the hero stands before lying down, and where they lie.
func lie_spot() -> Vector3:
	return global_position + foot() * LIE_OFFSET + Vector3(0, ROLL_SIZE.y, 0)


## Where the hero stands at the camp: at the foot of the bedroll.
func stand_spot() -> Vector3:
	return global_position + foot() * (ROLL_SIZE.z / 2.0 + 0.6)


## Where the fire burns.
func fire_spot() -> Vector3:
	return global_position + foot().cross(Vector3.UP).normalized() * FIRE_SIDE


func for_save() -> Dictionary:
	return {"x": global_position.x, "y": global_position.y, "z": global_position.z, "rot": rot}


## A camp from a saved game: {"pos": Vector3, "rot": float}, or {} if the
## game was not saved at a camp.
static func from_save(saved) -> Dictionary:
	if not (saved is Dictionary) or not saved.has("x") or not saved.has("z"):
		return {}
	return {"pos": Vector3(float(saved.x), float(saved.get("y", 0.0)), float(saved.z)), "rot": float(saved.get("rot", 0.0))}


## Why the hero cannot pitch a camp here and now, as a line for the player,
## or "" when they can.
static func why_not(player: Player, level: Level, indoors: bool) -> String:
	if not player.bag.has(ITEM):
		return Lang.t("Du hast keine Schlafrolle. (Der Händler verkauft eine.)")
	if indoors:
		return Lang.t("Hier drinnen schläfst du besser in einem Bett.")
	var at := player.global_position
	if player.fight_cooldown > 0.0 or level.enemies.any(func(e): return is_instance_valid(e) and not e.dead and not e.is_friend() and e.is_hunting() and _flat(e.global_position, at) < HUNT_RANGE):
		return Lang.t("Mitten im Kampf kannst du kein Lager aufschlagen.")
	if monster_near(level, player.global_position):
		return Lang.t("Zu gefährlich: Hier treiben sich Ungeheuer herum.")
	if not player.is_on_floor() or find_spot(level, player.global_position, player.facing()).is_empty():
		return Lang.t("Hier ist kein Platz für ein Lager.")
	return ""


## Whether a monster that is not the hero's friend is within SAFE_RANGE of
## `at`, or will be again after a reload: the start spot of a monster of
## the map that is still alive counts too.
static func monster_near(level: Level, at: Vector3) -> bool:
	for e in level.enemies:
		if is_instance_valid(e) and not e.dead and not e.is_friend() and _flat(e.global_position, at) < SAFE_RANGE:
			return true
	for m in level._map_enemies:
		var e = m.enemy
		if is_instance_valid(e) and not e.dead and not e.is_friend() and _flat(level.cell_to_world(m.cell), at) < SAFE_RANGE:
			return true
	return false


## Whether the hero can rest by the camp's fire here: on a dungeon floor,
## not in the open air (there the camp is for the night and logging out).
static func can_rest(level: Level) -> bool:
	return not level.outdoor and level.building == ""


## Why the hero cannot rest by the fire right now, as a line for the
## player, or "" when they can: not in a fight, nor with a monster close by.
static func why_no_rest(player: Player, level: Level) -> String:
	var at := player.global_position
	if player.fight_cooldown > 0.0 or level.enemies.any(func(e): return is_instance_valid(e) and not e.dead and not e.is_friend() and e.is_hunting() and _flat(e.global_position, at) < HUNT_RANGE):
		return Lang.t("Mitten im Kampf kannst du dich nicht ausruhen.")
	if monster_near(level, at):
		return Lang.t("Zu gefährlich: Hier treiben sich Ungeheuer herum.")
	return ""


## The chance of an ambush while resting here, with the companion of kind
## `guard` keeping watch ("" for nobody). None where no monster of the
## floor could come (see ambush_kinds).
static func ambush_chance(level: Level, guard: String) -> float:
	if ambush_kinds(level).is_empty():
		return 0.0
	return float(GUARDS.get(guard, AMBUSH_CHANCE))


## The kinds of monsters that may creep up to the fire: the plain ones this
## floor's map places (whether still alive or not), so they always belong
## here. No bosses, no guardian of the key and no horrors.
static func ambush_kinds(level: Level) -> Array[String]:
	var kinds: Array[String] = []
	for row in level.grid:
		for ch in row:
			if not Enemy.LETTERS.has(ch):
				continue
			var kind: String = Enemy.LETTERS[ch]
			if kind in kinds or kind == "waechter" or kind in HeroLevel.BOSSES or kind in Enemy.HORRORS \
					or Enemy.KINDS[kind].get("boss", false) or kind in ["drache", "grosser_alter", "brutdrache"]:
				continue
			kinds.append(kind)
	return kinds


## Where the ambushers turn up: open floor between AMBUSH_NEAR and
## AMBUSH_FAR from the fire at `at`, with a way to it, apart from each
## other. Fewer (or none) if there is no such floor.
static func ambush_cells(level: Level, at: Vector3, count: int) -> Array[Vector2i]:
	var from := level.world_to_cell(at)
	var reach := ceili(AMBUSH_FAR / Level.TILE)
	var spots: Array[Vector2i] = []
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var c := from + Vector2i(dx, dy)
			var p := level.cell_to_world(c)
			var d := _flat(p, at)
			if d >= AMBUSH_NEAR and d <= AMBUSH_FAR and _open(level, p):
				spots.append(c)
	spots.shuffle()
	var picked: Array[Vector2i] = []
	for c in spots:
		if picked.size() >= count:
			break
		if picked.any(func(o): return (o - c).length() < 1.5):
			continue
		if level.astar.is_in_boundsv(from) and level.astar.get_id_path(c, from).is_empty():
			continue
		picked.append(c)
	return picked


## After a reload at the camp: monsters that came up close by chance (the
## wandering ones are placed anew on every load) keep away from the fire.
## Bosses and the key's guardian stay, the camp was never pitched near them.
static func clear_around(level: Level, at: Vector3) -> void:
	for e in level.enemies.duplicate():
		if not is_instance_valid(e) or e.dead or e.is_friend() or e.is_level_boss() or e.kind == "waechter":
			continue
		if _flat(e.global_position, at) < SAFE_RANGE:
			level.enemies.erase(e)
			e.queue_free()


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _process(delta: float) -> void:
	# The fire flickers.
	_time += delta
	if _light:
		_light.light_energy = FIRE_ENERGY * (0.85 + 0.1 * sin(_time * 9.0) + 0.06 * sin(_time * 23.0 + 1.3))


func _build() -> void:
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.24, 0.3, 0.2)
	cloth.roughness = 0.95
	var edge := StandardMaterial3D.new()
	edge.albedo_color = Color(0.5, 0.32, 0.17)
	edge.roughness = 0.9
	var along := Basis(Vector3.UP, rot)
	# The mat, rolled out flat.
	var mat := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = ROLL_SIZE
	mat.mesh = box
	mat.material_override = cloth
	mat.basis = along
	mat.position = Vector3(0, ROLL_SIZE.y / 2.0, 0)
	add_child(mat)
	# Its head end, rolled up into a pillow, with two leather straps.
	var roll := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 0.14
	tube.bottom_radius = 0.14
	tube.height = ROLL_SIZE.x
	roll.mesh = tube
	roll.material_override = cloth
	var head := -foot() * (ROLL_SIZE.z / 2.0 - 0.1)
	roll.basis = along * Basis(Vector3.FORWARD, PI / 2.0)
	roll.position = head + Vector3(0, 0.14, 0)
	add_child(roll)
	for side in [-0.25, 0.25]:
		var strap := MeshInstance3D.new()
		var ring := CylinderMesh.new()
		ring.top_radius = 0.15
		ring.bottom_radius = 0.15
		ring.height = 0.05
		strap.mesh = ring
		strap.material_override = edge
		strap.basis = roll.basis
		strap.position = roll.position + along * Vector3(side * ROLL_SIZE.x, 0, 0)
		add_child(strap)
	_build_fire(to_local(fire_spot()))


## A ring of stones, two crossed logs, a flame and its light.
func _build_fire(at: Vector3) -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.42, 0.4, 0.38)
	stone.roughness = 1.0
	for i in 8:
		var a := i * TAU / 8.0
		var rock := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.15
		ball.height = 0.2
		rock.mesh = ball
		rock.material_override = stone
		rock.position = at + Vector3(cos(a), 0.0, sin(a)) * 0.5 + Vector3(0, 0.07, 0)
		rock.scale = Vector3(1.0 + 0.2 * sin(i * 2.3), 1.0, 1.0 + 0.2 * cos(i * 1.7))
		add_child(rock)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.36, 0.22, 0.12)
	wood.roughness = 0.9
	for angle in [0.5, 2.1]:
		var log_mesh := MeshInstance3D.new()
		var stick := CylinderMesh.new()
		stick.top_radius = 0.06
		stick.bottom_radius = 0.07
		stick.height = 0.8
		log_mesh.mesh = stick
		log_mesh.material_override = wood
		log_mesh.basis = Basis(Vector3.UP, angle) * Basis(Vector3.RIGHT, PI / 2.0)
		log_mesh.position = at + Vector3(0, 0.08, 0)
		add_child(log_mesh)
	# Glowing embers under the logs.
	var embers := MeshInstance3D.new()
	var glow := CylinderMesh.new()
	glow.top_radius = 0.3
	glow.bottom_radius = 0.32
	glow.height = 0.03
	embers.mesh = glow
	var hot := StandardMaterial3D.new()
	hot.albedo_color = Color(0.12, 0.05, 0.03)
	hot.emission_enabled = true
	hot.emission = Color(0.9, 0.25, 0.06)
	hot.emission_energy_multiplier = 0.7
	embers.material_override = hot
	embers.position = at + Vector3(0, 0.02, 0)
	add_child(embers)
	var flame := Effects.make_flame()
	flame.position = at + Vector3(0, 0.25, 0)
	flame.scale = Vector3.ONE * 1.8
	add_child(flame)
	_light = OmniLight3D.new()
	_light.light_color = FIRE_COLOR
	_light.light_energy = FIRE_ENERGY
	_light.omni_range = FIRE_RANGE
	_light.omni_attenuation = 1.4
	_light.position = at + Vector3(0, 1.2, 0)
	add_child(_light)
