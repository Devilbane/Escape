class_name Cursors
extends RefCounted
## The game's mouse cursors, themed on the devilbane logo and twice the usual size:
## a blue crystal arrow, and a gold one over anything the player can press
## (Control.CURSOR_POINTING_HAND, which buttons already ask for). The pictures are
## drawn by tools/make_cursors.py. The tip is the hotspot, so aiming stays precise.

const ARROW := preload("res://assets/ui/cursor_arrow.png")
const HAND := preload("res://assets/ui/cursor_hand.png")
## Where the tip of the arrow is in the 64 x 64 picture.
const HOTSPOT := Vector2(4, 3)


## Sets both cursors for the game window. Does nothing without a display.
static func setup() -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.set_custom_mouse_cursor(ARROW, Input.CURSOR_ARROW, HOTSPOT)
	Input.set_custom_mouse_cursor(HAND, Input.CURSOR_POINTING_HAND, HOTSPOT)
