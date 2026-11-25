class_name SilverSilk
extends RefCounted
## Silver spider silk: the only web in the dungeons that glows. A rare few of the cobwebs
## DungeonLife spins are spun of it instead: a pale blue-silver sheet with a faint glow of its
## own (and a tiny light) that shows in the dark. The hero can harvest it (click it or walk up
## to it) for one strand of silver silk in the ingredient pouch; the sheet is gone for good
## afterwards (kept in Level.taken). Every other cobweb, and every web a spider throws, is lit
## like the rest of the world and never glows.

## The station kind of a silver web, and the ingredient it yields (see Crafting).
const KIND := "silberseide"
const ID := "silberseide"
const YIELD := 1
## About one web in this many is silver.
const ONE_IN := 12
const COLOUR := Color(0.74, 0.86, 1.0)
## How strongly the sheet glows, and the light it throws (metres, energy).
const GLOW := 0.9
const LIGHT_RANGE := 2.6
const LIGHT_ENERGY := 0.35

const LEARN := "Manche Spinnweben im Verlies sind aus Silberseide gesponnen und schimmern leise. Lauf gegen eines, um einen Strang Silberseide zu ernten."


## Whether the web at `mid` of the level `level_name` is silver. Decided from the place alone, so the
## same webs are silver every visit, and the ordinary random rolls of the dungeon stay as they were.
static func is_silver(level_name: String, mid: Vector3) -> bool:
	return absi(hash("%s:silk:%d:%d" % [level_name, roundi(mid.x * 4.0), roundi(mid.z * 4.0)])) % ONE_IN == 0


## The key in Level.taken for the silver web at cell `c`.
static func key(c: Vector2i) -> String:
	return "silk:%d:%d" % [c.x, c.y]


## Spins a silver web from `corner` to `a`, `b` and `far` (as DungeonLife._web does) under `parent` and
## registers it as a station of `level`. A web already harvested is not spun again.
static func build(level: Level, parent: Node3D, corner: Vector3, a: Vector3, b: Vector3, far: Vector3, image: int) -> void:
	var mid := (corner + a + b + far) * 0.25
	var cell := level.world_to_cell(mid)
	if level.taken.has(key(cell)):
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal((a - corner).cross(b - corner).normalized())
	for v in [[corner, Vector2(0, 0)], [a, Vector2(1, 0)], [far, Vector2(1, 1)], [corner, Vector2(0, 0)], [far, Vector2(1, 1)], [b, Vector2(0, 1)]]:
		st.set_uv(v[1])
		st.add_vertex(v[0])
	var tex := DungeonLife._web_texture(image)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.albedo_color = COLOUR
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	mat.roughness = 1.0
	mat.emission_enabled = true
	mat.emission_texture = tex
	mat.emission = COLOUR
	mat.emission_energy_multiplier = GLOW
	var sheet := MeshInstance3D.new()
	sheet.mesh = st.commit()
	sheet.material_override = mat
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(sheet)
	var light := OmniLight3D.new()
	light.light_color = COLOUR
	light.light_energy = LIGHT_ENERGY
	light.omni_range = LIGHT_RANGE
	light.shadow_enabled = false
	light.position = mid
	parent.add_child(light)
	var station := {"kind": KIND, "cell": cell, "pos": mid, "spot": mid, "used": false, "sheet": sheet, "light": light}
	if level.cell_char(cell) != "#":
		station["stand"] = level.cell_to_world(cell)
	level.stations.append(station)


## Harvests the web of `station`: marks it taken and removes it. Returns the strands it gives, 0 when
## it was harvested already.
static func harvest(level: Level, station: Dictionary) -> int:
	if level.taken.has(key(station.cell)):
		return 0
	level.taken[key(station.cell)] = true
	level.stations.erase(station)
	for part in ["sheet", "light"]:
		if is_instance_valid(station[part]):
			station[part].queue_free()
	return YIELD


## Takes down the silver webs the hero harvested before (see Level.restore_taken).
static func restore(level: Level) -> void:
	for station in level.stations.duplicate():
		if station.kind == KIND and level.taken.has(key(station.cell)):
			level.taken.erase(key(station.cell))
			harvest(level, station)
			level.taken[key(station.cell)] = true
