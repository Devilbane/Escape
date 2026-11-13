class_name ChapelSpill
extends RefCounted
## The coloured light the temple's stained glass throws onto the ground outside:
## in front of each window a band of pools in the glass's own colours (ruby,
## cobalt, gold, emerald), strongest by the wall. One additive mesh for the
## whole temple, built in the temple's own metres. Its "glow" parameter is
## driven with the glass at night (see Outdoor.set_hour); the temple's windows
## burn all night. Fog is off for it, so the colours stay visible on foggy
## nights instead of being washed out (and an additive quad would otherwise
## add the fog colour over its whole rectangle).

## Where each window is on the wall, in the temple's metres: middle on the
## wall, and the way it faces. The rose window is at the back.
const WINDOWS := [
	[Vector3(11, 0, 12), Vector3(1, 0, 0)], [Vector3(11, 0, 4), Vector3(1, 0, 0)], [Vector3(11, 0, -4), Vector3(1, 0, 0)],
	[Vector3(-11, 0, -12), Vector3(-1, 0, 0)], [Vector3(-11, 0, -4), Vector3(-1, 0, 0)], [Vector3(-11, 0, 4), Vector3(-1, 0, 0)],
	[Vector3(4, 0, -11), Vector3(0, 0, -1)],
]
## The colours of the pools, across a window (from its left to its right).
const COLOURS := [Color(1.0, 0.12, 0.1), Color(0.25, 0.4, 1.0), Color(1.0, 0.78, 0.2), Color(0.15, 0.85, 0.4)]
## How far out the middle of a pool lies, its half width and half depth.
const REACH := 6.0
const HALF := Vector2(3.4, 6.5)
## How far the pools are spread across the window.
const SPREAD := 3.0
const LIFT := 0.1

const SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, fog_disabled, depth_draw_never, cull_disabled, shadows_disabled;
uniform float glow = 0.0;
uniform float scale = 1.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = clamp(1.0 - dot(p, p), 0.0, 1.0);
	// Brightest next to the wall (UV.y = 0), fading away from it.
	float along = 1.0 - UV.y * 0.5;
	ALBEDO = COLOR.rgb * d * sqrt(d) * along * glow / scale * 0.5;
}
"""


static func material(glow_scale: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SHADER
	mat.shader = shader
	mat.set_shader_parameter("scale", glow_scale)
	mat.set_shader_parameter("glow", 0.0)
	return mat


## The mesh of all the pools, in the temple's metres.
static func build_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	for w: Array in WINDOWS:
		var at: Vector3 = w[0]
		var out: Vector3 = w[1]
		var side := Vector3(out.z, 0, -out.x)
		for i in COLOURS.size():
			var across := (float(i) / (COLOURS.size() - 1) - 0.5) * 2.0 * SPREAD
			var mid := at + side * across + out * REACH + Vector3(0, LIFT, 0)
			var a := side * HALF.x
			var b := out * HALF.y
			var quad := [mid - a - b, mid + a - b, mid + a + b, mid - a + b]
			var quv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
			for k: int in [0, 1, 2, 0, 2, 3]:
				verts.append(quad[k])
				uvs.append(quv[k])
				cols.append(COLOURS[i])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = cols
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
