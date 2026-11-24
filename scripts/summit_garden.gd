class_name SummitGarden
extends RefCounted
## The garden nobody tends: a ledge high in the north rim of the high valley, a hidden climb (see
## ClimbSpots, the spot at CELL asks for Klettern LEVEL). Up there grow the rare silver edelweiss (picked by
## walking into it, it grows back after REGROW_DAYS days) and two mysteries: a weathered tablet that tells of
## the place, and a spring that never freezes and heals whoever drinks from it.
##
## The villagers know of it from hearsay only (see VillageRumours, "gipfelgarten"). Nothing on the ground
## below shows where the way up is: the face is plain rock like all the rest (see ClimbSpots).

## The rock tile that is the foot of the climb, the Klettern level it asks for and how high the ledge is
## (within Climbing.reach of LEVEL, and above the reach of the level before).
const CELL := Vector2i(151, 4)
const LEVEL := 16
const HEIGHT := 9.6

## The rare ingredient (see Crafting.INGREDIENTS) and how it grows: PLANTS tell where, in metres from the
## middle of the ledge (x east, z south), and every REGROW_DAYS days a picked one is back.
const INGREDIENT := "silberedelweiss"
const PLANTS := [Vector2(-1.45, -0.2), Vector2(-0.55, 0.65), Vector2(0.55, 0.75), Vector2(1.5, 0.15), Vector2(0.1, -1.55)]
const REGROW_DAYS := 6

## The tablet and the spring: where they stand and the stations they make (see Level.station_at).
const TABLET_AT := Vector2(-1.15, -1.5)
const SPRING_AT := Vector2(1.2, -1.1)
const TABLET_KIND := "tafel"
const SPRING_KIND := "gipfelquell"
const TOUCH := 1.0

## The viper in a crack of the face: about this far up (of the height) it bites the climbing hero once per
## climb, for BITE life points (never the last one) and with poison. The spring on the ledge is the cure.
const VIPER_AT := 0.5
const BITE := 3
const BITTEN := "Aus einer Felsspalte schnellt eine Kreuzotter und beißt dich in die Hand! Du kletterst weiter, aber das Gift brennt."
const BITTEN_LEARN := "Kreuzottern: In den Felsspalten über dem Hochtal nisten Kreuzottern. Wer dort hinaufklettert, wird gebissen und vergiftet. Oben im Berggarten gibt es einen Quell, der das Gift heilt."

## The words on the tablet (it goes into the compendium, see Game.writing_found).
const TABLET := "Hier oben pflegt niemand. Der Berg hält den Garten selbst. Nimm eine Blüte, wenn du sie brauchst, und lass die anderen stehen. Selbst die kleinen Drachen tragen von hier nichts fort."
## What the hero learns from the spring at the first sip, and the line at every sip.
const SPRING_LEARN := "Der Gipfelquell: Das Wasser auf dem Berggarten friert nie zu. Wer davon trinkt, wird geheilt, und das Gift weicht aus dem Blut."
const SPRING_FULL := "Du trinkst vom Quell. Es schmeckt nach Schnee und Sonne."
const SPRING_HEALED := "Das eiskalte Wasser des Quells heilt dich bis auf den letzten Kratzer."
const SPRING_CURED := "Das Wasser des Quells heilt dich von allem Übel."
## What the hero is told on picking the flower, and what the compendium learns of it.
const PICKED := "Silberedelweiß! Zart wie Filz und selten wie nichts sonst."
const PICKED_LEARN := "Silberedelweiß: Es wächst nur im Garten ganz oben auf dem Berg, wo noch nie jemand gepflegt hat. Nach ein paar Tagen blüht dort wieder eine."

const WHITE := Color(0.94, 0.95, 0.92)
const FELT := Color(0.78, 0.82, 0.76)
const GOLD := Color(0.95, 0.78, 0.25)
const LEAF := Color(0.42, 0.52, 0.4)
const GRASS := Color(0.36, 0.5, 0.26)
const MOSS := Color(0.28, 0.42, 0.22)
const STONE := Color(0.55, 0.55, 0.56)
const STONE_DARK := Color(0.34, 0.34, 0.37)
const GENTIAN := Color(0.2, 0.32, 0.85)
const WATER := Color(0.45, 0.8, 0.95)


## Where the middle of the ledge is, at its height.
static func middle(level: Level) -> Vector3:
	return level.cell_to_world(CELL) + Vector3(0, HEIGHT, 0)


## A point of the ledge, `at` metres from its middle.
static func spot(level: Level, at: Vector2) -> Vector3:
	return middle(level) + Vector3(at.x, 0.0, at.y)


## Builds the garden of `level` (the open-air map with the spot, see ClimbSpots); nothing for any other map.
static func build(level: Level) -> void:
	if ClimbSpots.at(level, CELL).is_empty():
		return
	var root := Node3D.new()
	root.name = "SummitGarden"
	level.add_child(root)
	root.position = middle(level)
	_carpet(root)
	_stones(root)
	_tufts(root)
	_gentians(root)
	_pine(root)
	_tablet(level, root)
	_spring(level, root)


# --- The carpet of grass and moss, the stones and the little flowers -----------------------------

static func _grain(base: Color, grain: float, rough := 0.95, frequency := 0.3, scale := 3.0) -> StandardMaterial3D:
	var m := ClimbHelmet.material(base, grain, 0.0, rough, frequency)
	m.uv1_scale = Vector3.ONE * scale
	return m


static func _node(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot_deg := Vector3.ZERO, scale := Vector3.ONE) -> MeshInstance3D:
	return ClimbHelmet.part(parent, mesh, pos, mat, rot_deg, scale)


static func _sphere(radius: float, height := -1.0) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height if height > 0.0 else radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 6
	return mesh


static func _cylinder(top: float, bottom: float, height: float, segments := 8) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = segments
	return mesh


## Mats of grass and cushions of moss laid over the bare rock of the ledge, each flat and a bit uneven.
static func _carpet(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("summit-carpet")
	var grass := _grain(GRASS, 0.35, 0.95, 0.4, 4.0)
	var moss := _grain(MOSS, 0.4, 1.0, 0.6, 6.0)
	for i in 9:
		var at := Vector3(rng.randf_range(-1.7, 1.7), 0.02, rng.randf_range(-1.8, 0.8))
		var patch := _node(root, _sphere(0.8), at, grass if i % 3 != 0 else moss, Vector3(0, rng.randf() * 360.0, 0),
				Vector3(rng.randf_range(0.8, 1.5), 0.06, rng.randf_range(0.7, 1.3)))
		patch.name = "Patch%d" % i
	for i in 6:
		var at := Vector3(rng.randf_range(-1.8, 1.8), 0.05, rng.randf_range(-1.8, 0.8))
		_node(root, _sphere(0.28, 0.4), at, moss, Vector3.ZERO, Vector3(rng.randf_range(0.9, 1.6), 0.5, rng.randf_range(0.9, 1.4)))


## Pebbles and a few bigger stones with grain, half sunk into the turf.
static func _stones(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("summit-stones")
	var light := _grain(STONE, 0.3, 0.9, 0.15, 3.0)
	var dark := _grain(STONE_DARK, 0.3, 0.9, 0.15, 3.0)
	for i in 12:
		var size := rng.randf_range(0.05, 0.2)
		var at := Vector3(rng.randf_range(-1.8, 1.8), size * 0.2, rng.randf_range(-1.85, 0.85))
		if Vector2(at.x, at.z).distance_to(TABLET_AT) < 0.9 or Vector2(at.x, at.z).distance_to(SPRING_AT) < 0.9:
			continue
		var stone := _node(root, _sphere(size), at, light if i % 2 == 0 else dark, Vector3(rng.randf() * 90.0, rng.randf() * 360.0, 0),
				Vector3(1.0, 0.65, rng.randf_range(0.8, 1.3)))
		stone.name = "Stone%d" % i


## Tufts of alpine grass: a few thin blades fanned out from one point.
static func _tufts(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("summit-tufts")
	var blade := _grain(GRASS.lightened(0.15), 0.3, 0.9, 0.5, 2.0)
	for i in 14:
		var at := Vector3(rng.randf_range(-1.85, 1.85), 0.04, rng.randf_range(-1.85, 0.85))
		if Vector2(at.x, at.z).distance_to(TABLET_AT) < 0.7 or Vector2(at.x, at.z).distance_to(SPRING_AT) < 0.8:
			continue
		var tuft := Node3D.new()
		tuft.name = "Tuft%d" % i
		root.add_child(tuft)
		tuft.position = at
		for j in 5:
			var mesh := _cylinder(0.0, 0.012, rng.randf_range(0.22, 0.4), 4)
			var lean := Vector3(rng.randf_range(-24.0, 24.0), rng.randf() * 360.0, rng.randf_range(-24.0, 24.0))
			_node(tuft, mesh, Vector3(0, 0.15, 0), blade, lean)


## A few tiny blue gentians between the grass: stem, five petals and a pale heart.
static func _gentians(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("summit-gentians")
	var stem := _grain(LEAF, 0.2, 0.9, 0.4, 2.0)
	var blue := ClimbHelmet.material(GENTIAN, 0.2, 0.0, 0.6, 0.5)
	blue.emission_enabled = true
	blue.emission = GENTIAN
	blue.emission_energy_multiplier = 0.25
	for i in 7:
		var at := Vector3(rng.randf_range(-1.8, 1.8), 0.0, rng.randf_range(-1.8, 0.8))
		if Vector2(at.x, at.z).distance_to(TABLET_AT) < 0.9 or Vector2(at.x, at.z).distance_to(SPRING_AT) < 0.9:
			continue
		var flower := Node3D.new()
		flower.name = "Gentian%d" % i
		root.add_child(flower)
		flower.position = at
		_node(flower, _cylinder(0.006, 0.008, 0.16, 5), Vector3(0, 0.08, 0), stem)
		for j in 5:
			var a := TAU * j / 5.0
			_node(flower, _sphere(0.035, 0.03), Vector3(cos(a) * 0.04, 0.17, sin(a) * 0.04), blue, Vector3(0, -rad_to_deg(a), 25.0), Vector3(1.4, 1.0, 0.8))
		_node(flower, _sphere(0.015), Vector3(0, 0.175, 0), _grain(WHITE, 0.1, 0.7, 0.5, 1.0))


## A dwarf pine bent by the wind in the north-west corner: a twisted trunk with a few flat cushions of needles.
static func _pine(root: Node3D) -> void:
	var bark := _grain(Color(0.34, 0.25, 0.18), 0.4, 0.95, 0.5, 2.0)
	var needles := _grain(Color(0.2, 0.34, 0.2), 0.35, 0.9, 0.7, 4.0)
	var pine := Node3D.new()
	pine.name = "DwarfPine"
	root.add_child(pine)
	pine.position = Vector3(-1.75, 0.0, -1.75)
	pine.rotation.y = 0.6
	_node(pine, _cylinder(0.07, 0.12, 0.5, 7), Vector3(0, 0.22, 0), bark, Vector3(0, 0, 14.0))
	_node(pine, _cylinder(0.05, 0.07, 0.45, 7), Vector3(0.18, 0.62, 0), bark, Vector3(0, 0, -38.0))
	_node(pine, _cylinder(0.035, 0.05, 0.35, 6), Vector3(0.45, 0.78, 0.05), bark, Vector3(0, 0, -78.0))
	_node(pine, _cylinder(0.035, 0.05, 0.3, 6), Vector3(0.12, 0.85, -0.04), bark, Vector3(0, 0, 40.0))
	for at in [Vector3(0.25, 0.85, 0.0), Vector3(0.62, 0.84, 0.08), Vector3(-0.04, 1.0, -0.06)]:
		_node(pine, _sphere(0.3, 0.2), at, needles, Vector3.ZERO, Vector3(1.0, 0.7, 1.0))
		_node(pine, _sphere(0.2, 0.14), at + Vector3(0.1, 0.1, 0.08), needles, Vector3.ZERO, Vector3(1.0, 0.7, 1.0))


# --- The tablet and the spring -------------------------------------------------------------------

## A weathered standing stone, taller than it is wide, with lines of writing carved into the face turned to
## the south, glowing faintly. Run into it to read it.
static func _tablet(level: Level, root: Node3D) -> void:
	var stone := _grain(STONE, 0.35, 0.9, 0.12, 2.0)
	var dark := _grain(STONE_DARK, 0.3, 0.9, 0.15, 3.0)
	var carved := ClimbHelmet.material(Color(1.0, 0.82, 0.45), 0.2, 0.0, 0.5, 0.5)
	carved.emission_enabled = true
	carved.emission = Color(1.0, 0.78, 0.4)
	carved.emission_energy_multiplier = 0.9
	var tablet := Node3D.new()
	tablet.name = "Tablet"
	root.add_child(tablet)
	tablet.position = Vector3(TABLET_AT.x, 0.0, TABLET_AT.y)
	tablet.rotation.y = deg_to_rad(8.0)
	var foot := _node(tablet, _sphere(0.7, 0.3), Vector3(0, 0.05, 0), dark, Vector3.ZERO, Vector3(1.0, 0.5, 0.7))
	foot.name = "Foot"
	var slab := _node(tablet, BoxMesh.new(), Vector3(0, 0.85, 0), stone, Vector3(-3.0, 0, 2.0))
	(slab.mesh as BoxMesh).size = Vector3(0.78, 1.5, 0.26)
	# A cracked corner and the lines of writing, shorter and shorter, down the face.
	_node(tablet, _sphere(0.17), Vector3(0.3, 1.55, 0.02), stone, Vector3.ZERO, Vector3(1.0, 0.7, 0.6))
	for row in 5:
		var line := BoxMesh.new()
		line.size = Vector3(0.52 - (row % 3) * 0.1, 0.045, 0.02)
		_node(tablet, line, Vector3((row % 2) * 0.04 - 0.02, 1.4 - row * 0.2, 0.14), carved)
	var sun := _node(tablet, _cylinder(0.12, 0.12, 0.02, 14), Vector3(0, 1.62, 0.14), carved, Vector3(90, 0, 0))
	sun.name = "Sun"
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.85, 0.55)
	glow.light_energy = 0.7
	glow.omni_range = 3.0
	glow.position = Vector3(0, 1.4, 0.8)
	tablet.add_child(glow)
	var at := spot(level, TABLET_AT)
	level._add_solid(at, Vector3(0.9, 1.7, 0.5))
	level.stations.append({"kind": TABLET_KIND, "cell": CELL, "pos": at, "used": false, "touch": TOUCH, "text": TABLET})


## A basin carved out of the rock, rimmed with stones and moss, with clear, faintly glowing water, a thin
## trickle running in from a crack behind it. Run into it to drink.
static func _spring(level: Level, root: Node3D) -> void:
	var stone := _grain(STONE, 0.35, 0.9, 0.12, 2.0)
	var dark := _grain(STONE_DARK, 0.3, 0.9, 0.15, 3.0)
	var moss := _grain(MOSS, 0.4, 1.0, 0.6, 6.0)
	var water := ClimbHelmet.material(WATER, 0.1, 0.1, 0.1, 0.2)
	water.emission_enabled = true
	water.emission = WATER
	water.emission_energy_multiplier = 0.5
	water.albedo_color = Color(1, 1, 1, 0.85)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var spring := Node3D.new()
	spring.name = "Spring"
	root.add_child(spring)
	spring.position = Vector3(SPRING_AT.x, 0.0, SPRING_AT.y)
	_node(spring, _cylinder(0.62, 0.7, 0.34, 14), Vector3(0, 0.17, 0), dark)
	_node(spring, _cylinder(0.5, 0.5, 0.04, 14), Vector3(0, 0.33, 0), water).name = "Water"
	for i in 9:
		var a := TAU * i / 9.0
		var block := _node(spring, _sphere(0.2, 0.3), Vector3(cos(a) * 0.62, 0.3, sin(a) * 0.62), stone if i % 2 == 0 else dark,
				Vector3(0, -rad_to_deg(a), 0), Vector3(1.0, 0.9, 1.3))
		block.name = "Rim%d" % i
	for i in 4:
		var a := 0.5 + i * 1.7
		_node(spring, _sphere(0.14, 0.1), Vector3(cos(a) * 0.66, 0.48, sin(a) * 0.66), moss, Vector3.ZERO, Vector3(1.4, 1.0, 1.4))
	# The crack the water comes out of and the thin trickle falling from it.
	_node(spring, _sphere(0.4, 0.8), Vector3(0.0, 0.5, -0.78), dark, Vector3.ZERO, Vector3(0.9, 1.0, 0.5))
	var trickle := _node(spring, _cylinder(0.012, 0.018, 0.28, 6), Vector3(0, 0.46, -0.62), water, Vector3(-10, 0, 0))
	trickle.name = "Trickle"
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.6, 0.85, 1.0)
	glow.light_energy = 0.6
	glow.omni_range = 2.6
	glow.position = Vector3(0, 0.8, 0)
	spring.add_child(glow)
	var at := spot(level, SPRING_AT)
	level._add_solid(at, Vector3(1.3, 0.5, 1.3))
	level.stations.append({"kind": SPRING_KIND, "cell": CELL, "pos": at, "used": false, "touch": TOUCH + 0.3})


## The viper bites the hero on the face: a few life points and the poison, and the climb goes on.
static func bite(hero: Player) -> void:
	hero.hp = maxi(1, hero.hp - BITE)
	hero.hurt.emit(BITE)
	hero.afflict("gift")
	Effects.head_text(hero.level, hero, 2.2, "-%d" % BITE, Color(0.8, 0.3, 0.3))
	Events.tell(Lang.t(BITTEN), Color(0.9, 0.5, 0.4))
	Events.teach(BITTEN_LEARN)


## The hero drinks: all the life back and no poison, and at the first sip the compendium learns of it.
static func drink(game: Node, s: Dictionary) -> void:
	game.player.face(s.pos - game.player.global_position)
	var gain: int = game.player.max_hp - game.player.hp
	game.player.hp += gain
	if gain > 0:
		Effects.float_text(game.level, game.player.global_position + Vector3(0, 2.6, 0), "+%d" % gain, Color(0.5, 1.0, 0.5))
	var cured: bool = game.player.cure()
	game.player.play_flourish("PickUp", 0.6)
	Sfx.play(game, "drink")
	var burst := Effects.make_sparkles(Color(0.6, 0.85, 1.0), true)
	burst.position = game.player.global_position + Vector3(0, 1.0, 0)
	game.level.add_child(burst)
	Events.teach(SPRING_LEARN)
	game.show_message(Lang.t(SPRING_CURED if cured else (SPRING_HEALED if gain > 0 else SPRING_FULL)))
	game._update_hud()


# --- The silver edelweiss ------------------------------------------------------------------------

## The key of a plant in the saved game: one bloom each, and a new one every REGROW_DAYS days (the old
## ones are dropped from the saved game).
static func plant_key(index: int, day: int) -> String:
	return "%s:%d:%d" % [INGREDIENT, day / REGROW_DAYS, index]


## How many silver edelweiss bloom on the ledge right now.
static func blooming(level: Level) -> int:
	return level._pickups.filter(func(p: Dictionary) -> bool: return str(p.get("id", "")).begins_with(INGREDIENT + ":")).size()


## Lets the plants of `level` grow as they do on `day`: the ones picked in this period stay gone, and any
## that was picked in an earlier one is back (`animate`: the bloom opens before the hero's eyes).
static func refresh(level: Level, day: int, animate := false) -> void:
	if ClimbSpots.at(level, CELL).is_empty():
		return
	for key in level.taken.keys():
		if str(key).begins_with(INGREDIENT + ":") and not str(key).begins_with("%s:%d:" % [INGREDIENT, day / REGROW_DAYS]):
			level.taken.erase(key)
	for i in PLANTS.size():
		var key := plant_key(i, day)
		var there := false
		for p: Dictionary in level._pickups:
			if p.get("slot", -1) == i:
				# One that nobody picked stays, under this period's key from now on.
				p.id = key
				there = true
		if level.taken.has(key) or there:
			continue
		_grow(level, i, key, animate)


## One plant: a rosette of woolly grey-green leaves, a short stem and a star of felty white bracts round
## a golden heart. It glows a little, so it can be seen at night.
static func _grow(level: Level, index: int, key: String, animate: bool) -> void:
	var felt := ClimbHelmet.material(FELT, 0.15, 0.0, 1.0, 0.6)
	felt.uv1_scale = Vector3.ONE * 2.0
	var white := ClimbHelmet.material(WHITE, 0.12, 0.0, 1.0, 0.7)
	white.uv1_scale = Vector3.ONE * 2.0
	white.emission_enabled = true
	white.emission = Color(0.85, 0.92, 1.0)
	white.emission_energy_multiplier = 0.25
	var gold := ClimbHelmet.material(GOLD, 0.2, 0.0, 0.8, 1.0)
	var leaf := _grain(LEAF, 0.25, 0.95, 0.5, 2.0)
	var holder := Node3D.new()
	holder.name = "Edelweiss%d" % index
	var at := spot(level, PLANTS[index])
	level.add_child(holder)
	holder.global_position = at
	holder.rotation.y = index * 1.3
	# The rosette of leaves at the foot: long, narrow, furry.
	for i in 7:
		var a := TAU * i / 7.0
		var blade := _node(holder, _sphere(0.05, 0.3), Vector3(cos(a) * 0.1, 0.05, sin(a) * 0.1), leaf if i % 2 == 0 else felt,
				Vector3(0, -rad_to_deg(a), 62.0), Vector3(1.0, 1.0, 0.35))
		blade.name = "Leaf%d" % i
	_node(holder, _cylinder(0.008, 0.012, 0.3, 5), Vector3(0, 0.17, 0), leaf).name = "Stem"
	# Two rings of pointed bracts, the lower longer, round a few tiny golden florets.
	var star := Node3D.new()
	star.name = "Star"
	holder.add_child(star)
	star.position = Vector3(0, 0.33, 0)
	for ring in 2:
		for i in 8:
			var a := TAU * (i + ring * 0.5) / 8.0
			var bract := _node(star, _cylinder(0.0, 0.028, 0.2 - ring * 0.05, 5), Vector3(cos(a) * 0.075, -ring * 0.012, sin(a) * 0.075),
					white if ring == 1 else felt, Vector3(0, -rad_to_deg(a), -90.0 + 8.0 * ring), Vector3(1.0, 1.0, 0.45))
			bract.name = "Bract%d_%d" % [ring, i]
	for i in 5:
		var a := TAU * i / 5.0
		_node(star, _sphere(0.02), Vector3(cos(a) * 0.016, 0.02, sin(a) * 0.016), gold)
	_node(star, _sphere(0.025), Vector3(0, 0.025, 0), gold)
	# The pickups hang the middle of a flower at the node (see Outdoor._grow_flower), the node sits on the ledge.
	level._pickups.append({"node": holder, "kind": "ingredient", "ingredient": INGREDIENT, "id": key, "slot": index, "radius": 0.75})
	if animate:
		holder.scale = Vector3.ONE * 0.01
		var tween := level.create_tween()
		tween.tween_property(holder, "scale", Vector3.ONE, 1.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
