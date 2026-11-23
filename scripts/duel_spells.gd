class_name DuelSpells
extends RefCounted
## The spells of the mages' practice duel (see MageDuel): four harmless shows of
## light, each with its own look and sound. They damage nothing, they only fly,
## burst and fade. A spell that "misses" sails past the target and fizzles on the
## ground behind it.
##
##   fire    an orange fire bolt with a flickering flame
##   frost   a spinning shard of ice with a trail of snow glitter
##   arcane  a violet orb with three little stars circling it
##   storm   a jagged bolt of lightning that strikes at once

const KINDS := ["fire", "frost", "arcane", "storm"]
## What the caster calls out (German, see Lang): shown over their head.
const NAMES := {"fire": "Feuerblitz!", "frost": "Frostsplitter!", "arcane": "Arkanorb!", "storm": "Blitzschlag!"}
const COLOURS := {
	"fire": Color(1.0, 0.5, 0.15),
	"frost": Color(0.6, 0.9, 1.0),
	"arcane": Color(0.75, 0.35, 1.0),
	"storm": Color(0.85, 0.9, 1.0),
}
## Seconds a bolt, shard or orb takes for one metre (the lightning needs none).
const SECONDS_PER_METRE := 0.09
## How long the flash and the glitter of a burst last, and a bolt of lightning stays lit.
const BURST_TIME := 0.7
const STORM_TIME := 0.32
## How far past the target a spell that misses flies, and how far to the side it veers (metres).
const MISS_PAST := 3.0
const MISS_SIDE := 1.6


## How long `kind` takes from `from` to `to` until it has burst, in seconds.
static func flight_time(kind: String, from: Vector3, to: Vector3) -> float:
	if kind == "storm":
		return 0.0
	return maxf(0.35, from.distance_to(to) * SECONDS_PER_METRE)


## Where a spell that misses ends up: past the target, off to one side, near the ground.
static func miss_point(from: Vector3, to: Vector3, side := 1.0) -> Vector3:
	var along := Vector3(to.x - from.x, 0.0, to.z - from.z).normalized()
	var across := Vector3(-along.z, 0.0, along.x)
	return Vector3(to.x, 0.5, to.z) + along * MISS_PAST + across * MISS_SIDE * side


## Casts `kind` from `from` towards `to` and returns the seconds until it has landed (or
## fizzled). `hit`: it bursts on the target; otherwise it flies wide.
static func cast(level: Node, kind: String, from: Vector3, to: Vector3, hit: bool, side := 1.0) -> float:
	var end := to if hit else miss_point(from, to, side)
	Sfx.play(level, "magic", -6.0, from, {"fire": 0.8, "frost": 1.35, "arcane": 1.05, "storm": 0.6}.get(kind, 1.0))
	if kind == "storm":
		_lightning(level, from, end, hit)
		return STORM_TIME
	var time := flight_time(kind, from, end)
	var spell := _body(kind)
	level.add_child(spell)
	spell.global_position = from
	var tween := spell.create_tween()
	tween.tween_property(spell, "global_position", end, time)
	tween.tween_callback(func():
		_burst(level, kind, end, hit)
		spell.queue_free())
	return time


## The glowing thing that flies.
static func _body(kind: String) -> Node3D:
	var colour: Color = COLOURS[kind]
	var body := Node3D.new()
	body.name = "DuelSpell_" + kind
	match kind:
		"fire":
			body.add_child(_ball(0.34, Color(1.0, 0.65, 0.2)))
			var flame := Effects.make_flame()
			flame.scale = Vector3.ONE * 2.2
			flame.local_coords = false
			body.add_child(flame)
		"frost":
			var shard := Node3D.new()
			shard.add_child(_cone(0.18, 1.0, Vector3(0, 0, 0), Color(0.75, 0.95, 1.0)))
			shard.add_child(_cone(0.18, 0.55, Vector3(0, 0, 0), Color(0.5, 0.8, 1.0), true))
			body.add_child(shard)
			var spin := shard.create_tween().set_loops()
			spin.tween_property(shard, "rotation:z", TAU, 0.45).from(0.0)
			var glitter := Effects.make_sparkles(Color(0.85, 0.97, 1.0))
			glitter.local_coords = false
			glitter.amount = 24
			body.add_child(glitter)
		"arcane":
			body.add_child(_ball(0.26, Color(0.85, 0.5, 1.0)))
			var ring := Node3D.new()
			body.add_child(ring)
			for i in 3:
				var star := _ball(0.08, Color(1.0, 0.85, 1.0))
				var angle := TAU * i / 3.0
				star.position = Vector3(cos(angle), sin(angle) * 0.6, sin(angle)) * 0.55
				ring.add_child(star)
			var turn := ring.create_tween().set_loops()
			turn.tween_property(ring, "rotation:y", TAU, 0.8).from(0.0)
			var motes := Effects.make_sparkles(colour)
			motes.local_coords = false
			body.add_child(motes)
	var glow := OmniLight3D.new()
	glow.light_color = colour
	glow.light_energy = 1.6
	glow.omni_range = 4.0
	body.add_child(glow)
	return body


static func _unshaded(colour: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = colour
	return mat


static func _ball(radius: float, colour: Color) -> MeshInstance3D:
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	ball.mesh = sphere
	ball.material_override = _unshaded(colour)
	return ball


## One cone of a crystal along the flight (the z axis): `back` points it behind.
static func _cone(radius: float, length: float, at: Vector3, colour: Color, back := false) -> MeshInstance3D:
	var cone := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 6
	cone.mesh = mesh
	cone.material_override = _unshaded(colour)
	cone.position = at + Vector3(0, 0, length * 0.5 * (1.0 if back else -1.0))
	# A cylinder stands up (y); lay it along z with its tip ahead (-z) or behind.
	cone.rotation.x = PI * 0.5 if not back else -PI * 0.5
	return cone


## What a spell does where it lands: a flash, a burst of glitter in its colour and a thump.
## A miss only fizzles, small and grey-edged.
static func _burst(level: Node, kind: String, at: Vector3, hit: bool) -> void:
	var colour: Color = COLOURS[kind]
	var burst := Node3D.new()
	level.add_child(burst)
	burst.global_position = at
	var sparks := Effects.make_sparkles(colour if hit else colour.lerp(Color(0.6, 0.6, 0.6), 0.5), true)
	if not hit:
		sparks.amount = 14
	burst.add_child(sparks)
	var flash := OmniLight3D.new()
	flash.light_color = colour
	flash.light_energy = 3.0 if hit else 1.2
	flash.omni_range = 5.0
	burst.add_child(flash)
	var fade := burst.create_tween()
	fade.tween_property(flash, "light_energy", 0.0, BURST_TIME * 0.8)
	fade.tween_interval(BURST_TIME)
	fade.tween_callback(burst.queue_free)
	Sfx.play(level, "hit", -14.0 if hit else -20.0, at, {"fire": 0.7, "frost": 1.5, "arcane": 1.1, "storm": 0.9}.get(kind, 1.0))


## A jagged bolt of lightning from the caster's hand to the target (or the ground beside it).
static func _lightning(level: Node, from: Vector3, to: Vector3, hit: bool) -> void:
	var colour: Color = COLOURS["storm"]
	var bolt := Node3D.new()
	bolt.name = "DuelLightning"
	level.add_child(bolt)
	var strike := to if hit else Vector3(to.x, 0.0, to.z)
	_zigzag(bolt, from, strike)
	var flash := OmniLight3D.new()
	flash.light_color = Color(0.7, 0.8, 1.0)
	flash.light_energy = 4.0
	flash.omni_range = 7.0
	flash.position = strike
	bolt.add_child(flash)
	Sfx.play(level, "thunder", -12.0, strike, 1.4)
	# It flickers: the path is drawn again twice, then gone.
	var flicker := bolt.create_tween()
	for i in 2:
		flicker.tween_interval(STORM_TIME / 3.0)
		flicker.tween_callback(func():
			for child in bolt.get_children():
				if child is MeshInstance3D:
					child.queue_free()
			_zigzag(bolt, from, strike))
	flicker.tween_interval(STORM_TIME / 3.0)
	flicker.tween_callback(func():
		_burst(level, "storm", strike, hit)
		bolt.queue_free())
	# The strike point rings with glitter at once.
	var rim := Effects.make_sparkles(colour, true)
	rim.position = strike
	bolt.add_child(rim)


static func _zigzag(parent: Node3D, from: Vector3, to: Vector3) -> void:
	var points := [from]
	var steps := 7
	var across := Vector3(-(to.z - from.z), 0.0, to.x - from.x).normalized()
	for i in range(1, steps):
		var p := from.lerp(to, float(i) / steps)
		p += across * randf_range(-0.35, 0.35) + Vector3(0, randf_range(-0.3, 0.3), 0)
		points.append(p)
	points.append(to)
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var seg := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.09, 0.09, a.distance_to(b))
		seg.mesh = mesh
		seg.material_override = _unshaded(Color(0.9, 0.95, 1.0))
		parent.add_child(seg)
		seg.global_position = (a + b) * 0.5
		seg.look_at(b, Vector3.UP)
