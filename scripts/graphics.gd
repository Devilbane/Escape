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
## shadows: the level of the shadow maps (see SHADOWS), which sets sun_map, lamp_map and soft.
## bump: how strong the surfaces' relief is drawn (1 = as designed, see RELIEF_PARAM). glow: bloom round bright lights.
const LOOKS := {
	QUALITY: {"msaa": Viewport.MSAA_4X, "smooth": Viewport.SCREEN_SPACE_AA_SMAA, "scale": 1.5, "sun_map": 8192, "lamp_map": 4096,
		"soft": RenderingServer.SHADOW_QUALITY_SOFT_HIGH, "lamps": 6, "sharp": Viewport.ANISOTROPY_16X, "fine_glow": true, "deband": true,
		"shadows": "ultra", "bump": 1.0, "glow": true},
	BALANCED: {"msaa": Viewport.MSAA_2X, "smooth": Viewport.SCREEN_SPACE_AA_SMAA, "scale": 1.0, "sun_map": 4096, "lamp_map": 4096,
		"soft": RenderingServer.SHADOW_QUALITY_SOFT_LOW, "lamps": 6, "sharp": Viewport.ANISOTROPY_4X, "fine_glow": true, "deband": true,
		"shadows": "medium", "bump": 1.0, "glow": true},
	PERFORMANCE: {"msaa": Viewport.MSAA_DISABLED, "smooth": Viewport.SCREEN_SPACE_AA_FXAA, "scale": 0.77, "sun_map": 2048, "lamp_map": 2048,
		"soft": RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW, "lamps": 4, "sharp": Viewport.ANISOTROPY_2X, "fine_glow": false, "deband": false,
		"shadows": "low", "bump": 1.0, "glow": true},
}
const SETTINGS_FILE := Sfx.SETTINGS_FILE

static var preset := DEFAULT

## The shadow levels the player can pick: the sun's and the lamps' map sizes and how soft the edges are.
const SHADOW_LEVELS := ["low", "medium", "high", "ultra"]
const SHADOWS := {
	"low": {"sun_map": 2048, "lamp_map": 2048, "soft": RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW},
	"medium": {"sun_map": 4096, "lamp_map": 4096, "soft": RenderingServer.SHADOW_QUALITY_SOFT_LOW},
	"high": {"sun_map": 8192, "lamp_map": 4096, "soft": RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM},
	"ultra": {"sun_map": 8192, "lamp_map": 4096, "soft": RenderingServer.SHADOW_QUALITY_SOFT_HIGH},
}
const SHARP_LEVELS := [Viewport.ANISOTROPY_DISABLED, Viewport.ANISOTROPY_2X, Viewport.ANISOTROPY_4X, Viewport.ANISOTROPY_8X, Viewport.ANISOTROPY_16X]
## The edge smoothing the player can pick. The modern renderer cannot use MSAA (see LOOKS), OpenGL has
## no SMAA and no TAA.
const AA_MODERN := ["off", "fxaa", "smaa", "taa"]
const AA_GL := ["off", "fxaa", "msaa2", "msaa4", "msaa8"]
const SCALE_RANGE := Vector2(0.5, 1.5)
const MAX_LAMPS := 8
const BUMP_RANGE := Vector2(0.0, 1.5)
## The global shader parameter (project.godot) that scales the relief of every bump-mapped surface.
const RELIEF_PARAM := "relief_strength"
## The options the player can change on top of a preset: option -> value. Picking a preset clears them.
## aa (a string of AA_MODERN or AA_GL), scale, sharp (a Viewport.ANISOTROPY_*), shadows (a SHADOW_LEVELS name),
## lamps, bump and glow; a missing option follows the preset.
const OPTIONS := ["aa", "scale", "sharp", "shadows", "lamps", "bump", "glow"]
static var custom := {}

## The frame rate caps (0: none) and the vertical sync modes the player can pick. They belong to no preset.
const FPS_CAPS := [0, 30, 60, 90, 120, 144, 165, 240]
const VSYNC_MODES := {"off": DisplayServer.VSYNC_DISABLED, "on": DisplayServer.VSYNC_ENABLED, "adaptive": DisplayServer.VSYNC_ADAPTIVE}
static var vsync := "on"
static var fps_cap := 0
## The picture's colour adjustments (Environment.adjustment_*): the same on every preset, remembered in the
## settings file. The defaults are the game's look.
const TONES := {"brightness": Vector3(0.7, 1.0, 1.4), "contrast": Vector3(0.7, 1.08, 1.5), "saturation": Vector3(0.0, 1.0, 1.6)}
static var tone := {"brightness": 1.0, "contrast": 1.08, "saturation": 1.0}
## The game's Environment, so the bloom can be switched (see watch_environment).
static var _env: Environment


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
	custom = {}
	if cfg.load(SETTINGS_FILE) != OK:
		return
	var saved := str(cfg.get_value("grafik", "stufe", DEFAULT))
	preset = saved if saved in PRESETS else DEFAULT
	for key: String in OPTIONS:
		if cfg.has_section_key("grafik", "o_" + key):
			set_custom(key, cfg.get_value("grafik", "o_" + key), false)
	var sync := str(cfg.get_value("grafik", "vsync", vsync))
	vsync = sync if sync in VSYNC_MODES else "on"
	var cap := int(cfg.get_value("grafik", "fps", 0))
	fps_cap = cap if cap in FPS_CAPS else 0
	for key: String in TONES:
		var range: Vector3 = TONES[key]
		tone[key] = clampf(float(cfg.get_value("grafik", "t_" + key, range.y)), range.x, range.z)


static func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_FILE)
	cfg.set_value("grafik", "stufe", preset)
	for key: String in OPTIONS:
		cfg.set_value("grafik", "o_" + key, custom[key] if custom.has(key) else null)
	cfg.set_value("grafik", "vsync", vsync)
	cfg.set_value("grafik", "fps", fps_cap)
	for key: String in TONES:
		cfg.set_value("grafik", "t_" + key, tone[key])
	cfg.save(SETTINGS_FILE)


## Picks a preset, remembers it and draws `view` (the game's window) with it at once. Options the
## player changed on top of the old preset are let go.
static func choose(which: String, view: Viewport) -> void:
	if not which in PRESETS:
		return
	preset = which
	custom = {}
	_save_settings()
	apply(view)


## Whether the player changed any option on top of the preset.
static func is_custom() -> bool:
	return not custom.is_empty()


## The edge smoothing modes this renderer offers.
static func aa_modes() -> Array:
	return AA_MODERN if modern() else AA_GL


## The edge smoothing a preset (without the player's options) uses, as one of aa_modes().
static func preset_aa(which: String) -> String:
	var look: Dictionary = LOOKS[which]
	if modern():
		return "smaa" if look.smooth == Viewport.SCREEN_SPACE_AA_SMAA else "fxaa"
	match look.msaa:
		Viewport.MSAA_2X:
			return "msaa2"
		Viewport.MSAA_4X:
			return "msaa4"
		Viewport.MSAA_8X:
			return "msaa8"
	return "fxaa"


## Whether `value` is a valid setting of the option `key`.
static func valid(key: String, value: Variant) -> bool:
	match key:
		"aa":
			return value is String and value in aa_modes()
		"scale":
			return (value is float or value is int) and float(value) >= SCALE_RANGE.x - 0.001 and float(value) <= SCALE_RANGE.y + 0.001
		"sharp":
			return value is int and value in SHARP_LEVELS
		"shadows":
			return value is String and value in SHADOW_LEVELS
		"lamps":
			return value is int and value >= 0 and value <= MAX_LAMPS
		"bump":
			return (value is float or value is int) and float(value) >= BUMP_RANGE.x - 0.001 and float(value) <= BUMP_RANGE.y + 0.001
		"glow":
			return value is bool
	return false


## Remembers one option on top of the preset; a value that does not fit is ignored. Returns whether it was taken.
static func set_custom(key: String, value: Variant, save := true) -> bool:
	if not valid(key, value):
		return false
	custom[key] = value
	if save:
		_save_settings()
	return true


## The setting in force for an option: the player's, else the picked preset's.
static func value(key: String) -> Variant:
	if custom.has(key):
		return custom[key]
	var look: Dictionary = LOOKS[preset]
	match key:
		"aa":
			return preset_aa(preset)
		"scale":
			return look.scale
		"sharp":
			return look.sharp
		"shadows":
			return look.shadows
		"lamps":
			return look.lamps
		"bump":
			return look.bump
		"glow":
			return look.glow
	return null


## Changes one option, remembers it and draws `view` with it at once.
static func choose_option(key: String, val: Variant, view: Viewport) -> void:
	if set_custom(key, val):
		apply(view)


## Picks the vertical sync mode, remembers it and uses it at once.
static func choose_vsync(mode: String) -> void:
	vsync = mode if mode in VSYNC_MODES else "on"
	_save_settings()
	apply_display()


## Picks the frame rate cap (0: none), remembers it and uses it at once.
static func choose_fps(cap: int) -> void:
	fps_cap = cap if cap in FPS_CAPS else 0
	_save_settings()
	apply_display()


## Vertical sync and the frame rate cap: the same on every preset.
static func apply_display() -> void:
	DisplayServer.window_set_vsync_mode(VSYNC_MODES[vsync])
	Engine.max_fps = fps_cap


## Sets one colour adjustment (brightness, contrast or saturation), remembers it and uses it at once.
static func choose_tone(key: String, val: float) -> void:
	if not TONES.has(key):
		return
	var range: Vector3 = TONES[key]
	tone[key] = clampf(val, range.x, range.z)
	_save_settings()
	_apply_tone()


static func _apply_tone() -> void:
	if _env:
		_env.adjustment_enabled = true
		_env.adjustment_brightness = tone.brightness
		_env.adjustment_contrast = tone.contrast
		# The saturation is multiplied in where the sky and the weather set it (DayNight, Game).
		_env.adjustment_saturation = tone.saturation


## Gives the game's Environment, so the bloom follows the setting from now on.
static func watch_environment(env: Environment) -> void:
	_env = env
	if _env:
		_env.glow_enabled = bool(value("glow"))
		_apply_tone()


## What the picked preset and the player's options together set (see LOOKS).
static func look() -> Dictionary:
	var look: Dictionary = LOOKS[preset].duplicate()
	for key: String in custom:
		look[key] = custom[key]
	look.merge(SHADOWS[look.shadows], true)
	return look


## Draws `view` as the picked preset and the player's options say.
static func apply(view: Viewport) -> void:
	var look := look()
	view.anisotropic_filtering_level = look.sharp
	view.positional_shadow_atlas_size = look.lamp_map
	if modern():
		view.msaa_3d = Viewport.MSAA_DISABLED
		_apply_edges(view, str(value("aa")))
		var scale: float = look.scale
		view.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if scale < 1.0 else Viewport.SCALING_3D_MODE_BILINEAR
		view.scaling_3d_scale = scale
		view.use_debanding = look.deband
	else:
		_apply_edges(view, str(value("aa")))
	RenderingServer.directional_shadow_atlas_set_size(look.sun_map, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(look.soft)
	RenderingServer.positional_soft_shadow_filter_set_quality(look.soft)
	RenderingServer.environment_glow_set_use_bicubic_upscale(look.fine_glow)
	RenderingServer.global_shader_parameter_set(RELIEF_PARAM, float(look.bump))
	if _env:
		_env.glow_enabled = look.glow
		_apply_tone()
	LightShadows.budget = look.lamps
	apply_display()


## Sets the edge smoothing of `view` to one of aa_modes().
static func _apply_edges(view: Viewport, aa: String) -> void:
	view.msaa_3d = Viewport.MSAA_DISABLED
	view.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	view.use_taa = false
	match aa:
		"fxaa":
			view.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		"smaa":
			view.screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA
		"taa":
			view.use_taa = true
		"msaa2":
			view.msaa_3d = Viewport.MSAA_2X
		"msaa4":
			view.msaa_3d = Viewport.MSAA_4X
		"msaa8":
			view.msaa_3d = Viewport.MSAA_8X
