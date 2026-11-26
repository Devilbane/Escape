class_name IvySeasons
extends RefCounted
## The vines on the village's houses follow the seasons (see Seasons, Weather.is_autumn,
## Weather.is_winter).
##
## Spring: green leaves and no grapes yet. Summer: the green leaves and small, unripe grapes, only
## some of the bunches they were grown with (AgedStone). Autumn: day by day more
## of the green leaves turn crimson, orange and gold, until nearly all have turned. Winter: the leaves
## keep their autumn colours, some lie under snow (SNOW_LEAVES), the snow settles on the upper rims
## of the rest (the ivy's snow, see SnowCover and snow_cutout.gdshader) and the grapes are gone; they hang again in summer. In autumn every bunch hangs ripe and full.
##
## Only green leaves change: the flowers of the shrubs and the few leaves that are red all year keep
## their colour. The leaves' summer colours are kept on each MultiMesh (meta "summer"), so a change
## of season only rewrites the instance colours, once.

## How readily snow settles on the upper rim of a leaf that stands upright on a wall (0 to 1, see
## snow_cutout.gdshader): with snow lying, the ivy wears white tops on its leaves.
const SNOW_CLING := 0.8

## The look of each season, as a stage: summer, the steps of autumn, winter, spring.
const SUMMER := 0
const WINTER := 99
const SPRING := 98
## How many days autumn takes to turn the leaves, and the share that stays green at the end.
const TURN_DAYS := 4
const STAY_GREEN := 0.03
## Autumn colours: crimson, wine red, orange red, orange, gold, yellow, and two browns.
const AUTUMN_COLOURS := [Color(0.62, 0.11, 0.07), Color(0.46, 0.08, 0.1), Color(0.74, 0.26, 0.06),
		Color(0.84, 0.46, 0.09), Color(0.8, 0.62, 0.14), Color(0.86, 0.74, 0.18),
		Color(0.48, 0.26, 0.09), Color(0.36, 0.19, 0.08)]
## The leafy trees (tree.gdshader): the share of their green leaves turned at the end of autumn.
const TREE_TURNED := 0.97
## Grapes ripen in autumn: in summer the bunches hang small and unripe (GRAPE_UNRIPE_COLOURS) and
## only GRAPE_SUMMER_SHARE of them show; in autumn every bunch hangs, swollen by GRAPE_RIPE, in the
## deep ripe colours, with the extra bunches only autumn hangs (AgedStone.AUTUMN_GRAPE_CHANCE),
## brought GRAPE_OUT metres forward out of the leaves so they show; in winter and spring there are none.
const GRAPE_SUMMER_SHARE := 0.6
const GRAPE_SUMMER_SIZE := 0.8
const GRAPE_OUT := 0.09
const GRAPE_UNRIPE_COLOURS := [Color(0.5, 0.6, 0.2), Color(0.58, 0.62, 0.24), Color(0.44, 0.5, 0.2)]
const GRAPE_RIPE := 1.45
const GRAPE_RIPE_COLOURS := [Color(0.16, 0.06, 0.24), Color(0.1, 0.06, 0.2), Color(0.32, 0.04, 0.1)]
## Winter keeps autumn's leaves (the same dice, so every leaf keeps its colour) and covers
## SNOW_LEAVES of them with snow.
const SNOW_LEAVES := 0.3
const SNOW_LEAF := Color(0.88, 0.91, 0.96)


## The stage for season day `day` (see Seasons): SPRING, SUMMER, 1 to TURN_DAYS while autumn turns
## the leaves, or WINTER.
static func stage(day: int) -> int:
	if Weather.is_winter(day):
		return WINTER
	if Weather.is_spring(day):
		return SPRING
	var d := Weather.autumn_day(day)
	if d < 0:
		return SUMMER
	return mini(d + 1, TURN_DAYS)


## The share of green leaves that has turned at `at` (a stage).
static func turned(at: int) -> float:
	if at == WINTER:
		return turned(TURN_DAYS)
	if at == SPRING:
		return 0.0
	return float(at) / float(TURN_DAYS) * (1.0 - STAY_GREEN)


## How far the leafy trees have turned at `at` (a stage): x the share of green leaves turned,
## y how much of the turned leaves lies under snow (winter keeps autumn's leaves, some snowed on).
static func tree_turn(at: int) -> Vector2:
	if at == WINTER:
		return Vector2(TREE_TURNED, 1.0)
	if at == SPRING:
		return Vector2.ZERO
	return Vector2(float(at) / float(TURN_DAYS) * TREE_TURNED, 0.0)


## Whether a leaf colour is a green one (and so changes with the seasons). The blue-greens of the
## evergreen bushes (BushKinds) are not: their blue is over EVERGREEN_BLUE of their green.
const EVERGREEN_BLUE := 0.65


static func is_green(c: Color) -> bool:
	return c.g > c.r and c.g > c.b and c.b < c.g * EVERGREEN_BLUE


## Dresses the ivy under `ivy` (AgedStone.ivy_node) for `day`. Does nothing while the stage holds.
static func apply(ivy: Node3D, day: int) -> void:
	if ivy == null:
		return
	var at := stage(day)
	if int(ivy.get_meta("season_stage", -1)) == at:
		return
	ivy.set_meta("season_stage", at)
	for child in ivy.get_children():
		var node := child as MultiMeshInstance3D
		if node == null:
			continue
		if node.name.begins_with("Grapes"):
			node.visible = at != WINTER and at != SPRING
			if node.visible:
				_ripen(node, at != SUMMER)
			continue
		if not node.has_meta("summer"):
			continue
		var now := colours(node.get_meta("summer"), String(node.name), at)
		node.set_meta("now", now)
		var mm := node.multimesh
		for i in now.size():
			mm.set_instance_color(i, now[i])


## The colours of one tile's leaves (`summer`, its MultiMesh named `tile`) at stage `at`. The same
## dice for a tile every time, so a leaf that turned yesterday stays turned.
static func colours(summer: PackedColorArray, tile: String, at: int) -> PackedColorArray:
	var share := turned(at)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(tile)
	var out := PackedColorArray()
	out.resize(summer.size())
	for i in summer.size():
		var c := summer[i]
		var roll := rng.randf()
		var pick := rng.randi()
		var light := rng.randf_range(0.85, 1.15)
		var snowed := rng.randf() < SNOW_LEAVES
		if not is_green(c):
			pass
		elif at == WINTER and snowed:
			c = SNOW_LEAF * lerpf(0.92, 1.05, (light - 0.85) / 0.3)
		elif roll < share:
			c = AUTUMN_COLOURS[pick % AUTUMN_COLOURS.size()] * light
		c.a = summer[i].a
		out[i] = c
	return out


## Hangs the grape bunches of one tile (`node`) for summer or, `ripe`, for autumn (see
## GRAPE_SUMMER_SHARE), from the bunches as they were grown (meta "grown", see AgedStone).
static func _ripen(node: MultiMeshInstance3D, ripe: bool) -> void:
	var mm := node.multimesh
	if not node.has_meta("grown"):
		return
	var grown: Array = node.get_meta("grown")
	var sizes := PackedFloat32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(node.name))
	for i in mm.instance_count:
		var t: Transform3D = grown[0][i]
		var c: Color = grown[1][i]
		var out: Vector3 = grown[2][i] if grown.size() > 2 else Vector3.ZERO
		var autumn_only: bool = grown[3][i] if grown.size() > 3 else false
		var shown := rng.randf() < GRAPE_SUMMER_SHARE and not autumn_only
		var pick := rng.randi()
		var light := rng.randf_range(0.85, 1.2)
		if ripe:
			t.basis = t.basis.scaled(Vector3.ONE * GRAPE_RIPE)
			t.origin += out * GRAPE_OUT
			c = GRAPE_RIPE_COLOURS[pick % GRAPE_RIPE_COLOURS.size()] * light
		else:
			# A hidden bunch is squashed to nothing (its place still kept for autumn).
			t.basis = t.basis.scaled(Vector3.ONE * (GRAPE_SUMMER_SIZE if shown else 0.0))
			c = GRAPE_UNRIPE_COLOURS[pick % GRAPE_UNRIPE_COLOURS.size()] * light
		c.a = 1.0
		sizes.append(t.basis.get_scale().x)
		mm.set_instance_transform(i, t)
		mm.set_instance_color(i, c)
	# How big each bunch hangs now (0 for a hidden one), for the tests.
	node.set_meta("sizes", sizes)
