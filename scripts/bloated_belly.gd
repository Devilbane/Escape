class_name BloatedBelly
extends RefCounted
## Too much water from the village fountain: whoever takes more than SIPS
## sips in a row, each within SIP_GAP seconds of the last, gets a belly
## swollen like a full waterskin for TIME seconds and walks at SLOW of their
## speed (Player.bloat). It is a passing trouble with its own icon and a
## countdown under the life bar (Game.hero_ailments), and nothing cures it:
## not more water, not a shrine, not a potion. It only goes down with time.
##
## One counter per game (Game.belly_sips) counts the sips; the hero's body
## mesh gets the swollen belly from swell().

## The ailment's key in Player.ailments.
const KIND := "bauch"
## This many sips in a row are still fine; the next one is too much.
const SIPS := 10
## A sip counts as "in a row" when it comes this soon after the last one.
const SIP_GAP := 2.5
## One sip takes this long: running on against the fountain gives no new sip
## before it is drunk (else holding a key against it would gulp every frame).
const SIP_TIME := 0.6
## How long the belly stays swollen, in seconds (three minutes).
const TIME := 180.0
## The share of the speed left while swollen: a heavy waddle, not a stop.
const SLOW := 0.3
## What the hero says when it happens (German, translated through Lang).
const LINES := [
	"Ich glaube, das war ein bisschen zu viel!",
	"Uff ... da passt kein Tropfen mehr rein.",
	"Ich gluckere bei jedem Schritt!",
]

## The belly's shape, in the body mesh's space (the model's own, before the
## woman's reshaping): how far it comes out at its fullest, at what height,
## and how far it reaches up, down and to the sides.
const OUT := 0.34
const HEIGHT := 0.72
const ABOVE := 0.22
const BELOW := 0.2
const WIDE := 0.3
## The sides swell a little too, so it is round and not a cone.
const SIDES := 0.28
## The front of the torso has few vertices around the belly: the triangles in
## this box are split into finer ones first (see BodyLook._refined).
const BELLY_BOX := AABB(Vector3(-0.5, 0.42, -0.1), Vector3(1.0, 0.63, 0.6))
const REFINE := 2

## Seconds of the last sip, and how many came in a row.
var _last := -INF
var count := 0

## Swollen meshes by the plain mesh they were made from, and back.
static var _swollen := {}
static var _plain := {}


## One sip at the time `now` (in seconds). Returns true when it is one too
## many: the count starts again from nothing then.
func sip(now: float) -> bool:
	count = count + 1 if now - _last <= SIP_GAP else 1
	_last = now
	if count > SIPS:
		count = 0
		return true
	return false


## Whether a sip at `now` comes too soon after the last one to be a new sip.
func still_drinking(now: float) -> bool:
	return now - _last < SIP_TIME


## Seconds left, short enough for an icon's corner: whole minutes ("3m")
## while more than a minute is left, then the seconds ("45").
static func countdown(seconds: float) -> String:
	var left := ceili(maxf(0.0, seconds))
	return "%dm" % ceili(left / 60.0) if left > 60 else str(left)


## Seconds left as minutes and seconds ("2:05"), for the icon's explanation.
static func long_countdown(seconds: float) -> String:
	var left := ceili(maxf(0.0, seconds))
	return "%d:%02d" % [left / 60, left % 60]


## A random line for the hero to say, translated.
static func line() -> String:
	return Lang.t(LINES[randi() % LINES.size()])


## Swells the belly of a Rogue model's body, or lets it go down again. Safe
## to call any number of times, and after BodyLook or GearLook gave the body
## a new mesh: the swollen one is always made from the plain one now worn.
static func swell(model: Node3D, on: bool) -> void:
	if model == null:
		return
	var mi := model.find_child("Rogue_Body", true, false) as MeshInstance3D
	if mi == null or mi.mesh == null:
		return
	if _plain.has(mi.mesh):
		if on:
			return
		mi.mesh = _plain[mi.mesh]
	elif on:
		mi.mesh = swollen(mi.mesh)


## Whether a model's belly is swollen right now.
static func is_swollen(model: Node3D) -> bool:
	if model == null:
		return false
	var mi := model.find_child("Rogue_Body", true, false) as MeshInstance3D
	return mi != null and _plain.has(mi.mesh)


## The swollen copy of a body mesh, built once. The skinning stays as it is,
## so the belly follows every animation; rest positions (GearLook's grain)
## are kept from the plain shape.
static func swollen(plain: Mesh) -> Mesh:
	if _swollen.has(plain):
		return _swollen[plain]
	var arrays := plain.surface_get_arrays(0)
	var had_rest: bool = arrays[Mesh.ARRAY_CUSTOM0] != null
	arrays[Mesh.ARRAY_CUSTOM0] = null
	for i in REFINE:
		arrays = BodyLook._refined(arrays, BELLY_BOX)
	var verts: PackedVector3Array = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
	var normals: PackedVector3Array = (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).duplicate()
	var flags := 0
	if had_rest:
		var rest := PackedFloat32Array()
		rest.resize(verts.size() * 3)
		for v in verts.size():
			rest[v * 3] = verts[v].x
			rest[v * 3 + 1] = verts[v].y
			rest[v * 3 + 2] = verts[v].z
		arrays[Mesh.ARRAY_CUSTOM0] = rest
		flags |= Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	for v in verts.size():
		normals[v] = _normal(verts[v], normals[v])
		verts[v] = _shape(verts[v])
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	if plain is ArrayMesh and (plain as ArrayMesh).surface_get_format(0) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS:
		flags |= Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	mesh.surface_set_material(0, plain.surface_get_material(0))
	_swollen[plain] = mesh
	_plain[mesh] = plain
	return mesh


## How much the belly fills out at a height (0 to 1): a soft round bulge.
static func _fill(y: float) -> float:
	var dy := y - HEIGHT
	return exp(-pow(dy / (ABOVE if dy > 0.0 else BELOW), 2.0))


## How far the front comes out at a point. It depends on the position alone,
## so vertices that share a position (along the texture's seams) move
## together and no gap opens.
static func _bulge(p: Vector3) -> float:
	if p.z <= -0.05:
		return 0.0
	var side := exp(-pow(p.x / WIDE, 2.0))
	return OUT * _fill(p.y) * side * smoothstep(-0.05, 0.2, p.z)


static func _shape(p: Vector3) -> Vector3:
	var q := p
	q.x *= 1.0 + SIDES * _fill(p.y)
	q.z += _bulge(p)
	return q


## A front-facing normal tilted by the slope of the belly, so it catches the
## light like the round shape it is.
static func _normal(p: Vector3, n: Vector3) -> Vector3:
	if n.z < 0.2:
		return n
	var e := 0.005
	var dx := (_bulge(p + Vector3(e, 0, 0)) - _bulge(p - Vector3(e, 0, 0))) / (2.0 * e)
	var dy := (_bulge(p + Vector3(0, e, 0)) - _bulge(p - Vector3(0, e, 0))) / (2.0 * e)
	if dx == 0.0 and dy == 0.0:
		return n
	return (n / n.z - Vector3(dx, dy, 0.0)).normalized()
