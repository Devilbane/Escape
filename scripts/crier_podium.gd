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
## The NEWS! sign beside it is its own class (see NewsSign); its mouse-over text is shown by
## Game (see TownCrier.sign_under_ray and Game._update_news_tip).

const W := preload("res://scripts/weathered_props.gd")

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
const PAPER := Color(0.94, 0.89, 0.76)

static var _banner_mesh: ArrayMesh


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
	NewsSign.build(root, SIGN_AT)
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


## The banner: the crown's blue cloth with the insignia, woven linen like the barber's tent roof (see
## BarberTent.cloth_material), hanging from the cross bar in a soft wave with a slight sag, uneven side edges
## and a scalloped valance along the hem, with a gold tassel at each scallop and a gold rod on top.
const BANNER_TOP := DECK_H + 2.88
const BANNER_BOTTOM := DECK_H + 1.2
const BANNER_HALF := 0.95
const SCALLOPS := 5.0

static var _banner_mat: StandardMaterial3D


## How far the valance hangs below the hem at `u` (0..1 across the banner): scallops.
static func _valance(u: float) -> float:
	return 0.07 + 0.1 * absf(sin(u * TAU * SCALLOPS * 0.5))


static func banner_mesh() -> ArrayMesh:
	if _banner_mesh != null:
		return _banner_mesh
	var n := FastNoiseLite.new()
	n.seed = 9
	n.frequency = 0.7
	n.fractal_octaves = 3
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var cols := 14
	var rows := 10
	var size := Vector2(BANNER_HALF * 2.0, BANNER_TOP - BANNER_BOTTOM)
	for r in rows:
		for c in cols:
			var corners := []
			for q in [[c, r], [c + 1, r], [c + 1, r + 1], [c, r + 1]]:
				var u := float(q[0]) / cols
				var v := float(q[1]) / rows
				corners.append(_banner_point(u, v, n, size))
			for k in [0, 1, 2, 0, 2, 3]:
				_vertex(st, corners[k][0], corners[k][1], size)
	# The valance: a strip from the hem down, its lower edge in scallops, hanging a little forward.
	var segs := 40
	for i in segs:
		var u0 := float(i) / segs
		var u1 := float(i + 1) / segs
		var h0: Vector3 = _banner_point(u0, 1.0, n, size)[0]
		var h1: Vector3 = _banner_point(u1, 1.0, n, size)[0]
		var l0 := h0 - Vector3(0, _valance(u0) + 0.02 * n.get_noise_1d(u0 * 30.0), -0.012)
		var l1 := h1 - Vector3(0, _valance(u1) + 0.02 * n.get_noise_1d(u1 * 30.0), -0.012)
		for q in [[h0, u0, 0.0], [h1, u1, 0.0], [l1, u1, 1.0], [h0, u0, 0.0], [l1, u1, 1.0], [l0, u0, 1.0]]:
			_vertex(st, q[0], Vector2(q[1], 0.985), size)
	st.generate_normals()
	st.generate_tangents()
	_banner_mesh = st.commit()
	_banner_mesh.surface_set_material(0, banner_material())
	return _banner_mesh


## A point of the cloth at (u, v) (0..1 from the top left) and its texture coordinate.
static func _banner_point(u: float, v: float, n: FastNoiseLite, size: Vector2) -> Array:
	var wave := 0.035 * sin(u * TAU * 1.5) * v
	# The sides are not ruler-straight, and the hem sags between the rod's ends.
	var wander := 0.03 * n.get_noise_2d(v * 6.0, 3.0) * smoothstep(0.0, 0.3, v) * (1.0 if u < 0.5 else -1.0)
	var edge := 0.0
	if u < 0.001 or u > 0.999:
		edge = wander
	var hem := 0.04 * n.get_noise_1d(u * 9.0) * v * v
	var sag := -0.05 * sin(u * PI) * pow(v, 3.0)
	var fold := 0.018 * n.get_noise_2d(u * 5.0 + 4.0, v * 5.0) * v
	var p := Vector3(lerpf(-BANNER_HALF, BANNER_HALF, u) + edge, lerpf(BANNER_TOP, BANNER_BOTTOM, v) + hem + sag, wave + fold)
	return [p, Vector2(u, v)]


static func _vertex(st: SurfaceTool, p: Vector3, uv: Vector2, size: Vector2) -> void:
	st.set_uv(uv)
	# The weave's coordinates are metres on the cloth, one tile a metre like the tent's linen.
	st.set_uv2(Vector2(uv.x * size.x, uv.y * size.y))
	st.add_vertex(p)


## The insignia cloth with the barber's linen weave over it (a detail layer by metres) and its slubs as relief.
static func banner_material() -> StandardMaterial3D:
	if _banner_mat != null:
		return _banner_mat
	var m := BarberTent.cloth_material().duplicate() as StandardMaterial3D
	m.albedo_texture = CrownInsignia.cloth()
	m.albedo_color = Color.WHITE
	m.uv1_scale = Vector3.ONE
	m.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
	m.normal_scale = 0.6
	_banner_mat = m
	return m


## The tassels at the scallops' tips and the rod along the banner's top edge, in the banner's space.
static func _fringe(banner: Node3D) -> void:
	var fringe := W.Builder.new()
	var segs := int(SCALLOPS) * 2
	for i in segs:
		var u := (float(i) + 0.5) / segs
		var x := lerpf(-BANNER_HALF, BANNER_HALF, u)
		var y := BANNER_BOTTOM - _valance(u) - 0.01
		fringe.cylinder(Vector3(x, y - 0.1, 0.0), 0.012, 0.026, 0.1, BRASS * 0.9, W.FRESH, 6)
	fringe.bar(Vector3(-BANNER_HALF - 0.03, BANNER_TOP, 0.0), Vector3(BANNER_HALF + 0.03, BANNER_TOP, 0.0), 0.028, BRASS, W.FRESH, 8)
	fringe.finish(banner, Vector3.ZERO)
