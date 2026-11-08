class_name WallShapes
extends RefCounted
## Sharp-edged relief for the walls of the rock, obsidian and crystal styles (see
## WallThemes): faceted shards and boulders that jut out of the wall face and
## stand up from its top, so the wall reads as raw rock or crystal and not as a
## flat block. Each is a low-poly mesh with flat faces, in the style's own
## material, so it takes the same light, glints and fade as the wall. The bone
## style stays flat. Nothing here blocks the hero: the shards stay close to the
## wall, and the collision is the wall's box.

## Per style: how many shards on the face, how many on top, how long and how
## thin they are (length is the base width times it), and how far they lean.
const LOOKS := {
	"rock": {"face": 3, "top": 1, "base": [0.35, 0.6], "long": [1.1, 2.0], "lean": 35.0, "sides": 5},
	"obsidian": {"face": 3, "top": 2, "base": [0.15, 0.3], "long": [3.5, 6.0], "lean": 28.0, "sides": 4},
	"crystal": {"face": 3, "top": 2, "base": [0.18, 0.34], "long": [3.0, 5.5], "lean": 30.0, "sides": 6},
}
## How many differently shaped shards a style has; each is shared by many.
const VARIANTS := 6

static var _meshes := {}


static func styled(style: String) -> bool:
	return LOOKS.has(style)


## A flat-faced shard: a ring of `sides` corners (a little uneven) up to a
## point that sits off to one side.
static func shard_mesh(style: String, variant: int) -> ArrayMesh:
	var key := "%s_%d" % [style, variant]
	if _meshes.has(key):
		return _meshes[key]
	var look: Dictionary = LOOKS[style]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var sides: int = look.sides
	var ring := []
	for i in sides:
		var a := TAU * i / sides + rng.randf_range(-0.2, 0.2)
		var r := rng.randf_range(0.75, 1.1)
		ring.append(Vector3(cos(a) * r, 0.0, sin(a) * r))
	# Unit size: base radius 1, height 1; the shard is scaled when placed.
	var apex := Vector3(rng.randf_range(-0.25, 0.25), 1.0, rng.randf_range(-0.25, 0.25))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in sides:
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[(i + 1) % sides]
		for v in [a, apex, b]:
			st.set_uv(Vector2(v.x * 0.25 + 0.5, v.y * 0.25 + 0.5))
			st.add_vertex(v)
	# Flat normals: no smoothing groups were set.
	st.generate_normals()
	var mesh := st.commit()
	_meshes[key] = mesh
	return mesh


## Adds shards to a wall piece `wall` (local +z points into the room, x runs
## along the wall, the wall is 4 m wide and 4 m high). `material` is the
## style's wall material; `seed_value` makes each wall different but the same
## every time.
static func dress(wall: Node3D, style: String, material: Material, seed_value: int) -> void:
	if not LOOKS.has(style):
		return
	var look: Dictionary = LOOKS[style]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in look.face:
		# Not in the middle: that is where a wall torch hangs.
		var x := rng.randf_range(0.85, 1.85) * (1.0 if i % 2 == 0 else -1.0)
		var y := rng.randf_range(0.5, 3.4)
		_add(wall, style, material, rng, Vector3(x, y, 0.3), look, true)
	for i in look.top:
		var x := rng.randf_range(-1.7, 1.7)
		_add(wall, style, material, rng, Vector3(x, 3.85, 0.0), look, false)


static func _add(wall: Node3D, style: String, material: Material, rng: RandomNumberGenerator, at: Vector3, look: Dictionary, outward: bool) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = shard_mesh(style, rng.randi() % VARIANTS)
	mi.material_override = material
	var base := rng.randf_range(look.base[0], look.base[1])
	var length := base * rng.randf_range(look.long[0], look.long[1])
	mi.scale = Vector3(base, length, base)
	mi.position = at
	var lean: float = look.lean
	if outward:
		# Pointing out of the wall and up, a bit to the side.
		# (A turn about x tips the shard's tip from up (+y) towards the room (+z).)
		mi.rotation_degrees = Vector3(rng.randf_range(45.0, 80.0), rng.randf_range(-25.0, 25.0), 0.0)
	else:
		mi.rotation_degrees = Vector3(rng.randf_range(-lean, lean), rng.randf_range(0.0, 360.0), rng.randf_range(-lean, lean))
		mi.scale = Vector3(base, length * 1.2, base)
	wall.add_child(mi)
