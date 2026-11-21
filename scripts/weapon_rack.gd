class_name WeaponRack
extends RefCounted
## The weapon rack, a piece of furniture for the hero's self-built house (see HouseFurniture,
## "waffenstaender"), bought from the interior furnisher like the bookshelf. The hero runs into it
## to open the window of the weapon store (see HomeStores.WEAPONS): it keeps every weapon the hero
## puts in it, and nothing else, like the bookshelf keeps books. It holds as much as you like.
##
## The rack shows what is kept: the finest weapons stand in its slots, each with its own model
## (the very one the hero holds in their hand), the rarest first (see shown). A blade stands with
## its point in the slot and its hilt up, an axe, a mace or a hammer stands on its haft with its
## head up. Every kind stands once before a second of a kind gets a slot. A plaque on the crest
## board reads how many weapons are kept, even when there are more than SLOTS.
##
## It is a handmade piece in the walnut of the bookshelf: a plinth with a slotted block for the
## points and hafts, two lathe-turned front posts with finials, a planked back, a rail with a pair
## of pegs between the weapons and a cornice with the brass-framed plaque.

## The kind of its station, and the window it opens.
const KIND := "waffenstaender"
## The node of the weapons in the rack, and of the plaque.
const WEAPONS_NODE := "Weapons"
const PLAQUE_NODE := "Plaque"

## The size across the wall, how deep and how high it stands (metres).
const WIDTH := 3.4
const DEPTH := 0.55
const HEIGHT := 2.3
## How many weapons stand in view, and how far apart.
const SLOTS := 7
const PITCH := 0.44
## How far in front of the back the weapons stand, the top of the slotted block they stand in,
## and how deep a point or a haft sinks into it.
const SLOT_Z := 0.3
const BLOCK_TOP := 0.3
const SINK := 0.06
## How tall a weapon stands at most, and how wide it may be so it keeps clear of its neighbours.
const WEAPON_HEIGHT := 1.45
const WEAPON_WIDTH := PITCH * 0.84
## The height of the rail behind the weapons, with a peg between every two slots: a blade's
## crossguard or an axe's head rests above it.
const RAIL_Y := 0.95
## The turned front post, bottom to top: radius and height (metres), like the bookshelf's but
## shorter: a bun foot, a vase between rings and a neck under the cornice.
const POST := [Vector2(0.0, 0.0), Vector2(0.09, 0.0), Vector2(0.11, 0.05), Vector2(0.11, 0.11), Vector2(0.08, 0.17),
		Vector2(0.06, 0.2), Vector2(0.095, 0.24), Vector2(0.095, 0.3), Vector2(0.06, 0.34),
		Vector2(0.055, 0.5), Vector2(0.08, 0.75), Vector2(0.07, 0.95), Vector2(0.05, 1.08),
		Vector2(0.09, 1.12), Vector2(0.09, 1.2), Vector2(0.05, 1.24),
		Vector2(0.055, 1.4), Vector2(0.08, 1.62), Vector2(0.06, 1.85), Vector2(0.05, 1.95),
		Vector2(0.09, 1.99), Vector2(0.09, 2.08), Vector2(0.0, 2.08)]


## The rack at `pos`, turned by `rot`, its back on `pos` (the wall behind it) and its front
## towards +z. No solid and no station: the caller adds them (see HouseFurnisher).
static func build_rack(parent: Node, pos: Vector3, rot: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "WeaponRack"
	pivot.position = pos
	pivot.rotation.y = rot
	parent.add_child(pivot)
	var oak := HomeStoreFurniture._mat(Bookshelf.OAK, 0.8)
	var dark := HomeStoreFurniture._mat(Bookshelf.DARK_OAK, 0.9)
	var turned := HomeStoreFurniture._mat(Bookshelf.TURNED_OAK, 0.55)
	var brass := HomeStoreFurniture._mat(Bookshelf.BRASS, 0.35, 0.8)
	var hole := HomeStoreFurniture._mat(Color(0.05, 0.03, 0.02), 1.0)
	var top := POST[POST.size() - 1].y as float
	var inner := WIDTH - 0.24
	# The planked back: a dark board with raised battens between the planks.
	HomeStoreFurniture._add(pivot, HomeStoreFurniture._box(Vector3(WIDTH - 0.04, top, 0.05)), dark, Vector3(0, top * 0.5, 0.025))
	for i in range(1, 7):
		var x := -WIDTH * 0.5 + WIDTH * i / 7.0
		HomeStoreFurniture._add(pivot, HomeStoreFurniture._box(Vector3(0.035, top - 0.2, 0.02)), oak, Vector3(x, top * 0.5, 0.06))
	# The plinth, and on it the slotted block: a dark hole for every slot.
	HomeStoreFurniture._add(pivot, HomeStoreFurniture._box(Vector3(WIDTH, 0.12, DEPTH)), dark, Vector3(0, 0.06, DEPTH * 0.5))
	HomeStoreFurniture._add(pivot, HomeStoreFurniture._box(Vector3(inner, BLOCK_TOP - 0.12, 0.26)), oak,
			Vector3(0, (BLOCK_TOP + 0.12) * 0.5, SLOT_Z))
	var lip := HomeStoreFurniture._add(pivot, Bookshelf._rod(inner, 0.03), turned, Vector3(0, BLOCK_TOP, SLOT_Z + 0.13))
	lip.rotation.z = PI * 0.5
	for i in SLOTS:
		HomeStoreFurniture._add(pivot, HomeStoreFurniture._box(Vector3(0.16, 0.012, 0.11)), hole, Vector3(slot_x(i), BLOCK_TOP, SLOT_Z))
	# Two sides from the back to the turned posts, which carry the front.
	for sx: float in [-1.0, 1.0]:
		var post_x := sx * (WIDTH * 0.5 - 0.1)
		HomeStoreFurniture._add(pivot, HomeStoreFurniture._box(Vector3(0.08, top, DEPTH - 0.14)), oak,
				Vector3(sx * (WIDTH * 0.5 - 0.04), top * 0.5, (DEPTH - 0.14) * 0.5))
		var post := HomeStoreFurniture._add(pivot, Bookshelf._lathe(POST), turned, Vector3(post_x, 0, DEPTH - 0.1))
		post.name = "PostWest" if sx < 0.0 else "PostEast"
		HomeStoreFurniture._add(pivot, Bookshelf._lathe(Bookshelf.FINIAL), turned, Vector3(post_x, HEIGHT, DEPTH - 0.1))
	# The rail behind the weapons, with a peg between every two slots that keeps them apart.
	HomeStoreFurniture._add(pivot, HomeStoreFurniture._box(Vector3(inner, 0.12, 0.07)), turned, Vector3(0, RAIL_Y, 0.09))
	for i in SLOTS + 1:
		var x := slot_x(i) - PITCH * 0.5
		var peg := HomeStoreFurniture._add(pivot, HomeStoreFurniture._cylinder(0.022, 0.026, SLOT_Z - 0.05), turned,
				Vector3(x, RAIL_Y, 0.12 + (SLOT_Z - 0.05) * 0.5))
		peg.rotation.x = PI * 0.5
		HomeStoreFurniture._add(pivot, HomeStoreFurniture._sphere(0.035), turned, Vector3(x, RAIL_Y, SLOT_Z + 0.08))
	# The cornice over the posts, with a bead under its front edge.
	HomeStoreFurniture._add(pivot, HomeStoreFurniture._box(Vector3(WIDTH + 0.06, HEIGHT - top, DEPTH + 0.06)), oak,
			Vector3(0, (top + HEIGHT) * 0.5, DEPTH * 0.5))
	var bead := HomeStoreFurniture._add(pivot, Bookshelf._rod(WIDTH - 0.3, 0.03), turned, Vector3(0, top - 0.02, DEPTH - 0.02))
	bead.rotation.z = PI * 0.5
	# The plaque with the number, in a brass frame on the back under the cornice.
	var plaque_y := top - 0.17
	HomeStoreFurniture._add(pivot, HomeStoreFurniture._box(Vector3(1.38, 0.3, 0.03)), brass, Vector3(0, plaque_y, 0.075))
	HomeStoreFurniture._add(pivot, HomeStoreFurniture._box(Vector3(1.3, 0.24, 0.04)), dark, Vector3(0, plaque_y, 0.085))
	var weapons := Node3D.new()
	weapons.name = WEAPONS_NODE
	pivot.add_child(weapons)
	var label := Label3D.new()
	label.name = PLAQUE_NODE
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.font = preload("res://assets/fonts/Cinzel-Bold.woff2")
	label.pixel_size = 0.004
	label.font_size = 56
	label.outline_size = 6
	label.modulate = Color(0.95, 0.8, 0.4)
	label.outline_modulate = Color(0.1, 0.06, 0.03)
	label.position = Vector3(0, plaque_y, 0.11)
	pivot.add_child(label)
	return pivot


## Where the middle of slot `i` lies across the rack, left to right.
static func slot_x(i: int) -> float:
	return (i - (SLOTS - 1) * 0.5) * PITCH


## How fine a weapon is, for its place on the rack: its rarity first (see Level.rank_of), then
## its price.
static func _finer(a: String, b: String) -> bool:
	var ra := Level.rank_of(a)
	var rb := Level.rank_of(b)
	if ra != rb:
		return ra > rb
	var pa := int(Items.ALL.get(a, {}).get("price", 0))
	var pb := int(Items.ALL.get(b, {}).get("price", 0))
	if pa != pb:
		return pa > pb
	return a < b


## The weapons that stand on the rack for `box` (the store: kind -> how many), slot by slot:
## the finest first, every kind once before a second of any kind, at most SLOTS.
static func shown(box: Dictionary) -> Array:
	var kinds: Array = []
	for id in box:
		if Items.ALL.has(str(id)) and int(box[id]) > 0:
			kinds.append(str(id))
	kinds.sort_custom(_finer)
	var out: Array = []
	var copies := 0
	while out.size() < SLOTS:
		var added := false
		for id in kinds:
			if int(box[id]) > copies and out.size() < SLOTS:
				out.append(id)
				added = true
		if not added:
			break
		copies += 1
	return out


## The number on the plaque: "Weapons: 3".
static func plaque_text(count: int) -> String:
	return Lang.t("Waffen: %d") % maxi(count, 0)


## Puts the weapons kept in `box` (the weapon store) on one rack (see build_rack): the finest in
## the slots, and the number of all of them on the plaque.
static func refresh_rack(pivot: Node, box: Dictionary) -> void:
	var weapons: Node3D = pivot.get_node(WEAPONS_NODE)
	for old in weapons.get_children():
		weapons.remove_child(old)
		old.queue_free()
	var ids := shown(box)
	for i in ids.size():
		var holder := weapon_model(ids[i])
		if holder == null:
			continue
		holder.name = "Slot%d" % i
		holder.position = Vector3(slot_x(i), 0, SLOT_Z)
		weapons.add_child(holder)
	var count := 0
	for id in box:
		count += int(box[id])
	var label: Label3D = pivot.get_node(PLAQUE_NODE)
	label.text = plaque_text(count)


## A weapon standing upright in its slot: its own model (the one in the hero's hand, dressed the
## same way, see GearLook.dress), a blade turned point down and hilt up, scaled to stand no taller
## than WEAPON_HEIGHT and no wider than WEAPON_WIDTH. Its origin is the slot's middle on the floor.
## A thunder weapon crackles with small sparks, as in the hand. Null for an item without a model.
static func weapon_model(id: String) -> Node3D:
	var item: Dictionary = Items.ALL.get(id, {})
	if not item.has("model") or not ResourceLoader.exists(str(item.model)):
		return null
	var holder := Node3D.new()
	var model: Node3D = load(str(item.model)).instantiate()
	GearLook.dress(model, item.get("material", ""))
	var box := _bounds(model)
	var roll := PI if item.get("uses", "") == "klingen" else 0.0
	var turned := Basis(Vector3(0, 0, 1), roll)
	var upright := Transform3D(turned, Vector3.ZERO) * box
	var fit := minf(WEAPON_HEIGHT / maxf(upright.size.y, 0.01), WEAPON_WIDTH / maxf(upright.size.x, 0.01))
	var t := Transform3D(turned.scaled(Vector3.ONE * fit), Vector3.ZERO)
	var placed := t * box
	t.origin = Vector3(-placed.get_center().x, BLOCK_TOP - SINK - placed.position.y, -placed.get_center().z)
	model.transform = t
	holder.add_child(model)
	if item.get("shock", 0.0) > 0.0:
		var sparks := Effects.make_sparkles(Enemy.SHOCK_COLOR)
		sparks.emission_sphere_radius = 0.25
		sparks.amount = 6
		sparks.position = Vector3(0, BLOCK_TOP + placed.size.y * 0.7, 0)
		holder.add_child(sparks)
	holder.set_meta("item", id)
	return holder


## The box round every mesh of a model, in the model's own space.
static func _bounds(model: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var to_model := Transform3D.IDENTITY
		var n: Node = mesh
		while n != model and n is Node3D:
			to_model = (n as Node3D).transform * to_model
			n = n.get_parent()
		var b := to_model * mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
