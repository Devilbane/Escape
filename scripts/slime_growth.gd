class_name SlimeGrowth
extends RefCounted
## Slimes come in many colours and sizes, and they grow by eating.
##
## - Colour: a plain slime ("schleim") is water of one of COLOURS, picked
##   when it is born; the crystal and ember slimes keep their own colour.
##   Slimes of one colour are kin and leave each other be.
## - Size: a slime is as big as its level (see size_for), from a small lump
##   at level 1 to a hulk at MAX_LEVEL. Some are born a level or more above
##   their place (BIRTH_GROWTH), so a group never looks all alike.
## - Hunger: a slime falls upon any other creature it could swallow (see
##   can_eat): a monster no more than PREY_MARGIN levels above it, or a
##   slime of another colour at least SLIME_GAP levels below it. Ghosts,
##   horrors, bosses and the big ones it leaves alone. The prey fights back.
## - Corpses: a slime smells the dead from afar (CORPSE_SCENT) and goes for
##   a corpse before anything living, the hero too unless the hero is right
##   next to it (HERO_CLOSE). It swallows the body and grows as from a kill.
## - Growth: whatever a slime fells it swallows whole, body and belongings
##   (see Enemy.swallow): no corpse is left, the slime heals and grows by
##   gain() levels, up to MAX_LEVEL. What its prey carried stays in its belly
##   (Enemy.belly) and spills out when the slime itself falls, with its own
##   loot (see Level.spill_belly).
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
## Into the compendium the first time the hero sees a slime swallow something.
const LEARN := "Schleime wachsen: Ein Schleim fällt über jedes Wesen her, das er verschlingen kann, auch über kleinere Schleime anderer Farbe, und er wittert die Toten von weitem und geht lieber an eine Leiche als an etwas Lebendiges. Was er erlegt, schluckt er ganz, samt allem, was es bei sich trug, und wird davon größer und stärker, bis Stufe 25. Ab Stufe 15 ist er ein Blob: Er funkelt, schlägt härter zu und vergiftet öfter. Fällt er, gibt er alles wieder her, was er verschluckt hat."


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
		return not kin(slime, prey) and prey.rated_level <= slime.rated_level - SLIME_GAP
	return prey.rated_level <= slime.rated_level + PREY_MARGIN


## Whether `slime`, having just felled `prey`, swallows it.
static func swallows(slime: Enemy, prey: Enemy) -> bool:
	return slime != null and is_instance_valid(slime) and not slime.dead and grows(slime.kind) \
			and slime != prey and edible(prey)


## Two slimes of one kind and colour.
static func kin(a: Enemy, b: Enemy) -> bool:
	return a.kind == b.kind and a._stats.get("tint", null) == b._stats.get("tint", null)


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
	var extra: int = BIRTH_GROWTH[randi() % BIRTH_GROWTH.size()]
	if extra > 0 and not fixed:
		e.rated_level = Enemy.fit_level(e.kind, e._stats, e.hardening, mini(MAX_LEVEL, e.rated_level + extra), MAX_LEVEL)
	e.rated_level = mini(e.rated_level, MAX_LEVEL)
	e._stats.size_jitter = randf_range(1.0 - SIZE_JITTER, 1.0 + SIZE_JITTER)
	if is_blob_level(e.rated_level):
		blob_up(e)
	e._stats.size = size_of(e)


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
