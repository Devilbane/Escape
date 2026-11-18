class_name Snowball
extends Node3D
## A snowball thrown in play (see KidPlay): a small white ball that flies in an arc from the
## thrower's hand to the target and bursts into a puff of snow. It follows the target as it
## flies, so a hit lands where the target really is; a throw meant to miss lands beside it.
## Somebody grown up who is hit grumbles about it (see HIT_LINES); nobody is hurt.

## How fast the ball flies (metres per second), and how high its arc rises per metre thrown.
const SPEED := 9.0
const ARC := 0.12
## The grumbles of a grown-up who is hit (German, translated by Lang).
const HIT_LINES := [
	"He! Das ist kalt!",
	"Pip! Pippi! Wartet nur!",
	"Mitten in den Nacken...",
	"Kinder! Nicht auf die Erwachsenen!",
	"Na wartet, ihr zwei!",
]

var target: Node3D
var thrower: Node3D
var world: Node3D
var _from := Vector3.ZERO
var _miss := Vector3.ZERO
var _time := 0.0
var _flight := 0.5


## Throws a ball from `from` at `at` (a body), and adds it to `level`. With `miss` true it lands
## beside the target.
static func throw(level: Node3D, from: Vector3, at: Node3D, by: Node3D, miss := false) -> Snowball:
	var ball := Snowball.new()
	ball.world = level
	ball.target = at
	ball.thrower = by
	ball.set_meta("no_snow", true)
	level.add_child(ball)
	ball._launch(from, miss)
	return ball


func _launch(from: Vector3, miss: bool) -> void:
	_from = from
	if miss:
		var side := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		_miss = side * randf_range(0.8, 1.4)
	var mesh := SphereMesh.new()
	mesh.radius = 0.07
	mesh.height = 0.14
	mesh.radial_segments = 10
	mesh.rings = 6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.97, 1.0)
	mat.roughness = 0.9
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	global_position = from
	reset_physics_interpolation()
	_flight = clampf(_aim().distance_to(from) / SPEED, 0.3, 1.0)


## Where the ball is headed now: the target's chest, or the ground beside it on a miss.
func _aim() -> Vector3:
	if target == null or not is_instance_valid(target):
		return _from + Vector3(0, -1.0, 2.0)
	var chest := target.global_position + Vector3(0, 0.9 * _size_of(target), 0)
	if _miss != Vector3.ZERO:
		return target.global_position + _miss + Vector3(0, 0.05, 0)
	return chest


func _ready() -> void:
	SmoothMotion.follow_ticks(self)


static func _size_of(body: Node3D) -> float:
	if body is Villager and (body as Villager)._model != null:
		return (body as Villager)._model.scale.x
	return 1.0


func _physics_process(delta: float) -> void:
	_time += delta
	var t := clampf(_time / _flight, 0.0, 1.0)
	var to := _aim()
	var rise := _from.distance_to(to) * ARC * 4.0 * t * (1.0 - t)
	global_position = _from.lerp(to, t) + Vector3(0, rise, 0)
	if t >= 1.0:
		_burst()


## The ball bursts into snow where it lands; a grown-up who is hit grumbles.
func _burst() -> void:
	Snowball.puff(world, global_position)
	Sfx.play(self, "step_grass_%d" % (randi() % 6), -10.0, global_position, 1.4)
	if _miss == Vector3.ZERO and target is Villager and is_instance_valid(target):
		var hit := target as Villager
		if hit._info.get("pal", "") == "" and hit.chat_partner == null and not hit.night:
			var line: String = HIT_LINES[randi() % HIT_LINES.size()]
			hit.say(Lang.t(line), thrower.global_position if is_instance_valid(thrower) else Vector3.INF, 2.5)
	queue_free()


## A burst of snow at `at`: white crumbs that fly out and fall. It frees itself.
static func puff(world: Node3D, at: Vector3) -> void:
	if world == null or not world.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.amount = 14
	p.lifetime = 0.7
	p.one_shot = true
	p.explosiveness = 0.95
	p.local_coords = false
	var quad := QuadMesh.new()
	quad.size = Vector2(0.07, 0.07)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = Effects._soft_dot()
	quad.material = mat
	p.mesh = quad
	p.direction = Vector3.UP
	p.spread = 70.0
	p.gravity = Vector3(0, -7.0, 0)
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 2.6
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var fade := Gradient.new()
	fade.set_color(0, Color(0.96, 0.97, 1.0, 1.0))
	fade.set_color(1, Color(0.96, 0.97, 1.0, 0.0))
	p.color_ramp = fade
	p.set_meta("no_snow", true)
	world.add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)
