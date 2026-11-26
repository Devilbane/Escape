class_name GraveSpirit
extends Node3D
## Archy Stanton's neighbour in the graveyard of the valley map. Two graves stand side by side: Archy's, with a line
## about the good, the bad and the ugly, and one that is only marked "Unknown". Standing by the unknown grave at
## midnight raises a spirit (see spirit.gdshader) that asks whether the hero remembers its name. The right words
## in the chat line (see ChatLine) make three gold coins drop and the spirit sighs and fades. Once a night.
##
## The answer is kept out of the game's texts, the compendium, the patch notes, the tests and this repository: only
## a salted hash of it is stored (see RiddleVault). It is no official riddle and does not count on the riddle stone.

const GRAVES := {"Apfeltal": {"archy": Vector2i(18, 9), "unknown": Vector2i(20, 9)}}
const ARCHY := {"name": "Archy Stanton", "text": "Er liebte das Gute, das Böse und das Hässliche!"}
## The unknown grave has no name, only its word.
const UNKNOWN := {"name": "", "text": "Unbekannt"}
const QUESTION := "Erinnerst du dich an meinen Namen?"
const THANKS := "Nur eine Handvoll Gold!"
const SIGH := "Der Geist seufzt und verweht."
const APPEARS := "Ein Geist steigt aus dem Grab..."
## The gold coins the right answer pays, and how they lie.
const PAYS := 3
const COIN := "goldmuenze"
## The hours (a little round midnight) the spirit can be raised, and how near (metres) the hero must stand.
const FROM := 23.5
const TO := 0.5
const NEAR := 3.4
## How far (metres) the hero may go before the spirit drifts off, and how near the words must be said.
const LEAVE := 18.0
const HEARD := 14.0
## Seconds between the spirit's questions while it waits, and its fade.
const ASK_EVERY := 14.0
const FADE := 2.2

## The entry of the answer (see RiddleVault); no answer is stored anywhere.
const ENTRY := {"salt": "a51803f50ae91a4f5f6feb12", "rounds": 60000, "hash": "fe3bc4545d96d56f528fa5ad2277514768fe337ee5dc2cdcd197db0c3195260b"}
## Lets a test stand in for the answer with an entry of its own; empty is the real one.
static var test_entry := {}

const SPIRIT_SHADER := preload("res://shaders/spirit.gdshader")
const MODEL := "res://assets/enemies/Skeleton_Rogue.glb"

var level: Level
var _at := Vector3.ZERO
var _spirit: Node3D
var _mats: Array[ShaderMaterial] = []
var _alpha := 0.0
var _want := 0.0
var _ask_timer := 0.0
## This night's spirit has been answered: it does not come back until the next midnight.
var _paid := false
var _light: OmniLight3D


## The two graves' cells of a town, empty when it has none.
static func graves_of(town: String) -> Dictionary:
	return GRAVES.get(town, {})


## The inscription of a grave of the pair, empty for any other.
static func inscription(c: Vector2i, town: String) -> Dictionary:
	var g := graves_of(town)
	if g.is_empty():
		return {}
	if c == g.archy:
		return ARCHY
	if c == g.unknown:
		return UNKNOWN
	return {}


## Whether `hour` is the spirit's time.
static func is_midnight(hour: float) -> bool:
	return hour >= FROM or (hour >= 0.0 and hour < TO)


## Whether a line the hero said is the answer: case does not matter, nor spaces or marks between the words.
static func is_answer(text: String) -> bool:
	return RiddleVault.check(text, test_entry if not test_entry.is_empty() else ENTRY)


func setup(lvl: Level, unknown_grave: Vector3) -> void:
	level = lvl
	name = "GraveSpirit"
	# The spirit hovers beside the stone, towards the way the hero comes from.
	_at = unknown_grave + Vector3(0.95, 0.0, 0.5)
	position = _at


## Whether the spirit is out right now.
func is_out() -> bool:
	return _spirit != null and _want > 0.0


## Called every frame from the map with the clock (see Outdoor._process).
func tick(delta: float, hero: Vector3, hour: float) -> void:
	var near := Vector2(hero.x - _at.x, hero.z - _at.z).length()
	if not is_midnight(hour):
		_paid = false
		_want = 0.0
	elif _spirit == null or _want <= 0.0:
		if not _paid and near < NEAR and _want <= 0.0 and _alpha <= 0.01:
			_raise()
	elif near > LEAVE:
		_want = 0.0
	if _spirit != null:
		_alpha = move_toward(_alpha, _want, delta / FADE)
		for m in _mats:
			m.set_shader_parameter("alpha", _alpha)
		if _light != null:
			_light.light_energy = 0.9 * _alpha
		if _alpha <= 0.0 and _want <= 0.0:
			_clear()
			return
		_face(hero)
		_spirit.position.y = 0.25 + sin(Time.get_ticks_msec() * 0.0018) * 0.08
		if _want > 0.0 and _alpha > 0.6:
			_ask_timer -= delta
			if _ask_timer <= 0.0:
				_ask_timer = ASK_EVERY
				_ask()


## The hero said `text` at `pos` (see Events.hero_spoke).
func on_hero_spoke(text: String, pos: Vector3) -> void:
	if not is_out() or _alpha < 0.5 or Vector2(pos.x - _at.x, pos.z - _at.z).length() > HEARD:
		return
	if not is_answer(text):
		return
	_paid = true
	_want = 0.0
	Events.bus().graveyard_riddle.emit(GraveyardRiddles.SPIRIT)
	level.lay_coins(_at + Vector3(0.0, 0.0, 1.1), PAYS, COIN)
	Events.tell(Lang.t(THANKS), Color(1.0, 0.9, 0.5))
	Effects.float_text(level, _at + Vector3(0, 2.6, 0), Lang.t(THANKS), Color(1.0, 0.92, 0.55))
	Events.tell(Lang.t(SIGH), Color(0.8, 0.95, 0.9))


func _ask() -> void:
	Effects.float_text(level, _at + Vector3(0, 2.6, 0), Lang.t(QUESTION), Color(0.75, 1.0, 0.85))
	Events.tell(Lang.t(QUESTION), Color(0.75, 1.0, 0.85))


func _raise() -> void:
	_clear()
	var model: Node3D = load(MODEL).instantiate()
	_spirit = Node3D.new()
	_spirit.add_child(model)
	add_child(_spirit)
	var color := Color(0.95, 1.0, 0.97)
	var aura := Color(0.3, 0.95, 1.0)
	var body := AABB()
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	for mesh: MeshInstance3D in meshes:
		if mesh.mesh != null:
			body = mesh.get_aabb() if body.size == Vector3.ZERO else body.merge(mesh.get_aabb())
	for mesh: MeshInstance3D in meshes:
		if mesh.mesh == null:
			continue
		mesh.material_override = null
		for i in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(i) as BaseMaterial3D
			var mat := ShaderMaterial.new()
			mat.shader = SPIRIT_SHADER
			if source != null and source.albedo_texture != null:
				mat.set_shader_parameter("tex", source.albedo_texture)
				mat.set_shader_parameter("use_tex", true)
			mat.set_shader_parameter("color", color)
			mat.set_shader_parameter("aura", aura)
			mat.set_shader_parameter("alpha", 0.0)
			mat.set_shader_parameter("fade_low", body.position.y + 0.06 * body.size.y)
			mat.set_shader_parameter("fade_high", body.position.y + 0.42 * body.size.y)
			mesh.set_surface_override_material(i, mat)
			_mats.append(mat)
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player != null:
		for anim in player.get_animation_list():
			if String(anim).ends_with("Idle"):
				var a := player.get_animation(anim)
				if a != null:
					a.loop_mode = Animation.LOOP_LINEAR
				player.play(anim)
				break
	_light = OmniLight3D.new()
	_light.light_color = aura
	_light.light_energy = 0.0
	_light.omni_range = 3.5
	_light.position = Vector3(0, 1.4, 0)
	_spirit.add_child(_light)
	_want = 1.0
	_alpha = 0.0
	_ask_timer = 3.0
	Events.tell(Lang.t(APPEARS), Color(0.75, 1.0, 0.85))


func _face(hero: Vector3) -> void:
	var d := hero - global_position
	_spirit.rotation.y = lerp_angle(_spirit.rotation.y, atan2(d.x, d.z), 0.08)


func _clear() -> void:
	if _spirit != null:
		_spirit.queue_free()
	_spirit = null
	_light = null
	_mats.clear()
	_alpha = 0.0
	_want = 0.0
