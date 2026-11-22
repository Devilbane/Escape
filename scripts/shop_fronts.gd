class_name ShopFronts
extends RefCounted
## What each shop and office sets out in front of its door, so one sees from the street what it is
## about: the tavern's casks and an outdoor table with tankards and a chalked board, Mira's market
## table of fruit, bread and cheese under a striped awning, the post office's parcels and post box,
## the Crown office's notice board of proclamations and a bench for those who wait, the guild's
## armour stand and archery target, the smithy's rack of blades and its quenching tub and
## grindstone, and the bank's iron strongbox with a halberd leaned on it.
##
## Everything stands against the front wall, on both sides of the door, and never in front of it:
## the way in (DOOR_FREE either side of the door's middle) stays clear, and nothing reaches further
## out than DEEP from the wall, so the street before the hall stays free too. Each piece is solid
## where it is drawn (see WalkIn._solid).

## How far either side of the door's middle stays free, and how far out from the wall a display reaches.
const DOOR_FREE := 1.15
const DEEP := 1.25
## Room kept between a display and the hall's corners.
const CORNER := 0.25

static var _mats := {}


## Sets out the displays of the hall of `kind` (one of VillageHalls.KINDS) in front of its wall.
## The hall's front wall is at z = d / 2 in its own frame, its door in the middle. Returns the
## root of the displays (named "ShopFront"), or null for a kind with none.
static func dress(walk_in: WalkIn, hall: Node3D, kind: String) -> Node3D:
	var shape: Dictionary = hall.get_meta("shape")
	var wall: float = float(shape.d) * 0.5
	var reach: float = minf(float(shape.w) * 0.5 - CORNER, 4.2)
	if reach - DOOR_FREE < 0.8:
		return null
	var root := Node3D.new()
	root.name = "ShopFront"
	root.position = Vector3(0, 0, wall)
	hall.add_child(root)
	var rec := walk_in._record(hall)
	var parts: Array = []
	match kind:
		"tavern":
			parts = _tavern(root, reach)
		"shop":
			parts = _shop(root, reach)
		"post":
			parts = _post(root, reach)
		"office":
			parts = _office(root, reach)
		"guild":
			parts = _guild(root, reach)
		"smithy":
			parts = _smithy(root, reach)
	if parts.is_empty():
		root.queue_free()
		return null
	# Each part: [middle, size] of its solid, in the display's frame (the wall's foot at z = 0).
	for part: Array in parts:
		var mid: Vector3 = part[0]
		if not rec.is_empty():
			walk_in._solid(rec, mid + root.position, part[1])
	root.set_meta("solids", parts)
	return root


## The bank's strongbox, its front turned along `out` (the bank's way out), to stand by the door on the
## side away from its sign: an iron-bound chest on a stone step, sacks of coin and a halberd leaned
## on it. Returns the root, standing on the ground; its meta `solid_size` is the size of its solid.
static func bank_strongbox(out: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "BankStrongbox"
	var stone := _mat("step_stone", Color(0.6, 0.58, 0.55))
	var oak := _mat("oak", Color(0.36, 0.22, 0.12))
	var iron := _mat("iron", Color(0.2, 0.2, 0.22), 0.45, 0.6)
	var gold := _mat("gold", Color(1.0, 0.78, 0.3), 0.35, 0.7)
	_box(root, Vector3(1.3, 0.18, 0.85), Vector3(0, 0.09, 0), stone)
	_box(root, Vector3(0.95, 0.5, 0.6), Vector3(0, 0.43, 0), oak)
	var lid := CylinderMesh.new()
	lid.top_radius = 0.3
	lid.bottom_radius = 0.3
	lid.height = 0.95
	root.add_child(_part(lid, oak, Vector3(0, 0.68, 0), Basis(Vector3.BACK, PI * 0.5), Vector3(1, 1, 0.45)))
	for x: float in [-0.38, 0.0, 0.38]:
		_box(root, Vector3(0.07, 0.52, 0.62), Vector3(x, 0.44, 0), iron)
		root.add_child(_part(lid, iron, Vector3(x, 0.685, 0), Basis(Vector3.BACK, PI * 0.5), Vector3(0.24, 0.075, 0.47)))
	_box(root, Vector3(0.14, 0.16, 0.04), Vector3(0, 0.55, 0.31), gold)
	_box(root, Vector3(0.04, 0.06, 0.02), Vector3(0, 0.52, 0.335), iron)
	for x: float in [-0.75, 0.62]:
		var bag := SphereMesh.new()
		bag.radius = 0.16
		bag.height = 0.3
		root.add_child(_part(bag, _mat("coin_bag", Color(0.5, 0.36, 0.2)), Vector3(x, 0.15 if x < 0 else 0.33, 0.25)))
		_box(root, Vector3(0.08, 0.06, 0.08), Vector3(x, 0.3 if x < 0 else 0.48, 0.25), _mat("cord", Color(0.75, 0.62, 0.3)))
	for i in 5:
		var coin := CylinderMesh.new()
		coin.top_radius = 0.05
		coin.bottom_radius = 0.05
		coin.height = 0.015
		root.add_child(_part(coin, gold, Vector3(-0.55 + i * 0.05, 0.19 + i * 0.016, 0.3 - i * 0.02)))
	# A halberd leaned on its end: a guard's weapon left by the door.
	var turn := Basis(Vector3.BACK, -0.22)
	_box(root, Vector3(0.05, 2.1, 0.05), Vector3(0.62, 1.05, -0.2), oak, turn)
	_box(root, Vector3(0.28, 0.2, 0.02), turn * Vector3(0.12, 1.0, 0) + Vector3(0.62, 0.95, -0.2), _mat("steel", Color(0.82, 0.84, 0.88), 0.3, 0.8), turn)
	root.rotation.y = atan2(out.x, out.z)
	root.set_meta("solid_size", Vector3(1.6, 1.0, 1.0))
	return root


## Casks stacked on chocks to the left, and to the right an outdoor table with tankards, a bench
## and a chalked board of what is poured today.
static func _tavern(root: Node3D, reach: float) -> Array:
	var x := -(DOOR_FREE + 0.5)
	for i in 2:
		var cask := _cask()
		cask.position = Vector3(x - i * 0.66, 0.34, 0.45)
		root.add_child(cask)
	var top := _cask()
	top.position = Vector3(x - 0.33, 0.92, 0.45)
	root.add_child(top)
	var standing := WalkInFurniture.barrel()
	standing.position = Vector3(x + 0.15, 0, 1.0)
	standing.scale = Vector3.ONE * 0.8
	root.add_child(standing)
	var mug := WalkInFurniture.mug()
	mug.position = Vector3(x + 0.15, 0.72, 1.0)
	root.add_child(mug)
	var parts := [[Vector3(x - 0.33, 0.6, 0.6), Vector3(1.4, 1.2, 1.1)]]
	if reach - DOOR_FREE >= 1.4:
		var tx := DOOR_FREE + 0.75
		var table := _plank_table(1.1, 0.6)
		table.position = Vector3(tx, 0, 0.7)
		root.add_child(table)
		for m in 3:
			var cup := WalkInFurniture.mug()
			cup.position = Vector3(tx - 0.35 + m * 0.33, 0.76, 0.66 + (m % 2) * 0.1)
			root.add_child(cup)
		var bench := _bench(1.1)
		bench.position = Vector3(tx, 0, 0.2)
		root.add_child(bench)
		parts.append([Vector3(tx, 0.4, 0.55), Vector3(1.3, 0.8, 1.2)])
	var board := _chalk_board()
	board.position = Vector3(minf(reach - 0.3, DOOR_FREE + 1.75), 0, 1.0)
	board.rotation.y = -0.35
	root.add_child(board)
	return parts


## Mira's market table under a striped awning on the left: apples, pears, loaves, a cheese and jars;
## to the right crates of vegetables, a sack and a barrel of brooms.
static func _shop(root: Node3D, reach: float) -> Array:
	var wide := minf(reach - DOOR_FREE - 0.2, 2.2)
	var x := -(DOOR_FREE + 0.1 + wide * 0.5)
	var table := _plank_table(wide, 0.7)
	table.position = Vector3(x, 0, 0.55)
	root.add_child(table)
	_awning(root, Vector3(x, 2.25, 0), wide + 0.3, 1.15, [Color(0.85, 0.2, 0.18), Color(0.95, 0.9, 0.8)])
	var fruit := [Color(0.82, 0.12, 0.1), Color(0.55, 0.75, 0.2), Color(0.95, 0.7, 0.15)]
	var basket_at := x - wide * 0.5 + 0.3
	var k := 0
	while basket_at < x + wide * 0.5 - 0.25:
		_basket(root, Vector3(basket_at, 0.76, 0.55), fruit[k % fruit.size()], k)
		basket_at += 0.5
		k += 1
	# Loaves and a cheese on the table's front edge.
	for i in 3:
		var loaf := SphereMesh.new()
		loaf.radius = 0.09
		loaf.height = 0.12
		root.add_child(_part(loaf, _mat("bread", Color(0.78, 0.52, 0.25)), Vector3(x - 0.3 + i * 0.2, 0.8, 0.85), Basis(Vector3.UP, 0.4 * i), Vector3(1.4, 1, 0.8)))
	var cheese := CylinderMesh.new()
	cheese.top_radius = 0.14
	cheese.bottom_radius = 0.14
	cheese.height = 0.1
	root.add_child(_part(cheese, _mat("cheese", Color(0.98, 0.82, 0.35)), Vector3(x + 0.35, 0.81, 0.85)))
	var parts := [[Vector3(x, 0.45, 0.55), Vector3(wide + 0.1, 0.9, 0.8)]]
	var rx := DOOR_FREE + 0.45
	for i in 2:
		var crate := WalkInFurniture.crate(0.55)
		crate.position = Vector3(rx + i * 0.62, 0, 0.45)
		crate.rotation.y = 0.08 * (i * 2 - 1)
		root.add_child(crate)
		_heap(root, Vector3(rx + i * 0.62, 0.55, 0.45), [Color(0.6, 0.42, 0.22), Color(0.9, 0.45, 0.1)][i], 0.4)
	var sack := WalkInFurniture.sack()
	sack.position = Vector3(rx + 0.3, 0, 1.0)
	sack.scale = Vector3.ONE * 0.8
	root.add_child(sack)
	parts.append([Vector3(rx + 0.31, 0.35, 0.65), Vector3(1.3, 0.7, 1.1)])
	if reach - DOOR_FREE >= 1.9:
		var cask := WalkInFurniture.barrel()
		cask.position = Vector3(rx + 1.35, 0, 0.45)
		cask.scale = Vector3.ONE * 0.85
		root.add_child(cask)
		for b in 3:
			var turn := Basis(Vector3.BACK, (b - 1) * 0.18)
			_box(root, Vector3(0.035, 1.2, 0.035), Vector3(rx + 1.35 + (b - 1) * 0.08, 1.05, 0.45), _mat("broom_stick", Color(0.6, 0.45, 0.28)), turn)
			_box(root, Vector3(0.16, 0.25, 0.08), turn * Vector3(0, 0.62, 0) + Vector3(rx + 1.35 + (b - 1) * 0.08, 1.05, 0.45), _mat("straw", Color(0.85, 0.72, 0.4)), turn)
		parts.append([Vector3(rx + 1.35, 0.4, 0.45), Vector3(0.6, 0.8, 0.6)])
	return parts


## Parcels tied with string stacked on a hand cart on the left, mail sacks beside them; on the right
## a yellow post box on its post with the black post horn.
static func _post(root: Node3D, reach: float) -> Array:
	var x := -(DOOR_FREE + 0.55)
	var cart := Node3D.new()
	cart.position = Vector3(x, 0, 0.5)
	# Its handles point away from the door.
	cart.rotation.y = PI
	root.add_child(cart)
	var wood := _mat("cart_wood", Color(0.5, 0.35, 0.2))
	_box(cart, Vector3(0.9, 0.06, 0.6), Vector3(0, 0.38, 0), wood)
	for s: float in [-1.0, 1.0]:
		var wheel := CylinderMesh.new()
		wheel.top_radius = 0.22
		wheel.bottom_radius = 0.22
		wheel.height = 0.05
		cart.add_child(_part(wheel, _mat("wheel", Color(0.3, 0.2, 0.12)), Vector3(-0.15, 0.22, s * 0.33), Basis(Vector3.RIGHT, PI * 0.5)))
	_box(cart, Vector3(0.6, 0.04, 0.04), Vector3(0.65, 0.5, 0.2), wood, Basis(Vector3.BACK, 0.35))
	_box(cart, Vector3(0.6, 0.04, 0.04), Vector3(0.65, 0.5, -0.2), wood, Basis(Vector3.BACK, 0.35))
	var paper := [Color(0.72, 0.56, 0.36), Color(0.82, 0.7, 0.5), Color(0.62, 0.48, 0.3)]
	var stack := [[Vector3(-0.2, 0.41, -0.1), Vector3(0.4, 0.24, 0.32)], [Vector3(0.2, 0.41, 0.05), Vector3(0.36, 0.3, 0.4)],
			[Vector3(-0.15, 0.65, 0.0), Vector3(0.3, 0.2, 0.26)], [Vector3(0.18, 0.71, -0.05), Vector3(0.22, 0.14, 0.2)]]
	for i in stack.size():
		_parcel(cart, stack[i][0], stack[i][1], paper[i % paper.size()], 0.15 * (i - 1.5))
	var parts := [[Vector3(x - 0.4, 0.45, 0.5), Vector3(1.2, 0.9, 0.75)]]
	for i in 2:
		var bag := WalkInFurniture.sack()
		bag.position = Vector3(x + 0.1 - i * 0.55, 0, 1.05)
		bag.scale = Vector3(0.7, 0.8, 0.6)
		root.add_child(bag)
		_box(root, Vector3(0.12, 0.05, 0.12), Vector3(x + 0.1 - i * 0.55, 0.56, 1.05), _mat("cord", Color(0.75, 0.62, 0.3)))
	parts.append([Vector3(x - 0.18, 0.3, 1.05), Vector3(0.95, 0.6, 0.4)])
	var px := DOOR_FREE + 0.55
	var black := _mat("horn_black", Color(0.1, 0.08, 0.07), 0.5, 0.3)
	_box(root, Vector3(0.12, 1.0, 0.12), Vector3(px, 0.5, 0.45), _mat("post_wood", Color(0.3, 0.2, 0.12)))
	_box(root, Vector3(0.5, 0.55, 0.38), Vector3(px, 1.27, 0.45), _mat("post_yellow", Color(0.95, 0.75, 0.12), 0.6))
	_box(root, Vector3(0.55, 0.06, 0.43), Vector3(px, 1.57, 0.45), black)
	_box(root, Vector3(0.28, 0.035, 0.02), Vector3(px, 1.42, 0.645), black)
	var horn := HangingShield.emblem("horn")
	horn.position = Vector3(px, 1.2, 0.645)
	horn.scale = Vector3.ONE * 0.8
	root.add_child(horn)
	parts.append([Vector3(px, 0.8, 0.45), Vector3(0.55, 1.6, 0.45)])
	return parts


## The Crown office's notice board of proclamations under a little roof on the left, and a bench
## for those who wait on the right, a blue Crown banner on a stand beside it.
static func _office(root: Node3D, reach: float) -> Array:
	var x := -(DOOR_FREE + 0.95)
	var board := _notice_board(1.4)
	board.position = Vector3(x, 0, 0.35)
	root.add_child(board)
	var parts := [[Vector3(x, 1.0, 0.35), Vector3(1.6, 2.0, 0.3)]]
	var bx := DOOR_FREE + 0.85
	var bench := _bench(1.3)
	bench.position = Vector3(bx, 0, 0.35)
	root.add_child(bench)
	_box(root, Vector3(1.3, 0.5, 0.05), Vector3(bx, 0.72, 0.12), WalkInFurniture._wood())
	parts.append([Vector3(bx, 0.4, 0.3), Vector3(1.4, 0.8, 0.55)])
	if reach - DOOR_FREE >= 2.0:
		var sx := DOOR_FREE + 1.85
		_box(root, Vector3(0.06, 2.3, 0.06), Vector3(sx, 1.15, 0.45), _mat("post_wood", Color(0.3, 0.2, 0.12)))
		_box(root, Vector3(0.7, 0.05, 0.05), Vector3(sx, 2.2, 0.45), _mat("post_wood", Color(0.3, 0.2, 0.12)))
		_box(root, Vector3(0.6, 1.1, 0.02), Vector3(sx, 1.62, 0.47), _mat("crown_blue", Color(0.15, 0.22, 0.52)))
		var crown := HangingShield.emblem("crown")
		crown.position = Vector3(sx, 1.72, 0.5)
		crown.scale = Vector3.ONE * 1.2
		root.add_child(crown)
		_box(root, Vector3(0.6, 0.08, 0.025), Vector3(sx, 1.2, 0.485), _mat("gold_band", Color(0.92, 0.75, 0.3), 0.4, 0.5))
		_box(root, Vector3(0.4, 0.05, 0.4), Vector3(sx, 0.025, 0.45), _mat("post_wood", Color(0.3, 0.2, 0.12)))
		parts.append([Vector3(sx, 1.1, 0.45), Vector3(0.4, 2.2, 0.4)])
	return parts


## A training dummy in a helmet with a red shield on the left, a rack of round shields leaned on the
## wall; on the right a straw archery target with arrows in it.
static func _guild(root: Node3D, reach: float) -> Array:
	var x := -(DOOR_FREE + 0.55)
	var dummy := WalkInFurniture.dummy()
	dummy.position = Vector3(x, 0, 0.7)
	root.add_child(dummy)
	var helm := SphereMesh.new()
	helm.radius = 0.17
	helm.height = 0.2
	helm.is_hemisphere = true
	root.add_child(_part(helm, _mat("steel", Color(0.82, 0.84, 0.88), 0.3, 0.8), Vector3(x, 1.68, 0.7)))
	var parts := [[Vector3(x, 0.8, 0.7), Vector3(0.6, 1.6, 0.6)]]
	if reach - DOOR_FREE >= 1.5:
		for i in 3:
			var shield := CylinderMesh.new()
			shield.top_radius = 0.32
			shield.bottom_radius = 0.32
			shield.height = 0.05
			var c: Color = [Color(0.62, 0.14, 0.12), Color(0.15, 0.25, 0.55), Color(0.85, 0.7, 0.2)][i]
			root.add_child(_part(shield, _mat("shield_%d" % i, c), Vector3(x - 0.75 - i * 0.45, 0.34, 0.12 + i * 0.03), Basis(Vector3.RIGHT, PI * 0.5 - 0.2)))
			var boss := SphereMesh.new()
			boss.radius = 0.07
			boss.height = 0.08
			root.add_child(_part(boss, _mat("steel", Color(0.82, 0.84, 0.88), 0.3, 0.8), Vector3(x - 0.75 - i * 0.45, 0.35, 0.16 + i * 0.03)))
		parts.append([Vector3(x - 1.2, 0.35, 0.15), Vector3(1.4, 0.7, 0.3)])
	var tx := DOOR_FREE + 0.8
	var target := Node3D.new()
	target.position = Vector3(tx, 0, 0.5)
	target.rotation.y = -0.3
	root.add_child(target)
	var leg_wood := _mat("post_wood", Color(0.3, 0.2, 0.12))
	for s: float in [-1.0, 1.0]:
		_box(target, Vector3(0.06, 1.5, 0.06), Vector3(s * 0.4, 0.72, -0.1), leg_wood, Basis(Vector3.BACK, s * 0.15))
	_box(target, Vector3(0.06, 1.3, 0.06), Vector3(0, 0.6, -0.45), leg_wood, Basis(Vector3.RIGHT, -0.4))
	var rings := [[0.48, Color(0.85, 0.72, 0.4)], [0.36, Color(0.95, 0.93, 0.85)], [0.25, Color(0.15, 0.3, 0.6)], [0.14, Color(0.75, 0.15, 0.12)], [0.06, Color(0.95, 0.8, 0.2)]]
	for i in rings.size():
		var disc := CylinderMesh.new()
		disc.top_radius = rings[i][0]
		disc.bottom_radius = rings[i][0]
		disc.height = 0.1 if i == 0 else 0.01
		target.add_child(_part(disc, _mat("target_%d" % i, rings[i][1]), Vector3(0, 1.0, 0.0 + i * 0.012 + (0.0 if i == 0 else 0.05)), Basis(Vector3.RIGHT, PI * 0.5)))
	for a in [Vector2(0.08, 0.1), Vector2(-0.15, -0.05), Vector2(0.2, -0.18)]:
		_box(target, Vector3(0.015, 0.015, 0.5), Vector3(a.x, 1.0 + a.y, 0.3), leg_wood, Basis(Vector3.UP, a.x))
		_box(target, Vector3(0.06, 0.04, 0.08), Vector3(a.x + a.x * 0.25, 1.0 + a.y, 0.52), _mat("fletching", Color(0.9, 0.9, 0.88)))
	parts.append([Vector3(tx, 0.7, 0.4), Vector3(1.1, 1.4, 0.7)])
	return parts


## The smith's wares on a rack on the left (swords and axes), with a shield hung on it; on the right
## a quenching tub and a grindstone on its frame.
static func _smithy(root: Node3D, reach: float) -> Array:
	var wide := minf(reach - DOOR_FREE - 0.2, 1.8)
	var x := -(DOOR_FREE + 0.1 + wide * 0.5)
	var rack := WalkInFurniture.weapon_rack(wide)
	rack.position = Vector3(x, 0, 0.3)
	root.add_child(rack)
	var shield := HangingShield.shield_of("smithy")
	shield.position = Vector3(x, 1.5, 0.36)
	shield.scale = Vector3.ONE * 0.45
	root.add_child(shield)
	var parts := [[Vector3(x, 0.75, 0.3), Vector3(wide + 0.1, 1.5, 0.4)]]
	var qx := DOOR_FREE + 0.5
	var tub := CylinderMesh.new()
	tub.top_radius = 0.38
	tub.bottom_radius = 0.33
	tub.height = 0.5
	root.add_child(_part(tub, WalkInFurniture._wood(), Vector3(qx, 0.25, 0.55)))
	var water := CylinderMesh.new()
	water.top_radius = 0.35
	water.bottom_radius = 0.35
	water.height = 0.02
	root.add_child(_part(water, _mat("dark_water", Color(0.12, 0.16, 0.18), 0.1, 0.2), Vector3(qx, 0.47, 0.55)))
	for y: float in [0.1, 0.4]:
		var hoop := CylinderMesh.new()
		hoop.top_radius = 0.37 if y > 0.2 else 0.345
		hoop.bottom_radius = hoop.top_radius
		hoop.height = 0.04
		root.add_child(_part(hoop, _mat("iron", Color(0.2, 0.2, 0.22), 0.45, 0.6), Vector3(qx, y, 0.55)))
	_box(root, Vector3(0.04, 0.6, 0.04), Vector3(qx + 0.2, 0.65, 0.55), _mat("iron", Color(0.2, 0.2, 0.22), 0.45, 0.6), Basis(Vector3.BACK, -0.3))
	parts.append([Vector3(qx, 0.3, 0.55), Vector3(0.8, 0.6, 0.8)])
	if reach - DOOR_FREE >= 1.8:
		var gx := DOOR_FREE + 1.45
		var frame_wood := _mat("post_wood", Color(0.3, 0.2, 0.12))
		for s: float in [-1.0, 1.0]:
			_box(root, Vector3(0.6, 0.06, 0.06), Vector3(gx, 0.45, 0.55 + s * 0.17), frame_wood)
			for e: float in [-1.0, 1.0]:
				_box(root, Vector3(0.06, 0.5, 0.06), Vector3(gx + e * 0.25, 0.22, 0.55 + s * 0.17), frame_wood)
		var stone := CylinderMesh.new()
		stone.top_radius = 0.3
		stone.bottom_radius = 0.3
		stone.height = 0.12
		root.add_child(_part(stone, _mat("grit", Color(0.66, 0.62, 0.55), 0.95), Vector3(gx, 0.72, 0.55), Basis(Vector3.RIGHT, PI * 0.5)))
		_box(root, Vector3(0.03, 0.03, 0.5), Vector3(gx, 0.72, 0.55), _mat("iron", Color(0.2, 0.2, 0.22), 0.45, 0.6))
		_box(root, Vector3(0.03, 0.2, 0.03), Vector3(gx, 0.62, 0.82), _mat("iron", Color(0.2, 0.2, 0.22), 0.45, 0.6))
		parts.append([Vector3(gx, 0.5, 0.55), Vector3(0.7, 1.0, 0.5)])
	return parts


## A cask lying on its side along x, its middle at the origin.
static func _cask() -> Node3D:
	var cask := Node3D.new()
	var body := CylinderMesh.new()
	body.top_radius = 0.26
	body.bottom_radius = 0.26
	body.height = 0.62
	var wood := WalkInFurniture._wood()
	cask.add_child(_part(body, wood, Vector3.ZERO, Basis(Vector3.BACK, PI * 0.5), Vector3(1.12, 1, 1.12)))
	for x: float in [-0.22, 0.0, 0.22]:
		var hoop := CylinderMesh.new()
		hoop.top_radius = 0.3 if x == 0.0 else 0.28
		hoop.bottom_radius = hoop.top_radius
		hoop.height = 0.04
		cask.add_child(_part(hoop, _mat("iron", Color(0.2, 0.2, 0.22), 0.45, 0.6), Vector3(x, 0, 0), Basis(Vector3.BACK, PI * 0.5)))
	var tap := CylinderMesh.new()
	tap.top_radius = 0.03
	tap.bottom_radius = 0.03
	tap.height = 0.1
	cask.add_child(_part(tap, _mat("brass", Color(0.75, 0.55, 0.25), 0.4, 0.6), Vector3(0.0, -0.1, 0.3), Basis(Vector3.RIGHT, PI * 0.5)))
	return cask


## A table of planks on trestles, `wide` along x and `deep` along z, 0.75 m high.
static func _plank_table(wide: float, deep: float) -> Node3D:
	var table := Node3D.new()
	table.name = "MarketTable"
	var wood := WalkInFurniture._wood()
	_box(table, Vector3(wide, 0.05, deep), Vector3(0, 0.73, 0), wood)
	for s: float in [-1.0, 1.0]:
		for e: float in [-1.0, 1.0]:
			_box(table, Vector3(0.06, 0.72, 0.06), Vector3(s * (wide * 0.5 - 0.1), 0.36, e * (deep * 0.5 - 0.08)), _mat("post_wood", Color(0.3, 0.2, 0.12)))
	_box(table, Vector3(wide - 0.2, 0.05, 0.04), Vector3(0, 0.2, 0), _mat("post_wood", Color(0.3, 0.2, 0.12)))
	return table


## A plain bench `wide` long, 0.45 m high.
static func _bench(wide: float) -> Node3D:
	var bench := Node3D.new()
	var wood := WalkInFurniture._wood()
	_box(bench, Vector3(wide, 0.05, 0.32), Vector3(0, 0.45, 0), wood)
	for s: float in [-1.0, 1.0]:
		_box(bench, Vector3(0.06, 0.44, 0.28), Vector3(s * (wide * 0.5 - 0.1), 0.22, 0), wood)
	return bench


## A chalk board on an A frame, telling what is poured today.
static func _chalk_board() -> Node3D:
	var board := Node3D.new()
	var frame := _mat("post_wood", Color(0.3, 0.2, 0.12))
	_box(board, Vector3(0.55, 0.75, 0.03), Vector3(0, 0.62, 0.1), _mat("slate", Color(0.12, 0.13, 0.13), 0.95), Basis(Vector3.RIGHT, -0.18))
	_box(board, Vector3(0.62, 0.82, 0.02), Vector3(0, 0.62, 0.085), frame, Basis(Vector3.RIGHT, -0.18))
	_box(board, Vector3(0.55, 0.85, 0.03), Vector3(0, 0.45, -0.1), frame, Basis(Vector3.RIGHT, 0.18))
	var chalk := _mat("chalk", Color(0.92, 0.92, 0.88))
	for i in 4:
		var w: float = [0.36, 0.28, 0.32, 0.2][i]
		_box(board, Vector3(w, 0.025, 0.005), Vector3(-0.03 + (0.36 - w) * 0.3, 0.86 - i * 0.12, 0.135 + i * 0.022), chalk, Basis(Vector3.RIGHT, -0.18))
	var mug := HangingShield.emblem("mug")
	mug.position = Vector3(0.17, 0.42, 0.17)
	mug.scale = Vector3.ONE * 0.4
	mug.rotation.x = -0.18
	board.add_child(mug)
	return board


## A notice board `wide` across under a small roof, papers with red seals pinned on it.
static func _notice_board(wide: float) -> Node3D:
	var board := Node3D.new()
	board.name = "NoticeBoard"
	var post := _mat("post_wood", Color(0.3, 0.2, 0.12))
	for s: float in [-1.0, 1.0]:
		_box(board, Vector3(0.1, 2.05, 0.1), Vector3(s * wide * 0.5, 1.02, 0), post)
	_box(board, Vector3(wide, 0.9, 0.05), Vector3(0, 1.3, 0), WalkInFurniture._wood())
	for s: float in [-1.0, 1.0]:
		_box(board, Vector3(wide + 0.3, 0.04, 0.32), Vector3(0, 2.05, s * 0.1), _mat("roof_board", Color(0.42, 0.24, 0.18)), Basis(Vector3.RIGHT, s * 0.45))
	var paper := _mat("paper", Color(0.93, 0.9, 0.8))
	var seal := _mat("seal", Color(0.75, 0.12, 0.1), 0.5)
	var sheets := [Vector3(-0.45, 1.42, 0.3), Vector3(-0.05, 1.32, 0.38), Vector3(0.38, 1.45, 0.28), Vector3(0.12, 1.05, 0.25), Vector3(-0.4, 1.02, 0.22)]
	for i in sheets.size():
		var s: Vector3 = sheets[i]
		if absf(s.x) + s.z * 0.5 > wide * 0.5:
			continue
		_box(board, Vector3(s.z, s.z * 1.3 if i < 3 else s.z, 0.01), Vector3(s.x, s.y, 0.03), paper, Basis(Vector3.BACK, 0.05 * (i - 2)))
		_box(board, Vector3(0.05, 0.05, 0.01), Vector3(s.x, s.y - s.z * 0.4, 0.04), seal)
	return board


## A striped cloth awning from the wall over a stall: its top edge on the wall at `top`, `wide`
## along x, reaching `out` from the wall and sloping down, on two poles at its front.
static func _awning(root: Node3D, top: Vector3, wide: float, out: float, colours: Array) -> void:
	var drop := 0.45
	var slope := atan2(drop, out)
	var length := Vector2(out, drop).length()
	var stripes := maxi(4, int(wide / 0.28))
	for i in stripes:
		var x := top.x - wide * 0.5 + (i + 0.5) * wide / stripes
		_box(root, Vector3(wide / stripes, 0.025, length), Vector3(x, top.y - drop * 0.5, out * 0.5), _mat("awning_%d" % (i % 2), colours[i % 2], 0.85), Basis(Vector3.RIGHT, slope))
		# A scalloped edge hanging at the front.
		_box(root, Vector3(wide / stripes - 0.02, 0.16, 0.02), Vector3(x, top.y - drop - 0.08, out + 0.01), _mat("awning_%d" % (i % 2), colours[i % 2], 0.85))
	for s: float in [-1.0, 1.0]:
		_box(root, Vector3(0.05, top.y - drop, 0.05), Vector3(top.x + s * (wide * 0.5 - 0.05), (top.y - drop) * 0.5, out - 0.05), _mat("post_wood", Color(0.3, 0.2, 0.12)))


## A shallow basket heaped with round fruit of `colour` at `at` (its bottom middle).
static func _basket(root: Node3D, at: Vector3, colour: Color, seed_value: int) -> void:
	var basket := CylinderMesh.new()
	basket.top_radius = 0.2
	basket.bottom_radius = 0.15
	basket.height = 0.12
	root.add_child(_part(basket, _mat("wicker", Color(0.7, 0.52, 0.3)), at + Vector3(0, 0.06, 0)))
	_heap(root, at + Vector3(0, 0.1, 0), colour, 0.32, seed_value)


## A heap of round goods (apples, onions, potatoes) of `colour`, `across` wide, its foot at `at`.
static func _heap(root: Node3D, at: Vector3, colour: Color, across: float, seed_value := 0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 31 + 7
	var fruit := SphereMesh.new()
	fruit.radius = 0.055
	fruit.height = 0.11
	fruit.radial_segments = 10
	fruit.rings = 5
	var mat := _mat("fruit_%s" % colour.to_html(false), colour, 0.55)
	var n := int(across * across * 70.0)
	for i in n:
		var r := sqrt(rng.randf()) * across * 0.42
		var a := rng.randf() * TAU
		var y := 0.05 + (1.0 - r / (across * 0.42)) * 0.08 + rng.randf() * 0.02
		root.add_child(_part(fruit, mat, at + Vector3(cos(a) * r, y, sin(a) * r)))


## A parcel `size`, wrapped in `colour` paper and tied with string, at `at` (its middle), turned `turn`.
static func _parcel(parent: Node3D, at: Vector3, size: Vector3, colour: Color, turn: float) -> void:
	var b := Basis(Vector3.UP, turn)
	_box(parent, size, at, _mat("parcel_%s" % colour.to_html(false), colour), b)
	var cord := _mat("cord", Color(0.75, 0.62, 0.3))
	_box(parent, Vector3(size.x + 0.01, size.y + 0.01, 0.02), at, cord, b)
	_box(parent, Vector3(0.02, size.y + 0.01, size.z + 0.01), at, cord, b)


static func _mat(key: String, colour: Color, roughness := 0.8, metallic := 0.0) -> StandardMaterial3D:
	if not _mats.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colour
		mat.roughness = roughness
		mat.metallic = metallic
		_mats[key] = mat
	return _mats[key]


static func _box(parent: Node3D, size: Vector3, at: Vector3, mat: Material, turn := Basis()) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := _part(mesh, mat, at, turn)
	parent.add_child(mi)
	return mi


static func _part(mesh: Mesh, mat: Material, at: Vector3, turn := Basis(), stretch := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = Transform3D(turn.scaled_local(stretch) if stretch != Vector3.ONE else turn, at)
	return mi
