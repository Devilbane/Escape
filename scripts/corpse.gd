class_name Corpse
extends Node
## A fallen monster stays where it fell and rots away, instead of sinking
## into the floor. This node sits on the dead Enemy and drives its decay:
##   flesh (bandits, beasts, horrors): darkens, sags flat and shrinks, then
##     leaves a dark stain with a few bones;
##   bones (skeletons): grey and slump, then crumble into a pile of bones;
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
## "wide"), and when it ends ("end", over "gone" seconds).
const STYLES := {
	"flesh": {"dark": 80.0, "black": 0.7, "sag": [6.0, 90.0], "flat": 0.3, "wide": 0.88, "end": 100.0, "gone": 6.0},
	"bones": {"dark": 40.0, "black": 0.5, "sag": [20.0, 45.0], "flat": 0.6, "wide": 1.0, "end": 50.0, "gone": 1.2},
	"melt": {"dark": 40.0, "black": 0.5, "sag": [0.0, 2.5], "flat": 0.14, "wide": 1.35, "end": 45.0, "gone": 5.0},
	"wisp": {"dark": 2.0, "black": 0.2, "sag": [0.0, 2.0], "flat": 0.6, "wide": 0.0, "end": 0.0, "gone": 2.0},
}
const ROT := Color(0.09, 0.07, 0.05)
const BONE := Color(0.8, 0.76, 0.66)
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
var _scale0 := Vector3.ONE
var _fog_timer := 0.0
var _done := false


## Lays `who` down to rot where it fell, and makes room if too many lie about.
static func lay(who: Enemy) -> Corpse:
	var c := Corpse.new()
	c.enemy = who
	c.style = style_of(who)
	who.add_child(c)
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
		mesh.material_overlay = _overlay
	# The dead give no light: glowing eyes and a horror's glow go out.
	for light in enemy.find_children("*", "Light3D", true, false):
		var fade := light.create_tween()
		fade.tween_property(light, "light_energy", 0.0, 1.5)
		fade.tween_callback(light.queue_free)


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
	_overlay.albedo_color.a = float(_rule.black) * clampf(age / float(_rule.dark), 0.0, 1.0)
	var sag: Array = _rule.sag
	var s := smoothstep(float(sag[0]), float(sag[1]), age)
	var shape := Vector3(lerpf(1.0, float(_rule.wide), s), lerpf(1.0, float(_rule.flat), s), lerpf(1.0, float(_rule.wide), s))
	if style == "wisp":
		shape = Vector3.ONE * lerpf(1.0, 0.0, s)
	var end := float(_rule.end)
	if age >= end:
		var gone := clampf((age - end) / float(_rule.gone), 0.0, 1.0)
		shape *= 1.0 - gone
		if gone >= 1.0:
			_finish()
			return
		if style == "bones" and gone > 0.0 and not has_meta("crumbled"):
			# The bones give way all at once, with a puff of dust (silent: a sound here
			# would draw on the shared random numbers the level runs depend on).
			set_meta("crumbled", true)
			_crumble_fx()
	enemy._model.scale = _scale0 * shape


## Comes to its end: what is left stays on the floor, the body goes.
func _finish() -> void:
	_done = true
	var level: Level = enemy.level
	if level != null and is_instance_valid(level) and style != "wisp":
		var bit := remnant(style, enemy.global_position, float(enemy._stats.size), enemy._stats.get("tint", SLIME))
		level.add_child(bit)
		bit.global_position = enemy.global_position
		level.remnants = level.remnants.filter(func(x): return is_instance_valid(x))
		level.remnants.append(bit)
		while level.remnants.size() > MAX_REMNANTS:
			level.remnants.pop_front().queue_free()
		level.corpses.erase(self)
	enemy.queue_free()


func _crumble_fx() -> void:
	var level: Level = enemy.level
	if level == null or not enemy.visible:
		return
	var dust := Effects.make_sparkles(Color(0.78, 0.74, 0.66), true)
	level.add_child(dust)
	dust.global_position = enemy.global_position + Vector3(0, 0.5, 0)


## What is left of a corpse of `style` and `size`: a dark stain (a slime's
## in its own colour), with a few bones for flesh and a heap for bones.
static func remnant(kind_style: String, at: Vector3, size: float, tint: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Remnant"
	root.rotation.y = absf(at.x * 7.3 + at.z * 3.1)
	var stain := MeshInstance3D.new()
	stain.mesh = _stain()
	stain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = _stain_tex
	mat.albedo_color = Color(tint.darkened(0.45), 0.6) if kind_style == "melt" else Color(0.05, 0.035, 0.025, 0.7 if kind_style == "flesh" else 0.45)
	stain.material_override = mat
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
