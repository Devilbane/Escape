class_name ChapelSpill
extends RefCounted
## The coloured light the temple's stained glass throws onto the lawn outside:
## for every window a shiny, see-through picture of its own glass (the same shape
## and colours, taken from the glass texture), lying on the ground in front of the
## window. It starts away from the wall by half as much as the window's sill is high,
## ends 72.5% longer than the window is tall (the window's top is the far end) and
## keeps its colours all along (it only softens at its two ends). A faint, blurred haze of rays of the same glass shines from the
## window down to the picture, like light falling through dusty air. One additive mesh for the whole temple, built in
## the temple's own metres. Its "glow" parameter is driven with the glass at night
## (see Outdoor.set_hour); the temple's windows burn all night. Fog is off for it,
## so the colours stay visible on foggy nights instead of being washed out (and an
## additive quad would otherwise add the fog colour over its whole rectangle).

const GLASS_TEXTURE := "res://assets/chapel/stained_glass_glow.png"

## The two kinds of window, as the kit's pieces have them (kit metres): how wide
## and tall the glass is, how high its bottom edge is above the ground, and where
## the glass is on the texture (the outside row), as a rectangle in 0..1.
const LANCETS := {"width": 4.35, "height": 8.65, "sill": 4.58, "uv": Rect2(0.0184, 0.0089, 0.2453, 0.4906)}
const ROSE := {"width": 6.45, "height": 6.62, "sill": 4.69, "uv": Rect2(0.5517, 0.0474, 0.3966, 0.3966)}
## Where each window is: the middle of the glass on the outside face of the wall,
## the way it faces, and its kind. The six side windows sit at the same places on
## both walls; the rose window is at the back.
const WINDOWS := [
	[Vector3(12.44, 0, 8), Vector3(1, 0, 0), LANCETS], [Vector3(12.44, 0, 0), Vector3(1, 0, 0), LANCETS],
	[Vector3(12.44, 0, -8), Vector3(1, 0, 0), LANCETS],
	[Vector3(-12.44, 0, 8), Vector3(-1, 0, 0), LANCETS], [Vector3(-12.44, 0, 0), Vector3(-1, 0, 0), LANCETS],
	[Vector3(-12.44, 0, -8), Vector3(-1, 0, 0), LANCETS],
	[Vector3(0, 0, -12.37), Vector3(0, 0, -1), ROSE],
]
## How much longer the picture is than the window, how far from the wall it starts
## (a fraction of the sill's height) and how bright it is at its far end (1 = the same all along).
const STRETCH := 1.725
const GAP := 0.5
const FAR_BRIGHTNESS := 1.0
## How many times wider the picture is at its far end than at the wall's side: the light spreads
## out the farther it travels, like real light through a window.
const SPREAD := 1.3
## The rays: ribbons across the beam at these heights of the window (0 = bottom,
## 1 = top) and sheets along it at these places across the window (0 = left, 1 = right).
const RIBBONS := [0.1, 0.3, 0.5, 0.7, 0.9]
const SHEETS := [0.12, 0.37, 0.63, 0.88]
## How bright the rays are against the picture: a faint haze, not crisp beams.
const RAY_STRENGTH := 0.5
## How bright the picture on the lawn is (the rays have their own strength).
const PICTURE_DIM := 0.55
## How high above the ground the picture lies, in kit metres (the temple is scaled down, so
## this is a little less in the world). Winter snow lies up to about 0.06 m thick (see
## SnowCover), so the light floats clear above it and is not buried.
const LIFT := 0.3
## How bright the light is next to the glass itself.
const DIM := 1.3

const SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, fog_disabled, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D glass : source_color, filter_linear_mipmap, repeat_disable;
uniform float glow = 0.0;
uniform float scale = 1.0;
uniform float dim = 1.0;
uniform float far_brightness = 0.04;
uniform float ray_strength = 0.5;
uniform float pic_dim = 1.0;
varying vec2 pic;
varying float is_ray;
void vertex() {
	// COLOR.rg: where on the glass texture this corner lies; COLOR.b: 1 on a ray.
	pic = COLOR.rg;
	is_ray = COLOR.b;
}
void fragment() {
	if (is_ray > 0.5) {
		// A soft haze of the glass's colours, heavily blurred so the colours run into
		// each other, strongest at the window. Its sides and both ends fade out over a
		// wide band, so the rays melt into one another instead of showing edges.
		vec3 rc = min(textureLod(glass, pic, 5.0).rgb * 1.6, vec3(0.6));
		float edge = smoothstep(0.0, 0.35, UV.x) * smoothstep(1.0, 0.65, UV.x);
		float along = (1.0 - UV.y * 0.6) * smoothstep(0.0, 0.2, UV.y) * smoothstep(1.0, 0.65, UV.y);
		ALBEDO = rc * edge * along * ray_strength * (is_ray - 0.4) * 1.67 * glow / scale * dim;
	} else {
		vec3 c = texture(glass, pic).rgb;
		// Fades along the picture from the wall's side (UV.y = 0) to the far end.
		float fade = mix(1.0, far_brightness, smoothstep(0.0, 1.0, UV.y * 0.9 + UV.y * UV.y * 0.1));
		// A little shine: the brightest colours turn towards white.
		float lum = max(c.r, max(c.g, c.b));
		c += vec3(lum * lum * 0.15);
		// Softer colours: a part of each colour is traded for its grey.
		c = mix(vec3(dot(c, vec3(0.33))), c, 0.8);
		// Soft ends, so the picture does not stop with a hard edge.
		float ends = smoothstep(0.0, 0.03, UV.y) * smoothstep(1.0, 0.97, UV.y);
		ALBEDO = c * fade * ends * glow / scale * dim * pic_dim;
	}
}
"""


static func material(glow_scale: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SHADER
	mat.shader = shader
	mat.set_shader_parameter("glass", load(GLASS_TEXTURE))
	mat.set_shader_parameter("scale", glow_scale)
	mat.set_shader_parameter("dim", DIM)
	mat.set_shader_parameter("far_brightness", FAR_BRIGHTNESS)
	mat.set_shader_parameter("ray_strength", RAY_STRENGTH)
	mat.set_shader_parameter("pic_dim", PICTURE_DIM)
	mat.set_shader_parameter("glow", 0.0)
	return mat


## The corners of one window's picture on the lawn, in the temple's metres, on the ground
## (the window's bottom edge is the near end, its top edge the far end).
static func picture(w: Array) -> Array:
	var at: Vector3 = w[0]
	var out: Vector3 = w[1]
	var kind: Dictionary = w[2]
	var side := Vector3(out.z, 0, -out.x)
	var near: float = float(kind["sill"]) * GAP
	var far: float = near + float(kind["height"]) * STRETCH
	var half: float = float(kind["width"]) * 0.5
	return [at + out * near - side * half, at + out * near + side * half,
		at + out * far + side * half * SPREAD, at + out * far - side * half * SPREAD]


## Every window's picture as an outline on the ground plane (x, z), placed by `to_world`
## (the temple's transform): ground patches keep off it, so nothing hides the light.
static func ground_outlines(to_world: Transform3D) -> Array[PackedVector2Array]:
	var outlines: Array[PackedVector2Array] = []
	for w: Array in WINDOWS:
		var outline := PackedVector2Array()
		for p: Vector3 in picture(w):
			var g: Vector3 = to_world * p
			outline.append(Vector2(g.x, g.z))
		outlines.append(outline)
	return outlines


## The mesh of all the pictures, in the temple's metres.
static func build_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	for w: Array in WINDOWS:
		var at: Vector3 = w[0]
		var out: Vector3 = w[1]
		var kind: Dictionary = w[2]
		# The picture is seen from outside, looking at the wall: its right is "side".
		var side := Vector3(out.z, 0, -out.x)
		var sill: float = kind["sill"]
		var near: float = sill * GAP
		var far: float = near + float(kind["height"]) * STRETCH
		var half: float = float(kind["width"]) * 0.5
		var rect: Rect2 = kind["uv"]
		var base := at + Vector3(0, LIFT, 0)
		var quad := picture(w).map(func(p: Vector3) -> Vector3: return p + Vector3(0, LIFT, 0))
		var quv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		var tex := [Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.end.y),
			Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.position.y)]
		for k: int in [0, 1, 2, 0, 2, 3]:
			verts.append(quad[k])
			uvs.append(quv[k])
			cols.append(Color((tex[k] as Vector2).x, (tex[k] as Vector2).y, 0.0))
		# The rays run from the glass (its bottom edge lands at the picture's near end,
		# its top edge at the far end) down to the lawn.
		var top: float = sill + float(kind["height"])
		var up := Vector3.UP
		for r: float in RIBBONS:
			var y := lerpf(sill, top, r)
			var d := lerpf(near, far, r)
			var tv := lerpf(rect.end.y, rect.position.y, r)
			var wide := lerpf(1.0, SPREAD, r)
			var corners := [base + up * y - side * half, base + up * y + side * half,
				base + out * d + side * half * wide, base + out * d - side * half * wide]
			var cuv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
			var ctex := [Vector2(rect.position.x, tv), Vector2(rect.end.x, tv),
				Vector2(rect.end.x, tv), Vector2(rect.position.x, tv)]
			_add_quad(verts, uvs, cols, corners, cuv, ctex, 1.0)
		for f: float in SHEETS:
			var across := side * (f - 0.5) * 2.0 * half
			var tu := lerpf(rect.position.x, rect.end.x, f)
			var corners := [base + across + up * sill, base + across + up * top,
				base + across * SPREAD + out * far, base + across + out * near]
			var cuv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
			var ctex := [Vector2(tu, rect.end.y), Vector2(tu, rect.position.y),
				Vector2(tu, rect.position.y), Vector2(tu, rect.end.y)]
			_add_quad(verts, uvs, cols, corners, cuv, ctex, 0.7)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = cols
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Adds one ray quad (blue above 0.5 in the colour marks it as a ray for the shader, and says how strong).
static func _add_quad(verts: PackedVector3Array, uvs: PackedVector2Array, cols: PackedColorArray,
		corners: Array, cuv: Array, ctex: Array, strength: float) -> void:
	for k: int in [0, 1, 2, 0, 2, 3]:
		verts.append(corners[k])
		uvs.append(cuv[k])
		cols.append(Color((ctex[k] as Vector2).x, (ctex[k] as Vector2).y, strength))
