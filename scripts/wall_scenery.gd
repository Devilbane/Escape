class_name WallScenery
extends RefCounted
## What surrounds a climbing wall (see WallStage): a sky, rings of far mountains and forested hills in the haze of the
## weather, a ground of earth, moss and grass that meets the mountains without an edge, and rock masses flanking the
## wall's two sides with a skirt of fallen stones and tufts at its foot, so the wall reads as a face of the mountain
## and not as a slab standing in an empty grey room.

## Per weather: the sky's top and horizon, the three rings of mountains (far to near), the hills' forest, the grass.
const PALETTE := {
	WallWeather.CLEAR: {"top": Color(0.28, 0.5, 0.82), "horizon": Color(0.78, 0.86, 0.94), "far": Color(0.62, 0.7, 0.82), "mid": Color(0.46, 0.55, 0.66), "near": Color(0.3, 0.38, 0.4), "forest": Color(0.13, 0.22, 0.14), "snow": 0.0},
	WallWeather.WIND: {"top": Color(0.34, 0.52, 0.78), "horizon": Color(0.76, 0.84, 0.92), "far": Color(0.6, 0.68, 0.8), "mid": Color(0.45, 0.54, 0.64), "near": Color(0.3, 0.37, 0.39), "forest": Color(0.13, 0.21, 0.14), "snow": 0.0},
	WallWeather.FOG: {"top": Color(0.66, 0.69, 0.72), "horizon": Color(0.76, 0.78, 0.8), "far": Color(0.72, 0.74, 0.77), "mid": Color(0.66, 0.69, 0.72), "near": Color(0.55, 0.58, 0.6), "forest": Color(0.38, 0.42, 0.42), "snow": 0.0},
	WallWeather.RAIN: {"top": Color(0.3, 0.33, 0.38), "horizon": Color(0.5, 0.54, 0.58), "far": Color(0.42, 0.46, 0.52), "mid": Color(0.33, 0.37, 0.42), "near": Color(0.22, 0.26, 0.28), "forest": Color(0.1, 0.16, 0.12), "snow": 0.0},
	WallWeather.STORM: {"top": Color(0.13, 0.14, 0.18), "horizon": Color(0.3, 0.32, 0.37), "far": Color(0.22, 0.24, 0.29), "mid": Color(0.17, 0.19, 0.23), "near": Color(0.11, 0.13, 0.15), "forest": Color(0.06, 0.1, 0.08), "snow": 0.0},
	WallWeather.SNOW: {"top": Color(0.6, 0.65, 0.73), "horizon": Color(0.86, 0.88, 0.92), "far": Color(0.78, 0.82, 0.88), "mid": Color(0.68, 0.73, 0.8), "near": Color(0.55, 0.6, 0.66), "forest": Color(0.28, 0.36, 0.34), "snow": 1.0},
}
## The three rings of mountains: how far from the wall, how high at most, how many peaks round the ring.
const RINGS := [
	{"key": "far", "radius": 330.0, "height": 120.0, "peaks": 7.0, "spikes": 0.0},
	{"key": "mid", "radius": 220.0, "height": 70.0, "peaks": 11.0, "spikes": 0.0},
	{"key": "near", "radius": 140.0, "height": 34.0, "peaks": 17.0, "spikes": 0.12},
]
const SEGMENTS := 420
const GROUND_SHADER := preload("res://shaders/wall_ground.gdshader")


static func palette(weather: String) -> Dictionary:
	return PALETTE.get(weather, PALETTE[WallWeather.CLEAR])


## The scenery of `wall` in `weather`: ridges, ground, flanks, foot stones and tufts, one node.
static func build(wall: WallMap, weather: String) -> Node3D:
	var pal := palette(weather)
	var root := Node3D.new()
	root.name = "Scenery"
	var centre := Vector3(wall.width * 0.5, 0.0, -4.0)
	for ring: Dictionary in RINGS:
		root.add_child(_ridge(centre, ring, pal))
	root.add_child(_ground(wall, pal))
	var rocks := _rocks(wall)
	if rocks != null:
		var mi := MeshInstance3D.new()
		mi.name = "Flanks"
		mi.mesh = rocks
		mi.material_override = AgedStone.rock_material()
		root.add_child(mi)
	var tufts := _tufts(wall, pal)
	if tufts != null:
		root.add_child(tufts)
	return root


## The sky, to put in the stage's environment: a gradient from the top to the horizon of the weather.
static func sky(weather: String) -> Sky:
	var pal := palette(weather)
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = pal.top
	mat.sky_horizon_color = pal.horizon
	mat.ground_horizon_color = pal.horizon
	mat.ground_bottom_color = (pal.far as Color).lerp(pal.horizon, 0.5)
	mat.sky_curve = 0.18
	mat.sun_angle_max = 0.0
	mat.sun_curve = 0.0
	var s := Sky.new()
	s.sky_material = mat
	return s


static func _hash(a: float) -> float:
	return fposmod(sin(a * 127.1 + 311.7) * 43758.5453, 1.0)


## One ring of mountains round `centre`: a band of triangles whose top follows a ragged outline (peaks of several
## sizes, and the jagged tips of fir trees on the nearest ring), and whose foot fades into the haze.
static func _ridge(centre: Vector3, ring: Dictionary, pal: Dictionary) -> MeshInstance3D:
	var noise := FastNoiseLite.new()
	noise.seed = 7 + int(float(ring.radius))
	noise.frequency = 1.0
	noise.fractal_octaves = 4
	var top_col: Color = pal[ring.key]
	var key: String = ring.key
	if key == "near":
		top_col = (pal.forest as Color).lerp(pal.near, 0.35)
	var haze: Color = (pal.horizon as Color)
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for i in SEGMENTS + 1:
		var a := TAU * float(i) / SEGMENTS
		var dir := Vector3(cos(a), 0, sin(a))
		var peaks := float(ring.peaks)
		var n := noise.get_noise_2d(cos(a) * peaks, sin(a) * peaks) * 0.5 + 0.5
		var fine := noise.get_noise_2d(cos(a) * peaks * 4.0 + 50.0, sin(a) * peaks * 4.0) * 0.5 + 0.5
		var h := float(ring.height) * (0.22 + 0.62 * n + 0.2 * fine * fine)
		if float(ring.spikes) > 0.0:
			h += float(ring.height) * float(ring.spikes) * absf(fposmod(a * 140.0, 2.0) - 1.0) * (0.4 + 0.6 * _hash(float(i)))
		var base := centre + dir * float(ring.radius)
		verts.append(Vector3(base.x, -30.0, base.z))
		cols.append(haze)
		verts.append(Vector3(base.x, h * 0.45, base.z))
		cols.append(haze.lerp(top_col, 0.55))
		verts.append(Vector3(base.x, h, base.z))
		cols.append(top_col.lerp(Color(0.95, 0.97, 1.0), float(pal.snow) * clampf((h / float(ring.height) - 0.55) * 3.0, 0.0, 0.8)) if key != "near" else top_col)
	for i in SEGMENTS:
		var o := i * 3
		var p := o + 3
		idx.append_array([o, p, o + 1, o + 1, p, p + 1, o + 1, p + 1, o + 2, o + 2, p + 1, p + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_fog = true
	var mi := MeshInstance3D.new()
	mi.name = "Ridge_" + key
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _ground(wall: WallMap, pal: Dictionary) -> MeshInstance3D:
	var r := 420.0
	var w := float(wall.width)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(w * 0.5 - r, 0, -r), Vector3(w * 0.5 + r, 0, -r), Vector3(w * 0.5 + r, 0, r), Vector3(w * 0.5 - r, 0, r)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 0, 3, 2])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	mat.shader = GROUND_SHADER
	mat.set_shader_parameter("haze", pal.horizon)
	mat.set_shader_parameter("snow", pal.snow)
	mat.set_shader_parameter("wet", 1.0 if pal.top.v < 0.45 else 0.0)
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = mesh
	mi.material_override = mat
	return mi


## Rock masses at both sides of the wall (stacked, overlapping boulders that rise to about half its height and cover
## its cut edges), and a skirt of fallen stones along its foot, merged into one mesh and weathered like the face.
static func _rocks(wall: WallMap) -> ArrayMesh:
	var st := SurfaceTool.new()
	var count := 0
	var w := float(wall.width)
	var h := float(wall.height)
	var kinds := ["rock_single_A", "rock_single_C", "rock_single_E"]
	for side in [-1, 1]:
		var edge := 0.0 if side < 0 else w
		# A pile of boulders leaning on the wall's edge: broad at the bottom, three layers high, each resting on the
		# one below (so nothing floats), and a few small ones round its foot.
		for layer in 3:
			for j in 3:
				var hh := _hash(float(layer * 17 + j * 5 + (3 if side < 0 else 11)))
				var h2 := _hash(float(layer * 7 + j * 13 + (5 if side < 0 else 2)))
				var mesh: ArrayMesh = NaturalRock.mesh(kinds[(layer + j + side + 1) % 3])
				if mesh == null:
					continue
				var size := lerpf(15.0, 9.0, layer / 2.0) * lerpf(0.85, 1.2, hh)
				var at := Vector3(edge + side * (2.2 - layer * 0.5 + j * 1.3 + h2 * 0.8), layer * 1.5, -1.6 + j * 1.0 + hh * 0.5)
				var basis := Basis(Vector3.UP, hh * TAU).scaled(Vector3(size, size * lerpf(0.8, 1.05, h2), size * lerpf(0.9, 1.15, hh)))
				st.append_from(mesh, 0, Transform3D(basis, at - Vector3(0, size * 0.03, 0)))
				count += 1
	# Fallen stones along the foot, thicker at the corners and in front of the wall.
	for i in 70:
		var hh := _hash(float(i * 3 + 1))
		var h2 := _hash(float(i * 5 + 4))
		var mesh: ArrayMesh = NaturalRock.mesh(kinds[i % 3])
		if mesh == null:
			continue
		var x := lerpf(-3.0, w + 3.0, _hash(float(i) * 1.7))
		var z := lerpf(0.2, 3.2, h2 * h2)
		var size := lerpf(1.5, 5.0, hh * hh)
		st.append_from(mesh, 0, Transform3D(Basis(Vector3.UP, hh * TAU).scaled(Vector3(size, size * lerpf(0.5, 0.9, h2), size)), Vector3(x, -0.02, z)))
		count += 1
	if count == 0:
		return null
	return WallBuild.new(wall)._weathered(st.commit(), false)


## Grass tufts and moss among the stones at the foot and out over the ground, in the colours of the weather.
static func _tufts(wall: WallMap, pal: Dictionary) -> MultiMeshInstance3D:
	if float(pal.snow) > 0.5:
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = MountainFoot._tuft_mesh()
	var w := float(wall.width)
	var n := 320
	mm.instance_count = n
	for i in n:
		var hh := _hash(float(i) * 2.3 + 1.0)
		var h2 := _hash(float(i) * 4.1 + 7.0)
		var x := lerpf(-12.0, w + 12.0, hh)
		var z := lerpf(0.3, 14.0, h2 * h2)
		var s := lerpf(0.45, 1.1, _hash(float(i) * 9.7))
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, hh * TAU).scaled(Vector3(s, s, s)), Vector3(x, 0.0, z)))
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 1.0
	var mi := MultiMeshInstance3D.new()
	mi.name = "Tufts"
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
