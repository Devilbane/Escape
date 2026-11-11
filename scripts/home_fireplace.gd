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

## How far the fireplace reaches out of its wall, and how wide it is. The firebox has
## its own sooty back, FIREBOX_BACK metres out of the wall, so the plain wall never shows
## behind the flames.
const DEPTH := 1.1
const WIDTH := 2.6
const FIREBOX_BACK := 0.55
## The fire: how many flame tongues (each in four layers, red to white) and how many sparks.
const TONGUES := 7
const SPARKS := 6
## The roughness of the stone: how much each block's colour varies, and how far a block may
## stand proud of its neighbours or lean (metres, radians).
const STONE_VARIETY := 0.14
const STONE_PROUD := 0.05
const STONE_LEAN := 0.05
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
	var jamb := 0.5
	var open := WIDTH - jamb * 2.0
	var top := 1.5
	var soot := Color(0.13, 0.115, 0.105)
	# The dark core of the surround, so no gap between the rough blocks shows light
	# or wall: the cheeks, the sooty back of the firebox and its floor.
	for s: float in [-1.0, 1.0]:
		b.box(Vector3(s * (open * 0.5 + jamb * 0.5), 0, DEPTH * 0.5), Vector3(jamb - 0.06, top, DEPTH - 0.06), soot, W.STONE)
	b.box(Vector3(0, 0, FIREBOX_BACK * 0.5), Vector3(open + 0.1, top, FIREBOX_BACK), soot, W.STONE)
	# Rough, sooty blocks lining the back and the cheeks inside the firebox.
	_courses(b, rng, Vector3(-open * 0.5, 0.12, FIREBOX_BACK), Vector3(1, 0, 0), open, top - 0.12, 0.3, 0.5, Vector3(0, 0, 1), 0.08, 0.6)
	for s: float in [-1.0, 1.0]:
		var x := s * open * 0.5
		_courses(b, rng, Vector3(x, 0.12, FIREBOX_BACK), Vector3(0, 0, 1), DEPTH - FIREBOX_BACK, top - 0.12, 0.3, 0.45, Vector3(-s, 0, 0), 0.08, 0.6)
	# The hearth: a slab of rough flagstones that reaches out into the room.
	b.box(Vector3(0, 0, FIREBOX_BACK + (DEPTH - FIREBOX_BACK) * 0.5 + 0.35), Vector3(WIDTH + 0.5, 0.1, DEPTH - FIREBOX_BACK + 0.7), soot, W.STONE)
	_flags(b, rng, Vector3(-(WIDTH + 0.5) * 0.5, 0.1, 0.0), WIDTH + 0.5, DEPTH + 0.5)
	# The jambs, laid in courses of rough blocks that stand a little proud or lean.
	for s: float in [-1.0, 1.0]:
		var x0 := s * (open * 0.5 + jamb * 0.5) - jamb * 0.5
		_courses(b, rng, Vector3(x0, 0.1, DEPTH), Vector3(1, 0, 0), jamb, top - 0.1, 0.28, 0.5, Vector3(0, 0, 1), STONE_PROUD, 0.0)
		# And the outer flank of each jamb, seen from the side.
		_courses(b, rng, Vector3(s * WIDTH * 0.5, 0.1, 0.0), Vector3(0, 0, 1), DEPTH, top - 0.1, 0.28, 0.5, Vector3(s, 0, 0), STONE_PROUD, 0.0)
	# The lintel: one long, heavy stone over the opening, and the mantel shelf of old oak.
	b.box(Vector3(0, top, DEPTH * 0.5), Vector3(WIDTH, 0.3, DEPTH), W.vary(W.STONES[1], rng, STONE_VARIETY) * 0.9, W.STONE)
	b.box(Vector3(0, top + 0.3, DEPTH * 0.5 + 0.04), Vector3(WIDTH + 0.25, 0.16, DEPTH + 0.14), W.TIMBER[3] * 0.75, W.WOOD)
	# The chimney breast narrowing from the mantel up into the ceiling, in courses too.
	var ch := W.vary(W.STONES[3], rng, 0.05) * Color(0.82, 0.8, 0.78)
	b.frustum(Vector3(0, top + 0.46, DEPTH * 0.5 - 0.06), Vector2(WIDTH - 0.3, DEPTH - 0.2), Vector2(1.2, 0.45), 1.9, ch, W.STONE)
	for i in 5:
		var y := top + 0.62 + i * 0.4
		var f := float(i) / 4.0
		var wd := lerpf(WIDTH - 0.28, 1.2, f * 0.85) + 0.04
		b.box(Vector3(0, y, DEPTH * 0.5 - 0.04), Vector3(wd, 0.05, lerpf(DEPTH - 0.2, 0.5, f * 0.85) + 0.04), W.vary(W.STONES[i % 4], rng, STONE_VARIETY) * 0.85, W.STONE)
	# Two charred logs across a pair of iron dogs, and some kindling.
	var lz := FIREBOX_BACK + 0.3
	for i in 2:
		var a := Vector3(-open * 0.4, 0.24 + i * 0.13, lz + i * 0.12)
		b.bar(a, a + Vector3(open * 0.8, 0.0, 0.0), 0.1, Color(0.17, 0.11, 0.08), W.WOOD, 7)
	for s: float in [-1.0, 1.0]:
		b.bar(Vector3(s * open * 0.4, 0.1, lz - 0.15), Vector3(s * open * 0.4, 0.34, lz - 0.15), 0.03, W.IRON_COLOUR * 0.35, W.IRON, 5)
		b.bar(Vector3(s * open * 0.4, 0.1, lz + 0.35), Vector3(s * open * 0.4, 0.34, lz + 0.35), 0.03, W.IRON_COLOUR * 0.35, W.IRON, 5)
	b.finish(root, Vector3.ZERO)
	# The coals under the logs and the fire over them: glowing shapes that flicker,
	# plain (not added to the picture) so the fog cannot wash them out.
	var coals := MeshInstance3D.new()
	var bed := BoxMesh.new()
	bed.size = Vector3(open - 0.2, 0.06, 0.6)
	coals.mesh = bed
	coals.material_override = VillageProps.coals_material()
	coals.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	coals.position = Vector3(0, 0.13, lz + 0.05)
	root.add_child(coals)
	_flames(root, rng, open, lz)
	# The warm light on the room, flickering like the flames.
	var light := OmniLight3D.new()
	light.name = "FireLight"
	light.light_color = LIGHT_COLOUR
	light.light_energy = LIGHT_ENERGY
	light.omni_range = LIGHT_RANGE
	light.omni_attenuation = 1.3
	light.position = Vector3(0, 0.9, DEPTH + 0.3)
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


## A face of rough blocks in staggered courses of about `row` metres, blocks of about `block`
## metres, starting at `origin` and running along `along` for `length` and up for `height`. The
## blocks face `out`, stand up to `proud` metres out of the face, lean a little and each has its
## own shade of stone; `soot` (0 to 1) darkens them towards the colour of the firebox.
static func _courses(b: W.Builder, rng: RandomNumberGenerator, origin: Vector3, along: Vector3, length: float, height: float, row: float, block: float, out: Vector3, proud: float, soot: float) -> void:
	var y := 0.0
	var r := 0
	while y < height - 0.02:
		var h := minf(row * rng.randf_range(0.8, 1.2), height - y)
		var x := -(rng.randf() * block * 0.5) if r % 2 == 1 else 0.0
		while x < length - 0.02:
			var wd := block * rng.randf_range(0.6, 1.5)
			var x0 := maxf(x, 0.0)
			var x1 := minf(x + wd, length)
			if x1 - x0 > 0.06:
				var colour := W.vary(W.STONES[rng.randi() % 4], rng, STONE_VARIETY)
				# Warmer or cooler, now and then a darker, mossier block.
				colour = colour * Color(rng.randf_range(0.94, 1.05), rng.randf_range(0.96, 1.04), rng.randf_range(0.92, 1.04))
				if rng.randf() < 0.18:
					colour = colour * 0.78
				colour = colour.lerp(Color(0.2, 0.18, 0.17), soot)
				var gap := 0.025
				var out_by := rng.randf_range(0.0, proud)
				var mid := origin + along * ((x0 + x1) * 0.5) + Vector3(0, y + h * 0.5, 0) - out * 0.04 + out * (out_by * 0.5)
				var depth := 0.1 + out_by
				var size := Vector3(absf(along.x) * (x1 - x0 - gap) + absf(out.x) * depth, h - gap, absf(along.z) * (x1 - x0 - gap) + absf(out.z) * depth)
				var basis := Basis.from_euler(Vector3(rng.randf_range(-1, 1) * STONE_LEAN, rng.randf_range(-1, 1) * STONE_LEAN, rng.randf_range(-1, 1) * STONE_LEAN))
				b.box(mid - Vector3(0, size.y * 0.5, 0), size, colour, W.STONE, basis)
			x += wd
		y += h
		r += 1


## Rough flagstones over a rectangle on the ground: `width` across (x) from `origin`, `depth` out.
static func _flags(b: W.Builder, rng: RandomNumberGenerator, origin: Vector3, width: float, depth: float) -> void:
	var z := 0.0
	while z < depth - 0.05:
		var d := minf(rng.randf_range(0.35, 0.55), depth - z)
		var x := 0.0
		while x < width - 0.05:
			var wd := minf(rng.randf_range(0.4, 0.8), width - x)
			var colour := W.vary(W.STONES[rng.randi() % 4], rng, STONE_VARIETY) * 0.9
			b.box(origin + Vector3(x + wd * 0.5, 0, z + d * 0.5), Vector3(wd - 0.03, rng.randf_range(0.03, 0.045), d - 0.03), colour, W.STONE)
			x += wd
		z += d


## The fire: layered tongues (red outside, then orange, yellow and a pale core) that rise and
## sway, a few sparks drifting up and fading out, all plain glowing shapes.
static func _flames(root: Node3D, rng: RandomNumberGenerator, open: float, lz: float) -> void:
	for i in TONGUES:
		var x := -open * 0.32 + i * open * 0.64 / float(TONGUES - 1) + rng.randf_range(-0.05, 0.05)
		var z := lz + rng.randf_range(-0.08, 0.1)
		var tall := rng.randf_range(0.55, 0.95) * (1.0 - absf(x) / open * 0.7)
		var tongue := Node3D.new()
		tongue.position = Vector3(x, 0.3, z)
		root.add_child(tongue)
		for layer in 4:
			var cone := CylinderMesh.new()
			var k := 1.0 - layer * 0.22
			cone.top_radius = 0.0
			cone.bottom_radius = (0.17 * k) * rng.randf_range(0.85, 1.15)
			cone.height = tall * k
			cone.radial_segments = 8
			var mi := MeshInstance3D.new()
			mi.mesh = cone
			mi.material_override = _flame_material(layer)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.position = Vector3(0, cone.height * 0.5, layer * 0.012)
			tongue.add_child(mi)
		var lean := rng.randf_range(0.08, 0.22)
		var sway := tongue.create_tween().set_loops()
		var t := rng.randf_range(0.22, 0.4)
		sway.tween_property(tongue, "scale", Vector3(rng.randf_range(0.9, 1.1), rng.randf_range(1.15, 1.4), 1.0), t)
		sway.parallel().tween_property(tongue, "rotation:z", lean, t)
		sway.tween_property(tongue, "scale", Vector3(rng.randf_range(0.85, 1.0), rng.randf_range(0.7, 0.92), 1.0), t * 1.2)
		sway.parallel().tween_property(tongue, "rotation:z", -lean, t * 1.2)
	for i in SPARKS:
		var spark := MeshInstance3D.new()
		var bit := SphereMesh.new()
		bit.radius = 0.02
		bit.height = 0.04
		bit.radial_segments = 4
		bit.rings = 2
		spark.mesh = bit
		spark.material_override = _flame_material(3)
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var from := Vector3(rng.randf_range(-open * 0.3, open * 0.3), 0.6, lz + rng.randf_range(-0.1, 0.1))
		spark.position = from
		root.add_child(spark)
		var rise := spark.create_tween().set_loops()
		rise.tween_interval(rng.randf_range(0.0, 1.2))
		rise.tween_property(spark, "position", from + Vector3(rng.randf_range(-0.2, 0.2), 0.8, 0.0), rng.randf_range(0.9, 1.5))
		rise.parallel().tween_property(spark, "scale", Vector3.ZERO, 1.2)
		rise.tween_callback(func() -> void:
			spark.position = from
			spark.scale = Vector3.ONE)


static func _flame_material(layer: int) -> StandardMaterial3D:
	var key := "hearth_flame_%d" % layer
	if not W._mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = [Color(0.95, 0.28, 0.06), Color(1.0, 0.55, 0.12), Color(1.0, 0.8, 0.3), Color(1.0, 0.94, 0.7)][layer]
		W._mats[key] = m
	return W._mats[key]
