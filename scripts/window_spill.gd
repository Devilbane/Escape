class_name WindowSpill
extends RefCounted
## Light that lit windows throw onto the ground in front of them: one soft,
## additive pool per pane, all of a house in a single mesh and all houses
## sharing one material. The material's "glow" parameter is driven by the
## village at night, just like the glass itself, so the pools are off by day
## and while the panes are dark.

## How far in front of the wall the middle of a pool lies, in metres.
const REACH := 1.5
## Half the width and depth of a pool of a ground-floor window.
const HALF := Vector2(1.7, 1.5)
## Pools of upper-floor windows are weaker and spread wider.
const UPPER_FADE := 0.55
const LIFT := 0.04
const GROUND_FLOOR := 2.4

const SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec3 colour : source_color = vec3(1.0, 0.7, 0.36);
uniform float glow = 0.0;
uniform float scale = 1.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = clamp(1.0 - dot(p, p), 0.0, 1.0);
	// Brightest next to the wall (UV.y = 0), fading away from it.
	float along = 1.0 - UV.y * 0.6;
	ALBEDO = colour * d * d * along * COLOR.a * glow / scale * 0.16;
}
"""


## The shared material; `glow_scale` is the glass's full glow, so a pool
## reaches full strength when the windows do.
static func material(colour: Color, glow_scale: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SHADER
	mat.shader = shader
	mat.set_shader_parameter("colour", Vector3(colour.r, colour.g, colour.b))
	mat.set_shader_parameter("scale", glow_scale)
	mat.set_shader_parameter("glow", 0.0)
	return mat


## Puts a pool in front of each window of a house built by VillageHouse.
static func attach(house: Node3D, mat: Material) -> void:
	var panes: Array = house.get_meta("windows", [])
	var outs: Array = house.get_meta("window_outs", [])
	if panes.is_empty() or outs.size() != panes.size():
		return
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	for i in panes.size():
		var at: Vector3 = panes[i]
		var out: Vector3 = outs[i]
		var upper := at.y > GROUND_FLOOR
		var strength := UPPER_FADE if upper else 1.0
		var widen := 1.3 if upper else 1.0
		var side := Vector3(out.z, 0, -out.x)
		var mid := Vector3(at.x, 0, at.z) + out * (REACH * widen) + Vector3(0, LIFT, 0)
		var a := side * HALF.x * widen
		var b := out * HALF.y * widen
		# Corners: wall side first (UV.y = 0), then the far side.
		var quad := [mid - a - b, mid + a - b, mid + a + b, mid - a + b]
		var quv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for k: int in [0, 1, 2, 0, 2, 3]:
			verts.append(quad[k])
			uvs.append(quv[k])
			cols.append(Color(1, 1, 1, strength))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = cols
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "WindowSpill"
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	house.add_child(mi)
