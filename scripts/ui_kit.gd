class_name UiKit
extends RefCounted
## The look of the game's labels, buttons and window frames, in a script of its
## own that needs nothing else from the game. The game (Game._make_label,
## Game._make_button, Menus.panel_style) and the Windows launcher both use it, so
## the launcher looks like the game without carrying the whole game inside it.

const TITLE_FONT := preload("res://assets/fonts/CinzelDecorative-Black.woff2")
const TEXT_FONT := preload("res://assets/fonts/Cinzel-Bold.woff2")
const GOLD := Color(1.0, 0.82, 0.4)
## Button text while the pointer is over the button: a lighter gold.
const BUTTON_HOVER_TEXT := Color(1.0, 0.92, 0.66)
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
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.05, 0.1, 0.72)
	normal.border_color = Color(0.85, 0.66, 0.32, 0.8)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(14)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.17, 0.11, 0.12, 0.85)
	hover.border_color = GOLD
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.3, 0.2, 0.1, 0.85)
	pressed.border_color = GOLD
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.06, 0.05, 0.07, 0.5)
	disabled.border_color = Color(0.85, 0.66, 0.32, 0.3)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color(1, 1, 1, 0.95)
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(16)
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


## The frame of every window.
static func panel_style(border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.03, 0.08, 0.9)
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(26)
	return style


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
