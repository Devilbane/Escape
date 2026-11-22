class_name LightMatch
extends RefCounted
## Keeps the light of the modern renderer (Forward+, see Graphics.modern) looking as it does on
## OpenGL, the renderer the game's light was tuned on.
##
## The two add light up differently. OpenGL draws every light that casts shadows (the sun or
## moon, and the few lamps LightShadows picks) in a pass of its own and adds that pass to the
## finished picture, after the brightness curve (tone mapping and the screen's gamma). The curve
## is steep in the dark and flat in the bright, so light added after it counts for more: the sun
## on a sunlit street, a lamp's dim outer reach on a lit floor. The modern renderer adds all
## light first and bends the sum once, which is the correct way, and comes out flatter and darker
## with the very same lights.
##
## So on the modern renderer the lights that OpenGL would add afterwards are made stronger by
## just as much as it takes to land on the same picture:
## - the sun or moon (see sun): its colour and strength, worked out for sunlit ground;
## - a lamp that casts shadows (see lamp): stronger, and with a gentler fall-off, because
##   OpenGL's lamps keep a long dim tail.
## The match is exact where it is worked out (flat ground, a surface of middling brightness) and
## close elsewhere. On OpenGL nothing is changed.

## How bright a middling surface is (linear albedo): cobbles, grass, wood, stone walls.
const ALBEDO := 0.3
## The game's tone mapping exposure (see Game._setup_world).
const EXPOSURE := 0.95
## A lamp is never made more than this much stronger, however dim it is against the sky.
const MAX_BOOST := 6.0
## The gentlest fall-off a matched lamp gets.
const MIN_ATTENUATION := 0.05
## Where along its reach a lamp is matched: near it and well out, as shares of its range.
const NEAR := 0.25
const FAR := 0.7


## The picture's brightness (0 to 1 on the screen) for a linear light value: Godot's filmic tone
## mapping at the game's exposure, then the screen's gamma (sRGB).
static func curve(x: float) -> float:
	var c := maxf(x, 0.0) * EXPOSURE
	# Godot's tonemap_filmic with white = 1 (servers/rendering/renderer_rd/shaders/effects/tonemap.glsl).
	var mapped := _filmic(c) / _filmic(1.0)
	mapped = clampf(mapped, 0.0, 1.0)
	return mapped * 12.92 if mapped < 0.0031308 else 1.055 * pow(mapped, 1.0 / 2.4) - 0.055


static func _filmic(x: float) -> float:
	const A := 0.22 * 4.0
	const B := 0.30 * 2.0
	const C := 0.10
	const D := 0.20
	const E := 0.01
	const F := 0.30
	return ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * F)) - E / F


## The linear light value that the curve shows as `y` (curve's inverse).
static func uncurve(y: float) -> float:
	if y <= 0.0:
		return 0.0
	var lo := 0.0
	var hi := 1.0
	while curve(hi) < y and hi < 64.0:
		hi *= 2.0
	for i in 24:
		var mid := (lo + hi) * 0.5
		if curve(mid) < y:
			lo = mid
		else:
			hi = mid
	return (lo + hi) * 0.5


## How strong a light must be on the modern renderer to look like `light` added OpenGL's way to
## a surface already lit by `base` (both linear light on the surface, one colour channel).
static func stacked(base: float, light: float) -> float:
	if light <= 0.0:
		return 0.0
	var shown := minf(curve(ALBEDO * base) + curve(ALBEDO * light), 1.0)
	return maxf(uncurve(shown) / ALBEDO - base, light)


## How bright the sky's own light is right now (the environment's ambient light, linear), set by
## sun and read by the lamps (see LightShadows).
static var sky := 0.0


## Matches the sun or moon to the sky's own light (the environment's ambient light): sets its
## colour and strength so sunlit flat ground looks as on OpenGL. Call it once after the hour, the
## moon and the weather have set them for the frame; it is no step on top of an earlier call.
static func sun(env: Environment, light: DirectionalLight3D) -> void:
	# Light colours are sRGB; the renderer works with their linear values.
	var above := env.ambient_light_color.srgb_to_linear() * env.ambient_light_energy
	sky = above.get_luminance()
	if not Graphics.modern() or light.light_energy <= 0.0:
		return
	# How steeply the light falls on flat ground.
	var slant := maxf(-light.global_basis.z.y, 0.05)
	var lit := light.light_color.srgb_to_linear() * light.light_energy * slant
	var want := Color(stacked(above.r, lit.r), stacked(above.g, lit.g), stacked(above.b, lit.b))
	var strength := maxf(want.r, maxf(want.g, want.b))
	if strength <= 0.0:
		return
	light.light_color = Color(want.r / strength, want.g / strength, want.b / strength).linear_to_srgb()
	light.light_energy = strength / slant


## How bright an omni light is at `distance` for a strength of 1 (Godot's fall-off: a soft
## window to the end of its range times distance to the power of minus its attenuation).
static func falloff(distance: float, reach: float, attenuation: float) -> float:
	var nd := distance / reach
	nd *= nd
	nd *= nd
	nd = maxf(1.0 - nd, 0.0)
	return nd * nd * pow(maxf(distance, 0.0001), -attenuation)


## A shadow-casting lamp matched to the light around it: returns [boost, attenuation] that make
## it look on the modern renderer as a lamp of `energy` (its linear brightness: strength times
## its colour's), `reach` and `attenuation` looks on OpenGL over a surface lit by `base` (the
## sky's ambient light, linear). Its strength is to be multiplied by boost. Matched at two
## distances (NEAR and FAR), so both its core and its long dim tail fit.
static func lamp(energy: float, reach: float, attenuation: float, base: float) -> Array:
	if energy <= 0.0 or reach <= 0.0:
		return [1.0, attenuation]
	var d1 := reach * NEAR
	var d2 := reach * FAR
	var is1 := energy * falloff(d1, reach, attenuation)
	var is2 := energy * falloff(d2, reach, attenuation)
	var want1 := minf(stacked(base, is1), is1 * MAX_BOOST)
	var want2 := minf(stacked(base, is2), is2 * MAX_BOOST)
	if want1 <= 0.0 or want2 <= 0.0:
		return [1.0, attenuation]
	# The windows at the two distances are the lamp's own; only the power changes.
	var window1 := falloff(d1, reach, 0.0)
	var window2 := falloff(d2, reach, 0.0)
	var fitted := -log((want1 / want2) / (window1 / window2)) / log(d1 / d2)
	fitted = clampf(fitted, MIN_ATTENUATION, maxf(attenuation, MIN_ATTENUATION))
	var strength := want1 / (window1 * pow(d1, -fitted))
	return [strength / energy, fitted]


## A light colour made `boost` times brighter (in linear light, as the renderer counts it).
static func brighter(color: Color, boost: float) -> Color:
	var c := color.srgb_to_linear() * boost
	c.a = color.a
	return c.linear_to_srgb()
