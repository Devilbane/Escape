class_name FloorPack
extends StaticBody3D
## A backpack set down on the floor. It is a container of its own: the hero
## clicks it to open its window (like a storage chest), moves things in and
## out, and pushes it over the floor with E, one step at a time, like a stone.
##
## Rules:
## - It holds as many items as the same backpack gives the hero when worn
##   (Items.bag_size), stacked the same way (Items.slots_used / Items.fits).
## - No backpack goes into a backpack: nothing can be put inside itself, and
##   no loop of packs can form.
## - The contents stay in the pack on the floor. It can only be picked up
##   again when it is empty (an item in the bag has no room for contents), so
##   nothing is duplicated or lost on the way.
## - It is one entry on the level's floor list (see Level.floor_items):
##   ["pack", backpack id, x, z, contents]. The list is part of the saved game,
##   and a floor entry of this kind is never swept away: not by the dragon's
##   helpers (they take items and coins only) and not when the list is full
##   (see Level._remember_on_floor). Monsters and villagers cannot move it or
##   take anything out of it.

## The kind of the floor entry.
const KIND := "pack"
## How far from the hero's middle a pack can be opened or pushed (metres).
const REACH := 2.4
## How far one push moves it, and how long that takes.
const PUSH_STEP := 0.8
const PUSH_TIME := 0.22
## The size of the pack's solid box.
const BOX := Vector3(0.7, 0.6, 0.7)
const MODEL := "res://assets/village/sack.gltf"

var entry: Array = []
var model: Node3D
var _push_tween: Tween


func _ready() -> void:
	add_to_group("floor_pack")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = BOX
	shape.shape = box
	shape.position.y = BOX.y * 0.5
	add_child(shape)
	model = make_model(backpack())
	add_child(model)
	position = Vector3(float(entry[2]), 0.0, float(entry[3]))


func backpack() -> String:
	return str(entry[1])


## The things in the pack (the list in the floor entry itself, changed in place).
func contents() -> Array:
	return entry[4]


func capacity() -> int:
	return Items.bag_size(backpack())


func used() -> int:
	return Items.slots_used(contents())


func is_empty() -> bool:
	return contents().is_empty()


## Whether one more `id` can go in: not a backpack, and a slot or a bundle has room.
func accepts(id: String) -> bool:
	return Items.ALL.has(id) and not Items.is_backpack(id) and Items.fits(contents(), capacity(), id)


## Why `id` cannot go in, "" when it can.
func why_not(id: String) -> String:
	if Items.is_backpack(id):
		return Lang.t("Ein Rucksack passt nicht in einen Rucksack.")
	if not accepts(id):
		return Lang.t("Der Rucksack ist voll.")
	return ""


## Slides the pack `step` metres to the new spot (its entry is changed at once).
func slide_to(spot: Vector3) -> void:
	entry[2] = snappedf(spot.x, 0.01)
	entry[3] = snappedf(spot.z, 0.01)
	if _push_tween != null and _push_tween.is_valid():
		_push_tween.kill()
	_push_tween = create_tween()
	_push_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_push_tween.tween_property(self, "position", Vector3(spot.x, 0.0, spot.z), PUSH_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# --- The floor entry ---------------------------------------------------------

## A new entry for a pack of this kind of backpack with nothing in it.
static func new_entry(id: String, pos: Vector3) -> Array:
	return [KIND, id, snappedf(pos.x, 0.01), snappedf(pos.z, 0.01), []]


## Whether a floor entry is a pack ([KIND, id, x, z, contents]).
static func is_pack(entry) -> bool:
	return entry is Array and entry.size() >= 5 and str(entry[0]) == KIND and entry[4] is Array \
			and Items.ALL.has(str(entry[1])) and Items.is_backpack(str(entry[1]))


## Makes a pack entry from the saved game safe: only known items that are not
## backpacks stay in it, no more than it holds (what does not fit is dropped
## from the end), numbers are numbers. An entry that is not a pack stays as it is.
static func clean(entry: Array) -> void:
	if not is_pack(entry):
		return
	var kept: Array = []
	var room := Items.bag_size(str(entry[1]))
	for id in entry[4]:
		var s := str(id)
		if Items.ALL.has(s) and not Items.is_backpack(s) and Items.fits(kept, room, s):
			kept.append(s)
	entry[4] = kept


# --- Look ----------------------------------------------------------------------

## The sack of that backpack, as wide as its size says, standing on the floor.
static func make_model(id: String) -> Node3D:
	var scene: Node3D = load(MODEL).instantiate()
	var box := AABB()
	var first := true
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var part: AABB = Crate._transform_to(scene, mi) * (mi as MeshInstance3D).mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	var holder := Node3D.new()
	var wide := maxf(box.size.x, box.size.z)
	if wide > 0.0:
		var width := 0.6 + 0.02 * float(Items.bag_size(id))
		var s := width / wide
		scene.scale = Vector3.ONE * s
		var middle := box.get_center()
		scene.position = Vector3(-middle.x * s, -box.position.y * s, -middle.z * s)
	holder.add_child(scene)
	return holder
