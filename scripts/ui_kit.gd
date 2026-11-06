class_name UiKit
extends RefCounted
## The look of the game's labels, buttons and window frames, in a script of its
## own that needs nothing else from the game. The game (Game._make_label,
## Game._make_button, Menus.panel_style) and the Windows launcher both use it, so
## the launcher looks like the game without carrying the whole game inside it.

const TITLE_FONT := preload("res://assets/fonts/CinzelDecorative-Black.woff2")
const TEXT_FONT := preload("res://assets/fonts/Cinzel-Bold.woff2")
## The forged-bronze frame (BronzeStyle), loaded by its path: the launcher
## runs this script without the game's list of named classes.
const Bronze := preload("res://scripts/bronze_style.gd")
const GOLD := Color(1.0, 0.82, 0.4)
## Button text while the pointer is over the button: a lighter gold.
const BUTTON_HOVER_TEXT := Color(1.0, 0.92, 0.66)
## The forged-bronze look (see BronzeStyle): the tint of the metal rims, the
## dark leather-brown grounds of windows and buttons, and the rims' sizes.
const BRONZE := Color(0.88, 0.66, 0.36)
const PANEL_BG := Color(0.085, 0.062, 0.045, 1.0)
const BUTTON_BG := Color(0.16, 0.1, 0.055, 0.97)
const PANEL_RIM := 15
const PANEL_RADIUS := 8
const BUTTON_RIM := 4
const BUTTON_RADIUS := 6
## The game draws all its text at this share of the size it was designed at
## (the owner found it a quarter too big): use sized() wherever a font size
## is set. The names over the heads of the hero, the townsfolk and the foes
## keep their size, and so does writing that is part of the world (signs,
## wall writings). The launcher keeps its own sizes.
const TEXT_SCALE := 0.75


## `size`, a font size as designed, at the game's text scale (TEXT_SCALE).
static func sized(size: int) -> int:
	return maxi(1, roundi(size * TEXT_SCALE))


static func label(font: Font, size: int, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.06))
	l.add_theme_constant_override("outline_size", maxi(4, size / 6))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Every button of the game, in one look. A button acts when the pointer is
## let go over it, so a click can still be called off by dragging off the
## button; `on_press` makes it act the moment the pointer goes down instead,
## which only the pull-out menu's game actions use (a jump or a strike must
## not trail behind the click).
## The states look different: hover lifts the border to bright gold, a press
## darkens the button, a disabled one is dimmed, and the keyboard focus (see
## Menus) draws a white outline around it. Focus stays off here; a window
## turns it on for its own buttons once the player uses the keys.
static func button(text: String, action: Callable, on_press := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(118, 64)
	b.add_theme_font_override("font", TEXT_FONT)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", GOLD)
	b.add_theme_color_override("font_hover_color", BUTTON_HOVER_TEXT)
	b.add_theme_color_override("font_pressed_color", GOLD)
	b.add_theme_color_override("font_hover_pressed_color", GOLD)
	b.add_theme_color_override("font_focus_color", BUTTON_HOVER_TEXT)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	var normal := Bronze.new()
	normal.bg_color = BUTTON_BG
	normal.border_color = BRONZE
	normal.set_border_width_all(BUTTON_RIM)
	normal.set_corner_radius_all(BUTTON_RADIUS)
	var hover: Bronze = normal.duplicate()
	hover.bg_color = Color(0.21, 0.14, 0.08, 0.9)
	hover.border_color = GOLD
	var pressed: Bronze = normal.duplicate()
	pressed.bg_color = Color(0.32, 0.2, 0.09, 0.9)
	pressed.border_color = GOLD
	var disabled: Bronze = normal.duplicate()
	disabled.bg_color = Color(0.07, 0.05, 0.04, 0.5)
	disabled.border_color = Color(BRONZE, 0.35)
	var focus := Bronze.new()
	focus.draw_center = false
	focus.border_color = Color(1, 1, 1, 0.95)
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(BUTTON_RADIUS + 2)
	focus.set_expand_margin_all(4)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", focus)
	if on_press:
		b.button_down.connect(action)
	else:
		b.pressed.connect(action)
	return b


## The frame of every window: a thick forged-bronze rim with rivets in its
## corners around a dark leather-brown ground. `border` tints the metal (the
## house gold gives bronze); a clearly visible border is drawn solid, so the
## ground does not shine through the rim.
static func panel_style(border: Color) -> Bronze:
	var style := Bronze.new()
	style.bg_color = PANEL_BG
	style.border_color = Color(border, 1.0) if border.a >= 0.6 else border
	style.set_border_width_all(PANEL_RIM)
	style.set_corner_radius_all(PANEL_RADIUS)
	style.set_content_margin_all(26)
	return style


## A smaller bronze frame for boxes inside a window or on the HUD (rows,
## cards, slots, tooltips): a thinner rim, no rivets, the same metal.
static func frame_style(bg: Color, border := BRONZE, width := 3, radius := 4) -> Bronze:
	var style := Bronze.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style


## A bronze rule beside a heading: a thin bar that is bright in its middle
## and fades out at both ends (the section lines of the mock-up).
static func rule() -> TextureRect:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.2, 0.5, 0.8, 1.0])
	gradient.colors = PackedColorArray([Color("a8682c", 0.0), Color("a8682c"), Color("e8b46a"), Color("a8682c"), Color("a8682c", 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 256
	tex.height = 3
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.custom_minimum_size = Vector2(24, 3)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Width of the scroll bars in the windows: slim, so a bar is a quiet hint at
## the side of a list rather than a wide grey strip next to it.
const SCROLL_BAR_WIDTH := 6


## The look of the windows' scroll bars, as a theme for a window's root: a
## faint dark track and a dim gold handle that brightens under the pointer,
## instead of the engine's wide grey bar. Everything else falls through to
## the default look.
static func scroll_theme() -> Theme:
	var theme := Theme.new()
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.0, 0.0, 0.0, 0.3)
	track.set_corner_radius_all(SCROLL_BAR_WIDTH / 2)
	track.set_content_margin_all(SCROLL_BAR_WIDTH / 2.0)
	# How strong the gold of the handle is: at rest, under the pointer, dragged.
	var alphas := {"grabber": 0.45, "grabber_highlight": 0.75, "grabber_pressed": 1.0}
	var handles := {}
	for state in alphas:
		var handle := StyleBoxFlat.new()
		handle.bg_color = Color(GOLD, alphas[state])
		handle.set_corner_radius_all(SCROLL_BAR_WIDTH / 2)
		handle.set_content_margin_all(SCROLL_BAR_WIDTH / 2.0)
		handles[state] = handle
	for type in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", type, track)
		theme.set_stylebox("scroll_focus", type, track)
		for name in handles:
			theme.set_stylebox(name, type, handles[name])
	return theme
