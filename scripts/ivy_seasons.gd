class_name IvySeasons
extends RefCounted
## The vines on the village's houses follow the seasons (see Weather.is_autumn, Weather.is_winter).
##
## Summer: the green leaves and the grapes they were grown with (AgedStone). Autumn: day by day more
## of the green leaves turn crimson, orange and gold, until nearly all have turned. Winter: the leaves
## darken to a dull bronze green, the snow settles on their upper rims (the ivy's snow, see
## SnowCover and snow_cutout.gdshader) and the grapes are gone; they hang again in spring.
##
## Only green leaves change: the flowers of the shrubs and the few leaves that are red all year keep
## their colour. The leaves' summer colours are kept on each MultiMesh (meta "summer"), so a change
## of season only rewrites the instance colours, once.

## How readily snow settles on the upper rim of a leaf that stands upright on a wall (0 to 1, see
## snow_cutout.gdshader): with snow lying, the ivy wears white tops on its leaves.
const SNOW_CLING := 0.8

## The look of each season, as a stage: summer, the steps of autumn, winter.
const SUMMER := 0
const WINTER := 99
## How many days autumn takes to turn the leaves, and the share that stays green at the end.
const TURN_DAYS := 4
const STAY_GREEN := 0.08
## Autumn colours: crimson, wine red, orange red, orange, gold.
const AUTUMN_COLOURS := [Color(0.62, 0.11, 0.07), Color(0.46, 0.08, 0.1), Color(0.74, 0.26, 0.06),
		Color(0.84, 0.46, 0.09), Color(0.8, 0.62, 0.14)]
## Winter colours: mostly the dark green of old ivy, now and then the bronze of a leaf in the cold.
const WINTER_COLOURS := [Color(0.13, 0.26, 0.12), Color(0.17, 0.3, 0.13), Color(0.2, 0.27, 0.11),
		Color(0.12, 0.22, 0.14), Color(0.3, 0.2, 0.11)]


## The stage for `day`: SUMMER, 1 to TURN_DAYS while autumn turns the leaves, or WINTER.
static func stage(day: int) -> int:
	if Weather.is_winter(day):
		return WINTER
	var d := Weather.autumn_day(day)
	if d < 0:
		return SUMMER
	return mini(d + 1, TURN_DAYS)


## The share of green leaves that has turned at `at` (a stage).
static func turned(at: int) -> float:
	if at == WINTER:
		return 1.0
	return float(at) / float(TURN_DAYS) * (1.0 - STAY_GREEN)


## Whether a leaf colour is a green one (and so changes with the seasons).
static func is_green(c: Color) -> bool:
	return c.g > c.r and c.g > c.b


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
			node.visible = at != WINTER
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
		if not is_green(c):
			pass
		elif at == WINTER:
			c = WINTER_COLOURS[pick % WINTER_COLOURS.size()] * light
		elif roll < share:
			c = AUTUMN_COLOURS[pick % AUTUMN_COLOURS.size()] * light
		c.a = summer[i].a
		out[i] = c
	return out
