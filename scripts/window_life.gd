class_name WindowLife
extends RefCounted
## Life behind the glass of Weavers' Lane. One thin pane-sized quad lies over
## each window's glass and, while that window is lit (see WindowLights), now
## and then shows what is going on inside: a curtain that is drawn shut and
## drawn open again, or, more rarely, the dark shape of a person walking past
## the lamp. Every window runs its own slow cycle (worked out in the shader from
## where the pane stands and the clock of the engine), so no two windows do
## the same thing at the same time and nothing is stored. A short stretch of
## each cycle may hold an event, and most cycles hold none: it stays subtle.

## The share of a window's cycles in which its curtain is drawn / a figure
## passes. A figure never shows in a cycle with a drawn curtain.
const CURTAIN_CHANCE := 0.22
const FIGURE_CHANCE := 0.10
## How long one window's cycle lasts in seconds: at least MIN_CYCLE, plus up
## to SPREAD more, per window.
const MIN_CYCLE := 70.0
const SPREAD := 50.0
## The glass of a pane, in metres: what the quad covers.
const PANE := Vector2(0.8, 0.9)
## How far in front of the wall's glass the quad lies, in metres.
const LIFT := 0.063

const HEAD := """
shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec3 colour : source_color = vec3(1.0, 0.7, 0.36);
uniform float glow = 0.0;
uniform float curtain_chance = %f;
uniform float figure_chance = %f;
uniform float min_cycle = %f;
uniform float spread = %f;
varying vec2 key;
""" % [CURTAIN_CHANCE, FIGURE_CHANCE, MIN_CYCLE, SPREAD]

const SHADER := HEAD + WindowLights.LIT_FUNCTION + """
float rnd(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}
void vertex() {
	key = UV2 + MODEL_MATRIX[3].xz;
}
void fragment() {
	float lit = window_lit(key);
	if (lit < 0.01) {
		discard;
	}
	vec2 k = floor(key * 4.0 + 0.5);
	// The pane: x from -0.5 to 0.5 across, y from -0.5 (sill) to 0.5.
	vec2 p = vec2(UV.x - 0.5, 0.5 - UV.y);
	// This window's cycle: which one it is in (n) and how far through (f).
	float t = TIME / (min_cycle + spread * rnd(k + vec2(3.1, 7.7))) + rnd(k + vec2(8.7, 1.9)) * 40.0;
	float n = floor(t);
	float f = fract(t);
	vec2 cycle = k + vec2(n * 1.7, n * 0.9);

	// The curtain: always a little cloth at both sides, drawn together to
	// the middle and back again in the cycles that hold a curtain event.
	float event = step(rnd(cycle + vec2(1.3, 4.1)), curtain_chance);
	float shut = event * smoothstep(0.12, 0.2, f) * (1.0 - smoothstep(0.6, 0.68, f));
	float reach = mix(0.1, 0.52, shut);
	float cover = smoothstep(0.5 - reach - 0.02, 0.5 - reach + 0.02, abs(p.x));
	float folds = 0.5 + 0.5 * sin(p.x * 38.0 + p.y * 3.0);
	vec3 cloth = mix(vec3(0.75, 0.28, 0.2), vec3(0.34, 0.5, 0.36), step(0.5, rnd(k + vec2(5.5, 2.5))));
	vec3 cloth_col = mix(colour, cloth, 0.55) * glow * lit * (0.3 + 0.25 * folds);

	// The figure: crosses the pane once, slowest in the middle, in the
	// cycles that hold no curtain event.
	float who = step(rnd(cycle + vec2(6.2, 2.2)), figure_chance) * (1.0 - event);
	float u = clamp((f - 0.3) / 0.3, 0.0, 1.0);
	float dir = rnd(cycle + vec2(9.1, 3.3)) > 0.5 ? 1.0 : -1.0;
	float x = dir * 0.7 * (2.0 * (u + 0.15 * sin(6.2832 * u)) - 1.0);
	float bob = 0.012 * sin(u * 40.0);
	float head = 1.0 - smoothstep(0.073, 0.097, length(p - vec2(x, 0.1 + bob)));
	float body = 1.0 - smoothstep(0.85, 1.0, length((p - vec2(x, -0.22 + bob)) / vec2(0.2, 0.32)));
	float a_fig = max(head, body) * 0.85 * who * (1.0 - cover);

	float a_cloth = cover;
	float w = a_cloth / (a_cloth + a_fig * (1.0 - a_cloth) + 0.0001);
	ALBEDO = mix(vec3(0.03, 0.02, 0.015), cloth_col, w);
	ALPHA = (1.0 - (1.0 - a_cloth) * (1.0 - a_fig)) * clamp(lit, 0.0, 1.0);
}
"""


## The shared material; "glow" and "hour" are driven by the village, like the glass's.
static func material(light: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SHADER
	mat.shader = shader
	mat.set_shader_parameter("colour", Vector3(light.r, light.g, light.b))
	mat.set_shader_parameter("glow", 0.0)
	mat.set_shader_parameter("hour", 12.0)
	return mat


## Lays a quad over each window of a house built by VillageHouse.
static func attach(house: Node3D, mat: Material) -> void:
	var panes: Array = house.get_meta("windows", [])
	var outs: Array = house.get_meta("window_outs", [])
	if panes.is_empty() or outs.size() != panes.size():
		return
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var keys := PackedVector2Array()
	for i in panes.size():
		var at: Vector3 = panes[i]
		var out: Vector3 = outs[i]
		var side := Vector3(out.z, 0, -out.x)
		var mid := at + out * LIFT
		var a := side * PANE.x * 0.5
		var b := Vector3.UP * PANE.y * 0.5
		var quad := [mid - a - b, mid + a - b, mid + a + b, mid - a + b]
		var quv := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for k: int in [0, 1, 2, 0, 2, 3]:
			verts.append(quad[k])
			uvs.append(quv[k])
			keys.append(WindowLights.key(at))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = keys
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "WindowLife"
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	house.add_child(mi)
