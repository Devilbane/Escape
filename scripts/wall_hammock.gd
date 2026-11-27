class_name WallHammock
extends RefCounted
## The hanging rest on the climbing wall: two iron pitons hammered into the rock and a woven hammock slung
## between them. WallStage hammers the pitons one after the other (`piton`), hangs the cloth (`cloth`) and lets
## the climber lie in it.

const SPAN := 2.0      ## distance between the two pitons
const SAG := 1.15      ## how far the cloth hangs below the pitons
const WIDTH := 1.4


## One iron piton: a tapered, rusty spike with an eye ring at its end, pointing out of the rock.
static func piton(side: int) -> Node3D:
	var root := Node3D.new()
	var iron := _iron()
	var spike := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.035
	cone.bottom_radius = 0.012
	cone.height = 0.26
	cone.radial_segments = 8
	spike.mesh = cone
	spike.rotation_degrees = Vector3(90, 0, 0)
	spike.material_override = iron
	root.add_child(spike)
	var eye := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.045
	ring.outer_radius = 0.075
	eye.mesh = ring
	eye.rotation_degrees = Vector3(90, 0, 0)
	eye.position = Vector3(0, 0, 0.15)
	eye.material_override = iron
	root.add_child(eye)
	root.name = "Piton%d" % side
	root.scale = Vector3.ONE * 2.2
	return root


## The hammock: a woven strip that sags between the two pitons, with a rope from each end to its piton.
## It is built from x = -SPAN/2 to +SPAN/2 around its own origin (the middle of the pitons).
static func cloth() -> Node3D:
	var root := Node3D.new()
	root.name = "Hammock"
	var steps := 18
	var across := 4
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var half := SPAN * 0.5 - 0.22
	# A horizontal cradle: it sags between the pitons along x and its two edges (in front and behind the sleeper) rise.
	for i in steps + 1:
		var t := float(i) / steps
		var x := lerpf(-half, half, t)
		var y := -SAG * (1.0 - pow(2.0 * t - 1.0, 2.0))
		for k in across + 1:
			var sd := lerpf(-1.0, 1.0, float(k) / across)
			verts.append(Vector3(x, y + 0.38 * sd * sd * sin(t * PI), sd * WIDTH * 0.5 * sin(t * PI * 0.5 + PI * 0.25)))
			uvs.append(Vector2(t * 6.0, float(k) / across))
		if i < steps:
			for k in across:
				var a := i * (across + 1) + k
				var b := a + across + 1
				idx.append_array([a, b, a + 1, a + 1, b, b + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var sheet := MeshInstance3D.new()
	sheet.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _weave()
	mat.albedo_color = Color(1.0, 0.62, 0.48)   # a red-dyed weave, so the hammock reads against the grey rock
	mat.roughness = 0.95
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	sheet.material_override = mat
	root.add_child(sheet)
	# The two ropes from the cloth's ends up to the pitons' eyes.
	for sgn in [-1.0, 1.0]:
		var rope := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.02
		cyl.bottom_radius = 0.02
		cyl.height = 1.0
		cyl.radial_segments = 6
		rope.mesh = cyl
		var a := Vector3(sgn * half, 0.0, 0.0)
		var b := Vector3(sgn * SPAN * 0.5, 0.0, 0.0)
		rope.position = (a + b) * 0.5
		var along := (b - a)
		rope.basis = Basis(Vector3.BACK, PI * 0.5).scaled_local(Vector3(1, along.length(), 1))
		var rm := StandardMaterial3D.new()
		rm.albedo_color = Color(0.62, 0.5, 0.3)
		rm.roughness = 0.95
		rope.material_override = rm
		root.add_child(rope)
	return root


## The sleeping bag the climber lies in, zipped up to the chin: a quilted, tapered (mummy) bag lying along x from the
## feet (x = -1.0) to the shoulders (x = +0.5), where a fur-lined collar leaves only the head with the helmet out.
## Its origin is the middle of the sleeper's spine, so put it at the climber's `from` + (0, 0.67, 0.1).
static func wrap() -> Node3D:
	var root := Node3D.new()
	root.name = "Wrap"
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _quilt()
	mat.uv1_scale = Vector3(4.0, 3.0, 1.0)
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var bag := MeshInstance3D.new()
	bag.name = "Bag"
	bag.mesh = _bag_mesh()
	bag.material_override = mat
	root.add_child(bag)
	# The zip along the top of the bag, with its pull at the neck.
	var zip_mat := StandardMaterial3D.new()
	zip_mat.albedo_color = Color(0.78, 0.78, 0.8)
	zip_mat.metallic = 0.6
	zip_mat.roughness = 0.4
	# The zip is a chain of short pieces, each lying along the curve of the bag.
	var pieces := 9
	var x0 := -0.8
	var x1 := 0.4
	for k in pieces:
		var xm := lerpf(x0, x1, (k + 0.5) / pieces)
		var zip := MeshInstance3D.new()
		zip.name = "Zip" if k == 0 else "Zip%d" % k
		var zip_box := BoxMesh.new()
		zip_box.size = Vector3((x1 - x0) / pieces * 1.08, 0.018, 0.022)
		zip.mesh = zip_box
		zip.material_override = zip_mat
		var tilt := atan(bend_slope(xm))
		zip.position = Vector3(xm - _bag_radius(xm).x * 1.02 * sin(tilt), bend(xm) + _bag_radius(xm).x * 1.02 * cos(tilt), 0.0)
		zip.rotation = Vector3(0.0, 0.0, tilt)
		root.add_child(zip)
	var pull := MeshInstance3D.new()
	pull.name = "Pull"
	var pull_box := BoxMesh.new()
	pull_box.size = Vector3(0.05, 0.03, 0.04)
	pull.mesh = pull_box
	pull.material_override = zip_mat
	pull.position = Vector3(0.38 - _bag_radius(0.38).x * 1.02 * sin(atan(bend_slope(0.38))), bend(0.38) + _bag_radius(0.38).x * 1.02 * cos(atan(bend_slope(0.38))) + 0.012, 0.0)
	root.add_child(pull)
	# The collar: a soft roll of fur round the neck.
	var fur := StandardMaterial3D.new()
	fur.albedo_color = Color(0.86, 0.82, 0.72)
	fur.roughness = 1.0
	var collar := MeshInstance3D.new()
	collar.name = "Collar"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.12
	ring.outer_radius = 0.2
	collar.mesh = ring
	collar.material_override = fur
	var neck := _bag_radius(BAG_END)
	collar.position = Vector3(BAG_END, bend(BAG_END), 0.0)
	collar.rotation = Vector3(0.0, 0.0, PI * 0.5 - atan(bend_slope(BAG_END)))
	collar.scale = Vector3(neck.x / 0.2, 1.0, neck.y / 0.2) * 1.1
	root.add_child(collar)
	return root


const BAG_START := -1.0
const BAG_END := 0.5
## The sleeper lies curved like a banana in the sag of the hammock: the hips are the lowest point (BEND_AT) and the
## feet and the shoulders rise by this much per square of the distance (so about 0.3 m at the feet).
const BEND_AT := -0.3
const BEND_RISE := 0.6


## How far the bag's spine is lifted at `x` above the lowest point, and the slope of that curve there.
static func bend(x: float) -> float:
	var d := x - BEND_AT
	return BEND_RISE * d * d


static func bend_slope(x: float) -> float:
	return 2.0 * BEND_RISE * (x - BEND_AT)


## The bag's half height (y) and half width (z) at `x`: narrow at the feet, full at the hips and chest, drawn in
## at the neck.
static func _bag_radius(x: float) -> Vector2:
	var t := clampf((x - BAG_START) / (BAG_END - BAG_START), 0.0, 1.0)
	var feet := smoothstep(0.0, 0.25, t)
	var neck := 1.0 - 0.35 * smoothstep(0.85, 1.0, t)
	var full := 0.4 + 0.05 * sin(clampf(t, 0.0, 1.0) * PI)
	return Vector2(full * lerpf(0.55, 1.0, feet) * neck, (full + 0.26) * lerpf(0.55, 1.0, feet) * neck)


static func _bag_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 24
	var sides := 16
	var grid: Array = []
	for i in rings + 1:
		var t := float(i) / rings
		var x := lerpf(BAG_START, BAG_END, t)
		var r := _bag_radius(x)
		# The foot end closes in a rounded cap.
		var cap := 1.0 if i > 0 else 0.15
		var row: Array = []
		for j in sides:
			var a := TAU * j / sides
			# Quilted puffs: the surface swells between the seams.
			var puff := 1.0 + 0.05 * sin(t * TAU * 6.0) * absf(sin(a * 2.0))
			# The ring follows the curve: lifted by bend(x) and tilted with its slope.
			var ly := sin(a) * r.x * cap * puff
			var tilt := atan(bend_slope(x))
			row.append(Vector3(x - ly * sin(tilt), bend(x) + ly * cos(tilt), cos(a) * r.y * cap * puff))
		grid.append(row)
	for i in rings:
		for j in sides:
			var j2 := (j + 1) % sides
			var a: Vector3 = grid[i][j]
			var b: Vector3 = grid[i + 1][j]
			var c: Vector3 = grid[i + 1][j2]
			var d: Vector3 = grid[i][j2]
			var u0 := float(i) / rings
			var u1 := float(i + 1) / rings
			var v0 := float(j) / sides
			var v1 := float(j + 1) / sides
			st.set_uv(Vector2(u0, v0)); st.add_vertex(a)
			st.set_uv(Vector2(u1, v0)); st.add_vertex(b)
			st.set_uv(Vector2(u1, v1)); st.add_vertex(c)
			st.set_uv(Vector2(u0, v0)); st.add_vertex(a)
			st.set_uv(Vector2(u1, v1)); st.add_vertex(c)
			st.set_uv(Vector2(u0, v1)); st.add_vertex(d)
	st.generate_normals()
	return st.commit()


## A quilted cover: a deep blue with a diamond of paler seams.
static func _quilt() -> ImageTexture:
	var size := 64
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGB8)
	var base := Color(0.14, 0.22, 0.46)
	var seam := Color(0.36, 0.44, 0.7)
	for y in size:
		for x in size:
			var u := float(x) / size
			var v := float(y) / size
			var dd := minf(absf(fposmod(u + v, 0.5) - 0.25), absf(fposmod(u - v, 0.5) - 0.25))
			img.set_pixel(x, y, seam if dd < 0.02 else base)
	return ImageTexture.create_from_image(img)


static func _iron() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var noise := FastNoiseLite.new()
	noise.frequency = 0.08
	noise.seed = 7
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.width = 64
	tex.height = 64
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(0.2, 0.2, 0.23), Color(0.46, 0.27, 0.15)])
	tex.color_ramp = ramp
	m.albedo_texture = tex
	m.metallic = 0.75
	m.roughness = 0.5
	return m


## Woven cloth: warp and weft threads in two tones with small flecks.
static func _weave() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for y in 64:
		for x in 64:
			var over := ((x / 4) + (y / 4)) % 2 == 0
			var base := Color(0.72, 0.58, 0.36) if over else Color(0.6, 0.45, 0.27)
			if (x % 4 == 0) or (y % 4 == 0):
				base = base.darkened(0.18)
			base = base.lightened(rng.randf_range(-0.04, 0.04))
			if (y / 16) % 4 == 1:
				base = base.lerp(Color(0.55, 0.2, 0.15), 0.5)
			img.set_pixel(x, y, base)
	return ImageTexture.create_from_image(img)
