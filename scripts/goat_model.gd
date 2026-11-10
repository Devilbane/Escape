class_name GoatModel
extends RefCounted
## The village goats. They are the sheep of the Farm Animals pack (CC0, assets/animals/Sheep.glb,
## with the Walk, Gallop and Eating made for it, tools/build_sheep.gd) turned into goats: a short
## smooth coat in place of the fleece, a leaner body, horns, a beard, ears that stick out
## sideways, a short upright tail. The red-horned goat (kind "billy") has red horns.
##
## The parts are fixed to the model's bones with BoneAttachment3D, so they move with the
## animations. Sizes are in the skeleton's own space, where the whole sheep is about 0.09 long,
## so every number below is written in millimetres of that space (MM).

const MM := 0.001
const COATS := {
	# coat: body colour, the markings (the pack's black head and legs)
	"": [Color(0.86, 0.82, 0.72), Color(0.42, 0.33, 0.26)],
	"brown": [Color(0.55, 0.39, 0.26), Color(0.2, 0.14, 0.11)],
	"black": [Color(0.24, 0.22, 0.22), Color(0.1, 0.09, 0.09)],
}
const HORN := Color(0.78, 0.72, 0.58)
const HORN_RED := Color(0.85, 0.1, 0.08)
const BEARD := Color(0.93, 0.9, 0.82)
const BODY_SCALE := Vector3(0.82, 0.96, 1.0)

static var _mats := {}
static var _cones := {}


## Dresses `model` (an instance of Sheep.glb) as a goat.
static func dress(model: Node3D, coat: String, billy: bool) -> void:
	var look: Array = COATS.get(coat, COATS[""])
	var skin := _skin_mat(look[0])
	var marks := _mat(look[1])
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			if m != null:
				mi.set_surface_override_material(s, skin if m.resource_name == "White" else marks)
	var skel: Skeleton3D = model.find_child("Skeleton3D", true, false)
	_head_parts(skel, billy, marks)
	_tail(skel, look[0])
	# A leaner animal than the sheep: narrower, a little lower.
	var armature: Node3D = model.get_node("Armature")
	armature.scale *= BODY_SCALE


static func _mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.95
		_mats[key] = m
	return _mats[key]


## A short smooth coat: the colour with a little shading noise, so it is not flat.
static func _skin_mat(color: Color) -> StandardMaterial3D:
	return _mat(color)


static func _attach(skel: Skeleton3D, bone: String) -> BoneAttachment3D:
	var at := BoneAttachment3D.new()
	at.bone_name = bone
	skel.add_child(at)
	return at


## A cone of `length` mm and `width` mm across at its base, its tip along +Y of `at`.
static func _spike(at: Node3D, color: Color, from: Vector3, length: float, width: float, basis: Basis, tip := 0.0) -> Node3D:
	if not _cones.has(tip):
		var cone := CylinderMesh.new()
		cone.top_radius = 0.5 * tip
		cone.bottom_radius = 0.5
		cone.height = 1.0
		cone.radial_segments = 6
		cone.rings = 1
		_cones[tip] = cone
	var m := MeshInstance3D.new()
	m.mesh = _cones[tip]
	m.material_override = _mat(color)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var size := Vector3(width, length, width) * MM
	# A cone is centred on its middle and points up: shift it so its base sits on `from`.
	m.transform = Transform3D(basis * Basis.from_scale(size), from * MM + basis * Vector3(0, length * 0.5 * MM, 0))
	at.add_child(m)
	return m


static func _head_parts(skel: Skeleton3D, billy: bool, marks: Material) -> void:
	var head := _attach(skel, "Head")
	var horn := HORN_RED if billy else HORN
	var big := 1.3 if billy else 1.0
	for side in [1.0, -1.0]:
		var s: float = side
		# Each horn is a chain of cones, each bent further back than the one before, the way a
		# goat's horns sweep up and back. Angles: 90 is straight up, more leans back.
		_chain(head, horn, Vector3(s * 2.6, 3.0, 4.0), [[110.0, 4.0 * big, 2.8], [140.0, 3.8 * big, 2.2], [175.0, 3.4 * big, 1.5]], s)
		# Ears stick out sideways, a little down.
		var ear := _spike(head, Color(0.5, 0.4, 0.33), Vector3(s * 3.5, 2.0, 1.0), 5.0, 3.0, Basis(Vector3.BACK, -s * 1.4))
		ear.scale.y *= 0.35
	# The beard hangs from the chin.
	_spike(head, BEARD, Vector3(0, 9.0, -2.0), 5.0, 2.0, Basis(Vector3.RIGHT, -PI / 2.0 - 0.3))


## A chain of cones: each starts where the one before ends. `steps` are [angle in degrees about
## X, length mm, width mm]; the horn also leans outwards by `side`.
static func _chain(at: Node3D, color: Color, from: Vector3, steps: Array, side: float) -> void:
	var pos := from
	for step in steps:
		var a := deg_to_rad(float(step[0]))
		var turn := Basis(Vector3.BACK, -side * 0.35) * Basis(Vector3.RIGHT, a)
		var last: bool = step == steps[-1]
		_spike(at, color, pos, float(step[1]) * 1.15, float(step[2]), turn, 0.0 if last else 0.72)
		var dir := turn * Vector3(0, 1, 0)
		pos += dir * float(step[1])


static func _tail(skel: Skeleton3D, color: Color) -> void:
	var hips := _attach(skel, "Hips")
	_spike(hips, color, Vector3(0, -3.0, 1.0), 8.0, 3.6, Basis(Vector3.RIGHT, -2.2))
