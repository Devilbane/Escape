class_name HandLamp
extends RefCounted
## The hand lantern some villagers carry at night instead of a torch: a candle in a little iron
## cage on a short bail, hung from the hand (no glass, so no new shader: the flame is the same as
## the torches' and the lanterns'). It stays upright whichever way the wrist turns (see hanging).

## The candle's light: a shade paler than a torch's.
const COLOR := Color(1.0, 0.72, 0.38)
## Where the flame burns, in the lamp's own space (the origin is the hand).
const FLAME_AT := Vector3(0, -0.22, 0)

static var _iron: StandardMaterial3D


## Builds the lamp under `parent`, hanging below its origin.
static func build(parent: Node3D) -> void:
	var cap := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.02
	cone.bottom_radius = 0.085
	cone.height = 0.06
	cap.mesh = cone
	cap.position = Vector3(0, -0.1, 0)
	_add(parent, cap)
	var base := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.08
	disc.bottom_radius = 0.07
	disc.height = 0.03
	base.mesh = disc
	base.position = Vector3(0, -0.34, 0)
	_add(parent, base)
	var bail := MeshInstance3D.new()
	var rod := CylinderMesh.new()
	rod.top_radius = 0.01
	rod.bottom_radius = 0.01
	rod.height = 0.1
	bail.mesh = rod
	bail.position = Vector3(0, -0.04, 0)
	_add(parent, bail)
	for k in 4:
		var post := MeshInstance3D.new()
		var bar := BoxMesh.new()
		bar.size = Vector3(0.016, 0.2, 0.016)
		post.mesh = bar
		var a := k * TAU / 4.0 + PI / 4.0
		post.position = Vector3(cos(a) * 0.065, -0.22, sin(a) * 0.065)
		_add(parent, post)
	var flame := Effects.make_flame()
	flame.scale = Vector3.ONE * 0.28
	# The flame's sparks ride with the lamp. In world space they are left behind while the bearer
	# walks and smear into a big blaze.
	flame.local_coords = true
	flame.position = FLAME_AT + Vector3(0, -0.03, 0)
	parent.add_child(flame)


## The turn of a lamp hanging from a hand: facing the way its bearer does (`yaw`), upright in
## the world, swaying a little (`time` in seconds), at the bearer's scale.
static func hanging(yaw: float, size: float, time: float) -> Basis:
	return Basis.from_euler(Vector3(0.07 * sin(time * 3.1), yaw, 0.05 * sin(time * 2.3 + 1.0))).scaled(Vector3.ONE * size)


## The turn of a torch held out in front: its flame always up in the world, however the arm is
## raised, leaning a little away from its bearer (`yaw` is the way the bearer faces).
static func held_up(yaw: float, size: float) -> Basis:
	return Basis.from_euler(Vector3(0.12, yaw, 0.0)).scaled(Vector3.ONE * size)


static func _add(parent: Node3D, part: MeshInstance3D) -> void:
	if _iron == null:
		_iron = StandardMaterial3D.new()
		_iron.albedo_color = Color(0.16, 0.15, 0.15)
		_iron.metallic = 0.5
		_iron.roughness = 0.6
	part.material_override = _iron
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
