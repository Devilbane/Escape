class_name CatSleeper
extends RefCounted
## The village cat curled up asleep (see VillageCat): not the standing cat squashed flat, but a model
## of its own that reads as a sleeping cat from every side. A round body with a rump and a shoulder,
## the head tucked down onto the two cream front paws with its eyes shut, ears, whiskers and cheeks, a hind
## foot peeking out, and the tail wrapped right round the body to lie in front of the nose with a
## dark tip. A tabby's stripes run across the back, the head and the tail, and a fur texture of fine
## strands breaks up the plain colour. Every part is a smooth low-poly ellipsoid, a short stick or a cone.
##
## It faces +z and lies on y = 0. `build` returns its joints: "root" (the whole sleeper, its y scale
## breathes), "tip" (the tail's last part, which flicks), "ears" (left and right, one twitches) and
## "head".

const GINGER := Color(0.86, 0.5, 0.2)
const DARK := Color(0.6, 0.28, 0.1)
const CREAM := Color(0.88, 0.78, 0.64)
const PINK := Color(0.9, 0.55, 0.55)
const INK := Color(0.1, 0.06, 0.05)

## Where the tail runs round the body: an ellipse (half widths) about the body's middle, from its
## rump round the right side to the front, in degrees from the way the cat faces.
const WRAP := Vector2(0.285, 0.31)
const WRAP_FROM := 168.0
const WRAP_TO := 22.0
const TAIL_PARTS := 8

static var _fur: ImageTexture
static var _mats := {}


## A tile of fine hair strands: a light and dark streak pattern that multiplies the plain colour.
static func fur_texture() -> ImageTexture:
	if _fur == null:
		var size := 128
		var img := Image.create(size, size, false, Image.FORMAT_RGB8)
		var rng := RandomNumberGenerator.new()
		rng.seed = 4242
		var column := PackedFloat32Array()
		for x in size:
			column.append(rng.randf())
		for y in size:
			for x in size:
				# Strands: each column keeps its own shade for a stretch, with a little speckle.
				var strand := column[(x + int(y / 9)) % size]
				var speck := rng.randf()
				var v := 0.8 + 0.16 * strand + 0.06 * speck
				img.set_pixel(x, y, Color(v, v, v))
		_fur = ImageTexture.create_from_image(img)
	return _fur


## One material per colour, furry (the strands, and a soft light edge like fluffed hair) unless plain.
static func paint(colour: Color, furry := true) -> StandardMaterial3D:
	var key := "%s %s" % [colour, furry]
	if not _mats.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colour
		mat.roughness = 1.0
		if furry:
			mat.albedo_texture = fur_texture()
			mat.uv1_scale = Vector3(3.0, 2.0, 1.0)
			mat.rim_enabled = true
			mat.rim = 0.1
			mat.rim_tint = 0.5
		_mats[key] = mat
	return _mats[key]


static func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, colour: Color, furry := true) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.position = at
	m.material_override = paint(colour, furry)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m


## A smooth ellipsoid with these half widths.
static func ball(parent: Node3D, at: Vector3, half: Vector3, colour: Color, furry := true) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 16
	s.rings = 9
	var m := _mesh(parent, s, at, colour, furry)
	m.scale = half * 2.0
	return m


static func cone(parent: Node3D, at: Vector3, radius: float, length: float, colour: Color, furry := true) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = radius
	c.height = length
	c.radial_segments = 5
	c.rings = 1
	return _mesh(parent, c, at, colour, furry)


## A short round stick from `a` to `b`.
static func rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, colour: Color, furry := true) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = a.distance_to(b)
	c.radial_segments = 10
	c.rings = 1
	var m := _mesh(parent, c, (a + b) * 0.5, colour, furry)
	# The cylinder stands along y; turn it along the way from a to b.
	var up := (b - a).normalized()
	var axis := Vector3.UP.cross(up)
	if axis.length() > 0.0001:
		m.basis = Basis(axis.normalized(), Vector3.UP.angle_to(up))
	return m


## The point on the tail's ring at `angle` degrees from the front (clockwise from above): x to the
## right of the cat, z to its front.
static func wrap_point(angle: float) -> Vector3:
	var a := deg_to_rad(angle)
	return Vector3(WRAP.x * sin(a), 0.045, WRAP.y * cos(a))


static func build(parent: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "Sleeper"
	parent.add_child(root)
	var out := {"root": root}
	# The body: a round loaf with a rump bulging at the back right and a shoulder at the front left.
	var body := Node3D.new()
	root.add_child(body)
	ball(body, Vector3(0, 0.125, -0.02), Vector3(0.205, 0.125, 0.235), GINGER)
	ball(body, Vector3(0.1, 0.13, -0.11), Vector3(0.125, 0.115, 0.13), GINGER)
	ball(body, Vector3(-0.06, 0.125, 0.1), Vector3(0.11, 0.1, 0.11), GINGER)
	# The cream belly shows a little at the side, where it lies on its flank.
	ball(body, Vector3(-0.12, 0.06, 0.02), Vector3(0.1, 0.06, 0.17), CREAM)
	# The stripes of a tabby, across the back: each as wide as the back is there.
	for z in [-0.17, -0.1, -0.03, 0.04, 0.11]:
		var across := 0.34 * sqrt(maxf(0.1, 1.0 - pow((z + 0.02) / 0.235, 2.0)))
		var top := 0.125 + 0.125 * sqrt(maxf(0.0, 1.0 - pow((z + 0.02) / 0.235, 2.0)))
		var stripe := ball(body, Vector3(0.0, top - 0.004, z), Vector3(across * 0.5, 0.022, 0.017), DARK)
		stripe.rotation.z = 0.0
	# The hind foot peeking out at the back, and the haunch's stripe.
	ball(body, Vector3(0.17, 0.045, 0.03), Vector3(0.05, 0.035, 0.075), CREAM)
	ball(body, Vector3(0.2, 0.15, -0.12), Vector3(0.012, 0.07, 0.045), DARK)
	# The front paws, tucked together under the chin.
	ball(body, Vector3(-0.07, 0.045, 0.255), Vector3(0.05, 0.036, 0.075), CREAM)
	ball(body, Vector3(-0.16, 0.045, 0.235), Vector3(0.05, 0.036, 0.075), CREAM)
	# The head, laid on the paws and turned a little to the side.
	var head := Node3D.new()
	head.position = Vector3(-0.115, 0.115, 0.255)
	head.rotation = Vector3(0.18, 0.55, 0.22)
	root.add_child(head)
	out["head"] = head
	ball(head, Vector3.ZERO, Vector3(0.125, 0.105, 0.108), GINGER)
	# Cheeks, a cream muzzle, the nose and the whiskers.
	for side in [-1.0, 1.0]:
		ball(head, Vector3(side * 0.085, -0.03, 0.035), Vector3(0.04, 0.035, 0.045), CREAM)
	ball(head, Vector3(0, -0.03, 0.082), Vector3(0.062, 0.045, 0.045), CREAM)
	ball(head, Vector3(0, -0.012, 0.118), Vector3(0.024, 0.017, 0.015), PINK, false)
	for side in [-1.0, 1.0]:
		for k in 3:
			var w := rod(head, Vector3(side * 0.05, -0.03 - k * 0.008, 0.1), Vector3(side * 0.15, -0.015 - k * 0.024, 0.085), 0.0025, Color(0.96, 0.94, 0.9), false)
			w.name = "Whisker"
	# The eyes shut: a dark crescent each, drooping outward, and the forehead's three stripes.
	for side in [-1.0, 1.0]:
		var lid := ball(head, Vector3(side * 0.052, 0.014, 0.096), Vector3(0.026, 0.006, 0.008), INK, false)
		lid.rotation.z = -side * 0.35
	for k in [-1, 0, 1]:
		var mark := ball(head, Vector3(k * 0.03, 0.098, 0.03), Vector3(0.009, 0.006, 0.04), DARK)
		mark.rotation.y = k * 0.25
	# The ears, pricked a little, with pink inside; one of them twitches in its sleep.
	var ears: Array[Node3D] = []
	for side in [-1.0, 1.0]:
		var ear := Node3D.new()
		ear.position = Vector3(side * 0.07, 0.075, -0.01)
		ear.rotation = Vector3(-0.1, 0.0, -side * 0.45)
		head.add_child(ear)
		cone(ear, Vector3(0, 0.05, 0), 0.052, 0.11, GINGER)
		cone(ear, Vector3(0, 0.043, 0.014), 0.032, 0.08, PINK, false)
		ears.append(ear)
	out["ears"] = ears
	# The tail: round the body from the rump to the front, its last part a dark tip that can flick.
	var tip := Node3D.new()
	var at_tip := wrap_point(lerpf(WRAP_FROM, WRAP_TO, 4.0 / TAIL_PARTS))
	tip.position = at_tip
	root.add_child(tip)
	out["tip"] = tip
	var prev := wrap_point(WRAP_FROM)
	for i in range(1, TAIL_PARTS + 1):
		var next := wrap_point(lerpf(WRAP_FROM, WRAP_TO, float(i) / TAIL_PARTS))
		var radius := lerpf(0.046, 0.034, float(i) / TAIL_PARTS)
		# Alternating bands of ginger and dark, the last two part cream at the very tip.
		var colour := DARK if i % 2 == 0 else GINGER
		if i >= TAIL_PARTS - 1:
			colour = CREAM if i == TAIL_PARTS else DARK
		if i > 4:
			rod(tip, prev - at_tip, next - at_tip, radius, colour)
			ball(tip, next - at_tip, Vector3.ONE * radius, colour)
		else:
			rod(root, prev, next, radius, colour)
			ball(root, next, Vector3.ONE * radius, colour)
		prev = next
	# The root of the tail where it leaves the rump.
	ball(root, wrap_point(WRAP_FROM) + Vector3(0, 0, 0.0), Vector3.ONE * 0.05, GINGER)
	return out
