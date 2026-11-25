class_name TownsfolkLook
extends RefCounted
## A look of their own for every person of the village: a skin tone, a haircut and hair colour for
## the women and men built on the Rogue model, glasses or a monocle for some, and a hat colour for
## those who wear a hat, so no two townsfolk share a face. The look of a named person is fixed
## (the table LOOKS), so they look the same on every playthrough. Pip and Pippi are not in the table:
## their hand-made looks (see Villager.ROLES) stay exactly as they are, and a haircut written into a
## role is never replaced.
##
## Villager._ready calls apply once the model is dressed. Glasses are built in code in the chunky
## low-poly shapes of WinterWear and hung from the head bone, so they move with the head.

const TAG := "Glasses"
## Marks a head that wears its own plain material (see _own_head).
const OWN_HEAD := "own_head"
## Where the eyes are in the skeleton's rest space: the same on every model (measured from renders of
## the Rogue, Mage and Knight faces), while the head's box differs from model to model.
const EYE_Y := 1.585

## Skin tones, a multiplier on the model's own skin (white keeps it). No tone is above Pip and Pippi's SKIN_ROSY
## in red or in blue/green: the model's skin is already bright in the midday sun, so a pale multiplier washes it out.
const FAIR := Color(0.95, 0.8, 0.74)
const PALE := Color(0.94, 0.77, 0.7)
const ASHEN := Color(0.93, 0.82, 0.8)
const WARM := Color(0.95, 0.86, 0.77)
const RUDDY := Color(0.95, 0.74, 0.66)
const OLIVE := Color(0.86, 0.78, 0.62)
const TAN := Color(0.88, 0.72, 0.56)
const BRONZE := Color(0.78, 0.58, 0.45)
const BROWN := Color(0.68, 0.48, 0.36)
const DARK := Color(0.58, 0.4, 0.31)
const DEEP := Color(0.5, 0.34, 0.26)
const SUNBURNT := Color(0.9, 0.66, 0.5)

## The frames, by kind: a pair of round lenses, square ones, half-moon reading glasses and a single
## monocle on its chain.
const GLASSES := ["round", "square", "half", "monocle"]
const IRON := Color(0.14, 0.11, 0.09)
const GOLD := Color(0.86, 0.69, 0.26)
const SILVER := Color(0.74, 0.76, 0.8)

## skin: tone; glasses: kind or none; frame: its colour; hat: the colour of the hat, helmet or cape
## (the third of the role's colours when it is not given); hair: haircut and colour of a Rogue
## model whose role names none; dye: a hair colour (a key of HairLook.COLORS, or its own root, middle and tip) for a model whose hair
## is painted into its texture (the Knight), so two of them with bare heads do not look alike.
const LOOKS := {
	"0": {"skin": PALE},
	"1": {"skin": BRONZE},
	"2": {"skin": TAN},
	"3": {"skin": SUNBURNT, "hat": Color(0.3, 0.42, 0.28)},
	"4": {"skin": OLIVE},
	"5": {"skin": RUDDY},
	"6": {"skin": WARM, "glasses": "round", "frame": GOLD, "hair": {"style": "natural", "color": "silver"}},
	"8": {"skin": ASHEN, "glasses": "monocle", "frame": GOLD, "hat": Color(0.22, 0.2, 0.46)},
	"9": {"skin": FAIR},
	"K": {"skin": BROWN, "dye": "black"},
	"¢": {"skin": Color(0.95, 0.82, 0.73), "glasses": "square", "frame": IRON},
	"µ": {"skin": Color(0.96, 0.78, 0.68), "glasses": "round", "frame": SILVER},
	"O": {"skin": DARK},
	"G": {"skin": Color(0.72, 0.52, 0.4)},
	"M": {"skin": Color(0.92, 0.78, 0.64)},
	"Z": {"skin": DEEP},
	# Matthes, the street sweeper: weathered by a life outdoors, an ordinary tone (a multiplier above 1 made his face glow).
	"sweeper": {"skin": WARM},
	"Y": {"skin": Color(0.93, 0.79, 0.74), "glasses": "half", "frame": SILVER, "hat": Color(0.16, 0.36, 0.28)},
	"S": {"skin": Color(0.82, 0.66, 0.52)},
	"%": {"skin": Color(0.7, 0.55, 0.42), "hat": Color(0.45, 0.15, 0.35)},
}


## The look of one person: {} for someone whose own look stays (Pip, Pippi), otherwise skin, glasses
## ("" for none), frame, hat (a Color, or null for the role's own), hair ({} for the role's own) and
## dye ("" for the model's own painted hair).
## Someone who is not in the table gets a look from the letter alone, the same every time.
static func look_for(role: String, info: Dictionary) -> Dictionary:
	if info.has("skin"):
		return {}
	var base: Dictionary = LOOKS.get(role, {})
	if base.is_empty():
		var h := absi(hash(role))
		base = {"skin": Color.from_hsv(0.05 + (h % 7) * 0.004, 0.26 + (h / 7 % 5) * 0.07, 0.95 - (h / 35 % 6) * 0.07)}
	var hair: Dictionary = {}
	if info.model == "Rogue" and not info.has("hair") and base.has("hair"):
		hair = base.hair
	return {
		"skin": base.skin,
		"glasses": base.get("glasses", ""),
		"frame": base.get("frame", IRON),
		"hat": base.get("hat", null),
		"hair": hair,
		"dye": base.get("dye", "") if info.model != "Rogue" else "",
	}


## Skin, hat colour and glasses on an already dressed model (the haircut goes on earlier, see hair_of).
static func apply(model: Node3D, info: Dictionary, look: Dictionary) -> void:
	if look.is_empty():
		return
	_tint_skin(model, info, look.skin, str(look.get("dye", "")) != "")
	if str(look.get("dye", "")) != "":
		_dye_hair(model, look.dye)
	if look.hat != null:
		_dye_hat(model, info, look.hat)
	if look.glasses != "":
		_put_on_glasses(model, look.glasses, look.frame)


## The haircut and colour of a role, as the villager wears it.
static func hair_of(info: Dictionary, look: Dictionary) -> Dictionary:
	if info.model != "Rogue":
		return {}
	if not look.is_empty() and not look.hair.is_empty():
		return HairLook.checked(look.hair)
	return HairLook.checked(info.get("hair", HairLook.DEFAULT))


## A head that shares GearLook's outfit material with its look-alikes keeps sharing it (one material
## for many heads, see tests/surface_detail.gd), unless its hair is dyed: then it gets its own.
static func _tint_skin(model: Node3D, info: Dictionary, tone: Color, dyed := false) -> void:
	if info.model == "Rogue":
		HairLook.tint_skin(model, tone)
		return
	for mi: MeshInstance3D in model.find_children("*_Head", "MeshInstance3D", true, false):
		var own: StandardMaterial3D = _own_head(mi) if dyed or mi.has_meta(OWN_HEAD) else null
		if own != null:
			own.albedo_color = own.albedo_color * tone
		elif mi.get_active_material(0) is StandardMaterial3D:
			var plain: StandardMaterial3D = mi.get_active_material(0).duplicate()
			plain.albedo_color = plain.albedo_color * tone
			mi.material_override = plain


## The head's own plain material, made once: GearLook.dress_body gives every head of the same
## texture and dye one shared shader material (cloth grain is not wanted on a face anyway), so a
## skin tone or a hair dye set on that would land on every such head, or on none. Null for a head
## with no plain material to start from.
static func _own_head(mi: MeshInstance3D) -> StandardMaterial3D:
	if mi.has_meta(OWN_HEAD):
		return mi.material_override as StandardMaterial3D
	var active := mi.get_active_material(0)
	var plain: StandardMaterial3D = null
	if active is StandardMaterial3D:
		plain = (active as StandardMaterial3D).duplicate()
	elif mi.mesh != null and mi.mesh.surface_get_material(0) is StandardMaterial3D:
		plain = mi.mesh.surface_get_material(0).duplicate()
		var dye = (active as ShaderMaterial).get_shader_parameter("dye") if active is ShaderMaterial else null
		if dye is Color:
			plain.albedo_color = dye
		elif dye is Vector3:
			plain.albedo_color = Color(dye.x, dye.y, dye.z)
	if plain == null:
		return null
	mi.material_override = plain
	mi.set_meta(OWN_HEAD, true)
	return plain


## Dyes the hair painted into the head's texture (and the eyebrows, painted in the same spot) with
## a hair colour of HairLook: a detail layer over the hair's patch of the texture, so the texture
## itself is never read back. Root colour at the bottom of the patch, tips at the top.
static func _dye_hair(model: Node3D, colour: Variant) -> void:
	for mi: MeshInstance3D in model.find_children("*_Head", "MeshInstance3D", true, false):
		var dyed := _own_head(mi)
		if dyed == null:
			continue
		dyed.detail_enabled = true
		dyed.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MIX
		dyed.detail_uv_layer = BaseMaterial3D.DETAIL_UV_1
		dyed.detail_albedo = dye_texture(colour)
		# Matt and barely shiny: the painted hair must not gleam like plastic.
		dyed.roughness = maxf(dyed.roughness, 0.85)
		dyed.metallic_specular = minf(dyed.metallic_specular, 0.2)


static var _dyes := {}


## A texture as big as the head's atlas in small: clear everywhere but the hair's patch
## (HairLook.HAIR_UV), which holds the colour's root-to-tip gradient.
static func dye_texture(colour: Variant) -> Texture2D:
	var key := str(colour)
	if _dyes.has(key):
		return _dyes[key]
	const SIZE := 256
	var shades: Array = colour if colour is Array else HairLook.COLORS.get(colour, HairLook.COLORS.natural)
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var patch := Rect2i(HairLook.HAIR_UV.position * SIZE, HairLook.HAIR_UV.size * SIZE)
	for y in range(patch.position.y, patch.end.y):
		var t := 1.0 - float(y - patch.position.y) / float(patch.size.y - 1)
		var c: Color = shades[0].lerp(shades[1], t * 2.0) if t < 0.5 else shades[1].lerp(shades[2], t * 2.0 - 1.0)
		for x in range(patch.position.x, patch.end.x):
			# Strands: each column its own shade, a few finer lines and a
			# little wave along its length, so the hair is not one flat tone.
			var col := float(x - patch.position.x)
			var strand := 0.78 + 0.34 * fposmod(sin(col * 12.9898) * 43758.5453, 1.0)
			var fine := 0.92 + 0.08 * sin(col * 2.4 + float(y) * 0.12)
			var shade := strand * fine
			img.set_pixel(x, y, Color(minf(c.r * shade, 1.0), minf(c.g * shade, 1.0), minf(c.b * shade, 1.0), c.a))
	var tex := ImageTexture.create_from_image(img)
	_dyes[key] = tex
	return tex


## Dyes the hat, helmet or cape the role shows.
static func _dye_hat(model: Node3D, info: Dictionary, colour: Color) -> void:
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var part := String(mi.name)
		if not part in info.show:
			continue
		if part.ends_with("Hat") or part.ends_with("Cape") or part.ends_with("Helmet"):
			var mat := mi.get_active_material(0)
			if mat is StandardMaterial3D:
				var dyed: StandardMaterial3D = mat.duplicate()
				dyed.albedo_color = colour
				mi.material_override = dyed


# --- Glasses -----------------------------------------------------------------------

## Hangs glasses on the face (once).
static func _put_on_glasses(model: Node3D, kind: String, frame: Color) -> void:
	if model.find_child(TAG, true, false) != null:
		return
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return
	var slot := BoneAttachment3D.new()
	slot.name = TAG + "_head"
	slot.bone_name = "head"
	var bind := skeleton.get_bone_global_rest(skeleton.find_bone("head")).affine_inverse()
	skeleton.add_child(slot)
	var mi := MeshInstance3D.new()
	mi.name = TAG
	mi.mesh = glasses_mesh(kind, WinterWear._head_box(model), frame)
	mi.transform = bind
	slot.add_child(mi)


## The frames in the skeleton's rest space, at the eyes (see EYE_Y), as wide as the head's box allows (the face looks along +Z).
static func glasses_mesh(kind: String, box: AABB, frame: Color) -> ArrayMesh:
	var st := WinterWear._start()
	var cx := box.get_center().x
	var eye := EYE_Y
	var z := box.end.z + 0.03
	var rx := box.size.x * 0.5
	var gap := 0.2
	var r := 0.13
	var thick := 0.022
	match kind:
		"monocle":
			# One ring over the right eye, a thin chain hanging from it down the cheek.
			_ring(st, Vector3(cx - gap, eye, z), r, thick, frame, 8, 1.0)
			_bar(st, Vector3(cx - gap + 0.02, eye - r, z), Vector3(cx - gap + 0.1, eye - 0.62, z + 0.0), 0.012, 0.012, frame)
			return WinterWear._finish(st)
		"square":
			for side in [-1.0, 1.0]:
				_ring(st, Vector3(cx + side * gap, eye, z), r, thick, frame, 4, 1.0)
		"half":
			# Half-moon reading glasses: only the lower half of the rim, perched low on the nose.
			for side in [-1.0, 1.0]:
				_ring(st, Vector3(cx + side * gap, eye - 0.03, z), r, thick, frame, 8, 0.5)
		_:
			for side in [-1.0, 1.0]:
				_ring(st, Vector3(cx + side * gap, eye, z), r, thick, frame, 8, 1.0)
	# The bridge over the nose and the two arms back to the ears.
	_bar(st, Vector3(cx - gap + r, eye, z), Vector3(cx + gap - r, eye, z), thick, thick, frame)
	for side in [-1.0, 1.0]:
		var from := Vector3(cx + side * (gap + r), eye, z)
		var to := Vector3(cx + side * (rx + 0.01), eye + 0.02, box.get_center().z)
		_bar(st, from, to, thick, thick, frame)
	return WinterWear._finish(st)


## A ring of `sides` bars round `at` in the XY plane; `part` 1 is all of it, 0.5 the lower half.
static func _ring(st: SurfaceTool, at: Vector3, radius: float, thick: float, colour: Color, sides: int, part: float) -> void:
	var n := roundi(sides * part)
	for i in n:
		var a0 := TAU * float(i) / sides + (PI * 0.5 if part < 1.0 else 0.0) + PI / sides
		var a1 := TAU * float(i + 1) / sides + (PI * 0.5 if part < 1.0 else 0.0) + PI / sides
		var from := at + Vector3(cos(a0), sin(a0), 0.0) * radius
		var to := at + Vector3(cos(a1), sin(a1), 0.0) * radius
		_bar(st, from, to, thick, thick, colour)


## A straight bar from a to b, `thick` across in the plane of the face and `depth` front to back
## (a bar that runs along Z gets its width from `thick`).
static func _bar(st: SurfaceTool, a: Vector3, b: Vector3, thick: float, depth: float, colour: Color) -> void:
	var d := (b - a)
	if d.length() < 0.0001:
		return
	var axis := d.normalized()
	var up := Vector3.UP if absf(axis.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var u := axis.cross(up).normalized() * thick * 0.5
	var v := axis.cross(u).normalized() * depth * 0.5
	st.set_color(colour)
	var c := []
	for p in [a, b]:
		for s in [[-1, -1], [1, -1], [1, 1], [-1, 1]]:
			c.append(p + u * s[0] + v * s[1])
	for f in [[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]:
		for p in [f[0], f[1], f[2], f[0], f[2], f[3]]:
			st.add_vertex(c[p])
