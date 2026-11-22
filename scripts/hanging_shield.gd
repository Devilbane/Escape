class_name HangingShield
extends RefCounted
## The village's hanging shop signs: a big wooden shield with an iron rim, hung on two chains, its
## mark painted large on both faces so a shop or office is easy to tell from the street and from the
## game's high camera. Two ways to hang it:
##  - on_wall: an iron bracket out from a front wall, high over the doorway's side (the halls);
##  - on_post: a wooden post with an arm, standing beside a yard (smithy, barber, mason, wood yard),
##    with the place's name on a small board under the shield.
## Both hang high enough to walk under (see CLEAR), and only the post itself is solid.

## The shield, in metres: wide across the top, tall from the top to its point.
const WIDE := 1.1
const TALL := 1.32
const THICK := 0.07
## The rim of iron round the shield, sticking out past the wood.
const RIM := 0.05
## How long the chains are, from the arm down to the shield's top.
const CHAIN := 0.2
## The lowest point of a hanging sign stays this high above the ground, so the hero walks under it.
const CLEAR := 2.0
## The post: how tall, and how far its arm reaches out sideways (along +x).
const POST_HIGH := 3.8
const ARM_OUT := 1.35
## How big the mark is painted on the shield, against the 0.3 m pictures of Effects.sign_icon.
const MARK_SCALE := 2.5

## The shield's field and the mark on it for each kind of place. The marks are pictures of
## Effects.sign_icon, or the extra ones drawn here (see emblem).
const LOOKS := {
	"tavern": {"field": Color(0.2, 0.42, 0.24), "mark": "mug"},
	"shop": {"field": Color(0.18, 0.32, 0.6), "mark": "scale"},
	"post": {"field": Color(0.85, 0.66, 0.16), "mark": "horn"},
	"office": {"field": Color(0.15, 0.22, 0.52), "mark": "crown"},
	"guild": {"field": Color(0.62, 0.14, 0.12), "mark": "swords"},
	"bank": {"field": Color(0.12, 0.36, 0.3), "mark": "coins"},
	"smithy": {"field": Color(0.24, 0.24, 0.27), "mark": "anvil"},
	"barber": {"field": Color(0.75, 0.18, 0.18), "mark": "scissors"},
	"mason": {"field": Color(0.36, 0.42, 0.5), "mark": "stone"},
	"wood": {"field": Color(0.3, 0.45, 0.2), "mark": "axe"},
	"jeweller": {"field": Color(0.38, 0.18, 0.45), "mark": "ring"},
	"gems": {"field": Color(0.2, 0.2, 0.32), "mark": "gem"},
	"alchemist": {"field": Color(0.15, 0.38, 0.42), "mark": "flask"},
	"store": {"field": Color(0.5, 0.32, 0.18), "mark": "chest"},
	"coin": {"field": Color(0.12, 0.36, 0.3), "mark": "coin"},
}
## The extra marks drawn here, on top of Effects.SIGN_ICONS.
const MARKS := ["mug", "scale", "horn", "crown", "swords", "coins"]

static var _mats := {}
static var _shield_mesh: ArrayMesh
static var _rim_mesh: ArrayMesh


## The shield of `kind` (one of LOOKS, or a mark name such as "gem") hung on a bracket out from a
## wall. The root sits on the wall at the arm's height; the wall is behind it (at -z) and the street
## at +z. With `across` the shield hangs edgewise to the wall, seen from along the street; without,
## it hangs flat in front of the wall from a crossbar at the arm's end, seen from across the street.
static func on_wall(kind: String, out := 1.1, across := true) -> Node3D:
	var root := Node3D.new()
	root.name = "HangingShield"
	root.set_meta("kind", kind)
	var iron := _mat("iron", Color(0.18, 0.18, 0.2), 0.45, 0.6)
	# The arm, a wall plate and a slanted brace under it, with a curl at the end.
	_box(root, Vector3(0.06, 0.06, out), Vector3(0, 0, out * 0.5), iron)
	_box(root, Vector3(0.18, 0.5, 0.03), Vector3(0, -0.15, 0.015), iron)
	var brace_len := Vector2(out * 0.6, 0.45).length()
	_box(root, Vector3(0.04, 0.04, brace_len), Vector3(0, -0.22, out * 0.3), iron, Basis(Vector3.RIGHT, atan2(0.45, out * 0.6)))
	var curl := TorusMesh.new()
	curl.inner_radius = 0.05
	curl.outer_radius = 0.08
	curl.rings = 12
	curl.ring_segments = 6
	root.add_child(_part(curl, iron, Vector3(0, 0.07, out + 0.02), Basis(Vector3.FORWARD, PI * 0.5)))
	var shield := shield_of(kind)
	if across:
		# Chains from two points along the arm; the shield turned to face along the wall.
		var mid := out * 0.58
		for z: float in [mid - WIDE * 0.38, mid + WIDE * 0.38]:
			_chain(root, Vector3(0, 0, z), CHAIN)
		shield.position = Vector3(0, -CHAIN, mid)
		shield.rotation.y = PI * 0.5
	else:
		var bar_at := out - 0.05
		_box(root, Vector3(WIDE * 0.95, 0.05, 0.05), Vector3(0, 0, bar_at), iron)
		for x: float in [-WIDE * 0.38, WIDE * 0.38]:
			_chain(root, Vector3(x, 0, bar_at), CHAIN)
		shield.position = Vector3(0, -CHAIN, bar_at)
	root.add_child(shield)
	return root


## The shield of `kind` on a wooden post standing on the ground (the root, at the post's foot),
## its arm reaching along +x and the shield facing +z. A `name` that fits is written on a small
## board hanging under the shield; one too long is left off.
static func on_post(kind: String, name := "", font: Font = null) -> Node3D:
	var root := Node3D.new()
	root.name = "ShopSign"
	root.set_meta("kind", kind)
	var wood := _mat("post_wood", Color(0.3, 0.2, 0.12))
	var iron := _mat("iron", Color(0.18, 0.18, 0.2), 0.45, 0.6)
	var post := CylinderMesh.new()
	post.top_radius = 0.08
	post.bottom_radius = 0.1
	post.height = POST_HIGH
	root.add_child(_part(post, wood, Vector3(0, POST_HIGH * 0.5, 0)))
	var cap := SphereMesh.new()
	cap.radius = 0.1
	cap.height = 0.16
	root.add_child(_part(cap, iron, Vector3(0, POST_HIGH + 0.03, 0)))
	var arm_y := POST_HIGH - 0.2
	_box(root, Vector3(ARM_OUT + 0.1, 0.1, 0.1), Vector3(ARM_OUT * 0.5, arm_y, 0), wood)
	var brace_len := Vector2(0.55, 0.55).length()
	_box(root, Vector3(brace_len, 0.07, 0.07), Vector3(0.27, arm_y - 0.27, 0), wood, Basis(Vector3.BACK, PI * 0.25))
	var mid := ARM_OUT * 0.58 + 0.08
	for x: float in [mid - WIDE * 0.38, mid + WIDE * 0.38]:
		_chain(root, Vector3(x, arm_y - 0.05, 0), CHAIN)
	var shield := shield_of(kind)
	shield.position = Vector3(mid, arm_y - 0.05 - CHAIN, 0)
	root.add_child(shield)
	var fits := name != "" and font != null and Effects.sign_text_fits(name, font)
	root.set_meta("text_shown", fits)
	if fits:
		# The name board hangs from two rings under the shield's shoulders.
		var under := shield.position.y - TALL * 0.78
		for x: float in [mid - 0.3, mid + 0.3]:
			_chain(root, Vector3(x, shield.position.y - TALL * 0.55, 0), 0.12)
		var plank := _box(root, Vector3(Effects.SIGN_BOARD_WIDTH, 0.26, 0.05), Vector3(mid, under, 0), _mat("plank", Color(0.62, 0.45, 0.26)))
		plank.name = "NameBoard"
		for side: float in [1.0, -1.0]:
			var label := Label3D.new()
			label.text = name
			label.font = font
			label.font_size = Effects.SIGN_FONT_SIZE
			label.pixel_size = Effects.SIGN_PIXEL_SIZE
			label.modulate = Color(0.1, 0.06, 0.03)
			label.outline_size = 0
			label.position = Vector3(mid, under, side * 0.03)
			label.rotation.y = 0.0 if side > 0 else PI
			root.add_child(label)
	return root


## The bottom of a post sign above the ground: its name board, or the shield's point.
static func post_low_point(with_name: bool) -> float:
	var shield_top := POST_HIGH - 0.25 - CHAIN
	return shield_top - TALL * 0.78 - 0.13 if with_name else shield_top - TALL


## The shield alone, its top middle at the origin, facing +z, with its mark on both faces.
static func shield_of(kind: String) -> Node3D:
	var look := look_of(kind)
	var shield := Node3D.new()
	shield.name = "Shield"
	shield.set_meta("mark", look.mark)
	var field := MeshInstance3D.new()
	field.mesh = _shield()
	field.material_override = _mat("field_%s" % look.field.to_html(), look.field, 0.75, 0.0, true)
	shield.add_child(field)
	var rim := MeshInstance3D.new()
	rim.mesh = _rim()
	rim.material_override = _mat("rim", Color(0.55, 0.45, 0.3), 0.4, 0.7, true)
	shield.add_child(rim)
	# Two rings on the top edge for the chains.
	for x: float in [-WIDE * 0.38, WIDE * 0.38]:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.025
		ring.outer_radius = 0.045
		ring.rings = 10
		ring.ring_segments = 5
		shield.add_child(_part(ring, _mat("iron", Color(0.18, 0.18, 0.2), 0.45, 0.6), Vector3(x, 0.02, 0), Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.RIGHT, PI * 0.5)))
	for side: float in [1.0, -1.0]:
		var mark := emblem(look.mark)
		mark.name = "Mark" if side > 0 else "MarkBack"
		mark.scale = Vector3.ONE * MARK_SCALE
		mark.position = Vector3(0, -TALL * 0.42, side * (THICK * 0.5 + 0.01))
		mark.rotation.y = 0.0 if side > 0 else PI
		shield.add_child(mark)
	return shield


## The field and mark of `kind`: a kind of place in LOOKS, or a mark name, which takes the look of
## the place with that mark (a coin on green for anything unknown).
static func look_of(kind: String) -> Dictionary:
	if LOOKS.has(kind):
		return LOOKS[kind]
	for place: String in LOOKS:
		if LOOKS[place].mark == kind:
			return LOOKS[place]
	return LOOKS.coin


## A mark for a shield, about 0.3 m across and facing +z: one of MARKS, or a picture of
## Effects.sign_icon (a coin for anything unknown).
static func emblem(kind: String) -> Node3D:
	if not kind in MARKS:
		return Effects.sign_icon(kind)
	var pic := Node3D.new()
	var gold := _mat("gold", Color(1.0, 0.78, 0.3), 0.35, 0.7)
	var steel := _mat("steel", Color(0.85, 0.87, 0.9), 0.3, 0.8)
	var pale := _mat("pale", Color(0.95, 0.9, 0.78))
	var brown := _mat("brown", Color(0.45, 0.28, 0.14))
	match kind:
		"mug":
			var cup := CylinderMesh.new()
			cup.top_radius = 0.1
			cup.bottom_radius = 0.09
			cup.height = 0.24
			pic.add_child(_part(cup, gold, Vector3(-0.02, -0.03, 0), Basis(), Vector3(1, 1, 0.3)))
			_box(pic, Vector3(0.22, 0.06, 0.04), Vector3(-0.02, 0.11, 0.01), pale)
			var handle := TorusMesh.new()
			handle.inner_radius = 0.04
			handle.outer_radius = 0.065
			handle.rings = 12
			handle.ring_segments = 5
			pic.add_child(_part(handle, gold, Vector3(0.11, -0.02, 0), Basis(Vector3.RIGHT, PI * 0.5)))
		"scale":
			_box(pic, Vector3(0.03, 0.28, 0.03), Vector3(0, -0.02, 0), gold)
			_box(pic, Vector3(0.16, 0.03, 0.03), Vector3(0, -0.16, 0), gold)
			_box(pic, Vector3(0.34, 0.03, 0.03), Vector3(0, 0.11, 0), gold)
			for x: float in [-0.15, 0.15]:
				_box(pic, Vector3(0.01, 0.12, 0.01), Vector3(x, 0.05, 0.01), gold)
				var pan := CylinderMesh.new()
				pan.top_radius = 0.07
				pan.bottom_radius = 0.04
				pan.height = 0.04
				pic.add_child(_part(pan, gold, Vector3(x, -0.02, 0.01), Basis(), Vector3(1, 1, 0.35)))
		"horn":
			# A post horn, black on the post's yellow: a thick ring of tube, a mouthpiece and a
			# wide bell, tied with a cord.
			var black := _mat("horn_black", Color(0.1, 0.08, 0.07), 0.5, 0.3)
			var coil := TorusMesh.new()
			coil.inner_radius = 0.075
			coil.outer_radius = 0.12
			coil.rings = 20
			coil.ring_segments = 8
			pic.add_child(_part(coil, black, Vector3(-0.03, 0.02, 0), Basis(Vector3.RIGHT, PI * 0.5), Vector3(1, 0.5, 1)))
			_box(pic, Vector3(0.26, 0.045, 0.03), Vector3(0.06, -0.1, 0.01), black)
			_box(pic, Vector3(0.06, 0.03, 0.03), Vector3(-0.2, -0.1, 0.01), black)
			var bell := CylinderMesh.new()
			bell.top_radius = 0.025
			bell.bottom_radius = 0.13
			bell.height = 0.16
			pic.add_child(_part(bell, black, Vector3(0.26, -0.1, 0.01), Basis(Vector3.BACK, PI * 0.5), Vector3(1, 1, 0.35)))
			_box(pic, Vector3(0.025, 0.12, 0.02), Vector3(-0.03, -0.17, 0.02), _mat("cord", Color(0.75, 0.15, 0.12)))
		"crown":
			# The Crown: a gold band with three points, each tipped with a ball, and jewels.
			_box(pic, Vector3(0.34, 0.08, 0.03), Vector3(0, -0.1, 0), gold)
			_box(pic, Vector3(0.3, 0.06, 0.03), Vector3(0, -0.03, 0), gold)
			var ball := SphereMesh.new()
			ball.radius = 0.028
			ball.height = 0.056
			for x: float in [-0.13, 0.0, 0.13]:
				var high := 0.17 if x == 0.0 else 0.12
				var point := CylinderMesh.new()
				point.top_radius = 0.0
				point.bottom_radius = 0.06
				point.height = high
				pic.add_child(_part(point, gold, Vector3(x, high * 0.5, 0), Basis(), Vector3(1, 1, 0.35)))
				pic.add_child(_part(ball, gold, Vector3(x, high + 0.02, 0)))
			for x: float in [-0.1, 0.0, 0.1]:
				var jewel := _mat("jewel_red" if x == 0.0 else "jewel_blue", Color(0.8, 0.12, 0.12) if x == 0.0 else Color(0.25, 0.45, 0.95), 0.2)
				_box(pic, Vector3(0.045, 0.045, 0.02), Vector3(x, -0.1, 0.02), jewel, Basis(Vector3.BACK, PI * 0.25))
		"swords":
			for side: float in [-1.0, 1.0]:
				var turn := Basis(Vector3.BACK, side * 0.75)
				_box(pic, Vector3(0.035, 0.34, 0.02), turn * Vector3(0, 0.03, 0) + Vector3(0, 0, 0.005 * side), steel, turn)
				_box(pic, Vector3(0.12, 0.025, 0.025), turn * Vector3(0, -0.13, 0) + Vector3(0, 0, 0.01), gold, turn)
				_box(pic, Vector3(0.03, 0.07, 0.025), turn * Vector3(0, -0.18, 0) + Vector3(0, 0, 0.01), brown, turn)
		"coins":
			var coin := CylinderMesh.new()
			coin.top_radius = 0.07
			coin.bottom_radius = 0.07
			coin.height = 0.02
			for i in 4:
				pic.add_child(_part(coin, gold, Vector3(-0.09, -0.15 + i * 0.045, 0.0), Basis(), Vector3(1, 1, 0.4)))
			var big := CylinderMesh.new()
			big.top_radius = 0.1
			big.bottom_radius = 0.1
			big.height = 0.025
			pic.add_child(_part(big, gold, Vector3(0.07, 0.03, 0.01), Basis(Vector3.RIGHT, PI * 0.5)))
			_box(pic, Vector3(0.03, 0.1, 0.03), Vector3(0.07, 0.03, 0.025), _mat("gold_dark", Color(0.7, 0.5, 0.15), 0.4, 0.7))
	return pic


## A short chain of iron links from `top` hanging straight down `length` metres.
static func _chain(parent: Node3D, top: Vector3, length: float) -> void:
	var link := TorusMesh.new()
	link.inner_radius = 0.012
	link.outer_radius = 0.026
	link.rings = 8
	link.ring_segments = 4
	var iron := _mat("iron", Color(0.18, 0.18, 0.2), 0.45, 0.6)
	var n := maxi(2, int(round(length / 0.045)))
	for i in n:
		var turn := Basis(Vector3.RIGHT, PI * 0.5) if i % 2 == 0 else Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.RIGHT, PI * 0.5)
		parent.add_child(_part(link, iron, top - Vector3(0, (i + 0.5) * length / n, 0), turn, Vector3(1, 1, 1.6)))


## The outline of the shield (x, y), its top middle at the origin: a flat top, straight sides to
## the shoulders and curved down to a point, `grow` metres larger all round.
static func outline(grow := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var w := WIDE * 0.5 + grow
	var top := grow
	var shoulder := -TALL * 0.4
	pts.append(Vector2(-w, top))
	pts.append(Vector2(w, top))
	pts.append(Vector2(w, shoulder))
	var steps := 10
	for i in range(1, steps):
		var t := float(i) / steps
		# A curve from the shoulder down to the point, bulging outwards.
		var x := w * (1.0 - t * t)
		var y := lerpf(shoulder, -TALL - grow, t)
		pts.append(Vector2(x * cos(t * 0.3), y))
	pts.append(Vector2(0, -TALL - grow * 1.4))
	for i in range(steps - 1, 0, -1):
		var t := float(i) / steps
		var x := w * (1.0 - t * t)
		var y := lerpf(shoulder, -TALL - grow, t)
		pts.append(Vector2(-x * cos(t * 0.3), y))
	pts.append(Vector2(-w, shoulder))
	return pts


static func _shield() -> ArrayMesh:
	if _shield_mesh == null:
		_shield_mesh = _slab(outline(), THICK)
	return _shield_mesh


static func _rim() -> ArrayMesh:
	if _rim_mesh == null:
		_rim_mesh = _slab(outline(RIM), THICK * 0.6)
	return _rim_mesh


## A flat slab of the outline `pts`, `thick` deep (centred on z = 0): both faces and the edge.
static func _slab(pts: PackedVector2Array, thick: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris := Geometry2D.triangulate_polygon(pts)
	var h := thick * 0.5
	for side: float in [1.0, -1.0]:
		st.set_normal(Vector3(0, 0, side))
		for i in range(0, tris.size(), 3):
			var order := [tris[i], tris[i + 1], tris[i + 2]] if side < 0 else [tris[i], tris[i + 2], tris[i + 1]]
			for k: int in order:
				st.add_vertex(Vector3(pts[k].x, pts[k].y, h * side))
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var n := Vector3(b.y - a.y, a.x - b.x, 0).normalized()
		st.set_normal(n)
		for v: Vector3 in [Vector3(a.x, a.y, h), Vector3(b.x, b.y, h), Vector3(b.x, b.y, -h),
				Vector3(a.x, a.y, h), Vector3(b.x, b.y, -h), Vector3(a.x, a.y, -h)]:
			st.add_vertex(v)
	return st.commit()


static func _mat(key: String, colour: Color, roughness := 0.8, metallic := 0.0, both_faces := false) -> StandardMaterial3D:
	if not _mats.has(key):
		var mat := StandardMaterial3D.new()
		if both_faces:
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_color = colour
		mat.roughness = roughness
		mat.metallic = metallic
		_mats[key] = mat
	return _mats[key]


static func _box(parent: Node3D, size: Vector3, at: Vector3, mat: Material, turn := Basis()) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := _part(mesh, mat, at, turn)
	parent.add_child(mi)
	return mi


static func _part(mesh: Mesh, mat: Material, at: Vector3, turn := Basis(), stretch := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = Transform3D(turn.scaled_local(stretch) if stretch != Vector3.ONE else turn, at)
	return mi
