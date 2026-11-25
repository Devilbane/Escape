class_name Graphics
extends RefCounted
## How finely the picture is drawn: three presets the player picks in the pull-out menu
## (see Game._make_graphics_row), remembered in the settings file.
##
## - Quality (the default): everything at its finest, for a strong graphics card. The world drawn
##   at one and a half times the window's size and shrunk (the smoothest edges), the softest
##   shadow edges, the largest shadow maps, the sharpest textures at a slant.
## - Balanced: the picture as it was before the presets: drawn at the window's size, edges smoothed
##   in one pass, soft shadows.
## - Performance: for weak graphics cards. The world is drawn at 77 % of the window's size and
##   sharpened up again, edges are smoothed in one cheap pass, shadows are smaller and harder, and
##   fewer lamps cast wall shadows at once.
##
## A preset never changes the light itself: how bright, what colour and how far every lamp, the
## moon and the sky shine is the same in all three (tests/lighting_reference_shots.gd takes the
## pictures that show it). Only how finely it is drawn differs.
##
## The game is drawn by one of two renderers (see modern): Godot's Forward+ renderer on
## DirectX 12, Vulkan or Metal, and the older OpenGL renderer in the browser and on graphics
## cards that have nothing newer. Each preset works on both; what a renderer cannot do
## (drawing larger or smaller than the window, SMAA and debanding on OpenGL) is left out there.

const QUALITY := "quality"
const BALANCED := "balanced"
const PERFORMANCE := "performance"
const PRESETS := [QUALITY, BALANCED, PERFORMANCE]
const DEFAULT := QUALITY
## The presets' names and what each is for (German, translated by Lang).
const NAMES := {QUALITY: "Qualität", BALANCED: "Ausgewogen", PERFORMANCE: "Leistung"}
const HINTS := {
	QUALITY: "Qualität: das schönste Bild. Glatte Kanten, weiche Schatten, scharfe Texturen.",
	BALANCED: "Ausgewogen: gutes Bild bei weniger Last für die Grafikkarte.",
	PERFORMANCE: "Leistung: flüssig auch auf schwachen Grafikkarten. Etwas gröberes Bild, härtere Schatten.",
}
## What each preset sets:
## msaa: how often every edge is sampled on OpenGL (Viewport.MSAA_*).
## smooth: the edge smoothing pass instead (Viewport.SCREEN_SPACE_AA_*). The modern renderer
##   always uses it and never MSAA: with MSAA its depth buffer cannot be read back, and the fog of
##   war, the fog banks and the weather all read it (see shaders/depth.gdshaderinc).
## scale: on the modern renderer, the share of the window's size the world is drawn at. Above 1
##   it is drawn larger and shrunk (supersampling: the finest edges and textures there are), below 1
##   smaller and sharpened up again (FSR 1). OpenGL always draws at the window's size.
## sun_map, lamp_map: the size of the shadow maps of the sun and moon, and of the lamps.
## soft: how finely shadow edges are softened (RenderingServer.SHADOW_QUALITY_*).
## lamps: how many lamps cast wall shadows at once (see LightShadows.budget).
## sharp: how sharp textures stay at a slant (Viewport.ANISOTROPY_*).
## fine_glow: the glow round lights drawn smooth rather than in blocks. deband: no stripes in dark skies.
const LOOKS := {
	QUALITY: {"msaa": Viewport.MSAA_4X, "smooth": Viewport.SCREEN_SPACE_AA_SMAA, "scale": 1.5, "sun_map": 8192, "lamp_map": 4096,
		"soft": RenderingServer.SHADOW_QUALITY_SOFT_HIGH, "lamps": 6, "sharp": Viewport.ANISOTROPY_16X, "fine_glow": true, "deband": true},
	BALANCED: {"msaa": Viewport.MSAA_2X, "smooth": Viewport.SCREEN_SPACE_AA_SMAA, "scale": 1.0, "sun_map": 4096, "lamp_map": 4096,
		"soft": RenderingServer.SHADOW_QUALITY_SOFT_LOW, "lamps": 6, "sharp": Viewport.ANISOTROPY_4X, "fine_glow": true, "deband": true},
	PERFORMANCE: {"msaa": Viewport.MSAA_DISABLED, "smooth": Viewport.SCREEN_SPACE_AA_FXAA, "scale": 0.77, "sun_map": 2048, "lamp_map": 2048,
		"soft": RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW, "lamps": 4, "sharp": Viewport.ANISOTROPY_2X, "fine_glow": false, "deband": false},
}
const SETTINGS_FILE := Sfx.SETTINGS_FILE

static var preset := DEFAULT


## Whether the modern renderer draws the game (Forward+ on DirectX 12, Vulkan or Metal), not OpenGL.
static func modern() -> bool:
	return RenderingServer.get_current_rendering_method() != "gl_compatibility"


## How much stronger the sun and the moon shine on the modern renderer. OpenGL draws a light
## that casts shadows (the sun, the moon) in a pass of its own and adds it to the finished picture,
## after the brightness curve, so it counts for much more there; the modern renderer adds all
## light first. Measured on the village by day (tests/lighting_reference_shots.gd with GRID=1):
## the sky's light alone and the sun alone look the same on both, together the modern renderer
## was half as bright, and the sun at 2.5 times its strength brings it level.
const SUN_MATCH := 2.5


## How much stronger a lamp shines on the modern renderer while it casts shadows (see
## LightShadows): OpenGL adds those lamps afterwards too, as it does the sun (see SUN_MATCH), which
## counts for most where little else lights the floor. Measured as SUN_MATCH was: down in the
## dungeons the torches need three times their strength, in the village at night (lamps over
## moonlit cobbles) one and a half.
const LAMP_MATCH := 1.5
const LAMP_MATCH_DUNGEON := 3.0
## The lamps' factor in use: Game.load_level picks it for the level (a variable, so tests can try others).
static var lamp_match := LAMP_MATCH


## How thick the air's haze (Environment fog: rain, snow, fog weather) is drawn on the modern
## renderer. OpenGL mixes the haze into the picture as screen colours, the modern renderer as
## light, where the same pale haze over darker things (people, trees, roofs) shows far stronger:
## winter fog laid one even milky film over the whole village. Half as thick looks as it did.
const FOG_MATCH := 0.5


## The haze's density to draw with, for its density as the weather sets it.
static func fog(density: float) -> float:
	return density * FOG_MATCH if modern() else density


## The sun's or moon's strength to draw with, for its strength as the game sets it. `night` is
## how much of the light is the moon's (DayNight.moon_at): the moon keeps its own strength, as the
## village by night looked far too bright with the sun's factor (the dungeons' faint light from
## above keeps it, see Game._set_atmosphere).
static func sun(energy: float, night := 0.0) -> float:
	return energy * lerpf(SUN_MATCH, 1.0, clampf(night, 0.0, 1.0)) if modern() else energy


## What a material that takes its colour from the mesh's vertex colours sets as
## vertex_color_is_srgb. The game's vertex colours were picked on OpenGL, which reads them as
## screen colours (see shaders/gl_colour.gdshaderinc); the modern renderer reads them as light
## unless told otherwise, and they came out bleached there (pale apple trees). On OpenGL it stays
## false, or the colour would be turned into light twice.
static func vertex_colours_srgb() -> bool:
	return modern()


## How much stronger a shadow-casting lamp shines: lamp_match on the modern renderer, 1 on OpenGL.
static func lamp() -> float:
	return lamp_match if modern() else 1.0


static func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_FILE) == OK:
		var saved := str(cfg.get_value("grafik", "stufe", DEFAULT))
		preset = saved if saved in PRESETS else DEFAULT


static func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_FILE)
	cfg.set_value("grafik", "stufe", preset)
	cfg.save(SETTINGS_FILE)


## Picks a preset, remembers it and draws `view` (the game's window) with it at once.
static func choose(which: String, view: Viewport) -> void:
	if not which in PRESETS:
		return
	preset = which
	_save_settings()
	apply(view)


## Draws `view` as the picked preset says.
static func apply(view: Viewport) -> void:
	var look: Dictionary = LOOKS[preset]
	view.anisotropic_filtering_level = look.sharp
	view.positional_shadow_atlas_size = look.lamp_map
	if modern():
		view.msaa_3d = Viewport.MSAA_DISABLED
		view.screen_space_aa = look.smooth
		var scale: float = look.scale
		view.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if scale < 1.0 else Viewport.SCALING_3D_MODE_BILINEAR
		view.scaling_3d_scale = scale
		view.use_debanding = look.deband
	else:
		view.msaa_3d = look.msaa
		# OpenGL has no SMAA: its cheap pass is FXAA, used only where there is no MSAA.
		view.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if look.msaa == Viewport.MSAA_DISABLED else Viewport.SCREEN_SPACE_AA_DISABLED
	RenderingServer.directional_shadow_atlas_set_size(look.sun_map, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(look.soft)
	RenderingServer.positional_soft_shadow_filter_set_quality(look.soft)
	RenderingServer.environment_glow_set_use_bicubic_upscale(look.fine_glow)
	LightShadows.budget = look.lamps
