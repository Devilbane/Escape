class_name CrierPodium
extends RefCounted
## The town crier's podium on the square and the NEWS! sign beside it, built from timber, brass and cloth.
##
## The podium (local space: the ground at y 0, the crowd to the south at +z, the steps on the east side at +x):
## a plank deck on four posts with board skirts, two steps up, a railing with turned balusters on the
## three other sides, a lectern with a sloped desk, a scroll and a brass bell, and behind it two tall posts
## with a cross bar and a blue banner with the crown's insignia (see CrownInsignia). The wood is weathered
## by the village's prop shader like everything else built from timber (see WeatheredProps).
##
## The sign: two posts, a small roof and a blue board in a brass frame that says NEWS! in gold letters
## beside the crown's insignia, the times of the news under it. Its mouse-over text is shown by
## Game (see TownCrier.sign_under_ray and Game._update_news_tip).

const W := preload("res://scripts/weathered_props.gd")
const FONT := preload("res://assets/fonts/Cinzel-Bold.woff2")

## The deck's height and its half sizes (x, z).
const DECK_H := 0.66
const HALF_X := 1.3
const HALF_Z := 1.0
## Where the herald stands to climb the steps and where he stands to speak, in the podium's space.
const STEP_FOOT := Vector3(2.7, 0.0, 0.0)
const STAND := Vector3(0.1, DECK_H, -0.12)
## The footprint that blocks the way (x, z full sizes) and its height, and where the sign stands from the podium.
const BLOCK := Vector2(2.7, 2.1)
const SIGN_AT := Vector3(-3.3, 0.0, 0.5)
## The sign's footprint and the centre of the board over the ground (for the mouse-over, see TownCrier).
const SIGN_BLOCK := Vector2(2.1, 0.4)
const BOARD_CENTRE := Vector3(0, 1.75, 0)

const BRASS := Color(0.95, 0.74, 0.28)
const BLUE_PAINT := Color(0.2, 0.34, 0.8)
const PAPER := Color(0.94, 0.89, 0.76)

static var _banner_mesh: ArrayMesh
static var _plaque_mesh: ArrayMesh


## Builds the podium and the sign at `pos` (the podium's middle on the ground). Returns the root.
static func build(parent: Node3D, pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "CrierPodium"
	root.position = pos
	parent.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("crier:%d:%d" % [roundi(pos.x), roundi(pos.z)])
	var b := W.Builder.new()
	_deck(b, rng)
	_steps(b, rng)
	_railing(b, rng)
	_posts_and_bar(b, rng)
	_lectern(b, rng)
	b.finish(root, Vector3.ZERO)
	var banner := MeshInstance3D.new()
	banner.name = "Banner"
	banner.mesh = banner_mesh()
	banner.position = Vector3(0, 0, -HALF_Z + 0.16)
	root.add_child(banner)
	_fringe(banner)
	_scroll(root)
	build_sign(root, SIGN_AT)
	return root


static func _wood(rng: RandomNumberGenerator, dark := false) -> Color:
	return W.vary(W.DARK_TIMBER if dark else W.TIMBER[rng.randi() % W.TIMBER.size()], rng, 0.09)


## The deck: four posts, frame beams, planks along z with their own shades, and skirt boards below.
static func _deck(b: W.Builder, rng: RandomNumberGenerator) -> void:
	for x in [-HALF_X + 0.1, HALF_X - 0.1]:
		for z in [-HALF_Z + 0.1, HALF_Z - 0.1]:
			b.box(Vector3(x, 0, z), Vector3(0.2, DECK_H - 0.06, 0.2), _wood(rng, true), W.WOOD, Basis.from_euler(Vector3(0, rng.randf_range(-0.04, 0.04), 0)))
	for z in [-HALF_Z + 0.1, HALF_Z - 0.1]:
		b.box(Vector3(0, DECK_H - 0.24, z), Vector3(HALF_X * 2.0, 0.16, 0.12), _wood(rng, true), W.WOOD)
	for x in [-HALF_X + 0.1, HALF_X - 0.1]:
		b.box(Vector3(x, DECK_H - 0.24, 0), Vector3(0.12, 0.16, HALF_Z * 2.0 - 0.2), _wood(rng, true), W.WOOD)
	# Planks across the whole deck, a few nails' worth of unevenness between them.
	var count := 11
	var width := HALF_X * 2.0 / count
	for i in count:
		var x := -HALF_X + width * (i + 0.5)
		b.box(Vector3(x, DECK_H - 0.06 + rng.randf_range(-0.006, 0.006), rng.randf_range(-0.02, 0.02)),
				Vector3(width - 0.014, 0.06, HALF_Z * 2.0 + rng.randf_range(-0.04, 0.0)), _wood(rng),
				W.WOOD, Basis.from_euler(Vector3(0, rng.randf_range(-0.01, 0.01), 0)))
	# The skirt: upright boards on the south, west and north faces.
	for face in [[Vector3(0, 0, HALF_Z - 0.02), true], [Vector3(0, 0, -HALF_Z + 0.02), true], [Vector3(-HALF_X + 0.02, 0, 0), false]]:
		var along_x: bool = face[1]
		var n := 11 if along_x else 9
		var span := (HALF_X * 2.0 - 0.2) if along_x else (HALF_Z * 2.0 - 0.2)
		var w := span / n
		for i in n:
			var s := -span * 0.5 + w * (i + 0.5)
			var h := DECK_H - 0.3 + rng.randf_range(-0.03, 0.03)
			var foot: Vector3 = face[0] + (Vector3(s, 0, 0) if along_x else Vector3(0, 0, s))
			var size := Vector3(w - 0.012, h, 0.04) if along_x else Vector3(0.04, h, w - 0.012)
			b.box(foot + Vector3(0, 0.06, 0), size, _wood(rng), W.WOOD)


## Two steps up on the east side, each a block of timber with a plank tread that overhangs a little, side
## boards, and a brass-capped nosing.
static func _steps(b: W.Builder, rng: RandomNumberGenerator) -> void:
	for i in 2:
		var h := 0.22 * float(i + 1)
		var x := HALF_X + 0.24 + 0.46 * float(1 - i)
		b.box(Vector3(x, 0, 0), Vector3(0.46, h - 0.05, 1.3), _wood(rng, true), W.WOOD)
		for k in 3:
			b.box(Vector3(x - 0.01, h - 0.05, -0.43 + 0.43 * k), Vector3(0.5, 0.05, 0.42), _wood(rng), W.WOOD,
					Basis.from_euler(Vector3(0, rng.randf_range(-0.01, 0.01), 0)))
		b.box(Vector3(x + 0.245, h - 0.045, 0), Vector3(0.02, 0.035, 1.3), BRASS * 0.9, W.FRESH)
	# The stringers either side, with the iron straps that hold them.
	for z in [-0.68, 0.68]:
		b.box(Vector3(HALF_X + 0.7, 0, z), Vector3(1.0, 0.1, 0.06), _wood(rng, true), W.WOOD)
		b.box(Vector3(HALF_X + 0.7, 0.1, z), Vector3(0.9, 0.1, 0.05), _wood(rng, true), W.WOOD, Basis.from_euler(Vector3(0, 0, 0.0)))


## The railing on the south, west and north sides and the short pieces on each side of the steps.
static func _railing(b: W.Builder, rng: RandomNumberGenerator) -> void:
	var top := DECK_H + 0.92
	var runs := [
		[Vector3(-HALF_X + 0.1, DECK_H, HALF_Z - 0.1), Vector3(HALF_X - 0.1, DECK_H, HALF_Z - 0.1)],
		[Vector3(-HALF_X + 0.1, DECK_H, -HALF_Z + 0.1), Vector3(-HALF_X + 0.1, DECK_H, HALF_Z - 0.1)],
		[Vector3(HALF_X - 0.1, DECK_H, HALF_Z - 0.1), Vector3(HALF_X - 0.1, DECK_H, 0.62)],
		[Vector3(HALF_X - 0.1, DECK_H, -0.62), Vector3(HALF_X - 0.1, DECK_H, -HALF_Z + 0.1)],
	]
	for run in runs:
		var a: Vector3 = run[0]
		var c: Vector3 = run[1]
		b.bar(a + Vector3(0, 0.08, 0), c + Vector3(0, 0.08, 0), 0.035, _wood(rng, true))
		b.bar(Vector3(a.x, top, a.z), Vector3(c.x, top, c.z), 0.05, _wood(rng, true))
		var length := a.distance_to(c)
		var n := maxi(2, int(length / 0.26))
		for i in n + 1:
			var p := a.lerp(c, float(i) / n)
			var post := i == 0 or i == n
			if post:
				b.cylinder(p, 0.065, 0.055, 0.92, _wood(rng, true), W.WOOD, 8)
				b.cylinder(p + Vector3(0, 0.92, 0), 0.07, 0.04, 0.1, _wood(rng), W.WOOD, 8)
				b.cylinder(p + Vector3(0, 1.02, 0), 0.045, 0.0, 0.07, BRASS, W.FRESH, 8)
			else:
				# A turned baluster: a thin neck and a swelling at the middle.
				b.cylinder(p + Vector3(0, 0.1, 0), 0.028, 0.028, 0.74, _wood(rng), W.WOOD, 6)
				b.cylinder(p + Vector3(0, 0.34, 0), 0.04, 0.04, 0.12, _wood(rng), W.WOOD, 6)


## The tall back posts, the cross bar between them and its brass finials.
static func _posts_and_bar(b: W.Builder, rng: RandomNumberGenerator) -> void:
	var height := DECK_H + 3.1
	for x in [-HALF_X + 0.1, HALF_X - 0.1]:
		b.box(Vector3(x, DECK_H, -HALF_Z + 0.1), Vector3(0.17, height - DECK_H, 0.17), _wood(rng, true), W.WOOD)
		b.cylinder(Vector3(x, height, -HALF_Z + 0.1), 0.09, 0.07, 0.06, BRASS, W.FRESH, 10)
		b.cylinder(Vector3(x, height + 0.06, -HALF_Z + 0.1), 0.07, 0.0, 0.2, BRASS, W.FRESH, 10)
		# A diagonal brace at the foot of each.
		b.bar(Vector3(x, DECK_H + 0.2, -HALF_Z + 0.1), Vector3(x * 0.55, DECK_H + 1.0, -HALF_Z + 0.1), 0.04, _wood(rng, true))
	b.bar(Vector3(-HALF_X + 0.1, DECK_H + 2.92, -HALF_Z + 0.1), Vector3(HALF_X - 0.1, DECK_H + 2.92, -HALF_Z + 0.1), 0.055, _wood(rng, true), W.WOOD, 8)
	# A board across the back below the banner, up to the top rail.
	for i in 9:
		var w := (HALF_X * 2.0 - 0.4) / 9.0
		b.box(Vector3(-HALF_X + 0.2 + w * (i + 0.5), DECK_H + 0.08, -HALF_Z + 0.04), Vector3(w - 0.01, 0.84, 0.04), _wood(rng), W.WOOD)


## The lectern: a plinth, a tapering column, a sloped desk with a lip at the speaker's side and brass trim.
static func _lectern(b: W.Builder, rng: RandomNumberGenerator) -> void:
	var at := Vector3(0, DECK_H, 0.52)
	b.box(at, Vector3(0.74, 0.1, 0.52), _wood(rng, true), W.WOOD)
	b.frustum(at + Vector3(0, 0.1, 0), Vector2(0.52, 0.34), Vector2(0.4, 0.28), 0.72, _wood(rng), W.WOOD)
	# Raised panels on the column's front and sides.
	b.box(at + Vector3(0, 0.22, 0.17), Vector3(0.3, 0.42, 0.02), _wood(rng, true), W.WOOD)
	var tilt := Basis(Vector3.RIGHT, -0.42)
	var desk := at + Vector3(0, 0.84, 0)
	b.box(desk, Vector3(0.98, 0.06, 0.62), _wood(rng), W.WOOD, tilt)
	# The lip on the speaker's side and the brass edging round the desk.
	b.box(desk + tilt * Vector3(0, 0.05, -0.3), Vector3(0.98, 0.07, 0.05), _wood(rng, true), W.WOOD, tilt)
	b.box(desk + tilt * Vector3(0, 0.06, 0.31), Vector3(1.0, 0.03, 0.025), BRASS, W.FRESH, tilt)
	for x in [-0.5, 0.5]:
		b.box(desk + tilt * Vector3(x, 0.06, 0), Vector3(0.025, 0.03, 0.62), BRASS, W.FRESH, tilt)
	# The brass hand bell on the desk's right corner.
	var bell := desk + tilt * Vector3(0.34, 0.06, 0.12)
	b.cylinder(bell, 0.08, 0.035, 0.1, BRASS, W.FRESH, 12)
	b.cylinder(bell + Vector3(0, 0.1, 0), 0.03, 0.02, 0.06, _wood(rng, true), W.WOOD, 8)
	b.cylinder(bell + Vector3(0, 0.15, 0), 0.02, 0.0, 0.03, BRASS, W.FRESH, 8)


## The scroll lying open on the desk, with a red seal.
static func _scroll(root: Node3D) -> void:
	var paper := StandardMaterial3D.new()
	paper.albedo_color = PAPER
	paper.roughness = 1.0
	paper.albedo_texture = _paper_texture()
	var seal := StandardMaterial3D.new()
	seal.albedo_color = Color(0.7, 0.1, 0.1)
	seal.roughness = 0.5
	var tilt := Basis(Vector3.RIGHT, -0.42)
	var desk := Vector3(0, DECK_H + 0.84, 0.52)
	var sheet := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(0.5, 0.008, 0.36)
	sheet.mesh = plane
	sheet.material_override = paper
	sheet.transform = Transform3D(tilt, desk + tilt * Vector3(-0.12, 0.071, 0.0))
	root.add_child(sheet)
	for end in [-1.0, 1.0]:
		var roll := MeshInstance3D.new()
		var tube := CylinderMesh.new()
		tube.top_radius = 0.028
		tube.bottom_radius = 0.028
		tube.height = 0.38
		roll.mesh = tube
		roll.material_override = paper
		roll.transform = Transform3D(tilt * Basis(Vector3(0, 0, 1), PI * 0.5), desk + tilt * Vector3(-0.12, 0.08, 0.17 * end))
		root.add_child(roll)
	var wax := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.035
	disc.bottom_radius = 0.04
	disc.height = 0.012
	wax.mesh = disc
	wax.material_override = seal
	wax.transform = Transform3D(tilt, desk + tilt * Vector3(0.05, 0.08, -0.12))
	root.add_child(wax)


static func _paper_texture() -> ImageTexture:
	var size := 64
	var img := Image.create(size, size, true, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 12
	noise.frequency = 0.12
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	for y in size:
		for x in size:
			var v := 0.88 + noise.get_noise_2d(x, y) * 0.08
			img.set_pixel(x, y, Color(v, v * 0.97, v * 0.9, 1.0))
	# Lines of ink: short dark strokes in rows.
	for row in 9:
		var y := 8 + row * 5
		var x := 6
		while x < size - 8:
			var word := rng.randi_range(3, 9)
			for k in word:
				img.set_pixel(x + k, y, Color(0.22, 0.17, 0.12))
			x += word + 3
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## The banner: blue cloth with the insignia, hanging from the cross bar in a soft wave, with a gold fringe
## along the bottom edge and a gold rod on top.
static func banner_mesh() -> ArrayMesh:
	if _banner_mesh != null:
		return _banner_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var top := DECK_H + 2.88
	var bottom := DECK_H + 1.2
	var half := 0.95
	var cols := 10
	var rows := 8
	for r in rows:
		for c in cols:
			var corners := []
			for q in [[c, r], [c + 1, r], [c + 1, r + 1], [c, r + 1]]:
				var u := float(q[0]) / cols
				var v := float(q[1]) / rows
				var wave := 0.035 * sin(u * TAU * 1.5) * v
				corners.append([Vector3(lerpf(-half, half, u), lerpf(top, bottom, v), wave), Vector2(u, v)])
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_uv(corners[k][1])
				st.add_vertex(corners[k][0])
	st.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = CrownInsignia.cloth()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(mat)
	_banner_mesh = st.commit()
	return _banner_mesh


## The fringe along the banner's bottom edge and the rod along its top, in the banner's space.
static func _fringe(banner: Node3D) -> void:
	var top := DECK_H + 2.88
	var bottom := DECK_H + 1.2
	var half := 0.95
	var fringe := W.Builder.new()
	var x := -half + 0.06
	while x < half:
		fringe.cylinder(Vector3(x, bottom - 0.14, 0.0), 0.012, 0.022, 0.14, BRASS * 0.9, W.FRESH, 5)
		x += 0.12
	fringe.bar(Vector3(-half - 0.03, top, 0.0), Vector3(half + 0.03, top, 0.0), 0.028, BRASS, W.FRESH, 8)
	fringe.finish(banner, Vector3.ZERO)


## The NEWS! sign, standing on the ground at `at` (in the podium's space), the board facing +z.
static func build_sign(parent: Node3D, at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "NewsSign"
	root.position = at
	parent.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var b := W.Builder.new()
	var half := 1.0
	# Two posts with a small base block each, a cross beam and a little gabled roof of shingles.
	for x in [-half, half]:
		b.box(Vector3(x, 0, 0), Vector3(0.3, 0.2, 0.3), W.STONES[1], W.STONE)
		b.box(Vector3(x, 0.2, 0), Vector3(0.16, 2.5, 0.16), _wood(rng, true), W.WOOD, Basis.from_euler(Vector3(0, rng.randf_range(-0.05, 0.05), 0)))
		b.cylinder(Vector3(x, 2.7, 0), 0.07, 0.0, 0.16, BRASS, W.FRESH, 8)
	b.box(Vector3(0, 2.4, 0), Vector3(half * 2.0 + 0.3, 0.12, 0.2), _wood(rng, true), W.WOOD)
	for side in [-1.0, 1.0]:
		var roof := Basis(Vector3.RIGHT, side * 0.5)
		for i in 7:
			var x := -half - 0.1 + (half * 2.0 + 0.2) / 6.0 * i
			b.box(Vector3(x, 2.55, side * 0.16), Vector3(0.3, 0.04, 0.4), _wood(rng, side > 0.0), W.WOOD, roof)
	# The board: dark blue paint over timber, a brass frame, and two chains from the beam.
	b.box(Vector3(0, 1.34, -0.04), Vector3(1.8, 0.92, 0.1), BLUE_PAINT, W.WOOD)
	for e in [[Vector3(0, 2.26, 0.02), Vector3(1.88, 0.06, 0.06)], [Vector3(0, 1.3, 0.02), Vector3(1.88, 0.06, 0.06)]]:
		b.box(e[0] - Vector3(0, 0.0, 0.0), e[1], BRASS, W.FRESH)
	for x in [-0.91, 0.91]:
		b.box(Vector3(x, 1.3, 0.02), Vector3(0.06, 0.96, 0.06), BRASS, W.FRESH)
	for x in [-0.8, 0.8]:
		for i in 5:
			b.cylinder(Vector3(x, 2.28 + 0.0 - 0.0, 0.0) - Vector3(0, 0.1 * i, 0), 0.016, 0.016, 0.09, W.IRON_COLOUR * 0.7, W.IRON, 5)
	b.finish(root, Vector3.ZERO)
	var plaque := MeshInstance3D.new()
	plaque.name = "Plaque"
	plaque.mesh = plaque_mesh()
	plaque.position = Vector3(-0.62, 1.78, 0.02)
	root.add_child(plaque)
	root.add_child(_letters("NEWS!", 92, Vector3(0.22, 1.72, 0.055), 0.0042, Color(0.98, 0.8, 0.34)))
	root.add_child(_letters(Lang.t("10 und 16 Uhr"), 38, Vector3(0.22, 1.45, 0.055), 0.0042, Color(0.9, 0.88, 0.78)))
	return root


## The insignia on a small square plaque with a brass rim, on the board's left.
static func plaque_mesh() -> ArrayMesh:
	if _plaque_mesh != null:
		return _plaque_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s := 0.34
	var pts := [Vector3(-s, -s, 0), Vector3(s, -s, 0), Vector3(s, s, 0), Vector3(-s, s, 0)]
	var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	for k in [0, 1, 2, 0, 2, 3]:
		st.set_uv(uvs[k])
		st.set_normal(Vector3(0, 0, 1))
		st.add_vertex(pts[k])
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = CrownInsignia.cloth()
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(mat)
	_plaque_mesh = st.commit()
	return _plaque_mesh


static func _letters(text: String, size: int, at: Vector3, pixel: float, colour: Color) -> Label3D:
	var label := Label3D.new()
	label.name = "Letters"
	label.text = text
	label.font = FONT
	label.font_size = size
	label.pixel_size = pixel
	label.modulate = colour
	label.outline_size = 10
	label.outline_modulate = Color(0.04, 0.05, 0.16)
	label.shaded = false
	label.double_sided = false
	label.position = at
	return label
