class_name ArcaneBolt
extends Node3D
## The spell of the tome of unleashed power from Sternhall's vault (see
## SternHall): a bolt of pure force the hero hurls at the nearest foe in
## sight (key 2 or the star button, see Game.spell_action). It flies fast,
## bends after its target, goes through every armour (a "pierce", see
## Enemy.take_hit) and hits harder the cleverer the hero is. Then the power
## needs COOLDOWN seconds to gather again. Casting trains Intelligenz.
## Armoured guardians still shrug it off: only a stab in the back finds the
## gap in their armour.

const COOLDOWN := 6.0
const RANGE := 24.0
const SPEED := 22.0
## How quickly it turns after its target (radians per second).
const TURN := 5.0
const LIFETIME := 1.6
const COLOR := Color(0.72, 0.45, 1.0)

var level: Level
var target: Enemy
var direction := Vector3.FORWARD
var damage := 4
## A fireball: cast at a foe that can ignite (see Ignition); it sets it alight.
var fiery := false
var _age := 0.0


## What a bolt deals: the hero's power plus two, and one more for every
## point of Intelligenz above the start.
static func damage_of(player: Player) -> int:
	return maxi(3, player.power + 2 + player.intelligence_points())


## Casts a bolt from the hero at the nearest foe in sight (or straight
## ahead). Returns "" when it flew, else why not.
static func cast(player: Player) -> String:
	if player.spell_wait > 0.0:
		return Lang.t("Die Kraft sammelt sich noch.")
	if not player.can_act() or player.level == null:
		return ""
	var foe := player.nearest_foe(RANGE)
	var dir := player.facing()
	if foe:
		dir = foe.global_position - player.global_position
	dir.y = 0.0
	if dir.length() < 0.01:
		dir = player.facing()
	player.path.clear()
	player.face(dir)
	player.play_once("Spellcast_Shoot", 0.45)
	player.spell_wait = COOLDOWN
	player.mark_fight()
	player.train("intelligenz", 2.0)
	var bolt := ArcaneBolt.new()
	bolt.level = player.level
	bolt.target = foe
	bolt.fiery = Ignition.wants_fireball(foe)
	bolt.damage = damage_of(player)
	bolt.direction = dir.normalized()
	player.level.add_child(bolt)
	bolt.global_position = player.global_position + Vector3(0, 1.5, 0) + bolt.direction * 0.7
	Sfx.play(player, "magic", -2.0, player.global_position, 1.3)
	return ""


func _ready() -> void:
	SmoothMotion.follow_ticks(self)
	var colour := Ignition.COLOR if fiery else COLOR
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.26
	sphere.height = 0.52
	core.mesh = sphere
	core.material_override = SternParts.material(Color(0.95, 0.88, 1.0), 3.0, 1.0, true)
	add_child(core)
	var star := MeshInstance3D.new()
	star.mesh = SternParts.star_mesh(0.42, 0.18, 0.04)
	star.material_override = SternParts.material(colour, 2.5, 0.9, true)
	star.name = "Star"
	add_child(star)
	var glow := OmniLight3D.new()
	glow.light_color = colour
	glow.light_energy = 2.6
	glow.omni_range = 5.0
	add_child(glow)
	add_child(Effects.make_sparkles(colour))


func _physics_process(delta: float) -> void:
	_age += delta
	var star := get_node_or_null("Star") as Node3D
	if star:
		star.rotation.z += delta * 9.0
	if is_instance_valid(target) and not target.dead:
		var want := target.global_position - global_position
		want.y = 0.0
		if want.length() > 0.01:
			var turn := clampf(direction.signed_angle_to(want.normalized(), Vector3.UP), -TURN * delta, TURN * delta)
			direction = direction.rotated(Vector3.UP, turn)
	var was := global_position
	global_position += direction * SPEED * delta
	if _age > LIFETIME or level.is_opaque(level.world_to_cell(global_position)) or level.shot_blocked(was, global_position):
		_burst()
		return
	for e in level.enemies:
		if not is_instance_valid(e) or e.dead or e.is_friend():
			continue
		if Vector2(e.global_position.x - global_position.x, e.global_position.z - global_position.z).length() < 1.0:
			e.take_hit(damage, global_position - direction, "pierce")
			if level.player:
				level.player.mark_fight()
				if e.dead:
					level.player.train("intelligenz", 3.0)
			_burst()
			return


func _burst() -> void:
	var spark := Effects.make_sparkles(Ignition.COLOR if fiery else COLOR, true)
	spark.position = global_position
	spark.amount = 30
	level.add_child(spark)
	queue_free()
