class_name SnowPrints
extends RefCounted
## Brief grey footprints in the snow. A print is a soft grey shape pressed into the white
## layer (see SnowCover); it stays all day and is wiped away when a new day starts (or when the snow melts, see `clear`). Prints are
## cheap quads, and only so many exist at once. Besides the hero's boot
## there are the tracks of the animals: a paw (fox, dog), a cloven hoof (deer, goat, sheep, cow)
## and a bird's foot (three toes forward, one back). Every texture is drawn toe-up, and `leave`
## turns it so the toes lead the way the walker goes.

## At most this many prints at once. When the pool is full the oldest print of the least
## important kind goes first (see PRIORITY), so the hero's own boots outlast the beetles' dots.
const MAX := 700
## Which kinds are kept longest when the pool is full.
const PRIORITY := {"bug": 0, "bird": 1, "paw": 2, "hoof": 2, "boot": 3}
## Just above the snow, which lies up to SnowCover's 0.06 m over the ground when it is deep
## (snow_cover.gdshader lifts it by 0.03 + 0.03 * amount); lower prints are buried in it.
const HEIGHT := 0.085
## The pictures are toe-up (v = 0), which a flat quad lays towards -Z; a walker heading `h` goes
## towards (sin h, 0, cos h), so the quad turns half way round.
const FRONT := PI
## The pressed grey. A print is lit like the snow round it, so it is always the same share darker than the
## snow and takes on the colour of the hour's light (pink at dusk, pale blue at night) instead of
## standing out as a cold grey dot. The grey itself is neutral, with no blue in it.
const GREY := Color(0.5, 0.5, 0.5, 0.92)

static var _shapes := {}
static var _textures := {}
static var _live: Array = []


## What each kind of print looks like: its size in metres (a quad of 1 x 2 for the boot, the
## others are square) and the grey it presses (the hero's boots are the darkest).
const KINDS := {
	"boot": Vector2(0.16, 0.32),
	"paw": Vector2(0.14, 0.14),
	"hoof": Vector2(0.12, 0.16),
	"bird": Vector2(0.1, 0.12),
	"bug": Vector2(0.05, 0.07),
}


static func _mesh(kind: String) -> QuadMesh:
	if not _shapes.has(kind):
		var q := QuadMesh.new()
		q.size = KINDS[kind]
		q.orientation = PlaneMesh.FACE_Y
		_shapes[kind] = q
	return _shapes[kind]


## The picture of one kind of print, drawn once, toes at the top (v = 0).
static func texture(kind: String) -> Texture2D:
	if not _textures.has(kind):
		var size: Vector2 = KINDS[kind]
		var w := 32
		var h := 64 if size.y > size.x * 1.5 else 32
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			for x in w:
				var u := (x + 0.5) / w * 2.0 - 1.0
				var v := (y + 0.5) / h
				img.set_pixel(x, y, Color(1, 1, 1, _alpha(kind, u, v)))
		_textures[kind] = ImageTexture.create_from_image(img)
	return _textures[kind]


## How much of the print lies at (u -1..1 across, v 0..1 from the toes back).
static func _alpha(kind: String, u: float, v: float) -> float:
	match kind:
		"paw":
			# A broad pad behind and four toes in an arc in front of it.
			var a := _blob(u, v, 0.0, 0.66, 0.5, 0.26)
			for t in [[-0.68, 0.34], [-0.24, 0.17], [0.24, 0.17], [0.68, 0.34]]:
				a = maxf(a, _blob(u, v, t[0], t[1], 0.24, 0.15))
			return a
		"hoof":
			# Two long halves, pointed at the front, a split between them.
			var a := 0.0
			for side in [-1.0, 1.0]:
				var du: float = u - float(side) * 0.42
				var tip: float = clampf(v / 0.9, 0.0, 1.0)
				a = maxf(a, _blob(du, v, 0.0, 0.5, 0.34 * (0.45 + 0.55 * tip), 0.46))
			return a
		"bird":
			# Three toes spread forward and a short one back, thin as a twig.
			var a := _stroke(u, v, 0.0, 0.62, -0.8, 0.12)
			a = maxf(a, _stroke(u, v, 0.0, 0.62, 0.0, 0.04))
			a = maxf(a, _stroke(u, v, 0.0, 0.62, 0.8, 0.12))
			return maxf(a, _stroke(u, v, 0.0, 0.62, 0.0, 0.95))
		"bug":
			# A beetle's tracks: three tiny dots each side of its line.
			var a := 0.0
			for side in [-1.0, 1.0]:
				for row in [0.2, 0.5, 0.8]:
					a = maxf(a, _blob(u, v, float(side) * 0.55, row, 0.22, 0.12))
			return a
		_:
			# The boot: the broad sole in front, a gap, the heel behind, soft at the edges.
			var sole := Vector2(u / 0.9, (v - 0.32) / 0.3).length()
			var heel := Vector2(u / 0.72, (v - 0.8) / 0.16).length()
			return maxf(1.0 - smoothstep(0.75, 1.0, sole), 1.0 - smoothstep(0.7, 1.0, heel))


## A soft oval of half-width `rx` and half-height `ry` about (cu, cv).
static func _blob(u: float, v: float, cu: float, cv: float, rx: float, ry: float) -> float:
	return 1.0 - smoothstep(0.7, 1.0, Vector2((u - cu) / rx, (v - cv) / ry).length())


## A thin line from (u0, v0) to (u1, v1).
static func _stroke(u: float, v: float, u0: float, v0: float, u1: float, v1: float) -> float:
	var a := Vector2(u0, v0)
	var d := Vector2(u1, v1) - a
	var p := Vector2(u, v) - a
	var t := clampf(p.dot(d) / d.length_squared(), 0.0, 1.0)
	return 1.0 - smoothstep(0.1, 0.22, (p - d * t).length())


## Frees the oldest print of the least important kind.
static func _drop_one() -> void:
	var worst := 0
	var worst_rank := 99
	for i in _live.size():
		var rank: int = PRIORITY.get(String((_live[i] as Node).get_meta("print_kind", "boot")), 3)
		if rank < worst_rank:
			worst_rank = rank
			worst = i
	(_live.pop_at(worst) as Node).queue_free()


## The snow is gone, or a new day starts: every print goes.
static func clear() -> void:
	for n in _live:
		if is_instance_valid(n):
			(n as Node).queue_free()
	_live.clear()


## Presses a print at `at` facing `heading` (radians about the up axis).
static func leave(world: Node3D, at: Vector3, heading: float, size := 1.0, kind := "boot", _daylight := 1.0) -> MeshInstance3D:
	_live = _live.filter(func(n): return is_instance_valid(n))
	while _live.size() >= MAX:
		_drop_one()
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = texture(kind)
	mat.albedo_color = GREY
	mat.roughness = 1.0
	mat.metallic_specular = 0.0
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh(kind)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("no_snow", true)
	world.add_child(mi)
	mi.global_position = Vector3(at.x, HEIGHT, at.z)
	mi.rotation.y = heading + FRONT
	mi.scale = Vector3(size, 1.0, size)
	mi.set_meta("print_kind", kind)
	_live.append(mi)
	return mi
