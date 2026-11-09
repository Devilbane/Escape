class_name HeroReveal
extends RefCounted
## The see-through circle around the hero. Walls on the near side of a room already fade in front of
## the hero (WallFade), but the wall tops further south and the walls themselves can still hide the
## hero's feet and the floor around them, above all in a narrow corridor. This opens a soft-edged disc
## around the hero in the stone that stands between the camera and the hero (the wall caps and the
## fading near walls, see shaders/reveal.gdshaderinc). It never touches the floor, the dark fill around
## the dungeon or anything behind the hero, so nothing hidden is shown, and it leaves the lighting alone.

## The global shader parameter the wall shaders read (see project.godot).
const PARAM := "hero_reveal"
## Radius of the disc in metres at the hero's depth: about a tile and a quarter (a tile is 4 m wide).
const RADIUS := 5.0
## The hero's chest, so the disc is centred on the body rather than on the feet.
const CHEST := 1.0
## The radius in use (0 turns the circle off).
static var radius := RADIUS


## Centres the disc on `hero`, or switches it off when there is none.
static func follow(hero: Node3D) -> void:
	if hero == null or not is_instance_valid(hero) or not hero.is_inside_tree():
		off()
		return
	var at := SmoothMotion.drawn_at(hero)
	RenderingServer.global_shader_parameter_set(PARAM, Color(at.x, at.y + CHEST, at.z, radius))


static func off() -> void:
	RenderingServer.global_shader_parameter_set(PARAM, Color(0, 0, 0, 0))
