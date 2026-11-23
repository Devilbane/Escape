class_name CandleStand
extends RefCounted
## The candle stand in the hero's house can be put out and lit again by a click (see
## HouseFurnisher.toggle_candles). The model (candle_triple.glb) is one mesh with three candles, each
## with its flame as a small piece of its own: `prepare` splits the flames off into their own mesh, so
## putting the candles out hides the flames and the light together. The state is kept in the placed
## piece under OUT (see HouseFurniture.GROWTH).

## The key of a candle stand put out, in its placed piece.
const OUT := "out"
## A piece of the model with this many triangles or fewer is a flame; a candle has 54.
const FLAME_TRIANGLES := 12
const FLAMES := "Flames"
const LIGHT := "CandleLight"

## Mesh id -> [what stays, the flames] (both ArrayMesh, or the flames null when none were found).
static var _split := {}


## Splits the flames off the model `model` and notes them and `light` on `root`. A model whose
## triangles cannot be read (a headless run has no mesh data) keeps its flames: only the light goes out.
static func prepare(root: Node3D, model: Node3D, light: Light3D) -> void:
	root.set_meta(LIGHT, light)
	for body: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if body.mesh == null:
			continue
		var parts := _parts(body.mesh)
		if parts[1] == null:
			continue
		body.mesh = parts[0]
		var flames := MeshInstance3D.new()
		flames.name = FLAMES
		flames.mesh = parts[1]
		body.add_child(flames)
		root.set_meta(FLAMES, flames)
		return


## Lights or puts out the candles of a stand prepared on `root`.
static func set_lit(root: Node3D, on: bool) -> void:
	var light = root.get_meta(LIGHT, null)
	if light is Light3D and is_instance_valid(light):
		light.visible = on
	var flames = root.get_meta(FLAMES, null)
	if flames is Node3D and is_instance_valid(flames):
		flames.visible = on


## Whether the stand on `root` burns.
static func is_lit(root: Node3D) -> bool:
	var light = root.get_meta(LIGHT, null)
	return light is Light3D and is_instance_valid(light) and light.visible


## The piece of `mesh` that stays and the flames, as [ArrayMesh, ArrayMesh]; the flames are null
## when the triangles cannot be read or the model has no small piece.
static func _parts(mesh: Mesh) -> Array:
	var id := mesh.get_instance_id()
	if _split.has(id):
		return _split[id]
	var result: Array = [mesh, null]
	if mesh.get_surface_count() > 0:
		var arrays := mesh.surface_get_arrays(0)
		var verts = arrays[Mesh.ARRAY_VERTEX] if arrays.size() > Mesh.ARRAY_VERTEX else null
		var index = arrays[Mesh.ARRAY_INDEX] if arrays.size() > Mesh.ARRAY_INDEX else null
		if verts is PackedVector3Array and index is PackedInt32Array and not verts.is_empty() and index.size() >= 3:
			result = _cut(mesh, arrays, verts, index)
	_split[id] = result
	return result


static func _cut(mesh: Mesh, arrays: Array, verts: PackedVector3Array, index: PackedInt32Array) -> Array:
	var lists := classify(verts, index)
	if lists[1].is_empty() or lists[0].is_empty():
		return [mesh, null]
	var material := mesh.surface_get_material(0)
	var parts: Array = []
	for list in lists:
		var own := arrays.duplicate()
		own[Mesh.ARRAY_INDEX] = list
		var piece := ArrayMesh.new()
		piece.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, own)
		piece.surface_set_material(0, material)
		parts.append(piece)
	return parts


## Sorts the triangles into [what stays, the flames]: triangles that share a corner are one piece, and a
## piece of FLAME_TRIANGLES or fewer is a flame.
static func classify(verts: PackedVector3Array, index: PackedInt32Array) -> Array[PackedInt32Array]:
	var up := {}
	for t in index.size() / 3:
		var first := _key(verts[index[t * 3]])
		for c in 3:
			_join(up, first, _key(verts[index[t * 3 + c]]))
	var count := {}
	for t in index.size() / 3:
		var root := _find(up, _key(verts[index[t * 3]]))
		count[root] = int(count.get(root, 0)) + 1
	var stays := PackedInt32Array()
	var burns := PackedInt32Array()
	for t in index.size() / 3:
		var small: bool = int(count[_find(up, _key(verts[index[t * 3]]))]) <= FLAME_TRIANGLES
		var into := burns if small else stays
		into.append(index[t * 3])
		into.append(index[t * 3 + 1])
		into.append(index[t * 3 + 2])
	return [stays, burns]


static func _key(v: Vector3) -> Vector3i:
	return Vector3i((v * 1000.0).round())


static func _find(up: Dictionary, k: Vector3i) -> Vector3i:
	var root := k
	while up.get(root, root) != root:
		root = up[root]
	return root


static func _join(up: Dictionary, a: Vector3i, b: Vector3i) -> void:
	var ra := _find(up, a)
	var rb := _find(up, b)
	if ra != rb:
		up[rb] = ra
	elif not up.has(ra):
		up[ra] = ra
