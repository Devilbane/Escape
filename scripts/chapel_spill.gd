class_name ChapelSpill
extends RefCounted
## The coloured light the temple's stained glass throws onto the ground outside:
## in front of each window a soft picture of its glass (a blue ground in lead
## lines, red and green medallions on it, a border of gold and red beads), strongest
## by the wall and dimmer than the glass itself. One additive mesh for the
## whole temple, built in the temple's own metres. Its "glow" parameter is
## driven with the glass at night (see Outdoor.set_hour); the temple's windows
## burn all night. Fog is off for it, so the colours stay visible on foggy
## nights instead of being washed out (and an additive quad would otherwise
## add the fog colour over its whole rectangle).

## Where each window is on the wall, in the temple's metres: middle on the
## wall, and the way it faces. The rose window is at the back. The pools of
## the right wall sit one pane (8 m) further north than the origins of its window
## pieces, so that they run parallel to the pools of the left wall.
const WINDOWS := [
	[Vector3(11, 0, 4), Vector3(1, 0, 0)], [Vector3(11, 0, -4), Vector3(1, 0, 0)], [Vector3(11, 0, -12), Vector3(1, 0, 0)],
	[Vector3(-11, 0, -12), Vector3(-1, 0, 0)], [Vector3(-11, 0, -4), Vector3(-1, 0, 0)], [Vector3(-11, 0, 4), Vector3(-1, 0, 0)],
	[Vector3(4, 0, -11), Vector3(0, 0, -1)],
]
## How far out the middle of a window's light lies, and its half width and half depth.
const REACH := 6.0
const HALF := Vector2(5.2, 6.5)
const LIFT := 0.1
## How bright the light is next to the glass itself (1.0 = as bright as the pools were before).
const DIM := 1.0

const SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, fog_disabled, depth_draw_never, cull_disabled, shadows_disabled;
uniform float glow = 0.0;
uniform float scale = 1.0;
uniform float dim = 0.5;
const vec3 ruby = vec3(0.85, 0.08, 0.1);
const vec3 cobalt = vec3(0.12, 0.24, 0.9);
const vec3 gold = vec3(1.0, 0.72, 0.16);
const vec3 emerald = vec3(0.1, 0.7, 0.32);
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = clamp(1.0 - dot(p, p), 0.0, 1.0);
	// Brightest next to the wall (UV.y = 0), fading away from it.
	float along = 1.0 - UV.y * 0.55;
	// Two tall panels side by side, each a column of the window's glass.
	float col = fract(UV.x * 2.0);
	float cx = abs(col - 0.5) * 2.0;
	// Lead lines at the edges and between the panels, and a saddle bar across.
	float lead = smoothstep(0.82, 0.95, cx) + (1.0 - smoothstep(0.0, 0.012, min(fract(UV.y * 4.0), 1.0 - fract(UV.y * 4.0))));
	// Blue ground cut into small pieces of glass: most blue, some ruby, gold and green,
	// each piece a little different in brightness, like a mosaic.
	vec2 cell = vec2(col * 5.0, UV.y * 16.0);
	cell.x += cell.y * 0.5;
	vec2 id = floor(cell);
	float h = fract(sin(dot(id + floor(UV.x * 2.0) * 7.0, vec2(12.9898, 78.233))) * 43758.5453);
	vec3 c = cobalt;
	c = h > 0.35 ? mix(cobalt, vec3(0.2, 0.55, 1.0), 0.6) : c;
	c = h > 0.55 ? gold : c;
	c = h > 0.75 ? ruby : c;
	c = h > 0.90 ? emerald : c;
	c *= 0.8 + 0.4 * fract(h * 37.0);
	vec2 f = abs(fract(cell) - 0.5);
	float piece_lead = smoothstep(0.42, 0.49, max(f.x, f.y));
	lead = max(lead, piece_lead * 0.85);
	// A border of gold and red beads along the edges of the panel.
	float bead = step(0.74, cx) * step(0.5, fract(UV.y * 22.0));
	c = mix(c, mix(gold, ruby, step(0.5, fract(UV.y * 11.0))), bead * step(cx, 0.82));
	// Medallions on the blue, quartered in ruby and green round a gold boss.
	vec2 m = vec2((col - 0.5) * 2.0 * 0.5, fract(UV.y * 3.0 + 0.15) - 0.5) * vec2(1.0, 1.0);
	m.y *= 2.2;
	float r = length(m);
	vec3 med = (m.x * m.y > 0.0) ? ruby : emerald;
	c = mix(c, med, (1.0 - smoothstep(0.26, 0.30, r)));
	c = mix(c, gold, (1.0 - smoothstep(0.06, 0.09, r)));
	c *= 1.0 - clamp(lead, 0.0, 1.0);
	ALBEDO = c * d * along * glow / scale * dim;
}
"""


static func material(glow_scale: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SHADER
	mat.shader = shader
	mat.set_shader_parameter("scale", glow_scale)
	mat.set_shader_parameter("dim", DIM)
	mat.set_shader_parameter("glow", 0.0)
	return mat


## The mesh of all the pools, in the temple's metres.
static func build_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	for w: Array in WINDOWS:
		var at: Vector3 = w[0]
		var out: Vector3 = w[1]
		var side := Vector3(out.z, 0, -out.x)
		var mid := at + out * REACH + Vector3(0, LIFT, 0)
		var a := side * HALF.x
		var b := out * HALF.y
		var quad := [mid - a - b, mid + a - b, mid + a + b, mid - a + b]
		var quv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for k: int in [0, 1, 2, 0, 2, 3]:
			verts.append(quad[k])
			uvs.append(quv[k])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
