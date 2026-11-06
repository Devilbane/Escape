class_name SlimeGrowth
extends RefCounted
## Slimes come in many colours and sizes, and they grow by eating.
##
## - Colour: a plain slime ("schleim") is water of one of COLOURS, picked
##   when it is born; the crystal and ember slimes keep their own colour.
## - Size: a slime is as big as its level (see size_for), from a small lump
##   at level 1 to a hulk at MAX_LEVEL. Some are born a level or more above
##   their place (BIRTH_GROWTH, never above its area's top, see birth_top),
##   so a group never looks all alike.
## - Hunger: a slime falls upon any other creature it could swallow (see
##   can_eat): a monster no more than PREY_MARGIN levels above it, or a
##   slime of another kind at least SLIME_GAP levels below it. Ghosts,
##   horrors, bosses and the big ones it leaves alone. The prey fights back.
## - Corpses: a slime smells the dead from afar (CORPSE_SCENT) and goes for
##   a corpse before anything living, the hero too unless the hero is right
##   next to it (HERO_CLOSE). It swallows the body and grows as from a kill.
## - Growth: whatever a slime fells it swallows whole, body and belongings
##   (see Enemy.swallow): no corpse is left, the slime heals and grows by
##   gain() levels, up to MAX_LEVEL. What its prey carried stays in its belly
##   (Enemy.belly), where it shows through the slime's body (SHOWN things
##   at most), and spills out when the slime itself falls, with its own loot
##   (see Level.spill_belly). A corpse's loot lies on the floor beside it:
##   a slime eating the corpse slurps up what lies within SLURP_REACH.
## - Merging: a slime notices another slime of its kind within
##   Enemy.RIVAL_SIGHT that it can see, and goes to it when it has nothing
##   better to do (no prey, no corpse, no hero). When two touch (MERGE_GAP),
##   the higher level takes the other in: their colours mix by their levels,
##   and it grows as from a meal, belly and all.
## - Wandering: in the open air a slime does not keep to its home but
##   wanders the whole map (WANDER_TILES at a go), the graveyard and the
##   mountains too.
## - Lasting: the slimes of the open air stay in the world while the hero
##   is in a dungeon or a house, and in the saved game (see snapshot and
##   restore): where they are, their level, colour, life and belly.
## - Blob: from BLOB_LEVEL on a slime is a Blob. It sparkles, hits harder
##   (BLOB_DAMAGE), strikes faster (BLOB_PACE) and its touch poisons more
##   often (BLOB_POISON).

## The kinds that grow. The Maw ("schlund") is a horror: it stays as it is.
const GROWERS := ["schleim", "kristallschleim", "glutschleim"]
const MAX_LEVEL := 25
const BLOB_LEVEL := 15
## How many levels above itself a slime still dares to hunt.
const PREY_MARGIN := 2
## How many levels smaller another slime must be to look like food.
const SLIME_GAP := 2
## The colours of the plain slimes (the water they are made of). The first
## one is the classic murky green of the neglected fountain (no tint).
const COLOURS := [
	null,
	Color(0.25, 0.55, 1.0), # blue
	Color(0.68, 0.32, 1.0), # violet
	Color(1.0, 0.22, 0.2), # red
	Color(1.0, 0.78, 0.15), # amber
	Color(1.0, 0.42, 0.75), # pink
	Color(0.15, 0.9, 0.82), # teal
	Color(0.45, 1.0, 0.25), # bright green
]
## How many levels above its place a slime is born, picked from this list.
const BIRTH_GROWTH := [0, 0, 0, 1, 1, 2, 3]
## Size against the kind's own: SIZE_BASE + SIZE_PER_LEVEL per level (1.0 at
## level 5), never more than SIZE_TOP; each one a little off (SIZE_JITTER).
const SIZE_BASE := 0.7
const SIZE_PER_LEVEL := 0.06
const SIZE_TOP := 2.8
const SIZE_JITTER := 0.06
## How long a gulp takes, the prey sliding in and the slime swelling.
const GULP_TIME := 0.6
## The Blob: blows this much harder (one more at least), this much less time
## between them, and this much more chance its touch poisons.
const BLOB_DAMAGE := 1.3
const BLOB_PACE := 0.85
const BLOB_POISON := 0.2
## The Blob's sparkle and the colour of its words.
const BLOB_SPARKLE := Color(1.0, 0.95, 0.7)
const GULP_COLOR := Color(0.6, 1.0, 0.45)
## How far a slime smells a corpse, and how close the hero must come before
## it leaves its meal for the hero.
const CORPSE_SCENT := 20.0
const HERO_CLOSE := 3.5
## How many swallowed things show inside a slime at most.
const SHOWN := 8
## How far (tiles) a slime in the open air sets out each time it wanders on.
const WANDER_TILES := 24
## How far round an eaten corpse a slime slurps up the loot lying there.
const SLURP_REACH := 1.6
## How long a swallowed thing may be inside it, against its body's height.
const INSIDE := 0.4
## The classic slime's colour, for mixing with a coloured one.
const PLAIN := Color(0.36, 0.78, 0.26)
## How close two slimes' bodies come before they flow into one.
const MERGE_GAP := 0.5
## Into the compendium the first time the hero sees a slime swallow something.
const LEARN := "Schleime wachsen: Ein Schleim fällt über jedes Wesen her, das er verschlingen kann, und er wittert die Toten von weitem und geht lieber an eine Leiche als an etwas Lebendiges. Was er erlegt, schluckt er ganz, samt allem, was es bei sich trug, und wird davon größer und stärker, bis Stufe 25. Ab Stufe 15 ist er ein Blob: Er funkelt, schlägt härter zu und vergiftet öfter. Fällt er, gibt er alles wieder her, was er verschluckt hat. Zwei Schleime, die einander bemerken, kriechen zueinander und fließen zu einem zusammen."


static func grows(kind: String) -> bool:
	return kind in GROWERS


## Whether a slime would make a meal of this one at all: not a ghost (no
## body), a horror, a boss or one of the big ones.
static func edible(prey: Enemy) -> bool:
	if prey.is_ghost() or prey.is_horror() or prey.is_level_boss() or HeroLevel.FIXED.has(prey.kind):
		return false
	return not prey._stats.get("big", false) and not prey._stats.get("boss", false)


## Whether `slime` hunts `prey` when it sees it (see the top).
static func can_eat(slime: Enemy, prey: Enemy) -> bool:
	if not grows(slime.kind) or prey == slime or prey.dead or not edible(prey):
		return false
	if grows(prey.kind):
		# One of its own kind it merges with instead (see try_merge).
		return prey.kind != slime.kind and prey.rated_level <= slime.rated_level - SLIME_GAP
	return prey.rated_level <= slime.rated_level + PREY_MARGIN


## Whether `slime`, having just felled `prey`, swallows it.
static func swallows(slime: Enemy, prey: Enemy) -> bool:
	return slime != null and is_instance_valid(slime) and not slime.dead and grows(slime.kind) \
			and slime != prey and edible(prey)



## How many levels a meal of this level is worth.
static func gain(prey_level: int) -> int:
	return maxi(1, ceili(prey_level / 3.0))


## How big a slime of this kind (its own size `base`) is at `slime_level`.
static func size_for(base: float, slime_level: int) -> float:
	return minf(base * (SIZE_BASE + SIZE_PER_LEVEL * slime_level), SIZE_TOP)


static func is_blob_level(slime_level: int) -> bool:
	return slime_level >= BLOB_LEVEL


## A new slime (from Enemy._ready, before its body is built): its colour,
## a level or so above its place now and then, and its size.
static func born(e: Enemy) -> void:
	if e.kind == "schleim" and not e._stats.has("tint"):
		var colour = COLOURS[randi() % COLOURS.size()]
		if colour != null:
			e._stats.tint = colour
	var fixed: bool = e.custom.has("hp") or e.custom.has("damage")
	# A slime kept from before (see snapshot): back at its own level.
	if e.custom.has("kept_level"):
		var kept := clampi(int(e.custom.kept_level), 1, MAX_LEVEL)
		e.rated_level = mini(Enemy.fit_level(e.kind, e._stats, e.hardening, kept, kept), MAX_LEVEL)
		if is_blob_level(e.rated_level):
			blob_up(e)
		e._stats.size = size_of(e)
		e.wanders = e.level != null and e.level.outdoor
		return
	var extra: int = BIRTH_GROWTH[randi() % BIRTH_GROWTH.size()]
	if extra > 0 and not fixed:
		e.rated_level = Enemy.fit_level(e.kind, e._stats, e.hardening, mini(MAX_LEVEL, e.rated_level + extra), MAX_LEVEL)
	e.rated_level = mini(e.rated_level, MAX_LEVEL)
	e._stats.size_jitter = randf_range(1.0 - SIZE_JITTER, 1.0 + SIZE_JITTER)
	if is_blob_level(e.rated_level):
		blob_up(e)
	# Born a fair fight for its place: the extra growth and a Blob's edge
	# stay within the place's levels (only what it eats lifts it above).
	var top := birth_top(e)
	if e.rated_level > top and not fixed:
		e.rated_level = Enemy.fit_level(e.kind, e._stats, e.hardening, top, top)
	e._stats.size = size_of(e)
	# Under the open sky a slime wanders the whole map, the graveyard and
	# the mountains too.
	e.wanders = e.level != null and e.level.outdoor


## The highest level a slime is born at where it lives: its area's top (see
## HeroLevel.AREAS), the dungeon's top, or MAX_LEVEL.
static func birth_top(e: Enemy) -> int:
	if e.level == null:
		return MAX_LEVEL
	var area := HeroLevel.area_of(e.level, e.kind)
	if area != "":
		return mini(int(HeroLevel.AREAS[area].max), MAX_LEVEL)
	if not e.level.outdoor and e.level.building == "":
		return HeroLevel.DUNGEON_TOP
	return MAX_LEVEL


## The size this slime has now.
static func size_of(e: Enemy) -> float:
	return size_for(float(Enemy.KINDS[e.kind].size), e.rated_level) * float(e._stats.get("size_jitter", 1.0))


## Makes it a Blob: harder, faster, more poisonous blows (see the top). Once.
static func blob_up(e: Enemy) -> void:
	if e.blob:
		return
	e.blob = true
	var damage := int(e._stats.damage)
	e._stats.damage = maxi(damage + 1, roundi(damage * BLOB_DAMAGE))
	e._stats.cooldown = float(e._stats.cooldown) * BLOB_PACE
	e._stats.poison = float(e._stats.get("poison", 0.0)) + BLOB_POISON
	e.rated_level = mini(maxi(e.rated_level, e._rating()), MAX_LEVEL)


## Whether this corpse can still be eaten: not rotted to its end, not a
## wisp of a ghost, not already in a slime.
static func still_food(c: Corpse) -> bool:
	return c != null and is_instance_valid(c) and not c._done and c.style != "wisp" \
			and is_instance_valid(c.enemy) and c.enemy.swallowed_by == null and edible(c.enemy)


## The nearest corpse this slime smells and can reach in a straight line or
## round the walls, or null.
static func nearest_corpse(slime: Enemy) -> Corpse:
	var best: Corpse = null
	var best_d := CORPSE_SCENT
	for c in slime.level.corpses:
		if not still_food(c):
			continue
		var d: float = slime._flat_distance(c.enemy)
		if d < best_d and (d < Enemy.RIVAL_SIGHT or slime.level.has_line_of_sight(slime.global_position, c.enemy.global_position)):
			best = c
			best_d = d
	return best


## The other slime of its kind this one notices: the nearest within
## Enemy.RIVAL_SIGHT that it can see, or null.
static func nearest_slime(e: Enemy) -> Enemy:
	var best: Enemy = null
	var best_d := Enemy.RIVAL_SIGHT
	for o in e.level.enemies:
		if not _mergeable(e, o):
			continue
		var d: float = e._flat_distance(o)
		if d < best_d and e.level.has_line_of_sight(e.global_position, o.global_position):
			best = o
			best_d = d
	return best


## Merges this slime with another of its kind it touches, if this one is the
## bigger (the higher level; on a tie, the older). True when it did.
static func try_merge(e: Enemy) -> bool:
	for o in e.level.enemies:
		if not _mergeable(e, o) or e._flat_distance(o) > e.radius + o.radius + MERGE_GAP:
			continue
		if o.rated_level > e.rated_level or (o.rated_level == e.rated_level and o.get_instance_id() < e.get_instance_id()):
			continue
		e.merge_with(o)
		return true
	return false


static func _mergeable(e: Enemy, o) -> bool:
	return is_instance_valid(o) and o is Enemy and o != e and not o.dead and o.kind == e.kind \
			and o.swallowed_by == null and not o.is_friend()


## The slimes of the open air as they are now, to keep while the hero is
## away and in the saved game (JSON-safe): kind, spot, level, colour, size,
## life and what is in the belly.
static func snapshot(level: Level) -> Array:
	var out := []
	for e in level.enemies:
		if not is_instance_valid(e) or e.dead or not grows(e.kind):
			continue
		var belly := []
		for meal in e.belly:
			for thing in meal.loot:
				belly.append(_thing_to_save(thing))
		var kept := {"kind": e.kind, "x": snappedf(e.global_position.x, 0.01), "z": snappedf(e.global_position.z, 0.01),
			"level": e.rated_level, "hp": e.hp, "jitter": snappedf(float(e._stats.get("size_jitter", 1.0)), 0.001), "belly": belly}
		if e._stats.has("tint"):
			var tint: Color = e._stats.tint
			kept.tint = [snappedf(tint.r, 0.001), snappedf(tint.g, 0.001), snappedf(tint.b, 0.001)]
		out.append(kept)
	return out


## Brings back slimes kept by snapshot on `level` (an Outdoor): each where it
## was, as it was. Entries it cannot read are skipped.
static func restore(level: Outdoor, kept: Array) -> void:
	for k in kept:
		if not k is Dictionary or not grows(str(k.get("kind", ""))):
			continue
		var custom := {"kept_level": int(k.get("level", 1)), "size_jitter": float(k.get("jitter", 1.0))}
		var tint = k.get("tint", null)
		if tint is Array and tint.size() >= 3:
			custom.tint = Color(float(tint[0]), float(tint[1]), float(tint[2]))
		var at := Vector3(float(k.get("x", 0.0)), 0.0, float(k.get("z", 0.0)))
		var e := level.spawn_slime(str(k.kind), at, custom)
		e.hp = clampi(int(k.get("hp", e.max_hp())), 1, e.max_hp())
		var loot := []
		for thing in k.get("belly", []):
			var t := _thing_from_save(thing)
			if not t.is_empty():
				loot.append(t)
		if not loot.is_empty():
			e.belly.append({"victim": null, "loot": loot})
			e.show_swallowed(loot)


static func _thing_to_save(thing: Array) -> Array:
	if thing[0] == "find":
		var c: Color = thing[2]
		return ["find", thing[1], [c.r, c.g, c.b], thing[3]]
	return thing.duplicate()


static func _thing_from_save(thing) -> Array:
	if not thing is Array or thing.is_empty():
		return []
	match str(thing[0]):
		"coins":
			return ["coins", str(thing[1]), int(thing[2])] if thing.size() >= 3 else []
		"item":
			return ["item", str(thing[1])] if thing.size() >= 2 and Items.ALL.has(str(thing[1])) else []
		"find":
			if thing.size() >= 4 and thing[2] is Array and thing[2].size() >= 3:
				return ["find", str(thing[1]), Color(float(thing[2][0]), float(thing[2][1]), float(thing[2][2])), int(thing[3])]
	return []
