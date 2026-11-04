class_name ElderLair
## The dungeon of the Great Old One, three floors deep below the high valley
## of the mountains (the cave mouth ")" on the open-air map). Its floors have
## the header "theme: uralt" and the buildings uralt1, uralt2 and uralt3,
## linked like the floors of a mine ("down:" and "up:", see Mines): the way
## down ("^") leads to the floor below, the stairs back up.
##
## - Floor 1, the scorched halls: brood drakes, rock trolls and mountain
##   orcs, and the first epic treasure room behind a locked door.
## - Floor 2, the bone galleries: the second epic treasure room, its key
##   carried by a guardian at the far end.
## - Floor 3, the lair: the Great Old One (see ElderDragon) asleep on its
##   bed of gold, and its hoard ("$") right in front of it.
##
## The Great Old One is not meant to be slain. Its hoard is for a hero who
## sneaks: walk up quietly, step onto the heap and go. The clink of the gold
## makes it stir (GRAB_STIR), so leave quietly too. In the hoard lie the old
## dragon's own treasure (taken once: ANCIENT_GOLD and two fine pieces of
## gear) and whatever the dragon helpers brought (see DragonHoard): most of
## the coins and gear they carry off the open ground at night ends up here,
## and comes back every time the hoard has grown.
##
## The epic chests ("&") hold a piece of gear of the epic tier (see Rarity)
## and a heap of gold. The monsters are lifted to hero levels 17 to 19
## (HeroLevel.AREAS "uralt").

const THEME := "uralt"
## The light down here: dim violet, with the warm gold of the hoard.
const MOOD := {"ambient": Color(0.4, 0.32, 0.5), "energy": 0.3, "light": Color(0.85, 0.7, 1.0)}
const GOLD := Color(1.0, 0.8, 0.35)
const VIOLET := Color(0.7, 0.35, 1.0)

## The old dragon's own treasure, taken the first time the hoard is.
const ANCIENT_KEY := "elder:ancient"
const ANCIENT_GOLD := 250
## How restless the clink of the gold makes the Great Old One.
const GRAB_STIR := 0.35
## Gold in an epic chest.
const EPIC_GOLD := 60

## The compendium's word on the place, learned on the first floor.
const LORE := "Der Große Alte: ein Drache, älter als der Berg, schläft tief unter dem Hochtal auf seinem Hort. Keine Klinge durchdringt seine Schuppen, und wach verbrennt er alles vor sich. Er sieht nicht, solange er schläft, aber er hört: Wer läuft, rennt oder springt, weckt ihn. Schleiche (Taste C) zu seinem Hort, nimm dir, was du tragen kannst, und schleiche wieder fort. Wacht er auf, flieh aus seinem Blick, bis er wieder einschläft."


## The light of the floors.
static func mood(theme: String) -> Dictionary:
	return MOOD if theme == THEME else {}


## Whether `level` is one of the floors.
static func is_floor(level: Level) -> bool:
	return level != null and level.theme == THEME


## The heap of the hoard ("$"): gold and gear glittering in front of the
## sleeping dragon. Only there while something lies in it.
static func build_hoard(level: Level, c: Vector2i) -> void:
	var pos := level.cell_to_world(c)
	# The old dragon's bed: gold heaped up wide around the spot, always there.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(pos)
	for i in 6:
		var angle := TAU * i / 6.0 + rng.randf_range(-0.3, 0.3)
		level._place_lair("Coin_Pile", pos + Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(2.6, 3.6), rng.randf() * TAU, rng.randf_range(9.0, 14.0))
	var glow := OmniLight3D.new()
	glow.light_color = GOLD
	glow.light_energy = 1.6
	glow.omni_range = 9.0
	glow.position = pos + Vector3(0, 1.5, 0)
	level.add_child(glow)
	if not has_loot(level):
		return
	var holder := Node3D.new()
	holder.name = "ElderHoard"
	holder.position = pos
	level.add_child(holder)
	var size := clampf(10.0 + float(level.elder_hoard.get("coins", 0)) / 20.0, 10.0, 18.0)
	if not level.taken.has(ANCIENT_KEY):
		size = 18.0
	level._place_lair("Coin_Pile", Vector3.ZERO, rng.randf() * TAU, size).reparent(holder, false)
	# A few of the pieces lying in it show on top.
	var shown: Array = (level.elder_hoard.get("items", []) as Array).slice(0, 4)
	for i in shown.size():
		var piece := level._item_model(str(shown[i]))
		var angle := TAU * i / maxf(1.0, shown.size())
		piece.position = Vector3(cos(angle), 0.6, sin(angle)) * 0.9
		piece.rotation.y = angle
		holder.add_child(piece)
	holder.add_child(Effects.make_sparkles(GOLD))
	level._pickups.append({"node": holder, "kind": "elder_hoard", "radius": 1.9})


## Whether anything lies in the hoard on this visit.
static func has_loot(level: Level) -> bool:
	if not level.taken.has(ANCIENT_KEY):
		return true
	return int(level.elder_hoard.get("coins", 0)) > 0 or not (level.elder_hoard.get("items", []) as Array).is_empty()


## The old dragon's own treasure, fixed per hero: an epic piece, a
## god-born one, and ANCIENT_GOLD.
static func ancient_loot(level: Level) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:elder:%s" % [level.level_name, level.hero])
	return {"coins": ANCIENT_GOLD, "items": [epic_item(level, rng, "episch"), epic_item(level, rng, "gottgeboren")]}


## A piece of gear of `tier` (see Level.TIERS) for the loot of this place:
## no books, no unique blades, nothing only the smith makes.
static func epic_item(level: Level, rng: RandomNumberGenerator, tier := "episch") -> String:
	var ids: Array = Items.ALL.keys().filter(func(id):
		var item: Dictionary = Items.ALL[id]
		return Level.tier_of(id) == tier and not item.get("no_loot", false) and not item.get("smith", false) \
				and not item.get("unique", false) and str(item.get("slot", "")) not in ["buch", "auftrag", "erz"] \
				and not level._rare_loot.has(id))
	if ids.is_empty():
		return level.loot_item(rng, int(Level.TIERS[tier].min_price), HeroLevel.place_level(level))
	ids.sort()
	var id: String = ids[rng.randi() % ids.size()]
	level._rare_loot[id] = int(level._rare_loot.get(id, 0)) + 1
	return id


## Dresses the floors: skulls and bones on the floor, cobwebs in the
## corners, scorch marks where the brood breathed fire, and a few lost
## coins. None of it is in the way. Fixed per floor, like the walls.
static func decorate(level: Level) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(level.level_name + THEME)
	var scorch := StandardMaterial3D.new()
	scorch.albedo_color = Color(0.06, 0.04, 0.05, 0.75)
	scorch.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var disc := CylinderMesh.new()
	disc.top_radius = 1.2
	disc.bottom_radius = 1.2
	disc.height = 0.02
	disc.material = scorch
	for y in level.height:
		for x in level.width:
			var c := Vector2i(x, y)
			var ch := level.cell_char(c)
			if not ch in ".,":
				continue
			var pos := level.cell_to_world(c)
			var north := level.cell_char(c + Vector2i(0, -1)) == "#"
			var west := level.cell_char(c + Vector2i(-1, 0)) == "#"
			var east := level.cell_char(c + Vector2i(1, 0)) == "#"
			if north and (west or east) and rng.randf() < 0.7:
				var side := -1.0 if west else 1.0
				level._place_lair("Cobweb" if rng.randf() < 0.5 else "Cobweb2",
						pos + Vector3(side * (Level.TILE * 0.5 - 0.35), 2.9, -Level.TILE * 0.5 + 0.35), PI * 0.25 * side + PI, 1.4)
			var roll := rng.randf()
			if roll < 0.12 and not north:
				level._place_lair("Skull", pos + Vector3(rng.randf_range(-1.3, 1.3), 0, rng.randf_range(-1.3, 1.3)), rng.randf() * TAU, rng.randf_range(0.7, 1.1))
			elif roll < 0.22:
				var mark := MeshInstance3D.new()
				mark.mesh = disc
				mark.position = pos + Vector3(rng.randf_range(-1.0, 1.0), 0.02, rng.randf_range(-1.0, 1.0))
				mark.scale = Vector3(rng.randf_range(0.6, 1.3), 1.0, rng.randf_range(0.6, 1.3))
				level.add_child(mark)
