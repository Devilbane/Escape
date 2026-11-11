class_name DurabilityRim
extends Control
## The wear of an item, shown on its slot's rim: at full durability the rim is
## intact; as points are lost the rim is dimmed from the top downwards, so the
## bright part is a bar from the bottom up that matches what is left. A broken
## piece (0) has a fully dimmed rim. It only paints over the rim, never changes
## the slot's size.

## The dark veil over the dimmed rim.
const VEIL := Color(0.03, 0.02, 0.015, 0.8)

var condition := 1.0
var rim := 5
var radius := 5


## A rim overlay for a slot: `condition_left` 0.0 to 1.0, `rim_width` the slot's border
## width. The overlay covers the top part of the slot (as tall as what is worn away) and
## clips what it draws, so only that part of the frame is dimmed.
static func make(condition_left: float, rim_width: int, corner: int) -> DurabilityRim:
	var r := DurabilityRim.new()
	r.condition = clampf(condition_left, 0.0, 1.0)
	r.rim = rim_width
	r.radius = corner
	r.clip_contents = true
	r.anchor_left = 0.0
	r.anchor_right = 1.0
	r.anchor_top = 0.0
	r.anchor_bottom = 1.0 - r.condition
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## The height of the whole slot, given the height of the dimmed top part.
func slot_height() -> float:
	return size.y / maxf(1.0 - condition, 0.001)


func _draw() -> void:
	if condition >= 1.0:
		return
	var style := UiKit.frame_style(Color.TRANSPARENT, VEIL, rim, radius)
	style.draw_center = false
	style.draw(get_canvas_item(), Rect2(Vector2.ZERO, Vector2(size.x, slot_height())))
