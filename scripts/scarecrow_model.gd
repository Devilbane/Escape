class_name ScarecrowModel
extends RefCounted
## The scarecrow of the sunflower field (see ValleyEvents, SunflowerRiddle): a gaunt figure on a tall post,
## three and a half metres high so it towers over the sunflowers. A ragged patched coat with a torn hem, long straw
## fingers ending in claws, a burlap sack for a head with hollow eyes that glow red, a stitched mouth full of bone
## teeth and a broken hat; two dead crows hang from its arms and a rusty scythe leans in its hand. It looks south.

## The top of the hat above the ground (metres).
const HAT_TOP := 3.75
## Where the crow lands (above the ground).
const PERCH := 3.7

const BURLAP := Color(0.62, 0.5, 0.33)
const CLOTH := Color(0.3, 0.24, 0.21)
const STRAW := Color(0.8, 0.66, 0.32)
const BONE := Color(0.88, 0.84, 0.7)
const DARK := Color(0.05, 0.035, 0.03)


static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "Scarecrow"
	var rng := RandomNumberGenerator.new()
	rng.seed = 43
	var b := WeatheredProps.Builder.new()
	var wood := WeatheredProps.TIMBER
	_frame(b, rng, wood)
	_coat(b, rng)
	_arms(b, rng, wood)
	_head(b, rng)
	_hat(b, rng)
	_scythe(b, rng, wood)
	_crow(b, Vector3(-1.15, 2.3, 0.1), 0.2)
	_crow(b, Vector3(0.78, 2.4, 0.12), -0.15)
	b.finish(root, Vector3.ZERO, true, true)
	_eyes(root)
	return root


## The post, the crossbar and the braces that hold it upright.
static func _frame(b: WeatheredProps.Builder, rng: RandomNumberGenerator, wood: Array) -> void:
	b.bar(Vector3(0, -0.4, 0), Vector3(0, 3.35, 0), 0.1, WeatheredProps.vary(wood[1], rng, 0.06), WeatheredProps.WOOD, 8)
	b.bar(Vector3(-1.6, 2.5, 0), Vector3(1.6, 2.5, 0), 0.07, WeatheredProps.vary(wood[2], rng, 0.06), WeatheredProps.WOOD, 7)
	for k in 4:
		var a := TAU * (k + 0.5) / 4.0
		b.bar(Vector3(cos(a) * 0.1, 1.1, sin(a) * 0.1), Vector3(cos(a) * 0.75, 0.0, sin(a) * 0.75), 0.045, WeatheredProps.vary(wood[0], rng, 0.08), WeatheredProps.WOOD, 6)
	# Rope lashings where the bar crosses the post.
	for k in 3:
		b.cylinder(Vector3(0, 2.44 + k * 0.045, 0), 0.125, 0.125, 0.03, Color(0.5, 0.4, 0.24), WeatheredProps.FRESH, 8)


## A patched, rotten coat on the post with a torn hem, strips hanging and straw poking out.
static func _coat(b: WeatheredProps.Builder, rng: RandomNumberGenerator) -> void:
	b.frustum(Vector3(0, 1.2, 0), Vector2(0.78, 0.5), Vector2(1.15, 0.52), 1.4, CLOTH, WeatheredProps.FRESH)
	b.frustum(Vector3(0, 0.95, 0), Vector2(0.95, 0.62), Vector2(0.78, 0.5), 0.27, CLOTH.darkened(0.08), WeatheredProps.FRESH)
	# Patches of other cloth, sewn on with big stitches.
	var patches := [
		[Vector3(-0.22, 1.9, 0.27), Vector2(0.28, 0.3), Color(0.38, 0.17, 0.14)],
		[Vector3(0.2, 1.5, 0.27), Vector2(0.3, 0.26), Color(0.2, 0.26, 0.34)],
		[Vector3(-0.15, 1.35, 0.27), Vector2(0.22, 0.2), Color(0.4, 0.34, 0.2)],
	]
	for p in patches:
		var at: Vector3 = p[0]
		var size: Vector2 = p[1]
		b.box(at, Vector3(size.x, size.y, 0.03), p[2], WeatheredProps.FRESH, Basis(Vector3.BACK, rng.randf_range(-0.2, 0.2)))
		for s in 5:
			b.box(at + Vector3(-size.x * 0.5 + (s + 0.5) * size.x / 5.0, size.y - 0.02, 0.02), Vector3(0.012, 0.05, 0.012), DARK, WeatheredProps.FRESH)
	# The ragged hem: long torn strips, some longer than others.
	var strips := 18
	for k in strips:
		var a := TAU * k / strips + rng.randf_range(-0.06, 0.06)
		var len := rng.randf_range(0.3, 0.75)
		var r := 0.36 + 0.06 * absf(cos(a))
		var foot := Vector3(cos(a) * r * 1.2, 0.95 - len, sin(a) * r * 0.78)
		var lean := Basis(Vector3(cos(a + PI * 0.5), 0, sin(a + PI * 0.5)), rng.randf_range(-0.1, 0.1)) * Basis(Vector3.UP, a)
		b.box(foot, Vector3(0.11, len, 0.02), WeatheredProps.vary(CLOTH, rng, 0.2), WeatheredProps.FRESH, lean)
	# Straw bursting out of a split at the belly.
	for k in 14:
		var from := Vector3(rng.randf_range(-0.2, 0.2), 1.4 + rng.randf_range(-0.1, 0.1), 0.25)
		b.bar(from, from + Vector3(rng.randf_range(-0.14, 0.14), rng.randf_range(-0.34, -0.1), rng.randf_range(0.08, 0.22)), 0.012, WeatheredProps.vary(STRAW, rng, 0.12), WeatheredProps.FRESH, 4)


## Long sleeves along the bar, rope-bound at the wrists, ending in straw fingers that end in claws.
static func _arms(b: WeatheredProps.Builder, rng: RandomNumberGenerator, _wood: Array) -> void:
	for side in [-1.0, 1.0]:
		b.bar(Vector3(side * 0.4, 2.5, 0), Vector3(side * 1.35, 2.46, 0), 0.17, CLOTH.lightened(0.04), WeatheredProps.FRESH, 8)
		# Frayed cuff.
		for k in 9:
			var a := TAU * k / 9.0
			var from := Vector3(side * 1.3, 2.46 + cos(a) * 0.15, sin(a) * 0.15)
			b.bar(from, from + Vector3(side * rng.randf_range(0.1, 0.22), rng.randf_range(-0.35, -0.12), 0), 0.014, WeatheredProps.vary(CLOTH, rng, 0.2), WeatheredProps.FRESH, 4)
		b.cylinder(Vector3(side * 1.42, 2.46, 0), 0.13, 0.13, 0.05, Color(0.5, 0.4, 0.24), WeatheredProps.FRESH, 8, Basis(Vector3.BACK, -side * PI * 0.5))
		# Fingers: straw tufts from the cuff, then long thin claws.
		for k in 5:
			var spread := (k - 2) * 0.13
			var from := Vector3(side * 1.48, 2.46, spread * 0.3)
			var mid := from + Vector3(side * 0.2, -0.12, spread * 0.5)
			var tip := mid + Vector3(side * 0.1, -0.3 - 0.04 * (2 - absi(k - 2)), spread * 0.35)
			b.bar(from, mid, 0.02, WeatheredProps.vary(STRAW, rng, 0.1), WeatheredProps.FRESH, 5)
			b.bar(mid, tip, 0.014, Color(0.18, 0.14, 0.1), WeatheredProps.WOOD, 5)
			b.cylinder(tip, 0.014, 0.0, 0.09, Color(0.14, 0.1, 0.08), WeatheredProps.WOOD, 5, Basis(Vector3.BACK, side * 0.35))


## A burlap sack with hollow, angry eyes and a stitched grin full of teeth.
static func _head(b: WeatheredProps.Builder, rng: RandomNumberGenerator) -> void:
	b.cylinder(Vector3(0, 2.62, 0), 0.19, 0.27, 0.16, BURLAP.darkened(0.1), WeatheredProps.FRESH, 12)
	b.cylinder(Vector3(0, 2.77, 0), 0.27, 0.33, 0.34, BURLAP, WeatheredProps.FRESH, 14)
	b.cylinder(Vector3(0, 3.1, 0), 0.33, 0.22, 0.2, BURLAP.lightened(0.04), WeatheredProps.FRESH, 14)
	# The neck rope and the knotted top.
	for k in 3:
		b.cylinder(Vector3(0, 2.66 + k * 0.04, 0), 0.215 + k * 0.01, 0.215 + k * 0.01, 0.03, Color(0.5, 0.4, 0.24), WeatheredProps.FRESH, 12)
	b.cylinder(Vector3(0, 3.28, 0), 0.07, 0.03, 0.12, BURLAP.darkened(0.12), WeatheredProps.FRESH, 7)
	# Hollow eyes under angry brows.
	for side in [-1.0, 1.0]:
		b.box(Vector3(side * 0.13, 2.94, 0.28), Vector3(0.12, 0.1, 0.06), DARK, WeatheredProps.FRESH, Basis(Vector3.BACK, side * 0.35))
		b.box(Vector3(side * 0.14, 3.06, 0.285), Vector3(0.19, 0.035, 0.03), Color(0.14, 0.1, 0.07), WeatheredProps.FRESH, Basis(Vector3.BACK, -side * 0.4))
	# A torn, stitched nose.
	b.frustum(Vector3(0, 2.82, 0.31), Vector2(0.07, 0.03), Vector2(0.025, 0.02), 0.1, BURLAP.darkened(0.25), WeatheredProps.FRESH)
	# The mouth: a dark gash, a row of sharp bone teeth above and below, stitches across.
	b.box(Vector3(0, 2.66, 0.3), Vector3(0.34, 0.1, 0.05), DARK, WeatheredProps.FRESH)
	for k in 8:
		var x := -0.14 + k * 0.04
		b.cylinder(Vector3(x, 2.71, 0.33), 0.016, 0.0, -0.05 - 0.02 * (k % 2), BONE, WeatheredProps.FRESH, 4)
		b.cylinder(Vector3(x + 0.02, 2.66, 0.33), 0.016, 0.0, 0.05 + 0.02 * ((k + 1) % 2), BONE, WeatheredProps.FRESH, 4)
	for k in 6:
		var x := -0.13 + k * 0.052
		b.box(Vector3(x, 2.6, 0.325), Vector3(0.012, 0.22, 0.012), Color(0.16, 0.11, 0.07), WeatheredProps.FRESH, Basis(Vector3.BACK, rng.randf_range(-0.2, 0.2)))
	# Straw hair over the ears.
	for k in 16:
		var a := rng.randf_range(0, TAU)
		var from := Vector3(cos(a) * 0.3, 2.95 + rng.randf_range(-0.12, 0.1), sin(a) * 0.3)
		if from.z > 0.12:
			continue
		b.bar(from, from + Vector3(cos(a) * 0.16, rng.randf_range(-0.3, -0.1), sin(a) * 0.16), 0.012, WeatheredProps.vary(STRAW, rng, 0.12), WeatheredProps.FRESH, 4)


## A broken, wide-brimmed hat pulled low and tilted.
static func _hat(b: WeatheredProps.Builder, rng: RandomNumberGenerator) -> void:
	var tilt := Basis(Vector3.BACK, 0.14)
	var felt := Color(0.24, 0.18, 0.13)
	b.cylinder(Vector3(0.0, 3.2, 0), 0.58, 0.54, 0.04, felt, WeatheredProps.FRESH, 16, tilt)
	b.cylinder(Vector3(-0.03, 3.22, 0), 0.26, 0.2, 0.5, felt.lightened(0.04), WeatheredProps.FRESH, 12, tilt)
	# The crown is bent: a dent near the top, and a torn hole in the brim.
	b.cylinder(Vector3(-0.1, 3.7, 0), 0.2, 0.1, 0.06, felt.darkened(0.1), WeatheredProps.FRESH, 10, Basis(Vector3.BACK, 0.4) * tilt)
	b.cylinder(Vector3(-0.03, 3.26, 0), 0.265, 0.265, 0.06, Color(0.4, 0.14, 0.12), WeatheredProps.FRESH, 12, tilt)
	for k in 6:
		var a := rng.randf_range(0, TAU)
		var from := Vector3(cos(a) * 0.56, 3.21, sin(a) * 0.56)
		b.bar(from, from + Vector3(cos(a) * 0.05, -rng.randf_range(0.1, 0.25), sin(a) * 0.05), 0.012, WeatheredProps.vary(felt, rng, 0.15), WeatheredProps.FRESH, 4)


## A rusty scythe leaning in the right hand, blade up.
static func _scythe(b: WeatheredProps.Builder, rng: RandomNumberGenerator, wood: Array) -> void:
	var base := Vector3(1.5, -0.05, 0.3)
	var top := Vector3(1.42, 3.0, 0.3)
	b.bar(base, top, 0.028, WeatheredProps.vary(wood[1], rng, 0.05), WeatheredProps.WOOD, 6)
	b.bar(Vector3(1.46, 1.1, 0.3), Vector3(1.28, 1.15, 0.45), 0.02, wood[0], WeatheredProps.WOOD, 5)
	# The blade bends away from the handle's tip: a row of tapering plates along an arc.
	var rust := Color(0.45, 0.3, 0.2)
	var prev := top
	for k in 8:
		var t := (k + 1) / 8.0
		var next := top + Vector3(-sin(t * 1.5) * 0.95, cos(t * 1.5) * 0.08 + t * 0.12 - 0.0, 0)
		var width := lerpf(0.09, 0.015, t * t)
		b.bar(prev, next, width * 0.6, WeatheredProps.vary(rust, rng, 0.12), WeatheredProps.IRON, 5)
		prev = next


## A dead crow hung by its feet from the arm, wings spread.
static func _crow(b: WeatheredProps.Builder, at: Vector3, sway: float) -> void:
	var black := Color(0.07, 0.07, 0.09)
	b.bar(at + Vector3(0, 0.3, 0), at + Vector3(0, 0.14, 0), 0.008, Color(0.45, 0.36, 0.22), WeatheredProps.FRESH, 4)
	var tilt := Basis(Vector3.BACK, sway)
	b.frustum(at - Vector3(0, 0.12, 0), Vector2(0.1, 0.16), Vector2(0.18, 0.28), 0.26, black, WeatheredProps.FRESH, tilt)
	b.box(at - Vector3(0, 0.2, 0.02), Vector3(0.1, 0.1, 0.12), black.lightened(0.04), WeatheredProps.FRESH, tilt)
	b.frustum(at - Vector3(0.0, 0.28, 0.07), Vector2(0.03, 0.02), Vector2(0.008, 0.008), 0.09, Color(0.3, 0.26, 0.2), WeatheredProps.FRESH, tilt * Basis(Vector3.RIGHT, 0.6))
	for side in [-1.0, 1.0]:
		b.box(at + Vector3(side * 0.05, -0.34, 0), Vector3(0.28, 0.02, 0.2), black.lightened(0.06), WeatheredProps.FRESH, Basis(Vector3.BACK, side * 0.9) * tilt)


## The hollow eyes burn a dull red: two small glowing beads and a faint light on the sack.
static func _eyes(root: Node3D) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.2, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.18, 0.08)
	mat.emission_energy_multiplier = 3.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var bead := SphereMesh.new()
	bead.radius = 0.028
	bead.height = 0.056
	bead.radial_segments = 8
	bead.rings = 4
	bead.material = mat
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		eye.name = "Eye"
		eye.mesh = bead
		eye.position = Vector3(side * 0.13, 2.94, 0.3)
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(eye)
	var glow := OmniLight3D.new()
	glow.name = "EyeGlow"
	glow.light_color = Color(1.0, 0.25, 0.12)
	glow.light_energy = 0.5
	glow.omni_range = 3.0
	glow.position = Vector3(0, 2.94, 0.6)
	glow.shadow_enabled = false
	root.add_child(glow)
