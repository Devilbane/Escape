class_name WallSpots
extends RefCounted
## The special spots on the climbing wall (markers of WallMap.MARKERS), built as small 3D scenes that stand on the face
## of the rock, in local coordinates: the origin is the middle of the square on the face, +x to the right, +y up and +z out
## of the wall.
## - "tar": a dark crack with mountain tar (a shilajit-like resin) seeping from it, running down in thick glossy streaks
##   and hanging in drops; the climber scrapes some off (ingredient "bergteer").
## - "edelweiss": a tuft of edelweiss on a small ledge stone, woolly white star flowers with yellow hearts over silvery
##   leaves (ingredient "edelweiss").
## - "door": an old timber door with iron bands in a rough stone arch, with rubble at its foot; it leads into a dungeon or
##   a mine (the wall's `door`, see WallPlacements.door_of).
## Textures and materials are made in code once and shared.

## What the climber takes from a gathering spot: the ingredient (see Crafting.INGREDIENTS) and how many.
const GATHER := {
	"tar": {"id": "bergteer", "count": 1},
	"edelweiss": {"id": "edelweiss", "count": 2},
}

static var _mats := {}


## The 3D scene of a spot of this kind, or null for a kind that has none (the signs are drawn by WallStage).
static func build(kind: String, seed_value: int) -> Node3D:
	var node: Node3D = null
	match kind:
		"tar":
			node = _tar(seed_value)
			node.scale = Vector3.ONE * 1.7
		"edelweiss":
			node = _edelweiss(seed_value)
			node.scale = Vector3.ONE * 1.8
		"door":
			node = _door(seed_value)
	return node


## Where a spot stands from the middle of its square (m): the tar beside the hold, the edelweiss on a ledge at its side, so
## the climber reaches out for them and the stones of the hold do not hide them.
static func offset(kind: String) -> Vector3:
	match kind:
		"tar":
			return Vector3(0.6, 0.3, 0.0)
		"edelweiss":
			return Vector3(-0.6, 0.15, 0.0)
	return Vector3.ZERO


# --- Materials and textures ------------------------------------------------------------------------

static func _noise_image(size: int, freq: Vector2, seed_value: int, dark: Color, light: Color) -> Image:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = 1.0
	var fine := FastNoiseLite.new()
	fine.seed = seed_value + 7
	fine.frequency = 1.0
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var v := 0.5 + n.get_noise_2d(x * freq.x, y * freq.y) * 0.9 + fine.get_noise_2d(x * 0.9, y * 0.9) * 0.15
			img.set_pixel(x, y, dark.lerp(light, clampf(v, 0.0, 1.0)))
	return img


static func _mat(id: String) -> StandardMaterial3D:
	if _mats.has(id):
		return _mats[id]
	var m := StandardMaterial3D.new()
	match id:
		"tar":
			# Mountain tar: nearly black with a deep amber-brown glow where light passes through, and a wet gloss.
			m.albedo_color = Color(0.1, 0.06, 0.03)
			m.roughness = 0.12
			m.metallic = 0.2
			m.clearcoat_enabled = true
			m.clearcoat = 1.0
			m.clearcoat_roughness = 0.05
			m.rim_enabled = true
			m.rim = 0.8
			m.rim_tint = 0.6
			m.emission_enabled = true
			m.emission = Color(0.5, 0.24, 0.05)
			m.emission_energy_multiplier = 0.3
		"crack":
			m.albedo_color = Color(0.02, 0.018, 0.018)
			m.roughness = 1.0
		"wood":
			m.albedo_texture = ImageTexture.create_from_image(_noise_image(128, Vector2(0.03, 0.9), 11, Color(0.17, 0.1, 0.05), Color(0.4, 0.26, 0.13)))
			m.roughness = 0.9
		"iron":
			m.albedo_color = Color(0.13, 0.13, 0.15)
			m.metallic = 0.7
			m.roughness = 0.55
		"stone":
			m.albedo_texture = ImageTexture.create_from_image(_noise_image(128, Vector2(0.09, 0.09), 31, Color(0.3, 0.29, 0.28), Color(0.55, 0.53, 0.5)))
			m.roughness = 1.0
		"leaf":
			m.albedo_texture = ImageTexture.create_from_image(_noise_image(64, Vector2(0.2, 0.2), 5, Color(0.36, 0.42, 0.33), Color(0.7, 0.76, 0.66)))
			m.roughness = 1.0
		"flower":
			m.albedo_texture = _flower_texture()
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.4
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.roughness = 1.0
			m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			m.emission_enabled = true
			m.emission = Color(0.12, 0.13, 0.14)
		"heart":
			m.albedo_color = Color(0.95, 0.78, 0.2)
			m.roughness = 0.9
	_mats[id] = m
	return m


## The star of an edelweiss: woolly white bracts round a yellow heart, soft at the edges (alpha cut at 0.4).
static func _flower_texture() -> ImageTexture:
	var size := 128
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var fuzz := FastNoiseLite.new()
	fuzz.seed = 3
	for y in size:
		for x in size:
			var p := Vector2(x - size * 0.5, y - size * 0.5) / (size * 0.5)
			var a := atan2(p.y, p.x)
			var d := p.length()
			# Seven pointed bracts, each a little different, with a felty rough edge.
			var reach := 0.62 + 0.3 * pow(absf(cos(a * 3.5)), 2.5) + fuzz.get_noise_2d(x * 2.0, y * 2.0) * 0.08
			var col := Color(0.0, 0.0, 0.0, 0.0)
			if d < reach:
				var shade := 0.82 + 0.18 * (1.0 - d / reach) + fuzz.get_noise_2d(x * 3.0 + 40.0, y * 3.0) * 0.1
				col = Color(0.93 * shade, 0.95 * shade, 0.96 * shade, 1.0)
			if d < 0.17:
				col = Color(0.95, 0.8, 0.25, 1.0).lerp(Color(0.7, 0.5, 0.12, 1.0), d / 0.17)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


# --- The pieces -------------------------------------------------------------------------------------

static func _part(parent: Node3D, mesh: Mesh, material: Material, at: Vector3, rot := Vector3.ZERO, scale := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = at
	mi.rotation = rot
	mi.scale = scale
	parent.add_child(mi)
	return mi


static func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 14
	s.rings = 8
	return s


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


## Mountain tar seeping out of a crack.
static func _tar(seed_value: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Tar"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var tar := _mat("tar")
	# The crack: a ragged dark slit, a few jagged pieces leaning against each other.
	var y := 0.55
	var x := -0.04
	for i in 5:
		var h := rng.randf_range(0.22, 0.34)
		_part(root, _box(Vector3(rng.randf_range(0.07, 0.12), h, 0.05)), _mat("crack"), Vector3(x, y - h * 0.5, 0.02), Vector3(0, 0, rng.randf_range(-0.35, 0.35)))
		y -= h * 0.9
		x += rng.randf_range(-0.07, 0.07)
	# The resin: a flat, glossy spill hugging the rock at the mouth of the crack (several overlapping lobes, wider than
	# high), runs that taper down the face as they thin out, and a heavy drop hanging at the end of each.
	for i in 5:
		var lobe := _part(root, _sphere(rng.randf_range(0.1, 0.17)), tar, Vector3(rng.randf_range(-0.16, 0.16), rng.randf_range(-0.02, 0.2), 0.03), Vector3(0, 0, rng.randf_range(-0.6, 0.6)), Vector3(rng.randf_range(1.3, 2.0), rng.randf_range(0.7, 1.0), 0.22))
		lobe.name = "Lobe%d" % i
	for i in 3:
		var run_x := rng.randf_range(-0.2, 0.2)
		var length := rng.randf_range(0.55, 1.0)
		var width := rng.randf_range(0.05, 0.085)
		var top := rng.randf_range(-0.02, 0.1)
		_part(root, _drip_mesh(length, width), tar, Vector3(run_x, top, 0.03), Vector3.ZERO, Vector3(1.0, 1.0, 0.4))
	# Old dried crust round the mouth: grey and brown crumbs.
	for i in 7:
		_part(root, _sphere(rng.randf_range(0.025, 0.05)), _mat("stone"), Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.1, 0.35), 0.03), Vector3.ZERO, Vector3(1, 0.8, 0.6))
	return root


## A tuft of edelweiss on a ledge.
static func _edelweiss(seed_value: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Edelweiss"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# The ledge: a rough stone jutting out under the flowers (the same stone as the wall's own).
	var ledge := NaturalRock.mesh("rock_single_E")
	if ledge != null:
		_part(root, ledge, AgedStone.rock_material(), Vector3(0, -0.28, 0.0), Vector3(deg_to_rad(90.0), rng.randf_range(-0.3, 0.3), 0.0), Vector3(2.2, 1.6, 1.5))
	# A cushion of silvery leaves, and the flowers on short furry stems.
	for i in 9:
		var blade := CapsuleMesh.new()
		blade.radius = 0.012
		blade.height = rng.randf_range(0.12, 0.2)
		_part(root, blade, _mat("leaf"), Vector3(rng.randf_range(-0.2, 0.2), -0.16 + blade.height * 0.4, rng.randf_range(0.06, 0.16)), Vector3(rng.randf_range(-0.5, 0.2), 0, rng.randf_range(-0.7, 0.7)))
	for i in 6:
		var fx := rng.randf_range(-0.2, 0.2)
		var fy := rng.randf_range(-0.05, 0.12)
		var fz := 0.12 + rng.randf_range(0.0, 0.12)
		var stem := CylinderMesh.new()
		stem.top_radius = 0.008
		stem.bottom_radius = 0.012
		stem.height = fy + 0.2
		_part(root, stem, _mat("leaf"), Vector3(fx * 0.7, -0.18 + stem.height * 0.5, fz * 0.7), Vector3(rng.randf_range(0.1, 0.5), 0, -fx))
		# The flower: a star facing the viewer, tilted a little, with a bump for its heart.
		var size := rng.randf_range(0.16, 0.24)
		var quad := QuadMesh.new()
		quad.size = Vector2(size, size)
		_part(root, quad, _mat("flower"), Vector3(fx, fy, fz), Vector3(rng.randf_range(-0.25, 0.1), rng.randf_range(-0.3, 0.3), rng.randf_range(0.0, TAU)))
		_part(root, _sphere(size * 0.1), _mat("heart"), Vector3(fx, fy, fz + 0.012))
	return root


## One smooth stream of tar hanging down from y = 0: thick at the top, thinning to a thread, with a heavy round drop at
## its end (a tube swept along -y with a radius that follows that profile). `length` is its whole length.
static func _drip_mesh(length: float, width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 28
	var sides := 12
	var grid: Array = []
	for i in rings + 1:
		var t := float(i) / rings
		var r := width * lerpf(1.0, 0.3, minf(1.0, t / 0.85))
		if t > 0.86:
			# The drop: swells to a ball and closes at the tip.
			var u := (t - 0.86) / 0.14
			r = lerpf(width * 0.3, width * 1.25, sin(minf(1.0, u * 1.6) * PI * 0.5)) * sqrt(maxf(0.0, 1.0 - pow(maxf(0.0, u - 0.55) / 0.45, 2.0)))
		var row := []
		for j in sides:
			var a := TAU * j / sides
			row.append(Vector3(cos(a) * r, -t * length, sin(a) * r))
		grid.append(row)
	for i in rings:
		for j in sides:
			var j2 := (j + 1) % sides
			var p00: Vector3 = grid[i][j]
			var p01: Vector3 = grid[i][j2]
			var p10: Vector3 = grid[i + 1][j]
			var p11: Vector3 = grid[i + 1][j2]
			for v in [p00, p10, p01, p01, p10, p11]:
				st.add_vertex(v)
	st.generate_normals()
	return st.commit()


## An old timber door with iron bands, in a rough stone arch, rubble at its foot.
static func _door(seed_value: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Door"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var wood := _mat("wood")
	var iron := _mat("iron")
	var stone := _mat("stone")
	var w := 1.1   # door width
	var h := 1.9   # to the springing of the arch
	# A dark recess behind the door, so the arch reads as a doorway into the rock.
	_part(root, _box(Vector3(w + 0.3, h + 0.55, 0.12)), _mat("crack"), Vector3(0, h * 0.5 - 0.2, 0.0))
	# Planks, side by side, each slightly different in height and shade (the wood texture is shared, offset by the plank).
	var planks := 6
	for i in planks:
		var px := -w * 0.5 + (i + 0.5) * w / planks
		var ph := h + rng.randf_range(-0.06, 0.02)
		_part(root, _box(Vector3(w / planks - 0.012, ph, 0.07)), wood, Vector3(px, ph * 0.5 - 0.2, 0.08 + rng.randf_range(-0.005, 0.01)))
	# The arch over it: a half ring of wedge stones, and the plank-ends cut round by the lintel.
	var arch_r := w * 0.5 + 0.12
	for i in 9:
		var a := PI * (i + 0.5) / 9.0
		var block := _box(Vector3(0.26, 0.3, 0.2 + rng.randf_range(0.0, 0.06)))
		_part(root, block, stone, Vector3(cos(a) * arch_r, h - 0.2 + sin(a) * arch_r, 0.1), Vector3(0, 0, a - PI * 0.5 + 0.0))
	for sx in [-1, 1]:
		# Jamb stones on both sides.
		for j in 4:
			_part(root, _box(Vector3(0.24 + rng.randf_range(0.0, 0.06), 0.46, 0.2)), stone, Vector3(sx * arch_r, -0.2 + 0.23 + j * 0.47, 0.1 + rng.randf_range(0.0, 0.03)), Vector3(0, 0, rng.randf_range(-0.03, 0.03)))
	# Iron bands and nails, a ring to pull it open.
	for by in [0.25, 1.15]:
		_part(root, _box(Vector3(w, 0.1, 0.02)), iron, Vector3(0, by - 0.2, 0.12))
		for i in 5:
			_part(root, _sphere(0.02), iron, Vector3(-w * 0.45 + i * w * 0.225, by - 0.2, 0.135))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.045
	ring.outer_radius = 0.06
	_part(root, ring, iron, Vector3(w * 0.22, 0.45, 0.14), Vector3(PI * 0.5, 0, 0))
	# A little rubble before it, fallen from the rock above.
	for i in 6:
		var rock := NaturalRock.mesh("rock_single_A" if i % 2 == 0 else "rock_single_C")
		if rock != null:
			_part(root, rock, AgedStone.rock_material(), Vector3(rng.randf_range(-0.8, 0.8), -0.45 + rng.randf_range(0.0, 0.12), 0.22 + rng.randf_range(0.0, 0.2)), Vector3(deg_to_rad(90.0), rng.randf() * TAU, 0.0), Vector3.ONE * rng.randf_range(0.7, 1.4))
	return root
