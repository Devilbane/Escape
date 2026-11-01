class_name HairLook
extends RefCounted
## Hair styles, hair colours and a head tattoo for characters built on the
## Rogue model (the hero, and the barber who sets them up).
##
## The model's hair is one smooth shape baked into the head mesh. For a
## shaved style its vertices are pulled onto a bald skull and coloured like
## the forehead, with a dark stubble from the shader. A mohawk adds a crest of
## hair locks along the middle of the skull; the shader cuts each lock into
## single strands of different lengths (shaders/hair.gdshaderinc). A tattoo
## is a word written in ink on the right side of a shaved head.
##
## A look is a Dictionary: {"style": one of STYLES, "color": a key of
## COLORS, "tattoo": the word, "" for none, "tattoo_shape": one of
## TATTOO_SHAPES, "show_helmet": false to leave a worn helmet or hat
## invisible, so the haircut shows (it still protects)}.

const SHADER := preload("res://shaders/hair.gdshader")
const FADE_SHADER := preload("res://shaders/hair_fade.gdshader")
const TATTOO_FONT := preload("res://assets/fonts/CinzelDecorative-Black.woff2")

const STYLES := ["natural", "mohawk", "bald"]
## Root, middle and tip colour of each hair colour. Rainbow and fire are
## drawn by the shader (MODES) and only use these for the stubble.
const COLORS := {
	"natural": [Color(0.32, 0.14, 0.09), Color(0.62, 0.33, 0.22), Color(0.84, 0.52, 0.34)],
	"black": [Color(0.05, 0.05, 0.06), Color(0.13, 0.12, 0.13), Color(0.26, 0.24, 0.26)],
	"blond": [Color(0.55, 0.4, 0.2), Color(0.88, 0.74, 0.45), Color(0.98, 0.9, 0.66)],
	"silver": [Color(0.45, 0.46, 0.5), Color(0.78, 0.8, 0.84), Color(0.97, 0.97, 1.0)],
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

## The natural and the shaved head mesh and the crest, by source mesh: built once.
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
	var shaved := style != "natural"
	head.mesh = _heads[source][1 if shaved else 0]
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
	crest.mesh = _heads[source][2]
	crest.set_meta("wanted", style == "mohawk")
	crest.visible = style == "mohawk" and not slot.get_meta("covered", false)
	var color: String = look.get("color", "natural")
	for mat: ShaderMaterial in [head.material_override, crest.material_override]:
		_set_color(mat, color)
	var head_mat := head.material_override as ShaderMaterial
	head_mat.set_shader_parameter("shaved", shaved)
	var word: String = look.get("tattoo", "")
	head_mat.set_shader_parameter("show_tattoo", shaved and word != "")
	if word != "":
		head_mat.set_shader_parameter("tattoo", _ink(head, word, look.get("tattoo_shape", "straight") == "arch"))


## A helmet or hat hides the crest (it would poke through).
static func cover(model: Node3D, covered: bool) -> void:
	var slot := head_slot(model)
	if slot == null:
		return
	slot.set_meta("covered", covered)
	var crest := slot.get_node_or_null("Crest") as Node3D
	if crest:
		crest.visible = crest.get_meta("wanted", false) and not covered


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
	# Short words big, long words smaller, so every word fits.
	var font_size := clampi(int(640.0 / maxf(word.length(), 3.0)), 40, 150)
	var widths: Array[float] = []
	var total := 0.0
	for ch in word:
		var w := TATTOO_FONT.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		widths.append(w)
		total += w
	# A half circle at most; a short word takes only part of it, so its
	# letters stay close together and easy to read.
	const RADIUS := 180.0
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


## The head mesh twice: with its natural hair, and shaved. Both carry in
## CUSTOM0 the position (for stubble and tattoo) and whether a vertex is hair.
static func _build_heads(source: Mesh) -> Array:
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
	var result := []
	for shaved in [false, true]:
		var a := arrays.duplicate()
		var v2: PackedVector3Array = verts.duplicate()
		var n2: PackedVector3Array = normals.duplicate()
		var uv2: PackedVector2Array = uvs.duplicate()
		var custom := PackedFloat32Array()
		custom.resize(verts.size() * 4)
		for v in verts.size():
			var p := verts[v]
			if hair[v] and shaved:
				var top := skull_point(p, shape)
				n2[v] = skull_point_normal(p, shape)
				p = top
				v2[v] = p
				uv2[v] = SCALP_UV
			elif shaved and blend[v] > 0.0:
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
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a, [], {}, flags)
		result.append(mesh)
	# The mohawk grows from this head's skull.
	result.append(crest_mesh(shape))
	return result


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
		var points: Array[Vector3] = []
		var dirs: Array[Vector3] = []
		var p := root - normal * 0.01 # Rooted just under the skin.
		for s in SEGMENTS + 1:
			points.append(p)
			dirs.append(dir)
			# Bend back and down a little, with a slight wave.
			var wobble := Vector3(rng.randfn(0.0, 0.03), rng.randfn(0.0, 0.03), rng.randfn(0.0, 0.03))
			dir = (dir + back * 0.05 + Vector3(0.0, -0.02, 0.0) + wobble).normalized()
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
	return st.commit()


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
