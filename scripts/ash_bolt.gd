class_name AshBolt
extends Node3D
## The hero's arcane bolt (see AshSpire.cast): a violet ball of magic energy
## that flies straight, shrugs off armour (it hurts like a blow that pierces,
## see Enemy.take_hit "pierce") and ends on the first monster or wall.

const SPEED := 17.0
const LIFETIME := 1.6
const HIT_RADIUS := 1.1
const COLOUR := Color(0.62, 0.4, 1.0)

var level: Level
var direction := Vector3.FORWARD
var damage := 4
var _age := 0.0


static func spawn(owner_level: Level, origin: Vector3, dir: Vector3, power: int) -> AshBolt:
	var b := AshBolt.new()
	b.level = owner_level
	dir.y = 0.0
	b.direction = dir.normalized()
	b.damage = power
	owner_level.add_child(b)
	b.global_position = origin
	var orb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	orb.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = COLOUR.lightened(0.35)
	orb.material_override = mat
	b.add_child(orb)
	var glow := OmniLight3D.new()
	glow.light_color = COLOUR
	glow.light_energy = 2.2
	glow.omni_range = 5.0
	b.add_child(glow)
	b.add_child(Effects.make_sparkles(COLOUR))
	return b


func _ready() -> void:
	SmoothMotion.follow_ticks(self)


func _physics_process(delta: float) -> void:
	_age += delta
	var was := global_position
	global_position += direction * SPEED * delta
	if _age > LIFETIME or level.is_opaque(level.world_to_cell(global_position)) or level.shot_blocked(was, global_position):
		queue_free()
		return
	for e in level.enemies:
		if not is_instance_valid(e) or e.dead or e.is_friend():
			continue
		if Vector2(e.global_position.x - global_position.x, e.global_position.z - global_position.z).length() < HIT_RADIUS * maxf(1.0, float(e._stats.size)):
			e.take_hit(damage, global_position - direction, "pierce")
			level.player.mark_fight()
			level.player.train("intelligenz", 0.6)
			Sfx.play(self, "magic", -4.0, global_position, 1.2)
			queue_free()
			return
