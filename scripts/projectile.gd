class_name Projectile
extends Node3D
## A thrown dagger (from the hero), a crossbow bolt or a magic orb (from a
## skeleton). Orbs fly slower but curve after the hero. The dragon's fire
## flies like an orb, burns for two, sets flammable monsters alight (see
## Ignition) and never curses. A skeleton mage casts the same fireball at them. A spider's web ("web")
## is a pale ball of silk: it does no harm but sticks to the hero and slows
## them for a moment (Player.afflict "netz"). A slime's gob ("gob") does no
## harm either, but slimes whoever it hits (see SlimeCoat).

const SPEED := 20.0
const LIFETIME := 2.0

var level: Level
var direction := Vector3.FORWARD
var from_player := true
## The skeleton that shot or cast it; the hero fights back against it.
var shooter: Node = null
## The rival monster it was aimed at (see Factions), or null when it flies
## at the hero. Aimed at a rival ("at_rival"), it hits only that one.
var foe: Enemy = null
var at_rival := false
## What the shot costs whoever it hits: the hero's knife or the shooter's own damage.
var damage := 1
var magic := false
var fire := false
## What a fireball costs a monster it hits.
var fire_damage := 2
## Where it was thrown from: a knife that ends inside a wall falls back
## towards here (see Level.knife_rest).
var thrown_from := Vector3.ZERO
var web := false
var gob := false
## The colour of the slime that spat the gob.
var gob_colour := SlimeCoat.COLOR
## This knife's own chance to break, KNIFE_BREAK_CHANCE unless a test sets it.
var break_chance := KNIFE_BREAK_CHANCE
var _age := 0.0

const MAGIC_SPEED := 5.5
const MAGIC_TURN := 0.8
const CURSE_CHANCE := 0.35
## How often a thrown knife breaks when it lands (on a foe, a wall or the
## floor) instead of lying there to be picked up again.
const KNIFE_BREAK_CHANCE := 0.2
## A web flies slower than a bolt: a hero who sees it coming can step aside.
const WEB_SPEED := 11.0


static func spawn(owner_level: Level, origin: Vector3, dir: Vector3, by_player: bool, is_magic := false, is_fire := false, is_web := false, slime = null) -> Projectile:
	var p := Projectile.new()
	p.level = owner_level
	p.from_player = by_player
	p.magic = is_magic
	p.fire = is_fire
	p.web = is_web
	p.gob = slime is Color
	if p.gob:
		p.gob_colour = slime
	dir.y = 0.0
	p.direction = dir.normalized()
	owner_level.add_child(p)
	p.global_position = origin
	p.thrown_from = origin
	p.look_at(origin + p.direction, Vector3.UP)
	if is_magic:
		var orb := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.35
		sphere.height = 0.7
		orb.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.55, 0.15) if is_fire else Color(0.75, 0.35, 1.0)
		orb.material_override = mat
		p.add_child(orb)
		var glow := OmniLight3D.new()
		glow.light_color = Color(1.0, 0.5, 0.15) if is_fire else Color(0.7, 0.3, 1.0)
		glow.light_energy = 2.0
		glow.omni_range = 4.0
		p.add_child(glow)
		p.add_child(Effects.make_sparkles(Color(1.0, 0.6, 0.2) if is_fire else Color(0.8, 0.4, 1.0)))
		return p
	if is_web:
		p.add_child(_web_ball())
		return p
	if p.gob:
		p.add_child(SlimeCoat.gob(slime))
		return p
	var model: Node3D = load("res://assets/weapons/dagger.gltf" if by_player else "res://assets/weapons/Skeleton_Arrow.gltf").instantiate()
	model.rotation.x = -PI * 0.5
	model.scale = Vector3.ONE * (1.4 if by_player else 2.0)
	p.add_child(model)
	if by_player:
		p.add_child(Effects.make_sparkles(Color(0.8, 0.9, 1.0)))
	return p


## A spider's web in flight: a pale, see-through ball of silk with a few
## threads trailing behind it and a faint glimmer, so it reads in the dark too.
static func _web_ball() -> Node3D:
	var ball := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.93, 0.93, 0.88, 0.8)
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.28
	sphere.height = 0.56
	sphere.radial_segments = 10
	sphere.rings = 5
	core.mesh = sphere
	core.material_override = mat
	ball.add_child(core)
	# Threads trailing back (look_at points -Z along the flight).
	for i in 3:
		var strand := MeshInstance3D.new()
		var line := BoxMesh.new()
		line.size = Vector3(0.025, 0.025, 0.9)
		strand.mesh = line
		strand.material_override = mat
		strand.position = Vector3((i - 1) * 0.12, (i % 2) * 0.1 - 0.05, 0.55)
		strand.rotation.y = (i - 1) * 0.18
		ball.add_child(strand)
	ball.add_child(Effects.make_sparkles(Color(0.95, 0.95, 0.9)))
	return ball


func _ready() -> void:
	SmoothMotion.follow_ticks(self)


func _physics_process(delta: float) -> void:
	_age += delta
	var homing := Vector3.INF
	if at_rival:
		if is_instance_valid(foe) and not foe.dead:
			homing = foe.global_position
	elif not level.player.dead:
		homing = level.player.global_position
	if magic and homing != Vector3.INF:
		var want := homing - global_position
		want.y = 0.0
		var turn := clampf(direction.signed_angle_to(want.normalized(), Vector3.UP), -MAGIC_TURN * delta, MAGIC_TURN * delta)
		direction = direction.rotated(Vector3.UP, turn)
	var step := direction * (MAGIC_SPEED if magic else WEB_SPEED if web else SlimeCoat.SPIT_SPEED if gob else SPEED) * delta
	var was := global_position
	global_position += step
	# A wall, a closed door or a pillar (statue, crate stack) stops it.
	if _age > (LIFETIME * 2.0 if magic else LIFETIME) or level.is_opaque(level.world_to_cell(global_position)) \
			or level.shot_blocked(was, global_position):
		_land(was)
		return
	if from_player:
		for e in level.enemies:
			# Knives fly past the hero's friends (see Factions).
			if is_instance_valid(e) and not e.dead and not e.is_friend() and _hits(e.global_position):
				# Monster knowledge: a knife may find a vital point (see MonsterLore).
				var vital: bool = level.player.finds_vital(e)
				var had: int = e.hp
				e.take_hit(level.player.vital_damage(level.player.throw_power(), "werfen") if vital else damage, global_position - direction, "knife")
				if vital:
					level.player.vital_struck(e)
				# A knife cuts: the wound may bleed (see Bleeding).
				level.player.wound_foe(e, had - e.hp, true, vital)
				level.player.mark_fight()
				level.player.train("werfen", 1.0)
				if e.dead and e.kind == "magier":
					level.player.train("intelligenz", 4.0)
				_land(global_position - direction * 0.6)
				return
	elif at_rival:
		if is_instance_valid(foe) and not foe.dead and _hits(foe.global_position):
			if gob:
				foe.get_slimed(gob_colour)
				if is_instance_valid(shooter):
					foe.provoke(shooter as Enemy)
			else:
				# A bolt or an arrow is a little shot a slime swallows (see SlimeCoat).
				foe.hit_by_rival(fire_damage if fire else damage, shooter as Enemy if is_instance_valid(shooter) else null, not magic and not fire)
			queue_free()
	else:
		var player: Player = level.player
		if not player.dead and _hits(player.global_position) and player.global_position.y < 1.2:
			if web:
				# Sticky silk: no harm, but the hero is slowed for a moment.
				player.afflict("netz")
				if is_instance_valid(shooter):
					player.defend_against(shooter)
				Sfx.play(player, "swing", -8.0, player.global_position, 0.7)
				queue_free()
				return
			if gob:
				player.get_slimed(gob_colour)
				if is_instance_valid(shooter):
					player.defend_against(shooter)
				Sfx.play(player, "swing", -8.0, player.global_position, 0.5)
				queue_free()
				return
			var before := player.hp
			player.take_damage(2 if fire else damage, global_position - direction)
			player.defend_against(shooter)
			# A bolt cuts: the hero may bleed (see Bleeding).
			if not magic and not fire and Bleeding.rolls_wound(before - player.hp):
				player.bleed(before - player.hp)
			# A mage's orb sometimes curses whoever it hits.
			if magic and not fire and player.hp < before and randf() < CURSE_CHANCE:
				player.afflict("fluch")
			queue_free()


## The shot is over. The hero's knife falls to the floor near `at` and lies
## there to be picked up again (see Level.lay_knife), unless it breaks
## (break_chance); bolts and orbs vanish.
func _land(at: Vector3) -> void:
	if from_player and not magic and is_instance_valid(level):
		if randf() < break_chance:
			Comic.pop(at, "break")
			Sfx.play(self, "gear_metal_%d" % (randi() % 3), -4.0, at, 1.5)
		else:
			level.lay_knife(level.knife_rest(at, thrown_from), direction)
	queue_free()


func _hits(target: Vector3) -> bool:
	return Vector2(target.x - global_position.x, target.z - global_position.z).length() < 0.9
