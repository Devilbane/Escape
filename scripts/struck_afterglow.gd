class_name StruckAfterglow
extends Node3D
## What a body keeps from a lightning stroke for a couple of minutes (see
## LightningStrike): one of a few harmless, readable oddities picked at random.
## Purely for show: nobody is slowed, hurt or helped by it.
##
## "frizzy": crackling blue sparks round the head and now and then a "Bzzt!";
## "sooty": a dark coat of soot and wisps of smoke, with an odd "Hust!";
## "charged": a pulsing blue glow that lights its surroundings and a "Zzzap!"
## when it flares up.
## Ends by itself after LASTS seconds, or when the body is freed.

const KINDS := ["frizzy", "sooty", "charged"]
## How long it lasts (seconds), and how often the body speaks up (seconds).
const LASTS := 120.0
const SAYS_EVERY := Vector2(9.0, 18.0)
const SAYS := {"frizzy": "Bzzt!", "sooty": "Hust!", "charged": "Zzzap!"}
const SOOT := Color(0.08, 0.07, 0.07)
const SPARK := Color(0.7, 0.85, 1.0)

var kind := "frizzy"
var _left := LASTS
var _say_in := 4.0
var _pulse := 0.0
var _light: OmniLight3D
var _particles: CPUParticles3D
var _old_overlays := {}
var _soot: StandardMaterial3D
var _rng := RandomNumberGenerator.new()


## Puts a random afterglow on `who`, or the given kind. Returns it.
static func put_on(who: Node3D, which := "") -> StruckAfterglow:
	var old := who.get_node_or_null("StruckAfterglow")
	if old:
		old.queue_free()
	var a := StruckAfterglow.new()
	a.name = "StruckAfterglow"
	a.kind = which if which in KINDS else KINDS[randi() % KINDS.size()]
	who.add_child(a)
	return a


func _ready() -> void:
	_rng.randomize()
	position = Vector3(0, 1.3, 0)
	match kind:
		"frizzy":
			_particles = Effects.make_sparkles(SPARK, false)
			add_child(_particles)
		"sooty":
			_particles = Effects.make_sparkles(Color(0.35, 0.33, 0.32), false)
			add_child(_particles)
			_soot_on()
		"charged":
			_light = OmniLight3D.new()
			_light.light_color = SPARK
			_light.omni_range = 6.0
			add_child(_light)
	_say_in = _rng.randf_range(SAYS_EVERY.x * 0.3, SAYS_EVERY.y * 0.5)


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		queue_free()
		return
	var fade := clampf(_left / 10.0, 0.0, 1.0)
	if _particles:
		_particles.emitting = fade > 0.05
	if _light:
		_pulse += delta * 3.0
		_light.light_energy = (1.2 + sin(_pulse) * 0.8) * fade
	_say_in -= delta
	if _say_in <= 0.0:
		_say_in = _rng.randf_range(SAYS_EVERY.x, SAYS_EVERY.y)
		_speak()


func _speak() -> void:
	var who := get_parent() as Node3D
	if who == null or who.get("dead") == true or not who.visible:
		return
	var lvl = who.get("level")
	if lvl == null:
		return
	Effects.head_text(lvl, who, 2.8, Lang.t(SAYS[kind]), SPARK if kind != "sooty" else Color(0.7, 0.68, 0.66))
	if kind == "charged":
		var burst := Effects.make_sparkles(SPARK, true)
		burst.position = position
		who.add_child(burst)
		Sfx.play(who, "magic", -14.0, who.global_position, 1.6)


## A coat of soot over the body (the meshes' own overlay is kept and put back).
func _soot_on() -> void:
	var who := get_parent() as Node3D
	_soot = StandardMaterial3D.new()
	_soot.albedo_color = Color(SOOT, 0.7)
	_soot.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for mesh in who.find_children("*", "MeshInstance3D", true, false):
		var m := mesh as MeshInstance3D
		if m.material_overlay == null:
			_old_overlays[m] = null
			m.material_overlay = _soot


func _exit_tree() -> void:
	for m in _old_overlays:
		if is_instance_valid(m) and m.material_overlay == _soot:
			m.material_overlay = null
