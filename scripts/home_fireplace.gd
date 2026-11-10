class_name HomeFireplace
extends RefCounted
## The fireplace every storey of the hero's own house has from the start, the
## cellar apart (a cellar is damp, and no chimney reaches it). It is built into
## one plain wall of the storey: a stone surround with a mantel, a chimney breast
## above, logs on a bed of coals, a few flames and a warm flickering light.
##
## It is picked, never put by hand, from the map (see pick): a tile of free floor
## ("."), so it stands on no stairs, door, bed or furniture spot, and Level hangs
## no torch or banner on that wall. It is only
## about 0.6 m deep, so the tile in front of it stays walkable. The flames are plain
## glowing shapes, not additive particles, so they do not wash out in the fog.
## Tested by tests/home_fireplace.gd.

const W := preload("res://scripts/weathered_props.gd")

## How far the fireplace reaches out of its wall, and how wide it is.
const DEPTH := 0.6
const WIDTH := 2.3
## The room's glow: warm, a little redder than a wall torch.
const LIGHT_COLOUR := Color(1.0, 0.58, 0.26)
const LIGHT_ENERGY := 3.0
const LIGHT_RANGE := 10.0


## Which wall each storey (from the ground floor up) gets its fireplace on, picked
## from the map alone: a tile of free floor (".") with a wall at its back, never the
## near (south) wall. Returns storey -> {"cell", "pos", "rot"} (`rot` turns the
## piece to face into the room, like a wall piece, see Level._build_walls).
static func pick(level: Level) -> Dictionary:
	var best := {}
	var best_score := {}
	for x in level.width:
		for y in level.height:
			var c := Vector2i(x, y)
			var storey := level.storey_of(c)
			if storey < 0 or level.cell_char(c) != ".":
				continue
			for d in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0)]:
				if level.cell_char(c + d) != "#":
					continue
				var score := 0.0
				# The north wall faces the camera: the fire is seen best there.
				if d.y < 0:
					score += 10.0
				# Keep clear of the stairs, the door, the bed and the companions' corner.
				for dx in range(-1, 2):
					for dy in range(-1, 2):
						var ch := level.cell_char(c + Vector2i(dx, dy))
						if ch != "" and "<>EBN".contains(ch):
							score -= 3.0
				# A tile with room to either side of it.
				for side in [Vector2i(-1, 0), Vector2i(1, 0)]:
					if level.cell_char(c + side) == "#":
						score -= 1.0
				if not best_score.has(storey) or score > best_score[storey]:
					best_score[storey] = score
					best[storey] = {"cell": c, "wall": d,
							"pos": level.cell_to_world(c) + Vector3(d.x, 0, d.y) * Level.TILE * 0.5,
							"rot": atan2(-float(d.x), -float(d.y))}
	return best


## Builds a fireplace on the wall piece `w` ({"pos", "rot"}) of `level`.
## Returns the node that holds it.
static func build(level: Level, w: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Fireplace"
	root.position = w.pos
	root.rotation.y = w.rot
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("fireplace:%d:%d" % [roundi(w.pos.x), roundi(w.pos.z)])
	# Local frame: the wall is the plane z = 0 and the room lies towards +z.
	var b := W.Builder.new()
	var stone := W.STONES
	var half := DEPTH * 0.5
	var jamb := 0.42
	var open := WIDTH - jamb * 2.0
	for s in [-1.0, 1.0]:
		b.box(Vector3(s * (open * 0.5 + jamb * 0.5), 0, half), Vector3(jamb, 1.55, DEPTH), W.vary(stone[0], rng), W.STONE)
	# The back of the opening, sooty, and the floor of the hearth.
	b.box(Vector3(0, 0, 0.06), Vector3(open, 1.55, 0.1), Color(0.16, 0.14, 0.13), W.STONE)
	b.box(Vector3(0, 0, half + 0.3), Vector3(WIDTH + 0.3, 0.1, DEPTH + 0.6), W.vary(stone[2], rng), W.STONE)
	b.box(Vector3(0, 0.1, 0.1 + 0.25), Vector3(open - 0.1, 0.06, 0.55), Color(0.12, 0.1, 0.09), W.STONE)
	# The mantel shelf, and the chimney breast narrowing up into the ceiling.
	b.box(Vector3(0, 1.55, half + 0.04), Vector3(WIDTH + 0.2, 0.2, DEPTH + 0.1), W.TIMBER[3] * 0.8, W.WOOD)
	b.frustum(Vector3(0, 1.75, 0.3), Vector2(WIDTH - 0.2, 0.6), Vector2(1.1, 0.4), 1.9, stone[3] * Color(0.8, 0.78, 0.76), W.STONE)
	# Two logs across a pair of irons, and some kindling.
	for i in 2:
		var a := Vector3(-open * 0.38, 0.2 + i * 0.12, 0.3 + i * 0.12)
		b.bar(a, a + Vector3(open * 0.76, 0.0, 0.0), 0.09, W.TIMBER[1] * 0.45, W.WOOD, 6)
	b.finish(root, Vector3.ZERO)
	# The coals under the logs and the flames over them: glowing shapes that
	# flicker, plain (not added to the picture) so the fog cannot wash them out.
	var coals := MeshInstance3D.new()
	var bed := BoxMesh.new()
	bed.size = Vector3(open - 0.3, 0.05, 0.5)
	coals.mesh = bed
	coals.material_override = VillageProps.coals_material()
	coals.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	coals.position = Vector3(0, 0.15, 0.4)
	root.add_child(coals)
	var flames: Array = []
	for i in 5:
		var tongue := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = rng.randf_range(0.11, 0.17)
		cone.height = rng.randf_range(0.45, 0.75)
		cone.radial_segments = 6
		tongue.mesh = cone
		tongue.material_override = _flame_material(i)
		tongue.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tongue.position = Vector3(-open * 0.3 + i * open * 0.15, 0.25 + cone.height * 0.5, 0.38 + rng.randf_range(-0.05, 0.05))
		root.add_child(tongue)
		flames.append(tongue)
		var base := tongue.scale
		var tween := tongue.create_tween().set_loops()
		tween.tween_property(tongue, "scale", base * Vector3(1.0, rng.randf_range(1.15, 1.4), 1.0), rng.randf_range(0.18, 0.3))
		tween.tween_property(tongue, "scale", base * Vector3(1.0, rng.randf_range(0.75, 0.95), 1.0), rng.randf_range(0.18, 0.3))
	# The warm light on the room, flickering like the flames.
	var light := OmniLight3D.new()
	light.name = "FireLight"
	light.light_color = LIGHT_COLOUR
	light.light_energy = LIGHT_ENERGY
	light.omni_range = LIGHT_RANGE
	light.omni_attenuation = 1.3
	light.position = Vector3(0, 0.9, 1.1)
	root.add_child(light)
	var glow := light.create_tween().set_loops()
	glow.tween_property(light, "light_energy", LIGHT_ENERGY * 1.15, 0.22)
	glow.tween_property(light, "light_energy", LIGHT_ENERGY * 0.82, 0.3)
	glow.tween_property(light, "light_energy", LIGHT_ENERGY * 1.05, 0.18)
	glow.tween_property(light, "light_energy", LIGHT_ENERGY * 0.9, 0.35)
	level.add_child(root)
	# The wall behind and the surround stop the hero; the tile in front stays free.
	var side := Vector3(sin(w.rot), 0.0, cos(w.rot))
	var size := Vector3(WIDTH, 1.6, DEPTH)
	if absf(side.x) > 0.5:
		size = Vector3(DEPTH, 1.6, WIDTH)
	level._add_solid(w.pos + side * (DEPTH * 0.5), size)
	return root


static func _flame_material(i: int) -> StandardMaterial3D:
	var key := "hearth_flame_%d" % (i % 2)
	if not W._mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.62, 0.18) if i % 2 == 0 else Color(1.0, 0.82, 0.38)
		W._mats[key] = m
	return W._mats[key]
