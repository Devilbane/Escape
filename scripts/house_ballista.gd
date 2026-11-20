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
const WOOD := Color(0.45, 0.3, 0.16)
const DARK_WOOD := Color(0.3, 0.2, 0.1)
const STONE := Color(0.5, 0.48, 0.44)
const IRON := Color(0.32, 0.33, 0.36)
const STRING := Color(0.85, 0.8, 0.65)
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
var _ring: MeshInstance3D
var _reload := 0.0
var _look := 0.0


## Whether the ballista shoots at this one: a living slime (see SlimeCoat.is_slime).
static func aims_at(e) -> bool:
	return e is Enemy and is_instance_valid(e) and not e.dead and SlimeCoat.is_slime(e)


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
	if shots == 1:
		Events.teach(LEARN)


# --- The model -----------------------------------------------------------------

func _build_model() -> void:
	var stone := _mat(DEMOLISH_COLOR if demolish else STONE)
	var wood := _mat(DEMOLISH_COLOR if demolish else WOOD)
	var dark := _mat(DEMOLISH_COLOR if demolish else DARK_WOOD)
	var iron := _mat(DEMOLISH_COLOR if demolish else IRON)
	# A low stone plinth and a thick post it turns on.
	_box(self, Vector3(0, 0.15, 0), Vector3(1.5, 0.3, 1.5), stone)
	_box(self, Vector3(0, 0.65, 0), Vector3(0.35, 0.7, 0.35), dark)
	_yaw.position = Vector3(0, BOW_HEIGHT, 0)
	add_child(_yaw)
	# The stock points along +z, the way the yaw faces.
	_box(_yaw, Vector3(0, -0.1, 0.1), Vector3(0.28, 0.22, 2.0), wood)
	_box(_yaw, Vector3(0, -0.28, -0.6), Vector3(0.5, 0.18, 0.4), dark)
	_box(_yaw, Vector3(0, 0.0, 1.0), Vector3(0.36, 0.3, 0.2), iron)
	# Two bow arms bent back from the head, and the string between their tips.
	for side in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(0.18 * side, 0.0, 0.95)
		arm.rotation.y = 0.45 * side
		arm.set_meta("rest", arm.rotation.y)
		_yaw.add_child(arm)
		_box(arm, Vector3(0.6 * side, 0, 0), Vector3(1.2, 0.12, 0.14), wood)
		_box(arm, Vector3(1.2 * side, 0, 0), Vector3(0.1, 0.16, 0.16), iron)
		_arms.append(arm)
	var string := _box(_yaw, Vector3(0, 0.02, 0.1), Vector3(2.0, 0.03, 0.03), _mat(STRING))
	string.name = "String"
	# The loaded bolt: a shaft with an iron head and fletching.
	_bolt_on_stock = Node3D.new()
	_bolt_on_stock.position = Vector3(0, 0.08, 0.5)
	_yaw.add_child(_bolt_on_stock)
	Bolt.dress(_bolt_on_stock)
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


static func _box(parent: Node3D, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat
	m.position = at
	parent.add_child(m)
	return m


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

	static func dress(parent: Node3D) -> void:
		HouseBallista._box(parent, Vector3(0, 0, 0), Vector3(0.07, 0.07, 1.1), HouseBallista._mat(Color(0.55, 0.4, 0.22)))
		HouseBallista._box(parent, Vector3(0, 0, 0.6), Vector3(0.14, 0.14, 0.18), HouseBallista._mat(HouseBallista.IRON))
		HouseBallista._box(parent, Vector3(0, 0, -0.5), Vector3(0.22, 0.02, 0.16), HouseBallista._mat(Color(0.9, 0.88, 0.8)))

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
