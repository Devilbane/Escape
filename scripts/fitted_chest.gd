class_name FittedChest
extends RefCounted
## The chests of the game, built from planks and metal fittings instead of the plain kit chest, in
## three styles (see STYLES):
##   oak    iron-banded oak: warm oak planks under black iron straps that run over the domed lid and
##          down the front, studded with rivets, with corner caps, strap hinges, a lock plate with a
##          hasp and two iron drop handles. The everyday chest: storage chests away from home (the
##          crafting square's, a village house's) and the everyday loot chests.
##   dark   dark reinforced: blackened boards held in heavy steel, every edge framed in angle steel,
##          broad bands round the body, a low flat lid, square studs in rows and a big padlock.
##          The steel-banded store at home (see HomeStoreFurniture) and the rich loot behind a puzzle
##          gate or in a secret room.
##   brass  ornate brass: turned walnut (as the bookshelf) on ball feet, slim brass bands with domed
##          studs, scrolled corner plates, a medallion on the lid and a shaped lock escutcheon.
##          The storage chest in the hero's own house (and the chest they furnish a built house
##          with) and the epic chests of the elder's lair.
##
## Every chest is the same size as the kit chest it replaces (1.6 m across, 1.24 m deep, about
## 1.25 m high), opens to its +Z side and stands with its back on the wall as before, so click
## areas, solids and facing stay as they were. The lid is a node of its own ("Lid", see LID), its
## origin on the hinge, so Level.search can swing it open by turning it about x, and every fitting
## on the lid (straps, hasp, hinge knuckles) swings with it.
##
## Each style is two meshes (body and lid) with a wood, a metal and (for loot) a gold surface, built
## once and shared, so a dungeon full of chests stays cheap.

## The node of the lid inside a chest.
const LID := "Lid"
const BODY := "Body"
## The chest's size: across (x), deep (z) and the body's height below the lid (metres).
const WIDTH := 1.6
const DEPTH := 1.24
const BODY_HEIGHT := 0.6
## How high the lid's straight rim is, below its curve.
const RIM := 0.12
## How thick the boards are, and how far metal stands proud of the wood.
const BOARD := 0.05
const PROUD := 0.018

## Each style: its woods, its metal, how far its lid rises above the rim, how high it stands on feet,
## where the straps cross it (as shares of the width) and how wide they are.
const STYLES := {
	"oak": {"wood": Color(0.56, 0.38, 0.22), "dark_wood": Color(0.36, 0.23, 0.13), "inside": Color(0.16, 0.1, 0.06),
			"metal": Color(0.2, 0.2, 0.21), "stud": Color(0.33, 0.32, 0.31), "rise": 0.46, "feet": 0.0,
			"straps": [-0.3, 0.3], "strap": 0.11},
	"dark": {"wood": Color(0.24, 0.17, 0.13), "dark_wood": Color(0.15, 0.1, 0.08), "inside": Color(0.14, 0.1, 0.08),
			"metal": Color(0.42, 0.44, 0.47), "stud": Color(0.6, 0.62, 0.66), "rise": 0.24, "feet": 0.0,
			"straps": [-0.36, 0.0, 0.36], "strap": 0.15},
	"brass": {"wood": Color(0.32, 0.19, 0.11), "dark_wood": Color(0.2, 0.12, 0.07), "inside": Color(0.32, 0.06, 0.08),
			"metal": Color(0.86, 0.64, 0.28), "stud": Color(0.95, 0.76, 0.36), "rise": 0.42, "feet": 0.09,
			"straps": [-0.3, -0.1, 0.1, 0.3], "strap": 0.06},
}
## The gold heaped in a loot chest, and the gems among it.
const GOLD := Color(1.0, 0.76, 0.3)
const GEMS := [Color(0.85, 0.1, 0.15), Color(0.15, 0.35, 0.95), Color(0.1, 0.75, 0.35)]
## How many slats the curve of a lid is built from.
const SLATS := 7

## The built meshes by style (and "+gold" for a loot chest): [body, lid, glint points].
static var _built := {}
static var _wood: StandardMaterial3D
static var _metal: StandardMaterial3D
static var _gold: StandardMaterial3D
static var _grain: Texture2D


## A chest of `style` at `pos` (in `parent`'s space), turned by `rot_y`. `gold` heaps coins inside
## (a loot chest); its glints are then on the chest's "glints" meta, switched off until it opens.
static func place(parent: Node, style: String, pos: Vector3, rot_y := 0.0, gold := false) -> Node3D:
	var built := _meshes(style, gold)
	var look: Dictionary = STYLES[style]
	var root := Node3D.new()
	root.name = "Chest"
	root.position = pos
	root.rotation.y = rot_y
	root.set_meta("style", style)
	var body := MeshInstance3D.new()
	body.name = BODY
	body.mesh = built[0]
	root.add_child(body)
	var lid := MeshInstance3D.new()
	lid.name = LID
	lid.mesh = built[1]
	lid.position = hinge(look)
	root.add_child(lid)
	parent.add_child(root)
	if gold:
		var glints := CoinShine.make(built[2], 5, 0.9)
		Effects.start_cold(glints)
		root.add_child(glints)
		root.set_meta("glints", glints)
	return root


## The lid of a chest built by `place`.
static func lid_of(chest: Node3D) -> Node3D:
	return chest.get_node_or_null(LID)


## Where the lid is hinged in the chest's own space: the top of the body's back.
static func hinge(look: Dictionary) -> Vector3:
	return Vector3(0, float(look.feet) + BODY_HEIGHT, -DEPTH * 0.5)


## The radius of the lid's curve and how far its centre lies below the rim's top (lid space).
static func _arc(look: Dictionary) -> Vector2:
	var rise: float = look.rise
	var r := (DEPTH * DEPTH * 0.25 + rise * rise) / (2.0 * rise)
	return Vector2(r, RIM + rise - r)


## The half angle the lid's curve spans.
static func _half_angle(look: Dictionary) -> float:
	return asin(DEPTH * 0.5 / _arc(look).x)


## A point on the lid's curve, `out` metres outside it, at angle `phi` (0 at the top, positive
## towards the front), in lid space.
static func _on_arc(look: Dictionary, phi: float, out := 0.0) -> Vector3:
	var arc := _arc(look)
	return Vector3(0, arc.y + (arc.x + out) * cos(phi), DEPTH * 0.5 + (arc.x + out) * sin(phi))


static func _meshes(style: String, gold: bool) -> Array:
	var key := style + ("+gold" if gold else "")
	if _built.has(key):
		return _built[key]
	_materials()
	var look: Dictionary = STYLES[style]
	var parts := [Part.new(), Part.new()]
	_build_body(parts[0], look, style)
	_build_lid(parts[1], look, style)
	var points := PackedVector3Array()
	if gold:
		points = _build_gold(parts[0], look)
	var result := [parts[0].commit(), parts[1].commit(), points]
	_built[key] = result
	return result


static func _materials() -> void:
	if _wood:
		return
	_wood = StandardMaterial3D.new()
	_wood.vertex_color_use_as_albedo = true
	_wood.albedo_texture = _grain_texture()
	_wood.roughness = 0.85
	_metal = StandardMaterial3D.new()
	_metal.vertex_color_use_as_albedo = true
	_metal.metallic = 0.55
	_metal.metallic_specular = 0.7
	_metal.roughness = 0.42
	_gold = StandardMaterial3D.new()
	_gold.vertex_color_use_as_albedo = true
	_gold.metallic = 0.45
	_gold.metallic_specular = 0.8
	_gold.roughness = 0.3
	_gold.emission_enabled = true
	_gold.emission = GOLD
	_gold.emission_energy_multiplier = 0.15


## A pale picture of wood grain, tinted by each board's colour: long wavy lines along u, a knot
## or two and darker ends.
static func _grain_texture() -> Texture2D:
	if _grain:
		return _grain
	var rng := RandomNumberGenerator.new()
	rng.seed = 9137
	var size := Vector2i(256, 64)
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var knots := []
	for i in 3:
		knots.append(Vector2(rng.randf_range(20, size.x - 20), rng.randf_range(10, size.y - 10)))
	for y in size.y:
		for x in size.x:
			var u := float(x) / size.x
			var p := Vector2(x, y)
			var bend := 0.0
			for k: Vector2 in knots:
				var d := p.distance_to(k)
				bend += 5.0 * exp(-d * d / 60.0) * signf(y - k.y)
			var wave := sin(u * TAU * 2.0 + y * 0.07) * 1.2 + sin(u * TAU * 5.0 + y * 0.3) * 0.4
			var line := sin((y + bend + wave) * 0.9) * 0.5 + 0.5
			var fine := sin((y + bend * 0.5) * 3.7 + u * 7.0) * 0.5 + 0.5
			var v := 1.0 - pow(line, 6.0) * 0.3 - fine * 0.07
			for k: Vector2 in knots:
				var d := Vector2((x - k.x) * 0.7, y - k.y).length()
				if d < 3.2:
					v *= 0.55 + d * 0.1
			img.set_pixel(x, y, Color(v, v, v))
	img.generate_mipmaps()
	_grain = ImageTexture.create_from_image(img)
	return _grain


## A wood shade a little off `base`, the same for the same `seed`.
static func _vary(base: Color, seed_value: int) -> Color:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 13
	return base.lightened(rng.randf_range(0.0, 0.09)) if rng.randf() < 0.5 else base.darkened(rng.randf_range(0.0, 0.1))


# ---------------------------------------------------------------------------------------------
# The body


static func _build_body(b: Part, look: Dictionary, style: String) -> void:
	var foot: float = look.feet
	var top := foot + BODY_HEIGHT
	var wood: Color = look.wood
	var dark: Color = look.dark_wood
	var metal: Color = look.metal
	var stud: Color = look.stud
	var hw := WIDTH * 0.5
	var hd := DEPTH * 0.5
	var mid := foot + BODY_HEIGHT * 0.5
	# The dark inside, seen through the gaps between the boards and from above with the lid up.
	b.wood(Vector3(0, mid, 0), Vector3(WIDTH - 0.04, BODY_HEIGHT, DEPTH - 0.04), look.inside)
	# The boards: three a side, lying along the chest, with a thin gap between them.
	var rows := 3
	var gap := 0.012
	var board_h := (BODY_HEIGHT - 0.1 - gap * (rows - 1)) / rows
	for i in rows:
		var y := foot + 0.1 + board_h * (i + 0.5) + gap * i
		for sz: float in [-1.0, 1.0]:
			b.wood(Vector3(0, y, sz * (hd - BOARD * 0.5)), Vector3(WIDTH, board_h, BOARD), _vary(wood, i * 2 + int(sz)), 0)
		for sx: float in [-1.0, 1.0]:
			b.wood(Vector3(sx * (hw - BOARD * 0.5), y, 0), Vector3(BOARD, board_h, DEPTH - BOARD * 2.0), _vary(wood, 10 + i * 2 + int(sx)), 2)
	# A plinth along the foot, and a rim round the top where the lid shuts.
	b.wood(Vector3(0, foot + 0.05, 0), Vector3(WIDTH + 0.04, 0.1, DEPTH + 0.04), dark, 0)
	for sz: float in [-1.0, 1.0]:
		b.wood(Vector3(0, top - 0.02, sz * (hd - 0.04)), Vector3(WIDTH, 0.04, 0.08), dark, 0)
	for sx: float in [-1.0, 1.0]:
		b.wood(Vector3(sx * (hw - 0.04), top - 0.02, 0), Vector3(0.08, 0.04, DEPTH - 0.16), dark, 2)
	var front := hd + 0.02 + PROUD * 0.5
	var back := -front
	var side := hw + 0.02 + PROUD * 0.5
	# The straps up the front and the back.
	var strap: float = look.strap
	for t: float in look.straps:
		var x := t * WIDTH
		for z: float in [front, back]:
			b.metal(Vector3(x, mid, z), Vector3(strap, BODY_HEIGHT, PROUD), metal)
		var studs := 4 if style != "brass" else 6
		for k in studs:
			var y := foot + 0.08 + (BODY_HEIGHT - 0.16) * k / (studs - 1)
			if style == "dark" and k % 2 == 1:
				continue
			_stud(b, Vector3(x, y, front + PROUD * 0.5), Vector3.BACK, style, stud)
	match style:
		"oak":
			# One band round the foot, iron caps on the corners and drop handles at the ends.
			_band(b, foot + 0.05, 0.08, metal)
			for sx: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					_corner(b, Vector3(sx * hw, foot, sz * hd), sx, sz, 0.2, 0.18, metal)
					_corner(b, Vector3(sx * hw, top - 0.18, sz * hd), sx, sz, 0.18, 0.18, metal)
			for sx: float in [-1.0, 1.0]:
				_drop_handle(b, Vector3(sx * side, foot + BODY_HEIGHT * 0.62, 0), sx, metal, stud, 0.14)
		"dark":
			# Two broad bands, every edge in angle steel, a grid of studs and ring handles.
			_band(b, foot + 0.07, 0.12, metal)
			_band(b, top - 0.08, 0.1, metal)
			for sx: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					_corner(b, Vector3(sx * hw, foot, sz * hd), sx, sz, BODY_HEIGHT, 0.13, metal)
			for x: float in [-0.36, -0.18, 0.18, 0.36]:
				for sz: float in [-1.0, 1.0]:
					_stud(b, Vector3(x, foot + 0.07, sz * (hd + 0.02 + PROUD * 1.5)), Vector3(0, 0, sz), style, stud)
			for sx: float in [-1.0, 1.0]:
				for k in 3:
					_stud(b, Vector3(sx * (side + PROUD * 0.5), foot + 0.07, -0.35 + k * 0.35), Vector3(sx, 0, 0), style, stud)
				_drop_handle(b, Vector3(sx * side, foot + BODY_HEIGHT * 0.5, 0), sx, metal, stud, 0.17)
		"brass":
			# Ball feet, slim brass edging up the corners, scrolled corner plates and side rings.
			for sx: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					var at := Vector3(sx * (hw - 0.1), foot * 0.5, sz * (hd - 0.1))
					b.wood_ball(at, foot * 0.62, look.dark_wood)
					b.metal(Vector3(sx * (hw + 0.01), mid, sz * (hd + 0.01)), Vector3(0.05, BODY_HEIGHT, 0.05), metal)
					_scroll_plate(b, Vector3(sx * hw, top - 0.04, sz * hd), sx, sz, metal, stud, true)
					_scroll_plate(b, Vector3(sx * hw, foot + 0.04, sz * hd), sx, sz, metal, stud, false)
			_band(b, foot + 0.1, 0.035, metal)
			_band(b, top - 0.03, 0.035, metal)
			for sx: float in [-1.0, 1.0]:
				_drop_handle(b, Vector3(sx * side, foot + BODY_HEIGHT * 0.6, 0), sx, metal, stud, 0.12)
	# The hinge plates on the back, below the knuckles on the lid.
	for sx: float in [-1.0, 1.0]:
		var x := sx * WIDTH * (0.3 if style != "brass" else 0.25)
		var plate := Vector3(0.16, 0.24, PROUD) if style != "dark" else Vector3(0.2, 0.32, PROUD)
		b.metal(Vector3(x, top - plate.y * 0.5, back - PROUD), plate, metal)
		for k in 2:
			_stud(b, Vector3(x, top - 0.06 - k * (plate.y - 0.1), back - PROUD * 1.5), Vector3.FORWARD, style, stud)
	_lock(b, look, style, Vector3(0, top - 0.02, front))


## A band round the body at height `y` (its middle), `h` high.
static func _band(b: Part, y: float, h: float, metal: Color) -> void:
	var o := 0.02 + PROUD
	b.metal(Vector3(0, y, DEPTH * 0.5 + o - PROUD * 0.5), Vector3(WIDTH + o * 2.0, h, PROUD), metal)
	b.metal(Vector3(0, y, -DEPTH * 0.5 - o + PROUD * 0.5), Vector3(WIDTH + o * 2.0, h, PROUD), metal)
	for sx: float in [-1.0, 1.0]:
		b.metal(Vector3(sx * (WIDTH * 0.5 + o - PROUD * 0.5), y, 0), Vector3(PROUD, h, DEPTH + o * 2.0), metal)


## An angle of metal over a vertical edge of the body at `at` (its foot), `h` high and `w` wide on
## both faces, with a rivet in each leg.
static func _corner(b: Part, at: Vector3, sx: float, sz: float, h: float, w: float, metal: Color) -> void:
	var o := 0.02 + PROUD * 0.5
	var y := at.y + h * 0.5
	b.metal(Vector3(at.x - sx * (w * 0.5 - o - PROUD), y, at.z + sz * o), Vector3(w, h, PROUD), metal)
	b.metal(Vector3(at.x + sx * o, y, at.z - sz * (w * 0.5 - o - PROUD)), Vector3(PROUD, h, w), metal)
	var rivet := metal.lightened(0.15)
	var heights := [h * 0.5] if h < 0.3 else [0.08, h * 0.5, h - 0.08]
	for ry: float in heights:
		b.dome(Vector3(at.x - sx * (w - 0.05), at.y + ry, at.z + sz * (o + PROUD * 0.5)), Vector3(0, 0, sz), 0.018, rivet)
		b.dome(Vector3(at.x + sx * (o + PROUD * 0.5), at.y + ry, at.z - sz * (w - 0.05)), Vector3(sx, 0, 0), 0.018, rivet)


## A stud on a strap: a round rivet (oak), a square boss (dark) or a domed brass nail.
static func _stud(b: Part, at: Vector3, normal: Vector3, style: String, colour: Color) -> void:
	match style:
		"dark":
			b.metal(at + normal * 0.008, Vector3(0.04, 0.04, 0.04), colour)
		"brass":
			b.dome(at, normal, 0.022, colour)
		_:
			b.dome(at, normal, 0.02, colour)


## A handle hanging from a plate on the side `sx` of the body: a ring for the dark and brass
## chests, a bent bar for the oak one. `r` is how far it hangs.
static func _drop_handle(b: Part, at: Vector3, sx: float, metal: Color, stud: Color, r: float) -> void:
	var n := Vector3(sx, 0, 0)
	b.metal(at, Vector3(PROUD, 0.12, 0.26), metal)
	for dz: float in [-0.08, 0.08]:
		b.dome(at + Vector3(sx * PROUD * 0.5, 0.0, dz), n, 0.02, stud)
	# Two lugs and the bail hanging down from them in a half ring.
	var out := at + n * 0.035
	var steps := 8
	var prev := Vector3.ZERO
	for i in steps + 1:
		var a := PI * float(i) / steps
		var p := out + Vector3(0, -r * sin(a) * 0.85 + 0.02, -cos(a) * r * 0.8)
		if i > 0:
			b.rod(prev, p, 0.016, metal)
		prev = p
	for dz: float in [-1.0, 1.0]:
		b.rod(at + Vector3(0, 0.02, dz * r * 0.8), out + Vector3(0, 0.02, dz * r * 0.8), 0.02, metal)


## A shaped corner plate (brass): a plate on each face with a trefoil of domes at its tip.
static func _scroll_plate(b: Part, at: Vector3, sx: float, sz: float, metal: Color, stud: Color, upper: bool) -> void:
	var o := 0.02 + PROUD * 0.5
	var dir := -1.0 if upper else 1.0
	var h := 0.16
	var y := at.y + dir * h * 0.5
	for face in 2:
		var along := Vector3(-sx, 0, 0) if face == 0 else Vector3(0, 0, -sz)
		var normal := Vector3(0, 0, sz) if face == 0 else Vector3(sx, 0, 0)
		var base := Vector3(at.x, y, at.z) + normal * o
		# The plate tapers away from the corner in three steps, ending in a leaf of three domes.
		for k in 3:
			var w := 0.07 - k * 0.012
			var tall := h - k * 0.04
			var c := base + along * (0.035 + k * 0.06)
			var size := Vector3(w if face == 0 else PROUD, tall, PROUD if face == 0 else w)
			b.metal(c, size, metal)
		var tip := base + along * 0.2
		b.dome(tip + normal * PROUD * 0.5, normal, 0.026, stud)
		b.dome(tip + normal * PROUD * 0.5 + Vector3(0, 0.035, 0) - along * 0.03, normal, 0.015, stud)
		b.dome(tip + normal * PROUD * 0.5 - Vector3(0, 0.035, 0) - along * 0.03, normal, 0.015, stud)


## The lock on the front, its top at `at`: a plate with a keyhole (and a padlock on the dark chest).
static func _lock(b: Part, look: Dictionary, style: String, at: Vector3) -> void:
	var metal: Color = look.metal
	var stud: Color = look.stud
	var hole := Color(0.03, 0.03, 0.035)
	var z := at.z + PROUD
	match style:
		"oak":
			b.metal(Vector3(0, at.y - 0.14, z), Vector3(0.24, 0.26, PROUD), metal)
			for dx: float in [-0.09, 0.09]:
				for dy: float in [-0.04, -0.24]:
					b.dome(Vector3(dx, at.y + dy, z + PROUD * 0.5), Vector3.BACK, 0.016, stud)
			b.metal(Vector3(0, at.y - 0.13, z + PROUD * 0.6), Vector3(0.035, 0.035, 0.004), hole)
			b.metal(Vector3(0, at.y - 0.165, z + PROUD * 0.6), Vector3(0.016, 0.05, 0.004), hole)
		"dark":
			b.metal(Vector3(0, at.y - 0.17, z), Vector3(0.3, 0.32, PROUD), metal.darkened(0.15))
			for dx: float in [-0.11, 0.11]:
				for dy: float in [-0.05, -0.29]:
					b.metal(Vector3(dx, at.y + dy, z + PROUD), Vector3(0.035, 0.035, 0.02), stud)
			# A padlock hanging from the staple: a shackle and a heavy round-bottomed case.
			var lock := Vector3(0, at.y - 0.26, z + 0.05)
			b.rod(lock + Vector3(-0.045, 0.05, 0), lock + Vector3(-0.045, 0.12, 0), 0.014, stud)
			b.rod(lock + Vector3(0.045, 0.05, 0), lock + Vector3(0.045, 0.12, 0), 0.014, stud)
			b.rod(lock + Vector3(-0.045, 0.12, 0), lock + Vector3(0.045, 0.12, 0), 0.014, stud)
			b.metal(lock, Vector3(0.15, 0.12, 0.05), metal.darkened(0.25))
			b.rod(lock + Vector3(-0.075, -0.06, 0), lock + Vector3(0.075, -0.06, 0), 0.025, metal.darkened(0.25))
			b.metal(lock + Vector3(0, -0.01, 0.026), Vector3(0.022, 0.05, 0.004), hole)
		"brass":
			# A shaped escutcheon: a round head over a pointed plate, edged in domes.
			var c := Vector3(0, at.y - 0.15, z)
			b.metal(c, Vector3(0.18, 0.2, PROUD), metal)
			b.disc(c + Vector3(0, 0.07, 0), Vector3.BACK, 0.12, PROUD, metal)
			b.metal(c + Vector3(0, -0.12, 0), Vector3(0.09, 0.09, PROUD), metal, Basis(Vector3.BACK, PI * 0.25))
			for a: float in [-1.0, -0.5, 0.0, 0.5, 1.0]:
				b.dome(c + Vector3(sin(a * 1.4) * 0.105, 0.07 + cos(a * 1.4) * 0.105, PROUD * 0.5), Vector3.BACK, 0.013, stud)
			b.metal(c + Vector3(0, 0.03, PROUD * 0.6), Vector3(0.035, 0.035, 0.004), hole)
			b.metal(c + Vector3(0, -0.005, PROUD * 0.6), Vector3(0.016, 0.05, 0.004), hole)


## A heap of coins in a loot chest with a few gems among them; returns where its glints may blink.
static func _build_gold(b: Part, look: Dictionary) -> PackedVector3Array:
	var top := float(look.feet) + BODY_HEIGHT - 0.02
	var high := minf(0.28, float(look.rise) + RIM - 0.08)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	b.heap(Vector3(0, top, 0.02), Vector3(WIDTH * 0.44, high, DEPTH * 0.38), GOLD)
	var points := PackedVector3Array()
	for i in 70:
		var u := rng.randf_range(-0.95, 0.95)
		var v := rng.randf_range(-0.9, 0.9)
		if u * u + v * v > 1.0:
			continue
		var lift := high * sqrt(maxf(0.0, 1.0 - u * u - v * v)) * 0.95 + 0.01
		var p := Vector3(u * WIDTH * 0.44, top + lift, 0.02 + v * DEPTH * 0.38)
		var tilt := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.1, 0.6))
		b.coin(p, tilt, 0.055, GOLD.lightened(rng.randf_range(0.0, 0.12)))
		if i % 3 == 0:
			points.append(p + Vector3.UP * 0.02)
	for i in GEMS.size():
		var p := Vector3((i - 1) * 0.34, top + high * 0.72, rng.randf_range(-0.12, 0.18))
		b.gem(p, 0.05, GEMS[i])
	return points


# ---------------------------------------------------------------------------------------------
# The lid (built in the lid's space: its origin on the hinge, the front towards +z)


static func _build_lid(b: Part, look: Dictionary, style: String) -> void:
	var wood: Color = look.wood
	var dark: Color = look.dark_wood
	var metal: Color = look.metal
	var stud: Color = look.stud
	var hw := WIDTH * 0.5
	var arc := _arc(look)
	var half := _half_angle(look)
	# The rim: a board all round, and the dark underside seen with the lid up.
	b.wood(Vector3(0, RIM * 0.5, DEPTH * 0.5), Vector3(WIDTH - 0.04, RIM, DEPTH - 0.04), look.inside)
	b.wood(Vector3(0, RIM * 0.5, BOARD * 0.5), Vector3(WIDTH, RIM, BOARD), dark, 0)
	b.wood(Vector3(0, RIM * 0.5, DEPTH - BOARD * 0.5), Vector3(WIDTH, RIM, BOARD), dark, 0)
	for sx: float in [-1.0, 1.0]:
		b.wood(Vector3(sx * (hw - BOARD * 0.5), RIM * 0.5, DEPTH * 0.5), Vector3(BOARD, RIM, DEPTH - BOARD * 2.0), dark, 2)
	# The curve: a dark core, ends of solid wood and slats over it with a thin gap between them.
	b.arch(-hw + BOARD, hw - BOARD, arc, half, RIM, look.inside, BOARD)
	for sx: float in [-1.0, 1.0]:
		b.arch(sx * hw - (BOARD if sx > 0 else 0.0), sx * hw + (0.0 if sx > 0 else BOARD), arc, half, RIM, dark, 0.0)
	var step := half * 2.0 / SLATS
	var chord := 2.0 * arc.x * sin(step * 0.5)
	for i in SLATS:
		var phi := -half + step * (i + 0.5)
		var c := _on_arc(look, phi, -BOARD * 0.5) * Vector3(0, 1, 1)
		b.wood(c, Vector3(WIDTH - 0.004, BOARD, chord - 0.012), _vary(wood, 40 + i), 0, Basis(Vector3.RIGHT, phi))
	var strap: float = look.strap
	# The straps over the curve and down the rim, front and back, studded.
	for t: float in look.straps:
		var x := t * WIDTH
		_arc_strip(b, look, x, strap, PROUD, metal)
		b.metal(Vector3(x, RIM * 0.5, DEPTH + PROUD * 0.5), Vector3(strap, RIM, PROUD), metal)
		b.metal(Vector3(x, RIM * 0.5, -PROUD * 0.5), Vector3(strap, RIM, PROUD), metal)
		var n := 5 if style != "brass" else 9
		for k in n:
			var phi := -half * 0.9 + half * 1.8 * k / (n - 1)
			if style == "dark" and k % 2 == 1:
				continue
			var at := _on_arc(look, phi, PROUD) + Vector3(x, 0, 0)
			_stud(b, at, Vector3(0, cos(phi), sin(phi)), style, stud)
	match style:
		"oak":
			for sx: float in [-1.0, 1.0]:
				# Iron caps over the lid's front corners.
				b.metal(Vector3(sx * (hw - 0.07), RIM * 0.5, DEPTH + PROUD * 0.5), Vector3(0.16, RIM + 0.02, PROUD), metal)
				b.metal(Vector3(sx * (hw + PROUD * 0.5), RIM * 0.5, DEPTH - 0.07), Vector3(PROUD, RIM + 0.02, 0.16), metal)
				b.dome(Vector3(sx * (hw - 0.1), RIM * 0.5, DEPTH + PROUD), Vector3.BACK, 0.016, stud)
		"dark":
			# Angle steel round the ends of the curve and along the rim, and a ridge bar.
			for sx: float in [-1.0, 1.0]:
				_end_band(b, look, sx, 0.07, metal)
				b.metal(Vector3(sx * (hw + PROUD * 0.5), RIM * 0.5, DEPTH * 0.5), Vector3(PROUD, RIM, DEPTH + PROUD * 2.0), metal)
			b.metal(Vector3(0, RIM * 0.5, DEPTH + PROUD * 0.5), Vector3(WIDTH + PROUD * 2.0, RIM, PROUD), metal)
			b.metal(Vector3(0, RIM * 0.5, -PROUD * 0.5), Vector3(WIDTH + PROUD * 2.0, RIM, PROUD), metal)
		"brass":
			for sx: float in [-1.0, 1.0]:
				_end_band(b, look, sx, 0.035, metal)
			# A medallion on the crown of the lid: a disc, a ring of domes and a boss.
			var crown := _on_arc(look, 0.0, PROUD)
			b.disc(crown, Vector3.UP, 0.15, PROUD, metal)
			for k in 8:
				var a := TAU * k / 8.0
				b.dome(crown + Vector3(cos(a) * 0.11, PROUD * 0.5, sin(a) * 0.11), Vector3.UP, 0.014, stud)
			b.dome(crown + Vector3(0, PROUD * 0.5, 0), Vector3.UP, 0.05, stud)
			# Thin brass along the rim's foot.
			b.metal(Vector3(0, 0.02, DEPTH + PROUD * 0.5), Vector3(WIDTH, 0.035, PROUD), metal)
	# The hinges: a knuckle on the axis and a strap up the back of the lid.
	for sx: float in [-1.0, 1.0]:
		var x := sx * WIDTH * (0.3 if style != "brass" else 0.25)
		b.rod(Vector3(x - 0.09, 0.0, -0.03), Vector3(x + 0.09, 0.0, -0.03), 0.03 if style != "dark" else 0.038, metal.darkened(0.1))
		b.metal(Vector3(x, RIM * 0.5, -PROUD * 1.5), Vector3(0.12, RIM + 0.04, PROUD), metal)
	# The hasp: a flap hanging from the front of the lid over the lock, with a staple through it.
	match style:
		"oak":
			b.metal(Vector3(0, -0.02, DEPTH + PROUD * 2.0), Vector3(0.08, RIM + 0.12, PROUD), metal)
			b.dome(Vector3(0, RIM - 0.03, DEPTH + PROUD * 2.5), Vector3.BACK, 0.018, stud)
			b.rod(Vector3(-0.02, -0.06, DEPTH + PROUD * 3.0), Vector3(0.02, -0.06, DEPTH + PROUD * 3.0), 0.014, stud)
		"dark":
			b.metal(Vector3(0, -0.05, DEPTH + PROUD * 2.0), Vector3(0.12, RIM + 0.16, PROUD), metal.darkened(0.1))
			b.metal(Vector3(0, -0.11, DEPTH + PROUD * 3.0), Vector3(0.05, 0.03, PROUD * 2.0), stud)
		"brass":
			b.metal(Vector3(0, RIM * 0.5, DEPTH + PROUD * 1.5), Vector3(0.1, RIM, PROUD), metal)
			b.dome(Vector3(0, RIM * 0.5, DEPTH + PROUD * 2.0), Vector3.BACK, 0.03, stud)


## A strap of metal following the lid's curve at `x`.
static func _arc_strip(b: Part, look: Dictionary, x: float, width: float, thick: float, colour: Color) -> void:
	var half := _half_angle(look)
	var steps := SLATS * 2
	var step := half * 2.0 / steps
	var r := _arc(look).x + thick * 0.5
	for i in steps:
		var phi := -half + step * (i + 0.5)
		var c := _on_arc(look, phi, thick * 0.5) + Vector3(x, 0, 0)
		b.metal(c, Vector3(width, thick, 2.0 * r * sin(step * 0.5) + 0.004), colour, Basis(Vector3.RIGHT, phi))


## A band of metal along the curved edge of the lid's end `sx`, `width` wide on both faces.
static func _end_band(b: Part, look: Dictionary, sx: float, width: float, colour: Color) -> void:
	var hw := WIDTH * 0.5
	var arc := _arc(look)
	var half := _half_angle(look)
	var steps := SLATS * 2
	var step := half * 2.0 / steps
	for i in steps:
		var phi := -half + step * (i + 0.5)
		var basis := Basis(Vector3.RIGHT, phi)
		var piece := 2.0 * (arc.x + PROUD) * sin(step * 0.5) + 0.004
		# On the top, along the end, and down the end face.
		b.metal(_on_arc(look, phi, PROUD * 0.5) + Vector3(sx * (hw - width * 0.5 + PROUD), 0, 0), Vector3(width, PROUD, piece), colour, basis)
		b.metal(_on_arc(look, phi, -width * 0.5 + PROUD) + Vector3(sx * (hw + PROUD * 0.5), 0, 0), Vector3(PROUD, width, piece), colour, basis)


# ---------------------------------------------------------------------------------------------
# Building meshes


## One mesh being built: a wood, a metal and a gold surface, each a SurfaceTool.
class Part:
	var _wood := SurfaceTool.new()
	var _metal := SurfaceTool.new()
	var _gold := SurfaceTool.new()
	var _has_gold := false

	func _init() -> void:
		for st: SurfaceTool in [_wood, _metal, _gold]:
			st.begin(Mesh.PRIMITIVE_TRIANGLES)

	## A board of wood, its grain along axis `grain` (0 x, 1 y, 2 z) of its own box.
	func wood(centre: Vector3, size: Vector3, colour: Color, grain := 0, basis := Basis.IDENTITY) -> void:
		FittedChest._box(_wood, centre, size, colour, basis, grain)

	func metal(centre: Vector3, size: Vector3, colour: Color, basis := Basis.IDENTITY) -> void:
		FittedChest._box(_metal, centre, size, colour, basis, 0)

	func dome(at: Vector3, normal: Vector3, r: float, colour: Color) -> void:
		FittedChest._dome(_metal, at, normal, r, colour)

	func disc(at: Vector3, normal: Vector3, r: float, thick: float, colour: Color) -> void:
		FittedChest._cylinder(_metal, at - normal * thick * 0.5, at + normal * thick * 0.5, r, colour, 16)

	func rod(from: Vector3, to: Vector3, r: float, colour: Color) -> void:
		FittedChest._cylinder(_metal, from, to, r, colour, 8)

	func wood_ball(at: Vector3, r: float, colour: Color) -> void:
		FittedChest._ball(_wood, at, Vector3(r, r * 0.9, r), colour)

	## The lid's curve between x0 and x1 as a solid of wood: the arc of `arc` (radius, centre)
	## over `half` either side of the top, sitting on the rim, shrunk by `inset`.
	func arch(x0: float, x1: float, arc: Vector2, half: float, rim: float, colour: Color, inset: float) -> void:
		FittedChest._arch(_wood, x0, x1, arc, half, rim, colour, inset)

	func heap(at: Vector3, radii: Vector3, colour: Color) -> void:
		_has_gold = true
		FittedChest._ball(_gold, at, radii, colour, true)

	func coin(at: Vector3, basis: Basis, r: float, colour: Color) -> void:
		_has_gold = true
		FittedChest._cylinder(_gold, at - basis.y * 0.006, at + basis.y * 0.006, r, colour, 10)

	func gem(at: Vector3, r: float, colour: Color) -> void:
		FittedChest._gem(_metal, at, r, colour)

	func commit() -> ArrayMesh:
		var mesh := ArrayMesh.new()
		_wood.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, FittedChest._wood)
		_metal.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, FittedChest._metal)
		if _has_gold:
			_gold.commit(mesh)
			mesh.surface_set_material(mesh.get_surface_count() - 1, FittedChest._gold)
		return mesh


## How many metres of wood the grain picture covers along a board, and across it.
const GRAIN_LENGTH := 1.2
const GRAIN_ACROSS := 0.4


static func _box(st: SurfaceTool, centre: Vector3, size: Vector3, colour: Color, basis: Basis, grain: int) -> void:
	var half := size * 0.5
	var axes := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	st.set_color(colour)
	for a in 3:
		for s: float in [-1.0, 1.0]:
			var n: Vector3 = axes[a] * s
			# The two axes across this face; u runs along the grain where the face holds it.
			var u_axis := grain if grain != a else (a + 1) % 3
			var v_axis := 3 - a - u_axis
			var u: Vector3 = axes[u_axis]
			var v: Vector3 = axes[v_axis]
			if u.cross(v).dot(n) < 0.0:
				v = -v
			var hu: float = half[u_axis]
			var hv: float = half[v_axis]
			var c := n * half[a]
			var corners := [c - u * hu - v * hv, c + u * hu - v * hv, c + u * hu + v * hv, c - u * hu + v * hv]
			var uvs := [Vector2(-hu, -hv), Vector2(hu, -hv), Vector2(hu, hv), Vector2(-hu, hv)]
			var offset := Vector2(centre.x * 0.37 + centre.z * 0.61, centre.y * 0.83 + float(a) * 0.29)
			st.set_normal(basis * n)
			for k: int in [0, 2, 1, 0, 3, 2]:
				st.set_uv((uvs[k] as Vector2) / Vector2(GRAIN_LENGTH, GRAIN_ACROSS) + offset)
				st.add_vertex(centre + basis * (corners[k] as Vector3))


## A low dome (a rivet head or a nail) on a face with `normal`, `r` across.
static func _dome(st: SurfaceTool, at: Vector3, normal: Vector3, r: float, colour: Color) -> void:
	var n := normal.normalized()
	var t := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
	var w := n.cross(t)
	var sides := 8
	var rings := [[0.0, 1.0], [0.35, 0.85], [0.6, 0.5], [0.7, 0.0]]
	st.set_color(colour)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		for k in rings.size() - 1:
			var lo: Array = rings[k]
			var hi: Array = rings[k + 1]
			var p := [
				_dome_point(at, n, t, w, r, a0, lo), _dome_point(at, n, t, w, r, a1, lo),
				_dome_point(at, n, t, w, r, a1, hi), _dome_point(at, n, t, w, r, a0, hi)]
			for idx: int in [0, 2, 1, 0, 3, 2]:
				var q: Vector3 = p[idx]
				st.set_normal(((q - at) + n * r * 0.2).normalized())
				st.add_vertex(q)


static func _dome_point(at: Vector3, n: Vector3, t: Vector3, w: Vector3, r: float, a: float, ring: Array) -> Vector3:
	return at + n * r * float(ring[0]) + (t * cos(a) + w * sin(a)) * r * float(ring[1])


## A closed cylinder from `from` to `to`.
static func _cylinder(st: SurfaceTool, from: Vector3, to: Vector3, r: float, colour: Color, sides: int) -> void:
	var axis := (to - from).normalized()
	var t := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var w := axis.cross(t)
	st.set_color(colour)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := t * cos(a0) + w * sin(a0)
		var d1 := t * cos(a1) + w * sin(a1)
		var quad := [from + d0 * r, from + d1 * r, to + d1 * r, to + d0 * r]
		var normals := [d0, d1, d1, d0]
		for idx: int in [0, 2, 1, 0, 3, 2]:
			st.set_normal(normals[idx])
			st.add_vertex(quad[idx])
		for cap: Array in [[from, -axis, [from + d0 * r, from + d1 * r]], [to, axis, [to + d1 * r, to + d0 * r]]]:
			st.set_normal(cap[1])
			st.add_vertex(cap[0])
			st.add_vertex(cap[2][0])
			st.add_vertex(cap[2][1])


## A ball squashed to `radii` round `at`; `upper` keeps only its top half (a heap).
static func _ball(st: SurfaceTool, at: Vector3, radii: Vector3, colour: Color, upper := false) -> void:
	var sides := 24 if upper else 12
	var rings := 8 if upper else 8
	var lo := 0.0 if upper else -PI * 0.5
	st.set_color(colour)
	for k in rings:
		var b0 := lo + (PI * 0.5 - lo) * k / rings
		var b1 := lo + (PI * 0.5 - lo) * (k + 1) / rings
		for i in sides:
			var a0 := TAU * i / sides
			var a1 := TAU * (i + 1) / sides
			var dirs := [_sphere_dir(a0, b0), _sphere_dir(a1, b0), _sphere_dir(a1, b1), _sphere_dir(a0, b1)]
			for idx: int in [0, 1, 2, 0, 2, 3]:
				var d: Vector3 = dirs[idx]
				var bump := 1.0
				if upper:
					# A heap of coins is lumpy, not a smooth dome, and catches the light unevenly.
					bump = 1.0 + _lump(d) * 0.16 * clampf(d.y * 3.0, 0.0, 1.0)
					st.set_color(colour.darkened(clampf(-_lump(d * 1.7) * 0.25, 0.0, 0.2)).lightened(clampf(_lump(d * 2.3) * 0.15, 0.0, 0.1)))
				st.set_normal((d / radii).normalized())
				st.set_uv(Vector2(float(i) / sides, float(k) / rings))
				st.add_vertex(at + d * radii * Vector3(1.0, bump, 1.0))


## A smooth wobble between -1 and 1 over the directions of a ball (the same for the same direction).
static func _lump(d: Vector3) -> float:
	return (sin(d.x * 9.0 + d.z * 3.0) * cos(d.z * 8.0 - d.x * 2.0) + sin(d.x * 17.0 - d.z * 13.0) * 0.5) / 1.5


static func _sphere_dir(a: float, b: float) -> Vector3:
	return Vector3(cos(a) * cos(b), sin(b), sin(a) * cos(b))


## A cut gem: two pyramids base to base, the top one flat.
static func _gem(st: SurfaceTool, at: Vector3, r: float, colour: Color) -> void:
	var sides := 6
	var top := at + Vector3.UP * r * 0.35
	var bottom := at - Vector3.UP * r * 0.9
	st.set_color(colour)
	for i in sides:
		var p0 := at + Vector3(cos(TAU * i / sides), 0, sin(TAU * i / sides)) * r
		var p1 := at + Vector3(cos(TAU * (i + 1) / sides), 0, sin(TAU * (i + 1) / sides)) * r
		var t0 := top + (p0 - at) * 0.55
		var t1 := top + (p1 - at) * 0.55
		for tri: Array in [[p0, t1, p1], [p0, t0, t1], [top, t1, t0], [p0, p1, bottom]]:
			var n: Vector3 = ((tri[1] as Vector3) - tri[0]).cross((tri[2] as Vector3) - tri[0]).normalized()
			if n.dot((tri[0] as Vector3) - at) < 0.0:
				n = -n
				tri = [tri[0], tri[2], tri[1]]
			st.set_normal(n)
			for k: int in [0, 2, 1]:
				st.add_vertex(tri[k])


## The solid under the lid's curve between x0 and x1: two curved end faces, the curve on top and a
## flat bottom on the rim. `inset` shrinks the curve (a core under the slats).
static func _arch(st: SurfaceTool, x0: float, x1: float, arc: Vector2, half: float, rim: float, colour: Color, inset: float) -> void:
	var r := arc.x - inset
	var steps := SLATS * 2
	var pts := []
	for i in steps + 1:
		var phi := -half + half * 2.0 * i / steps
		var y := maxf(rim, arc.y + r * cos(phi))
		pts.append(Vector2(DEPTH * 0.5 + r * sin(phi), y))
	st.set_color(colour)
	var base := Vector2(DEPTH * 0.5, rim)
	for x: float in [x0, x1]:
		var n := Vector3(-1 if x == x0 else 1, 0, 0)
		st.set_normal(n)
		for i in steps:
			var a: Vector2 = pts[i]
			var c: Vector2 = pts[i + 1]
			var tri := [Vector3(x, base.y, base.x), Vector3(x, a.y, a.x), Vector3(x, c.y, c.x)]
			if x == x1:
				tri = [tri[0], tri[2], tri[1]]
			for k in 3:
				var p: Vector3 = tri[k]
				st.set_uv(Vector2(p.z / GRAIN_LENGTH, p.y / GRAIN_ACROSS))
				st.add_vertex(p)
	for i in steps:
		var a: Vector2 = pts[i]
		var c: Vector2 = pts[i + 1]
		var mid := (a + c) * 0.5 - Vector2(DEPTH * 0.5, arc.y)
		var n := Vector3(0, mid.y, mid.x).normalized()
		st.set_normal(n)
		var quad := [Vector3(x0, a.y, a.x), Vector3(x1, a.y, a.x), Vector3(x1, c.y, c.x), Vector3(x0, c.y, c.x)]
		for idx: int in [0, 1, 2, 0, 2, 3]:
			var p: Vector3 = quad[idx]
			st.set_uv(Vector2(p.x / GRAIN_LENGTH, float(i) * 0.3))
			st.add_vertex(p)
