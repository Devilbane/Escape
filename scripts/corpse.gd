class_name Corpse
extends Node
## A fallen monster stays where it fell and rots away, instead of sinking
## into the floor. This node sits on the dead Enemy and drives its decay:
##   flesh (bandits, beasts, horrors): darkens and sags flat (a bandit with
##     black crosses for eyes, see DeadEyes), then sinks
##     away into a dark stain, and a real skeleton (see Remains) lies where
##     the body lay;
##   bones (skeletons): grey and slump, then fall apart into the same kind
##     of skeleton (no dust or sound: both would draw on the shared random
##     numbers, and the level runs in tests/play_all_levels.gd depend on
##     that stream);
##   melt (slimes): run out flat at once into a puddle that dries to a stain;
##   wisp (fog wraiths): blow away in a moment and leave nothing.
## For the web build only a few corpses lie about at once (MAX_CORPSES): a
## new one hurries the oldest to its end. The remnants are cheap static
## meshes, also capped (MAX_REMNANTS). Neither is kept when the hero leaves
## the level: a level is built fresh on the way back in, and the dead with it.

## At most this many corpses lie on one level at once.
const MAX_CORPSES := 8
## At most this many stains and bone piles stay on one level.
const MAX_REMNANTS := 24
## How often the corpse checks whether the fog of war hides it (seconds).
const FOG_CHECK := 0.25

## Per style: when the darkening is full and how dark ("dark", "black"),
## when the body starts and stops sagging and to what shape ("sag", "flat",
## "wide"), and when it ends ("end", over "gone" seconds). Over its end the
## body goes flat and black while the stain beneath it shows: the bones
## left behind keep the body's size and outline, nothing shrinks.
const STYLES := {
	"flesh": {"dark": 80.0, "black": 0.7, "sag": [6.0, 90.0], "flat": 0.3, "wide": 1.0, "end": 100.0, "gone": 8.0},
	"bones": {"dark": 40.0, "black": 0.5, "sag": [20.0, 45.0], "flat": 0.6, "wide": 1.0, "end": 50.0, "gone": 6.0},
	"melt": {"dark": 40.0, "black": 0.5, "sag": [0.0, 2.5], "flat": 0.14, "wide": 1.35, "end": 45.0, "gone": 5.0},
	"wisp": {"dark": 2.0, "black": 0.2, "sag": [0.0, 2.0], "flat": 0.6, "wide": 0.0, "end": 0.0, "gone": 2.0},
}
const ROT := Color(0.09, 0.07, 0.05)
## How dark the body is when it has gone flat at its very end.
const LAST_BLACK := 0.92
const BONE := Color(0.64, 0.58, 0.47)
## A plain slime has no tint of its own: its puddle is slime green.
const SLIME := Color(0.36, 0.78, 0.26)

static var _bone_mesh: ArrayMesh
static var _bone_mat: StandardMaterial3D
static var _stain_mesh: PlaneMesh
static var _stain_tex: GradientTexture2D

var enemy: Enemy
var style := "flesh"
## Seconds since it fell.
var age := 0.0
var _rule: Dictionary
var _overlay: StandardMaterial3D
## Copies of the rot layer for meshes that are cut to a shape by their
## texture's alpha (a slime's round puddle is a square plane): each copy
## carries that texture, so the rot darkens only the shape, not the square.
var _shaped: Array[StandardMaterial3D] = []
var _scale0 := Vector3.ONE
var _fog_timer := 0.0
var _done := false
## What it leaves behind, laid out as its end begins, and its stain's look.
var _remnant: Node3D
var _stain_mat: StandardMaterial3D
var _stain_alpha := 0.0


## Lays `who` down to rot where it fell, and makes room if too many lie about.
static func lay(who: Enemy) -> Corpse:
	var c := Corpse.new()
	c.enemy = who
	c.style = style_of(who)
	who.add_child(c)
	# The dead are no fighters: comic bubbles may cover them.
	who.remove_from_group("combatant")
	var level: Level = who.level
	if level != null:
		level.corpses = level.corpses.filter(func(x): return is_instance_valid(x) and not x._done)
		level.corpses.append(c)
		while level.corpses.size() > MAX_CORPSES:
			level.corpses.pop_front().hurry()
	return c


## How a kind rots away.
static func style_of(who: Enemy) -> String:
	if who.kind == "fog_wraith":
		return "wisp"
	if who.kind.contains("schleim"):
		return "melt"
	if who.is_human() or who.is_beast():
		return "flesh"
	return "bones"


func _ready() -> void:
	_rule = STYLES[style]
	_scale0 = enemy._model.scale
	# Rot darkens it from the first moment: one see-through layer over
	# every mesh, so its own colours and tints stay underneath.
	_overlay = StandardMaterial3D.new()
	_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_overlay.albedo_color = Color(ROT, 0.0)
	for mesh: MeshInstance3D in enemy._model.find_children("*", "MeshInstance3D", true, false):
		mesh.material_overlay = _overlay_for(mesh)
	# A dead person's eyes are covered in skin and crossed out in black
	# (see DeadEyes): the skin rots with the face, the crosses stay till the end.
	if enemy.is_human():
		DeadEyes.put_on(enemy._model, _overlay)
	# The dead give no light: glowing eyes and a horror's glow go out.
	for light in enemy.find_children("*", "Light3D", true, false):
		var fade := light.create_tween()
		fade.tween_property(light, "light_energy", 0.0, 1.5)
		fade.tween_callback(light.queue_free)


## The rot layer for `mesh`: the shared one, or a copy cut to the shape
## of its texture when that texture's alpha shapes it.
func _overlay_for(mesh: MeshInstance3D) -> StandardMaterial3D:
	var own := mesh.material_override as BaseMaterial3D
	if own == null or own.albedo_texture == null or own.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
		return _overlay
	var cut := _overlay.duplicate() as StandardMaterial3D
	cut.albedo_texture = own.albedo_texture
	_shaped.append(cut)
	return cut


## How dark the rot is (0 none, 1 black), on every layer.
func _set_rot(a: float) -> void:
	_overlay.albedo_color.a = a
	for cut in _shaped:
		cut.albedo_color.a = a


## Too many corpses: this one, the oldest, goes to its end now.
func hurry() -> void:
	age = maxf(age, float(_rule.end))


func _process(delta: float) -> void:
	if _done or not is_instance_valid(enemy):
		return
	age += delta
	_fog_timer -= delta
	if _fog_timer <= 0.0:
		_fog_timer = FOG_CHECK
		var level: Level = enemy.level
		if level != null:
			enemy.visible = level.fog == null or level.fog.is_cell_visible(level.world_to_cell(enemy.global_position))
	_set_rot(float(_rule.black) * clampf(age / float(_rule.dark), 0.0, 1.0))
	var sag: Array = _rule.sag
	var s := smoothstep(float(sag[0]), float(sag[1]), age)
	var shape := Vector3(lerpf(1.0, float(_rule.wide), s), lerpf(1.0, float(_rule.flat), s), lerpf(1.0, float(_rule.wide), s))
	if style == "wisp":
		shape = Vector3.ONE * lerpf(1.0, 0.0, s)
	var end := float(_rule.end)
	if age >= end:
		var gone := clampf((age - end) / float(_rule.gone), 0.0, 1.0)
		if style == "wisp":
			shape *= 1.0 - gone
		else:
			# No shrinking: the body sinks flat and black into its stain, and
			# the bones beneath, laid out as it lies, are what stays.
			_leave_remnant()
			var g := smoothstep(0.0, 1.0, gone)
			shape.y *= lerpf(1.0, 0.04, g)
			_set_rot(lerpf(_overlay.albedo_color.a, LAST_BLACK, g))
			DeadEyes.fade(enemy._model, 1.0 - g)
			if _stain_mat != null:
				_stain_mat.albedo_color.a = _stain_alpha * g
		if gone >= 1.0:
			_finish()
			return
	enemy._model.scale = _scale0 * shape


## Comes to its end: what is left stays on the floor, the body goes.
func _finish() -> void:
	_leave_remnant()
	_done = true
	if _stain_mat != null:
		_stain_mat.albedo_color.a = _stain_alpha
	var level: Level = enemy.level
	if level != null and is_instance_valid(level):
		level.corpses.erase(self)
	enemy.queue_free()


## Lays out what is left (once, as its end begins): bones where the body's
## bones lie right now, and a stain under them, still see-through.
func _leave_remnant() -> void:
	if _remnant != null or style == "wisp":
		return
	var level: Level = enemy.level
	if level == null or not is_instance_valid(level):
		return
	var size := float(enemy._stats.size)
	var layout := bone_layout() if style != "melt" else {}
	if layout.is_empty():
		_remnant = remnant(style, enemy.global_position, size, enemy._stats.get("tint", SLIME))
	else:
		var model := String(enemy._stats.model)
		var humanlike := model in ["Orc", "Yeti"] or not enemy.is_beast()
		_remnant = shaped_remnant(style, layout, not humanlike, model == "Spider")
	level.add_child(_remnant)
	_remnant.global_position = enemy.global_position
	_stain_mat = (_remnant.get_child(0) as MeshInstance3D).material_override
	_stain_alpha = _stain_mat.albedo_color.a
	_stain_mat.albedo_color.a = 0.0
	level.remnants = level.remnants.filter(func(x): return is_instance_valid(x))
	level.remnants.append(_remnant)
	while level.remnants.size() > MAX_REMNANTS:
		level.remnants.pop_front().queue_free()


## The body's rig as it lies (see Remains.read_rig), or empty when the
## model has no skeleton with a head to go by.
func bone_layout() -> Dictionary:
	return Remains.read_rig(enemy._model.find_child("Skeleton3D", true, false) as Skeleton3D, enemy.global_position)


## A stain the size of the body, and a real skeleton laid out along its rig
## (see Remains): skull, spine, ribcage, pelvis and jointed limbs. A spider
## leaves its husk and legs; a beast's skull has a snout.
static func shaped_remnant(kind_style: String, rig: Dictionary, beast: bool, husk: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "Remnant"
	var low := Vector3(INF, 0, INF)
	var high := Vector3(-INF, 0, -INF)
	var pos: Array = rig.pos
	var parent: Array = rig.parent
	for i in pos.size():
		if parent[i] == -2:
			continue
		var p: Vector3 = pos[i]
		low = Vector3(minf(low.x, p.x), 0, minf(low.z, p.z))
		high = Vector3(maxf(high.x, p.x), 0, maxf(high.z, p.z))
	var stain := _stain_node(kind_style, Color.WHITE)
	var reach := (high - low) + Vector3.ONE * 0.9
	stain.position = (low + high) * 0.5 + Vector3(0, 0.03, 0)
	stain.scale = Vector3(reach.x / 1.8, 1.0, reach.z / 1.8)
	root.add_child(stain)
	root.add_child(Remains.build(rig, beast, husk))
	return root


## What is left of a corpse of `style` and `size` when its model has no
## skeleton to go by: a dark stain (a slime's in its own colour), with a few
## bones for flesh and a heap for bones.
static func remnant(kind_style: String, at: Vector3, size: float, tint: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Remnant"
	root.rotation.y = absf(at.x * 7.3 + at.z * 3.1)
	var stain := _stain_node(kind_style, tint)
	stain.position.y = 0.03
	stain.scale = Vector3(1.0, 1.0, 0.75) * size * (1.3 if kind_style == "melt" else 1.0)
	root.add_child(stain)
	if kind_style != "melt":
		var bones := MeshInstance3D.new()
		bones.mesh = _bones()
		bones.material_override = _bone_mat
		bones.scale = Vector3.ONE * size * (1.0 if kind_style == "bones" else 0.6)
		root.add_child(bones)
	return root


## A stain of its own colour (a slime's in `tint`), so it can fade in alone.
static func _stain_node(kind_style: String, tint: Color) -> MeshInstance3D:
	var stain := MeshInstance3D.new()
	stain.mesh = _stain()
	stain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = _stain_tex
	mat.albedo_color = Color(tint.darkened(0.45), 0.6) if kind_style == "melt" else Color(0.05, 0.035, 0.025, 0.7 if kind_style == "flesh" else 0.45)
	stain.material_override = mat
	return stain


## A soft round stain: a flat square with a round fading spot on it.
static func _stain() -> PlaneMesh:
	if _stain_mesh == null:
		_stain_mesh = PlaneMesh.new()
		_stain_mesh.size = Vector2(1.8, 1.8)
		var fade := Gradient.new()
		fade.set_color(0, Color(1, 1, 1, 1))
		fade.add_point(0.45, Color(1, 1, 1, 0.8))
		fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
		_stain_tex = GradientTexture2D.new()
		_stain_tex.gradient = fade
		_stain_tex.fill = GradientTexture2D.FILL_RADIAL
		_stain_tex.fill_from = Vector2(0.5, 0.5)
		_stain_tex.fill_to = Vector2(1.0, 0.5)
		_stain_tex.width = 64
		_stain_tex.height = 64
	return _stain_mesh


## A heap of bones and a skull as one mesh, built once and shared.
static func _bones() -> ArrayMesh:
	if _bone_mesh != null:
		return _bone_mesh
	_bone_mat = StandardMaterial3D.new()
	_bone_mat.albedo_color = BONE
	_bone_mat.roughness = 0.9
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bone := CapsuleMesh.new()
	bone.radius = 0.045
	bone.height = 0.55
	bone.radial_segments = 6
	bone.rings = 1
	# Bones lie flat and crossed; the last two are short.
	var spots := [[Vector3(0.15, 0.05, 0.05), 0.3], [Vector3(-0.2, 0.05, 0.1), 1.9], [Vector3(0.0, 0.09, -0.15), 1.1],
		[Vector3(0.25, 0.05, -0.2), 2.6], [Vector3(-0.1, 0.05, -0.3), 0.7]]
	for i in spots.size():
		var b := Basis(Vector3.UP, spots[i][1]) * Basis(Vector3.RIGHT, PI * 0.5)
		if i >= 3:
			b = b.scaled(Vector3(1, 0.6, 1))
		st.append_from(bone, 0, Transform3D(b, spots[i][0]))
	var skull := SphereMesh.new()
	skull.radius = 0.15
	skull.height = 0.26
	skull.radial_segments = 8
	skull.rings = 4
	st.append_from(skull, 0, Transform3D(Basis(), Vector3(-0.3, 0.12, -0.05)))
	_bone_mesh = st.commit()
	return _bone_mesh
