class_name WallHammock
extends RefCounted
## The hanging rest on the climbing wall: two iron pitons hammered into the rock and a woven hammock slung
## between them. WallStage hammers the pitons one after the other (`piton`), hangs the cloth (`cloth`) and lets
## the climber lie in it.

const SPAN := 2.0      ## distance between the two pitons
const SAG := 0.45      ## how far the cloth hangs below the pitons
const WIDTH := 0.7


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
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var half := SPAN * 0.5 - 0.22
	for i in steps + 1:
		var t := float(i) / steps
		var x := lerpf(-half, half, t)
		var y := -SAG * (1.0 - pow(2.0 * t - 1.0, 2.0))
		# The cloth bulges forward a little at the sides, like a real hammock cradle.
		var belly := 0.12 * sin(t * PI)
		verts.append(Vector3(x, y - WIDTH * 0.5, 0.0))
		verts.append(Vector3(x, y + WIDTH * 0.5, belly))
		uvs.append(Vector2(t * 6.0, 0.0))
		uvs.append(Vector2(t * 6.0, 1.0))
		if i < steps:
			var a := i * 2
			idx.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
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
