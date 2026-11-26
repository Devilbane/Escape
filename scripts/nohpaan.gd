class_name Nohpaan
extends RefCounted
## Nohpaan: the hidden valley high above the farming valley, where no road goes. A hero who climbs the hardest wall
## of the mountains (a climbing wall whose header names this map as its summit, "summit: 42_nohpaan.txt:") comes
## down into a lush bowl of meadow, cedar and rhododendron, with mist drifting over the grass and a lotus pond at
## its heart. North of the pond, behind a red gate, stands the monastery whose monks teach the rare lessons (see
## Monastery); west and east lie a mist wood and the terraces, and in the north-west and north-east corners two
## sealed gates mark the roads to places still to come.
##
## The map is levels/42_nohpaan.txt ("building: nohpaan1", theme "nohpaan", walls "alpine"). Its letters
## (Tiles.DUNGEON): `π` cedar, `ψ` rhododendron, `ω` prayer wheel, `Ξ` stupa, `ζ` monastery wall, `Θ` the gate,
## `Λ` lotus pond, `Π` flagstones, `Γ` sealed gate. The way back down is the stairs `E`, which lead out onto the
## ledge of the summit garden (see SummitGarden).
##
## The light and the sounds of the map are Nohpaan's own (see mood, Soundscape); the rest is built from shapes and
## drawn textures (see NohpaanParts, NohpaanSurface) and costs next to nothing per frame (see NohpaanLife).

const BUILDING := "nohpaan1"
const THEME := "nohpaan"
const FILE := "42_nohpaan.txt"
const WALLS := "alpine"
## The mountains round the valley: how many tiles deep they reach into the rock.
const PEAK_FAR := 6

## Map letters (see Tiles.DUNGEON).
const CEDAR := "π"
const BUSH := "ψ"
const WHEEL := "ω"
const STUPA := "Ξ"
const WALL := "ζ"
const GATE := "Θ"
const POND := "Λ"
const FLAGS := "Π"
const SEALED := "Γ"
const LETTERS := "πψωΞζΘΛΠΓ"
## The letters of the monastery wall that join each other.
const WALL_LETTERS := "ζΘ"

## The station kind of a sealed gate (see Game._use_station), and what it says. The compendium learns of it too.
const SEALED_KIND := "nohpaan_tor"
const SEALED_TEXT := "Das Tor steckt unter dickem Eis. Dahinter rauscht ein Wind, der von weit her kommt. Noch gibt es keinen Weg hindurch."
const SEALED_LEARN := "Die versiegelten Tore von Nohpaan: In den Ecken des Tals führen zwei Tore in die Berge. Beide sind zugefroren. Die Mönche sagen, sie öffnen sich erst, wenn jemand die Lehren des Klosters ganz beherrscht."
## Where each sealed gate leads, by its name, for the future.
const SEALED_NAMES := {"7,9": "west", "57,9": "east"}

## The light of the valley: a high, cool, bright sun and a clear sky colour in the shadows.
const MOODS := {
	THEME: {"ambient": Color(0.78, 0.84, 0.92), "energy": 0.78, "light": Color(1.0, 0.95, 0.84)},
}
## The sound (see Soundscape).
const AMBIENCE := "amb_forest_deep"


static func mood(theme: String) -> Dictionary:
	return MOODS.get(theme, {})


static func is_here(lvl: Level) -> bool:
	return lvl != null and lvl.theme == THEME


## The file index of the valley among the game's levels, or -1.
static func level_index(game: Node) -> int:
	return game.level_files.find(game.LEVEL_DIR + FILE)


## Takes the hero to the valley (the climbing walls' summit, the testing panel's Travel tab): the usual fade and
## arrival at the map's start. Returns whether the trip began.
static func enter(game: Node) -> bool:
	var index := level_index(game)
	if index < 0:
		return false
	return game.teleport_to(index, false, "")


## The way back down: the stairs of the valley lead out onto the ledge of the summit garden (see SummitGarden).
static func place_door(outdoor: Level) -> void:
	if ClimbSpots.at(outdoor, SummitGarden.CELL).is_empty():
		return
	outdoor.doors[BUILDING] = SummitGarden.spot(outdoor, Vector2(0.0, 0.7))


## Builds what the map letter `ch` stands for on the tile `c` of `lvl`.
static func build_cell(lvl: Level, c: Vector2i, ch: String) -> void:
	match ch:
		CEDAR:
			NohpaanParts.cedar(lvl, c)
		BUSH:
			NohpaanParts.rhododendron(lvl, c)
		WHEEL:
			var drums: Array = lvl.get_meta("nohpaan_drums", [])
			drums.append(NohpaanParts.prayer_wheel(lvl, c))
			lvl.set_meta("nohpaan_drums", drums)
		STUPA:
			NohpaanParts.stupa(lvl, c)
		WALL:
			NohpaanParts.wall_piece(lvl, c)
		GATE:
			NohpaanParts.gate(lvl, c)
		POND:
			NohpaanParts.pond_cell(lvl, c)
		FLAGS:
			NohpaanParts.flagstone(lvl, c)
		SEALED:
			var key := "%d,%d" % [c.x, c.y]
			NohpaanParts.sealed_gate(lvl, c, SEALED_NAMES.get(key, key))
			var pos := lvl.cell_to_world(c)
			lvl.stations.append({"kind": SEALED_KIND, "cell": c, "pos": pos + Vector3(0, 0, 0.6), "used": false, "touch": 1.6})


## Running into a sealed gate: what it says, once also into the compendium.
static func use_sealed(game: Node, s: Dictionary) -> void:
	game.player.face(s.pos - game.player.global_position)
	game.player.play("Idle")
	Events.teach(SEALED_LEARN)
	game.show_message(Lang.t(SEALED_TEXT), 4.0)


## What the whole map gets on top of its tiles: the life of the valley (turning wheels, fluttering flags, mist) and
## the mountains on the rock round it.
static func dress(lvl: Level) -> void:
	var life := NohpaanLife.new()
	lvl.add_child(life)
	life.setup(lvl)
	_pave(lvl)
	_mountains(lvl)


## The paved parts of the monastery (tile rectangles: the hall and the courtyard path): flagstones also under what
## stands there (monks, braziers), which have letters of their own on the map.
const PAVED := [Rect2i(25, 4, 15, 4), Rect2i(31, 9, 3, 7)]


static func _pave(lvl: Level) -> void:
	for rect: Rect2i in PAVED:
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var c := Vector2i(x, y)
				var ch := lvl.cell_char(c)
				if ch != FLAGS and ch != "#" and not "EΘ".contains(ch) and not WALL_LETTERS.contains(ch):
					NohpaanParts.flagstone(lvl, c)


## How far (in tiles, as the king moves) a rock tile lies from the nearest open one, up to FAR.
static func _depths(lvl: Level) -> Dictionary:
	var depth := {}
	var front: Array[Vector2i] = []
	for y in lvl.height:
		for x in lvl.width:
			if lvl.cell_char(Vector2i(x, y)) != "#":
				depth[Vector2i(x, y)] = 0
				front.append(Vector2i(x, y))
	var round := 0
	while not front.is_empty() and round < PEAK_FAR:
		round += 1
		var next: Array[Vector2i] = []
		for c in front:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var n := c + Vector2i(dx, dy)
					if n.x < 0 or n.y < 0 or n.x >= lvl.width or n.y >= lvl.height or depth.has(n):
						continue
					depth[n] = round
					next.append(n)
		front = next
	return depth


## The rock of the map's edge is mountain: peaks stand on the wall tops, low next to the valley and high behind, so the
## hero in the valley sees a ring of crags and snow, and the view over a near wall stays clear.
static func _mountains(lvl: Level) -> void:
	var holder := Node3D.new()
	holder.name = "Mountains"
	lvl.add_child(holder)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(lvl.level_name + "gipfel")
	var depth := _depths(lvl)
	for y in lvl.height:
		for x in lvl.width:
			var c := Vector2i(x, y)
			if lvl.cell_char(c) != "#":
				continue
			var d: int = depth.get(c, PEAK_FAR)
			if d < 1:
				continue
			# Fewer peaks next to the valley and the nearer side of it, more in the depth.
			if rng.randf() > (0.06 if d == 1 else 0.1):
				continue
			var north := 1.0 - float(y) / float(lvl.height)
			var reach := float(mini(d, PEAK_FAR))
			var height := rng.randf_range(7.0, 11.0) + reach * rng.randf_range(2.4, 4.6) * (0.45 + north)
			var radius := rng.randf_range(5.0, 7.5) + reach * 0.9
			var at := lvl.cell_to_world(c) + Vector3(rng.randf_range(-1.5, 1.5), WallFade.WALL_HEIGHT, rng.randf_range(-1.5, 1.5))
			var node := NohpaanParts.peak(holder, at, radius, height, rng)
			if d <= 2:
				lvl._near_walls.add(node)
