class_name GroundItem
extends RefCounted
## What an item looks like lying on the floor, once the hero drops it or a foe
## leaves it: a small low-poly thing resting flat on the ground, not a glowing
## bubble. Items with a model of their own (swords, axes, shields, daggers,
## sacks, the water bucket) lie down in that model; everything else is put
## together here from boxes, cylinders and balls in worn, winter-village colours
## (see build). Anything this file does not know gets a leather pouch.
##
## Stackable things (see Items.STACK, Items.STACK_SLOTS) show how many lie
## together: the nth one of a kind dropped close to the others is laid beside
## them, then on top of them, so a few torches look like a few and a dozen like
## a heap (see slot).

## Items that keep standing as they are made (a bucket does not lie on its side).
const UPRIGHT := ["wassereimer", "leinenrucksack", "lederrucksack", "grosser_rucksack", "reiserucksack", "tornister", "mehlsack"]
## How close together two things of one kind must lie to count as one pile.
## How much smaller an item's own model is drawn lying down than when held.
const LIE_SCALE := 0.7
## The longest side of anything lying on the floor.
const MAX_SIZE := 0.95
const PILE_RADIUS := 0.9
## A pile grows this many layers high and no more.
const MAX_LAYERS := 3

const WOOD := Color(0.5, 0.33, 0.17)
const DARK_WOOD := Color(0.33, 0.21, 0.11)
const LEATHER := Color(0.45, 0.28, 0.14)
const STEEL := Color(0.62, 0.64, 0.68)
const GOLD := Color(0.9, 0.7, 0.25)
const PARCHMENT := Color(0.86, 0.78, 0.6)
const CLOTH := Color(0.62, 0.52, 0.38)
const BONE := Color(0.85, 0.82, 0.7)
const STONE := Color(0.5, 0.5, 0.48)

const GEMS := {"kraft": Color(0.85, 0.2, 0.15), "leben": Color(0.3, 0.8, 0.35), "tempo": Color(0.3, 0.55, 0.95),
		"kristall": Color(0.5, 0.9, 1.0), "glutherz": Color(1.0, 0.5, 0.15), "stern": Color(0.7, 0.55, 1.0),
		"schild": Color(0.7, 0.75, 0.85), "schatten": Color(0.4, 0.3, 0.6), "ruby": Color(0.8, 0.1, 0.2),
		"rubin": Color(0.8, 0.1, 0.2), "drachenblut": Color(0.7, 0.05, 0.1), "siegel": Color(0.75, 0.15, 0.15),
		"kompass": Color(0.4, 0.8, 0.9), "karawane": Color(0.3, 0.7, 0.55)}
const BOOKS := {"fechtbuch": Color(0.32, 0.4, 0.6), "axtbuch": Color(0.5, 0.3, 0.15), "wurfbuch": Color(0.25, 0.5, 0.3),
		"schildbuch": Color(0.6, 0.2, 0.18), "ruestbuch": Color(0.4, 0.4, 0.45), "schleichbuch": Color(0.25, 0.2, 0.35),
		"foliant_der_kraft": Color(0.45, 0.2, 0.6)}


## Whether several of this kind show as a pile.
static func stacks(id: String) -> bool:
	if not Items.ALL.has(id):
		return false
	return Items.STACK.has(id) or Items.STACK_SLOTS.has(str(Items.ALL[id].slot))


## The look of `id` lying on the floor, its middle on the origin, its underside
## on y = 0. `index` is how many of its kind already lie in the pile (0 for a
## lone one): it sets where in the pile this one lies.
static func build(id: String, index := 0) -> Node3D:
	var holder := Node3D.new()
	var model := _model(id)
	var box := _bounds(model)
	_ground(model, box)
	# The model sits centred in a pivot, which is what a pile moves and turns.
	var pivot := Node3D.new()
	pivot.add_child(model)
	holder.add_child(pivot)
	if index > 0 and stacks(id):
		var spot := slot(index, box.size)
		pivot.position = spot.offset
		pivot.rotation.y = spot.yaw
	return holder


## Where the `index`th of a pile goes (the lone first one is at 0): the first
## four lie side by side, the next ones on top of them, in turning rows.
static func slot(index: int, size: Vector3) -> Dictionary:
	var spread := maxf(size.x, size.z) * 0.85 + 0.04
	var layer := mini(floori(index / 4.0), MAX_LAYERS)
	var corners := [Vector2(0, 0), Vector2(1, 0), Vector2(-0.5, 0.87), Vector2(-0.5, -0.87)]
	var corner: Vector2 = corners[index % 4]
	var turn := layer * 0.9
	var at := corner.rotated(turn) * spread
	return {"offset": Vector3(at.x, layer * size.y * 0.8, at.y), "yaw": turn + index * 0.7}


# --- The model of one thing ------------------------------------------------------

static func _model(id: String) -> Node3D:
	if not Items.ALL.has(id):
		return _pouch()
	var item: Dictionary = Items.ALL[id]
	if item.has("model"):
		return _gltf(id, item)
	var tint: Color = item.get("tint", Color(0, 0, 0, 0))
	var made: Node3D = null
	if id.begins_with("kletter") and not str(item.slot) in ["schuhe", "handschuhe"]:
		return _climbing(id)
	match str(item.slot):
		"kopf":
			made = _helmet(id, item, tint)
		"umhang":
			made = _cloak(tint)
		"ruestung":
			made = _armour(item, tint)
		"schuhe":
			made = _boots(item, tint)
		"handschuhe":
			made = _gloves(item, tint)
		"amulett":
			made = _amulet(id)
		"ring":
			made = _ring(id)
		"armreif":
			made = _bracelet(id)
		"spezial":
			made = _special(id)
		"rolle":
			made = _scroll()
		"buch":
			made = _book(id)
		"kiste":
			made = _crate()
		"stein":
			made = _timber() if id == "bauholz" else _stone_block()
		"auftrag":
			made = _errand(id)
		"erz":
			made = _ore(tint)
		"futter":
			made = _feed(id)
		"licht":
			made = _torch()
		"rast":
			made = _bedroll()
		"trank":
			made = _potion(tint)
	return made if made != null else _pouch()


## An item with a model of its own, laid down: the thinnest way of the model
## points up, so a blade, an axe or a shield rests on its flat side.
static func _gltf(id: String, item: Dictionary) -> Node3D:
	var holder := Node3D.new()
	var model: Node3D = load(str(item.model)).instantiate()
	# A little smaller than held up, so a shield on the floor is a shield, not a table.
	model.scale = Vector3.ONE * float(item.get("model_scale", 1.6)) * LIE_SCALE
	if id == Items.KNIFE or id == "banditendolch":
		model.scale = Vector3.ONE * 0.8
	holder.add_child(model)
	var box := _bounds(holder)
	# Nothing on the floor is longer than a stride.
	if maxf(box.size.x, maxf(box.size.y, box.size.z)) > MAX_SIZE:
		model.scale *= MAX_SIZE / maxf(box.size.x, maxf(box.size.y, box.size.z))
		box = _bounds(holder)
	if id in UPRIGHT:
		return holder
	var s := box.size
	if s.x <= s.y and s.x <= s.z and s.x < s.y * 0.8:
		model.rotation.z = PI * 0.5
	elif s.z <= s.y and s.z <= s.x and s.z < s.y * 0.8:
		model.rotation.x = PI * 0.5
	elif s.z < s.x * 0.8 and s.z < s.y * 0.8:
		model.rotation.x = PI * 0.5
	holder.rotation.y = 0.5
	return holder


static func _helmet(id: String, item: Dictionary, tint: Color) -> Node3D:
	var n := Node3D.new()
	var kind := str(item.get("hat", ["", ""])[1]) if item.has("hat") else ""
	var base := _by_material(str(item.get("material", "metal")), tint)
	var metal := 0.5 if str(item.get("material", "")) in ["metal", "scale"] else 0.0
	if kind == "Mage_Hat":
		_cyl(n, 0.0, 0.17, 0.42, Vector3(0, 0.13, 0), Color(0.25, 0.22, 0.5), Vector3(0, 0, 80))
		_cyl(n, 0.3, 0.3, 0.025, Vector3(-0.14, 0.02, 0), Color(0.22, 0.2, 0.45))
		return n
	if kind == "Skeleton_Rogue_Hood":
		_ball(n, 0.17, Vector3(0, 0.12, 0), base, Vector3(1, 0.8, 1.1))
		_cyl(n, 0.12, 0.17, 0.12, Vector3(0, 0.05, 0.1), base.darkened(0.2), Vector3(70, 0, 0))
		return n
	_ball(n, 0.18, Vector3(0, 0.15, 0), base, Vector3(1, 0.9, 1.1), metal)
	_cyl(n, 0.16, 0.16, 0.02, Vector3(0.04, 0.15, 0.0), Color(0.07, 0.06, 0.06), Vector3(0, 0, 90)).position.x = 0.16
	if kind == "Knight_Helmet" or str(item.get("material", "")) in ["metal", "scale"]:
		_box(n, Vector3(0.03, 0.02, 0.2), Vector3(0.0, 0.325, 0), base.lightened(0.15), Vector3.ZERO, metal)
		_box(n, Vector3(0.04, 0.2, 0.02), Vector3(0.17, 0.16, 0), base.darkened(0.35), Vector3.ZERO, metal)
	elif kind == "Barbarian_Hat":
		_cone_horn(n, Vector3(0.0, 0.3, 0.14), 20)
		_cone_horn(n, Vector3(0.0, 0.3, -0.14), -20)
	elif kind == "Skeleton_Warrior_Helmet":
		_box(n, Vector3(0.02, 0.1, 0.1), Vector3(0.16, 0.12, 0), Color(0.12, 0.1, 0.09))
	return n


static func _cone_horn(parent: Node3D, pos: Vector3, lean: float) -> void:
	_cyl(parent, 0.0, 0.03, 0.14, pos, BONE, Vector3(lean, 0, 0))


static func _cloak(tint: Color) -> Node3D:
	var n := Node3D.new()
	var c := tint if tint.a > 0.0 else CLOTH
	_box(n, Vector3(0.5, 0.05, 0.4), Vector3(0, 0.025, 0), c.darkened(0.15), Vector3(0, 8, 0))
	_box(n, Vector3(0.42, 0.05, 0.3), Vector3(0.03, 0.07, 0.02), c, Vector3(0, -12, 3))
	_box(n, Vector3(0.18, 0.06, 0.12), Vector3(-0.16, 0.115, 0.0), c.lightened(0.1), Vector3(0, 20, 0))
	_ball(n, 0.03, Vector3(-0.2, 0.15, 0.04), GOLD, Vector3.ONE, 0.6)
	return n


static func _armour(item: Dictionary, tint: Color) -> Node3D:
	var n := Node3D.new()
	var c := tint if tint.a > 0.0 else LEATHER
	var metal := float(item.get("metal", 0.0)) + (0.3 if str(item.get("material", "")) == "metal" else 0.0)
	_box(n, Vector3(0.42, 0.09, 0.4), Vector3(0, 0.045, 0), c, Vector3.ZERO, metal)
	for side in [-1.0, 1.0]:
		_box(n, Vector3(0.16, 0.08, 0.18), Vector3(0.0, 0.13, side * 0.26), c.darkened(0.1), Vector3(side * 12, 0, 0), metal)
		_box(n, Vector3(0.1, 0.1, 0.16), Vector3(0.0, 0.1, side * 0.35), c.darkened(0.2), Vector3(side * 30, 0, 0), metal)
	_cyl(n, 0.09, 0.09, 0.012, Vector3(0.17, 0.095, 0), Color(0.08, 0.07, 0.07))
	_box(n, Vector3(0.36, 0.02, 0.05), Vector3(0, 0.1, 0), c.lightened(0.15), Vector3.ZERO, metal)
	if str(item.get("material", "")) == "scale":
		for i in 5:
			_ball(n, 0.05, Vector3(-0.1 + i * 0.05, 0.11, (i % 2) * 0.1 - 0.05), c.lightened(0.2), Vector3(1, 0.4, 1), 0.5)
	return n


static func _boots(item: Dictionary, tint: Color) -> Node3D:
	var n := Node3D.new()
	var c := tint if tint.a > 0.0 else LEATHER
	var metal := float(item.get("metal", 0.0)) + (0.3 if str(item.get("material", "")) == "metal" else 0.0)
	for i in 2:
		var b := Node3D.new()
		b.position = Vector3(0.0, 0.0, -0.1 + i * 0.2)
		b.rotation.y = -0.15 + i * 0.3
		n.add_child(b)
		_box(b, Vector3(0.3, 0.05, 0.12), Vector3(0.04, 0.025, 0), c.darkened(0.3), Vector3.ZERO, metal)
		_box(b, Vector3(0.14, 0.2, 0.11), Vector3(-0.07, 0.125, 0), c, Vector3.ZERO, metal)
		_box(b, Vector3(0.12, 0.09, 0.1), Vector3(0.09, 0.075, 0), c, Vector3.ZERO, metal)
		_box(b, Vector3(0.15, 0.03, 0.125), Vector3(-0.07, 0.215, 0), c.lightened(0.15), Vector3.ZERO, metal)
	return n


static func _gloves(item: Dictionary, tint: Color) -> Node3D:
	var n := Node3D.new()
	var c := tint if tint.a > 0.0 else LEATHER
	var metal := float(item.get("metal", 0.0)) + (0.3 if str(item.get("material", "")) == "metal" else 0.0)
	for i in 2:
		var g := Node3D.new()
		g.position = Vector3(0.0, 0.0, -0.1 + i * 0.2)
		g.rotation.y = 0.2 - i * 0.4
		n.add_child(g)
		_box(g, Vector3(0.13, 0.04, 0.12), Vector3(0, 0.02, 0), c, Vector3.ZERO, metal)
		for f in 4:
			_box(g, Vector3(0.11, 0.03, 0.022), Vector3(0.12, 0.018, -0.045 + f * 0.03), c.darkened(0.05), Vector3.ZERO, metal)
		_box(g, Vector3(0.09, 0.03, 0.025), Vector3(0.05, 0.018, 0.09), c.darkened(0.05), Vector3(0, -40, 0), metal)
		_box(g, Vector3(0.06, 0.055, 0.14), Vector3(-0.09, 0.028, 0), c.lightened(0.12), Vector3.ZERO, metal)
	return n


static func _gem_for(id: String, fallback := Color(0.8, 0.2, 0.2)) -> Color:
	for key in GEMS:
		if id.contains(key):
			return GEMS[key]
	return fallback


static func _band_for(id: String) -> Color:
	if id.contains("kupfer"):
		return Color(0.8, 0.43, 0.26)
	if id.contains("silber") or id.contains("klingen") or id.contains("wurf") or id.contains("schild") or id.contains("kristall"):
		return Color(0.82, 0.84, 0.9)
	if id.contains("bronze"):
		return Color(0.7, 0.5, 0.25)
	return GOLD


static func _amulet(id: String) -> Node3D:
	var n := Node3D.new()
	_torus(n, 0.115, 0.13, Vector3(0, 0.012, 0), _band_for(id) if not id.contains("tempo") else GOLD, Vector3.ZERO, 0.6, 0.012)
	_box(n, Vector3(0.1, 0.012, 0.12), Vector3(0.2, 0.012, 0), Color(0.75, 0.6, 0.25), Vector3.ZERO, 0.6)
	_ball(n, 0.05, Vector3(0.2, 0.035, 0), _gem_for(id, Color(0.4, 0.7, 0.9)), Vector3(1, 0.7, 1), 0.2, 0.5)
	return n


static func _ring(id: String) -> Node3D:
	var n := Node3D.new()
	n.scale = Vector3.ONE * 1.5
	_torus(n, 0.055, 0.085, Vector3(0, 0.02, 0), _band_for(id), Vector3.ZERO, 0.7, 0.02)
	if not id.contains("kupfer") and not id.contains("wurf") and not id.contains("klingen"):
		_ball(n, 0.035, Vector3(0.075, 0.05, 0), _gem_for(id, Color(0.75, 0.15, 0.15)), Vector3(1, 0.7, 1), 0.2, 0.4)
	return n


static func _bracelet(id: String) -> Node3D:
	var n := Node3D.new()
	_torus(n, 0.11, 0.15, Vector3(0, 0.03, 0), _band_for(id), Vector3.ZERO, 0.6, 0.03)
	if id.contains("schuppen") or id.contains("kompass") or id.contains("axt") or id.contains("last"):
		_ball(n, 0.04, Vector3(0.13, 0.06, 0), _gem_for(id, Color(0.9, 0.5, 0.2)), Vector3(1, 0.7, 1), 0.2, 0.4)
	return n


static func _special(id: String) -> Node3D:
	var n := Node3D.new()
	match id:
		"vampirzahn":
			_cyl(n, 0.0, 0.05, 0.2, Vector3(0, 0.05, 0), Color(0.93, 0.9, 0.8), Vector3(0, 20, 82))
		"gluecksklee":
			for i in 4:
				var a := i * PI * 0.5 + 0.4
				_ball(n, 0.06, Vector3(cos(a) * 0.06, 0.012, sin(a) * 0.06), Color(0.25, 0.65, 0.25), Vector3(1, 0.22, 1), 0.0, 0.0)
			_box(n, Vector3(0.12, 0.01, 0.015), Vector3(-0.1, 0.008, 0.08), Color(0.2, 0.5, 0.2), Vector3(0, 40, 0))
		"dornenrune":
			_box(n, Vector3(0.2, 0.06, 0.24), Vector3(0, 0.03, 0), STONE.darkened(0.2), Vector3(0, 12, 0))
			_box(n, Vector3(0.02, 0.01, 0.14), Vector3(0, 0.065, 0), Color(0.9, 0.25, 0.15), Vector3.ZERO, 0.0, 0.5, 1.2)
			_box(n, Vector3(0.1, 0.01, 0.02), Vector3(0, 0.066, 0.02), Color(0.9, 0.25, 0.15), Vector3.ZERO, 0.0, 0.5, 1.2)
		"phoenixfeder":
			_box(n, Vector3(0.34, 0.01, 0.05), Vector3(0, 0.012, 0), Color(0.95, 0.5, 0.15), Vector3(0, 15, 0), 0.0, 0.6, 0.4)
			_box(n, Vector3(0.2, 0.008, 0.08), Vector3(0.02, 0.01, 0.0), Color(1.0, 0.75, 0.2), Vector3(0, 15, 0), 0.0, 0.6, 0.4)
			_box(n, Vector3(0.1, 0.012, 0.01), Vector3(-0.2, 0.01, 0.03), Color(0.7, 0.55, 0.3), Vector3(0, 15, 0))
		_:
			return null
	return n


static func _scroll() -> Node3D:
	var n := Node3D.new()
	_cyl(n, 0.045, 0.045, 0.3, Vector3(0, 0.045, 0), PARCHMENT, Vector3(90, 0, 0))
	for side in [-1.0, 1.0]:
		_cyl(n, 0.052, 0.052, 0.02, Vector3(0, 0.045, side * 0.155), DARK_WOOD, Vector3(90, 0, 0))
	_cyl(n, 0.05, 0.05, 0.03, Vector3(0, 0.045, 0.03), Color(0.65, 0.12, 0.1), Vector3(90, 0, 0))
	n.rotation.y = 0.4
	return n


static func _book(id: String) -> Node3D:
	var n := Node3D.new()
	var c: Color = BOOKS.get(id, LEATHER)
	var k := 1.35 if id == "foliant_der_kraft" else 1.0
	_box(n, Vector3(0.26, 0.07, 0.34) * k, Vector3(0, 0.035 * k, 0), c)
	_box(n, Vector3(0.24, 0.05, 0.31) * k, Vector3(0.012 * k, 0.035 * k, 0), BONE.darkened(0.05))
	_box(n, Vector3(0.035, 0.075, 0.34) * k, Vector3(-0.13 * k, 0.035 * k, 0), c.darkened(0.15))
	_box(n, Vector3(0.12, 0.012, 0.04) * k, Vector3(0, 0.0725 * k, 0), GOLD, Vector3.ZERO, 0.6)
	n.rotation.y = 0.5
	return n


static func _crate() -> Node3D:
	var n := Node3D.new()
	_box(n, Vector3(0.5, 0.4, 0.5), Vector3(0, 0.2, 0), WOOD)
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			_box(n, Vector3(0.06, 0.42, 0.06), Vector3(x * 0.22, 0.2, z * 0.22), DARK_WOOD)
	_box(n, Vector3(0.52, 0.04, 0.52), Vector3(0, 0.4, 0), DARK_WOOD)
	n.rotation.y = 0.3
	return n


static func _stone_block() -> Node3D:
	var n := Node3D.new()
	_box(n, Vector3(0.5, 0.3, 0.38), Vector3(0, 0.15, 0), STONE)
	_box(n, Vector3(0.52, 0.03, 0.4), Vector3(0, 0.3, 0), STONE.lightened(0.1))
	n.rotation.y = 0.35
	return n


static func _timber() -> Node3D:
	var n := Node3D.new()
	for i in 3:
		_box(n, Vector3(0.6, 0.05, 0.14), Vector3(0, 0.025 + i * 0.05, (i - 1) * 0.02), WOOD.lightened(0.05 * i), Vector3(0, i * 5 - 5, 0))
	n.rotation.y = 0.2
	return n


static func _errand(id: String) -> Node3D:
	var n := Node3D.new()
	match id:
		"brief":
			_box(n, Vector3(0.22, 0.012, 0.15), Vector3(0, 0.006, 0), Color(0.93, 0.9, 0.82), Vector3(0, 20, 0))
			_cyl(n, 0.03, 0.03, 0.008, Vector3(0, 0.016, 0), Color(0.7, 0.12, 0.1))
		"kuerbis":
			_ball(n, 0.2, Vector3(0, 0.15, 0), Color(0.9, 0.5, 0.12), Vector3(1.0, 0.8, 1.0))
			_cyl(n, 0.02, 0.03, 0.07, Vector3(0, 0.32, 0), Color(0.3, 0.45, 0.2))
		"alriks_siegelring":
			return _ring("siegelring")
		"wetzstein":
			_box(n, Vector3(0.3, 0.05, 0.07), Vector3(0, 0.025, 0), Color(0.55, 0.53, 0.5), Vector3(0, 25, 0))
		"kartenstueck_1", "kartenstueck_2", "kartenstueck_3":
			_box(n, Vector3(0.2, 0.01, 0.15), Vector3(0, 0.005, 0), PARCHMENT.darkened(0.08), Vector3(0, 30, 0))
			var mark := Color(0.2, 0.45, 0.2) if id.ends_with("2") else (Color(0.65, 0.12, 0.1) if id.ends_with("3") else Color(0.35, 0.25, 0.15))
			_box(n, Vector3(0.09, 0.012, 0.015), Vector3(0, 0.008, 0), mark, Vector3(0, 30, 0))
		"schaedel_medusa", "schaedel_snoops":
			_ball(n, 0.11, Vector3(0, 0.13, 0), Color(0.9, 0.86, 0.74), Vector3(1.0, 0.95, 1.1))
			_box(n, Vector3(0.12, 0.07, 0.1), Vector3(0, 0.05, 0.03), Color(0.86, 0.82, 0.7))
			_ball(n, 0.03, Vector3(-0.045, 0.14, 0.09), Color(0.05, 0.04, 0.04))
			_ball(n, 0.03, Vector3(0.045, 0.14, 0.09), Color(0.05, 0.04, 0.04))
		"geladener_diamant":
			_box(n, Vector3(0.14, 0.14, 0.14), Vector3(0, 0.12, 0), Color(0.75, 0.9, 1.0), Vector3(45, 30, 45), 0.6, 0.1, 0.5)
		"schatzkarte":
			_box(n, Vector3(0.34, 0.012, 0.26), Vector3(0, 0.006, 0), PARCHMENT, Vector3(0, 15, 0))
			_box(n, Vector3(0.14, 0.014, 0.02), Vector3(0.02, 0.01, 0), Color(0.65, 0.12, 0.1), Vector3(0, 60, 0))
			_box(n, Vector3(0.14, 0.014, 0.02), Vector3(0.02, 0.01, 0), Color(0.65, 0.12, 0.1), Vector3(0, -30, 0))
		_:
			_box(n, Vector3(0.2, 0.012, 0.15), Vector3(0, 0.006, 0), PARCHMENT, Vector3(0, 20, 0))
	return n


static func _ore(tint: Color) -> Node3D:
	var n := Node3D.new()
	var c := tint if tint.a > 0.0 else Color(0.55, 0.75, 1.0)
	_box(n, Vector3(0.2, 0.16, 0.18), Vector3(0, 0.08, 0), STONE.darkened(0.3), Vector3(0, 20, 8))
	_box(n, Vector3(0.12, 0.2, 0.1), Vector3(0.05, 0.12, 0.04), c, Vector3(10, 40, -10), 0.4, 0.3, 0.7)
	_box(n, Vector3(0.09, 0.12, 0.08), Vector3(-0.07, 0.1, -0.06), c.darkened(0.15), Vector3(-15, -20, 12), 0.4, 0.3, 0.5)
	return n


## The climbing gear (see RockClimb): hammer, iron nail, rope and helmet, each with a few parts and
## two or three shades so none looks like a plain block.
static func _climbing(id: String) -> Node3D:
	var n := Node3D.new()
	var steel := Color(0.46, 0.47, 0.5)
	var iron := Color(0.27, 0.27, 0.3)
	var wood := Color(0.52, 0.36, 0.2)
	var hemp := Color(0.66, 0.54, 0.34)
	match id:
		"kletterhammer":
			# A short ash handle with a leather grip, a square steel face and a wedge-shaped peen.
			_cyl(n, 0.017, 0.021, 0.3, Vector3(0, 0.03, 0), wood, Vector3(0, 0, 90))
			_cyl(n, 0.023, 0.023, 0.1, Vector3(-0.07, 0.03, 0), Color(0.3, 0.2, 0.12), Vector3(0, 0, 90))
			_box(n, Vector3(0.055, 0.05, 0.05), Vector3(0.15, 0.04, 0), steel, Vector3.ZERO, 0.6, 0.4)
			_box(n, Vector3(0.05, 0.035, 0.012), Vector3(0.2, 0.04, 0), steel.lightened(0.15), Vector3.ZERO, 0.6, 0.35)
			_box(n, Vector3(0.07, 0.02, 0.03), Vector3(0.1, 0.04, 0), iron, Vector3(0, 0, -12), 0.6, 0.5)
		"kletterhaken":
			# A flat iron blade with a ring eye at its head.
			_box(n, Vector3(0.15, 0.01, 0.032), Vector3(0.0, 0.006, 0), iron, Vector3(0, 0, 0), 0.7, 0.5)
			_box(n, Vector3(0.05, 0.008, 0.02), Vector3(0.1, 0.006, 0), iron.darkened(0.15), Vector3(0, 0, 0), 0.7, 0.5)
			_torus(n, 0.012, 0.024, Vector3(-0.09, 0.012, 0), steel, Vector3.ZERO, 0.7, 0.012)
		"kletterseil":
			# A coil of hemp rope, three turns high, with the loose end tied round it.
			for i in 3:
				_torus(n, 0.07, 0.115, Vector3(0, 0.02 + i * 0.03, 0), hemp.darkened(0.06 * i), Vector3.ZERO, 0.0, 0.03)
			_box(n, Vector3(0.05, 0.04, 0.2), Vector3(0, 0.05, 0), hemp.lightened(0.1), Vector3(0, 90, 0))
			_cyl(n, 0.012, 0.012, 0.16, Vector3(0.12, 0.012, 0.06), hemp, Vector3(0, 0, 90))
		"kletterhelm":
			# The worn helmet (see ClimbHelmet) at ground size, lying brim down.
			var helmet := ClimbHelmet.build()
			helmet.scale = Vector3.ONE * 0.3
			n.add_child(helmet)
	return n


static func _feed(id: String) -> Node3D:
	var n := Node3D.new()
	match id:
		"wurst":
			var m := MeshInstance3D.new()
			var mesh := CapsuleMesh.new()
			mesh.radius = 0.05
			mesh.height = 0.28
			m.mesh = mesh
			m.material_override = _mat(Color(0.65, 0.3, 0.25), 0.0, 0.6)
			m.position = Vector3(0, 0.05, 0)
			m.rotation = Vector3(0, 0.4, PI * 0.5)
			n.add_child(m)
		"apfel":
			_ball(n, 0.09, Vector3(0, 0.08, 0), Color(0.75, 0.15, 0.12), Vector3(1, 0.9, 1), 0.0, 0.35)
			_cyl(n, 0.007, 0.007, 0.05, Vector3(0, 0.17, 0), DARK_WOOD)
		"koerner":
			for i in 14:
				var a := i * 2.4
				var r := 0.015 + 0.012 * sqrt(float(i))
				_ball(n, 0.014, Vector3(cos(a) * r * 2.0, 0.012, sin(a) * r * 2.0), Color(0.85, 0.7, 0.3 + (i % 3) * 0.05), Vector3(1.4, 0.8, 1))
		"salzleckstein":
			_box(n, Vector3(0.16, 0.12, 0.16), Vector3(0, 0.06, 0), Color(0.88, 0.86, 0.82), Vector3(0, 20, 0))
			_box(n, Vector3(0.17, 0.02, 0.03), Vector3(0, 0.1, 0), LEATHER, Vector3(0, 20, 0))
		_:
			return null
	return n


static func _torch() -> Node3D:
	var n := Node3D.new()
	_cyl(n, 0.03, 0.025, 0.46, Vector3(0, 0.03, 0), WOOD, Vector3(90, 0, 0))
	_cyl(n, 0.05, 0.035, 0.12, Vector3(0, 0.05, -0.28), Color(0.15, 0.1, 0.07), Vector3(90, 0, 0))
	_cyl(n, 0.052, 0.052, 0.03, Vector3(0, 0.05, -0.18), Color(0.45, 0.38, 0.28), Vector3(90, 0, 0))
	n.rotation.y = 0.6
	return n


static func _bedroll() -> Node3D:
	var n := Node3D.new()
	_cyl(n, 0.13, 0.13, 0.45, Vector3(0, 0.13, 0), CLOTH.lightened(0.05), Vector3(90, 0, 0))
	_cyl(n, 0.132, 0.132, 0.03, Vector3(0, 0.13, 0.1), LEATHER, Vector3(90, 0, 0))
	_cyl(n, 0.132, 0.132, 0.03, Vector3(0, 0.13, -0.1), LEATHER, Vector3(90, 0, 0))
	_cyl(n, 0.1, 0.1, 0.01, Vector3(0, 0.13, 0.226), CLOTH.darkened(0.3), Vector3(90, 0, 0))
	n.rotation.y = 0.3
	return n


static func _potion(tint: Color) -> Node3D:
	var n := Node3D.new()
	var c := tint if tint.a > 0.0 else Color(0.9, 0.2, 0.25)
	var glass := _mat(Color(c.r, c.g, c.b, 0.8), 0.0, 0.15, 0.35)
	glass.emission = c
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var body := _cyl(n, 0.06, 0.06, 0.15, Vector3(0, 0.06, 0), c, Vector3(0, 0, 90))
	body.material_override = glass
	var neck := _cyl(n, 0.022, 0.022, 0.09, Vector3(0.12, 0.06, 0), Color(0.75, 0.85, 0.85, 0.7), Vector3(0, 0, 90))
	neck.material_override = _mat(Color(0.75, 0.88, 0.88, 0.5), 0.0, 0.15)
	(neck.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cyl(n, 0.026, 0.024, 0.03, Vector3(0.18, 0.06, 0), Color(0.5, 0.35, 0.2), Vector3(0, 0, 90))
	_ball(n, 0.06, Vector3(-0.075, 0.06, 0), c, Vector3(0.4, 1, 1)).material_override = glass
	n.rotation.y = 0.8
	return n


## The fallback: a small leather pouch tied at the neck.
static func _pouch() -> Node3D:
	var n := Node3D.new()
	_ball(n, 0.13, Vector3(0, 0.1, 0), LEATHER, Vector3(1, 0.85, 1))
	_cyl(n, 0.04, 0.07, 0.07, Vector3(0, 0.22, 0), LEATHER.darkened(0.1))
	_torus(n, 0.035, 0.05, Vector3(0, 0.205, 0), CLOTH, Vector3.ZERO, 0.0, 0.02)
	return n


# --- Colours and the parts of a model -------------------------------------------

static func _by_material(material: String, tint: Color) -> Color:
	if tint.a > 0.0:
		return tint
	match material:
		"bone":
			return BONE
		"fur":
			return Color(0.4, 0.28, 0.18)
		"cloth":
			return CLOTH
		"leather":
			return LEATHER
	return STEEL


static func _mat(color: Color, metal := 0.0, rough := 0.85, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emit
	return m


static func _add(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, rot_deg: Vector3, metal: float, rough: float, emit: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = _mat(color, metal, rough, emit)
	m.position = pos
	m.rotation = Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z))
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m


static func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, rot_deg := Vector3.ZERO, metal := 0.0, rough := 0.85, emit := 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add(parent, mesh, pos, color, rot_deg, metal, rough, emit)


static func _cyl(parent: Node3D, top: float, bottom: float, height: float, pos: Vector3, color: Color, rot_deg := Vector3.ZERO, metal := 0.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 1
	return _add(parent, mesh, pos, color, rot_deg, metal, 0.85, 0.0)


static func _ball(parent: Node3D, radius: float, pos: Vector3, color: Color, squash := Vector3.ONE, metal := 0.0, rough := 0.85, emit := 0.0) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	var m := _add(parent, mesh, pos, color, Vector3.ZERO, metal, rough, emit)
	m.scale = squash
	return m


## A flat ring lying on the floor; `thick` is how tall the band stands.
static func _torus(parent: Node3D, inner: float, outer: float, pos: Vector3, color: Color, rot_deg := Vector3.ZERO, metal := 0.0, thick := 0.02) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 12
	mesh.ring_segments = 6
	var m := _add(parent, mesh, pos, color, rot_deg, metal, 0.4, 0.0)
	m.scale = Vector3(1, thick / maxf((outer - inner) * 0.5, 0.001), 1)
	return m


## The box round every mesh under `node`, in `node`'s own space.
static func _bounds(node: Node3D) -> AABB:
	var found := [false, AABB()]
	_collect(node, node.transform, found)
	return found[1] if found[0] else AABB(Vector3(-0.1, 0, -0.1), Vector3(0.2, 0.2, 0.2))


static func _collect(node: Node, to_root: Transform3D, found: Array) -> void:
	for child in node.get_children():
		var t := to_root
		if child is Node3D:
			t = to_root * (child as Node3D).transform
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			var box: AABB = t * (child as MeshInstance3D).mesh.get_aabb()
			if found[0]:
				found[1] = (found[1] as AABB).merge(box)
			else:
				found[0] = true
				found[1] = box
		_collect(child, t, found)


## Sets the model on the floor in its middle: its underside on y = 0.
static func _ground(model: Node3D, box: AABB) -> void:
	model.position -= Vector3(box.get_center().x, box.position.y, box.get_center().z)
