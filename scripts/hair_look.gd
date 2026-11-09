class_name HairLook
extends RefCounted
## Hair styles, hair colours and a head tattoo for characters built on the
## Rogue model (the hero, and the barber who sets them up).
##
## The model's hair is one smooth shape baked into the head mesh. The shader
## combs it into strands that grow from a crown at the back of the head, part
## on the left and fall in layered locks (shaders/hair.gdshaderinc). A short
## crop pulls that shape most of the way onto the skull. For a shaved style
## its vertices are pulled onto a bald skull and coloured like the forehead,
## with a dark stubble from the shader. A mohawk adds a crest of hair locks
## along the middle of the skull, which the shader cuts into single strands
## of different lengths; spikes are chunky tufts standing up on top of a
## short crop, dyed a little darker than the tufts so it never looks pale. A
## tattoo is a word written in ink on the right side of a shaved head. A
## woman (see BodyLook) ties her natural hair in a knot at the back.
##
## A look is a Dictionary: {"style": one of STYLES, "color": a key of
## COLORS, "tattoo": the word, "" for none, "tattoo_shape": one of
## TATTOO_SHAPES, "show_helmet": false to leave a worn helmet or hat
## invisible, so the haircut shows (it still protects)}.

const SHADER := preload("res://shaders/hair.gdshader")
const FADE_SHADER := preload("res://shaders/hair_fade.gdshader")
const TATTOO_FONT := preload("res://assets/fonts/CinzelDecorative-Black.woff2")

const STYLES := ["natural", "short", "spiky", "mohawk", "bald"]
## The styles whose sides are shaved, so the stubble and a tattoo show.
const SHAVED := ["mohawk", "bald"]
## How far a short crop pulls the hair onto the skull (1 would shave it).
const SHORT_CUT := 0.8
## Root, middle and tip colour of each hair colour. Rainbow and fire are
## drawn by the shader (MODES) and only use these for the stubble.
const COLORS := {
	"natural": [Color(0.32, 0.14, 0.09), Color(0.62, 0.33, 0.22), Color(0.84, 0.52, 0.34)],
	"black": [Color(0.05, 0.05, 0.06), Color(0.13, 0.12, 0.13), Color(0.26, 0.24, 0.26)],
	"blond": [Color(0.55, 0.4, 0.2), Color(0.88, 0.74, 0.45), Color(0.98, 0.9, 0.66)],
	"silver": [Color(0.45, 0.46, 0.5), Color(0.78, 0.8, 0.84), Color(0.97, 0.97, 1.0)],
	"ginger": [Color(0.38, 0.09, 0.03), Color(0.78, 0.29, 0.1), Color(0.95, 0.55, 0.26)],
	"red": [Color(0.35, 0.02, 0.03), Color(0.8, 0.08, 0.08), Color(1.0, 0.35, 0.3)],
	"green": [Color(0.04, 0.25, 0.06), Color(0.2, 0.75, 0.2), Color(0.65, 1.0, 0.45)],
	"blue": [Color(0.03, 0.08, 0.35), Color(0.15, 0.4, 0.95), Color(0.55, 0.85, 1.0)],
	"pink": [Color(0.45, 0.08, 0.3), Color(1.0, 0.4, 0.75), Color(1.0, 0.75, 0.9)],
	"purple": [Color(0.18, 0.04, 0.35), Color(0.5, 0.2, 0.85), Color(0.8, 0.6, 1.0)],
	"rainbow": [Color(0.15, 0.13, 0.14), Color(0.5, 0.5, 0.5), Color(0.8, 0.8, 0.8)],
	"fire": [Color(0.3, 0.03, 0.01), Color(1.0, 0.4, 0.05), Color(1.0, 0.9, 0.4)],
}
## Colours the shader draws itself: a rainbow running along the crest, and
## flickering flames that glow in the dark.
const MODES := {"rainbow": 1, "fire": 2}
## The writing runs straight, or arches over the ear in a half circle.
const TATTOO_SHAPES := ["straight", "arch"]
const DEFAULT := {"style": "natural", "color": "natural", "tattoo": "", "tattoo_shape": "straight", "show_helmet": true}
const TATTOO_MAX := 12

## The bald skull the shaved hair is pulled onto, in the head mesh's space.
const SKULL_CENTER := Vector3(0.0, 1.64, -0.06)
const SKULL_RADII := Vector3(0.425, 0.53, 0.45)
## Where the hair is painted in the texture, and a texel of forehead skin.
const HAIR_UV := Rect2(0.125, 0.0, 0.125, 0.25)
const SCALP_UV := Vector2(0.052, 0.105)

## The crest: how many locks, and where it starts and ends on the skull
## (angles along the middle of the skull: 0 is the top, positive is back).
const LOCKS := 150
const SEGMENTS := 6
const CREST_FRONT := -0.95
const CREST_BACK := 1.5

## Spikes: how many tufts grow out of the short crop's hair.
const SPIKES := 110
## How high up the head (0 at the ears, 1 on top) the tufts begin.
const TUFTS_FROM := 0.2
## The crop is shaved below this height, so no hair shows outside the tufts.
const FADE_FROM := 0.15

## The hair knot: where it sits (a direction from the skull's centre), how far
## out of the skull its middle is, and its size (across, up, and outwards).
const BUN_AT := Vector3(0.0, 0.3, -0.95)
const BUN_OUT := 0.13
const BUN_SIZE := Vector3(0.17, 0.15, 0.12)

## The two pigtails (look key "tails"): where each grows out of the skull (a
## direction from its centre, the left one; the right one mirrors it), how far
## out and down its middle hangs, and its size (across, along, outwards).
const TAIL_AT := Vector3(0.9, 0.22, -0.3)
const TAIL_OUT := 0.1
const TAIL_DROP := 0.24
const TAIL_SIZE := Vector3(0.17, 0.46, 0.17)

## The head meshes (natural, short, shaved), the locks (mohawk, spiky) and
## the hair knot (bun), by source mesh: built once.
static var _heads := {}


## Gives a Rogue model a look. The first call sets everything up; later calls
## only switch meshes and colours.
static func apply(model: Node3D, look: Dictionary) -> void:
	var head := _head(model)
	var slot := head_slot(model)
	if head == null or slot == null:
		return
	# The head the hair is cut from: a body look (BodyLook) may have set it.
	var source: Mesh = head.get_meta("hair_source") if head.has_meta("hair_source") else head.mesh
	if not head.has_meta("hair_source"):
		head.set_meta("hair_source", source)
	if not is_hair(head.material_override):
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		var base := source.surface_get_material(0) as StandardMaterial3D
		mat.set_shader_parameter("tex", base.albedo_texture if base else null)
		head.material_override = mat
	if not _heads.has(source):
		_heads[source] = _build_heads(source)
	var style: String = look.get("style", "natural")
	if not style in STYLES:
		style = "natural"
	var shaved := shows_scalp(style)
	var heads: Dictionary = _heads[source]
	# Spikes stand on a short crop whose sides are shaved off.
	head.mesh = heads.shaved if shaved else heads.fade if style == "spiky" else heads.short if style == "short" else heads.natural
	var crest := slot.get_node_or_null("Crest") as MeshInstance3D
	if crest == null:
		crest = MeshInstance3D.new()
		crest.name = "Crest"
		crest.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("crest", true)
		crest.material_override = mat
		crest.transform = slot.get_meta("bind")
		slot.add_child(crest)
	var locks := style in ["mohawk", "spiky"]
	if locks:
		crest.mesh = heads[style]
		# Spikes are solid tufts, grooved into a few thick strands.
		var crest_mat := crest.material_override as ShaderMaterial
		crest_mat.set_shader_parameter("tufts", style == "spiky")
		crest_mat.set_shader_parameter("strands", 4.0 if style == "spiky" else 6.0)
	crest.set_meta("wanted", locks)
	crest.visible = locks and not slot.get_meta("covered", false)
	var bun := slot.get_node_or_null("Bun") as MeshInstance3D
	if bun == null:
		bun = MeshInstance3D.new()
		bun.name = "Bun"
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("bun", true)
		mat.set_shader_parameter("tex", (head.material_override as ShaderMaterial).get_shader_parameter("tex"))
		bun.material_override = mat
		bun.transform = slot.get_meta("bind")
		slot.add_child(bun)
	bun.mesh = heads.bun
	var knot: bool = model.get_meta("sex", "male") == "female" and style == "natural"
	bun.set_meta("wanted", knot)
	bun.visible = knot and not slot.get_meta("covered", false)
	# Pigtails hang from both sides of the head; a girl who wears them has no knot.
	var tails := slot.get_node_or_null("Tails") as MeshInstance3D
	if tails == null:
		tails = MeshInstance3D.new()
		tails.name = "Tails"
		var tail_mat := ShaderMaterial.new()
		tail_mat.shader = SHADER
		tail_mat.set_shader_parameter("bun", true)
		tail_mat.set_shader_parameter("tex", (head.material_override as ShaderMaterial).get_shader_parameter("tex"))
		tails.material_override = tail_mat
		tails.transform = slot.get_meta("bind")
		slot.add_child(tails)
	tails.mesh = heads.tails
	var plaited: bool = bool(look.get("tails", false)) and style in ["natural", "short"]
	tails.set_meta("wanted", plaited)
	tails.visible = plaited and not slot.get_meta("covered", false)
	if plaited:
		bun.set_meta("wanted", false)
		bun.visible = false
	# A smile on the face of a child who has one (the lips of BodyLook are a woman's).
	var smile := slot.get_node_or_null("Smile") as MeshInstance3D
	if smile == null:
		smile = BodyLook.smile_mesh()
		smile.name = "Smile"
		smile.transform = slot.get_meta("bind")
		slot.add_child(smile)
	smile.visible = bool(look.get("smile", false))
	var color: String = look.get("color", "natural")
	for mat: ShaderMaterial in [head.material_override, crest.material_override, bun.material_override, tails.material_override]:
		_set_color(mat, color)
	var head_mat := head.material_override as ShaderMaterial
	head_mat.set_shader_parameter("shaved", shaved)
	head_mat.set_shader_parameter("freckles", bool(look.get("freckles", false)))
	head_mat.set_shader_parameter("ear_gem", bool(look.get("ear_gem", false)))
	head_mat.set_shader_parameter("short_hair", style in ["short", "spiky"])
	head_mat.set_shader_parameter("shaved_sides", style == "spiky")
	var word: String = look.get("tattoo", "")
	head_mat.set_shader_parameter("show_tattoo", shaved and word != "")
	if word != "":
		head_mat.set_shader_parameter("tattoo", _ink(head, word, look.get("tattoo_shape", "straight") == "arch"))


## Tints the skin of a Rogue model's face, ears and shaved scalp (white
## keeps the model's own); call after apply.
static func tint_skin(model: Node3D, tint: Color) -> void:
	var head := _head(model)
	if head and is_hair(head.material_override):
		(head.material_override as ShaderMaterial).set_shader_parameter("skin_tint", tint)


## Whether a style shaves the sides of the head, so a tattoo shows.
static func shows_scalp(style: String) -> bool:
	return style in SHAVED


## A helmet or hat hides the crest, the spikes and the hair knot (they would
## poke through).
static func cover(model: Node3D, covered: bool) -> void:
	var slot := head_slot(model)
	if slot == null:
		return
	slot.set_meta("covered", covered)
	for part in ["Crest", "Bun", "Tails"]:
		var locks := slot.get_node_or_null(part) as Node3D
		if locks:
			locks.visible = locks.get_meta("wanted", false) and not covered


## The point on the head bone everything worn on the head hangs from. Its
## "bind" meta turns the head mesh's space into the bone's.
static func head_slot(model: Node3D) -> BoneAttachment3D:
	var slot := model.find_child("HeadSlot", true, false) as BoneAttachment3D
	if slot:
		return slot
	var head := _head(model)
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if head == null or skeleton == null or head.skin == null:
		return null
	var bind := Transform3D.IDENTITY
	for i in head.skin.get_bind_count():
		if head.skin.get_bind_name(i) == "head":
			bind = head.skin.get_bind_pose(i)
	slot = BoneAttachment3D.new()
	slot.name = "HeadSlot"
	slot.bone_name = "head"
	slot.set_meta("bind", bind)
	skeleton.add_child(slot)
	return slot


## Swaps in the shader that can fade (for a sneaking hero), or back.
static func fade(mat: ShaderMaterial, alpha: float) -> void:
	mat.shader = FADE_SHADER if alpha > 0.0 else SHADER
	mat.set_shader_parameter("fade", alpha)


static func is_hair(mat: Material) -> bool:
	return mat is ShaderMaterial and (mat as ShaderMaterial).shader in [SHADER, FADE_SHADER]


## A clean copy of a look, with every field valid.
static func checked(look) -> Dictionary:
	var result := DEFAULT.duplicate()
	if look is Dictionary:
		if look.get("style", "") in STYLES:
			result.style = look.style
		if COLORS.has(look.get("color", "")):
			result.color = look.color
		result.tattoo = str(look.get("tattoo", "")).strip_edges().left(TATTOO_MAX)
		if look.get("tattoo_shape", "") in TATTOO_SHAPES:
			result.tattoo_shape = look.tattoo_shape
		result.show_helmet = bool(look.get("show_helmet", true))
		# Only a look that asks for them carries pigtails and freckles.
		if look.get("tails", false):
			result.tails = true
		if look.get("freckles", false):
			result.freckles = true
		if look.get("smile", false):
			result.smile = true
		if look.get("ear_gem", false):
			result.ear_gem = true
	return result


static func _head(model: Node3D) -> MeshInstance3D:
	return model.find_child("Rogue_Head", true, false) as MeshInstance3D


static func _set_color(mat: ShaderMaterial, color: String) -> void:
	var c: Array = COLORS.get(color, COLORS.natural)
	mat.set_shader_parameter("root_color", c[0])
	mat.set_shader_parameter("hair_color", c[1])
	mat.set_shader_parameter("tip_color", c[2])
	mat.set_shader_parameter("mode", MODES.get(color, 0))
	# The natural colour keeps the hair as the texture paints it.
	mat.set_shader_parameter("recolor", color != "natural")


## Writes the tattoo into a small texture: a hidden viewport with the word,
## drawn once, letter by letter, in a straight line or along a half circle.
## The shader lays it onto the side of the head.
const INK_SIZE := Vector2(512, 390)
## The tattoo's letter sizes in the ink texture: short words get the biggest.
const INK_FONT_MAX := 200
const INK_FONT_MIN := 40

static func _ink(head: MeshInstance3D, word: String, arch: bool) -> Texture2D:
	var view := head.get_node_or_null("TattooInk") as SubViewport
	if view == null:
		view = SubViewport.new()
		view.name = "TattooInk"
		view.size = Vector2i(INK_SIZE)
		view.transparent_bg = true
		view.disable_3d = true
		var word_node := Node2D.new()
		word_node.name = "Word"
		view.add_child(word_node)
		head.add_child(view)
	var word_node := view.get_node("Word") as Node2D
	for old in word_node.get_children():
		old.free()
	# As big as the word fits: short words fill the side of the head, long
	# words shrink until they fit the line or the half circle.
	const RADIUS := 180.0
	var room := RADIUS * PI * 0.9 / 1.15 if arch else INK_SIZE.x * 0.88
	var font_size := INK_FONT_MAX
	var widths: Array[float] = []
	var total := 0.0
	for attempt in 2:
		widths.clear()
		total = 0.0
		for ch in word:
			var w := TATTOO_FONT.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			widths.append(w)
			total += w
		if total <= room or attempt == 1:
			break
		font_size = maxi(int(font_size * room / total), INK_FONT_MIN)
	# A half circle at most; a short word takes only part of it, so its
	# letters stay close together and easy to read.
	var span := clampf(total * 1.15 / RADIUS, 0.0, PI * 0.9) if arch else 0.0
	var centre := Vector2(INK_SIZE.x * 0.5, INK_SIZE.y * 0.5 + (RADIUS * 0.45 if arch else 0.0))
	var x := -total * 0.5
	var angle := -span * 0.5
	for i in word.length():
		var label := Label.new()
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.text = word[i]
		label.add_theme_font_override("font", TATTOO_FONT)
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.size = Vector2(widths[i], font_size * 1.3)
		label.pivot_offset = label.size * 0.5
		var mid: Vector2
		if arch:
			# The letter's middle sits on the circle, turned to follow it.
			var a := angle + widths[i] * 0.5 / total * span
			mid = centre + Vector2(sin(a), -cos(a)) * RADIUS
			label.rotation = a
			angle += widths[i] / total * span
		else:
			mid = centre + Vector2(x + widths[i] * 0.5, 0.0)
			x += widths[i]
		label.position = mid - label.size * 0.5
		word_node.add_child(label)
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	return view.get_texture()


## The head mesh three times: with its natural hair, cut short, and shaved,
## and the locks of the mohawk and the spikes. Every head carries in CUSTOM0
## the position (for strands, stubble and tattoo) and whether a vertex is hair.
static func _build_heads(source: Mesh) -> Dictionary:
	var arrays := source.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var hair := _hair_vertices(verts, uvs, index)
	var rim := _face_rim(verts, hair, index)
	var shape := _skull_shape(rim)
	var blend := _face_blend(verts, hair, rim)
	var flags := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	if source is ArrayMesh and (source as ArrayMesh).surface_get_format(0) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS:
		flags |= Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
	var result := {}
	# The hair's triangles on the short crop, corner by corner, for the spikes.
	var crop := PackedVector3Array()
	for cut in ["natural", "short", "fade", "shaved"]:
		var shaved: bool = cut == "shaved"
		var a := arrays.duplicate()
		var v2: PackedVector3Array = verts.duplicate()
		var n2: PackedVector3Array = normals.duplicate()
		var uv2: PackedVector2Array = uvs.duplicate()
		var custom := PackedFloat32Array()
		custom.resize(verts.size() * 4)
		# Red marks the vertices the fade shaves.
		var marks := PackedColorArray()
		marks.resize(verts.size())
		for v in verts.size():
			var p := verts[v]
			var bare: bool = hair[v] and (shaved or (cut == "fade" and _low_on_crop(p, shape)))
			if bare:
				var top := skull_point(p, shape)
				n2[v] = skull_point_normal(p, shape)
				p = top
				v2[v] = p
				uv2[v] = SCALP_UV
				if cut == "fade":
					marks[v] = Color(1, 0, 0)
			elif hair[v] and cut in ["short", "fade"]:
				var top := skull_point(p, shape)
				n2[v] = normals[v].lerp(skull_point_normal(p, shape), SHORT_CUT).normalized()
				p = p.lerp(top, SHORT_CUT)
				v2[v] = p
			elif (shaved or cut == "fade") and blend[v] > 0.0:
				# The rim of the face grows into the skull, so the face is part
				# of the head instead of a mask on the front of it.
				n2[v] = normals[v].lerp(skull_point_normal(p, shape), blend[v]).normalized()
				p = p.lerp(skull_point(p, shape), blend[v])
				v2[v] = p
			custom[v * 4] = p.x
			custom[v * 4 + 1] = p.y
			custom[v * 4 + 2] = p.z
			custom[v * 4 + 3] = 1.0 if hair[v] else 0.0
		a[Mesh.ARRAY_VERTEX] = v2
		a[Mesh.ARRAY_NORMAL] = n2
		a[Mesh.ARRAY_TEX_UV] = uv2
		a[Mesh.ARRAY_TANGENT] = null
		a[Mesh.ARRAY_CUSTOM0] = custom
		if cut == "fade":
			a[Mesh.ARRAY_COLOR] = marks
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a, [], {}, flags)
		result[cut] = mesh
		if cut == "short":
			for t in range(0, index.size(), 3):
				if hair[index[t]] and hair[index[t + 1]] and hair[index[t + 2]]:
					for k in 3:
						crop.append(v2[index[t + k]])
	# The mohawk and the spikes grow from this head's skull.
	result.mohawk = crest_mesh(shape)
	result.spiky = spikes_mesh(crop)
	result.bun = bun_mesh(shape)
	result.tails = tails_mesh(shape)
	return result


## Whether a hair vertex lies below the tufts once cropped: the fade shaves it.
static func _low_on_crop(p: Vector3, shape: Array) -> bool:
	var cropped := p.lerp(skull_point(p, shape), SHORT_CUT)
	return ((cropped - SKULL_CENTER) / SKULL_RADII).normalized().y < FADE_FROM


## The hair knot: a squashed ball on the back of the head, sunk a little into
## the hair. CUSTOM0 carries the position and marks it all as hair; COLOR the
## point on a unit ball (0..1 per axis, z outwards), for the wound strands;
## the UV is a texel of hair in the texture.
static func bun_mesh(shape: Array) -> ArrayMesh:
	var root := skull_point(SKULL_CENTER + BUN_AT.normalized() * SKULL_RADII, shape)
	var out := skull_point_normal(root, shape)
	return _hair_ball([[root, out, BUN_OUT, 0.0]], BUN_SIZE)


## The two pigtails: long balls of wound hair, one on each side of the head,
## hanging down past the cheeks (same strands as the knot).
static func tails_mesh(shape: Array) -> ArrayMesh:
	var balls := []
	for mirror in [1.0, -1.0]:
		var dir := Vector3(TAIL_AT.x * mirror, TAIL_AT.y, TAIL_AT.z).normalized()
		var root := skull_point(SKULL_CENTER + dir * SKULL_RADII, shape)
		balls.append([root, skull_point_normal(root, shape), TAIL_OUT, TAIL_DROP])
	return _hair_ball(balls, TAIL_SIZE)


## Squashed balls of hair, each [root on the skull, outward normal, how far out
## its middle sits, how far it hangs down], sunk a little into the hair.
## CUSTOM0 carries the position and marks it all as hair; COLOR the point on a
## unit ball (0..1 per axis, z outwards), for the wound strands; the UV is a
## texel of hair in the texture.
static func _hair_ball(balls: Array, size: Vector3) -> ArrayMesh:
	var all := PackedVector3Array()
	var all_normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var custom := PackedFloat32Array()
	var indices := PackedInt32Array()
	for b in balls:
		var out: Vector3 = b[1]
		var side := Vector3.UP.cross(out).normalized()
		var up := out.cross(side).normalized()
		var centre: Vector3 = b[0] + out * b[2] + Vector3.DOWN * b[3]
		var ball := SphereMesh.new()
		ball.radial_segments = 16
		ball.rings = 8
		var arrays := ball.get_mesh_arrays()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var first := all.size()
		# The ball's own y is its axis: it points out of the head.
		for v in verts.size():
			var q := verts[v] / 0.5
			var local := Vector3(q.x, q.z, q.y)
			var p := centre + side * local.x * size.x + up * local.y * size.y + out * local.z * size.z
			var n := normals[v]
			n = (side * n.x / size.x + up * n.z / size.y + out * n.y / size.z).normalized()
			all.append(p)
			all_normals.append(n)
			colors.append(Color(local.x * 0.5 + 0.5, local.y * 0.5 + 0.5, local.z * 0.5 + 0.5))
			uvs.append(HAIR_UV.get_center())
			custom.append_array([p.x, p.y, p.z, 1.0])
		for i in arrays[Mesh.ARRAY_INDEX]:
			indices.append(first + i)
	var data := []
	data.resize(Mesh.ARRAY_MAX)
	data[Mesh.ARRAY_VERTEX] = all
	data[Mesh.ARRAY_NORMAL] = all_normals
	data[Mesh.ARRAY_COLOR] = colors
	data[Mesh.ARRAY_TEX_UV] = uvs
	data[Mesh.ARRAY_CUSTOM0] = custom
	data[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	return mesh


## How far each face vertex is pulled onto the skull of a shaved head: fully
## on the face's outer rim (which the hair used to cover), less and less
## further in, and not at all from FACE_BLEND inwards, so eyes, nose and
## mouth keep their shape.
const FACE_BLEND := 0.1

## The face's outer rim, the edge the hair used to cover: the longest run of
## open edges of the face (the eyes, the nose and the ears have small rings
## of their own).
static func _face_rim(verts: PackedVector3Array, hair: Array[bool], index: PackedInt32Array) -> Array[Vector3]:
	var n := verts.size()
	var keys: Array[Vector3i] = []
	keys.resize(n)
	for i in n:
		keys[i] = Vector3i((verts[i] * 1000.0).round())
	# Edges used by only one triangle of the face are its open edges.
	var count := {}
	for t in range(0, index.size(), 3):
		if hair[index[t]] or hair[index[t + 1]] or hair[index[t + 2]]:
			continue
		for k in 3:
			var a := keys[index[t + k]]
			var b := keys[index[t + (k + 1) % 3]]
			var edge := [a, b] if str(a) < str(b) else [b, a]
			count[edge] = count.get(edge, 0) + 1
	var links := {}
	for edge in count:
		if count[edge] != 1:
			continue
		for k in 2:
			if not links.has(edge[k]):
				links[edge[k]] = []
			links[edge[k]].append(edge[1 - k])
	var seen := {}
	var rim := []
	for start in links:
		if seen.has(start):
			continue
		var ring := []
		var todo := [start]
		while not todo.is_empty():
			var key = todo.pop_back()
			if seen.has(key):
				continue
			seen[key] = true
			ring.append(key)
			todo.append_array(links[key])
		if ring.size() > rim.size():
			rim = ring
	var rim_points: Array[Vector3] = []
	for key in rim:
		rim_points.append(Vector3(key) / 1000.0)
	return rim_points


static func _face_blend(verts: PackedVector3Array, hair: Array[bool], rim_points: Array[Vector3]) -> PackedFloat32Array:
	var n := verts.size()
	var result := PackedFloat32Array()
	result.resize(n)
	for i in n:
		if hair[i]:
			continue
		var nearest := INF
		for q in rim_points:
			nearest = minf(nearest, verts[i].distance_to(q))
		if nearest < FACE_BLEND:
			result[i] = smoothstep(FACE_BLEND, 0.0, nearest)
	return result


## How far round the skull (in radians) the face's rim still shapes it.
const SKULL_SPREAD := 0.35

## The skull of a shaved head: the ellipsoid, swollen (or shrunk) towards the
## face so that it meets the face's rim at the rim's own height, and the skin
## runs on from the face without a step. Returns the directions of the rim
## points from the skull's centre and how far out each one lies (1 = on the
## ellipsoid).
static func _skull_shape(rim: Array[Vector3]) -> Array:
	var dirs := PackedVector3Array()
	var reach := PackedFloat32Array()
	for q in rim:
		var d := (q - SKULL_CENTER) / SKULL_RADII
		dirs.append(d.normalized())
		reach.append(d.length())
	return [dirs, reach]


## The point of the shaped skull straight out from its centre through p.
static func skull_point(p: Vector3, shape: Array) -> Vector3:
	var u := ((p - SKULL_CENTER) / SKULL_RADII).normalized()
	if u == Vector3.ZERO:
		u = Vector3.UP
	var dirs: PackedVector3Array = shape[0]
	var reach: PackedFloat32Array = shape[1]
	var total := 0.0
	var swell := 0.0
	var nearest := 0.0
	for i in dirs.size():
		var angle := acos(clampf(dirs[i].dot(u), -1.0, 1.0))
		var w := exp(-pow(angle / SKULL_SPREAD, 2.0))
		total += w
		swell += w * (reach[i] - 1.0)
		nearest = maxf(nearest, w)
	var s := 1.0 + (swell / total * nearest if total > 0.000001 else 0.0)
	return SKULL_CENTER + u * SKULL_RADII * s


## The outward normal of the shaped skull at its point through p.
static func skull_point_normal(p: Vector3, shape: Array) -> Vector3:
	var n := skull_normal(on_skull(p))
	var t1 := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
	var t2 := n.cross(t1)
	const STEP := 0.01
	var a := skull_point(p + t1 * STEP, shape) - skull_point(p - t1 * STEP, shape)
	var b := skull_point(p + t2 * STEP, shape) - skull_point(p - t2 * STEP, shape)
	var result := a.cross(b).normalized()
	return result if result.dot(n) > 0.0 else -result


## Pulls a point straight in or out from the skull's centre onto the skull.
static func on_skull(p: Vector3) -> Vector3:
	var d := p - SKULL_CENTER
	var k := (d / SKULL_RADII).length()
	if k < 0.0001:
		return SKULL_CENTER + Vector3.UP * SKULL_RADII.y
	return SKULL_CENTER + d / k


static func skull_normal(p: Vector3) -> Vector3:
	return ((p - SKULL_CENTER) / (SKULL_RADII * SKULL_RADII)).normalized()


## Locks of hair along the middle of the skull. They stand up and lean back a
## little, longest on top, and fan out slightly to the sides. Each lock is a
## tapering ribbon: UV.x runs across it, UV.y from the root (0) to the tip (1);
## COLOR.r is a random number per lock, COLOR.g its shade and COLOR.b where
## it grows, from the forehead (0) to the nape (1).
static func crest_mesh(shape: Array) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in LOCKS:
		var t := (i + rng.randf()) / LOCKS
		var theta := lerpf(CREST_FRONT, CREST_BACK, t)
		var x := clampf(rng.randfn(0.0, 0.035), -0.09, 0.09)
		var root := skull_point(SKULL_CENTER + Vector3(x / SKULL_RADII.x, cos(theta), -sin(theta)).normalized() * SKULL_RADII, shape)
		var normal := skull_point_normal(root, shape)
		# Backwards along the middle of the skull.
		var back := Vector3(0.0, -sin(theta) * SKULL_RADII.y, -cos(theta) * SKULL_RADII.z).normalized()
		var lock_length := (0.12 + 0.32 * pow(sin(PI * clampf(t * 0.9 + 0.08, 0.0, 1.0)), 0.7)) * (0.8 + 0.35 * rng.randf())
		var dir := (normal + back * 0.12 + Vector3(x * 4.3, 0.0, 0.0)).normalized()
		# The ribbon lies mostly along the crest, some locks turned a little.
		var side := dir.cross(back).normalized()
		var turn := rng.randfn(0.0, 0.5)
		var across := back * cos(turn) + side * sin(turn)
		across = (across - dir * across.dot(dir)).normalized()
		var width := 0.05 + 0.02 * rng.randf()
		var color := Color(rng.randf(), rng.randf(), t)
		# Rooted just under the skin, bending back and down a little.
		_lock(st, root - normal * 0.01, dir, across, lock_length, width, color, rng, back * 0.05 + Vector3(0.0, -0.02, 0.0), 0.03)
	return st.commit()


## Tufts of hair standing up on top of a short crop: chunky cones, rooted at
## random points of the crop's hair triangles (crop: their corners) above
## TUFTS_FROM, that clump together, stand up and sweep back, longest on top.
## The back and the sides stay a short crop, so nothing sticks into the ears
## or the collar. UV.x runs round a tuft, UV.y from the root (0) to the tip
## (1); COLOR.r is a random number per tuft, COLOR.g its shade and COLOR.b
## runs from the forehead (0) to the back of the head (1).
static func spikes_mesh(crop: PackedVector3Array) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Bigger triangles get more tufts.
	var areas := PackedFloat32Array()
	var total := 0.0
	for t in range(0, crop.size(), 3):
		total += (crop[t + 1] - crop[t]).cross(crop[t + 2] - crop[t]).length()
		areas.append(total)
	if total <= 0.0:
		return st.commit()
	var placed := 0
	var tries := 0
	while placed < SPIKES and tries < SPIKES * 20:
		tries += 1
		var t := areas.bsearch(rng.randf() * total) * 3
		var a := rng.randf()
		var b := rng.randf()
		if a + b > 1.0:
			a = 1.0 - a
			b = 1.0 - b
		var root := crop[t] + (crop[t + 1] - crop[t]) * a + (crop[t + 2] - crop[t]) * b
		var out := ((root - SKULL_CENTER) / SKULL_RADII).normalized()
		if out.y < TUFTS_FROM:
			continue
		placed += 1
		var normal := skull_normal(on_skull(root))
		# How high up: 0 where the tufts start, 1 on top; and how far forward.
		var up := clampf((out.y - TUFTS_FROM) / (1.0 - TUFTS_FROM), 0.0, 1.0)
		var front := clampf(out.z, 0.0, 1.0)
		var lock_length := lerpf(0.12, 0.3, smoothstep(0.0, 0.7, up)) * (0.85 + 0.3 * rng.randf())
		# Over the forehead they stand up rather than into the eyes; the
		# lowest ones lean back over the crop.
		var dir := (normal + Vector3.UP * (0.25 + 0.6 * front) * up + Vector3(0.0, 0.0, -0.4 - 0.2 * front)).normalized()
		dir = (dir + Vector3(rng.randfn(0.0, 0.12), rng.randfn(0.0, 0.08), rng.randfn(0.0, 0.12))).normalized()
		var radius := lerpf(0.08, 0.11, up) * (0.85 + 0.3 * rng.randf())
		_tuft(st, root - dir * 0.03, dir, lock_length, radius,
				Color(rng.randf(), rng.randf(), clampf(0.5 - out.z * 0.6, 0.0, 1.0)), Vector3(0.0, -0.03, -0.05))
	return st.commit()


## One cone of hair from root along dir, bending by bend at every segment, as
## round as TUFT_SIDES allows and coming to a point.
const TUFT_SIDES := 6

static func _tuft(st: SurfaceTool, root: Vector3, dir: Vector3, lock_length: float, radius: float,
		color: Color, bend: Vector3) -> void:
	# The wide side of the clump faces forward: it spreads from ear to ear.
	var side := Vector3.RIGHT if absf(dir.x) < 0.8 else Vector3.BACK
	var points: Array[Vector3] = []
	var dirs: Array[Vector3] = []
	var p := root
	var d := dir
	for s in SEGMENTS + 1:
		points.append(p)
		dirs.append(d)
		d = (d + bend).normalized()
		p += d * lock_length / SEGMENTS
	for s in SEGMENTS:
		var v0 := float(s) / SEGMENTS
		var v1 := float(s + 1) / SEGMENTS
		# Full near the root, then tapering to a point.
		var r0 := radius * pow(1.0 - v0, 0.9)
		var r1 := radius * pow(1.0 - v1, 0.9)
		for k in TUFT_SIDES:
			var u0 := float(k) / TUFT_SIDES
			var u1 := float(k + 1) / TUFT_SIDES
			var ring := []
			for corner in [[s, u0, r0, v0], [s, u1, r0, v0], [s + 1, u1, r1, v1], [s + 1, u0, r1, v1]]:
				var at: Vector3 = dirs[corner[0]]
				var x := side - at * side.dot(at)
				x = x.normalized()
				var y := at.cross(x)
				var angle: float = corner[1] * TAU
				var n := (x * cos(angle) / 1.15 + y * sin(angle) / 0.6).normalized()
				# Lean the normal towards the tip, the way a cone faces.
				var n_tilt := (n + at * radius / lock_length).normalized()
				# Wider across than deep, like a clump of combed hair.
				var off: Vector3 = (x * cos(angle) * 1.15 + y * sin(angle) * 0.6) * corner[2]
				ring.append([points[corner[0]] + off, Vector2(corner[1], corner[3]), n_tilt])
			for c in [0, 2, 1, 0, 3, 2]:
				st.set_color(color)
				st.set_uv(ring[c][1])
				st.set_normal(ring[c][2])
				st.add_vertex(ring[c][0])


## One tapering ribbon of hair from root along dir, bending by bend at every
## segment (and a little at random, with a slight wave).
static func _lock(st: SurfaceTool, root: Vector3, dir: Vector3, across: Vector3, lock_length: float, width: float,
		color: Color, rng: RandomNumberGenerator, bend: Vector3, wobble: float) -> void:
	var points: Array[Vector3] = []
	var dirs: Array[Vector3] = []
	var p := root
	for s in SEGMENTS + 1:
		points.append(p)
		dirs.append(dir)
		var wob := Vector3(rng.randfn(0.0, wobble), rng.randfn(0.0, wobble), rng.randfn(0.0, wobble))
		dir = (dir + bend + wob).normalized()
		p += dir * lock_length / SEGMENTS
	for s in SEGMENTS:
		var v0 := float(s) / SEGMENTS
		var v1 := float(s + 1) / SEGMENTS
		var w0 := width * (1.0 - 0.85 * v0)
		var w1 := width * (1.0 - 0.85 * v1)
		var a0 := points[s] - across * w0
		var a1 := points[s] + across * w0
		var b0 := points[s + 1] - across * w1
		var b1 := points[s + 1] + across * w1
		var n0 := across.cross(dirs[s]).normalized()
		var n1 := across.cross(dirs[s + 1]).normalized()
		for corner in [[a0, 0.0, v0, n0], [a1, 1.0, v0, n0], [b1, 1.0, v1, n1], [a0, 0.0, v0, n0], [b1, 1.0, v1, n1], [b0, 0.0, v1, n1]]:
			st.set_color(color)
			st.set_uv(Vector2(corner[1], corner[2]))
			st.set_normal(corner[3])
			st.add_vertex(corner[0])


## The vertices of the hair: the biggest connected piece painted with the
## hair colour (the eyebrows are smaller pieces of the same colour).
static func _hair_vertices(verts: PackedVector3Array, uvs: PackedVector2Array, index: PackedInt32Array) -> Array[bool]:
	var n := verts.size()
	var painted: Array[bool] = []
	painted.resize(n)
	var parent: Array[int] = []
	parent.resize(n)
	for i in n:
		parent[i] = i
		painted[i] = HAIR_UV.has_point(uvs[i])
	# Vertices at the same place belong together (the mesh is split at UV seams).
	var first := {}
	for i in n:
		if not painted[i]:
			continue
		var key := Vector3i((verts[i] * 1000.0).round())
		if first.has(key):
			_join(parent, i, first[key])
		else:
			first[key] = i
	for t in range(0, index.size(), 3):
		var a := index[t]
		var b := index[t + 1]
		var c := index[t + 2]
		if painted[a] and painted[b] and painted[c]:
			_join(parent, a, b)
			_join(parent, a, c)
	var sizes := {}
	var biggest := -1
	for i in n:
		if painted[i]:
			var r := _root(parent, i)
			sizes[r] = sizes.get(r, 0) + 1
			if biggest < 0 or sizes[r] > sizes[biggest]:
				biggest = r
	var result: Array[bool] = []
	result.resize(n)
	for i in n:
		result[i] = painted[i] and _root(parent, i) == biggest
	return result


static func _root(parent: Array[int], i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i


static func _join(parent: Array[int], a: int, b: int) -> void:
	parent[_root(parent, a)] = _root(parent, b)
