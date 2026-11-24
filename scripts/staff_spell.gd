class_name StaffSpell
extends Node3D
## Priestess Elsbeth now and then raises her staff and intones a spell. Afterwards the staff
## glows with an enchanted light for a while, which slowly fades again. Purely for show.
##
## One of these hangs on the villager as a child. Villager calls `step` every physics tick of
## her work task: it waits a while, then she raises the staff (the "Spellcast_Raise" pose) and
## chants, and once the chant is done the staff glows (a warm light at its tip, an emissive
## sheen on the wood and a few drifting sparks) for GLOW_TIME seconds, brightest early on.

## Who does it (see Villager.ROLES).
const ROLE := "O"
## Seconds she waits between two spells, the chant itself, and how long the staff stays enchanted.
const WAIT := Vector2(35.0, 80.0)
const CHANT_TIME := 2.4
const GLOW_TIME := 28.0
## The glow swells in this long and over its last FADE_PART fades away.
const SWELL := 1.2
const FADE_PART := 0.55
const POSE := "Spellcast_Raise"
## What she intones (German; see scripts/lang/staff_spell.gd).
const CHANTS := [
	"Lux divina, accende baculum!",
	"Heiliges Licht, erfülle diesen Stab!",
	"Ave lux, ave vita!",
]
const LIGHT := Color(0.45, 0.65, 1.0)
const SPARK := Color(0.65, 0.8, 1.0)

var _villager: Villager
var _staff: Node3D
var _tip := Vector3.ZERO
var _wait := 0.0
var _chant_left := 0.0
var _glow_left := 0.0
var _time := 0.0
var _light: OmniLight3D
var _sparks: CPUParticles3D
var _sheen: StandardMaterial3D
var _meshes: Array[MeshInstance3D] = []
var _rng := RandomNumberGenerator.new()


## Hangs a StaffSpell on the villager (who must carry a staff). Returns it, null without a staff.
static func put_on(who: Villager) -> StaffSpell:
	var staff := who.find_child("2H_Staff", true, false) as Node3D
	if staff == null:
		return null
	var s := StaffSpell.new()
	s.name = "StaffSpell"
	s._villager = who
	s._staff = staff
	who.add_child(s)
	return s


func _ready() -> void:
	_rng.randomize()
	_wait = _rng.randf_range(WAIT.x * 0.3, WAIT.y * 0.6)
	for m in _staff.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(m)
	if _staff is MeshInstance3D:
		_meshes.append(_staff)
	# The tip of the staff, in its own space: the top of its mesh.
	var top := -INF
	var x := 0.0
	for m in _meshes:
		var box := m.get_aabb()
		if box.end.y > top:
			top = box.end.y
			x = box.get_center().x
	_tip = Vector3(x, top - 0.12, 0.0)
	_light = OmniLight3D.new()
	_light.light_color = LIGHT
	_light.omni_range = 4.5
	_light.light_energy = 0.0
	_light.visible = false
	_light.position = _tip
	_staff.add_child(_light)
	_sparks = Effects.make_sparkles(SPARK, false)
	_sparks.emission_sphere_radius = 0.15
	_sparks.gravity = Vector3(0, 0.5, 0)
	_sparks.emitting = false
	_sparks.position = _tip
	_staff.add_child(_sparks)
	_sheen = StandardMaterial3D.new()
	_sheen.albedo_color = Color(LIGHT, 0.0)
	_sheen.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_sheen.emission_enabled = true
	_sheen.emission = LIGHT
	_sheen.emission_energy_multiplier = 0.0


## How bright the enchantment is now, 0 to 1.
func glow() -> float:
	if _glow_left <= 0.0:
		return 0.0
	var spent := GLOW_TIME - _glow_left
	var swell := clampf(spent / SWELL, 0.0, 1.0)
	var fade := clampf(_glow_left / (GLOW_TIME * FADE_PART), 0.0, 1.0)
	return swell * fade


## Whether she is in the middle of the spell (her pose is held, nothing else may replace it).
func chanting() -> bool:
	return _chant_left > 0.0


## Whether the staff shines at all.
func glowing() -> bool:
	return _glow_left > 0.0


## Starts the spell at once (also what the timer does).
func cast() -> void:
	_chant_left = CHANT_TIME
	_villager.play(POSE, 0.15)
	_villager.say(CHANTS[_rng.randi() % CHANTS.size()], Vector3.INF, CHANT_TIME + 0.6)
	Sfx.play(_villager, "magic", -9.0, _villager.global_position, 0.8)


## Called by Villager every physics tick while she is at her work.
## Returns true while the spell holds the pose.
func step(delta: float, free: bool) -> bool:
	if _chant_left > 0.0 and not free and _villager._bubble_time <= 0.0:
		# Called away in the middle of it: no spell this time.
		_chant_left = 0.0
		return false
	if _chant_left > 0.0:
		_chant_left -= delta
		_villager.play(POSE, 0.15)
		if _chant_left <= 0.0:
			enchant()
		return true
	if _glow_left <= 0.0 and free:
		_wait -= delta
		if _wait <= 0.0:
			cast()
			return true
	return false


## The staff takes on its glow at once (also the end of a chant, and of a blessing).
func enchant() -> void:
	_glow_left = GLOW_TIME
	_wait = _rng.randf_range(WAIT.x, WAIT.y) + GLOW_TIME
	var burst := Effects.make_sparkles(SPARK, true)
	burst.position = _tip
	_staff.add_child(burst)
	get_tree().create_timer(2.5).timeout.connect(func(): if is_instance_valid(burst): burst.queue_free())
	Sfx.play(_villager, "magic", -12.0, _villager.global_position, 1.4)


func _process(delta: float) -> void:
	if _glow_left > 0.0:
		_glow_left -= delta
		_time += delta
	var g := glow()
	var shimmer := 1.0 + 0.12 * sin(_time * 7.0) + 0.06 * sin(_time * 13.0)
	_light.visible = g > 0.0
	_light.light_energy = 0.9 * g * shimmer
	_sparks.emitting = g > 0.05
	_sheen.albedo_color = Color(LIGHT, 0.15 * g)
	_sheen.emission_energy_multiplier = 1.1 * g * shimmer
	for m in _meshes:
		m.material_overlay = _sheen if g > 0.0 else null
