class_name Mines
## The three mines in the high valley of the mountains (see Mountains and
## the "]" entrances on the open-air map), each going deeper and each with
## a setting of its own (the header "theme:" of its floor):
##
## - Mine 1, the copper pit ("kupfer"): timber-propped tunnels lit by fire,
##   dead miners and mountain orcs.
## - Mine 2, the crystal grotto ("kristall"): cold caves full of glowing
##   crystals, crystal slimes, ice wolves and bats.
## - Mine 3, the dwarves' old workings ("zwerge") and below them the ember
##   tunnels and the heart of the mountain ("glut"), where the Mountain King
##   waits.
##
## The deep floors of mine 3 are sealed: its way down ("^" on a floor with
## "seal:") opens only for a hero who knows both runes of the dwarves. Each
## rune is carved on a stone tablet ("T") at the far end of mine 1 and of
## mine 2; reading a tablet puts its text in the compendium (see
## Events.writing_found), and that is all the seal asks for.
##
## How the floors hang together (headers of a floor):
##   down: <building>   where its "^" leads, e.g. "down: mine3b"
##   up: <building>     where its stairs ("E") lead, instead of outside
##   seal: runen        its "^" needs both runes
##
## The glowing crystal clusters ("%") can be mined: run into one and the
## hero knocks CRYSTAL_YIELD grotto crystals off it into the ingredient pouch
## (see Crafting). A mined cluster stays dull until the next morning, then it
## has grown back (kept in Level.taken as crystal_key plus the day it was
## mined). The crystals are cut into jewellery at the gem cutter's wheel on
## the crafting square; the recipes come with the first crystals.
##
## Difficulty: the mines and the road there are made for an experienced hero
## in the best gear there is, BENCHMARK below. The monsters' numbers are in
## Enemy.KINDS (the kinds marked "mountain"). On top of that every mine
## lifts its monsters to the hero levels it is made for (HeroLevel.AREAS):
## mine 1 for 11 to 13, mine 2 for 13 to 15, mine 3 for 16 to 20 (the
## top, HeroLevel.WORLD_TOP).

## The hero these places are made for: the owner's own seasoned character
## (Rabenklinge, Wappenschild, Plattenpanzer, Ritterhelm, Königsumhang,
## Flinke Stiefel, Amulett der Eile, two phoenix feathers; Klingen 4,
## Blocken 5). Life, power (the damage of a blow), hardening (taken off every
## hit) and the chance to block with the shield. Every mountain monster takes
## at least two of their blows, and none fells them in fewer than four.
const BENCHMARK := {"life": 18, "power": 12, "hardening": 4, "block": 0.66}

## The two tablets: the German text of each, as it goes into the compendium.
const RUNE_ORE := "Eine Steintafel der alten Zwerge: »Die Tiefe der dritten Grube verschlossen wir mit zwei Runen. Die erste ist die Rune des Erzes: ein Hammer über einem Berg. Wer beide kennt, öffnet das Siegel.« Die zweite Rune, so heißt es, ist in der Kristallgrotte, der zweiten Mine, in Eis geritzt."
const RUNE_ICE := "Eine Tafel aus klarem Eis: »Die zweite Rune ist die Rune des Eises: drei Spitzen, die nach oben zeigen. Wer sie und die Rune des Erzes kennt, dem öffnet sich das Siegel in der dritten Grube, und der Weg hinab zum Herzen des Berges ist frei.« Die erste Rune ist in der Kupfergrube, der ersten Mine, in Stein gehauen."
## Which tablet stands in which setting.
const TABLETS := {"kupfer": RUNE_ORE, "kristall": RUNE_ICE}

## The light of each setting: ambient colour and strength, and the colour
## of the light from above.
const MOODS := {
	"kupfer": {"ambient": Color(0.55, 0.4, 0.28), "energy": 0.32, "light": Color(1.0, 0.78, 0.55)},
	"kristall": {"ambient": Color(0.32, 0.45, 0.62), "energy": 0.36, "light": Color(0.7, 0.85, 1.0)},
	"zwerge": {"ambient": Color(0.48, 0.44, 0.38), "energy": 0.3, "light": Color(0.95, 0.85, 0.7)},
	"zinne": {"ambient": Color(0.6, 0.58, 0.7), "energy": 0.5, "light": Color(1.0, 0.92, 0.82)},
	"glut": {"ambient": Color(0.6, 0.28, 0.18), "energy": 0.34, "light": Color(1.0, 0.55, 0.35)},
}

const WOOD := Color(0.36, 0.24, 0.14)
const CRYSTAL := Color(0.45, 0.85, 1.0)
const EMBER := Color(1.0, 0.42, 0.12)

## What a crystal cluster yields, and the ingredient it is (see Crafting).
const CRYSTAL_ID := "grottenkristall"
const CRYSTAL_YIELD := 2
## How bright a mined cluster still glows, and how tall its stubs are.
const SPENT_GLOW := 0.15
const SPENT_HEIGHT := 0.3
## The station kind of a crystal cluster.
const CLUSTER := "kristalle"
## What the compendium says about mining, the first time.
const CRYSTAL_LEARN := "In den Minen wachsen leuchtende Kristalle. Lauf gegen ein Kristallbüschel, um zwei Grottenkristalle abzuschlagen; bis zum nächsten Morgen wächst es nach. Am Schleifrad auf dem Handwerkerplatz im Dorf schleifst du daraus Schmuck."

## The Mountain King's own hammer: he drops it the first time he falls.
const TROPHY := "runenhammer"
const KING_DEFEATED := "boss:bergkoenig"


## Whether the hero knows the rune carved in `theme`'s tablet.
static func knows(lore: Array, theme: String) -> bool:
	return lore.has(TABLETS.get(theme, ""))


## Whether the hero knows both runes, so the seal opens.
static func unsealed(lore: Array) -> bool:
	return knows(lore, "kupfer") and knows(lore, "kristall")


## What the seal says when the hero runs into it without both runes.
static func seal_text(lore: Array) -> String:
	var ore := knows(lore, "kupfer")
	var ice := knows(lore, "kristall")
	if not ore and not ice:
		return "Ein Siegel aus Stein verschließt den Schacht in die Tiefe. Zwei Runen fehlen darauf. Die alten Zwerge haben sie in der Kupfergrube und in der Kristallgrotte hinterlassen."
	if ore:
		return "Du ritzt die Rune des Erzes in das Siegel, und sie glimmt auf. Die zweite fehlt noch: Sie steht in der Kristallgrotte, der zweiten Mine."
	return "Du ritzt die Rune des Eises in das Siegel, und sie glimmt auf. Die erste fehlt noch: Sie steht in der Kupfergrube, der ersten Mine."


## The light of a setting, or {} for none.
static func mood(theme: String) -> Dictionary:
	var elder := ElderLair.mood(theme)
	return MOODS.get(theme, elder if not elder.is_empty() else SternHall.mood(theme))


## Builds the mine tiles of `level` (see Tiles.DUNGEON). True if `ch` was one.
static func build_cell(level: Level, c: Vector2i, ch: String) -> bool:
	var pos := level.cell_to_world(c)
	match ch:
		"j":
			_build_prop(level, c, pos)
		"%":
			_build_crystals(level, c, pos)
		"~":
			EmberCracks.build(level, c, pos)
		"T":
			_build_tablet(level, c, pos)
		"^":
			_build_shaft(level, c, pos)
		_:
			return false
	return true


static func _box(level: Level, pos: Vector3, size: Vector3, mat: Material, rot := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = rot
	level.add_child(mi)
	return mi


static func _material(colour: Color, glow := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.85
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = colour
		mat.emission_energy_multiplier = glow
	return mat


static func _light(level: Level, pos: Vector3, colour: Color, energy: float, reach: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = colour
	light.light_energy = energy
	light.omni_range = reach
	light.omni_attenuation = 1.4
	light.position = pos
	level.add_child(light)
	return light


## A timber frame over the tunnel: two posts against the walls and a beam
## across, so the hero walks under it.
static func _build_prop(level: Level, c: Vector2i, pos: Vector3) -> void:
	var wood := _material(WOOD)
	var across_x := level.cell_char(c + Vector2i(-1, 0)) == "#" or level.cell_char(c + Vector2i(1, 0)) == "#"
	var half := Level.TILE * 0.5 - 0.3
	for side in [-1.0, 1.0]:
		var at := pos + (Vector3(side * half, 1.9, 0) if across_x else Vector3(0, 1.9, side * half))
		_box(level, at, Vector3(0.4, 3.8, 0.4), wood)
	_box(level, pos + Vector3(0, 3.7, 0), Vector3(Level.TILE, 0.4, 0.45) if across_x else Vector3(0.45, 0.4, Level.TILE), wood)


## A cluster of glowing crystals growing out of the floor, lighting the cave
## around them in cold blue. The hero can mine it (a CLUSTER station).
static func _build_crystals(level: Level, c: Vector2i, pos: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(pos)
	var mat := _material(CRYSTAL, 1.6)
	mat.albedo_color.a = 0.85
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var spikes := []
	for i in 6:
		var mi := MeshInstance3D.new()
		var prism := CylinderMesh.new()
		prism.radial_segments = 6
		prism.rings = 1
		prism.top_radius = 0.02
		prism.bottom_radius = rng.randf_range(0.22, 0.42)
		prism.height = rng.randf_range(1.2, 2.8)
		mi.mesh = prism
		mi.material_override = mat
		var angle := TAU * i / 6.0 + rng.randf_range(-0.3, 0.3)
		var out := 0.0 if i == 0 else rng.randf_range(0.35, 0.9)
		# Grown from a point on the floor, so a mined cluster shrinks to
		# stubs there (see set_cluster).
		var root := Node3D.new()
		root.position = pos + Vector3(cos(angle) * out, 0.0, sin(angle) * out)
		root.rotation = Vector3(rng.randf_range(-0.35, 0.35), rng.randf() * TAU, rng.randf_range(-0.35, 0.35))
		mi.position = Vector3(0, prism.height * 0.4, 0)
		root.add_child(mi)
		level.add_child(root)
		spikes.append(root)
	var light := _light(level, pos + Vector3(0, 1.6, 0), CRYSTAL, 2.6, 9.0)
	level._add_solid(pos, Vector3(2.2, 2.4, 2.2))
	level.stations.append({"kind": CLUSTER, "cell": c, "pos": pos, "used": false, "spent": false,
			"spikes": spikes, "mat": mat, "light": light, "energy": light.light_energy})


## The key in Level.taken for a crystal cluster at cell `c` mined on `day`.
static func crystal_key(c: Vector2i, day: int) -> String:
	return "crystal:%d:%d@%d" % [c.x, c.y, day]


## The day the cluster at `c` was last mined, from Level.taken, or -1.
static func mined_on(taken: Dictionary, c: Vector2i) -> int:
	var prefix := "crystal:%d:%d@" % [c.x, c.y]
	for key in taken:
		if str(key).begins_with(prefix):
			return int(str(key).substr(prefix.length()))
	return -1


## Shows a cluster full grown or mined down to dull stubs.
static func set_cluster(station: Dictionary, spent: bool, animate := false) -> void:
	station.spent = spent
	var height := SPENT_HEIGHT if spent else 1.0
	var glow := 1.6 * (SPENT_GLOW if spent else 1.0)
	var energy: float = station.energy * (SPENT_GLOW if spent else 1.0)
	var light: OmniLight3D = station.light
	var mat: StandardMaterial3D = station.mat
	if not animate or not light.is_inside_tree():
		for root in station.spikes:
			root.scale = Vector3(1.0, height, 1.0)
		mat.emission_energy_multiplier = glow
		light.light_energy = energy
		return
	var tween := light.create_tween().set_parallel(true)
	for root in station.spikes:
		tween.tween_property(root, "scale", Vector3(1.0, height, 1.0), 0.6 if spent else 1.6)
	tween.tween_property(mat, "emission_energy_multiplier", glow, 0.6 if spent else 1.6)
	tween.tween_property(light, "light_energy", energy, 0.6 if spent else 1.6)


## The clusters of `level` as the hero left them: one mined before `day`
## has grown back (its mark is gone), one mined today is still dull.
## `animate`: grows back before the hero's eyes (a new morning).
static func refresh_crystals(level: Level, day: int, animate := false) -> void:
	for st in level.stations:
		if st.kind != CLUSTER:
			continue
		var mined := mined_on(level.taken, st.cell)
		if mined >= 0 and mined < day:
			level.taken.erase(crystal_key(st.cell, mined))
			mined = -1
		var spent := mined >= 0
		if spent != st.spent or not animate:
			set_cluster(st, spent, animate)


## Mines a cluster on `day`: marks it as mined and dims it. Returns the
## crystals it gives, 0 when it was mined already.
static func mine(level: Level, station: Dictionary, day: int) -> int:
	if station.spent:
		return 0
	level.taken[crystal_key(station.cell, day)] = true
	set_cluster(station, true, true)
	var burst := Effects.make_sparkles(CRYSTAL, true)
	burst.position = station.pos + Vector3(0, 1.2, 0)
	level.add_child(burst)
	return CRYSTAL_YIELD


## A stone tablet with the dwarves' writing: run into it to read it.
static func _build_tablet(level: Level, c: Vector2i, pos: Vector3) -> void:
	var stone := _material(Color(0.5, 0.5, 0.52) if level.theme != "kristall" else Color(0.7, 0.88, 1.0), 0.0 if level.theme != "kristall" else 0.5)
	_box(level, pos + Vector3(0, 1.1, 0), Vector3(1.8, 2.2, 0.45), stone)
	_box(level, pos + Vector3(0, 0.15, 0), Vector3(2.3, 0.3, 0.9), _material(Color(0.36, 0.35, 0.36)))
	# Lines of carved writing, glowing faintly.
	var carved := _material(Color(1.0, 0.82, 0.45) if level.theme != "kristall" else CRYSTAL, 1.2)
	for row in 4:
		_box(level, pos + Vector3(0, 1.75 - row * 0.36, 0.24), Vector3(1.3 - (row % 2) * 0.3, 0.07, 0.03), carved)
	_light(level, pos + Vector3(0, 1.8, 1.2), Color(1.0, 0.85, 0.6), 1.6, 6.0)
	level._add_solid(pos, Vector3(2.3, 2.2, 1.0))
	level.stations.append({"kind": "tafel", "cell": c, "pos": pos, "used": false,
			"text": TABLETS.get(level.theme, RUNE_ORE)})


## The way down to the next floor: stone steps sinking into the dark, a timber frame round
## it and the warm breath of the deep rising out of it. On a sealed floor a
## stone slab lies over it, with a place for each of the two runes.
static func _build_shaft(level: Level, c: Vector2i, pos: Vector3) -> void:
	# Steps going down, away from the side the hero comes from.
	var away := pos - level.cell_to_world(level._open_side(c))
	away.y = 0.0
	StairsDown.build(level, pos, Level.TILE, away.normalized() if away.length() > 0.1 else Vector3(0, 0, -1))
	var wood := _material(WOOD)
	for side in [-1.0, 1.0]:
		_box(level, pos + Vector3(side * 1.65, 0.15, 0), Vector3(0.35, 0.3, 3.6), wood)
		_box(level, pos + Vector3(0, 0.15, side * 1.65), Vector3(3.6, 0.3, 0.35), wood)
	var station := {"kind": "schacht", "cell": c, "pos": pos, "used": false, "building": level.down_to}
	if level.seal != "":
		var slab := _box(level, pos + Vector3(0, 0.25, 0), Vector3(3.0, 0.3, 3.0), _material(Color(0.38, 0.37, 0.39)))
		station.slab = slab
		for k in 2:
			var rune := _box(level, pos + Vector3(-0.7 + 1.4 * k, 0.42, 0), Vector3(0.7, 0.05, 0.7), _material(Color(0.2, 0.2, 0.22)))
			station["rune_%d" % k] = rune
	else:
		_light(level, pos + Vector3(0, 0.6, 0), EMBER, 1.6, 6.0)
	level._add_solid(pos, Vector3(3.2, 1.0, 3.2))
	level.shaft_side = level.cell_to_world(level._open_side(c))
	level.stations.append(station)


## Lights the runes on a sealed shaft that the hero knows, and opens the
## slab once both are there. True if the way down is open.
static func show_runes(station: Dictionary, lore: Array) -> bool:
	var colours := [EMBER, CRYSTAL]
	for k in 2:
		var rune: MeshInstance3D = station.get("rune_%d" % k)
		if rune and knows(lore, ["kupfer", "kristall"][k]):
			rune.material_override = _material(colours[k], 2.5)
	if not station.has("slab") or not unsealed(lore):
		return not station.has("slab")
	var slab: MeshInstance3D = station.slab
	if is_instance_valid(slab):
		slab.position.x += 3.2
		slab.rotation.y = 0.4
	station.erase("slab")
	return true
