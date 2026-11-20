class_name LightningBolt
extends RefCounted
## The bolt a lightning strike draws from the sky down to where it hit (see Outdoor._show_bolt):
## a hard zig-zag with a few forks that branch off and die out in the air. The camera looks
## north and down from above, so the bolt leans away from it to the north (LEAN), which lays it
## flat across the screen instead of pointing it at the camera, and the zig-zag swings east and
## west, where it can be seen.

## How high above the ground the bolt starts, and how far north it starts per unit of height.
const HEIGHT := 30.0
const LEAN := 1.3
## How many kinks the main bolt has, and how far each one swings out to the side, at least and at most.
const KINKS := 20
const SWING_MIN := 0.9
const SWING_MAX := 2.2
## How many forks branch off, at least and at most, and how many kinks each one has.
const FORKS_MIN := 3
const FORKS_MAX := 5
const FORK_KINKS := 4
## How thick the bright core and the glow around it are (the forks are thinner).
const CORE := 0.09
const GLOW := 0.28
const FORK_SHARE := 0.55
## How long the bolt stays: flashes and short dark blinks between them, in seconds, then it fades.
const FLASHES := [0.35, 0.06, 0.25, 0.05, 0.45]
const FADE := 0.35


## The kinks of the bolt, from the sky down to `at`: each one swings to the other side of the
## last, so the line zig-zags hard all the way down.
static func path(at: Vector3, rng: RandomNumberGenerator) -> PackedVector3Array:
	var points := PackedVector3Array()
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	for i in KINKS + 1:
		var t := float(i) / KINKS
		var p := at + Vector3(0, HEIGHT * (1.0 - t), -HEIGHT * LEAN * (1.0 - t))
		if i > 0 and i < KINKS:
			side = -side
			p.x += side * rng.randf_range(SWING_MIN, SWING_MAX)
			p.z += rng.randf_range(-0.6, 0.6)
			p.y += rng.randf_range(-0.3, 0.3) * HEIGHT / KINKS
		points.append(p)
	return points


## The forks: each starts at one of the bolt's kinks in its lower two thirds (where the camera sees it,
## and not the last two), runs down
## and out to one side in a shorter zig-zag, and ends in the air.
static func forks(main: PackedVector3Array, rng: RandomNumberGenerator) -> Array[PackedVector3Array]:
	var out: Array[PackedVector3Array] = []
	var starts := range(main.size() / 3, main.size() - 2)
	starts.shuffle()
	var step := HEIGHT / KINKS
	for i in mini(rng.randi_range(FORKS_MIN, FORKS_MAX), starts.size()):
		var p: Vector3 = main[starts[i]]
		var out_side := 1.0 if rng.randf() < 0.5 else -1.0
		var fork := PackedVector3Array([p])
		# A low fork drops less, so it still ends above the ground.
		var drop := minf(step * 0.9, (p.y - main[main.size() - 1].y - 1.5) / FORK_KINKS)
		for k in FORK_KINKS:
			var fall := drop * rng.randf_range(0.6, 1.0)
			p += Vector3(out_side * rng.randf_range(0.8, 2.2), -fall, fall * LEAN + rng.randf_range(-0.5, 0.5))
			if k % 2 == 1:
				p.x -= out_side * rng.randf_range(0.4, 1.0)
			fork.append(p)
		out.append(fork)
	return out


## Builds the bolt for a strike at `at`: a bright core and a softer glow around the main line
## and the forks. The materials are returned under "core" and "glow" so the caller can fade them.
static func build(at: Vector3, rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	root.name = "LightningBolt"
	var main := path(at, rng)
	var lines: Array[PackedVector3Array] = [main]
	lines.append_array(forks(main, rng))
	var core_mat := _material(Color(0.95, 0.97, 1.0), 9.0, 1.0)
	var glow_mat := _material(Color(0.6, 0.72, 1.0), 4.0, 0.35)
	root.add_child(_mesh(lines, CORE, core_mat))
	root.add_child(_mesh(lines, GLOW, glow_mat))
	root.set_meta("core", core_mat)
	root.set_meta("glow", glow_mat)
	return root


static func _material(colour: Color, energy: float, alpha: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(colour, alpha)
	mat.emission_enabled = true
	mat.emission = colour
	mat.emission_energy_multiplier = energy
	return mat


## One mesh of four-sided rods along every line; the first line is the main bolt, the rest are
## forks, thinner and thinning out towards their tips.
static func _mesh(lines: Array[PackedVector3Array], thick: float, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for l in lines.size():
		var line := lines[l]
		for i in line.size() - 1:
			var w := thick
			if l > 0:
				w *= FORK_SHARE * (1.0 - 0.6 * float(i) / (line.size() - 1))
			_rod(st, line[i], line[i + 1], w)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _rod(st: SurfaceTool, a: Vector3, b: Vector3, w: float) -> void:
	var along := (b - a).normalized()
	var u := along.cross(Vector3.FORWARD if absf(along.z) < 0.9 else Vector3.RIGHT).normalized() * w
	var v := along.cross(u).normalized() * w
	var ring := [u + v, u - v, -u - v, -u + v]
	for k in 4:
		var c0: Vector3 = ring[k]
		var c1: Vector3 = ring[(k + 1) % 4]
		for p in [a + c0, b + c0, b + c1, a + c0, b + c1, a + c1]:
			st.add_vertex(p)


## How long the bolt is on screen in all, flashes and fade together.
static func lasts() -> float:
	var total := FADE
	for t in FLASHES:
		total += t
	return total
