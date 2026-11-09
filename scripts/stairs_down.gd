class_name StairsDown
extends RefCounted
## A flight of stone steps going down into the ground, instead of a flat black
## hole: every step is a little darker than the one above it, the risers face
## the way the hero comes from, walls and a lit rim frame the opening, and the
## bottom fades into the dark. Used by the stairs down of a home ("<" and ">"),
## the shafts of the mines and lairs ("^"), and as a picture for the doorway of
## the dragon's lair (see doorway_texture).

const STEPS := 7
## Height of one step (metres), so the flight is STEPS * RISE deep.
const RISE := 0.24
const STONE := Color(0.62, 0.58, 0.52)
const BOTTOM := Color(0.02, 0.015, 0.015)
const WALL_THICK := 0.3

## How the flight looks in each setting: "stone" is the colour of the steps (as lit as the
## top step is), "bottom" the dark they fade into, "rim" the lip round the opening, "rough"
## how uneven the hewn steps and the lip are (0 for cut stone), "glow" an emissive edge on
## every tread (or null) and "gloss" how shiny the stone is. Keyed by the map's wall style
## ("walls:" header, see WallThemes), then by its mine setting ("theme:" header, see
## Mines); a map with neither gets the plain stone of the dungeon.
const LOOKS := {
	"": {"stone": Color(0.62, 0.58, 0.52), "bottom": BOTTOM, "rim": Color(0.52, 0.49, 0.44), "rough": 0.0, "glow": null, "gloss": 0.1},
	"bone": {"stone": Color(0.7, 0.64, 0.52), "bottom": Color(0.03, 0.022, 0.015), "rim": Color(0.58, 0.52, 0.41), "rough": 0.12, "glow": null, "gloss": 0.15},
	"rock": {"stone": Color(0.5, 0.43, 0.35), "bottom": Color(0.02, 0.014, 0.01), "rim": Color(0.36, 0.31, 0.26), "rough": 0.2, "glow": null, "gloss": 0.05},
	"obsidian": {"stone": Color(0.24, 0.2, 0.32), "bottom": Color(0.01, 0.008, 0.02), "rim": Color(0.16, 0.13, 0.22), "rough": 0.12, "glow": Color(0.55, 0.2, 0.9), "gloss": 0.75},
	"crystal": {"stone": Color(0.45, 0.6, 0.78), "bottom": Color(0.01, 0.02, 0.05), "rim": Color(0.3, 0.45, 0.68), "rough": 0.15, "glow": Color(0.35, 0.8, 1.0), "gloss": 0.6},
	"zwerge": {"stone": Color(0.55, 0.5, 0.44), "bottom": BOTTOM, "rim": Color(0.4, 0.36, 0.31), "rough": 0.0, "glow": null, "gloss": 0.2},
	"glut": {"stone": Color(0.36, 0.25, 0.2), "bottom": Color(0.03, 0.01, 0.005), "rim": Color(0.25, 0.17, 0.14), "rough": 0.1, "glow": Color(1.0, 0.4, 0.1), "gloss": 0.2},
	"uralt": {"stone": Color(0.68, 0.6, 0.45), "bottom": Color(0.03, 0.02, 0.012), "rim": Color(0.55, 0.47, 0.34), "rough": 0.05, "glow": null, "gloss": 0.1},
	"zinne": {"stone": Color(0.58, 0.55, 0.64), "bottom": Color(0.015, 0.012, 0.025), "rim": Color(0.45, 0.42, 0.5), "rough": 0.0, "glow": null, "gloss": 0.25},
	"sternhof": {"stone": Color(0.5, 0.52, 0.6), "bottom": Color(0.012, 0.014, 0.025), "rim": Color(0.38, 0.4, 0.5), "rough": 0.05, "glow": null, "gloss": 0.2},
	"sterngruft": {"stone": Color(0.4, 0.42, 0.56), "bottom": Color(0.01, 0.012, 0.03), "rim": Color(0.3, 0.32, 0.46), "rough": 0.05, "glow": Color(0.5, 0.6, 1.0), "gloss": 0.3},
}


## The look of the flight for a map with the wall style `style` and mine setting `theme`:
## the wall style wins (it dresses the walls the flight sinks into), then the setting.
static func look(style: String, theme := "") -> Dictionary:
	if LOOKS.has(style) and style != "":
		return LOOKS[style]
	return LOOKS.get(theme, LOOKS[""])


## Builds the flight in the tile at `pos`, going down towards `dir` (a unit
## step on the ground: the far end of the flight lies that way). `tile` is the
## tile's width. Returns the node that holds the pieces.
static func build(parent: Node3D, pos: Vector3, tile: float, dir: Vector3 = Vector3(0, 0, -1), style: Dictionary = {}) -> Node3D:
	if style.is_empty():
		style = LOOKS[""]
	var stone_colour: Color = style["stone"]
	var bottom_colour: Color = style["bottom"]
	var rough: float = style["rough"]
	var gloss: float = style["gloss"]
	var glow = style["glow"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(int(pos.x * 10.0), int(pos.z * 10.0)))
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = atan2(-dir.x, -dir.z)
	parent.add_child(holder)
	var depth := STEPS * RISE
	var run := tile / float(STEPS)
	var width := tile - WALL_THICK * 2.0
	for i in STEPS:
		var shade := darkness(i, STEPS)
		var colour := stone_colour.lerp(bottom_colour, shade)
		# The tread: its top lies RISE lower than that of the step before.
		var top := -RISE * float(i + 1)
		var z := tile * 0.5 - run * (float(i) + 0.5)
		# Hewn steps are a little uneven: each is wider or narrower than its neighbours.
		var w := width - rough * rng.randf() * 0.9
		var shift := (rng.randf() - 0.5) * rough * 0.9
		_box(holder, Vector3(w, 0.14, run), Vector3(shift, top - 0.07, z), _stone(colour, gloss, 0.55))
		if glow != null:
			# A faint glowing edge on the lip of every tread, so the flight shows up
			# in the dark and reads as steps from far away.
			var edge: Color = glow
			_box(holder, Vector3(w, 0.03, 0.07), Vector3(shift, top + 0.005, z - run * 0.5 + 0.04), _lit(edge.lerp(bottom_colour, shade * 0.7)))
		# The riser under the previous step's edge, a shade darker than its
		# tread so the steps read as steps from above.
		var riser := colour.lerp(bottom_colour, 0.35)
		_box(holder, Vector3(w, RISE, 0.06), Vector3(shift, top + RISE * 0.5, z + run * 0.5), _stone(riser, gloss, 0.4))
	# The wall at the far end and the dark below, fading out.
	_box(holder, Vector3(width, depth + 1.0, 0.2), Vector3(0, -depth * 0.5 - 0.5, -tile * 0.5 - 0.1), _unshaded(bottom_colour))
	_box(holder, Vector3(width, 0.1, tile), Vector3(0, -depth - 0.05, 0), _unshaded(bottom_colour))
	# Side walls, in stone that darkens the deeper it goes (a few bands).
	var bands := 4
	for side in [-1.0, 1.0]:
		for b in bands:
			var h := (depth + 0.4) / float(bands)
			var y0 := 0.4 - h * (float(b) + 0.5)
			var wall_colour := stone_colour.lerp(bottom_colour, darkness(b, bands) * 0.9).darkened(0.25)
			_box(holder, Vector3(WALL_THICK, h, tile), Vector3(side * (tile - WALL_THICK) * 0.5, y0, 0), _stone(wall_colour, gloss))
	# The rim round the opening, standing a little above the floor: a straight lip of cut
	# stone, or in rough settings a ring of uneven chunks, as if the flight was hewn out.
	var rim := _stone(style["rim"], gloss)
	if rough <= 0.0:
		_box(holder, Vector3(tile, 0.18, 0.3), Vector3(0, 0.09, tile * 0.5 - 0.15), rim)
		_box(holder, Vector3(tile, 0.18, 0.3), Vector3(0, 0.09, -tile * 0.5 + 0.15), rim)
		for side in [-1.0, 1.0]:
			_box(holder, Vector3(0.3, 0.18, tile), Vector3(side * (tile * 0.5 - 0.15), 0.09, 0), rim)
	else:
		_rough_rim(holder, tile, rim, rough, rng)
	return holder


## The lip of a hewn flight: chunks of different length, height and depth along the three
## sides that frame it (the top step side stays low, so the way down is open), a little out
## of line, each turned a few degrees.
static func _rough_rim(holder: Node3D, tile: float, rim: Material, rough: float, rng: RandomNumberGenerator) -> void:
	var count := 5
	for side in 4:
		# Side 0 is the near edge (open floor, where the hero steps on), 1 the far end, 2 and 3 the flanks.
		var along := Vector3(1, 0, 0) if side < 2 else Vector3(0, 0, 1)
		var across := Vector3(0, 0, 1) if side < 2 else Vector3(1, 0, 0)
		var sign := 1.0 if side % 2 == 0 else -1.0
		for k in count:
			var len := tile / float(count) * (1.0 + rng.randf() * 0.35)
			var h := 0.1 + rng.randf() * 0.18 * (1.0 + rough * 2.0)
			if side == 0:
				h = minf(h, 0.14)
			var t := (float(k) + 0.5) / float(count) - 0.5
			var thick := 0.22 + rng.randf() * 0.2
			var at := along * t * (tile - 0.3) + across * sign * (tile * 0.5 - thick * 0.5 - rng.randf() * rough * 0.2)
			at.y = h * 0.5
			var size := Vector3(len, h, thick) if side < 2 else Vector3(thick, h, len)
			var chunk := _box(holder, size, at, rim)
			chunk.rotation.y = (rng.randf() - 0.5) * rough * 0.7


## How dark step `i` of `count` is, from 0 (lit, at the top) to 1 (black).
## Eased, so the first steps stay readable and the last fade away.
static func darkness(i: int, count: int) -> float:
	var t := float(i) / float(maxi(1, count - 1))
	return clampf(t * t * 0.5 + t * 0.3, 0.0, 1.0)


## A picture of a stairway seen from the front, going down into a doorway:
## the lit steps at the foot of the opening and the dark closing in above
## them, used for the black hole behind the lair's arch.
static func doorway_texture(glow := Color(0.55, 0.16, 0.06)) -> Texture2D:
	var w := 64
	var h := 128
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var steps := 8
	for y in h:
		# The lower part of the picture is the flight: bands, lighter on the
		# top edge of each step, getting darker towards the top (further in).
		var v := float(y) / float(h - 1)
		var col := BOTTOM
		var floor_start := 0.30
		if v >= floor_start:
			var f := (v - floor_start) / (1.0 - floor_start)
			var band := f * float(steps)
			var within := band - floorf(band)
			var depth := 1.0 - f
			var light := STONE.lerp(BOTTOM, clampf(depth * 0.95, 0.0, 1.0))
			col = light * (0.8 + 0.4 * (1.0 - within))
			col = col.lerp(glow, clampf(depth * 0.35, 0.0, 0.35))
		else:
			col = BOTTOM.lerp(glow * 0.25, v / floor_start * 0.5)
		col.a = 1.0
		for x in w:
			var edge := absf(float(x) / float(w - 1) - 0.5) * 2.0
			var c := col.darkened(clampf(edge * edge * 0.6, 0.0, 0.6))
			c.a = 1.0
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func _stone(colour: Color, gloss := 0.1, self_lit := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	if self_lit > 0.0:
		# Down in the shaft no lamp reaches: the steps carry a little light of their own,
		# so the flight reads as steps and not as a black pit.
		mat.emission_enabled = true
		mat.emission = colour
		mat.emission_energy_multiplier = self_lit
	mat.albedo_color = colour
	mat.roughness = 0.9 - gloss * 0.6
	mat.metallic_specular = 0.5 + gloss * 0.5
	return mat


## A lit edge that does not depend on the lamps.
static func _lit(colour: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = colour
	return mat


static func _unshaded(colour: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = colour
	return mat


static func _box(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi
