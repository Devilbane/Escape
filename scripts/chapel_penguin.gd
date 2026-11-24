class_name ChapelPenguin
extends RefCounted
## An easter egg on the temple's tower: a Linux penguin (Tux) sits on the peak of
## the spire, with a banner fluttering from a pole behind it: "Save penguins and
## Antarctica". The banner is a strip of cloth with the text painted on it, and
## it flutters in the wind like the village's flags (see FlagWind).
##
## The penguin is "Tux" by durmieu (OpenGameArt, CC-BY 3.0, see assets/penguin/CREDITS.txt).
## Everything is in the chapel's own units (the kit's metres, see Outdoor.CHAPEL_PARTS).

const TUX := preload("res://assets/penguin/tux.glb")
const TUX_TEXTURE := preload("res://assets/penguin/tux_texture.png")
const BANNER_SHADER := preload("res://shaders/banner.gdshader")
const FONT := preload("res://assets/fonts/Cinzel-Bold.woff2")

## Where the spire's tip is, in chapel units (the spire stands 30 high on the
## rooftop's ridge, at the front of the nave).
const PEAK := Vector3(0, 46, 8)
## The penguin's height in chapel units, and how far in front of the pole it sits.
const PENGUIN_HEIGHT := 4.2
const PENGUIN_FRONT := 1.1
## The pole: how high above the tip it reaches and how thick it is.
const POLE_HEIGHT := 12.0
const POLE_RADIUS := 0.16
## The banner: size in chapel units, and how far below the pole's top it hangs.
const BANNER_SIZE := Vector2(15.0, 5.4)
const BANNER_DROP := 0.5
## The painted text, in pixels.
const TEXT_SIZE := Vector2i(1000, 360)
const COLOUR_CLOTH := Color(0.12, 0.3, 0.55)
const COLOUR_TEXT := Color(1.0, 0.97, 0.88)
const COLOUR_TRIM := Color(0.95, 0.78, 0.25)
const BANNER_NODE := "chapel_banner"


## The penguin, the pole and the banner, ready to be added to the chapel. `level`
## is the level they stand in (it tells the wind).
static func build(level: Node) -> Node3D:
	var root := Node3D.new()
	root.name = "ChapelPenguin"
	root.position = PEAK
	root.add_child(_pole())
	root.add_child(_penguin())
	var banner := _banner()
	root.add_child(banner)
	FlagWind.attach(banner, BANNER_NODE, level)
	return root


static func _pole() -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = POLE_RADIUS
	mesh.bottom_radius = POLE_RADIUS
	mesh.height = POLE_HEIGHT
	var pole := MeshInstance3D.new()
	pole.name = "Pole"
	pole.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.22, 0.14)
	mat.roughness = 0.8
	pole.set_surface_override_material(0, mat)
	pole.position = Vector3(0, POLE_HEIGHT * 0.5 - 1.0, -PENGUIN_FRONT)
	return pole


## Tux, sitting on the tip and looking out over the village.
static func _penguin() -> Node3D:
	var tux: Node3D = TUX.instantiate()
	tux.name = "Tux"
	tux.set_meta("no_snow", true)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = TUX_TEXTURE
	mat.roughness = 0.85
	for mi: MeshInstance3D in tux.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			mi.set_surface_override_material(i, mat)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The model's middle is at its origin: lift it so that its feet rest on the tip.
	var scale := PENGUIN_HEIGHT / 0.854
	tux.scale = Vector3.ONE * scale
	tux.position = Vector3(0, 0.494 * scale - 0.3, 0)
	return tux


## The cloth, hanging from the pole's top and flying out sideways.
static func _banner() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# One unit wide, so the wave's reach is (1, 0, 0) (see FlagWind.SHAPES).
	var h := BANNER_SIZE.y / BANNER_SIZE.x
	for q in [[0, 0], [1, 0], [1, 1], [0, 0], [1, 1], [0, 1]]:
		st.set_uv(Vector2(q[0], q[1]))
		st.set_normal(Vector3(0, 0, 1))
		st.add_vertex(Vector3(q[0], -q[1] * h, 0))
	var mi := MeshInstance3D.new()
	mi.name = BANNER_NODE
	mi.mesh = st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = BANNER_SHADER
	mat.set_shader_parameter("banner_tex", _banner_texture())
	mi.set_surface_override_material(0, mat)
	mi.scale = Vector3.ONE * BANNER_SIZE.x
	mi.position = Vector3(POLE_RADIUS, POLE_HEIGHT - 1.0 - BANNER_DROP, -PENGUIN_FRONT)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## The cloth with its text, painted once by a small viewport.
static func _banner_texture() -> Texture2D:
	var port := SubViewport.new()
	port.size = TEXT_SIZE
	port.transparent_bg = false
	port.render_target_update_mode = SubViewport.UPDATE_ONCE
	var cloth := ColorRect.new()
	cloth.color = COLOUR_CLOTH
	cloth.size = Vector2(TEXT_SIZE)
	port.add_child(cloth)
	for y in [8.0, TEXT_SIZE.y - 24.0]:
		var trim := ColorRect.new()
		trim.color = COLOUR_TRIM
		trim.position = Vector2(0, y)
		trim.size = Vector2(TEXT_SIZE.x, 16)
		port.add_child(trim)
	var label := Label.new()
	label.text = "Rettet die Pinguine und die Antarktis"
	label.size = Vector2(TEXT_SIZE.x - 20, TEXT_SIZE.y)
	label.position = Vector2(10, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 104)
	label.add_theme_color_override("font_color", COLOUR_TEXT)
	port.add_child(label)
	# The viewport must live in the tree to paint; it stays with the banner.
	var tex := port.get_texture()
	_Holder.keep(port)
	return tex


## Keeps the painting viewport alive under the scene tree's root.
class _Holder:
	static func keep(port: SubViewport) -> void:
		(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(port)
