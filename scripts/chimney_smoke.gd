class_name ChimneySmoke
extends RefCounted
## Smoke from the chimneys of the village houses on the evenings someone is
## at home. When the villagers come home at nightfall (see Villager.set_night)
## they light the fire, and a thin grey plume curls up out of their house's
## chimney and drifts off with the breeze. Late in the evening the fire burns
## down and the smoke thins away; an empty house never smokes.
##
## The plume is made like the other particles (see Effects): the same soft
## dot on the same additive, unshaded material kind, so no shader is new to
## the renderer when the first fire is lit (see LevelWarmup). Added light
## reads as pale smoke against the dark of the night.
## Tested by tests/chimney_smoke.gd.

## The fires burn from the hour the village goes home (DayNight.NIGHT_FROM)
## until FIRE_OUT, after midnight.
const FIRE_OUT := 1.0
## The breeze the smoke drifts off on (metres per second squared).
const BREEZE := Vector3(0.22, 0.32, 0.08)
## The smoke's colour: a cool grey, faint (it is added to what lies behind).
const GREY := Color(0.62, 0.64, 0.7)


## Whether the fires burn at an hour, for a house with someone at home.
static func fire_burns(hour: float) -> bool:
	hour = fposmod(hour, 24.0)
	return hour >= DayNight.NIGHT_FROM or hour < FIRE_OUT


## Whether a house's chimney smokes: in the evening, with someone at home.
static func smokes(hour: float, at_home: int) -> bool:
	return at_home > 0 and fire_burns(hour)


## A plume of smoke, to be put on top of a chimney. It starts cold (not
## emitting); `light` lights or puts out the fire.
static func make() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "ChimneySmoke"
	p.amount = 22
	p.lifetime = 6.5
	# The smoke stays where it was let out, so the breeze carries it off
	# even if the house is moved.
	p.local_coords = false
	p.emitting = false
	p.mesh = Effects._quad(0.9, Color(1, 1, 1))
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.18
	p.direction = Vector3.UP
	p.spread = 10.0
	p.gravity = BREEZE
	p.initial_velocity_min = 0.45
	p.initial_velocity_max = 0.7
	p.damping_min = 0.1
	p.damping_max = 0.2
	# No spin: a soft round dot looks the same turned, and a turning
	# billboard particle is the only kind that reads its instance custom data
	# (the angle). On some graphics drivers the compatibility renderer then
	# mixes up the instance data, and the smoke came out as glaring green and
	# yellow balls over the roof. Without spin it is drawn like every other
	# particle in the game.
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.2
	# Small and dense at the chimney's mouth, wide and thin up high.
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.35))
	grow.add_point(Vector2(0.4, 1.3))
	grow.add_point(Vector2(1, 2.6))
	p.scale_amount_curve = grow
	var ramp := Gradient.new()
	ramp.set_color(0, Color(GREY, 0.0))
	ramp.add_point(0.12, Color(GREY, 0.42))
	ramp.add_point(0.5, Color(GREY, 0.24))
	ramp.set_color(ramp.get_point_count() - 1, Color(GREY, 0.0))
	p.color_ramp = ramp
	return p


## Lights the fire under a plume or puts it out. Smoke already in the air
## drifts on and fades; `at_once` (a game loaded in the evening) has the
## plume standing over the roof straight away.
static func light(plume: CPUParticles3D, on: bool, at_once := false) -> void:
	if plume.emitting == on:
		return
	plume.emitting = on
	if on and at_once:
		plume.preprocess = plume.lifetime
		plume.restart()
	elif not on and at_once:
		plume.restart()
		plume.emitting = false
