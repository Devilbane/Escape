class_name SeasonIcon
extends Control
## The season as a little drawn picture in front of the HUD's location name (see Game._update_season_icon), in the
## same bronze tile as MoonIcon, so it reads without words: spring a blossom on a sprout, summer a
## sun, autumn a turning leaf, winter a snowflake. The name is the tooltip.

const SIZE := 30.0
const RIM := Color(0.72, 0.62, 0.38)
const SKY := {
	Weather.SPRING: Color(0.12, 0.2, 0.14, 0.92), Weather.SUMMER: Color(0.12, 0.2, 0.34, 0.92),
	Weather.AUTUMN: Color(0.22, 0.13, 0.07, 0.92), Weather.WINTER: Color(0.1, 0.15, 0.24, 0.92),
}

var season := Weather.SUMMER


static func make(which: String, tip := "") -> SeasonIcon:
	var icon := SeasonIcon.new()
	icon.custom_minimum_size = Vector2(SIZE, SIZE)
	icon.size = icon.custom_minimum_size
	icon.set_season(which, tip)
	return icon


func set_season(which: String, tip: String) -> void:
	season = which
	tooltip_text = tip
	mouse_filter = Control.MOUSE_FILTER_PASS if tip != "" else Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	UiKit.frame_style(SKY.get(season, SKY[Weather.SUMMER]), RIM, 2, 4).draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
	var c := size / 2.0
	match season:
		Weather.SPRING:
			# A sprout with two leaves, a pink blossom on top.
			var green := Color(0.4, 0.78, 0.3)
			draw_line(c + Vector2(0, 9), c + Vector2(0, -1), Color(0.3, 0.6, 0.22), 2.0, true)
			for side in [-1.0, 1.0]:
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, 6), c + Vector2(side * 8, 1), c + Vector2(side * 6, 7)]), green)
				draw_line(c + Vector2(0, 6), c + Vector2(side * 6.5, 3), Color(0.25, 0.5, 0.2), 1.0, true)
			for i in 5:
				draw_circle(c + Vector2(0, -5) + Vector2.from_angle(TAU * i / 5.0 - PI / 2.0) * 3.6, 2.6, Color(1.0, 0.72, 0.82))
			draw_circle(c + Vector2(0, -5), 1.8, Color(1.0, 0.85, 0.3))
		Weather.SUMMER:
			# A sun: a golden disc with a bright core and short rays.
			for i in 12:
				var d := Vector2.from_angle(TAU * i / 12.0)
				draw_line(c + d * 7.5, c + d * (11.0 if i % 2 == 0 else 9.5), Color(1.0, 0.82, 0.3), 1.6, true)
			draw_circle(c, 6.2, Color(1.0, 0.7, 0.18))
			draw_circle(c + Vector2(-1, -1), 4.2, Color(1.0, 0.86, 0.38))
			draw_circle(c + Vector2(-2, -2), 1.6, Color(1.0, 0.97, 0.8))
		Weather.AUTUMN:
			# A turning leaf: a pointed oval, its veins and stalk.
			var leaf := PackedVector2Array()
			for i in 21:
				var t := PI * i / 20.0
				leaf.append(c + Vector2(-1, -1) + Vector2(sin(t) * 7.0 * (1.0 + 0.25 * cos(t * 2.0)), -cos(t) * 10.0))
			for i in 21:
				var t := PI - PI * i / 20.0
				leaf.append(c + Vector2(-1, -1) + Vector2(-sin(t) * 7.0 * (1.0 + 0.25 * cos(t * 2.0)), -cos(t) * 10.0))
			draw_set_transform(c, 0.6)
			var shape := PackedVector2Array()
			for p in leaf:
				shape.append(p - c)
			draw_colored_polygon(shape, Color(0.92, 0.46, 0.12))
			draw_line(Vector2(0, -10), Vector2(0, 11), Color(0.55, 0.22, 0.06), 1.3, true)
			for y in [-5.0, 0.0, 5.0]:
				draw_line(Vector2(0, y), Vector2(4.5, y - 3.0), Color(0.55, 0.22, 0.06), 1.0, true)
				draw_line(Vector2(0, y), Vector2(-4.5, y - 3.0), Color(0.55, 0.22, 0.06), 1.0, true)
			draw_set_transform(Vector2.ZERO, 0.0)
		_:
			# A snowflake: six arms, each with two small branches.
			var ice := Color(0.85, 0.94, 1.0)
			for i in 6:
				var d := Vector2.from_angle(TAU * i / 6.0)
				draw_line(c, c + d * 10.5, ice, 1.6, true)
				for f in [0.5, 0.75]:
					for turn in [-0.7, 0.7]:
						draw_line(c + d * 10.5 * f, c + d * 10.5 * f + d.rotated(turn) * 3.2, ice, 1.1, true)
			draw_circle(c, 1.8, Color.WHITE)
