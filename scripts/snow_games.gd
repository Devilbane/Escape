class_name SnowGames
extends RefCounted
## What Pip and Pippi leave in the snow when they play in it (see KidPlay): the shape of a snow
## angel where one of them lay and swept arms and legs, and the big balls of snow they roll along
## and leave standing. Only a few of each stay (the oldest go first), and they melt with the snow
## (see melt, called from Outdoor.set_snow).

const GROUP := "snow_games"
## How many angels and rolled balls stay at once.
const MAX_ANGELS := 6
const MAX_LUMPS := 4
## The angels fade away below this much snow; the balls shrink with it and are gone below
## Snowman.MELTED.
const ANGEL_UNTIL := 0.3
## How high over the ground an angel lies, over the snow layer (as the footprints do).
const ANGEL_HEIGHT := 0.088
const ANGEL_DAY := Color(0.42, 0.48, 0.6, 0.55)

static var _angel_tex: Texture2D
static var _angel_mat: StandardMaterial3D
static var _lump_mat: StandardMaterial3D


## Leaves a snow angel centred at `at` (on the ground), its head the way `head` points (flat),
## `length` metres from head to feet.
static func angel(level: Node3D, at: Vector3, head: Vector3, length: float) -> MeshInstance3D:
	_trim(level, "angel", MAX_ANGELS)
	var quad := QuadMesh.new()
	quad.size = Vector2(length * 0.95, length)
	quad.orientation = PlaneMesh.FACE_Y
	quad.material = _angel_material()
	var mark := MeshInstance3D.new()
	mark.name = "SnowAngel"
	mark.mesh = quad
	mark.set_meta("no_snow", true)
	mark.set_meta("snow_game", "angel")
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mark.add_to_group(GROUP)
	level.add_child(mark)
	# The quad's -Z edge is the top of the texture, where the head is.
	mark.global_position = Vector3(at.x, level.global_position.y + ANGEL_HEIGHT, at.z)
	mark.rotation.y = atan2(-head.x, -head.z)
	return mark


## A ball of snow `radius` metres round, resting on the ground at `at`, that a child rolls along
## (see set_lump) and leaves standing.
static func lump(level: Node3D, at: Vector3, radius: float) -> MeshInstance3D:
	_trim(level, "lump", MAX_LUMPS)
	var ball := MeshInstance3D.new()
	ball.name = "SnowLump"
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 1.8
	sphere.radial_segments = 16
	sphere.rings = 8
	sphere.material = _lump_material()
	ball.mesh = sphere
	ball.set_meta("no_snow", true)
	ball.set_meta("snow_game", "lump")
	ball.add_to_group(GROUP)
	level.add_child(ball)
	set_lump(ball, at, radius)
	return ball


## Moves a rolled ball to `at` (on the ground) and lets it grow to `radius`.
static func set_lump(ball: MeshInstance3D, at: Vector3, radius: float) -> void:
	ball.scale = Vector3.ONE * radius
	ball.global_position = Vector3(at.x, at.y + radius * 0.85, at.z)
	ball.set_meta("radius", radius)


## The snow thins: the angels fade and go, the balls shrink and go with the last of it.
static func melt(level: Node, cover: float) -> void:
	for n in marks(level):
		var kind: String = n.get_meta("snow_game", "")
		if kind == "angel":
			if cover < ANGEL_UNTIL:
				n.queue_free()
		elif cover < Snowman.MELTED:
			n.queue_free()
		else:
			var full: float = n.get_meta("radius", 0.3)
			var size := full * clampf(0.4 + cover, 0.4, 1.0)
			var ball := n as Node3D
			var ground := ball.global_position.y - ball.scale.y * 0.85
			ball.scale = Vector3.ONE * size
			ball.global_position.y = ground + size * 0.85


## Everything the children left in the snow under `level`, oldest first.
static func marks(level: Node) -> Array[Node3D]:
	var out: Array[Node3D] = []
	if level.is_inside_tree():
		for n in level.get_tree().get_nodes_in_group(GROUP):
			if level.is_ancestor_of(n) and not n.is_queued_for_deletion():
				out.append(n)
	return out


## Makes room for one more of a kind: the oldest go.
static func _trim(level: Node, kind: String, most: int) -> void:
	var same := marks(level).filter(func(n: Node3D): return n.get_meta("snow_game", "") == kind)
	while same.size() >= most:
		(same.pop_front() as Node).queue_free()


static func _lump_material() -> StandardMaterial3D:
	if _lump_mat == null:
		_lump_mat = StandardMaterial3D.new()
		# The colour of the lying snow (see snow.gdshaderinc), not pure white.
		_lump_mat.albedo_color = Color(0.8, 0.83, 0.88)
		_lump_mat.roughness = 0.85
	return _lump_mat


static func _angel_material() -> StandardMaterial3D:
	if _angel_mat == null:
		_angel_mat = StandardMaterial3D.new()
		_angel_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_angel_mat.albedo_texture = angel_texture()
		_angel_mat.albedo_color = ANGEL_DAY
		_angel_mat.roughness = 1.0
		_angel_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _angel_mat


## The shape of a snow angel, pressed into the snow: head, body, the fan the arms swept and the
## skirt the legs swept, darker where it is pressed deepest. White with the shape in alpha.
static func angel_texture() -> Texture2D:
	if _angel_tex == null:
		var w := 64
		var h := 64
		var img := Image.create(w, h, true, Image.FORMAT_RGBA8)
		for y in h:
			for x in w:
				var u := (x + 0.5) / w - 0.5
				var v := (y + 0.5) / h
				img.set_pixel(x, y, Color(1, 1, 1, _angel_alpha(u, v)))
		img.generate_mipmaps()
		_angel_tex = ImageTexture.create_from_image(img)
	return _angel_tex


## How deep the angel is pressed at (u across, -0.5 to 0.5; v from head 0 to feet 1).
static func _angel_alpha(u: float, v: float) -> float:
	var a := 0.0
	# Head and body.
	a = maxf(a, _soft(Vector2(u / 0.11, (v - 0.1) / 0.09).length()))
	a = maxf(a, _soft(Vector2(u / 0.13, (v - 0.4) / 0.22).length()))
	# The wings: a fan swept by the arms from the shoulders, up past the head.
	var shoulder := Vector2(u, v - 0.3)
	var r := shoulder.length()
	var ang := atan2(absf(shoulder.x), -shoulder.y)
	if ang > 0.35 and ang < 2.1:
		a = maxf(a, 0.75 * _soft(r / 0.44) * _soft(absf(ang - 1.22) / 0.9))
	# The skirt: the legs swept out from the hips down to the feet.
	if v > 0.55:
		var spread := 0.1 + (v - 0.55) * 0.75
		a = maxf(a, 0.7 * _soft(absf(u) / spread) * _soft((v - 0.55) / 0.42))
	return clampf(a, 0.0, 1.0)


static func _soft(d: float) -> float:
	return 1.0 - smoothstep(0.75, 1.0, d)
