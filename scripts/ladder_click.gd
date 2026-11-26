class_name LadderClick
extends RefCounted
## Clicking a ladder (see Player.use_ladder): which ladder the mouse points at, and the glow of the one
## it points at. A ladder is climbed only by a click on it, never by walking into it.

## How near (metres) a click's ray has to pass to the middle line of a ladder to hit it.
const RADIUS := 1.0
## The hover glow over a ladder's rungs.
const GLOW := Color(1.0, 0.82, 0.4)

static var _glow: StandardMaterial3D


## How far the ray from `from` along the unit vector `dir` passes from the segment `a`-`b` (metres).
static func ray_miss(from: Vector3, dir: Vector3, a: Vector3, b: Vector3) -> float:
	var w := a - from
	var u := b - a
	var uu := u.dot(u)
	var ud := u.dot(dir)
	var denom := uu - ud * ud
	var s := 0.0
	if denom > 0.0001:
		s = clampf((w.dot(dir) * ud - w.dot(u)) / denom, 0.0, 1.0)
	var on_ladder := a + u * s
	var t := maxf(0.0, (on_ladder - from).dot(dir))
	return (on_ladder - (from + dir * t)).length()


## The ladder the ray points at that the hero could climb now, or null; the nearest one to the ray.
static func under_ray(tree: SceneTree, hero: Player, from: Vector3, dir: Vector3) -> Node3D:
	var best: Node3D = null
	var best_miss := RADIUS
	for ladder: Node3D in tree.get_nodes_in_group(Player.LADDER_GROUP):
		if hero.ladder_end(ladder) == 0:
			continue
		var foot: Vector3 = ladder.get_meta("foot")
		var top: Vector3 = ladder.get_meta("top")
		var push: Vector3 = ladder.get_meta("push")
		var edge: Vector3 = ladder.get_meta("edge")
		var line := Vector3(edge.x, 0, edge.z) - push * 0.1
		var miss := ray_miss(from, dir, line + Vector3(0, foot.y + 0.3, 0), line + Vector3(0, top.y + 0.4, 0))
		if miss <= best_miss:
			best = ladder
			best_miss = miss
	return best


## The nodes that draw `ladder`: the parts the house sketch built, or the whole upright ladder.
static func visuals(ladder: Node3D) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var parts: Variant = ladder.get_meta("parts") if ladder.has_meta("parts") else null
	if parts is Array:
		for m in parts:
			if is_instance_valid(m):
				out.append(m)
	var root: Variant = ladder.get_meta("visual") if ladder.has_meta("visual") else null
	if root is Node3D and is_instance_valid(root):
		for m in (root as Node3D).find_children("*", "MeshInstance3D", true, false):
			out.append(m)
	return out


## Lights `ladder` up (or puts the light out).
static func glow(ladder: Node3D, on: bool) -> void:
	if _glow == null:
		_glow = StandardMaterial3D.new()
		_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow.albedo_color = Color(GLOW.r, GLOW.g, GLOW.b, 0.45)
	for m in visuals(ladder):
		m.material_overlay = _glow if on else null
