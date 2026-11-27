class_name HouseBallista
extends Node3D
## A ballista the hero has built on their plot (see HouseSketch.BALLISTA): a big
## crossbow on a turning post, on the ground or on a flat roof. It guards the
## house against slimes and nothing else: it turns towards the nearest slime
## within RANGE, shoots one heavy bolt, and needs RELOAD seconds to wind up the
## next one. While it is loaded, the bolt lies on its stock for all to see.
##
## A bolt never misses (it flies straight at the slime, over walls and roofs)
## and costs it BOLT_DAMAGE plus LIFE_SHARE of its whole life, so a small slime
## falls to one or two bolts and the biggest Blob to about ten: it helps a lot,
## but a siege still takes a while, and the hero is free to join in. The hits
## show as the usual red number and comic word over the slime.

const RANGE := 18.0
const RELOAD := 2.5
## How fast the bow turns (radians a second), and how close to its slime it must
## point before it shoots.
const TURN := 3.0
const AIM := 0.12
const BOLT_SPEED := 30.0
const BOLT_DAMAGE := 8
const LIFE_SHARE := 0.1
## How often it looks for a new slime (seconds).
const LOOK := 0.25
## Where the bow sits above the ballista's foot.
const BOW_HEIGHT := 1.25
## The colours of the model, before the weathering (see WeatheredProps): old
## timber, dark iron, and twisted sinew rope for the springs and the string.
const IRON := Color(0.36, 0.37, 0.4)
const ROPE := Color(0.74, 0.64, 0.48)
const SINEW := Color(0.62, 0.52, 0.38)
## Where the springs (and so the roots of the arms) sit on the head, how long
## an arm is, and how far back it is bent at rest.
const SPRING_X := 0.27
const HEAD_Z := 0.95
const ARM_LENGTH := 1.05
const ARM_REST := 0.45
## Where the string's nock rests, drawn back, behind the loaded bolt.
const NOCK_Z := -0.06
const RING_COLOR := Color(1.0, 0.55, 0.3, 0.55)
const DEMOLISH_COLOR := Color(1.0, 0.45, 0.35, 0.6)
const LEARN := "Balliste: Eine Balliste auf deinem Grundstück schießt von selbst auf jeden Schleim, der ihr zu nahe kommt (18 Meter). Ihre schweren Bolzen treffen immer und kosten einen Schleim einen Zehntel seines Lebens und mehr; nach jedem Schuss spannt sie zweieinhalb Sekunden lang nach. Andere Wesen lässt sie in Ruhe. Du planst sie im Bauplan, auf dem Boden oder auf einem Flachdach."

var level: Level
## Marked for demolition: it stands, red, and no longer shoots.
var demolish := false
## The slime it aims at now, or null.
var target: Enemy = null
## How many bolts it has shot (for the tests).
var shots := 0
var _yaw := Node3D.new()
var _bolt_on_stock: Node3D
var _arms: Array = []
var _string: Node3D
var _ring: MeshInstance3D
var _reload := 0.0
var _look := 0.0


## Whether the ballista shoots at this one: a living slime (see SlimeCoat.is_slime).
static func aims_at(e) -> bool:
	return e is Enemy and is_instance_valid(e) and not e.dead and SlimeCoat.is_slime(e) and SlimeGrowth.above(e.global_position)


## What one bolt costs a slime.
static func damage_for(e: Enemy) -> int:
	return BOLT_DAMAGE + ceili(e.max_hp() * LIFE_SHARE)


func _ready() -> void:
	_build_model()


## Shows or hides the circle of its reach on the ground round it (the blueprint
## shows it, so the hero sees what it covers).
func show_range(on: bool) -> void:
	if _ring != null:
		_ring.visible = on


func is_loaded() -> bool:
	return _reload <= 0.0


func _physics_process(delta: float) -> void:
	if demolish or level == null:
		return
	_reload = maxf(0.0, _reload - delta)
	_bolt_on_stock.visible = is_loaded()
	_look -= delta
	if _look <= 0.0 or not _in_reach(target):
		_look = LOOK
		target = nearest_slime()
	if target == null:
		return
	var to := target.global_position - global_position
	var want := atan2(to.x, to.z)
	var diff := wrapf(want - _yaw.rotation.y, -PI, PI)
	_yaw.rotation.y += clampf(diff, -TURN * delta, TURN * delta)
	if is_loaded() and absf(diff) < AIM:
		fire()


func _in_reach(e) -> bool:
	if not aims_at(e):
		return false
	var to: Vector3 = e.global_position - global_position
	return Vector2(to.x, to.z).length() <= RANGE


## The nearest living slime within RANGE, or null.
func nearest_slime() -> Enemy:
	var best: Enemy = null
	var best_d := RANGE
	for e in level.enemies:
		if not aims_at(e):
			continue
		var to: Vector3 = e.global_position - global_position
		var d := Vector2(to.x, to.z).length()
		if d <= best_d:
			best_d = d
			best = e
	return best


## Shoots the loaded bolt at the target.
func fire() -> void:
	if target == null or not is_loaded():
		return
	_reload = RELOAD
	shots += 1
	_bolt_on_stock.visible = false
	var bolt := Bolt.new()
	bolt.target = target
	bolt.damage = damage_for(target)
	bolt.from = global_position
	level.add_child(bolt)
	bolt.global_position = _bolt_on_stock.global_position
	Sfx.play(self, "bow_1", 2.0, global_position, 0.55)
	# The arms snap forward, then are wound back.
	for arm: Node3D in _arms:
		var rest: float = arm.get_meta("rest")
		var tween := arm.create_tween()
		tween.tween_property(arm, "rotation:y", rest * 0.35, 0.06)
		tween.tween_property(arm, "rotation:y", rest, RELOAD * 0.8).set_trans(Tween.TRANS_SINE)
	# The string goes taut between the tips, then is wound back to the nock.
	var shot_tip := _tip(ARM_REST * 0.35)
	var rest_tip := _tip(ARM_REST)
	var pull := create_tween().set_parallel()
	pull.tween_property(_string, "position:z", shot_tip.z, 0.06)
	pull.tween_property(_string, "scale", Vector3(shot_tip.x / rest_tip.x, 1, 0.02), 0.06)
	pull.chain().tween_property(_string, "position:z", rest_tip.z, RELOAD * 0.8).set_trans(Tween.TRANS_SINE)
	pull.tween_property(_string, "scale", Vector3.ONE, RELOAD * 0.8).set_trans(Tween.TRANS_SINE)
	if shots == 1:
		Events.teach(LEARN)


# --- The model -----------------------------------------------------------------
#
# A small siege ballista as the Romans built them: a turning post on a stone
# footing, braced by four struts on a cross of beams; on it a fork holding the
# stock, with a windlass at the back to wind it; at the front a timber head
# with two springs of twisted sinew, iron washers on their ends, and an arm
# rising out of each; the string runs from the arm tips to the nock behind the
# bolt. Every still part is one mesh in the weathered material of the village
# props (see WeatheredProps), so the timber shows its grain and the iron rust.

## Where an arm's tip is (in the turning part), turned `angle` back.
static func _tip(angle: float) -> Vector3:
	return Vector3(SPRING_X + ARM_LENGTH * cos(angle), 0.0, HEAD_Z - ARM_LENGTH * sin(angle))


func _build_model() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_build_stand(rng)
	_yaw.position = Vector3(0, BOW_HEIGHT, 0)
	add_child(_yaw)
	_build_bow(rng)
	for side in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.name = "Arm"
		arm.position = Vector3(SPRING_X * side, 0.0, HEAD_Z)
		arm.rotation.y = ARM_REST * side
		arm.set_meta("rest", arm.rotation.y)
		_yaw.add_child(arm)
		_build_arm(arm, side, rng)
		_arms.append(arm)
	_build_string()
	# The loaded bolt lies in the groove, its tail in the nock.
	_bolt_on_stock = Node3D.new()
	_bolt_on_stock.position = Vector3(0, 0.08, 0.5)
	_yaw.add_child(_bolt_on_stock)
	Bolt.dress(_bolt_on_stock)
	if demolish:
		var red := _mat(DEMOLISH_COLOR)
		for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
			mi.material_override = red
	# The reach, as a faint circle round its foot (only while the blueprint is open).
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = RANGE - 0.15
	torus.outer_radius = RANGE + 0.15
	torus.rings = 96
	_ring.mesh = torus
	_ring.scale = Vector3(1, 0.05, 1)
	_ring.position = Vector3(0, 0.08, 0)
	var ring_mat := _mat(RING_COLOR)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring.material_override = ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.visible = false
	add_child(_ring)


func _timber(rng: RandomNumberGenerator) -> Color:
	return WeatheredProps.vary(WeatheredProps.TIMBER[rng.randi() % WeatheredProps.TIMBER.size()], rng, 0.05)


## The still stand: a footing of fitted stones, a cross of beams, the post with
## its iron bands and four struts, and the iron turntable on top.
func _build_stand(rng: RandomNumberGenerator) -> void:
	var b := WeatheredProps.Builder.new()
	var st := WeatheredProps.STONE
	# Four squared stones and a cap stone, not one smooth slab.
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var c := WeatheredProps.vary(WeatheredProps.STONES[rng.randi() % WeatheredProps.STONES.size()], rng, 0.06)
		var h := 0.2 + rng.randf_range(-0.02, 0.02)
		b.frustum(Vector3(corner.x * 0.36, 0, corner.y * 0.36), Vector2(0.7, 0.7), Vector2(0.64, 0.64), h, c, st)
	b.frustum(Vector3(0, 0.18, 0), Vector2(1.08, 1.08), Vector2(1.0, 1.0), 0.08,
			WeatheredProps.vary(WeatheredProps.STONES[0], rng, 0.04), st)
	# A cross of sleepers, one laid over the other, pinned with iron.
	var dark := WeatheredProps.DARK_TIMBER
	b.box(Vector3(0, 0.26, 0), Vector3(1.5, 0.14, 0.2), _timber(rng))
	b.box(Vector3(0, 0.4, 0), Vector3(0.2, 0.14, 1.5), _timber(rng))
	for end in [Vector3(0.66, 0.4, 0), Vector3(-0.66, 0.4, 0), Vector3(0, 0.54, 0.66), Vector3(0, 0.54, -0.66)]:
		b.cylinder(end, 0.035, 0.03, 0.02, IRON, WeatheredProps.IRON, 6)
	# The post, eight-sided, with two iron bands.
	b.cylinder(Vector3(0, 0.54, 0), 0.17, 0.15, 0.44, dark, WeatheredProps.WOOD, 8)
	for y in [0.62, 0.9]:
		b.cylinder(Vector3(0, y, 0), 0.18, 0.165, 0.04, IRON, WeatheredProps.IRON, 8)
	# Four struts from the ends of the sleepers up to the post.
	for d in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var low := 0.33 if d.x != 0.0 else 0.47
		b.bar(d * 0.62 + Vector3(0, low, 0), d * 0.12 + Vector3(0, 0.84, 0), 0.045, _timber(rng), WeatheredProps.WOOD, 6)
	# The iron turntable the bow turns on.
	b.cylinder(Vector3(0, 0.98, 0), 0.25, 0.23, 0.05, IRON, WeatheredProps.IRON, 12)
	b.finish(self)


## The turning part: the fork and stock, the windlass, and the head with its
## springs, all one mesh, laid out as if it stood on the ground (see Builder.lift).
func _build_bow(rng: RandomNumberGenerator) -> void:
	var b := WeatheredProps.Builder.new()
	b.lift = Vector3(0, BOW_HEIGHT, 0)
	var dark := WeatheredProps.DARK_TIMBER
	var iron := WeatheredProps.IRON
	# The fork: a block on the turntable and two cheeks with an iron pin.
	b.box(Vector3(0, -0.22, -0.05), Vector3(0.46, 0.08, 0.42), dark)
	for side in [-1.0, 1.0]:
		b.frustum(Vector3(0.19 * side, -0.14, -0.05), Vector2(0.07, 0.4), Vector2(0.07, 0.26), 0.18, _timber(rng))
	b.bar(Vector3(-0.25, -0.06, -0.05), Vector3(0.25, -0.06, -0.05), 0.03, IRON, iron, 8)
	# The stock: a long beam with two rails forming the groove the bolt lies in.
	var stock := _timber(rng)
	b.box(Vector3(0, -0.14, 0.05), Vector3(0.22, 0.15, 1.95), stock)
	for side in [-1.0, 1.0]:
		b.box(Vector3(0.085 * side, 0.01, 0.12), Vector3(0.05, 0.035, 1.6), WeatheredProps.vary(stock, rng, 0.06))
	for z in [-0.62, -0.1, 0.55]:
		b.box(Vector3(0, -0.15, z), Vector3(0.24, 0.17, 0.05), IRON, iron)
	# The trigger claw that holds the string, and its lever under the stock.
	b.box(Vector3(0, 0.01, NOCK_Z - 0.07), Vector3(0.1, 0.07, 0.1), IRON, iron)
	b.bar(Vector3(0, -0.14, NOCK_Z - 0.04), Vector3(0, -0.32, NOCK_Z - 0.2), 0.02, IRON, iron, 6)
	# The windlass at the back: a drum wound with rope, an iron axle, and a
	# wheel of four spokes on each end.
	var wz := -0.78
	b.bar(Vector3(-0.32, -0.12, wz), Vector3(0.32, -0.12, wz), 0.025, IRON, iron, 8)
	for side in [-1.0, 1.0]:
		b.box(Vector3(0.14 * side, -0.24, wz), Vector3(0.05, 0.2, 0.14), dark)
		var hub := Vector3(0.3 * side, -0.12, wz)
		b.bar(hub - Vector3(0.03 * side, 0, 0), hub + Vector3(0.03 * side, 0, 0), 0.05, dark, WeatheredProps.WOOD, 8)
		for k in 4:
			var ang := k * PI / 4.0 + 0.3
			var dir := Vector3(0, sin(ang), cos(ang))
			b.bar(hub - dir * 0.19, hub + dir * 0.19, 0.016, _timber(rng), WeatheredProps.WOOD, 5)
	b.bar(Vector3(-0.1, -0.12, wz), Vector3(0.1, -0.12, wz), 0.05, SINEW, WeatheredProps.WOOD, 8)
	# The head: a frame of two beams and four stiles, the springs between them.
	var frame := _timber(rng)
	for y in [-0.3, 0.17]:
		b.box(Vector3(0, y, HEAD_Z), Vector3(0.98, 0.09, 0.2), WeatheredProps.vary(frame, rng, 0.05))
	for x in [-0.46, -0.11, 0.11, 0.46]:
		b.box(Vector3(x, -0.21, HEAD_Z), Vector3(0.07, 0.38, 0.17), WeatheredProps.vary(frame, rng, 0.05))
	# Iron plates on the corners of the frame.
	for x in [-0.46, 0.46]:
		for y in [-0.31, 0.16]:
			b.box(Vector3(x, y, HEAD_Z + 0.105), Vector3(0.12, 0.11, 0.01), IRON, iron)
	for side in [-1.0, 1.0]:
		var at := Vector3(SPRING_X * side, 0, HEAD_Z)
		# The spring: a thick bundle of twisted sinew, bound twice round.
		b.cylinder(at + Vector3(0, -0.36, 0), 0.075, 0.075, 0.62, SINEW, WeatheredProps.WOOD, 10)
		for y in [-0.2, 0.06]:
			b.cylinder(at + Vector3(0, y, 0), 0.082, 0.082, 0.03, ROPE, WeatheredProps.WOOD, 10)
		# An iron washer on each end, with the lever that twists it.
		for y in [0.215, -0.395]:
			b.cylinder(at + Vector3(0, y, 0), 0.1, 0.095, 0.045, IRON, iron, 12)
			b.box(at + Vector3(0, y + 0.045, 0), Vector3(0.26, 0.03, 0.04), IRON, iron)
	b.finish(_yaw, -b.lift)


## One arm: a tapering timber limb out of the spring, bound with iron where it
## leaves it and capped with iron at the tip, where the string is tied.
func _build_arm(arm: Node3D, side: float, rng: RandomNumberGenerator) -> void:
	var b := WeatheredProps.Builder.new()
	b.lift = Vector3(0, BOW_HEIGHT, 0)
	var out := Vector3(side, 0, 0)
	var along := Basis(Vector3(0, 0, 1).cross(out), out, Vector3(0, 0, 1))
	b.frustum(Vector3.ZERO, Vector2(0.09, 0.12), Vector2(0.055, 0.075), ARM_LENGTH, _timber(rng), WeatheredProps.WOOD, along)
	b.frustum(out * 0.08, Vector2(0.11, 0.14), Vector2(0.11, 0.14), 0.05, IRON, WeatheredProps.IRON, along)
	b.frustum(out * (ARM_LENGTH - 0.08), Vector2(0.07, 0.09), Vector2(0.05, 0.07), 0.1, IRON, WeatheredProps.IRON, along)
	b.finish(arm, -b.lift)


## The string, from tip to tip by way of the nock. It stands where the tips
## are, so that firing only has to slide it forward and flatten it.
func _build_string() -> void:
	_string = Node3D.new()
	_string.name = "String"
	var tip := _tip(ARM_REST)
	_string.position = Vector3(0, 0.03, tip.z)
	_yaw.add_child(_string)
	var b := WeatheredProps.Builder.new()
	b.lift = Vector3(0, BOW_HEIGHT, 0)
	var nock := Vector3(0, 0.03, NOCK_Z - tip.z)
	for side in [-1.0, 1.0]:
		b.bar(Vector3(tip.x * side, 0, 0), nock, 0.012, ROPE, WeatheredProps.WOOD, 5)
	b.finish(_string, -b.lift, false)


static func _mat(colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = 0.85
	if colour.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


## One heavy bolt in flight: it flies straight at its slime and hits it, or
## falls where the slime was when it is gone already.
class Bolt extends Node3D:
	const LIFETIME := 2.5
	var target: Enemy
	var damage := 1
	var from := Vector3.ZERO
	var _aim := Vector3.ZERO
	var _age := 0.0

	## A round ash shaft, a four-sided iron head and three leather vanes,
	## the head on +z.
	static func dress(parent: Node3D) -> void:
		var b := WeatheredProps.Builder.new()
		b.lift = Vector3(0, HouseBallista.BOW_HEIGHT, 0)
		var ahead := Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0))
		b.cylinder(Vector3(0, 0, -0.55), 0.03, 0.03, 1.02, Color(0.7, 0.56, 0.4), WeatheredProps.WOOD, 6, ahead)
		b.frustum(Vector3(0, 0, 0.44), Vector2(0.05, 0.05), Vector2(0.075, 0.075), 0.05, HouseBallista.IRON, WeatheredProps.IRON, ahead)
		b.frustum(Vector3(0, 0, 0.49), Vector2(0.075, 0.075), Vector2(0.004, 0.004), 0.17, HouseBallista.IRON, WeatheredProps.IRON, ahead)
		for k in 3:
			var ang := k * TAU / 3.0 + PI / 2.0
			var out := Vector3(cos(ang), sin(ang), 0)
			# A thin vane, so it gets a face on each side.
			for face in [1.0, -1.0]:
				b.quad(Vector3(0, 0, -0.54) + out * 0.025, Vector3(0, 0, -0.32) + out * 0.025,
						Vector3(0, 0, -0.36) + out * 0.085, Vector3(0, 0, -0.52) + out * 0.09,
						Color(0.5, 0.38, 0.26), WeatheredProps.WOOD, out.cross(Vector3(0, 0, 1)) * face)
		b.finish(parent, -b.lift, false)

	func _ready() -> void:
		dress(self)

	func _physics_process(delta: float) -> void:
		_age += delta
		if HouseBallista.aims_at(target):
			_aim = target.global_position + Vector3(0, 0.6 * SlimeGrowth.size_of(target), 0)
		var to := _aim - global_position
		var step := HouseBallista.BOLT_SPEED * delta
		if to.length() <= step or _age > LIFETIME:
			_hit()
			return
		global_position += to.normalized() * step
		look_at(global_position + to, Vector3.UP if absf(to.normalized().y) < 0.99 else Vector3.RIGHT)
		# look_at points -z at the slime; the bolt's head is on +z.
		rotate_object_local(Vector3.UP, PI)

	func _hit() -> void:
		if HouseBallista.aims_at(target):
			target.take_hit(damage, from, "pierce", false)
			Sfx.play(target, "axe_hit_0", 0.0, global_position, 0.8)
		queue_free()
