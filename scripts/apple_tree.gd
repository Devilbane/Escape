class_name AppleTree
extends RefCounted
## The apple tree of the garden (see GardenDecor and HouseFurniture.KINDS "apfelbaum"): Ilse sells
## it as a seedling, the hero plants it in the open-air part of their plot, and it grows through
## the years and follows the seasons.
##
## Growth goes by the season days (see Weather.season and Outdoor.season_day) since it was planted
## (the piece's "planted" in HouseFurniture.placed, kept in the furniture books with the house):
##   Setzling          its first season: a sprig tied to a stake;
##   Bäumchen          the rest of its first year: a thin trunk with a little crown;
##   Junger Apfelbaum  its second year: it blossoms in spring and bears a few apples;
##   Apfelbaum         from its third year on: a broad crown, white with blossom in spring, full of
##                     apples in summer and autumn.
## With a season of one real week that is a sapling after a week, a young tree bearing fruit after
## four weeks and a full-grown tree after eight.
##
## The seasons: blossom in spring, green leaves and red apples in summer, red, orange and gold
## leaves (and apples) in autumn, bare branches in winter. Running into a tree with apples picks
## them all into the bag (Items "apfel", which deer love, see Companions); a tree bears again the
## next season it is in fruit (once in summer, once in autumn).
##
## Moved or turned with the furnishing tool, it keeps its age; picked up into the store, or sent
## back when a roof is built over it, it is a seedling again.

## The furniture kind, and its station (see Game._use_station).
const KIND := "apfelbaum"
const STATION := "apfelbaum"
## What a picked apple is.
const APPLE := "apfel"

## The growth stages.
const SEEDLING := 0
const SAPLING := 1
const YOUNG := 2
const MATURE := 3
const STAGE_NAMES := ["Setzling", "Bäumchen", "Junger Apfelbaum", "Apfelbaum"]
## When each stage starts, in seasons since planting.
const STAGE_FROM := [0, 1, 4, 8]
## The apples a tree bears each season it is in fruit, by stage.
const APPLES := [0, 0, 4, 12]

## What the compendium says once the hero has picked apples.
const LEARN := "Apfelbäume: Bei Raumausstatterin Ilse kaufst du einen Setzling für deinen Garten (unter freiem Himmel auf deinem Grundstück). Er wächst mit den Jahreszeiten: nach einer Jahreszeit ist er ein Bäumchen, im zweiten Jahr ein junger Baum, der blüht und ein paar Äpfel trägt, ab dem dritten Jahr ein großer Apfelbaum. Im Frühling blüht er, im Sommer und im Herbst hängen Äpfel daran: Lauf dagegen, um sie zu pflücken. Rehe lieben Äpfel. Verschiebst du den Baum, behält er sein Alter; nimmst du ihn ins Lager, ist er wieder ein Setzling."

## Leaves by season, blossom and apple colours, bark.
const LEAF := {"spring": Color(0.4, 0.64, 0.24), "summer": Color(0.2, 0.44, 0.15)}
const AUTUMN_LEAVES := [Color(0.7, 0.4, 0.12), Color(0.72, 0.56, 0.18), Color(0.54, 0.22, 0.1), Color(0.46, 0.44, 0.16), Color(0.62, 0.3, 0.1)]
const BLOSSOM := [Color(0.98, 0.96, 0.94), Color(0.98, 0.84, 0.88), Color(0.96, 0.74, 0.8)]
const APPLE_COLOUR := Color(0.78, 0.12, 0.09)
const BARK := Color(0.33, 0.24, 0.17)

## The sizes by stage: trunk height and thickness, where a young plant's leaves sit, the crown's
## radius, the size of a clump of leaves, and the strong limbs of a grown tree.
const TRUNK := [0.45, 1.1, 1.2, 1.7]
const THICK := [0.012, 0.035, 0.08, 0.16]
const CROWN_AT := [0.5, 1.25, 0.0, 0.0]
const CROWN := [0.12, 0.35, 0.95, 1.7]
const BLOB := [0.07, 0.2, 0.4, 0.6]
const SCAFFOLDS := [0, 0, 3, 5]
const BLOBS := [3, 5, 9, 14]

static var _balls := {}
static var _dapple: NoiseTexture2D


## The length of a season in season days.
static func season_days() -> int:
	return maxi(1, Weather.YEAR_DAYS / 4)


## How many season days the tree has grown on `day` (never less than none).
static func age(piece: Dictionary, day: int) -> int:
	return maxi(0, day - int(piece.get("planted", day)))


## The growth stage of a tree on `day`.
static func stage(piece: Dictionary, day: int) -> int:
	var seasons := age(piece, day) / season_days()
	var out := SEEDLING
	for i in STAGE_FROM.size():
		if seasons >= STAGE_FROM[i]:
			out = i
	return out


## Which season of all time `day` is in (each harvest is kept by it).
static func season_index(day: int) -> int:
	return floori(float(day) / season_days())


## Whether the tree's season on `day` is one for apples (summer and autumn).
static func fruit_season(day: int) -> bool:
	var s := Weather.season(day)
	return s == Weather.SUMMER or s == Weather.AUTUMN


## How many apples hang on the tree on `day`.
static func apples(piece: Dictionary, day: int) -> int:
	if not fruit_season(day) or int(piece.get("picked", -999999)) == season_index(day):
		return 0
	return APPLES[stage(piece, day)]


## Season days until the tree first bears apples (0 once it does).
static func days_to_fruit(piece: Dictionary, day: int) -> int:
	return maxi(0, STAGE_FROM[YOUNG] * season_days() - age(piece, day))


## The prompt beside the tree.
static func prompt(piece: Dictionary, day: int) -> String:
	var n := apples(piece, day)
	if n > 0:
		return Lang.t("Dagegenlaufen, um %d Äpfel zu pflücken") % n
	var name := Lang.t(STAGE_NAMES[stage(piece, day)])
	var wait := days_to_fruit(piece, day)
	if wait > 0:
		return Lang.t("%s: Er trägt in %d Tagen zum ersten Mal Äpfel.") % [name, wait]
	if fruit_season(day):
		return Lang.t("%s: Abgeerntet. Zur nächsten Erntezeit reifen neue Äpfel.") % name
	return Lang.t("%s: Äpfel reifen im Sommer und im Herbst.") % name


## The prompt beside the hero's own tree a station belongs to.
static func station_prompt(game: Node, station: Dictionary) -> String:
	var piece := _own_piece(game.house_furnisher, station)
	return "" if piece.is_empty() else prompt(piece, game.level.season_day)


## The hero runs into their tree: every apple on it goes into the bag while there is room.
static func pick(game: Node, station: Dictionary) -> void:
	var furnisher: HouseFurnisher = game.house_furnisher
	var day: int = game.level.season_day
	var piece := _own_piece(furnisher, station)
	if piece.is_empty():
		return
	var n := apples(piece, day)
	if n <= 0:
		game.show_message(prompt(piece, day), 3.0)
		return
	var player: Player = game.player
	var got := 0
	while got < n and player.bag_fits(APPLE):
		player.bag.append(APPLE)
		got += 1
	if got == 0:
		game.show_message(Lang.t("Deine Tasche ist voll. Wirf im Inventar (Taste I) etwas weg."), 2.6)
		return
	# What did not fit stays lost: the tree is picked for this season.
	piece.picked = season_index(day)
	furnisher.furniture.save(game.hero_name)
	player.play_flourish("PickUp", 0.6)
	Sfx.play(game, "gear_soft_0", -2.0, station.pos)
	Effects.loot_text(game.level, player.global_position + Vector3(0, 3.0, 0), "+%d %s" % [got, Items.item_name(APPLE)], APPLE_COLOUR.lightened(0.3), DamageNumber.item_worth(APPLE))
	var said := Lang.t("Du pflückst einen Apfel.") if got == 1 else Lang.t("Du pflückst %d Äpfel.") % got
	if got < n:
		said += " " + Lang.t("Für mehr ist kein Platz in deiner Tasche.")
	game.show_message(said, 3.0)
	Events.teach(LEARN)
	furnisher.refresh()
	game._update_hud()


## The placed tree of the hero's furniture that a station belongs to, or {}.
static func _own_piece(furnisher: HouseFurnisher, station: Dictionary) -> Dictionary:
	var at: Dictionary = station.get("piece", {})
	for p in furnisher.furniture.placed:
		if p.kind == KIND and p.storey == at.get("storey") and p.x == at.get("x") and p.y == at.get("y"):
			return p
	return {}


## The village's apple trees: four full-grown ones round the fountain on the square, on the
## paved cells between its benches (the diagonal neighbours of the fountain). They follow the
## seasons like a garden tree, with apples to see in summer and autumn (not to pick: they belong
## to the village). A grown-up tree, planted long ago.
const VILLAGE_TREE := {"planted": -100000}
## Their size against a garden tree's.
const VILLAGE_SCALE := 1.15
## Round the fountain: the cells between the benches.
const ROUND_FOUNTAIN := [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]


## Plants the apple trees round every fountain of `level` (an Outdoor) on paved square cells and
## returns them as [{node, cell, look}] (see dress). Their cells leave the square's spots, and
## Outdoor makes them solid for the walkers' paths.
static func plant_round_fountains(level: Node3D) -> Array:
	var out := []
	for y in level.height:
		for x in level.width:
			if level.cell_char(Vector2i(x, y)) != "F":
				continue
			for d: Vector2i in ROUND_FOUNTAIN:
				var c := Vector2i(x, y) + d
				if level.cell_char(c) != ":":
					continue
				var pos: Vector3 = level.cell_to_world(c)
				var node := Node3D.new()
				node.name = "SquareAppleTree"
				node.position = pos
				node.rotation.y = hash("square apple:%s" % c) % 628 / 100.0
				node.scale = Vector3.ONE * VILLAGE_SCALE
				level.add_child(node)
				level._add_solid(pos, Vector3(0.5, 2.5, 0.5))
				level.spots.square.erase(pos)
				level.spots.market.erase(pos)
				out.append({"node": node, "cell": c, "look": ""})
	return out


## Draws the village's trees again when their look changes on `day` (the season, the apples).
static func dress(trees: Array, day: int) -> void:
	var look := "%s:%d" % [Weather.season(day), apples(VILLAGE_TREE, day)]
	for t in trees:
		if t.look == look:
			continue
		t.look = look
		var node: Node3D = t.node
		for child in node.get_children():
			node.remove_child(child)
			child.queue_free()
		build(node, VILLAGE_TREE, day)


## Builds the tree of `piece` as it looks on `day` into `root` (on the ground, middle at the
## origin) and returns its solids ({at, size}, local): the trunk.
static func build(root: Node3D, piece: Dictionary, day: int) -> Array:
	var grown := stage(piece, day)
	var season := Weather.season(day)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("apple tree:%s" % root.position.snapped(Vector3.ONE * 0.1))
	var bark := HomeStoreFurniture._mat(BARK, 0.9)
	# A ring of dug earth round its foot.
	var soil := HomeStoreFurniture._add(root, HomeStoreFurniture._cylinder(0.45 + grown * 0.1, 0.5 + grown * 0.1, 0.04), HomeStoreFurniture._mat(Color(0.22, 0.15, 0.1), 0.95), Vector3(0, 0.02, 0))
	soil.name = "Soil"
	if grown <= SAPLING:
		# The stake it is tied to, with a band of bast round both.
		var stake_h: float = TRUNK[grown] + 0.25
		HomeStoreFurniture._add(root, HomeStoreFurniture._cylinder(0.018, 0.022, stake_h), HomeStoreFurniture._mat(Color(0.6, 0.48, 0.3), 0.85), Vector3(0.09, stake_h * 0.5, 0))
		HomeStoreFurniture._add(root, HomeStoreFurniture._box(Vector3(0.14, 0.03, 0.05)), HomeStoreFurniture._mat(Color(0.78, 0.68, 0.42), 0.9), Vector3(0.045, TRUNK[grown] * 0.7, 0))
	# The trunk, leaning a little.
	var top := Vector3(rng.randf_range(-0.06, 0.06) * grown, TRUNK[grown], rng.randf_range(-0.06, 0.06) * grown)
	_limb(root, Vector3.ZERO, top, THICK[grown], bark)
	# The crown: clumps of leaves ([middle, radius]), on a grown tree at the ends of its limbs.
	var clumps := []
	var centre := top + Vector3(0, CROWN[grown] * 0.6, 0)
	if grown <= SAPLING:
		for i in BLOBS[grown]:
			var a: float = TAU * i / BLOBS[grown] + rng.randf_range(-0.3, 0.3)
			var out: float = CROWN[grown] * rng.randf_range(0.5, 1.0)
			clumps.append([top + Vector3(cos(a) * out, CROWN_AT[grown] - TRUNK[grown] + rng.randf_range(-0.1, 0.3) * CROWN[grown], sin(a) * out), BLOB[grown]])
	else:
		# A few strong limbs out and up from the top of the trunk, each forking into branches
		# that end in a clump of leaves on the skin of the crown (wider than it is high).
		var radii := Vector3(CROWN[grown], CROWN[grown] * 0.7, CROWN[grown])
		var limbs: int = SCAFFOLDS[grown]
		for k in limbs:
			var a: float = TAU * k / limbs + rng.randf_range(-0.35, 0.35)
			var fork := top + Vector3(cos(a) * radii.x * 0.45, radii.y * rng.randf_range(0.5, 0.8), sin(a) * radii.z * 0.45)
			_limb(root, top, fork, THICK[grown] * 0.62, bark)
			for j in 3:
				var b := a + (j - 1) * 0.55 + rng.randf_range(-0.2, 0.2)
				var dir := Vector3(cos(b), rng.randf_range(-0.25, 0.85), sin(b)).normalized()
				var end := centre + dir * radii * rng.randf_range(0.62, 0.86)
				_limb(root, fork, end, THICK[grown] * 0.3, bark)
				clumps.append([end, BLOB[grown] * rng.randf_range(0.8, 1.12)])
				if season == Weather.WINTER:
					# Bare twigs where the leaves were.
					for t in 3:
						var twig: Vector3 = end + (dir + Vector3(rng.randf_range(-0.7, 0.7), rng.randf_range(0.0, 0.8), rng.randf_range(-0.7, 0.7))) * BLOB[grown] * 0.75
						_limb(root, end, twig, THICK[grown] * 0.12, bark)
		# The top of the crown and its heart, so no light shows through the middle.
		clumps.append([centre + Vector3(0, radii.y * 0.62, 0), BLOB[grown] * 1.1])
		clumps.append([centre + Vector3(0, radii.y * 0.1, 0), BLOB[grown] * 1.2])
	if season != Weather.WINTER:
		var low: float = centre.y - CROWN[grown]
		for c in clumps:
			var colour: Color = AUTUMN_LEAVES[rng.randi() % AUTUMN_LEAVES.size()] if season == Weather.AUTUMN else LEAF.get(season, LEAF.summer)
			# The lower clumps lie in the crown's shade.
			var shade := clampf((c[0].y - low) / maxf(CROWN[grown] * 1.6, 0.1), 0.0, 1.0)
			var blob := HomeStoreFurniture._add(root, _ball(1.0, 14), _leaf_mat(colour * lerpf(0.72, 1.08, shade) * rng.randf_range(0.92, 1.06)), c[0])
			blob.scale = Vector3(1.12, 0.86, 1.12) * c[1]
			blob.rotation.y = rng.randf() * TAU
			blob.name = "Leaves"
	# Blossom in spring, on a tree old enough to bear: on the outside of the crown.
	if season == Weather.SPRING and grown >= YOUNG:
		for i in clumps.size() * 7:
			var c: Array = clumps[rng.randi() % clumps.size()]
			var at: Vector3 = c[0] + _on_clump(rng, c[1], (c[0] - centre).normalized() + Vector3(0, 0.3, 0))
			var b := HomeStoreFurniture._add(root, _ball(BLOB[grown] * 0.13, 6), HomeStoreFurniture._mat(BLOSSOM[rng.randi() % BLOSSOM.size()], 0.7), at)
			b.name = "Blossom"
	# The apples, hanging on the outside and the underside of the crown.
	var n := apples(piece, day)
	var outer := clumps.slice(0, maxi(1, clumps.size() - 2)) if grown >= YOUNG else clumps
	for i in n:
		var c: Array = outer[(i * 5 + 2) % outer.size()]
		var at: Vector3 = c[0] + _on_clump(rng, c[1], (c[0] - centre).normalized() * Vector3(1, 0, 1) + Vector3(0, -0.45, 0))
		var apple := HomeStoreFurniture._add(root, _ball(0.12 if grown == MATURE else 0.09, 8), HomeStoreFurniture._mat(APPLE_COLOUR * rng.randf_range(0.88, 1.12), 0.4), at)
		apple.name = "Apple"
	var thick: float = maxf(THICK[grown] * 2.0, 0.2) + 0.1
	return [{"at": Vector3.ZERO, "size": Vector3(thick, maxf(TRUNK[grown], 0.6), thick)}]


## A point on the skin of a clump of leaves of radius `r` (scaled like the clumps), leaning
## towards `towards` (a direction: outwards, up or down).
static func _on_clump(rng: RandomNumberGenerator, r: float, towards: Vector3) -> Vector3:
	var d := (Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() + towards * 0.9).normalized()
	return Vector3(d.x * 1.12, d.y * 0.86, d.z * 1.12) * r * 0.97


## A leafy material of `colour`: a soft dapple of light and shade over it, so a clump reads as
## leaves and not as a smooth ball.
static func _leaf_mat(colour: Color) -> StandardMaterial3D:
	var m := HomeStoreFurniture._mat(colour, 0.95)
	if _dapple == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_CELLULAR
		noise.frequency = 0.09
		_dapple = NoiseTexture2D.new()
		_dapple.width = 128
		_dapple.height = 128
		_dapple.seamless = true
		_dapple.noise = noise
		_dapple.color_ramp = Gradient.new()
		_dapple.color_ramp.set_color(0, Color(0.62, 0.66, 0.6))
		_dapple.color_ramp.set_color(1, Color(1.12, 1.12, 1.05).clamp())
	m.albedo_texture = _dapple
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * 1.6
	return m


## A low sphere of `radius` with `sides` segments round (shared: a tree has many).
static func _ball(radius: float, sides: int) -> SphereMesh:
	var key := "%.3f:%d" % [radius, sides]
	if not _balls.has(key):
		var mesh := SphereMesh.new()
		mesh.radius = radius
		mesh.height = radius * 2.0
		mesh.radial_segments = sides
		mesh.rings = maxi(3, sides / 2)
		_balls[key] = mesh
	return _balls[key]


## A round limb of bark from `from` to `to`, `r` thick at its foot.
static func _limb(root: Node3D, from: Vector3, to: Vector3, r: float, mat: Material) -> void:
	var length := from.distance_to(to)
	if length < 0.01:
		return
	var mesh := HomeStoreFurniture._cylinder(r * 0.6, r, length)
	mesh.radial_segments = 8
	mesh.rings = 1
	var limb := HomeStoreFurniture._add(root, mesh, mat, (from + to) * 0.5)
	limb.basis = Basis(Quaternion(Vector3.UP, (to - from).normalized()))
	limb.name = "Limb"
