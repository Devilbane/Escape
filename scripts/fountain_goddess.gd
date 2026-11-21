class_name FountainGoddess
## The little marble goddess on top of the village fountain (see VillageFountain), in the manner of
## classical fountain statues: a slender woman in a light, long gown belted high under the bust,
## its skirt falling in soft pleats, her hair gathered into a knot. Her right hand holds a laurel
## wreath up beside her head, her left an urn at her hip that pours the fountain's water into the
## bowl below. About 1.3 m tall as built, facing +Z, her feet at the origin. Built from smooth turned
## and round pieces, all of one marble material.

## Which way the urn's mouth points as she tips it (from her feet, before she is turned).
const URN_POUR := Vector3(-0.45, -0.7, 0.5)
## How much flatter she is front to back than side to side.
const DEPTH := 0.68
const SIDES := 48


static func build(marble: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "Goddess"
	# A slight turn of the whole figure, so she does not stand stiffly square to the square.
	root.rotation.y = -0.18
	var body := MeshInstance3D.new()
	body.mesh = _body(marble)
	root.add_child(body)
	# The girdle under the bust.
	var girdle := MeshInstance3D.new()
	girdle.mesh = VillageFountain.lathe_mesh(PackedVector2Array([
		Vector2(0.118, 0.818), Vector2(0.134, 0.824), Vector2(0.136, 0.846), Vector2(0.122, 0.852),
	]), SIDES, marble)
	girdle.scale = Vector3(1, 1, DEPTH)
	root.add_child(girdle)
	# Head, a little longer than round, with the hair gathered into a knot at the back and a band.
	var head := Node3D.new()
	head.position = Vector3(0, 1.215, 0.012)
	head.rotation = Vector3(0.12, 0.3, 0.06)
	root.add_child(head)
	_ball(head, marble, Vector3(0, 0, 0), Vector3(0.064, 0.08, 0.068))
	_ball(head, marble, Vector3(0, 0.03, -0.02), Vector3(0.07, 0.07, 0.07))  # the hair
	for side in [-1.0, 1.0]:
		# Waves of hair drawn back over the ears.
		_ball(head, marble, Vector3(side * 0.05, 0.005, -0.012), Vector3(0.026, 0.052, 0.05))
	_ball(head, marble, Vector3(0, 0.03, -0.095), Vector3(0.042, 0.038, 0.036))  # its knot
	_ball(head, marble, Vector3(0, -0.035, 0.062), Vector3(0.011, 0.016, 0.012))  # the nose
	# The right arm raised, the wreath in her hand.
	var r_elbow := Vector3(0.24, 1.12, 0.05)
	var r_hand := Vector3(0.235, 1.33, 0.07)
	_limb(root, marble, Vector3(0.15, 1.01, 0.0), r_elbow, 0.03)
	_limb(root, marble, r_elbow, r_hand, 0.026)
	_ball(root, marble, r_hand + Vector3(0, 0.02, 0), Vector3(0.026, 0.032, 0.022))
	var wreath := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.055
	ring.outer_radius = 0.08
	ring.rings = 24
	ring.ring_segments = 8
	wreath.mesh = ring
	wreath.material_override = marble
	wreath.position = r_hand + Vector3(-0.02, 0.1, 0.0)
	wreath.rotation = Vector3(PI * 0.5, 0, 0.3)
	root.add_child(wreath)
	# The left arm down, the hand holding the urn tipped at her hip; the cloth of a light mantle
	# hangs over the forearm.
	var l_elbow := Vector3(-0.2, 0.84, 0.02)
	var l_hand := Vector3(-0.2, 0.69, 0.08)
	_limb(root, marble, Vector3(-0.15, 1.01, 0.0), l_elbow, 0.03)
	_limb(root, marble, l_elbow, l_hand, 0.026)
	_limb(root, marble, Vector3(-0.215, 0.78, 0.07), Vector3(-0.235, 0.5, 0.05), 0.03)
	_limb(root, marble, Vector3(-0.235, 0.5, 0.05), Vector3(-0.22, 0.28, 0.03), 0.034)
	var urn := MeshInstance3D.new()
	urn.mesh = VillageFountain.lathe_mesh(PackedVector2Array([
		Vector2(0.0, -0.09), Vector2(0.035, -0.09), Vector2(0.06, -0.05), Vector2(0.068, 0.0),
		Vector2(0.06, 0.04), Vector2(0.032, 0.07), Vector2(0.026, 0.085), Vector2(0.04, 0.1),
		Vector2(0.036, 0.106), Vector2(0.02, 0.095), Vector2(0.0, 0.09),
	]), 20, marble)
	urn.position = l_hand + Vector3(-0.02, -0.02, 0.04)
	# Tipped so its mouth points along URN_POUR.
	urn.basis = _turn_up_to(URN_POUR)
	root.add_child(urn)
	# Where the water leaves the urn, for the stream (see VillageFountain).
	root.set_meta("urn_mouth", urn.position + URN_POUR.normalized() * 0.1)
	return root


## A basis that turns +Y onto `dir`.
static func _turn_up_to(dir: Vector3) -> Basis:
	var up := dir.normalized()
	var axis := Vector3.UP.cross(up)
	if axis.length() < 0.001:
		return Basis()
	return Basis(axis.normalized(), Vector3.UP.angle_to(up))


## A smooth round piece (a sphere stretched to `size`, its half sizes).
static func _ball(parent: Node3D, marble: Material, at: Vector3, size: Vector3) -> void:
	var node := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 20
	sphere.rings = 10
	node.mesh = sphere
	node.material_override = marble
	node.position = at
	node.scale = size
	parent.add_child(node)


## A rounded limb from `a` to `b`.
static func _limb(parent: Node3D, marble: Material, a: Vector3, b: Vector3, radius: float) -> void:
	var node := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = a.distance_to(b) + radius * 2.0
	capsule.radial_segments = 14
	capsule.rings = 4
	node.mesh = capsule
	node.material_override = marble
	node.position = (a + b) * 0.5
	node.basis = _turn_up_to(b - a)
	parent.add_child(node)


## The gown and the figure under it, turned on a lathe: the hem flaring a little on the base, the
## skirt falling in pleats over the thighs and the wider hips, the narrow waist, the bust rounded
## under the girdled cloth, the shoulders broader than deep, and the neck. The pleats fade out above
## the hips, where the cloth clings.
static func _body(marble: Material) -> ArrayMesh:
	var profile := [
		Vector2(0.0, 0.0), Vector2(0.25, 0.0), Vector2(0.255, 0.035), Vector2(0.235, 0.09),
		Vector2(0.215, 0.22), Vector2(0.2, 0.38), Vector2(0.192, 0.5), Vector2(0.196, 0.6),
		Vector2(0.186, 0.66), Vector2(0.158, 0.72), Vector2(0.126, 0.78), Vector2(0.118, 0.83),
		Vector2(0.124, 0.86), Vector2(0.13, 0.88), Vector2(0.134, 0.9), Vector2(0.136, 0.92),
		Vector2(0.136, 0.94), Vector2(0.134, 0.96), Vector2(0.13, 0.99), Vector2(0.12, 1.02),
		Vector2(0.1, 1.045), Vector2(0.066, 1.065), Vector2(0.045, 1.085), Vector2(0.042, 1.15),
		Vector2(0.0, 1.16),
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: Array = []
	for p: Vector2 in profile:
		# The pleats: strong at the hem, gone by the hips.
		var pleat := 0.07 * clampf(1.0 - p.y / 0.68, 0.0, 1.0)
		# The shoulders: wider than the chest is round.
		var wide := 1.0 + 0.4 * exp(-pow((p.y - 1.015) / 0.035, 2.0))
		var row: Array[Vector3] = []
		for k in SIDES + 1:
			var t := TAU * k / SIDES
			var r := p.x * (1.0 + pleat * sin(t * 14.0))
			# The bust: two soft swells either side of the front (+Z is t = PI / 2).
			var front := t - PI * 0.5
			var swell := exp(-pow((front - 0.5) / 0.32, 2.0)) + exp(-pow((front + 0.5) / 0.32, 2.0))
			r += 0.075 * swell * exp(-pow((p.y - 0.91) / 0.042, 2.0)) * float(p.x > 0.0)
			row.append(Vector3(cos(t) * r * wide, p.y, sin(t) * r * DEPTH))
		rows.append(row)
	for i in rows.size() - 1:
		for k in SIDES:
			var q := [rows[i][k], rows[i][k + 1], rows[i + 1][k + 1], rows[i + 1][k]]
			for j in [0, 1, 2, 0, 2, 3]:
				st.add_vertex(q[j])
	st.index()
	st.generate_normals()
	st.set_material(marble)
	return st.commit()
