class_name WinterWear
extends RefCounted
## Winter clothes for the people of the village: a fur collar or a fur mantle over the shoulders, a
## fur hem on the coat, a wool scarf and a warm hat picked for each person (see HAT_OF): a knit cap
## with a bobble, a knit cap with earflaps and braids, a long stocking cap, a rolled watch cap, a fur
## ushanka, the herald's fur cap with its plume, a hood or a wool shawl over the head. The kind of fur
## differs from person to person (red fox, grey wolf, white hare, brown bear, black sable, tawny
## lynx). People who already wear a hat or a helmet keep it and get the scarf and the fur over the
## shoulders.
##
## Built in code in the chunky low-poly shapes of the KayKit people and hung from the bones (like
## PostCap), so it moves with the body. Everything is measured in the skeleton's rest space; the
## head's own box (see _head_box) sizes the headgear to every model.
##
## Villager.update_wear puts the clothes on and takes them off, and only while nobody sees it (see
## Outdoor.set_winter_wear): winter starts in the night, the village is asleep, and in the morning
## everyone steps out in winter clothes.

const FURS := {
	"fox": [Color(0.8, 0.36, 0.13), Color(0.97, 0.9, 0.78)],
	"wolf": [Color(0.46, 0.47, 0.5), Color(0.78, 0.79, 0.82)],
	"hare": [Color(0.93, 0.93, 0.95), Color(1.0, 1.0, 1.0)],
	"bear": [Color(0.34, 0.21, 0.13), Color(0.5, 0.35, 0.22)],
	"sable": [Color(0.16, 0.11, 0.09), Color(0.32, 0.24, 0.19)],
	"lynx": [Color(0.72, 0.58, 0.4), Color(0.93, 0.85, 0.7)],
}
const FUR_KINDS := ["fox", "wolf", "hare", "bear", "sable", "lynx"]

## The wool of caps, scarves and hoods.
const WOOLS := [Color(0.72, 0.2, 0.2), Color(0.2, 0.42, 0.3), Color(0.22, 0.34, 0.6), Color(0.85, 0.72, 0.3),
	Color(0.5, 0.5, 0.52), Color(0.45, 0.25, 0.4)]
## How much the coat takes of its winter tone (the dye of body and arms).
const COAT_TONES := [Color(0.42, 0.25, 0.18), Color(0.25, 0.32, 0.26), Color(0.3, 0.3, 0.38), Color(0.5, 0.38, 0.25),
	Color(0.38, 0.22, 0.24), Color(0.28, 0.27, 0.25)]
const COAT_SHARE := 0.55

## The kinds of hat, for anyone not in HAT_OF.
const HATS := ["bobble", "earflap", "ushanka", "watch", "stocking", "hood"]
## Every hatless person's own winter hat, picked to suit them: its kind, the colour of its cloth or
## wool and of its trim (the bobble, the stripes, the braid, the hood's edge), and the fur where it
## has some. Neighbours wear different kinds (Herald Konrad and Clerk Gero stand side by side).
const HAT_OF := {
	"1": {"hat": "watch", "cloth": Color(0.3, 0.29, 0.3), "trim": Color(0.62, 0.36, 0.2)},
	"2": {"hat": "shawl", "cloth": Color(0.86, 0.48, 0.22), "trim": Color(0.96, 0.84, 0.55)},
	"5": {"hat": "stocking", "cloth": Color(0.26, 0.52, 0.3), "trim": Color(0.96, 0.94, 0.88)},
	"6": {"hat": "ushanka", "cloth": Color(0.52, 0.24, 0.48), "fur": "hare"},
	"7": {"hat": "bobble", "cloth": Color(0.27, 0.42, 0.82), "trim": Color(0.97, 0.8, 0.27)},
	"pippi": {"hat": "earflap", "cloth": Color(0.84, 0.26, 0.28), "trim": Color(0.97, 0.95, 0.9)},
	"9": {"hat": "earflap", "cloth": Color(0.26, 0.5, 0.6), "trim": Color(0.97, 0.95, 0.9)},
	"sweeper": {"hat": "watch", "cloth": Color(0.36, 0.3, 0.22), "trim": Color(0.7, 0.35, 0.2)},
	"K": {"hat": "herald", "cloth": Color(0.27, 0.38, 0.85), "trim": Color(0.95, 0.78, 0.3), "fur": "sable"},
	"¢": {"hat": "ushanka", "cloth": Color(0.22, 0.27, 0.5), "fur": "bear"},
	"O": {"hat": "hood", "cloth": Color(0.9, 0.86, 0.76), "trim": Color(0.93, 0.74, 0.3)},
	"G": {"hat": "hood", "cloth": Color(0.6, 0.2, 0.16), "fur": "wolf"},
	"Z": {"hat": "bobble", "cloth": Color(0.95, 0.95, 0.95), "trim": Color(0.8, 0.18, 0.2)},
	"S": {"hat": "watch", "cloth": Color(0.78, 0.62, 0.25), "trim": Color(0.45, 0.42, 0.4)},
	"µ": {"hat": "shawl", "cloth": Color(0.26, 0.5, 0.46), "trim": Color(0.88, 0.7, 0.36)},
}
const MANTLES := [false, true]

## Whose looks these are, in order: the fur, the wool and the coat go round the list. A person's own
## look is fixed, so they wear the same every winter. Clerk Gero (¢) stands near Herald Konrad (K)
## and, left out of the list, happened to wear the same fur and hat.
const ORDER := "0123456789KOGMYZS¢"

const SIDES := 12
const TAG := "WinterWear"
const SPIKE := 0.05
## How far a band's inner wall sits behind its outer one (see _thicken).
const WALL := 0.05


## The look of one person: fur, hat ("" when a hat or a helmet is worn already), the hat's cloth and
## trim colours, mantle (fur over the shoulders instead of a collar), wool and coat tone. `info` is
## the role (see Villager.ROLES).
static func look_for(role: String, info: Dictionary) -> Dictionary:
	var i := ORDER.find(role)
	if i < 0:
		i = 17 + absi(hash(role)) % 7
	var hatted: bool = info.show.any(func(p): return String(p).ends_with("Hat") or String(p).ends_with("Helmet")) or info.get("cap", "") != ""
	var fur: String = FUR_KINDS[(i * 5 + 2) % FUR_KINDS.size()]
	var wool := i % WOOLS.size()
	var own: Dictionary = HAT_OF.get(role, {})
	var hat := ""
	if not hatted:
		hat = own.get("hat", "bobble" if info.get("scale", 1.0) < 1.0 else HATS[(i * 3 + 1) % HATS.size()])
		fur = own.get("fur", fur)
	return {
		"fur": fur,
		"hat": hat,
		"cloth": own.get("cloth", WOOLS[wool]),
		"trim": own.get("trim", Color(0.96, 0.94, 0.9)),
		# A hood is edged with fur only where its fur is named.
		"furred": own.has("fur") or not own.has("hat"),
		"mantle": hatted and i % 2 == 0 or (not hatted and i % 3 == 0),
		"wool": wool,
		"coat": (i * 2 + 1) % COAT_TONES.size(),
		"kid": info.get("scale", 1.0) < 1.0,
	}


## Whether the model wears winter clothes.
static func is_worn(model: Node3D) -> bool:
	return model.find_child(TAG, true, false) != null


## Dresses the model for winter (once).
static func put_on(model: Node3D, look: Dictionary) -> void:
	if is_worn(model):
		return
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return
	var fur: Array = FURS[look.fur]
	var wool: Color = WOOLS[look.wool]
	var chest := _slot(skeleton, "chest")
	var hips := _slot(skeleton, "hips")
	var head := _slot(skeleton, "head")
	# The fur on the shoulders and on the hem of the coat, and the scarf.
	_hang(chest, "Shoulders", _mantle(fur) if look.mantle else _collar(fur))
	_hang(hips, "Hem", _hem(fur))
	_hang(chest, "Scarf", _scarf(wool, look.kid))
	if look.hat != "":
		_hang(head, "Hat", WinterHats.mesh(look.hat, _head_box(model), look.cloth, look.trim, fur if look.furred else []))
		# A crest, spikes or a hair knot would poke through the hat; pigtails hang out below it.
		_tuck_hair(model, true)
		Bandana.show_on(model, false)
	_dye_coat(model, COAT_TONES[look.coat])
	var marker := Node3D.new()
	marker.name = TAG
	model.add_child(marker)


## Takes the winter clothes off again.
static func take_off(model: Node3D) -> void:
	var marker := model.find_child(TAG, true, false)
	if marker == null:
		return
	marker.get_parent().remove_child(marker)
	marker.free()
	for slot in model.find_children("Winter*", "BoneAttachment3D", true, false):
		slot.get_parent().remove_child(slot)
		slot.free()
	_tuck_hair(model, false)
	Bandana.show_on(model, true)
	_dye_coat(model, null)


## Hides the hair that would poke through a winter hat (the crest, the spikes and the knot), or shows
## it again. Pigtails stay: they hang out below the hat.
static func _tuck_hair(model: Node3D, tucked: bool) -> void:
	var slot := model.find_child("HeadSlot", true, false) as Node3D
	if slot == null:
		return
	for part in ["Crest", "Bun"]:
		var locks := slot.get_node_or_null(part) as Node3D
		if locks:
			locks.visible = locks.get_meta("wanted", false) and not tucked and not slot.get_meta("covered", false)


# --- Slots and dye ---------------------------------------------------------------

## A point on a bone that the parts hang from. Its "bind" turns the rest space into the bone's.
static func _slot(skeleton: Skeleton3D, bone: String) -> BoneAttachment3D:
	var slot := BoneAttachment3D.new()
	slot.name = "Winter_" + bone
	slot.bone_name = bone
	slot.set_meta("bind", skeleton.get_bone_global_rest(skeleton.find_bone(bone)).affine_inverse())
	skeleton.add_child(slot)
	return slot


static func _hang(slot: BoneAttachment3D, part: String, mesh: ArrayMesh) -> void:
	var mi := MeshInstance3D.new()
	mi.name = part
	mi.mesh = mesh
	mi.transform = slot.get_meta("bind")
	slot.add_child(mi)


## The coat takes its winter tone: the dye of the body and the arms leans towards `tone` (null:
## back to the summer's dye).
static func _dye_coat(model: Node3D, tone) -> void:
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var part := String(mi.name)
		if not (part.ends_with("_Body") or part.ends_with("_ArmLeft") or part.ends_with("_ArmRight")):
			continue
		if tone == null:
			if mi.has_meta("summer_look"):
				mi.material_override = mi.get_meta("summer_look")
				mi.remove_meta("summer_look")
			continue
		var own := mi.get_active_material(0)
		if own == null or mi.has_meta("summer_look"):
			continue
		mi.set_meta("summer_look", mi.material_override)
		var dyed: Material = own.duplicate()
		if dyed is ShaderMaterial:
			var dye = dyed.get_shader_parameter("dye")
			dyed.set_shader_parameter("dye", (dye if dye is Color else Color.WHITE).lerp(tone, COAT_SHARE))
		elif dyed is StandardMaterial3D:
			dyed.albedo_color = dyed.albedo_color.lerp(tone, COAT_SHARE)
		mi.material_override = dyed


## The head's box in the rest space: where the headgear goes.
static func _head_box(model: Node3D) -> AABB:
	for mi: MeshInstance3D in model.find_children("*_Head", "MeshInstance3D", true, false):
		return mi.get_aabb()
	return AABB(Vector3(-0.54, 1.17, -0.5), Vector3(1.08, 1.02, 1.0))


# --- Parts -------------------------------------------------------------------------

static func _start() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	return st


static func _finish(st: SurfaceTool) -> ArrayMesh:
	st.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = Graphics.vertex_colours_srgb()
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(mat)
	return st.commit()


## A point on an ellipse round (cx, cz) at the angle `a` (0 is the front).
static func _on(a: float, y: float, rx: float, rz: float, cx := 0.0, cz := 0.0) -> Vector3:
	return Vector3(cx + sin(a) * rx, y, cz + cos(a) * rz)


## A band between two ellipses, a hem above and below, in one colour. `from`..`to`: the angles it
## spans (a full ring by default).
static func _band(st: SurfaceTool, y0: float, y1: float, rx0: float, rz0: float, rx1: float, rz1: float, colour: Color, cx := 0.0, cz := 0.0, from := 0.0, to := TAU) -> void:
	st.set_color(colour)
	var n := maxi(1, int(SIDES * (to - from) / TAU))
	for i in n:
		var a0 := lerpf(from, to, float(i) / n)
		var a1 := lerpf(from, to, float(i + 1) / n)
		var b0 := _on(a0, y0, rx0, rz0, cx, cz)
		var b1 := _on(a1, y0, rx0, rz0, cx, cz)
		var t0 := _on(a0, y1, rx1, rz1, cx, cz)
		var t1 := _on(a1, y1, rx1, rz1, cx, cz)
		for p in [b0, b1, t1, b0, t1, t0]:
			st.add_vertex(p)


## Gives a band body so it reads as a solid roll of cloth or fur and not as a see-through ring: an
## inner wall set back by WALL and a rim joining it to the outer wall at the top and at the bottom.
static func _thicken(st: SurfaceTool, y0: float, y1: float, rx0: float, rz0: float, rx1: float, rz1: float, colour: Color, cx := 0.0, cz := 0.0, from := 0.0, to := TAU) -> void:
	_band(st, y0, y1, rx0 - WALL, rz0 - WALL, rx1 - WALL, rz1 - WALL, colour.darkened(0.25), cx, cz, from, to)
	st.set_color(colour)
	var n := maxi(1, int(SIDES * (to - from) / TAU))
	for i in n:
		var a0 := lerpf(from, to, float(i) / n)
		var a1 := lerpf(from, to, float(i + 1) / n)
		for rim in [[y0, rx0, rz0], [y1, rx1, rz1]]:
			var o0 := _on(a0, rim[0], rim[1], rim[2], cx, cz)
			var o1 := _on(a1, rim[0], rim[1], rim[2], cx, cz)
			var i0 := _on(a0, rim[0], rim[1] - WALL, rim[2] - WALL, cx, cz)
			var i1 := _on(a1, rim[0], rim[1] - WALL, rim[2] - WALL, cx, cz)
			for p in [o0, o1, i1, o0, i1, i0]:
				st.add_vertex(p)


## A fur band with a ragged edge: the band itself in the fur's colour, and a tuft over every
## segment in its tip colour, standing up (`dir` 1) or hanging down (-1) from the edge.
static func _fur_band(st: SurfaceTool, y0: float, y1: float, rx: float, rz: float, fur: Array, up := true, cx := 0.0, cz := 0.0, from := 0.0, to := TAU, thick := 0.0) -> void:
	_band(st, y0, y1, rx, rz, rx + thick, rz + thick, fur[0], cx, cz, from, to)
	_thicken(st, y0, y1, rx, rz, rx + thick, rz + thick, fur[0], cx, cz, from, to)
	var n := maxi(1, int(SIDES * 1.5 * (to - from) / TAU))
	var edge := y1 if up else y0
	for i in n:
		var a0 := lerpf(from, to, float(i) / n)
		var a1 := lerpf(from, to, float(i + 1) / n)
		var am := (a0 + a1) * 0.5
		var r_x := rx + thick
		var r_z := rz + thick
		st.set_color(fur[0].lerp(fur[1], 0.55))
		st.add_vertex(_on(a0, edge, r_x, r_z, cx, cz))
		st.add_vertex(_on(a1, edge, r_x, r_z, cx, cz))
		st.add_vertex(_on(am, edge + SPIKE * (1.0 if up else -1.0), r_x * 1.03, r_z * 1.03, cx, cz))


## A dome of rings, each (y, rx, rz), from the bottom up, in stripes of `colours`. Angles from `cut`
## either side of the front are left open (a hood); 0 closes it.
static func _dome(st: SurfaceTool, rings: Array, colours: Array, cx: float, cz: float, cut := 0.0) -> void:
	var n := SIDES * 2
	for k in rings.size() - 1:
		var r0: Array = rings[k]
		var r1: Array = rings[k + 1]
		st.set_color(colours[k % colours.size()])
		for i in n:
			var a0 := TAU * i / n
			var a1 := TAU * (i + 1) / n
			var mid := fposmod(a0 + PI / n + PI, TAU) - PI
			# The hood is open at the face, lower down than at the crown.
			if cut > 0.0 and absf(mid) < cut * (1.0 - float(k) / (rings.size() - 1)) and k < rings.size() - 2:
				continue
			var b0 := _on(a0, r0[0], r0[1], r0[2], cx, cz)
			var b1 := _on(a1, r0[0], r0[1], r0[2], cx, cz)
			var t0 := _on(a0, r1[0], r1[1], r1[2], cx, cz)
			var t1 := _on(a1, r1[0], r1[1], r1[2], cx, cz)
			for p in [b0, b1, t1, b0, t1, t0]:
				st.add_vertex(p)
	# The top, closed.
	var last: Array = rings[rings.size() - 1]
	st.set_color(colours[(rings.size() - 1) % colours.size()])
	for i in n:
		st.add_vertex(_on(TAU * i / n, last[0], last[1], last[2], cx, cz))
		st.add_vertex(_on(TAU * (i + 1) / n, last[0], last[1], last[2], cx, cz))
		st.add_vertex(Vector3(cx, last[0], cz))


## A box with its centre `at` and sides `size`.
static func _box(st: SurfaceTool, at: Vector3, size: Vector3, colour: Color) -> void:
	st.set_color(colour)
	var h := size * 0.5
	var c := [
		at + Vector3(-h.x, -h.y, -h.z), at + Vector3(h.x, -h.y, -h.z), at + Vector3(h.x, h.y, -h.z), at + Vector3(-h.x, h.y, -h.z),
		at + Vector3(-h.x, -h.y, h.z), at + Vector3(h.x, -h.y, h.z), at + Vector3(h.x, h.y, h.z), at + Vector3(-h.x, h.y, h.z)]
	for f in [[0, 1, 2, 3], [5, 4, 7, 6], [4, 0, 3, 7], [1, 5, 6, 2], [3, 2, 6, 7], [4, 5, 1, 0]]:
		for p in [f[0], f[1], f[2], f[0], f[2], f[3]]:
			st.add_vertex(c[p])


## A small fur collar standing round the neck.
static func _collar(fur: Array) -> ArrayMesh:
	var st := _start()
	_fur_band(st, 1.13, 1.27, 0.43, 0.36, fur, true, 0.0, 0.0, 0.0, TAU, 0.07)
	return _finish(st)


## A fur mantle over the shoulders: a wide ring, ragged at its lower edge, and the collar on it.
static func _mantle(fur: Array) -> ArrayMesh:
	var st := _start()
	_fur_band(st, 1.03, 1.16, 0.56, 0.42, fur, false, 0.0, 0.0, 0.0, TAU, 0.02)
	_fur_band(st, 1.16, 1.3, 0.44, 0.36, fur, true, 0.0, 0.0, 0.0, TAU, 0.06)
	return _finish(st)


## The hem of the coat: a fur band round the hips.
static func _hem(fur: Array) -> ArrayMesh:
	var st := _start()
	_fur_band(st, 0.44, 0.58, 0.42, 0.36, fur, false, 0.0, 0.0, 0.0, TAU, 0.03)
	return _finish(st)


## A wool scarf round the neck, in two stripes, with its end hanging down the chest.
static func _scarf(wool: Color, kid: bool) -> ArrayMesh:
	var st := _start()
	_band(st, 1.1, 1.18, 0.45, 0.38, 0.47, 0.4, wool, 0.0, 0.0)
	_band(st, 1.18, 1.25, 0.47, 0.4, 0.45, 0.38, wool.lightened(0.28), 0.0, 0.0)
	_thicken(st, 1.1, 1.18, 0.45, 0.38, 0.47, 0.4, wool)
	_thicken(st, 1.18, 1.25, 0.47, 0.4, 0.45, 0.38, wool.lightened(0.28))
	var drop := 0.34 if kid else 0.48
	_box(st, Vector3(0.2, 1.15 - drop * 0.5, 0.43), Vector3(0.17, drop, 0.045), wool)
	_box(st, Vector3(0.2, 1.15 - drop + 0.06, 0.435), Vector3(0.17, 0.05, 0.05), wool.lightened(0.28))
	return _finish(st)
